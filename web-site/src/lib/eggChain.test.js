import { readFileSync } from 'node:fs'
import { beforeAll, describe, expect, it, vi } from 'vitest'
import { eggChains, eggMoves } from './eggChain'
import { teraRaidPicks } from './teraRaid'

beforeAll(() => {
  vi.stubGlobal('fetch', async (url) => {
    const file = new URL(`../../public/data/${String(url).split('/data/')[1]}`, import.meta.url)
    return { ok: true, json: async () => JSON.parse(readFileSync(file, 'utf8')) }
  })
})

describe('golpes de ovo', () => {
  it('Charmander aprende Dragon Dance por um pai direto', async () => {
    expect(await eggMoves(4)).toContain('dragon-dance')
    const chains = await eggChains(4, 'dragon-dance')
    expect(chains.length).toBeGreaterThan(0)
    for (const chain of chains) {
      expect(chain[0].method).not.toBe('egg')
      for (const link of chain.slice(1)) expect(link.method).toBe('egg')
    }
  })
})

describe('Tera Raids', () => {
  it('contra Tera Water vêm atacantes de Grass/Electric', () => {
    const pokedex = JSON.parse(readFileSync(new URL('../../public/data/pokemon_index.json', import.meta.url), 'utf8')).filter((p) => p.default)
    const types = JSON.parse(readFileSync(new URL('../../public/data/types.json', import.meta.url), 'utf8'))
    const picks = teraRaidPicks(pokedex, types, ['fire'], 'water')
    expect(picks.length).toBeGreaterThan(0)
    for (const p of picks) expect(['grass', 'electric']).toContain(p.attackType)
  })
})
