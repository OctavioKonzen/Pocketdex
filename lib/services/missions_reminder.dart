// lib/services/missions_reminder.dart
//
// Lembrete das missões do dia do Pokelike: uma notificação às 20h (horário de
// Brasília) nos dias em que ainda falta alguma das três missões — elas viram à
// meia-noite. Liga e desliga nas Configurações; a escolha fica só neste
// aparelho. Como o lembrete do desafio (daily_reminder.dart): os próximos 7
// dias ficam agendados e a agenda é refeita ao abrir o app e ao cumprir as
// missões, então o de hoje some quando você já cumpriu todas.

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'factory_daily.dart';
import 'factory_run.dart';
import 'league.dart';
import 'user_data.dart';
import '../i18n/i18n.dart';

class MissionsReminder {
  MissionsReminder._();
  static final instance = MissionsReminder._();

  static const _prefKey = 'missionsReminder';
  static const _firstId = 920;
  static const _days = 7;

  /// 20h em Brasília = 23h UTC (Brasília é UTC-3 o ano todo).
  static const _hourUtc = 23;

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

  /// As três missões de hoje já foram cumpridas?
  static bool doneToday(Map? factory) => (FactoryDaily.stateOf(factory)['done'] as List).length >= FactoryDaily.of().length;

  /// Horários (UTC) dos próximos lembretes: 20h de Brasília dos próximos 7
  /// dias, sem os que já passaram e sem o de hoje se as missões já foram cumpridas.
  @visibleForTesting
  static List<DateTime> upcoming(DateTime now, {required bool doneToday}) {
    final utc = now.toUtc();
    final today = League.dayKey(utc);
    // 23h UTC ainda é o mesmo dia em Brasília (20h).
    return [
      for (var i = 0; i < _days; i++) DateTime.utc(utc.year, utc.month, utc.day + i, _hourUtc),
    ].where((at) => at.isAfter(utc) && !(doneToday && League.dayKey(at) == today)).toList();
  }

  /// Refaz a agenda dos próximos dias (pula hoje se as missões já foram cumpridas).
  Future<void> reschedule() async {
    if (!supported) return;
    try {
      await _init();
      for (var i = 0; i < _days; i++) {
        await _plugin.cancel(id: _firstId + i);
      }
      if (!await enabled) return;

      final days = upcoming(DateTime.now(), doneToday: doneToday(FactoryRun.of(UserData.instance.league)));
      for (var i = 0; i < days.length; i++) {
        await _plugin.zonedSchedule(
          id: _firstId + i,
          scheduledDate: tz.TZDateTime.from(days[i], tz.UTC),
          title: tr('Missões do dia 🎲'),
          body: tr('Ainda faltam missões do Pokelike hoje. Elas trocam à meia-noite.'),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'factory_missions',
              'Missões do dia',
              channelDescription: 'Lembrete das missões do dia do Pokelike.',
            ),
          ),
          // Sem horário exato: não precisa de permissão extra e o Android
          // entrega por volta das 20h.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e) {
      debugPrint('Lembrete das missões: $e');
    }
  }
}
