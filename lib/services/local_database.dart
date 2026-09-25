// lib/services/local_database.dart
//
// Banco de dados local do Pocketdex. Os dados ficam em assets/database/*.json
// (gerados por tool/build_database.py) e são carregados sob demanda, então o
// app funciona igual no Android, iOS e na Web sem depender da PokeAPI.
//
// Os métodos `*Json` devolvem mapas no mesmo formato das respostas da PokeAPI
// (apenas com os campos usados pelo app), para que os models continuem iguais.

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  static const spritesBaseUrl = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/';
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

  static String? spriteUrl(String? path) {
    if (path == null) return null;
    return path.startsWith('http') ? path : '$spritesBaseUrl$path';
  }

  /// Converte uma referência no formato "recurso/idOuNome/" em (recurso, chave).
  static (String, String) parseRef(String ref) {
    final parts = ref.split('/').where((s) => s.isNotEmpty).toList();
    if (parts.length < 2) throw ArgumentError('Referência inválida: $ref');
    return (parts[parts.length - 2], parts.last);
  }

  // ---------------------------------------------------------------------------
  // Pokémon
  // ---------------------------------------------------------------------------

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
      'height': p['height'],
      'weight': p['weight'],
      'species': {'name': p['name'], 'url': 'pokemon-species/${p['species']}/'},
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
      'moves': <dynamic>[
        for (final m in p['moves'] as List)
          {
            'move': {'name': m[0]},
            'version_group_details': <dynamic>[
              {
                'level_learned_at': m[1],
                'move_learn_method': {'name': m[1] > 0 ? 'level-up' : 'machine'},
              },
            ],
          },
      ],
    };
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
      'effect_entries': _englishEffect(m['effect']),
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
      'effect_entries': _englishEffect(i['effect']),
    };
  }

  Future<Map<String, dynamic>?> abilityJson(String idOrName) async {
    final a = await _find('abilities', idOrName);
    if (a == null) return null;
    return {
      'id': a['id'],
      'name': a['name'],
      'effect_entries': _englishEffect(a['effect']),
      'pokemon': await _pokemonRefs((a['pokemon'] as List).cast<int>(), wrap: true),
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
    }
    throw ArgumentError('Recurso desconhecido: $resource');
  }

  List<dynamic> _englishEffect(String? effect) => <dynamic>[
        if (effect != null) {'short_effect': effect, 'language': {'name': 'en'}},
      ];

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
