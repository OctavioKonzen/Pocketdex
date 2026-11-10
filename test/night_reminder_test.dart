import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/night_reminder.dart';

void main() {
  test('aviso da noite: 19h dos próximos 7 dias (hoje só se ainda não passou)', () {
    final morning = NightReminder.upcoming(DateTime(2026, 11, 4, 8));
    expect(morning.length, 7);
    expect(morning.first, DateTime(2026, 11, 4, 19));
    final late = NightReminder.upcoming(DateTime(2026, 11, 4, 21));
    expect(late.first, DateTime(2026, 11, 5, 19));
    expect(late.length, 7);
  });
}
