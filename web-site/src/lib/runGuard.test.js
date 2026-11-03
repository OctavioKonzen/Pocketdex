import { describe, expect, it } from 'vitest'
import { runChanged, useRunTakeover, noteTakeover } from './runGuard'

describe('runGuard', () => {
  const league = (run) => ({ factory: { coins: 0, run } })

  it('a corrida mudou em outro aparelho', () => {
    expect(runChanged(league({ floor: 3 }), league({ floor: 5 }))).toBe(true)
    // Acabou lá.
    expect(runChanged(league({ floor: 3 }), league(null))).toBe(true)
  })

  it('sem corrida aqui, ou a mesma corrida, não avisa', () => {
    expect(runChanged(league(null), league({ floor: 1 }))).toBe(false)
    expect(runChanged(undefined, league({ floor: 1 }))).toBe(false)
    expect(runChanged(league({ floor: 3 }), { ...league({ floor: 3 }), gym: 1 })).toBe(false)
  })

  it('conta os avisos', () => {
    const before = useRunTakeover.getState().count
    noteTakeover()
    expect(useRunTakeover.getState().count).toBe(before + 1)
  })
})

describe('runGuard: a ordem das chaves', () => {
  it('a conta devolve os campos em outra ordem: não é outra corrida', () => {
    const a = { factory: { run: { floor: 1, bag: { 'poke-ball': 5, potion: 4 }, foes: [{ id: 1, level: 3 }] } } }
    const b = { factory: { run: { foes: [{ level: 3, id: 1 }], bag: { potion: 4, 'poke-ball': 5 }, floor: 1 } } }
    expect(runChanged(a, b)).toBe(false)
  })
})
