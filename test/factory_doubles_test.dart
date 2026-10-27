import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocket_dex/i18n/i18n.dart';
import 'package:pocket_dex/screens/factory_panels.dart';
import 'package:pocket_dex/screens/turn_battle_screen.dart';
import 'package:pocket_dex/services/app_settings.dart';
import 'package:pocket_dex/services/damage_calc.dart';
import 'package:pocket_dex/services/factory_run.dart';
import 'package:pocket_dex/services/turn_battle.dart';
import 'package:pocket_dex/widgets/pokemon_sprite.dart';

// A batalha em dupla da Battle Factory (como no jogo): escolher o golpe de cada um dos dois.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({'pocketdex-language': 'pt'});
  setUpAll(() async {
    await I18n.load();
    await AppSettings.instance.load();
    await SpriteBoxes.load();
  });

  for (final (seedBase, floor) in Platform.environment['MANY'] != null
      ? [for (var k = 0; k < 24; k++) (100 + k * 13, 15 + (k * 7) % 80)]
      : [(7, 20), (11, 35), (23, 50), (31, 70), (41, 90), (53, 25), (61, 45), (71, 60)]) {
  testWidgets('dupla da Factory: escolhe o golpe dos dois e o turno acontece (semente $seedBase, andar $floor)', (tester) async {
    tester.view.physicalSize = const Size(1080, 2220);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final setup = await tester.runAsync(() async {
      final data = FactoryData.parse(jsonDecode(File('assets/database/factory.json').readAsStringSync()) as Map<String, dynamic>);
      var seed = seedBase;
      double rand() {
        final (v, s) = FactoryRun.nextRandom(seed);
        seed = s;
        return v;
      }
      final run = FactoryRun.startRun(FactoryRun.empty(), data, 1, 42)!;
      final team = [for (var k = 0; k < 4; k++) FactoryRun.newMon(1 + (rand() * 1000).floor(), (floor * 1.2).round(), rand)];
      final a = FactoryRun.encounterFor(data, floor, rand, null, false, {'kind': 'trainer', 'biome': 'grass'});
      final b = FactoryRun.encounterFor(data, floor, rand, null, false, {'kind': 'trainer', 'biome': 'grass'});
      final r = {...run, 'team': team, 'floor': floor, 'encounter': {...a, 'kind': 'trainer', 'foes': [...(a['foes'] as List).take(FactoryRun.pairTeam), ...(b['foes'] as List).take(FactoryRun.pairTeam)], 'pair': true}};
      expect(FactoryRun.isDoubleBattle(r), isTrue);
      final (battle, _) = await factoryBattle(r);
      return (battle: battle, data: await DamageData.load());
    });
    final battle = setup!.battle;
    addTearDown(battle.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(children: [
          BattleView(
            battle: battle,
            hit: TurnBattleSetup.hitter(setup.data),
            typeEff: TurnBattleSetup.typeEffect(setup.data),
            foeName: 'NPC',
            intro: true,
            keepMine: true,
            onAgain: () {},
            onExit: () {},
            onFinish: (_) {},
          ),
        ]),
      ),
    ));
    await tester.pump(const Duration(seconds: 3));
    String text() => tester.widgetList<Text>(find.descendant(of: find.byKey(const ValueKey('battle-text')), matching: find.byType(Text))).map((t) => t.data).join();
    final slotKey = RegExp(r'^battle-switch-\d-\d+$');
    Finder byPrefix(String p) => find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith(p));
    var stuck = 0, sameTurn = 0, lastTurn = -1;
    for (var step = 0; step < 200 && battle.winner == null; step++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byKey(const ValueKey('battle-fight')).evaluate().isNotEmpty) {
        stuck = 0;
        final before = text();
        await tester.tap(find.byKey(const ValueKey('battle-fight')));
        await tester.pump(const Duration(milliseconds: 300));
        final moves = find.byWidgetPredicate((w) => w is InkWell && w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('battle-move-') && w.onTap != null);
        if (moves.evaluate().isEmpty) {
          // ignore: avoid_print
          print('SEM GOLPES: $before');
          fail('sem golpes para tocar');
        }
        await tester.tap(moves.first);
        await tester.pump(const Duration(milliseconds: 300));
        if (byPrefix('battle-target-').evaluate().isNotEmpty) {
          await tester.tap(byPrefix('battle-target-').first);
          await tester.pump(const Duration(milliseconds: 300));
        }
        if (battle.turn == lastTurn && before.contains('(1/2)')) {
          if (++sameTurn > 3) fail('a escolha volta sempre para o primeiro: "${text()}"');
        } else {
          sameTurn = 0;
        }
        if (before.contains('(1/2)')) lastTurn = battle.turn;
        // As falas do turno, uma por uma.
        if (find.byKey(const ValueKey('battle-fight')).evaluate().isEmpty) {
          final seen = <String>[];
          for (var k = 0; k < 200 && find.byKey(const ValueKey('battle-fight')).evaluate().isEmpty && battle.winner == null; k++) {
            await tester.pump(const Duration(milliseconds: 250));
            final t = text();
            if (seen.isEmpty || seen.last != t) seen.add(t);
          }
        }
      } else if (find.byWidgetPredicate((w) => w.key is ValueKey && slotKey.hasMatch('${(w.key as ValueKey).value}')).evaluate().isNotEmpty) {
        stuck = 0;
        final keys = [for (final e in find.byWidgetPredicate((w) => w.key is ValueKey && slotKey.hasMatch('${(w.key as ValueKey).value}')).evaluate()) (e.widget.key as ValueKey).value as String];
        for (final key in keys) {
          if (find.byKey(ValueKey(key)).evaluate().isEmpty) break;
          await tester.tap(find.byKey(ValueKey(key)), warnIfMissed: false);
          await tester.pump();
          final pick = find.byKey(ValueKey('${key.substring(0, key.lastIndexOf('-'))}-pick'));
          if (pick.evaluate().isNotEmpty) {
            await tester.tap(pick, warnIfMissed: false);
            await tester.pump();
          }
        }
      } else {
        await tester.pump(const Duration(seconds: 5));
        if (++stuck > 12) {
          // ignore: avoid_print
          print('TRAVOU: "${text()}" turn=${battle.turn} sides=${battle.simulatorState!['sides']}');
          fail('travou');
        }
      }
    }
    expect(tester.takeException(), isNull);
    expect(battle.winner, isNotNull, reason: 'a batalha chegou ao fim (sem travar)');
    await tester.pumpWidget(const SizedBox());
  });
  }
}
