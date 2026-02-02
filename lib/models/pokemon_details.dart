import 'alternate_form.dart';
import 'evolution_chain_entry.dart';

class PokemonDetails {
  final int id;
  final String name;
  final String description;
  final String genus;
  final List<String> eggGroups;
  final int genderRate;
  final int hatchCounter;
  final List<EvolutionChainEntry> evolutionChain;
  final Map<String, Map<String, dynamic>> allMoveDetails;
  final Map<String, Map<String, dynamic>> allTypeDetails;
  final List<AlternateForm> forms;

  PokemonDetails({
    required this.id,
    required this.name,
    required this.description,
    required this.genus,
    required this.eggGroups,
    required this.genderRate,
    required this.hatchCounter,
    required this.evolutionChain,
    required this.allMoveDetails,
    required this.allTypeDetails,
    required this.forms,
  });

  factory PokemonDetails.fromJsons({
    required Map<String, dynamic> speciesJson,
    required Map<String, dynamic> evolutionJson,
    required List<Map<String, dynamic>> varietyJsons,
    required Map<String, Map<String, dynamic>> allMoveDetails,
    required Map<String, Map<String, dynamic>> allTypeDetails,
  }) {
    final baseName = speciesJson['name'] as String;
    
    String descriptionText = "No description available.";
    var flavorTextEntries = speciesJson['flavor_text_entries'] as List;
    var englishFlavorText = flavorTextEntries.firstWhere((entry) => entry['language']['name'] == 'en', orElse: () => null);
    if (englishFlavorText != null) {
      descriptionText = englishFlavorText['flavor_text'].replaceAll('\n', ' ').replaceAll('\f', ' ');
    }
    
    String genusText = "";
    var genera = speciesJson['genera'] as List;
    var englishGenus = genera.firstWhere((entry) => entry['language']['name'] == 'en', orElse: () => null);
    if (englishGenus != null) {
      genusText = englishGenus['genus'].replaceAll(' Pokémon', '');
    }

    List<String> eggGroupsList = (speciesJson['egg_groups'] as List).map((group) => group['name'] as String).toList();
    
    List<EvolutionChainEntry> evolutionChainEntries = [];
    var chain = evolutionJson['chain'];
    void parseChain(Map<String, dynamic> chainNode) {
      if (chainNode['evolves_to'] == null || (chainNode['evolves_to'] as List).isEmpty) { return; }
      for (var evolution in (chainNode['evolves_to'] as List)) {
        String fromName = chainNode['species']['name'];
        String fromId = (chainNode['species']['url'] as String).split('/').where((s) => s.isNotEmpty).last;
        String toName = evolution['species']['name'];
        String toId = (evolution['species']['url'] as String).split('/').where((s) => s.isNotEmpty).last;
        String triggerText = "Unknown";
        if ((evolution['evolution_details'] as List).isNotEmpty) {
          var details = evolution['evolution_details'][0];
          if (details['trigger']['name'] == 'level-up' && details['min_level'] != null) {
            triggerText = "(Level ${details['min_level']})";
          } else if (details['trigger']['name'] == 'use-item' && details['item'] != null) {
            triggerText = "(${details['item']['name'].replaceAll('-', ' ')})";
          } else {
            triggerText = "(${details['trigger']['name'].replaceAll('-', ' ')})";
          }
        }
        evolutionChainEntries.add(EvolutionChainEntry(fromPokemonName: fromName, toPokemonName: toName, fromPokemonId: fromId, toPokemonId: toId, trigger: triggerText));
        parseChain(evolution);
      }
    }
    parseChain(chain);

    List<AlternateForm> allForms = varietyJsons
        .map((varietyJson) => AlternateForm.fromJson(varietyJson, baseName))
        .toList();

    return PokemonDetails(
      id: speciesJson['id'],
      name: baseName,
      description: descriptionText,
      genus: genusText,
      eggGroups: eggGroupsList,
      genderRate: speciesJson['gender_rate'],
      hatchCounter: speciesJson['hatch_counter'] ?? 0, 
      evolutionChain: evolutionChainEntries,
      forms: allForms,
      allMoveDetails: allMoveDetails,
      allTypeDetails: allTypeDetails,
    );
  }
}