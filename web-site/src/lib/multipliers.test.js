import { describe, expect, it } from 'vitest'
import { battleHit, newSide } from './damageCalc'

// Mesmo atacante e mesmo alvo (mesmos status), mudando só os tipos: o dano
// tem que seguir os multiplicadores do jogo (STAB 1.5x, 2x, 4x, 0.5x, 0.25x, 0).
const STATS = [80, 100, 100, 100, 100, 80]
const mon = (types) => ({ base: { name: 'mew', types, stats: STATS, weight: 40 }, side: { ...newSide(), level: 50, nature: 'Hardy', ability: '', item: '' }, hp: 155, maxHp: 155 })
const max = (att, def, move) => {
  const r = battleHit(att, def, move, false)
  return { dmg: r.rolls[0].at(-1), eff: r.eff }
}

describe('multiplicadores de dano', () => {
  const water = mon(['water'])
  const normal = mon(['normal'])
  const base = max(normal, mon(['normal']), 'surf').dmg // sem STAB, neutro
  it('STAB 1.5x', () => {
    const stab = max(water, mon(['normal']), 'surf')
    expect(stab.eff).toBe(1)
    expect(stab.dmg / base).toBeCloseTo(1.5, 1)
  })
  it.each([
    [['fire'], 2],
    [['fire', 'rock'], 4],
    [['grass'], 0.5],
    [['grass', 'dragon'], 0.25],
  ])('Surf em %j = %sx', (types, mult) => {
    const r = max(normal, mon(types), 'surf')
    expect(r.eff).toBe(mult)
    expect(r.dmg / base).toBeCloseTo(mult, 1)
  })
  it('STAB e 4x juntos = 6x', () => {
    expect(max(water, mon(['fire', 'rock']), 'surf').dmg / base).toBeCloseTo(6, 0)
  })
  it('imune = 0', () => {
    const r = max(normal, mon(['ghost']), 'body-slam')
    expect(r.eff).toBe(0)
    expect(r.dmg).toBe(0)
  })
})
