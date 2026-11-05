import { describe, expect, it } from 'vitest'
import { DAILY_BATTLE_COINS, dailyBattleDone, winDailyBattle } from './dailyBattle'

describe('desafio do Pokémon do dia (igual ao app)', () => {
  it('vencer dá as moedas uma vez por dia', () => {
    const f = winDailyBattle({ coins: 10 }, '2026-01-01')
    expect(f).toEqual({ coins: 10 + DAILY_BATTLE_COINS, dailyBattle: '2026-01-01' })
    expect(winDailyBattle(f, '2026-01-01')).toBe(f)
    expect(dailyBattleDone(f, '2026-01-01')).toBe(true)
    expect(dailyBattleDone(f, '2026-01-02')).toBe(false)
    expect(winDailyBattle(f, '2026-01-02').coins).toBe(10 + 2 * DAILY_BATTLE_COINS)
  })
})
