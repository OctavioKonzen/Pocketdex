import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/animated_sprites.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Mega Zygarde usa os GIFs existentes normal e shiny', () async {
    await AnimatedSprites.instance.load();
    final normal = AnimatedSprites.instance.source(10301);
    final shiny = AnimatedSprites.instance.source(10301, shiny: true);
    expect(normal, isNotNull);
    expect(shiny, isNotNull);
    expect(normal!.url, contains('/sprites/animated/front/10301.gif'));
    expect(shiny!.url, contains('/sprites/animated/shiny/10301.gif'));
    expect(normal.width, greaterThan(0));
    expect(normal.height, greaterThan(0));
  });
}
