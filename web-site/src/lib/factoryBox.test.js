import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { addToBox, BOX_SIZE, boxToSet, capture, emptyFactory, encounterFor, endRun, HUNT_MAX, huntAfter, huntBase, huntMultOf, huntNode, releaseFromBox, setHunt, startRun } from './factoryRun'

const data = JSON.parse(readFileSync(new URL('../../../assets/database/factory.json', import.meta.url), 'utf8'))

describe('PC (igual ao app)', () => {
  it('no fim da corrida o time vai para o PC, com quem saiu do time', () => {
    let run = startRun(emptyFactory(), data, 1, 42)
    run = { ...run, team: [...run.team, ...[0, 1, 2, 3, 4].map((i) => ({ ...run.team[0], id: 10 + i }))] }
    run = { ...run, pending: { ...run.pending, capture: { id: 415, level: 9 } } }
    const caught = capture(run, 2)
    expect(caught.pc.map((m) => m.id)).toEqual([11])
    const box = endRun(emptyFactory(), caught).box
    expect(box.map((b) => b.id)).toEqual([1, 10, 415, 12, 13, 14, 11])
    for (const k of ['id', 'level', 'nature', 'ivs', 'evs', 'moves', 'date']) expect(box[0]).toHaveProperty(k)
  })
  it('cabe 300, solta e vira membro de time', () => {
    const many = addToBox(null, Array.from({ length: 310 }, (_, i) => ({ id: 1 + (i % 5), level: 5 })), '2026-11-04')
    expect(many.length).toBe(BOX_SIZE)
    expect(releaseFromBox({ ...emptyFactory(), box: many.slice(0, 2) }, 0).box.length).toBe(1)
    const set = boxToSet({ id: 25, level: 140, nature: 'Timid', shiny: true, ivs: { spe: 31 }, evs: { spe: 400 }, moves: [] }, ['thunderbolt', 'quick-attack'])
    expect(set.level).toBe(100)
    expect(set.moves).toEqual(['thunderbolt', 'quick-attack', '', ''])
    expect(set.evs.spe).toBe(252)
    expect(set.shiny).toBe(true)
  })

  it('caça shiny: a chance do escolhido sobe com os encontros e zera quando acha', () => {
    expect(huntMultOf(0)).toBe(1)
    expect(huntMultOf(25)).toBe(3)
    expect(huntMultOf(999)).toBe(HUNT_MAX)
    expect(setHunt(emptyFactory(), data, 6).hunt).toEqual({ id: 4, count: 0, found: 0 })
    const run = startRun({ ...emptyFactory(), hunt: { id: 4, count: 37 } }, data, 1, 42)
    expect(run.hunt).toBe(4)
    expect(huntNode(run)).toEqual({ hunt: 4, huntMult: 4 })
    const lcg = (seed) => { let x = seed; return () => (x = (x * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff }
    const plain = encounterFor(data, 5, lcg(7), null, false, { kind: 'wild', biome: 'grass' })
    const id = plain.foes[0].id
    const hunted = encounterFor(data, 5, lcg(7), null, false, { kind: 'wild', biome: 'grass', hunt: huntBase(data, id), huntMult: 4096 })
    expect(hunted.foes[0].shiny).toBe(true)
    expect(hunted.foes[0].id).toBe(id)
    const hf = { ...emptyFactory(), hunt: { id: 4, count: 37, found: 0 } }
    expect(huntAfter(hf, { hunt: 4, huntSeen: 5 })).toEqual({ id: 4, count: 42, found: 0 })
    expect(huntAfter(hf, { hunt: 4, huntSeen: 5, huntFound: true })).toEqual({ id: 4, count: 0, found: 1 })
  })
})
