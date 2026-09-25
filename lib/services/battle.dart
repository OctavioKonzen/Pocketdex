// lib/services/battle.dart
//
// Contas de batalha — iguais às do site (web-site/src/lib/battle.js).
// Nível 50, IVs 31 e Nature neutra; EVs 0 ou 252 conforme a escolha.

class DamageResult {
  final int min;
  final int max;
  final int hp;
  final double minPct;
  final double maxPct;
  final double mult;
  final bool stab;
  final int? hits;
  const DamageResult(this.min, this.max, this.hp, this.minPct, this.maxPct, this.mult, this.stab, this.hits);
}

class Battle {
  Battle._();

  static const level = 50;

  /// Status final: HP (index 0) tem outra fórmula.
  static int statAt(int base, int index, [int ev = 0]) {
    final core = ((2 * base + 31 + ev ~/ 4) * level) ~/ 100;
    return index == 0 ? core + level + 10 : core + 5;
  }

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

  /// Dano de um golpe (fórmula das gerações 5+), sem crítico, clima ou itens.
  /// stats = status base [hp, atk, def, spa, spd, spe].
  static DamageResult damage({
    required List<String> attackerTypes,
    required List<int> attackerStats,
    required List<String> defenderTypes,
    required List<int> defenderStats,
    required String moveType,
    required bool physical,
    required int power,
    required Map<String, Map<String, List<String>>> typeData,
    int attackEv = 0,
    int defenseEv = 0,
    int hpEv = 0,
  }) {
    final a = statAt(attackerStats[physical ? 1 : 3], physical ? 1 : 3, attackEv);
    final d = statAt(defenderStats[physical ? 2 : 4], physical ? 2 : 4, defenseEv);
    final hp = statAt(defenderStats[0], 0, hpEv);
    final mult = effectiveness(moveType, defenderTypes, typeData);
    final stab = attackerTypes.contains(moveType) ? 1.5 : 1.0;
    final base = ((((2 * level) ~/ 5 + 2) * power * a) ~/ d) ~/ 50 + 2;
    int roll(double r) => (((base * r).floor() * stab).floor() * mult).floor();
    final min = roll(0.85);
    final max = roll(1);
    double pct(int n) => (n / hp * 1000).round() / 10;
    return DamageResult(min, max, hp, pct(min), pct(max), mult, stab > 1, max > 0 ? (hp / max).ceil() : null);
  }
}
