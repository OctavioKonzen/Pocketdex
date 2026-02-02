// lib/screens/nature_guide_screen.dart

import 'package:flutter/material.dart';

class Nature {
  final String name;
  final String? increases;
  final String? decreases;

  const Nature({required this.name, this.increases, this.decreases});
}

class NatureGuideScreen extends StatelessWidget {
  const NatureGuideScreen({super.key});

  static const List<Nature> natures = [
    Nature(name: 'Hardy', increases: 'Attack', decreases: 'Attack'),
    Nature(name: 'Lonely', increases: 'Attack', decreases: 'Defense'),
    Nature(name: 'Brave', increases: 'Attack', decreases: 'Speed'),
    Nature(name: 'Adamant', increases: 'Attack', decreases: 'Sp. Atk'),
    Nature(name: 'Naughty', increases: 'Attack', decreases: 'Sp. Def'),
    Nature(name: 'Bold', increases: 'Defense', decreases: 'Attack'),
    Nature(name: 'Docile', increases: 'Defense', decreases: 'Defense'),
    Nature(name: 'Relaxed', increases: 'Defense', decreases: 'Speed'),
    Nature(name: 'Impish', increases: 'Defense', decreases: 'Sp. Atk'),
    Nature(name: 'Lax', increases: 'Defense', decreases: 'Sp. Def'),
    Nature(name: 'Timid', increases: 'Speed', decreases: 'Attack'),
    Nature(name: 'Hasty', increases: 'Speed', decreases: 'Defense'),
    Nature(name: 'Serious', increases: 'Speed', decreases: 'Speed'),
    Nature(name: 'Jolly', increases: 'Speed', decreases: 'Sp. Atk'),
    Nature(name: 'Naive', increases: 'Speed', decreases: 'Sp. Def'),
    Nature(name: 'Modest', increases: 'Sp. Atk', decreases: 'Attack'),
    Nature(name: 'Mild', increases: 'Sp. Atk', decreases: 'Defense'),
    Nature(name: 'Quiet', increases: 'Sp. Atk', decreases: 'Speed'),
    Nature(name: 'Bashful', increases: 'Sp. Atk', decreases: 'Sp. Atk'),
    Nature(name: 'Rash', increases: 'Sp. Atk', decreases: 'Sp. Def'),
    Nature(name: 'Calm', increases: 'Sp. Def', decreases: 'Attack'),
    Nature(name: 'Gentle', increases: 'Sp. Def', decreases: 'Defense'),
    Nature(name: 'Sassy', increases: 'Sp. Def', decreases: 'Speed'),
    Nature(name: 'Careful', increases: 'Sp. Def', decreases: 'Sp. Atk'),
    Nature(name: 'Quirky', increases: 'Sp. Def', decreases: 'Sp. Def'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guia de Natures'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: natures.length,
        itemBuilder: (context, index) {
          final nature = natures[index];
          final bool isNeutral = nature.increases == nature.decreases;

          return Card(
            color: theme.cardColor,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nature.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  isNeutral
                      ? Text(
                          'Neutra - Nenhum efeito',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                        )
                      : Row(
                          children: [
                            const Icon(Icons.arrow_upward, color: Colors.green, size: 18),
                            const SizedBox(width: 4),
                            Text(nature.increases!, style: theme.textTheme.bodyLarge),
                            const SizedBox(width: 24),
                            const Icon(Icons.arrow_downward, color: Colors.red, size: 18),
                            const SizedBox(width: 4),
                            Text(nature.decreases!, style: theme.textTheme.bodyLarge),
                          ],
                        ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}