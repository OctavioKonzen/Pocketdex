// lib/widgets/bw_bag.dart
//
// A Bolsa como no Black & White: separada em bolsos (Itens, Remédios, Poké
// Balls, TMs, Itens-chave), no layout do jogo e na cor do app: os bolsos à
// esquerda (o nome com « »), a lista escura com o escolhido em ciano à direita e,
// embaixo, o ícone grande do item com a descrição e o botão de voltar.
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

  // O azul do tema com listras, a lista e a descrição em azul-escuro (tingidos pelo tema) e o ciano do escolhido.
  static Color get _sky => Hud.tint(const Color(0xFF4AA3DF));
  static Color get _list => Hud.tint(const Color(0xFF0B1E36));
  static Color get _desc => Hud.tint(const Color(0xFF0F2C52));
  static const _cyan = Color(0xFF22D3EE);
  static const _dark = Color(0xFF0F172A);
  static const _white = TextStyle(color: Colors.white, fontWeight: FontWeight.w700);

  void _open(BagPocket p) => setState(() {
        _pocket = p.id;
        _selected = null;
        widget.onSelect?.call(null);
      });

  /// Uma linha da lista: ícone, nome e ×quantidade (a escolhida com contorno ciano).
  Widget _row(BagEntry it) {
    final on = _selected == it.id;
    return Container(
      key: ValueKey('${widget.testKey}-item-${it.id}'),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: ShapeDecoration(
        color: on ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
        shape: StadiumBorder(side: BorderSide(color: on ? _cyan : Colors.transparent, width: 2)),
        shadows: on ? [BoxShadow(color: _cyan.withValues(alpha: 0.6), blurRadius: 6)] : null,
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => setState(() {
          _selected = on ? null : it.id;
          widget.onSelect?.call(_selected);
        }),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 8, 2),
          child: Row(children: [
            _icon(it.icon, 28),
            const SizedBox(width: 6),
            // Nome do item como no jogo (não traduz).
            Expanded(child: Text(it.name, overflow: TextOverflow.ellipsis, style: _white)),
            if (it.count != null) Text('×${it.count}', style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }

  /// Um bolso à esquerda: o ícone num quadrado (o aberto claro e um pouco maior).
  Widget _pocketTile(BagPocket p, bool on) => Transform.scale(
        scale: on ? 1.06 : 1,
        child: Opacity(
          opacity: on ? 1 : 0.75,
          child: Material(
            key: ValueKey('${widget.testKey}-tab-${p.id}'),
            color: Colors.white.withValues(alpha: on ? 0.6 : 0.25),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8), side: BorderSide(color: on ? Colors.white : _dark.withValues(alpha: 0.4), width: 2)),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _open(p),
              child: Tooltip(message: tr(p.label), child: AspectRatio(aspectRatio: 1, child: Center(child: _icon(p.img, 24)))),
            ),
          ),
        ),
      );

  Widget _arrow(String key, String label, String tip, VoidCallback onTap) => InkWell(
        key: ValueKey('${widget.testKey}-$key'),
        onTap: onTap,
        child: Tooltip(
            message: tr(tip),
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3), child: Text(label, style: const TextStyle(color: _cyan, fontWeight: FontWeight.w900)))),
      );

  @override
  Widget build(BuildContext context) {
    final pockets = widget.pockets;
    final at = pockets.indexWhere((p) => p.id == _pocket).clamp(0, pockets.length - 1);
    final current = pockets[at];
    final picked = current.items.where((it) => it.id == _selected).firstOrNull;
    // A lista à direita: fundo escuro; com fill, rola e ocupa o que sobra.
    final list = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      if (current.items.isEmpty)
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(tr('Nada neste bolso.'), style: const TextStyle(color: Color(0xFFCBD5E1), fontWeight: FontWeight.bold))),
      for (final it in current.items) _row(it),
      if (widget.below != null) Padding(padding: const EdgeInsets.only(top: 6), child: widget.below),
    ]);
    final main = Padding(
      padding: const EdgeInsets.all(8),
      child: Row(crossAxisAlignment: widget.fill ? CrossAxisAlignment.stretch : CrossAxisAlignment.start, children: [
        // Os bolsos à esquerda (como no jogo) e, embaixo, o nome do bolso com « ».
        SizedBox(
          width: 112,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [for (final p in pockets) _pocketTile(p, p.id == current.id)],
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(color: const Color(0xFF020617), borderRadius: BorderRadius.circular(4)),
              child: Row(children: [
                _arrow('prev', '«', 'Bolso anterior', () => _open(pockets[(at - 1 + pockets.length) % pockets.length])),
                Expanded(
                    child: Text(tr(current.label),
                        textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900))),
                _arrow('next', '»', 'Próximo bolso', () => _open(pockets[(at + 1) % pockets.length])),
              ]),
            ),
          ]),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 128),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: _list, border: Border.all(color: _dark, width: 2), borderRadius: BorderRadius.circular(6)),
            child: widget.fill ? SingleChildScrollView(child: list) : list,
          ),
        ),
      ]),
    );
    return ClipRRect(
      key: ValueKey(widget.testKey),
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(color: _sky, border: Border.all(color: _dark, width: 4), borderRadius: BorderRadius.circular(12)),
        child: CustomPaint(
          painter: _Stripes(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            widget.fill ? Expanded(child: main) : main,
            // Embaixo, como no jogo: o ícone grande do item escolhido e a descrição (na batalha, vai para a caixa de texto).
            if (!widget.external)
              Container(
                key: ValueKey(picked != null ? '${widget.testKey}-help' : '${widget.testKey}-top'),
                constraints: const BoxConstraints(minHeight: 64),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _desc, border: const Border(top: BorderSide(color: _dark, width: 2))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: const Color(0xFF020617), border: Border.all(color: Colors.white, width: 2)),
                    child: Center(child: picked != null ? _icon(picked.icon, 48) : _icon(current.img, 40)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: picked != null
                        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${picked.name}${picked.count != null ? ' ×${picked.count}' : ''}',
                                overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                            Text(picked.help, style: const TextStyle(color: Colors.white, fontSize: 12)),
                            if (picked.onUse != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: FilledButton(
                                  key: ValueKey('${widget.testKey}-use'),
                                  style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF06B6D4),
                                      shape: const StadiumBorder(side: BorderSide(color: _dark, width: 2)),
                                      visualDensity: VisualDensity.compact),
                                  onPressed: picked.disabled ? null : picked.onUse,
                                  child: Text('▸ ${picked.use ?? tr('USAR')}', style: const TextStyle(fontWeight: FontWeight.w900)),
                                ),
                              ),
                          ])
                        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(tr(current.label), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                            Text(tr('Toque num item para ver o que ele faz.'), style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
                          ]),
                  ),
                ]),
              ),
            if (widget.onClose != null)
              Material(
                color: _dark,
                child: InkWell(
                  onTap: widget.onClose,
                  child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('↩ ${tr('Voltar')}', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFE2E8F0), fontWeight: FontWeight.w900))),
                ),
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
