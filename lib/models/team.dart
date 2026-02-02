// lib/models/team.dart

import 'dart:convert';

class Team {
  String id;
  String name;
  List<Map<String, String>> pokemons;
  double? score;
  String? color; 

  Team({
    required this.id,
    required this.name,
    this.pokemons = const [],
    this.score,
    this.color, 
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'pokemons': pokemons,
      'score': score,
      'color': color,
    };
  }

  factory Team.fromMap(Map<String, dynamic> map) {
    final pokemonData = map['pokemons'] as List<dynamic>? ?? [];
    final pokemonsList = pokemonData
        .map((item) => Map<String, String>.from(item as Map))
        .toList();

    return Team(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      pokemons: pokemonsList,
      score: map['score'],
      color: map['color'],
    );
  }
  
  String toJson() => json.encode(toMap());

  factory Team.fromJson(String source) => Team.fromMap(json.decode(source));
}