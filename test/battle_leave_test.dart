import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/i18n/i18n.dart';
import 'package:pocket_dex/screens/turn_battle_screen.dart';
import 'package:pocket_dex/services/app_settings.dart';
import 'package:pocket_dex/services/user_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  testWidgets('voltar no meio da batalha pergunta antes de sair', (tester) async {
    await tester.runAsync(() async {
      await I18n.load();
      await UserData.instance.load();
      await AppSettings.instance.load();
    });
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const TurnBattleScreen(mine: [(6, null)], theirs: [(3, null)], foeName: 'Ash'))),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pump(const Duration(milliseconds: 400));
    for (var i = 0; i < 30 && find.byKey(const ValueKey('inspect-me')).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.byKey(const ValueKey('inspect-me')), findsOneWidget);
    // O botão voltar do celular: aparece a pergunta e a batalha continua aberta.
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Sair da batalha?'), findsOneWidget);
    await tester.tap(find.text('Continuar batalhando'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('inspect-me')), findsOneWidget);
    // Confirmando, sai.
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('confirm-leave')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('abrir'), findsOneWidget);
    expect(find.byKey(const ValueKey('inspect-me')), findsNothing);
  });
}
