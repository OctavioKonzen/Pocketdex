import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/factory_daily.dart';
import 'package:pocket_dex/services/league.dart';
import 'package:pocket_dex/services/missions_reminder.dart';

void main() {
  test('lembrete das missões às 20h de Brasília (23h UTC) nos próximos dias', () {
    final days = MissionsReminder.upcoming(DateTime.utc(2026, 9, 26, 15), doneToday: false);
    expect(days.first, DateTime.utc(2026, 9, 26, 23));
    expect(days.length, 7);
  });

  test('sem lembrete hoje se já cumpriu as missões ou já passou das 20h', () {
    expect(MissionsReminder.upcoming(DateTime.utc(2026, 9, 26, 15), doneToday: true).first, DateTime.utc(2026, 9, 27, 23));
    expect(MissionsReminder.upcoming(DateTime.utc(2026, 9, 26, 23, 30), doneToday: false).first, DateTime.utc(2026, 9, 27, 23));
    // 22h de 26/09 em Brasília = 01h de 27/09 UTC: cumpriu as do dia 26, o de 27 continua.
    expect(MissionsReminder.upcoming(DateTime.utc(2026, 9, 27, 1), doneToday: true).first, DateTime.utc(2026, 9, 27, 23));
  });

  test('as três missões de hoje cumpridas', () {
    final kinds = [for (final m in FactoryDaily.of()) m.kind];
    expect(MissionsReminder.doneToday(null), isFalse);
    expect(MissionsReminder.doneToday({'daily': {'day': League.dayKey(), 'p': {}, 'done': kinds.take(2).toList(), 'streak': 0}}), isFalse);
    expect(MissionsReminder.doneToday({'daily': {'day': League.dayKey(), 'p': {}, 'done': kinds, 'streak': 0}}), isTrue);
    // As de ontem não contam.
    expect(MissionsReminder.doneToday({'daily': {'day': '2000-01-01', 'p': {}, 'done': kinds, 'streak': 0}}), isFalse);
  });
}
