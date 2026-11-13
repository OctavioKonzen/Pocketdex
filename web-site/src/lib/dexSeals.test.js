import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { buildSeals, doneSeals, sealDone, sealHave } from './dexSeals'

const rows = JSON.parse(readFileSync(new URL('../../../assets/database/pokemon.json', import.meta.url), 'utf8'))

describe('selos da Pokédex (igual ao app)', () => {
  it('9 regiões e 18 tipos, só as formas normais', () => {
    const seals = buildSeals(rows)
    expect(seals.length).toBe(27)
    const kanto = seals.find((s) => s.id === 'kanto')
    expect(kanto.ids.size).toBe(151)
    expect(seals.find((s) => s.id === 'paldea').ids.size).toBe(1025 - 905)
    const caught = new Set(kanto.ids)
    expect(sealDone(kanto, caught)).toBe(true)
    expect(doneSeals(seals, caught)).toContain('kanto')
    expect(sealDone(seals.find((s) => s.id === 'type-fire'), caught)).toBe(false)
    expect(sealHave(seals.find((s) => s.id === 'johto'), caught)).toBe(0)
  })
  it('funciona com o índice do site (default em vez de is_default)', () => {
    const index = rows.map((r) => ({ id: r.id, default: r.is_default, types: r.types }))
    expect(buildSeals(index).find((s) => s.id === 'kanto').ids.size).toBe(151)
  })
})
