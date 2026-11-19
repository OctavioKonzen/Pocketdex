// Pokémon do dia (igual ao app, lib/services/daily_pokemon.dart): um Pokémon
// diferente por dia (dia de Brasília), o mesmo para todo mundo.

import { dayKey } from './league'
import { seeded } from './challenge'

export const DAILY_COUNT = 1025

/** Pokémon do dia "AAAA-MM-DD": sempre o mesmo para o mesmo dia. */
export function dailyPokemonId(day = dayKey()) {
  const seed = Number(day.replaceAll('-', ''))
  // Mesma conta do app: a semente é cortada para 32 bits dentro do gerador.
  const rng = seeded(Number((BigInt(seed) * 2654435761n) & 0xffffffffn))
  return 1 + Math.floor(rng() * DAILY_COUNT)
}
