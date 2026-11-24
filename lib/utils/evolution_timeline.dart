// lib/utils/evolution_timeline.dart
//
// A linha do tempo da evolução. Igual ao site (web-site/src/lib/evolutionTimeline.js):
// a cadeia em etapas (1ª forma, 2ª, 3ª...) e a condição de cada evolução.

import '../models/evolution_chain_entry.dart';

/// A condição de uma evolução: o ícone, o texto (com {0} para o nível) e o item, se for um.
typedef EvoCondition = ({String icon, String text, String? item, int? level});

/// Um Pokémon numa etapa: id, nome e a condição para chegar nele (null na primeira).
typedef EvoStep = ({String id, String name, EvoCondition? cond});

class EvolutionTimeline {
  static const _triggers = {
    'trade': ('🔄', 'Troca'),
    'level up': ('⬆️', 'Subir de nível (condição especial)'),
    'use move': ('🥋', 'Usar um golpe específico'),
    'agile style move': ('🥋', 'Golpe no estilo ágil'),
    'strong style move': ('🥋', 'Golpe no estilo forte'),
    'shed': ('🐚', 'Lugar livre no time e uma Poké Ball'),
    'spin': ('🌀', 'Girar com um doce'),
    'three critical hits': ('🎯', 'Três acertos críticos numa batalha'),
    'take damage': ('💢', 'Receber dano e passar por um arco'),
    'recoil damage': ('💢', 'Receber dano de recuo'),
    'gimmighoul coins': ('🪙', '999 moedas de Gimmighoul'),
    'meltan candies': ('🍬', '400 doces de Meltan'),
    'three defeated bisharp': ('⚔️', 'Derrotar três Bisharp líderes'),
    'tower of darkness': ('🏯', 'Torre da Escuridão'),
    'in battle level up': ('⬆️', 'Subir de nível numa batalha'),
  };

  /// A condição de "(Level 16)", "(water stone)", "(trade)"...
  static EvoCondition condition(String trigger) {
    final raw = trigger.replaceAll(RegExp(r'^\(|\)$'), '');
    final level = RegExp(r'^Level (\d+)$').firstMatch(raw);
    if (level != null) return (icon: '⬆️', text: 'Nível {0}', item: null, level: int.parse(level.group(1)!));
    final known = _triggers[raw];
    if (known != null) return (icon: known.$1, text: known.$2, item: null, level: null);
    if (raw.isEmpty || raw == 'Unknown') return (icon: '❔', text: 'Condição especial', item: null, level: null);
    // Um item: o nome dele (não traduz) e o ícone da Bolsa.
    final name = raw.split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
    return (icon: '🎒', text: name, item: raw.replaceAll(' ', '-'), level: null);
  }

  /// As etapas da cadeia, a primeira com a forma inicial.
  static List<List<EvoStep>> stages(List<EvolutionChainEntry> edges) {
    if (edges.isEmpty) return const [];
    final targets = {for (final e in edges) e.toPokemonId};
    final roots = <String, EvoStep>{
      for (final e in edges)
        if (!targets.contains(e.fromPokemonId)) e.fromPokemonId: (id: e.fromPokemonId, name: e.fromPokemonName, cond: null),
    };
    final out = [roots.values.toList()];
    final seen = {...roots.keys};
    while (true) {
      final prev = {for (final s in out.last) s.id};
      final next = <EvoStep>[
        for (final e in edges)
          if (prev.contains(e.fromPokemonId) && !seen.contains(e.toPokemonId)) (id: e.toPokemonId, name: e.toPokemonName, cond: condition(e.trigger)),
      ];
      if (next.isEmpty) break;
      seen.addAll(next.map((s) => s.id));
      out.add(next);
    }
    return out;
  }
}
