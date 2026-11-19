import { describe, expect, it } from 'vitest'
import { FX_STAGE, STATUS_SCENES, STATUS_TEXT_SCENE, fxScene } from './battleFx'

describe('cenas de status (igual ao app)', () => {
  it('cada status tem a cena dele, no lado certo, sem esconder o Pokémon', () => {
    for (const kind of Object.keys(STATUS_SCENES)) {
      for (const side of [0, 1]) {
        const plan = fxScene({ kind, side, stage: FX_STAGE, seed: 3 })
        expect(plan.from).toBe(side)
        expect(plan.dur).toBeGreaterThan(800)
        expect(plan.layers.length).toBeGreaterThan(0)
        expect(plan.sprites.some((x) => x.k === 'hide')).toBe(false)
      }
    }
    expect(Object.values(STATUS_TEXT_SCENE).every((k) => STATUS_SCENES[k])).toBe(true)
  })
})
