// lib/services/battle.dart
//
// Efetividade de tipos (usada no Comparar e na análise de times). O dano fica
// em lib/services/damage_calc.dart (a mesma conta do Pokémon Showdown).

class Battle {
  Battle._();

  /// Multiplicador de um tipo de golpe contra os tipos do defensor.
  /// `typeData[tipo]` = {double_damage_from, half_damage_from, no_damage_from}.
  static double effectiveness(String moveType, List<String> defenderTypes, Map<String, Map<String, List<String>>> typeData) {
    var mult = 1.0;
    for (final type in defenderTypes) {
      final rel = typeData[type];
      if (rel == null) continue;
      if (rel['double_damage_from']!.contains(moveType)) mult *= 2;
      if (rel['half_damage_from']!.contains(moveType)) mult *= 0.5;
      if (rel['no_damage_from']!.contains(moveType)) mult *= 0;
    }
    return mult;
  }
}
