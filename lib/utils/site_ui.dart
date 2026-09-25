// lib/utils/site_ui.dart
//
// Componentes com o mesmo visual do site (web-site/src/components/ui.jsx):
// cores do tema, cabeçalho de página, cards arredondados, botões "pílula",
// etiquetas de tipo, campo de busca e cards de ferramenta.

import 'package:flutter/material.dart';

import 'pokemon_colors.dart';
import 'string_extensions.dart';

/// Cores do site (as mesmas variáveis --bg, --surface, --card, --muted, --line).
class SiteColors {
  final Color bg;
  final Color surface;
  final Color card;
  final Color text;
  final Color muted;
  final Color line;
  const SiteColors({required this.bg, required this.surface, required this.card, required this.text, required this.muted, required this.line});

  static const dark = SiteColors(
    bg: Color(0xFF363636),
    surface: Color(0xFF303030),
    card: Color(0xFF464646),
    text: Colors.white,
    muted: Color(0xFFBDBDBD),
    line: Color(0xFF4A4A4A),
  );
  static const light = SiteColors(
    bg: Color(0xFFF5F5F5),
    surface: Colors.white,
    card: Colors.white,
    text: Color(0xFF111111),
    muted: Color(0xFF616161),
    line: Color(0xFFE0E0E0),
  );

  static SiteColors of(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Cores de cada seção (as mesmas do menu do app e do site).
class SectionColors {
  static const pokedex = Color(0xFF26A69A);
  static const favorites = Color(0xFFFFCA28);
  static const teams = Color(0xFFFF5252);
  static const game = Color(0xFF42A5F5);
  static const encyclopedia = Color(0xFFAB47BC);
  static const training = Color(0xFFFFA726);
}

const _cardShadow = [BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4))];

/// Título de página com subtítulo e ação à direita (ex.: "+ Novo time").
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  const PageHeader({super.key, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: c.text)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: TextStyle(fontSize: 13, color: c.muted)),
                ],
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: 12), action!],
        ],
      ),
    );
  }
}

/// Card arredondado do site, que encolhe um pouco ao tocar.
class SiteCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Gradient? gradient;
  final Color? accentLeft;
  final Color? accentTop;
  final double radius;
  const SiteCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.gradient,
    this.accentLeft,
    this.accentTop,
    this.radius = 24,
  });

  @override
  State<SiteCard> createState() => _SiteCardState();
}

class _SiteCardState extends State<SiteCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final radius = BorderRadius.circular(widget.radius);
    Widget content = Padding(padding: widget.padding, child: widget.child);
    if (widget.accentLeft != null || widget.accentTop != null) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: widget.accentLeft != null ? BorderSide(color: widget.accentLeft!, width: 8) : BorderSide.none,
            top: widget.accentTop != null ? BorderSide(color: widget.accentTop!, width: 4) : BorderSide.none,
          ),
        ),
        child: content,
      );
    }
    final card = AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 120),
      child: Container(
        decoration: BoxDecoration(
          color: widget.gradient == null ? (widget.color ?? c.card) : null,
          gradient: widget.gradient,
          borderRadius: radius,
          boxShadow: _cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: widget.onTap == null ? null : (v) => setState(() => _pressed = v),
            child: content,
          ),
        ),
      ),
    );
    return card;
  }
}

/// Botão "pílula" colorido (igual ao Button do site).
class PillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Gradient? gradient;
  final IconData? icon;
  final bool expand;
  final Color foreground;
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = const Color(0xFF2196F3),
    this.gradient,
    this.icon,
    this.expand = false,
    this.foreground = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 20, color: foreground), const SizedBox(width: 6)],
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: foreground, fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      ],
    );
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: gradient == null ? color : null,
            gradient: gradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPressed,
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11), child: child),
          ),
        ),
      ),
    );
  }
}

/// Etiqueta de tipo (Fire, Water...).
class TypeBadge extends StatelessWidget {
  final String type;
  final bool small;
  const TypeBadge(this.type, {super.key, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 12, vertical: small ? 2 : 4),
      decoration: BoxDecoration(color: getColorForType(type), borderRadius: BorderRadius.circular(30)),
      child: Text(type.capitalise(),
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: small ? 11 : 12)),
    );
  }
}

/// Campo de busca arredondado.
class SiteSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String hint;
  const SiteSearchField({super.key, this.controller, this.onChanged, required this.hint});

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(color: c.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.muted),
        prefixIcon: Icon(Icons.search, color: c.muted),
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: c.line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: c.line)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 2)),
      ),
    );
  }
}

/// Card de ferramenta: ícone num círculo, título e subtítulo, na cor da ferramenta.
class ToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const ToolCard({super.key, required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SiteCard(
      color: color,
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(color: Color(0x33FFFFFF), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 13)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white),
        ],
      ),
    );
  }
}

/// Mensagem para listas vazias.
class EmptyMessage extends StatelessWidget {
  final String text;
  const EmptyMessage(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
        child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: SiteColors.of(context).muted, fontSize: 15)),
      );
}
