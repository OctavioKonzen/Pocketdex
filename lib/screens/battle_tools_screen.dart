// lib/screens/battle_tools_screen.dart
//
// Ferramentas de batalha do Treino (as mesmas do site):
//   • Comparar 2 Pokémon: status base lado a lado, total e fraquezas;
//   • a calculadora de dano fica em damage_calc_screen.dart e usa o
//     PickedPokemon e o PokemonSlot daqui.

import 'package:flutter/material.dart' hide Text;

import '../services/account_format.dart';
import '../services/battle.dart';
import '../services/local_database.dart';
import '../utils/pokemon_colors.dart';
import '../utils/responsive.dart';
import '../utils/site_ui.dart';
import '../utils/string_extensions.dart';
import '../widgets/pokemon_sprite.dart';
import 'pokedex_screen.dart';
import 'package:pocket_dex/i18n/text.dart';

const _statLabels = ['HP', 'Attack', 'Defense', 'Sp. Atk', 'Sp. Def', 'Speed'];

/// Pokémon escolhido, com os dados do banco (tipos, status, golpes,
/// habilidades e peso em hectogramas).
class PickedPokemon {
  final int id;
  final String name;
  final List<String> types;
  final List<int> stats;
  final List<String> moves;
  final List<String> abilities;
  final int weight;
  const PickedPokemon(this.id, this.name, this.types, this.stats, this.moves, {this.abilities = const [], this.weight = 1000});

  String get label => name.replaceAll('-', ' ').capitalise();

  static Future<PickedPokemon?> choose(BuildContext context) async {
    final picked = await Navigator.push<Map<String, String>?>(
      context,
      MaterialPageRoute(builder: (_) => const PokedexScreen(isForTeamSelection: true)),
    );
    if (picked == null) return null;
    final id = AccountFormat.pokemonIdFromImage(picked['imageUrl']) ?? int.tryParse(picked['id'] ?? '');
    if (id == null) return null;
    final row = await LocalDatabase.instance.pokemonRow(id);
    if (row == null) return null;
    return PickedPokemon(
      id,
      row['name'] as String,
      (row['types'] as List).cast<String>(),
      [for (final s in row['stats'] as List) (s as List).first as int],
      {for (final m in row['moves'] as List) (m as List).first as String}.toList(),
      abilities: [for (final a in (row['abilities'] as List?) ?? const []) (a as List).first as String],
      weight: (row['weight'] as num?)?.toInt() ?? 1000,
    );
  }
}

Color _typeColor(String type) => pokemonTypeColors[type] ?? const Color(0xFF616161);

LinearGradient _typeGradient(List<String> types) {
  final a = _typeColor(types.first);
  final b = types.length > 1 ? _typeColor(types[1]) : Color.lerp(a, Colors.black, 0.25)!;
  return LinearGradient(colors: [a, b], begin: Alignment.topLeft, end: Alignment.bottomRight);
}

class PokemonSlot extends StatelessWidget {
  final PickedPokemon? pokemon;
  final String label;
  final VoidCallback onTap;
  const PokemonSlot({required this.pokemon, required this.label, required this.onTap});

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
  PickedPokemon? _left;
  PickedPokemon? _right;
  Map<String, Map<String, List<String>>>? _chart;

  @override
  void initState() {
    super.initState();
    LocalDatabase.instance.typeChart().then((c) => mounted ? setState(() => _chart = c) : null);
  }

  Future<void> _pick(bool left) async {
    final p = await PickedPokemon.choose(context);
    if (p == null || !mounted) return;
    setState(() => left ? _left = p : _right = p);
  }

  List<MapEntry<String, double>> _weak(PickedPokemon p) {
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
                Expanded(child: PokemonSlot(pokemon: a, label: 'Escolher Pokémon', onTap: () => _pick(true))),
                const SizedBox(width: 12),
                Expanded(child: PokemonSlot(pokemon: b, label: 'Escolher Pokémon', onTap: () => _pick(false))),
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

