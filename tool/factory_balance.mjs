// Balanceamento da Battle Factory: corridas inteiras no motor de verdade
// (tool/battle-engine/engine.mjs), com a IA do computador jogando pelo seu
// time (e jogando a bola nos selvagens fracos) e um jogador entre os andares
// como quem joga: caminho no mapa (sorteando de novo quando não serve), cartas,
// loja, Bolsa, itens guardados no melhor, trocas e o mais fraco abrindo as
// batalhas fáceis para treinar.
// Mostra até onde as corridas chegam e como o nível do time acompanha o dos
// adversários (web-site/src/lib/factoryRun.js).
//
// Uso: node tool/factory_balance.mjs [corridas=12] [andar máximo=200]
//      START_FLOOR=100 node tool/factory_balance.mjs   (começa no andar com um time pronto)
//      UPGRADES=2 node tool/factory_balance.mjs        (com até 2 níveis de cada melhoria permanente, como quem já jogou)
//      NO_TRAIN=1 node tool/factory_balance.mjs        (sem pôr o mais fraco para abrir as batalhas fáceis)

import { readFileSync } from 'node:fs'
import { PocketDexSim as sim } from './battle-engine/engine.mjs'
import * as F from '../web-site/src/lib/factoryRun.js'

const db = (name) => JSON.parse(readFileSync(new URL(`../assets/database/${name}.json`, import.meta.url), 'utf8'))
const data = db('factory')
const pokemon = Object.fromEntries(db('pokemon').map((p) => [p.id, p]))
const moves = Object.fromEntries(db('moves').map((m) => [m.name, { ...m, category: m.damage_class }]))

const runs = Number(process.argv[2] ?? 12)
const maxFloor = Number(process.argv[3] ?? 200)

function engineMon(member) {
  const p = pokemon[member.id]
  const { levelCap, bonus, boost, hpRatio, lockMoves, ...set } = member.set
  return { set: { ...set, species: p.name }, levelCap, bonus, boost, hpRatio }
}
const movesOf = (id, level) => F.movesAt(pokemon[id].moves, level, pokemon[id].types, moves)

/** Uma batalha do andar; devolve {won, after}. */
function battle(run) {
  const order = F.battleOrder(run)
  const mine = order.map((i) => engineMon(F.memberOf(run, run.team[i], movesOf(run.team[i].id, run.team[i].level))))
  const theirs = run.encounter.foes.map((f) => engineMon(F.foeMember(f, movesOf(f.id, f.level))))
  const capture = F.captureFor(run, data)
  // O cenário, o clima e o efeito do lugar, como no jogo.
  const scene = F.bossScene(data, run.encounter.boss, run.encounter.scene ?? 'grass')
  const place = F.fieldOf(run, scene)
  const weather = F.weatherOf(run, scene) || (place === 'wind' ? 'wind' : '')
  const field = place === 'wind' ? '' : place
  const game = sim.create({ teams: [mine, theirs], seed: [run.seed & 0xffff, run.floor, 3, 4], bags: F.bagsFor(run), healPct: true, ...(capture ? { capture } : {}), ...(weather ? { weather } : {}), ...(field ? { field } : {}) })
  // Vale capturar? Com vaga no time ou mais forte que o mais fraco.
  const foe0 = run.encounter.foes[0]
  const weakest = Math.min(...run.team.map(strength))
  const wantCatch = capture && (run.team.length < F.MAX_TEAM || strength(foe0) > weakest * 1.1)
  let state = game.state
  // Quem lutou contra cada adversário (para o XP).
  const fought = run.encounter.foes.map(() => [])
  const mark = () => { const list = fought[state.sides[1].active]; const mine = order[state.sides[0].active]; if (list && !list.includes(mine)) list.push(mine) }
  mark()
  try {
    for (let turn = 0; turn < 400 && state.winner == null; turn++) {
      const actions = [0, 1].map((side) => {
        const s = state.sides[side]
        const me = s.team[s.active]
        // A bola no selvagem quando ele está fraco (a melhor que tiver).
        const wild = state.sides[1].team[state.sides[1].active]
        if (side === 0 && wantCatch && !s.forceSwitch && !s.wait && wild.hp > 0 && wild.hp < wild.maxHp * 0.35) {
          const ball = ['master-ball', 'ultra-ball', 'great-ball', 'net-ball', 'dusk-ball', 'timer-ball', 'poke-ball'].find((id) => state.bags[0][id] > 0)
          if (ball) return { kind: 'item', item: ball, index: state.sides[1].active }
        }
        // Poção quando o que está em campo está mal (o jogador e o adversário).
        if (!s.forceSwitch && !s.wait && me.hp > 0 && me.hp < me.maxHp * 0.3) {
          const potion = ['max-potion', 'hyper-potion', 'super-potion', 'potion'].find((id) => state.bags[side][id] > 0)
          if (potion) return { kind: 'item', item: potion, index: s.active }
        }
        return sim.recommend(game.handle, side).actions[0]
      })
      state = sim.choose(game.handle, actions).state
      mark()
    }
  } catch (error) {
    if (process.env.DEBUG) console.error('erro na batalha:', error.message)
    return { won: false, after: null }
  } finally {
    sim.dispose(game.handle)
  }
  const hp = [...run.team.map((m) => m.hp)]
  order.forEach((teamIndex, slot) => { const p = state.sides[0].team[slot]; hp[teamIndex] = p.hp / p.maxHp })
  if (process.env.DEBUG && state.winner !== 0) console.error(`andar ${run.floor}: perdeu para ${run.encounter.kind} ${run.encounter.foes.map((f) => `${pokemon[f.id].name}:${f.level}`).join(' ')} (turnos ${state.turn})`)
  return { won: state.winner === 0, after: { hp, bag: state.bags[0], captured: state.captured != null, fought } }
}

function strength(m) { return (data.species[m.id]?.[1] ?? 300) * m.level }
const balls = (run) => F.BALL_IDS.reduce((sum, id) => sum + (run.bag[id] ?? 0), 0)

/**
 * Treinar: numa batalha fácil (selvagem ou treinador) o mais fraco abre, se não
 * estiver muito abaixo dos adversários; nas outras, o mais forte.
 */
function pickLead(run) {
  const alive = [...run.team.keys()].filter((i) => (run.team[i].hp ?? 1) > 0.5)
  if (!alive.length) return run
  const foe = Math.max(...run.encounter.foes.map((f) => f.level))
  const easy = ['wild', 'trainer'].includes(run.encounter.kind)
  const weakest = [...alive].sort((a, b) => run.team[a].level - run.team[b].level)[0]
  if (process.env.NO_TRAIN) return run
  if (easy && alive.length >= 3 && run.team[weakest].level >= foe) return F.setLead(run, weakest)
  return F.setLead(run, [...alive].sort((a, b) => strength(run.team[b]) - strength(run.team[a]))[0])
}

/** O caminho no mapa: Centro com o time mal, loja com dinheiro, treinador forte com o time inteiro, selvagem com vaga no time. */
function choosePath(run) {
  const options = run.route.options
  const down = run.team.filter((m) => !(m.hp > 0)).length
  const hurt = run.team.reduce((sum, m) => sum + (1 - (m.hp ?? 1)), 0) / run.team.length
  const has = (kind) => options.findIndex((o) => o.kind === kind)
  const order = [
    hurt > 0.45 || down * 2 >= run.team.length ? 'center' : null,
    run.money > 600 * F.priceScale(run.floor) ? 'mart' : null,
    hurt < 0.2 ? 'ace' : null,
    run.team.length < F.MAX_TEAM ? 'wild' : null,
    'trainer', 'wild', 'event', 'trade', 'ace', 'wildboss', 'mart', 'center', 'boss',
  ]
  for (const kind of order) if (kind && has(kind) >= 0) return has(kind)
  return 0
}

/** Sorteia o caminho de novo quando o time está mal e não tem Centro (ou está bem e só tem coisa fraca). */
function maybeReroll(run) {
  const kinds = run.route.options.map((o) => o.kind)
  const hurt = run.team.reduce((sum, m) => sum + (1 - (m.hp ?? 1)), 0) / run.team.length
  if (run.townMap && (run.rerolls ?? 0) > 0 && kinds.length > 1 && hurt > 0.5 && !kinds.includes('center')) return F.rerollRoute(run, data) ?? run
  return run
}

/** O que um jogador simples faz entre os andares. */
function between(run) {
  const p = run.pending
  // Entrou num lugar perto da cidade (sem pendência): já tem os caminhos dele.
  if (!p) return run
  if (p.capture) {
    const foe = { id: p.capture.id, level: p.capture.level }
    if (run.team.length < F.MAX_TEAM) run = F.capture(run)
    else {
      const weakest = [...run.team.keys()].sort((a, b) => strength(run.team[a]) - strength(run.team[b]))[0]
      run = strength(foe) > strength(run.team[weakest]) * 1.1 ? F.capture(run, weakest) : F.skipCapture(run)
    }
  } else run = F.skipCapture(run)
  // Troca: dá o mais fraco se o oferecido (3 níveis acima) for mais forte.
  if (run.pending.trade) {
    const weakest = [...run.team.keys()].sort((a, b) => strength(run.team[a]) - strength(run.team[b]))[0]
    const offer = { id: run.pending.trade.id, level: run.team[weakest].level + F.TRADE_LEVELS }
    run = strength(offer) > strength(run.team[weakest]) ? F.tradeMon(run, weakest, data) : F.skipTrade(run)
  }
  if (run.pending.cards) {
    const down = run.team.filter((m) => !(m.hp > 0)).length
    const want = [down >= 2 ? 'heal' : null, balls(run) < 2 ? 'balls' : null, 'atk', 'hp', 'exp', 'level', 'def', 'spe', 'money', 'sale', 'heal', 'balls']
    run = F.takeCard(run, want.find((c) => c && run.pending.cards.includes(c)), data)
  }
  const shop = run.pending.shop ?? []
  const buy = (id, index = 0) => { const next = F.buyItem(run, id, index, data); if (next) run = next; return Boolean(next) }
  const down = () => run.team.filter((m) => !(m.hp > 0)).length
  for (let guard = 0; guard < 60 && shop.length; guard++) {
    const potions = run.bag.potion + run.bag['super-potion'] + run.bag['hyper-potion'] + run.bag['max-potion']
    const lowest = [...run.team.keys()].sort((a, b) => run.team[a].level - run.team[b].level)[0]
    const best = [...run.team.keys()].sort((a, b) => strength(run.team[b]) - strength(run.team[a]))[0]
    if (down() > run.bag.revive && shop.includes('revive') && buy('revive')) continue
    if (potions < 3 && ['hyper-potion', 'super-potion', 'max-potion', 'potion'].some((id) => shop.includes(id) && buy(id))) continue
    if (balls(run) < 3 && ['ultra-ball', 'great-ball', 'poke-ball'].some((id) => shop.includes(id) && buy(id))) continue
    if (shop.includes('town-map') && !run.townMap && buy('town-map')) continue
    if (shop.includes('exp-share') && !run.expShare && buy('exp-share')) continue
    if (shop.includes('rare-candy') && buy('rare-candy', lowest)) continue
    const held = shop.find((id) => F.HELD_BOOST[id])
    if (held && buy(held, best)) continue
    const vit = shop.find((id) => F.VITAMINS[id] || id === 'bottle-cap')
    if (vit && buy(vit, best)) continue
    break
  }
  // Os itens guardados (dos treinadores fortes): no mais forte que ainda não segura nada (senão, no mais forte).
  while ((run.stash ?? []).length) {
    const order = [...run.team.keys()].sort((a, b) => strength(run.team[b]) - strength(run.team[a]))
    run = F.equipFromStash(run, 0, order.find((i) => !run.team[i].item) ?? order[0])
  }
  // Bolsa fora da batalha: Revive em quem desmaiou, poção em quem está abaixo da metade.
  for (const [i, m] of run.team.entries()) {
    if (!(m.hp > 0)) run = F.applyBagItem(run, 'revive', i) ?? run
    for (const id of ['super-potion', 'potion', 'hyper-potion']) if (run.team[i].hp > 0 && run.team[i].hp < 0.5) run = F.applyBagItem(run, id, i) ?? run
  }
  return F.nextFloor(run, data)
}

/**
 * Para testar os andares altos sem jogar tudo: começa no andar com um time
 * pronto (evoluídos, nível ~15% acima dos adversários, EVs como os deles,
 * um item cada e uma carta por chefe), como um jogador que chegou lá.
 */
function preparedRun(run, floor, r) {
  let seed = 99 + r
  const rand = () => { const [v, s] = F.nextRandom(seed); seed = s; return v }
  const strong = Object.entries(data.species).filter(([id, i]) => i[2] === 0 && i[1] >= 480 && i[1] <= 540 && !data.evolutions[id]).map(([id]) => Number(id))
  const held = Object.keys(F.HELD_BOOST)
  const level = Math.round(F.foeLevelAt(floor) * 1.15)
  const team = Array.from({ length: 6 }, () => ({
    ...F.newMon(strong[Math.floor(rand() * strong.length)], level, rand, 20),
    evs: Object.fromEntries(F.STATS.map((s) => [s, F.foeEvsAt(floor)])), item: held[Math.floor(rand() * held.length)],
  }))
  // As cartas que ele teria pegado (uma por chefe): atributos em rodízio.
  const cards = ['atk', 'hp', 'def', 'spe']
  let teamBoost = Object.fromEntries(F.STATS.map((s) => [s, 0]))
  for (let i = 0; i < Math.floor(floor / 10); i++) {
    const card = F.CARDS[cards[i % cards.length]]
    teamBoost = Object.fromEntries(F.STATS.map((s) => [s, teamBoost[s] + (card.team[s] ?? 0)]))
  }
  const out = { ...run, floor, team, teamBoost, money: 0, boss: { region: 0, step: Math.min(12, Math.floor(floor / 10)) } }
  out.route = F.routeOptions(out, data, rand)
  return out
}

const startFloor = Number(process.env.START_FLOOR ?? 1)
const results = []
const checkpoints = {}
for (let r = 0; r < runs; r++) {
  const starter = data.starters[r % data.starters.length]
  // Melhorias permanentes (UPGRADES níveis de cada), como quem já jogou algumas corridas.
  let meta = { ...F.emptyFactory(), coins: 1e9, best: 999, owned: [...data.starters] }
  for (const id of Object.keys(F.UPGRADES)) for (let k = 0; k < Number(process.env.UPGRADES ?? 0); k++) meta = F.buyUpgrade(meta, id) ?? meta
  let run = F.startRun(meta, data, starter, 1000 + r * 7919)
  if (startFloor > 1) run = preparedRun(run, startFloor, r)
  while (run.floor <= maxFloor) {
    run = maybeReroll(run)
    // Na cidade: cura no Centro e compra no Poké Mart dela antes de escolher (o ginásio ou o lugar perto dela).
    if (run.route.town) {
      run = F.townCenter(run)
      run = { ...run, pending: null }
      run = between(F.townShop(run))
      run = { ...run, pending: null }
      run = { ...run, route: F.routeOptions(run, data, () => 0.5) }
    }
    // Sem o Mapa, a bifurcação vai às cegas (como no jogo).
    run = F.chooseNode(run, data, run.townMap || run.route.options.length < 2 ? choosePath(run) : F.blindPick(run))
    // Escolha na rota: ajuda se sobra dinheiro, entra na caverna e segue o Pokémon ferido se o time está bem.
    const choice = run.pending?.choice
    if (choice) {
      const healthy = run.team.filter((m) => (m.hp ?? 1) > 0.5).length >= Math.ceil(run.team.length / 2)
      run = F.resolveChoice(run, data, choice.kind === 'help' ? run.money >= choice.cost * 3 : choice.kind === 'secret' || healthy)
    }
    // Sem batalha (Poké Mart, Centro, evento): o que tiver para fazer e o próximo andar.
    if (!run.encounter) {
      run = between(run)
      continue
    }
    run = pickLead(run)
    const { won, after } = battle(run)
    if (!won) break
    const floor = run.floor
    run = F.winFloor(run, data, after)
    if (process.env.TRACE) console.error(`  andar ${floor} ${run.encounter?.kind ?? ''} venceu: time ${run.team.map((m) => `${pokemon[m.id]?.name}:${m.level}:${Math.round(m.hp * 100)}%`).join(' ')} | bolsa ${JSON.stringify(run.bag)} | $${run.money} loja ${Boolean(run.pending.shop)}`)
    if (floor % 25 === 0) {
      const top = Math.max(...run.team.map((m) => m.level))
      ;(checkpoints[floor] ??= []).push({ top, foe: F.foeLevelAt(floor), team: run.team.length, money: run.money })
    }
    run = between(run)
  }
  results.push(run.floor - 1)
  console.log(`corrida ${r + 1}: ${pokemon[starter].name} chegou ao andar ${run.floor - 1} (time ${run.team.map((m) => `${pokemon[m.id]?.name}:${m.level}`).join(' ')})`)
}
results.sort((a, b) => a - b)
console.log('\nandares vencidos:', results.join(' '), '| mediana', results[Math.floor(results.length / 2)])
for (const [floor, list] of Object.entries(checkpoints)) {
  const avg = (k) => Math.round(list.reduce((s, x) => s + x[k], 0) / list.length)
  console.log(`andar ${floor}: ${list.length} corridas | maior nível do time ${avg('top')} x adversários ${avg('foe')} | time ${avg('team')} | dinheiro ${avg('money')}`)
}
