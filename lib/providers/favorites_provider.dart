import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesProvider extends ChangeNotifier {
  List<String> _favoritePokemonIds = [];

  List<String> get favoritePokemonIds => _favoritePokemonIds;

  FavoritesProvider() {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    _favoritePokemonIds = prefs.getStringList('favorite_pokemon') ?? [];
    notifyListeners();
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorite_pokemon', _favoritePokemonIds);
  }

  bool isFavorite(String pokemonId) {
    return _favoritePokemonIds.contains(pokemonId);
  }

  void toggleFavorite(String pokemonId) {
    if (isFavorite(pokemonId)) {
      _favoritePokemonIds.remove(pokemonId);
    } else {
      _favoritePokemonIds.add(pokemonId);
    }
    _saveFavorites();
    notifyListeners();
  }
}