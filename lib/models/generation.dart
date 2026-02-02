class Generation {
  final int id;
  final String name;
  final String pokedexName;
  final List<String> starterIds;

  Generation({
    required this.id,
    required this.name,
    required this.pokedexName,
    required this.starterIds,
  });
}

final List<Generation> generations = [
  Generation(id: 1, name: 'Generation I', pokedexName: 'kanto', starterIds: ['1', '4', '7']),
  Generation(id: 2, name: 'Generation II', pokedexName: 'original-johto', starterIds: ['152', '155', '158']),
  Generation(id: 3, name: 'Generation III', pokedexName: 'hoenn', starterIds: ['252', '255', '258']),
  Generation(id: 4, name: 'Generation IV', pokedexName: 'original-sinnoh', starterIds: ['387', '390', '393']),
  Generation(id: 5, name: 'Generation V', pokedexName: 'original-unova', starterIds: ['495', '498', '501']),
  Generation(id: 6, name: 'Generation VI', pokedexName: 'kalos-central', starterIds: ['650', '653', '656']),
  Generation(id: 7, name: 'Generation VII', pokedexName: 'original-alola', starterIds: ['722', '725', '728']),
  Generation(id: 8, name: 'Generation VIII', pokedexName: 'galar', starterIds: ['810', '813', '816']),
  Generation(id: 9, name: 'Generation IX', pokedexName: 'paldea', starterIds: ['906', '909', '912']),
];