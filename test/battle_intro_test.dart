// A abertura da batalha no app: o treinador adversário e as suas costas,
// a Poké Ball lançada e os Pokémon saindo dela (igual ao site).
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocket_dex/i18n/i18n.dart';
import 'package:pocket_dex/screens/turn_battle_screen.dart';
import 'package:pocket_dex/services/trainers.dart';
import 'package:pocket_dex/services/turn_battle.dart';
import 'package:pocket_dex/widgets/pokemon_sprite.dart';
import 'package:pocket_dex/widgets/trainer_sprite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({'pocketdex-language': 'pt'});
  setUpAll(() async {
    await I18n.load();
    await SpriteBoxes.load();
    await Trainers.load();
  });

  test('os treinadores do banco: frente animada e as costas dos jogáveis', () async {
    final list = await Trainers.load();
    expect(list.length, greaterThanOrEqualTo(70));
    expect(Trainers.byId('red')!.back!.frames, 5);
    expect(Trainers.byId('brock')!.frames, greaterThan(1));
    // A foto de perfil guarda a posição: o Brock continua no mesmo lugar.
    expect(Trainers.ofAvatar(Trainers.avatarBase + list.indexWhere((t) => t.id == 'brock'))!.id, 'brock');
    expect(Trainers.ofAvatar(25), isNull);
    for (final t in list) {
      expect(File(t.front).existsSync(), isTrue, reason: t.id);
      if (t.back != null) expect(File(t.backPath).existsSync(), isTrue, reason: t.id);
    }
  });

  testWidgets('abertura: treinadores, Poké Ball e depois o menu', (tester) async {
    tester.view.physicalSize = const Size(1080, 2220);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final battle = await tester.runAsync(() async {
      final me = await TurnBattleSetup.mons([(25, <String, dynamic>{'moves': ['swift', 'protect']})], (row) => '${row['name']}');
      final npc = await TurnBattleSetup.mons([(74, <String, dynamic>{'moves': ['splash']})], (row) => '${row['name']}');
      return TurnBattle(me, npc, Random(3).nextDouble);
    });
    addTearDown(battle!.dispose);
    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('preview'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SingleChildScrollView(
            child: BattleView(
                battle: battle,
                hit: (_, _, _, _, [power, weather = '']) => null,
                typeEff: (_, _) => 1,
                foeName: '',
                foeTrainer: 'brock',
                intro: true,
                onAgain: () {},
                onExit: () {}),
          ),
        ),
      ),
    ));
    await tester.runAsync(() async {
      for (final t in [Trainers.byId('brock')!, Trainers.mine!]) {
        await precacheImage(AssetImage(t.front), tester.element(find.byType(BattleView)));
        if (t.back != null) await precacheImage(AssetImage(t.backPath), tester.element(find.byType(BattleView)));
      }
    });
    Future<void> shot(String name) async {
      if (Platform.environment['BATTLE_SHOTS'] == null) return;
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('preview')));
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${Platform.environment['BATTLE_SHOTS']}/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
      });
    }

    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(TrainerSprite), findsOneWidget);
    expect(find.byType(TrainerBack), findsOneWidget);
    expect(find.text('LUTAR'), findsNothing);
    await shot('1-treinadores');
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('Brock quer batalhar!'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.textContaining('Brock enviou'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    await shot('2-pokebola');
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 300));
    await shot('3-lancando');
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 1500));
    // Os treinadores saíram e o menu abriu.
    expect(find.byType(TrainerSprite), findsNothing);
    expect(find.byType(TrainerBack), findsNothing);
    expect(find.text('LUTAR'), findsOneWidget);
    await shot('4-batalha');
    await tester.pumpWidget(const SizedBox());
  });
}
