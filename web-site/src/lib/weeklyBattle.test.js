import { describe, expect, it } from 'vitest'
import { scoreToTurns, turnsToScore, weeklyBest, weeklyRandom, weeklyWin } from './weeklyBattle'

describe('Desafio semanal', () => {
  it('menos turnos, mais pontos (e volta)', () => {
    expect(turnsToScore(10)).toBeGreaterThan(turnsToScore(11))
    expect(scoreToTurns(turnsToScore(23))).toBe(23)
    expect(turnsToScore(5000)).toBe(1)
  })

  it('o mesmo sorteio na mesma semana', () => {
    const a = weeklyRandom('2026-10-26'), b = weeklyRandom('2026-10-26')
    expect([a(), a()]).toEqual([b(), b()])
  })

  it('guarda o menor número de turnos da semana', () => {
    let league = weeklyWin({}, 20, '2026-10-26')
    league = weeklyWin(league, 25, '2026-10-26')
    expect(weeklyBest(league, '2026-10-26')).toBe(20)
    expect(weeklyBest(weeklyWin(league, 12, '2026-10-26'), '2026-10-26')).toBe(12)
    expect(weeklyBest(league, '2026-11-02')).toBe(null)
  })
})
