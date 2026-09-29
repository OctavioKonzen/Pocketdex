// lib/screens/damage_calc_screen.dart
//
// Calculadora de dano do Treino — as mesmas opções do site
// (web-site/src/components/DamageCalc.jsx) e a mesma conta dos jogos
// oficiais da geração 9 (lib/services/damage_calc.dart).
//
//   • os dois lados: nível, Nature, habilidade, item, Tera, status, HP atual,
//     EVs, IVs e estágios de cada status;
//   • campo: simples/dupla, clima, terreno, Trick Room, telas, Spikes...;
//   • todos os golpes de dano do atacante com o % real, do que mais tira ao
//     que menos tira, ou qualquer outro golpe;
//   • resultado: faixa de dano, chance de derrotar, quem age primeiro e as
//     16 variações de dano.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/damage_calc.dart';
import '../utils/responsive.dart';
import '../utils/site_ui.dart';
import '../utils/string_extensions.dart';
import '../widgets/pick_fields.dart';
import 'battle_tools_screen.dart';

const _statLabels = {'hp': 'HP', 'atk': 'Atk', 'def': 'Def', 'spa': 'Sp. Atk', 'spd': 'Sp. Def', 'spe': 'Speed'};

const _teraTypes = [
  'normal', 'fire', 'water', 'electric', 'grass', 'ice', 'fighting', 'poison', 'ground', //
  'flying', 'psychic', 'bug', 'rock', 'ghost', 'dragon', 'dark', 'steel', 'fairy', 'stellar',
];

const _weathers = [
  ('', 'Nenhum'),
  ('Sun', 'Sol'),
  ('Rain', 'Chuva'),
  ('Sand', 'Tempestade de areia'),
  ('Snow', 'Neve'),
  ('Harsh Sunshine', 'Sol extremo (Desolate Land)'),
  ('Heavy Rain', 'Chuva forte (Primordial Sea)'),
  ('Strong Winds', 'Ventos fortes (Delta Stream)'),
];

const _terrains = [
  ('', 'Nenhum'),
  ('Electric', 'Electric Terrain'),
  ('Grassy', 'Grassy Terrain'),
  ('Psychic', 'Psychic Terrain'),
  ('Misty', 'Misty Terrain'),
];

const _statuses = [
  ('', 'Saudável'),
  ('brn', 'Queimado'),
  ('par', 'Paralisado'),
  ('psn', 'Envenenado'),
  ('tox', 'Muito envenenado'),
  ('slp', 'Dormindo'),
  ('frz', 'Congelado'),
];

/// Habilidades que dependem de algo que a conta não vê (ligar/desligar).
const _toggleAbilities = {
  'Flash Fire': 'Flash Fire ativado',
  'Protosynthesis': 'Protosynthesis ativa',
  'Quark Drive': 'Quark Drive ativa',
  'Stakeout': 'O alvo acabou de entrar',
  'Analytic': 'Age depois do alvo',
  'Slow Start': 'Slow Start ativo',
  'Intimidate': 'Intimidate no adversário',
  'Unburden': 'Unburden ativo',
  'Plus': 'Aliado com Plus/Minus',
  'Minus': 'Aliado com Plus/Minus',
  'Electromorphosis': 'Carregado (Electromorphosis)',
  'Intrepid Sword': 'Intrepid Sword ao entrar',
  'Dauntless Shield': 'Dauntless Shield ao entrar',
  'Teraform Zero': 'Teraform Zero ativo',
  'Wind Rider': 'Wind Rider ativado',
};

/// Habilidades que mudam o clima ou o terreno ao entrar (como nos jogos).
const _abilityWeather = {
  'Drought': 'Sun',
  'Orichalcum Pulse': 'Sun',
  'Drizzle': 'Rain',
  'Sand Stream': 'Sand',
  'Snow Warning': 'Snow',
  'Desolate Land': 'Harsh Sunshine',
  'Primordial Sea': 'Heavy Rain',
  'Delta Stream': 'Strong Winds',
};
const _abilityTerrain = {
  'Electric Surge': 'Electric',
  'Hadron Engine': 'Electric',
  'Grassy Surge': 'Grassy',
  'Psychic Surge': 'Psychic',
  'Misty Surge': 'Misty',
};

/// Itens mais usados em batalha (aparecem primeiro na lista).
const _popularItems = [
  'Choice Band', 'Choice Specs', 'Choice Scarf', 'Life Orb', 'Leftovers', 'Focus Sash', 'Assault Vest', //
  'Heavy-Duty Boots', 'Expert Belt', 'Eviolite', 'Booster Energy', 'Rocky Helmet', 'Sitrus Berry', 'Lum Berry',
  'Black Sludge', 'Loaded Dice', 'Clear Amulet', 'Covert Cloak', 'Air Balloon', 'Weakness Policy', 'Light Clay',
  'Punching Glove', 'Mirror Herb', 'Throat Spray',
];

// Opções do campo que são só ligar/desligar: chave → nome.
const _fieldToggles = [
  ('trickRoom', 'Trick Room'),
  ('gravity', 'Gravity'),
  ('magicRoom', 'Magic Room'),
  ('wonderRoom', 'Wonder Room'),
  ('fairyAura', 'Fairy Aura'),
  ('darkAura', 'Dark Aura'),
  ('auraBreak', 'Aura Break'),
  ('swordOfRuin', 'Sword of Ruin'),
  ('beadsOfRuin', 'Beads of Ruin'),
  ('tabletsOfRuin', 'Tablets of Ruin'),
  ('vesselOfRuin', 'Vessel of Ruin'),
];
const _attackerToggles = [
  ('helpingHand', 'Helping Hand'),
  ('charge', 'Charge'),
  ('battery', 'Battery (aliado)'),
  ('powerSpot', 'Power Spot (aliado)'),
  ('steelySpirit', 'Steely Spirit (aliado)'),
  ('flowerGift', 'Flower Gift (aliado)'),
  ('attackerTailwind', 'Tailwind'),
];
const _defenderToggles = [
  ('reflect', 'Reflect'),
  ('lightScreen', 'Light Screen'),
  ('auroraVeil', 'Aurora Veil'),
  ('friendGuard', 'Friend Guard (aliado)'),
  ('protect', 'Protect'),
  ('stealthRock', 'Stealth Rock'),
  ('saltCure', 'Salt Cure'),
  ('leechSeed', 'Leech Seed'),
  ('defenderTailwind', 'Tailwind'),
  ('switchingOut', 'Saindo da batalha (Pursuit)'),
];

const _attackerColor = Color(0xFFEF5350);
const _defenderColor = Color(0xFF42A5F5);

String _pct(double x) {
  final s = x == x.roundToDouble() ? x.toInt().toString() : x.toStringAsFixed(1);
  return s.replaceAll('.', ',');
}

Color _barColor(double pct) => pct >= 100
    ? const Color(0xFFE53935)
    : pct >= 50
        ? const Color(0xFFFB8C00)
        : const Color(0xFF43A047);

/// Configuração de um lado (os dois lados têm as mesmas opções).
class _Side {
  _Side(Map<String, int> evs)
      : evs = {for (final s in statIds) s: evs[s] ?? 0},
        ivs = {for (final s in statIds) s: 31},
        boosts = {for (final s in statIds) s: 0};

  int level = 50;
  String nature = 'Hardy';
  String ability = '';
  bool abilityOn = false;
  String item = '';
  String teraType = '';
  bool terastallized = false;
  String status = '';
  int hpPct = 100;
  final Map<String, int> evs, ivs, boosts;
  int alliesFainted = 0;

  int get evTotal => evs.values.fold(0, (a, b) => a + b);
}

/// Campo: clima, terreno e o que está ligado.
class _Field {
  String gameType = 'Singles';
  String weather = '';
  String terrain = '';
  int spikes = 0;
  final on = <String>{};

  bool operator [](String key) => on.contains(key);
  void set(String key, bool value) => value ? on.add(key) : on.remove(key);

  CalcField toCalc() => CalcField(
        gameType: gameType,
        weather: weather,
        terrain: terrain,
        isGravity: this['gravity'],
        isMagicRoom: this['magicRoom'],
        isWonderRoom: this['wonderRoom'],
        isSwordOfRuin: this['swordOfRuin'],
        isBeadsOfRuin: this['beadsOfRuin'],
        isTabletsOfRuin: this['tabletsOfRuin'],
        isVesselOfRuin: this['vesselOfRuin'],
        isFairyAura: this['fairyAura'],
        isDarkAura: this['darkAura'],
        isAuraBreak: this['auraBreak'],
        attackerSide: CalcSide(
          isHelpingHand: this['helpingHand'],
          isBattery: this['battery'],
          isPowerSpot: this['powerSpot'],
          isSteelySpirit: this['steelySpirit'],
          isFlowerGift: this['flowerGift'],
          isCharge: this['charge'],
          isTailwind: this['attackerTailwind'],
        ),
        defenderSide: CalcSide(
          isReflect: this['reflect'],
          isLightScreen: this['lightScreen'],
          isAuroraVeil: this['auroraVeil'],
          isFriendGuard: this['friendGuard'],
          isSR: this['stealthRock'],
          spikes: spikes,
          isSaltCured: this['saltCure'],
          isSeeded: this['leechSeed'],
          isProtected: this['protect'],
          isTailwind: this['defenderTailwind'],
          isSwitching: this['switchingOut'] ? 'out' : '',
        ),
      );
}

/// Opções do golpe escolhido.
class _MoveOptions {
  bool crit = false;
  int hits = 0;
  int timesUsed = 1;
  int metronome = 1;
  bool stellarFirst = true;
}

/// Resultado de um golpe, já com os números que a tela mostra.
class _Run {
  _Run(this.slug, this.result) {
    final (lo, hi) = result.range();
    min = lo;
    max = hi;
    hp = result.defender.maxHP();
    curHP = result.defender.curHP();
    minPct = (min / hp * 1000).round() / 10;
    maxPct = (max / hp * 1000).round() / 10;
    ko = max > 0 ? result.kochance() : const KOChance(0, 0, 'Não causa dano.');
  }

  final String slug;
  final CalcResult result;
  late final int min, max, hp, curHP;
  late final double minPct, maxPct;
  late final KOChance ko;

  CalcMove get move => result.move;
  bool get noDamage => max == 0;
  String get koText => noDamage ? 'Não causa dano.' : ko.text;
}

/// Pokémon da calculadora a partir do que escolhemos e da configuração.
CalcPokemon _makePokemon(DamageData data, PickedPokemon base, _Side side) {
  final ability = side.ability;
  final qp = ability == 'Protosynthesis' || ability == 'Quark Drive';
  final pokemon = CalcPokemon(
    data,
    data.speciesName(base.name),
    baseStats: {for (var i = 0; i < 6; i++) statIds[i]: base.stats[i]},
    types: [for (final t in base.types) t.capitalise()],
    weightkg: base.weight / 10,
    level: side.level,
    ability: ability,
    abilityOn: side.abilityOn,
    alliesFainted: side.alliesFainted,
    boostedStat: qp ? 'auto' : '',
    item: side.item,
    teraType: side.terastallized && side.teraType.isNotEmpty ? side.teraType.capitalise() : '',
    nature: side.nature,
    ivs: side.ivs,
    evs: side.evs,
    boosts: side.boosts,
    status: side.status,
  );
  // Ativada sem sol / Electric Terrain / Booster Energy: o maior status sobe.
  if (qp && side.abilityOn) {
    var best = 'atk';
    for (final s in const ['def', 'spa', 'spd', 'spe']) {
      if (pokemon.stats[s]! > pokemon.stats[best]!) best = s;
    }
    pokemon.boostedStat = best;
  }
  final hp = (pokemon.maxHP() * side.hpPct / 100).floor();
  pokemon.originalCurHP = hp < 1 ? 1 : hp;
  return pokemon;
}

class DamageCalcScreen extends StatefulWidget {
  const DamageCalcScreen({super.key});
  @override
  State<DamageCalcScreen> createState() => _DamageCalcScreenState();
}

class _DamageCalcScreenState extends State<DamageCalcScreen> {
  DamageData? _data;
  String? _error;
  PickedPokemon? _attacker;
  PickedPokemon? _defender;
  var _a = _Side({'atk': 252, 'spa': 252, 'spe': 4});
  var _d = _Side({'hp': 252, 'def': 4});
  final _field = _Field();
  var _options = _MoveOptions();
  String _moveSlug = '';
  bool _allMoves = false;

  @override
  void initState() {
    super.initState();
    DamageData.load().then((d) {
      if (mounted) setState(() => _data = d);
    }).catchError((Object e) {
      if (mounted) setState(() => _error = '$e');
    });
  }

  /// Habilidade (pelo nome) e o que ela faz no campo ao entrar.
  void _setAbility(_Side side, String ability) {
    final changed = side.ability != ability;
    side.ability = ability;
    side.abilityOn = false;
    if (!changed) return;
    final w = _abilityWeather[ability];
    final t = _abilityTerrain[ability];
    if (w != null) _field.weather = w;
    if (t != null) _field.terrain = t;
  }

  List<String> _ownAbilities(PickedPokemon? p) {
    final data = _data;
    if (data == null || p == null) return const [];
    return [
      for (final slug in p.abilities)
        if (data.abilityName(slug).isNotEmpty) data.abilityName(slug),
    ];
  }

  Future<void> _pick(bool attacker) async {
    final p = await PickedPokemon.choose(context);
    if (p == null || !mounted) return;
    setState(() {
      final own = _ownAbilities(p);
      if (attacker) {
        _attacker = p;
        _moveSlug = '';
        _options = _MoveOptions();
        _allMoves = false;
        _setAbility(_a, own.firstOrNull ?? '');
      } else {
        _defender = p;
        _setAbility(_d, own.firstOrNull ?? '');
      }
    });
  }

  void _swap() => setState(() {
        final pa = _attacker, sa = _a;
        _attacker = _defender;
        _defender = pa;
        _a = _d;
        _d = sa;
        final at = _field['attackerTailwind'];
        _field.set('attackerTailwind', _field['defenderTailwind']);
        _field.set('defenderTailwind', at);
        _moveSlug = '';
        _options = _MoveOptions();
        _allMoves = false;
      });

  _Run? _run(String slug, _MoveOptions opts) {
    final data = _data, a = _attacker, d = _defender;
    if (data == null || a == null || d == null || data.move(slug) == null) return null;
    try {
      final attacker = _makePokemon(data, a, _a);
      final defender = _makePokemon(data, d, _d);
      final move = CalcMove(
        data,
        data.move(slug)!.name,
        ability: attacker.ability,
        item: attacker.item,
        isCrit: opts.crit,
        isStellarFirstUse: opts.stellarFirst,
        hits: opts.hits,
        timesUsed: opts.timesUsed > 1 ? opts.timesUsed : 0,
        timesUsedWithMetronome: opts.metronome > 1 ? opts.metronome : 0,
      );
      return _Run(slug, calculateDamage(attacker, defender, move, _field.toCalc()));
    } catch (e) {
      debugPrint('calculadora de dano: $e');
      return null;
    }
  }

  /// Todos os golpes de dano que o atacante aprende, do que mais tira ao que menos tira.
  List<_Run> _learnedMoves() {
    final data = _data, a = _attacker;
    if (data == null || a == null || _defender == null) return const [];
    final runs = [
      for (final slug in a.moves)
        if (data.move(slug) != null && data.move(slug)!.category != 'Status') _run(slug, _MoveOptions()),
    ].whereType<_Run>().toList()
      ..sort((x, y) {
        final c = y.maxPct.compareTo(x.maxPct);
        return c != 0 ? c : x.move.name.compareTo(y.move.name);
      });
    return runs;
  }

  Future<void> _pickOtherMove() async {
    final data = _data;
    if (data == null) return;
    final names = [
      for (final m in data.moves.values)
        if (m.category != 'Status' && m.basePower >= 0) m.name,
    ]..sort();
    final chosen = await showSearchSheet(context, title: 'Outro golpe (qualquer um)', options: names);
    if (chosen == null || chosen.isEmpty || !mounted) return;
    setState(() {
      _moveSlug = toId(chosen);
      _options = _MoveOptions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final data = _data;
    final a = _attacker, d = _defender;

    Widget body;
    if (_error != null) {
      body = Center(child: Text('Não deu para abrir a calculadora: $_error', style: TextStyle(color: c.muted)));
    } else if (data == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final learned = _learnedMoves();
      final current = _moveSlug.isNotEmpty ? _moveSlug : (learned.firstOrNull?.slug ?? '');
      final result = current.isEmpty ? null : _run(current, _options);
      final visible = _allMoves ? learned : learned.take(8).toList();
      final otherMove = current.isNotEmpty && !learned.any((r) => r.slug == current);

      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Row(
            children: [
              Expanded(child: _slotColumn('Atacante', _attackerColor, a, 'Escolher atacante', () => _pick(true))),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 24, 4, 0),
                child: IconButton.filledTonal(
                  tooltip: 'Trocar atacante e defensor',
                  onPressed: a == null && d == null ? null : _swap,
                  icon: const Icon(Icons.swap_horiz),
                ),
              ),
              Expanded(child: _slotColumn('Defensor', _defenderColor, d, 'Escolher defensor', () => _pick(false))),
            ],
          ),
          const SizedBox(height: 16),
          if (a != null && d != null) ...[
            SiteCard(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('Golpes de ${a.label}',
                        style: TextStyle(color: c.text, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  const SizedBox(height: 6),
                  if (learned.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text('Nenhum golpe de dano encontrado.', style: TextStyle(color: c.muted)),
                    ),
                  for (final r in visible)
                    _MoveRow(
                      run: r,
                      active: r.slug == current,
                      onTap: () => setState(() {
                        _moveSlug = r.slug;
                        _options = _MoveOptions();
                      }),
                    ),
                  if (otherMove && result != null)
                    _MoveRow(run: result, active: true, onTap: () {}),
                  if (learned.length > 8)
                    TextButton(
                      onPressed: () => setState(() => _allMoves = !_allMoves),
                      child: Text(_allMoves ? 'Mostrar menos' : 'Ver todos os ${learned.length} golpes'),
                    ),
                  OutlinedButton.icon(
                    onPressed: _pickOtherMove,
                    icon: const Icon(Icons.search),
                    label: const Text('Outro golpe (qualquer um)'),
                  ),
                ],
              ),
            ),
            if (result != null) ...[
              const SizedBox(height: 12),
              _resultCard(context, data, result, a, d),
            ],
            const SizedBox(height: 12),
          ],
          if (a != null || d != null) ...[
            _SidePanel(
              title: 'Atacante',
              accent: _attackerColor,
              data: data,
              pokemon: a,
              side: _a,
              own: _ownAbilities(a),
              onAbility: (v) => setState(() => _setAbility(_a, v)),
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 12),
            _SidePanel(
              title: 'Defensor',
              accent: _defenderColor,
              data: data,
              pokemon: d,
              side: _d,
              own: _ownAbilities(d),
              onAbility: (v) => setState(() => _setAbility(_d, v)),
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 12),
            _FieldPanel(field: _field, onChanged: () => setState(() {})),
            const SizedBox(height: 10),
            Text(
              'Mesma conta dos jogos oficiais (geração 9), com habilidades, itens, campo e golpes especiais.',
              style: TextStyle(color: c.muted, fontSize: 11),
            ),
          ],
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Calculadora de dano')),
      body: ReadableWidth(child: body),
    );
  }

  Widget _slotColumn(String title, Color accent, PickedPokemon? p, String label, VoidCallback onTap) => Column(
        children: [
          Text(title, style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          PokemonSlot(pokemon: p, label: label, onTap: onTap),
        ],
      );

  Widget _resultCard(BuildContext context, DamageData data, _Run result, PickedPokemon a, PickedPokemon d) {
    final c = SiteColors.of(context);
    final move = result.move;
    final info = data.move(result.slug);
    final mh = info?.multihit;
    final hitRange = mh is List && mh.length == 2 ? ((mh[0] as num).toInt(), (mh[1] as num).toInt()) : null;
    final speedA = result.result.attacker.stats['spe'];
    final speedD = result.result.defender.stats['spe'];
    final trickRoom = _field['trickRoom'];
    final muted = TextStyle(color: c.muted, fontSize: 13);

    void setOpt(void Function(_MoveOptions o) change) => setState(() => change(_options));

    return SiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(move.name, style: TextStyle(color: c.text, fontWeight: FontWeight.w900, fontSize: 18)),
              TypeBadge(move.type.toLowerCase(), small: true),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${move.category == 'Physical' ? 'Físico' : 'Especial'} · poder ${move.bp}'
            '${move.hits > 1 ? ' · ${move.hits} acertos' : ''}',
            style: muted,
          ),
          const SizedBox(height: 10),
          if (result.noDamage)
            Text('Não causa dano.', style: TextStyle(color: c.text, fontSize: 24, fontWeight: FontWeight.w900))
          else ...[
            Text('${_pct(result.minPct)}% – ${_pct(result.maxPct)}%',
                style: TextStyle(color: c.text, fontSize: 32, fontWeight: FontWeight.w900)),
            Text(
              '${result.min}–${result.max} de ${result.hp} HP'
              '${result.curHP < result.hp ? ' (HP atual: ${result.curHP})' : ''}',
              style: muted,
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (result.maxPct / 100).clamp(0.0, 1.0),
                minHeight: 14,
                backgroundColor: c.surface,
                valueColor: AlwaysStoppedAnimation(_barColor(result.maxPct)),
              ),
            ),
            const SizedBox(height: 10),
            Text(result.koText, style: TextStyle(color: c.text, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
          if (speedA != null && speedD != null) ...[
            const SizedBox(height: 8),
            Text(
              'Velocidade: ${a.label} $speedA × $speedD ${d.label} — '
              '${speedA == speedD ? 'empate' : '${((speedA > speedD) != trickRoom ? a : d).label} age primeiro${trickRoom ? ' (Trick Room)' : ''}'}',
              style: muted,
            ),
          ],
          const Divider(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _CheckChip(label: 'Golpe crítico', value: _options.crit, onChanged: (v) => setOpt((o) => o.crit = v)),
              if (hitRange != null && hitRange.$1 != hitRange.$2)
                _Inline(
                  label: 'Acertos',
                  child: DropdownButton<int>(
                    value: _options.hits,
                    items: [
                      const DropdownMenuItem(value: 0, child: Text('Padrão')),
                      for (var h = hitRange.$1; h <= hitRange.$2; h++) DropdownMenuItem(value: h, child: Text('$h')),
                    ],
                    onChanged: (v) => setOpt((o) => o.hits = v ?? 0),
                  ),
                ),
              _Inline(
                label: 'Vezes seguidas',
                child: _Stepper(value: _options.timesUsed, min: 1, max: 5, onChanged: (v) => setOpt((o) => o.timesUsed = v)),
              ),
              if (_a.item == 'Metronome')
                _Inline(
                  label: 'Usos com Metronome',
                  child: _Stepper(value: _options.metronome, min: 1, max: 6, onChanged: (v) => setOpt((o) => o.metronome = v)),
                ),
              if (_a.terastallized && _a.teraType == 'stellar')
                _CheckChip(
                  label: 'Primeiro uso do tipo (Stellar)',
                  value: _options.stellarFirst,
                  onChanged: (v) => setOpt((o) => o.stellarFirst = v),
                ),
            ],
          ),
          if (!result.noDamage)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('As 16 variações de dano', style: TextStyle(color: c.muted, fontSize: 13)),
                children: [
                  for (var i = 0; i < result.result.damage.length; i++)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${result.result.damage.length > 1 ? 'Acerto ${i + 1}: ' : ''}${result.result.damage[i].join(', ')}',
                          style: TextStyle(color: c.muted, fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Um golpe da lista, com o % que tira.
class _MoveRow extends StatelessWidget {
  final _Run run;
  final bool active;
  final VoidCallback onTap;
  const _MoveRow({required this.run, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    return Material(
      color: active ? const Color(0xFF0EA5E9).withValues(alpha: 0.18) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              SizedBox(width: 76, child: Align(alignment: Alignment.centerLeft, child: TypeBadge(run.move.type.toLowerCase(), small: true))),
              Expanded(
                child: Text(run.move.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.text, fontWeight: active ? FontWeight.bold : FontWeight.w500)),
              ),
              const SizedBox(width: 8),
              Text(
                run.noDamage ? '—' : '${_pct(run.minPct)}–${_pct(run.maxPct)}%',
                style: TextStyle(
                  color: run.noDamage ? c.muted : _barColor(run.maxPct),
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Configuração de um lado (os dois lados têm as mesmas opções).
class _SidePanel extends StatelessWidget {
  final String title;
  final Color accent;
  final DamageData data;
  final PickedPokemon? pokemon;
  final _Side side;
  final List<String> own;
  final ValueChanged<String> onAbility;
  final VoidCallback onChanged;
  const _SidePanel({
    required this.title,
    required this.accent,
    required this.data,
    required this.pokemon,
    required this.side,
    required this.own,
    required this.onAbility,
    required this.onChanged,
  });

  String _natureLabel(String name) {
    final n = data.natures[name]!;
    return n[0] == n[1] ? '$name (neutra)' : '$name (+${_statLabels[n[0]]} −${_statLabels[n[1]]})';
  }

  List<String> get _allItems {
    final held = [
      for (final name in data.items.keys)
        if (!name.endsWith(' Ball') && !RegExp(r'^T[RM]\d').hasMatch(name)) name,
    ]..sort();
    return {..._popularItems.where(data.items.containsKey), ...held}.toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final p = pokemon;
    final stats = p == null ? null : _makePokemon(data, p, side);
    final toggle = _toggleAbilities[side.ability];
    final nature = data.natures[side.nature]!;
    void change(void Function() f) {
      f();
      onChanged();
    }

    final summary = [
      'Nv. ${side.level}',
      side.nature,
      if (side.ability.isNotEmpty) side.ability,
      if (side.item.isNotEmpty) side.item,
      if (side.terastallized && side.teraType.isNotEmpty) 'Tera ${side.teraType.capitalise()}',
      if (side.hpPct < 100) 'HP ${side.hpPct}%',
    ].join(' · ');

    return SiteCard(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Text('$title${p != null ? ' · ${p.label}' : ''}',
              style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 16)),
          subtitle: Text(summary, style: TextStyle(color: c.muted, fontSize: 12)),
          children: [
            Row(
              children: [
                _Labeled(
                  label: 'Nível',
                  child: NumberField(value: side.level, min: 1, max: 100, width: 72, onChanged: (v) => change(() => side.level = v)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Labeled(
                    label: 'Nature',
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: side.nature,
                      items: [
                        for (final n in data.natures.keys)
                          DropdownMenuItem(value: n, child: Text(_natureLabel(n), overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => change(() => side.nature = v ?? 'Hardy'),
                    ),
                  ),
                ),
              ],
            ),
            _Labeled(
              label: 'Habilidade',
              child: _PickerButton(
                value: side.ability,
                empty: 'Nenhuma',
                onTap: () async {
                  final v = await showSearchSheet(context,
                      title: 'Habilidade', options: {...own, ...data.abilities}.toList(), emptyLabel: 'Nenhuma');
                  if (v != null) onAbility(v);
                },
              ),
            ),
            if (own.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final ab in own)
                      ChoiceChip(
                        label: Text(ab, style: const TextStyle(fontSize: 12)),
                        selected: side.ability == ab,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => onAbility(ab),
                      ),
                  ],
                ),
              ),
            if (toggle != null) _CheckChip(label: toggle, value: side.abilityOn, onChanged: (v) => change(() => side.abilityOn = v)),
            _Labeled(
              label: 'Item',
              child: _PickerButton(
                value: side.item,
                empty: 'Nenhum',
                onTap: () async {
                  final v = await showSearchSheet(context, title: 'Item', options: _allItems, emptyLabel: 'Nenhum');
                  if (v != null) change(() => side.item = v);
                },
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _Labeled(
                    label: 'Tipo Tera',
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: side.teraType,
                      items: [
                        const DropdownMenuItem(value: '', child: Text('—')),
                        for (final t in _teraTypes) DropdownMenuItem(value: t, child: Text(t.capitalise())),
                      ],
                      onChanged: (v) => change(() {
                        side.teraType = v ?? '';
                        side.terastallized = side.teraType.isNotEmpty;
                      }),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: _CheckChip(
                      label: 'Terastalizado',
                      value: side.terastallized,
                      onChanged: side.teraType.isEmpty ? null : (v) => change(() => side.terastallized = v),
                    ),
                  ),
                ),
              ],
            ),
            _Labeled(
              label: 'Status',
              child: DropdownButton<String>(
                isExpanded: true,
                value: side.status,
                items: [for (final (v, l) in _statuses) DropdownMenuItem(value: v, child: Text(l))],
                onChanged: (v) => change(() => side.status = v ?? ''),
              ),
            ),
            _Labeled(
              label: 'HP atual: ${side.hpPct}%${stats != null ? ' (${stats.curHP()}/${stats.maxHP()})' : ''}',
              child: Slider(
                value: side.hpPct.toDouble(),
                min: 1,
                max: 100,
                divisions: 99,
                activeColor: const Color(0xFF43A047),
                onChanged: (x) => change(() => side.hpPct = x.round()),
              ),
            ),
            const SizedBox(height: 4),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1.3),
                1: FixedColumnWidth(64),
                2: FixedColumnWidth(56),
                3: FixedColumnWidth(64),
                4: FlexColumnWidth(1),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(children: [
                  const SizedBox(),
                  for (final h in const ['EVs', 'IVs', 'Estágio'])
                    Center(child: Text(h, style: TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.w600))),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('Final', style: TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ]),
                for (final key in statIds)
                  TableRow(children: [
                    Text.rich(TextSpan(
                      text: _statLabels[key],
                      style: TextStyle(color: c.text, fontWeight: FontWeight.bold, fontSize: 13),
                      children: [
                        if (nature[0] != nature[1] && nature[0] == key)
                          const TextSpan(text: '+', style: TextStyle(color: Color(0xFF22C55E))),
                        if (nature[0] != nature[1] && nature[1] == key)
                          const TextSpan(text: '−', style: TextStyle(color: Color(0xFFEF4444))),
                      ],
                    )),
                    Padding(
                      padding: const EdgeInsets.all(2),
                      child: NumberField(value: side.evs[key]!, min: 0, max: 252, onChanged: (v) => change(() => side.evs[key] = v)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(2),
                      child: NumberField(value: side.ivs[key]!, min: 0, max: 31, onChanged: (v) => change(() => side.ivs[key] = v)),
                    ),
                    key == 'hp'
                        ? const SizedBox()
                        : Center(
                            child: DropdownButton<int>(
                              value: side.boosts[key],
                              isDense: true,
                              items: [
                                for (var s = 6; s >= -6; s--)
                                  DropdownMenuItem(value: s, child: Text(s > 0 ? '+$s' : '$s', style: const TextStyle(fontSize: 13))),
                              ],
                              onChanged: (v) => change(() => side.boosts[key] = v ?? 0),
                            ),
                          ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        stats == null ? '—' : '${key == 'hp' ? stats.maxHP() : stats.stats[key]}',
                        style: TextStyle(
                          color: c.text,
                          fontWeight: FontWeight.bold,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ]),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'EVs usados: ${side.evTotal} de 510',
              style: TextStyle(
                color: side.evTotal > 510 ? const Color(0xFFEF4444) : c.muted,
                fontSize: 12,
                fontWeight: side.evTotal > 510 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            _Labeled(
              label: 'Aliados já derrotados (Supreme Overlord, Last Respects)',
              child: _Stepper(value: side.alliesFainted, min: 0, max: 5, onChanged: (v) => change(() => side.alliesFainted = v)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Campo de batalha.
class _FieldPanel extends StatelessWidget {
  final _Field field;
  final VoidCallback onChanged;
  const _FieldPanel({required this.field, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    void change(void Function() f) {
      f();
      onChanged();
    }

    Widget toggles(String title, List<(String, String)> list) => _Labeled(
          label: title,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (key, label) in list)
                FilterChip(
                  label: Text(label, style: const TextStyle(fontSize: 12)),
                  selected: field[key],
                  visualDensity: VisualDensity.compact,
                  onSelected: (v) => change(() => field.set(key, v)),
                ),
            ],
          ),
        );

    final summary = [
      field.gameType == 'Doubles' ? 'Dupla' : 'Simples',
      if (field.weather.isNotEmpty) _weathers.firstWhere((w) => w.$1 == field.weather).$2,
      if (field.terrain.isNotEmpty) _terrains.firstWhere((t) => t.$1 == field.terrain).$2,
      if (field.on.isNotEmpty) '${field.on.length} ${field.on.length == 1 ? 'opção ligada' : 'opções ligadas'}',
    ].join(' · ');

    return SiteCard(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Text('Campo', style: TextStyle(color: c.text, fontWeight: FontWeight.bold, fontSize: 16)),
          subtitle: Text(summary, style: TextStyle(color: c.muted, fontSize: 12)),
          children: [
            Row(
              children: [
                Expanded(
                  child: _Labeled(
                    label: 'Batalha',
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: field.gameType,
                      items: const [
                        DropdownMenuItem(value: 'Singles', child: Text('Simples')),
                        DropdownMenuItem(value: 'Doubles', child: Text('Dupla')),
                      ],
                      onChanged: (v) => change(() => field.gameType = v ?? 'Singles'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Labeled(
                    label: 'Spikes no defensor',
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: field.spikes,
                      items: [
                        for (var n = 0; n <= 3; n++)
                          DropdownMenuItem(value: n, child: Text(n == 0 ? 'Nenhum' : '$n camada${n > 1 ? 's' : ''}')),
                      ],
                      onChanged: (v) => change(() => field.spikes = v ?? 0),
                    ),
                  ),
                ),
              ],
            ),
            _Labeled(
              label: 'Clima',
              child: DropdownButton<String>(
                isExpanded: true,
                value: field.weather,
                items: [for (final (v, l) in _weathers) DropdownMenuItem(value: v, child: Text(l))],
                onChanged: (v) => change(() => field.weather = v ?? ''),
              ),
            ),
            _Labeled(
              label: 'Terreno',
              child: DropdownButton<String>(
                isExpanded: true,
                value: field.terrain,
                items: [for (final (v, l) in _terrains) DropdownMenuItem(value: v, child: Text(l))],
                onChanged: (v) => change(() => field.terrain = v ?? ''),
              ),
            ),
            toggles('Campo todo', _fieldToggles),
            toggles('Lado do atacante', _attackerToggles),
            toggles('Lado do defensor', _defenderToggles),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- peças

class _Labeled extends StatelessWidget {
  final String label;
  final Widget child;
  const _Labeled({required this.label, required this.child});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(color: SiteColors.of(context).muted, fontSize: 12, fontWeight: FontWeight.w600)),
            child,
          ],
        ),
      );
}

class _Inline extends StatelessWidget {
  final String label;
  final Widget child;
  const _Inline({required this.label, required this.child});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: SiteColors.of(context).text, fontSize: 14)),
          const SizedBox(width: 6),
          child,
        ],
      );
}

class _CheckChip extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  const _CheckChip({required this.label, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: value,
              visualDensity: VisualDensity.compact,
              onChanged: onChanged == null ? null : (v) => onChanged!(v ?? false),
            ),
            Flexible(child: Text(label, style: TextStyle(color: SiteColors.of(context).text, fontSize: 14))),
            const SizedBox(width: 4),
          ],
        ),
      );
}

class _Stepper extends StatelessWidget {
  final int value, min, max;
  final ValueChanged<int> onChanged;
  const _Stepper({required this.value, required this.min, required this.max, required this.onChanged});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text('$value', style: TextStyle(color: SiteColors.of(context).text, fontWeight: FontWeight.bold, fontSize: 16)),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      );
}

/// Botão que mostra o valor e abre a busca (habilidades e itens).
class _PickerButton extends StatelessWidget {
  final String value;
  final String empty;
  final VoidCallback onTap;
  const _PickerButton({required this.value, required this.empty, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            Expanded(
              child: Text(value.isEmpty ? empty : value,
                  style: TextStyle(color: value.isEmpty ? c.muted : c.text, fontWeight: FontWeight.w600)),
            ),
            Icon(Icons.search, size: 18, color: c.muted),
          ],
        ),
      ),
    );
  }
}

