import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/screens/official_teams_screen.dart';
import 'package:pocket_dex/services/official_teams.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('times oficiais: separados por jogo, com os dados do jogo (igual ao site)', () async {
    final games = await OfficialTeams.load();
    expect([for (final g in games) g.id],
        ['red-blue', 'yellow', 'gold-silver', 'crystal', 'ruby-sapphire', 'emerald', 'firered-leafgreen', 'platinum', 'black2-white2', 'scarlet-violet']);
    final glimmora = games.last.trainers.firstWhere((t) => t.name == 'Geeta').battles.first.team.last;
    expect(glimmora.tera, 'rock');
    expect(glimmora.evText, 'EVs: 252 HP');
    expect(glimmora.abilityText((s) => s), 'toxic-debris');
    final cynthia = games.firstWhere((g) => g.id == 'platinum').trainers.firstWhere((t) => t.name == 'Cynthia');
    final garchomp = cynthia.battles.first.team.last;
    expect([for (final m in cynthia.battles.first.team) m.level], [58, 58, 60, 60, 58, 62]);
    expect(garchomp.item, 'sitrus-berry');
    expect(garchomp.ivText, 'IVs: 30 em todos');
    expect(garchomp.evText, 'EVs: 0 em todos');
    final onix = games.first.trainers.firstWhere((t) => t.name == 'Brock').battles.first.team[1];
    expect(onix.moves, ['tackle', 'screech', 'bide']);
    expect(onix.ivText, 'DVs: HP 8 · Atk 9 · Def 8 · Spe 8 · Spc 8');
    expect(onix.evText, 'Stat Exp: 0');
    expect([for (final a in OfficialTeams.appearances(games, 'Brock')) a.game.id],
        ['red-blue', 'yellow', 'gold-silver', 'crystal', 'firered-leafgreen']);
    expect([for (final t in games[3].filter('elite')) t.name], ['Will', 'Koga', 'Bruno', 'Karen']);
  });

  testWidgets('tela: escolhe o jogo, abre o personagem e mostra todas as aparições', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(const MaterialApp(home: OfficialTeamsScreen()));
    for (var i = 0; i < 10 && find.text('Brock').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('Brock'), findsWidgets);
    await tester.tap(find.text('Brock').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Todas as aparições:'), findsOneWidget);
    expect(find.text('Crystal · Líder de Ginásio'), findsOneWidget);
    expect(find.text('Tackle · Screech · Bide'), findsOneWidget);
    await tester.tap(find.text('Crystal · Líder de Ginásio'));
    await tester.pump();
    expect(find.text('Líder de Ginásio em Crystal (Johto)'), findsOneWidget);
  });
}
