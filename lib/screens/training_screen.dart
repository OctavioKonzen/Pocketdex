// lib/screens/training_screen.dart
//
// Treino no estilo do site: um card com o Pokémon animado para cada
// ferramenta (Natures, Breeding, EVs, IVs, shiny e Nuzlocke). As de batalha
// (dano, comparar, velocidade...) ficam no Centro de Batalha.

import 'package:flutter/material.dart' hide Text;
import '../widgets/tool_tabs.dart';

import '../utils/responsive.dart';
import '../utils/site_ui.dart';
import 'breeding_help_screen.dart';
import 'egg_chain_screen.dart';
import 'ev_counter_screen.dart';
import 'nature_guide_screen.dart';
import 'tools/iv_calc_screen.dart';
import 'tools/nuzlocke_screen.dart';
import 'tools/shiny_hunt_screen.dart';
import 'package:pocket_dex/i18n/text.dart';

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
              eyebrow: 'Assistente competitivo',
              title: 'Treino',
              subtitle: 'Ferramentas para treinadores dedicados que buscam o Pokémon perfeito.',
            ),
            for (final (icon, title, color, pokemon, shiny, screen) in [
              (Icons.help_outline, 'Guia de Natures', const Color(0xFF42A5F5), 282, false, const NatureGuideScreen()),
              // Breeding e Golpes de ovo numa tela só, com abas.
              (Icons.favorite, 'Breeding e Golpes de ovo', const Color(0xFFEC407A), 132, false,
                  const ToolTabs(title: 'Breeding e Golpes de ovo', tabs: [('Breeding', BreedingHelpScreen()), ('Golpes de ovo', EggChainScreen())])),
              (Icons.fitness_center, 'Contador de EVs', const Color(0xFF66BB6A), 67, false, const EvCounterScreen()),
              (Icons.calculate, 'Calculadora de IVs', const Color(0xFF26A69A), 137, false, const IvCalcScreen()),
              (Icons.auto_awesome, 'Contador de shiny', const Color(0xFFF59E0B), 130, true, const ShinyHuntScreen()),
              (Icons.catching_pokemon, 'Nuzlocke', const Color(0xFF8D6E63), 104, false, const NuzlockeScreen()),
            ])
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: ModeCard(icon: icon, title: title, color: color, pokemon: pokemon, shiny: shiny, onTap: () => _open(context, screen)),
              ),
          ],
        ),
      ),
    );
  }
}
