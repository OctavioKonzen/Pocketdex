import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import { GIRL_TRAINERS, playable } from './trainers'

const list = JSON.parse(readFileSync(new URL('../../../assets/database/trainers.json', import.meta.url), 'utf8'))

describe('escolha do treinador', () => {
  it('mostra quem lança a Poké Ball de costas, até os sem animação de frente (Dawn, Lyra...)', () => {
    const ids = list.filter(playable).map((t) => t.id)
    for (const id of ['dawn', 'lyra', 'lucas', 'ethan', 'leaf', 'may', 'brendan', 'hilda', 'red']) expect(ids).toContain(id)
    expect(ids).not.toContain('sd-dawn')
  })
  it('as meninas são todas jogáveis', () => {
    const ids = new Set(list.filter(playable).map((t) => t.id))
    for (const id of GIRL_TRAINERS) expect(ids.has(id)).toBe(true)
  })
})
