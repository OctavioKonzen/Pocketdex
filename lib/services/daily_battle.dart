// lib/services/daily_battle.dart
//
// Desafio do Pokémon do dia (igual ao site, web-site/src/lib/dailyBattle.js):
// o seu primeiro time contra um trio do Pokémon de hoje. Vencer vale moedas do
// Pokelike, uma vez por dia (o dia de Brasília).

import 'factory_run.dart';
import 'league.dart';

class DailyBattle {
  DailyBattle._();

  /// As moedas da vitória (uma vez por dia).
  static const coins = 150;

  /// O trio do Pokémon do dia.
  static const foes = 3;

  static bool doneToday(Map? factory, [String? day]) => factory?['dailyBattle'] == (day ?? League.dayKey());

  /// A Factory com as moedas da vitória de hoje (a mesma, se já ganhou hoje).
  static Map<String, dynamic> win(Map<String, dynamic> factory, [String? day]) {
    day ??= League.dayKey();
    if (doneToday(factory, day)) return factory;
    return {...factory, 'coins': ((factory['coins'] as num?) ?? 0).toInt() + coins, 'dailyBattle': day};
  }

  /// A Factory da conta (a "league" do UserData).
  static Map<String, dynamic> factoryOf(Map? league) => FactoryRun.of(league);
}
