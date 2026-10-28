// lib/utils/site_ui.dart
//
// Componentes com o mesmo visual do site (web-site/src/components/ui.jsx):
// cores do tema, cabeçalho de página, cards arredondados, botões "pílula",
// etiquetas de tipo, campo de busca e cards de ferramenta.

import 'package:flutter/material.dart' hide Text;

import 'pokemon_colors.dart';
import 'string_extensions.dart';
import '../services/app_settings.dart';
import '../widgets/pokemon_sprite.dart';
import 'package:pocket_dex/i18n/text.dart';

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
    bg: Color(0xFF0E1014),
    surface: Color(0xFF12141A),
    card: Color(0xFF1B1F27),
    text: Color(0xFFF3F4F6),
    muted: Color(0xFF9AA1AE),
    line: Color(0xFF272C37),
  );
  static const light = SiteColors(
    bg: Color(0xFFF4F5F7),
    surface: Colors.white,
    card: Colors.white,
    text: Color(0xFF12141A),
    muted: Color(0xFF5F6673),
    line: Color(0xFFE2E5EA),
  );

  /// As cores puxadas para [accent] (os temas coloridos das Configurações).
  static SiteColors tinted(Color accent, Brightness brightness) {
    final h = HSLColor.fromColor(accent).hue;
    Color hsl(double s, double l) => HSLColor.fromAHSL(1, h, s, l).toColor();
    return brightness == Brightness.dark
        ? SiteColors(bg: hsl(0.30, 0.07), surface: hsl(0.28, 0.09), card: hsl(0.24, 0.13), text: const Color(0xFFF3F4F6), muted: hsl(0.14, 0.68), line: hsl(0.20, 0.20))
        : SiteColors(bg: hsl(0.45, 0.95), surface: Colors.white, card: Colors.white, text: hsl(0.30, 0.08), muted: hsl(0.12, 0.40), line: hsl(0.30, 0.87));
  }

  /// As cores do tema escolhido nas Configurações (claro ou escuro).
  static SiteColors forBrightness(Brightness brightness) {
    final accent = AppSettings.instance.themeAccent;
    if (accent != null) return tinted(accent, brightness);
    return brightness == Brightness.dark ? dark : light;
  }

  static SiteColors of(BuildContext context) => forBrightness(Theme.of(context).brightness);
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

/// Vermelho das chamadas acima dos títulos (o mesmo do site).
const eyebrowColor = Color(0xFFEF3B36);

/// Título de página com subtítulo e ação à direita (ex.: "+ Novo time"). Com
/// [eyebrow], uma chamada curta em vermelho acima do título (como no site).
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? eyebrow;
  final Widget? action;
  const PageHeader({super.key, required this.title, this.subtitle, this.eyebrow, this.action});

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          Text(tr(eyebrow!).toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: eyebrowColor)),
          const SizedBox(height: 4),
        ],
        Text(title, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: c.text)),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: TextStyle(fontSize: 13, color: c.muted)),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      // Em tela estreita a ação desce para baixo do título, em vez de espremê-lo.
      child: LayoutBuilder(
        builder: (context, box) => action == null
            ? text
            : box.maxWidth < 440
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [text, const SizedBox(height: 10), action!],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [Expanded(child: text), const SizedBox(width: 12), action!],
                  ),
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
        hintText: tr(hint),
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

/// Card de modo/ferramenta do novo visual (o ModeCard do site): fundo escuro
/// com borda, ícone na cor da ferramenta, título e o Pokémon animado com a
/// altura do card, apoiado embaixo à direita (sem [pokemon], só ícone e título).
/// [compact]: card pequeno (título embaixo, na largura toda).
class ModeCard extends StatelessWidget {
  final String title;
  final Color color;
  final IconData? icon;
  final String? emoji;
  final int? pokemon;
  final bool shiny;
  final String? tag;
  final double height;
  final bool compact;
  final VoidCallback onTap;
  const ModeCard({
    super.key,
    required this.title,
    required this.color,
    required this.onTap,
    this.pokemon,
    this.icon,
    this.emoji,
    this.shiny = false,
    this.tag,
    this.height = 132,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final radius = BorderRadius.circular(18);
    final badge = Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withAlpha(0x26), borderRadius: BorderRadius.circular(12)),
      child: emoji != null ? Text(emoji!, style: const TextStyle(fontSize: 20)) : Icon(icon, color: color, size: 22),
    );
    final name = Text(title, style: TextStyle(color: c.text, fontWeight: FontWeight.w700, fontSize: compact ? 15 : 17, height: 1.2));
    final sprite = pokemon == null ? null : PokemonSprite(pokemon!, shiny: shiny, fill: 0.96, alignBottom: true);
    return SizedBox(
      height: height,
      child: Material(
        color: c.card,
        shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: c.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              if (sprite != null && compact)
                Positioned(top: 6, right: 6, width: height * 0.58, height: height * 0.58, child: sprite)
              else if (sprite != null)
                Positioned(top: 8, right: 8, bottom: 8, child: AspectRatio(aspectRatio: 1, child: sprite)),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 16, compact || sprite == null ? 12 : height - 8, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [badge, const Spacer(), if (compact) FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: name) else name],
                ),
              ),
              if (tag != null)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFFFCB05), borderRadius: BorderRadius.circular(20)),
                    child: Text(tag!, style: const TextStyle(color: Color(0xFF16130A), fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ),
            ],
          ),
        ),
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
