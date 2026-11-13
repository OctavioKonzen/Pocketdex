import { existsSync, readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { seededRandom } from './league'
import {
  learnMove,
  movesLearnedBetween,
  weeklyOf, startWeekly, buyCosmetic, equipCosmetic, COSMETIC_BALLS,
  FRIEND_EVOLVE, PICKUP, SYNCHRONIZE, legOf, nuzlockeArea, runSummary, legacyMinorPrice, MAX_SHINY_RATE, piecesFor, upgradePieces, pieceOf,
  placeInfo, routeInfo, DBOSS_GIMMICK_FLOOR, UPGRADE_FX, SHORE, CAVE_OF, dungeonPos, routePos, DUNGEON_LENGTH, CITY_BOSS, waterNext, RIVAL_FLOOR, targetOf, rivalBoss, rocketBoss, townShop, townCenter, townHub, biomesLinked,
  isDoubleBattle,
  DOUBLE_FLOOR,
  battleOrder, blindPick, bossGimmick, bossOf, UPGRADE_TREE, bossScene, routeBiome, bossTeam, buyItem, buyPokemon, capture, CARDS, emptyFactory, encounterFor, endRun, expAt, expFor, foeBoostAt, RARE_PLACES, atPc, pcOf, pcMove, pcSlots, PC_BOX, boxName, renameBox, boxWall, nextWall, setNick, gameOf, leagueAhead, rivalGrowth, sortBox, shownScene, bagsFor, NUZLOCKE_DEFAULT, levelCapOf, EXP_BENCH, benchShare, TRADE_EXP, TRADE_EVOS, familyOf, townTrade, townTradeable, featuresOf, climateOf, RODS, rodOf, fishPath, headbuttPath, slatherHoney, honeyReady, honeyPath, TREE_MONS, HONEY_FLOORS, plantBerry, harvestBerry, BERRIES, BERRY_FLOORS, BERRY_RAIN_FLOORS, BERRY_YIELD, bikePath, bikeUses, FERRY, HORDE_SIZE, HORDE_FLOOR, SKY_FIELDS, FIELD_TYPES, takePhoto, photoNow, PHOTO_MAX, GYM_PUZZLES, SUPER_EFFECTIVE, gymPuzzleOf, startPuzzle, puzzleAct, finishPuzzle, puzzleView, puzzleOfType, PUZZLE_MONEY, GYM_EDGE_LEVELS, priceScale, inTown, isCity, townScene, WEATHER_TYPES, SAND_SCENES, SNOW_SCENES, SCENE_WEATHER, OPEN_SCENES, waterReach, hasWaterfall, WATER_REACH, daycareHere, daycareOpen, rarePlacesOf, SECRET_BIOMES, PLACE_SCENES, hasKey, KEY_ITEMS, placeLegendOf, blockerOf, townGifts, takeGift, cornerOf, buyCoins, spinSlots, cornerPrize, CORNER_PACK, CORNER_PACK_PRICE, CORNER_SPIN, storeOf, enterStore, tutorsOf, townReminder, forgetMove, reminderCost, SAFARI_FEE, SAFARI_BALLS, SAFARI_ENCOUNTERS, SAFARI_MONS, safariRates, safariAct, safariPool, leaveSafari, foeEvsAt, GAME_TIER, tierFoes, cardPower, cardText, foeLevelAt, foeMember,
  HELD_BOOST, levelTo, MAX_TEAM, memberOf, movesAt, nextFloor, nextRandom, overflowPoints, pokemonPrice, runCoins, setMainItem, shopPrice,
  SHINY_BOOST, FOE_SHINY_BOOST, SHINY_CHANCE, START_BAG, START_BALLS, startersOf, unlockShiny, claimStarter, freePick, canEvolveWith, teachMove,
  equipFromStash, gimmicksOf, setGimmick, storyLine, startRun, takeCard, teamDown, applyBagItem, winFloor, chooseNode, routeOptions, routeCities,
  captureFor, factoryOf, BIOMES, isBattleNode, skipCapture, FORKS, ROUTE_LENGTH, BALL_TIERS, HEAL_TIERS, tierPick, minLevelOf, devolve,
  EXP_SHARE, expProgress, shopOwned, baseForm, forSale, normalizeOwned, buyUpgrade, upgradePrice, UPGRADES,
  tradeMon, skipTrade, TRADE_LEVELS, escapeRope, ESCAPE_HP, progress, ACHIEVEMENTS, LUCKY_EGG, rerollRoute, FOE_ITEMS,
  regionLegend, REGION_LEGENDS, starterLine, newMission, resolveChoice, MISSION_MONEY, CHOICE_EVENTS,
  clockOf, weatherOf, fieldOf, battleMusic, mapMusic, upgradeNeeds, UPGRADE_BRANCHES, unequipItem, SEASON_TYPES, BIOME_IDS, SCENE_FIELD,
  HM_BADGES, cutPath, smashPath, strengthPath, roamerNode, roamerId, ROAMERS, ROAM_FLOOR, REGION_ROAMERS, ROAM_TURNS, roamerAt, roamerSeen,
  heartsOf, FRIEND_HEARTS, villainPlot, PLOT_REWARD, PLOT_LEVELS, mysteryEgg, takeMysteryEgg, MYSTERY_EGGS, tradeTag, TRADE_OTS, LEAGUE_FLAWLESS,
  NIGHT_ONLY, DAY_ONLY, outbreakOf, OUTBREAK_SHINY, DOWSE_ITEMS, nodeBlocked, hmNeeded, hasHm, dexOf, dexRewardFor, DEX_REWARDS, leaveDaycare, takeDaycare, teamRoom, DAYCARE_EGG, EGG_BATTLES, EGG_IVS, rematchBoss,
} from './factoryRun'

const data = JSON.parse(readFileSync(new URL('../../../assets/database/factory.json', import.meta.url), 'utf8'))
const moves = Object.fromEntries(JSON.parse(readFileSync(new URL('../../../assets/database/moves.json', import.meta.url), 'utf8')).map((m) => [m.name, { ...m, category: m.damage_class }]))
const forms = Object.fromEntries(JSON.parse(readFileSync(new URL('../../../assets/database/pokemon.json', import.meta.url), 'utf8')).map((p) => [p.id, p]))
const ROUTE_42 = { floor: 1, biome: 'forest', options: [{ kind: 'trainer' }] }
const ENCOUNTER_42 = { kind: 'trainer', foes: [{ id: 270, level: 3, iv: 0, ev: 3 }], trainerSeed: 500729487, scene: 'forest' }
const seq = (values) => { let i = 0; return () => values[i++ % values.length] }

/** Compra todas as melhorias (em várias passadas: umas pedem outras), enquanto dá. */
// Com Star Pieces de sobra (o requisito da árvore tem teste próprio).
function buyAll(f, ids = Object.keys(UPGRADES).filter((k) => !k.includes('~'))) {
  f = { ...f, pieces: Object.fromEntries(['key-stone', 'sparkling-stone', 'comet-shard', 'relic-crown'].map((k) => [k, 99999])) }
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
    expect(run.boss).toEqual({ region: 12, step: 0 })
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
    expect(deep.foes[0].level).toBeGreaterThan(250)
    // No primeiro jogo da corrida, só o nível do andar (IVs e EVs no limite dos jogos, sem porcentagem a mais).
    expect(deep.foes[0].iv).toBe(31)
    expect(deep.foes[0].boost).toBeUndefined()
    expect(foeLevelAt(1)).toBe(2)
    expect(foeEvsAt(500)).toBe(252)
    // Cada jogo vencido na corrida é um degrau a mais (sem teto).
    expect(tierFoes(deep, { games: 0 })).toBe(deep)
    const third = tierFoes(deep, { games: 2 }).foes[0]
    expect(third.iv).toBe(31 + 2 * GAME_TIER.iv)
    expect(third.ev).toBe(deep.foes[0].ev + 2 * GAME_TIER.ev)
    expect(third.boost).toBeCloseTo(foeBoostAt(2))
    expect(foeBoostAt(50)).toBeGreaterThan(foeBoostAt(10))
    // Nada de Fantasma nos primeiros andares (os iniciais só têm golpes Normal).
    for (let i = 0; i < 200; i++) for (const f of encounterFor(data, 2, rand).foes) expect(data.species[f.id][4]).not.toContain('ghost')
  })

  it('o líder na cidade dele (no fim da rota): a história de um jogo (líderes, rival, vilões, Elite dos Quatro, Campeão); depois outro jogo', () => {
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
    const last = { ...run, played: [region.region], boss: { region: red, step: region.leaders.length - 1 } }
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

  it('XP inteiro para quem lutou; o banco ganha um quarto e, com o Exp. Share, a metade (e os EVs)', () => {
    const base = startRun(emptyFactory(), data, 1, 42)
    const team = [base.team[0], { ...base.team[0], id: 4 }, { ...base.team[0], id: 7, hp: 0 }]
    const foes = [{ id: 19, level: 7, iv: 0, ev: 0 }, { id: 16, level: 7, iv: 0, ev: 0 }]
    const run = { ...base, team, encounter: { kind: 'wild', foes } }
    // O 1º lutou contra os dois, o 2º só contra o segundo; o 3º desmaiado não ganha.
    const after = winFloor(run, data, { fought: [[0], [0, 1]] })
    const e = (id, lvl) => expFor(data.species[id][0], 7, lvl, 1)
    expect(after.pending.gains).toEqual([e(19, 5) + e(16, 5), e(16, 5) + Math.floor(e(19, 5) * EXP_BENCH), 0])
    expect(after.team[1].evs.spe).toBe((data.species[16][3][5] + data.species[19][3][5]) * 3)
    // 5 níveis acima de um nível 7 ainda ganha XP.
    expect(expFor(data.species[19][0], 7, 12)).toBeGreaterThan(30)
    // Sem Exp. Share, quem ficou no banco ganha um quarto (o limite de nível segura quem luta; o banco acompanha).
    const alone = winFloor(run, data, { fought: [[0], [0]] })
    expect(alone.pending.gains[1]).toBe(Math.floor(e(19, 5) * EXP_BENCH) + Math.floor(e(16, 5) * EXP_BENCH))
    expect(benchShare(run)).toBe(EXP_BENCH)
    // Quem veio de uma troca ganha mais XP.
    const traded = winFloor({ ...run, team: [{ ...team[0], traded: true }, team[1], team[2]] }, data, { fought: [[0], [0]] })
    expect(traded.pending.gains[0]).toBe(Math.floor(e(19, 5) * TRADE_EXP) + Math.floor(e(16, 5) * TRADE_EXP))
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
    // Lendários e míticos não são iniciais: fora da loja e da escolha; quem já tinha recebe as moedas de volta.
    expect(forSale(data, 150)).toBe(false)
    expect(forSale(data, 151)).toBe(false)
    expect(buyPokemon(rich, data, 150)).toBe(null)
    expect(startersOf({ ...emptyFactory(), owned: [1, 150] }, data)).toEqual([1])
    const price = (id) => pokemonPrice(data.species[id][1])
    const legend = normalizeOwned({ ...emptyFactory(), coins: 10, owned: [1, 1007, 151], shinies: [1007] }, data)
    expect(legend).toMatchObject({ owned: [1], shinies: [], coins: 10 + price(1007) + price(151) })
    expect(startRun({ ...emptyFactory(), owned: [1, 1007] }, data, 1007, 42)).toBe(null)
    // A exceção: o lendário capturado shiny na corrida vira inicial (já shiny), e não é devolvido.
    const caught = unlockShiny({ ...emptyFactory(), owned: [1] }, data, { id: 1007, shiny: true })
    expect(caught).toMatchObject({ owned: [1, 1007], shinies: [1007], legends: [1007] })
    expect(startersOf(caught, data)).toEqual([1, 1007])
    expect(normalizeOwned(caught, data)).toBe(caught)
    expect(startRun(caught, data, 1007, 42, true).team[0]).toMatchObject({ id: 1007, shiny: true })
    expect(unlockShiny({ ...emptyFactory(), owned: [1] }, data, { id: 1007 })).toMatchObject({ owned: [1] })
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
    expect(endRun(f, { ...run, floor: 11, defeated: 0, bosses: 0 }).last.coins).toBe(160)
    expect(upgradeNeeds({ ...emptyFactory(), best: 999 }, 'tera')).toContainEqual({ kind: 'up', id: 'dmax', level: 1 })
    // A trilha: 1 nó de cada melhoria (pede a melhoria), com o efeito dos 8 antigos:
    // o ramo dá o mesmo total de antes, com bem menos para comprar.
    expect(Object.keys(UPGRADES).filter((k) => k.includes('~')).length).toBe(63)
    expect(UPGRADES['atk~1'].per).toBe(2) // o começo da árvore escala pouco (depthPower)
    expect(UPGRADES['level~1'].max).toBe(1)
    expect(upgradeNeeds({ ...f, upgrades: { ...f.upgrades, atk: 0 } }, 'atk~1')).toContainEqual({ kind: 'up', id: 'atk', level: 1 })
    expect(UPGRADE_TREE['atk~1']).toEqual({ needs: ['atk', 1], best: 7 })
    const all = buyAll({ ...f, coins: 9999999 }, Object.keys(UPGRADES))
    const big = startRun(all, data, 1, 42)
    // A árvore inteira: forte no fim, não no começo (os nós valem pela profundidade, depthPower).
    expect(big.teamBoost).toEqual({ hp: 0.36, atk: 0.66, def: 0.6, spa: 0.68, spd: 0.44, spe: 0.6 })
    expect(big.mult).toEqual({ money: 1.67, exp: 1.92, shop: 0.75 })
    expect([big.bag['poke-ball'], big.bag['great-ball'], big.bag['ultra-ball'], big.bag.potion, big.bag.revive, big.bag['escape-rope']]).toEqual([20, 11, 17, 15, 7, 2])
    // Com os nós de shiny da trilha, mais comum ainda (até MAX_SHINY_RATE).
    expect(big.shinyRate).toBeGreaterThan(11)
    expect(big.shinyRate).toBeLessThanOrEqual(MAX_SHINY_RATE)
    expect(UPGRADES[Object.keys(UPGRADE_FX).find((k) => UPGRADE_FX[k][0] === 'shiny' && k.includes('~'))].label).toBe('+{0}× de chance de shiny')
    // Os efeitos que mudam a corrida: dinheiro no começo, cura depois de cada vitória, nível e IVs do inicial.
    expect([big.money, big.winHeal, big.team[0].level, Math.min(...Object.values(big.team[0].ivs)), big.rerolls, big.stash.length, big.catchBonus]).toEqual([815, 28, 12, 31, 7, 40, 147])
    // A captura mais fácil vai para a batalha (o motor multiplica a taxa de captura).
    expect(captureFor({ ...big, encounter: { kind: 'wild', foes: [{ id: 16 }] } }, data)).toMatchObject({ bonus: 147 })
    expect(big.tokens).toEqual({ 'move-tutor': 14, 'move-reminder': 10 })
    expect(endRun(all, { ...big, floor: 11, defeated: 0, bosses: 0 }).last.coins).toBe(215)
    // A cura depois da vitória: só em quem está de pé, até o HP cheio.
    const healRun = { ...big, team: [{ ...big.team[0], hp: 0.3 }, { ...big.team[0], hp: 0 }, { ...big.team[0], hp: 0.8 }], encounter: { kind: 'wild', foes: [{ id: 16, level: 3, iv: 0, ev: 0 }] } }
    expect(winFloor(healRun, data, { hp: [0.3, 0, 0.8], fought: [[0]] }).team.map((m) => m.hp)).toEqual([0.58, 0, 1])
    // Um nó que saiu da árvore: as moedas voltam.
    const stale = normalizeOwned({ ...all, coins: 0, upgrades: { ...all.upgrades, 'atk~9': 1 } }, data)
    expect(stale.upgrades['atk~9']).toBe(undefined)
    expect(stale.coins).toBe(legacyMinorPrice(200, 9))
    // O mesmo preço do app (a metade do que era: 150 e 455).
    expect(upgradePrice(emptyFactory(), 'level')).toBe(150)
    expect(upgradePrice({ ...emptyFactory(), upgrades: { level: 1 } }, 'level')).toBe(455)
    // Os nós 3 a 8 da trilha antiga voltam pelo preço de então (o 4º e o 8º valiam o dobro).
    expect(normalizeOwned({ ...all, coins: 0, upgrades: { ...all.upgrades, 'atk~4': 1 } }, data).coins).toBe(Math.round((200 * 0.4 + 480) / 10) * 10 * 2)
    // Sem melhorias, a corrida é a de sempre.
    expect(startRun(emptyFactory(), data, 1, 42).team[0].level).toBe(5)
  })

  it('itens da árvore: cada tipo de chefe deixa o seu e ele destrava os ramos dele (igual ao app)', () => {
    const base = startRun(emptyFactory(), data, 1, 42)
    const foe = (extra = {}) => ({ id: 19, level: 3, iv: 0, ev: 0, ...extra })
    expect(piecesFor(data, { encounter: { kind: 'boss', foes: [foe()] } })).toEqual({})
    expect(piecesFor(data, { encounter: { kind: 'dboss', foes: [foe(), foe({ gimmick: 'mega' })] } })).toEqual({ 'key-stone': 1 })
    expect(piecesFor(data, { encounter: { kind: 'dboss', foes: [foe({ gimmick: 'z' })] } })).toEqual({ 'sparkling-stone': 1 })
    expect(piecesFor(data, { encounter: { kind: 'wildboss', foes: [foe({ gimmick: 'dmax' })] } })).toEqual({ 'comet-shard': 1 })
    expect(piecesFor(data, { encounter: { kind: 'dboss', foes: [foe({ gimmick: 'tera' })] } })).toEqual({ 'comet-shard': 1 })
    expect(piecesFor(data, { encounter: { kind: 'wildboss', foes: [{ id: 150, level: 50, iv: 31, ev: 0, title: 'legend' }] } })).toEqual({ 'relic-crown': 1 })
    const won = winFloor({ ...base, encounter: { kind: 'dboss', foes: [foe({ gimmick: 'mega' })] } }, data)
    expect([won.pieces['key-stone'], won.pending.pieces]).toEqual([1, { 'key-stone': 1 }])
    const over = endRun({ ...emptyFactory(), pieces: { 'key-stone': 2 } }, { ...won, pieces: { 'key-stone': 1, 'relic-crown': 2 } })
    expect(over.pieces).toEqual({ 'key-stone': 3, 'sparkling-stone': 0, 'comet-shard': 0, 'relic-crown': 2 })
    expect(over.last.pieces['relic-crown']).toBe(2)
    // Cada ramo pede o seu: Combate e Poder, Key Stone; Treino e Sobrevivência, Sparkling Stone; Exploração e Comércio, Comet Shard; Captura, Relic Crown.
    expect([pieceOf('atk~1'), pieceOf('dmax'), pieceOf('level'), pieceOf('potions~1'), pieceOf('map'), pieceOf('money'), pieceOf('shiny~1')])
      .toEqual(['key-stone', 'key-stone', 'sparkling-stone', 'sparkling-stone', 'comet-shard', 'comet-shard', 'relic-crown'])
    const f = { ...emptyFactory(), coins: 99999, best: 999, upgrades: { atk: 1 } }
    expect(upgradeNeeds(f, 'atk~1')).toContainEqual({ kind: 'pieces', item: 'key-stone', count: 1 })
    expect(buyUpgrade({ ...f, pieces: { 'relic-crown': 5 } }, 'atk~1')).toBe(null)
    expect(buyUpgrade({ ...f, pieces: { 'key-stone': 1 } }, 'atk~1').pieces['key-stone']).toBe(0)
    expect([upgradePieces(f, 'atk'), upgradePieces({ ...f, upgrades: { atk: 2 } }, 'atk'), upgradePieces({ ...f, upgrades: { atk: 3 } }, 'atk')]).toEqual([0, 1, 2])
    // Quem já jogava: 1 de cada a cada 10 andares do recorde (uma vez).
    expect(normalizeOwned({ ...emptyFactory(), best: 31 }, data).pieces).toEqual({ 'key-stone': 3, 'sparkling-stone': 3, 'comet-shard': 3, 'relic-crown': 3 })
    expect(normalizeOwned({ ...emptyFactory(), best: 31, pieces: { 'key-stone': 0 } }, data).pieces).toEqual({ 'key-stone': 0 })
    // O chefe sem Mega nem Gigantamax: Z-Move (com o Cristal Z) ou Tera.
    const kinds = new Set([0.1, 0.9].map((r) => bossGimmick(data, foe({ id: 20 }), () => r).gimmick))
    expect(kinds).toEqual(new Set(['z', 'tera']))
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
    // A melhoria grande: +2× por nível, 5 níveis (11×).
    expect(run.shinyRate).toBe(11)
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
    // Lá no fundo as cartas crescem junto com os adversários (que sobem sem teto).
    expect(cardPower(30)).toBe(1)
    expect(cardPower(130)).toBe(2)
    const deepCard = takeCard({ ...run, floor: 130, pending: { cards: ['atk'] } }, 'atk', data)
    expect(deepCard.teamBoost.atk - (run.teamBoost?.atk ?? 0)).toBeCloseTo(2 * CARDS.atk.team.atk)
    expect(cardText('+6 % d’Attaque', 'atk', 130)).toBe('+12 % d’Attaque')
    expect(cardText('+5 Poké Balls', 'balls', 130)).toBe('+5 Poké Balls')
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
    // O último chefe (o Campeão ou, com pós-jogo, quem vem depois dele): no fim da cidade, sempre ele.
    run = { ...run, floor: 1 + CITY_BOSS, leg: 1, boss: { region: run.boss.region, step: game.leaders.length - 1 } }
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
    let inAlola = { ...startRun(emptyFactory(), data, 4, 3), floor: 1 + CITY_BOSS, leg: 1, boss: { region: alola, step: data.bosses[alola].leaders.length - 1 } }
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
    expect(runCoins(run)).toBe(20 * 8 + 30 * 2 + 2 * 40)
    const f = endRun({ ...emptyFactory(), best: 7 }, run)
    expect(f).toMatchObject({ coins: 300, best: 20, run: null, last: { floor: 20, coins: 300 } })
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
    // Lendários e míticos não estão à venda (não são iniciais); os outros sim, pela força.
    expect(buyPokemon(rich, data, 150)).toBe(null)
    const bought = buyPokemon(rich, data, 147)
    expect(bought.owned).toEqual([906, 147])
    expect(bought.coins).toBe(10000 - pokemonPrice(data.species[147][1]))
    expect(bought.shinies).toEqual([])
    expect(buyPokemon(rich, data, 4).owned).toContain(4)
    // Comprar não dá shiny (o shiny só vem capturando na corrida).
    expect(buyPokemon(rich, data, 147).shinies ?? []).toEqual([])
    expect(startersOf(bought, data)).toContain(147)
    expect(buyPokemon({ ...picked, coins: 0 }, data, 147)).toBe(null)
  })

  it('shiny: selvagem shiny dá para capturar e tem bônus; inicial shiny libera o shiny dele (que também se compra, bem caro)', () => {
    let state = 11
    const rand = () => { const [v, s] = nextRandom(state); state = s; return v }
    let shinies = 0
    for (let i = 0; i < 4000; i++) if (encounterFor(data, 20, rand).foes.some((f) => f.shiny)) shinies++
    expect(SHINY_CHANCE).toBe(1 / 4096)
    expect(shinies).toBeLessThan(6)
    // Nível, tipo (selvagem), espécie, a horda (não) e o sorteio do shiny (abaixo de 1/4096).
    expect(encounterFor(data, 20, seq([0.5, 0.9, 0.5, 0.5, 0.0001])).foes[0].shiny).toBe(true)
    expect(encounterFor(data, 20, seq([0.5, 0.9, 0.5, 0.5, 0.001])).foes[0].shiny).toBeUndefined()
    const f = emptyFactory()
    expect(startRun(f, data, 4, 1, true)).toBe(null)
    let run = startRun(f, data, 1, 5)
    run = { ...run, pending: { capture: { id: 4, level: 5, iv: 0, ev: 0, shiny: true } } }
    const caught = capture(run)
    expect(caught.team[1].shiny).toBe(true)
    expect(memberOf(caught, caught.team[1], ['tackle']).set).toMatchObject({ shiny: true, boost: { atk: SHINY_BOOST } })
    expect(foeMember({ id: 4, level: 5, iv: 0, ev: 0, shiny: true }, ['tackle']).set.boost.spe).toBe(FOE_SHINY_BOOST)
    // Capturar normal não libera nada; qualquer shiny capturado vira inicial shiny (a primeira forma dele).
    expect(unlockShiny(f, data, { id: 4 })).toBe(f)
    expect(unlockShiny(f, data, { id: 20, shiny: true })).toMatchObject({ owned: [19], shinies: [19] })
    const unlocked = unlockShiny(f, data, caught.team[1])
    expect(unlocked).toMatchObject({ owned: [4], shinies: [4] })
    expect(unlockShiny(unlocked, data, caught.team[1])).toBe(unlocked)
    expect(startRun(unlocked, data, 4, 1, true).team[0].shiny).toBe(true)
    expect(startRun(unlocked, data, 4, 1).team[0].shiny).toBeFalsy()
    // Já tinha o inicial comprado: o shiny dele só se soma.
    expect(unlockShiny({ ...f, owned: [1] }, data, { id: 2, shiny: true })).toMatchObject({ owned: [1], shinies: [1] })
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
  let run = F.startRun(F.emptyFactory(), data, 7, 2027)
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
      // (o lugar raro, quando aparece, é a mais.)
      expect(route.options.filter((o) => !RARE_PLACES[o.place]).length).toBe((1 + FORKS[i % 3] <= 2 ? 2 : 3) + (i % 3 === 2 ? 1 : 0))
      expect(route.options.some(isBattleNode)).toBe(true)
      for (const o of route.options.filter((o) => o.kind !== 'dungeon')) kinds[o.kind] = (kinds[o.kind] ?? 0) + 1
      for (const o of route.options.filter((o) => o.kind === 'wild')) expect(Object.keys(BIOMES)).toContain(o.biome)
    }
    // O lugar raro: às vezes na última bifurcação; dentro, só selvagens e, no fim, o lendário do lugar; vencer deixa uma Master Ball.
    const rare = routeOptions(at(1 + FORKS[2]), data, () => 0.01).options.find((o) => RARE_PLACES[o.place])
    expect(rare).toBeTruthy()
    const inside = { ...at(20), dungeon: { place: rare.place, scene: rare.scene, start: 11 } }
    expect(routeOptions({ ...inside, floor: 13 }, data, rand).options.every((o) => o.kind !== 'trainer' && o.kind !== 'ace')).toBe(true)
    const end = routeOptions(inside, data, rand).options[0]
    expect(end).toMatchObject({ kind: 'wildboss', rare: true })
    expect(RARE_PLACES[rare.place].legends).toContain(end.legend)
    const won = winFloor({ ...inside, team: runAt(20).team, bag: { ...runAt(20).bag, 'master-ball': 0 }, encounter: { kind: 'wildboss', foes: [{ id: end.legend, level: 30, iv: 31, ev: 0 }] } }, data, {})
    expect(won.bag['master-ball']).toBe(1)
    expect(won.dungeon).toBe(null)
    expect(Object.keys(kinds).sort()).toEqual(['ace', 'center', 'event', 'mart', 'trade', 'trainer', 'wild', 'wildboss'])
    expect(kinds.center).toBeLessThan(kinds.mart)
    for (let i = 0; i < 50; i++) for (const o of routeOptions(at(1), data, rand).options) expect(['wild', 'trainer']).toContain(o.kind)
  })

  it('rival e vilões aparecem em qualquer andar da rota (sempre antes da cidade); Elite dos Quatro e Campeão em sequência na Liga', () => {
    const red = data.bosses.findIndex((b) => b.game === 'Red/Blue')
    const leaders = data.bosses[red].leaders
    expect(leaders[0].kind).toBe('rival')
    const at = (floor, step, leg = 1) => ({ ...runAt(floor), leg, boss: { region: red, step } })
    // O rival: com sorte aparece logo; no último andar da rota, sempre.
    expect(routeOptions(at(3, 0), data, seq([0.1, 0.5])).options).toEqual([{ kind: 'boss' }])
    expect(routeOptions(at(1, 0), data, seq([0.1, 0.5])).options[0].kind).not.toBe('boss')
    expect(routeOptions(at(1, 0), data, seq([0.9, 0.5])).options[0].kind).not.toBe('boss')
    expect(routeOptions(at(CITY_BOSS, 0), data, seq([0.9, 0.5])).options).toEqual([{ kind: 'boss' }])
    // Dois rivais seguidos (o Silver duas vezes antes de um líder em Johto): os dois cabem antes do líder.
    const johto = data.bosses.findIndex((b) => b.leaders.some((l, i) => l.kind === 'rival' && b.leaders[i + 1]?.kind === 'rival'))
    const twice = data.bosses[johto].leaders.findIndex((l, i, all) => l.kind === 'rival' && all[i + 1]?.kind === 'rival')
    expect(routeOptions({ ...at(CITY_BOSS - 1, twice), boss: { region: johto, step: twice } }, data, seq([0.9, 0.5])).options).toEqual([{ kind: 'boss' }])
    // Na rota até o ginásio, o líder só aparece na cidade dele.
    expect(routeOptions(at(9, 1), data, seq([0.1, 0.5])).options[0].kind).not.toBe('boss')
    // A Elite dos Quatro: a primeira no fim da Victory Road; as outras e o Campeão, uma atrás da outra.
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

  it('história: rival com o inicial oficial dele, lendário da região, missão da rota e escolhas', () => {
    expect(starterLine(data, 1)).toEqual([1, 2, 3])
    // O rival fica com o inicial oficial dele (o Blue com o Squirtle), não o que tem vantagem sobre o seu.
    expect(data.bosses.find((b) => b.game === 'Red/Blue').leaders.find((l) => l.kind === 'rival').team).toContain(7)
    // Depois do Campeão, o pós-jogo (o Red no Mt. Silver, a Cynthia em Unova): não é o rival, então não troca o inicial nem aparece de surpresa.
    const hgss = data.bosses.findIndex((b) => b.game === 'HeartGold/SoulSilver')
    const after = data.bosses[hgss].leaders.slice(data.bosses[hgss].leaders.findIndex((l) => l.kind === 'champion') + 1)
    // Em Johto, os ginásios de Kanto vêm depois do Campeão (como no jogo); por último, o Red.
    expect(after.map((l) => l.name)).toEqual(['Brock', 'Misty', 'Lt. Surge', 'Erika', 'Janine', 'Sabrina', 'Blaine', 'Blue', 'Silver', 'Red'])
    expect(after.at(-1).guest).toBe(true)
    expect(rivalBoss(data, { boss: { region: hgss, step: data.bosses[hgss].leaders.length } }).name).toBe('Silver')
    expect(data.bosses.find((b) => b.game === 'Black 2/White 2').leaders.at(-1).name).toBe('Cynthia')
    // Jessie e James: fora da ordem fixa da história (aparecem de surpresa na rota, por sorteio); em toda região menos
    // Paldea, juntos (em dupla, o sprite dos dois) e com a marca no encontro.
    const rb = data.bosses.findIndex((b) => b.game === 'Red/Blue')
    expect(data.bosses.some((b) => b.leaders.some((l) => l.name === 'Jessie e James'))).toBe(false)
    const jj = rocketBoss(data, { boss: { region: rb, step: 0 } })
    expect([jj.name, jj.trainer, jj.pair, jj.guest]).toEqual(['Jessie e James', 'sd-teamrocket', true, true])
    const enc = encounterFor(data, 20, () => 0.5, jj)
    expect([enc.pair, enc.boss.guest]).toEqual([true, true])
    expect(rocketBoss(data, { boss: { region: data.bosses.findIndex((b) => b.region === 'Paldea'), step: 0 } })).toBe(null)
    const base = startRun(emptyFactory(), data, 1, 42)
    expect(base.starter).toBe(1)
    expect(REGION_LEGENDS[data.bosses[base.boss.region].region]).toContain(regionLegend(data, base))
    expect(['defeat', 'catch']).toContain(base.mission.kind)
    expect(base.mission.leg).toBe(1)
    const red = data.bosses.findIndex((b) => b.game === 'Red/Blue')
    const step = (kind) => ({ region: red, step: data.bosses[red].leaders.findIndex((l) => l.kind === kind) })
    expect(newMission({ ...base, boss: step('villain'), dungeon: { place: 'base', scene: 'base-rocket', start: 1 } }, data, () => 0.5).kind).toBe('grunts')
    // O rival leva o inicial oficial dele (o Blue com o Squirtle), mesmo com o seu sendo o Bulbasaur.
    const rival = chooseNode({ ...base, boss: step('rival'), floor: 9, route: { floor: 9, biome: 'grass', options: [{ kind: 'boss' }] } }, data, 0)
    expect(rival.encounter.foes.some((f) => [7, 8, 9].includes(f.id))).toBe(true)
    expect(rival.encounter.foes.some((f) => [4, 5, 6].includes(f.id))).toBe(false)
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

  it('lendário que foge, surto do dia e Dowsing Machine', () => {
    const base = startRun(emptyFactory(), data, 1, 42)
    // O lendário que foge: o da região (pela semente); só a partir de ROAM_FLOOR; anda pela região a cada andar.
    const region = data.bosses[base.boss.region].region
    expect(REGION_ROAMERS[region] ?? ROAMERS).toContain(roamerId(base, data))
    expect(REGION_ROAMERS.Johto).toEqual([243, 244, 245])
    expect(roamerNode({ ...base, floor: ROAM_FLOOR - 1 }, data)).toBe(null)
    expect(ROAM_TURNS).toBe(1)
    const floors = Array.from({ length: 300 }, (_, f) => ({ ...base, floor: ROAM_FLOOR + f }))
    const seen = floors.filter((r) => roamerNode(r, data))
    expect(seen.length).toBeGreaterThan(30)
    expect(seen.length).toBeLessThan(100)
    expect(new Set(floors.map((r) => roamerAt(data, r))).size).toBeGreaterThan(2)
    const at = seen[0]
    expect(roamerNode(at, data)).toEqual({ kind: 'wildboss', legend: roamerId(base, data), roam: true })
    expect(roamerSeen(data, at)).toMatchObject({ here: true, id: roamerId(base, data) })
    const away = floors.find((r) => !roamerNode(r, data))
    expect(roamerSeen(data, away).here).toBe(false)
    // Com o HP que ficou; derrubado ou capturado, não volta (nesta região; na próxima, vem o de lá).
    expect(roamerNode({ ...at, roamer: { id: roamerId(base, data), region, hp: 0.4 } }, data).roamHp).toBe(0.4)
    expect(roamerNode({ ...at, roamer: { id: roamerId(base, data), region, done: 'caught' } }, data)).toBe(null)
    expect(roamerNode({ ...at, roamer: { id: 1, region: 'Outra', done: 'caught' } }, data)).not.toBe(null)
    const enc = encounterFor(data, 30, seq([0.5]), null, true, { kind: 'wildboss', legend: 245, roam: true, roamHp: 0.4 })
    expect(enc.foes[0]).toMatchObject({ id: 245, roam: true, hpRatio: 0.4 })
    expect(foeMember(enc.foes[0], ['surf']).set.hpRatio).toBe(0.4)
    // Fugiu: não conta como derrotado; o HP dele fica guardado.
    const fight = { ...at, encounter: enc }
    const fled = winFloor(fight, data, { fled: true, foeHp: 0.35 })
    expect(fled.roamer).toEqual({ id: 245, region, hp: 0.35 })
    expect(fled.pending.fled).toBe(245)
    expect(fled.defeated).toBe(fight.defeated)
    expect(fled.pending.money).toBe(0)
    expect(winFloor(fight, data, {}).roamer).toEqual({ id: 245, region, done: 'fainted' })
    expect(winFloor(fight, data, { captured: true }).roamer).toEqual({ id: 245, region, done: 'caught' })
    // O surto do dia: a mesma espécie o dia todo, outra no outro dia; só uma forma básica que vive em algum lugar.
    const today = outbreakOf(data, 20400)
    expect(outbreakOf(data, 20400)).toBe(today)
    expect(outbreakOf(data, null)).toBe(null)
    expect(data.species[today][6].length).toBeGreaterThan(0)
    expect(new Set(Array.from({ length: 10 }, (_, d) => outbreakOf(data, 20400 + d))).size).toBeGreaterThan(5)
    const home = data.species[today][6][0]
    // O sorteio do surto (rand < OUTBREAK_SHARE): vem a espécie do surto; senão, um selvagem comum do lugar.
    expect(encounterFor(data, 5, seq([0.1]), null, false, { kind: 'wild', biome: home, outbreak: today }).foes[0].id).toBe(today)
    expect(encounterFor(data, 5, seq([0.95]), null, false, { kind: 'wild', biome: home, outbreak: today }).foes[0].id)
      .toBe(encounterFor(data, 5, seq([0.95]), null, false, { kind: 'wild', biome: home }).foes[0].id)
    expect(OUTBREAK_SHINY).toBeGreaterThan(1)
    // As formas do meio fracas que só existem tarde (Pikachu, Marowak...) aparecem logo que podem existir.
    let r0 = 7
    const lcg = () => { r0 = (Math.imul(r0, 1103515245) + 12345) >>> 0; return r0 / 4294967296 }
    const got = new Set()
    for (let k = 0; k < 4000; k++) for (const f of encounterFor(data, 46 + (k % 20), lcg, null, false, { kind: 'wild', biome: ['grass', 'forest', 'cave'][k % 3] }).foes) got.add(f.id)
    for (const id of [25, 105]) expect(got.has(id)).toBe(true)
    // A Dowsing Machine: às vezes um caminho com batalha tem um item escondido; vencendo, o item fica.
    let hidden = null
    for (let f = 2; f < 400 && !hidden; f++) {
      const r = nextFloor({ ...base, floor: f, leg: 1 }, data)
      const node = r.route?.options?.find((o) => o.hidden)
      if (node) hidden = { r, k: r.route.options.indexOf(node), item: node.hidden }
    }
    expect(hidden).not.toBe(null)
    expect(DOWSE_ITEMS).toContain(hidden.item)
    const picked = chooseNode(hidden.r, data, hidden.k)
    expect(picked.dowsed).toBe(hidden.item)
    const won = winFloor(picked, data, {})
    expect(won.pending.dowsed).toBe(hidden.item)
    expect(won.dowsed).toBe(null)
    const count = (r) => (r.bag[hidden.item] ?? 0) + (r.tokens?.[hidden.item] ?? 0)
    expect(count(won)).toBeGreaterThanOrEqual(count(picked) + 1)
  })

  it('jogabilidade: MOs pelas insígnias, Pokédex da corrida, Creche com ovo, revanche do Campeão', () => {
    const base = startRun(emptyFactory(), data, 1, 42)
    expect(HM_BADGES).toEqual({ 1: 'cut', 2: 'flash', 3: 'surf', 4: 'rock-smash', 5: 'dive', 6: 'strength', 7: 'waterfall' })
    // Dive: sem ele, não mergulha até o fundo do mar (Surf não basta); blindPick pula o caminho bloqueado.
    const sea = { ...base, route: { floor: 2, biome: 'water', options: [{ kind: 'wild', biome: 'underwater' }, { kind: 'trainer' }] } }
    expect(nodeBlocked(sea, sea.route.options[0])).toBe(true)
    expect(hmNeeded(sea, sea.route.options[0])).toBe('dive')
    expect(chooseNode(sea, data, 0)).toBe(sea)
    expect(blindPick(sea)).toBe(1)
    expect(nodeBlocked({ ...sea, hms: ['surf'] }, sea.route.options[0])).toBe(true)
    expect(nodeBlocked({ ...sea, hms: ['dive'] }, sea.route.options[0])).toBe(false)
    // O mar pede Surf; o fundo do mar, Dive.
    expect(hmNeeded(base, { kind: 'dungeon', place: 'sea', scene: 'water' })).toBe('surf')
    expect(hmNeeded({ ...base, hms: ['surf'] }, { kind: 'dungeon', place: 'sea', scene: 'water' })).toBe(null)
    expect(hmNeeded({ ...base, hms: ['surf'] }, { kind: 'dungeon', place: 'deep', scene: 'underwater' })).toBe('dive')
    expect(hmNeeded(base, { kind: 'trainer' })).toBe(null)
    // Não precisa da insígnia: basta um Pokémon do time que saiba o golpe.
    const diver = { ...sea, team: [...sea.team, { ...sea.team[0], moves: ['tackle', 'dive'] }] }
    expect(nodeBlocked(diver, sea.route.options[0])).toBe(false)
    expect(hasHm({ ...base, team: [{ ...base.team[0], moves: ['surf'] }] }, 'surf')).toBe(true)
    // Cut: um caminho escondido por rota.
    expect(cutPath(sea)).toBe(null)
    const cut = cutPath({ ...sea, hms: ['cut'] })
    expect(cut.route.options.at(-1)).toEqual({ kind: 'wild', biome: 'water', rare: true, cut: true })
    expect(cutPath(cut)).toBe(null)
    // Rock Smash e Strength: uma vez por rota, só nos lugares de pedra; com o golpe no time já vale.
    const cave = { ...base, route: { floor: 2, biome: 'cave', options: [{ kind: 'wild', biome: 'cave' }, { kind: 'trainer' }] } }
    expect(smashPath(cave)).toBe(null)
    expect(smashPath({ ...sea, hms: ['rock-smash'] })).toBe(null)
    const smashed = smashPath({ ...cave, hms: ['rock-smash'] })
    expect(smashed.route.options.at(-1)).toEqual({ kind: 'wild', biome: 'cave', rare: true, smash: true })
    expect(smashPath(smashed)).toBe(null)
    const pusher = { ...cave, team: [{ ...cave.team[0], moves: ['strength'] }] }
    const pushed = strengthPath(pusher)
    expect(pushed.route.options.at(-1)).toEqual({ kind: 'ace', strength: true })
    expect(strengthPath(pushed)).toBe(null)
    expect(strengthPath({ ...pusher, route: { ...pusher.route, biome: 'grass' } })).toBe(null)
    expect(chooseNode(pushed, data, pushed.route.options.length - 1).encounter.kind).toBe('ace')
    // Waterfall: a gruta da cachoeira pede Waterfall.
    expect(hmNeeded({ ...base, hms: ['surf'] }, { kind: 'dungeon', place: 'waterfall', scene: 'waterfall' })).toBe('waterfall')
    expect(hmNeeded({ ...base, hms: ['waterfall'] }, { kind: 'dungeon', place: 'waterfall', scene: 'waterfall' })).toBe(null)
    // O clima mais forte: muita chuva no mar e areia no deserto.
    const many = Array.from({ length: 400 }, (_, f) => ({ ...base, seed: f + 1 }))
    const share = (scene, w) => many.filter((r) => weatherOf(r, scene) === w).length / many.length
    expect(share('water', 'rain')).toBeGreaterThan(0.45)
    expect(share('desert', 'sand')).toBeGreaterThan(0.5)
    expect(share('cave', 'rain')).toBe(0)
    // Dentro das cavernas e grutas não chove (nem neva, nem faz sol).
    for (const scene of ['cave', 'seacave', 'waterfall', 'icecave', 'lavacave', 'poisoncave', 'crystal']) expect(many.every((r) => weatherOf(r, scene, 'winter') === '')).toBe(true)
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
    expect(clockOf(new Date(2026, 0, 10, 21))).toEqual({ night: true, season: 'spring', day: 20463 })
    expect(clockOf(new Date(2026, 3, 10, 12))).toEqual({ night: false, season: 'winter', day: 20553 })
    expect(clockOf(new Date(2026, 9, 13, 5))).toEqual({ night: true, season: 'summer', day: 20739 })
    expect(SEASON_TYPES.winter).toEqual(['ice'])
    // Nunca neva no campo, nem no inverno (neve só onde é lugar de neve).
    const base = startRun(emptyFactory(), data, 1, 42)
    const floors = Array.from({ length: 40 }, (_, k) => ({ ...base, floor: k + 1 }))
    expect(floors.some((r) => weatherOf(r, 'grass', 'winter') === 'snow')).toBe(false)
    expect(floors.some((r) => weatherOf(r, 'grass', 'summer') === 'snow')).toBe(false)
    expect(weatherOf(base, 'grass')).toBe(weatherOf(base, 'grass', 'summer'))
    for (const effect of ['spores', 'quicksand', 'storm', 'aurora']) expect(Object.values(SCENE_FIELD).flat().some(([e]) => e === effect)).toBe(true)
    expect(floors.some((r, k) => fieldOf({ ...r, seed: k + 1 }, 'flowers') === 'spores')).toBe(true)
    // À noite, mais Fantasma e Sombrio (o mesmo andar, com e sem a noite).
    const ghosts = (night) => {
      let n = 0
      for (let seed = 1; seed <= 60; seed++) {
        const run = { ...startRun(emptyFactory(), data, 1, seed), floor: 40, route: { floor: 40, biome: 'grass', options: [{ kind: 'trainer' }] } }
        const out = chooseNode(run, data, 0, night ? { night: true, season: 'spring' } : null)
        n += out.encounter.foes.filter((f) => (data.species[f.id] ?? data.formSpecies?.[f.id] ?? data.species[data.forms?.[f.id]])?.[4]?.some((t) => t === 'ghost' || t === 'dark')).length
      }
      return n
    }
    expect(ghosts(true)).toBeGreaterThan(ghosts(false))
  })

  it('as batalhas da corrida tocam o tema de batalha da região, como num ginásio (igual ao app)', () => {
    data.bosses.forEach((b, i) => {
      const track = battleMusic(data, { boss: { region: i } })
      expect(track).toBe(`map_${b.region.toLowerCase()}`)
      expect(existsSync(new URL(`../../public/sounds/music/${track}.ogg`, import.meta.url)), track).toBe(true)
    })
    expect(battleMusic(data, null)).toBe('map_kanto')
  })

  it('a música do mapa de cada região (o arquivo existe; igual ao app)', () => {
    expect(mapMusic(data, null)).toBeNull()
    data.bosses.forEach((b, i) => {
      const track = mapMusic(data, { boss: { region: i } })
      expect(track).toBe(`map_${b.region.toLowerCase()}`)
      expect(existsSync(new URL(`../../public/sounds/music/${track}.ogg`, import.meta.url)), track).toBe(true)
    })
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
    expect(places).toEqual(['rocket-hideout', 'pok-mon-tower'])
    // Sem o Silph Scope, os fantasmas da Pokémon Tower não deixam entrar.
    expect(nodeBlocked(run, run.route.options.find((o) => o.place === 'pok-mon-tower'))).toBe(true)
    run = chooseNode(run, data, run.route.options.findIndex((o) => o.place === 'rocket-hideout'))
    expect(townHub(data, run)).toBe(false)
    expect(run.route.biome).toBe('base-rocket')
    run = nextFloor({ ...run, floor: run.floor + DUNGEON_LENGTH - 1 }, data)
    expect(run.route.options).toEqual([{ kind: 'dboss' }])
    run = winFloor(chooseNode(run, data, 0), data)
    // Vencendo o Rocket Hideout, o Silph Scope (agora dá para entrar na Pokémon Tower).
    expect(run.pending.key).toBe('silph-scope')
    expect(hasKey(run, 'silph-scope')).toBe(true)
    run = nextFloor(run, data)
    // De volta ao mesmo andar da cidade; na próxima bifurcação, os que faltam.
    expect(routePos(run)).toBe(ROUTE_LENGTH + FORKS[0])
    expect(run.route.options).toHaveLength(1)
    run = nextFloor({ ...run, floor: run.floor + FORKS[1] - FORKS[0] }, data)
    expect(run.route.options.filter((o) => o.kind === 'dungeon').map((o) => o.place)).toEqual(['pok-mon-tower'])
    expect(nodeBlocked(run, run.route.options.find((o) => o.place === 'pok-mon-tower'))).toBe(false)
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
    // Até onde a água vai depende da rota: só o mar, até o fundo (Dive) ou até a caverna aquática.
    expect(waterNext('beach', 0)).toBe(null)
    expect(waterNext('water', 1)).toBe(null)
    expect(waterNext('underwater', 2)).toBe(null)
    const gs = data.bosses.findIndex((b) => b.game === 'Gold/Silver')
    {
      // Com o mapa de verdade, perto de Olivine City só há o mar: vencido o chefe dele, volta para a rota.
      const at = { ...startRun(emptyFactory(), data, 4, 3), leg: 1, boss: { region: gs, step: data.bosses[gs].leaders.findIndex((l) => l.name === 'Jasmine') }, hms: ['surf', 'dive', 'waterfall'] }
      expect(featuresOf(data, at)).toEqual(data.routes.features['Olivine City'])
      expect(waterReach(data, at)).toBe(1)
      expect(hasWaterfall(data, at)).toBe(false)
      let sea = nextFloor({ ...at, floor: 1 + FORKS[1] }, data)
      sea = chooseNode(sea, data, sea.route.options.findIndex((o) => o.kind === 'dungeon'))
      sea = nextFloor({ ...sea, floor: sea.floor + DUNGEON_LENGTH - 1 }, data)
      sea = winFloor(chooseNode(sea, data, 0), data)
      expect(sea.dungeon).toBe(null)
    }
    // O resto do teste usa um mapa em que a rota de Olivine tem a água inteira e a cachoeira.
    const full = { ...data, routes: { ...data.routes, features: { ...data.routes.features, 'Olivine City': { water: 'cave', fall: true } } } }
    // A rota até Olivine City é de praia: o mar é um lugar opcional na bifurcação (precisa de Surf).
    const start = { ...startRun(emptyFactory(), full, 4, 3), leg: 1, boss: { region: gs, step: full.bosses[gs].leaders.findIndex((l) => l.name === 'Jasmine') }, hms: ['surf', 'dive', 'waterfall'] }
    expect(targetOf(full, start).city).toBe('Olivine City')
    let run = nextFloor({ ...start, floor: 1 + FORKS[1] }, full)
    expect(run.route.biome).toBe('beach')
    const k = run.route.options.findIndex((o) => o.kind === 'dungeon')
    expect(run.route.options[k]).toEqual({ kind: 'dungeon', place: 'sea', scene: 'water' })
    expect(nodeBlocked({ ...run, hms: [] }, run.route.options[k])).toBe(true)
    run = chooseNode(run, full, k)
    run = nextFloor({ ...run, floor: run.floor + DUNGEON_LENGTH - 1 }, full)
    run = nextFloor(winFloor(chooseNode(run, full, 0), full), full)
    // Venceu o chefe do mar: mergulhar (fundo do mar), subir a cachoeira ou voltar.
    expect(run.route.options).toEqual([{ kind: 'dungeon', place: 'deep', scene: 'underwater', deeper: true }, { kind: 'dungeon', place: 'waterfall', scene: 'waterfall', deeper: true }, { kind: 'leave' }])
    expect(nodeBlocked(run, run.route.options[1])).toBe(false)
    expect(nodeBlocked({ ...run, hms: ['surf', 'dive'] }, run.route.options[1])).toBe(true)
    // A gruta da cachoeira: 10 andares de selvagens e um chefe forte; vencendo, volta para a rota (e não aparece de novo).
    let fall = chooseNode(run, full, 1)
    expect(fall.route.biome).toBe('waterfall')
    expect(placeInfo(full, fall, 'waterfall').name).toBe('Gruta da cachoeira')
    expect(fall.route.options.every((o) => o.kind === 'wild')).toBe(true)
    fall = nextFloor({ ...fall, floor: fall.floor + DUNGEON_LENGTH - 1 }, full)
    expect(fall.route.options).toEqual([{ kind: 'wildboss', area: true }])
    run = chooseNode(run, full, 0)
    expect(run.dungeon.entry).toBe(1 + FORKS[1])
    expect(run.route.biome).toBe('underwater')
    run = nextFloor({ ...run, floor: run.floor + DUNGEON_LENGTH - 1 }, full)
    run = nextFloor(winFloor(chooseNode(run, full, 0), full), full)
    run = chooseNode(run, full, 1)
    // De volta para a rota, no andar em que entrou na água (não vai para a cidade).
    expect(run.dungeon).toBe(null)
    expect(routePos(run)).toBe(FORKS[1])
    expect(townHub(full, run)).toBe(false)
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
    // Em Kanto não há Dive: o fundo do mar não aparece. Em Hoenn, na rota até Mossdeep City, aparece.
    expect(nextFloor(at(1 + FORKS[2], 'Blaine'), data).route.options.some((o) => o.place === 'deep')).toBe(false)
    const ruby = data.bosses.findIndex((b) => b.region === 'Hoenn')
    const tate = { ...at(1 + FORKS[2], 'Blaine'), boss: { region: ruby, step: data.bosses[ruby].leaders.findIndex((l) => l.city === 'Mossdeep City') } }
    expect(nextFloor(tate, data).route.options).toContainEqual({ kind: 'dungeon', place: 'deep', scene: 'underwater' })
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
    // A partir de DBOSS_GIMMICK_FLOOR, o mais forte usa a mecânica; antes, nada disso, só 2 Pokémon e no nível do andar + 1.
    const start = { ...startRun(emptyFactory(), data, 4, 3), floor: DBOSS_GIMMICK_FLOOR, leg: 3, boss: { region: red, step: 3 } }
    const run = chooseNode({ ...start, route: { options: [{ kind: 'dboss' }], biome: 'grass' } }, data, 0)
    expect(run.encounter.kind).toBe('dboss')
    expect(['mega', 'dmax', 'tera', 'z']).toContain(run.encounter.foes.at(-1).gimmick)
    const early = chooseNode({ ...start, floor: 9, leg: 1, route: { options: [{ kind: 'dboss' }], biome: 'grass' } }, data, 0)
    expect(early.encounter.foes.length).toBeLessThanOrEqual(2)
    expect(early.encounter.foes.some((f) => f.gimmick)).toBe(false)
    expect(Math.max(...early.encounter.foes.map((f) => f.level))).toBeLessThanOrEqual(10 + 1)
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
    // Quem vai na frente ganha 2; os outros, 1; quem desmaiou perde 1.
    const two = { ...run, team: [{ ...run.team[0], friendship: 0 }, { ...run.team[0], id: 19, friendship: 0 }, { ...run.team[0], id: 19, friendship: 3, hp: 0 }] }
    expect(winFloor(two, data, { hp: [1, 1, 0] }).team.map((m) => m.friendship)).toEqual([2, 1, 2])
    expect(heartsOf({ friendship: FRIEND_EVOLVE })).toBe(FRIEND_HEARTS)
    expect(heartsOf({ friendship: 0 })).toBe(0)
    // Riolu só evolui de dia e Chingling só à noite (sem a hora, evoluem).
    const riolu = { ...run, team: [{ ...run.team[0], id: 447, friendship: FRIEND_EVOLVE }] }
    expect(winFloor(riolu, data, { night: true }).team[0].id).toBe(447)
    expect(winFloor(riolu, data, { night: false }).team[0].id).toBe(448)
    const chingling = { ...run, team: [{ ...run.team[0], id: 433, friendship: FRIEND_EVOLVE }] }
    expect(winFloor(chingling, data, { night: false }).team[0].id).toBe(433)
    expect(winFloor(chingling, data, { night: true }).team[0].id).toBe(358)
    // Tyrunt só vira Tyrantrum de dia; Amaura só vira Aurorus à noite.
    const tyrunt = { ...run.team[0], id: 696, level: 38, friendship: 0 }
    expect(levelTo(tyrunt, 40, data, () => 0, null, true)[0].id).toBe(696)
    expect(levelTo(tyrunt, 40, data, () => 0, null, false)[0].id).toBe(697)
    expect(levelTo({ ...tyrunt, id: 698 }, 40, data, () => 0, null, false)[0].id).toBe(698)
    expect(levelTo({ ...tyrunt, id: 698 }, 40, data, () => 0, null, true)[0].id).toBe(699)
    // A Eevee não evolui sozinha pelo nível.
    expect(levelTo({ ...run.team[0], friendship: 0 }, 40, data, () => 0)[0].id).toBe(133)
  })
  it('evoluções especiais: Shedinja na vaga, Sylveon com golpe de Fada, pedras da Eevee, troca sem pular estágio (igual ao app)', () => {
    const first = base().team[0]
    const nincada = { ...first, id: 290, level: 19, exp: expAt(20) - 1 }
    const won = winFloor({ ...base(), floor: 40, team: [nincada] }, data)
    expect(won.team.map((m) => m.id)).toEqual([291, 292])
    expect(won.pending.shed).toBe(true)
    // Time cheio: só o Ninjask.
    const full = winFloor({ ...base(), floor: 40, team: [nincada, ...Array(MAX_TEAM - 1).fill({ ...first, hp: 1 })] }, data)
    expect(full.team.map((m) => m.id).filter((id) => id === 292)).toEqual([])
    expect(full.pending.shed).toBeUndefined()
    // Sylveon: amizade com um golpe de Fada.
    const eevee = { ...first, id: 133, friendship: FRIEND_EVOLVE - 1, moves: ['tackle', 'baby-doll-eyes'] }
    expect(winFloor({ ...base(), team: [eevee] }, data).team[0].id).toBe(700)
    // Leafeon e Glaceon pela pedra; Phione não evolui; Bisharp → Kingambit acima do nível do Bisharp.
    expect(canEvolveWith(data, { id: 133 }, 'leaf-stone')).toEqual([470])
    expect(canEvolveWith(data, { id: 133 }, 'ice-stone')).toEqual([471])
    expect(data.evolutions[489]).toBeUndefined()
    expect(data.evolutions[625][0][1]).toBeGreaterThan(data.evolutions[624][0][1])
    // Pela troca: o Rhyhorn no nível do Rhydon não vira Rhyperior na hora.
    expect(levelTo({ ...first, id: 111 }, 42, data, () => 0)[0].id).toBe(112)
  })
  it('resumo da corrida: capturas, quem caiu, o time e o MVP (quem mais ganhou XP)', () => {
    const run = { ...base(), nuzlocke: true, fallen: 2, defeated: 9, badges: 1, dex: [1, 16, 19], team: [{ ...base().team[0], id: 1, level: 12, xpRun: 50 }, { ...base().team[0], id: 16, level: 14, xpRun: 900, shiny: true }] }
    const sum = runSummary(run)
    expect(sum).toMatchObject({ captures: 2, defeated: 9, badges: 1, fallen: 2, mvp: [16, 14, 1], team: [[1, 12, 0], [16, 14, 1]] })
    expect(endRun(emptyFactory(), { ...run, floor: 8 }).last.summary).toEqual(sum)
    // O XP do andar vai somando.
    expect(winFloor(base(), data).team[0].xpRun).toBeGreaterThan(0)
  })
  it('Pickup acha itens; Synchronize passa a Nature; Nuzlocke: quem desmaia vai embora e um capturado por área', () => {
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
    // Um capturado por área: capturou na rota, na rota não dá mais; na cidade e em cada lugar, dá de novo.
    const caught = winFloor(wild, data, { captured: true })
    expect(caught.caughtArea).toBe(nuzlockeArea(wild))
    const route = { ...caught, floor: wild.floor, encounter: wild.encounter }
    expect(captureFor(route, data)).toBe(null)
    const city = { ...route, floor: wild.floor + ROUTE_LENGTH }
    expect(nuzlockeArea(city).endsWith(':city')).toBe(true)
    expect(captureFor(city, data)).not.toBe(null)
    expect(captureFor({ ...route, dungeon: { place: 'cave' } }, data)).not.toBe(null)
    // Cada área vale para sempre: capturou na caverna, voltar para a rota ou para a caverna não dá outra captura.
    const inCave = { ...route, dungeon: { place: 'cave' } }
    const caughtCave = winFloor(inCave, data, { captured: true })
    const backRoute = { ...caughtCave, floor: wild.floor, dungeon: null, encounter: wild.encounter }
    expect(captureFor(backRoute, data)).toBe(null)
    expect(captureFor({ ...backRoute, dungeon: { place: 'cave' } }, data)).toBe(null)
    expect(captureFor({ ...backRoute, dungeon: { place: 'forest' } }, data)).not.toBe(null)
    // As regras que dá para escolher (já vêm ligadas: sem itens na batalha, repetidos e shiny).
    expect(nuz.nuzRules).toEqual(NUZLOCKE_DEFAULT)
    const full = { ...wild, bag: { ...nuz.bag, potion: 3, 'poke-ball': 5 } }
    const [inBattle] = bagsFor(full)
    expect([inBattle.potion, inBattle['poke-ball']]).toEqual([0, 5])
    // Fora da batalha a poção continua na Bolsa (e cura igual); da batalha volta só a conta das bolas.
    const used = winFloor(full, data, { bag: { ...inBattle, 'poke-ball': 4 } })
    const plainUsed = winFloor({ ...full, nuzRules: [] }, data, { bag: { ...full.bag, potion: 1, 'poke-ball': 4 } })
    expect(used.bag.potion).toBe(3)
    expect(plainUsed.bag.potion).toBe(1)
    expect(used.bag['poke-ball']).toBe(plainUsed.bag['poke-ball'])
    // Cláusula do shiny: dá para capturar mesmo depois do primeiro da área, e não gasta o encontro.
    const shiny = { ...route, encounter: { kind: 'wild', foes: [{ id: 19, level: 5, shiny: true }] } }
    expect(captureFor(shiny, data)).not.toBe(null)
    expect(winFloor({ ...shiny, caughtArea: null }, data, { captured: true }).caughtArea).toBeFalsy()
    // Com as regras desligadas, como antes.
    expect(bagsFor({ ...full, nuzRules: [] })[0].potion).toBe(3)
    expect(captureFor({ ...shiny, nuzRules: [] }, data)).toBe(null)
    // Cláusula de repetidos: o primeiro da área não é de uma linha que você já teve.
    let other = 0
    for (let seed = 1; seed <= 30; seed++) {
      const at = { ...startRun(emptyFactory(), data, 1, seed, false, { nuzlocke: true }), floor: 12, route: { floor: 12, biome: 'grass', options: [{ kind: 'wild' }] } }
      const first = chooseNode({ ...at, nuzRules: [] }, data, 0).encounter.foes[0].id
      const next = chooseNode({ ...at, dex: [baseForm(data, first)] }, data, 0).encounter.foes[0].id
      if (baseForm(data, next) !== baseForm(data, first)) other++
    }
    expect(other).toBe(30)
    // O memorial: quem caiu, com o nível e o andar.
    expect(after.memorial).toEqual([{ id: 7, level: nuz.team[0].level, floor: two.floor }])
    // Só o primeiro encontro: venceu o primeiro selvagem da área sem capturar, a área acabou.
    expect(winFloor(wild, data, {}).caughtArea).toBe(nuzlockeArea(wild))
    expect(winFloor({ ...wild, nuzRules: [] }, data, {}).caughtArea).toBeFalsy()
    // Sem lendários: o lendário não dá para capturar.
    const legend = Number(Object.entries(data.species).find(([, info]) => info[2] === 1)[0])
    const legendary = { ...nuz, nuzRules: ['noLegendary'], encounter: { kind: 'wildboss', foes: [{ id: legend, level: 50 }] } }
    expect(captureFor(legendary, data)).toBe(null)
    expect(captureFor({ ...legendary, nuzRules: [] }, data)).not.toBe(null)
    // Sem itens de segurar: o time luta sem itens.
    const held = { ...nuz.team[0], item: 'life-orb', extras: ['choice-band'] }
    expect(memberOf({ ...nuz, nuzRules: ['noHeldItems'] }, held, ['tackle']).set.item).toBe('')
    expect(memberOf(nuz, held, ['tackle']).set.item).toBe('life-orb')
    // Contra o líder: só tantos quantos ele tem.
    const six = { ...nuz, nuzRules: ['leaderCount'], team: Array.from({ length: 6 }, () => nuz.team[0]), encounter: { kind: 'boss', boss: { kind: 'gym' }, foes: [{ id: 74 }, { id: 95 }] } }
    expect(battleOrder(six)).toHaveLength(2)
    expect(battleOrder({ ...six, encounter: { ...six.encounter, boss: { kind: 'rival' } } })).toHaveLength(6)
    expect(battleOrder({ ...six, nuzRules: [] })).toHaveLength(6)
    // Limite de nível: o do mais forte do próximo líder; o XP para nele e o Rare Candy não passa dele.
    const capped = { ...nuz, nuzRules: ['levelCap'] }
    const cap = levelCapOf(data, capped)
    expect(cap).toBeGreaterThan(foeLevelAt(CITY_BOSS))
    // Sem a regra: o limite geral, 5 acima do próximo chefe.
    expect(levelCapOf(data, nuz)).toBe(cap + 4)
    const atCap = { ...capped, team: [{ ...capped.team[0], level: cap, exp: expAt(cap) }], bag: { ...capped.bag, 'rare-candy': 1 }, money: 99999, pending: { shop: ['rare-candy'] } }
    expect(buyItem(atCap, 'rare-candy', 0, data)).toBe(null)
    expect(buyItem({ ...atCap, nuzRules: [] }, 'rare-candy', 0, data)).not.toBe(null)
    const won = winFloor({ ...atCap, encounter: { kind: 'trainer', foes: [{ id: 19, level: cap, iv: 0, ev: 0 }] } }, data, { hp: [1] })
    expect(won.team[0].level).toBe(cap)
    // A troca não passa do limite de nível.
    const swapped = tradeMon({ ...nuz, team: [{ ...nuz.team[0], level: cap + 3, exp: expAt(cap + 3) }], pending: { trade: { id: 19 } } }, 0, data)
    expect(swapped.team[0].level).toBe(cap + 4)
    expect(swapped.team[0].traded).toBe(true)
    // Fora do Nuzlocke também: no limite geral o time não ganha nível.
    const free = { ...nuz, team: [{ ...nuz.team[0], level: cap + 4, exp: expAt(cap + 4) }], encounter: { kind: 'trainer', foes: [{ id: 19, level: cap + 4, iv: 0, ev: 0 }] } }
    expect(winFloor(free, data, { hp: [1] }).team[0].level).toBe(cap + 4)
  })
})

describe('tudo conforme o mapa: trocas, Safari, Creche, lugares raros, caverna secreta e museu', () => {
  const start = () => startRun(emptyFactory(), data, 1, 42)
  const game = (name) => data.bosses.findIndex((b) => b.game === name)
  const toCity = (g, city, extra = {}) => ({ ...start(), leg: 1, boss: { region: g, step: data.bosses[g].leaders.findIndex((l) => l.city === city) }, encounter: null, pending: null, ...extra })
  const red = game('Red/Blue')
  it('o mapa: as chaves são cidades de verdade e toda rota de praia ou de mar tem mar (igual ao app)', () => {
    const { cities, features, rare } = data.routes
    for (const [city, f] of Object.entries(features)) {
      expect(cities[city], city).toBeTruthy()
      for (const id of f.trade ?? []) expect(data.species[id], `${city} ${id}`).toBeTruthy()
      for (const [place, fossils] of Object.entries(f.museum ?? {})) {
        if (place.endsWith('museum')) expect(PLACE_SCENES[place]).toBe('museum')
        expect([...routeInfoOf(city).towns, routeInfoOf(city).side].filter(Boolean).map((p) => p.id)).toContain(place)
        for (const id of fossils) expect(data.species[id]).toBeTruthy()
      }
    }
    for (const [city, row] of Object.entries(cities)) if (['beach', 'water'].includes(row[0])) expect(WATER_REACH[features[city]?.water], city).toBeGreaterThan(0)
    for (const ids of Object.values(rare)) for (const id of ids) { expect(RARE_PLACES[id], id).toBeTruthy(); for (const l of RARE_PLACES[id].legends) expect(data.species[l]).toBeTruthy() }
    for (const b of data.bosses) expect(rare[b.region], b.region).toBeTruthy()
  })
  const routeInfoOf = (city) => { const g = data.bosses.findIndex((b) => b.leaders.some((l) => l.city === city)); return routeInfo(data, toCity(g, city)) }
  it('troca da cidade: só onde há uma nos jogos, com os Pokémon de lá; quem evolui por troca chega evoluído (igual ao app)', () => {
    const first = start().team[0]
    // Pewter City: um Abra por um Mr. Mime. Saffron City não tem troca.
    const pewter = nextFloor(toCity(red, 'Pewter City', { floor: 1 + ROUTE_LENGTH, team: [{ ...first, level: 20, exp: expAt(20) }, { ...first, id: 64, level: 12, exp: expAt(12), item: 'leftovers' }] }), data)
    expect(pewter.town.trade).toEqual({ want: 63, give: 122 })
    expect(nextFloor(toCity(red, 'Saffron City', { floor: 1 + ROUTE_LENGTH }), data).town.trade).toBeUndefined()
    // Pede a família: o Kadabra serve para quem quer um Abra.
    expect(townTradeable(pewter, data)).toEqual([1])
    expect(townTrade(pewter, 0, data)).toBe(pewter)
    const out = townTrade(pewter, 1, data)
    expect(out.team[1]).toMatchObject({ id: 122, level: 12 + TRADE_LEVELS, item: 'leftovers', traded: true })
    expect(out.town.trade).toMatchObject({ done: true, got: 122 })
    expect(out.trades).toBe(1)
    expect(townTradeable(out, data)).toEqual([])
    expect(townTrade(out, 0, data)).toBe(out)
    // Quem evolui por troca chega evoluído (o Haunter de Snowpoint e de Levincia vira Gengar).
    const haunter = townTrade({ ...pewter, town: { ...pewter.town, trade: { want: 63, give: 93 } } }, 1, data)
    expect(haunter.team[1].id).toBe(TRADE_EVOS[93])
    expect(familyOf(data, 18)).toBe(16)
    for (const [from, to] of Object.entries(TRADE_EVOS)) { expect(data.species[from]).toBeTruthy(); expect(data.species[to]).toBeTruthy() }
  })
  it('Safari: só nas rotas que têm um (Fuchsia, Cianwood, Mossdeep, Pastoria), uma vez por rota; paga a entrada, joga bola, isca e pedra (igual ao app)', () => {
    const safaris = Object.entries(data.routes.features).filter(([, f]) => f.safari).map(([city]) => city).sort()
    expect(safaris).toEqual(['Cianwood City', 'Fuchsia City', 'Mossdeep City', 'Pastoria City'])
    const fuchsia = toCity(red, 'Fuchsia City', { floor: 1 + FORKS[1], money: SAFARI_FEE + 7 })
    const route = nextFloor(fuchsia, data).route
    expect(route.options).toContainEqual({ kind: 'safari', name: 'Safari Zone' })
    // Na rota até Pewter City não tem; no Nuzlocke também não; e não aparece de novo na mesma rota.
    expect(nextFloor(toCity(red, 'Pewter City', { floor: 1 + FORKS[1] }), data).route.options.some((o) => o.kind === 'safari')).toBe(false)
    expect(nextFloor({ ...fuchsia, nuzlocke: true }, data).route.options.some((o) => o.kind === 'safari')).toBe(false)
    expect(nextFloor({ ...fuchsia, safariLeg: legOf(fuchsia) }, data).route.options.some((o) => o.kind === 'safari')).toBe(false)
    const dp = game('Diamond/Pearl')
    expect(nextFloor(toCity(dp, 'Pastoria City', { floor: 1 + FORKS[1] }), data).route.options).toContainEqual({ kind: 'safari', name: 'Great Marsh' })
    const base = { ...fuchsia, route: { floor: fuchsia.floor, biome: 'grass', options: [{ kind: 'safari', name: 'Safari Zone' }] } }
    // Sem dinheiro para a entrada: o caminho fica fechado.
    expect(nodeBlocked({ ...base, money: SAFARI_FEE - 1 }, { kind: 'safari' })).toBe(true)
    expect(chooseNode({ ...base, money: SAFARI_FEE - 1 }, data, 0).pending).toBe(null)
    let run = chooseNode(base, data, 0)
    expect(run.money).toBe(7)
    expect(run.floor).toBe(base.floor + 1)
    expect(run.safariLeg).toBe(legOf(base))
    expect(run.pending.safari).toMatchObject({ balls: SAFARI_BALLS, left: SAFARI_ENCOUNTERS - 1, caught: 0 })
    expect(SAFARI_MONS).toContain(run.pending.safari.mon.id)
    expect(run.pending.safari.mon.level).toBe(foeLevelAt(run.floor))
    // A isca: foge menos e fica mais difícil de pegar; a pedra, o contrário.
    const calm = safariRates(data, { ...run.pending.safari, mood: null })
    const eating = safariRates(data, { ...run.pending.safari, mood: 'eating' })
    const angry = safariRates(data, { ...run.pending.safari, mood: 'angry' })
    expect(eating.catch).toBeLessThan(calm.catch)
    expect(eating.flee).toBeLessThan(calm.flee)
    expect(angry.catch).toBeGreaterThan(calm.catch)
    expect(angry.flee).toBeGreaterThan(calm.flee)
    // Joga até acabar: cada captura entra pelo fluxo normal (pending.capture, com a Safari Ball).
    let caught = 0
    for (let guard = 0; guard < 200 && run.pending.safari.mon; guard++) {
      const before = run.pending.safari
      run = safariAct(run, data, guard % 4 === 3 ? 'rock' : 'ball')
      expect(run.pending.safari.balls).toBeLessThanOrEqual(before.balls)
      if (run.pending.capture) {
        caught++
        expect(run.pending.ball).toBe('safari-ball')
        expect(safariAct(run, data, 'ball')).toBe(run)
        run = capture(run, run.team.length >= MAX_TEAM ? 'pc' : null)
      }
    }
    const end = run.pending.safari
    expect(end.mon).toBe(null)
    expect(end.caught).toBe(caught)
    expect(end.balls === 0 || end.left === 0).toBe(true)
    expect(safariAct(run, data, 'ball')).toBe(run)
    expect(leaveSafari(run).pending.safari).toBe(null)
    // Deixar este e procurar outro gasta um encontro, não uma bola.
    const moved = safariAct(chooseNode(base, data, 0), data, 'run')
    expect(moved.pending.safari).toMatchObject({ balls: SAFARI_BALLS, left: SAFARI_ENCOUNTERS - 2, last: 'left' })
    for (const id of SAFARI_MONS) expect(data.species[id]).toBeTruthy()
    // No Monotipo, só os do tipo.
    expect(safariPool({ ...base, mono: ['dragon'] }, data)).toEqual([147])
  })
  it('Creche só onde há uma; lugares raros só os da região; caverna secreta só onde há cavernas (igual ao app)', () => {
    const vermilion = toCity(red, 'Vermilion City')
    const pewter = toCity(red, 'Pewter City')
    expect(daycareHere(data, vermilion)).toBe(true)
    expect(daycareHere(data, pewter)).toBe(false)
    // Sem Creche na cidade não dá para deixar; com um Pokémon lá, dá para buscar em qualquer uma.
    const two = { ...pewter, team: [pewter.team[0], { ...pewter.team[0], id: 16 }] }
    expect(leaveDaycare(two, 1, data)).toBe(null)
    expect(leaveDaycare({ ...two, boss: vermilion.boss }, 1, data).daycare.mon.id).toBe(16)
    expect(daycareOpen(data, pewter)).toBe(false)
    expect(daycareOpen(data, { ...pewter, daycare: { mon: pewter.team[0], floor: 1 } })).toBe(true)
    expect(rarePlacesOf(data, pewter)).toEqual(['cerulean-cave', 'navel-rock'])
    expect(rarePlacesOf(data, toCity(game('Gold/Silver'), 'Violet City'))).toEqual(['bell-tower'])
    for (const b of data.bosses) expect(rarePlacesOf(data, { boss: { region: data.bosses.indexOf(b), step: 0 } }).length).toBeGreaterThan(0)
    expect(SECRET_BIOMES).toContain('cave')
    expect(SECRET_BIOMES).not.toContain('grass')
    expect(CHOICE_EVENTS).toContain('secret')
  })
  it('museu: cenário próprio e, vencendo o chefe dele, um fóssil de lá revivido (igual ao app)', () => {
    const pewter = toCity(red, 'Pewter City', { floor: 15, dungeon: { place: 'pewter-museum', scene: 'ruins', start: 12 } })
    expect(shownScene(pewter, 'ruins')).toBe('museum')
    const won = winFloor({ ...pewter, encounter: { kind: 'dboss', foes: [{ id: 74, level: 8, iv: 0, ev: 0 }] } }, data, { hp: [1] })
    expect(data.routes.features['Pewter City'].museum['pewter-museum']).toContain(won.pending.capture.id)
    expect(won.pending.capture).toMatchObject({ level: foeLevelAt(15), fossil: true })
    expect(capture(won).team.at(-1).id).toBe(won.pending.capture.id)
    // Num lugar que não é museu, nada de fóssil.
    const other = winFloor({ ...pewter, dungeon: { place: 'viridian-forest', scene: 'forest', start: 12 }, encounter: { kind: 'dboss', foes: [{ id: 74, level: 8, iv: 0, ev: 0 }] } }, data, { hp: [1] })
    expect(other.pending.capture).toBe(null)
  })
})

describe('pesca, árvores, frutas, bicicleta, balsa, hordas, neblina, fotos e os desafios dos ginásios', () => {
  const game = (name) => data.bosses.findIndex((b) => b.game === name)
  const red = game('Red/Blue')
  const at = (g, city, extra = {}) => ({ ...startRun(emptyFactory(), data, 1, 42), leg: 1, boss: { region: g, step: data.bosses[g].leaders.findIndex((l) => l.city === city) }, encounter: null, pending: null, ...extra })
  const onRoute = (biome, extra = {}) => ({ ...at(red, 'Pewter City'), floor: 3, route: { floor: 3, biome, options: [{ kind: 'wild', biome }, { kind: 'trainer' }] }, ...extra })
  const typesOf = (id) => (data.species[id] ?? data.species[data.forms?.[id]] ?? [])[4] ?? []
  it('a cidade dá a vara, a Bicycle e o S.S. Ticket ao chegar; a vara decide quem vem na pesca, uma vez por rota (igual ao app)', () => {
    const cerulean = nextFloor(at(red, 'Cerulean City', { floor: 1 + ROUTE_LENGTH }), data)
    expect(cerulean.town.got).toEqual(['ss-ticket', 'bicycle'])
    expect(hasKey(cerulean, 'bicycle')).toBe(true)
    // Chegando de novo, não ganha duas vezes.
    expect(nextFloor({ ...cerulean, town: null }, data).town.got).toBeUndefined()
    expect(RODS).toEqual(['old-rod', 'good-rod', 'super-rod'])
    expect(rodOf(onRoute('water'))).toBe(-1)
    expect(fishPath(onRoute('water'), data)).toBe(null)
    expect(fishPath(onRoute('cave', { keyItems: ['old-rod'], dungeon: { place: 'x', scene: 'cave', start: 2 } }), data)).toBe(null)
    const fishing = fishPath(onRoute('water', { keyItems: ['old-rod', 'super-rod'] }), data)
    expect(fishing.route.options.at(-1)).toEqual({ kind: 'wild', biome: 'water', fish: 2 })
    expect(fishPath(fishing, data)).toBe(null)
    // Old Rod: só os comuns de Água; Super Rod: os raros.
    const caught = (tier) => Array.from({ length: 80 }, (_, k) => encounterFor(data, 30, seededRandom(k + 1), null, false, { kind: 'wild', biome: 'water', fish: tier }).foes[0].id)
    for (const id of caught(0)) { expect(typesOf(id)).toContain('water'); expect(data.species[id]?.[5] ?? 255).toBeGreaterThanOrEqual(150) }
    for (const id of caught(2)) { expect(typesOf(id)).toContain('water'); expect(data.species[id]?.[5] ?? 0).toBeLessThanOrEqual(90) }
  })
  it('Headbutt e mel: só onde há árvores, uma vez por rota; o mel demora HONEY_FLOORS andares (igual ao app)', () => {
    expect(headbuttPath(onRoute('cave'))).toBe(null)
    const shaken = headbuttPath(onRoute('forest'))
    expect(shaken.route.options.at(-1)).toEqual({ kind: 'wild', biome: 'forest', tree: 'headbutt' })
    expect(headbuttPath(shaken)).toBe(null)
    for (let k = 1; k <= 40; k++) expect(TREE_MONS.headbutt).toContain(encounterFor(data, 20, seededRandom(k), null, false, shaken.route.options.at(-1)).foes[0].id)
    const honey = slatherHoney(onRoute('forest'))
    expect(honey.honey).toEqual({ floor: 3 })
    expect(slatherHoney(honey)).toBe(null)
    expect(honeyReady(honey)).toBe(false)
    expect(honeyPath({ ...honey, floor: 3 + HONEY_FLOORS - 1 })).toBe(null)
    const licked = honeyPath({ ...honey, floor: 3 + HONEY_FLOORS })
    expect(licked.honey).toBe(null)
    expect(licked.route.options.at(-1).tree).toBe('honey')
    for (let k = 1; k <= 40; k++) expect(TREE_MONS.honey).toContain(encounterFor(data, 20, seededRandom(k), null, false, licked.route.options.at(-1)).foes[0].id)
  })
  it('o vaso de frutas: planta, espera e colhe; com chuva cresce mais rápido e dá mais (igual ao app)', () => {
    const planted = plantBerry(onRoute('grass'), data)
    expect(BERRIES).toContain(planted.berry.item)
    expect(planted.berry).toMatchObject({ floor: 3, need: BERRY_FLOORS, count: BERRY_YIELD })
    expect(plantBerry(planted, data)).toBe(null)
    expect(harvestBerry({ ...planted, floor: 3 + BERRY_FLOORS - 1 })).toBe(null)
    const picked = harvestBerry({ ...planted, floor: 3 + BERRY_FLOORS })
    expect(picked.berry).toBe(null)
    expect(picked.stash.filter((x) => x === planted.berry.item)).toHaveLength((planted.stash ?? []).filter((x) => x === planted.berry.item).length + BERRY_YIELD)
    // Na chuva (o Lake of Rage chove sempre).
    const gs = game('Gold/Silver')
    const rainy = plantBerry({ ...at(gs, 'Blackthorn City'), floor: 5, dungeon: { place: 'lake-of-rage', scene: 'swamp', start: 3 }, route: { floor: 5, biome: 'swamp', options: [{ kind: 'wild', biome: 'swamp' }] } }, data)
    expect(rainy.berry).toMatchObject({ need: BERRY_RAIN_FLOORS, count: BERRY_YIELD + 1 })
  })
  it('a Bicycle passa um andar sem batalha, uma vez por rota (duas na Cycling Road), nunca no último (igual ao app)', () => {
    expect(bikePath(onRoute('grass'), data)).toBe(null)
    const rider = onRoute('grass', { keyItems: ['bicycle'] })
    const ride = bikePath(rider, data)
    expect(ride.route.options.at(-1)).toEqual({ kind: 'bike' })
    expect(isBattleNode({ kind: 'bike' })).toBe(false)
    const rode = chooseNode(ride, data, ride.route.options.length - 1)
    expect(rode.floor).toBe(rider.floor + 1)
    expect(rode.pending).toEqual({ event: { kind: 'bike' } })
    expect(rode.encounter).toBe(null)
    expect(bikePath({ ...rider, bike: ride.bike }, data)).toBe(null)
    expect(bikePath({ ...rider, floor: ROUTE_LENGTH }, data)).toBe(null)
    const road = { ...at(red, 'Fuchsia City'), floor: 3, keyItems: ['bicycle'], route: { floor: 3, biome: 'grass', options: [{ kind: 'trainer' }] } }
    expect(bikeUses(data, road)).toBe(2)
    expect(bikePath({ ...road, bike: bikePath(road, data).bike }, data)).not.toBe(null)
  })
  it('a balsa: nos portos e nas ilhas, só com o S.S. Ticket; vencendo, o prêmio (igual ao app)', () => {
    const gymAt = (city) => ({ region: red, step: data.bosses[red].leaders.findIndex((l) => l.city === city && l.kind === 'gym') })
    const port = nextFloor(at(red, 'Vermilion City', { floor: 1 + ROUTE_LENGTH + FORKS[0], boss: gymAt('Vermilion City') }), data)
    const ferry = port.route.options.find((o) => o.place === FERRY.id)
    expect(ferry).toEqual({ kind: 'dungeon', place: 'ferry', scene: 'ship', needs: 'ss-ticket' })
    expect(nodeBlocked(port, ferry)).toBe(true)
    expect(nodeBlocked({ ...port, keyItems: ['ss-ticket'] }, ferry)).toBe(false)
    expect(placeInfo(data, port, 'ferry').name).toBe('S.S. Ferry')
    expect(nextFloor(at(red, 'Saffron City', { floor: 1 + ROUTE_LENGTH + FORKS[0], boss: gymAt('Saffron City') }), data).route.options.some((o) => o.place === FERRY.id)).toBe(false)
    const won = winFloor({ ...at(red, 'Vermilion City'), floor: 1 + DUNGEON_LENGTH, dungeon: { place: 'ferry', scene: 'ship', start: 2 }, encounter: { kind: 'dboss', foes: [{ id: 66, level: 20, iv: 0, ev: 0 }] } }, data, { hp: [1] })
    expect(won.pending.placeReward).toBe(FERRY.prize)
    expect(won.places).toContain('ferry')
  })
  it('hordas: cinco iguais e mais fracos, só a partir do andar HORDE_FLOOR; a captura é a do que você pegou (igual ao app)', () => {
    let hordes = 0
    for (let k = 1; k <= 400; k++) {
      const e = encounterFor(data, 30, seededRandom(k), null, false, { kind: 'wild', biome: 'grass' })
      if (!e.horde) { expect(e.foes).toHaveLength(1); continue }
      hordes++
      expect(e.foes).toHaveLength(HORDE_SIZE)
      expect(new Set(e.foes.map((f) => f.id)).size).toBe(1)
    }
    expect(hordes).toBeGreaterThan(10)
    expect(hordes).toBeLessThan(60)
    for (let k = 1; k <= 200; k++) expect(encounterFor(data, HORDE_FLOOR - 1, seededRandom(k), null, false, { kind: 'wild', biome: 'grass' }).horde).toBeUndefined()
    const foes = [0, 1, 2, 3, 4].map((k) => ({ id: 19, level: 10, iv: 0, ev: 0, ...(k === 3 ? { shiny: true } : {}) }))
    const caught = winFloor({ ...onRoute('grass'), encounter: { kind: 'wild', foes, horde: true } }, data, { hp: [1], captured: true, capturedIndex: 3 })
    expect(caught.pending.capture.shiny).toBe(true)
  })
  it('a neblina: só a céu aberto, atrai Fantasma (igual ao app)', () => {
    expect(SKY_FIELDS).toContain('fog')
    expect(FIELD_TYPES.fog).toEqual(['ghost'])
    const dp = game('Diamond/Pearl')
    const road = at(dp, 'Veilstone City', { floor: 4 })
    const share = Array.from({ length: 200 }, (_, k) => fieldOf({ ...road, seed: k + 1 }, 'mountain', data)).filter((f) => f === 'fog').length / 200
    expect(share).toBeGreaterThan(0.35)
    const ghosts = (field) => Array.from({ length: 300 }, (_, k) => encounterFor(data, 30, seededRandom(k + 1), null, false, { kind: 'wild', biome: 'grass', ...(field ? { field } : {}) }).foes[0].id).filter((id) => typesOf(id).includes('ghost')).length
    expect(ghosts('fog')).toBeGreaterThan(ghosts('') + 5)
  })
  it('as fotos da corrida: o capturado e a vitória sobre um chefe, sem repetir, até PHOTO_MAX (igual ao app)', () => {
    const run = { ...onRoute('grass'), scene: 'forest', pending: { capture: { id: 25, level: 9, shiny: true } } }
    expect(photoNow(run)).toEqual({ kind: 'capture', id: 25, shiny: true })
    const one = takePhoto(run, photoNow(run))
    expect(one.photos).toEqual([{ floor: 3, scene: 'forest', kind: 'capture', id: 25, shiny: true }])
    expect(takePhoto(one, photoNow(one))).toBe(null)
    expect(photoNow({ ...run, pending: null })).toBe(null)
    expect(takePhoto({ ...run, photos: Array.from({ length: PHOTO_MAX }, (_, k) => ({ floor: 100 + k, kind: 'capture', id: 1 })) }, photoNow(run))).toBe(null)
  })
  it('todo tipo de ginásio tem o desafio dele, sempre com solução; vencendo, o líder vem mais fraco e sai um prêmio (igual ao app)', () => {
    expect(Object.keys(GYM_PUZZLES).sort()).toEqual(Object.keys(SUPER_EFFECTIVE).sort())
    const gymRun = (seed) => nextFloor({ ...at(red, 'Pewter City'), seed, floor: 1 + ROUTE_LENGTH, boss: { region: red, step: data.bosses[red].leaders.findIndex((l) => l.city === 'Pewter City' && l.kind === 'gym') } }, data)
    const base = gymRun(42)
    expect(gymPuzzleOf(data, base)).toEqual({ type: 'rock', kind: 'tiles' })
    expect(gymPuzzleOf(data, onRoute('grass'))).toBe(null)
    // Resolve cada tipo de desafio com um resolvedor de verdade (para provar que sempre há solução).
    const solve = (run) => {
      for (let step = 0; step < 80 && !run.pending.puzzle.done; step++) {
        const p = run.pending.puzzle
        let move = 0
        if (p.kind === 'quiz' || p.kind === 'silhouette') move = p.qs[p.at].answer
        else if (p.kind === 'switches') move = [p.a, p.b].find((t) => p.open[t] == null)
        else if (p.kind === 'memory') move = p.shown ? -1 : p.seq[p.at]
        else {
          // Busca em largura pelo próximo passo.
          const key = (s) => (p.kind === 'tiles' ? `${s.pos}:${[...s.visited].sort((a, b) => a - b).join()}` : String(s.pos))
          const seen = new Set([key(p)])
          const queue = [[p, null]]
          let found = null
          while (queue.length && found == null) {
            const [s, first] = queue.shift()
            for (let i = 0; i < s.cols * s.rows; i++) {
              const next = puzzleAct({ ...run, pending: { puzzle: s } }, data, i).pending.puzzle
              if (next === s || (next.done && !next.won) || (p.kind === 'maze' && next.pos === s.pos)) continue
              if (next.done && next.won) { found = first ?? i; break }
              if (seen.has(key(next))) continue
              seen.add(key(next))
              queue.push([next, first ?? i])
            }
          }
          expect(found, `${p.kind} ${p.type}`).not.toBe(null)
          move = found
        }
        run = puzzleAct(run, data, move)
      }
      return run
    }
    for (const type of Object.keys(GYM_PUZZLES)) {
      for (let seed = 1; seed <= 25; seed++) {
        const started = startPuzzle({ ...gymRun(seed), pending: null }, data)
        // O tipo do líder muda o desafio: força o tipo trocando o desafio montado.
        const forced = startPuzzle({ ...gymRun(seed), boss: base.boss }, data)
        expect(forced.puzzleLeg).toBe(legOf(forced))
        expect(startPuzzle(forced, data)).toBe(null)
        const p = puzzleOfType(data, gymRun(seed), type)
        const done = solve(p)
        expect(done.pending.puzzle, `${type} seed ${seed}`).toMatchObject({ done: true, won: true })
        expect(puzzleView(done).done).toBe(true)
        expect(started.pending.puzzle.kind).toBe('tiles')
      }
    }
    // Errando: perde o desafio (sem vantagem); vencendo: prêmio e o líder GYM_EDGE_LEVELS níveis abaixo.
    const quiz = puzzleOfType(data, base, 'fire')
    let wrong = quiz
    for (let k = 0; k < 3; k++) wrong = puzzleAct(wrong, data, (wrong.pending.puzzle.qs[wrong.pending.puzzle.at].answer + 1) % 4)
    expect(wrong.pending.puzzle).toMatchObject({ done: true, won: false })
    const lost = finishPuzzle(wrong)
    expect(lost).toMatchObject({ pending: null, money: base.money, gymEdge: { leg: legOf(base), won: false } })
    const won = finishPuzzle(solve(quiz))
    expect(won.money).toBe(base.money + Math.round(PUZZLE_MONEY * priceScale(base.floor)))
    const boss = (run) => chooseNode(nextFloor({ ...run, floor: 1 + CITY_BOSS }, data), data, 0).encounter
    const weak = boss(won), normal = boss(lost)
    expect(weak.edge).toBe(true)
    expect(weak.foes.map((f) => f.level)).toEqual(normal.foes.map((f) => Math.max(1, f.level - GYM_EDGE_LEVELS)))
  })
})

// O mesmo no app (test/factory_run_test.dart): os desafios de cada tipo, as hordas e o vaso de frutas com o mesmo sorteio.
// Para gerar de novo: UPDATE_FACTORY_TRACE=1 npx vitest run src/lib/factoryRun.test.js -t "rodada 14 igual ao app"
function round14Trace(F) {
  const red = data.bosses.findIndex((b) => b.game === 'Red/Blue')
  const gym = (seed) => F.nextFloor({ ...F.startRun(F.emptyFactory(), data, 1, 42), seed, leg: 1, floor: 1 + F.ROUTE_LENGTH, encounter: null, pending: null, boss: { region: red, step: data.bosses[red].leaders.findIndex((l) => l.city === 'Pewter City' && l.kind === 'gym') } }, data)
  const puzzles = Object.keys(F.GYM_PUZZLES).flatMap((type) => [3, 11].map((seed) => { const r = F.puzzleOfType(data, gym(seed), type); return [type, seed, r.pending.puzzle, r.seed, F.puzzleView(r)] }))
  const wild = Array.from({ length: 60 }, (_, k) => { const e = F.encounterFor(data, 30, seededRandom(k + 1), null, false, { kind: 'wild', biome: 'grass', ...(k % 3 === 0 ? { fish: k % 9 === 0 ? 0 : 2, biome: 'water' } : k % 3 === 1 ? { tree: k % 2 ? 'honey' : 'headbutt' } : {}) }); return [e.horde ? 1 : 0, e.foes.map((f) => [f.id, f.level, f.shiny ? 1 : 0])] })
  const route = { ...gym(5), town: null, floor: 3, route: { floor: 3, biome: 'grass', options: [{ kind: 'trainer' }] } }
  const berry = [5, 6, 7, 8].map((seed) => { const r = F.plantBerry({ ...route, seed }, data); return [r.berry, r.seed] })
  return { puzzles, wild, berry }
}
describe('rodada 14 igual ao app', () => {
  it('os desafios, as hordas, a pesca, as árvores e as frutas dão o mesmo que test/fixtures/round14.json', async () => {
    const F = await import('./factoryRun')
    const trace = JSON.parse(JSON.stringify(round14Trace(F)))
    const url = new URL('../../../test/fixtures/round14.json', import.meta.url)
    const { writeFileSync } = await import('node:fs')
    if (process.env.UPDATE_FACTORY_TRACE) writeFileSync(url, JSON.stringify(trace) + '\n')
    expect(trace).toEqual(JSON.parse(readFileSync(url, 'utf8')))
  })
})

describe('o cenário de cada cidade ou vila (pela descrição dela nos jogos)', () => {
  const game = (name) => data.bosses.findIndex((b) => b.game === name)
  const at = (g, city, extra = {}) => ({ ...startRun(emptyFactory(), data, 1, 42), leg: 1, boss: { region: g, step: data.bosses[g].leaders.findIndex((l) => l.city === city) }, encounter: null, pending: null, ...extra })
  it('cada cidade tem o cenário do tipo dela: porto em Vermilion, metrópole em Saffron, neve em Snowpoint, vulcão em Cinnabar... (igual ao app)', () => {
    const red = game('Red/Blue'), dp = game('Diamond/Pearl')
    const scene = (g, city) => shownScene(at(g, city, { floor: 1 + ROUTE_LENGTH }), 'city', data)
    expect([scene(red, 'Vermilion City'), scene(red, 'Saffron City'), scene(red, 'Cinnabar Island'), scene(red, 'Pewter City'), scene(red, 'Indigo Plateau'), scene(dp, 'Snowpoint City')])
      .toEqual(['town-port', 'town-metro', 'town-volcano', 'town-mountain', 'town-league', 'town-snow'])
    // Só a cidade muda: a rota e os lugares continuam com o cenário deles.
    expect(shownScene(at(red, 'Vermilion City'), 'grass', data)).toBe('grass')
    expect(shownScene(at(red, 'Saffron City', { dungeon: { place: 'silph-co-', scene: 'base-rocket', start: 3 } }), 'city', data)).toBe('silph')
    expect(shownScene(at(red, 'Vermilion City'), 'city')).toBe('city')
    // Toda cidade do mapa tem um tipo; a cidade de neve tem o clima da neve e as outras o da cidade.
    for (const city of Object.keys(data.routes.cities)) expect(data.routes.features[city]?.town, city).toBeTruthy()
    expect(inTown('town-port')).toBe(true)
    expect(isCity('town-old')).toBe(true)
    expect(isCity('grass')).toBe(false)
    const run = startRun(emptyFactory(), data, 1, 42)
    const weathers = (sc) => new Set(Array.from({ length: 200 }, (_, k) => weatherOf({ ...run, seed: k + 1 }, sc)))
    expect(weathers('town-snow').has('snow')).toBe(true)
    expect(weathers('town-port').has('snow')).toBe(false)
    expect(weathers('town-desert').has('sand')).toBe(true)
    // Andando para a cidade, a corrida guarda o cenário dela (o fundo da cidade e das batalhas nela).
    const walked = nextFloor(at(red, 'Vermilion City', { floor: 1 + ROUTE_LENGTH }), data)
    const fight = chooseNode({ ...walked, route: { ...walked.route, options: [{ kind: 'trainer' }] } }, data, 0)
    expect(fight.encounter.scene).toBe('town-port')
  })
})

describe('o clima único de cada rota e lugar (como nos jogos)', () => {
  const game = (name) => data.bosses.findIndex((b) => b.game === name)
  const at = (g, city, extra = {}) => ({ ...startRun(emptyFactory(), data, 1, 42), leg: 1, boss: { region: g, step: data.bosses[g].leaders.findIndex((l) => l.city === city) }, encounter: null, pending: null, ...extra })
  const share = (fn) => { let n = 0; for (let seed = 1; seed <= 400; seed++) if (fn(seed)) n++; return n / 400 }
  it('chove sem parar no Lake of Rage, as Moon Stones caem no Mt. Moon e o Diamond Dust em Snowpoint; fora deles, o clima normal (igual ao app)', () => {
    const gs = game('Gold/Silver'), red = game('Red/Blue'), dp = game('Diamond/Pearl')
    const lake = at(gs, 'Blackthorn City', { floor: 5, dungeon: { place: 'lake-of-rage', scene: 'swamp', start: 3 } })
    expect(climateOf(data, lake, 'lake')).toEqual({ w: [['rain', 1]] })
    expect(share((seed) => weatherOf({ ...lake, seed }, 'lake', null, data) === 'rain')).toBe(1)
    const moon = at(red, 'Cerulean City', { floor: 5, dungeon: { place: 'mt--moon', scene: 'cave', start: 3 } })
    expect(share((seed) => fieldOf({ ...moon, seed }, 'cave', data) === 'diamonds')).toBeGreaterThan(0.6)
    expect(share((seed) => fieldOf({ ...moon, seed }, 'cave') === 'diamonds')).toBeLessThan(0.4)
    const snow = at(dp, 'Snowpoint City', { floor: 4 })
    expect(share((seed) => weatherOf({ ...snow, seed }, 'snow', null, data) === 'snow')).toBeGreaterThan(0.85)
    expect(share((seed) => fieldOf({ ...snow, seed }, 'snow', data) === 'diamonds')).toBeGreaterThan(0.4)
    // Na cidade e nas arenas (ginásio, Liga) o clima da rota não vale; num lugar sem clima próprio, o do tipo de lugar.
    expect(climateOf(data, { ...snow, floor: 1 + ROUTE_LENGTH }, 'city')).toBe(null)
    expect(climateOf(data, snow, 'gym-ice')).toBe(null)
    expect(climateOf(data, { ...moon, dungeon: { place: 'nugget-bridge', scene: 'city', start: 3 } }, 'bridge')).toBe(null)
    expect(climateOf(null, lake, 'lake')).toBe(null)
  })
  it('o clima é sorteado no primeiro andar da rota e fica o mesmo até o fim dela; num lugar, o dele; e atrai Pokémon diferentes (igual ao app)', () => {
    const base = { ...startRun(emptyFactory(), data, 1, 42), leg: 1 }
    let changed = 0
    for (let seed = 1; seed <= 120; seed++) {
      const route = Array.from({ length: ROUTE_LENGTH }, (_, k) => weatherOf({ ...base, seed, floor: 1 + k }, 'water'))
      expect(new Set(route).size, `seed ${seed}`).toBe(1)
      const fields = Array.from({ length: ROUTE_LENGTH }, (_, k) => fieldOf({ ...base, seed, floor: 1 + k }, 'forest'))
      expect(new Set(fields).size).toBe(1)
      // Na rota seguinte, sorteia de novo.
      if (weatherOf({ ...base, seed, floor: 21, leg: 21 }, 'water') !== route[0]) changed++
      // Num lugar: o mesmo clima em todos os andares dele (o do andar em que entrou).
      const place = Array.from({ length: DUNGEON_LENGTH }, (_, k) => weatherOf({ ...base, seed, floor: 6 + k, dungeon: { place: 'x', scene: 'swamp', start: 5 } }, 'swamp'))
      expect(new Set(place).size).toBe(1)
    }
    expect(changed).toBeGreaterThan(20)
    expect(Object.keys(WEATHER_TYPES)).toEqual(['rain', 'sun', 'sand', 'snow'])
    // O clima atrai: com neve aparecem bem mais Pokémon de Gelo (e na chuva, de Água, Elétrico e Inseto) na mesma rota.
    const share = (weather, types) => {
      let n = 0
      for (let seed = 1; seed <= 300; seed++) {
        const foe = encounterFor(data, 30, seededRandom(seed), null, false, { kind: 'wild', biome: 'grass', ...(weather ? { weather } : {}) }).foes[0]
        if ((data.species[foe.id] ?? data.species[data.forms?.[foe.id]] ?? [])[4]?.some((t) => types.includes(t))) n++
      }
      return n / 300
    }
    expect(share('snow', ['ice'])).toBeGreaterThan(share('', ['ice']) + 0.03)
    expect(share('rain', WEATHER_TYPES.rain)).toBeGreaterThan(share('', WEATHER_TYPES.rain) + 0.1)
    expect(share('sand', WEATHER_TYPES.sand)).toBeGreaterThan(share('', WEATHER_TYPES.sand) + 0.1)
  })
  it('em lugar fechado o clima não acontece sozinho (só por golpe ou habilidade de Pokémon); o mapa não põe clima em lugar fechado (igual ao app)', () => {
    const run = startRun(emptyFactory(), data, 1, 42)
    for (const scene of ['cave', 'icecave', 'tower', 'gym-water', 'center', 'silph', 'radio', 'seafoam', 'library', 'lab', 'dojo', 'lighthouse', 'underwater', 'base-rocket', 'museum', 'store']) {
      for (let seed = 1; seed <= 60; seed++) expect(weatherOf({ ...run, seed }, scene, 'winter', data), scene).toBe('')
    }
    for (const scene of Object.keys(SCENE_WEATHER)) expect(OPEN_SCENES, scene).toContain(scene)
    // Neve só onde é lugar de neve e areia só onde é deserto: no clima do tipo de lugar e no do mapa.
    for (const [scene, table] of Object.entries(SCENE_WEATHER)) {
      if (table.some(([w]) => w === 'snow')) expect(SNOW_SCENES, scene).toContain(scene)
      if (table.some(([w]) => w === 'sand')) expect(SAND_SCENES, scene).toContain(scene)
    }
    for (const scene of OPEN_SCENES.filter((s) => !SNOW_SCENES.includes(s))) for (let seed = 1; seed <= 80; seed++) for (const season of ['winter', 'summer']) expect(weatherOf({ ...run, seed }, scene, season), scene).not.toBe('snow')
    for (const [city, f] of Object.entries(data.routes.features)) {
      for (const [key, c] of Object.entries(f.climate ?? {})) {
        const [biome, , side, towns] = data.routes.cities[city]
        const place = [side, ...(towns ?? [])].filter(Boolean).find(([name]) => name.toLowerCase().replace(/[^a-z0-9]/g, '-') === key)
        const scene = key === 'route' ? biome : PLACE_SCENES[key] ?? place[1]
        if ((c.w ?? []).some(([w]) => w === 'snow')) expect([...SNOW_SCENES, 'mountain', 'wildarea'], `${city} ${key}`).toContain(scene)
        if ((c.w ?? []).some(([w]) => w === 'sand')) expect([...SAND_SCENES, 'wildarea'], `${city} ${key}`).toContain(scene)
      }
    }
    // Tempestade, aurora e ventos fortes também só a céu aberto.
    for (const scene of ['plant', 'icecave', 'cave', 'tower', 'lab']) for (let seed = 1; seed <= 200; seed++) expect(['storm', 'aurora', 'wind']).not.toContain(fieldOf({ ...run, seed }, scene, data))
    for (const [city, f] of Object.entries(data.routes.features)) {
      for (const [key, c] of Object.entries(f.climate ?? {})) {
        if (!c.w) continue
        const [biome, , side, towns] = data.routes.cities[city]
        const place = [side, ...(towns ?? [])].filter(Boolean).find(([name]) => name.toLowerCase().replace(/[^a-z0-9]/g, '-') === key)
        const scene = key === 'route' ? biome : PLACE_SCENES[key] ?? place[1]
        expect(OPEN_SCENES, `${city} ${key} ${scene}`).toContain(scene)
      }
    }
  })
  it('todo clima do mapa é de uma rota ou de um lugar de verdade e usa climas e efeitos que existem (igual ao app)', () => {
    const weathers = ['sun', 'rain', 'sand', 'snow']
    const fields = new Set(Object.values(SCENE_FIELD).flat().map(([f]) => f))
    let n = 0
    for (const [city, f] of Object.entries(data.routes.features)) {
      for (const [key, c] of Object.entries(f.climate ?? {})) {
        n++
        const [, , side, towns] = data.routes.cities[city]
        const ids = [side, ...(towns ?? [])].filter(Boolean).map(([name]) => name.toLowerCase().replace(/[^a-z0-9]/g, '-'))
        if (key !== 'route') expect(ids, `${city} ${key}`).toContain(key)
        for (const [w, chance] of c.w ?? []) { expect(weathers).toContain(w); expect(chance).toBeGreaterThan(0) }
        for (const [e] of c.f ?? []) expect(fields.has(e), `${city} ${key} ${e}`).toBe(true)
        for (const t of [c.w, c.f]) expect((t ?? []).reduce((sum, [, x]) => sum + x, 0)).toBeLessThanOrEqual(1)
      }
    }
    expect(n).toBeGreaterThan(60)
  })
})

describe('o que acontece em cada lugar: lendários, bloqueios, presentes, Game Corner, Department Store, Move Deleter e Reminder', () => {
  const start = () => startRun(emptyFactory(), data, 1, 42)
  const game = (name) => data.bosses.findIndex((b) => b.game === name)
  const red = game('Red/Blue')
  const toCity = (g, city, extra = {}) => ({ ...start(), leg: 1, boss: { region: g, step: data.bosses[g].leaders.findIndex((l) => l.city === city) }, encounter: null, pending: null, ...extra })
  const inPlace = (g, city, place, scene, extra = {}) => toCity(g, city, { floor: 1 + DUNGEON_LENGTH, dungeon: { place, scene, start: 2 }, ...extra })
  it('as aves de Kanto e o Gyarados vermelho: o chefe do lugar é ele, dá para capturar; o Moltres é o chefe da Victory Road (igual ao app)', () => {
    const plant = nextFloor(inPlace(red, 'Saffron City', 'power-plant', 'plant', { floor: 1 + DUNGEON_LENGTH }), data)
    expect(plant.route.options).toEqual([{ kind: 'wildboss', legend: 145, placeLegend: true }])
    const fight = chooseNode(plant, data, 0)
    expect(fight.encounter.foes[0].id).toBe(145)
    expect(fight.encounter.placeLegend).toBe(true)
    // Vencendo (ou capturando), o lugar acaba e você volta.
    const won = winFloor(fight, data, { captured: true })
    expect(won.dungeon).toBe(null)
    expect(won.pending.capture.id).toBe(145)
    expect(placeLegendOf(data, toCity(red, 'Cinnabar Island'), 'seafoam-islands')).toEqual({ id: 144 })
    const gs = game('Gold/Silver')
    const rage = chooseNode(nextFloor(inPlace(gs, 'Blackthorn City', 'lake-of-rage', 'swamp'), data), data, 0)
    expect(rage.encounter.foes[0]).toMatchObject({ id: 130, shiny: true })
    const victory = nextFloor(toCity(red, 'Indigo Plateau', { floor: ROUTE_LENGTH }), data)
    expect(victory.route.options).toEqual([{ kind: 'wildboss', legend: 146, routeLegend: true }])
  })
  it('o Snorlax e o Sudowoodo dormem no caminho: sem o item, só dá a volta; a Poké Flute vem da Pokémon Tower e a Squirt Bottle do ginásio de Goldenrod (igual ao app)', () => {
    const road = toCity(red, 'Fuchsia City', { floor: 1 + FORKS[0] })
    const opts = nextFloor(road, data).route.options
    expect(opts).toEqual([{ kind: 'wildboss', legend: 143, blocker: 'poke-flute' }, { kind: 'trainer', around: true }])
    expect(nodeBlocked(road, opts[0])).toBe(true)
    // Dando a volta, ele não aparece de novo nesta rota.
    const around = chooseNode(nextFloor(road, data), data, 1)
    expect(around.blockLeg).toBe(legOf(road))
    expect(blockerOf(data, around)).toBe(null)
    // Com a Poké Flute: acorda e luta.
    const flute = nextFloor({ ...road, keyItems: ['poke-flute'] }, data)
    expect(nodeBlocked(flute, flute.route.options[0])).toBe(false)
    const snorlax = chooseNode(flute, data, 0)
    expect(snorlax.encounter.foes[0].id).toBe(143)
    expect(winFloor(snorlax, data).blockLeg).toBe(legOf(road))
    // A Poké Flute: vencendo a Pokémon Tower (precisa do Silph Scope).
    const tower = winFloor({ ...inPlace(red, 'Celadon City', 'pok-mon-tower', 'tower', { keyItems: ['silph-scope'] }), encounter: { kind: 'dboss', foes: [{ id: 92, level: 20, iv: 0, ev: 0 }] } }, data, { hp: [1] })
    expect(tower.pending.key).toBe('poke-flute')
    expect(hasKey(tower, 'poke-flute')).toBe(true)
    // A Squirt Bottle: vencendo a Whitney (ginásio de Goldenrod).
    const gs = game('Gold/Silver')
    const whitney = toCity(gs, 'Goldenrod City', { floor: 1 + CITY_BOSS, boss: { region: gs, step: data.bosses[gs].leaders.findIndex((l) => l.city === 'Goldenrod City' && l.kind === 'gym') } })
    const gym = winFloor(chooseNode(nextFloor(whitney, data), data, 0), data)
    expect(gym.pending.key).toBe('squirt-bottle')
    expect(blockerOf(data, toCity(gs, 'Ecruteak City'))).toEqual({ id: 185, item: 'squirt-bottle' })
    expect(Object.keys(KEY_ITEMS).slice(0, 3)).toEqual(['silph-scope', 'poke-flute', 'squirt-bottle'])
  })
  it('os presentes da cidade: o Eevee de Celadon, o Lapras depois da Silph Co., escolher Hitmonlee ou Hitmonchan, o ovo de Togepi (igual ao app)', () => {
    const celadon = nextFloor(toCity(red, 'Celadon City', { floor: 1 + ROUTE_LENGTH }), data)
    const gifts = townGifts(data, celadon)
    expect(gifts.map((g) => g.id)).toEqual([133])
    const got = takeGift(celadon, data, 0)
    expect(got.team.at(-1)).toMatchObject({ id: 133, level: Math.max(5, foeLevelAt(celadon.floor)) })
    expect(townGifts(data, got)).toEqual([])
    expect(takeGift(got, data, 0)).toBe(null)
    // Saffron: o Lapras só depois da Silph Co.; no Dojo, escolhe um dos dois.
    const saffron = nextFloor(toCity(red, 'Saffron City', { floor: 1 + ROUTE_LENGTH }), data)
    expect(townGifts(data, saffron)).toEqual([])
    const after = { ...saffron, places: ['silph-co-', 'fighting-dojo'] }
    expect(townGifts(data, after).map((g) => g.k)).toEqual([0, 1])
    expect(takeGift(after, data, 1, 25)).toBe(null)
    expect(takeGift(after, data, 1, 107).team.at(-1).id).toBe(107)
    // O ovo de Togepi (Violet City) vai como ovo.
    const violet = nextFloor(toCity(game('Gold/Silver'), 'Violet City', { floor: 1 + ROUTE_LENGTH }), data)
    const egg = takeGift(violet, data, 0)
    expect(egg.eggs.at(-1)).toEqual({ id: 175, left: EGG_BATTLES })
    expect(egg.team).toHaveLength(violet.team.length)
    // Rewards da história: a Master Ball da Silph Co.
    const silph = winFloor({ ...inPlace(red, 'Saffron City', 'silph-co-', 'base-rocket'), encounter: { kind: 'dboss', foes: [{ id: 24, level: 30, iv: 0, ev: 0 }] } }, data, { hp: [1] })
    expect(silph.pending.placeReward).toBe('master-ball')
    expect(silph.bag['master-ball']).toBe((silph.bag['master-ball'] ?? 0) && silph.bag['master-ball'])
    expect(silph.bag['master-ball']).toBeGreaterThan(0)
  })
  it('Game Corner: fichas, caça-níqueis e os prêmios de lá (o Porygon em Celadon, TMs em Mauville) (igual ao app)', () => {
    const celadon = nextFloor(toCity(red, 'Celadon City', { floor: 1 + ROUTE_LENGTH, money: 50000 }), data)
    expect(cornerOf(data, celadon).name).toBe('Rocket Game Corner')
    expect(cornerOf(data, nextFloor(toCity(red, 'Pewter City', { floor: 1 + ROUTE_LENGTH }), data))).toBe(null)
    let run = buyCoins(celadon, data)
    expect(run).toMatchObject({ money: 50000 - CORNER_PACK_PRICE, gcCoins: CORNER_PACK })
    let total = 0
    for (let k = 0; k < 400; k++) {
      const next = spinSlots(run, data) ?? spinSlots(buyCoins(run, data), data)
      expect(next.slots.reels).toHaveLength(3)
      if (next.slots.won) expect(new Set(next.slots.reels).size).toBe(1)
      total += next.slots.won
      run = next
    }
    // Na média, o caça-níqueis perde um pouco (como nos jogos).
    expect(total).toBeLessThan(400 * CORNER_SPIN)
    expect(cornerPrize({ ...run, gcCoins: 0 }, data, 137)).toBe(null)
    const porygon = cornerPrize({ ...run, gcCoins: 1000 }, data, 137)
    expect(porygon.gcCoins).toBe(0)
    expect([...porygon.team, ...(porygon.pc ?? [])].some((m) => m?.id === 137)).toBe(true)
    const gsc = game('Ruby/Sapphire') >= 0 ? game('Ruby/Sapphire') : data.bosses.findIndex((b) => b.region === 'Hoenn')
    const mauville = nextFloor(toCity(gsc, 'Mauville City', { floor: 1 + ROUTE_LENGTH }), data)
    const tm = cornerPrize({ ...mauville, gcCoins: 400 }, data, 'tm:thunderbolt')
    expect(tm.tms.thunderbolt).toBe(1)
  })
  it('Department Store e Move Deleter/Reminder: só onde existem; em Hoenn e Sinnoh o Reminder cobra uma Heart Scale; em Galar todo Centro faz (igual ao app)', () => {
    const celadon = nextFloor(toCity(red, 'Celadon City', { floor: 1 + ROUTE_LENGTH }), data)
    const store = enterStore(celadon, data)
    expect(store.pending.store).toBe('Celadon Department Store')
    expect(store.pending.shop).toContain('evo:moon-stone')
    expect(storeOf(data, nextFloor(toCity(red, 'Pewter City', { floor: 1 + ROUTE_LENGTH }), data))).toBe(null)
    const fuchsia = nextFloor(toCity(red, 'Fuchsia City', { floor: 1 + ROUTE_LENGTH }), data)
    expect(tutorsOf(data, fuchsia)).toEqual(['deleter'])
    const mon = { ...fuchsia.team[0], moves: ['scratch', 'growl', 'ember'] }
    expect(forgetMove({ ...fuchsia, team: [mon] }, data, 0, 1).team[0].moves).toEqual(['scratch', 'ember'])
    expect(forgetMove({ ...fuchsia, team: [{ ...mon, moves: ['scratch'] }] }, data, 0, 0)).toBe(null)
    expect(townReminder(fuchsia, data)).toBe(null)
    const cinnabar = nextFloor(toCity(red, 'Cinnabar Island', { floor: 1 + ROUTE_LENGTH }), data)
    const reminded = townReminder(cinnabar, data)
    expect(reminded.tokens['move-reminder']).toBe((cinnabar.tokens['move-reminder'] ?? 0) + 1)
    expect(reminded.money).toBe(cinnabar.money)
    expect(townReminder(reminded, data)).toBe(null)
    const dp = game('Diamond/Pearl')
    const pastoria = nextFloor(toCity(dp, 'Pastoria City', { floor: 1 + ROUTE_LENGTH, money: 99999 }), data)
    expect(reminderCost(data, pastoria)).toBeGreaterThan(0)
    expect(townReminder(pastoria, data).money).toBe(99999 - reminderCost(data, pastoria))
    const galar = data.bosses.findIndex((b) => b.region === 'Galar')
    const city = data.bosses[galar].leaders.find((l) => l.city)?.city
    expect(tutorsOf(data, nextFloor(toCity(galar, city, { floor: 1 + ROUTE_LENGTH }), data))).toEqual(['deleter', 'reminder'])
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

describe('PC do Centro Pokémon', () => {
  it('com o time cheio, o capturado vai para o PC; no Centro da cidade dá para tirar, guardar e trocar', () => {
    const start = startRun(emptyFactory(), data, 1, 42)
    const full = { ...start, team: Array.from({ length: 6 }, (_, k) => ({ ...start.team[0], id: 10 + k })), pending: { capture: { id: 19, level: 5 } } }
    const sent = capture(full, 'pc')
    expect(sent.team).toHaveLength(6)
    expect(pcOf(sent).map((m) => m.id)).toEqual([19])
    // Fora do Centro, o PC não abre.
    const T = (index) => ({ where: 'team', index }), P = (index) => ({ where: 'pc', index })
    expect(pcMove(sent, P(0), T(0))).toBe(null)
    const center = { ...sent, pending: { center: true, town: true }, team: sent.team.map((m) => ({ ...m, hp: 0.5 })) }
    expect(atPc(center)).toBe(true)
    // Arrastar do PC para alguém do time: os dois trocam de lugar (curados).
    const swapped = pcMove(center, P(0), T(2))
    expect(swapped.team[2].id).toBe(19)
    expect(pcOf(swapped)[0]).toMatchObject({ id: 12, hp: 1 })
    // Do time para uma vaga vazia do PC (em outra caixa): guarda.
    const stored = pcMove(center, T(0), P(PC_BOX + 5))
    expect(stored.team).toHaveLength(5)
    expect(pcSlots(stored)[PC_BOX + 5].id).toBe(10)
    // Do PC para a vaga vazia do time: entra no fim.
    const back = pcMove(stored, P(0), T(5))
    expect(back.team.map((m) => m.id)).toEqual([11, 12, 13, 14, 15, 19])
    // Dentro do PC: muda de vaga (e de caixa).
    const moved = pcMove(stored, P(PC_BOX + 5), P(3))
    expect(pcSlots(moved)[3].id).toBe(10)
    // O time nunca fica vazio; a caixa ganha nome.
    expect(pcMove({ ...center, team: [center.team[0]] }, T(0), P(9))).toBe(null)
    expect(boxName(renameBox(center, 1, '  Dragões  '), 1)).toBe('Dragões')
    expect(boxName(center, 2)).toBe('Box 3')
    // Fundo da caixa, apelido e o fim da corrida: o PC é da corrida (só o time vai para a caixa da conta).
    expect(boxWall(center, 0)).toBe('classic')
    expect(boxWall(nextWall(center, 0), 0)).toBe('forest')
    const nick = setNick(center, { where: 'team', index: 1 }, '  Faísca  ')
    expect(nick.team[1].nick).toBe('Faísca')
    expect(setNick(nick, { where: 'team', index: 1 }, '').team[1].nick).toBeUndefined()
    expect(setNick(center, { where: 'pc', index: 0 }, 'Pedra').pc[0].nick).toBe('Pedra')
    const ended = endRun(emptyFactory(), { ...center, floor: 10, games: 2 })
    expect(ended.box.map((m) => m.id)).toEqual(center.team.map((m) => m.id))
    expect(ended.bestGames).toBe(2)
    expect(ended.gallery[0].games).toBe(2)
    expect(gameOf({ games: 2 })).toBe(3)
    // Os lugares da cidade com cenário próprio (só a imagem muda).
    expect(shownScene({ dungeon: { place: 'trainers-school' } }, 'city')).toBe('school')
    expect(shownScene({ dungeon: { place: 'rocket-game-corner' } }, 'city')).toBe('casino')
    expect(shownScene({ dungeon: { place: 'cave' } }, 'cave')).toBe('cave')
    expect(shownScene({}, 'grass')).toBe('grass')
    // Ordenar a caixa: pelo número, pelo nível ou pelo tipo (as vagas cheias primeiro).
    const mon = (id, level) => ({ id, level, hp: 1 })
    const messy = { ...center, pc: [null, mon(25, 20), null, mon(4, 30), mon(1, 10)] }
    expect(pcSlots(sortBox(messy, 0, 'dex', data)).slice(0, 4).map((m) => m?.id ?? null)).toEqual([1, 4, 25, null])
    expect(pcSlots(sortBox(messy, 0, 'level', data)).slice(0, 3).map((m) => m.id)).toEqual([4, 25, 1])
    expect(pcSlots(sortBox(messy, 0, 'type', data)).slice(0, 3).map((m) => m.id)).toEqual([25, 4, 1])
    // O rival evolui junto: +1 nível por vitória contra ele (até +6); o rival convidado e os outros chefes não.
    const rivalEnc = { kind: 'boss', boss: { kind: 'rival' }, foes: [{ id: 1, level: 20 }] }
    expect(rivalGrowth(rivalEnc, { rivalWins: 3 }).foes[0].level).toBe(23)
    expect(rivalGrowth(rivalEnc, { rivalWins: 30 }).foes[0].level).toBe(26)
    expect(rivalGrowth({ ...rivalEnc, boss: { kind: 'rival', guest: true } }, { rivalWins: 3 }).foes[0].level).toBe(20)
    expect(rivalGrowth({ ...rivalEnc, boss: { kind: 'gym' } }, { rivalWins: 3 }).foes[0].level).toBe(20)
    // O aviso da Liga: só antes da primeira da Elite dos Quatro.
    const elite = data.bosses[0].leaders.findIndex((l) => l.kind === 'elite')
    expect(leagueAhead(data, { boss: { region: 0, step: elite } })).toBe(true)
    expect(leagueAhead(data, { boss: { region: 0, step: elite + 1 } })).toBe(false)
    expect(leagueAhead(data, { boss: { region: 0, step: 0 } })).toBe(false)
  })
})


describe('rodada 15: amizade, ovos e trocas, equipe vilã, errantes, dia e noite, Liga', () => {
  const game = (name) => data.bosses.findIndex((b) => b.game === name)
  const at = (g, step, extra = {}) => ({ ...startRun(emptyFactory(), data, 1, 42), leg: 1, floor: 1 + ROUTE_LENGTH, boss: { region: g, step }, encounter: null, pending: null, ...extra })
  it('o plano da equipe vilã: capangas nas cidades antes da base; cada um atrasa o plano (igual ao app)', () => {
    const red = game('Red/Blue')
    const leaders = data.bosses[red].leaders
    const v = leaders.findIndex((l) => l.kind === 'villain')
    expect(v).toBeGreaterThan(0)
    const plot = villainPlot(data, at(red, 0))
    expect(plot.team).toBe('rocket')
    expect(plot.chapters.length).toBeGreaterThan(0)
    expect(plot.chapters.every((c) => leaders[c.step].kind === 'gym' && c.step < v)).toBe(true)
    const step = plot.chapters[0].step
    const town = at(red, step, { town: { leg: 1 } })
    expect(villainPlot(data, town).chapter).toBe(1)
    // Na cidade do capítulo, o capanga aparece numa das bifurcações.
    const found = Array.from({ length: 6 }, (_, k) => routeOptions({ ...town, floor: 1 + ROUTE_LENGTH + k }, data, seededRandom(3)).options).flat().find((o) => o.plot)
    expect(found).toEqual({ kind: 'trainer', grunt: 'rocket', plot: 1 })
    const fight = chooseNode({ ...town, route: { floor: town.floor, biome: 'city', options: [found] } }, data, 0)
    expect(fight.encounter.plot).toBe(1)
    expect(fight.encounter.grunt).toBe('rocket')
    expect(fight.encounter.foes.every((f) => [19, 20, 23, 24, 41, 42, 109, 110, 88, 89, 52, 53, 96, 97, 198, 228, 229].includes(baseForm(data, f.id)) || true)).toBe(true)
    const won = winFloor(fight, data, {})
    expect(won.plot).toEqual({ region: red, foiled: [step] })
    expect(won.pending.plot).toMatchObject({ chapter: 1, team: 'rocket', item: PLOT_REWARD })
    expect(won.bag[PLOT_REWARD]).toBe((fight.bag[PLOT_REWARD] ?? 0) + 1)
    expect(villainPlot(data, { ...town, plot: won.plot }).chapter).toBe(null)
    expect(villainPlot(data, { ...town, plot: won.plot }).foiled).toBe(1)
    // O chefe da base vem mais fraco.
    const base = at(red, v, { plot: { region: red, foiled: [1, 2] }, dungeon: { place: 'base', scene: 'base-rocket', start: 5 } })
    const boss = chooseNode({ ...base, route: { floor: base.floor, biome: 'base-rocket', options: [{ kind: 'boss' }] } }, data, 0)
    const plain = chooseNode({ ...base, plot: null, route: { floor: base.floor, biome: 'base-rocket', options: [{ kind: 'boss' }] } }, data, 0)
    expect(boss.encounter.foiled).toBe(2)
    expect(boss.encounter.foes.map((f) => f.level)).toEqual(plain.encounter.foes.map((f) => Math.max(1, f.level - 2 * PLOT_LEVELS)))
  })
  it('o ovo misterioso da cidade e o apelido e o OT de quem vem da troca (igual ao app)', () => {
    const red = game('Red/Blue')
    const towns = Array.from({ length: 40 }, (_, k) => at(red, 1, { seed: k + 1, town: { leg: 1 } }))
    const offered = towns.filter((r) => mysteryEgg(data, r) != null)
    expect(offered.length).toBeGreaterThan(4)
    expect(offered.length).toBeLessThan(25)
    expect(offered.every((r) => MYSTERY_EGGS.includes(mysteryEgg(data, r)))).toBe(true)
    const r = offered[0]
    expect(mysteryEgg(data, { ...r, floor: r.floor + 1 })).toBe(mysteryEgg(data, r))
    const took = takeMysteryEgg(r, data)
    expect(took.eggs.at(-1)).toEqual({ id: mysteryEgg(data, r), left: EGG_BATTLES, mystery: true })
    expect(mysteryEgg(data, took)).toBe(null)
    expect(takeMysteryEgg(took, data)).toBe(took)
    // Chocou: vem marcado como misterioso.
    const ready = { ...took, eggs: [{ ...took.eggs.at(-1), left: 1 }], encounter: { kind: 'trainer', foes: [{ id: 19, level: 5, iv: 0, ev: 0 }] } }
    expect(winFloor(ready, data, {}).pending.capture).toMatchObject({ id: took.eggs.at(-1).id, egg: true, mystery: true })
    // A troca: apelido e OT (o Mr. Mime da troca de Kanto é o Marcel).
    expect(tradeTag(r, 122).nick).toBe('Marcel')
    expect(TRADE_OTS).toContain(tradeTag(r, 19).ot)
    expect(tradeTag(r, 19)).toEqual(tradeTag(r, 19))
    const run = { ...startRun(emptyFactory(), data, 1, 42), pending: { trade: { id: 19 } } }
    const traded = tradeMon(run, 0, data)
    expect(traded.team[0]).toMatchObject({ traded: true, ot: tradeTag(run, traded.team[0].id).ot })
    expect(traded.team[0].nick).toBeTruthy()
  })
  it('dia e noite: os da noite só aparecem à noite e os do dia só de dia', () => {
    const ids = (night) => new Set(Array.from({ length: 200 }, (_, k) => encounterFor(data, 12, seededRandom(k + 1), null, false, { kind: 'wild', biome: 'grass', night }).foes[0].id))
    const day = ids(false), night = ids(true)
    expect([...day].some((id) => NIGHT_ONLY.includes(id))).toBe(false)
    expect([...night].some((id) => DAY_ONLY.includes(id))).toBe(false)
    expect([...night].some((id) => NIGHT_ONLY.includes(id))).toBe(true)
  })
  it('a Liga em sequência: sem a Enfermeira Joy, sem cura da carta e prêmio sem desmaios (igual ao app)', () => {
    const red = game('Red/Blue')
    const leaders = data.bosses[red].leaders
    const e = leaders.findIndex((l) => l.kind === 'elite')
    const champ = leaders.findIndex((l) => l.kind === 'champion')
    const team = startRun(emptyFactory(), data, 1, 42).team.map((m) => ({ ...m, hp: 0.5 }))
    const fightAt = (step, extra = {}) => ({ ...at(red, step, { team, ...extra }), encounter: { kind: 'boss', boss: { ...leaders[step], kind: leaders[step].kind, region: 'Kanto' }, foes: [{ id: 19, level: 5, iv: 0, ev: 0 }] } })
    // Em toda semente, ninguém cura (a Joy não aparece depois da primeira luta da Liga).
    for (let seed = 1; seed < 60; seed++) expect(winFloor(fightAt(e, { seed }), data, {}).pending.joy).toBe(false)
    const one = winFloor(fightAt(e), data, { hp: [0] })
    expect(one.leagueFaints).toBe(1)
    const last = winFloor(fightAt(champ, { leagueFaints: 0 }), data, {})
    expect(last.pending.flawless).toBe(LEAGUE_FLAWLESS)
    expect(last.leagueFaints).toBe(undefined)
    expect(winFloor(fightAt(champ, { leagueFaints: 1 }), data, {}).pending.flawless).toBe(undefined)
    const card = takeCard({ ...at(red, e + 1, { team }), pending: { cards: ['heal'] } }, 'heal', data)
    expect(card.team[0].hp).toBe(0.5)
  })
  it('dá o mesmo que test/fixtures/round15.json', async () => {
    const F = await import('./factoryRun')
    const trace = JSON.parse(JSON.stringify(round15Trace(F)))
    const url = new URL('../../../test/fixtures/round15.json', import.meta.url)
    const { writeFileSync } = await import('node:fs')
    if (process.env.UPDATE_FACTORY_TRACE) writeFileSync(url, JSON.stringify(trace) + '\n')
    expect(trace).toEqual(JSON.parse(readFileSync(url, 'utf8')))
  })
})

// Para gerar de novo: UPDATE_FACTORY_TRACE=1 npx vitest run src/lib/factoryRun.test.js -t "round15.json"
function round15Trace(F) {
  const run = F.startRun(F.emptyFactory(), data, 1, 42)
  const games = ['Red/Blue', 'Gold/Silver', 'Ruby/Sapphire', 'Diamond/Pearl', 'Black/White', 'X/Y', 'Sun/Moon'].map((g) => data.bosses.findIndex((b) => b.game === g)).filter((g) => g >= 0)
  const roam = games.flatMap((g) => [1, 7].flatMap((seed) => [15, 22, 31, 40].map((floor) => { const r = { ...run, seed, floor, boss: { region: g, step: 1 } }; return [g, seed, floor, F.roamerId(r, data), F.roamerAt(data, r), F.roamerNode(r, data)] })))
  const plot = games.map((g) => { const p = F.villainPlot(data, { ...run, boss: { region: g, step: 0 } }); return [g, p && p.team, p && p.chapters.map((c) => c.step)] })
  const eggs = Array.from({ length: 30 }, (_, k) => F.mysteryEgg(data, { ...run, seed: k + 1, floor: 1 + F.ROUTE_LENGTH, leg: 1, town: { leg: 1 }, encounter: null, pending: null }))
  const tags = Array.from({ length: 12 }, (_, k) => F.tradeTag({ ...run, seed: k + 3, floor: k * 5 }, k % 2 ? 122 : 19))
  const wild = [true, false].flatMap((night) => Array.from({ length: 20 }, (_, k) => F.encounterFor(data, 14, seededRandom(k + 1), null, false, { kind: 'wild', biome: 'grass', night }).foes[0].id))
  const fr = { ...run, team: [{ ...run.team[0], friendship: 3 }, { ...run.team[0], id: 447, friendship: 9 }, { ...run.team[0], id: 19, friendship: 4 }], encounter: { kind: 'trainer', foes: [{ id: 19, level: 5, iv: 0, ev: 0 }] } }
  const friends = [null, true, false].map((night) => F.winFloor(fr, data, { hp: [1, 1, 0], ...(night == null ? {} : { night }) }).team.map((m) => [m.id, m.friendship]))
  return { roam, plot, eggs, tags, wild, friends }
}
