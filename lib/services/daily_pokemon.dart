// lib/services/daily_pokemon.dart
//
// Pokémon do dia (igual ao site, web-site/src/lib/dailyPokemon.js): um
// Pokémon diferente por dia (dia de Brasília), o mesmo para todo mundo, no
// app e no site. Aparece no Início e pode avisar por notificação às 10h.

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../i18n/i18n.dart';
import '../utils/string_extensions.dart';
import 'challenge.dart';
import 'league.dart';
import 'local_database.dart';

class DailyPokemon {
  DailyPokemon._();
  static final instance = DailyPokemon._();

  /// Quantos Pokémon entram no sorteio (a Pokédex nacional).
  static const count = 1025;

  /// Pokémon do dia "AAAA-MM-DD": sempre o mesmo para o mesmo dia.
  static int idFor(String dayKey) {
    final seed = int.parse(dayKey.replaceAll('-', ''));
    final rng = seeded(seed * 2654435761);
    return 1 + (rng() * count).floor();
  }

  static int get today => idFor(League.dayKey());

  // ---------------------------------------------------------------- aviso

  static const _prefKey = 'dailyPokemonReminder';
  static const _firstId = 920;
  static const _days = 7;

  /// 10h em Brasília = 13h UTC.
  static const _hourUtc = 13;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> get enabled async => (await SharedPreferences.getInstance()).getBool(_prefKey) ?? false;

  Future<void> _init() async {
    if (_ready) return;
    await _plugin.initialize(settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    _ready = true;
  }

  /// Liga ou desliga o aviso; devolve false se a permissão for negada.
  Future<bool> setEnabled(bool on) async {
    if (!supported) return false;
    await _init();
    if (on) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (!(await android?.requestNotificationsPermission() ?? true)) return false;
    }
    await (await SharedPreferences.getInstance()).setBool(_prefKey, on);
    await reschedule();
    return true;
  }

  /// Agenda os avisos dos próximos 7 dias, cada um com o nome do Pokémon.
  Future<void> reschedule() async {
    if (!supported) return;
    try {
      await _init();
      for (var i = 0; i < _days; i++) {
        await _plugin.cancel(id: _firstId + i);
      }
      if (!await enabled) return;
      final now = DateTime.now().toUtc();
      for (var i = 0; i < _days; i++) {
        final at = DateTime.utc(now.year, now.month, now.day + i, _hourUtc);
        if (!at.isAfter(now)) continue;
        final id = idFor(League.dayKey(at));
        final row = await LocalDatabase.instance.pokemonRow(id);
        final name = I18n.pokemonName(((row?['name'] as String?) ?? '#$id').split('-').first.capitalise());
        await _plugin.zonedSchedule(
          id: _firstId + i,
          scheduledDate: tz.TZDateTime.from(at, tz.UTC),
          title: tr('Pokémon do dia: {0}').replaceAll('{0}', name),
          body: tr('Toque para conhecer o Pokémon de hoje e ouvir o grito dele.'),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails('daily_pokemon', 'Pokémon do dia', channelDescription: 'Aviso diário do Pokémon do dia.'),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e) {
      debugPrint('Pokémon do dia: $e');
    }
  }
}
