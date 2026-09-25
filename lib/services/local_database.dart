// lib/services/local_database.dart
//
// Banco de dados local do Pocketdex. Os dados ficam em assets/database/*.json
// (gerados por tool/build_database.py) e são carregados sob demanda, então o
// app funciona igual no Android, iOS e na Web sem depender da PokeAPI.
//
// Os métodos `*Json` devolvem mapas no mesmo formato das respostas da PokeAPI,
// para que os models continuem iguais. As imagens também fazem parte do banco
// (assets/database/sprites/), então as URLs de sprite apontam para assets.

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../utils/app_images.dart';

class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  static const _statNames = ['hp', 'attack', 'defense', 'special-attack', 'special-defense', 'speed'];

  final Map<String, Future<dynamic>> _tables = {};

  Future<dynamic> _table(String name) {
    return _tables.putIfAbsent(name, () async {
      final raw = await rootBundle.loadString('assets/database/$name.json');
      return json.decode(raw);
    });
  }

  Future<Map<String, Map<String, dynamic>>> _indexByName(String table) async {
    final key = '$table#byName';
    final index = await _tables.putIfAbsent(key, () async {
      final rows = (await _table(table) as List).cast<Map<String, dynamic>>();
      return {for (final row in rows) row['name'] as String: row};
    });
    return index as Map<String, Map<String, dynamic>>;
  }

  Future<Map<int, Map<String, dynamic>>> _indexById(String table) async {
    final key = '$table#byId';
    final index = await _tables.putIfAbsent(key, () async {
      final rows = (await _table(table) as List).cast<Map<String, dynamic>>();
      return {for (final row in rows) row['id'] as int: row};
    });
    return index as Map<int, Map<String, dynamic>>;
  }

  Future<Map<String, dynamic>?> _find(String table, String idOrName) async {
    final key = idOrName.trim().toLowerCase();
    final id = int.tryParse(key);
    if (id != null) return (await _indexById(table))[id];
    return (await _indexByName(table))[key];
  }

  static String? spriteUrl(String? path) => AppImages.assetPath(path);

  /// Converte uma referência no formato "recurso/idOuNome/" em (recurso, chave).
  static (String, String) parseRef(String ref) {
    final parts = ref.split('/').where((s) => s.isNotEmpty).toList();
    if (parts.length < 2) throw ArgumentError('Referência inválida: $ref');
    return (parts[parts.length - 2], parts.last);
  }

  // ---------------------------------------------------------------------------
  // Pokémon
  // ---------------------------------------------------------------------------

  /// Espécie de cada Pokémon (ex.: 10034 Mega Charizard X → 6).
  Future<Map<int, int>> speciesOfPokemon() async {
    final index = await _indexById('pokemon');
    return {for (final e in index.entries) e.key: e.value['species'] as int};
  }

  /// Pokémon padrão de cada espécie, em ordem da Pokédex nacional.
  Future<List<Map<String, dynamic>>> defaultPokemon() async {
    final rows = (await _table('pokemon') as List).cast<Map<String, dynamic>>();
    return rows.where((p) => (p['id'] as int) < 10000).toList();
  }

  Future<Map<String, dynamic>?> pokemonJson(String idOrName) async {
    final p = await _find('pokemon', idOrName);
    return p == null ? null : _pokemonToApi(p);
  }

  Map<String, dynamic> _pokemonToApi(Map<String, dynamic> p) {
    final sprites = p['sprites'] as List;
    final stats = p['stats'] as List;
    return {
      'id': p['id'],
      'name': p['name'],
      'is_default': p['is_default'],
      'base_experience': p['base_experience'],
      'height': p['height'],
      'weight': p['weight'],
      'species': {'name': p['name'], 'url': 'pokemon-species/${p['species']}/'},
      'abilities': <dynamic>[
        for (var i = 0; i < (p['abilities'] as List).length; i++)
          {
            'slot': i + 1,
            'is_hidden': p['abilities'][i][1],
            'ability': {'name': p['abilities'][i][0], 'url': 'ability/${p['abilities'][i][0]}/'},
          },
      ],
      'forms': <dynamic>[
        for (final id in p['forms'] as List) {'url': 'pokemon-form/$id/'},
      ],
      'types': <dynamic>[
        for (var i = 0; i < (p['types'] as List).length; i++)
          {'slot': i + 1, 'type': {'name': p['types'][i]}},
      ],
      'stats': <dynamic>[
        for (var i = 0; i < _statNames.length; i++)
          {'base_stat': stats[i][0], 'effort': stats[i][1], 'stat': {'name': _statNames[i]}},
      ],
      'sprites': {
        'front_default': spriteUrl(sprites[0]),
        'front_shiny': spriteUrl(sprites[1]),
        'other': {
          'official-artwork': {
            'front_default': spriteUrl(sprites[2]),
            'front_shiny': spriteUrl(sprites[3]),
          },
        },
      },
      'moves': _movesToApi(p['moves'] as List),
    };
  }

  /// Linhas [golpe, método, nível] agrupadas por golpe, no formato da PokeAPI.
  List<dynamic> _movesToApi(List rows) {
    final byMove = <String, List<dynamic>>{};
    for (final row in rows) {
      byMove.putIfAbsent(row[0] as String, () => <dynamic>[]).add({
        'level_learned_at': row[2],
        'move_learn_method': {'name': row[1]},
      });
    }
    return <dynamic>[
      for (final entry in byMove.entries)
        {'move': {'name': entry.key, 'url': 'move/${entry.key}/'}, 'version_group_details': entry.value},
    ];
  }

  /// Formas (inclusive cosméticas, como Unown A–Z) com sprites normais e shiny.
  Future<Map<String, dynamic>?> formJson(String idOrName) async {
    final f = await _find('forms', idOrName);
    if (f == null) return null;
    final sprites = f['sprites'] as List;
    final pokemonById = await _indexById('pokemon');
    return {
      'id': f['id'],
      'name': f['name'],
      'form_name': f['form_name'],
      'is_default': f['is_default'],
      'is_mega': f['is_mega'],
      'is_battle_only': f['is_battle_only'],
      'pokemon': {'name': pokemonById[f['pokemon']]?['name'], 'url': 'pokemon/${f['pokemon']}/'},
      'types': <dynamic>[
        for (var i = 0; i < (f['types'] as List).length; i++)
          {'slot': i + 1, 'type': {'name': f['types'][i]}},
      ],
      'sprites': {
        'front_default': spriteUrl(sprites[0]),
        'front_shiny': spriteUrl(sprites[1]),
        'other': {
          'official-artwork': {
            'front_default': spriteUrl(sprites[2]),
            'front_shiny': spriteUrl(sprites[3]),
          },
        },
      },
    };
  }

  /// Todas as formas de um Pokémon (pelo id do Pokémon).
  Future<List<Map<String, dynamic>>> formsOfPokemon(int pokemonId) async {
    final rows = (await _table('forms') as List).cast<Map<String, dynamic>>();
    return [
      for (final f in rows)
        if (f['pokemon'] == pokemonId) (await formJson('${f['id']}'))!,
    ];
  }

  // ---------------------------------------------------------------------------
  // Espécies e evoluções
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> speciesJson(String idOrName) async {
    final s = await _find('species', idOrName);
    if (s == null) return null;
    final pokemonById = await _indexById('pokemon');
    return {
      'id': s['id'],
      'name': s['name'],
      'gender_rate': s['gender_rate'],
      'hatch_counter': s['hatch_counter'],
      'capture_rate': s['capture_rate'],
      'base_happiness': s['base_happiness'],
      'is_baby': s['is_baby'],
      'is_legendary': s['is_legendary'],
      'is_mythical': s['is_mythical'],
      'growth_rate': _named(s['growth_rate']),
      'habitat': _named(s['habitat']),
      'color': _named(s['color']),
      'shape': _named(s['shape']),
      'evolves_from_species': s['evolves_from'] == null
          ? null
          : {'name': await speciesName(s['evolves_from'] as int), 'url': 'pokemon-species/${s['evolves_from']}/'},
      'names': <dynamic>[
        for (final entry in (s['names'] as Map<String, dynamic>).entries)
          {'name': entry.value, 'language': {'name': entry.key}},
      ],
      'pokedex_numbers': <dynamic>[
        for (final entry in (s['pokedex_numbers'] as Map<String, dynamic>).entries)
          {'entry_number': entry.value, 'pokedex': {'name': entry.key}},
      ],
      'flavor_text_entries': <dynamic>[
        if (s['flavor'] != null) {'flavor_text': s['flavor'], 'language': {'name': 'en'}},
      ],
      'genera': <dynamic>[
        if (s['genus'] != null) {'genus': s['genus'], 'language': {'name': 'en'}},
      ],
      'egg_groups': <dynamic>[for (final g in s['egg_groups'] as List) {'name': g}],
      'evolution_chain': s['evolution_chain'] == null ? null : {'url': 'evolution-chain/${s['evolution_chain']}/'},
      'varieties': <dynamic>[
        for (final id in s['varieties'] as List)
          {'pokemon': {'name': pokemonById[id]?['name'] ?? '$id', 'url': 'pokemon/$id/'}},
      ],
    };
  }

  Future<Map<String, dynamic>?> evolutionChainJson(String id) async {
    final chains = await _table('evolution_chains') as Map<String, dynamic>;
    final chain = chains[id];
    if (chain == null) return null;

    Map<String, dynamic> toApi(Map<String, dynamic> node) {
      final details = node['details'] as Map<String, dynamic>?;
      return {
        'species': {'name': node['name'], 'url': 'pokemon-species/${node['species']}/'},
        'evolution_details': <dynamic>[
          if (details != null)
            {
              'trigger': {'name': details['trigger'] ?? 'unknown'},
              'min_level': details['min_level'],
              'item': details['item'] == null ? null : {'name': details['item']},
            },
        ],
        'evolves_to': <dynamic>[for (final e in node['evolves_to'] as List) toApi(e as Map<String, dynamic>)],
      };
    }

    return {'id': int.parse(id), 'chain': toApi(chain as Map<String, dynamic>)};
  }

  Future<List<int>> speciesIdsOfGeneration(int generation) async {
    final gens = await _table('generations') as Map<String, dynamic>;
    return ((gens['$generation'] ?? []) as List).cast<int>();
  }

  Future<List<int>> speciesIdsOfEggGroup(String eggGroup) async {
    final groups = await _table('egg_groups') as Map<String, dynamic>;
    return ((groups[eggGroup] ?? []) as List).cast<int>();
  }

  Future<String> speciesName(int id) async {
    return (await _indexById('species'))[id]?['name'] as String? ?? 'pokemon-$id';
  }

  // ---------------------------------------------------------------------------
  // Tipos
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> typeJson(String name) async {
    final types = await _table('types') as Map<String, dynamic>;
    final t = types[name.toLowerCase()];
    if (t == null) return null;
    final relations = t['damage_relations'] as Map<String, dynamic>;
    return {
      'name': name.toLowerCase(),
      'damage_relations': {
        for (final entry in relations.entries)
          entry.key: <dynamic>[for (final typeName in entry.value as List) {'name': typeName}],
      },
      'pokemon': await _pokemonRefs((t['pokemon'] as List).cast<int>(), wrap: true),
    };
  }

  // ---------------------------------------------------------------------------
  // Golpes, itens e habilidades
  // ---------------------------------------------------------------------------

  Future<List<Map<String, String>>> resourceList(String table, String resource) async {
    final rows = (await _table(table) as List).cast<Map<String, dynamic>>();
    return [
      for (final row in rows) {'name': row['name'] as String, 'url': '$resource/${row['id']}/'},
    ];
  }

  Future<Map<String, dynamic>?> moveJson(String idOrName) async {
    final m = await _find('moves', idOrName);
    if (m == null) return null;
    return {
      'id': m['id'],
      'name': m['name'],
      'type': {'name': m['type'] ?? 'unknown'},
      'damage_class': {'name': m['damage_class'] ?? 'status'},
      'power': m['power'],
      'accuracy': m['accuracy'],
      'pp': m['pp'],
      'effect_chance': m['effect_chance'],
      'priority': m['priority'],
      'target': _named(m['target']),
      'generation': m['generation'] == null ? null : {'url': 'generation/${m['generation']}/'},
      'meta': m['meta'] == null
          ? null
          : {
              ...m['meta'] as Map<String, dynamic>,
              'ailment': _named(m['meta']['ailment']),
              'category': _named(m['meta']['category']),
            },
      'stat_changes': <dynamic>[
        for (final c in m['stat_changes'] as List) {'change': c[1], 'stat': {'name': c[0]}},
      ],
      'effect_entries': _englishEffect(m['effect'], m['effect_full']),
      'flavor_text_entries': _englishFlavor(m['flavor']),
      'learned_by_pokemon': await _pokemonRefs((m['learned_by'] as List).cast<int>()),
    };
  }

  Future<Map<String, dynamic>?> itemJson(String idOrName) async {
    final i = await _find('items', idOrName);
    if (i == null) return null;
    return {
      'id': i['id'],
      'name': i['name'],
      'sprites': {'default': spriteUrl(i['sprite'])},
      'category': {'name': i['category']},
      'cost': i['cost'],
      'fling_power': i['fling_power'],
      'fling_effect': _named(i['fling_effect']),
      'attributes': <dynamic>[for (final a in i['attributes'] as List) {'name': a}],
      'held_by_pokemon': <dynamic>[
        for (final ref in await _pokemonRefs((i['held_by'] as List).cast<int>())) {'pokemon': ref},
      ],
      'effect_entries': _englishEffect(i['effect'], i['effect_full']),
      'flavor_text_entries': _englishFlavor(i['flavor'], key: 'text'),
    };
  }

  Future<Map<String, dynamic>?> abilityJson(String idOrName) async {
    final a = await _find('abilities', idOrName);
    if (a == null) return null;
    return {
      'id': a['id'],
      'name': a['name'],
      'is_main_series': a['is_main_series'],
      'generation': a['generation'] == null ? null : {'url': 'generation/${a['generation']}/'},
      'effect_entries': _englishEffect(a['effect'], a['effect_full']),
      'flavor_text_entries': _englishFlavor(a['flavor']),
      'pokemon': [
        for (final ref in await _pokemonRefs((a['pokemon'] as List).cast<int>(), wrap: true))
          {...ref as Map<String, dynamic>, 'is_hidden': (a['hidden_for'] as List).contains(_idOf(ref['pokemon']['url']))},
      ],
    };
  }

  /// Busca um recurso a partir de uma referência "recurso/idOuNome/".
  Future<Map<String, dynamic>?> resourceJson(String ref) {
    final (resource, key) = parseRef(ref);
    switch (resource) {
      case 'pokemon':
        return pokemonJson(key);
      case 'pokemon-species':
        return speciesJson(key);
      case 'evolution-chain':
        return evolutionChainJson(key);
      case 'move':
        return moveJson(key);
      case 'item':
        return itemJson(key);
      case 'ability':
        return abilityJson(key);
      case 'type':
        return typeJson(key);
      case 'pokemon-form':
        return formJson(key);
    }
    throw ArgumentError('Recurso desconhecido: $resource');
  }

  List<dynamic> _englishEffect(String? shortEffect, [String? effect]) => <dynamic>[
        if (shortEffect != null || effect != null)
          {'short_effect': shortEffect, 'effect': effect, 'language': {'name': 'en'}},
      ];

  List<dynamic> _englishFlavor(String? text, {String key = 'flavor_text'}) => <dynamic>[
        if (text != null) {key: text, 'language': {'name': 'en'}},
      ];

  static Map<String, dynamic>? _named(Object? name) => name == null ? null : {'name': name};

  static int _idOf(String url) => int.parse(parseRef(url).$2);

  Future<List<dynamic>> _pokemonRefs(List<int> ids, {bool wrap = false}) async {
    final pokemonById = await _indexById('pokemon');
    return <dynamic>[
      for (final id in ids)
        if (pokemonById[id] != null)
          wrap
              ? {'pokemon': {'name': pokemonById[id]!['name'], 'url': 'pokemon/$id/'}}
              : {'name': pokemonById[id]!['name'], 'url': 'pokemon/$id/'},
    ];
  }
}
