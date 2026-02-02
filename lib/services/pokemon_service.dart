// lib/services/pokemon_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/pokemon_listing.dart';
import '../models/pokemon_details.dart';
import '../models/generation.dart';

class PokemonService {
  final String _baseUrl = 'https://pokeapi.co/api/v2';

  static final Map<int, PokemonDetails> _detailsCache = {};

  Future<List<PokemonListing>> fetchPokemonByTypes(List<String> typeNames) async {
    if (typeNames.isEmpty) {
      return [];
    }

    final response1 = await http.get(Uri.parse('$_baseUrl/type/${typeNames[0]}'));
    if (response1.statusCode != 200) {
      throw Exception('Failed to load type ${typeNames[0]}');
    }
    final data1 = json.decode(response1.body);
    final pokemonList1 = (data1['pokemon'] as List)
        .map((p) => p['pokemon'] as Map<String, dynamic>)
        .toList();

    if (typeNames.length > 1) {
      final response2 = await http.get(Uri.parse('$_baseUrl/type/${typeNames[1]}'));
      if (response2.statusCode != 200) {
        throw Exception('Failed to load type ${typeNames[1]}');
      }
      final data2 = json.decode(response2.body);
      final pokemonNameList1 = pokemonList1.map((p) => p['name'] as String).toSet();
      final pokemonList2 = (data2['pokemon'] as List)
          .map((p) => p['pokemon'] as Map<String, dynamic>)
          .toList();
      
      final intersectionList = pokemonList1.where((p) {
        return pokemonNameList1.contains(p['name']) && pokemonList2.any((p2) => p2['name'] == p['name']);
      }).toList();
      
      return intersectionList.map((p) => PokemonListing.fromJson(p)).toList();

    } else {
      return pokemonList1.map((p) => PokemonListing.fromJson(p)).toList();
    }
  }

  Future<T> fetchResourceDetails<T>(String url, T Function(Map<String, dynamic>) fromJson) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final decodedBody = json.decode(response.body);
        if (decodedBody is Map<String, dynamic>) {
            return fromJson(decodedBody);
        } else {
            throw Exception('Invalid JSON format received from $url');
        }
      } else {
        throw Exception('Failed to load resource details from $url');
      }
    } catch (e) {
      throw Exception('Error fetching resource details: $e');
    }
  }

  Future<List<Map<String, String>>> _fetchAllPaginated(String endpoint) async {
    List<Map<String, String>> allResults = [];
    String? nextUrl = '$_baseUrl/$endpoint?limit=200';

    while (nextUrl != null) {
      final response = await http.get(Uri.parse(nextUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = (data['results'] as List)
            .map((item) => {
                  'name': item['name'] as String,
                  'url': item['url'] as String,
                })
            .toList();
        allResults.addAll(results);
        nextUrl = data['next'];
      } else {
        throw Exception('Failed to load paginated list from $endpoint');
      }
    }
    return allResults;
  }

  Future<List<PokemonListing>> fetchAllPokemonList() async {
     final response = await http.get(Uri.parse('$_baseUrl/pokemon?limit=1028'));
     if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['results'] as List)
            .map((p) => PokemonListing.fromJson(p))
            .toList();
     } else {
       throw Exception('Failed to load full Pokémon list');
     }
  }

  Future<List<PokemonListing>> fetchPokedex(Generation generation) async {
    final response = await http.get(Uri.parse('$_baseUrl/generation/${generation.id}'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final speciesList = (data['pokemon_species'] as List);

      speciesList.sort((a, b) {
        final idA = int.parse((a['url'] as String).split('/')[6]);
        final idB = int.parse((b['url'] as String).split('/')[6]);
        return idA.compareTo(idB);
      });

      return speciesList.map((species) {
            final urlParts = (species['url'] as String).split('/');
            final id = urlParts[urlParts.length - 2];
            return PokemonListing(
              name: species['name'],
              url: 'https://pokeapi.co/api/v2/pokemon/$id/',
              imageUrl: 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$id.png'
            );
          }).toList();
    } else {
      throw Exception('Failed to load Pokedex for ${generation.name}');
    }
  }

  Future<PokemonDetails> fetchPokemonDetails(int id) async {
    if (_detailsCache.containsKey(id)) {
      return _detailsCache[id]!;
    }

    final basePokemonResponse = await http.get(Uri.parse('$_baseUrl/pokemon/$id/'));
    if (basePokemonResponse.statusCode != 200) throw Exception('Failed to load base pokemon data for ID $id');
    final basePokemonJson = json.decode(basePokemonResponse.body);
    
    final speciesUrl = basePokemonJson['species']['url'];

    final speciesResponse = await http.get(Uri.parse(speciesUrl));
    if (speciesResponse.statusCode != 200) throw Exception('Failed to load species from $speciesUrl');
    final speciesJson = json.decode(speciesResponse.body);

    final evolutionUrl = speciesJson['evolution_chain']['url'];
    final evolutionResponse = await http.get(Uri.parse(evolutionUrl));
    if (evolutionResponse.statusCode != 200) throw Exception('Failed to load evolution chain');
    final evolutionJson = json.decode(evolutionResponse.body);

    final varietyUrls = (speciesJson['varieties'] as List).map((v) => v['pokemon']['url'] as String).toList();
    final varietyFutures = varietyUrls.map((url) => http.get(Uri.parse(url)));
    final varietyResponses = await Future.wait(varietyFutures);
    
    final List<Map<String, dynamic>> varietyJsons = varietyResponses.map((res) {
      if (res.statusCode == 200) return json.decode(res.body) as Map<String, dynamic>;
      throw Exception('Failed to load a variety: ${res.request?.url}');
    }).toList();
    
    final Set<String> moveUrls = {};
    for (var varietyJson in varietyJsons) {
      for (var move in (varietyJson['moves'] as List)) {
        moveUrls.add(move['move']['url']);
      }
    }
    final moveFutures = moveUrls.map((url) => http.get(Uri.parse(url)));
    final moveResponses = await Future.wait(moveFutures);
    final Map<String, Map<String, dynamic>> allMoveDetails = {
      for (var res in moveResponses)
        if (res.statusCode == 200)
          (json.decode(res.body) as Map<String, dynamic>)['name'] as String: json.decode(res.body) as Map<String, dynamic>
    };

    final Set<String> typeUrls = {};
    for (var varietyJson in varietyJsons) {
      for (var type in (varietyJson['types'] as List)) {
        typeUrls.add(type['type']['url']);
      }
    }
    final typeFutures = typeUrls.map((url) => http.get(Uri.parse(url)));
    final typeResponses = await Future.wait(typeFutures);
    final Map<String, Map<String, dynamic>> allTypeDetails = {
      for (var res in typeResponses)
        if (res.statusCode == 200)
          (json.decode(res.body) as Map<String, dynamic>)['name'] as String: json.decode(res.body) as Map<String, dynamic>
    };

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

     final partnerFutures = eggGroups.map((groupName) => http.get(Uri.parse('$_baseUrl/egg-group/$groupName/')));
     final responses = await Future.wait(partnerFutures);
     
     final Set<String> partnerIds = {};
     for (var res in responses) {
       if (res.statusCode == 200) {
         final data = json.decode(res.body);
         for (var species in data['pokemon_species']) {
            final urlParts = (species['url'] as String).split('/');
            final id = urlParts[urlParts.length - 2];
            if (id != details.id.toString()) {
              partnerIds.add(id);
            }
         }
       }
     }
     
     return partnerIds.map((id) {
        return PokemonListing(
          name: 'pokemon-$id',
          url: '$_baseUrl/pokemon/$id/',
          imageUrl: 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$id.png'
        );
     }).toList();
  }

  Future<List<Map<String, String>>> fetchAllMovesList() => _fetchAllPaginated('move');
  Future<List<Map<String, String>>> fetchAllItemsList() => _fetchAllPaginated('item');
  Future<List<Map<String, String>>> fetchAllAbilitiesList() => _fetchAllPaginated('ability');

  Future<List<PokemonListing>> fetchPokemonWhoLearnMove(String moveName) async {
    final response = await http.get(Uri.parse('$_baseUrl/move/${moveName.toLowerCase().replaceAll(' ', '-')}/'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['learned_by_pokemon'] as List)
          .map((p) => PokemonListing.fromJson(p))
          .toList();
    }
    return [];
  }

  Future<List<PokemonListing>> fetchPokemonWithAbility(String abilityName) async {
    final response = await http.get(Uri.parse('$_baseUrl/ability/${abilityName.toLowerCase().replaceAll(' ', '-')}/'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['pokemon'] as List)
          .map((p) => PokemonListing.fromJson(p['pokemon']))
          .toList();
    }
    return [];
  }
}