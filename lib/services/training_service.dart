// lib/services/training_service.dart
//
// Pokémon em treino de EVs ficam em UserData (mesmo formato do site) e são
// sincronizados com a conta.

import '../models/training_pokemon.dart';
import 'account_format.dart';
import 'user_data.dart';

class TrainingService {
  UserData get _data => UserData.instance;

  Future<List<TrainingPokemon>> getTrainingList() async =>
      _data.training.map(AccountFormat.trainingFromAccount).toList();

  Future<void> saveTrainingList(List<TrainingPokemon> pokemons) async {
    final previous = {for (final t in _data.training) t['id']: t};
    _data.update({
      'training': [
        for (final p in pokemons) AccountFormat.trainingToAccount(p, previous[p.id]),
      ],
    });
  }
}
