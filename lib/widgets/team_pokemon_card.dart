// lib/widgets/team_pokemon_card.dart
//
// Espaço de um Pokémon no Montador de Times (igual ao site): card com a cor
// do tipo e o Pokémon, ou um espaço tracejado com "+" para adicionar.

import 'package:flutter/material.dart';

import '../services/account_format.dart';
import '../services/pokemon_service.dart';
import '../utils/pokemon_colors.dart';
import '../utils/site_ui.dart';
import '../utils/string_extensions.dart';
import 'pokemon_sprite.dart';

class TeamPokemonCard extends StatefulWidget {
  final Map<String, String>? pokemonData;
  final VoidCallback onTap;

  const TeamPokemonCard({super.key, required this.pokemonData, required this.onTap});

  @override
  State<TeamPokemonCard> createState() => _TeamPokemonCardState();
}

class _TeamPokemonCardState extends State<TeamPokemonCard> {
  Future<Map<String, dynamic>?>? _details;

  int? get _pokemonId {
    final p = widget.pokemonData;
    if (p == null) return null;
    return AccountFormat.pokemonIdFromImage(p['imageUrl']) ?? int.tryParse(p['id'] ?? '');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TeamPokemonCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pokemonData?['imageUrl'] != oldWidget.pokemonData?['imageUrl']) _load();
  }

  void _load() {
    final id = _pokemonId;
    _details = id == null ? null : PokemonService().fetchPokemonJson('$id').then<Map<String, dynamic>?>((d) => d).catchError((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final id = _pokemonId;
    if (id == null) {
      return InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(18),
        child: CustomPaint(
          painter: _DashedBorder(color: c.muted.withAlpha(140)),
          child: Center(child: Icon(Icons.add, color: c.muted, size: 36)),
        ),
      );
    }
    return FutureBuilder<Map<String, dynamic>?>(
      future: _details,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final types = data == null ? <String>[] : [for (final t in data['types'] as List) t['type']['name'] as String];
        final name = (data?['name'] as String? ?? '').split('-').first.capitalise();
        return GestureDetector(
          onTap: widget.onTap,
          child: Container(
            decoration: typeBackground(types, borderRadius: BorderRadius.circular(18)).copyWith(
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 3))],
            ),
            child: Column(
              children: [
                Expanded(child: Padding(padding: const EdgeInsets.all(6), child: PokemonSprite(id, fill: 0.85))),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
                  child: Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 3)])),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DashedBorder extends CustomPainter {
  final Color color;
  _DashedBorder({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)));
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 12) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}
