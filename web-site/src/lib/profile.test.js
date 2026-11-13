import { describe, expect, it } from 'vitest'
import { profileOf } from './profile'

describe('Perfil público', () => {
  it('resume a conta', () => {
    const p = profileOf({ avatar: 6, rankedRecord: 120, league: { badges: { Kanto: [1, 2, 3] }, hall: [{ region: 'Kanto', team: [6, 9, 3], at: 1 }], tower: { best: 4 }, factory: { best: 30, shinies: [] } }, collection: { red: { c: [1, 2], s: [2] } } })
    expect(p).toMatchObject({ avatar: 6, ranked: 120, badges: 3, tower: 4, factory: 30, caught: 2, theme: 0, shiny: false, champion: false })
    expect(p.hall).toEqual([{ region: 'Kanto', team: [6, 9, 3] }])
    expect(p.medals).toEqual(['floor25', 'champion'])
  })
})
