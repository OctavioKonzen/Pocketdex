// lib/services/pokemon_service.dart
import '../models/pokemon_listing.dart';
import '../models/pokemon_details.dart';
import '../models/generation.dart';
import 'local_database.dart';

class PokemonService {
  final LocalDatabase _db = LocalDatabase.instance;

  static final Map<int, PokemonDetails> _detailsCache = {};

  Future<List<PokemonListing>> fetchPokemonByTypes(List<String> typeNames) async {
    if (typeNames.isEmpty) {
      return [];
    }

    final data1 = await _db.typeJson(typeNames[0]);
    if (data1 == null) {
      throw Exception('Failed to load type ${typeNames[0]}');
    }
    final pokemonList1 = (data1['pokemon'] as List)
        .map((p) => p['pokemon'] as Map<String, dynamic>)
        .toList();

    if (typeNames.length > 1) {
      final data2 = await _db.typeJson(typeNames[1]);
      if (data2 == null) {
        throw Exception('Failed to load type ${typeNames[1]}');
      }
      final pokemonNameList2 = (data2['pokemon'] as List)
          .map((p) => p['pokemon']['name'] as String)
          .toSet();

      return pokemonList1
          .where((p) => pokemonNameList2.contains(p['name']))
          .map((p) => PokemonListing.fromJson(p))
          .toList();
    } else {
      return pokemonList1.map((p) => PokemonListing.fromJson(p)).toList();
    }
  }

  /// [url] é uma referência local no formato "recurso/idOuNome/" (ex.: "move/1/").
  Future<T> fetchResourceDetails<T>(String url, T Function(Map<String, dynamic>) fromJson) async {
    final data = await _db.resourceJson(url);
    if (data == null) {
      throw Exception('Resource not found: $url');
    }
    return fromJson(data);
  }

  /// Dados de um Pokémon (por id ou nome) no formato da PokeAPI.
  Future<Map<String, dynamic>> fetchPokemonJson(String idOrName) async {
    final data = await _db.pokemonJson(idOrName);
    if (data == null) {
      throw Exception('Pokémon not found: $idOrName');
    }
    return data;
  }

  /// Igual a [fetchPokemonJson], mas a partir da url de um [PokemonListing].
  Future<Map<String, dynamic>> fetchPokemonJsonByUrl(String url) async {
    final data = await _db.resourceJson(url);
    if (data == null) {
      throw Exception('Pokémon not found: $url');
    }
    return data;
  }

  Future<List<PokemonListing>> fetchAllPokemonList() async {
    final pokemon = await _db.defaultPokemon();
    return pokemon
        .map((p) => PokemonListing.fromJson({'name': p['name'], 'url': 'pokemon/${p['id']}/'}))
        .toList();
  }

  Future<List<PokemonListing>> fetchPokedex(Generation generation) async {
    final speciesIds = await _db.speciesIdsOfGeneration(generation.id);
    if (speciesIds.isEmpty) {
      throw Exception('Failed to load Pokedex for ${generation.name}');
    }

    return [
      for (final id in speciesIds)
        PokemonListing(
          name: await _db.speciesName(id),
          url: 'pokemon/$id/',
          imageUrl: PokemonListing.artworkUrl('$id'),
        ),
    ];
  }

  Future<PokemonDetails> fetchPokemonDetails(int id) async {
    if (_detailsCache.containsKey(id)) {
      return _detailsCache[id]!;
    }

    final basePokemonJson = await _db.pokemonJson('$id');
    if (basePokemonJson == null) throw Exception('Failed to load base pokemon data for ID $id');

    final speciesUrl = basePokemonJson['species']['url'] as String;
    final speciesJson = await _db.resourceJson(speciesUrl);
    if (speciesJson == null) throw Exception('Failed to load species from $speciesUrl');

    final evolutionUrl = speciesJson['evolution_chain']?['url'] as String?;
    final evolutionJson = evolutionUrl == null ? null : await _db.resourceJson(evolutionUrl);
    if (evolutionJson == null) throw Exception('Failed to load evolution chain');

    final List<Map<String, dynamic>> varietyJsons = [];
    for (final variety in speciesJson['varieties'] as List) {
      final varietyJson = await _db.resourceJson(variety['pokemon']['url'] as String);
      if (varietyJson == null) throw Exception('Failed to load a variety: ${variety['pokemon']['url']}');
      varietyJsons.add(varietyJson);
    }

    final Set<String> moveNames = {
      for (final varietyJson in varietyJsons)
        for (final move in varietyJson['moves'] as List) move['move']['name'] as String,
    };
    final Map<String, Map<String, dynamic>> allMoveDetails = {};
    for (final name in moveNames) {
      final moveJson = await _db.moveJson(name);
      if (moveJson != null) allMoveDetails[name] = moveJson;
    }

    final Set<String> typeNames = {
      for (final varietyJson in varietyJsons)
        for (final type in varietyJson['types'] as List) type['type']['name'] as String,
    };
    final Map<String, Map<String, dynamic>> allTypeDetails = {};
    for (final name in typeNames) {
      final typeJson = await _db.typeJson(name);
      if (typeJson != null) allTypeDetails[name] = typeJson;
    }

    final details = PokemonDetails.fromJsons(
      speciesJson: speciesJson,
      evolutionJson: evolutionJson,
      varietyJsons: varietyJsons,
      allMoveDetails: allMoveDetails,
      allTypeDetails: allTypeDetails,
    );

    _detailsCache[id] = details;

    return details;
  }

  Future<List<PokemonListing>> fetchCompatiblePartners(PokemonDetails details) async {
    final eggGroups = details.eggGroups;
    if (eggGroups.isEmpty || eggGroups.contains('no-eggs')) return [];

    final Set<int> partnerIds = {};
    for (final groupName in eggGroups) {
      for (final id in await _db.speciesIdsOfEggGroup(groupName)) {
        if (id != details.id) partnerIds.add(id);
      }
    }

    return [
      for (final id in partnerIds)
        PokemonListing(
          name: await _db.speciesName(id),
          url: 'pokemon/$id/',
          imageUrl: PokemonListing.artworkUrl('$id'),
        ),
    ];
  }

  Future<List<Map<String, String>>> fetchAllMovesList() => _db.resourceList('moves', 'move');
  Future<List<Map<String, String>>> fetchAllItemsList() => _db.resourceList('items', 'item');
  Future<List<Map<String, String>>> fetchAllAbilitiesList() => _db.resourceList('abilities', 'ability');

  Future<List<PokemonListing>> fetchPokemonWhoLearnMove(String moveName) async {
    final data = await _db.moveJson(moveName.toLowerCase().replaceAll(' ', '-'));
    if (data == null) return [];
    return (data['learned_by_pokemon'] as List)
        .map((p) => PokemonListing.fromJson(p))
        .toList();
  }

  Future<List<PokemonListing>> fetchPokemonWithAbility(String abilityName) async {
    final data = await _db.abilityJson(abilityName.toLowerCase().replaceAll(' ', '-'));
    if (data == null) return [];
    return (data['pokemon'] as List)
        .map((p) => PokemonListing.fromJson(p['pokemon']))
        .toList();
  }
}
