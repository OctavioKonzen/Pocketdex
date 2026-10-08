import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import {
  battleOrder, bossOf, bossTeam, buyItem, buyPokemon, capture, CARDS, emptyFactory, encounterFor, endRun, expAt, expFor, foeBoostAt, foeLevelAt, foeMember,
  HELD_BOOST, levelTo, MAX_TEAM, memberOf, movesAt, nextFloor, nextRandom, overflowPoints, pokemonPrice, runCoins, setMainItem, shopPrice,
  SHINY_BOOST, SHINY_CHANCE, START_BAG, START_BALLS, startersOf, buyShiny, shinyPrice, unlockShiny, claimStarter, freePick, canEvolveWith, teachMove,
  equipFromStash, gimmicksOf, setGimmick, storyLine, startRun, takeCard, teamDown, applyBagItem, winFloor,
} from './factoryRun'

const data = JSON.parse(readFileSync(new URL('../../../assets/database/factory.json', import.meta.url), 'utf8'))
const moves = Object.fromEntries(JSON.parse(readFileSync(new URL('../../../assets/database/moves.json', import.meta.url), 'utf8')).map((m) => [m.name, { ...m, category: m.damage_class }]))
const forms = Object.fromEntries(JSON.parse(readFileSync(new URL('../../../assets/database/pokemon.json', import.meta.url), 'utf8')).map((p) => [p.id, p]))
const seq = (values) => { let i = 0; return () => values[i++ % values.length] }

describe('Battle Factory (roguelike)', () => {
  it('começa com um inicial grátis no nível 5, 5 Poké Balls e a Bolsa; os outros só comprando', () => {
    const f = emptyFactory()
    expect(startRun(f, data, 150, 1)).toBe(null)
    const run = startRun(f, data, 1, 42)
    expect(run.team).toHaveLength(1)
    expect(run.team[0]).toMatchObject({ id: 1, level: 5, exp: expAt(5), item: null, hp: 1 })
    expect(run.balls).toBe(START_BALLS)
    expect(run.bag).toEqual(START_BAG)
    expect(run.floor).toBe(1)
    // Mesma semente, mesma corrida (e o mesmo que o app sorteia: test/factory_run_test.dart).
    expect(startRun(f, data, 1, 42)).toEqual(run)
    expect(run.seed).toBe(503953318)
    expect(run.team[0].ivs).toEqual({ hp: 25, atk: 22, def: 29, spa: 26, spd: 17, spe: 23 })
    expect(run.team[0].nature).toBe('Docile')
    expect(run.boss).toEqual({ region: 11, step: 0 })
    expect(run.encounter).toEqual({ kind: 'wild', foes: [{ id: 235, level: 3, iv: 0, ev: 3 }] })
  })

  it('o sorteio é o mulberry32 (o app usa o mesmo)', () => {
    expect(nextRandom(1)[0]).toBeCloseTo(0.6270739405881613, 12)
    expect(nextRandom(nextRandom(1)[1])[0]).toBeCloseTo(0.002735721180215478, 12)
  })

  it('andares sem fim: selvagem e treinador (lendário só como chefe); o nível e a força sobem sem teto', () => {
    const kinds = new Set()
    let state = 7
    const rand = () => { const [v, s] = nextRandom(state); state = s; return v }
    for (let i = 0; i < 400; i++) kinds.add(encounterFor(data, 30, rand).kind)
    expect([...kinds].sort()).toEqual(['trainer', 'wild'])
    for (let i = 0; i < 400; i++) for (const f of encounterFor(data, 30, rand).foes) expect([1, 2]).not.toContain(data.species[f.id][2])
    const deep = encounterFor(data, 500, seq([0.5, 0.9, 0.1]))
    expect(deep.foes[0].level).toBeGreaterThan(300)
    expect(deep.foes[0].iv).toBeGreaterThan(31)
    expect(deep.foes[0].boost).toBeCloseTo(foeBoostAt(500))
    expect(foeLevelAt(1)).toBe(2)
    expect(foeBoostAt(30)).toBe(0)
    // Nada de Fantasma nos primeiros andares (os iniciais só têm golpes Normal).
    for (let i = 0; i < 200; i++) for (const f of encounterFor(data, 2, rand).foes) expect(data.species[f.id][4]).not.toContain('ghost')
  })

  it('a cada 10 andares um chefe: a história de um jogo (líderes, rival, vilões, Elite Four, Campeão); depois outro jogo', () => {
    let run = startRun(emptyFactory(), data, 4, 3)
    const region = data.bosses[run.boss.region]
    run = { ...run, floor: 10 }
    run = nextFloor({ ...run, floor: 10 }, data)
    expect(run.encounter.kind).toBe('boss')
    expect(run.encounter.boss.name).toBe(region.leaders[0].name)
    expect(run.encounter.foes.map((f) => f.id)).toEqual(bossTeam(region.leaders[0], 10))
    const won = winFloor(run, data)
    expect(won.boss).toEqual({ region: run.boss.region, step: 1 })
    expect(won.bosses).toBe(1)
    expect(won.pending.cards).toHaveLength(3)
    expect(won.pending.capture).toBe(null)
    // Depois do Campeão, outra região.
    const last = { ...run, boss: { region: run.boss.region, step: region.leaders.length - 1 } }
    const champ = winFloor({ ...last, encounter: encounterFor(data, 10, seq([0.3]), bossOf(data, last)) }, data)
    expect(champ.boss.step).toBe(0)
    expect(champ.boss.region).not.toBe(run.boss.region)
  })

  it('venceu: XP e EVs só para quem está de pé; o HP e a Bolsa continuam; selvagem dá para capturar com Poké Ball', () => {
    let run = startRun(emptyFactory(), data, 4, 3)
    run = { ...run, team: [...run.team, { ...run.team[0], id: 7 }], encounter: { kind: 'wild', foes: [{ id: 19, level: 5, iv: 0, ev: 0 }] } }
    const after = winFloor(run, data, { hp: [0.4, 0], bag: { ...run.bag, potion: 1 } })
    expect(after.floor).toBe(2)
    expect(after.defeated).toBe(1)
    expect(after.team.map((m) => m.hp)).toEqual(after.pending.joy ? [1, 1] : [0.4, 0])
    expect(after.bag.potion).toBe(1)
    expect(after.team[0].exp).toBe(expAt(5) + expFor(data.species[19][0], 5, 5))
    expect(after.team[0].evs.spe).toBe(data.species[19][3][5] * 3)
    expect(after.team[1].exp).toBe(expAt(5))
    expect(after.pending.capture).toMatchObject({ id: 19, level: 5 })
    const caught = capture(after)
    expect(caught.team.map((m) => m.id)).toEqual([4, 7, 19])
    expect(caught.balls).toBe(START_BALLS - 1)
    expect(capture({ ...after, balls: 0 })).toEqual({ ...after, balls: 0 })
    // Treinador: sem captura e dinheiro em dobro.
    const t = winFloor({ ...run, encounter: { kind: 'trainer', foes: [{ id: 19, level: 5, iv: 0, ev: 0 }] } }, data)
    expect(t.pending.capture).toBe(null)
    expect(t.money).toBe(2 * winFloor(run, data).money)
  })

  it('chefes: rival e vilões no meio dos ginásios; os times crescem e ninguém fica com 1 só', () => {
    const red = data.bosses.find((b) => b.game === 'Red/Blue')
    const kinds = red.leaders.map((l) => l.kind)
    expect(kinds).toContain('rival')
    expect(kinds).toContain('villain')
    expect(kinds.at(-1)).toBe('champion')
    expect(kinds.slice(-5, -1)).toEqual(['elite', 'elite', 'elite', 'elite'])
    const blue = red.leaders.filter((l) => l.name === 'Blue' && l.kind === 'rival')
    expect(blue[0].team.length).toBeLessThan(blue.at(-1).team.length)
    expect(bossTeam(blue[0], 10).length).toBeGreaterThanOrEqual(2)
    expect(bossTeam(blue[0], 200)).toHaveLength(6)
    expect(bossTeam(red.leaders[1], 10)).toEqual(expect.arrayContaining(red.leaders[1].team))
  })

  it('XP: mais para quem está abaixo do adversário, bem menos para quem está acima', () => {
    expect(expFor(100, 20, 10)).toBeGreaterThan(expFor(100, 20, 20))
    expect(expFor(100, 20, 30)).toBeLessThan(expFor(100, 20, 20) / 5)
    expect(expFor(100, 20, 20)).toBeGreaterThan(expAt(21) - expAt(20))
  })

  it('time cheio (6): captura trocando um, ou deixa passar', () => {
    let run = startRun(emptyFactory(), data, 7, 9)
    run = { ...run, team: Array.from({ length: MAX_TEAM }, () => run.team[0]), pending: { capture: { id: 25, level: 9, iv: 3 } } }
    expect(capture(run)).toBe(run)
    expect(capture(run, 2).team[2].id).toBe(25)
  })

  it('sem limite de nível; sobe e evolui (Bulbasaur no 16 vira Ivysaur, no 32 Venusaur)', () => {
    const rand = () => 0
    const [mon, evolved] = levelTo({ id: 1, level: 15, exp: expAt(15) }, 16, data, rand)
    expect([mon.id, evolved]).toEqual([2, 2])
    expect(levelTo({ id: 1, level: 15, exp: 0 }, 40, data, rand)[0].id).toBe(3)
    expect(levelTo({ id: 3, level: 100, exp: 0 }, 250, data, rand)[0].level).toBe(250)
  })

  it('loja a cada 5 andares (uma logo antes do chefe), com Poké Ball e itens da Bolsa', () => {
    let run = startRun(emptyFactory(), data, 1, 5)
    run = { ...run, floor: 9, encounter: { kind: 'trainer', foes: [{ id: 19, level: 12, iv: 0, ev: 0 }] } }
    const after = winFloor(run, data)
    expect(after.pending.shop).toContain('poke-ball')
    expect(after.pending.cards).toBe(null)
    let shop = { ...after, money: 100000 }
    shop = buyItem(shop, 'poke-ball', 0, data)
    expect(shop.balls).toBe(START_BALLS + 1)
    const potion = after.pending.shop[1]
    expect(buyItem(shop, potion, 0, data).bag[potion]).toBe((shop.bag[potion] ?? 0) + 1)
    // Preços sobem com o andar; o Rare Candy também com o nível do time.
    expect(shopPrice({ ...run, floor: 50 }, 'poke-ball')).toBeGreaterThan(shopPrice({ ...run, floor: 1 }, 'poke-ball'))
    const high = { ...run, team: [{ ...run.team[0], level: 60 }] }
    expect(shopPrice(high, 'rare-candy')).toBeGreaterThan(shopPrice(run, 'rare-candy') * 5)
  })

  it('itens sem limite: um é o principal; os outros dão uma porcentagem bem menor no atributo certo', () => {
    let run = startRun(emptyFactory(), data, 1, 5)
    run = { ...run, money: 1e9, pending: { shop: ['leftovers', 'choice-band', 'protein', 'bottle-cap', 'rare-candy'] } }
    run = buyItem(run, 'leftovers', 0, data)
    expect(run.team[0].item).toBe('leftovers')
    run = buyItem(run, 'choice-band', 0, data)
    run = buyItem(run, 'choice-band', 0, data)
    expect(run.team[0].item).toBe('leftovers')
    expect(run.team[0].extras).toEqual(['choice-band', 'choice-band'])
    expect(memberOf(run, run.team[0], ['tackle']).set.boost.atk).toBeCloseTo(2 * HELD_BOOST['choice-band'].atk)
    const swapped = setMainItem(run, 0, 1)
    expect(swapped.team[0].item).toBe('choice-band')
    expect(swapped.team[0].extras).toEqual(['choice-band', 'leftovers'])
    expect(memberOf(swapped, swapped.team[0], ['tackle']).set.boost.hp).toBeCloseTo(HELD_BOOST.leftovers.hp)
    // Vitaminas e Bottle Cap passam do limite de EVs e IVs: o que sobra vira pontos.
    for (let i = 0; i < 20; i++) run = buyItem(run, 'protein', 0, data)
    for (let i = 0; i < 5; i++) run = buyItem(run, 'bottle-cap', 0, data)
    expect(run.team[0].evs.atk).toBeGreaterThan(252)
    expect(run.team[0].ivs.atk).toBeGreaterThan(31)
    const set = memberOf(run, run.team[0], ['tackle']).set
    expect(set.evs.atk).toBe(252)
    expect(set.ivs.atk).toBe(31)
    expect(set.bonus.atk).toBe(overflowPoints(run.team[0].ivs, run.team[0].evs, run.team[0].level).atk)
    expect(overflowPoints({ atk: 41 }, { atk: 652 }, 100).atk).toBe(110)
    // Cartas em porcentagem para o time todo.
    const withCard = takeCard({ ...run, pending: { cards: ['atk'] } }, 'atk', data)
    expect(memberOf(withCard, withCard.team[0], ['tackle']).set.boost.atk).toBeCloseTo(2 * HELD_BOOST['choice-band'].atk + CARDS.atk.team.atk)
  })

  it('sem cura entre os andares: Bolsa fora da batalha, carta de cura e o time desmaiado', () => {
    let run = startRun(emptyFactory(), data, 1, 5)
    run = { ...run, team: [{ ...run.team[0], hp: 0.3 }, { ...run.team[0], hp: 0 }] }
    expect(applyBagItem(run, 'revive', 0)).toBe(null)
    const healed = applyBagItem(run, 'super-potion', 0)
    expect(healed.team[0].hp).toBeCloseTo(0.8)
    expect(healed.bag['super-potion']).toBe(run.bag['super-potion'] - 1)
    expect(applyBagItem(run, 'potion', 1)).toBe(null)
    expect(applyBagItem(run, 'revive', 1).team[1].hp).toBe(0.5)
    expect(battleOrder(run)).toEqual([0, 1])
    expect(battleOrder({ ...run, team: [run.team[1], run.team[0]] })).toEqual([1, 0])
    const card = takeCard({ ...run, pending: { cards: ['heal'] } }, 'heal', data)
    expect(card.team.map((m) => m.hp)).toEqual([1, 1])
    expect(card.bag['max-potion']).toBe(1)
    expect(teamDown({ ...run, team: [{ hp: 0 }, { hp: 0 }] })).toBe(true)
    expect(teamDown(run)).toBe(false)
  })

  it('chefes sem treinador nos andares 5, 15...: Mega (deixa a Mega Pedra), Gigantamax e lendário; dá para capturar', () => {
    let state = 3
    const rand = () => { const [v, s] = nextRandom(state); state = s; return v }
    const titles = new Set()
    for (let i = 0; i < 60; i++) {
      const e = encounterFor(data, 25, rand, null, true)
      expect(e.kind).toBe('wildboss')
      titles.add(e.foes[0].title)
      if (e.foes[0].title === 'mega') expect(data.megas[e.foes[0].id].map((m) => m[0])).toContain(e.foes[0].item)
      if (e.foes[0].title === 'gmax') expect(e.foes[0].gimmick).toBe('dmax')
      if (e.foes[0].title === 'legend') expect([1, 2]).toContain(data.species[e.foes[0].id][2])
    }
    expect([...titles].sort()).toEqual(['gmax', 'legend', 'mega'])
    const run = { ...startRun(emptyFactory(), data, 4, 3), floor: 25, encounter: { kind: 'wildboss', foes: [{ id: 6, level: 20, iv: 31, ev: 50, item: 'charizardite-x', gimmick: 'mega', title: 'mega' }] } }
    const after = winFloor(run, data)
    expect(after.stash).toEqual(['charizardite-x'])
    expect(after.pending.drop).toBe('charizardite-x')
    expect(after.pending.capture.id).toBe(6)
    expect(foeMember(run.encounter.foes[0], ['tackle']).set).toMatchObject({ item: 'charizardite-x', gimmick: 'mega' })
  })

  it('chefe da história deixa um Cristal Z; acabou a história, começa a de outra região (com o fim e o começo da história)', () => {
    let run = startRun(emptyFactory(), data, 4, 3)
    const game = data.bosses[run.boss.region]
    run = { ...run, floor: 10, boss: { region: run.boss.region, step: game.leaders.length - 1 } }
    run = nextFloor(run, data)
    const after = winFloor(run, data)
    expect(after.boss.step).toBe(0)
    expect(data.bosses[after.boss.region].region).not.toBe(game.region)
    expect(after.played).toEqual([game.region, data.bosses[after.boss.region].region])
    expect(after.pending.story).toContain(storyLine(data, game.region, 'end'))
    expect(after.pending.story).toContain(storyLine(data, data.bosses[after.boss.region].region, 'intro'))
    expect(Object.values(data.zcrystals)).toContain(after.stash[0])
    for (const region of new Set(data.bosses.map((b) => b.region))) {
      for (const key of ['intro', 'gym', 'rival', 'villain', 'elite', 'champion', 'end']) expect(storyLine(data, region, key, 'X').length).toBeGreaterThan(20)
    }
  })

  it('loja nova: TM, Move Tutor, Move Reminder, pedras de evolução, Dynamax Band e Tera Orb; Mega e Z pelo item', () => {
    let run = startRun(emptyFactory(), data, 1, 5)
    run = { ...run, money: 1e9, team: [{ ...run.team[0], id: 133 }, { ...run.team[0], id: 6 }],
      pending: { shop: ['tm:thunderbolt', 'move-tutor', 'move-reminder', 'evo:thunder-stone', 'evo:fire-stone', 'dynamax-band', 'tera-orb'] } }
    expect(canEvolveWith(data, run.team[0], 'thunder-stone')).toEqual([135])
    expect(buyItem(run, 'evo:fire-stone', 1, data)).toBe(null)
    run = buyItem(run, 'evo:thunder-stone', 0, data)
    expect(run.team[0].id).toBe(135)
    run = buyItem(run, 'tm:thunderbolt', 0, data)
    expect(run.tms.thunderbolt).toBe(1)
    run = buyItem(run, 'move-tutor', 0, data)
    expect(run.tokens['move-tutor']).toBe(1)
    const taught = teachMove(run, 0, 'thunderbolt', ['tackle', 'growl', 'quick-attack', 'thunder-shock'], 3, 'tm')
    expect(taught.team[0].moves).toEqual(['tackle', 'growl', 'quick-attack', 'thunderbolt'])
    expect(taught.tms.thunderbolt).toBe(0)
    expect(teachMove(taught, 0, 'thunderbolt', ['tackle'], 0, 'tm')).toBe(null)
    expect(memberOf(taught, taught.team[0], ['tackle']).set.moves).toEqual(['tackle', 'growl', 'quick-attack', 'thunderbolt'])
    expect(teachMove(run, 0, 'zap-cannon', ['tackle'], 0, 'move-tutor').tokens['move-tutor']).toBe(0)
    expect(gimmicksOf(data, run, run.team[1])).toEqual([])
    run = buyItem(buyItem(run, 'dynamax-band', 0, data), 'tera-orb', 0, data)
    expect(buyItem(run, 'dynamax-band', 0, data)).toBe(null)
    run = { ...run, stash: ['charizardite-y', 'firium-z'] }
    run = equipFromStash(run, 0, 1)
    expect(run.team[1].item).toBe('charizardite-y')
    expect(gimmicksOf(data, run, run.team[1])).toEqual(['mega', 'dmax', 'tera'])
    expect(memberOf(run, run.team[1], ['ember'], data).set.gimmick).toBe('mega')
    expect(memberOf(setGimmick(run, 1, 'tera'), run.team[1], ['ember'], data).set.gimmick).toBe('mega')
    const tera = setGimmick(run, 1, 'tera')
    expect(memberOf(tera, tera.team[1], ['ember'], data).set.gimmick).toBe('tera')
    expect(gimmicksOf(data, run, equipFromStash(run, 0, 0).team[0])).toContain('z')
  })

  it('perdeu: moedas pela pontuação, recorde; moedas compram Pokémon pela força', () => {
    const run = { ...startRun(emptyFactory(), data, 1, 5), floor: 21, defeated: 30, bosses: 2 }
    expect(runCoins(run)).toBe(20 * 5 + 30 * 2 + 2 * 25)
    const f = endRun({ ...emptyFactory(), best: 7 }, run)
    expect(f).toMatchObject({ coins: 210, best: 20, run: null, last: { floor: 20, coins: 210 } })
    expect(pokemonPrice(data.species[150][1])).toBeGreaterThan(pokemonPrice(data.species[19][1]))
    // Primeiro um inicial grátis (de qualquer geração); os outros, inclusive iniciais, se compram.
    expect(freePick(f)).toBe(true)
    expect(startersOf(f, data)).toEqual(data.starters)
    expect(buyPokemon({ ...f, coins: 1e6 }, data, 150)).toBe(null)
    const picked = claimStarter(f, data, 906)
    expect(picked.owned).toEqual([906])
    expect(claimStarter(picked, data, 1)).toBe(picked)
    expect(startersOf(picked, data)).toEqual([906])
    const rich = { ...picked, coins: 10000 }
    const bought = buyPokemon(rich, data, 150)
    expect(bought.owned).toEqual([906, 150])
    expect(bought.coins).toBe(10000 - pokemonPrice(data.species[150][1]))
    expect(bought.shinies).toEqual([])
    expect(buyPokemon(rich, data, 4).owned).toContain(4)
    expect(buyPokemon(rich, data, 150, 0).shinies).toEqual([150])
    expect(startersOf(bought, data)).toContain(150)
    expect(buyPokemon(picked, data, 150)).toBe(null)
  })

  it('shiny: selvagem shiny dá para capturar e tem bônus; inicial shiny libera o shiny dele (que também se compra, bem caro)', () => {
    let state = 11
    const rand = () => { const [v, s] = nextRandom(state); state = s; return v }
    let shinies = 0
    for (let i = 0; i < 4000; i++) if (encounterFor(data, 20, rand).foes.some((f) => f.shiny)) shinies++
    expect(SHINY_CHANCE).toBe(1 / 4096)
    expect(shinies).toBeLessThan(6)
    // Nível, tipo (selvagem), espécie e o sorteio do shiny (abaixo de 1/4096).
    expect(encounterFor(data, 20, seq([0.5, 0.9, 0.5, 0.0001])).foes[0].shiny).toBe(true)
    expect(encounterFor(data, 20, seq([0.5, 0.9, 0.5, 0.001])).foes[0].shiny).toBeUndefined()
    const f = emptyFactory()
    expect(startRun(f, data, 4, 1, true)).toBe(null)
    let run = startRun(f, data, 1, 5)
    run = { ...run, pending: { capture: { id: 4, level: 5, iv: 0, ev: 0, shiny: true } } }
    const caught = capture(run)
    expect(caught.team[1].shiny).toBe(true)
    expect(memberOf(caught, caught.team[1], ['tackle']).set).toMatchObject({ shiny: true, boost: { atk: SHINY_BOOST } })
    expect(foeMember({ id: 4, level: 5, iv: 0, ev: 0, shiny: true }, ['tackle']).set.boost.spe).toBe(SHINY_BOOST)
    // Capturar o inicial normal não libera nada; shiny libera o shiny dele.
    expect(unlockShiny(f, data, { id: 4 })).toBe(f)
    expect(unlockShiny(f, data, { id: 19, shiny: true })).toBe(f)
    const unlocked = unlockShiny(f, data, caught.team[1])
    expect(unlocked.shinies).toEqual([4])
    expect(startRun(unlocked, data, 4, 1, true).team[0].shiny).toBe(true)
    // Comprar: bem caro.
    expect(shinyPrice(data.species[1][1])).toBeGreaterThanOrEqual(3000)
    expect(buyShiny({ ...f, coins: 100 }, data, 1)).toBe(null)
    expect(buyShiny({ ...f, coins: 1e6 }, data, 150)).toBe(null)
    expect(buyShiny({ ...f, coins: 1e6 }, data, 1)).toBe(null)
    expect(buyShiny({ ...f, owned: [1], coins: 1e6 }, data, 1).shinies).toEqual([1])
  })

  it('golpes pelo nível; golpes fortes só a partir de um nível compatível com o poder', () => {
    const list = movesAt(forms[4].moves, 5, ['fire'], moves)
    expect(list).toContain('scratch')
    expect(list.every((s) => forms[4].moves.some((m) => m[0] === s && m[1] === 'level-up' && m[2] <= 5))).toBe(true)
    // Golem aprende Explosion/Heavy Slam "no nível 1", mas no nível 9 não usa.
    const golem = movesAt(forms[76].moves, 9, ['rock', 'ground'], moves)
    expect(golem).not.toContain('explosion')
    expect(golem).not.toContain('rollout')
    expect(movesAt(forms[76].moves, 130, ['rock', 'ground'], moves).some((s) => moves[s].power >= 100)).toBe(true)
    expect(foeMember({ id: 19, level: 7, iv: 4, ev: 0 }, ['tackle']).set).toMatchObject({ level: 7, levelCap: 'none', lockMoves: true })
  })
})

// O mesmo roteiro no app (test/factory_run_test.dart): 40 andares com chefes, captura, carta e loja.
// Para gerar de novo: UPDATE_FACTORY_TRACE=1 npx vitest run src/lib/factoryRun.test.js
function factoryTrace(F, data) {
  let run = F.startRun(F.emptyFactory(), data, 7, 2024)
  const out = []
  for (let i = 0; i < 40; i++) {
    run = F.winFloor(run, data, { hp: run.team.map((_, k) => (k === 0 ? 0.7 : 1)) })
    if (run.pending.capture) run = F.capture(run, run.team.length >= F.MAX_TEAM ? 1 : null)
    if (run.pending.cards) run = F.takeCard(run, run.pending.cards[0], data)
    run = { ...run, money: run.money + 500 }
    for (const id of run.pending.shop ?? []) run = F.buyItem(run, id, 0, data) ?? run
    run = F.nextFloor(run, data)
    out.push([run.seed, run.floor, run.money, run.balls, run.boss.region, run.boss.step, run.team.map((m) => [m.id, m.level, m.exp, m.item ?? '', m.extras.length]),
      run.encounter.kind, run.encounter.foes.map((f) => [f.id, f.level, f.shiny ? 1 : 0])])
  }
  return out
}

describe('roteiro igual ao app', () => {
  it('40 andares dão o mesmo resultado que test/fixtures/factory_trace.json', async () => {
    const F = await import('./factoryRun')
    const trace = factoryTrace(F, data)
    const url = new URL('../../../test/fixtures/factory_trace.json', import.meta.url)
    const { writeFileSync } = await import('node:fs')
    if (process.env.UPDATE_FACTORY_TRACE) writeFileSync(url, JSON.stringify(trace) + '\n')
    expect(trace).toEqual(JSON.parse(readFileSync(url, 'utf8')))
    expect(trace.some((t) => t[7] === 'boss')).toBe(true)
  })
})
