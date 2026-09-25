// lib/widgets/team_analysis_view.dart
//
// Análise do time (igual à do site) e as estrelas da nota da comunidade.

import 'package:flutter/material.dart';

import '../utils/site_ui.dart';
import '../utils/team_analysis.dart';

class TeamAnalysisView extends StatelessWidget {
  final TeamAnalysis? analysis;
  const TeamAnalysisView({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final a = analysis;
    if (a == null) return Text('Adicione Pokémon para ver a análise.', style: TextStyle(color: c.muted));

    Widget section(String title, String hint, Widget? child, String empty) => Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: c.text, fontWeight: FontWeight.bold)),
              Text(hint, style: TextStyle(color: c.muted, fontSize: 12)),
              const SizedBox(height: 8),
              child ?? Text(empty, style: TextStyle(color: c.muted)),
            ],
          ),
        );

    Widget row(String type, bool bad) => Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: (bad ? Colors.red : Colors.green).withAlpha(25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: (bad ? Colors.red : Colors.green).withAlpha(100)),
          ),
          child: Row(
            children: [
              TypeBadge(type, small: true),
              const SizedBox(width: 8),
              Expanded(child: Text(a.rows[type]!.summary, style: TextStyle(color: c.text, fontSize: 13))),
            ],
          ),
        );

    final advantages = a.advantages.entries.toList()..sort((x, y) => y.value.compareTo(x.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (good, text) in a.tips)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('${good ? '✅' : '⚠️'} $text',
                style: TextStyle(
                    color: good ? Colors.greenAccent.shade400 : Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        section(
          'Fraquezas',
          'Tipos em que o time tem mais Pokémon fracos do que Pokémon que aguentam.',
          a.weaknesses.isEmpty ? null : Column(children: [for (final t in a.weaknesses) row(t, true)]),
          'Nenhuma 🎉',
        ),
        section(
          'Defesa forte',
          'Tipos que pelo menos 2 Pokémon aguentam (resistem ou são imunes).',
          a.strengths.isEmpty ? null : Column(children: [for (final t in a.strengths) row(t, false)]),
          'Nenhuma',
        ),
        section(
          'Ataque',
          'Quantos Pokémon acertam cada tipo com dano super efetivo usando golpes do próprio tipo (STAB).',
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final e in advantages)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TypeBadge(e.key, small: true),
                    const SizedBox(width: 2),
                    Text('${e.value}×', style: TextStyle(color: c.muted, fontSize: 12)),
                  ],
                ),
            ],
          ),
          '',
        ),
        section(
          'Sem cobertura',
          'Nenhum Pokémon acerta estes tipos com dano super efetivo (STAB).',
          a.missing.isEmpty
              ? null
              : Wrap(spacing: 6, runSpacing: 6, children: [for (final t in a.missing) TypeBadge(t, small: true)]),
          'Nenhum 🎉',
        ),
      ],
    );
  }
}

/// Estrelas da nota: só mostra, ou deixa votar com `onRate`.
class StarRating extends StatelessWidget {
  final double value;
  final ValueChanged<int>? onRate;
  final double size;
  const StarRating({super.key, required this.value, this.onRate, this.size = 26});

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var n = 1; n <= 5; n++)
          GestureDetector(
            onTap: onRate == null ? null : () => onRate!(n),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Icon(
                value >= n
                    ? Icons.star_rounded
                    : value >= n - 0.5
                        ? Icons.star_half_rounded
                        : Icons.star_outline_rounded,
                color: value >= n - 0.5 ? Colors.amber : c.muted,
                size: size,
              ),
            ),
          ),
      ],
    );
  }
}

/// "★ 4,3 (12 votos)" ou "Sem notas ainda".
class RatingText extends StatelessWidget {
  final double? rating;
  final int count;
  const RatingText({super.key, required this.rating, required this.count});

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    if (count == 0 || rating == null) return Text('Sem notas ainda', style: TextStyle(color: c.muted, fontSize: 13));
    return Text.rich(
      TextSpan(children: [
        TextSpan(
            text: '★ ${rating!.toStringAsFixed(1).replaceAll('.', ',')} ',
            style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
        TextSpan(text: '($count ${count == 1 ? 'voto' : 'votos'})', style: TextStyle(color: c.muted)),
      ]),
      style: const TextStyle(fontSize: 13),
    );
  }
}
