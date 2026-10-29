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

class BwParty extends StatefulWidget {
  const BwParty(
      {super.key, required this.team, required this.onPick, this.title, this.disabled, this.onCancel, this.cancelLabel, this.testKey = 'bw-party', this.active, this.header, this.onInfo, this.pickLabel, this.fill = false, this.selected, this.onSelect});
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

  /// Como no jogo: tocando num Pokémon aparecem as opções (pickLabel, DADOS e CANCELAR); DADOS chama onInfo.
  final ValueChanged<int>? onInfo;
  final String? pickLabel;

  /// Na batalha (como no jogo): os 6 ocupam exatamente a tela (3 linhas × 2 colunas, sem rolar); o título vai para a
  /// caixa de texto e as opções (TROCAR, DADOS, CANCELAR) para os botões fixos de baixo.
  final bool fill;

  /// Com [onSelect], quem foi tocado fica com quem chama (as opções ficam lá fora).
  final int? selected;
  final ValueChanged<int>? onSelect;

  @override
  State<BwParty> createState() => _BwPartyState();
}

class _BwPartyState extends State<BwParty> {
  /// O tocado (com as opções embaixo).
  int? _picked;
  List<PartySlot> get team => widget.team;
  String get testKey => widget.testKey;

  static const _ink = Color(0xFF0F172A);

  @override
  void didUpdateWidget(covariant BwParty old) {
    super.didUpdateWidget(old);
    if (_picked != null && _picked! >= team.length) _picked = null;
  }

  void _tap(int i) {
    if (widget.onSelect != null) return widget.onSelect!(i);
    if (widget.onInfo == null) return widget.onPick(i);
    setState(() => _picked = _picked == i ? null : i);
  }

  Widget _actions(int i) {
    final off = widget.disabled?.call(i) ?? false;
    Widget button(String label, Color color, VoidCallback? onTap, String key) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: FilledButton(
              key: ValueKey('$testKey-$key'),
              style: FilledButton.styleFrom(backgroundColor: color, visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 4)),
              onPressed: onTap,
              child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
            ),
          ),
        );
    return Container(
      key: ValueKey('$testKey-actions'),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFF0F3D44), borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        button(widget.pickLabel ?? tr('TROCAR'), const Color(0xFF16A34A), off ? null : () { setState(() => _picked = null); widget.onPick(i); }, 'pick'),
        button(tr('DADOS'), const Color(0xFF2563EB), () => widget.onInfo!(i), 'info'),
        button(tr('CANCELAR'), const Color(0xFF64748B), () => setState(() => _picked = null), 'close'),
      ]),
    );
  }

  Color _hpColor(double hp) => hp > 0.5 ? const Color(0xFF34D399) : hp > 0.2 ? const Color(0xFFFBBF24) : const Color(0xFFEF4444);

  Widget _slot(int i) {
    final m = team[i];
    // Com as opções (onInfo), dá para ver os dados até de quem não pode ser escolhido.
    final off = (widget.disabled?.call(i) ?? false) && widget.onInfo == null && widget.onSelect == null;
    final dim = widget.disabled?.call(i) ?? false;
    final hp = m.hp.clamp(0.0, 1.0);
    final colors = i == (widget.onSelect != null ? widget.selected : _picked)
        ? const [Color(0xFFFDBA74), Color(0xFFF97316)]
        : i == (widget.active ?? 0)
            ? const [Color(0xFFA5E9B0), Color(0xFF5CC07A)]
            : const [Color(0xFF7FD3F0), Color(0xFF4AA8D8)];
    return Opacity(
      opacity: dim ? 0.55 : 1,
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
            onTap: off ? null : () => _tap(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: _fitted(Row(children: [
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
                      Expanded(
                          child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(m.name, maxLines: 1, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 12)))),
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
                    // O texto de baixo (ex.: o item) diminui para caber, sem cortar.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(m.sub ?? (hp > 0 ? '${(hp * 100).round()}%' : tr('Desmaiado')),
                          maxLines: 1, style: const TextStyle(color: _ink, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                ),
              ])),
            ),
          ),
        ),
      ),
    );
  }

  /// No modo da batalha o cartão ocupa a célula dele: o conteúdo centraliza (e diminui, se não couber).
  Widget _fitted(Widget row) => widget.fill
      ? LayoutBuilder(builder: (context, box) => FittedBox(fit: BoxFit.scaleDown, child: SizedBox(width: box.maxWidth, child: row)))
      : row;

  @override
  Widget build(BuildContext context) => widget.fill
      ? Container(
          key: ValueKey(testKey),
          padding: const EdgeInsets.all(6),
          color: const Color(0xFF1F6F78),
          child: Column(children: [
            for (var r = 0; r < team.length || r < 6; r += 2) ...[
              if (r > 0) const SizedBox(height: 6),
              Expanded(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: r < team.length ? _slot(r) : const SizedBox()),
                  const SizedBox(width: 6),
                  Expanded(child: r + 1 < team.length ? _slot(r + 1) : const SizedBox()),
                ]),
              ),
            ],
          ]),
        )
      : Container(
        key: ValueKey(testKey),
        padding: const EdgeInsets.all(8),
        color: const Color(0xFF1F6F78),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (widget.title != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFF0F3D44), border: Border.all(color: const Color(0xFF0B2A2F), width: 2), borderRadius: BorderRadius.circular(8)),
              child: Text(widget.title!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            ),
          if (widget.header != null) Padding(padding: const EdgeInsets.only(bottom: 6), child: widget.header),
          for (var r = 0; r < team.length; r += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Expanded(child: _slot(r)),
                const SizedBox(width: 6),
                Expanded(child: r + 1 < team.length ? _slot(r + 1) : const SizedBox()),
              ]),
            ),
          if (_picked != null) _actions(_picked!),
          if (widget.onCancel != null)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: ValueKey('$testKey-cancel'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626), visualDensity: VisualDensity.compact),
                onPressed: widget.onCancel,
                child: Text('✕ ${widget.cancelLabel ?? tr('Voltar')}', style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
        ]),
      );
}
