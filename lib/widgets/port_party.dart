// lib/widgets/port_party.dart
//
// A tela do time como no port de Black & White (a da Battle Factory): o primeiro (quem vai na frente) grande à
// esquerda e os outros cinco um embaixo do outro à direita, nas caixas escuras de borda cinza da HUD (cor fixa).
// Arrastar um em cima do outro troca os dois de lugar (onMove). Abre por cima do campo, para escolher em quem usar um
// item, quem trocar, quem sai do time ou quem entra. Igual ao site (web-site/src/components/BwParty.jsx).

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import 'bw_party.dart' show PartySlot;
import 'pokemon_sprite.dart';

const _font = TextStyle(fontFamily: 'PixelifySans', color: Colors.white, fontWeight: FontWeight.w600, shadows: [Shadow(color: Colors.black, offset: Offset(1, 1))]);
const _box = BeveledRectangleBorder(borderRadius: BorderRadius.only(bottomRight: Radius.circular(10)));

class PortParty extends StatefulWidget {
  const PortParty(
      {super.key,
      required this.team,
      required this.onPick,
      this.title,
      this.disabled,
      this.onCancel,
      this.cancelLabel,
      this.testKey = 'bw-party',
      this.eggs = const [],
      this.mystery = const {},
      this.onMove,
      this.active,
      this.selected,
      this.onSelect,
      this.footer,
      this.leads});
  final List<PartySlot> team;
  final ValueChanged<int> onPick;
  final String? title;
  final bool Function(int)? disabled;
  final VoidCallback? onCancel;
  final String? cancelLabel;
  final String testKey;

  /// Os ovos no time (as vitórias que faltam para chocar), cada um numa vaga depois dos Pokémon.
  final List<int> eggs;

  /// Quais ovos são misteriosos (aparecem como ❔).
  final Set<int> mystery;

  /// Arrastou um em cima do outro: troca os dois de lugar (sem onMove, não arrasta).
  final void Function(int from, int to)? onMove;

  /// Na batalha: quem está em campo (borda verde).
  final int? active;

  /// Na batalha: quem foi tocado (em amarelo); com [onSelect], tocar só marca (as opções ficam nos botões de baixo).
  final int? selected;
  final ValueChanged<int>? onSelect;

  /// Embaixo de tudo (na batalha: a fala e os botões TROCAR / DADOS / CANCELAR), com a tela do time na tela inteira.
  final Widget? footer;

  /// Na batalha: quem está em campo (posições no time), à esquerda, um embaixo do outro (1 na normal, 2 na dupla, 3 na
  /// tripla); os outros à direita, na ordem do time. Sem: o primeiro grande à esquerda e os outros cinco à direita.
  final List<int>? leads;

  @override
  State<PortParty> createState() => _PortPartyState();
}

class _PortPartyState extends State<PortParty> {
  int? _over, _from;

  Color _hp(double hp) => hp > 0.5 ? const Color(0xFF4ADE80) : hp > 0.2 ? const Color(0xFFFACC15) : const Color(0xFFEF4444);

  Widget _frame(Widget child, {bool hot = false, bool over = false, bool field = false, Key? key}) => Material(
        key: key,
        shape: _box.copyWith(
            side: BorderSide(color: over ? const Color(0xFF22D3EE) : hot ? const Color(0xFFFACC15) : field ? const Color(0xFF4ADE80) : const Color(0xFF8B93A1), width: 2)),
        clipBehavior: Clip.antiAlias,
        color: over ? const Color(0xF2083344) : hot ? const Color(0xEB42340A) : const Color(0xEB14161C),
        child: child,
      );

  Widget _slot(int i, double w, {bool big = false}) {
    final m = widget.team[i];
    final off = widget.disabled?.call(i) ?? false;
    final hp = m.hp.clamp(0.0, 1.0).toDouble();
    final icon = Opacity(opacity: hp > 0 ? 1 : 0.5, child: SizedBox(width: big ? w * 0.11 : w * 0.055, height: big ? w * 0.11 : w * 0.055, child: PokemonSprite(m.id, shiny: m.shiny, fill: 0.95)));
    final info = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _font.copyWith(fontSize: big ? w * 0.026 : w * 0.019))),
        Text('Lv.${m.level}', style: _font.copyWith(fontSize: w * 0.015)),
        if (m.max)
          Container(
              key: ValueKey('${widget.testKey}-max-$i'),
              margin: const EdgeInsets.only(left: 3),
              padding: const EdgeInsets.symmetric(horizontal: 2),
              color: const Color(0xFFFBBF24),
              child: Text('MÁX', style: TextStyle(fontSize: w * 0.011, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)))),
      ]),
      if (m.hearts != null)
        Text.rich(
            key: ValueKey('${widget.testKey}-hearts-$i'),
            TextSpan(children: [
              TextSpan(text: '♥' * m.hearts!),
              TextSpan(text: '♥' * (5 - m.hearts!).clamp(0, 5), style: const TextStyle(color: Color(0x66F472B6))),
            ]),
            style: TextStyle(fontSize: w * 0.012, color: const Color(0xFFF472B6), height: 1)),
      Row(children: [
        Text('HP', style: _font.copyWith(color: const Color(0xFFA3E635), fontSize: w * 0.012)),
        SizedBox(width: w * 0.006),
        Expanded(
          child: Container(
            height: w * 0.008,
            decoration: BoxDecoration(color: const Color(0xFF2B3240), border: Border.all(color: Colors.black, width: 1)),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(widthFactor: hp, heightFactor: 1, child: ColoredBox(color: _hp(hp))),
          ),
        ),
      ]),
      Text(m.sub ?? (hp > 0 ? '${(hp * 100).round()}%' : tr('Desmaiado')), maxLines: 1, overflow: TextOverflow.ellipsis, style: _font.copyWith(fontSize: w * 0.013, color: const Color(0xFFCBD5E1))),
    ]);
    // Encolhe para caber na caixa (nada corta).
    final body = Padding(
      padding: EdgeInsets.symmetric(horizontal: w * 0.012, vertical: 2),
      child: LayoutBuilder(
        builder: (context, b) => FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: b.maxWidth,
            child: big
                ? Column(mainAxisSize: MainAxisSize.min, children: [icon, SizedBox(height: w * 0.01), info])
                : Row(children: [icon, SizedBox(width: w * 0.012), Expanded(child: info)]),
          ),
        ),
      ),
    );
    Widget card = Opacity(
      opacity: off ? 0.45 : _from == i ? 0.4 : 1,
      child: _frame(InkWell(onTap: off && widget.onSelect == null ? null : () => (widget.onSelect ?? widget.onPick)(i), child: body),
          over: _over == i && _from != i, hot: widget.selected == i, field: widget.active == i || (widget.leads?.contains(i) ?? false), key: ValueKey('${widget.testKey}-$i')),
    );
    if (widget.onMove == null) return DragTarget<int>(builder: (_, _, _) => card, onWillAcceptWithDetails: (_) => false);
    // Apagado (na batalha: quem já está em campo): não sai do lugar, mas recebe quem for solto em cima (troca).
    if (off) {
      return DragTarget<int>(
        onWillAcceptWithDetails: (d) {
          if (d.data == i) return false;
          setState(() => _over = i);
          return true;
        },
        onLeave: (_) => setState(() => _over = null),
        onAcceptWithDetails: (d) {
          setState(() => _over = null);
          widget.onMove!(d.data, i);
        },
        builder: (context, _, _) => card,
      );
    }
    // Segura e arrasta (como no jogo): solta em cima de outro para trocar os dois de lugar.
    return DragTarget<int>(
      onWillAcceptWithDetails: (d) {
        if (d.data == i) return false;
        setState(() => _over = i);
        return true;
      },
      onLeave: (_) => setState(() => _over = null),
      onAcceptWithDetails: (d) {
        setState(() => _over = null);
        widget.onMove!(d.data, i);
      },
      builder: (context, _, _) => LayoutBuilder(
        builder: (context, box) => LongPressDraggable<int>(
          data: i,
          delay: const Duration(milliseconds: 150),
          onDragStarted: () => setState(() => _from = i),
          onDragEnd: (_) => setState(() => _from = null),
          feedback: SizedBox(width: box.maxWidth, height: box.maxHeight, child: Material(color: Colors.transparent, child: Opacity(opacity: 0.85, child: _frame(body, hot: true)))),
          child: card,
        ),
      ),
    );
  }

  /// Na batalha: quem está em campo à esquerda (um embaixo do outro) e o resto à direita, na ordem do time.
  Widget _battleRows(List<Widget Function({bool big})> slots, double w) {
    final leads = [for (final i in widget.leads!) if (i >= 0 && i < widget.team.length) i];
    final rest = [for (var i = 0; i < widget.team.length; i++) if (!leads.contains(i)) i];
    final rows = math.max(rest.length, 6 - leads.length);
    Widget column(List<int> list, int count, {bool big = false}) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var k = 0; k < count; k++) ...[
            if (k > 0) SizedBox(height: w * 0.01),
            Expanded(child: k < list.length ? slots[list[k]](big: big) : Opacity(opacity: 0.35, child: _frame(const SizedBox.expand()))),
          ],
        ]);
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Um só em campo: grande, no meio da altura (como fora da batalha); dois ou três: um embaixo do outro.
      SizedBox(
          width: w * 0.42,
          child: leads.length == 1
              ? Center(child: FractionallySizedBox(heightFactor: 0.62, child: slots[leads.first](big: true)))
              : Padding(padding: EdgeInsets.symmetric(vertical: w * 0.02), child: column(leads, leads.length))),
      SizedBox(width: w * 0.015),
      Expanded(child: column(rest, rows)),
    ]);
  }

  Widget _egg(int k, double w) {
    final mystery = widget.mystery.contains(k);
    return _frame(
      key: const ValueKey('party-egg'),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: w * 0.012),
        child: Row(children: [
          Text(mystery ? '❔' : '🥚', style: TextStyle(fontSize: w * 0.035)),
          SizedBox(width: w * 0.012),
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr(mystery ? 'Ovo misterioso' : 'Ovo'), maxLines: 1, style: _font.copyWith(fontSize: w * 0.019)),
              Text(tr('Choca em {0} vitórias').replaceAll('{0}', '${widget.eggs[k]}'), maxLines: 1, style: _font.copyWith(fontSize: w * 0.013, color: const Color(0xFFCBD5E1))),
            ]),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        final slots = <Widget Function({bool big})>[
          for (var i = 0; i < widget.team.length; i++) ({bool big = false}) => _slot(i, w, big: big),
          for (var k = 0; k < widget.eggs.length; k++) ({bool big = false}) => _egg(k, w),
        ];
        // Sem altura (dentro de algo que rola): do tamanho do campo (16:9).
        return MediaQuery.withNoTextScaling(
          child: Container(
            key: ValueKey(widget.testKey),
            height: box.hasBoundedHeight ? null : w * 9 / 16,
            // Fundo fixo (não muda com o tema), azul-petróleo com listras.
            decoration: const BoxDecoration(color: Color(0xFF1F6F78)),
            padding: EdgeInsets.all(w * 0.015),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (widget.title != null) ...[
                _frame(Padding(padding: EdgeInsets.symmetric(horizontal: w * 0.015, vertical: 3), child: Text(widget.title!, style: _font.copyWith(fontSize: w * 0.018)))),
                SizedBox(height: w * 0.012),
              ],
              if (widget.leads != null)
                Expanded(child: _battleRows(slots, w))
              else
              Expanded(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  // O primeiro (quem vai na frente) grande, à esquerda.
                  SizedBox(width: w * 0.42, child: Center(child: FractionallySizedBox(heightFactor: 0.62, child: slots.isEmpty ? const SizedBox() : slots.first(big: true)))),
                  SizedBox(width: w * 0.015),
                  // Os outros, um embaixo do outro.
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      for (var k = 1; k <= 5; k++) ...[
                        if (k > 1) SizedBox(height: w * 0.01),
                        Expanded(child: k < slots.length ? slots[k]() : Opacity(opacity: 0.35, child: _frame(const SizedBox.expand()))),
                      ],
                    ]),
                  ),
                ]),
              ),
              if (widget.onMove != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(tr(widget.leads != null ? 'Arraste um Pokémon para cima de quem está em campo para trocar.' : 'Arraste um Pokémon em cima de outro para trocar de lugar.'), textAlign: TextAlign.center, style: _font.copyWith(fontSize: w * 0.013, color: const Color(0xFFCBD5E1))),
                ),
              if (widget.footer != null) ...[SizedBox(height: w * 0.012), SizedBox(height: w * 0.075, child: widget.footer)],
              if (widget.onCancel != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: _frame(
                      key: ValueKey('${widget.testKey}-cancel'),
                      InkWell(onTap: widget.onCancel, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), child: Text('✕ ${widget.cancelLabel ?? tr('Voltar')}', style: _font.copyWith(fontSize: w * 0.016)))),
                    ),
                  ),
                ),
            ]),
          ),
        );
      });
}
