import 'package:flutter/painting.dart';

class Generation {
  final int id;
  final String name;
  final String pokedexName;
  final List<String> starterIds;
  final String region;

  /// Cores dos jogos da geração (as mesmas do site), usadas em gradiente.
  final List<Color> colors;

  Generation({
    required this.id,
    required this.name,
    required this.pokedexName,
    required this.starterIds,
    required this.region,
    required this.colors,
  });

  String get label => name.replaceFirst('Generation', 'Geração');

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
        stops: const [0.15, 0.9],
      );
}

final List<Generation> generations = [
  Generation(id: 1, name: 'Generation I', pokedexName: 'kanto', starterIds: ['1', '4', '7'], region: 'Kanto', colors: const [Color(0xFFE3350D), Color(0xFF3B7BD4)]),
  Generation(id: 2, name: 'Generation II', pokedexName: 'original-johto', starterIds: ['152', '155', '158'], region: 'Johto', colors: const [Color(0xFFC9A227), Color(0xFF9EA3A8)]),
  Generation(id: 3, name: 'Generation III', pokedexName: 'hoenn', starterIds: ['252', '255', '258'], region: 'Hoenn', colors: const [Color(0xFFB3122E), Color(0xFF1F4FA8)]),
  Generation(id: 4, name: 'Generation IV', pokedexName: 'original-sinnoh', starterIds: ['387', '390', '393'], region: 'Sinnoh', colors: const [Color(0xFF5F8FD0), Color(0xFFC98AA0)]),
  Generation(id: 5, name: 'Generation V', pokedexName: 'original-unova', starterIds: ['495', '498', '501'], region: 'Unova', colors: const [Color(0xFF2B2B2B), Color(0xFF9A9A9A)]),
  Generation(id: 6, name: 'Generation VI', pokedexName: 'kalos-central', starterIds: ['650', '653', '656'], region: 'Kalos', colors: const [Color(0xFF1E5AA8), Color(0xFFC8102E)]),
  Generation(id: 7, name: 'Generation VII', pokedexName: 'original-alola', starterIds: ['722', '725', '728'], region: 'Alola', colors: const [Color(0xFFF28C28), Color(0xFF5B3F9E)]),
  Generation(id: 8, name: 'Generation VIII', pokedexName: 'galar', starterIds: ['810', '813', '816'], region: 'Galar', colors: const [Color(0xFF0091D5), Color(0xFFD8006F)]),
  Generation(id: 9, name: 'Generation IX', pokedexName: 'paldea', starterIds: ['906', '909', '912'], region: 'Paldea', colors: const [Color(0xFFD0342C), Color(0xFF7B3FA0)]),
];

/// "Todas as gerações" (Pikachu, Eevee e Mewtwo, como no site).
const allGenerationsStarters = ['25', '133', '150'];
const allGenerationsGradient = LinearGradient(colors: [Color(0xFF26A69A), Color(0xFF42A5F5)]);
