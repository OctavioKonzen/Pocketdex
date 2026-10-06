import { readFileSync, writeFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { fxPlan, moveAnim, TYPE_PARTICLE } from './moveAnim'

const moves = JSON.parse(readFileSync(new URL('../../public/data/moves.json', import.meta.url), 'utf8'))

const KINDS = ['tackle', 'punch', 'kick', 'bite', 'slash', 'orb', 'beam', 'stream', 'volley', 'bolt', 'quake', 'rocks', 'meteor', 'wave', 'wind', 'rings', 'drain',
  'boost', 'drop', 'heal', 'shield', 'wall', 'powder', 'status', 'hazard', 'weather', 'terrain', 'field', 'charge', 'explode', 'spin', 'dive', 'pierce', 'whip', 'swap']

describe('animação dos golpes', () => {
  it('cada golpe no seu estilo', () => {
    const kind = (slug) => moveAnim(slug, moves[slug].type, moves[slug].category)
    expect(kind('thunder-punch')).toBe('punch')
    expect(kind('flamethrower')).toBe('stream')
    expect(kind('hydro-pump')).toBe('stream')
    expect(kind('thunderbolt')).toBe('bolt')
    expect(kind('surf')).toBe('wave')
    expect(kind('earthquake')).toBe('quake')
    expect(kind('ice-beam')).toBe('beam')
    expect(kind('crunch')).toBe('bite')
    expect(kind('leaf-blade')).toBe('slash')
    expect(kind('rock-slide')).toBe('rocks')
    expect(kind('draco-meteor')).toBe('meteor')
    expect(kind('hurricane')).toBe('wind')
    expect(kind('psychic')).toBe('rings')
    expect(kind('giga-drain')).toBe('drain')
    expect(kind('bullet-seed')).toBe('volley')
    expect(kind('shadow-ball')).toBe('orb')
    expect(kind('tackle')).toBe('tackle')
  })

  it('igual ao app (todos os golpes do banco)', () => {
    const all = Object.fromEntries(
      Object.keys(moves)
        .filter((slug) => moves[slug].category !== 'status')
        .sort()
        .map((slug) => [slug, moveAnim(slug, moves[slug].type, moves[slug].category)]),
    )
    const file = new URL('../../../test/fixtures/move_anims.json', import.meta.url)
    // WRITE_FIXTURE=1 npx vitest run moveAnim → refaz o arquivo.
    if (process.env.WRITE_FIXTURE) writeFileSync(file, `${JSON.stringify(all, null, 1)}\n`)
    expect(all).toEqual(JSON.parse(readFileSync(file, 'utf8')))
  })

  it('toda animação tem peças e todo tipo tem partícula', () => {
    for (const kind of KINDS) expect(fxPlan(kind, 'fire', 0, { x: 24, y: 70 }, { x: 76, y: 26 }).parts.length).toBeGreaterThan(0)
    for (const m of Object.values(moves)) expect(TYPE_PARTICLE[m.type] ?? null).not.toBeNull()
  })

  it('cada golpe com a sua animação (move_anims.json): nenhuma repetida', () => {
    const table = JSON.parse(readFileSync(new URL('../../public/data/move_anims.json', import.meta.url), 'utf8'))
    const keys = Object.values(table).map((x) => x.join('|'))
    expect(new Set(keys).size).toBe(keys.length)
    for (const [kind] of Object.values(table)) expect(KINDS).toContain(kind)
    expect(table['ice-punch'].slice(0, 2)).toEqual(['punch', '🧊'])
    expect(table.thunderbolt.slice(0, 2)).toEqual(['bolt', '⚡'])
    // Todos os golpes, inclusive os de status, cada um com a sua.
    for (const slug of Object.keys(moves)) expect(table[slug], slug).toBeDefined()
    expect(table['swords-dance'].slice(0, 2)).toEqual(['boost', '⚔️'])
    expect(table.toxic.slice(0, 2)).toEqual(['status', '☠️'])
    expect(table['rain-dance'].slice(0, 2)).toEqual(['weather', '🌧️'])
    expect(table['stealth-rock'].slice(0, 2)).toEqual(['hazard', '🪨'])
    expect(table.protect[0]).toBe('shield')
    expect(table.recover[0]).toBe('heal')
  })

  it('peças iguais às do app (test/fixtures/fx_plans.json)', () => {
    const all = {}
    for (const kind of KINDS)
      for (let v = 0; v < 6; v++) all[`${kind}/${v}`] = fxPlan(kind, 'water', v % 2, { x: 24, y: 69 }, { x: 75, y: 25 }, v % 3 ? '🧊' : null, v)
    const file = new URL('../../../test/fixtures/fx_plans.json', import.meta.url)
    if (process.env.WRITE_FIXTURE) writeFileSync(file, `${JSON.stringify(all)}\n`)
    const expected = JSON.parse(readFileSync(file, 'utf8'))
    expect(JSON.parse(JSON.stringify(all))).toEqual(expected)
  })
})
