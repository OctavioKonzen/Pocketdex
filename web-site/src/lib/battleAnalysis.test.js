import { describe, expect, it } from 'vitest'
import { battleAnalysis } from './battleAnalysis'

const names = [['A', 'B', 'C'], ['X', 'Y', 'Z']]
const ko = (turn, side, by = null) => ({ turn, side, by: by == null ? null : { side: 1 - side, index: by } })

describe('Análise da batalha', () => {
  it('derrota: quem varreu e o turno da virada', () => {
    const out = battleAnalysis([ko(2, 1, 0), ko(4, 0, 2), ko(5, 0, 2), ko(7, 0, 2)], [3, 3], names, 1)
    expect(out.map((o) => o.icon)).toEqual(['🌪️', '📉', '🎯'])
    expect(out[0].text).toContain('Z')
    expect(out[1].text).toContain('5')
    expect(out[2].text).toContain('2')
  })

  it('vitória de virada', () => {
    const out = battleAnalysis([ko(1, 0, 0), ko(3, 1, 1), ko(4, 1, 1), ko(6, 1, 1)], [3, 3], names, 0)
    expect(out.map((o) => o.icon)).toEqual(['📈'])
    expect(out[0].text).toContain('4')
  })

  it('vitória sem ficar atrás', () => {
    expect(battleAnalysis([ko(1, 1, 0)], [1, 1], names, 0).map((o) => o.icon)).toEqual(['🛡️'])
  })
})
