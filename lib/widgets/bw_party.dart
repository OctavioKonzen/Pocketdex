// lib/widgets/bw_party.dart
//
// A tela do time como no Black & White: os 6 em duas colunas, cada um num
// cartão com o ícone, o nome, o nível e a barra de HP; o primeiro verde e o
// escolhido laranja. Abre por cima do campo (a mesma tela), para escolher em
// quem usar um item, quem trocar ou quem sai do time. Igual ao site
// (web-site/src/components/BwParty.jsx).

import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import 'pokemon_sprite.dart';

class PartySlot {
  const PartySlot({required this.id, this.shiny = false, required this.name, required this.level, this.hp = 1, this.sub, this.status = ''});
  final int id, level;
  final bool shiny;
  final String name;
  final double hp;
  final String? sub;

  /// O status (PAR, SLP...), se tiver.
  final String status;
}

class BwParty extends StatelessWidget {
  const BwParty({super.key, required this.team, required this.onPick, this.title, this.disabled, this.onCancel, this.cancelLabel, this.testKey = 'bw-party', this.active, this.header});
  final List<PartySlot> team;
  final ValueChanged<int> onPick;
  final String? title;
  final bool Function(int)? disabled;
  final VoidCallback? onCancel;
  final String? cancelLabel;
  final String testKey;

  /// O que está em campo (o cartão verde, como no jogo); sem ele, o primeiro.
  final int? active;

  /// Algo embaixo do título (ex.: as fraquezas do adversário).
  final Widget? header;

  static const _ink = Color(0xFF0F172A);

  Color _hpColor(double hp) => hp > 0.5 ? const Color(0xFF34D399) : hp > 0.2 ? const Color(0xFFFBBF24) : const Color(0xFFEF4444);

  Widget _slot(int i) {
    final m = team[i];
    final off = disabled?.call(i) ?? false;
    final hp = m.hp.clamp(0.0, 1.0);
    final colors = i == (active ?? 0) ? const [Color(0xFFA5E9B0), Color(0xFF5CC07A)] : const [Color(0xFF7FD3F0), Color(0xFF4AA8D8)];
    return Opacity(
      opacity: off ? 0.45 : 1,
      child: Material(
        key: ValueKey('$testKey-$i'),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors, begin: Alignment.topCenter, end: Alignment.bottomCenter),
            border: Border.all(color: const Color(0xFF0F3D5C), width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: off ? null : () => onPick(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(children: [
                SizedBox(
                    width: 38,
                    height: 38,
                    child: ColorFiltered(
                      colorFilter: hp > 0 ? const ColorFilter.mode(Colors.transparent, BlendMode.dst) : const ColorFilter.mode(Colors.grey, BlendMode.saturation),
                      child: PokemonSprite(m.id, shiny: m.shiny, fill: 0.9),
                    )),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      // Nome do Pokémon como no jogo (não traduz).
                      Expanded(child: Text(m.name, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 12))),
                      if (m.status.isNotEmpty && hp > 0)
                        Container(
                            margin: const EdgeInsets.only(right: 3),
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(color: const Color(0xFF7C3AED), borderRadius: BorderRadius.circular(3)),
                            child: Text(m.status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900))),
                      Text('Lv${m.level}', style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 11)),
                    ]),
                    const SizedBox(height: 2),
                    Row(children: [
                      Container(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(2)),
                          child: const Text('HP', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900))),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Container(
                          height: 5,
                          decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(3)),
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(widthFactor: hp, child: Container(decoration: BoxDecoration(color: _hpColor(hp), borderRadius: BorderRadius.circular(3)))),
                        ),
                      ),
                    ]),
                    Text(m.sub ?? (hp > 0 ? '${(hp * 100).round()}%' : tr('Desmaiado')),
                        overflow: TextOverflow.ellipsis, style: const TextStyle(color: _ink, fontSize: 10, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
        key: ValueKey(testKey),
        padding: const EdgeInsets.all(8),
        color: const Color(0xFF1F6F78),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (title != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFF0F3D44), border: Border.all(color: const Color(0xFF0B2A2F), width: 2), borderRadius: BorderRadius.circular(8)),
              child: Text(title!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            ),
          if (header != null) Padding(padding: const EdgeInsets.only(bottom: 6), child: header),
          for (var r = 0; r < team.length; r += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Expanded(child: _slot(r)),
                const SizedBox(width: 6),
                Expanded(child: r + 1 < team.length ? _slot(r + 1) : const SizedBox()),
              ]),
            ),
          if (onCancel != null)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: ValueKey('$testKey-cancel'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626), visualDensity: VisualDensity.compact),
                onPressed: onCancel,
                child: Text('✕ ${cancelLabel ?? tr('Voltar')}', style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
        ]),
      );
}
