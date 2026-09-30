// lib/models/game.dart
//
// Jogos principais — mesmas chaves de "games" no banco e mesma lista do site
// (web-site/src/lib/pokemon.js).

import 'package:flutter/painting.dart';

class Game {
  final String key;
  final String name;
  final int gen;
  final List<int> mascots;
  final List<Color> colors;
  final bool spinoff; // jogo secundário
  /// As duas versões, quando cada uma tem Pokémon exclusivos (["Red", "Blue"]).
  final List<String> versions;
  const Game(this.key, this.name, this.gen, this.mascots, this.colors, {this.spinoff = false, this.versions = const []});

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
        stops: const [0.15, 0.9],
      );
}

const games = <Game>[
  Game('rb', 'Red / Blue', 1, [6, 9], [Color(0xFFE3350D), Color(0xFF3B7BD4)], versions: ['Red', 'Blue']),
  Game('yellow', 'Yellow', 1, [25], [Color(0xFFF4C430), Color(0xFFE0A800)]),
  Game('gs', 'Gold / Silver', 2, [250, 249], [Color(0xFFC9A227), Color(0xFF9EA3A8)], versions: ['Gold', 'Silver']),
  Game('crystal', 'Crystal', 2, [245], [Color(0xFF4FC3F7), Color(0xFF7E57C2)]),
  Game('rs', 'Ruby / Sapphire', 3, [383, 382], [Color(0xFFB3122E), Color(0xFF1F4FA8)], versions: ['Ruby', 'Sapphire']),
  Game('emerald', 'Emerald', 3, [384], [Color(0xFF2E8B57), Color(0xFF1B5E20)]),
  Game('frlg', 'FireRed / LeafGreen', 3, [6, 3], [Color(0xFFE65100), Color(0xFF43A047)], versions: ['FireRed', 'LeafGreen']),
  Game('dp', 'Diamond / Pearl', 4, [483, 484], [Color(0xFF5F8FD0), Color(0xFFC98AA0)], versions: ['Diamond', 'Pearl']),
  Game('platinum', 'Platinum', 4, [487], [Color(0xFF8D8D8D), Color(0xFF5E5E5E)]),
  Game('hgss', 'HeartGold / SoulSilver', 4, [250, 249], [Color(0xFFD4A017), Color(0xFFA8B8C8)], versions: ['HeartGold', 'SoulSilver']),
  Game('bw', 'Black / White', 5, [643, 644], [Color(0xFF2B2B2B), Color(0xFF9A9A9A)], versions: ['Black', 'White']),
  Game('b2w2', 'Black 2 / White 2', 5, [646], [Color(0xFF37474F), Color(0xFFB0BEC5)], versions: ['Black 2', 'White 2']),
  Game('xy', 'X / Y', 6, [716, 717], [Color(0xFF1E5AA8), Color(0xFFC8102E)], versions: ['X', 'Y']),
  Game('oras', 'Omega Ruby / Alpha Sapphire', 6, [383, 382], [Color(0xFFC62828), Color(0xFF1565C0)], versions: ['Omega Ruby', 'Alpha Sapphire']),
  Game('sm', 'Sun / Moon', 7, [791, 792], [Color(0xFFF28C28), Color(0xFF5B3F9E)], versions: ['Sun', 'Moon']),
  Game('usum', 'Ultra Sun / Ultra Moon', 7, [800], [Color(0xFFFF7043), Color(0xFF3949AB)], versions: ['Ultra Sun', 'Ultra Moon']),
  Game('lgpe', "Let's Go, Pikachu! / Eevee!", 7, [25, 133], [Color(0xFFF4C430), Color(0xFFA1887F)], versions: ["Let's Go Pikachu", "Let's Go Eevee"]),
  Game('swsh', 'Sword / Shield', 8, [888, 889], [Color(0xFF0091D5), Color(0xFFD8006F)], versions: ['Sword', 'Shield']),
  Game('bdsp', 'Brilliant Diamond / Shining Pearl', 8, [483, 484], [Color(0xFF4FA3E0), Color(0xFFE08DB5)], versions: ['Brilliant Diamond', 'Shining Pearl']),
  Game('pla', 'Legends: Arceus', 8, [493], [Color(0xFF6D5D3B), Color(0xFFC9B37E)]),
  Game('sv', 'Scarlet / Violet', 9, [1007, 1008], [Color(0xFFD0342C), Color(0xFF7B3FA0)], versions: ['Scarlet', 'Violet']),
  Game('lza', 'Legends: Z-A', 9, [718], [Color(0xFF2E7D32), Color(0xFF1B1B1B)]),
  // Jogos secundários.
  Game('colosseum', 'Colosseum', 3, [197, 196], [Color(0xFF6D4C41), Color(0xFF3E2723)], spinoff: true),
  Game('xd', 'XD: Gale of Darkness', 3, [249], [Color(0xFF4527A0), Color(0xFF1A237E)], spinoff: true),
  Game('conquest', 'Conquest', 5, [495], [Color(0xFFB71C1C), Color(0xFF212121)], spinoff: true),
  Game('champions', 'Champions', 9, [25], [Color(0xFF0D47A1), Color(0xFFFFB300)], spinoff: true),
];

final gamesByKey = {for (final g in games) g.key: g};
