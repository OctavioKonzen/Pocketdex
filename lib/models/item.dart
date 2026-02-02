// lib/models/item.dart
import '../utils/string_extensions.dart';

class Item {
  final String name;
  final String imageUrl;
  final String category;
  final String effect;

  Item({
    required this.name,
    required this.imageUrl,
    required this.category,
    required this.effect,
  });

  factory Item.fromApiJson(Map<String, dynamic> json) {
    String effectStr = "No effect description available.";
    var effectEntries = json['effect_entries'] as List;
    if (effectEntries.isNotEmpty) {
      var englishEntry = effectEntries.firstWhere((e) => e['language']['name'] == 'en', orElse: () => null);
      if (englishEntry != null && englishEntry['short_effect'] != null) {
        effectStr = englishEntry['short_effect'];
      }
    }
    
    return Item(
      name: (json['name'] as String).replaceAll('-', ' ').capitalise(),
      imageUrl: json['sprites']['default'] ?? '',
      category: (json['category']['name'] as String).replaceAll('-', ' ').capitalise(),
      effect: effectStr,
    );
  }
}