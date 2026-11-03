import { describe, expect, it } from 'vitest'
import { speedStat } from './speed'

describe('Speed', () => {
  it('como no jogo (Garchomp, base 102)', () => {
    expect(speedStat(102, 50, 31, 252, 1.1)).toBe(169)
    expect(speedStat(102, 50, 31, 252, 1.1, { scarf: true })).toBe(253)
    expect(speedStat(102, 100, 31, 252, 1)).toBe(303)
    expect(speedStat(102, 100, 0, 0, 0.9)).toBe(188)
    expect(speedStat(102, 50, 31, 252, 1, { tailwind: true })).toBe(308)
  })
})
