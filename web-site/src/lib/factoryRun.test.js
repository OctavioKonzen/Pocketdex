import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import {
  buyItem, buyPokemon, capture, CARDS, emptyFactory, encounterFor, endRun, expAt, foeMember, HELD_BONUS, levelTo, MAX_TEAM, memberOf,
  movesAt, nextFloor, nextRandom, pokemonPrice, runCoins, startersOf, startRun, takeCard, winFloor,
} from './factoryRun'

const data = JSON.parse(readFileSync(new URL('../../../assets/database/factory.json', import.meta.url), 'utf8'))
const moves = Object.fromEntries(JSON.parse(readFileSync(new URL('../../../assets/database/moves.json', import.meta.url), 'utf8')).map((m) => [m.name, { ...m, category: m.damage_class }]))
const forms = Object.fromEntries(JSON.parse(readFileSync(new URL('../../../assets/database/pokemon.json', import.meta.url), 'utf8')).map((p) => [p.id, p]))
const seq = (values) => { let i = 0; return () => values[i++ % values.length] }

describe('Battle Factory (subir andares)', () => {
  it('começa com um inicial grátis no nível 5; os outros só comprando', () => {
    const f = emptyFactory()
    expect(startRun(f, data, 150, 1)).toBe(null)
    const run = startRun(f, data, 1, 42)
    expect(run.team).toHaveLength(1)
    expect(run.team[0]).toMatchObject({ id: 1, level: 5, exp: expAt(5), item: null })
    expect(run.floor).toBe(1)
    expect(['wild', 'trainer']).toContain(run.encounter.kind)
    // Mesma semente, mesma corrida (e o mesmo que o app sorteia: test/factory_run_test.dart).
    expect(startRun(f, data, 1, 42)).toEqual(run)
    expect(run.seed).toBe(1135788988)
    expect(run.team[0].ivs).toEqual({ hp: 25, atk: 22, def: 29, spa: 26, spd: 17, spe: 23 })
    expect(run.team[0].nature).toBe('Docile')
    expect(run.encounter).toEqual({ kind: 'wild', foes: [{ id: 403, level: 3, iv: 0 }] })
  })

  it('o sorteio é o mulberry32 (o app usa o mesmo)', () => {
    expect(nextRandom(1)[0]).toBeCloseTo(0.6270739405881613, 12)
    expect(nextRandom(nextRandom(1)[1])[0]).toBeCloseTo(0.002735721180215478, 12)
  })

  it('andares: selvagem, treinador e lendário (só a partir do 10º); os níveis sobem com o andar', () => {
    const kinds = new Set()
    let state = 7
    const rand = () => { const [v, s] = nextRandom(state); state = s; return v }
    for (let i = 0; i < 400; i++) kinds.add(encounterFor(data, 12, rand).kind)
    expect([...kinds].sort()).toEqual(['legendary', 'trainer', 'wild'])
    for (let i = 0; i < 100; i++) expect(encounterFor(data, 3, rand).kind).not.toBe('legendary')
    const low = encounterFor(data, 1, seq([0.5, 0.9, 0.1])), high = encounterFor(data, 40, seq([0.5, 0.9, 0.1]))
    expect(low.foes[0].level).toBeLessThan(high.foes[0].level)
    expect(encounterFor(data, 1, seq([0.5, 0.9, 0.1])).foes[0].level).toBeLessThanOrEqual(6)
  })

  it('venceu: XP para o time, dinheiro, andar seguinte; selvagem dá para capturar', () => {
    let run = startRun(emptyFactory(), data, 4, 3)
    run = { ...run, encounter: { kind: 'wild', foes: [{ id: 19, level: 5, iv: 0 }] } }
    const after = winFloor(run, data)
    expect(after.floor).toBe(2)
    expect(after.defeated).toBe(1)
    expect(after.money).toBe(40)
    expect(after.team[0].exp).toBe(expAt(5) + Math.floor((data.species[19][0] * 5) / 7))
    expect(after.pending.capture).toEqual({ id: 19, level: 5, iv: 0 })
    const caught = capture(after)
    expect(caught.team.map((m) => m.id)).toEqual([4, 19])
    expect(caught.team[1].level).toBe(5)
    // Treinador: sem captura e dinheiro em dobro.
    const t = winFloor({ ...run, encounter: { kind: 'trainer', foes: [{ id: 19, level: 5, iv: 0 }] } }, data)
    expect(t.pending.capture).toBe(null)
    expect(t.money).toBe(80)
  })

  it('time cheio (6): captura trocando um, ou deixa passar', () => {
    let run = startRun(emptyFactory(), data, 7, 9)
    run = { ...run, team: Array.from({ length: MAX_TEAM }, () => run.team[0]), pending: { capture: { id: 25, level: 9, iv: 3 } } }
    expect(capture(run)).toBe(run)
    expect(capture(run, 2).team[2].id).toBe(25)
  })

  it('sobe de nível e evolui (Bulbasaur no 16 vira Ivysaur, no 32 Venusaur)', () => {
    const rand = () => 0
    const [mon, evolved] = levelTo({ id: 1, level: 15, exp: expAt(15), bonus: {} }, 16, data, rand)
    expect([mon.id, evolved]).toEqual([2, 2])
    expect(levelTo({ id: 1, level: 15, exp: 0 }, 40, data, rand)[0].id).toBe(3)
  })

  it('loja a cada 5 andares; carta a cada 10', () => {
    let run = startRun(emptyFactory(), data, 1, 5)
    run = { ...run, floor: 10, encounter: { kind: 'trainer', foes: [{ id: 19, level: 12, iv: 0 }] } }
    const after = winFloor(run, data)
    expect(after.pending.shop).toContain('rare-candy')
    expect(after.pending.cards).toHaveLength(3)
    const card = after.pending.cards[0]
    const taken = takeCard(after, card, data)
    expect(taken.cards).toEqual([card])
    expect(taken.pending.cards).toBe(null)
    expect(nextFloor(taken, data).encounter.foes.length).toBeGreaterThan(0)
  })

  it('itens sem limite: o primeiro é segurado, os outros viram pontos; vitaminas sem limite de EVs', () => {
    let run = startRun(emptyFactory(), data, 1, 5)
    run = { ...run, money: 20000, pending: { shop: ['leftovers', 'choice-band', 'protein', 'rare-candy'] } }
    run = buyItem(run, 'leftovers', 0, data)
    expect(run.team[0].item).toBe('leftovers')
    run = buyItem(run, 'choice-band', 0, data)
    expect(run.team[0].item).toBe('leftovers')
    expect(run.team[0].extras).toEqual(['choice-band'])
    expect(run.team[0].bonus.atk).toBe(HELD_BONUS['choice-band'].atk)
    for (let i = 0; i < 60; i++) run = buyItem(run, 'protein', 0, data) ?? run
    expect(run.team[0].bonus.atk).toBeGreaterThan(252 / 4)
    const level = run.team[0].level
    expect(buyItem(run, 'rare-candy', 0, data).team[0].level).toBe(level + 1)
    expect(buyItem({ ...run, money: 0 }, 'rare-candy', 0, data)).toBe(null)
    // Cartas que mexem no time todo entram no membro da batalha.
    const withCard = takeCard({ ...run, pending: { cards: ['atk'] } }, 'atk', data)
    expect(memberOf(withCard, withCard.team[0], ['tackle']).set.bonus.atk).toBe(run.team[0].bonus.atk + CARDS.atk.team.atk)
  })

  it('perdeu: moedas pela pontuação, recorde; moedas compram Pokémon pela força', () => {
    const run = { ...startRun(emptyFactory(), data, 1, 5), floor: 21, defeated: 30 }
    expect(runCoins(run)).toBe(20 * 5 + 30 * 2)
    const f = endRun({ ...emptyFactory(), best: 7 }, run)
    expect(f).toMatchObject({ coins: 160, best: 20, run: null, last: { floor: 20, coins: 160 } })
    expect(pokemonPrice(data.species[150][1])).toBeGreaterThan(pokemonPrice(data.species[19][1]))
    const rich = { ...f, coins: 10000 }
    const bought = buyPokemon(rich, data, 150)
    expect(bought.owned).toEqual([150])
    expect(bought.coins).toBe(10000 - pokemonPrice(data.species[150][1]))
    expect(startersOf(bought, data)).toContain(150)
    expect(buyPokemon(f, data, 150)).toBe(null)
  })

  it('golpes pelo nível (Charmander nível 5: Scratch, Growl, ...) e o adversário no formato da batalha', () => {
    const list = movesAt(forms[4].moves, 5, ['fire'], moves)
    expect(list).toContain('scratch')
    expect(list.every((s) => forms[4].moves.some((m) => m[0] === s && m[1] === 'level-up' && m[2] <= 5))).toBe(true)
    expect(foeMember({ id: 19, level: 7, iv: 4 }, ['tackle']).set).toMatchObject({ level: 7, levelCap: 100, lockMoves: true })
  })
})
