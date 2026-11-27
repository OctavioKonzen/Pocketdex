import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { ACHIEVEMENTS, addToHistory, capture, capturedMon, captureFor, emptyFactory, endRun, genderOf, progress, regionalEncounter, startRun, tradePieces, withSeen } from './factoryRun'

const data = JSON.parse(readFileSync(new URL('../../../assets/database/factory.json', import.meta.url), 'utf8'))
const base = () => startRun(emptyFactory(), data, 1, 42)

describe('rodada 6 (igual ao app)', () => {
  it('troca de itens da árvore: 3 de um por 1 de outro', () => {
    const f = { ...emptyFactory(), pieces: { 'key-stone': 4 } }
    expect(tradePieces(f, 'key-stone', 'relic-crown').pieces).toEqual({ 'key-stone': 1, 'sparkling-stone': 0, 'comet-shard': 0, 'relic-crown': 1 })
    expect(tradePieces({ ...f, pieces: { 'key-stone': 2 } }, 'key-stone', 'relic-crown')).toBe(null)
    expect(tradePieces(f, 'key-stone', 'key-stone')).toBe(null)
  })

  it('captura: a tela vê antes quem entra (gênero e Nature) e é o mesmo que entra', () => {
    const run = { ...base(), pending: { capture: { id: 415, level: 10 } } }
    const preview = capturedMon(run)
    const after = capture(run)
    expect(after.team[after.team.length - 1]).toEqual(preview)
    expect(['M', 'F']).toContain(genderOf(data, preview))
  })

  it('modos: monotipo só captura do tipo do inicial; sem itens; formas regionais em qualquer região', () => {
    const mono = startRun(emptyFactory(), data, 1, 42, false, { modes: ['mono'] })
    expect(mono.mono).toEqual(['grass', 'poison'])
    expect(captureFor({ ...mono, encounter: { kind: 'wild', foes: [{ id: 16 }] } }, data)).toBe(null)
    expect(captureFor({ ...mono, encounter: { kind: 'wild', foes: [{ id: 43 }] } }, data)).not.toBe(null)
    const empty = startRun(emptyFactory(), data, 1, 42, false, { modes: ['noItems'] })
    expect(Object.values(empty.bag).every((n) => n === 0)).toBe(true)
    const regional = startRun(emptyFactory(), data, 1, 42, false, { modes: ['regionalAll'] })
    const kanto = { ...regional, boss: { region: data.bosses.findIndex((b) => b.region === 'Kanto'), step: 0 } }
    expect(regionalEncounter(data, kanto, { kind: 'wild', foes: [{ id: 52, level: 9 }] }).foes[0].id).toBe(10107)
    expect(regionalEncounter(data, kanto, { kind: 'wild', foes: [{ id: 194, level: 9 }] }).foes[0].id).toBe(10253)
  })

  it('histórico: as últimas 10 corridas, a mais nova primeiro', () => {
    let f = emptyFactory()
    for (let i = 2; i <= 13; i++) f = endRun(f, { ...base(), floor: i, nuzlocke: i === 13 })
    expect(f.history).toHaveLength(10)
    expect(f.history[0]).toMatchObject({ floor: 12, modes: ['nuzlocke'] })
    expect(f.history[0].summary.team.length).toBeGreaterThan(0)
    expect(addToHistory([], { ...base(), floor: 5, mono: ['grass'] }, 10, '2026-01-01')[0]).toMatchObject({ date: '2026-01-01', floor: 4, coins: 10, modes: ['mono'] })
  })

  it('conquistas novas: Shedinja, os três Hitmon e 5 formas regionais (contando a conta)', () => {
    expect(ACHIEVEMENTS.shedinja && ACHIEVEMENTS.hitmons && ACHIEVEMENTS.regional5).toBeTruthy()
    const run = { ...base(), team: [...base().team, { ...base().team[0], id: 292 }] }
    const [f] = progress({ ...emptyFactory(), caught: [106, 107, 237, 10091, 10107, 10161, 10229, 10253] }, run)
    expect(f.achievements).toEqual(expect.arrayContaining(['shedinja', 'hitmons', 'regional5']))
  })

  it('Pokédex: a forma regional marca também a espécie', () => {
    const f = withSeen({ ...emptyFactory(), run: { ...base(), team: [{ id: 10161 }], encounter: { foes: [{ id: 10107 }] } } }, data)
    expect(f.caught).toEqual(expect.arrayContaining([10161, 52]))
    expect(f.seen).toEqual(expect.arrayContaining([10107, 52]))
  })
})
