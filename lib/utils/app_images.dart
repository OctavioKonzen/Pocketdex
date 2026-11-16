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
    // A arte oficial saiu (o app é só estilo BW): caminhos antigos salvos
    // viram o sprite parado do mesmo Pokémon.
    var path = ref.replaceFirstMapped(RegExp(r'pokemon/other/official-artwork/(shiny/)?([\w-]+)\.(?:png|webp)$'),
        (m) => 'pokemon/${m[1] ?? ''}${m[2]}.png');
    if (path.startsWith(localRoot)) return path;
    if (path.startsWith(_remoteRoot)) {
      path = path.substring(_remoteRoot.length);
    } else if (path.startsWith('http')) {
      return null;
    }
    return '$localRoot$path';
  }

  static String pokemonSprite(Object id, {bool shiny = false}) =>
      '${localRoot}pokemon/${shiny ? 'shiny/' : ''}$id.png';

  /// Antes era a arte oficial; o app agora é só estilo BW (o sprite parado).
  static String pokemonArtwork(Object id, {bool shiny = false}) => pokemonSprite(id, shiny: shiny);

  /// ImageProvider para usar em Image(), CircleAvatar, Ink.image, etc.
  static ImageProvider provider(String ref) {
    final asset = assetPath(ref);
    return asset != null ? AssetImage(asset) : NetworkImage(ref) as ImageProvider;
  }
}
