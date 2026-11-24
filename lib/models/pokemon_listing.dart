// lib/models/pokemon_listing.dart

import '../utils/app_images.dart';

class PokemonListing {
  final String name;
  final String url;
  final String imageUrl;

  PokemonListing({
    required this.name,
    required this.url,
    required this.imageUrl,
  });

  factory PokemonListing.fromJson(Map<String, dynamic> json) {
    String url = json['url'];
    final parts = url.split('/');
    final id = parts[parts.length - 2];
    return PokemonListing(
      name: json['name'],
      url: url,
      imageUrl: artworkUrl(id),
    );
  }
  
  factory PokemonListing.fromDbMap(Map<String, dynamic> map) {
    return PokemonListing(
      name: map['name'],
      url: 'pokemon/${map['id']}/',
      imageUrl: map['artwork_image_url'] ?? map['pixel_image_url'] ?? '',
    );
  }

  String get id {
    final parts = url.split('/');
    return parts[parts.length - 2];
  }
  
  String get pixelImageUrl => AppImages.pokemonSprite(id);

  static String artworkUrl(String id) => AppImages.pokemonArtwork(id);
}