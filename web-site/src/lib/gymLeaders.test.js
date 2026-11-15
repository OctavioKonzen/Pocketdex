import { readFileSync } from 'node:fs'
import { beforeAll, describe, expect, it, vi } from 'vitest'
import { battleMons, leaderTeam } from './battleSetup'
import { simulatorDispose } from './battleSimulator'
import { seededRandom } from './league'
import { newBattle, playTurn, startBattle } from './turnBattle'

beforeAll(() => {
  vi.stubGlobal('fetch', async (url) => {
    const file = new URL(`../../public/data/${String(url).split('/data/')[1]}`, import.meta.url)
    return { ok: true, json: async () => JSON.parse(readFileSync(file, 'utf8')) }
  })
})

const regions = JSON.parse(readFileSync(new URL('../../../assets/database/gym_leaders.json', import.meta.url), 'utf8'))
const trainers = new Set(JSON.parse(readFileSync(new URL('../../../assets/database/trainers.json', import.meta.url), 'utf8')).map((t) => t.id))
const leaders = regions.flatMap((r) => r.leaders)

describe('Desafio dos Líderes', () => {
  it('cada região tem campeão; todo líder tem treinador e de 1 a 6 Pokémon', () => {
    expect(regions.map((r) => r.region)).toEqual(['Kanto', 'Johto', 'Hoenn', 'Sinnoh', 'Unova', 'Kalos', 'Alola', 'Galar', 'Paldea'])
    for (const r of regions) expect(r.leaders.some((l) => l.kind === 'champion')).toBe(true)
    for (const l of leaders) {
      expect(trainers.has(l.trainer)).toBe(true)
      expect(l.team.length).toBeGreaterThanOrEqual(1)
      expect(l.team.length).toBeLessThanOrEqual(6)
    }
    expect(new Set(leaders.map((l) => l.id)).size).toBe(leaders.length)
  })

  it.each(leaders.map((l) => [l.id, l]))('%s: o time entra na batalha, todos no nível 50', async (_, leader) => {
    const random = seededRandom(7)
    const team = await battleMons(await leaderTeam(leader, random))
    expect(team).toHaveLength(leader.team.length)
    expect(team.map((m) => m.id)).toEqual(leader.team)
    for (const mon of team) expect(mon.level).toBe(50)
    const b = newBattle(team.slice(), team.slice(), seededRandom(1), { seed: 1 })
    try {
      startBattle(b)
      playTurn(b, { move: 0, gimmick: 'none' }, () => null)
      expect(b.turn).toBeGreaterThanOrEqual(1)
    } finally {
      simulatorDispose(b)
    }
  }, 30000)
})
