import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/utils/app_images.dart';

void main() {
  test('caminho antigo da arte oficial vira o sprite BW', () {
    expect(AppImages.pokemonArtwork(6), AppImages.pokemonSprite(6));
    expect(AppImages.assetPath('pokemon/other/official-artwork/6.png'), '${AppImages.localRoot}pokemon/6.png');
    expect(AppImages.assetPath('${AppImages.localRoot}pokemon/other/official-artwork/shiny/6.webp'), '${AppImages.localRoot}pokemon/shiny/6.png');
  });
}
