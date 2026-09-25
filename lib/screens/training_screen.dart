// lib/screens/training_screen.dart
//
// Centro de Treinamento no estilo do site: um card colorido para cada
// ferramenta (Natures, Breeding e Contador de EVs).

import 'package:flutter/material.dart';

import '../utils/responsive.dart';
import '../utils/site_ui.dart';
import 'breeding_help_screen.dart';
import 'ev_counter_screen.dart';
import 'nature_guide_screen.dart';

class TrainingScreen extends StatelessWidget {
  const TrainingScreen({super.key});

  void _open(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Treino')),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const PageHeader(
              title: 'Centro de Treinamento',
              subtitle: 'Ferramentas para treinadores que buscam o Pokémon perfeito.',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  ToolCard(
                    icon: Icons.help_outline,
                    title: 'Guia de Natures',
                    subtitle: 'Veja como cada Nature afeta os status',
                    color: const Color(0xFF42A5F5),
                    onTap: () => _open(context, const NatureGuideScreen()),
                  ),
                  const SizedBox(height: 14),
                  ToolCard(
                    icon: Icons.favorite,
                    title: 'Ajuda de Criação (Breeding)',
                    subtitle: 'Encontre parceiros compatíveis',
                    color: const Color(0xFFEC407A),
                    onTap: () => _open(context, const BreedingHelpScreen()),
                  ),
                  const SizedBox(height: 14),
                  ToolCard(
                    icon: Icons.fitness_center,
                    title: 'Contador de EVs',
                    subtitle: 'Acompanhe o treino dos seus Pokémon',
                    color: const Color(0xFF66BB6A),
                    onTap: () => _open(context, const EvCounterScreen()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
