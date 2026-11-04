// lib/services/team_sets.dart
//
// Dados completos de cada Pokémon do time — mesmo formato do site
// (web-site/src/lib/teamSets.js). O time guarda `sets`: 6 posições, uma para
// cada Pokémon de `pokemon`, com:
//   {nickname, level, gender ('M'|'F'|''), shiny, ability (slug), item (slug),
//    nature ('Jolly'...), tera (tipo), moves: [slug x4], evs: {hp..spe}, ivs: {hp..spe}}

const statKeys = ['hp', 'atk', 'def', 'spa', 'spd', 'spe'];
const statLabels = {'hp': 'HP', 'atk': 'Atk', 'def': 'Def', 'spa': 'SpA', 'spd': 'SpD', 'spe': 'Spe'};
const statNames = {'hp': 'HP', 'atk': 'Attack', 'def': 'Defense', 'spa': 'Sp. Atk', 'spd': 'Sp. Def', 'spe': 'Speed'};

/// Nature → (status que sobe, status que desce) (índices de [statKeys]).
const natures = <String, (int, int)>{
  'Hardy': (0, 0), 'Lonely': (1, 2), 'Brave': (1, 5), 'Adamant': (1, 3), 'Naughty': (1, 4), //
  'Bold': (2, 1), 'Docile': (0, 0), 'Relaxed': (2, 5), 'Impish': (2, 3), 'Lax': (2, 4),
  'Timid': (5, 1), 'Hasty': (5, 2), 'Serious': (0, 0), 'Jolly': (5, 3), 'Naive': (5, 4),
  'Modest': (3, 1), 'Mild': (3, 2), 'Quiet': (3, 5), 'Bashful': (0, 0), 'Rash': (3, 4),
  'Calm': (4, 1), 'Gentle': (4, 2), 'Sassy': (4, 5), 'Careful': (4, 3), 'Quirky': (0, 0),
};

String natureLabel(String name) {
  final (up, down) = natures[name] ?? (0, 0);
  return up == down ? '$name (neutra)' : '$name (+${statLabels[statKeys[up]]} −${statLabels[statKeys[down]]})';
}

/// Mecânica que o Pokémon usa na batalha (ativa sozinha no primeiro ataque, uma por time). Igual ao site.
const gimmicks = ['mega', 'z', 'dmax', 'tera'];

const teraTypes = [
  'normal', 'fire', 'water', 'electric', 'grass', 'ice', 'fighting', 'poison', 'ground', //
  'flying', 'psychic', 'bug', 'rock', 'ghost', 'dragon', 'dark', 'steel', 'fairy', 'stellar',
];

/// Itens mais usados em batalha (aparecem primeiro).
const popularItems = [
  'choice-band', 'choice-specs', 'choice-scarf', 'life-orb', 'leftovers', 'focus-sash', 'assault-vest', //
  'heavy-duty-boots', 'expert-belt', 'eviolite', 'booster-energy', 'rocky-helmet', 'sitrus-berry', 'lum-berry',
  'black-sludge', 'loaded-dice', 'clear-amulet', 'covert-cloak', 'air-balloon', 'weakness-policy', 'light-clay',
  'punching-glove', 'mirror-herb', 'throat-spray',
];

Map<String, int> _stats(int v) => {for (final k in statKeys) k: v};

int _clamp(Object? n, int min, int max, int fallback) {
  final v = n is num ? n : num.tryParse('${n ?? ''}');
  if (v == null || !v.isFinite) return fallback;
  return v.round().clamp(min, max);
}

/// Set novo para um Pokémon.
Map<String, dynamic> newSet([String ability = '']) => {
      'nickname': '',
      'level': 50,
      'gender': '',
      'shiny': false,
      'ability': ability,
      'item': '',
      'nature': 'Hardy',
      'tera': '',
      'gimmick': '',
      'moves': ['', '', '', ''],
      'evs': _stats(0),
      'ivs': _stats(31),
    };

/// Corrige um set vindo de fora: sempre completo e válido (ou null).
Map<String, dynamic>? normalizeSet(Object? raw) {
  if (raw is! Map) return null;
  String str(Object? v, [int max = 40]) => v is String ? (v.length > max ? v.substring(0, max) : v) : '';
  final moves = raw['moves'] is List ? raw['moves'] as List : const [];
  final evs = raw['evs'] is Map ? raw['evs'] as Map : const {};
  final ivs = raw['ivs'] is Map ? raw['ivs'] as Map : const {};
  final nature = raw['nature'];
  final tera = raw['tera'];
  return {
    'nickname': str(raw['nickname'], 18),
    'level': _clamp(raw['level'], 1, 100, 50),
    'gender': raw['gender'] == 'M' || raw['gender'] == 'F' ? raw['gender'] : '',
    'shiny': raw['shiny'] == true,
    'ability': str(raw['ability']),
    'item': str(raw['item']),
    'nature': natures.containsKey(nature) ? nature : 'Hardy',
    'tera': teraTypes.contains(tera) ? tera : '',
    'gimmick': gimmicks.contains(raw['gimmick']) ? raw['gimmick'] : '',
    'moves': [for (var i = 0; i < 4; i++) i < moves.length ? str(moves[i]) : ''],
    'evs': {for (final k in statKeys) k: _clamp(evs[k], 0, 252, 0)},
    'ivs': {for (final k in statKeys) k: _clamp(ivs[k], 0, 31, 31)},
  };
}

/// Os 6 sets de um time da conta (null onde não tem Pokémon).
List<Map<String, dynamic>?> teamSets(List<int?> pokemon, Object? sets) {
  final list = sets is List ? sets : const [];
  return [
    for (var i = 0; i < 6; i++) i < pokemon.length && pokemon[i] != null ? normalizeSet(i < list.length ? list[i] : null) : null,
  ];
}

/// Status final (fórmula dos jogos). base: [hp, atk, def, spa, spd, spe].
int statValue(List<int> base, int index, Map<String, dynamic> set) {
  final key = statKeys[index];
  final level = set['level'] as int;
  final core = ((2 * base[index] + (set['ivs'][key] as int) + (set['evs'][key] as int) ~/ 4) * level) ~/ 100;
  if (index == 0) return base[0] == 1 ? 1 : core + level + 10; // Shedinja
  final (up, down) = natures[set['nature']] ?? (0, 0);
  final mult = up == down ? 1.0 : (index == up ? 1.1 : (index == down ? 0.9 : 1.0));
  return ((core + 5) * mult).floor();
}

int evTotal(Map<String, dynamic> set) => statKeys.fold(0, (sum, k) => sum + (set['evs'][k] as int));

const _special = {
  'u-turn': 'U-turn', 'x-scissor': 'X-Scissor', 'v-create': 'V-create', 'kings-rock': "King's Rock", //
  'double-edge': 'Double-Edge', 'will-o-wisp': 'Will-O-Wisp', 'freeze-dry': 'Freeze-Dry', 'self-destruct': 'Self-Destruct',
  'soft-boiled': 'Soft-Boiled', 'lock-on': 'Lock-On', 'wake-up-slap': 'Wake-Up Slap', 'baby-doll-eyes': 'Baby-Doll Eyes',
  'power-up-punch': 'Power-Up Punch', 'mud-slap': 'Mud-Slap', 'trick-or-treat': 'Trick-or-Treat',
};

/// "choice-band" → "Choice Band"; "u-turn" → "U-turn".
String prettySlug(String slug) {
  if (slug.isEmpty) return '';
  return _special[slug] ?? slug.split('-').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
}

String _simple(String s) => s.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

/// Mapa nome simplificado → slug (para ler texto de simulador).
Map<String, String> lookupOf(Iterable<String> slugs) => {for (final s in slugs) _simple(s): s};

String _slugFor(String name, Map<String, String>? lookup) {
  final clean = name.trim();
  final found = lookup?[_simple(clean)];
  if (found != null) return found;
  return clean
      .toLowerCase()
      .replaceAll("'", '')
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}

/// Um Pokémon no formato de texto de times (Showdown, PKHeX e outros).
String setToText(String speciesName, Map<String, dynamic>? set) {
  if (set == null) return '$speciesName\n';
  final lines = <String>[];
  var first = (set['nickname'] as String).isNotEmpty ? '${set['nickname']} ($speciesName)' : speciesName;
  if ((set['gender'] as String).isNotEmpty) first += ' (${set['gender']})';
  if ((set['item'] as String).isNotEmpty) first += ' @ ${prettySlug(set['item'])}';
  lines.add(first);
  if ((set['ability'] as String).isNotEmpty) lines.add('Ability: ${prettySlug(set['ability'])}');
  if (set['level'] != 100) lines.add('Level: ${set['level']}');
  if (set['shiny'] == true) lines.add('Shiny: Yes');
  if ((set['tera'] as String).isNotEmpty) lines.add('Tera Type: ${prettySlug(set['tera'])}');
  final evs = [for (final k in statKeys) if (set['evs'][k] != 0) '${set['evs'][k]} ${statLabels[k]}'];
  if (evs.isNotEmpty) lines.add('EVs: ${evs.join(' / ')}');
  lines.add('${set['nature']} Nature');
  final ivs = [for (final k in statKeys) if (set['ivs'][k] != 31) '${set['ivs'][k]} ${statLabels[k]}'];
  if (ivs.isNotEmpty) lines.add('IVs: ${ivs.join(' / ')}');
  for (final mv in set['moves'] as List) {
    if ((mv as String).isNotEmpty) lines.add('- ${prettySlug(mv)}');
  }
  return '${lines.join('\n')}\n';
}

/// Bloco de texto de um Pokémon → (espécie, set).
(String, Map<String, dynamic>)? textToSet(String block,
    {Map<String, String>? moves, Map<String, String>? abilities, Map<String, String>? items}) {
  final rows = block.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  if (rows.isEmpty) return null;
  final set = newSet()..['level'] = 100; // sem "Level:" no texto = nível 100
  var first = rows.first;
  final at = first.indexOf('@');
  if (at >= 0) {
    set['item'] = _slugFor(first.substring(at + 1), items);
    first = first.substring(0, at).trim();
  }
  final gender = RegExp(r'\((M|F)\)\s*$').firstMatch(first);
  if (gender != null) {
    set['gender'] = gender.group(1);
    first = first.substring(0, gender.start).trim();
  }
  var species = first;
  final inner = RegExp(r'^(.*?)\s*\(([^()]+)\)\s*$').firstMatch(first);
  if (inner != null) {
    final nick = inner.group(1)!;
    set['nickname'] = nick.length > 18 ? nick.substring(0, 18) : nick;
    species = inner.group(2)!;
  }
  final moveList = List<String>.from(set['moves'] as List);
  for (final row in rows.skip(1)) {
    RegExpMatch? m;
    if ((m = RegExp(r'^Ability:\s*(.+)$', caseSensitive: false).firstMatch(row)) != null) {
      set['ability'] = _slugFor(m!.group(1)!, abilities);
    } else if ((m = RegExp(r'^Level:\s*(\d+)', caseSensitive: false).firstMatch(row)) != null) {
      set['level'] = _clamp(m!.group(1), 1, 100, 50);
    } else if (RegExp(r'^Shiny:\s*Yes', caseSensitive: false).hasMatch(row)) {
      set['shiny'] = true;
    } else if ((m = RegExp(r'^Tera Type:\s*(.+)$', caseSensitive: false).firstMatch(row)) != null) {
      final t = _simple(m!.group(1)!);
      set['tera'] = teraTypes.firstWhere((x) => x == t, orElse: () => '');
    } else if ((m = RegExp(r'^(EVs|IVs):\s*(.+)$', caseSensitive: false).firstMatch(row)) != null) {
      final target = Map<String, int>.from(set[m!.group(1)!.toLowerCase()] as Map);
      for (final part in m.group(2)!.split('/')) {
        final pm = RegExp(r'(\d+)\s*([A-Za-z]+)').firstMatch(part.trim());
        final key = pm?.group(2)!.toLowerCase();
        if (pm != null && statKeys.contains(key)) target[key!] = int.parse(pm.group(1)!);
      }
      set[m.group(1)!.toLowerCase()] = target;
    } else if ((m = RegExp(r'^(\w+)\s+Nature$', caseSensitive: false).firstMatch(row)) != null) {
      final name = m!.group(1)!.toLowerCase();
      for (final n in natures.keys) {
        if (n.toLowerCase() == name) set['nature'] = n;
      }
    } else if ((m = RegExp(r'^[-~]\s*(.+)$').firstMatch(row)) != null) {
      final i = moveList.indexWhere((x) => x.isEmpty);
      if (i >= 0) moveList[i] = _slugFor(m!.group(1)!.replaceAll(RegExp(r'\s*\[.*\]$'), ''), moves);
    }
  }
  set['moves'] = moveList;
  return (species, normalizeSet(set)!);
}
