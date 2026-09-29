// lib/screens/tools/type_chart_screen.dart
//
// Tabela de tipos: escolha 1 ou 2 tipos para ver fraquezas e resistências, e
// a tabela inteira (ataque × defesa) logo abaixo.

import 'package:flutter/material.dart' hide Text;

import '../../i18n/text.dart';
import '../../services/battle.dart';
import '../../services/local_database.dart';
import '../../utils/pokemon_colors.dart';
import '../../utils/responsive.dart';
import '../../utils/site_ui.dart';
import '../../utils/string_extensions.dart';
import '../../utils/team_analysis.dart';

class TypeChartScreen extends StatefulWidget {
  const TypeChartScreen({super.key});

  @override
  State<TypeChartScreen> createState() => _TypeChartScreenState();
}

class _TypeChartScreenState extends State<TypeChartScreen> {
  Map<String, Map<String, List<String>>>? _chart;
  List<String> _picked = ['fire'];

  static const _groups = [
    (4.0, 'Muito fraco (×4)', Color(0xFFB91C1C)),
    (2.0, 'Fraco (×2)', Color(0xFFEF4444)),
    (0.5, 'Resiste (×½)', Color(0xFF22C55E)),
    (0.25, 'Resiste muito (×¼)', Color(0xFF15803D)),
    (0.0, 'Imune (×0)', Color(0xFF64748B)),
  ];

  @override
  void initState() {
    super.initState();
    LocalDatabase.instance.typeChart().then((c) {
      if (mounted) setState(() => _chart = c);
    });
  }

  void _toggle(String t) => setState(() {
        if (_picked.contains(t)) {
          if (_picked.length > 1) _picked = _picked.where((x) => x != t).toList();
        } else {
          _picked = [..._picked.length == 2 ? _picked.sublist(1) : _picked, t];
        }
      });

  Widget _badge(String t, {double size = 11}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: getColorForType(t), borderRadius: BorderRadius.circular(20)),
        child: Text(t.capitalise(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: size)),
      );

  @override
  Widget build(BuildContext context) {
    final chart = _chart;
    final c = SiteColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tabela de tipos')),
      body: chart == null
          ? const Center(child: CircularProgressIndicator())
          : ReadableWidth(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Escolha 1 ou 2 tipos (defesa):', style: TextStyle(color: c.muted)),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.6,
                    children: [
                      for (final t in allTypes)
                        Opacity(
                          opacity: _picked.contains(t) ? 1 : 0.45,
                          child: Material(
                            color: getColorForType(t),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: _picked.contains(t) ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _toggle(t),
                              child: Center(
                                child: Text(t.capitalise(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  for (final (mult, label, color) in _groups)
                    Builder(builder: (context) {
                      final list = allTypes.where((t) => Battle.effectiveness(t, _picked, chart) == mult).toList();
                      if (list.isEmpty) return const SizedBox.shrink();
                      return SiteCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Wrap(spacing: 6, runSpacing: 6, children: [for (final t in list) _badge(t)]),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 16),
                  Text('Tabela completa: linha = tipo do golpe, coluna = tipo de quem recebe.',
                      style: TextStyle(color: c.muted, fontSize: 12)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const SizedBox(width: 64),
                          for (final d in allTypes)
                            SizedBox(
                              width: 26,
                              height: 64,
                              child: RotatedBox(
                                quarterTurns: 3,
                                child: Text(d.capitalise(),
                                    style: TextStyle(color: getColorForType(d), fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),
                        ]),
                        for (final a in allTypes)
                          Row(children: [
                            SizedBox(
                              width: 64,
                              child: Text(a.capitalise(),
                                  style: TextStyle(color: getColorForType(a), fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                            for (final d in allTypes) _cell(Battle.effectiveness(a, [d], chart), c),
                          ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _cell(double v, SiteColors c) {
    final (text, color) = switch (v) {
      0 => ('0', const Color(0xFF334155)),
      0.5 => ('½', const Color(0xFF15803D)),
      2 => ('2', const Color(0xFFDC2626)),
      _ => ('', c.surface),
    };
    return Container(
      width: 24,
      height: 24,
      margin: const EdgeInsets.all(1),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
    );
  }
}
