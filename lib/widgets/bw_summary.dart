// lib/widgets/bw_summary.dart
//
// Os dados de um Pokémon como no Black & White (a tela "Dados" do time):
// nome, nível, tipos, HP, status, habilidade, item, atributos (com os
// estágios da batalha) e os golpes com PP. Igual ao site
// (web-site/src/components/BwSummary.jsx).

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as mt show Text;

import '../i18n/text.dart';
import 'pokemon_sprite.dart';
import 'type_chip.dart';

class SummaryMove {
  const SummaryMove(this.name, this.type, this.pp, this.maxPp);
  final String name, type;
  final int pp, maxPp;
}

class SummaryData {
  const SummaryData({
    required this.id,
    this.shiny = false,
    required this.name,
    required this.level,
    required this.hp,
    required this.maxHp,
    this.status = '',
    this.types = const [],
    this.ability = '',
    this.item = '',
    this.stats = const {},
    this.boosts = const {},
    this.moves = const [],
  });
  final int id, level, hp, maxHp;
  final bool shiny;
  final String name, status, ability, item;
  final List<String> types;
  final Map<String, int> stats, boosts;
  final List<SummaryMove> moves;
}

/// Os nomes dos atributos (na ordem do jogo).
const summaryStats = [('atk', 'Ataque'), ('def', 'Defesa'), ('spa', 'At. Esp.'), ('spd', 'Def. Esp.'), ('spe', 'Velocidade')];

class BwSummary extends StatelessWidget {
  const BwSummary(this.data, {super.key, required this.onBack, this.onSwitch, this.extra});
  final SummaryData data;
  final VoidCallback onBack;

  /// Algo a mais antes dos botões (ex.: os itens e as opções do Pokémon no time da Battle Factory).
  final Widget? extra;

  /// Trocar por ele (só quando dá).
  final VoidCallback? onSwitch;

  static const _ink = Color(0xFF0F172A);

  Widget _row(String label, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(children: [
          SizedBox(width: 86, child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))),
          // Habilidade e item: nomes do jogo (não traduz).
          Expanded(child: _value(value, color: color)),
        ]),
      );

  static Widget _value(String value, {Color? color}) => mt.Text(value,
      overflow: TextOverflow.ellipsis, style: TextStyle(color: color ?? const Color(0xFFFDE68A), fontSize: 12, fontWeight: FontWeight.w900));

  @override
  Widget build(BuildContext context) {
    final d = data;
    final hp = d.maxHp > 0 ? (d.hp / d.maxHp).clamp(0.0, 1.0) : 0.0;
    return Container(
      key: const ValueKey('bw-summary'),
      padding: const EdgeInsets.all(8),
      color: const Color(0xFF1F6F78),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: const Color(0xFF0F3D44), border: Border.all(color: const Color(0xFF0B2A2F), width: 2), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Expanded(child: mt.Text(d.name, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15))),
            mt.Text('Lv${d.level}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ]),
        ),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(color: const Color(0xFFBDE7F0), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF0F3D5C), width: 2)),
            child: PokemonSprite(d.id, shiny: d.shiny, fill: 0.85),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 4, runSpacing: 4, children: [for (final t in d.types) TypeChip(t)]),
              const SizedBox(height: 4),
              Row(children: [
                const Text('HP', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(3)),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                        widthFactor: hp,
                        child: Container(
                            decoration: BoxDecoration(
                                color: hp > 0.5 ? const Color(0xFF34D399) : hp > 0.2 ? const Color(0xFFFBBF24) : const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(3)))),
                  ),
                ),
                const SizedBox(width: 4),
                mt.Text('${d.hp}/${d.maxHp}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
              ]),
              if (d.status.isNotEmpty && d.hp > 0) _row(tr('Status'), d.status.toUpperCase(), color: const Color(0xFFC4B5FD)),
              if (d.ability.isNotEmpty) _row(tr('Habilidade'), d.ability),
              _row(tr('Item'), d.item.isEmpty || d.item == 'No Item' ? '—' : d.item),
            ]),
          ),
        ]),
        const SizedBox(height: 6),
        // Os atributos (com os estágios da batalha: ▲ subiu, ▼ caiu).
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF0F3D5C), width: 2)),
          child: Column(children: [
            for (final (key, label) in summaryStats)
              Row(children: [
                Expanded(child: Text(label, style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w800))),
                if ((d.boosts[key] ?? 0) != 0)
                  mt.Text('${d.boosts[key]! > 0 ? '▲' : '▼'}${d.boosts[key]!.abs()} ',
                      style: TextStyle(color: d.boosts[key]! > 0 ? const Color(0xFFDC2626) : const Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.w900)),
                mt.Text('${d.stats[key] ?? '—'}', style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w900)),
              ]),
          ]),
        ),
        const SizedBox(height: 6),
        for (final mv in d.moves)
          Container(
            margin: const EdgeInsets.only(bottom: 3),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF0F3D5C), width: 2)),
            child: Row(children: [
              if (mv.type.isNotEmpty) TypeChip(mv.type),
              const SizedBox(width: 6),
              // Nome do golpe como no jogo (não traduz).
              Expanded(child: mt.Text(mv.name, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w900))),
              mt.Text('PP ${mv.pp}/${mv.maxPp}', style: const TextStyle(color: _ink, fontSize: 11, fontWeight: FontWeight.w800)),
            ]),
          ),
        if (extra != null) Padding(padding: const EdgeInsets.only(top: 3), child: extra),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          if (onSwitch != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilledButton(
                key: const ValueKey('bw-summary-switch'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A), visualDensity: VisualDensity.compact),
                onPressed: onSwitch,
                child: Text(tr('TROCAR'), style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          FilledButton(
            key: const ValueKey('bw-summary-back'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626), visualDensity: VisualDensity.compact),
            onPressed: onBack,
            child: Text('✕ ${tr('Voltar')}', style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ]),
      ]),
    );
  }
}
