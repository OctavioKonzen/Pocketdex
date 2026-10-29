import { describe, expect, it } from 'vitest'
import { evoCondition, evoStages } from './evolutionTimeline'

const p = (id) => ({ id, name: `p${id}` })
describe('Linha do tempo da evolução', () => {
  it('as condições', () => {
    expect(evoCondition('(Level 16)')).toMatchObject({ icon: '⬆️', level: 16 })
    expect(evoCondition('(water stone)')).toMatchObject({ text: 'Water Stone', item: 'water-stone' })
    expect(evoCondition('(trade)').icon).toBe('🔄')
  })
  it('as etapas, com galhos', () => {
    const stages = evoStages([
      { from: p(133), to: p(134), trigger: '(water stone)' },
      { from: p(133), to: p(135), trigger: '(thunder stone)' },
    ])
    expect(stages.map((s) => s.map((x) => x.p.id))).toEqual([[133], [134, 135]])
    const line = evoStages([{ from: p(1), to: p(2), trigger: '(Level 16)' }, { from: p(2), to: p(3), trigger: '(Level 32)' }])
    expect(line.map((s) => s.map((x) => x.p.id))).toEqual([[1], [2], [3]])
  })
})
