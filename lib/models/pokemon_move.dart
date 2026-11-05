// lib/models/pokemon_move.dart

class PokemonMove {
  final String name;
  final String apiName; 
  final String learnMethod;
  final int levelLearnedAt;
  final String type;
  final int? power;
  final int? accuracy;
  final int pp;
  final String effect;

  PokemonMove({
    required this.name,
    required this.apiName,
    required this.learnMethod,
    required this.levelLearnedAt,
    required this.type,
    this.power,
    this.accuracy,
    required this.pp,
    required this.effect,
  });
}