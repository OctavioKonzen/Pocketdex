import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocket_dex/i18n/i18n.dart';
import 'package:pocket_dex/screens/turn_battle_screen.dart';
import 'package:pocket_dex/services/app_settings.dart';
import 'package:pocket_dex/services/party_battle.dart';
import 'package:pocket_dex/services/turn_battle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({'pocketdex-language':'pt'});
  setUpAll(() async {await I18n.load(); await AppSettings.instance.load();});
  for (final count in [2,3]) {
    testWidgets('Golpes visíveis e utilizáveis nas $count posições após atacar', (tester) async {
      tester.view.physicalSize = const Size(1080,2220);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final battle = await tester.runAsync(() async {
        final me=await TurnBattleSetup.mons([for(var i=0;i<6;i++) (151, <String,dynamic>{'moves':['swift','recover','helping-hand','protect']})], (row)=>'Mew');
        final npc=await TurnBattleSetup.mons([for(var i=0;i<6;i++) (151, <String,dynamic>{'moves':['splash','recover','helping-hand','protect']})], (row)=>'Mew');
        return PartyBattle.create({'me':me,'npc3':npc}, [...List.filled(count,'me'),...List.filled(count,'npc3')],count,Random(42).nextDouble);
      });
      addTearDown(battle!.dispose);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: BattleView(
        battle:battle, hit:(_, _, _, _, [power, weather=''])=>null, typeEff:(_,_)=>1,
        foeName:'NPC', onAgain:(){}, onExit:(){},
      )))));
      await tester.pump(const Duration(milliseconds:100));
      for(var turn=0;turn<3;turn++) {
        for(var position=0;position<count;position++) {
          for(var move=0;move<4;move++) expect(find.byKey(ValueKey('battle-move-$position-$move')), findsOneWidget);
          final button=find.byKey(ValueKey('battle-move-$position-0'));
          expect(tester.widget<InkWell>(button).onTap,isNotNull);
          await tester.ensureVisible(button); await tester.tap(button); await tester.pump();
        }
        final confirm=find.widgetWithText(FilledButton,'Confirmar ações');
        expect(tester.widget<FilledButton>(confirm).onPressed,isNotNull);
        final previous=battle.turn;
        await tester.ensureVisible(confirm); await tester.tap(confirm); await tester.pump();
        expect(battle.turn,greaterThan(previous));
        expect(tester.takeException(),isNull);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
