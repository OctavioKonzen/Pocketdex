// lib/screens/battle_center_screen.dart
//
// Centro de Batalha (igual ao site, BattlePage.jsx), em três partes:
//   • Batalhar: contra o computador, online com amigos e o histórico;
//   • Preparar o time: dano, quem vence e comparar;
//   • Consultar: tabela de tipos e Tera Raids.
// As de treino (EVs, IVs, Natures, criação...) ficam no Treino.

import 'package:flutter/material.dart' hide Text;

import '../i18n/text.dart';
import '../utils/responsive.dart';
import '../utils/site_ui.dart';
import 'battle_history_screen.dart';
import 'battle_tools_screen.dart';
import 'damage_calc_screen.dart';
import 'online_battle_screen.dart';
import 'tools/counters_screen.dart';
import 'tools/tera_raid_screen.dart';
import 'tools/type_chart_screen.dart';
import 'turn_battle_screen.dart';

class BattleCenterScreen extends StatelessWidget {
  const BattleCenterScreen({super.key});

  void _open(BuildContext context, Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
        child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      );

  @override
  Widget build(BuildContext context) {
    final battle = [
      ('🎮', 'Contra o computador', const Color(0xFFDC2626), 448, null, const TurnBattleScreen()),
      ('🌐', 'Online com amigos', const Color(0xFF0284C7), 6, 'Ao vivo', const OnlineBattleScreen()),
      ('📜', 'Histórico e replays', const Color(0xFF059669), 65, null, const BattleHistoryScreen()),
    ];
    final prepare = [
      (Icons.flash_on, 'Calculadora de dano', const Color(0xFFEF5350), 68, const DamageCalcScreen()),
      (Icons.shield, 'Quem vence?', const Color(0xFF14B8A6), 107, const CountersScreen()),
      (Icons.compare_arrows, 'Comparar Pokémon', const Color(0xFF7E57C2), 132, const CompareScreen()),
    ];
    final consult = [
      (Icons.grid_on, 'Tabela de tipos', const Color(0xFF5C6BC0), 133, const TypeChartScreen()),
      (Icons.diamond, 'Tera Raids', const Color(0xFFDB2777), 1024, const TeraRaidScreen()),
    ];
    Widget card(Widget child) => Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: child);
    List<Widget> tools(List<(IconData, String, Color, int, Widget)> list) => [
          for (final (icon, title, color, pokemon, screen) in list)
            card(ModeCard(icon: icon, title: title, color: color, pokemon: pokemon, onTap: () => _open(context, screen))),
        ];
    return Scaffold(
      appBar: AppBar(title: const Text('Batalha')),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const PageHeader(eyebrow: 'Arena', title: 'Batalha', subtitle: 'Enfrente o computador, desafie amigos online e prepare o seu time.'),
            _title(tr('Batalhar')),
            for (final (emoji, title, color, pokemon, tag, screen) in battle)
              card(ModeCard(
                key: ValueKey('battle-mode-$title'),
                emoji: emoji,
                title: title,
                color: color,
                pokemon: pokemon,
                tag: tag,
                height: 150,
                onTap: () => _open(context, screen),
              )),
            _title(tr('Preparar o time')),
            ...tools(prepare),
            _title(tr('Consultar')),
            ...tools(consult),
          ],
        ),
      ),
    );
  }
}
