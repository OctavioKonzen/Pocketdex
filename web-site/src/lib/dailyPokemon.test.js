import { describe, expect, it } from 'vitest'
import { dailyPokemonId } from './dailyPokemon'

describe('Pokémon do dia', () => {
  it('é o mesmo do app', () => {
    // Mesmos valores do teste do app (test/daily_pokemon_test.dart).
    expect(dailyPokemonId('2026-09-30')).toBe(695)
    expect(dailyPokemonId('2026-10-01')).toBe(399)
  })
})
