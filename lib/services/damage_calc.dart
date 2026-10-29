// lib/services/damage_calc.dart
//
// Calculadora de dano da geração 9: tradução para Dart da calculadora oficial
// do Pokémon Showdown (@smogon/calc, licença MIT — mesma conta do site).
// A ordem das contas e os arredondamentos seguem o original passo a passo;
// test/damage_calc_test.dart confere milhares de situações contra ele.
//
// Os dados (golpes, itens, espécies, Natures e tipos) vêm de
// assets/database/damage_data.json, gerado por
// web-site/scripts/build-damage-data.mjs.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

String toId(String? s) => (s ?? '').toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

// ---------------------------------------------------------------- dados

class MoveInfo {
  MoveInfo(List<dynamic> row)
      : name = row[0] as String,
        type = row[1] as String,
        category = row[2] as String,
        basePower = (row[3] as num).toInt(),
        priority = (row[4] as num).toInt(),
        target = row[5] as String,
        flags = (row[6] as List).cast<String>().toSet(),
        multihit = row[7],
        bits = (row[8] as num).toInt(),
        dropsStats = (row[9] as num).toInt(),
        overrideDefensiveStat = row[10] as String;

  final String name, type, category, target, overrideDefensiveStat;
  final int basePower, priority, bits, dropsStats;
  final Set<String> flags;

  /// 0, um número ou [mínimo, máximo].
  final dynamic multihit;

  bool _bit(int b) => bits & b != 0;
  bool get secondaries => _bit(1);
  bool get recoil => _bit(2);
  bool get hasCrashDamage => _bit(4);
  bool get mindBlownRecoil => _bit(8);
  bool get struggleRecoil => _bit(16);
  bool get willCrit => _bit(32);
  bool get drain => _bit(64);
  bool get ignoreDefensive => _bit(128);
  bool get breaksProtect => _bit(256);
  bool get multiaccuracy => _bit(512);
  bool get isZ => _bit(1024);
  bool get isMax => _bit(2048);
}

class ItemInfo {
  ItemInfo(Map<String, dynamic> m)
      : boostType = m['b'] as String?,
        resistType = m['r'] as String?,
        fling = (m['f'] as num?)?.toInt() ?? 0,
        naturalGift = m['g'] as List?,
        megaStone = (m['m'] as List?)?.cast<String>() ?? const [],
        isBerry = m['y'] == 1,
        technoBlast = m['t'] as String?,
        multiAttack = m['a'] as String?;

  final String? boostType, resistType, technoBlast, multiAttack;
  final int fling;
  final List? naturalGift;
  final List<String> megaStone;
  final bool isBerry;
}

class SpeciesInfo {
  SpeciesInfo(List<dynamic> row)
      : name = row[0] as String,
        nfe = row[1] == 1,
        gender = row[2] as String,
        ability = row.length > 3 ? row[3] as String : '';

  final String name, gender, ability;
  final bool nfe;
}

class DamageData {
  DamageData(Map<String, dynamic> json)
      : moves = (json['moves'] as Map<String, dynamic>).map((k, v) => MapEntry(k, MoveInfo(v as List))),
        items = (json['items'] as Map<String, dynamic>).map((k, v) => MapEntry(k, ItemInfo(v as Map<String, dynamic>))),
        species = (json['species'] as Map<String, dynamic>).map((k, v) => MapEntry(k, SpeciesInfo(v as List))),
        natures = (json['natures'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as List).cast<String>())),
        types = (json['types'] as Map<String, dynamic>).map((k, v) =>
            MapEntry(k, (v as Map<String, dynamic>).map((t, e) => MapEntry(t, (e as num).toDouble())))),
        abilities = (json['abilities'] as List).cast<String>(),
        seedStat = (json['seedStat'] as Map<String, dynamic>).cast<String, String>() {
    for (final name in items.keys) {
      _itemsById[toId(name)] = name;
    }
    for (final a in abilities) {
      _abilitiesById[toId(a)] = a;
    }
  }

  final Map<String, MoveInfo> moves;
  final Map<String, ItemInfo> items;
  final Map<String, SpeciesInfo> species;
  final Map<String, List<String>> natures;
  final Map<String, Map<String, double>> types;
  final List<String> abilities;
  final Map<String, String> seedStat;
  final _itemsById = <String, String>{};
  final _abilitiesById = <String, String>{};

  static DamageData? _instance;
  static DamageData? get instance => _instance;

  static Future<DamageData> load() async {
    return _instance ??= DamageData(
        jsonDecode(await rootBundle.loadString('assets/database/damage_data.json')) as Map<String, dynamic>);
  }

  static void setForTest(DamageData data) => _instance = data;

  MoveInfo? move(String name) => moves[toId(name)];
  String itemName(String text) => _itemsById[toId(text)] ?? '';
  String abilityName(String text) => _abilitiesById[toId(text)] ?? '';

  /// Nome da espécie no Showdown ("tauros-paldea-combat-breed" → "Tauros-Paldea-Combat").
  String speciesName(String slug) {
    const aliases = {
      'necrozma-dusk': 'Necrozma-Dusk-Mane',
      'necrozma-dawn': 'Necrozma-Dawn-Wings',
      'zygarde-10-power-construct': 'Zygarde-10%',
      'zygarde-10': 'Zygarde-10%',
      'zygarde-50-power-construct': 'Zygarde',
      'meowstic-female': 'Meowstic-F',
      'indeedee-female': 'Indeedee-F',
      'basculegion-female': 'Basculegion-F',
      'oinkologne-female': 'Oinkologne-F',
      'ogerpon-wellspring-mask': 'Ogerpon-Wellspring',
      'ogerpon-hearthflame-mask': 'Ogerpon-Hearthflame',
      'ogerpon-cornerstone-mask': 'Ogerpon-Cornerstone',
      'greninja-battle-bond': 'Greninja-Bond',
      'rockruff-own-tempo': 'Rockruff',
      'minior-red-meteor': 'Minior-Meteor',
    };
    if (aliases.containsKey(slug)) return aliases[slug]!;
    final parts = slug.split('-');
    for (var n = parts.length; n > 0; n--) {
      final sp = species[toId(parts.sublist(0, n).join('-'))];
      if (sp != null) return sp.name;
    }
    return 'Mew';
  }

  double effectiveness(String moveType, String defType) => types[moveType]?[defType] ?? 1;
}

// ---------------------------------------------------------------- números

num of16(num n) => n > 65535 ? n % 65536 : n;
num of32(num n) => n > 4294967295 ? n % 4294967296 : n;

int pokeRound(num n) => n.remainder(1) > 0.5 ? n.ceil() : n.floor();

int _toInt32(num x) {
  var v = x.truncate() & 0xFFFFFFFF;
  if (v >= 0x80000000) v -= 0x100000000;
  return v;
}

int chainMods(List<int> mods, int lower, int upper) {
  var m = 4096;
  for (final mod in mods) {
    if (mod != 4096) m = _toInt32(m * mod + 2048) >> 12;
  }
  return m < lower ? lower : (m > upper ? upper : m);
}

int getBaseDamage(int level, int basePower, int attack, int defense) {
  return of32((of32(of32((2 * level / 5 + 2).floor() * basePower) * attack) / defense).floor() / 50 + 2).floor();
}

int getModifiedStat(int stat, int mod) {
  const table = [
    [2, 8], [2, 7], [2, 6], [2, 5], [2, 4], [2, 3], [2, 2], [3, 2], [4, 2], [5, 2], [6, 2], [7, 2], [8, 2], //
  ];
  final s = of16(stat * table[6 + mod][0]);
  return (s / table[6 + mod][1]).floor();
}

// ---------------------------------------------------------------- estado

const statIds = ['hp', 'atk', 'def', 'spa', 'spd', 'spe'];

class CalcPokemon {
  /// [name]: nome da espécie no Showdown; [baseStats], [types] e [weightkg]
  /// vêm dos nossos dados.
  CalcPokemon(
    this.data,
    this.name, {
    required Map<String, int> baseStats,
    required List<String> types,
    required this.weightkg,
    this.level = 100,
    String gender = '',
    String ability = '',
    this.abilityOn = false,
    this.alliesFainted = 0,
    this.boostedStat = '',
    this.item = '',
    this.teraType = '',
    String nature = '',
    Map<String, int>? ivs,
    Map<String, int>? evs,
    Map<String, int>? boosts,
    int curHP = 0,
    this.status = '',
    this.toxicCounter = 0,
  })  : baseStats = Map.of(baseStats),
        speciesTypes = List.of(types),
        types = List.of(types),
        nature = nature.isEmpty ? 'Serious' : nature {
    final sp = data.species[toId(name)];
    this.gender = gender.isNotEmpty ? gender : (sp != null && sp.gender.isNotEmpty ? sp.gender : 'M');
    this.ability = ability.isNotEmpty ? ability : (sp?.ability ?? '');
    nfe = sp?.nfe ?? false;
    this.ivs = {for (final s in statIds) s: ivs?[s] ?? 31};
    this.evs = {for (final s in statIds) s: evs?[s] ?? 0};
    this.boosts = {for (final s in statIds) s: boosts?[s] ?? 0};
    for (final s in statIds) {
      rawStats[s] = _calcStat(s);
      stats[s] = rawStats[s]!;
    }
    originalCurHP = curHP > 0 && curHP <= rawStats['hp']! ? curHP : rawStats['hp']!;
  }

  final DamageData data;
  String name;
  final Map<String, int> baseStats;
  final List<String> speciesTypes;
  List<String> types;
  double weightkg;
  int level;
  late String gender;
  late String ability;
  bool abilityOn;
  int alliesFainted;
  String boostedStat;
  String item;
  String disabledItem = '';
  String teraType;
  String nature;
  late Map<String, int> ivs, evs, boosts;
  final rawStats = <String, int>{};
  final stats = <String, int>{};
  late int originalCurHP;
  String status;
  int toxicCounter;
  late bool nfe;

  int _calcStat(String stat) {
    final base = baseStats[stat]!;
    final iv = ivs[stat]!;
    final ev = evs[stat]!;
    if (stat == 'hp') {
      return base == 1 ? base : ((base * 2 + iv + (ev / 4).floor()) * level / 100).floor() + level + 10;
    }
    final nat = data.natures[nature];
    final plus = nat?[0] ?? '';
    final minus = nat?[1] ?? '';
    final n = plus == stat && minus == stat
        ? 1
        : plus == stat
            ? 1.1
            : minus == stat
                ? 0.9
                : 1;
    return ((((base * 2 + iv + (ev / 4).floor()) * level / 100).floor() + 5) * n).floor();
  }

  int maxHP() => rawStats['hp']!;
  int curHP() => originalCurHP;
  bool hasAbility(List<String> names) => ability.isNotEmpty && names.contains(ability);
  bool hasItem(List<String> names) => item.isNotEmpty && names.contains(item);
  bool hasStatus(List<String> names) => status.isNotEmpty && names.contains(status);
  bool hasType(List<String> list) {
    for (final t in list) {
      if (teraType.isNotEmpty && teraType != 'Stellar' ? teraType == t : types.contains(t)) return true;
    }
    return false;
  }

  bool hasOriginalType(List<String> list) => list.any(types.contains);
  bool named(List<String> names) => names.contains(name);

  CalcPokemon clone() {
    final p = CalcPokemon(
      data,
      name,
      baseStats: baseStats,
      types: speciesTypes,
      weightkg: weightkg,
      level: level,
      gender: gender,
      ability: ability,
      abilityOn: abilityOn,
      alliesFainted: alliesFainted,
      boostedStat: boostedStat,
      item: item,
      teraType: teraType,
      nature: nature,
      ivs: ivs,
      evs: evs,
      boosts: boosts,
      status: status,
      toxicCounter: toxicCounter,
    );
    // Sem habilidade: o clone também fica sem (o construtor usaria a padrão).
    p.ability = ability;
    p.originalCurHP = originalCurHP;
    return p;
  }
}

class CalcMove {
  CalcMove(
    this.data,
    String name, {
    String ability = '',
    this.item = '',
    bool isCrit = false,
    this.isStellarFirstUse = false,
    int hits = 0,
    int timesUsed = 0,
    this.timesUsedWithMetronome = 0,
  }) : originalName = name {
    final info = data.move(name)!;
    this.name = info.name;
    this.ability = ability;
    if (info.multihit != 0) {
      final mh = info.multihit;
      if (info.multiaccuracy && mh is num) {
        this.hits = hits > 0 ? hits : mh.toInt();
      } else if (mh is num) {
        this.hits = mh.toInt();
      } else if (hits > 0) {
        this.hits = hits;
      } else {
        final range = (mh as List).cast<num>();
        this.hits = ability == 'Skill Link' ? range[1].toInt() : range[0].toInt() + 1;
      }
    }
    bp = info.basePower;
    type = info.name == 'Struggle' ? '???' : info.type;
    category = info.category;
    dropsStats = info.dropsStats;
    this.timesUsed = timesUsed > 0 ? timesUsed : 1;
    secondaries = info.secondaries;
    target = info.target;
    recoil = info.recoil;
    hasCrashDamage = info.hasCrashDamage;
    mindBlownRecoil = info.mindBlownRecoil;
    struggleRecoil = info.struggleRecoil;
    this.isCrit = isCrit || info.willCrit;
    drain = info.drain;
    flags = {for (final f in info.flags) f: true};
    priority = info.priority;
    ignoreDefensive = info.ignoreDefensive;
    overrideDefensiveStat = info.overrideDefensiveStat;
    breaksProtect = info.breaksProtect;
    isZ = info.isZ;
    isMax = info.isMax;
    multiaccuracy = info.multiaccuracy;
    if (bp == 0 && const ['Return', 'Frustration', 'Pika Papow', 'Veevee Volley'].contains(info.name)) bp = 102;
  }

  final DamageData data;
  final String originalName;
  late String name;
  late String ability;
  String item;
  int hits = 1;
  late int bp;
  late String type;
  late String category;
  late int dropsStats;
  late int timesUsed;
  int timesUsedWithMetronome;
  late bool secondaries;
  late String target;
  late bool recoil, hasCrashDamage, mindBlownRecoil, struggleRecoil, isCrit, drain;
  bool isStellarFirstUse;
  late Map<String, bool> flags;
  late int priority;
  late bool ignoreDefensive, breaksProtect, isZ, isMax, multiaccuracy;
  late String overrideDefensiveStat;

  bool flag(String f) => flags[f] ?? false;
  bool named(List<String> names) => names.contains(name);
  bool hasType(List<String?> types) => types.contains(type);

  CalcMove clone() => CalcMove(
        data,
        originalName,
        ability: ability,
        item: item,
        isCrit: isCrit,
        isStellarFirstUse: isStellarFirstUse,
        hits: hits,
        timesUsed: timesUsed,
        timesUsedWithMetronome: timesUsedWithMetronome,
      );
}

class CalcSide {
  CalcSide({
    this.spikes = 0,
    this.isSR = false,
    this.isReflect = false,
    this.isLightScreen = false,
    this.isProtected = false,
    this.isSeeded = false,
    this.isNightmared = false,
    this.isSaltCured = false,
    this.isForesight = false,
    this.isCharge = false,
    this.isTailwind = false,
    this.isHelpingHand = false,
    this.isFlowerGift = false,
    this.isPowerTrick = false,
    this.isFriendGuard = false,
    this.isAuroraVeil = false,
    this.isBattery = false,
    this.isPowerSpot = false,
    this.isSteelySpirit = false,
    this.isSwitching = '',
  });

  factory CalcSide.fromJson(Map<String, dynamic>? j) {
    bool b(String k) => j?[k] == true;
    return CalcSide(
      spikes: (j?['spikes'] as num?)?.toInt() ?? 0,
      isSR: b('isSR'),
      isReflect: b('isReflect'),
      isLightScreen: b('isLightScreen'),
      isProtected: b('isProtected'),
      isSeeded: b('isSeeded'),
      isNightmared: b('isNightmared'),
      isSaltCured: b('isSaltCured'),
      isForesight: b('isForesight'),
      isCharge: b('isCharge'),
      isTailwind: b('isTailwind'),
      isHelpingHand: b('isHelpingHand'),
      isFlowerGift: b('isFlowerGift'),
      isPowerTrick: b('isPowerTrick'),
      isFriendGuard: b('isFriendGuard'),
      isAuroraVeil: b('isAuroraVeil'),
      isBattery: b('isBattery'),
      isPowerSpot: b('isPowerSpot'),
      isSteelySpirit: b('isSteelySpirit'),
      isSwitching: (j?['isSwitching'] as String?) ?? '',
    );
  }

  int spikes;
  bool isSR, isReflect, isLightScreen, isProtected, isSeeded, isNightmared, isSaltCured, isForesight, isCharge;
  bool isTailwind, isHelpingHand, isFlowerGift, isPowerTrick, isFriendGuard, isAuroraVeil, isBattery, isPowerSpot;
  bool isSteelySpirit;
  String isSwitching;

  CalcSide clone() => CalcSide(
        spikes: spikes,
        isSR: isSR,
        isReflect: isReflect,
        isLightScreen: isLightScreen,
        isProtected: isProtected,
        isSeeded: isSeeded,
        isNightmared: isNightmared,
        isSaltCured: isSaltCured,
        isForesight: isForesight,
        isCharge: isCharge,
        isTailwind: isTailwind,
        isHelpingHand: isHelpingHand,
        isFlowerGift: isFlowerGift,
        isPowerTrick: isPowerTrick,
        isFriendGuard: isFriendGuard,
        isAuroraVeil: isAuroraVeil,
        isBattery: isBattery,
        isPowerSpot: isPowerSpot,
        isSteelySpirit: isSteelySpirit,
        isSwitching: isSwitching,
      );
}

class CalcField {
  CalcField({
    this.gameType = 'Singles',
    this.weather = '',
    this.terrain = '',
    this.isMagicRoom = false,
    this.isWonderRoom = false,
    this.isGravity = false,
    this.isAuraBreak = false,
    this.isFairyAura = false,
    this.isDarkAura = false,
    this.isBeadsOfRuin = false,
    this.isSwordOfRuin = false,
    this.isTabletsOfRuin = false,
    this.isVesselOfRuin = false,
    CalcSide? attackerSide,
    CalcSide? defenderSide,
  })  : attackerSide = attackerSide ?? CalcSide(),
        defenderSide = defenderSide ?? CalcSide();

  factory CalcField.fromJson(Map<String, dynamic> j) {
    bool b(String k) => j[k] == true;
    return CalcField(
      gameType: (j['gameType'] as String?) ?? 'Singles',
      weather: (j['weather'] as String?) ?? '',
      terrain: (j['terrain'] as String?) ?? '',
      isMagicRoom: b('isMagicRoom'),
      isWonderRoom: b('isWonderRoom'),
      isGravity: b('isGravity'),
      isAuraBreak: b('isAuraBreak'),
      isFairyAura: b('isFairyAura'),
      isDarkAura: b('isDarkAura'),
      isBeadsOfRuin: b('isBeadsOfRuin'),
      isSwordOfRuin: b('isSwordOfRuin'),
      isTabletsOfRuin: b('isTabletsOfRuin'),
      isVesselOfRuin: b('isVesselOfRuin'),
      attackerSide: CalcSide.fromJson(j['attackerSide'] as Map<String, dynamic>?),
      defenderSide: CalcSide.fromJson(j['defenderSide'] as Map<String, dynamic>?),
    );
  }

  String gameType;
  String weather;
  String terrain;
  bool isMagicRoom, isWonderRoom, isGravity, isAuraBreak, isFairyAura, isDarkAura;
  bool isBeadsOfRuin, isSwordOfRuin, isTabletsOfRuin, isVesselOfRuin;
  CalcSide attackerSide, defenderSide;

  bool hasWeather(List<String> list) => weather.isNotEmpty && list.contains(weather);
  bool hasTerrain(List<String> list) => terrain.isNotEmpty && list.contains(terrain);

  CalcField clone() => CalcField(
        gameType: gameType,
        weather: weather,
        terrain: terrain,
        isMagicRoom: isMagicRoom,
        isWonderRoom: isWonderRoom,
        isGravity: isGravity,
        isAuraBreak: isAuraBreak,
        isFairyAura: isFairyAura,
        isDarkAura: isDarkAura,
        isBeadsOfRuin: isBeadsOfRuin,
        isSwordOfRuin: isSwordOfRuin,
        isTabletsOfRuin: isTabletsOfRuin,
        isVesselOfRuin: isVesselOfRuin,
        attackerSide: attackerSide.clone(),
        defenderSide: defenderSide.clone(),
      );
}

/// Resultado: [damage] tem uma lista de danos por acerto (16 valores, ou 1
/// quando o dano é fixo). Vazia = não causa dano.
class CalcResult {
  CalcResult(this.attacker, this.defender, this.move, this.field);

  final CalcPokemon attacker, defender;
  final CalcMove move;
  final CalcField field;
  List<List<int>> damage = const [
    [0]
  ];

  /// Dano mínimo e máximo somando todos os acertos.
  (int, int) range() {
    var min = 0, max = 0;
    for (final hit in damage) {
      min += hit.first;
      max += hit.last;
    }
    return (min, max);
  }

  KOChance kochance() => getKOChance(attacker, defender, move, field, damage);
}

// ---------------------------------------------------------------- utilidades (mechanics/util.js)

const _evItems = ['Macho Brace', 'Power Anklet', 'Power Band', 'Power Belt', 'Power Bracer', 'Power Lens', 'Power Weight'];

bool isGrounded(CalcPokemon p, CalcField field) =>
    field.isGravity ||
    p.hasItem(['Iron Ball']) ||
    (!p.hasType(['Flying']) && !p.hasAbility(['Levitate', 'Eelevate']) && !p.hasItem(['Air Balloon']));

void computeFinalStats(CalcPokemon attacker, CalcPokemon defender, CalcField field, List<String> which) {
  for (final (pokemon, side) in [(attacker, field.attackerSide), (defender, field.defenderSide)]) {
    for (final stat in which) {
      if (stat == 'spe') {
        pokemon.stats['spe'] = getFinalSpeed(pokemon, field, side);
      } else {
        pokemon.stats[stat] = getModifiedStat(pokemon.rawStats[stat]!, pokemon.boosts[stat]!);
      }
    }
  }
}

int getFinalSpeed(CalcPokemon p, CalcField field, CalcSide side) {
  final weather = field.weather;
  final terrain = field.terrain;
  var speed = getModifiedStat(p.rawStats['spe']!, p.boosts['spe']!);
  final mods = <int>[];
  if (side.isTailwind) mods.add(8192);
  if ((p.hasAbility(['Unburden']) && p.abilityOn) ||
      (p.hasAbility(['Chlorophyll']) && weather.contains('Sun')) ||
      (p.hasAbility(['Sand Rush']) && weather == 'Sand') ||
      (p.hasAbility(['Swift Swim']) && weather.contains('Rain')) ||
      (p.hasAbility(['Slush Rush']) && (weather == 'Hail' || weather == 'Snow')) ||
      (p.hasAbility(['Surge Surfer']) && terrain == 'Electric')) {
    mods.add(8192);
  } else if (p.hasAbility(['Quick Feet']) && p.status.isNotEmpty) {
    mods.add(6144);
  } else if (p.hasAbility(['Slow Start']) && p.abilityOn) {
    mods.add(2048);
  } else if (isQPActive(p, field) && getQPBoostedStat(p) == 'spe') {
    mods.add(6144);
  }
  if (!(p.hasAbility(['Unburden']) && p.abilityOn)) {
    if (p.hasItem(['Choice Scarf'])) {
      mods.add(6144);
    } else if (p.hasItem(['Iron Ball', ..._evItems])) {
      mods.add(2048);
    } else if (p.hasItem(['Quick Powder']) && p.named(['Ditto'])) {
      mods.add(8192);
    }
  }
  speed = of32(pokeRound(speed * chainMods(mods, 410, 131172) / 4096)).toInt();
  if (p.hasStatus(['par']) && !p.hasAbility(['Quick Feet'])) {
    speed = (of32(speed * 50) / 100).floor();
  }
  if (speed > 10000) speed = 10000;
  return speed < 0 ? 0 : speed;
}

double getMoveEffectiveness(
    DamageData data, CalcMove move, String type, bool isGhostRevealed, bool isGravity, bool isRingTarget) {
  if (isGhostRevealed && type == 'Ghost' && move.hasType(['Normal', 'Fighting'])) return 1;
  if (isGravity && type == 'Flying' && move.hasType(['Ground'])) return 1;
  if (move.named(['Freeze-Dry']) && type == 'Water') return 2;
  if (move.named(['Nihil Light']) && type == 'Fairy') return 1;
  var e = data.effectiveness(move.type, type);
  if (e == 0 && isRingTarget) e = 1;
  if (move.named(['Flying Press'])) e *= data.effectiveness('Flying', type);
  return e;
}

void checkAirLock(CalcPokemon p, CalcField field) {
  if (p.hasAbility(['Air Lock', 'Cloud Nine'])) field.weather = '';
}

void checkTeraformZero(CalcPokemon p, CalcField field) {
  if (p.hasAbility(['Teraform Zero']) && p.abilityOn) {
    field.weather = '';
    field.terrain = '';
  }
}

void checkForecast(CalcPokemon p, String weather) {
  if (p.hasAbility(['Forecast']) && p.named(['Castform'])) {
    p.types = switch (weather) {
      'Sun' || 'Harsh Sunshine' => ['Fire'],
      'Rain' || 'Heavy Rain' => ['Water'],
      'Hail' || 'Snow' => ['Ice'],
      _ => ['Normal'],
    };
  }
}

void checkItem(CalcPokemon p, bool magicRoom) {
  if ((p.hasAbility(['Klutz']) && !_evItems.contains(p.item)) || magicRoom) {
    p.disabledItem = p.item;
    p.item = '';
  }
}

void checkRawStatChanges(CalcPokemon p, bool powerTrick, bool wonderRoom) {
  if (powerTrick) {
    final atk = p.rawStats['atk']!;
    p.rawStats['atk'] = p.rawStats['def']!;
    p.rawStats['def'] = atk;
  }
  if (wonderRoom) {
    final def = p.rawStats['def']!;
    p.rawStats['def'] = p.rawStats['spd']!;
    p.rawStats['spd'] = def;
  }
}

int _clampBoost(int v) => v < -6 ? -6 : (v > 6 ? 6 : v);

void checkIntimidate(CalcPokemon source, CalcPokemon target) {
  final blocked = target.hasAbility(['Clear Body', 'White Smoke', 'Hyper Cutter', 'Full Metal Body']) ||
      target.hasAbility(['Inner Focus', 'Own Tempo', 'Oblivious', 'Scrappy']) ||
      target.hasItem(['Clear Amulet']);
  if (source.hasAbility(['Intimidate']) && source.abilityOn && !blocked) {
    if (target.hasAbility(['Contrary', 'Defiant', 'Guard Dog'])) {
      target.boosts['atk'] = _clampBoost(target.boosts['atk']! + 1);
    } else if (target.hasAbility(['Simple'])) {
      target.boosts['atk'] = _clampBoost(target.boosts['atk']! - 2);
    } else {
      target.boosts['atk'] = _clampBoost(target.boosts['atk']! - 1);
    }
    if (target.hasAbility(['Competitive'])) {
      target.boosts['spa'] = _clampBoost(target.boosts['spa']! + 2);
    }
  }
}

void checkDownload(CalcPokemon source, CalcPokemon target, bool wonderRoom) {
  if (source.hasAbility(['Download'])) {
    var def = target.stats['def']!;
    var spd = target.stats['spd']!;
    if (wonderRoom) (def, spd) = (spd, def);
    if (spd <= def) {
      source.boosts['spa'] = _clampBoost(source.boosts['spa']! + 1);
    } else {
      source.boosts['atk'] = _clampBoost(source.boosts['atk']! + 1);
    }
  }
}

void checkIntrepidSword(CalcPokemon p) {
  if (p.hasAbility(['Intrepid Sword']) && p.abilityOn) p.boosts['atk'] = _clampBoost(p.boosts['atk']! + 1);
}

void checkDauntlessShield(CalcPokemon p) {
  if (p.hasAbility(['Dauntless Shield']) && p.abilityOn) p.boosts['def'] = _clampBoost(p.boosts['def']! + 1);
}

void checkWindRider(CalcPokemon p, CalcSide side) {
  if (p.hasAbility(['Wind Rider']) && side.isTailwind) p.boosts['atk'] = _clampBoost(p.boosts['atk']! + 1);
}

void checkEmbody(CalcPokemon p) {
  switch (p.ability) {
    case 'Embody Aspect (Cornerstone)':
      p.boosts['def'] = _clampBoost(p.boosts['def']! + 1);
    case 'Embody Aspect (Hearthflame)':
      p.boosts['atk'] = _clampBoost(p.boosts['atk']! + 1);
    case 'Embody Aspect (Teal)':
      p.boosts['spe'] = _clampBoost(p.boosts['spe']! + 1);
    case 'Embody Aspect (Wellspring)':
      p.boosts['spd'] = _clampBoost(p.boosts['spd']! + 1);
  }
}

void checkInfiltrator(CalcPokemon p, CalcSide side) {
  if (p.hasAbility(['Infiltrator'])) {
    side.isReflect = false;
    side.isLightScreen = false;
    side.isAuroraVeil = false;
  }
}

void checkSeedBoost(CalcPokemon p, CalcField field) {
  if (p.item.isEmpty) return;
  if (field.terrain.isNotEmpty && p.item.contains('Seed')) {
    final seed = p.item.substring(0, p.item.indexOf(' '));
    if (field.hasTerrain([seed])) {
      final stat = seed == 'Grassy' || seed == 'Electric' ? 'def' : 'spd';
      p.boosts[stat] = p.hasAbility(['Contrary']) ? _clampBoost(p.boosts[stat]! - 1) : _clampBoost(p.boosts[stat]! + 1);
      p.item = '';
    }
  }
}

/// Efeitos entre um acerto e outro (golpes de vários acertos e Parental Bond).
(bool, bool) checkMultihitBoost(
    CalcPokemon attacker, CalcPokemon defender, CalcMove move, CalcField field, bool attackerUsedItem, bool defenderUsedItem) {
  if (move.named(['Gyro Ball', 'Electro Ball']) && defender.hasAbility(['Gooey', 'Tangling Hair'])) {
    if (attacker.hasItem(['White Herb']) && !attackerUsedItem) {
      attackerUsedItem = true;
    } else {
      attacker.boosts['spe'] = _clampBoost(attacker.boosts['spe']! - 1);
      attacker.stats['spe'] = getFinalSpeed(attacker, field, field.attackerSide);
    }
  } else if (move.named(['Power-Up Punch'])) {
    attacker.boosts['atk'] = _clampBoost(attacker.boosts['atk']! + 1);
    attacker.stats['atk'] = getModifiedStat(attacker.rawStats['atk']!, attacker.boosts['atk']!);
  }
  final atkSimple = attacker.hasAbility(['Simple']) ? 2 : 1;
  final defSimple = defender.hasAbility(['Simple']) ? 2 : 1;
  // A precedência (&& antes de ||) é a mesma do original.
  if ((!defenderUsedItem && defender.hasItem(['Luminous Moss']) && move.hasType(['Water'])) ||
      (defender.hasItem(['Maranga Berry']) && move.category == 'Special') ||
      (defender.hasItem(['Kee Berry']) && move.category == 'Physical')) {
    final defStat = defender.hasItem(['Kee Berry']) ? 'def' : 'spd';
    if (!attacker.hasAbility(['Unaware'])) {
      if (defender.hasAbility(['Contrary'])) {
        if (defender.hasItem(['White Herb']) && !defenderUsedItem) {
          defenderUsedItem = true;
        } else {
          defender.boosts[defStat] = _clampBoost(defender.boosts[defStat]! - defSimple);
        }
      } else {
        defender.boosts[defStat] = _clampBoost(defender.boosts[defStat]! + defSimple);
      }
      defender.stats[defStat] = getModifiedStat(defender.rawStats[defStat]!, defender.boosts[defStat]!);
      defenderUsedItem = true;
    }
  }
  if (defender.hasAbility(['Seed Sower'])) field.terrain = 'Grassy';
  if (defender.hasAbility(['Sand Spit'])) field.weather = 'Sand';
  if (defender.hasAbility(['Stamina'])) {
    if (!attacker.hasAbility(['Unaware'])) {
      defender.boosts['def'] = _clampBoost(defender.boosts['def']! + 1);
      defender.stats['def'] = getModifiedStat(defender.rawStats['def']!, defender.boosts['def']!);
    }
  } else if (defender.hasAbility(['Water Compaction']) && move.hasType(['Water'])) {
    if (!attacker.hasAbility(['Unaware'])) {
      defender.boosts['def'] = _clampBoost(defender.boosts['def']! + 2);
      defender.stats['def'] = getModifiedStat(defender.rawStats['def']!, defender.boosts['def']!);
    }
  } else if (defender.hasAbility(['Weak Armor'])) {
    if (!attacker.hasAbility(['Unaware'])) {
      if (defender.hasItem(['White Herb']) && !defenderUsedItem && defender.boosts['def'] == 0) {
        defenderUsedItem = true;
      } else {
        defender.boosts['def'] = _clampBoost(defender.boosts['def']! - 1);
        defender.stats['def'] = getModifiedStat(defender.rawStats['def']!, defender.boosts['def']!);
      }
    }
    defender.boosts['spe'] = _clampBoost(defender.boosts['spe']! + 2);
    defender.stats['spe'] = getFinalSpeed(defender, field, field.defenderSide);
  }
  if (move.dropsStats > 0) {
    if (!attacker.hasAbility(['Unaware'])) {
      final stat = move.category == 'Special' ? 'spa' : 'atk';
      var boosts = attacker.boosts[stat]!;
      if (attacker.hasAbility(['Contrary'])) {
        boosts = _clampBoost(boosts + move.dropsStats);
      } else {
        boosts = _clampBoost(boosts - move.dropsStats * atkSimple);
      }
      if (attacker.hasItem(['White Herb']) && attacker.boosts[stat]! < 0 && !attackerUsedItem) {
        boosts += move.dropsStats * atkSimple;
        attackerUsedItem = true;
      }
      attacker.boosts[stat] = boosts;
      // O original usa os estágios do defensor aqui (mantido igual).
      attacker.stats[stat] = getModifiedStat(attacker.rawStats[stat]!, defender.boosts[stat]!);
    }
  }
  if (defender.hasAbility(['Mummy', 'Wandering Spirit', 'Lingering Aroma']) && move.flag('contact')) {
    final old = attacker.ability;
    attacker.ability = defender.ability;
    if (defender.hasAbility(['Wandering Spirit'])) defender.ability = old;
  }
  return (attackerUsedItem, defenderUsedItem);
}

String getQPBoostedStat(CalcPokemon p) {
  if (p.boostedStat.isNotEmpty && p.boostedStat != 'auto') return p.boostedStat;
  var best = 'atk';
  for (final stat in ['def', 'spa', 'spd', 'spe']) {
    if (getModifiedStat(p.rawStats[stat]!, p.boosts[stat]!) > getModifiedStat(p.rawStats[best]!, p.boosts[best]!)) {
      best = stat;
    }
  }
  return best;
}

bool isQPActive(CalcPokemon p, CalcField field) {
  if (p.boostedStat.isEmpty) return false;
  return (p.hasAbility(['Protosynthesis']) && (field.weather.contains('Sun') || p.hasItem(['Booster Energy']))) ||
      (p.hasAbility(['Quark Drive']) && (field.terrain == 'Electric' || p.hasItem(['Booster Energy']))) ||
      p.boostedStat != 'auto';
}

int getFinalDamage(int baseAmount, int i, double effectiveness, bool isBurned, int stabMod, int finalMod, bool protect) {
  num damage = (of32(baseAmount * (85 + i)) / 100).floor();
  if (stabMod != 4096) damage = of32(damage * stabMod) / 4096;
  damage = (of32(pokeRound(damage) * effectiveness)).floor();
  if (isBurned) damage = (damage / 2).floor();
  if (protect) damage = pokeRound(of32(damage * 1024) / 4096);
  final x = of32(damage * finalMod) / 4096;
  return of16(pokeRound(x < 1 ? 1 : x)).toInt();
}

String getShellSideArmCategory(CalcPokemon source, CalcPokemon target, bool wonderRoom) {
  var physical = source.stats['atk']! / target.stats['def']!;
  var special = source.stats['spa']! / target.stats['spd']!;
  if (wonderRoom) {
    physical = source.stats['atk']! / target.stats['spd']!;
    special = source.stats['spa']! / target.stats['def']!;
  }
  return physical > special ? 'Physical' : 'Special';
}

double getWeight(CalcPokemon p) {
  var hg = p.weightkg * 10;
  final factor = p.hasAbility(['Heavy Metal'])
      ? 2
      : p.hasAbility(['Light Metal'])
          ? 0.5
          : 1;
  if (factor != 1) hg = (hg * factor).truncateToDouble() < 1 ? 1 : (hg * factor).truncateToDouble();
  if (p.hasItem(['Float Stone'])) hg = (hg * 0.5).truncateToDouble() < 1 ? 1 : (hg * 0.5).truncateToDouble();
  return hg / 10;
}

int getStabMod(CalcPokemon p, CalcMove move) {
  var stab = 4096;
  if (p.hasOriginalType([move.type])) {
    stab += 2048;
  } else if (p.hasAbility(['Protean', 'Libero']) && p.teraType.isEmpty) {
    stab += 2048;
  }
  final tera = p.teraType;
  if (tera == move.type && tera != 'Stellar') stab += 2048;
  if (p.hasAbility(['Adaptability']) && p.hasType([move.type])) {
    stab += tera.isNotEmpty && p.hasOriginalType([tera]) ? 1024 : 2048;
  }
  return stab;
}

int getStellarStabMod(CalcPokemon p, CalcMove move, int stabMod, [int turns = 0]) {
  final boosted = p.teraType == 'Stellar' && ((move.isStellarFirstUse && turns == 0) || p.named(['Terapagos-Stellar']));
  if (boosted) {
    if (p.hasOriginalType([move.type])) {
      stabMod += 2048;
    } else {
      stabMod = 4915;
    }
  }
  return stabMod;
}

int countBoosts(Map<String, int> boosts) {
  var sum = 0;
  for (final s in ['atk', 'def', 'spa', 'spd', 'spe']) {
    final b = boosts[s] ?? 0;
    if (b > 0) sum += b;
  }
  return sum;
}

int handleFixedDamageMoves(CalcPokemon attacker, CalcMove move) {
  if (move.named(['Seismic Toss', 'Night Shade'])) return attacker.level;
  if (move.named(['Dragon Rage'])) return 40;
  if (move.named(['Sonic Boom'])) return 20;
  return 0;
}

// ---------------------------------------------------------------- conta (mechanics/gen789.js)

const _defenderAbilityIgnorable = [
  'Armor Tail', 'Aroma Veil', 'Aura Break', 'Battle Armor', 'Big Pecks', 'Bulletproof', 'Clear Body', 'Contrary', 'Damp',
  'Dazzling', 'Disguise', 'Dry Skin', 'Earth Eater', 'Eelevate', 'Filter', 'Flash Fire', 'Flower Gift', 'Flower Veil',
  'Fluffy', 'Friend Guard', 'Fur Coat', 'Good as Gold', 'Grass Pelt', 'Guard Dog', 'Heatproof', 'Heavy Metal',
  'Hyper Cutter', 'Ice Face', 'Ice Scales', 'Illuminate', 'Immunity', 'Inner Focus', 'Insomnia', 'Keen Eye', 'Leaf Guard',
  'Levitate', 'Light Metal', 'Lightning Rod', 'Limber', 'Magic Bounce', 'Magma Armor', 'Marvel Scale', "Mind's Eye",
  'Mirror Armor', 'Motor Drive', 'Multiscale', 'Oblivious', 'Overcoat', 'Own Tempo', 'Pastel Veil', 'Punk Rock',
  'Purifying Salt', 'Queenly Majesty', 'Sand Veil', 'Sap Sipper', 'Shell Armor', 'Shield Dust', 'Simple', 'Snow Cloak',
  'Solid Rock', 'Soundproof', 'Sticky Hold', 'Storm Drain', 'Sturdy', 'Suction Cups', 'Sweet Veil', 'Tangled Feet',
  'Telepathy', 'Tera Shell', 'Thermal Exchange', 'Thick Fat', 'Unaware', 'Vital Spirit', 'Volt Absorb', 'Water Absorb',
  'Water Bubble', 'Water Veil', 'Well-Baked Body', 'White Smoke', 'Wind Rider', 'Wonder Guard', 'Wonder Skin', //
];

const _ignoresNeutralizingGas = [
  'As One (Glastrier)', 'As One (Spectrier)', 'Battle Bond', 'Comatose', 'Disguise', 'Gulp Missile', 'Ice Face',
  'Multitype', 'Neutralizing Gas', 'Power Construct', 'RKS System', 'Schooling', 'Shields Down', 'Stance Change',
  'Tera Shift', 'Zen Mode', 'Zero to Hero', //
];

/// Calcula o dano (copia os Pokémon, o golpe e o campo antes, como o original).
CalcResult calculateDamage(CalcPokemon attacker, CalcPokemon defender, CalcMove move, CalcField field) =>
    _calculate(attacker.clone(), defender.clone(), move.clone(), field.clone());

CalcResult _calculate(CalcPokemon attacker, CalcPokemon defender, CalcMove move, CalcField field) {
  final data = attacker.data;
  checkAirLock(attacker, field);
  checkAirLock(defender, field);
  checkTeraformZero(attacker, field);
  checkTeraformZero(defender, field);
  checkForecast(attacker, field.weather);
  checkForecast(defender, field.weather);
  checkItem(attacker, field.isMagicRoom);
  checkItem(defender, field.isMagicRoom);
  checkRawStatChanges(attacker, field.attackerSide.isPowerTrick, field.isWonderRoom);
  checkRawStatChanges(defender, field.defenderSide.isPowerTrick, field.isWonderRoom);
  checkSeedBoost(attacker, field);
  checkSeedBoost(defender, field);
  checkDauntlessShield(attacker);
  checkDauntlessShield(defender);
  checkEmbody(attacker);
  checkEmbody(defender);
  computeFinalStats(attacker, defender, field, ['def', 'spd', 'spe']);
  checkIntimidate(attacker, defender);
  checkIntimidate(defender, attacker);
  checkDownload(attacker, defender, field.isWonderRoom);
  checkDownload(defender, attacker, field.isWonderRoom);
  checkIntrepidSword(attacker);
  checkIntrepidSword(defender);
  checkWindRider(attacker, field.attackerSide);
  checkWindRider(defender, field.defenderSide);
  if (move.named(['Meteor Beam', 'Electro Shot'])) {
    final up = attacker.hasAbility(['Simple'])
        ? 2
        : attacker.hasAbility(['Contrary'])
            ? -1
            : 1;
    attacker.boosts['spa'] = _clampBoost(attacker.boosts['spa']! + up);
  }
  computeFinalStats(attacker, defender, field, ['atk', 'spa']);
  checkInfiltrator(attacker, field.defenderSide);
  checkInfiltrator(defender, field.attackerSide);

  if (move.named(['Photon Geyser', 'Light That Burns the Sky']) ||
      (move.named(['Tera Blast']) && attacker.teraType.isNotEmpty) ||
      (move.named(['Tera Starstorm']) && attacker.teraType.isNotEmpty && attacker.named(['Terapagos-Stellar']))) {
    move.category = attacker.stats['atk']! > attacker.stats['spa']! ? 'Physical' : 'Special';
  }

  final result = CalcResult(attacker, defender, move, field);
  if (move.category == 'Status' && !move.named(['Nature Power'])) return result;

  if (move.flag('punch') && attacker.hasItem(['Punching Glove'])) move.flags['contact'] = false;
  if (move.named(['Shell Side Arm']) && getShellSideArmCategory(attacker, defender, field.isWonderRoom) == 'Physical') {
    move.category = 'Physical';
    move.flags['contact'] = true;
  }

  final breaksProtect =
      move.breaksProtect || move.isZ || (attacker.hasAbility(['Unseen Fist', 'Piercing Drill']) && move.flag('contact'));
  if (field.defenderSide.isProtected && !breaksProtect) return result;

  if (move.name == 'Pain Split') {
    final average = ((attacker.curHP() + defender.curHP()) / 2).floor();
    final d = defender.curHP() - average;
    result.damage = [
      [d < 0 ? 0 : d]
    ];
    return result;
  }

  final defenderAbilityIgnored = defender.hasAbility(_defenderAbilityIgnorable);
  final attackerIgnoresAbility = attacker.hasAbility(['Mold Breaker', 'Teravolt', 'Turboblaze']);
  final moveIgnoresAbility = move.named([
    'G-Max Drum Solo', 'G-Max Fire Ball', 'G-Max Hydrosnipe', 'Light That Burns the Sky', //
    'Menacing Moonraze Maelstrom', 'Moongeist Beam', 'Photon Geyser', 'Searing Sunraze Smash', 'Sunsteel Strike',
  ]);
  if (defenderAbilityIgnored && (attackerIgnoresAbility || moveIgnoresAbility)) {
    if (!defender.hasItem(['Ability Shield'])) defender.ability = '';
  }
  if (attacker.hasAbility(['Neutralizing Gas']) && !_ignoresNeutralizingGas.contains(defender.ability)) {
    if (!defender.hasItem(['Ability Shield'])) defender.ability = '';
  }
  if (defender.hasAbility(['Neutralizing Gas']) && !_ignoresNeutralizingGas.contains(attacker.ability)) {
    if (!attacker.hasItem(['Ability Shield'])) attacker.ability = '';
  }

  final isCritical = !defender.hasAbility(['Battle Armor', 'Shell Armor']) &&
      (move.isCrit || (attacker.hasAbility(['Merciless']) && defender.hasStatus(['psn', 'tox']))) &&
      move.timesUsed == 1;

  var type = move.type;
  if (move.originalName == 'Weather Ball') {
    final umbrella = attacker.hasItem(['Utility Umbrella']);
    final megaSol = attacker.hasAbility(['Mega Sol']);
    type = (field.hasWeather(['Sun', 'Harsh Sunshine']) || megaSol) && !umbrella
        ? 'Fire'
        : field.hasWeather(['Rain', 'Heavy Rain']) && !umbrella
            ? 'Water'
            : field.hasWeather(['Sand'])
                ? 'Rock'
                : field.hasWeather(['Hail', 'Snow'])
                    ? 'Ice'
                    : 'Normal';
  } else if (move.named(['Judgment']) && attacker.item.contains('Plate')) {
    type = data.items[attacker.item]?.boostType ?? type;
  } else if (move.originalName == 'Techno Blast' && attacker.item.contains('Drive')) {
    type = data.items[attacker.item]?.technoBlast ?? type;
  } else if (move.originalName == 'Multi-Attack' && attacker.item.contains('Memory')) {
    type = data.items[attacker.item]?.multiAttack ?? type;
  } else if (move.named(['Natural Gift']) && attacker.item.endsWith('Berry')) {
    type = (data.items[attacker.item]?.naturalGift?[1] as String?) ?? type;
  } else if (move.named(['Nature Power']) || (move.originalName == 'Terrain Pulse' && isGrounded(attacker, field))) {
    type = field.hasTerrain(['Electric'])
        ? 'Electric'
        : field.hasTerrain(['Grassy'])
            ? 'Grass'
            : field.hasTerrain(['Misty'])
                ? 'Fairy'
                : field.hasTerrain(['Psychic'])
                    ? 'Psychic'
                    : 'Normal';
  } else if (move.originalName == 'Revelation Dance') {
    if (attacker.teraType.isNotEmpty) {
      type = attacker.teraType;
    } else if (attacker.types[0] == '???' && attacker.types.length > 1) {
      type = attacker.types[1];
    } else {
      type = attacker.types[0];
    }
  } else if (move.named(['Aura Wheel']) && attacker.named(['Morpeko-Hangry'])) {
    type = 'Dark';
  } else if (move.named(['Raging Bull'])) {
    if (attacker.named(['Tauros'])) {
      type = 'Normal';
    } else if (attacker.named(['Tauros-Paldea-Aqua'])) {
      type = 'Water';
    } else if (attacker.named(['Tauros-Paldea-Blaze'])) {
      type = 'Fire';
    } else if (attacker.named(['Tauros-Paldea-Combat'])) {
      type = 'Fighting';
    }
    field.defenderSide.isReflect = false;
    field.defenderSide.isLightScreen = false;
    field.defenderSide.isAuroraVeil = false;
  } else if (move.named(['Ivy Cudgel'])) {
    if (attacker.named(['Ogerpon']) || attacker.name.contains('Ogerpon-Teal')) {
      type = 'Grass';
    } else if (attacker.name.contains('Ogerpon-Cornerstone')) {
      type = 'Rock';
    } else if (attacker.name.contains('Ogerpon-Hearthflame')) {
      type = 'Fire';
    } else if (attacker.name.contains('Ogerpon-Wellspring')) {
      type = 'Water';
    }
  } else if (move.named(['Tera Starstorm']) && attacker.name == 'Terapagos-Stellar') {
    move.target = 'allAdjacentFoes';
    type = 'Stellar';
  } else if (move.named(['Brick Break', 'Psychic Fangs'])) {
    field.defenderSide.isReflect = false;
    field.defenderSide.isLightScreen = false;
    field.defenderSide.isAuroraVeil = false;
  }

  if (attacker.hasAbility(['Electromorphosis']) && attacker.abilityOn) field.attackerSide.isCharge = true;

  var hasAteAbilityTypeChange = false;
  final noTypeChange = move.named([
        'Revelation Dance', 'Judgment', 'Nature Power', 'Techno Blast', 'Multi-Attack', 'Natural Gift', //
        'Weather Ball', 'Terrain Pulse', 'Struggle',
      ]) ||
      (move.named(['Tera Blast']) && attacker.teraType.isNotEmpty);
  if (!move.isZ && !noTypeChange) {
    final normal = type == 'Normal';
    var ate = false;
    if (attacker.hasAbility(['Aerilate']) && normal) {
      type = 'Flying';
      ate = true;
    } else if (attacker.hasAbility(['Galvanize']) && normal) {
      type = 'Electric';
      ate = true;
    } else if (attacker.hasAbility(['Liquid Voice']) && move.flag('sound')) {
      type = 'Water';
    } else if (attacker.hasAbility(['Pixilate']) && normal) {
      type = 'Fairy';
      ate = true;
    } else if (attacker.hasAbility(['Refrigerate']) && normal) {
      type = 'Ice';
      ate = true;
    } else if (attacker.hasAbility(['Normalize'])) {
      type = 'Normal';
      ate = true;
    } else if (attacker.hasAbility(['Dragonize']) && normal) {
      type = 'Dragon';
      ate = true;
    }
    hasAteAbilityTypeChange = ate;
  }
  if (move.named(['Tera Blast']) && attacker.teraType.isNotEmpty) type = attacker.teraType;
  move.type = type;

  final isGhostRevealed =
      attacker.hasAbility(['Scrappy']) || attacker.hasAbility(["Mind's Eye"]) || field.defenderSide.isForesight;
  final isRingTarget = defender.hasItem(['Ring Target']) && !defender.hasAbility(['Klutz']);
  final t1 = getMoveEffectiveness(data, move, defender.types[0], isGhostRevealed, field.isGravity, isRingTarget);
  final t2 = defender.types.length > 1
      ? getMoveEffectiveness(data, move, defender.types[1], isGhostRevealed, field.isGravity, isRingTarget)
      : 1.0;
  var typeEffectiveness = t1 * t2;
  if (defender.teraType.isNotEmpty && defender.teraType != 'Stellar') {
    typeEffectiveness =
        getMoveEffectiveness(data, move, defender.teraType, isGhostRevealed, field.isGravity, isRingTarget);
  }
  if (typeEffectiveness == 0 && move.hasType(['Ground']) && defender.hasItem(['Iron Ball']) && !defender.hasAbility(['Klutz'])) {
    typeEffectiveness = 1;
  }
  if (typeEffectiveness == 0 && move.named(['Thousand Arrows'])) typeEffectiveness = 1;
  if (typeEffectiveness == 0) return result;

  if ((move.named(['Sky Drop']) && (defender.hasType(['Flying']) || defender.weightkg >= 200 || field.isGravity)) ||
      (move.named(['Synchronoise']) &&
          !defender.hasType([attacker.types[0]]) &&
          (attacker.types.length < 2 || !defender.hasType([attacker.types[1]]))) ||
      (move.named(['Dream Eater']) && !(defender.hasStatus(['slp']) || defender.hasAbility(['Comatose']))) ||
      (move.named(['Steel Roller']) && field.terrain.isEmpty) ||
      (move.named(['Poltergeist']) &&
          (defender.item.isEmpty || (isQPActive(defender, field) && defender.hasItem(['Booster Energy']))))) {
    return result;
  }
  if ((field.hasWeather(['Harsh Sunshine']) && move.hasType(['Water'])) ||
      (field.hasWeather(['Heavy Rain']) && move.hasType(['Fire']))) {
    return result;
  }
  if (field.hasWeather(['Strong Winds']) &&
      defender.hasType(['Flying']) &&
      data.effectiveness(move.type, 'Flying') > 1) {
    typeEffectiveness /= 2;
  }
  if (move.type == 'Stellar') typeEffectiveness = defender.teraType.isEmpty ? 1 : 2;

  final turn2typeEffectiveness = typeEffectiveness;
  if (defender.hasAbility(['Tera Shell']) &&
      defender.curHP() == defender.maxHP() &&
      ((!field.defenderSide.isSR && (field.defenderSide.spikes == 0 || defender.hasType(['Flying']))) ||
          defender.hasItem(['Heavy-Duty Boots']))) {
    typeEffectiveness = 0.5;
  }
  if ((defender.hasAbility(['Wonder Guard']) && typeEffectiveness <= 1) ||
      (move.hasType(['Grass']) && defender.hasAbility(['Sap Sipper'])) ||
      (move.hasType(['Fire']) && defender.hasAbility(['Flash Fire', 'Well-Baked Body'])) ||
      (move.hasType(['Water']) && defender.hasAbility(['Dry Skin', 'Storm Drain', 'Water Absorb'])) ||
      (move.hasType(['Electric']) && defender.hasAbility(['Lightning Rod', 'Motor Drive', 'Volt Absorb'])) ||
      (move.hasType(['Ground']) &&
          !field.isGravity &&
          !move.named(['Thousand Arrows']) &&
          !defender.hasItem(['Iron Ball']) &&
          defender.hasAbility(['Levitate', 'Eelevate'])) ||
      (move.flag('bullet') && defender.hasAbility(['Bulletproof'])) ||
      (move.flag('sound') && !move.named(['Clangorous Soul']) && defender.hasAbility(['Soundproof'])) ||
      (move.priority > 0 && defender.hasAbility(['Queenly Majesty', 'Dazzling', 'Armor Tail'])) ||
      (move.hasType(['Ground']) && defender.hasAbility(['Earth Eater'])) ||
      (move.flag('wind') && defender.hasAbility(['Wind Rider']))) {
    return result;
  }
  if (move.hasType(['Ground']) && !move.named(['Thousand Arrows']) && !field.isGravity && defender.hasItem(['Air Balloon'])) {
    return result;
  }
  if (move.priority > 0 && field.hasTerrain(['Psychic']) && isGrounded(defender, field)) return result;

  final fixed = handleFixedDamageMoves(attacker, move);
  if (fixed > 0) {
    result.damage = attacker.hasAbility(['Parental Bond'])
        ? [
            [fixed],
            [fixed]
          ]
        : [
            [fixed]
          ];
    return result;
  }
  if (move.named(['Final Gambit'])) {
    result.damage = [
      [attacker.curHP()]
    ];
    return result;
  }
  if (move.named(['Guardian of Alola'])) {
    result.damage = [
      [(defender.curHP() * 3 / 4).floor()]
    ];
    return result;
  }
  if (move.named(["Nature's Madness"])) {
    result.damage = [
      [field.defenderSide.isProtected ? 0 : (defender.curHP() / 2).floor()]
    ];
    return result;
  }
  if (move.named(['Spectral Thief'])) {
    for (final stat in ['atk', 'def', 'spa', 'spd', 'spe']) {
      final b = defender.boosts[stat]!;
      if (b > 0) {
        attacker.boosts[stat] = _clampBoost(attacker.boosts[stat]! + (attacker.hasAbility(['Contrary']) ? -b : b));
        attacker.stats[stat] = getModifiedStat(attacker.rawStats[stat]!, attacker.boosts[stat]!);
        defender.boosts[stat] = 0;
        defender.stats[stat] = defender.rawStats[stat]!;
      }
    }
  }

  var basePower = calculateBasePower(attacker, defender, move, field, hasAteAbilityTypeChange);
  if (basePower == 0) return result;

  final attack = calculateAttack(attacker, defender, move, field, isCritical);
  final defense = calculateDefense(attacker, defender, move, field, isCritical);
  final baseDamage = calculateBaseDamage(attacker, defender, basePower, attack, defense, move, field, isCritical);
  if ((attacker.hasAbility(['Triage']) && move.drain) ||
      (attacker.hasAbility(['Gale Wings']) && move.hasType(['Flying']) && attacker.curHP() == attacker.maxHP())) {
    move.priority = 1;
  }

  var preStellarStabMod = getStabMod(attacker, move);
  var stabMod = getStellarStabMod(attacker, move, preStellarStabMod);
  final applyBurn = attacker.hasStatus(['brn']) &&
      move.category == 'Physical' &&
      !attacker.hasAbility(['Guts']) &&
      !move.named(['Facade']);
  final finalMods = calculateFinalMods(attacker, defender, move, field, isCritical, typeEffectiveness);

  var protect = false;
  if (field.defenderSide.isProtected &&
      (attacker.hasAbility(['Unseen Fist', 'Piercing Drill']) || (move.isZ && attacker.item.contains(' Z')))) {
    protect = true;
  }
  final finalMod = chainMods(finalMods, 41, 131072);
  final isSpread = field.gameType != 'Singles' && ['allAdjacent', 'allAdjacentFoes'].contains(move.target);

  List<int>? childDamage;
  if (attacker.hasAbility(['Parental Bond']) && move.hits == 1 && !isSpread) {
    final child = attacker.clone();
    child.ability = 'Parental Bond (Child)';
    checkMultihitBoost(child, defender, move, field, false, false);
    final childResult = _calculate(child, defender, move, field);
    final cd = childResult.damage;
    // Só vale se o filho causa dano (no original: 0 conta como "sem dano").
    if (!(cd.length == 1 && cd[0].length == 1 && cd[0][0] == 0)) childDamage = cd[0];
  }

  final damage = [
    for (var i = 0; i < 16; i++) getFinalDamage(baseDamage, i, typeEffectiveness, applyBurn, stabMod, finalMod, protect)
  ];
  result.damage = childDamage != null ? [damage, childDamage] : [damage];

  if (move.timesUsed > 1 || move.hits > 1) {
    final numAttacks = move.timesUsed > 1 ? move.timesUsed : move.hits;
    var usedItems = (false, false);
    final matrix = <List<int>>[damage];
    for (var times = 1; times < numAttacks; times++) {
      usedItems = checkMultihitBoost(attacker, defender, move, field, usedItems.$1, usedItems.$2);
      final newAttack = calculateAttack(attacker, defender, move, field, isCritical);
      final newDefense = calculateDefense(attacker, defender, move, field, isCritical);
      hasAteAbilityTypeChange = hasAteAbilityTypeChange &&
          attacker.hasAbility(['Aerilate', 'Galvanize', 'Pixilate', 'Refrigerate', 'Normalize', 'Dragonize']);
      if (move.timesUsed > 1) {
        preStellarStabMod = getStabMod(attacker, move);
        typeEffectiveness = turn2typeEffectiveness;
        stabMod = getStellarStabMod(attacker, move, preStellarStabMod, times);
      }
      final newBasePower = calculateBasePower(attacker, defender, move, field, hasAteAbilityTypeChange, times + 1);
      final newBaseDamage =
          calculateBaseDamage(attacker, defender, newBasePower, newAttack, newDefense, move, field, isCritical);
      final newFinalMods = calculateFinalMods(attacker, defender, move, field, isCritical, typeEffectiveness, times);
      final newFinalMod = chainMods(newFinalMods, 41, 131072);
      matrix.add([
        for (var i = 0; i < 16; i++)
          getFinalDamage(newBaseDamage, i, typeEffectiveness, applyBurn, stabMod, newFinalMod, protect)
      ]);
    }
    result.damage = matrix;
  }
  return result;
}

int calculateBasePower(CalcPokemon attacker, CalcPokemon defender, CalcMove move, CalcField field,
    bool hasAteAbilityTypeChange,
    [int hit = 1]) {
  final data = attacker.data;
  final turnOrder = attacker.stats['spe']! > defender.stats['spe']! ? 'first' : 'last';
  int basePower;
  switch (move.name) {
    case 'Payback':
      basePower = move.bp * (turnOrder == 'last' ? 2 : 1);
    case 'Bolt Beak' || 'Fishious Rend':
      basePower = move.bp * (turnOrder != 'last' ? 2 : 1);
    case 'Pursuit':
      basePower = move.bp * (field.defenderSide.isSwitching == 'out' ? 2 : 1);
    case 'Electro Ball':
      final r = (attacker.stats['spe']! / defender.stats['spe']!).floor();
      basePower = r >= 4
          ? 150
          : r >= 3
              ? 120
              : r >= 2
                  ? 80
                  : r >= 1
                      ? 60
                      : 40;
      if (defender.stats['spe'] == 0) basePower = 40;
    case 'Gyro Ball':
      if (attacker.stats['spe'] == 0) {
        basePower = 1;
      } else {
        final v = (25 * defender.stats['spe']! / attacker.stats['spe']!).floor() + 1;
        basePower = v > 150 ? 150 : v;
      }
    case 'Punishment':
      final v = 60 + 20 * countBoosts(defender.boosts);
      basePower = v > 200 ? 200 : v;
    case 'Low Kick' || 'Grass Knot':
      final w = getWeight(defender);
      basePower = w >= 200
          ? 120
          : w >= 100
              ? 100
              : w >= 50
                  ? 80
                  : w >= 25
                      ? 60
                      : w >= 10
                          ? 40
                          : 20;
    case 'Hex' || 'Infernal Parade':
      basePower = move.bp * (defender.status.isNotEmpty || defender.hasAbility(['Comatose']) ? 2 : 1);
    case 'Barb Barrage':
      basePower = move.bp * (defender.hasStatus(['psn', 'tox']) ? 2 : 1);
    case 'Heavy Slam' || 'Heat Crash':
      final wr = getWeight(attacker) / getWeight(defender);
      basePower = wr >= 5
          ? 120
          : wr >= 4
              ? 100
              : wr >= 3
                  ? 80
                  : wr >= 2
                      ? 60
                      : 40;
    case 'Stored Power' || 'Power Trip':
      basePower = 20 + 20 * countBoosts(attacker.boosts);
    case 'Acrobatics':
      basePower = move.bp *
          (attacker.hasItem(['Flying Gem']) ||
                  (attacker.item.isEmpty || (isQPActive(attacker, field) && attacker.hasItem(['Booster Energy'])))
              ? 2
              : 1);
    case 'Assurance':
      basePower = move.bp * (defender.hasAbility(['Parental Bond (Child)']) ? 2 : 1);
    case 'Wake-Up Slap':
      basePower = move.bp * (defender.hasStatus(['slp']) || defender.hasAbility(['Comatose']) ? 2 : 1);
    case 'Smelling Salts':
      basePower = move.bp * (defender.hasStatus(['par']) ? 2 : 1);
    case 'Weather Ball':
      final strongWinds = field.hasWeather(['Strong Winds']);
      final megaSol = attacker.hasAbility(['Mega Sol']);
      basePower = move.bp * ((field.weather.isNotEmpty && !strongWinds) || megaSol ? 2 : 1);
      if (field.hasWeather(['Sun', 'Harsh Sunshine', 'Rain', 'Heavy Rain']) &&
          attacker.hasItem(['Utility Umbrella']) &&
          !megaSol) {
        basePower = move.bp;
      }
    case 'Terrain Pulse':
      basePower = move.bp * (isGrounded(attacker, field) && field.terrain.isNotEmpty ? 2 : 1);
    case 'Rising Voltage':
      basePower = move.bp * (isGrounded(defender, field) && field.hasTerrain(['Electric']) ? 2 : 1);
    case 'Psyblade':
      // O original multiplica por 1,5 aqui (pode dar número quebrado).
      final v = move.bp * (field.hasTerrain(['Electric']) ? 1.5 : 1);
      return _finishBasePower(attacker, defender, move, field, hasAteAbilityTypeChange, turnOrder, hit, v);
    case 'Fling':
      basePower = data.items[attacker.item]?.fling ?? 0;
    case 'Dragon Energy' || 'Eruption' || 'Water Spout':
      final v = (150 * attacker.curHP() / attacker.maxHP()).floor();
      basePower = v < 1 ? 1 : v;
    case 'Flail' || 'Reversal':
      final p = (48 * attacker.curHP() / attacker.maxHP()).floor();
      basePower = p <= 1
          ? 200
          : p <= 4
              ? 150
              : p <= 9
                  ? 100
                  : p <= 16
                      ? 80
                      : p <= 32
                          ? 40
                          : 20;
    case 'Natural Gift':
      if (attacker.item.endsWith('Berry')) {
        basePower = (data.items[attacker.item]?.naturalGift?[0] as num?)?.toInt() ?? move.bp;
      } else {
        basePower = move.bp;
      }
    case 'Nature Power':
      move.category = 'Special';
      move.secondaries = true;
      if (attacker.hasAbility(['Prankster']) && defender.types.contains('Dark')) {
        basePower = 0;
        break;
      }
      switch (field.terrain) {
        case 'Electric':
          basePower = 90;
        case 'Grassy':
          basePower = 90;
        case 'Misty':
          basePower = 95;
        case 'Psychic':
          basePower = attacker.hasAbility(['Prankster']) && isGrounded(defender, field) ? 0 : 90;
        default:
          basePower = 80;
      }
    case 'Water Shuriken':
      basePower = attacker.named(['Greninja-Ash']) && attacker.hasAbility(['Battle Bond']) ? 20 : 15;
    case 'Triple Axel':
      basePower = hit * 20;
    case 'Triple Kick':
      basePower = hit * 10;
    case 'Crush Grip' || 'Wring Out':
      final b = 100 * (defender.curHP() * 4096 / defender.maxHP()).floor();
      final v = ((120 * b + 2048 - 1) / 4096).floor() ~/ 100;
      basePower = v == 0 ? 1 : v;
    case 'Hard Press':
      final b = 100 * (defender.curHP() * 4096 / defender.maxHP()).floor();
      final v = ((100 * b + 2048 - 1) / 4096).floor() ~/ 100;
      basePower = v == 0 ? 1 : v;
    case 'Tera Blast':
      basePower = attacker.teraType == 'Stellar' ? 100 : 80;
    default:
      basePower = move.bp;
  }
  return _finishBasePower(attacker, defender, move, field, hasAteAbilityTypeChange, turnOrder, hit, basePower);
}

int _finishBasePower(CalcPokemon attacker, CalcPokemon defender, CalcMove move, CalcField field,
    bool hasAteAbilityTypeChange, String turnOrder, int hit, num basePower) {
  if (basePower == 0) return 0;
  final bpMods = calculateBPMods(attacker, defender, move, field, basePower, hasAteAbilityTypeChange, turnOrder, hit);
  final v = pokeRound(basePower * chainMods(bpMods, 41, 2097152) / 4096);
  var bp = of16(v < 1 ? 1 : v).toInt();
  if (attacker.teraType.isNotEmpty &&
      ((move.type == attacker.teraType && attacker.hasType([attacker.teraType])) ||
          (attacker.teraType == 'Stellar' && move.isStellarFirstUse)) &&
      move.hits == 1 &&
      !move.multiaccuracy &&
      move.priority <= 0 &&
      move.bp > 0 &&
      !move.named(['Dragon Energy', 'Eruption', 'Water Spout']) &&
      bp < 60) {
    bp = 60;
  }
  return bp;
}

List<int> calculateBPMods(CalcPokemon attacker, CalcPokemon defender, CalcMove move, CalcField field, num basePower,
    bool hasAteAbilityTypeChange, String turnOrder, int hit) {
  final data = attacker.data;
  final mods = <int>[];
  final defenderItem = defender.item.isNotEmpty ? defender.item : defender.disabledItem;
  var resisted = (defenderItem.isEmpty || (isQPActive(defender, field) && defenderItem == 'Booster Energy')) ||
      (defender.named(['Dialga-Origin']) && defenderItem == 'Adamant Crystal') ||
      (defender.named(['Palkia-Origin']) && defenderItem == 'Lustrous Globe') ||
      (defender.name.contains('Giratina-Origin') && defenderItem.contains('Griseous')) ||
      (defender.name.contains('Arceus') && defenderItem.contains('Plate')) ||
      (defender.name.contains('Genesect') && defenderItem.contains('Drive')) ||
      (defender.named(['Groudon', 'Groudon-Primal']) && defenderItem == 'Red Orb') ||
      (defender.named(['Kyogre', 'Kyogre-Primal']) && defenderItem == 'Blue Orb') ||
      (defender.name.contains('Silvally') && defenderItem.contains('Memory')) ||
      defenderItem.contains(' Z') ||
      (defender.name.contains('Zacian') && defenderItem == 'Rusted Sword') ||
      (defender.name.contains('Zamazenta') && defenderItem == 'Rusted Shield') ||
      (defender.name.contains('Ogerpon-Cornerstone') && defenderItem == 'Cornerstone Mask') ||
      (defender.name.contains('Ogerpon-Hearthflame') && defenderItem == 'Hearthflame Mask') ||
      (defender.name.contains('Ogerpon-Wellspring') && defenderItem == 'Wellspring Mask') ||
      (defender.named(['Venomicon-Epilogue']) && defenderItem == 'Vile Vial');
  if (!resisted && defenderItem.isNotEmpty) {
    final item = data.items[defenderItem];
    resisted = item != null && item.megaStone.contains(defender.name);
  }
  if (!resisted && hit > 1 && !defender.hasAbility(['Sticky Hold'])) resisted = true;

  if ((move.named(['Facade']) && attacker.hasStatus(['brn', 'par', 'psn', 'tox'])) ||
      (move.named(['Brine']) && defender.curHP() <= defender.maxHP() / 2) ||
      (move.named(['Venoshock']) && defender.hasStatus(['psn', 'tox'])) ||
      (move.named(['Lash Out']) && countBoosts(attacker.boosts) < 0)) {
    mods.add(8192);
  } else if (move.named(['Expanding Force']) && isGrounded(attacker, field) && field.hasTerrain(['Psychic'])) {
    move.target = 'allAdjacentFoes';
    mods.add(6144);
  } else if ((move.named(['Knock Off']) && !resisted) ||
      (move.named(['Misty Explosion']) && isGrounded(attacker, field) && field.hasTerrain(['Misty'])) ||
      (move.named(['Grav Apple']) && field.isGravity)) {
    mods.add(6144);
  } else if (move.named(['Solar Beam', 'Solar Blade']) && field.hasWeather(['Rain', 'Heavy Rain', 'Sand', 'Hail', 'Snow'])) {
    mods.add(2048);
  } else if (move.named(['Collision Course', 'Electro Drift'])) {
    final ghost = attacker.hasAbility(['Scrappy']) || attacker.hasAbility(["Mind's Eye"]) || field.defenderSide.isForesight;
    final ring = defender.hasItem(['Ring Target']) && !defender.hasAbility(['Klutz']);
    final types = defender.teraType.isNotEmpty && defender.teraType != 'Stellar' ? [defender.teraType] : defender.types;
    final e1 = getMoveEffectiveness(data, move, types[0], ghost, field.isGravity, ring);
    final e2 = types.length > 1 ? getMoveEffectiveness(data, move, types[1], ghost, field.isGravity, ring) : 1.0;
    if (e1 * e2 >= 2) mods.add(5461);
  }
  if (field.attackerSide.isHelpingHand) mods.add(6144);
  if (isGrounded(attacker, field)) {
    if ((field.hasTerrain(['Electric']) && move.hasType(['Electric'])) ||
        (field.hasTerrain(['Grassy']) && move.hasType(['Grass'])) ||
        (field.hasTerrain(['Psychic']) && move.hasType(['Psychic']))) {
      mods.add(5325);
    }
  }
  if (isGrounded(defender, field)) {
    if ((field.hasTerrain(['Misty']) && move.hasType(['Dragon'])) ||
        (field.hasTerrain(['Grassy']) && move.named(['Bulldoze', 'Earthquake']))) {
      mods.add(2048);
    }
  }
  if ((attacker.hasAbility(['Technician']) && basePower <= 60) ||
      (attacker.hasAbility(['Flare Boost']) && attacker.hasStatus(['brn']) && move.category == 'Special') ||
      (attacker.hasAbility(['Toxic Boost']) && attacker.hasStatus(['psn', 'tox']) && move.category == 'Physical') ||
      (attacker.hasAbility(['Mega Launcher']) && move.flag('pulse')) ||
      (attacker.hasAbility(['Strong Jaw']) && move.flag('bite')) ||
      (attacker.hasAbility(['Steely Spirit']) && move.hasType(['Steel'])) ||
      (attacker.hasAbility(['Sharpness']) && move.flag('slicing'))) {
    mods.add(6144);
  }
  if (field.attackerSide.isCharge && move.hasType(['Electric'])) mods.add(8192);

  final aura = '${move.type} Aura';
  final attackerAura = attacker.hasAbility([aura]);
  final defenderAura = defender.hasAbility([aura]);
  final userAuraBreak = attacker.hasAbility(['Aura Break']) || defender.hasAbility(['Aura Break']);
  final fieldFairy = field.isFairyAura && move.type == 'Fairy';
  final fieldDark = field.isDarkAura && move.type == 'Dark';
  if (attackerAura || defenderAura || fieldFairy || fieldDark) {
    mods.add(field.isAuraBreak || userAuraBreak ? 3072 : 5448);
  }
  if ((attacker.hasAbility(['Sheer Force']) &&
          (move.secondaries || move.named(['Electro Shot', 'Order Up'])) &&
          !move.isMax) ||
      (attacker.hasAbility(['Sand Force']) && field.hasWeather(['Sand']) && move.hasType(['Rock', 'Ground', 'Steel'])) ||
      (attacker.hasAbility(['Analytic']) &&
          (turnOrder != 'first' || field.defenderSide.isSwitching == 'out' || attacker.abilityOn)) ||
      (attacker.hasAbility(['Tough Claws']) && move.flag('contact')) ||
      (attacker.hasAbility(['Punk Rock']) && move.flag('sound'))) {
    mods.add(5325);
  }
  if (field.attackerSide.isBattery && move.category == 'Special') mods.add(5325);
  if (field.attackerSide.isPowerSpot) mods.add(5325);
  if (attacker.hasAbility(['Rivalry']) && attacker.gender != 'N' && defender.gender != 'N') {
    mods.add(attacker.gender == defender.gender ? 5120 : 3072);
  }
  if (!move.isMax && hasAteAbilityTypeChange) mods.add(4915);
  if ((attacker.hasAbility(['Reckless']) && (move.recoil || move.hasCrashDamage)) ||
      (attacker.hasAbility(['Iron Fist']) && move.flag('punch'))) {
    mods.add(4915);
  }
  if (defender.hasAbility(['Dry Skin']) && move.hasType(['Fire'])) mods.add(5120);
  if (attacker.hasAbility(['Supreme Overlord']) && attacker.alliesFainted > 0) {
    const powMod = [4096, 4506, 4915, 5325, 5734, 6144];
    mods.add(powMod[attacker.alliesFainted > 5 ? 5 : attacker.alliesFainted]);
  }
  final boostType = attacker.item.isNotEmpty ? data.items[attacker.item]?.boostType : null;
  if (attacker.hasItem(['${move.type} Gem'])) {
    mods.add(5325);
  } else if ((((attacker.hasItem(['Adamant Crystal']) && attacker.named(['Dialga-Origin'])) ||
              (attacker.hasItem(['Adamant Orb']) && attacker.named(['Dialga']))) &&
          move.hasType(['Steel', 'Dragon'])) ||
      (((attacker.hasItem(['Lustrous Orb']) && attacker.named(['Palkia'])) ||
              (attacker.hasItem(['Lustrous Globe']) && attacker.named(['Palkia-Origin']))) &&
          move.hasType(['Water', 'Dragon'])) ||
      (((attacker.hasItem(['Griseous Orb']) || attacker.hasItem(['Griseous Core'])) &&
              (attacker.named(['Giratina-Origin']) || attacker.named(['Giratina']))) &&
          move.hasType(['Ghost', 'Dragon'])) ||
      (attacker.hasItem(['Vile Vial']) && attacker.named(['Venomicon-Epilogue']) && move.hasType(['Poison', 'Flying'])) ||
      (attacker.hasItem(['Soul Dew']) &&
          attacker.named(['Latios', 'Latias', 'Latios-Mega', 'Latias-Mega']) &&
          move.hasType(['Psychic', 'Dragon'])) ||
      (attacker.item.isNotEmpty && move.hasType([boostType])) ||
      (attacker.name.contains('Ogerpon-Cornerstone') && attacker.hasItem(['Cornerstone Mask'])) ||
      (attacker.name.contains('Ogerpon-Hearthflame') && attacker.hasItem(['Hearthflame Mask'])) ||
      (attacker.name.contains('Ogerpon-Wellspring') && attacker.hasItem(['Wellspring Mask']))) {
    mods.add(4915);
  } else if ((attacker.hasItem(['Muscle Band']) && move.category == 'Physical') ||
      (attacker.hasItem(['Wise Glasses']) && move.category == 'Special')) {
    mods.add(4505);
  } else if (attacker.hasItem(['Punching Glove']) && move.flag('punch')) {
    mods.add(4506);
  }
  return mods;
}

int calculateAttack(CalcPokemon attacker, CalcPokemon defender, CalcMove move, CalcField field, bool isCritical) {
  final source = move.named(['Foul Play']) ? defender : attacker;
  final stat = move.named(['Body Press'])
      ? (field.isWonderRoom ? 'spd' : 'def')
      : (move.category == 'Special' ? 'spa' : 'atk');
  final boosts = source.boosts[stat]!;
  int attack;
  if (boosts == 0 || (isCritical && boosts < 0)) {
    attack = source.rawStats[stat]!;
  } else if (defender.hasAbility(['Unaware'])) {
    attack = source.rawStats[stat]!;
  } else {
    attack = getModifiedStat(source.rawStats[stat]!, boosts);
  }
  if (attacker.hasAbility(['Hustle']) && move.category == 'Physical') attack = pokeRound(attack * 3 / 2);
  final mods = calculateAtMods(attacker, defender, move, field);
  final v = pokeRound(attack * chainMods(mods, 410, 131072) / 4096);
  return of16(v < 1 ? 1 : v).toInt();
}

List<int> calculateAtMods(CalcPokemon attacker, CalcPokemon defender, CalcMove move, CalcField field) {
  final mods = <int>[];
  final physical = move.category == 'Physical';
  final special = move.category == 'Special';
  if ((attacker.hasAbility(['Slow Start']) && attacker.abilityOn && (physical || (special && move.isZ))) ||
      (attacker.hasAbility(['Defeatist']) && attacker.curHP() <= attacker.maxHP() / 2)) {
    mods.add(2048);
  } else if ((attacker.hasAbility(['Solar Power']) && field.hasWeather(['Sun', 'Harsh Sunshine']) && special) ||
      (attacker.named(['Cherrim']) &&
          attacker.hasAbility(['Flower Gift']) &&
          field.hasWeather(['Sun', 'Harsh Sunshine']) &&
          physical)) {
    mods.add(6144);
  } else if (attacker.hasAbility(['Gorilla Tactics']) && physical) {
    mods.add(6144);
  } else if ((attacker.hasAbility(['Guts']) && attacker.status.isNotEmpty && physical) ||
      (attacker.curHP() <= attacker.maxHP() / 3 &&
          ((attacker.hasAbility(['Overgrow']) && move.hasType(['Grass'])) ||
              (attacker.hasAbility(['Blaze']) && move.hasType(['Fire'])) ||
              (attacker.hasAbility(['Torrent']) && move.hasType(['Water'])) ||
              (attacker.hasAbility(['Swarm']) && move.hasType(['Bug'])))) ||
      (special && attacker.abilityOn && attacker.hasAbility(['Plus', 'Minus']))) {
    mods.add(6144);
  } else if (attacker.hasAbility(['Flash Fire']) && attacker.abilityOn && move.hasType(['Fire'])) {
    mods.add(6144);
  } else if ((attacker.hasAbility(['Steelworker']) && move.hasType(['Steel'])) ||
      (attacker.hasAbility(["Dragon's Maw"]) && move.hasType(['Dragon'])) ||
      (attacker.hasAbility(['Rocky Payload']) && move.hasType(['Rock'])) ||
      (attacker.hasAbility(['Fire Mane']) && move.hasType(['Fire']))) {
    mods.add(6144);
  } else if (attacker.hasAbility(['Transistor']) && move.hasType(['Electric'])) {
    mods.add(5325);
  } else if (attacker.hasAbility(['Stakeout']) && attacker.abilityOn) {
    mods.add(8192);
  } else if ((attacker.hasAbility(['Water Bubble']) && move.hasType(['Water'])) ||
      (attacker.hasAbility(['Huge Power', 'Pure Power']) && physical)) {
    mods.add(8192);
  }
  if (field.attackerSide.isFlowerGift &&
      !attacker.hasAbility(['Flower Gift']) &&
      field.hasWeather(['Sun', 'Harsh Sunshine']) &&
      physical) {
    mods.add(6144);
  }
  if (field.attackerSide.isSteelySpirit && move.hasType(['Steel'])) mods.add(6144);
  if ((defender.hasAbility(['Thick Fat']) && move.hasType(['Fire', 'Ice'])) ||
      (defender.hasAbility(['Water Bubble']) && move.hasType(['Fire'])) ||
      (defender.hasAbility(['Purifying Salt']) && move.hasType(['Ghost']))) {
    mods.add(2048);
  }
  if (defender.hasAbility(['Heatproof']) && move.hasType(['Fire'])) mods.add(2048);
  final tablets = (defender.hasAbility(['Tablets of Ruin']) || field.isTabletsOfRuin) && !attacker.hasAbility(['Tablets of Ruin']);
  final vessel = (defender.hasAbility(['Vessel of Ruin']) || field.isVesselOfRuin) && !attacker.hasAbility(['Vessel of Ruin']);
  if ((tablets && physical) || (vessel && special)) mods.add(3072);
  if (isQPActive(attacker, field)) {
    final stat = getQPBoostedStat(attacker);
    if ((physical && stat == 'atk') || (special && stat == 'spa')) mods.add(5325);
  }
  if ((attacker.hasAbility(['Hadron Engine']) && special && field.hasTerrain(['Electric'])) ||
      (attacker.hasAbility(['Orichalcum Pulse']) &&
          physical &&
          field.hasWeather(['Sun', 'Harsh Sunshine']) &&
          !attacker.hasItem(['Utility Umbrella']))) {
    mods.add(5461);
  }
  if ((attacker.hasItem(['Thick Club']) &&
          attacker.named(['Cubone', 'Marowak', 'Marowak-Alola', 'Marowak-Alola-Totem']) &&
          physical) ||
      (attacker.hasItem(['Deep Sea Tooth']) && attacker.named(['Clamperl']) && special) ||
      (attacker.hasItem(['Light Ball']) && attacker.name.contains('Pikachu') && !move.isZ)) {
    mods.add(8192);
  } else if (!move.isZ &&
      !move.isMax &&
      ((attacker.hasItem(['Choice Band']) && physical) || (attacker.hasItem(['Choice Specs']) && special))) {
    mods.add(6144);
  }
  return mods;
}

int calculateDefense(CalcPokemon attacker, CalcPokemon defender, CalcMove move, CalcField field, bool isCritical) {
  final hitsPhysical = move.overrideDefensiveStat == 'def' || move.category == 'Physical';
  final stat = hitsPhysical ? 'def' : 'spd';
  final boosts = defender.boosts[stat]!;
  int defense;
  if (boosts == 0 || (isCritical && boosts > 0) || move.ignoreDefensive) {
    defense = defender.rawStats[stat]!;
  } else if (attacker.hasAbility(['Unaware']) || move.name == 'Nihil Light') {
    defense = defender.rawStats[stat]!;
  } else {
    defense = getModifiedStat(defender.rawStats[stat]!, boosts);
  }
  if (field.hasWeather(['Sand']) && defender.hasType(['Rock']) && !hitsPhysical) defense = pokeRound(defense * 3 / 2);
  if (field.hasWeather(['Snow']) && defender.hasType(['Ice']) && hitsPhysical) defense = pokeRound(defense * 3 / 2);
  final mods = calculateDfMods(attacker, defender, move, field, isCritical, hitsPhysical);
  final v = pokeRound(defense * chainMods(mods, 410, 131072) / 4096);
  return of16(v < 1 ? 1 : v).toInt();
}

List<int> calculateDfMods(
    CalcPokemon attacker, CalcPokemon defender, CalcMove move, CalcField field, bool isCritical, bool hitsPhysical) {
  final mods = <int>[];
  final sun = field.hasWeather(['Sun', 'Harsh Sunshine']);
  if (defender.hasAbility(['Marvel Scale']) && defender.status.isNotEmpty && hitsPhysical) {
    mods.add(6144);
  } else if (defender.named(['Cherrim']) && defender.hasAbility(['Flower Gift']) && sun && !hitsPhysical) {
    mods.add(6144);
  } else if (field.defenderSide.isFlowerGift && sun && !hitsPhysical) {
    mods.add(6144);
  } else if (defender.hasAbility(['Grass Pelt']) && field.hasTerrain(['Grassy']) && hitsPhysical) {
    mods.add(6144);
  } else if (defender.hasAbility(['Fur Coat']) && hitsPhysical) {
    mods.add(8192);
  }
  final sword = (attacker.hasAbility(['Sword of Ruin']) || field.isSwordOfRuin) && !defender.hasAbility(['Sword of Ruin']);
  final beads = (attacker.hasAbility(['Beads of Ruin']) || field.isBeadsOfRuin) && !defender.hasAbility(['Beads of Ruin']);
  if ((sword && hitsPhysical) || (beads && !hitsPhysical)) mods.add(3072);
  if (isQPActive(defender, field)) {
    final stat = getQPBoostedStat(defender);
    if ((hitsPhysical && stat == 'def') || (!hitsPhysical && stat == 'spd')) mods.add(5324);
  }
  if ((defender.hasItem(['Eviolite']) && (defender.name == 'Dipplin' || defender.nfe)) ||
      (!hitsPhysical && defender.hasItem(['Assault Vest']))) {
    mods.add(6144);
  } else if ((defender.hasItem(['Metal Powder']) && defender.named(['Ditto']) && hitsPhysical) ||
      (defender.hasItem(['Deep Sea Scale']) && defender.named(['Clamperl']) && !hitsPhysical)) {
    mods.add(8192);
  }
  return mods;
}

int calculateBaseDamage(CalcPokemon attacker, CalcPokemon defender, int basePower, int attack, int defense,
    CalcMove move, CalcField field, bool isCritical) {
  var baseDamage = getBaseDamage(attacker.level, basePower, attack, defense);
  final isSpread = field.gameType != 'Singles' && ['allAdjacent', 'allAdjacentFoes'].contains(move.target);
  if (isSpread) baseDamage = pokeRound(of32(baseDamage * 3072) / 4096);
  if (attacker.hasAbility(['Parental Bond (Child)'])) baseDamage = pokeRound(of32(baseDamage * 1024) / 4096);
  final megaSol = attacker.hasAbility(['Mega Sol']);
  if ((field.hasWeather(['Sun']) || megaSol) && move.named(['Hydro Steam']) && !attacker.hasItem(['Utility Umbrella'])) {
    baseDamage = pokeRound(of32(baseDamage * 6144) / 4096);
  } else if (!defender.hasItem(['Utility Umbrella'])) {
    if (((field.hasWeather(['Sun', 'Harsh Sunshine']) || megaSol) && move.hasType(['Fire'])) ||
        ((field.hasWeather(['Rain', 'Heavy Rain']) && !megaSol) && move.hasType(['Water']))) {
      baseDamage = pokeRound(of32(baseDamage * 6144) / 4096);
    } else if (((field.hasWeather(['Sun']) || megaSol) && move.hasType(['Water'])) ||
        (field.hasWeather(['Rain']) && move.hasType(['Fire']))) {
      baseDamage = pokeRound(of32(baseDamage * 2048) / 4096);
    }
  }
  if (isCritical) baseDamage = of32(baseDamage * 1.5).floor();
  return baseDamage;
}

List<int> calculateFinalMods(CalcPokemon attacker, CalcPokemon defender, CalcMove move, CalcField field, bool isCritical,
    double typeEffectiveness,
    [int hitCount = 0]) {
  final data = attacker.data;
  final mods = <int>[];
  final doubles = field.gameType != 'Singles';
  final side = field.defenderSide;
  if (side.isReflect && move.category == 'Physical' && !isCritical && !side.isAuroraVeil) {
    mods.add(doubles ? 2732 : 2048);
  } else if (side.isLightScreen && move.category == 'Special' && !isCritical && !side.isAuroraVeil) {
    mods.add(doubles ? 2732 : 2048);
  }
  if (side.isAuroraVeil && !isCritical) mods.add(doubles ? 2732 : 2048);
  if (attacker.hasAbility(['Neuroforce']) && typeEffectiveness > 1) {
    mods.add(5120);
  } else if (attacker.hasAbility(['Sniper']) && isCritical) {
    mods.add(6144);
  } else if (attacker.hasAbility(['Tinted Lens']) && typeEffectiveness < 1) {
    mods.add(8192);
  }
  if (defender.hasAbility(['Multiscale', 'Shadow Shield']) &&
      defender.curHP() == defender.maxHP() &&
      hitCount == 0 &&
      ((!side.isSR && (side.spikes == 0 || defender.hasType(['Flying']))) || defender.hasItem(['Heavy-Duty Boots'])) &&
      !attacker.hasAbility(['Parental Bond (Child)'])) {
    mods.add(2048);
  }
  final halveContact = defender.hasAbility(['Fluffy']) || defender.hasAbility(['Aura Guard']);
  if (halveContact && move.flag('contact') && !attacker.hasAbility(['Long Reach'])) {
    mods.add(2048);
  } else if ((defender.hasAbility(['Punk Rock']) && move.flag('sound')) ||
      (defender.hasAbility(['Ice Scales']) && move.category == 'Special')) {
    mods.add(2048);
  }
  if (defender.hasAbility(['Solid Rock', 'Filter', 'Prism Armor']) && typeEffectiveness > 1) mods.add(3072);
  if (side.isFriendGuard) mods.add(3072);
  if (defender.hasAbility(['Fluffy']) && move.hasType(['Fire'])) mods.add(8192);
  if (attacker.hasItem(['Expert Belt']) && typeEffectiveness > 1 && !move.isZ) {
    mods.add(4915);
  } else if (attacker.hasItem(['Life Orb'])) {
    mods.add(5324);
  } else if (attacker.hasItem(['Metronome']) && move.timesUsedWithMetronome >= 1) {
    final times = move.timesUsedWithMetronome;
    mods.add(times <= 4 ? 4096 + times * 819 : 8192);
  }
  final resist = defender.item.isNotEmpty ? data.items[defender.item]?.resistType : null;
  if (move.hasType([resist]) &&
      (typeEffectiveness > 1 || move.hasType(['Normal'])) &&
      hitCount == 0 &&
      !attacker.hasAbility(['Unnerve', 'As One (Glastrier)', 'As One (Spectrier)'])) {
    mods.add(defender.hasAbility(['Ripen']) ? 1024 : 2048);
  }
  return mods;
}

// ---------------------------------------------------------------- chance de derrotar (desc.js)

/// [chance] de 0 a 1 (null = "pode derrotar", sem saber a chance), [n] golpes
/// ou turnos e o texto em português.
class KOChance {
  const KOChance(this.chance, this.n, this.text);
  final double? chance;
  final int n;
  final String text;
}

const _trapping = [
  'Bind', 'Clamp', 'Fire Spin', 'Infestation', 'Magma Storm', 'Sand Tomb', 'Thunder Cage', 'Whirlpool', 'Wrap', //
  'G-Max Sandblast', 'G-Max Centiferno',
];

(int, List<String>) _hazards(CalcPokemon defender, CalcSide side) {
  var damage = 0;
  final texts = <String>[];
  final data = defender.data;
  if (defender.hasItem(['Heavy-Duty Boots'])) return (0, texts);
  if (side.isSR && !defender.hasAbility(['Magic Guard', 'Mountaineer'])) {
    final e = defender.teraType.isNotEmpty && defender.teraType != 'Stellar'
        ? data.effectiveness('Rock', defender.teraType)
        : data.effectiveness('Rock', defender.types[0]) *
            (defender.types.length > 1 ? data.effectiveness('Rock', defender.types[1]) : 1);
    final d = (e * defender.maxHP() / 8).floor();
    damage += d < 1 ? 1 : d;
    texts.add('Stealth Rock');
  }
  if (!defender.hasType(['Flying']) &&
      !defender.hasAbility(['Magic Guard', 'Levitate', 'Eelevate']) &&
      !defender.hasItem(['Air Balloon'])) {
    if (side.spikes == 1) {
      damage += (defender.maxHP() / 8).floor();
      texts.add('1 camada de Spikes');
    } else if (side.spikes == 2) {
      damage += (defender.maxHP() / 6).floor();
      texts.add('2 camadas de Spikes');
    } else if (side.spikes == 3) {
      damage += (defender.maxHP() / 4).floor();
      texts.add('3 camadas de Spikes');
    }
  }
  return (damage, texts);
}

(int, List<String>) _endOfTurn(CalcPokemon attacker, CalcPokemon defender, CalcMove move, CalcField field) {
  var damage = 0;
  final texts = <String>[];
  final max = defender.maxHP();
  final loseItem = move.named(['Knock Off']) && !defender.hasAbility(['Sticky Hold']);
  final healBlock = move.named(['Psychic Noise']) &&
      !(attacker.hasAbility(['Sheer Force']) ||
          defender.hasItem(['Covert Cloak']) ||
          defender.hasAbility(['Shield Dust', 'Aroma Veil']));
  if (field.hasWeather(['Sun', 'Harsh Sunshine'])) {
    if (defender.hasAbility(['Dry Skin', 'Solar Power'])) {
      damage -= (max / 8).floor();
      texts.add('dano de ${defender.ability}');
    }
  } else if (field.hasWeather(['Rain', 'Heavy Rain']) && !healBlock) {
    if (defender.hasAbility(['Dry Skin'])) {
      damage += (max / 8).floor();
      texts.add('recuperação do Dry Skin');
    } else if (defender.hasAbility(['Rain Dish'])) {
      damage += (max / 16).floor();
      texts.add('recuperação do Rain Dish');
    }
  } else if (field.hasWeather(['Sand'])) {
    if (!defender.hasType(['Rock', 'Ground', 'Steel']) &&
        !defender.hasAbility(['Magic Guard', 'Overcoat', 'Sand Force', 'Sand Rush', 'Sand Veil']) &&
        !defender.hasItem(['Safety Goggles'])) {
      damage -= (max / 16).floor();
      texts.add('dano da tempestade de areia');
    }
  } else if (field.hasWeather(['Hail', 'Snow'])) {
    if (defender.hasAbility(['Ice Body']) && !healBlock) {
      damage += (max / 16).floor();
      texts.add('recuperação do Ice Body');
    } else if (!defender.hasType(['Ice']) &&
        !defender.hasAbility(['Magic Guard', 'Overcoat', 'Snow Cloak']) &&
        !defender.hasItem(['Safety Goggles']) &&
        field.hasWeather(['Hail'])) {
      damage -= (max / 16).floor();
      texts.add('dano do granizo');
    }
  }
  if (defender.hasItem(['Leftovers']) && !loseItem && !healBlock) {
    damage += (max / 16).floor();
    texts.add('recuperação do Leftovers');
  } else if (defender.hasItem(['Black Sludge']) && !loseItem) {
    if (defender.hasType(['Poison'])) {
      if (!healBlock) {
        damage += (max / 16).floor();
        texts.add('recuperação do Black Sludge');
      }
    } else if (!defender.hasAbility(['Magic Guard', 'Klutz'])) {
      damage -= (max / 8).floor();
      texts.add('dano do Black Sludge');
    }
  } else if (defender.hasItem(['Sticky Barb']) && !loseItem && !defender.hasAbility(['Magic Guard', 'Klutz'])) {
    damage -= (max / 8).floor();
    texts.add('dano do Sticky Barb');
  }
  if (field.defenderSide.isSeeded && !defender.hasAbility(['Magic Guard'])) {
    damage -= (max / 8).floor();
    texts.add('Leech Seed');
  }
  if (field.defenderSide.isNightmared && !defender.hasAbility(['Magic Guard'])) {
    damage -= (max / 4).floor();
    texts.add('Nightmare');
  }
  if (field.attackerSide.isSeeded && !attacker.hasAbility(['Magic Guard'])) {
    var recovery = (attacker.maxHP() / 8).floor();
    if (defender.hasItem(['Big Root'])) recovery = (recovery * 5324 / 4096).truncate();
    if (attacker.hasAbility(['Liquid Ooze'])) {
      damage -= recovery;
      texts.add('dano do Liquid Ooze');
    } else if (!healBlock) {
      damage += recovery;
      texts.add('recuperação do Leech Seed');
    }
  }
  if (field.hasTerrain(['Grassy']) && isGrounded(defender, field) && !healBlock) {
    damage += (max / 16).floor();
    texts.add('recuperação do Grassy Terrain');
  }
  if (defender.hasStatus(['psn'])) {
    if (defender.hasAbility(['Poison Heal'])) {
      if (!healBlock) {
        damage += (max / 8).floor();
        texts.add('Poison Heal');
      }
    } else if (!defender.hasAbility(['Magic Guard'])) {
      damage -= (max / 8).floor();
      texts.add('dano do veneno');
    }
  } else if (defender.hasStatus(['tox'])) {
    if (defender.hasAbility(['Poison Heal'])) {
      if (!healBlock) {
        damage += (max / 8).floor();
        texts.add('Poison Heal');
      }
    } else if (!defender.hasAbility(['Magic Guard'])) {
      texts.add('dano do veneno');
    }
  } else if (defender.hasStatus(['brn'])) {
    if (defender.hasAbility(['Heatproof'])) {
      damage -= (max / 32).floor();
      texts.add('dano reduzido da queimadura');
    } else if (!defender.hasAbility(['Magic Guard'])) {
      damage -= (max / 16).floor();
      texts.add('dano da queimadura');
    }
  } else if ((defender.hasStatus(['slp']) || defender.hasAbility(['Comatose'])) &&
      attacker.hasAbility(['Bad Dreams']) &&
      !defender.hasAbility(['Magic Guard'])) {
    damage -= (max / 8).floor();
    texts.add('Bad Dreams');
  }
  if (!defender.hasAbility(['Magic Guard']) && _trapping.contains(move.name)) {
    damage -= attacker.hasItem(['Binding Band']) ? (max / 6).floor() : (max / 8).floor();
    texts.add('dano de prender');
  }
  if (field.defenderSide.isSaltCured && !defender.hasAbility(['Magic Guard'])) {
    damage -= (max / (defender.hasType(['Water', 'Steel']) ? 4 : 8)).floor();
    texts.add('Salt Cure');
  }
  if (!defender.hasType(['Fire']) &&
      !defender.hasAbility(['Magic Guard']) &&
      move.named(['Fire Pledge (Grass Pledge Boosted)', 'Grass Pledge (Fire Pledge Boosted)'])) {
    damage -= (max / 8).floor();
    texts.add('mar de fogo');
  }
  return (damage, texts);
}

/// Junta os danos de todos os acertos numa só distribuição (como o original).
(List<int>, bool) _combine(List<List<int>> damage) {
  if (damage.length == 1) return (damage[0], false);
  if (damage.every((d) => d.length == 1)) {
    return ([damage.fold<int>(0, (s, d) => s + d[0])], false);
  }
  List<int> reduce(List<int> dist, int scale) {
    final length = dist.length ~/ scale;
    final reduced = List<int>.filled(length, 0);
    reduced[0] = dist[0];
    reduced[length - 1] = dist[dist.length - 1];
    for (var i = 1; i < length - 1; i++) {
      reduced[i] = dist[(i * scale + scale / 2).round()];
    }
    return reduced;
  }

  var combined = <int>[0];
  final numRolls = damage[0].length;
  final numAccuracy = numRolls == 16 && damage.length == 3 ? 3 : 2;
  var approximate = false;
  for (var i = 0; i < damage.length; i++) {
    final dist = damage[i];
    combined = [
      for (final a in combined)
        for (final b in dist) a + b
    ]..sort();
    if (i >= numAccuracy) {
      combined = reduce(combined, dist.length);
      approximate = true;
    }
  }
  return (combined, approximate);
}

double _computeKOChance(List<int> damage, int hp, int eot, int hits, int timesUsed, int maxHP, int toxicCounter) {
  var toxicDamage = 0;
  if (toxicCounter > 0) {
    toxicDamage = (toxicCounter * maxHP / 16).floor();
    toxicCounter++;
  }
  final n = damage.length;
  if (hits == 1) {
    if (eot - toxicDamage > 0) {
      eot = 0;
      toxicDamage = 0;
    }
    for (var i = 0; i < n; i++) {
      if (damage[n - 1] - eot + toxicDamage < hp) return 0;
      if (damage[i] - eot + toxicDamage >= hp) return (n - i) / n;
    }
  }
  var sum = 0.0;
  var lastc = 0.0;
  for (var i = 0; i < n; i++) {
    double c;
    if (i == 0 || damage[i] != damage[i - 1]) {
      c = _computeKOChance(damage, hp - damage[i] + eot - toxicDamage, eot, hits - 1, timesUsed, maxHP, toxicCounter);
    } else {
      c = lastc;
    }
    if (c == 1) {
      sum += n - i;
      break;
    } else {
      sum += c;
    }
    lastc = c;
  }
  return sum / n;
}

int _predictTotal(int damage, int eot, int hits, int timesUsed, int toxicCounter, int maxHP) {
  var toxicDamage = 0;
  var lastTurnEot = eot;
  if (toxicCounter > 0) {
    for (var i = 0; i < hits - 1; i++) {
      toxicDamage += ((toxicCounter + i) * maxHP / 16).floor();
    }
    lastTurnEot -= ((toxicCounter + (hits - 1)) * maxHP / 16).floor();
  }
  var total = hits > 1 && timesUsed == 1 ? damage * hits - eot * (hits - 1) + toxicDamage : damage - eot * (hits - 1) + toxicDamage;
  if (lastTurnEot < 0) total -= lastTurnEot;
  return total;
}

String _joinPt(List<String> parts) {
  if (parts.length <= 1) return parts.join();
  return '${parts.sublist(0, parts.length - 1).join(', ')} e ${parts.last}';
}

String _pct(double chance) {
  final r = (chance * 1000).round().clamp(1, 999) / 10;
  final s = r == r.roundToDouble() ? r.toInt().toString() : r.toString();
  return '${s.replaceAll('.', ',')}%';
}

KOChance getKOChance(CalcPokemon attacker, CalcPokemon defender, CalcMove move, CalcField field, List<List<int>> damageObj) {
  final (damage, approximate) = _combine(damageObj);
  if (damage.isEmpty || damage.last == 0) return const KOChance(0, 0, 'Não causa dano.');
  final timesUsed = move.timesUsed < 1 ? 1 : move.timesUsed;
  final metronome = move.timesUsedWithMetronome < 1 ? 1 : move.timesUsedWithMetronome;
  if (damage[0] >= defender.maxHP() && timesUsed == 1 && metronome == 1) {
    return const KOChance(1, 1, 'Derrota com 1 golpe, garantido.');
  }
  final (hazardDamage, hazardTexts) = _hazards(defender, field.defenderSide);
  final (eot, eotTexts) = _endOfTurn(attacker, defender, move, field);
  final toxicCounter =
      defender.hasStatus(['tox']) && !defender.hasAbility(['Magic Guard', 'Poison Heal']) ? defender.toxicCounter : 0;
  final qualifier = approximate ? 'aprox. ' : '';
  final hazardsText = hazardTexts.isNotEmpty ? ', depois de ${_joinPt(hazardTexts)}' : '';
  final afterText =
      hazardTexts.isNotEmpty || eotTexts.isNotEmpty ? ', depois de ${_joinPt([...hazardTexts, ...eotTexts])}' : '';
  final afterNoHazards = eotTexts.isNotEmpty ? ', depois de ${_joinPt(eotTexts)}' : '';

  KOChance ko(double? without, double? withEot, int n, [bool multipleTurns = false]) {
    final how = multipleTurns
        ? '$n turnos'
        : n == 1
            ? '1 golpe'
            : '$n golpes';
    if (without == null || withEot == null) return KOChance(null, n, '${qualifier}Pode derrotar com $how.');
    if (without + withEot == 0) return KOChance(0, n, 'Não derrota.');
    if (without == 1) return KOChance(1, n, 'Derrota com $how, garantido$hazardsText.');
    if (without > 0) {
      if (withEot == 1) {
        return KOChance(withEot, n,
            '$qualifier${_pct(without)} de chance de derrotar com $how$hazardsText (derrota com $how, garantido$afterNoHazards).');
      }
      if (withEot > without) {
        return KOChance(withEot, n,
            '$qualifier${_pct(without)} de chance de derrotar com $how$hazardsText ($qualifier${_pct(withEot)} de chance$afterNoHazards).');
      }
      return KOChance(withEot, n, '$qualifier${_pct(without)} de chance de derrotar com $how$hazardsText.');
    }
    // without == 0
    if (withEot == 1) return KOChance(1, n, 'Derrota com $how, garantido$afterText.');
    if (withEot > 0) return KOChance(withEot, n, '$qualifier${_pct(withEot)} de chance de derrotar com $how$afterText.');
    return KOChance(withEot, n, 'Não derrota.');
  }

  final hp = defender.curHP() - hazardDamage;
  if (timesUsed == 1 && metronome == 1) {
    final chance = _computeKOChance(damage, hp, 0, 1, 1, defender.maxHP(), 0);
    final chanceWithEot = _computeKOChance(damage, hp, eot, 1, 1, defender.maxHP(), toxicCounter);
    if (chance + chanceWithEot > 0) return ko(chance, chanceWithEot, 1);
    for (var i = 2; i <= 4; i++) {
      final c = _computeKOChance(damage, hp, eot, i, 1, defender.maxHP(), toxicCounter);
      if (c > 0) return ko(0, c, i);
    }
    for (var i = 5; i <= 9; i++) {
      if (_predictTotal(damage[0], eot, i, 1, toxicCounter, defender.maxHP()) >= hp) return ko(0, 1, i);
      if (_predictTotal(damage.last, eot, i, 1, toxicCounter, defender.maxHP()) >= hp) return ko(null, null, i);
    }
  } else {
    final chance = _computeKOChance(
        damage, defender.maxHP() - hazardDamage, eot, move.hits, timesUsed, defender.maxHP(), toxicCounter);
    if (chance > 0) return ko(0, chance, timesUsed, chance == 1);
    if (_predictTotal(damage[0], eot, 1, timesUsed, toxicCounter, defender.maxHP()) >= hp) {
      return ko(0, 1, timesUsed, true);
    }
    if (_predictTotal(damage.last, eot, 1, timesUsed, toxicCounter, defender.maxHP()) >= hp) {
      return ko(null, null, timesUsed, true);
    }
    return ko(0, 0, timesUsed);
  }
  return const KOChance(0, 0, 'Não derrota.');
}
