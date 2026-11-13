import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { followerFit, FOLLOW_MIN, PERSON_DM } from './FactoryPanels'
import { battleScale } from './BattleScene'

const anim = JSON.parse(readFileSync(new URL('../../../assets/database/animated_sprites.json', import.meta.url), 'utf8'))
// O desenho de frente: [largura, altura] em caixas (como standOf, com o GIF animado).
const stand = (id) => {
  const z = Math.max(1, anim.fit.front[id]?.[0] ?? 1)
  const [w, h] = anim.stand.front[id]
  return [w * z, h * z]
}
const person = 0.95 * battleScale(PERSON_DM)
// A altura do Pokémon e a do treinador na tela (em caixas), como o campo desenha.
const sizes = (height, id) => {
  const s = stand(id)
  const { k, scale } = followerFit(height, s)
  return { pokemon: scale * 0.95 * s[1], trainer: person * k, k }
}

describe('o Pokémon ao lado do treinador, na altura de verdade (igual ao app)', () => {
  it('a proporção é a das alturas (pessoa de 1,6 m)', () => {
    for (const [id, height] of [[25, 4], [6, 17], [143, 21], [1007, 25]]) {
      const { pokemon, trainer } = sizes(height, id)
      expect(pokemon / trainer).toBeCloseTo(height / PERSON_DM, 2)
    }
  })
  it('quem é grande demais deixa a cena menor, sem passar do campo', () => {
    const koraidon = sizes(25, 1007)
    expect(koraidon.k).toBeLessThan(1)
    const wailord = sizes(145, 321)
    expect(wailord.k).toBe(FOLLOW_MIN)
    expect(wailord.pokemon).toBeLessThanOrEqual(0.95 + 1e-9)
    expect(sizes(4, 25).k).toBe(1)
  })
})
