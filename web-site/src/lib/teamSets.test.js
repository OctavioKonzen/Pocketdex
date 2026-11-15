import { describe, expect, test } from 'vitest'
import { decodeTeam, encodeTeam, fromShowdown, toShowdown } from './teamShare'
import { lookupOf, newSet, normalizeSet, statValue } from './teamSets'

const index = [
  { id: 445, name: 'garchomp', default: true },
  { id: 6, name: 'charizard', default: true },
]
const byId = new Map(index.map((p) => [p.id, p]))
const garchomp = {
  ...newSet('rough-skin'),
  nickname: 'Chompy',
  gender: 'M',
  shiny: true,
  item: 'choice-scarf',
  nature: 'Jolly',
  tera: 'steel',
  level: 100,
  moves: ['earthquake', 'outrage', 'u-turn', 'stone-edge'],
  evs: { hp: 0, atk: 252, def: 0, spa: 0, spd: 4, spe: 252 },
  ivs: { hp: 31, atk: 31, def: 31, spa: 0, spd: 31, spe: 31 },
}
const team = { name: 'Areia', color: '#FF5252', pokemon: [445, 6, null, null, null, null], sets: [garchomp, newSet('blaze'), null, null, null, null] }

describe('times completos', () => {
  test('código leva todos os dados', () => {
    const back = decodeTeam(encodeTeam(team))
    expect(back.pokemon).toEqual(team.pokemon)
    expect(back.sets[0]).toEqual(normalizeSet(garchomp))
    expect(back.sets[2]).toBeNull()
  })

  test('texto de simulador ida e volta', () => {
    const text = toShowdown(team, byId)
    expect(text).toContain('Chompy (Garchomp) (M) @ Choice Scarf')
    expect(text).toContain('EVs: 252 Atk / 4 SpD / 252 Spe')
    expect(text).toContain('Jolly Nature')
    expect(text).toContain('IVs: 0 SpA')
    expect(text).toContain('- U-turn')
    const lookups = { moves: lookupOf(['earthquake', 'outrage', 'u-turn', 'stone-edge']), abilities: lookupOf(['rough-skin', 'blaze']), items: lookupOf(['choice-scarf']) }
    const back = fromShowdown(text, index, lookups)
    expect(back.pokemon.slice(0, 2)).toEqual([445, 6])
    expect(back.sets[0]).toEqual(normalizeSet(garchomp))
  })

  test('status final igual ao dos jogos', () => {
    // Garchomp nível 100, 252+ Atk Jolly → Atk 359, Speed 333
    const base = [108, 130, 95, 80, 85, 102]
    const set = normalizeSet(garchomp)
    expect(statValue(base, 1, set)).toBe(359)
    expect(statValue(base, 5, set)).toBe(333)
    expect(statValue(base, 0, set)).toBe(357)
  })

  test('set inválido vira válido', () => {
    const s = normalizeSet({ level: 500, evs: { atk: 999 }, nature: 'X', moves: ['a'] })
    expect(s.level).toBe(100)
    expect(s.evs.atk).toBe(252)
    expect(s.nature).toBe('Hardy')
    expect(s.moves).toEqual(['a', '', '', ''])
  })
})
