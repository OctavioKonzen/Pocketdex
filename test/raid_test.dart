import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/raid.dart';

void main() {
  test('raid da semana: o chefe e a mecânica são os mesmos para todo mundo na semana (igual ao site)', () {
    expect(Raid.bossOf('2026-11-02'), Raid.bossOf('2026-11-02'));
    expect(Raid.bosses, contains(Raid.bossOf('2026-11-02')));
    expect(['dmax', 'tera'], contains(Raid.gimmickOf('2026-11-02')));
    // Valores fixos: o site tem que dar o mesmo.
    expect(Raid.bossOf('2026-11-02'), Raid.bosses[_expectedIndex]);
    // O mesmo número do site (raid.test.js): Salamence nesta semana.
    expect(Raid.bossOf('2026-11-02'), 373);
    final (id, set) = Raid.member('2026-11-02');
    expect(id, Raid.bossOf('2026-11-02'));
    expect(set!['level'], 75);
  });

  test('raid: 3 lutas por dia e o prêmio uma vez quando o grupo derruba o chefe', () {
    var f = <String, dynamic>{'coins': 0};
    expect(Raid.triesLeft(f, 'w', 'd1'), 3);
    for (var i = 0; i < 3; i++) {
      f = Raid.afterFight(f, 40, 'w', 'd1');
    }
    expect(Raid.triesLeft(f, 'w', 'd1'), 0);
    expect(Raid.triesLeft(f, 'w', 'd2'), 3);
    expect((f['raid'] as Map)['mine'], 120);
    expect(Raid.claim(f, Raid.pool - 1, 'w')['coins'], 0);
    f = Raid.claim(f, Raid.pool, 'w');
    expect(f['coins'], Raid.coins);
    expect(Raid.claim(f, Raid.pool, 'w')['coins'], Raid.coins);
    // Semana nova: tudo de novo.
    expect(Raid.claimed(f, 'w2'), isFalse);
    expect(Raid.triesLeft(f, 'w2', 'd1'), 3);
  });
}

// O índice do chefe da semana 2026-11-02 (FNV-1a de 32 bits % 18), conferido no site.
final _expectedIndex = () {
  var h = 2166136261;
  for (final c in '2026-11-02'.codeUnits) {
    h = ((h ^ c) * 16777619) & 0xFFFFFFFF;
  }
  return h % Raid.bosses.length;
}();
