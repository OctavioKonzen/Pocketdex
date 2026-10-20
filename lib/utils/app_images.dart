// lib/utils/app_images.dart
//
// Todas as imagens (sprites, shiny, artes oficiais e itens) fazem parte do
// banco local em assets/database/sprites/. Este helper converte qualquer
// referência de imagem para o arquivo local, inclusive URLs antigas do
// repositório de sprites que já estejam salvas em times e treinos.

import 'package:flutter/widgets.dart';

class AppImages {
  static const localRoot = 'assets/database/sprites/';
  static const _remoteRoot = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/';

  /// Caminho do asset local para uma referência de sprite
  /// (ex.: "pokemon/25.png" ou a URL completa do repositório de sprites).
  static String? assetPath(String? ref) {
    if (ref == null || ref.isEmpty) return null;
    var path = ref;
    if (path.startsWith(localRoot)) return path;
    if (path.startsWith(_remoteRoot)) {
      path = path.substring(_remoteRoot.length);
    } else if (path.startsWith('http')) {
      return null;
    }
    // As artes oficiais ficam em WebP no banco para ocupar menos espaço.
    if (path.startsWith('pokemon/other/official-artwork/') && path.endsWith('.png')) {
      path = '${path.substring(0, path.length - 4)}.webp';
    }
    return '$localRoot$path';
  }

  static String pokemonSprite(Object id, {bool shiny = false}) =>
      '${localRoot}pokemon/${shiny ? 'shiny/' : ''}$id.png';

  static String pokemonArtwork(Object id, {bool shiny = false}) =>
      '${localRoot}pokemon/other/official-artwork/${shiny ? 'shiny/' : ''}$id.webp';

  /// ImageProvider para usar em Image(), CircleAvatar, Ink.image, etc.
  static ImageProvider provider(String ref) {
    final asset = assetPath(ref);
    return asset != null ? AssetImage(asset) : NetworkImage(ref) as ImageProvider;
  }
}
