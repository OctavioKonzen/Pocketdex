import 'turn_battle.dart';

class PartyBattle {
  static String modeOf(int count) => ['singles', 'doubles', 'triples'][count - 1];
  static int countOf(Map room) => room['mode'] == 'triples' ? 3 : room['mode'] == 'doubles' ? 2 : 1;
  static bool isNpc(String controller) => RegExp(r'^npc[0-5]$').hasMatch(controller);
  static List<String> seatsOf(Map room) => List<String>.from((room['seats'] ?? room['players']) as List);
  static int sideOf(Map room, String uid) => seatsOf(room).indexOf(uid) ~/ countOf(room);

  static List<BattleMon> assemble(List<String> controllers, Map<String, List<BattleMon>> rosters) {
    final unique = controllers.toSet().toList(), quota = 6 ~/ controllers.toSet().length;
    final pools = {for (final uid in unique) uid: rosters[uid]!.take(quota).toList()};
    final active = <BattleMon>[];
    for (final uid in controllers) {
      if (pools[uid]!.isEmpty) throw StateError('Cada participante precisa de Pokémon suficientes para as posições que controla.');
      active.add(pools[uid]!.removeAt(0));
    }
    return [...active, for (final uid in unique) ...pools[uid]!];
  }
  static TurnBattle create(Map<String, List<BattleMon>> rosters, List<String> seats, int count, double Function() random) {
    final controllers = [seats.take(count).toList(), seats.skip(count).take(count).toList()];
    return TurnBattle(assemble(controllers[0], rosters), assemble(controllers[1], rosters), random, mode: modeOf(count), controllers: controllers);
  }
  static List<BattleEvent> play(TurnBattle battle, List<Map<String, dynamic>> submissions) {
    final count = battle.controllers![0].length;
    final all = <List<Map<String, dynamic>>>[];
    for (var side = 0; side < 2; side++) {
      final choices = [for (final s in submissions) for (final dynamic c in s['choices'] as List) if ((c['seat'] as int) ~/ count == side) Map<String, dynamic>.from(c as Map)];
      final actions = battle.recommend(side, {
        'controlledSlots': [for (var slot = 0; slot < count; slot++) if (isNpc(battle.controllers![side][slot])) slot],
        'reservedSwitches': [for (final c in choices) if (c['kind'] == 'switch') c['index']],
        'reservedMechanics': [for (final c in choices) if (c['gimmick'] != null && c['gimmick'] != '' && c['gimmick'] != 'none') c['gimmick']],
      });
      for (final choice in choices) { actions[(choice['seat'] as int) % count] = choice; }
      all.add(actions);
    }
    return battle.playGroupTurn(all);
  }
}
