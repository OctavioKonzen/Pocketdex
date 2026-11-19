// lib/providers/favorites_provider.dart
//
// Favoritos ficam em UserData (sincronizados com a conta). As telas do app
// usam o id como texto; na conta ele é número.

import 'package:flutter/material.dart';
import '../services/user_data.dart';

class FavoritesProvider extends ChangeNotifier {
  final UserData _data = UserData.instance;

  FavoritesProvider() {
    _data.addListener(_onData);
    _onData();
  }

  List<String> _ids = [];
  List<String> get favoritePokemonIds => _ids;

  void _onData() {
    final ids = _data.favorites.map((id) => '$id').toList();
    if (ids.join(',') == _ids.join(',')) return;
    _ids = ids;
    notifyListeners();
  }

  bool isFavorite(String pokemonId) => _ids.contains(pokemonId);

  void toggleFavorite(String pokemonId) {
    final id = int.tryParse(pokemonId);
    if (id == null) return;
    final favorites = _data.favorites;
    favorites.contains(id) ? favorites.remove(id) : favorites.add(id);
    _data.update({'favorites': favorites});
  }

  @override
  void dispose() {
    _data.removeListener(_onData);
    super.dispose();
  }
}
