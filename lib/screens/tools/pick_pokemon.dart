// lib/screens/tools/pick_pokemon.dart
//
// Abre a Pokédex para escolher um Pokémon e devolve o id dele.

import 'package:flutter/material.dart';

import '../../services/account_format.dart';
import '../pokedex_screen.dart';

Future<int?> pickPokemon(BuildContext context) async {
  final result = await Navigator.of(context).push<Map<String, String>?>(
    MaterialPageRoute(builder: (_) => const PokedexScreen(isForTeamSelection: true)),
  );
  if (result == null) return null;
  return AccountFormat.pokemonIdFromImage(result['imageUrl']) ?? int.tryParse(result['id'] ?? '');
}

/// "mr-mime" → "Mr" (como os cards mostram o nome).
String shortName(String slug) {
  final base = slug.split('-').first;
  return base.isEmpty ? base : base[0].toUpperCase() + base.substring(1);
}
