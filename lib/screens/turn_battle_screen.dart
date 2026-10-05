// lib/screens/turn_battle_screen.dart
//
// Batalha por turnos (como nos jogos de GBA), igual ao site
// (TurnBattlePage.jsx): seu time contra o time de um amigo (ou um time
// aleatório), com o computador jogando pelo outro lado. O motor fica em
// lib/services/turn_battle.dart.

import 'dart:async';
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
  int? _mine;
  String _friend = _random;
  List<BattleTeam>? _friendTeams = const [];
  int? _theirs;
  bool _busy = false;
  int _count = 1;
  bool _npcPartner = false;
  TurnBattle? _battle;
  String _foeName = '';
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
  }

  Future<void> _pickFriend(String uid) async {
    setState(() {
      _friend = uid;
      _theirs = null;
      _friendTeams = uid == _random ? const [] : null;
    });
    if (uid == _random) return;
    try {
      final snap = await FirebaseFirestore.instance.collection('publicTeams').where('ownerUid', isEqualTo: uid).get();
      final teams = [for (final d in snap.docs) BattleTeam.fromMap(d.data())].whereType<BattleTeam>().toList();
      if (mounted && _friend == uid) setState(() => _friendTeams = teams);
    } catch (_) {
      if (mounted) setState(() => _friendTeams = const []);
    }
  }

  Future<void> _start(List<Member> mine, List<Member>? theirs, String foeName) async {
    setState(() => _busy = true);
    try {
    final random = League.seededRandom(Random().nextInt(1 << 31));
    final a = await TurnBattleSetup.mons(mine, battleMonName);
    final b = await TurnBattleSetup.mons(theirs ?? await TurnBattleSetup.randomTeam(random), battleMonName);
    final rosters = <String, List<BattleMon>>{'me': a, 'npc3': b};
    final own = [for (var slot = 0; slot < _count; slot++) slot > 0 && _npcPartner ? 'npc$slot' : 'me'];
    for (final uid in own.where((uid) => uid != 'me')) {
      rosters[uid] = await TurnBattleSetup.mons(await TurnBattleSetup.randomTeam(random), battleMonName);
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (a.isNotEmpty && b.isNotEmpty) {
        _battle = _count == 1 ? TurnBattle(a, b, random) : PartyBattle.create(rosters, [...own, ...List.filled(_count, 'npc3')], _count, random);
        _foeName = foeName;
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
    setState(() {
      _battle = TurnBattle(
          [for (final m in b.teams[0]) m.fresh()], [for (final m in b.teams[1]) m.fresh()], League.seededRandom(Random().nextInt(1 << 31)), mode: b.mode, controllers: b.controllers);
      _key++;
    });
    b.dispose();
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
                    onAgain: _again,
                    onExit: () {
                      if (widget.mine != null) { Navigator.pop(context); }
                      else { _battle?.dispose(); setState(() => _battle = null); }
                    },
                  ),
                ],
              )
            : _setup(context),
      ),
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
    final ready = _mine != null && myTeams[_mine!].members.length >= (_npcPartner ? 1 : _count) && (_friend == _random || _theirs != null && _friendTeams![_theirs!].members.length >= _count);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<int>(initialValue: _count, decoration: deco('Formato'), items: const [DropdownMenuItem(value: 1, child: Text('Individual')), DropdownMenuItem(value: 2, child: Text('Dupla')), DropdownMenuItem(value: 3, child: Text('Tripla'))], onChanged: _busy ? null : (v) => setState(() => _count = v!)),
        if (_count > 1) CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Jogar com parceiros NPC'), subtitle: const Text('Desmarcado: você controla todos os Pokémon.'), value: _npcPartner, onChanged: _busy ? null : (v) => setState(() => _npcPartner = v!)),
        const SizedBox(height: 12),
        Text('Nível máximo 50. Batalha por turnos como nos jogos: seu time contra o de um amigo (ou um aleatório), com o computador jogando pelo outro lado.',
            style: TextStyle(color: c.muted, fontSize: 13)),
        const SizedBox(height: 14),
        if (myTeams.isEmpty)
          const EmptyMessage('Monte um time em Times para batalhar.')
        else
          DropdownButtonFormField<int>(
            initialValue: _mine,
            isExpanded: true,
            decoration: deco('Seu time'),
            items: [for (final (i, t) in myTeams.indexed) DropdownMenuItem(value: i, child: _teamRow(t))],
            onChanged: (v) => setState(() => _mine = v),
          ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _friend,
          isExpanded: true,
          decoration: deco('Adversário'),
          items: [
            const DropdownMenuItem(value: _random, child: Text('🎲 Time aleatório')),
            for (final f in friends) DropdownMenuItem(value: f.uid, child: m.Text(f.name)),
          ],
          onChanged: (v) => _pickFriend(v ?? _random),
        ),
        if (_friend != _random) ...[
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
        PillButton(
          label: _busy ? tr('Preparando...') : '⚔️ ${tr('Começar batalha')}',
          expand: true,
          gradient: const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFF9333EA)]),
          onPressed: _busy || !ready || _hit == null
              ? null
              : () {
                  final foe = _friend == _random ? '' : friends.where((f) => f.uid == _friend).firstOrNull?.name ?? '';
                  _start(myTeams[_mine!].members, _friend == _random ? null : _friendTeams![_theirs!].members, foe);
                },
        ),
      ],
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
  const OnlineBattleControl({required this.round, required this.events, this.before, this.uid = 'me', this.names = const {},
    required this.locked, required this.waitForSwitch, required this.message,
    required this.onAction, required this.onClose});
}

class BattleView extends StatefulWidget {
  final TurnBattle battle;
  final BattleHit hit;
  final double Function(String, List<String>) typeEff;
  final String foeName;
  final VoidCallback onAgain, onExit;
  final OnlineBattleControl? online;
  const BattleView(
      {super.key,
      required this.battle,
      required this.hit,
      required this.typeEff,
      required this.foeName,
      required this.onAgain,
      required this.onExit,
      this.online});

  @override
  State<BattleView> createState() => BattleViewState();
}

class BattleViewState extends State<BattleView> with SingleTickerProviderStateMixin {
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

  @override
  void initState() {
    super.initState();
    if (_b.mode != 'singles') return;
    LocalDatabase.instance.moveAnims().then((t) => _anims = t).catchError((_) => <String, dynamic>{});
    // Começo: as habilidades de clima de quem entrou (Drizzle, Drought...).
    _menu = _b.needSwitch ? 'party' : 'main';
    if (widget.online != null) return;
    final opening = _b.start();
    if (opening.isNotEmpty) _wait(_step.inMilliseconds).then((_) => mounted ? _play(opening) : null);
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
    });
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _shake.dispose();
    super.dispose();
  }

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
    for (final e in events) {
      if (!mounted) return;
      switch (e.t) {
        case 'attack':
          // Cada golpe com a sua animação (move_anim.dart), nas cores do tipo.
          final entry = _anims?[e.slug];
          final kind = entry is List ? '${entry[0]}' : moveAnim(e.slug, e.type, e.category);
          final variant = entry is List ? (entry[2] as num).toInt() : 0;
          // Golpe de status: anéis em quem usa (Swords Dance, Recover) ou no alvo (Will-O-Wisp, Toxic).
          final rules = _b.active(e.side).moves.where((m) => m.slug == e.slug).firstOrNull?.rules;
          final self = e.category == 'status' && (rules?['t'] == 'self' || rules?['h'] != null);
          final plan = e.category == 'status'
              ? fxPlan('rings', e.type, e.side, _center[e.side], _center[self ? e.side : 1 - e.side], self ? '✨' : null, variant)
              : fxPlan(kind, e.type, e.side, _center[e.side], _center[1 - e.side], entry is List ? '${entry[1]}' : null, variant);
          _sprites[e.side].currentState?.lunge(dash: contactKinds.contains(kind));
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
          setState(() => _text = _format(e));
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
          setState(() {
            _active[e.side] = e.value;
            _fainted[e.side] = false;
            _form[e.side] = null;
            _dmax[e.side] = false;
          });
        case 'mega':
          setState(() {
            _flash++;
            _form[e.side] = e.value;
          });
          await _wait(500);
        case 'dmax':
          setState(() {
            _form[e.side] = e.value;
            _dmax[e.side] = e.index == 1;
          });
          await _wait(700);
        case 'tera':
          setState(() => _flash++);
          await _wait(400);
        case 'weather':
          // O cenário muda com o clima (céu, chão, chuva caindo...).
          setState(() => _weather = e.type);
          await _wait(600);
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _menu = _b.needSwitch ? 'party' : 'main';
      if (_b.needSwitch) _text = tr('Escolha o próximo Pokémon.');
    });
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
    final before = [_b.active(0).id, _b.active(1).id];
    final gimmick = _selectedGimmick;
    setState(() { _gimmickPick = null; _gimmickMon = null; });
    if (widget.online != null) {
      widget.online!.onAction({'kind': 'move', 'index': i, 'gimmick': gimmick});
      return;
    }
    _play(_b.playTurn(widget.hit, move: i, gimmick: gimmick), before);
  }
  void _choose(int i) {
    setState(() { _gimmickPick = null; _gimmickMon = null; });
    if (widget.online != null) { widget.online!.onAction({'kind': 'switch', 'index': i}); return; }
    final item = _item;
    if (item != null) {
      _item = null;
      _play(_b.playTurn(widget.hit, item: item, target: i));
      return;
    }
    _play(_b.needSwitch ? _b.replace(i) : _b.playTurn(widget.hit, switchTo: i));
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

  @override
  Widget build(BuildContext context) {
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
                          child: _InfoBox(mon: foe, hp: _hp[1][_active[1]], status: _status[1][_active[1]], dmax: _dmax[1])),
                      Positioned(
                          // O inimigo fica mais longe: menor e com os pés na
                          // frente do meio da plataforma (pisando nela, como o seu).
                          right: w * 0.12,
                          bottom: h * 0.53,
                          width: w * 0.26,
                          height: w * 0.26,
                          child: _Sprite(key: _sprites[1], mon: foe, id: _form[1] ?? foe.id, dmax: _dmax[1], fainted: _fainted[1])),
                      Positioned(
                          left: w * 0.06,
                          bottom: h * 0.05,
                          width: w * 0.36,
                          height: w * 0.36,
                          child: _Sprite(key: _sprites[0], mon: me, id: _form[0] ?? me.id, dmax: _dmax[0], back: true, fainted: _fainted[0])),
                      Positioned(
                          right: w * 0.03,
                          bottom: h * 0.06,
                          width: w * 0.5,
                          child: _InfoBox(mon: me, hp: _hp[0][_active[0]], status: _status[0][_active[0]], dmax: _dmax[0], mine: true)),
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
                    subtitle: Text(it.revive ? tr('Revive com metade do HP') : tr('Recupera {0} de HP').replaceAll('{0}', '${it.heal}')),
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
        if (!_busy && _b.winner != null && widget.online == null) ...[
          const SizedBox(height: 14),
          PillButton(
            label: tr('Batalhar de novo'),
            expand: true,
            gradient: const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFF9333EA)]),
            onPressed: widget.onAgain,
          ),
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

/// Cenário da batalha (desenho nosso, igual ao do site), com cara de 3D como
/// no Black & White: céu com sol e nuvens, montanhas com luz e sombra, árvores
/// no horizonte, gramado em perspectiva e as plataformas com espessura. Muda
/// com o clima ([weather]: céu, nuvens, sol e o chão).
/// Coordenadas numa grade de 160 × 100, esticada para o campo.
class _FieldPainter extends CustomPainter {
  const _FieldPainter(this.weather);
  final String weather;

  /// Linha do horizonte: o chão começa aqui.
  static const _horizon = 36.0;

  /// Nuvens: (x, y, largura).
  static const _clouds = [(24.0, 9.0, 11.0), (70.0, 5.0, 8.0), (104.0, 15.0, 9.0), (150.0, 19.0, 6.0)];

  /// Montanhas: (x do pico, altura do pico, meia largura).
  static const _mountains = [(20.0, 16.0, 22.0), (58.0, 10.0, 26.0), (100.0, 18.0, 22.0), (140.0, 12.0, 26.0)];

  /// Céu de cada clima: (cima, horizonte). Igual ao site.
  static const _sky = {
    '': (Color(0xFF5FB9F5), Color(0xFFE6F7FF)),
    'rain': (Color(0xFF4F6073), Color(0xFFA5B2BF)),
    'sun': (Color(0xFFFF9B3D), Color(0xFFFFF0C2)),
    'sand': (Color(0xFFB4844B), Color(0xFFE6CB96)),
    'hail': (Color(0xFF8AA2B9), Color(0xFFE7EFF7)),
    'snow': (Color(0xFF8AA2B9), Color(0xFFEEF4FA)),
  };

  /// Cor das nuvens e o chão no clima (cor por cima do gramado).
  static const _cloudColor = {'rain': Color(0xFF76838F), 'sand': Color(0xFFD8C095), 'hail': Color(0xFFDFE7EF), 'snow': Color(0xFFEEF3F8)};
  static const _groundTint = {
    'rain': Color(0x4D16324F),
    'sun': Color(0x24FFCF5A),
    'sand': Color(0x66C9A063),
    'hail': Color(0x40FFFFFF),
    'snow': Color(0x80FFFFFF),
  };

  @override
  void paint(Canvas canvas, Size size) {
    const hz = _horizon;
    final sx = size.width / 160, sy = size.height / 100;
    Offset p(double x, double y) => Offset(x * sx, y * sy);
    Rect r(double x, double y, double w, double h) => Rect.fromLTWH(x * sx, y * sy, w * sx, h * sy);
    Rect oval(double cx, double cy, double rx, double ry) => Rect.fromCenter(center: p(cx, cy), width: 2 * rx * sx, height: 2 * ry * sy);
    Path poly(List<(double, double)> points) => Path()..addPolygon([for (final (x, y) in points) p(x, y)], true);

    final (skyTop, skyBottom) = _sky[weather] ?? _sky['']!;
    canvas.drawRect(
        r(0, 0, 160, hz + 2),
        Paint()
          ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [skyTop, skyBottom])
              .createShader(r(0, 0, 160, hz + 2)));
    // Sol (maior no sol forte; escondido na chuva, areia e neve).
    if (weather.isEmpty || weather == 'sun') {
      final sun = oval(132, 9, weather == 'sun' ? 24 : 14, weather == 'sun' ? 24 : 14);
      canvas.drawOval(
          sun,
          Paint()
            ..shader = const RadialGradient(colors: [Color(0xFFFFFBE6), Color(0xE6FFF3B0), Color(0x00FFF3B0)], stops: [0, 0.4, 1])
                .createShader(sun));
    }
    // Nuvens.
    final cloud = Paint()..color = (_cloudColor[weather] ?? Colors.white).withAlpha(weather == 'sun' ? 102 : 217);
    for (final (x, y, w) in _clouds) {
      canvas.drawOval(oval(x, y, w, w * 0.32), cloud);
      canvas.drawOval(oval(x - w * 0.45, y + w * 0.08, w * 0.55, w * 0.24), cloud);
      canvas.drawOval(oval(x + w * 0.5, y + w * 0.1, w * 0.5, w * 0.22), cloud);
    }
    // Montanhas: lado da luz e lado da sombra.
    for (final (x, top, w) in _mountains) {
      final snow = top + (hz - top) * 0.25;
      canvas.drawPath(poly([(x - w, hz), (x, top), (x + w, hz)]), Paint()..color = const Color(0xFFA8CFE0));
      canvas.drawPath(poly([(x, top), (x + w, hz), (x + w * 0.2, hz)]), Paint()..color = const Color(0xFF86B3C9));
      canvas.drawPath(poly([(x - w * 0.25, snow), (x, top), (x + w * 0.25, snow), (x, top + (hz - top) * 0.32)]), Paint()..color = const Color(0xFFF4FBFF));
    }
    canvas.drawRect(
        r(0, hz - 14, 160, 14),
        Paint()
          ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x73FFFFFF), Color(0x00FFFFFF)])
              .createShader(r(0, hz - 14, 160, 14)));
    // Árvores no horizonte.
    for (var i = 0; i < 23; i++) {
      final x = i * 7.3 + i % 3, rad = 3.2 + (i % 4) * 0.6;
      canvas.drawOval(oval(x, hz - rad * 0.6, rad, rad), Paint()..color = const Color(0xFF3F8F45));
      canvas.drawOval(oval(x - rad * 0.3, hz - rad * 0.85, rad * 0.55, rad * 0.55), Paint()..color = const Color(0xFF5AAB52));
    }
    // Gramado: faixas mais finas perto do horizonte (perspectiva).
    for (var i = 0, y = hz; y < 100; i++) {
      final h = 1 + i * 0.9;
      canvas.drawRect(r(0, y, 160, h + 0.2), Paint()..color = Color(i.isOdd ? 0xFF8FD162 : 0xFFA3DC74));
      y += h;
    }
    // Linhas que fogem para o horizonte.
    final line = Paint()
      ..color = Colors.white.withAlpha(26)
      ..strokeWidth = 0.4 * sx;
    for (final x in [-60.0, -20.0, 20.0, 60.0, 100.0, 140.0, 180.0, 220.0]) {
      canvas.drawLine(p(80, hz), p(x, 100), line);
    }
    // O chão no clima: molhado, areia, coberto de neve, ao sol.
    final tint = _groundTint[weather];
    if (tint != null) canvas.drawRect(r(0, hz, 160, 100 - hz), Paint()..color = tint);
    // Plataformas no chão: a do inimigo, mais longe, é menor e mais achatada.
    _platform(canvas, oval, 120, 45, 23, 3.6, 1.4);
    _platform(canvas, oval, 38.4, 91, 34, 7, 3);
  }

  /// Plataforma com espessura: terra, borda de grama e sombra no chão.
  void _platform(Canvas canvas, Rect Function(double, double, double, double) oval, double cx, double cy, double rx, double ry, double depth) {
    canvas.drawOval(oval(cx, cy + depth * 0.7, rx * 1.06, ry * 1.15), Paint()..color = const Color(0x4D2F6B2A));
    final top = oval(cx, cy, rx, ry), bottom = oval(cx, cy + depth, rx, ry);
    final side = Path()
      ..addRect(Rect.fromLTRB(top.left, top.center.dy, top.right, bottom.center.dy))
      ..addOval(bottom);
    canvas.drawPath(side, Paint()..color = const Color(0xFF8A6F3C));
    canvas.drawOval(
        top,
        Paint()
          ..shader = const RadialGradient(center: Alignment(-0.1, -0.3), radius: 0.7, colors: [Color(0xFFF1E3B4), Color(0xFFD9C28A), Color(0xFFB79C5E)], stops: [0, 0.6, 1])
              .createShader(top));
    canvas.drawOval(
        top,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = top.height * 0.12
          ..color = const Color(0xFF6FB24A));
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
  const _Sprite({super.key, required this.mon, required this.id, this.back = false, this.fainted = false, this.dmax = false});

  @override
  State<_Sprite> createState() => _SpriteState();
}

class _SpriteState extends State<_Sprite> with TickerProviderStateMixin {
  late final _lunge = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  late final _hurt = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late final _dodge = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

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
            child: AnimatedScale(
              scale: widget.dmax ? 1.35 : 1,
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
                  PokemonSprite(widget.id, shiny: widget.mon.shiny, back: widget.back, fill: 0.95, alignBottom: true, battle: true),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
  List<BattleEvent> _events = [];
  String? _error;
  int _generation = 0;
  TurnBattle get _b => widget.battle;
  String get _uid => widget.online?.uid ?? 'me';
  int get _side => _b.controllers!.indexWhere((team) => team.contains(_uid));
  int get _count => _b.controllers![0].length;
  Map get _own => _b.simulatorState!['sides'][_side] as Map;
  List<Map> get _slots => (_own['slots'] as List).cast<Map>();
  bool get _forced => _slots.any((slot) => slot['forceSwitch'] == true);
  bool get _locked => widget.online?.locked == true || _b.winner != null;
  @override
  void didUpdateWidget(covariant _MultiBattleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.battle != _b || oldWidget.online?.round != widget.online?.round) {
      _choices.clear(); _error = null; _generation++;
    }
  }
  Map<String, dynamic>? _automatic(Map slot) => _own['wait'] == true
      ? {'kind': 'wait', 'index': 0}
      : slot['pass'] == true || _forced && slot['forceSwitch'] != true ? {'kind': 'pass', 'index': 0} : null;
  Map<String, dynamic>? _picked(Map slot) => _automatic(slot) ?? _choices[slot['slot'] as int];
  void _pick(Map slot, String kind, int index, [String? mechanic]) {
    final position = slot['slot'] as int;
    final gimmick = mechanic ?? '${_choices[position]?['gimmick'] ?? ''}';
    final result = kind == 'move' ? _b.targets(_side, position, index, gimmick) : {'targets': <dynamic>[]};
    final targets = (result['targets'] as List).cast<Map>();
    final target = targets.where((t) => t['ally'] != true).firstOrNull ?? targets.firstOrNull;
    setState(() => _choices[position] = {'kind': kind, 'index': index, 'gimmick': kind == 'move' ? gimmick : '', 'target': target?['loc'] ?? 0});
  }
  void _send() {
    final owned = _slots.where((slot) => _b.controllers![_side][slot['slot'] as int] == _uid);
    final submitted = [for (final slot in owned) {'seat': _side * _count + (slot['slot'] as int), ..._picked(slot)!}];
    final switches = [for (final c in submitted) if (c['kind'] == 'switch') c['index']];
    if (switches.toSet().length != switches.length) { setState(() => _error = 'Escolha Pokémon diferentes para as substituições.'); return; }
    final action = <String, dynamic>{'kind': 'team', 'choices': submitted};
    if (widget.online != null) { widget.online!.onAction(action); return; }
    try {
      final events = PartyBattle.play(_b, [action]);
      for (var attempt = 0; attempt < 12 && _b.winner == null; attempt++) {
        final state = _b.simulatorState!['sides'][_side] as Map;
        final slots = (state['slots'] as List).cast<Map>();
        final forced = slots.any((s) => s['forceSwitch'] == true);
        final needsChoice = slots.any((s) => _b.controllers![_side][s['slot'] as int] == _uid && state['wait'] != true && s['pass'] != true && (!forced || s['forceSwitch'] == true));
        if (needsChoice) break;
        final waiting = {'kind': 'team', 'choices': [for (final s in slots) if (_b.controllers![_side][s['slot'] as int] == _uid) {'seat': _side * _count + (s['slot'] as int), 'kind': state['wait'] == true ? 'wait' : 'pass', 'index': 0}]};
        events.addAll(PartyBattle.play(_b, [waiting]));
      }
      setState(() { _events = events; _choices.clear(); _error = null; _generation++; });
    } catch (e) { setState(() => _error = e is StateError ? e.message : 'Não foi possível executar estas ações. Escolha novamente.'); }
  }
  String _trainer(String controller) => controller == _uid ? tr('Você') : '${widget.online?.names[controller] ?? 'NPC'}';
  Widget _teamRow(int side) {
    final slots = (_b.simulatorState!['sides'][side]['slots'] as List).cast<Map>();
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final slot in slots)
      Expanded(child: Padding(padding: const EdgeInsets.all(3), child: Builder(builder: (context) {
        final mon = _b.teams[side][slot['index'] as int];
        return Column(children: [
          Container(width: double.infinity, padding: const EdgeInsets.all(2), color: const Color(0xBB0F172A), child: m.Text(_trainer(_b.controllers![side][slot['slot'] as int]), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11))),
          AspectRatio(aspectRatio: 1, child: _Sprite(mon: mon, id: mon.dmax > 0 ? mon.gmax ?? mon.id : mon.id, dmax: mon.dmax > 0, back: side == _side, fainted: mon.hp <= 0)),
          _InfoBox(mon: mon, hp: mon.hp, mine: true, status: mon.status, dmax: mon.dmax > 0),
        ]);
      }))),
    ]);
  }
  Widget _actions(Map slot) {
    final position = slot['slot'] as int, mon = _b.teams[_side][slot['index'] as int];
    final action = _picked(slot), req = slot['request'] as Map?;
    final moves = (req?['moves'] as List?)?.cast<Map>() ?? [];
    final mechanic = mon.gimmick;
    final index = action?['index'] as int? ?? 0;
    final available = switch (mechanic) {
      'mega' => req?['canMegaEvo'] == true,
      'tera' => req?['canTerastallize'] != null && req?['canTerastallize'] != false,
      'dmax' => req?['canDynamax'] == true,
      'z' => req?['canZMove'] is List && index < (req!['canZMove'] as List).length && (req['canZMove'] as List)[index] != null,
      _ => false,
    };
    final reserved = _choices.entries.any((entry) => entry.key != position && entry.value['gimmick'] == mechanic);
    final targetData = action?['kind'] == 'move' ? _b.targets(_side, position, index, '${action?['gimmick'] ?? ''}') : {'targets': <dynamic>[], 'automatic': true};
    final targets = (targetData['targets'] as List).cast<Map>();
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      m.Text('${mon.name} · ${tr('posição')} ${position + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      if (_automatic(slot) != null) Text(_own['wait'] == true ? 'Aguardando as substituições.' : 'Esta posição passa durante a substituição.')
      else ...[
        DropdownButtonFormField<String>(key: ValueKey((_generation, position, action?['kind'], action?['index'])), initialValue: action == null ? null : '${action['kind']}:${action['index']}', isExpanded: true,
          decoration: InputDecoration(labelText: '${tr('Ação de')} ${mon.name} ${position + 1}'),
          items: [
            if (slot['forceSwitch'] != true) for (final (i, move) in moves.indexed) DropdownMenuItem(value: 'move:$i', enabled: move['disabled'] != true && move['pp'] != 0, child: m.Text('${move['move']} · PP ${move['pp'] ?? '—'}', overflow: TextOverflow.ellipsis)),
            for (final dynamic i in slot['switchOptions'] as List) DropdownMenuItem(value: 'switch:$i', child: m.Text('${tr(slot['revival'] == true ? 'Reviver' : 'Trocar para')} ${_b.teams[_side][i as int].name}', overflow: TextOverflow.ellipsis)),
            if (slot['canShift'] == true) const DropdownMenuItem(value: 'shift:0', child: Text('Trocar posição com o centro')),
            if (slot['forceSwitch'] == true && (slot['switchOptions'] as List).isEmpty) const DropdownMenuItem(value: 'pass:0', child: Text('Sem reservas: passar')),
          ],
          onChanged: _locked ? null : (v) { if (v != null) { final fields = v.split(':'); _pick(slot, fields[0], int.parse(fields[1])); } }),
        if (action?['kind'] == 'move' && targetData['automatic'] != true) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(key: ValueKey((_generation, position, action?['gimmick'], action?['target'])), initialValue: action?['target'] as int?, isExpanded: true, decoration: InputDecoration(labelText: '${tr('Alvo de')} ${mon.name} ${position + 1}'),
            items: [for (final target in targets) DropdownMenuItem(value: target['loc'] as int, child: m.Text('${tr(target['ally'] == true ? 'Aliado' : 'Adversário')}: ${target['name']} · ${(target['slot'] as int) + 1}', overflow: TextOverflow.ellipsis))],
            onChanged: _locked ? null : (v) => setState(() => _choices[position] = {...action!, 'target': v})),
        ],
        if (action?['kind'] == 'move' && targetData['automatic'] == true) const Text('O golpe aplica seus alvos automaticamente.', style: TextStyle(fontSize: 12)),
        if (available) TextButton(onPressed: _locked || reserved ? null : () => _pick(slot, 'move', index, action?['gimmick'] == mechanic ? '' : mechanic),
          child: Text('${mechanic == 'dmax' && mon.gmax != null ? 'Gigantamax' : const {'mega': 'Mega', 'tera': 'Terastal', 'dmax': 'Dynamax', 'z': 'Z-Move'}[mechanic]}${action?['gimmick'] == mechanic ? ' ✓' : ''}')),
      ],
    ])));
  }
  @override
  Widget build(BuildContext context) {
    final owned = _slots.where((s) => _b.controllers![_side][s['slot'] as int] == _uid).toList();
    final events = widget.online?.events ?? _events;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ClipRRect(borderRadius: BorderRadius.circular(16), child: Stack(children: [Positioned.fill(child: CustomPaint(painter: _FieldPainter(_b.weather))), Column(children: [_teamRow(1 - _side), _teamRow(_side)])])),
      const SizedBox(height: 8),
      Text(widget.online?.message ?? (_b.winner != null ? _b.winner == -1 ? 'Empate!' : _b.winner == _side ? 'Você venceu!' : 'A equipe adversária venceu!' : 'Turno ${_b.turn}: escolha uma ação por Pokémon.'), style: const TextStyle(fontWeight: FontWeight.bold)),
      if (_b.winner == null) for (final slot in owned) _actions(slot),
      const Text('A reserva é compartilhada pela equipe. Os itens equipados mantêm seus efeitos.', style: TextStyle(fontSize: 12)),
      if (_error != null) Text(_error!, style: const TextStyle(color: Colors.redAccent)),
      if (_b.winner == null) FilledButton(onPressed: _locked || owned.any((s) => _picked(s) == null) ? null : _send, child: Text(owned.every((s) => _automatic(s) != null) ? 'Continuar' : 'Confirmar ações')),
      ConstrainedBox(constraints: const BoxConstraints(maxHeight: 180), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final e in events.where((e) => e.t == 'text')) Builder(builder: (_) {
        final (line, args) = TurnBattle.lineOf(e); var value = tr(line);
        for (var i = 0; i < args.length; i++) { value = value.replaceFirst('{$i}', args[i]); }
        return m.Text(value, style: const TextStyle(fontSize: 12));
      })]))),
      Wrap(spacing: 10, children: [TextButton(onPressed: widget.online?.onClose ?? widget.onExit, child: Text(widget.online == null ? 'Voltar' : 'Desistir')), if (widget.online == null && _b.winner != null) TextButton(onPressed: widget.onAgain, child: const Text('Batalhar de novo'))]),
    ]);
  }
}

class _InfoBox extends StatelessWidget {
  final BattleMon mon;
  final int hp;
  final bool mine, dmax;
  final String status;
  const _InfoBox({required this.mon, required this.hp, this.mine = false, this.status = '', this.dmax = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          border: Border.all(color: const Color(0xFF334155), width: 3),
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(10), topRight: Radius.circular(10), bottomLeft: Radius.circular(10), bottomRight: Radius.circular(22)),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w900),
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
