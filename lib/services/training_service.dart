// lib/services/training_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/training_pokemon.dart';

class TrainingService {
  static const _key = 'training_pokemon_list';

  Future<List<TrainingPokemon>> getTrainingList() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null) {
      return [];
    }
    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((json) => TrainingPokemon.fromMap(json)).toList();
  }

  Future<void> saveTrainingList(List<TrainingPokemon> pokemons) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList =
        pokemons.map((p) => p.toMap()).toList();
    await prefs.setString(_key, json.encode(jsonList));
  }
}