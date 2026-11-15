import { describe, it, expect, vi } from 'vitest'
vi.mock('../lib/pokemonIndex', () => ({ usePokemonIndex: () => new Map() }))
import { skillTreeLayout } from './FactoryPanels'

describe('árvore de melhorias', () => {
  it('nenhum nó em cima do outro (os vizinhos do mesmo anel não encostam)', () => {
    const { branches, size } = skillTreeLayout()
    const nodes = branches.flatMap((b) => b.nodes)
    let closest = Infinity
    for (let i = 0; i < nodes.length; i++)
      for (let j = i + 1; j < nodes.length; j++) closest = Math.min(closest, Math.hypot(nodes[i].pos[0] - nodes[j].pos[0], nodes[i].pos[1] - nodes[j].pos[1]))
    expect(closest).toBeGreaterThanOrEqual(50)
  })
})
