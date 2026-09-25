// lib/services/battle.dart
//
// Contas de batalha — iguais às do site (web-site/src/lib/battle.js).
// Fórmula de dano das gerações 5+ (com Tera da geração 9), arredondando para
// baixo a cada passo. É uma aproximação muito boa do jogo; não inclui
// habilidades nem os casos especiais de golpes.

import 'dart:math';

/// Nature → (status que aumenta, status que diminui) (1 Atk, 2 Def, 3 SpA, 4 SpD, 5 Spe).
const natures = <String, (int, int)>{
  'Hardy': (0, 0), 'Lonely': (1, 2), 'Brave': (1, 5), 'Adamant': (1, 3), 'Naughty': (1, 4),
  'Bold': (2, 1), 'Docile': (0, 0), 'Relaxed': (2, 5), 'Impish': (2, 3), 'Lax': (2, 4),
  'Timid': (5, 1), 'Hasty': (5, 2), 'Serious': (0, 0), 'Jolly': (5, 3), 'Naive': (5, 4),
  'Modest': (3, 1), 'Mild': (3, 2), 'Quiet': (3, 5), 'Bashful': (0, 0), 'Rash': (3, 4),
  'Calm': (4, 1), 'Gentle': (4, 2), 'Sassy': (4, 5), 'Careful': (4, 3), 'Quirky': (0, 0),
};

const attackerItems = <String, String>{
  'none': 'Nenhum',
  'lifeOrb': 'Life Orb (×1.3)',
  'choice': 'Choice Band / Specs (×1.5 no ataque)',
  'expertBelt': 'Expert Belt (×1.2 se super efetivo)',
  'typeBoost': 'Item do tipo do golpe (×1.2)',
};

const defenderItems = <String, String>{
  'none': 'Nenhum',
  'assaultVest': 'Assault Vest (×1.5 Sp. Def)',
  'eviolite': 'Eviolite (×1.5 Def e Sp. Def)',
};

const weathers = <String, String>{
  'none': 'Nenhum',
  'sun': 'Sol',
  'rain': 'Chuva',
  'sand': 'Tempestade de areia',
  'snow': 'Neve',
};

/// Um lado da batalha (atacante ou defensor).
class BattleSide {
  final List<String> types;
  final List<int> stats; // status base [hp, atk, def, spa, spd, spe]
  final int level;
  final String nature;
  final Map<String, int> evs; // hp, atk, def, spa, spd
  final int ivs;
  final int stage;
  final String item;
  final String? tera;
  final bool burned;

  const BattleSide({
    required this.types,
    required this.stats,
    this.level = 50,
    this.nature = 'Hardy',
    this.evs = const {},
    this.ivs = 31,
    this.stage = 0,
    this.item = 'none',
    this.tera,
    this.burned = false,
  });
}

class DamageResult {
  final int min;
  final int max;
  final int hp;
  final double minPct;
  final double maxPct;
  final double mult;
  final double stabMult;
  final List<int> rolls;
  final int? hits;
  final double chance;
  final int attack;
  final int defense;
  const DamageResult(this.min, this.max, this.hp, this.minPct, this.maxPct, this.mult, this.stabMult, this.rolls, this.hits,
      this.chance, this.attack, this.defense);

  bool get stab => stabMult > 1;

  /// "Derrota com 1 golpe, garantido." / "37,5% de chance de derrotar com 1 golpe."
  String get koText {
    if (hits == null) return 'Não causa dano.';
    final n = hits == 1 ? '1 golpe' : '$hits golpes';
    if (chance >= 0.9999) return 'Derrota com $n, garantido.';
    return '${(chance * 100).toStringAsFixed(1).replaceAll('.', ',')}% de chance de derrotar com $n.';
  }
}

class Battle {
  Battle._();

  static const level = 50;

  static double _natureMult(String nature, int index) {
    final (up, down) = natures[nature] ?? (0, 0);
    if (up == down) return 1;
    return index == up ? 1.1 : (index == down ? 0.9 : 1);
  }

  /// Status final (HP é o index 0 e tem outra fórmula).
  static int statAt(int base, int index, [int ev = 0, int lvl = level, int iv = 31, String nature = 'Hardy']) {
    final core = ((2 * base + iv + ev ~/ 4) * lvl) ~/ 100;
    if (index == 0) return base == 1 ? 1 : core + lvl + 10; // Shedinja
    return ((core + 5) * _natureMult(nature, index)).floor();
  }

  /// Multiplicador de estágio (-6 a +6).
  static double stageMult(int stage) => stage >= 0 ? (2 + stage) / 2 : 2 / (2 - stage);

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

  /// Chance (0 a 1) de derrotar com `hits` golpes, somando as 16 variações de dano.
  static double koChance(List<int> rolls, int hp, int hits) {
    var dist = <int, double>{0: 1};
    for (var h = 0; h < hits; h++) {
      final next = <int, double>{};
      dist.forEach((sum, p) {
        for (final r in rolls) {
          final s = min(hp, sum + r);
          next[s] = (next[s] ?? 0) + p / rolls.length;
        }
      });
      dist = next;
    }
    return dist[hp] ?? 0;
  }

  /// Dano de um golpe. field: clima, crítico, tela (Reflect/Light Screen) e golpe em área (duplas).
  static DamageResult damage({
    required BattleSide attacker,
    required BattleSide defender,
    required String moveType,
    required bool physical,
    required int power,
    required Map<String, Map<String, List<String>>> typeData,
    String weather = 'none',
    bool crit = false,
    bool screen = false,
    bool spread = false,
  }) {
    final aIdx = physical ? 1 : 3;
    final dIdx = physical ? 2 : 4;
    final aKey = physical ? 'atk' : 'spa';
    final dKey = physical ? 'def' : 'spd';

    var a = statAt(attacker.stats[aIdx], aIdx, attacker.evs[aKey] ?? 0, attacker.level, attacker.ivs, attacker.nature);
    var d = statAt(defender.stats[dIdx], dIdx, defender.evs[dKey] ?? 0, defender.level, defender.ivs, defender.nature);
    final hp = statAt(defender.stats[0], 0, defender.evs['hp'] ?? 0, defender.level, defender.ivs);
    // No crítico, estágios ruins do atacante e bons do defensor são ignorados.
    final aStage = crit ? max(0, attacker.stage) : attacker.stage;
    final dStage = crit ? min(0, defender.stage) : defender.stage;
    a = (a * stageMult(aStage)).floor();
    d = (d * stageMult(dStage)).floor();
    if (attacker.item == 'choice') a = (a * 1.5).floor();
    if (!physical && (defender.item == 'assaultVest' || defender.item == 'eviolite')) d = (d * 1.5).floor();
    if (physical && defender.item == 'eviolite') d = (d * 1.5).floor();

    final defTypes = defender.tera != null ? [defender.tera!] : defender.types;
    if (weather == 'sand' && !physical && defTypes.contains('rock')) d = (d * 1.5).floor();
    if (weather == 'snow' && physical && defTypes.contains('ice')) d = (d * 1.5).floor();

    final mult = effectiveness(moveType, defTypes, typeData);
    // STAB: tipo original 1.5; com Tera do mesmo tipo do golpe, 2 se também era original.
    final original = attacker.types.contains(moveType);
    final teraMatch = attacker.tera == moveType;
    final stab = teraMatch ? (original ? 2.0 : 1.5) : (original ? 1.5 : 1.0);

    var base = ((((2 * attacker.level) ~/ 5 + 2) * power * a) ~/ d) ~/ 50 + 2;
    if (spread) base = (base * 0.75).floor();
    if (weather == 'sun') base = (base * (moveType == 'fire' ? 1.5 : (moveType == 'water' ? 0.5 : 1))).floor();
    if (weather == 'rain') base = (base * (moveType == 'water' ? 1.5 : (moveType == 'fire' ? 0.5 : 1))).floor();
    if (crit) base = (base * 1.5).floor();

    final rolls = <int>[];
    for (var r = 85; r <= 100; r++) {
      var x = (base * r) ~/ 100;
      x = (x * stab).floor();
      x = (x * mult).floor();
      if (physical && attacker.burned) x = (x * 0.5).floor();
      if (screen && !crit) x = (x * 0.5).floor();
      if (attacker.item == 'lifeOrb') x = (x * 1.3).floor();
      if (attacker.item == 'expertBelt' && mult > 1) x = (x * 1.2).floor();
      if (attacker.item == 'typeBoost') x = (x * 1.2).floor();
      if (mult > 0 && x < 1) x = 1;
      rolls.add(x);
    }
    double pct(int n) => (n / hp * 1000).round() / 10;
    int? hits;
    var chance = 0.0;
    if (rolls.last > 0) {
      for (var n = 1; n <= 10; n++) {
        final c = koChance(rolls, hp, n);
        if (c > 0) {
          hits = n;
          chance = c;
          break;
        }
      }
    }
    return DamageResult(rolls.first, rolls.last, hp, pct(rolls.first), pct(rolls.last), mult, stab, rolls, hits, chance, a, d);
  }
}
