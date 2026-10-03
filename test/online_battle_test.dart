import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/turn_battle.dart';
import 'package:pocket_dex/services/online_battle.dart';

BattleMon mon(int id, [int spe = 80]) => BattleMon(id, 'Mon $id', 50, 100, spe, ['normal'], [
  BattleMove('strong', 'strong', 'normal', 25, 100, 10, 10, 0),
  BattleMove('weak', 'weak', 'normal', 5, 100, 10, 10, 0),
]);
TurnBattle battle() => TurnBattle([mon(1), mon(2)], [mon(3, 60), mon(4, 60)], () => 0.9);
HitResult hit(BattleMon att, BattleMon def, String slug, bool crit, [int? power, String weather = '']) =>
    (rolls: [[att.moves.firstWhere((m) => m.slug == slug).power]], eff: 1.0);
Map<String, dynamic> attack(int index) => {'kind': 'move', 'index': index};
void main() {
  test('quatro mecânicas uma vez cada e limites separados por jogador', () {
    BattleMon member(int id, String gimmick) => BattleMon(id, 'Mon', 50, 100, 80, ['normal'],
      [BattleMove('tackle', 'Tackle', 'normal', 40, 100, 10, 10, 0)],
      gimmick: gimmick, teraType: 'grass', zType: 'normal', gmax: 10196,
      mega: const BattleMega(10035, 'Mega', ['fire'], 100));
    final kinds = ['mega', 'dmax', 'tera', 'z'];
    final b = TurnBattle([for (var i = 0; i < 4; i++) member(i + 1, kinds[i])],
      [for (var i = 0; i < 4; i++) member(i + 10, kinds[i])], () => 0.9);
    HitResult tinyHit(BattleMon att, BattleMon def, String slug, bool crit, [int? power, String weather = '']) =>
      (rolls: [[1]], eff: 1.0);
    for (var i = 0; i < kinds.length; i++) {
      if (i > 0) b.playOnlineTurn([{'kind': 'switch', 'index': i}, {'kind': 'switch', 'index': i}], tinyHit);
      expect(b.canGimmick(0, kinds[i], 0), isTrue);
      expect(b.canGimmick(1, kinds[i], 0), isTrue);
      b.playOnlineTurn([{'kind': 'move', 'index': 0, 'gimmick': kinds[i]}, {'kind': 'move', 'index': 0, 'gimmick': 'none'}], tinyHit);
      expect(b.canGimmick(0, kinds[i], 0), isFalse);
      expect(b.canGimmick(1, kinds[i], 0), isTrue);
    }
    expect(b.usedGimmicks[0], kinds.toSet());
    expect(b.usedGimmicks[1], isEmpty);
    expect(b.viewFor(1).usedGimmicks[1], kinds.toSet());
  });

  test('perspectiva preserva HP e status sem restaurar a partida', () {
    final b = battle();
    b.active(1).hp = 42; b.active(1).status = 'brn';
    b.weather = 'rain'; b.winner = 1;
    final view = b.viewFor(1);
    expect(view.active(0).hp, 42); expect(view.active(0).status, 'brn');
    expect(view.weather, 'rain'); expect(view.winner, 0);
    expect(b.active(0).id, 1); expect(b.winner, 1);
    final event = BattleEvent.text('move', [(1, 'Mon')]);
    expect(BattleEvent.viewFor(event, 1).args, [(0, 'Mon')]);
    expect(event.args, [(1, 'Mon')]);
  });
  test('usa a escolha do segundo jogador sem CPU, igual ao site', () {
    final b = battle();
    b.playOnlineTurn([attack(0), attack(1)], hit);
    expect(b.active(0).hp, 95);
    expect(b.active(1).hp, 75);
    expect(b.active(1).moves.map((m) => m.pp), [10, 9]);
  });
  test('desmaio espera o dono trocar sem consumir outro turno', () {
    final b = battle();
    b.active(1).hp = 20;
    b.playOnlineTurn([attack(0), attack(1)], hit);
    expect(b.activeIndex[1], 0);
    expect(b.active(0).hp, 100);
    final turn = b.turn;
    b.playOnlineTurn([{'kind': 'wait', 'index': 0}, {'kind': 'switch', 'index': 1}], hit);
    expect(b.activeIndex[1], 1);
    expect(b.turn, turn);
  });
  test('desmaio simultâneo permite a troca dos dois lados', () {
    final b = battle();
    b.active(0).hp = 0; b.active(1).hp = 0;
    b.playOnlineTurn([{'kind': 'switch', 'index': 1}, {'kind': 'switch', 'index': 1}], hit);
    expect(b.activeIndex, [1, 1]);
  });
  test('recusa golpe sem PP', () {
    final b = battle();
    b.active(0).moves[0].pp = 0;
    expect(() => b.playOnlineTurn([attack(0), attack(0)], hit), throwsStateError);
  });
  test('retoma rodadas completas em ordem', () {
    Map<String, dynamic> a(int r, String uid) => {'round': r, 'uid': uid, ...attack(0)};
    expect(OnlineBattles.pairs([a(1, 'b'), a(0, 'b'), a(0, 'a')], ['a', 'b']), [[a(0, 'a'), a(0, 'b')]]);
  });
}
