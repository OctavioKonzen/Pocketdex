import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math';
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

// Uma batalha dupla inteira, jogada pela tela como uma pessoa joga: LUTAR, golpe, alvo, o turno
// tocado ação por ação, desmaios e substituições, até alguém vencer.
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

  testWidgets('batalha dupla do começo ao fim pela tela, sem travar nem erro', (tester) async {
    tester.view.physicalSize = const Size(1080, 2220);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final setup = await tester.runAsync(() async {
      final data = await DamageData.load();
      final me = await TurnBattleSetup.mons([
        (6, <String, dynamic>{'moves': ['flamethrower', 'air-slash', 'dragon-claw', 'protect']}),
        (9, <String, dynamic>{'moves': ['surf', 'ice-beam', 'earthquake', 'protect']}),
        (25, <String, dynamic>{'moves': ['thunderbolt', 'quick-attack', 'iron-tail', 'protect']}),
        (3, <String, dynamic>{'moves': ['giga-drain', 'sludge-bomb', 'earthquake', 'protect']}),
      ], (row) => '${row['name']}');
      final foe = await TurnBattleSetup.mons([
        (18, <String, dynamic>{'moves': ['brave-bird', 'quick-attack', 'u-turn', 'roost']}),
        (94, <String, dynamic>{'moves': ['shadow-ball', 'sludge-bomb', 'thunderbolt', 'protect']}),
        (68, <String, dynamic>{'moves': ['close-combat', 'stone-edge', 'bullet-punch', 'protect']}),
        (65, <String, dynamic>{'moves': ['psychic', 'shadow-ball', 'focus-blast', 'protect']}),
      ], (row) => '${row['name']}');
      return (data: data, battle: PartyBattle.create({'me': me, 'npc3': foe}, ['me', 'me', 'npc3', 'npc3'], 2, Random(11).nextDouble));
    });
    final battle = setup!.battle;
    addTearDown(battle.dispose);
    var finished = 0;
    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('shot'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
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
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    final dir = Directory('build/battle-ui-shots/doubles-run')..createSync(recursive: true);
    Future<void> shot(String name) async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
      });
    }

    // Os Pokémon na tela do time (a mesma da batalha normal): battle-switch-<posição>-<índice>.
    final slotKey = RegExp(r'^battle-switch-\d-\d+$');
    Finder partySlots() => find.byWidgetPredicate((w) => w.key is ValueKey && slotKey.hasMatch('${(w.key as ValueKey).value}'));
    Finder byPrefix(String prefix) => find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith(prefix));
    Future<void> tap(Finder f) async {
      await tester.ensureVisible(f.first);
      await tester.tap(f.first);
      await tester.pump();
    }

    final log = <String>[];
    var turns = 0, switches = 0, targets = 0, picks = 0;
    bool visible(String key) => find.byKey(ValueKey(key)).evaluate().isNotEmpty;
    String boxText() => tester.widgetList<Text>(find.descendant(of: find.byKey(const ValueKey('battle-text')), matching: find.byType(Text))).map((t) => t.data).join();
    // Depois de cada escolha: se o turno começou (o menu some), mostra a ordem e cada ação até acabar.
    Future<void> afterChoice() async {
      await tester.pump(const Duration(milliseconds: 50));
      if (visible('battle-fight') || partySlots().evaluate().isNotEmpty) return;
      turns++;
      if (turns == 1) await shot('3-ordem');
      log.add('T$turns: ${boxText()}');
      await tester.pump(const Duration(milliseconds: 2500));
      if (turns == 1) await shot('4-acao');
      if (turns == 3) await shot('4b-acao-turno3');
      await tester.pump(const Duration(seconds: 90));
      expect(tester.takeException(), isNull);
      // Quem entrou aparece no campo (a imagem carrega de verdade antes do print).
      if (turns == 3) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 800)));
        await tester.pump();
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
        await tester.pump();
        await shot('7-depois-da-troca');
        // ignore: avoid_print
        print('SPRITES: ${tester.widgetList<PokemonSprite>(find.byType(PokemonSprite)).map((w) => '${w.id}${w.back ? 'b' : ''}').join(',')}');
      }
    }

    for (var step = 0; step < 400 && battle.winner == null; step++) {
      if (visible('battle-fight')) {
        await tap(find.byKey(const ValueKey('battle-fight')));
        if (picks == 0) await shot('1-golpes');
        // Um golpe que dá para usar (alterna entre os três primeiros).
        final moves = byPrefix('battle-move-').evaluate().where((e) => (e.widget as InkWell).onTap != null).toList();
        expect(moves, isNotEmpty);
        await tap(find.byWidget(moves[picks++ % min(3, moves.length)].widget));
        if (byPrefix('battle-target-').evaluate().isNotEmpty) {
          targets++;
          if (targets == 1) await shot('2-alvo');
          await tap(byPrefix('battle-target-'));
        }
      } else if (partySlots().evaluate().isNotEmpty) {
        // Desmaiou: quem entra no lugar (toca nos do time até um que pode entrar).
        switches++;
        if (switches == 1) await shot('6-substituicao');
        final keys = [for (final e in partySlots().evaluate()) (e.widget.key as ValueKey).value as String];
        // Toca no Pokémon (as opções aparecem nos botões de baixo) e em TROCAR; até achar um que pode entrar.
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
        await shot('erro');
        fail('sem menu nem troca no turno ${battle.turn}: ${boxText()}');
      }
      await afterChoice();
    }
    await shot('5-fim');
    // ignore: avoid_print
    print('turnos: $turns, substituições: $switches, alvos: $targets, vencedor: ${battle.winner}\n${log.join('\n')}');
    expect(battle.winner, isNotNull);
    expect(finished, 1);
    expect(switches, greaterThan(0), reason: 'alguém desmaiou e entrou outro');
    await tester.pumpWidget(const SizedBox());
  });
}
