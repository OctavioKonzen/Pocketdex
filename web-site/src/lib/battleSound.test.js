import { describe, expect, it } from 'vitest'
import { HIT_AT, syncedStart } from './battleSound'

describe('fanfarra da Mega/Dynamax junto com a animação', () => {
  it('em 2x e 4x começa adiantada para o estouro cair no clarão (igual ao app)', () => {
    for (const speed of [1, 2, 4]) {
      const flash = HIT_AT / speed // o clarão: 700 ms de espera, dividido pela velocidade
      expect(HIT_AT - syncedStart(speed)).toBeCloseTo(flash, 6)
    }
    expect(syncedStart(1)).toBe(0)
  })
})
