import {readFileSync} from 'node:fs'
import {describe, it, expect} from 'vitest'
import {npcMembers} from './npcSets'

const builds = JSON.parse(readFileSync(new URL('../../../assets/database/npc_sets.json', import.meta.url)))
const pokemon = JSON.parse(readFileSync(new URL('../../../assets/database/pokemon.json', import.meta.url)))
const items = JSON.parse(readFileSync(new URL('../../../assets/database/battle_items.json', import.meta.url)))
const moves = JSON.parse(readFileSync(new URL('../../../assets/database/moves.json', import.meta.url)))
const byId = new Map(pokemon.map(p => [p.id, p]))
const byMove = new Map(moves.map(m => [m.name, m]))

describe('NPC competitive builds', () => {
  it('covers every default Pokémon with level 50, max IVs, legal moves/abilities and valid EVs', () => {
    for (const p of pokemon.filter(p => p.is_default)) {
      const options = builds[p.id]
      expect(options, p.name).toBeDefined()
      for (const s of [...options.sets, ...options.mega]) {
        expect(s.level).toBe(50)
        expect(Object.values(s.ivs)).toEqual([31,31,31,31,31,31])
        expect(Object.values(s.evs).every(v => v >= 0 && v <= 252)).toBe(true)
        expect(Object.values(s.evs).reduce((a,b) => a+b, 0)).toBeLessThanOrEqual(510)
        expect(p.abilities.some(([a]) => a === s.ability)).toBe(true)
        expect(s.moves.length, p.name).toBeGreaterThan(0)
        expect(s.moves.length).toBeLessThanOrEqual(4)
        for (const m of s.moves) expect(p.moves.some(([n]) => n === m), `${p.name}: ${m}`).toBe(true)
      }
    }
  })
  it('normal randomizes IVs/EVs legally while hard preserves competitive spreads', () => {
    let seed = 13
    const rng = () => ((seed = (seed * 1664525 + 1013904223) >>> 0) / 2**32)
    const ids = [6,68,25,445,376,242]
    for (let trial = 0; trial < 50; trial++) {
      const team = npcMembers(ids, builds, rng)
      expect(team.some(m => Object.values(m.set.ivs).some(v => v !== 31))).toBe(true)
      for (const {set} of team) {
        expect(Object.values(set.ivs).every(v => v >= 0 && v <= 31)).toBe(true)
        expect(Object.values(set.evs).reduce((a,b) => a+b,0)).toBe(508)
        expect(Object.values(set.evs).every(v => v >= 0 && v <= 252)).toBe(true)
      }
    }
    expect(npcMembers(ids,builds,rng,'hard').every(m => Object.values(m.set.ivs).every(v => v === 31))).toBe(true)
  })
  it('allocates Mega, Gigantamax, Z and Tera separately without changing species or shared templates', () => {
    const original = JSON.stringify(builds)
    const ids = [6,68,25,445,376,242]
    const team = npcMembers(ids, builds, () => 0, 'hard')
    expect(team.map(m => m.id)).toEqual(ids)
    expect(team.filter(m => m.set.gimmick === 'mega')).toHaveLength(1)
    expect(team.filter(m => m.set.gimmick === 'dmax')).toHaveLength(1)
    expect(builds[team.find(m => m.set.gimmick === 'dmax').id].gmax).toBe(true)
    expect(team.filter(m => m.set.gimmick === 'z')).toHaveLength(1)
    expect(team.filter(m => m.set.gimmick === 'tera')).toHaveLength(3)
    const mega = team.find(m => m.set.gimmick === 'mega')
    expect(pokemon.find(p => p.name === items.mega[mega.set.item]).species).toBe(byId.get(mega.id).species)
    const z = team.find(m => m.set.gimmick === 'z')
    expect(z.set.moves.some(m => byMove.get(m).type === items.z[z.set.item])).toBe(true)
    expect(JSON.stringify(builds)).toBe(original)
  })
})

