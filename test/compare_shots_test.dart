import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocket_dex/i18n/i18n.dart';
import 'package:pocket_dex/screens/turn_battle_screen.dart';
import 'package:pocket_dex/services/app_settings.dart';
import 'package:pocket_dex/services/damage_calc.dart';
import 'package:pocket_dex/services/party_battle.dart';
import 'package:pocket_dex/services/turn_battle.dart';
import 'package:pocket_dex/widgets/pokemon_sprite.dart';

// A batalha 1v1 e a dupla lado a lado, nas mesmas situações (menu, golpes, troca, turno): os prints ficam em
// build/battle-ui-shots/compare-*.png e o teste confere que tudo está no mesmo lugar.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({'pocketdex-language': 'pt'});
  setUpAll(() async {
    await I18n.load();
    await AppSettings.instance.load();
    await SpriteBoxes.load();
    final exe = Platform.resolvedExecutable;
    final root = Platform.environment['FLUTTER_ROOT'] ?? (exe.contains('/bin/cache/') ? exe.substring(0, exe.indexOf('/bin/cache/')) : '');
    final font = File('$root/bin/cache/dart-sdk/bin/resources/devtools/assets/packages/devtools_app_shared/fonts/Roboto/Roboto-Regular.ttf');
    if (font.existsSync()) {
      final loader = FontLoader('Roboto')..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
      await loader.load();
    }
  });

  testWidgets('1v1 e dupla: mesma aparência e tudo no mesmo lugar', (tester) async {
    tester.view.physicalSize = const Size(1080, 2220);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final setup = await tester.runAsync(() async {
      final data = await DamageData.load();
      Future<List<BattleMon>> team(List<int> ids) => TurnBattleSetup.mons([
            for (final id in ids) (id, <String, dynamic>{'moves': id == 6 ? ['flamethrower', 'air-slash', 'dragon-claw', 'protect'] : ['surf', 'ice-beam', 'earthquake', 'protect']}),
          ], (row) => '${row['name']}');
      final single = TurnBattle(await team([6, 9, 25]), await team([94, 18, 65]), Random(5).nextDouble);
      final double = PartyBattle.create({'me': await team([6, 9, 25, 3]), 'npc3': await team([94, 18, 65, 68])}, ['me', 'me', 'npc3', 'npc3'], 2, Random(5).nextDouble);
      return (data: data, battles: [single, double]);
    });
    final dir = Directory('build/battle-ui-shots')..createSync(recursive: true);
    final places = <String, List<Rect>>{};
    for (final (k, battle) in setup!.battles.indexed) {
      final name = k == 0 ? '1v1' : 'dupla';
      await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('shot'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Roboto'),
          home: Scaffold(body: SingleChildScrollView(child: BattleView(key: ValueKey(k), battle: battle, hit: TurnBattleSetup.hitter(setup.data), typeEff: TurnBattleSetup.typeEffect(setup.data), foeName: 'NPC', onAgain: () {}, onExit: () {}))),
        ),
      ));
      for (var i = 0; i < 90 && find.byKey(const ValueKey('battle-fight')).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      Future<void> shot(String state) async {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
        await tester.pump();
        places['$name $state'] = [for (final key in ['battle-text', 'battle-bottom', 'battle-bottom-info', 'battle-bottom-grid', 'battle-bottom-footer']) tester.getRect(find.byKey(ValueKey(key)))];
        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          File('${dir.path}/compare-$name-$state.png').writeAsBytesSync(png!.buffer.asUint8List());
        });
      }

      Future<void> tap(Key key) async {
        await tester.tap(find.byKey(key));
        await tester.pump();
      }

      await shot('1-menu');
      await tester.tap(find.byKey(const ValueKey('battle-fight')));
      await tester.pump();
      await shot('2-golpes');
      await tap(const ValueKey('battle-bottom-footer'));
      await tester.tap(find.text('POKÉMON'));
      await tester.pump();
      await shot('3-troca');
      // Fecha a troca e ataca (na dupla, os dois e o alvo).
      // Toca num Pokémon: as opções nos botões de baixo; depois Voltar.
      await tester.tap(find.byWidgetPredicate((w) => w.key is ValueKey && RegExp(r'^battle-(single-)?switch-(\d-)?1$').hasMatch('${(w.key as ValueKey).value}')));
      await tester.pump();
      await shot('3b-opcoes');
      await tap(const ValueKey('battle-bottom-footer'));
      for (var pos = 0; pos < (k == 0 ? 1 : 2); pos++) {
        await tester.tap(find.byKey(const ValueKey('battle-fight')));
        await tester.pump();
        await tap(ValueKey(k == 0 ? 'battle-single-move-0' : 'battle-move-$pos-0'));
        final target = find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('battle-target-'));
        if (target.evaluate().isNotEmpty) {
          if (pos == 0) await shot('4-alvo');
          await tester.tap(target.first);
          await tester.pump();
        }
      }
      await tester.pump(const Duration(milliseconds: 1800));
      await shot('5-turno');
      await tester.pump(const Duration(seconds: 90));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      battle.dispose();
    }
    // Texto, tela de baixo e cada parte dela no mesmo lugar em todas as situações, na 1v1 e na dupla.
    final first = places.values.first;
    for (final e in places.entries) {
      expect(e.value, first, reason: e.key);
    }
  });
}
