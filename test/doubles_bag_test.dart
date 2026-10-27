import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
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

// A dupla igual à batalha normal: a Bolsa (Potion no Pokémon machucado, gastando o turno de quem usa), o dano
// estimado nos golpes e nos alvos, e FUGIR.
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

  Future<({TurnBattle battle, int Function() finished})> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2220);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final setup = await tester.runAsync(() async {
      final data = await DamageData.load();
      final me = await TurnBattleSetup.mons([
        (143, <String, dynamic>{'moves': ['body-slam', 'rest', 'protect', 'curse']}),
        (9, <String, dynamic>{'moves': ['surf', 'ice-beam', 'protect', 'rain-dance']}),
        (25, <String, dynamic>{'moves': ['thunderbolt', 'protect', 'iron-tail', 'quick-attack']}),
      ], (row) => '${row['name']}');
      final foe = await TurnBattleSetup.mons([
        (19, <String, dynamic>{'moves': ['tackle', 'quick-attack']}),
        (16, <String, dynamic>{'moves': ['tackle', 'gust']}),
        (10, <String, dynamic>{'moves': ['tackle']}),
      ], (row) => '${row['name']}');
      return (data: data, battle: PartyBattle.create({'me': me, 'npc3': foe}, ['me', 'me', 'npc3', 'npc3'], 2, Random(5).nextDouble));
    });
    final battle = setup!.battle;
    addTearDown(battle.dispose);
    var finished = 0;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(fontFamily: 'Roboto'),
      home: Scaffold(
        body: SingleChildScrollView(
          child: BattleView(
            battle: battle,
            hit: TurnBattleSetup.hitter(setup.data),
            typeEff: TurnBattleSetup.typeEffect(setup.data),
            foeName: 'NPC',
            onAgain: () {},
            onExit: () {},
            onFinish: (_) => finished++,
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    return (battle: battle, finished: () => finished);
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    expect(f, findsOneWidget, reason: key);
    await tester.ensureVisible(f);
    await tester.tap(f);
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('dupla: dano estimado, Potion pela Bolsa e FUGIR', (tester) async {
    final (:battle, :finished) = await start(tester);
    // O dano estimado em cada adversário nos golpes e no alvo.
    await tap(tester, 'battle-fight');
    expect(find.byKey(const ValueKey('damage-range-0-0-0')), findsOneWidget);
    // O primeiro usa Curse (sem alvo); o segundo, Ice Beam: no alvo também aparece o dano estimado.
    await tap(tester, 'battle-move-0-3');
    final anyTarget = find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('battle-target-'));
    if (anyTarget.evaluate().isNotEmpty) {
      await tester.tap(anyTarget.first);
      await tester.pump();
    }
    await tap(tester, 'battle-fight');
    await tap(tester, 'battle-move-1-1');
    final target = find.byWidgetPredicate((w) => w.key is ValueKey && RegExp(r'^damage-range-target-').hasMatch('${(w.key as ValueKey).value}'));
    expect(target, findsWidgets);
    final pickTarget = find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('battle-target-'));
    await tester.tap(pickTarget.first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 60));
    expect(tester.takeException(), isNull);
    // Mais turnos (Curse e um golpe) até alguém seu ficar machucado.
    List<int> hurtMons() => [for (final (i, m) in battle.teams[0].indexed) if (m.hp > 0 && m.hp < m.maxHp) i];
    for (var turn = 0; turn < 8 && battle.winner == null && hurtMons().isEmpty; turn++) {
      for (var k = 0; k < 2 && find.byKey(const ValueKey('battle-fight')).evaluate().isNotEmpty; k++) {
        await tap(tester, 'battle-fight');
        final moves = find.byWidgetPredicate((w) => w is InkWell && w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('battle-move-') && w.onTap != null);
        await tester.tap(moves.at(min(3, moves.evaluate().length - 1)));
        await tester.pump();
        if (anyTarget.evaluate().isNotEmpty) {
          await tester.tap(anyTarget.first);
          await tester.pump();
        }
      }
      await tester.pump(const Duration(seconds: 60));
    }
    final hurt = hurtMons();
    expect(hurt, isNotEmpty, reason: 'alguém se machucou');
    expect(find.byKey(const ValueKey('battle-bag')), findsOneWidget);
    {
      final potions = battle.bags[0]['potion'] ?? 0;
      await tap(tester, 'battle-bag');
      expect(find.byKey(const ValueKey('bag')), findsOneWidget);
      await tap(tester, 'bag-item-potion');
      await tap(tester, 'bag-use');
      // Em quem: o machucado; USAR.
      final party = find.byWidgetPredicate((w) => w.key is ValueKey && RegExp('^battle-switch-\\d-${hurt.first}\$').hasMatch('${(w.key as ValueKey).value}'));
      expect(party, findsOneWidget);
      await tester.tap(party);
      await tester.pump();
      final pick = find.byWidgetPredicate((w) => w.key is ValueKey && RegExp(r'^battle-switch-\d-pick$').hasMatch('${(w.key as ValueKey).value}'));
      await tester.tap(pick);
      await tester.pump(const Duration(milliseconds: 300));
      // O outro (se ainda tem escolha) ataca.
      if (find.byKey(const ValueKey('battle-fight')).evaluate().isNotEmpty) {
        await tap(tester, 'battle-fight');
        final move = find.byWidgetPredicate((w) => w is InkWell && w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('battle-move-') && w.onTap != null);
        await tester.tap(move.first);
        await tester.pump(const Duration(milliseconds: 300));
        final target = find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('battle-target-'));
        if (target.evaluate().isNotEmpty) {
          await tester.tap(target.first);
          await tester.pump();
        }
      }
      await tester.pump(const Duration(seconds: 60));
      expect(tester.takeException(), isNull);
      expect(battle.bags[0]['potion'], potions - 1, reason: 'a Potion foi usada');
    }
    // FUGIR: pergunta e termina a batalha.
    if (battle.winner == null) {
      await tap(tester, 'battle-run');
      await tester.tap(find.text('Fugir'));
      await tester.pump(const Duration(seconds: 10));
      expect(battle.winner, isNotNull);
      expect(finished(), 1);
    }
    await tester.pumpWidget(const SizedBox());
  });
}
