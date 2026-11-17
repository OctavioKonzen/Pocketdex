// lib/utils/ivs.dart
//
// Calculadora de IVs (a mesma conta do site, web-site/src/lib/ivs.js).

import '../services/team_sets.dart';

/// Multiplicador da Nature para o status i (0 = HP, 1 = Attack ... 5 = Speed).
double natureMultiplier(String nature, int i) {
  final n = natures[nature];
  if (n == null || i == 0 || n.$1 == n.$2) return 1;
  if (n.$1 == i) return 1.1;
  if (n.$2 == i) return 0.9;
  return 1;
}

/// Status final (fórmula dos jogos a partir da Gen 3).
int statValue(int i, int base, int iv, int ev, int level, String nature) {
  final core = ((2 * base + iv + ev ~/ 4) * level) ~/ 100;
  if (i == 0) return base == 1 ? 1 : core + level + 10; // Shedinja
  return ((core + 5) * natureMultiplier(nature, i)).floor();
}

/// IVs (0–31) que dão exatamente o status mostrado; vazio se nenhum.
List<int> possibleIvs(int i, int base, int shown, int ev, int level, String nature) => [
      for (var iv = 0; iv <= 31; iv++)
        if (statValue(i, base, iv, ev, level, nature) == shown) iv,
    ];
