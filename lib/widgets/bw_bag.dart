// lib/widgets/bw_bag.dart
//
// A Bolsa como no Black & White: separada em bolsos (Itens, Remédios, Poké
// Balls, TMs, Itens-chave), os bolsos em abas em cima, a lista de itens em
// abas brancas e, embaixo, a barra com o nome do bolso e as setas « ».
// Igual ao site (web-site/src/components/BwBag.jsx).

import 'package:flutter/material.dart';

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

  static const _blue = Color(0xFF2563C9);
  static const _dark = Color(0xFF0F172A);

  void _open(BagPocket p) => setState(() {
        _pocket = p.id;
        _selected = null;
        widget.onSelect?.call(null);
      });

  /// Com fill, o meio rola e ocupa o que sobra; sem, cresce com o conteúdo.
  Widget _fillOrNot(Widget child) => widget.fill ? Expanded(child: SingleChildScrollView(child: child)) : child;

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
        decoration: BoxDecoration(color: _blue, border: Border.all(color: _dark, width: 4), borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Os bolsos em abas.
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
            child: Row(children: [
              for (final p in pockets)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Material(
                      key: ValueKey('${widget.testKey}-tab-${p.id}'),
                      color: p.id == current.id ? const Color(0xFFFBBF24) : const Color(0x99334155),
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(8)), side: BorderSide(color: _dark, width: 2)),
                      child: InkWell(
                        onTap: () => _open(p),
                        child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Center(child: _icon(p.img, 24))),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
          _fillOrNot(Padding(
            padding: const EdgeInsets.all(8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (current.items.isEmpty)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                  child: Text(tr('Nada neste bolso.'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              for (final it in current.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    key: ValueKey('${widget.testKey}-item-${it.id}'),
                    color: _selected == it.id ? const Color(0xFFFEF3C7) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(24), right: Radius.circular(8)),
                      side: BorderSide(color: _selected == it.id ? const Color(0xFFF59E0B) : _dark, width: 2),
                    ),
                    elevation: 2,
                    child: InkWell(
                      onTap: () => setState(() {
                        _selected = _selected == it.id ? null : it.id;
                        widget.onSelect?.call(_selected);
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(children: [
                          _icon(it.icon, 28),
                          const SizedBox(width: 8),
                          // Nome do item como no jogo (não traduz).
                          Expanded(child: Text(it.name, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _dark, fontWeight: FontWeight.w900))),
                          if (it.count != null) Text('×${it.count}', style: const TextStyle(color: _dark, fontWeight: FontWeight.w900)),
                        ]),
                      ),
                    ),
                  ),
                ),
              if (picked != null && !widget.external)
                Container(
                  key: ValueKey('${widget.testKey}-help'),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _dark, width: 2), borderRadius: BorderRadius.circular(8)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(picked.help, style: const TextStyle(color: _dark, fontSize: 12, fontWeight: FontWeight.w600)),
                    if (picked.onUse != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: FilledButton(
                          key: ValueKey('${widget.testKey}-use'),
                          style: FilledButton.styleFrom(backgroundColor: _dark, visualDensity: VisualDensity.compact),
                          onPressed: picked.disabled ? null : picked.onUse,
                          child: Text('▸ ${picked.use ?? tr('USAR')}', style: const TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                  ]),
                ),
              if (widget.below != null) Padding(padding: const EdgeInsets.only(top: 6), child: widget.below),
            ]),
          )),
          // A barra de baixo: « BOLSO » e fechar.
          Container(
            color: _dark,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(children: [
              IconButton(tooltip: tr('Bolso anterior'), 
                  key: ValueKey('${widget.testKey}-prev'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _open(pockets[(at - 1 + pockets.length) % pockets.length]),
                  icon: const Text('«', style: TextStyle(color: Color(0xFF7DD3FC), fontSize: 18, fontWeight: FontWeight.w900))),
              Expanded(
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _icon(current.img, 20),
                  const SizedBox(width: 4),
                  Flexible(
                      child: Text(tr(current.label).toUpperCase(),
                          overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 0.5))),
                ]),
              ),
              IconButton(tooltip: tr('Próximo bolso'), 
                  key: ValueKey('${widget.testKey}-next'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _open(pockets[(at + 1) % pockets.length]),
                  icon: const Text('»', style: TextStyle(color: Color(0xFF7DD3FC), fontSize: 18, fontWeight: FontWeight.w900))),
              for (var i = 0; i < pockets.length; i++)
                Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: i == at ? const Color(0xFFFBBF24) : const Color(0xFF475569))),
              if (widget.onClose != null)
                IconButton(tooltip: tr('Fechar'), 
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.onClose,
                    icon: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(color: const Color(0xFFDC2626), borderRadius: BorderRadius.circular(4)),
                        child: const Text('✕', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)))),
            ]),
          ),
        ]),
      ),
    );
  }
}
