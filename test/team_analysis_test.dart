import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/local_database.dart';
import 'package:pocket_dex/utils/team_analysis.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('análise igual à do site (web-site/src/lib/pokemon.test.js)', () async {
    final chart = await LocalDatabase.instance.typeChart();
    // Charizard, Blastoise e Venusaur
    final a = TeamAnalysis.of([
      ['fire', 'flying'],
      ['water'],
      ['grass', 'poison'],
    ], chart)!;
    expect(a.immunities, ['ground']);
    expect(a.rows['electric']!.summary, '2 fracos · 1 resiste');
    expect(a.rows['rock']!.summary, '1 fraco (1 ×4)');
    expect(a.weaknesses, containsAll(['electric', 'rock']));
    expect(a.weaknesses, isNot(contains('ice')));
    expect(a.weaknesses, isNot(contains('ground')));
    expect(a.strengths, contains('grass'));
    expect(TeamAnalysis.of([], chart), isNull);
  });
}
