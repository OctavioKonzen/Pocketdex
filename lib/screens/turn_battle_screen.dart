// lib/screens/turn_battle_screen.dart
//
// Batalha por turnos (como nos jogos de GBA), igual ao site
// (TurnBattlePage.jsx): seu time contra o time de um amigo (ou um time
// aleatório), com o computador jogando pelo outro lado. O motor fica em
// lib/services/turn_battle.dart.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;

import '../i18n/i18n.dart';
import '../i18n/text.dart';
import '../services/damage_calc.dart';
import '../services/friends_service.dart';
import '../services/league.dart';
import '../services/team_battle.dart';
import '../services/local_database.dart';
import '../services/move_anim.dart';
import '../services/turn_battle.dart';
import '../services/party_battle.dart';
import '../services/user_data.dart';
import '../utils/pokemon_colors.dart';
import '../utils/responsive.dart';
import '../utils/site_ui.dart';
import '../utils/string_extensions.dart';
import '../utils/team_analysis.dart' show allTypes;
import '../widgets/pokemon_sprite.dart';
import '../widgets/trainer_sprite.dart';
import '../services/trainers.dart';
import '../services/battle_log.dart';
import '../services/battle_sounds.dart';
import '../services/gym_challenge.dart';
import '../services/gym_leaders.dart';
import '../services/factory_run.dart';
import 'factory_panels.dart';

/// Um time para a batalha: nome e membros (id + set).
class BattleTeam {
  final String name;
  final List<Member> members;
  const BattleTeam(this.name, this.members);

  static BattleTeam? fromMap(Map<String, dynamic> t) {
    final ids = (t['pokemon'] as List?) ?? const [];
    final sets = (t['sets'] as List?) ?? const [];
    final members = <Member>[
      for (var i = 0; i < ids.length && i < 6; i++)
        if (ids[i] is num) ((ids[i] as num).toInt(), i < sets.length && sets[i] is Map ? Map<String, dynamic>.from(sets[i] as Map) : null),
    ];
    return members.isEmpty ? null : BattleTeam('${t['name'] ?? 'Time'}', members);
  }
}

String battleMonName(Map<String, dynamic> row) => I18n.pokemonName((row['name'] as String).split('-').first.capitalise());

class TurnBattleScreen extends StatefulWidget {
  /// Vindo do Draft: começa direto com esses times.
  final List<Member>? mine, theirs;
  final String foeName;
  const TurnBattleScreen({super.key, this.mine, this.theirs, this.foeName = ''});

  @override
  State<TurnBattleScreen> createState() => _TurnBattleScreenState();
}

class _TurnBattleScreenState extends State<TurnBattleScreen> {
  static const _random = '__random__';
  int? _mine = -1;
  String _difficulty = 'normal';
  String _friend = _random;
  List<BattleTeam>? _friendTeams = const [];
  int? _theirs;
  bool _busy = false;
  int _count = 1;
  bool _npcPartner = false;
  TurnBattle? _battle;
  String _foeName = '';
  String? _foeTrainer;
  // Jornada (gym_challenge.dart): {kind: 'gym' | 'league', leader | region, step, difficulty}.
  Map<String, dynamic>? _challenge;
  String _endNote = '';
  ({String label, VoidCallback onTap})? _next;
  List<Member> _lastMine = const [];
  GymLeader? get _foeLeader {
    final ch = _challenge;
    if (ch == null) return null;
    if (ch['kind'] == 'factory') return null;
    if (ch['kind'] == 'league') {
      final region = _regions.where((r) => r.region == ch['region']).firstOrNull;
      final order = region == null ? const <GymLeader>[] : GymChallenge.leagueOrder(region);
      final step = ch['step'] as int;
      return step < order.length ? order[step] : null;
    }
    return _regions.expand((r) => r.leaders).where((l) => l.id == ch['leader']).firstOrNull;
  }
  // Adversário 'gym:<id>': um líder, Elite Four ou campeão (gym_leaders.json).
  static const _gym = 'gym:';
  // Torre (sequência de vitórias, gym_challenge.dart) e Battle Factory (subir andares com um inicial, factory_run.dart).
  static const _tower = '__tower__', _factory = '__factory__';
  String? get _streak => _friend == _tower ? 'tower' : null;
  bool get _isFactory => _friend == _factory;
  FactoryData? _factoryData;
  // Battle Factory: a posição de cada um da batalha no time da corrida (para ler o HP no fim).
  List<int> _factoryOrder = const [];
  /// Na sequência, a partir da 4ª batalha o computador usa sets competitivos.
  static String _streakDifficulty(int wins, String difficulty) => wins >= 3 ? 'hard' : difficulty;
  List<({String region, List<GymLeader> leaders})> _regions = const [];
  GymLeader? get _leader => _friend.startsWith(_gym)
      ? _regions.expand((r) => r.leaders).where((l) => l.id == _friend.substring(_gym.length)).firstOrNull
      : null;

  /// Prévia dos times (como no Showdown): os dois times e você escolhe quem começa.
  ({List<BattleMon> a, List<BattleMon> b, List<Member> ma, List<Member> mb, double Function() random, String foeName, String? foeTrainer, Map<String, dynamic>? challenge})? _preview;

  /// A batalha individual com a sua própria semente: o replay refaz tudo igual (battle_log.dart).
  TurnBattle _single(List<BattleMon> a, List<BattleMon> b, List<Member> ma, List<Member> mb, double Function() random) {
    final seed = (random() * (1 << 31)).floor();
    final battle = TurnBattle(a, b, League.seededRandom(seed))
      ..ai = _difficulty == 'easy' ? 'easy' : 'normal'
      ..seed = seed;
    // Só quando todos entraram (o time do registro bate com o da batalha).
    if (a.length == ma.length && b.length == mb.length) battle.members = (mine: BattleLog.toRecord(ma), theirs: BattleLog.toRecord(mb));
    return battle;
  }
  BattleHit? _hit;
  double Function(String, List<String>)? _typeEff;
  int _key = 0;

  List<BattleTeam> get _myTeams => [for (final t in UserData.instance.teams) BattleTeam.fromMap(t)].whereType<BattleTeam>().toList();

  @override
  void initState() {
    super.initState();
    DamageData.load().then((data) {
      if (mounted) {
        setState(() {
          _hit = TurnBattleSetup.hitter(data);
          _typeEff = TurnBattleSetup.typeEffect(data);
        });
      }
    });
    if (widget.mine != null && widget.theirs != null) _start(widget.mine!, widget.theirs!, widget.foeName);
    GymLeaders.load().then((regions) => mounted ? setState(() => _regions = regions) : null).catchError((_) => null);
  }

  Future<void> _pickFriend(String uid) async {
    setState(() {
      _friend = uid;
      _theirs = null;
      _friendTeams = uid == _random || uid == _tower || uid == _factory || uid.startsWith(_gym) ? const [] : null;
    });
    if (uid == _random || uid == _tower || uid == _factory || uid.startsWith(_gym)) return;
    try {
      final snap = await FirebaseFirestore.instance.collection('publicTeams').where('ownerUid', isEqualTo: uid).get();
      final teams = [for (final d in snap.docs) BattleTeam.fromMap(d.data())].whereType<BattleTeam>().toList();
      if (mounted && _friend == uid) setState(() => _friendTeams = teams);
    } catch (_) {
      if (mounted) setState(() => _friendTeams = const []);
    }
  }

  Future<void> _start(List<Member>? mine, List<Member>? theirs, String foeName, {GymLeader? pick, Map<String, dynamic>? challenge}) async {
    setState(() => _busy = true);
    try {
    final random = League.seededRandom(Random().nextInt(1 << 31));
    final leader = theirs == null ? pick ?? _leader : null;
    final streak = leader == null && theirs == null ? _streak : null;
    challenge ??= leader != null
        ? {'kind': 'gym', 'leader': leader.id, 'difficulty': _difficulty}
        : streak != null
            ? {'kind': streak, 'wins': 0, 'difficulty': _difficulty}
            : null;
    // Torre: o seu time contra um aleatório.
    final ma = mine ?? await TurnBattleSetup.randomTeam(random, difficulty: _difficulty);
    if (streak != null) {
      final league = UserData.instance.league;
      UserData.instance.update({'league': {...league, streak: {...league[streak] as Map, 'streak': 0}}});
    }
    final mb = theirs ?? (leader != null ? await leader.members(random, difficulty: _difficulty) : await TurnBattleSetup.randomTeam(random, difficulty: _difficulty));
    final foeTrainer = leader?.trainer;
    final a = await TurnBattleSetup.mons(ma, battleMonName);
    final b = await TurnBattleSetup.mons(mb, battleMonName);
    final rosters = <String, List<BattleMon>>{'me': a, 'npc3': b};
    final own = [for (var slot = 0; slot < _count; slot++) slot > 0 && _npcPartner ? 'npc$slot' : 'me'];
    for (final uid in own.where((uid) => uid != 'me')) {
      rosters[uid] = await TurnBattleSetup.mons(await TurnBattleSetup.randomTeam(random, difficulty: _difficulty), battleMonName);
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (a.isNotEmpty && b.isNotEmpty) {
        if ((_count == 1 || challenge?['kind'] == 'league' || streak != null) && widget.mine == null) {
          _preview = (a: a, b: b, ma: ma, mb: mb, random: random, foeName: foeName, foeTrainer: foeTrainer, challenge: challenge);
          return;
        }
        _battle = _count == 1 ? _single(a, b, ma, mb, random) : PartyBattle.create(rosters, [...own, ...List.filled(_count, 'npc3')], _count, random);
        _foeName = foeName;
        _foeTrainer = foeTrainer;
        _challenge = challenge;
        _endNote = '';
        _next = null;
        _lastMine = ma;
        _key++;
      }
    });
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível iniciar a batalha. Confira os times e tente novamente.')));
      }
    }
  }

  void _again() {
    final b = _battle!;
    final seed = Random().nextInt(1 << 31);
    setState(() {
      _battle = TurnBattle(
          [for (final m in b.teams[0]) m.fresh()], [for (final m in b.teams[1]) m.fresh()], League.seededRandom(seed), mode: b.mode, controllers: b.controllers)
        ..ai = b.ai
        ..seed = seed
        ..members = b.members;
      _endNote = '';
      _next = null;
      _key++;
    });
    b.dispose();
  }

  /// Liga: o próximo da Elite Four (ou o Campeão) com o mesmo time seu.
  Future<void> _nextLeague() async {
    final ch = _challenge!;
    final region = _regions.firstWhere((r) => r.region == ch['region']);
    final step = (ch['step'] as int) + 1;
    final foe = GymChallenge.leagueOrder(region)[step];
    final difficulty = '${ch['difficulty'] ?? 'normal'}';
    final random = League.seededRandom(Random().nextInt(1 << 31));
    final mb = await foe.members(random, difficulty: difficulty);
    final a = await TurnBattleSetup.mons(_lastMine, battleMonName);
    final b = await TurnBattleSetup.mons(mb, battleMonName);
    if (!mounted || a.isEmpty || b.isEmpty) return;
    final old = _battle;
    setState(() {
      _difficulty = difficulty;
      _battle = _single(a, b, _lastMine, mb, random);
      _foeName = foe.name;
      _foeTrainer = foe.trainer;
      _challenge = {...ch, 'step': step};
      _endNote = '';
      _next = null;
      _key++;
    });
    old?.dispose();
  }

  /// Torre: o próximo adversário aleatório.
  Future<void> _nextStreak() async {
    final ch = _challenge!;
    final wins = (ch['wins'] as int) + 1;
    final difficulty = '${ch['difficulty'] ?? 'normal'}';
    final random = League.seededRandom(Random().nextInt(1 << 31));
    final ma = _lastMine;
    final mb = await TurnBattleSetup.randomTeam(random, difficulty: _streakDifficulty(wins, difficulty));
    final a = await TurnBattleSetup.mons(ma, battleMonName);
    final b = await TurnBattleSetup.mons(mb, battleMonName);
    if (!mounted || a.isEmpty || b.isEmpty) return;
    final old = _battle;
    setState(() {
      // O computador deixa de jogar ao acaso a partir da 4ª batalha.
      _difficulty = wins >= 3 && difficulty == 'easy' ? 'normal' : difficulty;
      _battle = _single(a, b, ma, mb, random);
      _difficulty = difficulty;
      _lastMine = ma;
      _foeName = '';
      _foeTrainer = null;
      _challenge = {...ch, 'wins': wins};
      _endNote = '';
      _next = null;
      _key++;
    });
    old?.dispose();
  }

  /// Battle Factory: a batalha do andar atual da corrida.
  Future<void> _factoryFloor(Json run) async {
    setState(() => _busy = true);
    try {
      _factoryData ??= await FactoryData.load();
      final (battle, order) = await factoryBattle(run);
      final foe = factoryFoe(run);
      if (!mounted) return;
      final old = _battle;
      setState(() {
        _busy = false;
        _battle = battle;
        _factoryOrder = order;
        _foeName = foe.foeName;
        _foeTrainer = foe.foeTrainer;
        _challenge = foe.challenge;
        _endNote = '';
        _next = null;
        _key++;
      });
      old?.dispose();
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível iniciar a batalha. Confira os times e tente novamente.')));
      }
    }
  }

  /// Fim de uma batalha da jornada: insígnia, próxima da Liga ou Hall da Fama; Torre: a sequência; Factory: o andar.
  Future<void> _finishChallenge() async {
    final kind = _challenge?['kind'];
    if (kind == 'factory') {
      final factory = currentFactory();
      final run = factory['run'] as Map<String, dynamic>?;
      if (run == null || run['encounter'] == null) return;
      final floor = run['floor'];
      String note;
      if (_battle?.winner == 0) {
        final data = _factoryData ??= await FactoryData.load();
        final after = factoryAfter(_battle!, _factoryOrder, run);
        saveFactory({...factory, 'run': FactoryRun.winFloor(run, data, hp: after.hp, bag: after.bag)});
        final boss = run['encounter']['boss'] as Map?;
        note = '${boss != null ? '🏅 ${tr('Você venceu {0}!').replaceAll('{0}', '${boss['name']}')} ' : '🏆 '}${tr('Andar {0} vencido!').replaceAll('{0}', '$floor')}';
      } else {
        final after = FactoryRun.endRun(factory, run);
        saveFactory(after);
        note = tr('A corrida acabou no andar {0}: +{1} moedas. Recorde: andar {2}.')
            .replaceAll('{0}', '$floor')
            .replaceAll('{1}', '${(after['last'] as Map)['coins']}')
            .replaceAll('{2}', '${after['best']}');
      }
      if (mounted) {
        setState(() {
          _endNote = note;
          _next = null;
        });
      }
      return;
    }
    if (kind == 'tower') {
      final won = _battle?.winner == 0;
      final after = GymChallenge.streakResult(UserData.instance.league, '$kind', won);
      UserData.instance.update({'league': after});
      final wins = _challenge!['wins'] as int;
      setState(() {
        _endNote = won
            ? '🔥 ${tr('{0} vitórias seguidas!').replaceAll('{0}', '${wins + 1}')}'
            : tr('A sequência terminou com {0} vitórias. Recorde: {1}.').replaceAll('{0}', '$wins').replaceAll('{1}', '${(after[kind] as Map)['best']}');
        _next = won ? (label: '⚔️ ${tr('Próximo adversário')}', onTap: () => _nextStreak()) : null;
      });
      return;
    }
    final ch = _challenge, foe = _foeLeader, b = _battle;
    if (ch == null || foe == null || b == null) return;
    final won = b.winner == 0;
    final league = UserData.instance.league;
    final region = GymChallenge.regionOf(_regions, foe.id);
    if (region == null) return;
    var note = '';
    ({String label, VoidCallback onTap})? next;
    if (ch['kind'] == 'gym') {
      if (won) {
        final after = GymChallenge.winBadge(league, _regions, foe);
        UserData.instance.update({'league': after});
        if (GymChallenge.badgesOf(after, region).length > GymChallenge.badgesOf(league, region).length) {
          note = '🏅 ${tr('Você ganhou a insígnia de {0}!').replaceAll('{0}', foe.name)}';
          if (!GymChallenge.leagueOpen(league, region) && GymChallenge.leagueOpen(after, region)) {
            note += ' ${tr('A Liga de {0} foi liberada!').replaceAll('{0}', region.region)}';
          }
        }
      }
    } else {
      final order = GymChallenge.leagueOrder(region);
      final step = ch['step'] as int;
      if (!won) {
        note = tr('A Liga acabou. Tente de novo!');
      } else if (step < order.length - 1) {
        final upcoming = order[step + 1];
        note = tr('Próximo desafiante: {0}').replaceAll('{0}', upcoming.name);
        next = (label: '⚔️ ${tr('Enfrentar {0}').replaceAll('{0}', upcoming.name)}', onTap: _nextLeague);
      } else {
        UserData.instance.update({
          'league': GymChallenge.addHallOfFame(league, region, [for (final m in _lastMine) m.$1], UserData.instance.trainer, DateTime.now().millisecondsSinceEpoch),
        });
        note = '🏆 ${tr('Você venceu a Liga de {0} e entrou no Hall da Fama!').replaceAll('{0}', region.region)}';
      }
    }
    setState(() {
      _endNote = note;
      _next = next;
    });
  }

  @override
  void dispose() {
    _battle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final battle = _battle;
    return Scaffold(
      appBar: AppBar(title: const Text('Batalha')),
      body: ReadableWidth(
        child: battle != null && _hit != null
            ? ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  BattleView(
                    key: ValueKey(_key),
                    battle: battle,
                    hit: _hit!,
                    typeEff: _typeEff!,
                    foeName: _foeName,
                    foeTrainer: _foeTrainer,
                    intro: true,
                    music: _challenge?['boss'] is Map
                        ? GymChallenge.musicFor('${_challenge!['boss']['name']}', '${_challenge!['boss']['kind']}', '${_challenge!['boss']['region']}')
                        : GymChallenge.musicOf(_foeLeader),
                    endNote: _endNote,
                    next: _next,
                    wild: _challenge?['wild'] == true,
                    canAgain: !const ['league', 'tower', 'factory'].contains(_challenge?['kind']),
                    onFinish: (foeTrainer) {
                      final b = _battle;
                      // A Factory fica fora do histórico: o replay não refaz as bolsas da corrida.
                      if (b != null && b.members != null && b.seed != null && _challenge?['kind'] != 'factory') {
                        BattleLog.add(BattleLog.record(b, foeName: _foeName, foeTrainer: foeTrainer));
                      }
                      _finishChallenge();
                    },
                    onAgain: _again,
                    onExit: () {
                      if (widget.mine != null) { Navigator.pop(context); }
                      else { _battle?.dispose(); setState(() => _battle = null); }
                    },
                  ),
                  if (_challenge?['kind'] == 'factory' && _endNote.isNotEmpty && _factoryData != null && currentFactory()['run'] != null)
                    FactoryAfter(key: ValueKey('after-$_key'), run: Map<String, dynamic>.from(currentFactory()['run'] as Map), data: _factoryData!, onNext: _factoryFloor),
                ],
              )
            : _preview != null
                ? _previewView(context, _preview!)
                : _setup(context),
      ),
    );
  }

  /// Prévia dos times: o do adversário e o seu, tocando em quem começa.
  Widget _previewView(BuildContext context, ({List<BattleMon> a, List<BattleMon> b, List<Member> ma, List<Member> mb, double Function() random, String foeName, String? foeTrainer, Map<String, dynamic>? challenge}) p) {
    final c = SiteColors.of(context);
    void lead(int i) {
      List<T> first<T>(List<T> list) => [list[i], for (var j = 0; j < list.length; j++) if (j != i) list[j]];
      setState(() {
        _preview = null;
        _battle = _single(first(p.a), p.b, p.ma.length == p.a.length ? first(p.ma) : p.ma, p.mb, p.random);
        _foeName = p.foeName;
        _foeTrainer = p.foeTrainer;
        _challenge = p.challenge;
        _endNote = '';
        _next = null;
        _lastMine = p.ma.length == p.a.length ? first(p.ma) : p.ma;
        _key++;
      });
    }

    Widget icon(BattleMon mon, double size) => SizedBox.square(dimension: size, child: PokemonSprite(mon.id, shiny: mon.shiny, fill: 0.95));
    return ListView(
      key: const ValueKey('team-preview'),
      padding: const EdgeInsets.all(16),
      children: [
        Text('Prévia dos times', style: TextStyle(color: c.text, fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Text(p.foeName.isNotEmpty ? tr('Time de {0}').replaceAll('{0}', p.foeName) : 'Time do adversário', style: TextStyle(color: c.muted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final mon in p.b)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [icon(mon, 48), m.Text(mon.name, style: TextStyle(color: c.text, fontSize: 11, fontWeight: FontWeight.w700))]),
            ),
        ]),
        const SizedBox(height: 16),
        Text('Escolha quem começa', style: TextStyle(color: c.muted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.85,
          children: [
            for (var i = 0; i < p.a.length; i++)
              InkWell(
                key: ValueKey('lead-$i'),
                borderRadius: BorderRadius.circular(14),
                onTap: () => lead(i),
                child: Container(
                  decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.all(6),
                  child: Column(children: [
                    Expanded(child: LayoutBuilder(builder: (context, box) => icon(p.a[i], box.biggest.shortestSide))),
                    m.Text(p.a[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.text, fontSize: 12, fontWeight: FontWeight.w800)),
                    Wrap(spacing: 2, children: [for (final t in p.a[i].types) TypeBadge(t, small: true)]),
                  ]),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: () => setState(() => _preview = null), child: const Text('Voltar')),
      ],
    );
  }

  Widget _teamRow(BattleTeam t) => Row(
        children: [
          Expanded(child: m.Text(t.name, overflow: TextOverflow.ellipsis)),
          for (final mb in t.members) SizedBox.square(dimension: 28, child: PokemonSprite(mb.$1, shiny: mb.$2?['shiny'] == true, fill: 0.95)),
        ],
      );

  Widget _setup(BuildContext context) {
    final c = SiteColors.of(context);
    if (widget.mine != null) return const Center(child: CircularProgressIndicator());
    final myTeams = _myTeams;
    final friends = FriendsService.instance.friends;
    InputDecoration deco(String label) => InputDecoration(labelText: tr(label), border: const OutlineInputBorder(), isDense: true);
    final ready = (_mine == -1 || _mine != null && myTeams[_mine!].members.length >= (_npcPartner ? 1 : _count)) && (_friend == _random || _streak != null || _leader != null || _theirs != null && _friendTeams![_theirs!].members.length >= _count);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!_isFactory) DropdownButtonFormField<int>(initialValue: _count, decoration: deco('Formato'), items: const [DropdownMenuItem(value: 1, child: Text('Individual')), DropdownMenuItem(value: 2, child: Text('Dupla')), DropdownMenuItem(value: 3, child: Text('Tripla'))], onChanged: _busy ? null : (v) => setState(() => _count = v!)),
        if (_count > 1 && !_isFactory) CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Jogar com parceiros NPC'), subtitle: const Text('Desmarcado: você controla todos os Pokémon.'), value: _npcPartner, onChanged: _busy ? null : (v) => setState(() => _npcPartner = v!)),
        const SizedBox(height: 12),
        Text(
            _isFactory
                ? 'Battle Factory: sem nível máximo. Batalha por turnos como nos jogos, com o computador jogando pelo outro lado.'
                : 'Nível máximo 50. Batalha por turnos como nos jogos: seu time contra o de um amigo (ou um aleatório), com o computador jogando pelo outro lado.',
            style: TextStyle(color: c.muted, fontSize: 13)),
        const SizedBox(height: 14),
        if (!_isFactory)
          DropdownButtonFormField<int>(
            initialValue: _mine,
            isExpanded: true,
            decoration: deco('Seu time'),
            items: [const DropdownMenuItem(value: -1, child: Text('🎲 Time aleatório')), for (final (i, t) in myTeams.indexed) DropdownMenuItem(value: i, child: _teamRow(t))],
            onChanged: (v) => setState(() => _mine = v),
          ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _friend,
          isExpanded: true,
          decoration: deco('Adversário'),
          items: [
            const DropdownMenuItem(value: _random, child: Text('🎲 Time aleatório')),
            DropdownMenuItem(value: _tower, child: m.Text('🗼 ${tr('Torre de Batalha')}')),
            DropdownMenuItem(value: _factory, child: m.Text('🏭 ${tr('Battle Factory')}')),
            for (final f in friends) DropdownMenuItem(value: f.uid, child: m.Text(f.name)),
            // Desafio dos Líderes: um cabeçalho por região.
            for (final r in _regions) ...[
              DropdownMenuItem(
                  enabled: false,
                  value: 'region:${r.region}',
                  child: m.Text('${tr('Líderes e campeões')} · ${r.region}', style: TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.w800))),
              for (final l in r.leaders)
                DropdownMenuItem(value: '$_gym${l.id}', child: m.Text('   ${l.name}${const {'elite': ' · E4', 'champion': ' · 👑', 'kahuna': ' · Kahuna'}[l.kind] ?? ''}')),
            ],
          ],
          onChanged: (v) => _pickFriend(v ?? _random),
        ),
        if (_leader != null) ...[const SizedBox(height: 10), _LeaderCard(leader: _leader!)],
        if (_streak != null) ...[const SizedBox(height: 10), _StreakCard(kind: _streak!)],
        if (_isFactory) ...[const SizedBox(height: 10), FactoryHub(onBattle: _factoryFloor, busy: _busy || _hit == null)],
        if (_leader != null && GymChallenge.regionOf(_regions, _leader!.id) != null) ...[
          const SizedBox(height: 10),
          ListenableBuilder(
            listenable: UserData.instance,
            builder: (context, _) => _RegionProgress(
              region: GymChallenge.regionOf(_regions, _leader!.id)!,
              enabled: !_busy && _hit != null && (_mine == -1 || _mine != null),
              onLeague: (first, region) => _start(_mine == -1 ? null : myTeams[_mine!].members, null, first.name,
                  pick: first, challenge: {'kind': 'league', 'region': region.region, 'step': 0, 'difficulty': _difficulty}),
            ),
          ),
        ],
        if (_friend == _random || _streak != null || _leader != null || _npcPartner) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(isExpanded: true, initialValue: _difficulty, decoration: deco('Dificuldade dos NPCs'), items: const [DropdownMenuItem(value: 'easy', child: Text('Fácil')), DropdownMenuItem(value: 'normal', child: Text('Normal')), DropdownMenuItem(value: 'hard', child: Text('Difícil'))], onChanged: _busy ? null : (v) => setState(() => _difficulty = v!)),
          const SizedBox(height: 6),
          const Text('Fácil: o computador ataca ao acaso, sem trocar nem usar itens.\nNormal: IVs e EVs aleatórios.\nDifícil: sets competitivos.'),
        ],
        if (_friend != _random && _leader == null && _streak == null && !_isFactory) ...[
          const SizedBox(height: 12),
          if (_friendTeams == null)
            const Center(child: CircularProgressIndicator())
          else if (_friendTeams!.isEmpty)
            Text('Esse amigo ainda não montou nenhum time.', style: TextStyle(color: c.muted))
          else
            DropdownButtonFormField<int>(
              initialValue: _theirs,
              isExpanded: true,
              decoration: deco('Time do amigo'),
              items: [for (final (i, t) in _friendTeams!.indexed) DropdownMenuItem(value: i, child: _teamRow(t))],
              onChanged: (v) => setState(() => _theirs = v),
            ),
        ],
        const SizedBox(height: 10),
        Text(
            'O computador joga pelo adversário. Golpes com PP, precisão, prioridade, crítico, status, mudanças de atributo e clima.',
            style: TextStyle(color: c.muted, fontSize: 12)),
        const SizedBox(height: 14),
        if (!_isFactory)
        PillButton(
          label: _busy ? tr('Preparando...') : '⚔️ ${tr('Começar batalha')}',
          expand: true,
          gradient: const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFF9333EA)]),
          onPressed: _busy || !ready || _hit == null
              ? null
              : () {
                  final leader = _leader;
                  final foe = leader?.name ?? (_friend == _random ? '' : friends.where((f) => f.uid == _friend).firstOrNull?.name ?? '');
                  _start(_mine == -1 ? null : myTeams[_mine!].members, _friend == _random || leader != null || _streak != null ? null : _friendTeams![_theirs!].members, foe);
                },
        ),
      ],
    );
  }
}

/// Torre de Batalha: como funciona e o seu recorde.
class _StreakCard extends StatelessWidget {
  final String kind;
  const _StreakCard({required this.kind});

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final best = ((UserData.instance.league[kind] as Map?)?['best'] as num? ?? 0).toInt();
    return Container(
      key: const ValueKey('streak-card'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        m.Text('🗼 ${tr('Torre de Batalha')}', style: TextStyle(color: c.text, fontWeight: FontWeight.w900)),
        Text(
            'Seu time contra adversários aleatórios em sequência; a partir da 4ª vitória eles usam sets competitivos. Perdeu, a sequência acaba.',
            style: TextStyle(color: c.muted, fontSize: 12)),
        const SizedBox(height: 4),
        m.Text(tr('Recorde: {0} vitórias seguidas').replaceAll('{0}', '$best'), style: TextStyle(color: c.text, fontWeight: FontWeight.w800, fontSize: 13)),
      ]),
    );
  }
}

/// A região do líder: as insígnias e a Liga (liberada com as insígnias).
class _RegionProgress extends StatelessWidget {
  final Region region;
  final bool enabled;
  final void Function(GymLeader first, Region region) onLeague;
  const _RegionProgress({required this.region, required this.enabled, required this.onLeague});

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final league = UserData.instance.league;
    final have = GymChallenge.badgesOf(league, region);
    final open = GymChallenge.leagueOpen(league, region);
    final order = GymChallenge.leagueOrder(region);
    final halls = [for (final h in league['hall'] as List) if ((h as Map)['region'] == region.region) h].length;
    return Container(
      key: const ValueKey('region-progress'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          m.Text('${tr('Insígnias de {0}').replaceAll('{0}', region.region)}: ${have.length}/${GymChallenge.badgesNeeded(region)}${halls > 0 ? '   🏆 ×$halls' : ''}',
              style: TextStyle(color: c.text, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final l in GymChallenge.regionGyms(region))
              Tooltip(
                message: l.name,
                child: Container(
                  key: ValueKey('badge-${l.id}-${have.contains(l.id) ? 'on' : 'off'}'),
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: have.contains(l.id) ? getColorForType(l.type) : const Color(0x5564748B),
                    border: have.contains(l.id) ? Border.all(color: const Color(0xFFFBBF24), width: 2) : null,
                  ),
                  child: have.contains(l.id) ? const m.Text('★', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)) : null,
                ),
              ),
          ]),
          const SizedBox(height: 8),
          PillButton(
            key: const ValueKey('league-button'),
            label: '🏆 ${tr('Desafiar a Liga de {0}').replaceAll('{0}', region.region)}',
            expand: true,
            gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFDC2626)]),
            onPressed: open && enabled && order.isNotEmpty ? () => onLeague(order.first, region) : null,
          ),
          const SizedBox(height: 4),
          m.Text(
            open
                ? tr('Elite Four e Campeão em sequência ({0} batalhas). Perdeu, recomeça.').replaceAll('{0}', '${order.length}')
                : tr('Vença os líderes de ginásio para ganhar as insígnias e liberar a Liga.'),
            style: TextStyle(color: c.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// O líder escolhido: o treinador e o time (todos no nível 50, já evoluídos).
class _LeaderCard extends StatelessWidget {
  final GymLeader leader;
  const _LeaderCard({required this.leader});

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final trainer = Trainers.byId(leader.trainer);
    return Container(
      key: const ValueKey('leader-card'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          if (trainer != null) TrainerSprite(trainer, box: 84),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                m.Text(leader.name, style: TextStyle(color: c.text, fontWeight: FontWeight.w900, fontSize: 16)),
                Text(leader.kindLabel, style: TextStyle(color: c.muted, fontSize: 12)),
                const SizedBox(height: 4),
                Wrap(spacing: 2, runSpacing: 2, children: [
                  for (final id in leader.team) SizedBox.square(dimension: 40, child: PokemonSprite(id, fill: 0.95)),
                ]),
                Text('Time original, já evoluído, todos no nível 50.', style: TextStyle(color: c.muted, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnlineBattleControl {
  final String uid;
  final Map<String, dynamic> names;
  final int round;
  final List<BattleEvent> events;
  final List<int>? before;
  final bool locked, waitForSwitch;
  final String message;
  final void Function(Map<String, dynamic>) onAction;
  final VoidCallback onClose;

  /// Replay (battle_history_screen.dart): os eventos do começo também passam
  /// na tela, e [onPlayed] avisa quando cada rodada terminou de passar.
  final bool replay;
  final VoidCallback? onPlayed;
  const OnlineBattleControl({required this.round, required this.events, this.before, this.uid = 'me', this.names = const {},
    required this.locked, required this.waitForSwitch, required this.message,
    required this.onAction, required this.onClose, this.replay = false, this.onPlayed});
}

class BattleView extends StatefulWidget {
  final TurnBattle battle;
  final BattleHit hit;
  final double Function(String, List<String>) typeEff;
  final String foeName;
  final VoidCallback onAgain, onExit;
  final OnlineBattleControl? online;

  /// A abertura: os treinadores aparecem, lançam a Poké Ball e os Pokémon saem.
  final bool intro;

  /// O treinador do adversário (id de trainers.json; null: um sorteado).
  final String? foeTrainer;

  /// A batalha acabou (com o treinador do adversário): histórico e replay.
  final void Function(String? foeTrainer)? onFinish;

  /// Jornada (gym_challenge.dart): a música, a mensagem do fim e o próximo desafiante.
  final String music;
  final String endNote;
  final ({String label, VoidCallback onTap})? next;
  final bool canAgain;

  /// Pokémon selvagem (Battle Factory): sem treinador do outro lado.
  final bool wild;
  const BattleView(
      {super.key,
      required this.battle,
      required this.hit,
      required this.typeEff,
      required this.foeName,
      required this.onAgain,
      required this.onExit,
      this.online,
      this.intro = false,
      this.foeTrainer,
      this.onFinish,
      this.music = 'battle_music',
      this.endNote = '',
      this.next,
      this.canAgain = true,
      this.wild = false});

  @override
  State<BattleView> createState() => BattleViewState();
}

class BattleViewState extends State<BattleView> with SingleTickerProviderStateMixin, RouteAware {
  static const _step = Duration(milliseconds: 1100);
  late final List<int> _active = [widget.battle.activeIndex[0], widget.battle.activeIndex[1]];
  late final List<List<int>> _hp = [
    for (final t in widget.battle.teams) [for (final mon in t) mon.hp]
  ];
  late final List<List<String>> _status = [
    for (final t in widget.battle.teams) [for (final mon in t) mon.status]
  ];
  late final List<bool> _fainted = [for (final s in [0, 1]) widget.battle.active(s).hp <= 0];

  /// Forma na tela (Mega / Gigantamax) e se está dinamaxizado.
  late final List<int?> _form = [for (final s in [0, 1]) widget.battle.active(s).id];
  late final List<bool> _dmax = [for (final s in [0, 1]) widget.battle.active(s).dmax > 0];

  /// Tipo Tera de quem terastalizou ('' se não): brilho de cristal e joia na tela.
  late final List<String> _tera = [for (final s in [0, 1]) _teraOf(widget.battle.active(s))];

  /// Estágios dos atributos de quem está em campo (Swords Dance: Atq +2, +4... até +6).
  late final List<Map<String, int>> _boosts = [for (final s in [0, 1]) Map.of(widget.battle.active(s).boosts)];

  /// Clima na tela (o cenário muda com ele).
  late String _weather = widget.battle.weather;
  late String _text = widget.foeName.isNotEmpty ? tr('{0} quer batalhar!').replaceAll('{0}', widget.foeName) : tr('Um treinador quer batalhar!');
  bool _busy = false;
  String _menu = 'main'; // main | fight | party | bag
  String? _item; // item da Bolsa escolhido (falta escolher em quem)
  String? _gimmickPick;
  int? _gimmickMon;
  late final _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  int _flash = 0;
  Completer<void>? _skip;
  final _sprites = [GlobalKey<_SpriteState>(), GlobalKey<_SpriteState>()];
  (FxPlan, Color, int)? _fx; // animação do golpe na tela
  int _fxKey = 0;

  /// A animação de cada golpe (estilo, símbolo e variação).
  Map<String, dynamic>? _anims;
  Future<void> _onlineQueue = Future.value();

  /// Os treinadores da abertura: o seu (de costas) e o do adversário.
  late final Trainer? _coach = widget.wild ? null : widget.foeTrainer != null ? Trainers.byId(widget.foeTrainer) : Trainers.random();
  late final Trainer? _myTrainer = Trainers.mine;
  bool _introOn = false;
  bool _finished = false;
  bool _foeGone = false, _meGone = false;
  int _backFrame = 0;

  /// Cada Pokémon: '' na tela, 'hidden' dentro da Poké Ball, 'release' saindo, 'recall' voltando.
  final List<String> _poke = ['', ''];

  /// A Poké Ball de cada lado: 'throw' (lançada) ou 'open' (abrindo na plataforma).
  final List<String?> _ball = [null, null];

  @override
  void initState() {
    super.initState();
    if (_b.mode != 'singles') return;
    // A música da batalha (para quando sai da tela).
    if (_b.winner == null) BattleSounds.startMusic(widget.music, this);
    LocalDatabase.instance.moveAnims().then((t) => _anims = t).catchError((_) => <String, dynamic>{});
    // Começo: as habilidades de clima de quem entrou (Drizzle, Drought...).
    _menu = _b.needSwitch ? 'party' : 'main';
    final online = widget.online;
    if (online != null) {
      // Replay: a primeira rodada (o começo da batalha) também passa na tela.
      if (online.replay) {
        _busy = true;
        _onlineQueue = _onlineQueue.then((_) async {
          await _wait(300);
          if (mounted) await _play(online.events, online.before);
          if (mounted) online.onPlayed?.call();
        });
      }
      return;
    }
    _introOn = widget.intro;
    // Com a abertura, quem entrou já saiu da Poké Ball nela: sem repetir o "enviou".
    final opening = [
      for (final e in _b.start())
        if (!_introOn || (e.t != 'switch' && e.key != 'go' && e.key != 'foeSent')) e
    ];
    if (_introOn) {
      _poke.setAll(0, ['hidden', 'hidden']);
      _busy = true;
      _runIntro().then((_) {
        if (!mounted) return;
        if (opening.isNotEmpty) {
          _play(opening);
        } else {
          setState(() => _busy = false);
        }
      });
    } else if (opening.isNotEmpty) {
      _busy = true;
      _wait(_step.inMilliseconds).then((_) => mounted ? _play(opening) : null);
    }
  }

  /// A Poké Ball abre na plataforma e o Pokémon sai dela.
  Future<void> _release(int side) async {
    BattleSounds.play('open');
    setState(() => _ball[side] = 'open');
    await _wait(260);
    if (!mounted) return;
    setState(() {
      _ball[side] = null;
      _poke[side] = 'release';
    });
    await _wait(420);
    if (mounted) setState(() => _poke[side] = '');
  }

  /// A abertura: os treinadores aparecem, lançam a Poké Ball e os Pokémon saem.
  Future<void> _runIntro() async {
    await _wait(700);
    if (!mounted) return;
    if (widget.foeName.isEmpty && _coach != null) setState(() => _text = tr('{0} quer batalhar!').replaceAll('{0}', _coach.name));
    await _wait(1100);
    if (!mounted) return;
    final who = widget.foeName.isNotEmpty ? widget.foeName : _coach?.name ?? tr('O adversário');
    if (widget.wild) {
      // Selvagem: ele já está ali, sem Poké Ball.
      setState(() {
        _foeGone = true;
        _poke[1] = '';
        _text = tr('Um {0} selvagem apareceu!').replaceAll('{0}', _b.active(1).name);
      });
      await _wait(900);
    } else {
      setState(() {
        _text = tr('{0} enviou {1}!').replaceAll('{0}', who).replaceAll('{1}', _b.active(1).name);
        _foeGone = true;
        _ball[1] = 'throw';
      });
      BattleSounds.play('throw');
      await _wait(520);
      if (!mounted) return;
      await _release(1);
    }
    if (!mounted) return;
    setState(() => _text = tr('Vai, {0}!').replaceAll('{0}', _b.active(0).name));
    for (var f = 1; f < 5; f++) {
      setState(() => _backFrame = f);
      await _wait(90);
      if (!mounted) return;
    }
    setState(() {
      _meGone = true;
      _ball[0] = 'throw';
    });
    BattleSounds.play('throw');
    await _wait(520);
    if (!mounted) return;
    await _release(0);
    if (mounted) setState(() => _introOn = false);
  }

  @override
  void didUpdateWidget(covariant BattleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_b.mode != 'singles') return;
    final online = widget.online;
    if (online == null || online.round == oldWidget.online?.round) return;
    _busy = true;
    _onlineQueue = _onlineQueue.then((_) async {
      if (mounted) await _play(online.events, online.before);
      if (mounted) online.onPlayed?.call();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      BattleSounds.routes.unsubscribe(this);
      BattleSounds.routes.subscribe(this, route);
    }
  }

  // Outra tela abriu por cima da batalha: a música pausa; voltou, continua.
  @override
  void didPushNext() => BattleSounds.setCovered(true, this);
  @override
  void didPopNext() => BattleSounds.setCovered(false, this);

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _shake.dispose();
    BattleSounds.routes.unsubscribe(this);
    BattleSounds.stopMusic(this);
    super.dispose();
  }

  /// Voltar no meio da batalha: pergunta antes de sair.
  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da batalha?'),
        content: const Text('A batalha em andamento será perdida.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Continuar batalhando')),
          FilledButton(key: const ValueKey('confirm-leave'), onPressed: () => Navigator.pop(context, true), child: const Text('Sair')),
        ],
      ),
    );
    if (leave != true || !mounted) return;
    BattleSounds.stopMusic(this);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: _b.winner != null || widget.online?.replay == true,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _confirmLeave();
        },
        child: _battleBody(context),
      );

  /// Esperas da animação: canceladas quando a tela fecha (nada fica rodando).
  final Set<Timer> _timers = {};
  Future<void> _wait(int ms) {
    final done = Completer<void>();
    late final Timer timer;
    timer = Timer(Duration(milliseconds: ms), () {
      _timers.remove(timer);
      done.complete();
    });
    _timers.add(timer);
    return done.future;
  }

  TurnBattle get _b => widget.battle;

  String _format(BattleEvent e) {
    final (line, args) = TurnBattle.lineOf(e);
    var text = tr(line);
    for (var i = 0; i < args.length; i++) {
      // Nomes dos atributos (Ataque, Defesa...) também são traduzidos.
      text = text.replaceFirst('{$i}', statNames.containsValue(args[i]) ? tr(args[i]) : args[i]);
    }
    return text;
  }

  /// [before]: o id de cada lado antes do turno (o motor já mudou a Mega; a tela muda no evento).
  Future<void> _play(List<BattleEvent> events, [List<int>? before]) async {
    setState(() {
      _busy = true;
      if (before != null) {
        for (final s in [0, 1]) {
          if (!_dmax[s]) _form[s] = before[s];
        }
      }
    });
    try {
    String? lastEffect;
    for (final e in events) {
      if (!mounted) return;
      // Som de cada evento (golpe, super efetivo, desmaio, atributos, cura).
      if (e.t == 'text' && (e.key == 'super' || e.key == 'weak')) lastEffect = e.key;
      final sound = BattleSounds.of(e, lastEffect);
      if (sound != null) BattleSounds.play(sound);
      if (e.t == 'hp') lastEffect = null;
      switch (e.t) {
        case 'attack':
          // Cada golpe com a sua animação (move_anims.json + move_anim.dart), nas cores do tipo:
          // os de status também (Swords Dance sobe, Toxic no alvo, Rain Dance no campo...).
          final entry = _anims?[e.slug];
          final rules = _b.active(e.side).moves.where((m) => m.slug == e.slug).firstOrNull?.rules;
          final self = rules?['t'] == 'self' || rules?['h'] != null;
          final kind = entry is List
              ? '${entry[0]}'
              : e.category == 'status'
                  ? (self ? 'boost' : 'status')
                  : moveAnim(e.slug, e.type, e.category);
          final variant = entry is List ? (entry[2] as num).toInt() : 0;
          final plan = fxPlan(kind, e.type, e.side, _center[e.side], _center[1 - e.side], entry is List ? '${entry[1]}' : null, variant);
          if (!selfKinds.contains(kind)) _sprites[e.side].currentState?.lunge(dash: contactKinds.contains(kind));
          setState(() => _fx = (plan, getColorForType(e.type), ++_fxKey));
          if (plan.shake) _shake.forward(from: 0);
          if (plan.flash) _wait(250).then((_) => mounted ? setState(() => _flash++) : null);
          await _wait(plan.duration + 80);
          if (!mounted) return;
          setState(() => _fx = null);
        case 'status':
          setState(() => _status[e.side][_active[e.side]] = e.type);
        case 'heal':
          setState(() {
            _hp[e.side][e.index] = e.value;
            if (e.index == _active[e.side]) _fainted[e.side] = false;
          });
          await _wait(500);
        case 'miss':
          _sprites[1 - e.side].currentState?.dodge();
          await _wait(300);
        case 'text':
          if (e.key == 'crit') setState(() => _flash++);
          // Estágio do atributo na caixa de HP, junto com o texto (o fim do turno confere com o motor).
          final by = _boostText[e.key];
          final who = e.args.isNotEmpty && e.args.first is (int, String) ? (e.args.first as (int, String)).$1 : -1;
          if (by != null && e.args.length > 1 && (who == 0 || who == 1)) {
            final stat = '${e.args[1]}';
            setState(() => _boosts[who][stat] = ((_boosts[who][stat] ?? 0) + by).clamp(-6, 6));
          }
          if (e.key == 'statsReset') {
            setState(() {
              for (final b in _boosts) {
                b.clear();
              }
            });
          }
          final line = _format(e);
          if (line.isEmpty) continue;
          setState(() => _text = line);
          _skip = Completer<void>();
          await Future.any([_wait(_step.inMilliseconds), _skip!.future]);
          _skip = null;
        case 'hp':
          _sprites[e.side].currentState?.hurt();
          setState(() => _hp[e.side][_active[e.side]] = e.value);
          // Espera piscar e a barra de HP descer.
          await _wait(550);
        case 'faint':
          setState(() => _fainted[e.side] = true);
        case 'switch':
          // Volta para a Poké Ball (se não desmaiou) e o outro sai dela.
          if (!_fainted[e.side] && _active[e.side] != e.value) {
            BattleSounds.play('recall');
            setState(() => _poke[e.side] = 'recall');
            await _wait(380);
            if (!mounted) return;
          }
          setState(() {
            _poke[e.side] = 'hidden';
            _active[e.side] = e.value;
            _fainted[e.side] = false;
            _form[e.side] = null;
            _dmax[e.side] = false;
            _tera[e.side] = '';
            _boosts[e.side].clear();
          });
          await _release(e.side);
        case 'mega':
          setState(() {
            _flash++;
            _form[e.side] = e.value;
          });
          await _wait(500);
        case 'form':
          // Forma que muda na batalha (Aegislash, Mimikyu, Darmanitan, Palafin...).
          if (!_dmax[e.side]) setState(() => _form[e.side] = e.value);
          await _wait(400);
        case 'dmax':
          setState(() {
            _form[e.side] = e.value;
            _dmax[e.side] = e.index == 1;
          });
          await _wait(700);
        case 'tera':
          setState(() {
            _flash++;
            _tera[e.side] = e.type.isEmpty ? 'normal' : e.type;
          });
          await _wait(700);
        case 'weather':
          // O cenário muda com o clima (céu, chão, chuva caindo...).
          setState(() => _weather = e.type);
          await _wait(600);
      }
    }
    } catch (error, stack) {
      debugPrint('Battle presentation failed: $error\n$stack');
    } finally {
      if (mounted) setState(() {
        // The simulator already resolved the turn. Always restore its final
        // state, even if one visual event could not be displayed.
        for (final side in [0, 1]) {
          _active[side] = _b.activeIndex[side];
          for (final (index, mon) in _b.teams[side].indexed) {
            _hp[side][index] = mon.hp;
            _status[side][index] = mon.status;
          }
          _fainted[side] = _b.active(side).hp <= 0;
          _form[side] = _b.active(side).dmax > 0 ? _b.active(side).gmax ?? _b.active(side).id : _b.active(side).id;
          _dmax[side] = _b.active(side).dmax > 0;
          _boosts[side] = Map.of(_b.active(side).boosts);
          _tera[side] = _teraOf(_b.active(side));
        }
        _weather = _b.weather;
        _fx = null;
        _skip = null;
        _busy = false;
        _menu = _b.needSwitch ? 'party' : 'main';
        if (_b.needSwitch) _text = tr('Escolha o próximo Pokémon.');
      });
      // Acabou: vai para o histórico (só as batalhas contra o computador).
      if (mounted && _b.winner != null && !_finished) {
        _finished = true;
        // Fim: a música para; vencendo, a fanfarra.
        BattleSounds.stopMusic(this);
        if (_b.winner == 0) BattleSounds.play('victory', volume: 0.7);
        if (widget.online == null) widget.onFinish?.call(_coach?.id);
      }
      _autoLocked();
    }
  }

  /// Golpe em sequência: não pergunta nada, só continua o golpe.
  Future<void> _autoLocked() async {
    if (!mounted || widget.online != null || _b.winner != null || _b.needSwitch) return;
    final locked = _b.lockedMove();
    if (locked == null) return;
    setState(() {
      _busy = true;
      _text = tr('{0} continua com {1}!').replaceAll('{0}', _b.active(0).name).replaceAll('{1}', locked.name);
    });
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    _busy = false;
    _fight(locked.index < 0 ? 0 : locked.index);
  }

  /// Tocar no Pokémon: o seu mostra tudo; o do adversário, só o que já apareceu na batalha.
  void _inspect(int side) {
    final d = _b.monDetails(side);
    final mon = _b.active(side);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final c = SiteColors.of(context);
        const stat = {'hp': 'HP', 'atk': 'Atk', 'def': 'Def', 'spa': 'SpA', 'spd': 'SpD', 'spe': 'Spe'};
        Widget line(String label, String? value) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$label: ', style: TextStyle(color: c.text, fontWeight: FontWeight.w800)),
                Expanded(child: m.Text(value ?? '?', style: TextStyle(color: value == null ? c.muted : c.text))),
              ]),
            );
        return SafeArea(
          child: Padding(
            key: const ValueKey('mon-details'),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              m.Text(mon.name, style: TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              if (d != null) ...[
                Wrap(spacing: 4, children: [for (final t in d.types) TypeBadge(t)]),
                const SizedBox(height: 8),
                line(tr('Habilidade'), d.ability),
                line(tr('Item'), d.item ?? (side == 0 ? '—' : null)),
                line(side == 0 ? tr('Golpes') : tr('Golpes vistos'), d.moves.isEmpty ? null : d.moves.join(', ')),
                if (d.stats != null)
                  m.Text([for (final e in stat.entries) if (d.stats![e.key] != null) '${e.value} ${d.stats![e.key]}'].join(' · '), style: TextStyle(color: c.text)),
                if (side == 1) Text('Do adversário aparece só o que ele já mostrou na batalha.', style: TextStyle(color: c.muted, fontSize: 12)),
              ],
            ]),
          ),
        );
      },
    );
  }

  List<(String, String)> get _gimmickOptions {
    final mon = _b.active(0);
    return [
      ('mega', 'Mega Evolução'),
      ('tera', 'Tera'),
      ('dmax', mon.gmax != null ? 'Gigantamax' : 'Dynamax'),
      ('z', 'Movimento Z'),
    ].where((option) => option.$1 == mon.gimmick).where((option) => option.$1 == 'z'
        ? mon.moves.indexed.any((move) => _b.canGimmick(0, 'z', move.$1))
        : _b.canGimmick(0, option.$1)).toList();
  }

  String get _selectedGimmick => _gimmickMon == _b.active(0).id &&
      _gimmickOptions.any((option) => option.$1 == _gimmickPick)
      ? _gimmickPick! : 'none';

  void _fight(int i) {
    if (_busy || widget.online?.locked == true || _b.needSwitch || _b.winner != null) return;
    final before = [_b.active(0).id, _b.active(1).id];
    final gimmick = _selectedGimmick;
    setState(() { _gimmickPick = null; _gimmickMon = null; });
    if (widget.online != null) {
      widget.online!.onAction({'kind': 'move', 'index': i, 'gimmick': gimmick});
      return;
    }
    _act(() => _b.playTurn(widget.hit, move: i, gimmick: gimmick), before);
  }
  void _choose(int i) {
    if (_busy || widget.online?.locked == true || _b.winner != null) return;
    setState(() { _gimmickPick = null; _gimmickMon = null; });
    if (widget.online != null) { widget.online!.onAction({'kind': 'switch', 'index': i}); return; }
    final item = _item;
    if (item != null) {
      _item = null;
      _act(() => _b.playTurn(widget.hit, item: item, target: i));
      return;
    }
    _act(() => _b.needSwitch ? _b.replace(i) : _b.playTurn(widget.hit, switchTo: i));
  }

  Future<void> _act(List<BattleEvent> Function() action, [List<int>? before]) async {
    setState(() => _busy = true);
    try {
      await _play(action(), before);
    } catch (error, stack) {
      debugPrint('Battle action failed: $error\n$stack');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _fx = null;
        _menu = _b.needSwitch ? 'party' : 'main';
        _text = tr('Não foi possível executar esta ação. Escolha novamente.');
      });
    }
  }

  Future<void> _run() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text('Fugir da batalha? Conta como derrota.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Fugir')),
        ],
      ),
    );
    if (ok == true) {
      if (widget.online != null) { widget.online!.onClose(); }
      else { _play(_b.forfeit()); }
    }
  }

  Widget _battleBody(BuildContext context) {
    if (_b.mode != 'singles') return _MultiBattleView(battle: _b, online: widget.online, onExit: widget.onExit, onAgain: widget.onAgain);
    final me = _b.teams[0][_active[0]];
    final foe = _b.teams[1][_active[1]];
    final current = _b.active(0);
    final waiting = !_busy && !(widget.online?.locked ?? false) && _b.winner == null;
    // Efetividade (como nos jogos): nos golpes, nas fraquezas do inimigo e na troca.
    final rival = _b.active(1);
    final foeWeak = TurnBattle.weaknesses(rival.types, allTypes, widget.typeEff);
    // A mecânica do set (montador) ativa sozinha no primeiro ataque, como nos
    // jogos: o menu já mostra os Z-Moves / Max Moves que vão sair.
    final selected = _selectedGimmick;
    final maxed = current.dmax > 0 || (selected == 'dmax' && _b.canGimmick(0, 'dmax'));
    const border = Color(0xFF1E293B);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Campo
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: AspectRatio(
            aspectRatio: 16 / 11,
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border.all(color: border, width: 4), color: const Color(0xFF9FDCFF)),
              child: LayoutBuilder(builder: (context, box) {
                final w = box.maxWidth, h = box.maxHeight;
                // Terremoto: o campo treme.
                return AnimatedBuilder(
                  animation: _shake,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(_shake.isAnimating ? sin(_shake.value * pi * 10) * w * 0.015 : 0, 0),
                    child: child,
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 800),
                          child: CustomPaint(key: ValueKey(_weather), painter: _FieldPainter(_weather), size: Size.infinite),
                        ),
                      ),
                      Positioned(
                          left: w * 0.03,
                          top: h * 0.05,
                          width: w * 0.48,
                          child: AnimatedOpacity(
                              opacity: _introOn && _poke[1] == 'hidden' ? 0 : 1,
                              duration: const Duration(milliseconds: 200),
                              child: GestureDetector(
                                  key: const ValueKey('inspect-foe'),
                                  onTap: () => _inspect(1),
                                  child: _InfoBox(mon: foe, hp: _hp[1][_active[1]], status: _status[1][_active[1]], dmax: _dmax[1], boosts: _boosts[1])))),
                      Positioned(
                          // O inimigo fica mais longe: menor e com os pés na
                          // frente do meio da plataforma (pisando nela, como o seu).
                          right: w * 0.12,
                          bottom: h * 0.53,
                          width: w * 0.26,
                          height: w * 0.26,
                          child: _PokeOut(
                              state: _poke[1],
                              child: _Sprite(key: _sprites[1], mon: foe, id: _form[1] ?? foe.id, dmax: _dmax[1], tera: _tera[1], fainted: _fainted[1]))),
                      if (_ball[1] != null)
                        Positioned(right: w * 0.12, bottom: h * 0.53, width: w * 0.26, height: w * 0.26, child: _Ball(side: 1, phase: _ball[1]!)),
                      if (_introOn && _coach != null)
                        Positioned(
                          right: w * 0.08,
                          bottom: h * 0.53,
                          width: w * 0.34,
                          height: w * 0.34,
                          child: AnimatedSlide(
                            key: const ValueKey('foe-trainer'),
                            offset: _foeGone ? const Offset(1.6, 0) : Offset.zero,
                            duration: const Duration(milliseconds: 520),
                            curve: Curves.easeIn,
                            child: TrainerSprite(_coach, box: w * 0.34),
                          ),
                        ),
                      Positioned(
                          left: w * 0.06,
                          bottom: h * 0.05,
                          width: w * 0.36,
                          height: w * 0.36,
                          child: _PokeOut(
                              state: _poke[0],
                              child: _Sprite(key: _sprites[0], mon: me, id: _form[0] ?? me.id, dmax: _dmax[0], tera: _tera[0], back: true, fainted: _fainted[0]))),
                      if (_ball[0] != null)
                        Positioned(left: w * 0.06, bottom: h * 0.05, width: w * 0.36, height: w * 0.36, child: _Ball(side: 0, phase: _ball[0]!)),
                      if (_introOn && _myTrainer != null)
                        Positioned(
                          left: w * 0.02,
                          bottom: 0,
                          child: AnimatedSlide(
                            key: const ValueKey('my-trainer'),
                            offset: _meGone ? const Offset(-1.3, 0) : Offset.zero,
                            duration: const Duration(milliseconds: 520),
                            curve: Curves.easeIn,
                            child: TrainerBack(_myTrainer, frame: _backFrame, height: h * 0.62),
                          ),
                        ),
                      Positioned(
                          right: w * 0.03,
                          bottom: h * 0.06,
                          width: w * 0.5,
                          child: AnimatedOpacity(
                              opacity: _introOn && _poke[0] == 'hidden' ? 0 : 1,
                              duration: const Duration(milliseconds: 200),
                              child: GestureDetector(
                                  key: const ValueKey('inspect-me'),
                                  onTap: () => _inspect(0),
                                  child: _InfoBox(mon: me, hp: _hp[0][_active[0]], status: _status[0][_active[0]], dmax: _dmax[0], boosts: _boosts[0], mine: true)))),
                      Positioned.fill(child: _WeatherFx(_weather)),
                      if (_fx != null) _MoveFx(key: ValueKey(('fx', _fx!.$3)), plan: _fx!.$1, color: _fx!.$2, w: w, h: h),
                      if (_flash > 0) _Flash(key: ValueKey(('flash', _flash))),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
        _FieldBar(conditions: _b.fieldConditions()),
        // Texto e menus
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: border, borderRadius: BorderRadius.vertical(bottom: Radius.circular(16))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: () { if (_skip != null && !_skip!.isCompleted) _skip!.complete(); },
                child: Container(
                  constraints: const BoxConstraints(minHeight: 72),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFD97706), width: 4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  // Já traduzido (nomes e golpes não mudam).
                  child: m.Text(!_busy && widget.online != null ? tr(widget.online!.message) : _text, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              if (waiting && (widget.online?.waitForSwitch ?? false))
                FilledButton(onPressed: () => widget.online!.onAction({'kind': 'wait', 'index': 0}), child: const Text('Aguardar troca do amigo')),
              if (waiting && !(widget.online?.waitForSwitch ?? false) && _menu == 'main' && !_b.needSwitch) ...[
                const SizedBox(height: 8),
                Row(children: [
                  _MenuButton('LUTAR', () {
                    if (TurnBattle.usableMoves(current).isEmpty) {
                      _fight(-1);
                    } else {
                      setState(() => _menu = 'fight');
                    }
                  }),
                  const SizedBox(width: 6),
                  _MenuButton('BOLSA', widget.online == null ? () => setState(() => _menu = 'bag') : null),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  _MenuButton(
                      'POKÉMON',
                      () => setState(() {
                            _item = null;
                            _menu = 'party';
                          })),
                  const SizedBox(width: 6),
                  _MenuButton('FUGIR', _run),
                ]),
              ],
              if (waiting && _menu == 'fight') ...[
                const SizedBox(height: 8),
                _Weak(rival, foeWeak, dark: true),
                for (final option in _gimmickOptions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Material(
                      borderRadius: BorderRadius.circular(8),
                      clipBehavior: Clip.antiAlias,
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: selected == option.$1 ? const LinearGradient(colors: [Color(0xFFD946EF), Color(0xFFFBBF24), Color(0xFF0EA5E9)]) : null,
                          color: selected == option.$1 ? null : const Color(0xFFF1F5F9),
                          border: Border.all(color: selected == option.$1 ? const Color(0xFFC026D3) : const Color(0xFFCBD5E1), width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: InkWell(
                          key: ValueKey(option.$1),
                          onTap: () => setState(() {
                            _gimmickPick = selected == option.$1 ? null : option.$1;
                            _gimmickMon = current.id;
                          }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              '${tr(option.$2).toUpperCase()}${option.$1 == 'tera' ? ' ${current.teraType}' : ''}${selected == option.$1 ? ' ✓' : ''}',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: selected == option.$1 ? Colors.white : const Color(0xFF64748B)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  // Altura pelas duas linhas de texto (cresce com o texto maior).
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    mainAxisExtent: 12 + MediaQuery.textScalerOf(context).scale(18) + MediaQuery.textScalerOf(context).scale(19),
                  ),
                  children: [
                    for (final (i, mv) in current.moves.indexed)
                      Material(
                        color: getColorForType(mv.type).withAlpha(mv.pp > 0 ? 255 : 100),
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          key: ValueKey('battle-single-move-$i'),
                          borderRadius: BorderRadius.circular(10),
                          onTap: mv.pp > 0 && !mv.disabled ? () => _fight(i) : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Com Z-Move / Dinamax: o nome do golpe especial (o poder dele no lugar do PP).
                                m.Text(
                                    mv.category == 'status'
                                        ? mv.name
                                        : selected == 'z' && _b.canGimmick(0, 'z', i)
                                            ? TurnBattle.zMoves[mv.type]!
                                            : maxed
                                                ? TurnBattle.maxMoves[mv.type]!
                                                : mv.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                                Row(children: [
                                  m.Text(
                                      mv.category != 'status' && ((selected == 'z' && _b.canGimmick(0, 'z', i)) || maxed)
                                          ? '${tr('Poder')} ${selected == 'z' && !maxed ? TurnBattle.zPower(mv.power) : TurnBattle.maxPower(mv.power, mv.type)}'
                                          : 'PP ${mv.pp}/${mv.maxPp}',
                                      style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                  // Dano estimado (em % da vida do adversário).
                                  if (!maxed && !(selected == 'z' && _b.canGimmick(0, 'z', i)))
                                    if (TurnBattle.damageRange(widget.hit, current, rival, mv, _weather) case final r?)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 6),
                                        child: m.Text(r.low == r.high ? '${r.low}%' : '${r.low}–${r.high}%',
                                            key: ValueKey('damage-range-$i'), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                                      ),
                                  const Spacer(),
                                  // A efetividade diminui se não couber (tela estreita).
                                  Flexible(
                                    flex: 4,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: _EffectTag(TurnBattle.moveEffect(widget.hit, current, rival, mv)),
                                    ),
                                  ),
                                ]),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(children: [_MenuButton('Voltar', () => setState(() => _menu = 'main'))]),
              ],
            ],
          ),
        ),
        if (waiting && _menu == 'bag') ...[
          const SizedBox(height: 12),
          SiteCard(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  const Expanded(child: Text('Bolsa', style: TextStyle(fontWeight: FontWeight.bold))),
                  TextButton(onPressed: () => setState(() => _menu = 'main'), child: const Text('Voltar')),
                ]),
                for (final it in battleItems)
                  if (it.count > 0 || (_b.bags[0][it.slug] ?? 0) > 0)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    enabled: [for (var i = 0; i < _b.teams[0].length; i++) i].any((i) => _b.canUseItem(0, it.slug, i)),
                    onTap: () => setState(() {
                      _item = it.slug;
                      _menu = 'party';
                    }),
                    leading: Image.asset('assets/database/sprites/items/${it.slug}.png',
                        width: 40, height: 40, filterQuality: FilterQuality.none, errorBuilder: (_, __, ___) => const SizedBox(width: 40)),
                    // Nome do item como no jogo (não traduz).
                    title: m.Text(it.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(it.revive
                        ? tr('Revive com metade do HP')
                        : it.heal >= 9999
                            ? tr('Recupera todo o HP')
                            : _b.healPct
                                ? tr('Recupera {0}% do HP').replaceAll('{0}', '${((const {'potion': 0.25, 'super-potion': 0.5, 'hyper-potion': 0.75}[it.slug] ?? 0) * 100).round()}')
                                : tr('Recupera {0} de HP').replaceAll('{0}', '${it.heal}')),
                    trailing: m.Text('×${_b.bags[0][it.slug] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  ),
              ],
            ),
          ),
        ],
        if (waiting && _menu == 'party') ...[
          const SizedBox(height: 12),
          SiteCard(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                        _b.needSwitch
                            ? 'Escolha o próximo Pokémon'
                            : _item != null
                                ? 'Usar em qual Pokémon?'
                                : 'Trocar de Pokémon',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  if (!_b.needSwitch)
                    TextButton(
                        onPressed: () => setState(() {
                              _menu = _item != null ? 'bag' : 'main';
                              _item = null;
                            }),
                        child: const Text('Voltar')),
                ]),
                if (_item == null) _Weak(rival, foeWeak),
                for (final (i, mon) in _b.teams[0].indexed)
                  ListTile(
                    key: ValueKey('battle-single-switch-$i'),
                    contentPadding: EdgeInsets.zero,
                    enabled: _item != null ? _b.canUseItem(0, _item!, i) : _b.canSwitch(0, i),
                    onTap: () => _choose(i),
                    leading: SizedBox.square(dimension: 44, child: PokemonSprite(mon.id, shiny: mon.shiny, fill: 0.95)),
                    title: Row(children: [
                      Flexible(child: m.Text(mon.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold))),
                      if (mon.status.isNotEmpty && mon.hp > 0) ...[const SizedBox(width: 6), _StatusBadge(mon.status)],
                    ]),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HpBar(hp: mon.hp, max: mon.maxHp),
                        mon.hp > 0
                            ? m.Text('${mon.hp}/${mon.maxHp}', style: const TextStyle(fontSize: 12))
                            : const Text('Desmaiado', style: TextStyle(fontSize: 12)),
                        if (_item == null && mon.hp > 0) _matchup(TurnBattle.switchMatchup(widget.hit, mon, rival, widget.typeEff)),
                      ],
                    ),
                    trailing: i == _b.activeIndex[0] ? const Icon(Icons.check_circle, color: Color(0xFF0EA5E9)) : null,
                  ),
              ],
            ),
          ),
        ],
        if (!_busy && _b.winner != null && widget.endNote.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            key: const ValueKey('end-note'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: SiteColors.of(context).surface, borderRadius: BorderRadius.circular(14)),
            child: m.Text(widget.endNote, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
        if (!_busy && _b.winner != null && widget.online == null && widget.next != null) ...[
          const SizedBox(height: 14),
          PillButton(
            key: const ValueKey('next-challenger'),
            label: widget.next!.label,
            expand: true,
            gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFDC2626)]),
            onPressed: widget.next!.onTap,
          ),
        ],
        if (!_busy && _b.winner != null && widget.online == null) ...[
          if (widget.canAgain) ...[
          const SizedBox(height: 14),
          PillButton(
            label: tr('Batalhar de novo'),
            expand: true,
            gradient: const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFF9333EA)]),
            onPressed: widget.onAgain,
          ),
          ],
          const SizedBox(height: 8),
          OutlinedButton(onPressed: widget.onExit, child: Text(widget.foeName.isEmpty ? 'Trocar os times' : 'Sair')),
        ],
      ],
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _MenuButton(this.label, this.onTap);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Opacity(opacity: onTap == null ? 0.4 : 1, child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w900))),
            ),
          ),
        ),
      );
}

/// Campo clássico compartilhado pela individual, dupla e tripla.
class _FieldPainter extends CustomPainter {
  const _FieldPainter(this.weather);
  final String weather;
  @override
  void paint(Canvas canvas, Size size) {
    final colors = switch(weather) {
      'rain' => [const Color(0xFFA1BAC4),const Color(0xFFD6E3D6)],
      'sun' => [const Color(0xFFFFE4A1),const Color(0xFFE8F6B6)],
      'sand' => [const Color(0xFFD1BD96),const Color(0xFFEEE2AD)],
      'hail' || 'snow' => [const Color(0xFFBACBD8),const Color(0xFFEEF5E3)],
      _ => [const Color(0xFFB9E6BD),const Color(0xFFEDF9C8)],
    };
    final rect=Offset.zero & size;
    canvas.drawRect(rect,Paint()..shader=LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:colors).createShader(rect));
    final sx=size.width/160,sy=size.height/100;
    for(var i=0;i<50;i++) canvas.drawRect(Rect.fromLTWH(0,i*2*sy,size.width,0.4*sy),Paint()..color=const Color(0x40FFFFFF));
    void base(double cx,double cy,double rx,double ry,Color color) => canvas.drawOval(Rect.fromCenter(center:Offset(cx*sx,cy*sy),width:rx*2*sx,height:ry*2*sy),Paint()..color=color);
    base(120,45,32,8,const Color(0xFF7EBA62));base(120,44,29,6,const Color(0xFFA9D57B));
    base(38,91,42,12,const Color(0xFF7EBA62));base(38,89,39,9,const Color(0xFFA9D57B));
  }
  @override
  bool shouldRepaint(_FieldPainter old) => old.weather != weather;
}

/// O clima caindo por cima do campo (chuva, areia, granizo, neve) ou o brilho
/// do sol. Igual ao site (index.css, .weather-*).
class _WeatherFx extends StatefulWidget {
  const _WeatherFx(this.weather);
  final String weather;
  @override
  State<_WeatherFx> createState() => _WeatherFxState();
}

class _WeatherFxState extends State<_WeatherFx> with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(vsync: this, duration: const Duration(seconds: 6));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_WeatherFx old) {
    super.didUpdateWidget(old);
    _sync();
  }

  /// Só anima com clima (e sem "reduzir animações" no celular).
  void _sync() {
    if (widget.weather.isNotEmpty) {
      if (!_clock.isAnimating) _clock.repeat();
    } else {
      _clock.stop();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: widget.weather.isEmpty ? 0 : 1,
        duration: const Duration(milliseconds: 700),
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _clock,
            builder: (context, _) => CustomPaint(
              painter: _WeatherPainter(widget.weather, still ? 0 : _clock.value * 6),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    );
  }
}

/// Desenha as partículas do clima no tempo [t] (segundos, volta a cada 6).
class _WeatherPainter extends CustomPainter {
  const _WeatherPainter(this.weather, this.t);
  final String weather;
  final double t;

  /// Posição fixa (0 a 1) de cada partícula, sem sorteio a cada quadro.
  static double _hash(int i, int k) {
    final v = sin(i * 12.9898 + k * 78.233) * 43758.5453;
    return v - v.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (weather == 'sun') {
      // Brilho do sol pulsando no canto.
      final glow = 0.8 + 0.2 * cos(t * pi * 2 / 3);
      canvas.drawRect(
          Offset.zero & size,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(0.68, -0.88),
              radius: 0.9,
              colors: [const Color(0xFFFFF4C8).withValues(alpha: 0.75 * glow), const Color(0xFFFFD678).withValues(alpha: 0.25 * glow), Colors.transparent],
              stops: const [0, 0.3, 0.6],
            ).createShader(Offset.zero & size));
      return;
    }
    if (weather == 'sand') canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0x40C9A063));
    // (quantas, velocidade em alturas por segundo, deriva x por y, cor, tamanho)
    final (count, speed, drift, color, len) = switch (weather) {
      'rain' => (70, 3.2, -0.25, const Color(0xBFDBE9FF), 0.06),
      'sand' => (60, 0.6, 0.0, const Color(0xCCE7C58A), 0.012),
      'hail' => (40, 1.6, -0.1, const Color(0xFFF4FBFF), 0.012),
      'snow' => (50, 0.35, 0.25, const Color(0xE6FFFFFF), 0.012),
      _ => (0, 0.0, 0.0, Colors.transparent, 0.0),
    };
    final paint = Paint()
      ..color = color
      ..strokeWidth = weather == 'rain' ? 1.3 : 1
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < count; i++) {
      final sp = speed * (0.75 + 0.5 * _hash(i, 3));
      final y = ((_hash(i, 1) + t * sp) % 1.0) * h;
      // A areia voa de lado; o resto cai inclinado (deriva).
      final dx = weather == 'sand' ? -t * 0.9 : y / h * drift;
      final x = (_hash(i, 2) + dx) % 1.0 * w;
      if (weather == 'rain') {
        canvas.drawLine(Offset(x, y), Offset(x + drift * len * h, y + len * h), paint);
      } else if (weather == 'snow') {
        canvas.drawCircle(Offset(x + sin(t * 2 + i) * 4, y), (1.4 + _hash(i, 4)) * 1.2, paint);
      } else {
        canvas.drawCircle(Offset(x, y), len * h * (0.8 + _hash(i, 4)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_WeatherPainter old) => old.t != t || old.weather != weather;
}

class _Sprite extends StatefulWidget {
  final BattleMon mon;

  /// A forma na tela (Mega / Gigantamax).
  final int id;
  final bool back, fainted, dmax;

  /// Tipo Tera ('' se não terastalizou).
  final String tera;
  const _Sprite({super.key, required this.mon, required this.id, this.back = false, this.fainted = false, this.dmax = false, this.tera = ''});

  @override
  State<_Sprite> createState() => _SpriteState();
}

class _SpriteState extends State<_Sprite> with TickerProviderStateMixin {
  late final _lunge = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  late final _hurt = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late final _dodge = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  /// Terastal: o reflexo de cristal passando pelo corpo e o brilho pulsando.
  late final _shine = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void initState() {
    super.initState();
    if (widget.tera.isNotEmpty) _shine.repeat();
  }

  @override
  void didUpdateWidget(covariant _Sprite old) {
    super.didUpdateWidget(old);
    if (widget.tera.isNotEmpty && !_shine.isAnimating) _shine.repeat();
    if (widget.tera.isEmpty && _shine.isAnimating) _shine.stop();
  }

  /// Quem ataca avança na direção do outro ([dash]: vai até ele, golpe corpo a corpo).
  void lunge({bool dash = false}) {
    _dash = dash;
    _lunge.forward(from: 0);
  }

  bool _dash = false;

  /// Levou o golpe: pisca e treme.
  void hurt() => _hurt.forward(from: 0);

  /// O golpe errou: pula para o lado.
  void dodge() => _dodge.forward(from: 0);

  @override
  void dispose() {
    _lunge.dispose();
    _hurt.dispose();
    _dodge.dispose();
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dir = widget.back ? 1.0 : -1.0;
    return AnimatedSlide(
      duration: const Duration(milliseconds: 500),
      offset: widget.fainted ? const Offset(0, 0.4) : Offset.zero,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 500),
        opacity: widget.fainted ? 0 : 1,
        child: AnimatedBuilder(
          animation: Listenable.merge([_lunge, _hurt, _dodge]),
          builder: (context, child) {
            final l = _lunge.value, h = _hurt.value, d = _dodge.value;
            final push = (l < 0.4 ? l / 0.4 : (1 - l) / 0.6) * (_dash ? 6.8 : 1);
            final shaking = h > 0 && h < 1;
            return FractionalTranslation(
              translation: Offset(
                dir * 0.14 * push + (shaking ? sin(h * pi * 6) * 0.05 : 0) + sin(d * pi) * 0.22,
                -dir * (_dash ? 0.11 : 0.10) * push,
              ),
              child: Opacity(opacity: shaking && (h * 5).floor().isEven ? 0.15 : 1, child: child),
            );
          },
          // Trocou de Pokémon (ou megaevoluiu): começa do zero. Do nosso banco,
          // de frente ou de costas, todos do mesmo tamanho (como na Pokédex).
          child: KeyedSubtree(
            key: ValueKey((widget.id, widget.mon.shiny)),
            // Dinamax: gigante e com um brilho vermelho em volta do contorno
            // dele (não da caixa), como o drop-shadow do site.
            child: AnimatedSlide(
              // O do adversário (lá no alto do campo) cresce menos e desce um pouco, para não passar do topo.
              offset: Offset(0, widget.dmax && !widget.back ? 0.06 : 0),
              duration: const Duration(milliseconds: 700),
              child: AnimatedScale(
              scale: widget.dmax ? (widget.back ? 1.35 : 1.15) : 1,
              alignment: Alignment.bottomCenter,
              duration: const Duration(milliseconds: 700),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.dmax)
                    ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.mode(Color(0xFFE11D48), BlendMode.srcIn),
                        child: PokemonSprite(widget.id, shiny: widget.mon.shiny, back: widget.back, fill: 0.95, alignBottom: true, battle: true),
                      ),
                    ),
                  if (widget.tera.isNotEmpty) ..._teraBack(),
                  PokemonSprite(widget.id,
                      shiny: widget.mon.shiny,
                      back: widget.back,
                      fill: 0.95,
                      alignBottom: true,
                      battle: true,
                      // Terastal: a coroa de cristal na cabeça, acompanhando a animação.
                      crown: widget.tera.isEmpty ? null : CustomPaint(painter: _TeraCrownPainter(getColorForType(widget.tera))),
                      // e o corpo cristalizado (facetas e reflexo).
                      crystal: widget.tera.isEmpty ? null : getColorForType(widget.tera)),
                ],
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tipo Tera de quem terastalizou ('' se não).
String _teraOf(BattleMon mon) => mon.terastal ? (mon.teraType.isEmpty ? 'normal' : mon.teraType) : '';

extension on _SpriteState {
  PokemonSprite _plain() => PokemonSprite(widget.id, shiny: widget.mon.shiny, back: widget.back, fill: 0.95, alignBottom: true, battle: true);

  /// Atrás do Pokémon: brilho na cor do tipo em volta do contorno, pulsando.
  List<Widget> _teraBack() {
    final color = getColorForType(widget.tera);
    return [
      AnimatedBuilder(
        animation: _shine,
        builder: (context, child) => Opacity(opacity: 0.55 + 0.45 * sin(_shine.value * pi), child: child),
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: ColorFiltered(colorFilter: ColorFilter.mode(color, BlendMode.srcIn), child: _plain()),
        ),
      ),
    ];
  }
}

/// O Pokémon entrando ('release': sai da Poké Ball num clarão), voltando
/// ('recall': encolhe numa luz vermelha) ou guardado ('hidden'). Igual ao site.
class _PokeOut extends StatelessWidget {
  final String state;
  final Widget child;
  const _PokeOut({required this.state, required this.child});

  @override
  Widget build(BuildContext context) {
    if (state == 'hidden') return Opacity(opacity: 0, child: child);
    if (state != 'release' && state != 'recall') return child;
    final release = state == 'release';
    return TweenAnimationBuilder<double>(
      key: ValueKey(state),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: release ? 420 : 380),
      builder: (context, t, child) {
        final scale = release ? (t < 0.6 ? t / 0.6 * 1.08 : 1.08 - (t - 0.6) / 0.4 * 0.08) : 1 - t;
        final tint = release ? Colors.white.withValues(alpha: (1 - t).clamp(0, 1)) : const Color(0xFFE53935).withValues(alpha: (t * 1.6).clamp(0, 0.8));
        return Transform.scale(
          scale: scale,
          alignment: const Alignment(0, 0.7),
          child: ColorFiltered(colorFilter: ColorFilter.mode(tint, BlendMode.srcATop), child: child),
        );
      },
      child: child,
    );
  }
}

/// A Poké Ball: lançada em arco até a plataforma ('throw') ou abrindo nela ('open').
class _Ball extends StatelessWidget {
  final int side;
  final String phase;
  const _Ball({required this.side, required this.phase});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final size = box.maxWidth * 0.3;
      final ground = Offset(box.maxWidth / 2 - size / 2, box.maxHeight * 0.92 - size);
      return TweenAnimationBuilder<double>(
        key: ValueKey(phase),
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: phase == 'throw' ? 520 : 260),
        curve: phase == 'throw' ? const Cubic(.3, .7, .5, 1) : Curves.easeOut,
        builder: (context, t, _) {
          if (phase == 'open') {
            return Stack(children: [
              Positioned(
                left: ground.dx,
                top: ground.dy - size * 0.1 * t,
                width: size,
                height: size,
                child: Opacity(
                  opacity: t < 0.6 ? 1 : (1 - (t - 0.6) / 0.4).clamp(0, 1),
                  child: Transform.scale(scale: 1 + 0.6 * t, child: CustomPaint(painter: _BallPainter(glow: t))),
                ),
              ),
            ]);
          }
          // Do treinador até a plataforma, num arco (a sua vem da esquerda, a dele de trás).
          final start = side == 0 ? Offset(ground.dx - box.maxWidth * 0.9, ground.dy - box.maxHeight * 0.2) : Offset(ground.dx + box.maxWidth * 0.5, ground.dy - box.maxHeight * 0.6);
          final pos = Offset.lerp(start, ground, t)! - Offset(0, sin(t * pi) * box.maxHeight * (side == 0 ? 0.9 : 0.6));
          return Stack(children: [
            Positioned(
              left: pos.dx,
              top: pos.dy,
              width: size,
              height: size,
              child: Transform.rotate(angle: (side == 0 ? -1 : 1) * t * 4 * pi, child: const CustomPaint(painter: _BallPainter())),
            ),
          ]);
        },
      );
    });
  }
}

class _BallPainter extends CustomPainter {
  final double glow;
  const _BallPainter({this.glow = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = size.center(Offset.zero);
    final edge = Paint()
      ..color = const Color(0xFF1F2937)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.16;
    final rect = Rect.fromCircle(center: c, radius: r * 0.9);
    canvas
      ..drawCircle(c, r * 0.9, Paint()..color = Colors.white)
      ..drawArc(rect, pi, pi, true, Paint()..color = const Color(0xFFE3350D))
      ..drawCircle(c, r * 0.9, edge)
      ..drawLine(Offset(c.dx - r * 0.9, c.dy), Offset(c.dx + r * 0.9, c.dy), edge)
      ..drawCircle(c, r * 0.28, Paint()..color = Colors.white)
      ..drawCircle(c, r * 0.28, edge..strokeWidth = r * 0.12);
    // Abrindo: a luz branca de dentro.
    if (glow > 0) canvas.drawCircle(c, r, Paint()..color = Colors.white.withValues(alpha: (glow * 1.4).clamp(0, 0.9)));
  }

  @override
  bool shouldRepaint(_BallPainter old) => old.glow != glow;
}

/// A coroa de cristal do Terastal na cor do Tera Type (igual ao site, TeraCrown).
class _TeraCrownPainter extends CustomPainter {
  final Color color;
  const _TeraCrownPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    // Desenhada numa grade de 24 × 16, como o SVG do site.
    canvas.scale(size.width / 24, size.height / 16);
    Path poly(List<double> p) {
      final path = Path()..moveTo(p[0], p[1]);
      for (var i = 2; i < p.length; i += 2) {
        path.lineTo(p[i], p[i + 1]);
      }
      return path..close();
    }

    final parts = [
      poly([1, 15, 4, 5, 8, 12]),
      poly([16, 12, 20, 5, 23, 15]),
      poly([6, 15, 12, 0, 18, 15]),
      poly([1, 15, 23, 15, 21, 11, 3, 11]),
    ];
    final glow = Paint()
      ..color = Colors.white.withAlpha(0xE6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
    final fill = Paint()..color = color;
    final edge = Paint()
      ..color = Colors.black.withAlpha(0x8C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeJoin = StrokeJoin.round;
    for (final p in parts) {
      canvas.drawPath(p, glow);
    }
    for (final p in parts) {
      canvas
        ..drawPath(p, fill)
        ..drawPath(p, edge);
    }
    final light = Paint()..color = Colors.white.withAlpha(0x8C);
    canvas
      ..drawPath(poly([12, 1.5, 12, 14, 8.5, 14]), light)
      ..drawPath(poly([4, 6, 4.4, 12, 2.6, 13]), Paint()..color = Colors.white.withAlpha(0x80))
      ..drawPath(poly([20, 6, 19.6, 12, 17.6, 11.6]), Paint()..color = Colors.white.withAlpha(0x59))
      ..drawRect(const Rect.fromLTWH(3, 12, 18, 1), Paint()..color = Colors.white.withAlpha(0x66));
  }

  @override
  bool shouldRepaint(_TeraCrownPainter old) => old.color != color;
}

/// Onde fica o meio de cada Pokémon no campo (em %).
const _center = [Point<double>(24, 69), Point<double>(75, 25)];

/// Clarão branco (crítico, relâmpago, meteoro).
class _Flash extends StatelessWidget {
  const _Flash({super.key});

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: IgnorePointer(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.85, end: 0),
            duration: const Duration(milliseconds: 260),
            builder: (context, t, _) => ColoredBox(color: Colors.white.withValues(alpha: t)),
          ),
        ),
      );
}

/// As peças da animação do golpe por cima do campo (move_anim.dart).
class _MoveFx extends StatefulWidget {
  final FxPlan plan;
  final Color color;
  final double w, h;
  const _MoveFx({super.key, required this.plan, required this.color, required this.w, required this.h});

  @override
  State<_MoveFx> createState() => _MoveFxState();
}

class _MoveFxState extends State<_MoveFx> with SingleTickerProviderStateMixin {
  late final int _total = widget.plan.parts.fold(1, (m, p) => max(m, p.delay + p.dur));
  late final _clock = AnimationController(vsync: this, duration: Duration(milliseconds: _total))..forward();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  /// Progresso de uma peça (null = ainda não começou).
  double? _t(FxPart p) {
    final elapsed = _clock.value * _total;
    if (elapsed < p.delay) return null;
    return Curves.easeOut.transform(((elapsed - p.delay) / p.dur).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.w, h = widget.h;
    double lerp(double a, double b, double t) => a + (b - a) * t;
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _clock,
          builder: (context, _) => Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              for (final p in widget.plan.parts.where((p) => p.shape == 'wave'))
                if (_t(p) case final t?)
                  Positioned(
                    left: lerp(p.dir > 0 ? -0.6 : 1.05, p.dir > 0 ? 1.05 : -0.6, t) * w,
                    bottom: -0.05 * h,
                    width: 0.55 * w,
                    height: 0.75 * h,
                    child: Opacity(
                      opacity: lerp(0.9, 0.6, t),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.vertical(top: Radius.elliptical(0.275 * w, 0.375 * h)),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [widget.color.withAlpha(0xdd), widget.color.withAlpha(0x55)],
                          ),
                        ),
                      ),
                    ),
                  ),
              CustomPaint(
                size: Size(w, h),
                painter: _FxPainter([
                  for (final p in widget.plan.parts)
                    if (p.shape == 'line' || p.shape == 'ring')
                      if (_t(p) case final t?) (p, t),
                ], widget.color),
              ),
              // Órbita (Swords Dance): gira em volta de quem usa, aparecendo e sumindo devagar.
              for (final p in widget.plan.parts.where((p) => p.shape == 'orbit'))
                if (_clock.value * _total >= p.delay)
                  () {
                    final t = ((_clock.value * _total - p.delay) / p.dur).clamp(0.0, 1.0);
                    final ang = lerp(p.a0, p.a1, t) * pi / 180;
                    final size = p.size * 0.5 / 100 * w;
                    final opacity = t < 0.1 ? t / 0.1 : t > 0.85 ? (1 - t) / 0.15 : 1.0;
                    return Positioned(
                      left: (p.x0 + cos(ang) * p.r) / 100 * w - size,
                      top: (p.y0 + sin(ang) * p.r * 0.8) / 100 * h - size,
                      width: size * 2,
                      height: size * 2,
                      child: Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: 0.85 + sin(ang) * 0.15,
                          child: Center(child: m.Text(p.char, style: TextStyle(fontSize: size, height: 1))),
                        ),
                      ),
                    );
                  }(),
              for (final p in widget.plan.parts.where((p) => p.shape == 'emoji'))
                if (_t(p) case final t?)
                  () {
                    final size = p.size * 0.5 / 100 * w;
                    return Positioned(
                      left: lerp(p.x0, p.x1, t) / 100 * w - size,
                      top: lerp(p.y0, p.y1, t) / 100 * h - size,
                      width: size * 2,
                      height: size * 2,
                      child: Opacity(
                        opacity: lerp(p.o0, p.o1, t).clamp(0.0, 1.0),
                        child: Transform.rotate(
                          angle: p.rot * t * pi / 180,
                          child: Transform.scale(
                            scale: lerp(p.s0, p.s1, t),
                            child: Center(child: m.Text(p.char, style: TextStyle(fontSize: size, height: 1))),
                          ),
                        ),
                      ),
                    );
                  }(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Linhas (raio, corte, relâmpago) e anéis das animações.
class _FxPainter extends CustomPainter {
  final List<(FxPart, double)> parts;
  final Color color;
  _FxPainter(this.parts, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    for (final (p, t) in parts) {
      if (p.shape == 'ring') {
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.008
          ..color = color.withValues(alpha: 1 - t);
        canvas.drawCircle(Offset(p.x0 / 100 * size.width, p.y0 / 100 * size.height), size.width * 0.07 * (0.2 + 2 * t), paint);
        continue;
      }
      // Linha: se desenha até 55% do tempo e depois some.
      final grow = (t / 0.55).clamp(0.0, 1.0);
      final alpha = t < 0.55 ? 1.0 : 1 - (t - 0.55) / 0.45;
      final a = Offset(p.x0 / 100 * size.width, p.y0 / 100 * size.height);
      final b = Offset.lerp(a, Offset(p.x1 / 100 * size.width, p.y1 / 100 * size.height), grow)!;
      for (final (c, width) in [(color, p.width * 1.6), (Colors.white, p.width * 0.6)]) {
        canvas.drawLine(
          a,
          b,
          Paint()
            ..color = c.withValues(alpha: alpha)
            ..strokeWidth = width
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_FxPainter old) => true;
}

class _HpBar extends StatelessWidget {
  final int hp, max;
  const _HpBar({required this.hp, required this.max});

  @override
  Widget build(BuildContext context) {
    final pct = (hp / max).clamp(0.0, 1.0);
    final color = pct > 0.5 ? const Color(0xFF22C55E) : (pct > 0.2 ? const Color(0xFFEAB308) : const Color(0xFFEF4444));
    return Row(children: [
      const m.Text('HP', style: TextStyle(color: Color(0xFFD97706), fontSize: 10, fontWeight: FontWeight.w900)),
      const SizedBox(width: 4),
      Expanded(
        child: Container(
          height: 8,
          decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: pct),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOut,
            builder: (context, v, _) => FractionallySizedBox(
              widthFactor: v,
              heightFactor: 1,
              child: DecoratedBox(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8))),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// Selo do status, como no Showdown.
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);
  static const _colors = {
    'brn': Color(0xFFEE8130),
    'par': Color(0xFFC9A400),
    'psn': Color(0xFFA33EA1),
    'tox': Color(0xFF7B2E7A),
    'slp': Color(0xFF78716C),
    'frz': Color(0xFF4FB3D9),
  };

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(color: _colors[status] ?? Colors.grey, borderRadius: BorderRadius.circular(4)),
        child: m.Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
      );
}

class _MultiBattleView extends StatefulWidget {
  final TurnBattle battle;
  final OnlineBattleControl? online;
  final VoidCallback onExit, onAgain;
  const _MultiBattleView({required this.battle, this.online, required this.onExit, required this.onAgain});
  @override
  State<_MultiBattleView> createState() => _MultiBattleViewState();
}
class _MultiBattleViewState extends State<_MultiBattleView> {
  final Map<int, Map<String, dynamic>> _choices = {};
  // Como no Showdown: um Pokémon por vez; golpe com alvo abre a escolha do alvo.
  Map<String, dynamic>? _aim;
  bool _gimmickOn = false;
  List<BattleEvent> _events = [];
  String? _error;
  TurnBattle get _b => widget.battle;
  String get _uid => widget.online?.uid ?? 'me';
  int get _side => _b.controllers!.indexWhere((team) => team.contains(_uid));
  int get _count => _b.controllers![0].length;
  Map get _own => _b.simulatorState!['sides'][_side] as Map;
  List<Map> get _slots => (_own['slots'] as List).cast<Map>();
  bool get _forced => _slots.any((slot) => slot['forceSwitch'] == true);
  bool get _locked => widget.online?.locked == true || _b.winner != null;
  String _choicePhase(TurnBattle battle) {
    final state = battle.simulatorState!;
    return jsonEncode([state['turn'], for (final side in state['sides'] as List) [side['wait'], for (final slot in side['slots'] as List) [slot['slot'], slot['index'], slot['forceSwitch'], slot['pass']]]]);
  }
  @override
  void didUpdateWidget(covariant _MultiBattleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_choicePhase(oldWidget.battle) != _choicePhase(_b) || oldWidget.online?.round != widget.online?.round) {
      _choices.clear(); _aim = null; _gimmickOn = false; _error = null;
    }
  }
  Map<String, dynamic>? _automatic(Map slot) => _own['wait'] == true
      ? {'kind': 'wait', 'index': 0}
      : slot['pass'] == true || _forced && slot['forceSwitch'] != true ? {'kind': 'pass', 'index': 0}
      : slot['locked'] != null && !_forced ? {'kind': 'move', 'index': 0, 'gimmick': 'none'} : null;
  // Golpe em sequência (Outrage, recarga...) em todos os seus: joga sozinho.
  String? _autoSent;
  void _autoLocked() {
    final phase = _choicePhase(_b);
    if (_locked || _autoSent == phase || _own['wait'] == true || _forced) return;
    final owned = _owned;
    if (owned.isEmpty || owned.any((slot) => _automatic(slot) == null) || !owned.any((slot) => slot['locked'] != null)) return;
    _autoSent = phase;
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted && _choicePhase(_b) == phase) _send();
    });
  }
  Map<String, dynamic>? _picked(Map slot) => _automatic(slot) ?? _choices[slot['slot'] as int];
  List<Map> get _owned => _slots.where((slot) => _b.controllers![_side][slot['slot'] as int] == _uid).toList();
  List<Map> get _pending => _owned.where((slot) => _automatic(slot) == null).toList();
  // Fecha a escolha deste Pokémon; depois do último, manda o turno (como no Showdown).
  void _commit(Map slot, Map<String, dynamic> choice) {
    _choices[slot['slot'] as int] = choice;
    _aim = null;
    _gimmickOn = false;
    if (_pending.every((p) => _choices.containsKey(p['slot']))) {
      _send();
    } else {
      setState(() {});
    }
  }
  void _chooseMove(Map slot, int index) {
    final position = slot['slot'] as int, mon = _b.teams[_side][slot['index'] as int];
    final canZ = (slot['request'] as Map?)?['canZMove'];
    // Z-Move só nos golpes que têm Z (o motor diz quais).
    final gimmick = _gimmickOn && (mon.gimmick != 'z' || canZ is List && index < canZ.length && canZ[index] != null) ? mon.gimmick : '';
    final result = _b.targets(_side, position, index, gimmick);
    final targets = (result['targets'] as List).cast<Map>();
    if (result['automatic'] != true && targets.length > 1) {
      setState(() => _aim = {'kind': 'move', 'index': index, 'gimmick': gimmick});
      return;
    }
    _commit(slot, {'kind': 'move', 'index': index, 'gimmick': gimmick, 'target': targets.firstOrNull?['loc'] ?? 0});
  }
  void _back() => setState(() {
        if (_aim != null) {
          _aim = null;
          return;
        }
        final last = _pending.reversed.where((slot) => _choices.containsKey(slot['slot'])).firstOrNull;
        if (last != null) _choices.remove(last['slot']);
        _gimmickOn = false;
      });
  String _describe(Map slot) {
    final c = _choices[slot['slot'] as int]!, mon = _b.teams[_side][slot['index'] as int];
    if (c['kind'] == 'move') {
      final moves = ((slot['request'] as Map?)?['moves'] as List?)?.cast<Map>() ?? [];
      final target = (_b.targets(_side, slot['slot'] as int, c['index'] as int, '${c['gimmick']}')['targets'] as List).cast<Map>().where((t) => t['loc'] == c['target']).firstOrNull;
      final gimmick = const {'mega': 'Mega', 'tera': 'Terastal', 'dmax': 'Dynamax', 'z': 'Z-Move'}[c['gimmick']];
      return '${mon.name}: ${(c['index'] as int) < moves.length ? moves[c['index'] as int]['move'] : ''}${gimmick != null ? ' ($gimmick)' : ''}${target != null ? ' → ${target['name']}' : ''}';
    }
    if (c['kind'] == 'switch') return '${mon.name} ⇄ ${_b.teams[_side][c['index'] as int].name}';
    return '${mon.name}: ${tr(c['kind'] == 'shift' ? 'trocar de posição' : 'passar')}';
  }
  void _send() {
    final owned = _slots.where((slot) => _b.controllers![_side][slot['slot'] as int] == _uid);
    final submitted = [for (final slot in owned) {'seat': _side * _count + (slot['slot'] as int), ..._picked(slot)!}];
    final switches = [for (final c in submitted) if (c['kind'] == 'switch') c['index']];
    if (switches.toSet().length != switches.length) { setState(() { _error = 'Escolha Pokémon diferentes para as substituições.'; _choices.clear(); }); return; }
    final action = <String, dynamic>{'kind': 'team', 'choices': submitted};
    if (widget.online != null) { setState(() {}); widget.online!.onAction(action); return; }
    try {
      final events = PartyBattle.play(_b, [action], order: true);
      for (var attempt = 0; attempt < 12 && _b.winner == null; attempt++) {
        final state = _b.simulatorState!['sides'][_side] as Map;
        final slots = (state['slots'] as List).cast<Map>();
        final forced = slots.any((s) => s['forceSwitch'] == true);
        final needsChoice = slots.any((s) => _b.controllers![_side][s['slot'] as int] == _uid && state['wait'] != true && s['pass'] != true && (!forced || s['forceSwitch'] == true));
        if (needsChoice) break;
        final waiting = {'kind': 'team', 'choices': [for (final s in slots) if (_b.controllers![_side][s['slot'] as int] == _uid) {'seat': _side * _count + (s['slot'] as int), 'kind': state['wait'] == true ? 'wait' : 'pass', 'index': 0}]};
        events.addAll(PartyBattle.play(_b, [waiting]));
      }
      setState(() { _events = events; _choices.clear(); _error = null; });
    } catch (e) { setState(() { _error = e is StateError ? e.message : 'Não foi possível executar estas ações. Escolha novamente.'; _choices.clear(); }); }
  }
  String _trainer(String controller) => controller == _uid ? tr('Você') : '${widget.online?.names[controller] ?? 'NPC'}';
  Widget _field() => AspectRatio(aspectRatio:(_count==3?1:16/10)/MediaQuery.textScalerOf(context).scale(1).clamp(1,2),child: Container(
    decoration:BoxDecoration(border:Border.all(color:const Color(0xFF1E293B),width:4)),
    child:LayoutBuilder(builder:(context,constraints) {
      final w=constraints.maxWidth,h=constraints.maxHeight;
      Widget sprites(int side) => Positioned(left:side==_side?w*0.01:null,right:side==_side?null:w*0.01,bottom:h*(side==_side ? 0.05 : 0.52),width:w*0.45,
        child:Row(key:ValueKey('battle-sprites-$side'),crossAxisAlignment:CrossAxisAlignment.end,children:[for(final slot in (_b.simulatorState!['sides'][side]['slots'] as List).cast<Map>())
          if((slot['index'] as int)>=0) Expanded(child:AspectRatio(aspectRatio:1,child:Builder(builder:(_) {
            final mon=_b.teams[side][slot['index'] as int];
            return _Sprite(mon:mon,id:mon.dmax>0?mon.gmax??mon.id:mon.id,dmax:mon.dmax>0,tera:_teraOf(mon),back:side==_side,fainted:mon.hp<=0);
          }))),
        ]));
      Widget info(int side) => Positioned(left:side==_side?null:w*0.03,right:side==_side?w*0.03:null,top:side==_side?null:h*0.04,bottom:side==_side?h*0.04:null,width:w*0.45,
        child:Column(key:ValueKey('battle-info-$side'),children:[for(final slot in (_b.simulatorState!['sides'][side]['slots'] as List).cast<Map>())
          if((slot['index'] as int)>=0) Padding(padding:const EdgeInsets.only(bottom:2),child:Builder(builder:(_) {
            final mon=_b.teams[side][slot['index'] as int];
            return Semantics(label:'${_trainer(_b.controllers![side][slot['slot'] as int])} · ${mon.name}',child:FittedBox(fit:BoxFit.scaleDown,child:SizedBox(width:210,child:_InfoBox(mon:mon,hp:mon.hp,mine:side==_side,status:mon.status,dmax:mon.dmax>0))));
          })),
        ]));
      return Stack(clipBehavior:Clip.hardEdge,children:[Positioned.fill(child:CustomPaint(painter:_FieldPainter(_b.weather))),sprites(1-_side),sprites(_side),info(1-_side),info(_side)]);
    }),
  ));
  Widget _button(String label, String sub, Color color, Key key, VoidCallback? onTap, {Color text = Colors.white}) => Material(
        color: color,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(key: key, borderRadius: BorderRadius.circular(10), onTap: onTap,
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            m.Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontWeight: FontWeight.w900, fontSize: 13)),
            if (sub.isNotEmpty) m.Text(sub, style: TextStyle(color: text.withValues(alpha: 0.75), fontSize: 11)),
          ]))),
      );
  Widget _grid(List<Widget> children, {int columns = 2}) => LayoutBuilder(builder: (context, constraints) => Wrap(spacing: 6, runSpacing: 6, children: [
        for (final c in children) SizedBox(width: (constraints.maxWidth - 6 * (columns - 1)) / columns, child: c),
      ]));
  Widget _panel() {
    final pending = _pending;
    final current = pending.where((slot) => !_choices.containsKey(slot['slot'])).firstOrNull;
    final chosen = pending.where((slot) => _choices.containsKey(slot['slot'])).toList();
    Widget body;
    if (current == null) {
      body = Text(widget.online?.locked == true ? 'Aguardando os outros jogadores…' : 'Enviando…');
    } else {
      final slot = current, position = slot['slot'] as int, mon = _b.teams[_side][slot['index'] as int];
      final req = slot['request'] as Map?;
      final moves = (req?['moves'] as List?)?.cast<Map>() ?? [];
      final step = '(${pending.indexOf(slot) + 1}/${pending.length})';
      if (_aim != null) {
        final index = _aim!['index'] as int;
        final targets = (_b.targets(_side, position, index, '${_aim!['gimmick']}')['targets'] as List).cast<Map>();
        List<Map> row(bool ally) => targets.where((t) => (t['ally'] == true) == ally).toList()..sort((a, b) => (a['slot'] as int).compareTo(b['slot'] as int));
        body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          m.Text('${tr('Em quem')} ${mon.name} ${tr('vai usar')} ${index < moves.length ? moves[index]['move'] : ''}? $step', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final ally in [false, true])
            if (row(ally).isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 6), child: _grid(columns: _count, [
              for (final target in row(ally))
                _button('${target['name']}', '${tr(ally ? 'Aliado' : 'Adversário')} · ${(target['slot'] as int) + 1}', ally ? const Color(0xFFE0F2FE) : const Color(0xFFFFE4E6),
                    ValueKey('battle-target-${target['loc']}'), _locked ? null : () => _commit(slot, {..._aim!, 'target': target['loc']}), text: const Color(0xFF0F172A)),
            ])),
        ]);
      } else {
        final mechanic = mon.gimmick;
        final available = switch (mechanic) {
          'mega' => req?['canMegaEvo'] == true,
          'tera' => req?['canTerastallize'] != null && req?['canTerastallize'] != false,
          'dmax' => req?['canDynamax'] == true,
          'z' => req?['canZMove'] is List && (req!['canZMove'] as List).any((z) => z != null),
          _ => false,
        };
        final reserved = _choices.values.any((c) => c['gimmick'] == mechanic);
        // Pokémon que outro já escolheu para entrar não aparece de novo.
        final taken = {for (final c in _choices.values) if (c['kind'] == 'switch') c['index']};
        final options = [for (final i in slot['switchOptions'] as List) if (!taken.contains(i)) i as int];
        body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          m.Text(slot['forceSwitch'] == true ? '${tr('Quem entra no lugar de')} ${mon.name}? $step' : '${tr('O que')} ${mon.name} ${tr('vai fazer?')} $step', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (slot['forceSwitch'] != true) Container(
            key: ValueKey('battle-moves-$position'),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFF475569), width: 4), borderRadius: BorderRadius.circular(12)),
            child: _grid([
              for (final (i, move) in moves.indexed)
                _button('${move['move']}', 'PP ${move['pp'] ?? '—'}/${i < mon.moves.length ? mon.moves[i].maxPp : move['pp'] ?? '—'}', getColorForType(i < mon.moves.length ? mon.moves[i].type : 'normal'),
                    ValueKey('battle-move-$position-$i'), _locked || move['disabled'] == true || move['pp'] == 0 ? null : () => _chooseMove(slot, i)),
            ]),
          ),
          if (slot['forceSwitch'] != true && available) Padding(padding: const EdgeInsets.only(top: 6), child: Align(alignment: Alignment.centerLeft, child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _gimmickOn ? const Color(0xFF8B5CF6) : const Color(0xFF6D28D9)),
            onPressed: _locked || reserved ? null : () => setState(() => _gimmickOn = !_gimmickOn),
            child: Text('${mechanic == 'dmax' && mon.gmax != null ? 'Gigantamax' : const {'mega': 'Mega', 'tera': 'Terastal', 'dmax': 'Dynamax', 'z': 'Z-Move'}[mechanic]}${_gimmickOn ? ' ✓' : ''}')))),
          if (options.isNotEmpty || slot['canShift'] == true || slot['forceSwitch'] == true) ...[
            const SizedBox(height: 8),
            Text(slot['forceSwitch'] == true ? 'POKÉMON' : 'TROCAR (gasta a ação)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
            const SizedBox(height: 4),
            _grid([
              for (final i in options)
                _button('${tr(slot['revival'] == true ? 'Reviver' : '')} ${_b.teams[_side][i].name}'.trim(), '${_b.teams[_side][i].hp}/${_b.teams[_side][i].maxHp}', const Color(0xFF334155),
                    ValueKey('battle-switch-$position-$i'), _locked ? null : () => _commit(slot, {'kind': 'switch', 'index': i})),
              if (slot['canShift'] == true) _button(tr('Trocar posição com o centro'), '', const Color(0xFF334155), ValueKey('battle-shift-$position'), _locked ? null : () => _commit(slot, {'kind': 'shift', 'index': 0})),
              if (slot['forceSwitch'] == true && options.isEmpty) _button(tr('Sem reservas: passar'), '', const Color(0xFF334155), ValueKey('battle-pass-$position'), _locked ? null : () => _commit(slot, {'kind': 'pass', 'index': 0})),
            ]),
          ],
        ]);
      }
    }
    return Card(color: const Color(0xFF1E293B), child: Padding(padding: const EdgeInsets.all(8), child: DefaultTextStyle.merge(style: const TextStyle(color: Colors.white), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final slot in chosen) m.Text('✓ ${_describe(slot)}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
      if (chosen.isNotEmpty) const SizedBox(height: 6),
      body,
      if ((_aim != null || chosen.isNotEmpty) && !_locked) Align(alignment: Alignment.centerLeft, child: TextButton(key: const ValueKey('battle-back'), onPressed: _back, child: const Text('◂ Voltar'))),
    ]))));
  }
  @override
  Widget build(BuildContext context) {
    final events = widget.online?.events ?? _events;
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _autoLocked(); });
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _field(),
      const SizedBox(height: 8),
      Text(widget.online?.message ?? (_b.winner != null ? _b.winner == -1 ? 'Empate!' : _b.winner == _side ? 'Você venceu!' : 'A equipe adversária venceu!' : '${tr('Turno')} ${_b.turn}'), style: const TextStyle(fontWeight: FontWeight.bold)),
      if (_b.winner == null && _pending.isNotEmpty) _panel(),
      const Text('A reserva é compartilhada pela equipe. Os itens equipados mantêm seus efeitos.', style: TextStyle(fontSize: 12)),
      if (_error != null) Text(_error!, style: const TextStyle(color: Colors.redAccent)),
      if (_b.winner == null && _pending.isEmpty) FilledButton(onPressed: _locked ? null : _send, child: const Text('Continuar')),
      ConstrainedBox(constraints: const BoxConstraints(maxHeight: 180), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final e in events.where((e) => e.t == 'text')) Builder(builder: (_) {
        final (line, args) = TurnBattle.lineOf(e); var value = tr(line);
        for (var i = 0; i < args.length; i++) { value = value.replaceFirst('{$i}', args[i]); }
        return m.Text(value, style: const TextStyle(fontSize: 12));
      })]))),
      Wrap(spacing: 10, children: [TextButton(onPressed: widget.online?.onClose ?? widget.onExit, child: Text(widget.online == null ? 'Voltar' : 'Desistir')), if (widget.online == null && _b.winner != null) TextButton(onPressed: widget.onAgain, child: const Text('Batalhar de novo'))]),
    ]);
  }
}

/// Quanto o texto do turno muda o estágio (statUp2 = +2...).
const _boostText = {'statUp': 1, 'statUp2': 2, 'statUp3': 3, 'statDown': -1, 'statDown2': -2, 'statDown3': -3};

/// Selo dos estágios de atributo.
const _boostShort = {'atk': 'Atq', 'def': 'Def', 'spa': 'AtE', 'spd': 'DfE', 'spe': 'Vel', 'accuracy': 'Pre', 'evasion': 'Eva'};

/// Armadilhas, telas e efeitos do campo (como no Showdown), entre o campo e o texto.
class _FieldBar extends StatelessWidget {
  final List<List<String>> conditions;
  const _FieldBar({required this.conditions});

  @override
  Widget build(BuildContext context) {
    final [mine, theirs, all] = conditions;
    if (mine.isEmpty && theirs.isEmpty && all.isEmpty) return const SizedBox.shrink();
    Widget chip(String text, Color color) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99)),
          child: m.Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
        );
    const label = TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, fontWeight: FontWeight.w800);
    return Container(
      key: const ValueKey('field-bar'),
      color: const Color(0xFF334155),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Wrap(spacing: 4, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        if (theirs.isNotEmpty) const Text('Adversário:', style: label),
        for (final x in theirs) chip(x, const Color(0xFFB45309)),
        if (mine.isNotEmpty) const Text('Você:', style: label),
        for (final x in mine) chip(x, const Color(0xFF0369A1)),
        for (final x in all) chip(x, const Color(0xFF7C3AED)),
      ]),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final BattleMon mon;
  final int hp;
  final bool mine, dmax;
  final String status;
  final Map<String, int> boosts;
  const _InfoBox({required this.mon, required this.hp, this.mine = false, this.status = '', this.dmax = false, this.boosts = const {}});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDE0),
          border: Border.all(color: const Color(0xFF334155), width: 2),
          borderRadius: BorderRadius.circular(2),
          boxShadow: const [BoxShadow(color: Color(0xFF52634A), offset: Offset(2,2))],
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w900, fontFamily: 'monospace'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                // Nome longo diminui em vez de cortar.
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: m.Text(mon.name, maxLines: 1, style: const TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 4),
                // Selos e nível: diminuem juntos se não couberem (Tera + DMAX + status).
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 110),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (mon.terastal) ...[_Tag('TERA ${mon.teraType.toUpperCase()}', getColorForType(mon.teraType)), const SizedBox(width: 4)],
                      if (dmax) ...[const _Tag('DMAX', Color(0xFFE11D48)), const SizedBox(width: 4)],
                      if (status.isNotEmpty) ...[_StatusBadge(status), const SizedBox(width: 4)],
                      m.Text('Nv.${mon.level}', style: const TextStyle(fontSize: 11)),
                    ]),
                  ),
                ),
              ]),
              _HpBar(hp: hp, max: mon.maxHp),
              if (boosts.entries.any((b) => b.value != 0 && _boostShort.containsKey(b.key)))
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Wrap(alignment: WrapAlignment.end, spacing: 2, runSpacing: 2, children: [
                    for (final b in boosts.entries)
                      if (b.value != 0 && _boostShort.containsKey(b.key))
                        _Tag('${tr(_boostShort[b.key]!)} ${b.value > 0 ? '+' : '−'}${b.value.abs()}',
                            b.value > 0 ? const Color(0xFF059669) : const Color(0xFFE11D48)),
                  ]),
                ),
              if (mine) m.Text('$hp/${mon.maxHp}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
}

// Cores da efetividade: verde = bom para quem ataca, vermelho = ruim.
const _effectColors = {
  'Super efetivo': Color(0xFF15803D),
  'Efetivo': Color(0xFF475569),
  'Pouco efetivo': Color(0xFFB45309),
  'Não afeta': Color(0xFF1F2937),
};

String _times(double x) => x == 0.25 ? '¼' : x == 0.5 ? '½' : x == x.roundToDouble() ? '${x.toInt()}' : '$x';

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        // Já traduzido.
        child: m.Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
      );
}

/// "Super efetivo ×2", "Pouco efetivo ×½", "Não afeta"... (nada para golpe de status).
class _EffectTag extends StatelessWidget {
  final double? eff;
  final String? prefix;
  const _EffectTag(this.eff, {this.prefix});

  @override
  Widget build(BuildContext context) {
    final label = TurnBattle.effectLabel(eff);
    if (label == null) return const SizedBox.shrink();
    final mult = eff == 0 || eff == 1 ? '' : ' ×${_times(eff!)}';
    return _Tag('${prefix == null ? '' : '${tr(prefix!)}: '}${tr(label)}$mult', _effectColors[label]!);
  }
}

/// Na troca: quanto ele bate no inimigo e quanto sofre com os tipos dele.
Widget _matchup(({double? attack, double defense}) m) {
  final d = m.defense;
  final (label, color) = d == 0
      ? ('Imune', const Color(0xFF15803D))
      : d < 1
          ? ('Resiste', const Color(0xFF15803D))
          : d > 1
              ? ('Fraco', const Color(0xFFB91C1C))
              : ('Neutro', const Color(0xFF475569));
  return Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Wrap(spacing: 4, runSpacing: 4, children: [
      if (m.attack != null) _EffectTag(m.attack, prefix: 'Ataca'),
      _Tag('${tr('Recebe')}: ${tr(label)}${d == 0 || d == 1 ? '' : ' ×${_times(d)}'}', color),
    ]),
  );
}

/// Fraquezas do inimigo (tipos que causam ×2 ou ×4).
class _Weak extends StatelessWidget {
  final BattleMon mon;
  final List<({String type, double mult})> list;
  final bool dark;
  const _Weak(this.mon, this.list, {this.dark = false});

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(spacing: 4, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        m.Text(tr('{0} é fraco contra:').replaceAll('{0}', mon.name),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: dark ? Colors.white : null)),
        for (final w in list) _Tag('${w.type.toUpperCase()} ×${_times(w.mult)}', getColorForType(w.type)),
      ]),
    );
  }
}
