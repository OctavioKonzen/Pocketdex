import { describe, expect, it } from 'vitest'
import { medalsOf } from './medals'

describe('Álbum de medalhas', () => {
  it('libera pelos marcos da conta', () => {
    const on = (state) => medalsOf(state).filter((m) => m.unlocked).map((m) => m.id)
    expect(on({})).toEqual([])
    expect(on({ league: { factory: { shinies: [1], best: 30 }, hall: [{ region: 'Kanto' }], tower: { best: 12 } } })).toEqual(['shiny1', 'floor25', 'champion', 'tower10'])
    expect(on({ collection: { red: { c: Array.from({ length: 151 }, (_, i) => i + 1) } } })).toEqual(['kanto'])
  })
})
