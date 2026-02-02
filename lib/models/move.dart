// lib/models/move.dart
import '../utils/string_extensions.dart';

class Move {
  final String name;
  final String type;
  final String category;
  final int? power;
  final int? accuracy;
  final int? pp;
  final String effect;

  Move({
    required this.name,
    required this.type,
    required this.category,
    this.power,
    this.accuracy,
    this.pp,
    required this.effect,
  });

  factory Move.fromApiJson(Map<String, dynamic> json) {
    String effectStr = "No effect description available.";
    var effectEntries = json['effect_entries'] as List;
    if (effectEntries.isNotEmpty) {
      var englishEntry = effectEntries.firstWhere((e) => e['language']['name'] == 'en', orElse: () => null);
      if (englishEntry != null && englishEntry['short_effect'] != null) {
        effectStr = englishEntry['short_effect'].replaceAll('\$effect_chance', json['effect_chance']?.toString() ?? '');
      }
    }
    
    return Move(
      name: (json['name'] as String).capitalise(),
      type: json['type']['name'] as String,
      category: json['damage_class']['name'] as String,
      power: json['power'],
      accuracy: json['accuracy'],
      pp: json['pp'],
      effect: effectStr,
    );
  }
}