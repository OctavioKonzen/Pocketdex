// lib/widgets/type_relations_section.dart

import 'package:flutter/material.dart';
import '../utils/pokemon_colors.dart';

class TypeRelationsSection extends StatelessWidget {
  final String title;
  final dynamic relations;

  const TypeRelationsSection({
    super.key,
    required this.title,
    required this.relations,
  });

  String _capitalise(String text) {
    if (text.isEmpty) {
      return "";
    }
    return "${text[0].toUpperCase()}${text.substring(1)}";
  }

  @override
  Widget build(BuildContext context) {
    if (relations == null || relations.isEmpty) {
      return const SizedBox.shrink();
    }

    List<Widget> buildChips() {
      if (relations is Map<String, double>) {
        return relations.entries.map<Widget>((entry) {
          final type = entry.key;
          final multiplier = entry.value.toStringAsFixed(1).replaceAll('.0', '');
          return Chip(
            label: Text('${_capitalise(type)} (x$multiplier)'),
            backgroundColor: getColorForType(type).withAlpha(200),
            labelStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          );
        }).toList();
      }
      else if (relations is Map<String, int>) {
         return relations.entries.map<Widget>((entry) {
          final type = entry.key;
          final count = entry.value;
          return Chip(
            label: Text('${_capitalise(type)} (x$count)'),
            backgroundColor: getColorForType(type).withAlpha(200),
            labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          );
        }).toList();
      }
      else if (relations is List<String>) {
        return relations.map<Widget>((type) {
          return Chip(
            label: Text(_capitalise(type)),
            backgroundColor: getColorForType(type).withAlpha(200),
            labelStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          );
        }).toList();
      }
      return [];
    }

    final chips = buildChips();

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: chips,
        ),
      ],
    );
  }
}