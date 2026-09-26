// lib/services/daily_reminder.dart
//
// Lembrete do desafio do dia: uma notificação às 9h (horário de Brasília)
// nos dias em que o desafio ainda não foi jogado. Liga e desliga nas
// Configurações; a escolha fica só neste aparelho.
//
// Os lembretes dos próximos 7 dias ficam agendados no Android. Ao abrir o app
// e ao começar o desafio a agenda é refeita, então o de hoje some quando você
// já jogou.

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'league.dart';
import 'user_data.dart';

class DailyReminder {
  DailyReminder._();
  static final instance = DailyReminder._();

  static const _prefKey = 'dailyReminder';
  static const _firstId = 900;
  static const _days = 7;

  /// 9h em Brasília = 12h UTC (Brasília é UTC-3 o ano todo).
  static const _hourUtc = 12;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> get enabled async => (await SharedPreferences.getInstance()).getBool(_prefKey) ?? false;

  Future<void> _init() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
    _ready = true;
  }

  /// Liga ou desliga. Ao ligar, pede a permissão de notificação (Android 13+);
  /// devolve false se ela for negada.
  Future<bool> setEnabled(bool on) async {
    if (!supported) return false;
    await _init();
    if (on) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission() ?? true;
      if (!granted) return false;
    }
    await (await SharedPreferences.getInstance()).setBool(_prefKey, on);
    await reschedule();
    return true;
  }

  /// Horários (UTC) dos próximos lembretes: 9h de Brasília dos próximos 7
  /// dias, sem os que já passaram e sem o de hoje se o desafio já foi jogado.
  @visibleForTesting
  static List<DateTime> upcoming(DateTime now, {required bool playedToday}) {
    final utc = now.toUtc();
    final today = League.dayKey(utc);
    return [
      for (var i = 0; i < _days; i++) DateTime.utc(utc.year, utc.month, utc.day + i, _hourUtc),
    ].where((day) => day.isAfter(utc) && !(playedToday && League.dayKey(day) == today)).toList();
  }

  /// Refaz a agenda dos próximos dias (pula hoje se o desafio já foi jogado).
  Future<void> reschedule() async {
    if (!supported) return;
    try {
      await _init();
      for (var i = 0; i < _days; i++) {
        await _plugin.cancel(id: _firstId + i);
      }
      if (!await enabled) return;

      final playedToday = UserData.instance.stats['lastDaily'] == League.dayKey();
      final days = upcoming(DateTime.now(), playedToday: playedToday);
      for (var i = 0; i < days.length; i++) {
        final day = days[i];
        await _plugin.zonedSchedule(
          id: _firstId + i,
          scheduledDate: tz.TZDateTime.from(day, tz.UTC),
          title: 'Desafio do dia 📅',
          body: 'O desafio de hoje já está valendo. Quem é esse Pokémon?',
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'daily_challenge',
              'Desafio do dia',
              channelDescription: 'Lembrete diário do desafio do dia.',
            ),
          ),
          // Sem horário exato: não precisa de permissão extra e o Android
          // entrega por volta das 9h.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e) {
      debugPrint('Lembrete do desafio: $e');
    }
  }
}
