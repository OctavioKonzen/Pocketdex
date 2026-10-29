// lib/widgets/medal_badge.dart
//
// Uma medalha do álbum (services/medals.dart): o desenho do Pokémon na cor
// dele (liberada) ou só a sombra (trancada). Igual ao site (Medal em
// web-site/src/components/Achievements.jsx).

import 'package:flutter/material.dart' hide Text;

import '../i18n/text.dart';
import '../services/app_settings.dart';
import '../services/medals.dart';
import '../utils/site_ui.dart';
import 'pokemon_theme_art.dart';

/// Uma medalha do álbum.
class MedalBadge extends StatelessWidget {
  final Medal medal;
  final bool unlocked;
  const MedalBadge({super.key, required this.medal, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final color = AppSettings.themeColorOf(medal.pokemon);
    final fill = unlocked && color != null ? color : const Color(0xFF4B5563);
    final line = unlocked && color != null ? Color.lerp(color, Colors.black, 0.85)! : const Color(0xFF1F2937);
    return Tooltip(
      message: tr(medal.text),
      child: Column(key: ValueKey('medal-${medal.id}'), children: [
        Opacity(
          opacity: unlocked ? 1 : 0.6,
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 76,
              height: 76,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: unlocked && color != null ? color : c.line, width: 4),
                gradient: unlocked && color != null ? RadialGradient(colors: [color.withAlpha(0x55), Colors.transparent]) : null,
                color: unlocked ? null : c.surface,
                boxShadow: unlocked && color != null ? [BoxShadow(color: color.withAlpha(0x55), blurRadius: 10)] : null,
              ),
              child: PokemonThemeArt(medal.pokemon, fill: fill, line: line),
            ),
            if (!unlocked) const Positioned(right: -2, bottom: -2, child: Text('🔒', style: TextStyle(fontSize: 15))),
          ]),
        ),
        const SizedBox(height: 4),
        Text(medal.title, textAlign: TextAlign.center, style: TextStyle(color: c.text, fontSize: 12, fontWeight: FontWeight.bold)),
        Text(medal.text, textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 10)),
      ]),
    );
  }
}

