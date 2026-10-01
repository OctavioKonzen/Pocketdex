import { readFileSync, writeFileSync } from 'node:fs'
import { beforeAll, describe, expect, it, vi } from 'vitest'
import { battleMons, pickMoves } from './battleSetup'
import { seededRandom } from './league'
import { active, canUseItem, effectLabel, lineOf, maxPower, moveEffect, newBattle, playTurn, replace, switchMatchup, usableMoves, weaknesses, zPower } from './turnBattle'

beforeAll(() => {
  vi.stubGlobal('fetch', async (url) => {
    const file = new URL(`../../public/data/${String(url).split('/data/')[1]}`, import.meta.url)
    return { ok: true, json: async () => JSON.parse(readFileSync(file, 'utf8')) }
  })
})

// Batalha de mentira (dano simples, sem a calculadora), a mesma do teste do
// app (test/turn_battle_test.dart): os dois têm que dar exatamente o mesmo
// registro, guardado em test/fixtures/turn_battle.json.
const move = (slug, type, power, accuracy, pp, priority = 0, rules = null, category = 'physical') => ({
  slug,
  name: slug,
  type,
  category,
  power,
  accuracy,
  pp,
  maxPp: pp,
  priority,
  ...(rules ? { rules } : {}),
})
const mon = (id, name, types, hp, spe, moves, extra = {}) => ({ id, name, level: 50, maxHp: hp, hp, spe, types, moves, teraType: types[0], ...extra })
const fakeHit = (att, def, slug, crit, power) => {
  const found = att.moves.find((x) => x.slug === slug) ?? { power: 50, type: 'normal' }
  const m = { ...found, power: power ?? found.power }
  const eff = m.type === 'normal' && def.types.includes('ghost') ? 0 : m.type === 'water' && def.types.includes('fire') ? 2 : m.type === 'grass' && def.types.includes('fire') ? 0.5 : 1
  const roll = Array.from({ length: 16 }, (_, i) => Math.floor(((m.power * (85 + i)) / 100) * eff * 0.5))
  return { rolls: slug === 'double-hit' ? [roll, roll] : [roll], eff }
}
export function fakeBattleLog() {
  const battle = newBattle(
    [
      mon(1, 'Azul', ['water'], 110, 80, [
        move('water-gun', 'water', 60, 100, 3, 0, { d: [1, 2], c: 1 }),
        move('quick-attack', 'normal', 40, 100, 30, 1),
        move('double-hit', 'normal', 35, 90, 10, 0, { x: [{ p: 50, f: 1 }] }),
      ]),
      mon(2, 'Verde', ['grass'], 100, 60, [
        move('toxic', 'poison', 0, 90, 2, 0, { s: 'tox', ok: 1 }, 'status'),
        move('swords-dance', 'normal', 0, null, 1, 0, { b: { atk: 2 }, t: 'self', ok: 1 }, 'status'),
        move('vine-whip', 'grass', 45, 100, 25, 0, { r: [1, 3], sb: { def: -1 } }),
        move('tackle', 'normal', 40, 100, 35),
      ]),
    ],
    [
      mon(3, 'Fogo', ['fire'], 120, 90, [move('ember', 'fire', 60, 100, 25, 0, { x: [{ p: 60, s: 'brn' }] }), move('scratch', 'normal', 40, 95, 35)], {
        mega: { id: 30, name: 'Mega Fogo', types: ['fire', 'dragon'], spe: 110 },
      }),
      mon(4, 'Fantasma', ['ghost'], 90, 70, [
        move('lick', 'ghost', 50, 100, 30, 0, { x: [{ p: 70, s: 'par' }, { p: 40, b: { spe: -1 } }] }),
        move('shadow-sneak', 'ghost', 40, 100, 30, 1),
        move('recover', 'normal', 0, null, 5, 0, { h: [1, 2], ok: 1 }, 'status'),
      ]),
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
      else if (e.t === 'status') log.push(`[status ${e.side} ${e.status}]`)
      else if (e.t === 'heal') log.push(`[heal ${e.side} ${e.index} ${e.hp}]`)
      else if (e.t === 'mega') log.push(`[mega ${e.side} ${e.id}]`)
      else if (e.t === 'tera') log.push(`[tera ${e.side} ${e.type}]`)
      else if (e.t === 'dmax') log.push(`[dmax ${e.side} ${e.on ? 1 : 0} ${e.id}]`)
      else log.push(`[${e.t} ${e.side} ${e.hp ?? e.index ?? ''}]`.replace(' ]', ']'))
    }
  }
  for (let turn = 0; turn < 60 && battle.winner == null; turn++) {
    if (battle.needSwitch) {
      write(replace(battle, battle.sides[0].team.findIndex((m) => m.hp > 0)))
      continue
    }
    const me = active(battle, 0)
    const fainted = battle.sides[0].team.findIndex((m) => m.hp <= 0)
    // Troca uma vez no turno 2, usa uma Super Potion no 5 e revive quem
    // desmaiou; fora isso, o primeiro golpe com PP.
    // Dinamax no primeiro turno (o computador escolhe a dele sozinho).
    if (turn === 0) write(playTurn(battle, { move: 0, gimmick: 'dmax' }, fakeHit))
    else if (turn === 2 && battle.sides[0].team[1].hp > 0) write(playTurn(battle, { switch: 1 }, fakeHit))
    else if (turn === 5 && canUseItem(battle, 0, 'super-potion', battle.sides[0].active))
      write(playTurn(battle, { item: 'super-potion', target: battle.sides[0].active }, fakeHit))
    else if (fainted >= 0 && canUseItem(battle, 0, 'revive', fainted)) write(playTurn(battle, { item: 'revive', target: fainted }, fakeHit))
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

  it('mecânicas com a calculadora: Mega, Z-Move e Tera', async () => {
    const { battleHit } = await import('./damageCalc')
    const [zard, venu] = await battleMons([
      { id: 6, set: { level: 50, item: 'Charizardite Y', moves: ['flamethrower'], teraType: 'grass' } },
      { id: 3, set: { level: 50, moves: ['giga-drain'] } },
    ])
    expect(zard.mega).toMatchObject({ id: 10035, name: 'Mega Charizard Y', types: ['fire', 'flying'] })
    expect(zard.gmax).toBe(10196)
    expect(zard.teraType).toBe('grass')
    const normal = battleHit(zard, venu, 'flamethrower', false)
    const z = battleHit(zard, venu, 'flamethrower', false, 175)
    expect(Math.max(...z.rolls[0])).toBeGreaterThan(Math.max(...normal.rolls[0]))
    // Terastal em Grama: Giga Drain deixa de ser ×¼ (Fogo/Voador) e vira ×½ (Grama).
    const tera = { ...zard, side: { ...zard.side, terastallized: true, teraType: 'grass' } }
    expect(battleHit({ ...venu, moves: venu.moves }, zard, 'giga-drain', false).eff).toBe(0.25)
    expect(battleHit(venu, tera, 'giga-drain', false).eff).toBe(0.5)
  }, 30000)
})

describe('efetividade na tela', () => {
  const chart = { water: { fire: 2, grass: 0.5 }, electric: { ground: 0, water: 2 }, normal: {}, ground: { electric: 2, fire: 2 } }
  const typeEff = (t, types) => types.reduce((m, d) => m * (chart[t]?.[d] ?? 1), 1)
  const hit = (att, def, slug) => ({ rolls: [[1]], eff: typeEff(slug, def.types) })
  const mv = (slug, category = 'special') => ({ slug, type: slug, category })
  const mon = (types, moves) => ({ types, moves })

  it('golpe: super, pouco, não afeta, status', () => {
    const fire = mon(['fire'], [])
    const att = mon(['water'], [])
    expect(effectLabel(moveEffect(hit, att, fire, mv('water')))).toBe('Super efetivo')
    expect(effectLabel(moveEffect(hit, att, mon(['grass'], []), mv('water')))).toBe('Pouco efetivo')
    expect(effectLabel(moveEffect(hit, att, mon(['ground'], []), mv('electric')))).toBe('Não afeta')
    expect(effectLabel(moveEffect(hit, att, fire, mv('normal')))).toBe('Efetivo')
    expect(moveEffect(hit, att, fire, mv('water', 'status'))).toBeNull()
  })

  it('troca e fraquezas', () => {
    const foe = mon(['fire'], [mv('normal')])
    const m = switchMatchup(hit, mon(['water'], [mv('water'), mv('normal')]), foe, typeEff)
    expect(m).toEqual({ attack: 2, defense: 1 })
    expect(weaknesses(['fire'], ['water', 'electric', 'normal', 'ground'], typeEff)).toEqual([
      { type: 'water', mult: 2 },
      { type: 'ground', mult: 2 },
    ])
  })
})

describe('mecânicas especiais', () => {
  it('poder do Z-Move e do Max Move (tabelas dos jogos)', () => {
    expect([40, 60, 70, 80, 90, 100, 110, 120, 130, 150].map(zPower)).toEqual([100, 120, 140, 160, 175, 180, 185, 190, 195, 200])
    expect([40, 50, 60, 70, 100, 140, 150].map((p) => maxPower(p, 'fire'))).toEqual([90, 100, 110, 120, 130, 140, 150])
    expect([40, 100, 150].map((p) => maxPower(p, 'fighting'))).toEqual([70, 90, 100])
  })
})

