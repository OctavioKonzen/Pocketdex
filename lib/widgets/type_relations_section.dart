// lib/widgets/type_relations_section.dart
//
// Grupo de etiquetas de tipo (fraquezas, resistências...) no estilo do site.

import 'package:flutter/material.dart';

import '../utils/pokemon_colors.dart';
import '../utils/site_ui.dart';
import '../utils/string_extensions.dart';

class TypeRelationsSection extends StatelessWidget {
  final String title;

  /// Map<String, double> (multiplicador), Map<String, int> (quantos) ou List<String>.
  final dynamic relations;

  const TypeRelationsSection({super.key, required this.title, required this.relations});

  Widget _badge(String type, [String? suffix]) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(color: getColorForType(type), borderRadius: BorderRadius.circular(30)),
        child: Text('${type.capitalise()}${suffix == null ? '' : ' ×$suffix'}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      );

  @override
  Widget build(BuildContext context) {
    final List<Widget> badges;
    if (relations is Map<String, double>) {
      badges = [
        for (final e in (relations as Map<String, double>).entries)
          _badge(e.key, e.value.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')),
      ];
    } else if (relations is Map<String, int>) {
      badges = [for (final e in (relations as Map<String, int>).entries) _badge(e.key, '${e.value}')];
    } else if (relations is List<String>) {
      badges = [for (final t in relations as List<String>) _badge(t)];
    } else {
      badges = const [];
    }
    if (badges.isEmpty) return const SizedBox.shrink();

    final c = SiteColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: c.text, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: badges),
      ],
    );
  }
}
