// lib/widgets/base_stats.dart
//
// Aba de status do Pokémon (igual à do site, StatsTab em DetailsPanel.jsx):
// cada status base com barra colorida pelo valor, o mínimo e o máximo no
// nível 100, o total (BST) e os EVs que ele dá ao ser derrotado.

import 'package:flutter/material.dart' hide Text;

import '../i18n/text.dart';

const _keys = ['hp', 'attack', 'defense', 'special-attack', 'special-defense', 'speed'];
const _labels = ['HP', 'Attack', 'Defense', 'Sp. Atk', 'Sp. Def', 'Speed'];

/// Cor da barra pelo valor (vermelho = baixo, verde/azul = alto).
Color statColor(int value) => switch (value) {
      < 50 => const Color(0xFFF34444),
      < 80 => const Color(0xFFFF7F0F),
      < 100 => const Color(0xFFFFC928),
      < 120 => const Color(0xFFA0E515),
      < 150 => const Color(0xFF23CD5E),
      _ => const Color(0xFF00C2B8),
    };

/// Status no nível 100: mínimo (IV 0, sem EV, Nature contra) e máximo
/// (IV 31, 252 EVs, Nature a favor). O HP não muda com a Nature.
(int, int) statRange(int index, int base, {bool shedinja = false}) {
  if (index == 0) {
    if (shedinja) return (1, 1);
    return (2 * base + 110, 2 * base + 31 + 63 + 110);
  }
  final min = ((2 * base + 5) * 0.9).floor();
  final max = ((2 * base + 31 + 63 + 5) * 1.1).floor();
  return (min, max);
}

class BaseStatsView extends StatelessWidget {
  final Map<String, int> stats;
  final Map<String, int> efforts;
  final bool shedinja;
  const BaseStatsView({super.key, required this.stats, this.efforts = const {}, this.shedinja = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.hintColor;
    final values = [for (final k in _keys) stats[k] ?? 0];
    final total = values.fold(0, (a, b) => a + b);
    final evs = [
      for (var i = 0; i < 6; i++)
        if ((efforts[_keys[i]] ?? 0) > 0) '+${efforts[_keys[i]]} ${tr(_labels[i])}',
    ];
    final small = TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.bold);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SizedBox(width: 116),
              const Spacer(),
              SizedBox(width: 84, child: Text('Mín – Máx', textAlign: TextAlign.right, style: small)),
            ],
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < 6; i++) _row(context, i, values[i]),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withAlpha(14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Text('Total', style: TextStyle(color: muted, fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                Text('$total', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(width: 12),
                Expanded(
                  child: _Bar(value: total / 720, color: statColor(total ~/ 6), height: 10, delay: 6),
                ),
              ],
            ),
          ),
          if (evs.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Dá de EV:', style: TextStyle(color: muted, fontSize: 12)),
                for (final e in evs)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withAlpha(40),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Mín e máx no nível 100: de IV 0 sem EV e Nature contra até IV 31, 252 EVs e Nature a favor.',
            style: TextStyle(color: muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, int i, int value) {
    final theme = Theme.of(context);
    final (min, max) = statRange(i, value, shedinja: shedinja);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(_labels[i], style: TextStyle(color: theme.hintColor, fontWeight: FontWeight.w600)),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text('$value', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          ),
          Expanded(child: _Bar(value: value / 200, color: statColor(value), delay: i)),
          SizedBox(
            width: 84,
            child: Text('$min – $max', textAlign: TextAlign.right, style: TextStyle(color: theme.hintColor, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

/// Barra que cresce ao abrir (cada uma um pouco depois da anterior).
class _Bar extends StatelessWidget {
  final double value;
  final Color color;
  final double height;
  final int delay;
  const _Bar({required this.value, required this.color, this.height = 8, this.delay = 0});

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.onSurface.withAlpha(25);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: Duration(milliseconds: 500 + delay * 60),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Container(
        height: height,
        decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(height)),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: v,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withAlpha(200), color]),
              borderRadius: BorderRadius.circular(height),
            ),
          ),
        ),
      ),
    );
  }
}
