import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/daily_reminder.dart';

void main() {
  test('lembrete às 9h de Brasília (12h UTC) nos próximos dias', () {
    // 8h em Brasília: o de hoje ainda vale.
    final days = DailyReminder.upcoming(DateTime.utc(2026, 9, 26, 11), playedToday: false);
    expect(days.first, DateTime.utc(2026, 9, 26, 12));
    expect(days.length, 7);
  });

  test('sem lembrete hoje se já jogou ou se já passou das 9h', () {
    final played = DailyReminder.upcoming(DateTime.utc(2026, 9, 26, 11), playedToday: true);
    expect(played.first, DateTime.utc(2026, 9, 27, 12));
    final late = DailyReminder.upcoming(DateTime.utc(2026, 9, 26, 15), playedToday: false);
    expect(late.first, DateTime.utc(2026, 9, 27, 12));
  });

  test('perto da meia-noite (já é outro dia em UTC, ainda não em Brasília)', () {
    // 22h de 26/09 em Brasília = 01h de 27/09 UTC; jogou o desafio do dia 26.
    final days = DailyReminder.upcoming(DateTime.utc(2026, 9, 27, 1), playedToday: true);
    expect(days.first, DateTime.utc(2026, 9, 27, 12));
  });
}
