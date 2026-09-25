// lib/screens/battle_tools_screen.dart
//
// Ferramentas de batalha do Treino (as mesmas do site):
//   • Comparar 2 Pokémon: status base lado a lado, total e fraquezas;
//   • Calculadora de dano: quanto um golpe do atacante tira do defensor
//     (nível 50, IVs máximos, Nature neutra — lib/services/battle.dart).

import 'package:flutter/material.dart';

import '../services/account_format.dart';
import '../services/battle.dart';
import '../services/local_database.dart';
import '../utils/pokemon_colors.dart';
import '../utils/responsive.dart';
import '../utils/site_ui.dart';
import '../utils/string_extensions.dart';
import '../widgets/pokemon_sprite.dart';
import 'pokedex_screen.dart';

const _statLabels = ['HP', 'Attack', 'Defense', 'Sp. Atk', 'Sp. Def', 'Speed'];

/// Pokémon escolhido, com os dados do banco (tipos, status e golpes).
class _Picked {
  final int id;
  final String name;
  final List<String> types;
  final List<int> stats;
  final List<String> moves;
  const _Picked(this.id, this.name, this.types, this.stats, this.moves);

  String get label => name.replaceAll('-', ' ').capitalise();

  static Future<_Picked?> choose(BuildContext context) async {
    final picked = await Navigator.push<Map<String, String>?>(
      context,
      MaterialPageRoute(builder: (_) => const PokedexScreen(isForTeamSelection: true)),
    );
    if (picked == null) return null;
    final id = AccountFormat.pokemonIdFromImage(picked['imageUrl']) ?? int.tryParse(picked['id'] ?? '');
    if (id == null) return null;
    final row = await LocalDatabase.instance.pokemonRow(id);
    if (row == null) return null;
    return _Picked(
      id,
      row['name'] as String,
      (row['types'] as List).cast<String>(),
      [for (final s in row['stats'] as List) (s as List).first as int],
      {for (final m in row['moves'] as List) (m as List).first as String}.toList(),
    );
  }
}

Color _typeColor(String type) => pokemonTypeColors[type] ?? const Color(0xFF616161);

LinearGradient _typeGradient(List<String> types) {
  final a = _typeColor(types.first);
  final b = types.length > 1 ? _typeColor(types[1]) : Color.lerp(a, Colors.black, 0.25)!;
  return LinearGradient(colors: [a, b], begin: Alignment.topLeft, end: Alignment.bottomRight);
}

class _Slot extends StatelessWidget {
  final _Picked? pokemon;
  final String label;
  final VoidCallback onTap;
  const _Slot({required this.pokemon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final p = pokemon;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 190,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: p == null ? null : _typeGradient(p.types),
          color: p == null ? c.surface : null,
          borderRadius: BorderRadius.circular(24),
          border: p == null ? Border.all(color: c.line, width: 2) : null,
        ),
        child: p == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 40, color: c.muted),
                  const SizedBox(height: 6),
                  Text(label, textAlign: TextAlign.center, style: TextStyle(color: c.muted)),
                ],
              )
            : Column(
                children: [
                  Expanded(child: PokemonSprite(p.id, fill: 0.85)),
                  Text(p.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 4),
                  Wrap(spacing: 4, alignment: WrapAlignment.center, children: [for (final t in p.types) TypeBadge(t, small: true)]),
                ],
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------- comparar

class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});
  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  _Picked? _left;
  _Picked? _right;
  Map<String, Map<String, List<String>>>? _chart;

  @override
  void initState() {
    super.initState();
    LocalDatabase.instance.typeChart().then((c) => mounted ? setState(() => _chart = c) : null);
  }

  Future<void> _pick(bool left) async {
    final p = await _Picked.choose(context);
    if (p == null || !mounted) return;
    setState(() => left ? _left = p : _right = p);
  }

  List<MapEntry<String, double>> _weak(_Picked p) {
    final chart = _chart;
    if (chart == null) return [];
    final list = [
      for (final t in chart.keys) MapEntry(t, Battle.effectiveness(t, p.types, chart)),
    ].where((e) => e.value >= 2).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final a = _left, b = _right;
    return Scaffold(
      appBar: AppBar(title: const Text('Comparar Pokémon')),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Row(
              children: [
                Expanded(child: _Slot(pokemon: a, label: 'Escolher Pokémon', onTap: () => _pick(true))),
                const SizedBox(width: 12),
                Expanded(child: _Slot(pokemon: b, label: 'Escolher Pokémon', onTap: () => _pick(false))),
              ],
            ),
            const SizedBox(height: 16),
            if (a == null || b == null)
              Text(
                a == null && b == null ? 'Escolha dois Pokémon para comparar.' : 'Escolha o outro Pokémon para comparar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.muted),
              )
            else
              SiteCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status base', style: TextStyle(color: c.text, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    for (var i = 0; i < 6; i++) _StatRow(label: _statLabels[i], left: a.stats[i], right: b.stats[i]),
                    Divider(color: c.line),
                    _StatRow(
                      label: 'Total',
                      left: a.stats.reduce((x, y) => x + y),
                      right: b.stats.reduce((x, y) => x + y),
                      bars: false,
                    ),
                    const SizedBox(height: 12),
                    for (final p in [a, b]) ...[
                      Text('Fraquezas de ${p.label}', style: TextStyle(color: c.muted, fontSize: 13)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final e in _weak(p))
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TypeBadge(e.key, small: true),
                                const SizedBox(width: 2),
                                Text('×${e.value.toStringAsFixed(0)}',
                                    style: TextStyle(color: c.text, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final int left;
  final int right;
  final bool bars;
  const _StatRow({required this.label, required this.left, required this.right, this.bars = true});

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    TextStyle style(bool win) =>
        TextStyle(fontWeight: FontWeight.w900, color: win ? Colors.greenAccent.shade400 : c.text);
    Widget bar(int v, Color color, bool alignRight) => Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 10,
              color: c.surface,
              alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
              child: FractionallySizedBox(widthFactor: (v / 200).clamp(0.0, 1.0), child: Container(color: color)),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(width: 34, child: Text('$left', textAlign: TextAlign.right, style: style(left > right))),
          const SizedBox(width: 6),
          if (bars) bar(left, const Color(0xFF0EA5E9), true) else const Spacer(),
          SizedBox(
            width: 64,
            child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 12)),
          ),
          if (bars) bar(right, const Color(0xFFF97316), false) else const Spacer(),
          const SizedBox(width: 6),
          SizedBox(width: 34, child: Text('$right', style: style(right > left))),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- dano

const _types = [
  'normal', 'fire', 'water', 'electric', 'grass', 'ice', 'fighting', 'poison', 'ground',
  'flying', 'psychic', 'bug', 'rock', 'ghost', 'dragon', 'dark', 'steel', 'fairy',
];

String _natureLabel(String name) {
  final (up, down) = natures[name]!;
  return up == down ? '$name (neutra)' : '$name (+${_statLabels[up]} −${_statLabels[down]})';
}

/// Configuração de um lado (o que dá para mudar na calculadora).
class _SideConfig {
  int level = 50;
  String nature = 'Hardy';
  Map<String, int> evs;
  int ivs = 31;
  int stage = 0;
  String item = 'none';
  String? tera;
  bool burned = false;
  _SideConfig(this.evs);

  BattleSide toSide(_Picked p) => BattleSide(
        types: p.types,
        stats: p.stats,
        level: level,
        nature: nature,
        evs: evs,
        ivs: ivs,
        stage: stage,
        item: item,
        tera: tera,
        burned: burned,
      );
}

class DamageCalcScreen extends StatefulWidget {
  const DamageCalcScreen({super.key});
  @override
  State<DamageCalcScreen> createState() => _DamageCalcScreenState();
}

class _DamageCalcScreenState extends State<DamageCalcScreen> {
  _Picked? _attacker;
  _Picked? _defender;
  Map<String, Map<String, dynamic>>? _moves;
  Map<String, Map<String, List<String>>>? _chart;
  String? _moveName;
  final _a = _SideConfig({'atk': 252, 'spa': 252});
  final _d = _SideConfig({'hp': 0, 'def': 0, 'spd': 0});
  String _weather = 'none';
  bool _crit = false;
  bool _screen = false;
  bool _spread = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final moves = await LocalDatabase.instance.movesByName();
    final chart = await LocalDatabase.instance.typeChart();
    if (!mounted) return;
    setState(() {
      _moves = moves;
      _chart = chart;
    });
  }

  Future<void> _pick(bool attacker) async {
    final p = await _Picked.choose(context);
    if (p == null || !mounted) return;
    setState(() {
      if (attacker) {
        _attacker = p;
        _moveName = null;
      } else {
        _defender = p;
      }
    });
  }

  void _swap() => setState(() {
        final a = _attacker;
        _attacker = _defender;
        _defender = a;
        _moveName = null;
      });

  /// Golpes de dano do atacante, do que mais machuca o defensor ao que menos
  /// (poder × STAB × efetividade × Attack ou Sp. Atk) — igual ao site.
  List<Map<String, dynamic>> get _options {
    final a = _attacker, moves = _moves, chart = _chart, d = _defender;
    if (a == null || moves == null) return [];
    double score(Map<String, dynamic> m) {
      final type = m['type'] as String;
      final stab = a.types.contains(type) ? 1.5 : 1.0;
      final eff = d != null && chart != null ? Battle.effectiveness(type, d.types, chart) : 1.0;
      final stat = a.stats[m['damage_class'] == 'physical' ? 1 : 3];
      return (m['power'] as num) * stab * eff * stat;
    }

    final list = [
      for (final n in a.moves)
        if (moves[n] != null && ((moves[n]!['power'] as num?) ?? 0) > 0 && moves[n]!['damage_class'] != 'status') moves[n]!,
    ]..sort((x, y) {
        final c = score(y).compareTo(score(x));
        return c != 0 ? c : (x['name'] as String).compareTo(y['name'] as String);
      });
    return list;
  }

  static String _multText(double m) => m == 0
      ? 'Não tem efeito'
      : m >= 2
          ? 'Super efetivo'
          : m < 1
              ? 'Pouco efetivo'
              : 'Efetivo';

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final options = _options;
    final move = options.where((m) => m['name'] == _moveName).firstOrNull ?? options.firstOrNull;
    final physical = move == null || move['damage_class'] == 'physical';
    final a = _attacker, d = _defender, chart = _chart;
    final result = a != null && d != null && move != null && chart != null
        ? Battle.damage(
            attacker: _a.toSide(a),
            defender: _d.toSide(d),
            moveType: move['type'] as String,
            physical: physical,
            power: (move['power'] as num).toInt(),
            typeData: chart,
            weather: _weather,
            crit: _crit,
            screen: _screen,
            spread: _spread,
          )
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Calculadora de dano')),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text('Atacante', style: TextStyle(color: c.muted, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      _Slot(pokemon: a, label: 'Escolher atacante', onTap: () => _pick(true)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 24, 4, 0),
                  child: IconButton.filledTonal(
                    tooltip: 'Trocar atacante e defensor',
                    onPressed: a == null && d == null ? null : _swap,
                    icon: const Icon(Icons.swap_horiz),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text('Defensor', style: TextStyle(color: c.muted, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      _Slot(pokemon: d, label: 'Escolher defensor', onTap: () => _pick(false)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (a != null)
              SiteCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Golpe (os que mais machucam o defensor primeiro)',
                        style: TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: move?['name'] as String?,
                      items: [
                        for (final m in options)
                          DropdownMenuItem(
                            value: m['name'] as String,
                            child: Text(
                              '${(m['name'] as String).replaceAll('-', ' ').capitalise()} · ${m['type']} · '
                              '${m['damage_class'] == 'physical' ? 'físico' : 'especial'} · ${m['power']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => _moveName = v),
                    ),
                  ],
                ),
              ),
            if (result != null && move != null) ...[
              const SizedBox(height: 12),
              SiteCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TypeBadge(move['type'] as String, small: true),
                        Text(_multText(result.mult), style: TextStyle(color: c.text, fontWeight: FontWeight.bold)),
                        if (result.mult != 1 && result.mult != 0) Text('×${result.mult}', style: TextStyle(color: c.muted)),
                        if (result.stab)
                          Text('STAB ×${result.stabMult}',
                              style: const TextStyle(color: Color(0xFF0EA5E9), fontWeight: FontWeight.bold)),
                        if (_crit) const Text('Crítico', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('${result.minPct}% – ${result.maxPct}%',
                        style: TextStyle(color: c.text, fontSize: 32, fontWeight: FontWeight.w900)),
                    Text('${result.min}–${result.max} de ${result.hp} HP', style: TextStyle(color: c.muted, fontSize: 13)),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (result.maxPct / 100).clamp(0.0, 1.0),
                        minHeight: 14,
                        backgroundColor: c.surface,
                        valueColor: AlwaysStoppedAnimation(result.maxPct >= 100
                            ? const Color(0xFFE53935)
                            : result.maxPct >= 50
                                ? const Color(0xFFFB8C00)
                                : const Color(0xFF43A047)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(result.koText, style: TextStyle(color: c.text, fontWeight: FontWeight.bold, fontSize: 16)),
                    Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text('Detalhes', style: TextStyle(color: c.muted, fontSize: 13)),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Ataque usado: ${result.attack} · Defesa usada: ${result.defense} · HP: ${result.hp}\n'
                              'Os 16 danos possíveis: ${result.rolls.join(', ')}',
                              style: TextStyle(color: c.muted, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (a != null || d != null) ...[
              const SizedBox(height: 12),
              _SideCard(title: 'Atacante', config: _a, attacker: true, physical: physical, onChanged: () => setState(() {})),
              const SizedBox(height: 12),
              _SideCard(title: 'Defensor', config: _d, attacker: false, physical: physical, onChanged: () => setState(() {})),
              const SizedBox(height: 12),
              SiteCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Campo', style: TextStyle(color: c.text, fontWeight: FontWeight.bold, fontSize: 16)),
                    _Labeled(
                      label: 'Clima',
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _weather,
                        items: [for (final e in weathers.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                        onChanged: (v) => setState(() => _weather = v ?? 'none'),
                      ),
                    ),
                    _Check(label: 'Golpe crítico (×1.5)', value: _crit, onChanged: (v) => setState(() => _crit = v)),
                    _Check(
                      label: physical ? 'Reflect no defensor (×0.5)' : 'Light Screen no defensor (×0.5)',
                      value: _screen,
                      onChanged: (v) => setState(() => _screen = v),
                    ),
                    _Check(
                      label: 'Golpe em área em batalha dupla (×0.75)',
                      value: _spread,
                      onChanged: (v) => setState(() => _spread = v),
                    ),
                    const SizedBox(height: 6),
                    Text('Conta aproximada, igual à do jogo; não considera habilidades nem efeitos especiais de golpes.',
                        style: TextStyle(color: c.muted, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Labeled extends StatelessWidget {
  final String label;
  final Widget child;
  const _Labeled({required this.label, required this.child});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: SiteColors.of(context).muted, fontSize: 12, fontWeight: FontWeight.w600)),
            child,
          ],
        ),
      );
}

class _Check extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Check({required this.label, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        title: Text(label, style: TextStyle(color: SiteColors.of(context).text, fontSize: 14)),
      );
}

class _SideCard extends StatelessWidget {
  final String title;
  final _SideConfig config;
  final bool attacker;
  final bool physical;
  final VoidCallback onChanged;
  const _SideCard({
    required this.title,
    required this.config,
    required this.attacker,
    required this.physical,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final offKey = physical ? 'atk' : 'spa';
    final defKey = physical ? 'def' : 'spd';

    Widget number(int value, int minV, int maxV, ValueChanged<int> set) => Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: value > minV
                  ? () {
                      set(value - 1);
                      onChanged();
                    }
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text('$value', style: TextStyle(color: c.text, fontWeight: FontWeight.bold, fontSize: 16)),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: value < maxV
                  ? () {
                      set(value + 1);
                      onChanged();
                    }
                  : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        );

    Widget evSlider(String label, String key) {
      final v = config.evs[key] ?? 0;
      return _Labeled(
        label: '$label: $v',
        child: Slider(
          value: v.toDouble(),
          max: 252,
          divisions: 63,
          onChanged: (x) {
            config.evs = {...config.evs, key: x.round()};
            onChanged();
          },
        ),
      );
    }

    return SiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: c.text, fontWeight: FontWeight.bold, fontSize: 16)),
          _Labeled(
            label: 'Nível: ${config.level}',
            child: Slider(
              value: config.level.toDouble(),
              min: 1,
              max: 100,
              divisions: 99,
              onChanged: (x) {
                config.level = x.round();
                onChanged();
              },
            ),
          ),
          _Labeled(label: 'IVs (0 a 31)', child: number(config.ivs, 0, 31, (v) => config.ivs = v)),
          _Labeled(
            label: 'Nature',
            child: DropdownButton<String>(
              isExpanded: true,
              value: config.nature,
              items: [for (final n in natures.keys) DropdownMenuItem(value: n, child: Text(_natureLabel(n)))],
              onChanged: (v) {
                config.nature = v ?? 'Hardy';
                onChanged();
              },
            ),
          ),
          if (attacker)
            evSlider('EVs em ${physical ? 'Attack' : 'Sp. Atk'}', offKey)
          else ...[
            evSlider('EVs em HP', 'hp'),
            evSlider('EVs em ${physical ? 'Defense' : 'Sp. Def'}', defKey),
          ],
          Row(
            children: [
              Expanded(
                child: _Labeled(
                  label: 'Estágio',
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: config.stage,
                    items: [
                      for (var s = -6; s <= 6; s++) DropdownMenuItem(value: s, child: Text(s > 0 ? '+$s' : '$s')),
                    ],
                    onChanged: (v) {
                      config.stage = v ?? 0;
                      onChanged();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Labeled(
                  label: 'Terastal',
                  child: DropdownButton<String?>(
                    isExpanded: true,
                    value: config.tera,
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Sem Tera')),
                      for (final t in _types) DropdownMenuItem<String?>(value: t, child: Text('Tera $t')),
                    ],
                    onChanged: (v) {
                      config.tera = v;
                      onChanged();
                    },
                  ),
                ),
              ),
            ],
          ),
          _Labeled(
            label: 'Item',
            child: DropdownButton<String>(
              isExpanded: true,
              value: config.item,
              items: [
                for (final e in (attacker ? attackerItems : defenderItems).entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) {
                config.item = v ?? 'none';
                onChanged();
              },
            ),
          ),
          if (attacker)
            _Check(
              label: 'Queimado (golpes físicos tiram metade)',
              value: config.burned,
              onChanged: (v) {
                config.burned = v;
                onChanged();
              },
            ),
        ],
      ),
    );
  }
}
