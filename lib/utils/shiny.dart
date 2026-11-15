// lib/utils/shiny.dart
//
// Chance de shiny por método (a mesma lista do site, web-site/src/lib/shiny.js).

import 'dart:math';

class ShinyMethod {
  final String key;
  final String label;
  final int odds;
  const ShinyMethod(this.key, this.label, this.odds);
}

const shinyMethods = [
  ShinyMethod('full', 'Encontro normal (Gen 6+)', 4096),
  ShinyMethod('old', 'Encontro normal (Gen 2–5)', 8192),
  ShinyMethod('charm', 'Com Shiny Charm', 1365),
  ShinyMethod('masuda', 'Método Masuda (ovos)', 683),
  ShinyMethod('masuda-charm', 'Masuda + Shiny Charm', 512),
  ShinyMethod('outbreak', 'Surto em massa + Shiny Charm (SV)', 512),
  ShinyMethod('sandwich', 'Sanduíche Sparkling + surto + Charm (SV)', 410),
  ShinyMethod('sos', 'Chamado SOS (31+) + Shiny Charm', 273),
];

ShinyMethod shinyMethod(String? key) => shinyMethods.firstWhere((m) => m.key == key, orElse: () => shinyMethods.first);

/// Chance (0–1) de já ter aparecido um shiny depois de [count] encontros.
double shinyChanceSoFar(int count, int odds) => 1 - pow(1 - 1 / odds, count).toDouble();
