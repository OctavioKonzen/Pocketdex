import { describe, expect, it } from 'vitest'
import { dailyMissions, dailyOf, trackDaily } from './factoryDaily'

const DAY = '2026-10-28'
const run = (o = {}) => ({ floor: 1, defeated: 0, bosses: 0, starter: 1, dex: [1], bag: { potion: 4 }, ...o })

describe('Missões diárias', () => {
  it('três missões diferentes, as mesmas no mesmo dia', () => {
    const a = dailyMissions(DAY)
    expect(a).toHaveLength(3)
    expect(new Set(a.map((m) => m.kind)).size).toBe(3)
    expect(dailyMissions(DAY)).toEqual(a)
  })

  it('o progresso sai da diferença na corrida e paga as moedas uma vez', () => {
    const missions = dailyMissions(DAY)
    let factory = { coins: 0, run: run() }
    const big = run({ floor: 30, defeated: 40, bosses: 3, dex: [1, 2, 3, 4] })
    factory = trackDaily(factory, { ...factory, run: big }, DAY)
    const total = missions.reduce((s, m) => s + m.coins, 0)
    expect(dailyOf(factory, DAY).done).toHaveLength(3)
    expect(factory.coins).toBe(total)
    const again = trackDaily(factory, { ...factory, run: { ...big, floor: 31 } }, DAY)
    expect(again.coins).toBe(total)
  })

  it('usar poção zera a sequência sem poção', () => {
    const prev = { coins: 0, run: run({ floor: 3 }), daily: { day: DAY, p: {}, done: [], streak: 2 } }
    const next = trackDaily(prev, { ...prev, run: run({ floor: 3, bag: { potion: 3 } }) }, DAY)
    expect(next.daily.streak).toBe(0)
  })

  it('o dia novo começa do zero', () => {
    expect(dailyOf({ daily: { day: '2026-10-27', p: { defeat: 3 }, done: ['defeat'], streak: 1 } }, DAY)).toEqual({ day: DAY, p: {}, done: [], streak: 0 })
  })
})
