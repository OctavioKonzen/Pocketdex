// lib/models/training_pokemon.dart

import 'dart:convert';

class TrainingPokemon {
  String id;
  String pokemonId;
  String pokemonName;
  String imageUrl;
  
  int hpEVs;
  int attackEVs;
  int defenseEVs;
  int spAttackEVs;
  int spDefenseEVs;
  int speedEVs;

  TrainingPokemon({
    required this.id,
    required this.pokemonId,
    required this.pokemonName,
    required this.imageUrl,
    this.hpEVs = 0,
    this.attackEVs = 0,
    this.defenseEVs = 0,
    this.spAttackEVs = 0,
    this.spDefenseEVs = 0,
    this.speedEVs = 0,
  });

  int get totalEVs => hpEVs + attackEVs + defenseEVs + spAttackEVs + spDefenseEVs + speedEVs;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pokemonId': pokemonId,
      'pokemonName': pokemonName,
      'imageUrl': imageUrl,
      'hpEVs': hpEVs,
      'attackEVs': attackEVs,
      'defenseEVs': defenseEVs,
      'spAttackEVs': spAttackEVs,
      'spDefenseEVs': spDefenseEVs,
      'speedEVs': speedEVs,
    };
  }

  factory TrainingPokemon.fromMap(Map<String, dynamic> map) {
    return TrainingPokemon(
      id: map['id'] ?? '',
      pokemonId: map['pokemonId'] ?? '',
      pokemonName: map['pokemonName'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      hpEVs: map['hpEVs']?.toInt() ?? 0,
      attackEVs: map['attackEVs']?.toInt() ?? 0,
      defenseEVs: map['defenseEVs']?.toInt() ?? 0,
      spAttackEVs: map['spAttackEVs']?.toInt() ?? 0,
      spDefenseEVs: map['spDefenseEVs']?.toInt() ?? 0,
      speedEVs: map['speedEVs']?.toInt() ?? 0,
    );
  }

  String toJson() => json.encode(toMap());

  factory TrainingPokemon.fromJson(String source) => TrainingPokemon.fromMap(json.decode(source));
}