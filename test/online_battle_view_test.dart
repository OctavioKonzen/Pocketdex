import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/i18n/i18n.dart';
import 'package:pocket_dex/screens/turn_battle_screen.dart';
import 'package:pocket_dex/services/app_settings.dart';
import 'package:pocket_dex/services/pokemon_service.dart';
import 'package:pocket_dex/services/turn_battle.dart';
import 'package:pocket_dex/services/battle_simulator.dart';
import 'package:pocket_dex/services/party_battle.dart';
import 'package:pocket_dex/widgets/pokemon_sprite.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({'pocketdex-language': 'pt'});
  setUpAll(() async {
    await I18n.load(); await AppSettings.instance.load();
    await PokemonService().fetchPokemonDetails(6);
    await PokemonService().fetchPokemonDetails(9);
  });
  testWidgets('online reutiliza o campo, envia escolha e espera o turno sincronizado', (tester) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    BattleMon mon(int id) => BattleMon(id, 'Mon $id', 50, 100, 80, ['normal'],
      [BattleMove('tackle', 'Tackle', 'normal', 40, 100, 10, 10, 0)]);
    final canonical = TurnBattle([mon(6)], [mon(9)], () => 0.9);
    Map<String, dynamic>? chosen;
    Widget screen({int round = 0, bool locked = false, List<BattleEvent> events = const []}) =>
      ChangeNotifierProvider.value(value: AppSettings.instance,
        child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: BattleView(
          battle: canonical.viewFor(1), foeName: 'Amigo',
          hit: (_, __, ___, ____, [int? power, String weather = '']) => (rolls: [[25]], eff: 1.0),
          typeEff: (_, __) => 1, onAgain: () {}, onExit: () {},
          online: OnlineBattleControl(round: round, events: events, locked: locked,
            message: locked ? 'Aguardando amigo' : 'Escolha sua ação', waitForSwitch: false,
            onAction: (a) => chosen = a, onClose: () {}),
        )))));
    await tester.pumpWidget(screen());
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    expect(find.byWidgetPredicate((w) => w is PokemonSprite && w.id == 9 && w.back), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is PokemonSprite && w.id == 6 && !w.back), findsOneWidget);
    await tester.tap(find.text('LUTAR')); await tester.pump();
    await tester.tap(find.text('Tackle')); await tester.pump();
    expect(chosen, {'kind': 'move', 'index': 0, 'gimmick': 'none'});
    expect(canonical.active(1).hp, 100);
    expect(canonical.active(1).moves.first.pp, 10);
    await tester.pumpWidget(screen(locked: true)); await tester.pump();
    expect(find.text('Aguardando amigo'), findsOneWidget);
    canonical.active(1).hp = 75;
    await tester.pumpWidget(screen(round: 1, events: [const BattleEvent.hp(0, 75)]));
    await tester.pump(); await tester.pump(const Duration(seconds: 1)); await tester.pump();
    expect(find.text('75/100'), findsOneWidget);
    expect(find.text('LUTAR'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final count in [2,3]) {
    testWidgets('campo com $count Pokémon cabe no celular e mostra apenas a posição do jogador', (tester) async {
      tester.view.physicalSize = const Size(320,900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late TurnBattle battle;
      await tester.runAsync(() async {
        await BattleSimulator.load();
        final mons = await TurnBattleSetup.mons([(6, {'moves': ['tackle']}), (9, {'moves': ['tackle']}), (3, {'moves': ['tackle']})], (row) => '${row['name']}');
        final seats = [for (var i=0;i<count;i++) i==0?'alice':'npc$i', for (var i=count;i<count*2;i++) 'npc$i'];
        battle = PartyBattle.create({for (final uid in seats) uid: mons.map((mon)=>mon.fresh()).toList()},seats,count,()=>0.5);
      });
      await tester.pumpWidget(ChangeNotifierProvider.value(value: AppSettings.instance, child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: BattleView(
        battle: battle, hit: (_, __, ___, ____, [int? power, String weather='']) => (rolls:[[25]],eff:1.0), typeEff: (_,__)=>1,
        onAgain:(){},onExit:(){}, online: OnlineBattleControl(uid:'alice',round:0,events:const [],locked:false,message:'Escolha',waitForSwitch:false,onAction:(_){},onClose:(){}),
      ))))));
      await tester.pump();
      expect(find.byType(DropdownButtonFormField<String>),findsOneWidget);
      expect(tester.takeException(),isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      battle.dispose();
    });
  }
  for (final kind in ['mega', 'tera', 'dmax']) {
    testWidgets('botão $kind seleciona, desmarca e envia só com o golpe', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      BattleMon mon(int id) => BattleMon(id, 'Mon $id', 50, 100, 80, ['normal'],
        [BattleMove('tackle', 'Tackle', 'normal', 40, 100, 10, 10, 0)],
        mega: const BattleMega(10035, 'Mega', ['fire'], 100), teraType: 'grass',
        gmax: kind == 'dmax' ? 10196 : null, gimmick: kind);
      final battle = TurnBattle([mon(6)], [mon(9)], () => 0.9);
      Map<String, dynamic>? chosen;
      await tester.pumpWidget(ChangeNotifierProvider.value(value: AppSettings.instance,
        child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: BattleView(
          battle: battle, foeName: 'Amigo',
          hit: (_, __, ___, ____, [int? power, String weather = '']) => (rolls: [[25]], eff: 1.0),
          typeEff: (_, __) => 1, onAgain: () {}, onExit: () {},
          online: OnlineBattleControl(round: 0, events: const [], locked: false,
            message: 'Escolha', waitForSwitch: false, onAction: (a) => chosen = a, onClose: () {}),
        ))))));
      await tester.pump();
      await tester.tap(find.text('LUTAR')); await tester.pump();
      for (final other in ['mega', 'tera', 'dmax', 'z'].where((other) => other != kind)) {
        expect(find.byKey(ValueKey(other)), findsNothing);
      }
      final button = find.byKey(ValueKey(kind));
      await tester.ensureVisible(button);
      await tester.tap(button); await tester.pump();
      expect(chosen, isNull);
      expect(battle.gimmicks[0], isNull);
      await tester.tap(button); await tester.pump();
      await tester.tap(button); await tester.pump();
      final attack = find.text(kind == 'dmax' ? TurnBattle.maxMoves['normal']! : 'Tackle');
      await tester.ensureVisible(attack); await tester.tap(attack); await tester.pump();
      expect(chosen, {'kind': 'move', 'index': 0, 'gimmick': kind});
      expect(battle.gimmicks[0], isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
