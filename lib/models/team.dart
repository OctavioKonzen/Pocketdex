// lib/models/team.dart

import 'dart:convert';

import '../services/team_sets.dart';

class Team {
  String id;
  String name;
  List<Map<String, String>> pokemons;
  /// Dados completos de cada Pokémon (golpes, item, EVs...), na mesma posição
  /// de [pokemons] — formato de lib/services/team_sets.dart.
  List<Map<String, dynamic>?> sets;
  double? score;
  String? color;

  Team({
    required this.id,
    required this.name,
    this.pokemons = const [],
    List<Map<String, dynamic>?>? sets,
    this.score,
    this.color,
  }) : sets = sets ?? List.filled(6, null);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'pokemons': pokemons,
      'sets': sets,
      'score': score,
      'color': color,
    };
  }

  factory Team.fromMap(Map<String, dynamic> map) {
    final pokemonData = map['pokemons'] as List<dynamic>? ?? [];
    final pokemonsList = pokemonData
        .map((item) => Map<String, String>.from(item as Map))
        .toList();

    final setsData = map['sets'] as List<dynamic>? ?? const [];
    return Team(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      pokemons: pokemonsList,
      sets: [for (var i = 0; i < 6; i++) i < setsData.length ? normalizeSet(setsData[i]) : null],
      score: map['score'],
      color: map['color'],
    );
  }
  
  String toJson() => json.encode(toMap());

  factory Team.fromJson(String source) => Team.fromMap(json.decode(source));
}