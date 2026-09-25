// lib/services/account_format.dart
//
// Converte os modelos do app (Team, TrainingPokemon) para o formato dos dados
// da conta, que é o mesmo do site (ver UserData), e de volta.
//
// No app um Pokémon de time/treino é {id: espécie, imageUrl: arte da forma};
// no site é só o id do Pokémon (a forma), ex.: 10034 = Mega Charizard X.

import '../models/team.dart';
import '../models/training_pokemon.dart';
import '../utils/app_images.dart';
import 'local_database.dart';
import 'user_data.dart';

class AccountFormat {
  AccountFormat._();

  static Map<int, int> _species = {};

  /// Carrega a tabela Pokémon → espécie (chamado ao abrir o app).
  static Future<void> init() async {
    _species = await LocalDatabase.instance.speciesOfPokemon();
    _migrateLegacy();
  }

  static int speciesOf(int pokemonId) => _species[pokemonId] ?? pokemonId;

  /// Id do Pokémon (forma) a partir da imagem salva pelo app.
  static int? pokemonIdFromImage(String? imageUrl) {
    if (imageUrl == null) return null;
    final match = RegExp(r'/(\d+)\.(png|webp)$').firstMatch(imageUrl);
    return match == null ? null : int.parse(match.group(1)!);
  }

  static Map<String, String> _appPokemon(int pokemonId) => {
        'id': '${speciesOf(pokemonId)}',
        'imageUrl': AppImages.pokemonArtwork(pokemonId),
      };

  static int? _accountPokemon(Map<String, String> p) {
    if (p.isEmpty) return null;
    return pokemonIdFromImage(p['imageUrl']) ?? int.tryParse(p['id'] ?? '');
  }

  // ---------------------------------------------------------------- cores
  // App: 'ffrrggbb' (ARGB em hexa) · Site: '#RRGGBB'

  static String? colorToAccount(String? argb) {
    if (argb == null || argb.isEmpty) return null;
    final hex = argb.padLeft(8, '0');
    return '#${hex.substring(hex.length - 6).toUpperCase()}';
  }

  static String? colorFromAccount(String? css) {
    if (css == null || !css.startsWith('#') || css.length != 7) return null;
    return 'ff${css.substring(1).toLowerCase()}';
  }

  // ---------------------------------------------------------------- times

  static Team teamFromAccount(Map<String, dynamic> t) {
    final slots = (t['pokemon'] as List? ?? []);
    return Team(
      id: t['id'] as String? ?? '',
      name: t['name'] as String? ?? '',
      color: colorFromAccount(t['color'] as String?),
      score: (t['score'] as num?)?.toDouble(),
      pokemons: [
        for (final id in slots) id is num ? _appPokemon(id.toInt()) : <String, String>{},
      ],
    );
  }

  static Map<String, dynamic> teamToAccount(Team team, [Map<String, dynamic>? previous]) {
    final slots = <int?>[for (final p in team.pokemons) _accountPokemon(p)];
    while (slots.length < 6) {
      slots.add(null);
    }
    return {
      ...?previous, // mantém campos que só o site usa
      'id': team.id,
      'name': team.name,
      'color': colorToAccount(team.color),
      'pokemon': slots.take(6).toList(),
      if (team.score != null) 'score': team.score,
    };
  }

  // ---------------------------------------------------------------- treinos

  static const _evKeys = {
    'hp': 'hpEVs',
    'attack': 'attackEVs',
    'defense': 'defenseEVs',
    'special-attack': 'spAttackEVs',
    'special-defense': 'spDefenseEVs',
    'speed': 'speedEVs',
  };

  static TrainingPokemon trainingFromAccount(Map<String, dynamic> t) {
    final pokemonId = (t['pokemonId'] as num?)?.toInt() ?? 0;
    final evs = Map<String, dynamic>.from(t['evs'] as Map? ?? {});
    int ev(String k) => (evs[k] as num?)?.toInt() ?? 0;
    return TrainingPokemon(
      id: t['id'] as String? ?? '',
      pokemonId: '${speciesOf(pokemonId)}',
      pokemonName: t['name'] as String? ?? '',
      imageUrl: AppImages.pokemonArtwork(pokemonId),
      hpEVs: ev('hp'),
      attackEVs: ev('attack'),
      defenseEVs: ev('defense'),
      spAttackEVs: ev('special-attack'),
      spDefenseEVs: ev('special-defense'),
      speedEVs: ev('speed'),
    );
  }

  static Map<String, dynamic> trainingToAccount(TrainingPokemon p, [Map<String, dynamic>? previous]) {
    final pokemonId = pokemonIdFromImage(p.imageUrl) ?? int.tryParse(p.pokemonId) ?? 0;
    final values = p.toMap();
    final evs = <String, int>{
      for (final e in _evKeys.entries)
        if ((values[e.value] as int) > 0) e.key: values[e.value] as int,
    };
    final samePokemon = previous != null && previous['pokemonId'] == pokemonId;
    return {
      ...?previous,
      'id': p.id,
      'pokemonId': pokemonId,
      'name': p.pokemonName,
      'sprite': 'pokemon/$pokemonId.png',
      if (!samePokemon) 'box': null,
      'evs': evs,
    }..removeWhere((k, v) => k == 'box' && v == null);
  }

  // ---------------------------------------------------------------- migração

  /// Times e treinos salvos pelas versões antigas do app.
  static void _migrateLegacy() {
    final data = UserData.instance;
    final teams = data.takeLegacy('legacyTeams');
    final training = data.takeLegacy('legacyTraining');
    final changes = <String, dynamic>{};
    if (teams != null && data.teams.isEmpty) {
      changes['teams'] = [
        for (final t in teams) teamToAccount(Team.fromMap(Map<String, dynamic>.from(t as Map))),
      ];
    }
    if (training != null && data.training.isEmpty) {
      changes['training'] = [
        for (final t in training) trainingToAccount(TrainingPokemon.fromMap(Map<String, dynamic>.from(t as Map))),
      ];
    }
    if (changes.isNotEmpty) data.update(changes);
  }
}
