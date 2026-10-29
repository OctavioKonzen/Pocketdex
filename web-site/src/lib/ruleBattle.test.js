import { describe, expect, it } from 'vitest'
import { RULES, ruleOfWeek, ruleWin, ruleWins } from './ruleBattle'

describe('Desafio com regra', () => {
  it('uma regra por semana, a mesma para todos', () => {
    expect(ruleOfWeek('2026-10-26')).toBe(ruleOfWeek('2026-10-26'))
    expect(RULES.length).toBe(18 + 9 + 2)
  })
  it('as regras', () => {
    const fire = RULES.find((r) => r.key === 'type:fire')
    expect(fire.fits({ types: ['fire', 'flying'], gen: 1 })).toBe(true)
    expect(RULES.find((r) => r.key === 'gen:3').fits({ types: ['grass'], gen: 3 })).toBe(true)
    expect(RULES.find((r) => r.key === 'small').fits({ types: ['grass'], height: 10 })).toBe(true)
    expect(RULES.find((r) => r.key === 'mono').fits({ types: ['grass', 'poison'] })).toBe(false)
  })
  it('conta as vitórias da semana', () => {
    const l = ruleWin(ruleWin({}, '2026-10-26'), '2026-10-26')
    expect(ruleWins(l, '2026-10-26')).toBe(2)
    expect(ruleWins(l, '2026-11-02')).toBe(0)
  })
})
