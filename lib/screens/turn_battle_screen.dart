// lib/screens/turn_battle_screen.dart
//
// Batalha por turnos (como nos jogos de GBA), igual ao site
// (TurnBattlePage.jsx): seu time contra o time de um amigo (ou um time
// aleatório), com o computador jogando pelo outro lado. O motor fica em
// lib/services/turn_battle.dart.

import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;

import '../i18n/i18n.dart';
import '../i18n/text.dart';
import '../services/damage_calc.dart';
import '../services/friends_service.dart';
import '../services/league.dart';
import '../services/team_battle.dart';
import '../services/move_anim.dart';
import '../services/turn_battle.dart';
import '../services/user_data.dart';
import '../utils/pokemon_colors.dart';
import '../utils/responsive.dart';
import '../utils/site_ui.dart';
import '../utils/string_extensions.dart';
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

String _monName(Map<String, dynamic> row) => I18n.pokemonName((row['name'] as String).split('-').first.capitalise());

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
  TurnBattle? _battle;
  String _foeName = '';
  BattleHit? _hit;
  int _key = 0;

  List<BattleTeam> get _myTeams => [for (final t in UserData.instance.teams) BattleTeam.fromMap(t)].whereType<BattleTeam>().toList();

  @override
  void initState() {
    super.initState();
    DamageData.load().then((data) {
      if (mounted) setState(() => _hit = TurnBattleSetup.hitter(data));
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
    final random = League.seededRandom(Random().nextInt(1 << 31));
    final a = await TurnBattleSetup.mons(mine, _monName);
    final b = await TurnBattleSetup.mons(theirs ?? await TurnBattleSetup.randomTeam(random), _monName);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (a.isNotEmpty && b.isNotEmpty) {
        _battle = TurnBattle(a, b, random);
        _foeName = foeName;
        _key++;
      }
    });
  }

  void _again() {
    final b = _battle!;
    setState(() {
      _battle = TurnBattle(
          [for (final m in b.teams[0]) m.fresh()], [for (final m in b.teams[1]) m.fresh()], League.seededRandom(Random().nextInt(1 << 31)));
      _key++;
    });
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
                  _BattleView(
                    key: ValueKey(_key),
                    battle: battle,
                    hit: _hit!,
                    foeName: _foeName,
                    onAgain: _again,
                    onExit: () => widget.mine != null ? Navigator.pop(context) : setState(() => _battle = null),
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
    final ready = _mine != null && (_friend == _random || _theirs != null);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Batalha por turnos como nos jogos: seu time contra o de um amigo (ou um aleatório), com o computador jogando pelo outro lado.',
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
            'O computador joga pelo adversário. Batalha simplificada: só golpes de dano (com PP, precisão, prioridade e crítico), sem status nem clima.',
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

class _BattleView extends StatefulWidget {
  final TurnBattle battle;
  final BattleHit hit;
  final String foeName;
  final VoidCallback onAgain, onExit;
  const _BattleView({super.key, required this.battle, required this.hit, required this.foeName, required this.onAgain, required this.onExit});

  @override
  State<_BattleView> createState() => _BattleViewState();
}

class _BattleViewState extends State<_BattleView> with SingleTickerProviderStateMixin {
  static const _step = Duration(milliseconds: 1100);
  late final List<int> _active = [widget.battle.activeIndex[0], widget.battle.activeIndex[1]];
  late final List<List<int>> _hp = [
    for (final t in widget.battle.teams) [for (final mon in t) mon.hp]
  ];
  final List<bool> _fainted = [false, false];
  late String _text = widget.foeName.isNotEmpty ? tr('{0} quer batalhar!').replaceAll('{0}', widget.foeName) : tr('Um treinador quer batalhar!');
  bool _busy = false;
  String _menu = 'main'; // main | fight | party | bag
  String? _item; // item da Bolsa escolhido (falta escolher em quem)
  late final _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  int _flash = 0;
  Completer<void>? _skip;
  final _sprites = [GlobalKey<_SpriteState>(), GlobalKey<_SpriteState>()];
  (FxPlan, Color, int)? _fx; // animação do golpe na tela
  int _fxKey = 0;

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

  TurnBattle get _b => widget.battle;

  String _format(BattleEvent e) {
    final (line, args) = TurnBattle.lineOf(e);
    var text = tr(line);
    for (var i = 0; i < args.length; i++) {
      text = text.replaceFirst('{$i}', args[i]);
    }
    return text;
  }

  Future<void> _play(List<BattleEvent> events) async {
    setState(() => _busy = true);
    for (final e in events) {
      if (!mounted) return;
      switch (e.t) {
        case 'attack':
          // Cada golpe com a sua animação (move_anim.dart), nas cores do tipo.
          final kind = moveAnim(e.slug, e.type, e.category);
          final plan = fxPlan(kind, e.type, e.side, _center[e.side], _center[1 - e.side]);
          _sprites[e.side].currentState?.lunge(dash: contactKinds.contains(kind));
          setState(() => _fx = (plan, getColorForType(e.type), ++_fxKey));
          if (plan.shake) _shake.forward(from: 0);
          if (plan.flash) Future<void>.delayed(const Duration(milliseconds: 250), () => mounted ? setState(() => _flash++) : null);
          await _wait(fxDuration[kind] ?? 700);
          if (!mounted) return;
          setState(() => _fx = null);
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
          await Future.any([Future<void>.delayed(_step), _skip!.future]);
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
          });
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _menu = _b.needSwitch ? 'party' : 'main';
      if (_b.needSwitch) _text = tr('Escolha o próximo Pokémon.');
    });
  }

  void _fight(int i) => _play(_b.playTurn(widget.hit, move: i));
  void _choose(int i) {
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
    if (ok == true) _play(_b.forfeit());
  }

  @override
  Widget build(BuildContext context) {
    final me = _b.teams[0][_active[0]];
    final foe = _b.teams[1][_active[1]];
    final current = _b.active(0);
    final waiting = !_busy && _b.winner == null;
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
              decoration: BoxDecoration(
                border: Border.all(color: border, width: 4),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFBFE6FF), Color(0xFFE8F6FF), Color(0xFFB9E59A), Color(0xFF8FD16B)],
                  stops: [0, 0.45, 0.46, 1],
                ),
              ),
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
                      Positioned(left: w * 0.03, top: h * 0.05, width: w * 0.48, child: _InfoBox(mon: foe, hp: _hp[1][_active[1]])),
                      Positioned(right: w * 0.06, top: h * 0.32, width: w * 0.38, height: h * 0.07, child: const _Platform()),
                      Positioned(
                          right: w * 0.1,
                          top: h * 0.02,
                          width: w * 0.3,
                          height: w * 0.3,
                          child: _Sprite(key: _sprites[1], mon: foe, fainted: _fainted[1])),
                      Positioned(left: w * 0.02, bottom: h * 0.03, width: w * 0.46, height: h * 0.09, child: const _Platform()),
                      Positioned(
                          left: w * 0.06,
                          bottom: h * 0.05,
                          width: w * 0.36,
                          height: w * 0.36,
                          child: _Sprite(key: _sprites[0], mon: me, back: true, fainted: _fainted[0])),
                      Positioned(right: w * 0.03, bottom: h * 0.06, width: w * 0.5, child: _InfoBox(mon: me, hp: _hp[0][_active[0]], mine: true)),
                      if (_fx != null) _MoveFx(key: ValueKey(_fx!.$3), plan: _fx!.$1, color: _fx!.$2, w: w, h: h),
                      if (_flash > 0) _Flash(key: ValueKey(_flash)),
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
                onTap: () => _skip?.complete(),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 72),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFD97706), width: 4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  // Já traduzido (nomes e golpes não mudam).
                  child: m.Text(_text, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              if (waiting && _menu == 'main' && !_b.needSwitch) ...[
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
                  _MenuButton('BOLSA', () => setState(() => _menu = 'bag')),
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
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 3.2,
                  children: [
                    for (final (i, mv) in current.moves.indexed)
                      Material(
                        color: getColorForType(mv.type).withAlpha(mv.pp > 0 ? 255 : 100),
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: mv.pp > 0 ? () => _fight(i) : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                m.Text(mv.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                                m.Text('PP ${mv.pp}/${mv.maxPp}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
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
                for (final (i, mon) in _b.teams[0].indexed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    enabled: _item != null ? _b.canUseItem(0, _item!, i) : mon.hp > 0 && i != _b.activeIndex[0],
                    onTap: () => _choose(i),
                    leading: SizedBox.square(dimension: 44, child: PokemonSprite(mon.id, shiny: mon.shiny, fill: 0.95)),
                    title: m.Text(mon.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HpBar(hp: mon.hp, max: mon.maxHp),
                        mon.hp > 0
                            ? m.Text('${mon.hp}/${mon.maxHp}', style: const TextStyle(fontSize: 12))
                            : const Text('Desmaiado', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    trailing: i == _b.activeIndex[0] ? const Icon(Icons.check_circle, color: Color(0xFF0EA5E9)) : null,
                  ),
              ],
            ),
          ),
        ],
        if (!_busy && _b.winner != null) ...[
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
  final VoidCallback onTap;
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
              child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w900)),
            ),
          ),
        ),
      );
}

class _Platform extends StatelessWidget {
  const _Platform();
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: const Color(0xFF166534).withAlpha(90), borderRadius: const BorderRadius.all(Radius.elliptical(200, 30))),
      );
}

// Sprites animados do Black & White (oficiais, do #1 ao #649), de frente e de
// costas, direto do repositório de sprites da PokeAPI (igual ao site). Do #650
// em diante (ou sem internet) fica o sprite parado de sempre, balançando.
const _bwAnimated = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/versions/generation-v/black-white/animated';
String? _bwUrl(int id, bool back, bool shiny) => id >= 1 && id <= 649 ? '$_bwAnimated/${back ? 'back/' : ''}${shiny ? 'shiny/' : ''}$id.gif' : null;

class _Sprite extends StatefulWidget {
  final BattleMon mon;
  final bool back, fainted;
  const _Sprite({super.key, required this.mon, this.back = false, this.fainted = false});

  @override
  State<_Sprite> createState() => _SpriteState();
}

class _SpriteState extends State<_Sprite> with TickerProviderStateMixin {
  late final _lunge = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  late final _hurt = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late final _dodge = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final _idle = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();

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
    _idle.dispose();
    super.dispose();
  }

  Widget _static(bool bob) => AnimatedBuilder(
        animation: _idle,
        builder: (context, child) => FractionalTranslation(
          translation: Offset(0, bob ? -0.015 * (1 - cos(_idle.value * 2 * pi)) : 0),
          child: child,
        ),
        // O seu fica de costas (espelhado), como nos jogos.
        child: Transform.flip(flipX: widget.back, child: PokemonSprite(widget.mon.id, shiny: widget.mon.shiny, fill: 0.95, alignBottom: true)),
      );

  @override
  Widget build(BuildContext context) {
    final url = _bwUrl(widget.mon.id, widget.back, widget.mon.shiny);
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
          // Trocou de Pokémon: começa do zero (sem ficar o sprite do anterior).
          child: KeyedSubtree(
            key: ValueKey((widget.mon.id, widget.mon.shiny)),
            child: url == null
                ? _static(true)
                : LayoutBuilder(
                    // Tamanho de verdade do sprite (os pequenos continuam pequenos, como no jogo).
                    builder: (context, box) => Align(
                      alignment: Alignment.bottomCenter,
                      child: Image.network(
                        url,
                        scale: 96 / box.maxWidth,
                        filterQuality: FilterQuality.none,
                        gaplessPlayback: true,
                        loadingBuilder: (context, child, progress) => progress == null ? child : _static(false),
                        errorBuilder: (context, error, stack) => _static(true),
                      ),
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

class _InfoBox extends StatelessWidget {
  final BattleMon mon;
  final int hp;
  final bool mine;
  const _InfoBox({required this.mon, required this.hp, this.mine = false});

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
                m.Text('Nv.${mon.level}', style: const TextStyle(fontSize: 11)),
              ]),
              _HpBar(hp: hp, max: mon.maxHp),
              if (mine) m.Text('$hp/${mon.maxHp}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
}
