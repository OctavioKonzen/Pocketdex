import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/i18n/i18n.dart';
import 'package:pocket_dex/providers/favorites_provider.dart';
import 'package:pocket_dex/providers/theme_provider.dart';
import 'package:pocket_dex/screens/pokemon_detail_screen.dart';
import 'package:pocket_dex/services/app_settings.dart';
import 'package:pocket_dex/services/auth_service.dart';
import 'package:pocket_dex/services/user_data.dart';
import 'package:pocket_dex/widgets/pokemon_display.dart';
import 'package:pocket_dex/widgets/pokemon_sprite.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({'pocketdex-language': 'pt'});
  setUpAll(() async {
    await I18n.load();
    await UserData.instance.load();
    await AppSettings.instance.load();
  });

  for (final id in [10034, 10301, 10181]) {
    testWidgets('abre diretamente a forma $id e mantém seu sprite', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: AuthService.instance),
          ChangeNotifierProvider.value(value: AppSettings.instance),
          ChangeNotifierProvider(create: (_) => FavoritesProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: MaterialApp(home: PokemonDetailScreen(initialPokemonId: id)),
      ));
      // A tela anima continuamente; pumpAndSettle não termina.
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(PokemonDisplay), findsOneWidget);
      expect(tester.widget<PokemonDisplay>(find.byType(PokemonDisplay)).form.id, id);
      expect(find.byWidgetPredicate((w) => w is PokemonSprite && w.id == id), findsWidgets);
      expect(find.text('Carregando Pokémon...'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
