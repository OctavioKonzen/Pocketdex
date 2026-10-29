import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import {
  learnMove,
  movesLearnedBetween,
  weeklyOf, startWeekly, buyCosmetic, equipCosmetic, COSMETIC_BALLS,
  FRIEND_EVOLVE, PICKUP, SYNCHRONIZE, legOf,
  placeInfo, routeInfo, UPGRADE_FX, SHORE, CAVE_OF, dungeonPos, routePos, DUNGEON_LENGTH, CITY_BOSS, waterNext, RIVAL_FLOOR, targetOf, rivalBoss, townShop, townCenter, townHub, biomesLinked,
  isDoubleBattle,
  DOUBLE_FLOOR,
  battleOrder, blindPick, bossGimmick, bossOf, UPGRADE_TREE, bossScene, routeBiome, bossTeam, buyItem, buyPokemon, capture, CARDS, emptyFactory, encounterFor, endRun, expAt, expFor, foeBoostAt, foeLevelAt, foeMember,
  HELD_BOOST, levelTo, MAX_TEAM, memberOf, movesAt, nextFloor, nextRandom, overflowPoints, pokemonPrice, runCoins, setMainItem, shopPrice,
  SHINY_BOOST, SHINY_CHANCE, START_BAG, START_BALLS, startersOf, buyShiny, shinyPrice, unlockShiny, claimStarter, freePick, canEvolveWith, teachMove,
  equipFromStash, gimmicksOf, setGimmick, storyLine, startRun, takeCard, teamDown, applyBagItem, winFloor, chooseNode, routeOptions, routeCities,
  captureFor, factoryOf, BIOMES, isBattleNode, skipCapture, FORKS, ROUTE_LENGTH, BALL_TIERS, HEAL_TIERS, tierPick, minLevelOf, devolve,
  EXP_SHARE, expProgress, shopOwned, baseForm, forSale, normalizeOwned, buyUpgrade, upgradePrice, UPGRADES,
  tradeMon, skipTrade, TRADE_LEVELS, escapeRope, ESCAPE_HP, progress, ACHIEVEMENTS, LUCKY_EGG, rerollRoute, FOE_ITEMS,
  regionLegend, REGION_LEGENDS, rivalStarter, starterLine, newMission, resolveChoice, MISSION_MONEY, CHOICE_EVENTS,
  clockOf, weatherOf, fieldOf, placeMusic, upgradeNeeds, UPGRADE_BRANCHES, unequipItem, SEASON_TYPES, BIOME_IDS, SCENE_FIELD,
  HM_BADGES, cutPath, nodeBlocked, dexOf, dexRewardFor, DEX_REWARDS, leaveDaycare, takeDaycare, teamRoom, DAYCARE_EGG, EGG_BATTLES, EGG_IVS, rematchBoss,
} from './factoryRun'

const data = JSON.parse(readFileSync(new URL('../../../assets/database/factory.json', import.meta.url), 'utf8'))
const moves = Object.fromEntries(JSON.parse(readFileSync(new URL('../../../assets/database/moves.json', import.meta.url), 'utf8')).map((m) => [m.name, { ...m, category: m.damage_class }]))
const forms = Object.fromEntries(JSON.parse(readFileSync(new URL('../../../assets/database/pokemon.json', import.meta.url), 'utf8')).map((p) => [p.id, p]))
const ROUTE_42 = { floor: 1, biome: 'grass', options: [{ kind: 'trainer' }] }
const ENCOUNTER_42 = { kind: 'trainer', foes: [{ id: 276, level: 3, iv: 0, ev: 3 }], trainerSeed: 500729487, scene: 'grass' }
const seq = (values) => { let i = 0; return () => values[i++ % values.length] }

/** Compra todas as melhorias (em várias passadas: umas pedem outras), enquanto dá. */
function buyAll(f, ids = Object.keys(UPGRADES).filter((k) => !k.includes('~'))) {
  for (let pass = 0; pass < 6; pass++) for (const id of ids) for (let next = buyUpgrade(f, id); next; next = buyUpgrade(f, id)) f = next
  return f
}

describe('Battle Factory (roguelike)', () => {
  it('dupla de treinadores salva com os dois times inteiros: fica com 3 de cada (a batalha aceita 6)', () => {
    const foes = Array.from({ length: 11 }, (_, i) => ({ id: 1 + i, level: 40 }))
    const fixed = normalizeOwned({ ...emptyFactory(), run: { ...startRun(emptyFactory(), data, 1, 42), encounter: { kind: 'trainer', foes, pair: true } } }, data)
    expect(fixed.run.encounter.foes.map((f) => f.id)).toEqual([1, 2, 3, 9, 10, 11])
  })

  it('começa com um inicial grátis no nível 5, 5 Poké Balls e a Bolsa; os outros só comprando', () => {
    const f = emptyFactory()
    expect(startRun(f, data, 150, 1)).toBe(null)
    const run = startRun(f, data, 1, 42)
    expect(run.team).toHaveLength(1)
    expect(run.team[0]).toMatchObject({ id: 1, level: 5, exp: expAt(5), item: null, hp: 1 })
    expect(run.bag).toEqual(START_BAG)
    expect(run.bag['poke-ball']).toBe(START_BALLS)
    expect(run.floor).toBe(1)
    // Mesma semente, mesma corrida (e o mesmo que o app sorteia: test/factory_run_test.dart).
    expect(startRun(f, data, 1, 42)).toEqual(run)
    expect(run.seed).toBe(2967354801)
    expect(run.team[0].ivs).toEqual({ hp: 25, atk: 22, def: 29, spa: 26, spd: 17, spe: 23 })
    expect(run.team[0].nature).toBe('Docile')
    expect(run.boss).toEqual({ region: 11, step: 0 })
    // O mapa: no 1º andar, o caminho segue (uma batalha comum).
    expect(run.encounter).toBe(null)
    expect(run.route).toEqual(ROUTE_42)
    expect(chooseNode(run, data, 0).encounter).toEqual(ENCOUNTER_42)
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

  it('o líder na cidade dele (no fim da rota): a história de um jogo (líderes, rival, vilões, Elite Four, Campeão); depois outro jogo', () => {
    let run = startRun(emptyFactory(), data, 4, 3)
    const red = data.bosses.findIndex((b) => b.game === 'Red/Blue')
    const region = data.bosses[red]
    // O 10º andar da rota é o chefe dela; o líder fica no último andar da cidade.
    expect(nextFloor({ ...run, floor: ROUTE_LENGTH, leg: 1, boss: { region: red, step: 1 } }, data).route.options).toEqual([{ kind: 'dboss' }])
    run = nextFloor({ ...run, floor: 1 + CITY_BOSS, leg: 1, boss: { region: red, step: 1 } }, data)
    expect(run.route.town).toBe(true)
    expect(run.route.options).toEqual([{ kind: 'boss' }])
    expect(run.town.shop.length).toBeGreaterThan(4)
    run = chooseNode(run, data, 0)
    expect(run.encounter.kind).toBe('boss')
    expect(run.encounter.boss.name).toBe('Brock')
    expect(run.encounter.foes.map((f) => f.id)).toEqual(bossTeam(region.leaders[1], 10))
    const won = winFloor(run, data)
    expect(won.boss).toEqual({ region: red, step: 2 })
    // Venceu o líder: começa a rota seguinte.
    expect(won.leg).toBe(2 + CITY_BOSS)
    expect(won.bosses).toBe(1)
    expect(won.pending.cards).toHaveLength(3)
    expect(won.pending.capture).toBe(null)
    // Depois do Campeão, outra região.
    const last = { ...run, boss: { region: red, step: region.leaders.length - 1 } }
    const champ = winFloor({ ...last, encounter: encounterFor(data, 10, seq([0.3]), bossOf(data, last)) }, data)
    expect(champ.boss.step).toBe(0)
    expect(champ.boss.region).not.toBe(red)
  })

  it('venceu: XP e EVs só para quem está de pé; o HP e a Bolsa continuam; o capturado na batalha entra no time', () => {
    let run = startRun(emptyFactory(), data, 4, 3)
    run = { ...run, team: [...run.team, { ...run.team[0], id: 7 }], encounter: { kind: 'wild', foes: [{ id: 19, level: 5, iv: 0, ev: 0 }] } }
    const after = winFloor(run, data, { hp: [0.4, 0], bag: { ...run.bag, potion: 1, 'poke-ball': 4 }, captured: true })
    expect(after.floor).toBe(2)
    expect(after.defeated).toBe(1)
    expect(after.team.map((m) => m.hp)).toEqual(after.pending.joy ? [1, 1] : [0.4, 0])
    expect(after.bag.potion).toBe(1)
    expect(after.team[0].exp).toBe(expAt(5) + expFor(data.species[19][0], 5, 5))
    expect(after.team[0].evs.spe).toBe(data.species[19][3][5] * 3)
    expect(after.team[1].exp).toBe(expAt(5))
    expect(after.pending.capture).toMatchObject({ id: 19, level: 5 })
    expect(after.bag['poke-ball']).toBe(4)
    const caught = capture(after)
    expect(caught.team.map((m) => m.id)).toEqual([4, 7, 19])
    expect(skipCapture(after).team).toHaveLength(2)
    // Derrotou sem capturar: nada para pôr no time.
    expect(winFloor(run, data).pending.capture).toBe(null)
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
    expect(expFor(100, 20, 30)).toBeLessThan(expFor(100, 20, 20) / 4)
    expect(expFor(100, 20, 20)).toBeGreaterThan(expAt(21) - expAt(20))
  })

  it('XP só para quem lutou contra o adversário; com o Exp. Share, o resto do time ganha a metade (e os EVs)', () => {
    const base = startRun(emptyFactory(), data, 1, 42)
    const team = [base.team[0], { ...base.team[0], id: 4 }, { ...base.team[0], id: 7, hp: 0 }]
    const foes = [{ id: 19, level: 7, iv: 0, ev: 0 }, { id: 16, level: 7, iv: 0, ev: 0 }]
    const run = { ...base, team, encounter: { kind: 'wild', foes } }
    // O 1º lutou contra os dois, o 2º só contra o segundo; o 3º desmaiado não ganha.
    const after = winFloor(run, data, { fought: [[0], [0, 1]] })
    const e = (id, lvl) => expFor(data.species[id][0], 7, lvl, 1)
    expect(after.pending.gains).toEqual([e(19, 5) + e(16, 5), e(16, 5), 0])
    expect(after.team[1].evs.spe).toBe(data.species[16][3][5] * 3)
    // 5 níveis acima de um nível 7 ainda ganha XP.
    expect(expFor(data.species[19][0], 7, 12)).toBeGreaterThan(30)
    // Sem Exp. Share, quem não lutou fica sem nada.
    const alone = winFloor(run, data, { fought: [[0], [0]] })
    expect(alone.pending.gains[1]).toBe(0)
    expect(alone.team[1].evs).toEqual(team[1].evs)
    // Com o Exp. Share (da loja), a metade.
    const shared = buyItem({ ...run, money: 99999, pending: { shop: ['exp-share'] } }, 'exp-share', 0, data)
    expect(shared.expShare).toBe(true)
    expect(shopOwned(shared, 'exp-share')).toBe(true)
    const half = winFloor({ ...shared, encounter: run.encounter }, data, { fought: [[0], [0]] })
    expect(half.pending.gains[1]).toBe(Math.floor(e(19, 5) * EXP_SHARE) + Math.floor(e(16, 5) * EXP_SHARE))
    expect(expProgress({ level: 5, exp: expAt(5) })).toBe(0)
    expect(expProgress({ level: 5, exp: (expAt(5) + expAt(6)) / 2 })).toBe(0.5)
    expect(expProgress({ level: 5, exp: expAt(5) }, 9999)).toBe(1)
  })

  it('só a primeira forma está à venda; contas com forma evoluída ficam com a primeira; melhorias permanentes', () => {
    expect(baseForm(data, 6)).toBe(4)
    expect(baseForm(data, 26)).toBe(172)
    expect(forSale(data, 4)).toBe(true)
    expect(forSale(data, 6)).toBe(false)
    const rich = { ...emptyFactory(), owned: [1], coins: 99999 }
    expect(buyPokemon(rich, data, 6)).toBe(null)
    expect(buyPokemon(rich, data, 4).owned).toEqual([1, 4])
    const old = { ...emptyFactory(), owned: [1, 6, 5, 3], shinies: [6] }
    expect(normalizeOwned(old, data)).toMatchObject({ owned: [1, 4], shinies: [4] })
    const ok = { ...emptyFactory(), owned: [1, 4] }
    expect(normalizeOwned(ok, data)).toBe(ok)
    // Melhorias: cada nível mais caro, até o máximo; valem na próxima corrida.
    let f = { ...rich, coins: 999999, best: 999, owned: [1, 4, 7, 152, 155, 158, 252, 255, 387, 390] }
    const p1 = upgradePrice(f, 'level')
    f = buyUpgrade(f, 'level')
    expect(upgradePrice(f, 'level')).toBeGreaterThan(p1)
    expect(f.coins).toBe(999999 - p1)
    f = buyAll(f)
    expect(buyUpgrade(f, 'level')).toBe(null)
    const run = startRun(f, data, 1, 42)
    expect(run.team[0].level).toBe(START_BALLS + 5)
    expect(Math.min(...Object.values(run.team[0].ivs))).toBeGreaterThanOrEqual(30)
    expect(run.bag['poke-ball']).toBe(START_BALLS + 5)
    expect(run.bag.potion).toBe(START_BAG.potion + 5)
    expect(run.bag.revive).toBe(START_BAG.revive + 3)
    expect(run.money).toBe(500)
    expect(run.mult).toEqual({ money: 1.25, exp: 1.4, shop: 0.8 })
    // A árvore grande: bônus no time (atributo + Mestre), itens guardados, Bolsa e fichas.
    expect(run.teamBoost).toEqual({ hp: 0.15, atk: 0.15, def: 0.15, spa: 0.15, spd: 0.15, spe: 0.15 })
    expect(run.stash).toContain('leftovers')
    expect(run.stash).toContain('lucky-egg')
    expect(run.stash.length).toBe(Object.entries(UPGRADE_FX).filter(([k, [kind]]) => kind === 'stash' && !k.includes('~')).length)
    expect([run.bag['ultra-ball'], run.bag['master-ball'], run.bag['max-potion']]).toEqual([3, 1, 2])
    expect(run.tokens).toEqual({ 'move-tutor': 3, 'move-reminder': 3 })
    // Os ramos novos: Great Balls, Escape Rope, Mapa, Dynamax Band, Tera Orb e moedas a mais no fim.
    expect(run.bag['great-ball']).toBe(3)
    expect(run.bag['escape-rope']).toBe(2)
    expect([run.townMap, run.dmax, run.tera]).toEqual([true, true, true])
    expect(endRun(f, { ...run, floor: 11, defeated: 0, bosses: 0 }).last.coins).toBe(100)
    expect(upgradeNeeds({ ...emptyFactory(), best: 999 }, 'tera')).toContainEqual({ kind: 'up', id: 'dmax', level: 1 })
    // A trilha: 8 nós de cada melhoria (cada um pede o anterior; a cada 4, um nó-chave com o dobro); comprando tudo, os bônus somam.
    expect(Object.keys(UPGRADES).filter((k) => k.includes('~')).length).toBe(63 * 8)
    expect([UPGRADES['atk~1'].per, UPGRADES['atk~4'].per]).toEqual([2, 2])
    expect([UPGRADES['level~1'].per, UPGRADES['level~4'].per, UPGRADES['level~4'].max]).toEqual([1, 4, 1])
    expect(upgradeNeeds({ ...f, upgrades: { ...f.upgrades, 'atk~2': 0 } }, 'atk~3')).toContainEqual({ kind: 'up', id: 'atk~2', level: 1 })
    expect(UPGRADE_TREE['atk~1']).toEqual({ needs: ['atk', 1], best: 7 })
    const all = buyAll({ ...f, coins: 9999999 }, Object.keys(UPGRADES))
    const big = startRun(all, data, 1, 42)
    expect(big.teamBoost).toEqual({ hp: 0.82, atk: 1.28, def: 1.2, spa: 1.32, spd: 1.18, spe: 1.6 })
    expect(big.mult).toEqual({ money: 2.7, exp: 3.1, shop: 0.52 })
    expect([big.bag['poke-ball'], big.bag['great-ball'], big.bag['ultra-ball'], big.bag.potion, big.bag.revive, big.bag['escape-rope']]).toEqual([52, 35, 17, 35, 18, 2])
    // Os efeitos que mudam a corrida: dinheiro no começo, cura depois de cada vitória, nível e IVs do inicial.
    expect([big.money, big.winHeal, big.team[0].level, Math.min(...Object.values(big.team[0].ivs)), big.rerolls, big.stash.length, big.catchBonus]).toEqual([2900, 50, 25, 31, 18, 50, 150])
    // A captura mais fácil vai para a batalha (o motor multiplica a taxa de captura).
    expect(captureFor({ ...big, encounter: { kind: 'wild', foes: [{ id: 16 }] } }, data)).toMatchObject({ bonus: 150 })
    expect(big.tokens).toEqual({ 'move-tutor': 20, 'move-reminder': 18 })
    expect(endRun(all, { ...big, floor: 11, defeated: 0, bosses: 0 }).last.coins).toBe(140)
    // A cura depois da vitória: só em quem está de pé, até o HP cheio.
    const healRun = { ...big, team: [{ ...big.team[0], hp: 0.3 }, { ...big.team[0], hp: 0 }, { ...big.team[0], hp: 0.8 }], encounter: { kind: 'wild', foes: [{ id: 16, level: 3, iv: 0, ev: 0 }] } }
    expect(winFloor(healRun, data, { hp: [0.3, 0, 0.8], fought: [[0]] }).team.map((m) => m.hp)).toEqual([0.8, 0, 1])
    // Um nó que saiu da árvore: as moedas voltam.
    const stale = normalizeOwned({ ...all, coins: 0, upgrades: { ...all.upgrades, 'atk~9': 1 } }, data)
    expect(stale.upgrades['atk~9']).toBe(undefined)
    expect(stale.coins).toBe(Math.round((200 * 0.25 + 60 * 9) / 10) * 10)
    // Sem melhorias, a corrida é a de sempre.
    expect(startRun(emptyFactory(), data, 1, 42).team[0].level).toBe(5)
  })

  it('troca: dá um, vem o oferecido 3 níveis acima com o item; recusar não muda o time', () => {
    const base = startRun(emptyFactory(), data, 1, 42)
    const run = { ...base, team: [{ ...base.team[0], level: 10, item: 'leftovers' }], pending: { trade: { id: 19 } } }
    const out = tradeMon(run, 0, data)
    expect(out.team[0].level).toBe(10 + TRADE_LEVELS)
    expect([19, 20]).toContain(out.team[0].id)
    expect(out.team[0].item).toBe('leftovers')
    expect(out.trades).toBe(1)
    expect(out.pending.trade).toBe(null)
    expect(skipTrade(run).team).toEqual(run.team)
    // O mapa às vezes oferece uma troca (a partir do 3º andar), com um Pokémon da rota.
    let seen = null
    for (let s = 1; s < 400 && !seen; s++) {
      const r = { ...base, floor: 5, leg: 1, seed: s }
      r.route = routeOptions(r, data, seq([0.3, 0.9, 0.5, 0.97, 0.99, 0.2]))
      const i = r.route.options.findIndex((o) => o.kind === 'trade')
      if (i >= 0) seen = chooseNode(r, data, i)
    }
    expect(seen?.pending?.trade?.id).toBeGreaterThan(0)
  })

  it('Escape Rope: perdeu com ela na Bolsa, foge com pouco HP no mesmo andar; sem ela, null', () => {
    const base = startRun(emptyFactory(), data, 1, 42)
    expect(escapeRope(base, data, { hp: [0] })).toBe(null)
    const run = { ...base, floor: 7, bag: { ...base.bag, 'escape-rope': 1 }, encounter: { kind: 'trainer', foes: [] } }
    const out = escapeRope(run, data, { hp: [0], bag: { ...run.bag, potion: 0 } })
    expect(out.bag['escape-rope']).toBe(0)
    expect(out.bag.potion).toBe(0)
    expect(out.team[0].hp).toBe(ESCAPE_HP)
    expect(out.floor).toBe(7)
    expect(out.encounter).toBe(null)
    expect(out.route.options.length).toBeGreaterThan(0)
    // A batalha não leva a corda embora.
    const won = winFloor({ ...run, encounter: { kind: 'trainer', foes: [{ id: 19, level: 5, iv: 0, ev: 0 }] } }, data, { bag: { potion: 1 } })
    expect(won.bag['escape-rope']).toBe(1)
  })

  it('Lucky Egg: quem segura ganha +50% de XP', () => {
    const base = startRun(emptyFactory(), data, 1, 42)
    const foes = [{ id: 19, level: 7, iv: 0, ev: 0 }]
    const plain = winFloor({ ...base, encounter: { kind: 'wild', foes } }, data)
    const egg = winFloor({ ...base, team: [{ ...base.team[0], item: 'lucky-egg' }], encounter: { kind: 'wild', foes } }, data)
    expect(egg.pending.gains[0]).toBe(Math.floor(plain.pending.gains[0] / 1 * LUCKY_EGG.held) || egg.pending.gains[0])
    expect(egg.pending.gains[0]).toBeGreaterThan(plain.pending.gains[0] * 1.4)
  })

  it('conquistas dão moedas uma vez; o Hall da Fama guarda o time que venceu o Campeão', () => {
    const base = startRun(emptyFactory(), data, 1, 42)
    const run = { ...base, floor: 30, badges: 1, champions: 1, pending: { champion: true }, team: [{ ...base.team[0], shiny: true }] }
    const [f1, earned] = progress({ ...emptyFactory(), coins: 0 }, run)
    expect(earned).toEqual(expect.arrayContaining(['badge', 'champion', 'floor25', 'shiny']))
    expect(f1.coins).toBe(earned.reduce((s, id) => s + ACHIEVEMENTS[id].coins, 0))
    expect(f1.hall).toHaveLength(1)
    expect(f1.hall[0].team[0]).toMatchObject({ id: 1, shiny: true })
    const [f2, again] = progress(f1, run)
    expect(again).toEqual([])
    expect(f2).toBe(f1)
  })

  it('devolve moedas na troca para a primeira forma; melhorias que mudam o jogo; chefes com itens', () => {
    const price = (id) => pokemonPrice(data.species[id][1])
    const fixed = normalizeOwned({ ...emptyFactory(), coins: 0, owned: [1, 6, 5, 4] }, data)
    expect(fixed.owned).toEqual([1, 4])
    expect(fixed.coins).toBe(price(6) + price(5))
    expect(normalizeOwned({ ...emptyFactory(), coins: 10, owned: [1, 6] }, data).coins).toBe(10 + price(6) - price(4))
    // Exp. Share, carta a mais, sorteio de novo e shiny.
    let f = { ...emptyFactory(), coins: 999999, best: 999, owned: [1, 4, 7, 152, 155, 158, 252, 255] }
    f = buyAll(f)
    const run = startRun(f, data, 1, 42)
    expect(run.expShare).toBe(true)
    expect(run.cardCount).toBe(4)
    expect(run.rerolls).toBe(2)
    expect(run.shinyRate).toBe(4)
    const again = rerollRoute(run, data)
    expect(again.rerolls).toBe(1)
    expect(rerollRoute({ ...run, rerolls: 0 }, data)).toBe(null)
    // Os chefes (a partir do andar 10) seguram itens de verdade.
    let state = 5
    const rand = () => { const [v, s] = nextRandom(state); state = s; return v }
    const boss = encounterFor(data, 20, rand, bossOf(data, startRun(emptyFactory(), data, 1, 42)))
    expect(boss.foes.every((x) => FOE_ITEMS.includes(x.item))).toBe(true)
  })

  it('Mapa: aparece fácil na loja até ser comprado; sem ele, a bifurcação vai às cegas (igual ao app)', () => {
    const cases = [[42, 2, 3], [123456789, 5, 2], [2147483647, 9, 3], [7, 100, 3]]
    expect(cases.map(([seed, floor, n]) => blindPick({ seed, floor, route: { options: Array(n).fill({}) } }))).toEqual([1, 0, 1, 2])
    const run = { ...startRun(emptyFactory(), data, 1, 42), money: 9999, pending: { shop: ['town-map'] } }
    const bought = buyItem(run, 'town-map', 0, data)
    expect(bought.townMap).toBe(true)
    expect(buyItem(bought, 'town-map', 0, data)).toBe(null)
  })

  it('base da equipe vilã: só capangas com os Pokémon da equipe; cenário de cada chefe (igual ao app)', () => {
    // A base é um lugar da cidade (com a equipe vilã na cidade): na rota, o lugar do ginásio.
    const run = { ...startRun(emptyFactory(), data, 1, 42), floor: 23, leg: 3, boss: { region: 0, step: 11 }, dungeon: { place: 'base', scene: 'base-rocket', start: 21 } }
    expect(routeBiome(data, run)).toBe('base-rocket')
    expect(routeBiome(data, { ...run, dungeon: null })).not.toBe('base-rocket')
    let seed = 11
    const rand = () => { const [v, s] = nextRandom(seed); seed = s; return v }
    for (let i = 0; i < 30; i++) {
      const route = routeOptions({ ...run, floor: 21 + (i % 9) }, data, rand)
      expect(route.options.some((o) => ['wild', 'mart', 'trade', 'wildboss'].includes(o.kind))).toBe(false)
    }
    const grunt = encounterFor(data, 23, rand, null, false, { kind: 'trainer', biome: 'base-rocket' })
    expect(grunt.grunt).toBe('rocket')
    expect(grunt.foes.length).toBeGreaterThan(0)
    const brock = data.bosses[0].leaders.find((l) => l.id === 'kanto-brock')
    expect(bossScene(data, { ...brock, region: 'Kanto' })).toBe('gym-rock')
    expect(bossScene(data, { kind: 'champion', region: 'Kanto' })).toBe('champion-kanto')
    expect(bossScene(data, { kind: 'villain', name: 'Archie' })).toBe('base-aqua')
    expect(bossScene(data, null, 'forest')).toBe('forest')
  })

  it('no mar, a bifurcação tem a opção de mergulhar (selvagem do fundo do mar, só quem vive debaixo d’água)', () => {
    let seed = 3
    const rand = () => { const [v, s] = nextRandom(seed); seed = s; return v }
    const deep = encounterFor(data, 20, rand, null, false, { kind: 'wild', biome: 'underwater' })
    expect(data.species[deep.foes[0].id][6]).toContain('underwater')
    expect(data.species[515][6]).not.toContain('underwater')
  })

  it('selvagens pela raridade: os comuns (taxa de captura alta) aparecem bem mais', () => {
    let seed = 7
    const rand = () => { const [v, s] = nextRandom(seed); seed = s; return v }
    const count = { common: 0, rare: 0 }
    for (let i = 0; i < 600; i++) {
      const id = encounterFor(data, 6, rand, null, false, { kind: 'wild' }).foes[0].id
      const rate = data.species[id][5]
      if (rate >= 190) count.common++
      else if (rate <= 45) count.rare++
    }
    expect(count.common).toBeGreaterThan(count.rare * 3)
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

  it('o Poké Mart da cidade (o estoque dela), com Poké Balls e itens da Bolsa; o Centro Pokémon cura', () => {
    let run = startRun(emptyFactory(), data, 1, 5)
    run = { ...run, floor: CITY_BOSS, leg: 1, boss: { region: data.bosses.findIndex((b) => b.game === 'Red/Blue'), step: 1 }, encounter: { kind: 'trainer', foes: [{ id: 19, level: 12, iv: 0, ev: 0 }] } }
    const won = winFloor(run, data)
    // Chegando na cidade não abre a loja sozinha: ela é um lugar da cidade.
    expect(won.pending.shop).toBe(null)
    const town = nextFloor(won, data)
    const after = townShop(town)
    expect(townShop(after)).toBe(after)
    const healed = townCenter({ ...town, team: town.team.map((m) => ({ ...m, hp: 0 })) })
    expect(healed.team.every((m) => m.hp === 1)).toBe(true)
    // Vários tipos de bola e de remédio.
    const balls = after.pending.shop.filter((id) => BALL_TIERS.includes(id))
    const heals = after.pending.shop.filter((id) => HEAL_TIERS.includes(id))
    expect(balls.length).toBe(2)
    expect(heals.length).toBe(2)
    expect(won.pending.cards).toBe(null)
    const shop = { ...after, money: 100000 }
    for (const id of [...balls, ...heals]) expect(buyItem(shop, id, 0, data).bag[id]).toBe((shop.bag[id] ?? 0) + 1)
    // Preços sobem com o andar; o Rare Candy também com o nível do time.
    expect(shopPrice({ ...run, floor: 50 }, 'poke-ball')).toBeGreaterThan(shopPrice({ ...run, floor: 1 }, 'poke-ball'))
    const high = { ...run, team: [{ ...run.team[0], level: 60 }] }
    expect(shopPrice(high, 'rare-candy')).toBeGreaterThan(shopPrice(run, 'rare-candy') * 5)
  })

  it('evoluídos só a partir do nível em que evoluem: abaixo dele, a forma anterior (nada de Sceptile nível 2)', () => {
    expect([minLevelOf(data, 252), minLevelOf(data, 253), minLevelOf(data, 254)]).toEqual([1, 16, 36])
    expect([devolve(data, 254, 2), devolve(data, 254, 20), devolve(data, 254, 40)]).toEqual([252, 253, 254])
    // Por pedra: a partir do nível 20 (e nunca antes da forma anterior).
    expect(minLevelOf(data, 26)).toBe(25)
    let state = 8
    const rand = () => { const [v, s] = nextRandom(state); state = s; return v }
    const red = data.bosses.find((b) => b.game === 'Ruby/Sapphire') ?? data.bosses[0]
    for (let floor = 1; floor <= 40; floor++) {
      for (const node of [{ kind: 'wild', biome: 'forest' }, { kind: 'trainer' }, { kind: 'ace' }]) {
        for (const f of encounterFor(data, floor, rand, null, false, node).foes) expect(f.level).toBeGreaterThanOrEqual(minLevelOf(data, f.id))
      }
      for (const leader of red.leaders) for (const f of encounterFor(data, floor, rand, { ...leader, region: red.region, game: red.game }).foes) expect(f.level).toBeGreaterThanOrEqual(minLevelOf(data, f.id))
      for (const f of encounterFor(data, floor, rand, null, true).foes) expect(f.level).toBeGreaterThanOrEqual(minLevelOf(data, f.id))
    }
  })

  it('loja: bolas e remédios melhores ficam mais comuns conforme o andar', () => {
    let state = 4
    const rand = () => { const [v, s] = nextRandom(state); state = s; return v }
    const count = (list, floor, step) => {
      const out = Object.fromEntries(list.map((id) => [id, 0]))
      for (let i = 0; i < 3000; i++) out[tierPick(list, floor, step, rand)]++
      return out
    }
    const early = count(BALL_TIERS, 1, 25), mid = count(BALL_TIERS, 25, 25), late = count(BALL_TIERS, 60, 25)
    expect(early['poke-ball']).toBeGreaterThan(early['great-ball'])
    expect(early['ultra-ball']).toBeGreaterThan(0)
    expect(mid['great-ball']).toBeGreaterThan(mid['poke-ball'])
    expect(late['ultra-ball']).toBeGreaterThan(late['great-ball'])
    const heals = count(HEAL_TIERS, 70, 20)
    expect(heals['max-potion']).toBeGreaterThan(heals.potion)
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
    const after = winFloor(run, data, { captured: true })
    expect(after.stash).toEqual(['charizardite-x'])
    expect(after.pending.drop).toBe('charizardite-x')
    expect(after.pending.capture.id).toBe(6)
    expect(foeMember(run.encounter.foes[0], ['tackle']).set).toMatchObject({ item: 'charizardite-x', gimmick: 'mega' })
  })

  it('chefe da história deixa um Cristal Z; acabou a história, começa a de outra região (com o fim e o começo da história)', () => {
    let run = startRun(emptyFactory(), data, 4, 3)
    const game = data.bosses[run.boss.region]
    run = { ...run, floor: 10, boss: { region: run.boss.region, step: game.leaders.length - 1 } }
    run = chooseNode(nextFloor(run, data), data, 0)
    const after = winFloor(run, data)
    expect(after.boss.step).toBe(0)
    expect(data.bosses[after.boss.region].region).not.toBe(game.region)
    expect(after.played).toEqual([game.region, data.bosses[after.boss.region].region])
    expect(after.pending.story).toContain(storyLine(data, game.region, 'end'))
    expect(after.pending.story).toContain(storyLine(data, data.bosses[after.boss.region].region, 'intro'))
    // Cristal Z só dos chefes de Alola.
    if (game.region === 'Alola') expect(Object.values(data.zcrystals)).toContain(after.stash[0])
    else expect(Object.values(data.zcrystals)).not.toContain(after.stash?.[0])
    const alola = data.bosses.findIndex((b) => b.region === 'Alola')
    let inAlola = { ...startRun(emptyFactory(), data, 4, 3), floor: 10, boss: { region: alola, step: data.bosses[alola].leaders.length - 1 } }
    inAlola = winFloor(chooseNode(nextFloor(inAlola, data), data, 0), data)
    expect(Object.values(data.zcrystals)).toContain(inAlola.stash[0])
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

// O mesmo roteiro no app (test/factory_run_test.dart): 80 andares com chefes, captura, carta e loja.
// Para gerar de novo: UPDATE_FACTORY_TRACE=1 npx vitest run src/lib/factoryRun.test.js
function factoryTrace(F, data) {
  let run = F.startRun(F.emptyFactory(), data, 7, 2024)
  const out = []
  for (let i = 0; i < 80; i++) {
    const options = run.route.options
    // Na cidade: compra no Poké Mart dela antes de escolher (o ginásio ou o lugar perto dela).
    if (run.route.town) {
      run = F.townShop({ ...run, money: run.money + 500 })
      for (const id of run.pending.shop) run = F.buyItem(run, id, 0, data) ?? run
      run = { ...run, pending: null }
    }
    run = F.chooseNode(run, data, i % options.length)
    const encounter = run.encounter
    if (encounter) run = F.winFloor(run, data, { hp: run.team.map((_, k) => (k === 0 ? 0.7 : 1)), captured: i % 3 === 0 })
    run = { ...run, pending: run.pending ?? {} }
    if (run.pending.capture) run = F.capture(run, run.team.length >= F.MAX_TEAM ? 1 : null)
    if (run.pending.cards) run = F.takeCard(run, run.pending.cards[0], data)
    run = { ...run, money: run.money + 500 }
    for (const id of run.pending.shop ?? []) run = F.buyItem(run, id, 0, data) ?? run
    const pending = run.pending
    run = F.nextFloor(run, data)
    out.push([run.seed, run.floor, run.money, run.bag, run.boss.region, run.boss.step, run.team.map((m) => [m.id, m.level, m.exp, m.item ?? '', m.extras.length, m.hp]),
      options.map((o) => `${o.kind}${o.biome ? `:${o.biome}` : ''}`), encounter?.kind ?? '', (encounter?.foes ?? []).map((f) => [f.id, f.level, f.shiny ? 1 : 0]),
      pending.event ?? null, pending.reward ?? null, run.stash])
  }
  return out
}

describe('roteiro igual ao app', () => {
  it('80 andares dão o mesmo resultado que test/fixtures/factory_trace.json', async () => {
    const F = await import('./factoryRun')
    const trace = factoryTrace(F, data)
    const url = new URL('../../../test/fixtures/factory_trace.json', import.meta.url)
    const { writeFileSync } = await import('node:fs')
    if (process.env.UPDATE_FACTORY_TRACE) writeFileSync(url, JSON.stringify(trace) + '\n')
    expect(trace).toEqual(JSON.parse(readFileSync(url, 'utf8')))
    expect(trace.some((t) => t[8] === 'boss')).toBe(true)
    // O rival aparece de surpresa na rota (fora os da história).
    expect(trace.some((t) => t[8] === 'rival')).toBe(true)
    for (const kind of ['mart', 'event', 'ace']) expect(trace.some((t) => t[7].some((o) => o.startsWith(kind)))).toBe(true)
  })
})

describe('mapa da corrida', () => {
  const runAt = (floor, seed = 3) => ({ ...startRun(emptyFactory(), data, 4, seed), floor })

  it('cada chefe tem a sua cidade; a rota vai de uma cidade a outra', () => {
    for (const game of data.bosses) for (const l of game.leaders) expect(l.city?.length).toBeGreaterThan(2)
    const red = data.bosses.find((b) => b.game === 'Red/Blue')
    expect(red.leaders.find((l) => l.name === 'Brock').city).toBe('Pewter City')
    expect(red.leaders.at(-1).city).toBe('Indigo Plateau')
    const run = { ...runAt(1), boss: { region: data.bosses.indexOf(red), step: 2 } }
    expect(routeCities(data, run)).toEqual({ from: red.leaders[1].city, to: red.leaders[2].city })
  })

  it('o caminho só se divide nas bifurcações (2 a 3 caminhos, sempre uma batalha); Centro Pokémon raro', () => {
    let state = 5
    const rand = () => { const [v, s] = nextRandom(state); state = s; return v }
    const kinds = {}
    // Um líder de ginásio como próximo chefe (sem rival no caminho).
    const red = data.bosses.findIndex((b) => b.game === 'Red/Blue')
    const at = (floor, leg = 1) => ({ ...runAt(floor), leg, boss: { region: red, step: 1 } })
    for (let pos = 0; pos < ROUTE_LENGTH; pos++) {
      const route = routeOptions(at(11 + pos, 11), data, rand)
      // Na última bifurcação, a entrada do lugar no caminho (Viridian Forest, a caminho de Pewter City).
      expect(route.options.length).toBe(FORKS.includes(pos) ? (pos === FORKS[2] ? 4 : 3) : 1)
    }
    for (let i = 0; i < 600; i++) {
      const route = routeOptions(at(1 + FORKS[i % 3]), data, rand)
      expect(route.options.length).toBe((1 + FORKS[i % 3] <= 2 ? 2 : 3) + (i % 3 === 2 ? 1 : 0))
      expect(route.options.some(isBattleNode)).toBe(true)
      for (const o of route.options.filter((o) => o.kind !== 'dungeon')) kinds[o.kind] = (kinds[o.kind] ?? 0) + 1
      for (const o of route.options.filter((o) => o.kind === 'wild')) expect(Object.keys(BIOMES)).toContain(o.biome)
    }
    expect(Object.keys(kinds).sort()).toEqual(['ace', 'center', 'event', 'mart', 'trade', 'trainer', 'wild', 'wildboss'])
    expect(kinds.center).toBeLessThan(kinds.mart)
    for (let i = 0; i < 50; i++) for (const o of routeOptions(at(1), data, rand).options) expect(['wild', 'trainer']).toContain(o.kind)
  })

  it('rival e vilões aparecem em qualquer andar da rota (sempre antes da cidade); Elite Four e Campeão em sequência na Liga', () => {
    const red = data.bosses.findIndex((b) => b.game === 'Red/Blue')
    const leaders = data.bosses[red].leaders
    expect(leaders[0].kind).toBe('rival')
    const at = (floor, step, leg = 1) => ({ ...runAt(floor), leg, boss: { region: red, step } })
    // O rival: com sorte aparece logo; no último andar da rota, sempre.
    expect(routeOptions(at(3, 0), data, seq([0.1, 0.5])).options).toEqual([{ kind: 'boss' }])
    expect(routeOptions(at(1, 0), data, seq([0.1, 0.5])).options[0].kind).not.toBe('boss')
    expect(routeOptions(at(1, 0), data, seq([0.9, 0.5])).options[0].kind).not.toBe('boss')
    expect(routeOptions(at(CITY_BOSS, 0), data, seq([0.9, 0.5])).options).toEqual([{ kind: 'boss' }])
    // Dois rivais seguidos (Blue, Blue antes da Misty): os dois cabem antes do líder.
    const twice = leaders.findIndex((l, i) => l.kind === 'rival' && leaders[i + 1]?.kind === 'rival')
    expect(routeOptions(at(CITY_BOSS - 1, twice), data, seq([0.9, 0.5])).options).toEqual([{ kind: 'boss' }])
    // Na rota até o ginásio, o líder só aparece na cidade dele.
    expect(routeOptions(at(9, 1), data, seq([0.1, 0.5])).options[0].kind).not.toBe('boss')
    // A Elite Four: a primeira no fim da Victory Road; as outras e o Campeão, uma atrás da outra.
    const first = leaders.findIndex((l) => l.kind === 'elite')
    expect(routeOptions(at(5, first), data, seq([0.1, 0.5])).options[0].kind).not.toBe('boss')
    expect(routeOptions(at(1 + CITY_BOSS, first), data, seq([0.5])).options).toEqual([{ kind: 'boss' }])
    for (let step = first + 1; step < leaders.length; step++) expect(routeOptions(at(12, step, 12), data, seq([0.5])).options).toEqual([{ kind: 'boss' }])
    expect(routeCities(data, at(12, first + 1, 12))).toEqual({ from: 'Indigo Plateau', to: 'Indigo Plateau' })
    // A loja não abre sozinha: o Poké Mart é um lugar da cidade (também na da Liga).
    const before = { ...at(CITY_BOSS, 1), encounter: { kind: 'trainer', foes: [{ id: 19, level: 9, iv: 0, ev: 0 }] } }
    expect(winFloor(before, data).pending.shop).toBe(null)
    expect(winFloor({ ...before, boss: { region: red, step: first } }, data).pending.shop).toBe(null)
  })

  it('selvagem do lugar: só quem vive nele (nada fora do bioma; no fundo do mar, só quem vive debaixo d’água); Dusk Ball nos lugares escuros', () => {
    let state = 9
    const rand = () => { const [v, s] = nextRandom(state); state = s; return v }
    for (const biome of ['water', 'forest', 'underwater', 'cave']) {
      let local = 0
      for (let i = 0; i < 100; i++) {
        const e = encounterFor(data, 20, rand, null, false, { kind: 'wild', biome })
        expect(e.kind).toBe('wild')
        // O habitat dele (dos locais de encontro dos jogos) inclui o lugar.
        if (data.species[e.foes[0].id][6].includes(biome)) local++
      }
      expect(local).toBe(100)
    }
    const run = { ...runAt(20), encounter: { kind: 'wild', biome: 'cave', foes: [{ id: 74, level: 20 }] } }
    expect(captureFor(run, data)).toEqual({ rates: [255], dusk: true })
    expect(captureFor({ ...run, encounter: { kind: 'trainer', foes: [{ id: 74, level: 20 }] } }, data)).toBe(null)
  })

  it('treinador forte: um Pokémon a mais, mais forte, e sempre deixa um item', () => {
    let state = 2
    const rand = () => { const [v, s] = nextRandom(state); state = s; return v }
    const e = encounterFor(data, 30, rand, null, false, { kind: 'ace' })
    expect(e.kind).toBe('ace')
    expect(e.reward).toBeTruthy()
    const run = { ...runAt(30), encounter: { ...e, reward: 'ultra-ball' } }
    const after = winFloor(run, data)
    expect(after.bag['ultra-ball']).toBe(1)
    expect(after.pending.reward).toBe('ultra-ball')
    const held = winFloor({ ...run, encounter: { ...e, reward: 'leftovers' } }, data)
    expect(held.stash).toContain('leftovers')
    expect(winFloor({ ...run, encounter: { ...e, kind: 'trainer' } }, data).money).toBeLessThan(after.money)
  })

  it('sem batalha: Poké Mart (loja), Centro Pokémon (cura todos) e eventos; contam como um andar', () => {
    const base = { ...runAt(4), team: [{ ...runAt(4).team[0], hp: 0 }, { ...runAt(4).team[0], hp: 0.2 }] }
    const mart = chooseNode({ ...base, route: { floor: 4, options: [{ kind: 'mart' }] } }, data, 0)
    expect(mart.floor).toBe(5)
    expect(mart.encounter).toBe(null)
    expect(mart.pending.shop.length).toBeGreaterThanOrEqual(10)
    const center = chooseNode({ ...base, route: { floor: 4, options: [{ kind: 'center' }] } }, data, 0)
    expect(center.team.map((m) => m.hp)).toEqual([1, 1])
    for (let seed = 0; seed < 20; seed++) {
      const ev = chooseNode({ ...base, seed, route: { floor: 4, options: [{ kind: 'event' }] } }, data, 0)
      // Às vezes, uma escolha (ajudar, seguir um Pokémon ferido, caverna secreta).
      if (ev.pending.choice) {
        expect(CHOICE_EVENTS).toContain(ev.pending.choice.kind)
        continue
      }
      const { kind } = ev.pending.event
      if (kind === 'items') expect(ev.bag[ev.pending.event.item]).toBe((base.bag[ev.pending.event.item] ?? 0) + ev.pending.event.count)
      if (kind === 'money') expect(ev.money).toBeGreaterThan(0)
      if (kind === 'berries') expect(ev.team.map((m) => m.hp)).toEqual([0, 0.5])
      if (kind === 'tutor') expect(ev.tokens['move-tutor']).toBe(1)
    }
    const next = nextFloor(mart, data)
    expect(next.pending).toBe(null)
    expect(next.route.floor).toBe(5)
  })

  it('corridas antigas: as Poké Balls de fora vão para a Bolsa', () => {
    const run = { ...runAt(3), balls: 7 }
    const f = factoryOf({ factory: { ...emptyFactory(), run } })
    expect(f.run.balls).toBeUndefined()
    expect(f.run.bag['poke-ball']).toBe(START_BALLS + 7)
  })

  it('história: rival com o inicial de vantagem, lendário da região, missão da rota e escolhas', () => {
    expect(starterLine(data, 1)).toEqual([1, 2, 3])
    expect([rivalStarter(data, 1), rivalStarter(data, 4), rivalStarter(data, 7), rivalStarter(data, 19)]).toEqual([4, 7, 1, null])
    const base = startRun(emptyFactory(), data, 1, 42)
    expect(base.starter).toBe(1)
    expect(REGION_LEGENDS[data.bosses[base.boss.region].region]).toContain(regionLegend(data, base))
    expect(['defeat', 'catch']).toContain(base.mission.kind)
    expect(base.mission.leg).toBe(1)
    const red = data.bosses.findIndex((b) => b.game === 'Red/Blue')
    const step = (kind) => ({ region: red, step: data.bosses[red].leaders.findIndex((l) => l.kind === kind) })
    expect(newMission({ ...base, boss: step('villain'), dungeon: { place: 'base', scene: 'base-rocket', start: 1 } }, data, () => 0.5).kind).toBe('grunts')
    // O rival leva o inicial que vence o seu (Bulbasaur → a linha do Charmander).
    const rival = chooseNode({ ...base, boss: step('rival'), floor: 9, route: { floor: 9, biome: 'grass', options: [{ kind: 'boss' }] } }, data, 0)
    expect(rival.encounter.foes.some((f) => [4, 5, 6].includes(f.id))).toBe(true)
    // Missão: o terceiro Normal derrotado completa (dinheiro e item).
    const run = { ...base, money: 0, mission: { leg: 1, kind: 'defeat', type: 'normal', need: 3, done: 2 }, encounter: { kind: 'trainer', foes: [{ id: 19, level: 5, iv: 0, ev: 0 }] } }
    const won = winFloor(run, data, { bag: { potion: 1 } })
    expect(won.mission.done).toBe(3)
    expect(won.pending.mission.money).toBeGreaterThanOrEqual(MISSION_MONEY)
    expect(won.money).toBeGreaterThanOrEqual(won.pending.mission.money)
    expect(winFloor({ ...run, mission: { ...run.mission, type: 'fire' } }, data, {}).mission.done).toBe(2)
    // Escolhas.
    const at = { ...base, money: 1000, floor: 4, scene: 'grass' }
    expect(resolveChoice({ ...at, pending: { choice: { kind: 'help', cost: 100 } } }, data, false).pending.event.kind).toBe('declined')
    const helped = resolveChoice({ ...at, pending: { choice: { kind: 'help', cost: 100 } } }, data, true)
    expect(helped.money).toBe(900)
    expect(helped.pending.event.kind).toBe('helped')
    expect(resolveChoice({ ...at, money: 10, pending: { choice: { kind: 'help', cost: 100 } } }, data, true).money).toBe(10)
    expect(resolveChoice({ ...at, hms: ['flash'], pending: { choice: { kind: 'secret' } } }, data, true).pending.event.kind).toBe('secretFound')
    const follow = resolveChoice({ ...at, pending: { choice: { kind: 'follow' } } }, data, true)
    expect(follow.floor).toBe(3)
    expect(follow.encounter.kind).toBe('wild')
    expect(data.species[follow.encounter.foes[0].id][5]).toBeLessThanOrEqual(75)
    // Eventos novos: o mercador, a aposta e o Pokémon ferido.
    const bought = resolveChoice({ ...at, pending: { choice: { kind: 'merchant', cost: 300, item: 'master-ball' } } }, data, true)
    expect(bought.money).toBe(700)
    expect(bought.bag['master-ball']).toBe((at.bag['master-ball'] ?? 0) + 1)
    expect(resolveChoice({ ...at, money: 50, pending: { choice: { kind: 'merchant', cost: 300, item: 'master-ball' } } }, data, true).pending.event.kind).toBe('declined')
    const bet = resolveChoice({ ...at, pending: { choice: { kind: 'bet', cost: 100 } } }, data, true)
    expect([900, 1100]).toContain(bet.money)
    expect(['betWon', 'betLost']).toContain(bet.pending.event.kind)
    const healed = resolveChoice({ ...at, bag: { ...at.bag, potion: 2 }, pending: { choice: { kind: 'injured', mon: { id: 16, level: 5 } } } }, data, true)
    expect(healed.bag.potion).toBe(1)
    expect(healed.pending.capture).toEqual({ id: 16, level: 5 })
    expect(healed.pending.event.kind).toBe('injuredJoined')
    const noHeal = { potion: 0, 'super-potion': 0, 'hyper-potion': 0, 'max-potion': 0 }
    expect(resolveChoice({ ...at, bag: { ...at.bag, ...noHeal }, pending: { choice: { kind: 'injured', mon: { id: 16, level: 5 } } } }, data, true).pending.event.kind).toBe('noPotion')
  })

  it('relíquias: mudam a regra da corrida (bônus com um preço)', () => {
    const base = startRun(emptyFactory(), data, 1, 42)
    const ember = takeCard({ ...base, pending: { cards: ['atk', 'relic-ember'] } }, 'relic-ember', data)
    expect(ember.relics).toEqual(['relic-ember'])
    expect(ember.teamBoost.atk).toBeCloseTo(0.15)
    expect(ember.teamBoost.def).toBeCloseTo(-0.1)
    expect(ember.cards).toEqual(base.cards)
    const coin = takeCard({ ...base, pending: { cards: ['relic-coin'] } }, 'relic-coin', data)
    expect(coin.mult.money).toBeCloseTo(base.mult.money + 1)
    expect(coin.mult.shop).toBeCloseTo(base.mult.shop + 0.25)
    const spring = takeCard({ ...base, pending: { cards: ['relic-spring'] } }, 'relic-spring', data)
    expect(spring.winHeal).toBe(15)
  })

  it('jogabilidade: MOs pelas insígnias, Pokédex da corrida, Creche com ovo, revanche do Campeão', () => {
    const base = startRun(emptyFactory(), data, 1, 42)
    expect(HM_BADGES).toEqual({ 1: 'cut', 2: 'flash', 3: 'surf' })
    // Surf: sem ele, não mergulha; blindPick pula o caminho bloqueado.
    const sea = { ...base, route: { floor: 2, biome: 'water', options: [{ kind: 'wild', biome: 'underwater' }, { kind: 'trainer' }] } }
    expect(nodeBlocked(sea, sea.route.options[0])).toBe(true)
    expect(chooseNode(sea, data, 0)).toBe(sea)
    expect(blindPick(sea)).toBe(1)
    expect(nodeBlocked({ ...sea, hms: ['surf'] }, sea.route.options[0])).toBe(false)
    // Cut: um caminho escondido por rota.
    expect(cutPath(sea)).toBe(null)
    const cut = cutPath({ ...sea, hms: ['cut'] })
    expect(cut.route.options.at(-1)).toEqual({ kind: 'wild', biome: 'water', rare: true, cut: true })
    expect(cutPath(cut)).toBe(null)
    // Pokédex da corrida: o inicial já conta; a 5ª espécie dá o prêmio.
    expect(dexOf(base)).toEqual([1])
    const four = { ...base, dex: [1, 2, 3, 4] }
    expect(dexRewardFor(four, 4)).toBe(null)
    expect(dexRewardFor(four, 19)).toEqual(DEX_REWARDS[0])
    const caught = capture({ ...four, money: 0, pending: { capture: { id: 19, level: 5 } } })
    expect(caught.dex).toEqual([1, 2, 3, 4, 19])
    expect(caught.money).toBe(DEX_REWARDS[0].money)
    expect(caught.bag[DEX_REWARDS[0].item]).toBe((base.bag[DEX_REWARDS[0].item] ?? 0) + DEX_REWARDS[0].count)
    // Creche: um nível por andar e, depois de DAYCARE_EGG andares, um ovo com IVs bons.
    const two = { ...base, team: [base.team[0], { ...base.team[0], id: 19, level: 10 }] }
    expect(leaveDaycare(base, 0)).toBe(null)
    const left = leaveDaycare(two, 1)
    expect(left.team.length).toBe(1)
    const back = takeDaycare({ ...left, floor: left.floor + DAYCARE_EGG }, data)
    expect(back.team[1].level).toBe(10 + DAYCARE_EGG)
    // O ovo vai junto e choca depois de EGG_BATTLES vitórias.
    expect(back.eggs).toEqual([{ id: 19, left: EGG_BATTLES }])
    expect(back.pending).toBe(left.pending)
    let walk = back
    for (let k = 0; k < EGG_BATTLES; k++) {
      walk = winFloor({ ...walk, pending: null, encounter: { kind: 'trainer', foes: [{ id: 16, level: 3 }] } }, data)
      expect(walk.pending.capture).toEqual(k < EGG_BATTLES - 1 ? null : { id: 19, level: 5, egg: true })
    }
    expect(walk.eggs).toEqual([])
    // O ovo ocupa uma vaga: com 5 Pokémon e um ovo, o time está cheio (o capturado só entra trocando alguém).
    const five = { ...back, team: Array(5).fill(base.team[0]), pending: { capture: { id: 16, level: 3 } } }
    expect(teamRoom(five)).toBe(5)
    expect(capture(five)).toBe(five)
    expect(capture(five, 0).team[0].id).toBe(16)
    const egg = capture(walk)
    expect(Math.min(...Object.values(egg.team[2].ivs))).toBeGreaterThanOrEqual(EGG_IVS)
    expect(takeDaycare({ ...left, floor: left.floor + 1 }, data).pending).toBe(left.pending)
    // Revanche: o Campeão vencido vem na primeira bifurcação e some depois de vencido.
    const red = data.bosses.findIndex((b) => b.game === 'Red/Blue')
    const re = { ...base, rematch: { region: red } }
    expect(rematchBoss(data, re).kind).toBe('champion')
    const fight = chooseNode({ ...re, route: { floor: 2, biome: 'grass', options: [{ kind: 'rematch' }] } }, data, 0)
    expect(fight.encounter.kind).toBe('rematch')
    expect(fight.encounter.boss.kind).toBe('champion')
    const won = winFloor(fight, data, {})
    expect(won.rematch).toBe(null)
    expect(won.rematches).toBe(1)
    expect(won.boss).toEqual(fight.boss)
  })

  it('lugares novos, noite e estações (pelo relógio) e os efeitos novos', () => {
    for (const b of ['ruins', 'flowers', 'plant', 'crystal', 'dunes', 'bamboo', 'temple']) {
      expect(BIOME_IDS).toContain(b)
      expect(Object.values(data.species).some((s) => s[6].includes(b))).toBe(true)
    }
    expect(clockOf(new Date(2026, 0, 10, 21))).toEqual({ night: true, season: 'spring' })
    expect(clockOf(new Date(2026, 3, 10, 12))).toEqual({ night: false, season: 'winter' })
    expect(clockOf(new Date(2026, 9, 13, 5))).toEqual({ night: true, season: 'summer' })
    expect(SEASON_TYPES.winter).toEqual(['ice'])
    // No inverno neva no campo (em algum andar); fora do inverno, nunca neve no campo.
    const base = startRun(emptyFactory(), data, 1, 42)
    const floors = Array.from({ length: 40 }, (_, k) => ({ ...base, floor: k + 1 }))
    expect(floors.some((r) => weatherOf(r, 'grass', 'winter') === 'snow')).toBe(true)
    expect(floors.some((r) => weatherOf(r, 'grass', 'summer') === 'snow')).toBe(false)
    expect(weatherOf(base, 'grass')).toBe(weatherOf(base, 'grass', 'summer'))
    for (const effect of ['spores', 'quicksand', 'storm', 'aurora']) expect(Object.values(SCENE_FIELD).flat().some(([e]) => e === effect)).toBe(true)
    expect(floors.some((r) => fieldOf(r, 'flowers') === 'spores')).toBe(true)
    // À noite, mais Fantasma e Sombrio (o mesmo andar, com e sem a noite).
    const ghosts = (night) => {
      let n = 0
      for (let seed = 1; seed <= 60; seed++) {
        const run = { ...startRun(emptyFactory(), data, 1, seed), floor: 20, route: { floor: 20, biome: 'grass', options: [{ kind: 'trainer' }] } }
        const out = chooseNode(run, data, 0, night ? { night: true, season: 'spring' } : null)
        n += out.encounter.foes.filter((f) => data.species[f.id][4].some((t) => t === 'ghost' || t === 'dark')).length
      }
      return n
    }
    expect(ghosts(true)).toBeGreaterThan(ghosts(false))
  })

  it('a música de cada lugar (os chefes têm a deles)', () => {
    expect(placeMusic('grass')).toBe('place_field')
    expect(placeMusic('crystal')).toBe('place_cave')
    expect(placeMusic('tower')).toBe('place_spooky')
    expect(placeMusic('base-rocket')).toBe('place_city')
    expect(placeMusic('gym-fire')).toBe('battle_music')
    for (const b of BIOME_IDS) expect(placeMusic(b)).not.toBe('battle_music')
  })

  it('árvore de melhorias: a anterior, o andar recorde e os Pokémon pedem para avançar', () => {
    const f = { ...emptyFactory(), coins: 99999 }
    expect(upgradeNeeds(f, 'level')).toEqual([])
    expect(upgradeNeeds(f, 'ivs')).toEqual([{ kind: 'up', id: 'level', level: 2 }, { kind: 'best', floor: 8 }])
    expect(buyUpgrade(f, 'ivs')).toBe(null)
    let g = buyUpgrade(f, 'level')
    expect(upgradeNeeds(g, 'level')).toEqual([{ kind: 'best', floor: 3 }])
    g = buyUpgrade({ ...g, best: 3 }, 'level')
    expect(buyUpgrade({ ...g, best: 7 }, 'ivs')).toBe(null)
    expect(buyUpgrade({ ...g, best: 8 }, 'ivs').upgrades.ivs).toBe(1)
    expect(upgradeNeeds({ ...g, best: 99, upgrades: { reroll: 1 } }, 'cards')).toEqual([{ kind: 'owned', count: 8 }])
    expect(UPGRADE_BRANCHES.flatMap((b) => b[2]).sort()).toEqual(Object.keys(UPGRADES).sort())
  })

  it('tirar o item equipado: vai para os guardados e dá para equipar em outro', () => {
    const base = startRun(emptyFactory(), data, 1, 42)
    const run = { ...base, team: [{ ...base.team[0], item: 'leftovers', extras: ['life-orb'] }, { ...base.team[0], item: null, extras: [] }], stash: [] }
    const off = unequipItem(run, 0)
    expect(off.team[0].item).toBe(null)
    expect(off.stash).toEqual(['leftovers'])
    const extra = unequipItem(off, 0, 0)
    expect(extra.team[0].extras).toEqual([])
    expect(extra.stash).toEqual(['leftovers', 'life-orb'])
    expect(equipFromStash(extra, 0, 1).team[1].item).toBe('leftovers')
    expect(unequipItem(run, 1)).toBe(run)
  })
})

describe('batalhas duplas', () => {
  it('a dupla de treinadores luta em dupla a partir do andar DOUBLE_FLOOR, com 2 de pé', () => {
    const run = { floor: DOUBLE_FLOOR, encounter: { pair: true }, team: [{ hp: 1 }, { hp: 0.5 }] }
    expect(isDoubleBattle(run)).toBe(true)
    expect(isDoubleBattle({ ...run, floor: DOUBLE_FLOOR - 1 })).toBe(false)
    expect(isDoubleBattle({ ...run, encounter: {} })).toBe(false)
    expect(isDoubleBattle({ ...run, team: [{ hp: 1 }, { hp: 0 }] })).toBe(false)
  })
})

describe('cidade e lugares perto dela', () => {
  it('rota (10 andares, chefe no último) → cidade (10 andares, líder no último); na cidade, só lugares de cidade, dá para entrar em mais de um', () => {
    const red = data.bosses.findIndex((b) => b.game === 'Red/Blue')
    const start = { ...startRun(emptyFactory(), data, 4, 3), leg: 1, boss: { region: red, step: data.bosses[red].leaders.findIndex((l) => l.name === 'Erika') } }
    expect(targetOf(data, start).city).toBe('Celadon City')
    // O primeiro andar da cidade: o Poké Mart, o Centro e a Creche ficam nela.
    let run = nextFloor({ ...start, floor: 1 + ROUTE_LENGTH }, data)
    expect(townHub(data, run)).toBe(true)
    expect(run.route.town).toBe(true)
    expect(run.route.biome).toBe('city')
    // Na bifurcação da cidade, os lugares dela (do jogo), nunca floresta ou caverna.
    run = nextFloor({ ...run, floor: 1 + ROUTE_LENGTH + FORKS[0] }, data)
    const places = run.route.options.filter((o) => o.kind === 'dungeon').map((o) => o.place)
    expect(places).toEqual(['rocket-game-corner', 'rocket-hideout', 'celadon-department-store'])
    run = chooseNode(run, data, run.route.options.findIndex((o) => o.place === 'rocket-hideout'))
    expect(townHub(data, run)).toBe(false)
    expect(run.route.biome).toBe('base-rocket')
    run = nextFloor({ ...run, floor: run.floor + DUNGEON_LENGTH - 1 }, data)
    expect(run.route.options).toEqual([{ kind: 'dboss' }])
    run = nextFloor(winFloor(chooseNode(run, data, 0), data), data)
    // De volta ao mesmo andar da cidade; na próxima bifurcação, os que faltam.
    expect(routePos(run)).toBe(ROUTE_LENGTH + FORKS[0])
    expect(run.route.options).toHaveLength(1)
    run = nextFloor({ ...run, floor: run.floor + FORKS[1] - FORKS[0] }, data)
    expect(run.route.options.filter((o) => o.kind === 'dungeon').map((o) => o.place)).toEqual(['rocket-game-corner', 'celadon-department-store'])
    // O último andar da cidade: o líder.
    run = nextFloor({ ...run, floor: run.floor + CITY_BOSS - ROUTE_LENGTH - FORKS[1] }, data)
    expect(routePos(run)).toBe(CITY_BOSS)
    expect(run.route.options).toEqual([{ kind: 'boss' }])
    const won = winFloor(chooseNode(run, data, 0), data)
    expect(won.leg).toBe(won.floor)
    expect(won.places).toBe(undefined)
    expect(won.detour).toBe(undefined)
  })

  it('a água em ordem: praia → mar → fundo do mar → caverna aquática; vencendo um, segue ou volta; só a rota leva para a cidade', () => {
    expect(waterNext('beach')).toEqual({ id: 'sea', name: 'Mar', scene: 'water' })
    expect(waterNext('water').id).toBe('deep')
    expect(waterNext('underwater')).toEqual({ id: 'seacave', name: 'Caverna aquática', scene: 'seacave' })
    expect(waterNext('seacave')).toBe(null)
    const gs = data.bosses.findIndex((b) => b.game === 'Gold/Silver')
    // A rota até Olivine City é de praia: o mar é um lugar opcional na bifurcação (precisa de Surf).
    const start = { ...startRun(emptyFactory(), data, 4, 3), leg: 1, boss: { region: gs, step: data.bosses[gs].leaders.findIndex((l) => l.name === 'Jasmine') }, hms: ['surf'] }
    expect(targetOf(data, start).city).toBe('Olivine City')
    let run = nextFloor({ ...start, floor: 1 + FORKS[1] }, data)
    expect(run.route.biome).toBe('beach')
    const k = run.route.options.findIndex((o) => o.kind === 'dungeon')
    expect(run.route.options[k]).toEqual({ kind: 'dungeon', place: 'sea', scene: 'water' })
    expect(nodeBlocked({ ...run, hms: [] }, run.route.options[k])).toBe(true)
    run = chooseNode(run, data, k)
    run = nextFloor({ ...run, floor: run.floor + DUNGEON_LENGTH - 1 }, data)
    run = nextFloor(winFloor(chooseNode(run, data, 0), data), data)
    // Venceu o chefe do mar: mergulhar (fundo do mar) ou voltar.
    expect(run.route.options).toEqual([{ kind: 'dungeon', place: 'deep', scene: 'underwater', deeper: true }, { kind: 'leave' }])
    run = chooseNode(run, data, 0)
    expect(run.dungeon.entry).toBe(1 + FORKS[1])
    expect(run.route.biome).toBe('underwater')
    run = nextFloor({ ...run, floor: run.floor + DUNGEON_LENGTH - 1 }, data)
    run = nextFloor(winFloor(chooseNode(run, data, 0), data), data)
    run = chooseNode(run, data, 1)
    // De volta para a rota, no andar em que entrou na água (não vai para a cidade).
    expect(run.dungeon).toBe(null)
    expect(routePos(run)).toBe(FORKS[1])
    expect(townHub(data, run)).toBe(false)
    expect(run.places).toEqual(['sea', 'deep'])
  })

  it('rota de mar: começa pela praia e vira mar; o fundo do mar é opcional; as cavernas combinam com o lugar', () => {
    const red = data.bosses.findIndex((b) => b.game === 'Red/Blue')
    const at = (floor, name) => ({ ...startRun(emptyFactory(), data, 4, 3), leg: 1, floor, boss: { region: red, step: data.bosses[red].leaders.findIndex((l) => l.name === name) }, hms: ['surf'] })
    // Até Cinnabar Island: praia nos primeiros andares, depois o mar.
    expect(routeBiome(data, at(1, 'Blaine'))).toBe('beach')
    expect(routeBiome(data, at(SHORE, 'Blaine'))).toBe('beach')
    expect(routeBiome(data, at(1 + SHORE, 'Blaine'))).toBe('water')
    expect(nextFloor(at(1 + FORKS[1], 'Blaine'), data).route.options.some((o) => o.place === 'sea')).toBe(false)
    const deep = nextFloor(at(1 + FORKS[2], 'Blaine'), data).route.options
    expect(deep).toContainEqual({ kind: 'dungeon', place: 'deep', scene: 'underwater' })
    // A caverna no caminho combina com a rota: no pântano, venenosa; no mar, aquática; numa de grama, normal.
    const sinnoh = data.bosses.findIndex((b) => b.game === 'Diamond/Pearl')
    const wake = { ...startRun(emptyFactory(), data, 4, 3), boss: { region: sinnoh, step: data.bosses[sinnoh].leaders.findIndex((l) => l.name === 'Wake') } }
    expect(routeInfo(data, wake).side).toEqual({ id: 'ruin-maniac-cave', name: 'Ruin Maniac Cave', scene: 'poisoncave' })
    expect(routeInfo(data, at(1, 'Blaine')).side.scene).toBe('icecave')
    expect(routeInfo(data, at(1, 'Brock')).side.scene).toBe('forest')
    expect(CAVE_OF.volcano).toBe('lavacave')
    for (const scene of ['lavacave', 'poisoncave', 'seacave']) expect(BIOMES[scene].length).toBeGreaterThan(0)
  })

  it('o mapa do jogo: a rota até Pewter City; o lugar no caminho (Viridian Forest) tem 10 andares sem desvio e volta no mesmo andar da rota', () => {
    const red = data.bosses.findIndex((b) => b.game === 'Red/Blue')
    const start = { ...startRun(emptyFactory(), data, 4, 3), boss: { region: red, step: 1 } }
    expect(routeInfo(data, start).name).toBe('Route 1 · Route 2')
    expect(routeCities(data, { ...start, boss: { region: red, step: 0 } }).from).toBe('Pallet Town')
    let run = nextFloor({ ...start, floor: 1 + FORKS[2] }, data)
    expect(routePos(run)).toBe(FORKS[2])
    expect(run.route.biome).toBe('grass')
    const k = run.route.options.findIndex((o) => o.kind === 'dungeon')
    expect(run.route.options[k]).toEqual({ kind: 'dungeon', place: 'viridian-forest', scene: 'forest' })
    run = chooseNode(run, data, k)
    expect(run.dungeon).toEqual({ place: 'viridian-forest', scene: 'forest', start: 1 + FORKS[2] })
    expect(placeInfo(data, run, 'viridian-forest').name).toBe('Viridian Forest')
    // Dentro do lugar: sem desvio (um caminho por andar) até o chefe no 10º.
    for (let i = 0; i < DUNGEON_LENGTH - 1; i++) {
      expect(dungeonPos(run)).toBe(i)
      expect(run.route.options).toHaveLength(1)
      expect(run.route.biome).toBe('forest')
      run = nextFloor({ ...run, floor: run.floor + 1 }, data)
    }
    expect(run.route.options).toEqual([{ kind: 'dboss' }])
    run = chooseNode(run, data, 0)
    run = nextFloor(winFloor(run, data), data)
    // De volta na rota, no mesmo andar em que entrou, sem outro desvio; o lugar não aparece de novo.
    expect(run.dungeon).toBe(null)
    expect(routePos(run)).toBe(FORKS[2])
    expect(legOf(run)).toBe(1)
    expect(run.route.options).toHaveLength(1)
    expect(run.places).toEqual(['viridian-forest'])
    expect(routeOptions({ ...run, back: null }, data, () => 0.5).options.some((o) => o.kind === 'dungeon')).toBe(false)
    // A Escape Rope também leva de volta para o andar da rota.
    let rope = chooseNode(nextFloor({ ...start, floor: 1 + FORKS[2], bag: { 'escape-rope': 1 } }, data), data, k)
    rope = escapeRope({ ...rope, floor: rope.floor + 3 }, data)
    expect(routePos(rope)).toBe(FORKS[2])
    expect(rope.route.options).toHaveLength(1)
    // A rota seguinte (até Cerulean City): Mt. Moon no caminho.
    expect(routeInfo(data, { ...start, boss: { region: red, step: 2 } }).side.name).toBe('Mt. Moon')
  })

  it('lugar sem treinadores (mar, cavernas de gelo, lava...): só selvagens e o chefe é um selvagem forte, capturável', () => {
    const red = data.bosses.findIndex((b) => b.game === 'Red/Blue')
    const start = { ...startRun(emptyFactory(), data, 4, 3), leg: 1, boss: { region: red, step: 1 }, dungeon: { place: 'seacave', scene: 'seacave', start: 30 } }
    for (let k = 0; k < 30; k++) expect(['wild', 'event']).toContain(routeOptions({ ...start, floor: 31 + (k % 8) }, data, () => (k % 10) / 10).options[0].kind)
    let run = nextFloor({ ...start, floor: 39 }, data)
    expect(run.route.options).toEqual([{ kind: 'wildboss', area: true }])
    run = chooseNode(run, data, 0)
    expect(run.encounter).toMatchObject({ kind: 'wildboss', area: true })
    expect(run.encounter.foes[0].iv).toBeGreaterThanOrEqual(31)
    expect(['mega', 'dmax', 'tera']).toContain(run.encounter.foes[0].gimmick)
    // Vencendo (ou capturando), sai do lugar.
    const won = winFloor(run, data, { captured: true })
    expect(won.dungeon).toBe(null)
    expect(won.pending.capture).toBeTruthy()
  })

  it('chefes dos lugares usam Mega (a pedra dele), Gigantamax ou Tera', () => {
    expect(bossGimmick(data, { id: 6 }, () => 0.99)).toMatchObject({ item: 'charizardite-y', gimmick: 'mega' })
    expect(bossGimmick(data, { id: 12 }, () => 0)).toEqual({ id: 12, gimmick: 'dmax' })
    expect(bossGimmick(data, { id: 16 }, () => 0.99)).toEqual({ id: 16, gimmick: 'tera', tera: 'fairy' })
    expect(foeMember({ id: 16, level: 30, iv: 31, gimmick: 'tera', tera: 'fairy' }, ['tackle']).set).toMatchObject({ gimmick: 'tera', tera: 'fairy' })
    const red = data.bosses.findIndex((b) => b.game === 'Red/Blue')
    const start = { ...startRun(emptyFactory(), data, 4, 3), floor: 29, leg: 3, boss: { region: red, step: 3 } }
    const run = chooseNode({ ...start, route: { options: [{ kind: 'dboss' }], biome: 'grass' } }, data, 0)
    expect(run.encounter.kind).toBe('dboss')
    expect(['mega', 'dmax', 'tera']).toContain(run.encounter.foes.at(-1).gimmick)
  })

  it('o rival no começo (antes do andar 10) vem com um Pokémon só, sem IVs e EVs a mais', () => {
    const red = data.bosses.findIndex((b) => b.game === 'Red/Blue')
    const run = { ...startRun(emptyFactory(), data, 4, 3), floor: 5, boss: { region: red, step: 0 } }
    const foes = encounterFor(data, 5, () => 0.5, rivalBoss(data, run)).foes
    expect(foes).toHaveLength(1)
    expect(foes[0].iv).toBeLessThan(31)
    expect(RIVAL_FLOOR).toBeGreaterThanOrEqual(10)
  })
})

describe('ideias: amizade, habilidades fora da batalha, Nuzlocke', () => {
  const base = () => ({ ...startRun(emptyFactory(), data, 1, 42), encounter: { kind: 'trainer', foes: [{ id: 19, level: 5, iv: 0, ev: 0 }] } })
  it('amizade: a cada andar vencido; com FRIEND_EVOLVE, evolui (Eevee: Espeon de dia, Umbreon à noite)', () => {
    const run = { ...base(), team: [{ ...base().team[0], id: 133, friendship: FRIEND_EVOLVE - 1 }] }
    const day = winFloor(run, data, { night: false })
    expect(day.team[0].id).toBe(196)
    expect(day.pending.levels.some((l) => l.friend && l.evolved === 196)).toBe(true)
    expect(winFloor(run, data, { night: true }).team[0].id).toBe(197)
    expect(winFloor({ ...run, team: [{ ...run.team[0], friendship: 0 }] }, data).team[0].friendship).toBe(1)
    // A Eevee não evolui sozinha pelo nível.
    expect(levelTo({ ...run.team[0], friendship: 0 }, 40, data, () => 0)[0].id).toBe(133)
  })
  it('Pickup acha itens; Synchronize passa a Nature; Nuzlocke: quem desmaia vai embora e um capturado por rota', () => {
    let found = 0
    for (let seed = 1; seed < 60; seed++) {
      const r = winFloor({ ...base(), seed, team: [{ ...base().team[0], id: PICKUP[0] }] }, data)
      if (r.pending.picked) found++
    }
    expect(found).toBeGreaterThan(0)
    const lead = { ...base().team[0], id: SYNCHRONIZE[0], nature: 'Modest' }
    let same = 0
    for (let seed = 1; seed < 40; seed++) {
      const caught = capture({ ...base(), seed, team: [lead], pending: { capture: { id: 19, level: 5 } } })
      if (caught.team[1].nature === 'Modest') same++
    }
    expect(same).toBeGreaterThan(10)
    const nuz = { ...startRun(emptyFactory(), data, 1, 42, false, { nuzlocke: true }) }
    expect(nuz.nuzlocke).toBe(true)
    const two = { ...nuz, team: [nuz.team[0], { ...nuz.team[0], id: 7, hp: 0 }], encounter: { kind: 'trainer', foes: [{ id: 19, level: 5, iv: 0, ev: 0 }] } }
    const after = winFloor(two, data, { hp: [1, 0] })
    expect(after.team.map((m) => m.id)).toEqual([nuz.team[0].id])
    expect(after.pending.lost).toEqual([7])
    const wild = { ...nuz, encounter: { kind: 'wild', foes: [{ id: 19, level: 5 }] } }
    expect(captureFor(wild, data)).not.toBe(null)
    expect(captureFor({ ...wild, caughtLeg: legOf(wild) }, data)).toBe(null)
  })
})

describe('corrida da semana e cosméticos', () => {
  it('a mesma semente, o mesmo inicial e a mesma regra para todos na semana', () => {
    const a = weeklyOf(data, '2026-10-12'), b = weeklyOf(data, '2026-10-12'), c = weeklyOf(data, '2026-10-19')
    expect(a).toEqual(b)
    expect([a.seed, a.starter, a.rule]).not.toEqual([c.seed, c.starter, c.rule])
    const run = startWeekly(emptyFactory(), data, '2026-10-12')
    expect(run.weekly).toBe('2026-10-12')
    expect(run.team[0].id).toBe(a.starter)
    if (a.rule === 'noItems') expect(Object.values(run.bag).every((n) => n === 0)).toBe(true)
  })
  it('cosméticos: compra com moedas e usa a Poké Ball escolhida', () => {
    const rich = { ...emptyFactory(), coins: 2000 }
    const bought = buyCosmetic(rich, 'ball', 'luxury-ball')
    expect(bought.coins).toBe(2000 - COSMETIC_BALLS['luxury-ball'])
    expect(bought.ball).toBe('luxury-ball')
    expect(buyCosmetic(bought, 'ball', 'luxury-ball')).toBe(null)
    expect(buyCosmetic({ ...emptyFactory(), coins: 10 }, 'ball', 'luxury-ball')).toBe(null)
    expect(equipCosmetic(bought, 'ball', null).ball).toBe(null)
    expect(equipCosmetic(bought, 'ball', 'cherish-ball')).toBe(bought)
  })
})

describe('aprender golpe subindo de nível (igual ao app)', () => {
  it('os golpes novos com a regra do poder e aprender no lugar de outro', () => {
    const form = [['tackle', 'level-up', 1], ['ember', 'level-up', 13], ['flamethrower', 'level-up', 20], ['growl', 'egg', 0]]
    const moves = { tackle: { power: 40 }, ember: { power: 40 }, flamethrower: { power: 90 }, growl: { power: null } }
    expect(movesLearnedBetween(form, 12, 20, moves)).toEqual(['ember'])
    // Flamethrower (90 de poder) só a partir do nível 30.
    expect(movesLearnedBetween(form, 20, 30, moves)).toEqual(['flamethrower'])
    const run = { team: [{ id: 4, moves: ['tackle', 'ember', 'growl', 'scratch'] }] }
    expect(learnMove(run, 0, 'flamethrower', ['tackle', 'ember', 'growl', 'scratch'], 2).team[0].moves).toEqual(['tackle', 'ember', 'flamethrower', 'scratch'])
    expect(learnMove(run, 0, 'flamethrower', ['tackle']).team[0].moves).toEqual(['tackle', 'flamethrower'])
    // Com 4 e sem escolher qual esquecer, nada muda.
    expect(learnMove(run, 0, 'flamethrower', ['tackle', 'ember', 'growl', 'scratch'])).toBe(run)
  })
})
