import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
  setUpAll(() async {
    await I18n.load(); await AppSettings.instance.load();
    final exe=Platform.resolvedExecutable;
    final root=Platform.environment['FLUTTER_ROOT'] ?? (exe.contains('/bin/cache/')?exe.substring(0,exe.indexOf('/bin/cache/')):'');
    final font=File('$root/bin/cache/dart-sdk/bin/resources/devtools/assets/packages/devtools_app_shared/fonts/Roboto/Roboto-Regular.ttf');
    if(font.existsSync()) for(final family in ['Roboto','monospace']) {
      final loader=FontLoader(family)..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
      await loader.load();
    }
  });
  test('Mensagens do simulador podem ser exibidas por ambos os jogadores', () async {
    final a=await TurnBattleSetup.mons([(151,<String,dynamic>{'moves':['swift','recover','helping-hand','protect']})],(row)=>'Mew');
    final b=await TurnBattleSetup.mons([(151,<String,dynamic>{'moves':['splash','recover','helping-hand','protect']})],(row)=>'Mew');
    final battle=TurnBattle(a,b,Random(3).nextDouble);
    try {
      final events=[...battle.start(),...battle.playOnlineTurn([{'kind':'move','index':0},{'kind':'move','index':0}],(_,_,_,_,[power,weather=''])=>null)];
      expect(events.where((e)=>e.key=='used'),isNotEmpty);
      for(final e in events.where((e)=>e.t=='text')) {
        expect(TurnBattle.lineOf(e).$1,isNotEmpty);
        for(final side in [0,1]) expect(TurnBattle.lineOf(BattleEvent.viewFor(e,side)).$1,isNotEmpty);
      }
    } finally {battle.dispose();}
  });
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
      await tester.pumpWidget(RepaintBoundary(key:const ValueKey('preview'),child:MaterialApp(theme:ThemeData(fontFamily:'Roboto'),home: Scaffold(body: SingleChildScrollView(child: BattleView(
        battle:battle, hit:(_, _, _, _, [power, weather=''])=>null, typeEff:(_,_)=>1,
        foeName:'NPC', onAgain:(){}, onExit:(){},
      ))))));
      await tester.pump(const Duration(milliseconds:100));
      final boundary=tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('preview')));
      await tester.runAsync(() async {
        final image=await boundary.toImage(pixelRatio:1.5);
        final png=await image.toByteData(format:ui.ImageByteFormat.png);
        final dir=Directory('build/battle-ui-shots')..createSync(recursive:true);
        File('${dir.path}/classic-$count.png').writeAsBytesSync(png!.buffer.asUint8List());
      });
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
