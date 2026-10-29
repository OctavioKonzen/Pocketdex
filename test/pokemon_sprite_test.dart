// Sprites com o mesmo tamanho visual: o recorte vem de sprite_boxes.json.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/widgets/pokemon_sprite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Bulbasaur (pequeno no sprite) é ampliado para preencher a caixa', (tester) async {
    await tester.runAsync(SpriteBoxes.load);
    expect(SpriteBoxes.of(1), isNotNull);
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: SizedBox.square(dimension: 300, child: PokemonSprite(1, fill: 0.9))),
    ));
    final image = tester.widget<Image>(find.byType(Image));
    // Sprite de 96 px: com o recorte, a imagem fica bem maior que a caixa.
    expect(image.width, greaterThan(500));
    expect(tester.getSize(find.byType(Image)).width, greaterThan(500));
  });
}
