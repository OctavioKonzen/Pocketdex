// lib/widgets/pick_fields.dart
//
// Peças de formulário usadas na calculadora de dano e no editor de times:
// campo de número com limite e lista com busca (habilidades, itens, golpes).

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../utils/site_ui.dart';
import 'package:pocket_dex/i18n/text.dart';

String _id(String s) => s.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

/// Campo de número (EVs, IVs, nível) que aceita só valores entre [min] e [max].
class NumberField extends StatefulWidget {
  final int value, min, max;
  final double? width;
  final ValueChanged<int> onChanged;
  const NumberField({super.key, required this.value, required this.min, required this.max, required this.onChanged, this.width});
  @override
  State<NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<NumberField> {
  late final _controller = TextEditingController(text: '${widget.value}');
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      // Ao sair do campo, mostra o valor que valeu (ex.: vazio → mínimo).
      if (!_focus.hasFocus) _controller.text = '${widget.value}';
    });
  }

  @override
  void didUpdateWidget(NumberField old) {
    super.didUpdateWidget(old);
    if (int.tryParse(_controller.text) != widget.value && !_focus.hasFocus) _controller.text = '${widget.value}';
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    return SizedBox(
      width: widget.width,
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
        textAlign: TextAlign.center,
        style: TextStyle(color: c.text, fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: c.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        ),
        onChanged: (text) {
          final n = int.tryParse(text);
          final v = (n ?? widget.min).clamp(widget.min, widget.max);
          if (n != null && n != v) {
            _controller.value = TextEditingValue(text: '$v', selection: TextSelection.collapsed(offset: '$v'.length));
          }
          if (v != widget.value) widget.onChanged(v);
        },
      ),
    );
  }
}

/// Lista com busca; devolve o escolhido ('' = nenhum) ou null se fechar.
/// [label]: texto mostrado de cada opção; [trailing]: algo à direita (tipo, poder...).
Future<String?> showSearchSheet(BuildContext context,
    {required String title,
    required List<String> options,
    String? emptyLabel,
    String Function(String)? label,
    Widget? Function(String)? trailing}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) =>
        _SearchSheet(title: title, options: options, emptyLabel: emptyLabel, label: label, trailing: trailing),
  );
}

class _SearchSheet extends StatefulWidget {
  final String title;
  final List<String> options;
  final String? emptyLabel;
  final String Function(String)? label;
  final Widget? Function(String)? trailing;
  const _SearchSheet({required this.title, required this.options, this.emptyLabel, this.label, this.trailing});
  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final q = _id(_query);
    String text(String o) => widget.label?.call(o) ?? o;
    final list = q.isEmpty ? widget.options : widget.options.where((o) => _id(text(o)).contains(q)).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(widget.title, style: TextStyle(color: c.text, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SiteSearchField(hint: 'Buscar', onChanged: (v) => setState(() => _query = v)),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: list.length + (widget.emptyLabel != null && q.isEmpty ? 1 : 0),
                itemBuilder: (context, i) {
                  if (widget.emptyLabel != null && q.isEmpty) {
                    if (i == 0) {
                      return ListTile(
                        title: Text(widget.emptyLabel!, style: TextStyle(color: c.muted)),
                        onTap: () => Navigator.pop(context, ''),
                      );
                    }
                    i--;
                  }
                  return ListTile(
                    title: Text(text(list[i]), style: TextStyle(color: c.text)),
                    trailing: widget.trailing?.call(list[i]),
                    onTap: () => Navigator.pop(context, list[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

