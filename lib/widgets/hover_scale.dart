// lib/widgets/hover_scale.dart

import 'package:flutter/material.dart';

/// Aumenta suavemente o [child] quando o mouse passa por cima (efeito de site).
/// No celular não há hover, então nada muda.
class HoverScale extends StatefulWidget {
  final Widget child;
  final double scale;
  final Duration duration;
  final MouseCursor cursor;

  /// Chamado quando o mouse entra (true) ou sai (false).
  final ValueChanged<bool>? onHoverChanged;

  const HoverScale({
    super.key,
    required this.child,
    this.scale = 1.06,
    this.duration = const Duration(milliseconds: 180),
    this.cursor = SystemMouseCursors.click,
    this.onHoverChanged,
  });

  @override
  State<HoverScale> createState() => _HoverScaleState();
}

class _HoverScaleState extends State<HoverScale> {
  bool _hovering = false;

  void _setHover(bool value) {
    if (_hovering == value) return;
    setState(() => _hovering = value);
    widget.onHoverChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.cursor,
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: AnimatedScale(
        scale: _hovering ? widget.scale : 1.0,
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Botão redondo com ícone, usado no painel de detalhes do site.
class HoverIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? iconColor;
  final double size;

  const HoverIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconColor,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: HoverScale(
        scale: 1.15,
        child: Material(
          color: Colors.white.withAlpha(51),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => RotationTransition(
                  turns: Tween(begin: 0.75, end: 1.0).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Icon(icon,
                    key: ValueKey('$icon$iconColor'),
                    color: iconColor ?? Colors.white,
                    size: size),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
