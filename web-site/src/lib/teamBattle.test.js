import { readFileSync } from 'node:fs'
import { beforeAll, describe, expect, it, vi } from 'vitest'
import { runBattle, teamMembers } from './teamBattle'

beforeAll(() => {
  // O banco local vem de public/data (no site é baixado com fetch).
  vi.stubGlobal('fetch', async (url) => {
    const file = new URL(`../../public/data/${String(url).split('/data/')[1]}`, import.meta.url)
    return { ok: true, json: async () => JSON.parse(readFileSync(file, 'utf8')) }
  })
})

describe('batalha de times', () => {
  it('fogo ganha de planta, água ganha de fogo', async () => {
    const r = await runBattle(
      [{ id: 6 }, { id: 9 }],
      [{ id: 3 }, { id: 6 }],
    )
    expect(r[0][0].result).toBe(1)
    expect(r[1][1].result).toBe(1)
  }, 30000)

  it('usa os golpes do set', async () => {
    const set = { level: 50, nature: 'Timid', moves: ['flamethrower', '', '', ''], evs: { spa: 252, spe: 252 } }
    const r = await runBattle([{ id: 6, set }], [{ id: 3 }])
    expect(r[0][0].mine.move).toBe('Flamethrower')
  })

  it('membros do time', () => {
    expect(teamMembers({ pokemon: [25, null, 6], sets: [{ level: 5 }] })).toEqual([
      { id: 25, set: { level: 5 } },
      { id: 6, set: null },
    ])
  })
})
