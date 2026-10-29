// A velocidade da batalha: 2× corta as esperas pela metade e fica guardada.
import { describe, expect, it } from 'vitest'

const memory = new Map()
globalThis.localStorage = { getItem: (k) => memory.get(k) ?? null, setItem: (k, v) => memory.set(k, String(v)), removeItem: (k) => memory.delete(k) }

describe('velocidade da batalha', () => {
  it('2× corta as esperas pela metade e fica guardada', async () => {
    const { fast, toggleBattleSpeed, useBattleSpeed } = await import('./battleSpeed')
    expect(fast(1100)).toBe(1100)
    toggleBattleSpeed()
    expect(useBattleSpeed.getState().speed).toBe(2)
    expect(fast(1100)).toBe(550)
    expect(memory.get('pocketdex-battle-speed')).toBe('2')
    toggleBattleSpeed()
    expect(fast(1100)).toBe(1100)
  })
})
