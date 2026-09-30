import { readFileSync, writeFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { fxPlan, moveAnim, TYPE_PARTICLE } from './moveAnim'

const moves = JSON.parse(readFileSync(new URL('../../public/data/moves.json', import.meta.url), 'utf8'))

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
    for (const kind of ['tackle', 'punch', 'kick', 'bite', 'slash', 'orb', 'beam', 'stream', 'volley', 'bolt', 'quake', 'rocks', 'meteor', 'wave', 'wind', 'rings', 'drain'])
      expect(fxPlan(kind, 'fire', 0, { x: 24, y: 70 }, { x: 76, y: 26 }).parts.length).toBeGreaterThan(0)
    for (const m of Object.values(moves)) expect(TYPE_PARTICLE[m.type] ?? null).not.toBeNull()
  })
})
