// lib/screens/battle_center_screen.dart
//
// Centro de Batalha (igual ao site, BattlePage.jsx): as ferramentas de
// batalha num lugar só — dano, comparar, velocidade, quem vence, tipos e
// Tera Raids. As de treino (EVs, IVs, Natures, criação...) ficam no Treino.

import 'package:flutter/material.dart' hide Text;

import '../i18n/text.dart';
import '../utils/responsive.dart';
import '../utils/site_ui.dart';
import 'battle_tools_screen.dart';
import 'damage_calc_screen.dart';
import 'tools/counters_screen.dart';
import 'tools/speed_tiers_screen.dart';
import 'tools/tera_raid_screen.dart';
import 'tools/type_chart_screen.dart';

class BattleCenterScreen extends StatelessWidget {
  const BattleCenterScreen({super.key});

  void _open(BuildContext context, Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final tools = [
      (Icons.flash_on, 'Calculadora de dano', 'Quanto um golpe tira do outro', const Color(0xFFEF5350), const DamageCalcScreen()),
      (Icons.shield, 'Quem vence?', 'Quem ganha de um Pokémon 1 contra 1', const Color(0xFF14B8A6), const CountersScreen()),
      (Icons.speed, 'Faixas de velocidade', 'Quem ataca primeiro, com Scarf, Tailwind...', const Color(0xFFF97316), const SpeedTiersScreen()),
      (Icons.compare_arrows, 'Comparar Pokémon', 'Status e fraquezas lado a lado', const Color(0xFF7E57C2), const CompareScreen()),
      (Icons.grid_on, 'Tabela de tipos', 'Fraquezas e resistências de cada tipo', const Color(0xFF5C6BC0), const TypeChartScreen()),
      (Icons.diamond, 'Tera Raids', 'Os melhores Pokémon contra cada chefe', const Color(0xFFDB2777), const TeraRaidScreen()),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Batalha')),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const PageHeader(title: 'Centro de Batalha', subtitle: 'Ferramentas para vencer as batalhas.'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (final (icon, title, subtitle, color, screen) in tools) ...[
                    ToolCard(icon: icon, title: title, subtitle: subtitle, color: color, onTap: () => _open(context, screen)),
                    const SizedBox(height: 14),
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
