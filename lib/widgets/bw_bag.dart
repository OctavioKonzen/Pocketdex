// lib/widgets/bw_bag.dart
//
// A Bolsa como no Black & White: separada em bolsos (Itens, Remédios, Poké
// Balls, TMs, Itens-chave). Em cima, o item escolhido grande com a descrição
// (como a tela de cima do DS); no meio, os itens em pílulas brancas de borda
// azul; embaixo, os bolsos em botões redondos, as setas « » e o botão de voltar.
// Igual ao site (web-site/src/components/BwBag.jsx).

import 'package:flutter/material.dart';
import '../utils/hud_colors.dart';

import '../i18n/i18n.dart';

/// Um item da Bolsa. onUse: o que ele faz (quem chama pergunta em quem); sem onUse, só a ajuda.
class BagEntry {
  const BagEntry({required this.id, required this.name, this.count, required this.icon, this.help = '', this.onUse, this.use, this.disabled = false});
  final String id, name, icon, help;
  final int? count;
  final VoidCallback? onUse;
  final String? use;
  final bool disabled;
}

/// Um bolso: o nome, o item que vira o ícone (sprites/items/<img>.png) e os itens.
class BagPocket {
  const BagPocket({required this.id, required this.label, required this.img, required this.items});
  final String id, label, img;
  final List<BagEntry> items;
}

Widget _icon(String id, double size) => Image.asset('assets/database/sprites/items/$id.png',
    width: size, height: size, filterQuality: FilterQuality.none, errorBuilder: (_, __, ___) => SizedBox(width: size, height: size));

class BwBag extends StatefulWidget {
  const BwBag({super.key, required this.pockets, this.onClose, this.below, this.onSelect, this.testKey = 'bw-bag', this.fill = false, this.external = false});

  /// Na batalha (como no jogo): a descrição vai para a caixa de texto e USAR para os botões fixos de baixo.
  final bool external;

  /// Ocupa a altura toda (dentro do campo da batalha): as abas e a barra de baixo fixas, a lista rola no meio.
  final bool fill;
  final List<BagPocket> pockets;
  final VoidCallback? onClose;

  /// Aparece embaixo da lista (por exemplo, escolher em quem usar).
  final Widget? below;

  /// Avisa quando outro item é tocado (quem chama limpa o "em quem").
  final ValueChanged<String?>? onSelect;
  final String testKey;

  @override
  State<BwBag> createState() => _BwBagState();
}

class _BwBagState extends State<BwBag> {
  late String _pocket = (widget.pockets.where((p) => p.items.isNotEmpty).firstOrNull ?? widget.pockets.first).id;
  String? _selected;

  // O azul-claro com listras da Bolsa do Black & White, a barra azul-escura dos bolsos e a borda azul das pílulas.
  static Color get _sky => Hud.tint(const Color(0xFF4AA3DF));
  static Color get _bar => Hud.tint(const Color(0xFF1E4F8A));
  static const _edge = Color(0xFF075985);
  static const _dark = Color(0xFF0F172A);

  void _open(BagPocket p) => setState(() {
        _pocket = p.id;
        _selected = null;
        widget.onSelect?.call(null);
      });

  /// Com fill, o meio rola e ocupa o que sobra; sem, cresce com o conteúdo.
  Widget _fillOrNot(Widget child) => widget.fill ? Expanded(child: SingleChildScrollView(child: child)) : child;

  /// Uma pílula da lista: ícone, nome e ×quantidade (a escolhida em laranja).
  Widget _pill(BagEntry it) => Material(
        key: ValueKey('${widget.testKey}-item-${it.id}'),
        color: _selected == it.id ? const Color(0xFFFCD34D) : Colors.white,
        shape: StadiumBorder(side: BorderSide(color: _selected == it.id ? const Color(0xFFEA580C) : _edge, width: 2)),
        elevation: 2,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => setState(() {
            _selected = _selected == it.id ? null : it.id;
            widget.onSelect?.call(_selected);
          }),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 12, 2),
            child: Row(children: [
              _icon(it.icon, 28),
              const SizedBox(width: 6),
              // Nome do item como no jogo (não traduz).
              Expanded(child: Text(it.name, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _dark, fontWeight: FontWeight.w900))),
              if (it.count != null) Text('×${it.count}', style: const TextStyle(color: _edge, fontWeight: FontWeight.w900)),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final pockets = widget.pockets;
    final at = pockets.indexWhere((p) => p.id == _pocket).clamp(0, pockets.length - 1);
    final current = pockets[at];
    final picked = current.items.where((it) => it.id == _selected).firstOrNull;
    return ClipRRect(
      key: ValueKey(widget.testKey),
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(color: _sky, border: Border.all(color: _dark, width: 4), borderRadius: BorderRadius.circular(12)),
        child: CustomPaint(
          painter: _Stripes(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // A "tela de cima": o item escolhido (ícone grande, nome e descrição) ou a bolsa com o nome do bolso.
            if (!widget.external)
              Container(
                key: ValueKey(picked != null ? '${widget.testKey}-help' : '${widget.testKey}-top'),
                margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minHeight: 72),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  border: Border.all(color: _edge, width: 2),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [BoxShadow(color: Color(0x4D0F172A), offset: Offset(0, 3))],
                ),
                child: picked != null
                    ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _icon(picked.icon, 48),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${picked.name}${picked.count != null ? '  ×${picked.count}' : ''}',
                                overflow: TextOverflow.ellipsis, style: const TextStyle(color: _dark, fontSize: 14, fontWeight: FontWeight.w900)),
                            Text(picked.help, style: const TextStyle(color: _dark, fontSize: 12, fontWeight: FontWeight.w600)),
                            if (picked.onUse != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: FilledButton(
                                  key: ValueKey('${widget.testKey}-use'),
                                  style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF0284C7),
                                      shape: const StadiumBorder(side: BorderSide(color: Color(0xFF0C4A6E), width: 2)),
                                      visualDensity: VisualDensity.compact),
                                  onPressed: picked.disabled ? null : picked.onUse,
                                  child: Text('▸ ${picked.use ?? tr('USAR')}', style: const TextStyle(fontWeight: FontWeight.w900)),
                                ),
                              ),
                          ]),
                        ),
                      ])
                    : Row(children: [
                        const Text('🎒', style: TextStyle(fontSize: 34)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              _icon(current.img, 20),
                              const SizedBox(width: 4),
                              Flexible(
                                  child: Text(tr(current.label).toUpperCase(),
                                      overflow: TextOverflow.ellipsis, style: const TextStyle(color: _dark, fontWeight: FontWeight.w900, letterSpacing: 0.5))),
                            ]),
                            Text(tr('Toque num item para ver o que ele faz.'), style: const TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ]),
              ),
            // Os itens: pílulas brancas de borda azul, em duas colunas quando cabe (a escolhida em laranja).
            _fillOrNot(Padding(
              padding: const EdgeInsets.all(8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (current.items.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: ShapeDecoration(color: Colors.white.withValues(alpha: 0.9), shape: const StadiumBorder(side: BorderSide(color: _edge, width: 2))),
                    child: Text(tr('Nada neste bolso.'), style: const TextStyle(color: _dark, fontWeight: FontWeight.bold)),
                  ),
                LayoutBuilder(builder: (context, box) {
                  final cols = box.maxWidth >= 400 ? 2 : 1;
                  final w = (box.maxWidth - 6 * (cols - 1)) / cols;
                  return Wrap(spacing: 6, runSpacing: 6, children: [for (final it in current.items) SizedBox(width: w, child: _pill(it))]);
                }),
                if (widget.below != null) Padding(padding: const EdgeInsets.only(top: 6), child: widget.below),
              ]),
            )),
            // A barra de baixo: os bolsos em botões redondos, as setas « » e o botão vermelho de voltar.
            Container(
              decoration: BoxDecoration(color: _bar, border: const Border(top: BorderSide(color: _dark, width: 2))),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(children: [
                IconButton(
                    tooltip: tr('Bolso anterior'),
                    key: ValueKey('${widget.testKey}-prev'),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _open(pockets[(at - 1 + pockets.length) % pockets.length]),
                    icon: const Text('«', style: TextStyle(color: Color(0xFFBAE6FD), fontSize: 18, fontWeight: FontWeight.w900))),
                Expanded(
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    for (final p in pockets)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Material(
                          key: ValueKey('${widget.testKey}-tab-${p.id}'),
                          color: p.id == current.id ? const Color(0xFFFBBF24) : Colors.white.withValues(alpha: 0.85),
                          shape: const CircleBorder(side: BorderSide(color: _dark, width: 2)),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _open(p),
                            child: SizedBox.square(dimension: p.id == current.id ? 40 : 32, child: Center(child: _icon(p.img, p.id == current.id ? 28 : 20))),
                          ),
                        ),
                      ),
                  ]),
                ),
                IconButton(
                    tooltip: tr('Próximo bolso'),
                    key: ValueKey('${widget.testKey}-next'),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _open(pockets[(at + 1) % pockets.length]),
                    icon: const Text('»', style: TextStyle(color: Color(0xFFBAE6FD), fontSize: 18, fontWeight: FontWeight.w900))),
                if (widget.onClose != null)
                  Material(
                    color: const Color(0xFFDC2626),
                    shape: const CircleBorder(side: BorderSide(color: _dark, width: 2)),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: widget.onClose,
                      child: Tooltip(
                          message: tr('Fechar'),
                          child: const SizedBox.square(
                              dimension: 36, child: Center(child: Text('↩', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))))),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// As listras na diagonal do fundo da Bolsa (como no Black & White).
class _Stripes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.13)
      ..strokeWidth = 6;
    for (double x = -size.height; x < size.width; x += 14) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
