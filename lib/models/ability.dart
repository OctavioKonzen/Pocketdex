// lib/models/ability.dart
import '../utils/string_extensions.dart';

class Ability {
  final String name;
  final String description;

  Ability({required this.name, required this.description});

  factory Ability.fromApiJson(Map<String, dynamic> json) {
    String desc = "No description available for this ability.";
    var effectEntries = json['effect_entries'] as List;
    if (effectEntries.isNotEmpty) {
      var englishEntry = effectEntries.firstWhere((e) => e['language']['name'] == 'en', orElse: () => null);
      if (englishEntry != null && englishEntry['short_effect'] != null) {
        desc = englishEntry['short_effect'];
      }
    }
    return Ability(
      name: (json['name'] as String).replaceAll('-', ' ').capitalise(),
      description: desc,
    );
  }
}