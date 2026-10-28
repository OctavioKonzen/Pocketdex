class EvolutionChainEntry {
  final String fromPokemonName;
  final String toPokemonName;
  final String fromPokemonId;
  final String toPokemonId;
  final String trigger;

  EvolutionChainEntry({
    required this.fromPokemonName,
    required this.toPokemonName,
    required this.fromPokemonId,
    required this.toPokemonId,
    required this.trigger,
  });
}