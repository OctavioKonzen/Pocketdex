import { readFileSync, writeFileSync } from 'node:fs'
import { beforeAll, describe, expect, it, vi } from 'vitest'
import { battleMons, pickMoves } from './battleSetup'
import { seededRandom } from './league'
import { active, lineOf, newBattle, playTurn, replace, usableMoves } from './turnBattle'

beforeAll(() => {
  vi.stubGlobal('fetch', async (url) => {
    const file = new URL(`../../public/data/${String(url).split('/data/')[1]}`, import.meta.url)
    return { ok: true, json: async () => JSON.parse(readFileSync(file, 'utf8')) }
  })
})

// Batalha de mentira (dano simples, sem a calculadora), a mesma do teste do
// app (test/turn_battle_test.dart): os dois têm que dar exatamente o mesmo
// registro, guardado em test/fixtures/turn_battle.json.
const move = (slug, type, power, accuracy, pp, priority = 0) => ({ slug, name: slug, type, power, accuracy, pp, maxPp: pp, priority })
const mon = (id, name, types, hp, spe, moves) => ({ id, name, level: 50, maxHp: hp, hp, spe, types, moves })
const fakeHit = (att, def, slug) => {
  const m = att.moves.find((x) => x.slug === slug) ?? { power: 50, type: 'normal' }
  const eff = m.type === 'normal' && def.types.includes('ghost') ? 0 : m.type === 'water' && def.types.includes('fire') ? 2 : m.type === 'grass' && def.types.includes('fire') ? 0.5 : 1
  const roll = Array.from({ length: 16 }, (_, i) => Math.floor(((m.power * (85 + i)) / 100) * eff * 0.5))
  return { rolls: slug === 'double-hit' ? [roll, roll] : [roll], eff }
}
export function fakeBattleLog() {
  const battle = newBattle(
    [
      mon(1, 'Azul', ['water'], 110, 80, [move('water-gun', 'water', 60, 100, 3), move('quick-attack', 'normal', 40, 100, 30, 1), move('double-hit', 'normal', 35, 90, 10)]),
      mon(2, 'Verde', ['grass'], 100, 60, [move('vine-whip', 'grass', 45, 100, 25), move('tackle', 'normal', 40, 100, 35)]),
    ],
    [
      mon(3, 'Fogo', ['fire'], 120, 90, [move('ember', 'fire', 60, 100, 25), move('scratch', 'normal', 40, 95, 35)]),
      mon(4, 'Fantasma', ['ghost'], 90, 70, [move('lick', 'ghost', 50, 100, 30), move('shadow-sneak', 'ghost', 40, 100, 30, 1)]),
    ],
    seededRandom(42),
  )
  const log = []
  const write = (events) => {
    for (const e of events) {
      if (e.t === 'text') {
        const [line, args] = lineOf(e)
        log.push(args.reduce((text, arg, i) => text.replace(`{${i}}`, arg), line))
      } else if (e.t === 'attack') log.push(`[attack ${e.side} ${e.type}]`)
      else log.push(`[${e.t} ${e.side} ${e.hp ?? e.index ?? ''}]`.replace(' ]', ']'))
    }
  }
  for (let turn = 0; turn < 60 && battle.winner == null; turn++) {
    if (battle.needSwitch) {
      write(replace(battle, battle.sides[0].team.findIndex((m) => m.hp > 0)))
      continue
    }
    const me = active(battle, 0)
    // Troca uma vez no turno 2; fora isso, o primeiro golpe com PP.
    if (turn === 2 && battle.sides[0].team[1].hp > 0) write(playTurn(battle, { switch: 1 }, fakeHit))
    else write(playTurn(battle, { move: usableMoves(me)[0] ?? -1 }, fakeHit))
  }
  log.push(`vencedor: ${battle.winner}`)
  return log
}

describe('batalha por turnos', () => {
  it('igual ao app (mesma semente, mesmo registro)', () => {
    const file = new URL('../../../test/fixtures/turn_battle.json', import.meta.url)
    // WRITE_FIXTURE=1 npx vitest run turnBattle → refaz o arquivo.
    if (process.env.WRITE_FIXTURE) writeFileSync(file, `${JSON.stringify(fakeBattleLog(), null, 1)}\n`)
    const expected = JSON.parse(readFileSync(file, 'utf8'))
    expect(fakeBattleLog()).toEqual(expected)
  })

  it('escolhe os golpes: os do set e, se faltar, um de cada tipo', () => {
    const moves = {
      flamethrower: { type: 'fire', category: 'special', power: 90, accuracy: 100 },
      'fire-blast': { type: 'fire', category: 'special', power: 110, accuracy: 85 },
      'air-slash': { type: 'flying', category: 'special', power: 75, accuracy: 95 },
      'dragon-claw': { type: 'dragon', category: 'physical', power: 80, accuracy: 100 },
      'hyper-beam': { type: 'normal', category: 'special', power: 150, accuracy: 90 },
      roost: { type: 'flying', category: 'status', power: null, accuracy: null },
      scratch: { type: 'normal', category: 'physical', power: 40, accuracy: 100 },
    }
    expect(pickMoves(['roost', 'flamethrower'], Object.keys(moves), ['fire', 'flying'], moves)).toEqual(['flamethrower', 'air-slash', 'dragon-claw', 'scratch'])
  })

  it('monta os Pokémon com a calculadora', async () => {
    const [charizard] = await battleMons([{ id: 6, set: { level: 50, nature: 'Timid', moves: ['flamethrower', 'roost'], evs: { hp: 4, spa: 252, spe: 252 } } }])
    expect(charizard.maxHp).toBe(154)
    expect(charizard.spe).toBe(167)
    expect(charizard.moves).toHaveLength(4)
    expect(charizard.moves[0]).toMatchObject({ slug: 'flamethrower', name: 'Flamethrower', pp: 15 })
  }, 30000)
})
