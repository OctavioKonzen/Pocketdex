import {it, expect} from 'vitest'
import {readFileSync} from 'node:fs'
import '../../../assets/database/battle_engine.js'

const canonical = value => Array.isArray(value) ? value.map(canonical) : value && typeof value === 'object' ? Object.fromEntries(Object.keys(value).sort().map(key => [key, canonical(value[key])])) : value
const comparable = state => ({turn: state.turn, winner: state.winner, weather: state.weather, terrain: state.terrain,
  sides: state.sides.map(side => ({active: side.active, forceSwitch: side.forceSwitch, wait: side.wait,
    team: side.team.map(p => ({hp: p.hp, maxHp: p.maxHp, status: p.status, boosts: p.boosts,
      species: p.species, types: p.types, ability: p.ability, item: p.item, tera: p.tera, dmax: p.dmax,
      moves: p.moves.map(m => ({slug: m.slug, pp: m.pp, maxPp: m.maxPp, disabled: Boolean(m.disabled)}))}))}))})

it('All 919 moves match the standalone reference in the browser bundle', () => {
  const fixtures = JSON.parse(readFileSync(new URL('../../../test/fixtures/battle_move_reference.json', import.meta.url), 'utf8'))
  expect(fixtures).toHaveLength(919)
  const sim = globalThis.PocketDexSim
  for (const fixture of fixtures) {
    const game = sim.create(fixture.input)
    try {
      for (const step of fixture.steps) {
        const next = sim.choose(game.handle, step.actions)
        expect(JSON.stringify(canonical(comparable(next.state))), fixture.slug).toBe(step.expected)
      }
    } finally { sim.dispose(game.handle) }
  }
}, 120000)
