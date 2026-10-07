import { readFileSync, writeFileSync } from 'node:fs'
import { beforeAll, describe, expect, it, vi } from 'vitest'
import { battleMons, pickMoves } from './battleSetup'
import { seededRandom } from './league'
import { active, cpuPlan, canGimmick, canUseItem, effectLabel, lineOf, maxPower, moveEffect, newBattle, playTurn, replace, startBattle, switchMatchup, usableMoves, weaknesses, zPower } from './turnBattle'

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
const fakeHit = (att, def, slug, crit, power, weather = '') => {
  const found = att.moves.find((x) => x.slug === slug) ?? { power: 50, type: 'normal' }
  const m = { ...found, power: power ?? found.power }
  const eff = m.type === 'normal' && def.types.includes('ghost') ? 0 : m.type === 'water' && def.types.includes('fire') ? 2 : m.type === 'grass' && def.types.includes('fire') ? 0.5 : 1
  // Clima: chuva fortalece água e enfraquece fogo; sol, o contrário.
  const boosted = (weather === 'rain' && m.type === 'water') || (weather === 'sun' && m.type === 'fire')
  const weakened = (weather === 'rain' && m.type === 'fire') || (weather === 'sun' && m.type === 'water')
  const w = boosted ? 1.5 : weakened ? 0.5 : 1
  const roll = Array.from({ length: 16 }, (_, i) => Math.floor(((m.power * (85 + i)) / 100) * eff * w * 0.5))
  return { rolls: slug === 'double-hit' ? [roll, roll] : [roll], eff }
}
/** Registro dos eventos em texto (igual ao do teste do app). */
const writer = (log) => (events) => {
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
    else if (e.t === 'weather') log.push(`[weather ${e.weather}]`)
    else log.push(`[${e.t} ${e.side} ${e.hp ?? e.index ?? ''}]`.replace(' ]', ']'))
  }
}

/**
 * Batalha com clima: Sand Stream ao entrar, Rain Dance, Thunder (sempre acerta
 * na chuva), Swift Swim, Moonlight no clima, Drought quando o outro entra,
 * Sunny Day e o dano da areia. Igual ao do app (test/fixtures/turn_battle_weather.json).
 */
export function fakeWeatherLog() {
  const battle = newBattle(
    [
      mon(1, 'Chuva', ['water'], 300, 50, [
        move('rain-dance', 'water', 0, null, 5, 0, { w: 'rain', ok: 1 }, 'status'),
        move('thunder', 'electric', 110, 70, 10, 0, { x: [{ p: 30, s: 'par' }] }),
        move('water-gun', 'water', 40, 100, 25),
      ], { ability: 'Swift Swim' }),
    ],
    [
      mon(2, 'Areia', ['rock'], 100, 60, [move('rock-throw', 'rock', 50, 90, 15), move('moonlight', 'fairy', 0, null, 5, 0, { h: [1, 2], ok: 1 }, 'status')], { ability: 'Sand Stream' }),
      mon(3, 'Sol', ['fire'], 90, 40, [move('sunny-day', 'fire', 0, null, 5, 0, { w: 'sun', ok: 1 }, 'status'), move('ember', 'fire', 40, 100, 25)], { ability: 'Drought' }),
    ],
    seededRandom(7),
  )
  const log = []
  const write = writer(log)
  write(startBattle(battle))
  for (let turn = 0; turn < 40 && battle.winner == null; turn++) {
    const me = active(battle, 0)
    // Water Gun no primeiro (a areia machuca), depois Rain Dance sempre que
    // a chuva não está; senão Thunder.
    const pick = turn === 0 ? 2 : battle.weather !== 'rain' && me.moves[0].pp > 0 ? 0 : me.moves[1].pp > 0 ? 1 : 2
    write(playTurn(battle, { move: pick }, fakeHit))
    log.push(`clima: ${battle.weather || '-'} ${battle.weatherTurns}`)
  }
  log.push(`vencedor: ${battle.winner}`)
  return log
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
  const write = writer(log)
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

  it('clima igual ao app (mesma semente, mesmo registro)', () => {
    const file = new URL('../../../test/fixtures/turn_battle_weather.json', import.meta.url)
    if (process.env.WRITE_FIXTURE) writeFileSync(file, `${JSON.stringify(fakeWeatherLog(), null, 1)}\n`)
    const log = fakeWeatherLog()
    expect(log).toEqual(JSON.parse(readFileSync(file, 'utf8')))
    expect(log).toContain('Começou uma tempestade de areia!')
    expect(log).toContain('Começou a chover!')
    expect(log).toContain('A luz do sol ficou forte!')
  })

  it('clima com a calculadora: chuva fortalece Surf; Drizzle e Drought na habilidade', async () => {
    const { battleHit } = await import('./damageCalc')
    const [blastoise, zard, pelipper] = await battleMons([
      { id: 9, set: { level: 50, moves: ['surf'] } },
      { id: 6, set: { level: 50, item: 'Charizardite Y', moves: ['flamethrower'] } },
      { id: 279, set: { level: 50, ability: 'Drizzle', moves: ['hurricane'] } },
    ])
    const dry = battleHit(blastoise, zard, 'surf', false)
    const wet = battleHit(blastoise, zard, 'surf', false, undefined, 'Rain')
    expect(Math.max(...wet.rolls[0])).toBeGreaterThan(Math.max(...dry.rolls[0]))
    expect(pelipper.ability).toBe('Drizzle')
    expect(zard.mega.ability).toBe('Drought')
  }, 30000)

  it('formas pelo item: Primal e Crowned ao entrar; a Mega da própria forma', async () => {
    const [groudon, zacian, tatsugiri] = await battleMons([
      { id: 383, set: { level: 50, item: 'red-orb', moves: ['earthquake'] } },
      { id: 888, set: { level: 50, item: 'rusted-sword', moves: ['play-rough'] } },
      { id: 10258, set: { level: 50, item: 'tatsugirinite', moves: ['draco-meteor'] } },
    ])
    expect(groudon.id).toBe(10078)
    expect(zacian.id).toBe(10188)
    expect(tatsugiri.mega?.id).toBe(10323)
  }, 30000)

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
    expect(pickMoves(['roost', 'flamethrower'], Object.keys(moves), ['fire', 'flying'], moves)).toEqual(['roost', 'flamethrower', 'dragon-claw', 'scratch'])
  })

  it('limita a 50 antes de calcular HP, atributos, Mega e dano, sem mudar o time', async () => {
    const { battleHit } = await import('./damageCalc')
    const set = { level: 100, nature: 'Timid', item: 'charizardite-y', moves: ['flamethrower'], evs: { hp: 4, spa: 252, spe: 252 }, ivs: { atk: 0 } }
    const [capped, reference, lower, foe] = await battleMons([
      { id: 6, set }, { id: 6, set: { ...set, level: 50 } },
      { id: 6, set: { ...set, level: 10 } }, { id: 3, set: { level: 100, moves: ['tackle'] } },
    ])
    expect(capped.level).toBe(50); expect(capped.side.level).toBe(50)
    expect(capped.maxHp).toBe(154); expect(capped.spe).toBe(167)
    expect(capped.side.ivs.atk).toBe(0); expect(capped.side.evs.spa).toBe(252)
    expect(capped.mega.side.level).toBe(50)
    expect(capped.mega.spe).toBe(167)
    expect(capped.mega).toEqual(reference.mega)
    const actual = battleHit(capped, foe, 'flamethrower', false)
    expect(actual).not.toBeNull()
    expect(actual).toEqual(battleHit(reference, foe, 'flamethrower', false))
    expect([Math.min(...actual.rolls[0]), Math.max(...actual.rolls[0])]).toEqual([138, 164])
    expect(foe.level).toBe(50)
    expect(lower.level).toBe(10); expect(lower.maxHp).toBe(38); expect(lower.spe).toBe(37)
    expect(set.level).toBe(100)
  }, 30000)

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
      { id: 6, set: { level: 50, item: 'Charizardite Y', moves: ['flamethrower'], tera: 'grass', gimmick: 'mega' } },
      { id: 3, set: { level: 50, moves: ['giga-drain'] } },
    ])
    expect(zard.mega).toMatchObject({ id: 10035, name: 'Mega Charizard Y', types: ['fire', 'flying'] })
    expect(zard.gmax).toBe(10196)
    expect(zard.teraType).toBe('grass')
    expect(zard.gimmick).toBe('mega')
    // Regras dos jogos: sem a Mega Pedra não megaevolui; Cristal Z só no tipo dele.
    const [plain, zcrystal, zacian] = await battleMons([
      { id: 6, set: { level: 50, moves: ['flamethrower'] } },
      { id: 6, set: { level: 50, item: 'firium-z--held', moves: ['flamethrower', 'air-slash'] } },
      { id: 888, set: { level: 50, moves: ['play-rough'] } },
    ])
    expect(plain.mega).toBeNull()
    expect(zcrystal.zType).toBe('fire')
    expect(zacian.noDmax).toBe(true)
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


it('respeita a mecânica do set e bloqueia outro uso após trocar de Pokémon', () => {
  const member = (id) => mon(id, 'Mon', ['normal'], 100, 80, [move('tackle', 'normal', 40, 100, 10)], {
    gimmick: 'tera', teraType: 'grass', mega: { id: 10035, name: 'Mega', types: ['fire'], spe: 100 },
  })
  const battle = newBattle([member(6), member(9)], [member(25)], () => 0.9)
  expect(canGimmick(battle, 0, 'tera')).toBe(true)
  expect(canGimmick(battle, 0, 'mega')).toBe(false)
  expect(canGimmick(battle, 0, 'dmax')).toBe(false)
  playTurn(battle, { move: 0, gimmick: 'tera' }, fakeHit)
  expect(battle.gimmicks[0]).toBe('tera')
  playTurn(battle, { switch: 1 }, fakeHit)
  expect(active(battle, 0).id).toBe(9)
  expect(canGimmick(battle, 0, 'tera')).toBe(false)
})

describe('computador usa vantagem, trocas e bolsa', () => {
  const member = (id, type, spe = 80) => mon(id, 'Mon', [type], 100, spe, [move(type, type, 40, 100, 10)])
  const hit = (att, def, slug) => {
    const type = att.moves.find((m) => m.slug === slug).type
    const eff = type === 'water' && def.types.includes('fire') ? 2 : type === 'water' && def.types.includes('grass') ? 0.5 : 1
    return { rolls: [[40 * eff]], eff }
  }
  it('troca para resistir e atacar melhor, sem atacar no turno da troca', () => {
    const b = newBattle([member(1, 'water')], [member(2, 'fire'), member(3, 'grass')], () => 0.9)
    expect(cpuPlan(b, hit)).toEqual({ kind: 'switch', index: 1 })
    const events = playTurn(b, { move: 0, gimmick: 'none' }, hit)
    expect(active(b, 1).id).toBe(3)
    expect(active(b, 0).hp).toBe(100)
    expect(events.some((e) => e.t === 'switch' && e.side === 1)).toBe(true)
    expect(cpuPlan(b, hit).kind).not.toBe('switch')
  })
  it('cura, gasta o item e não desperdiça turno quando consegue finalizar', () => {
    const b = newBattle([member(1, 'normal', 60)], [member(2, 'normal')], () => 0.9)
    active(b, 1).hp = 25
    expect(cpuPlan(b, hit)).toEqual({ kind: 'item', item: 'hyper-potion', target: 0 })
    playTurn(b, { move: 0, gimmick: 'none' }, hit)
    expect(b.bags[1]['hyper-potion']).toBe(0)
    expect(active(b, 0).hp).toBe(100)
    active(b, 1).hp = 25; active(b, 0).hp = 20
    expect(cpuPlan(b, hit).kind).toBe('move')
  })
  it('prioriza golpe vantajoso; Revive só quando não consegue causar dano', () => {
    const b = newBattle([member(1, 'fire')], [member(2, 'normal'), member(3, 'grass')], () => 0)
    active(b, 1).moves.push(move('water', 'water', 40, 100, 10))
    expect(cpuPlan(b, hit)).toEqual({ kind: 'move', index: 1 })
    b.sides[1].team[1].hp = 0
    // Pode atacar: ataca (cada item é um turno sem atacar).
    expect(cpuPlan(b, hit)).toEqual({ kind: 'move', index: 1 })
    const harmless = (att, def, slug) => (att === active(b, 1) ? { rolls: [[0]], eff: 0 } : hit(att, def, slug))
    expect(cpuPlan(b, harmless)).toEqual({ kind: 'item', item: 'revive', target: 1 })
  })
})
