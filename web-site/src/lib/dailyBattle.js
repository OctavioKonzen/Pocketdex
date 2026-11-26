// Desafio do Pokémon do dia (igual ao app, lib/services/daily_battle.dart): o
// seu primeiro time contra um trio do Pokémon de hoje. Vencer vale moedas do
// Pokelike, uma vez por dia (o dia de Brasília).
import { dayKey } from './league'

/** As moedas da vitória (uma vez por dia). */
export const DAILY_BATTLE_COINS = 150
/** O trio do Pokémon do dia. */
export const DAILY_BATTLE_FOES = 3

export const dailyBattleDone = (factory, day = dayKey()) => factory?.dailyBattle === day

/** A Factory com as moedas da vitória de hoje (a mesma, se já ganhou hoje). */
export function winDailyBattle(factory, day = dayKey()) {
  if (dailyBattleDone(factory, day)) return factory
  return { ...factory, coins: (factory.coins ?? 0) + DAILY_BATTLE_COINS, dailyBattle: day }
}
