import { describe, expect, it } from 'vitest'
import { caughtIds, seenIds } from './dexMarks'
import { withSeen } from './factoryRun'

describe('visto × capturado (igual ao app)', () => {
  it('a corrida guarda os vistos (adversários) e os capturados (time e Pokédex da corrida)', () => {
    const factory = { coins: 0, run: { starter: 1, dex: [1, 16], team: [{ id: 2 }], encounter: { foes: [{ id: 19 }, { id: 21 }] } } }
    const out = withSeen(factory)
    expect(out.seen).toEqual([19, 21])
    expect(out.caught).toEqual([1, 2, 16])
    // Nada novo: a mesma Factory.
    expect(withSeen(out)).toBe(out)
    expect(withSeen({ coins: 0, run: null })).toEqual({ coins: 0, run: null })
  })

  it('capturado: Coleção e Pokelike; visto: os capturados e os vistos', () => {
    const collection = { red: { c: [25], s: ['133'] } }
    const league = { factory: { owned: [4], shinies: [7], caught: [16], seen: [19] } }
    expect([...caughtIds(collection, league)].sort((a, b) => a - b)).toEqual([4, 7, 16, 25, 133])
    expect(seenIds(collection, league).has(19)).toBe(true)
    expect(caughtIds(collection, league).has(19)).toBe(false)
    expect(caughtIds(undefined, undefined).size).toBe(0)
  })
})
