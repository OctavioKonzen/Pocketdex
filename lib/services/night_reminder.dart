// lib/services/night_reminder.dart
//
// Aviso do evento noturno do Pokelike: às 19h (no relógio do celular), quando
// os Pokémon da noite (fantasma e sombrio) começam a aparecer mais nas rotas
// (FactoryRun.clockOf, das 19h às 6h). Liga e desliga nas Configurações; a
// escolha fica só neste aparelho. Como o lembrete das missões
// (missions_reminder.dart): os próximos 7 dias ficam agendados e a agenda é
// refeita ao abrir o app.

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../i18n/i18n.dart';

class NightReminder {
  NightReminder._();
  static final instance = NightReminder._();

  static const _prefKey = 'nightReminder';
  static const _firstId = 940;
  static const _days = 7;

  /// A hora em que a noite começa no Pokelike (igual a FactoryRun.clockOf).
  static const hour = 19;

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

  /// Liga ou desliga. Ao ligar, pede a permissão de notificação (Android 13+); devolve false se ela for negada.
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

  /// Os próximos avisos: 19h (hora do celular) dos próximos 7 dias, sem os que já passaram.
  @visibleForTesting
  static List<DateTime> upcoming(DateTime now) => [
        for (var i = 0; i < _days + 1; i++) DateTime(now.year, now.month, now.day + i, hour),
      ].where((at) => at.isAfter(now)).take(_days).toList();

  Future<void> reschedule() async {
    if (!supported) return;
    try {
      await _init();
      for (var i = 0; i < _days; i++) {
        await _plugin.cancel(id: _firstId + i);
      }
      if (!await enabled) return;
      final days = upcoming(DateTime.now());
      for (var i = 0; i < days.length; i++) {
        await _plugin.zonedSchedule(
          id: _firstId + i,
          scheduledDate: tz.TZDateTime.from(days[i].toUtc(), tz.UTC),
          title: tr('A noite chegou 🌙'),
          body: tr('Os Pokémon da noite (fantasma e sombrio) estão aparecendo mais no Pokelike.'),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails('factory_night', 'Evento noturno', channelDescription: 'Aviso de quando a noite começa no Pokelike.'),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e) {
      debugPrint('Aviso da noite: $e');
    }
  }
}
