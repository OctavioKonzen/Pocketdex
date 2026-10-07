// lib/screens/battle_center_screen.dart
//
// Centro de Batalha (igual ao site, BattlePage.jsx), em três partes:
//   • Batalhar: contra o computador, online com amigos e draft;
//   • Preparar o time: dano, quem vence, velocidade e comparar;
//   • Consultar: tabela de tipos e Tera Raids.
// As de treino (EVs, IVs, Natures, criação...) ficam no Treino.

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;

import '../i18n/text.dart';
import '../utils/responsive.dart';
import '../utils/site_ui.dart';
import 'battle_tools_screen.dart';
import 'damage_calc_screen.dart';
import 'draft_screen.dart';
import 'online_battle_screen.dart';
import 'tools/counters_screen.dart';
import 'tools/speed_tiers_screen.dart';
import 'tools/tera_raid_screen.dart';
import 'tools/type_chart_screen.dart';
import 'turn_battle_screen.dart';

class BattleCenterScreen extends StatelessWidget {
  const BattleCenterScreen({super.key});

  void _open(BuildContext context, Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.6, color: Color(0xFF94A3B8))),
      );

  Widget _mode(BuildContext context, String emoji, String title, String subtitle, List<Color> colors, Widget screen) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Material(
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: InkWell(
              key: ValueKey('battle-mode-$title'),
              onTap: () => _open(context, screen),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  m.Text(emoji, style: const TextStyle(fontSize: 32)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                      Text(subtitle, style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white),
                ]),
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final prepare = [
      (Icons.flash_on, 'Calculadora de dano', 'Quanto um golpe tira do outro', const Color(0xFFEF5350), const DamageCalcScreen()),
      (Icons.shield, 'Quem vence?', 'Quem ganha de um Pokémon 1 contra 1', const Color(0xFF14B8A6), const CountersScreen()),
      (Icons.speed, 'Faixas de velocidade', 'Quem ataca primeiro, com Scarf, Tailwind...', const Color(0xFFF97316), const SpeedTiersScreen()),
      (Icons.compare_arrows, 'Comparar Pokémon', 'Status e fraquezas lado a lado', const Color(0xFF7E57C2), const CompareScreen()),
    ];
    final consult = [
      (Icons.grid_on, 'Tabela de tipos', 'Fraquezas e resistências de cada tipo', const Color(0xFF5C6BC0), const TypeChartScreen()),
      (Icons.diamond, 'Tera Raids', 'Os melhores Pokémon contra cada chefe', const Color(0xFFDB2777), const TeraRaidScreen()),
    ];
    List<Widget> tools(List<(IconData, String, String, Color, Widget)> list) => [
          for (final (icon, title, subtitle, color, screen) in list)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: ToolCard(icon: icon, title: title, subtitle: subtitle, color: color, onTap: () => _open(context, screen)),
            ),
        ];
    return Scaffold(
      appBar: AppBar(title: const Text('Batalha')),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const PageHeader(title: 'Centro de Batalha', subtitle: 'Batalhe e prepare o seu time.'),
            _title(tr('BATALHAR')),
            _mode(context, '🎮', 'Contra o computador', 'Individual, dupla ou tripla, com o seu time ou um aleatório',
                const [Color(0xFFDC2626), Color(0xFF9333EA)], const TurnBattleScreen()),
            _mode(context, '🌐', 'Online com amigos', 'Convide amigos e batalhem ao vivo', const [Color(0xFF0284C7), Color(0xFF4F46E5)], const OnlineBattleScreen()),
            _mode(context, '🎯', 'Draft', 'Você e um amigo escolhem Pokémon um de cada vez e batalham',
                const [Color(0xFFF59E0B), Color(0xFFEA580C)], const DraftsScreen()),
            _title(tr('PREPARAR O TIME')),
            ...tools(prepare),
            _title(tr('CONSULTAR')),
            ...tools(consult),
          ],
        ),
      ),
    );
  }
}
