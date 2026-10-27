import { describe, expect, it } from 'vitest'
import { currentSeason, eloAfter, repeatedSpecies } from './onlineBattle'

describe('online: ranking e regras', () => {
  it('Elo: ganhar de alguém igual dá +16; mais forte, mais; nunca mais de 40', () => {
    expect(eloAfter(1000, 1000, true)).toBe(1016)
    expect(eloAfter(1000, 1000, false)).toBe(984)
    expect(eloAfter(1000, 1400, true)).toBe(1029)
    expect(eloAfter(1400, 1000, false)).toBe(1371)
    expect(eloAfter(1000, 5000, true) - 1000).toBeLessThanOrEqual(40)
  })
  it('temporada é o mês; time com Pokémon repetido', () => {
    expect(currentSeason(new Date(2026, 9, 8))).toBe('2026-10')
    expect(currentSeason(new Date(2027, 0, 1))).toBe('2027-01')
    expect(repeatedSpecies({ pokemon: [6, 9, 6] })).toBe(true)
    expect(repeatedSpecies({ pokemon: [6, 9, null, null] })).toBe(false)
  })
})
