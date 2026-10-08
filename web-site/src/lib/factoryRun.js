// Battle Factory: você escolhe um inicial no nível 5 e vai subindo andares.
// Cada andar é um Pokémon selvagem (dá para capturar, até 6 no time), um
// treinador ou, mais raro, um lendário. Cada Pokémon derrotado dá XP (o time
// todo sobe de nível e evolui) e dinheiro para a loja, que aparece a cada 5
// andares e com 20% de chance nos outros. A cada 10 andares você escolhe uma
// carta de bônus. Aqui não há limite de itens, IVs ou EVs: um item é o
// segurado e os outros viram pontos a mais nos atributos (o motor soma esses
// pontos: tool/battle-engine/engine.mjs, "bonus").
// Perdeu: a corrida acaba e a pontuação vira moedas, que compram Pokémon para
// começar as próximas corridas (os mais fortes custam mais).
// Dados: assets/database/factory.json (tool/build_factory_data.py). Igual ao
// app (lib/services/factory_run.dart).

export const STATS = ['hp', 'atk', 'def', 'spa', 'spd', 'spe']
export const NATURE_LIST = ['Hardy', 'Lonely', 'Brave', 'Adamant', 'Naughty', 'Bold', 'Docile', 'Relaxed', 'Impish', 'Lax', 'Timid', 'Hasty', 'Serious',
  'Jolly', 'Naive', 'Modest', 'Mild', 'Quiet', 'Bashful', 'Rash', 'Calm', 'Gentle', 'Sassy', 'Careful', 'Quirky']
export const MAX_TEAM = 6
export const START_LEVEL = 5
export const MAX_LEVEL = 100

const zero = () => Object.fromEntries(STATS.map((s) => [s, 0]))
const addStats = (a, b) => Object.fromEntries(STATS.map((s) => [s, (a?.[s] ?? 0) + (b?.[s] ?? 0)]))

/** XP total para chegar ao nível (crescimento médio, n³). */
export const expAt = (level) => level ** 3

/** Sorteio com estado salvo na corrida (mulberry32): a mesma corrida dá os mesmos andares no site e no app. */
export function nextRandom(state) {
  const t = (state + 0x6d2b79f5) >>> 0
  let r = Math.imul(t ^ (t >>> 15), t | 1)
  r ^= r + Math.imul(r ^ (r >>> 7), r | 61)
  return [((r ^ (r >>> 14)) >>> 0) / 4294967296, t]
}
/** Um sorteador que avança run.seed. */
function dice(run) {
  return () => {
    const [value, seed] = nextRandom(run.seed)
    run.seed = seed
    return value
  }
}
const pickOne = (list, rand) => list[Math.floor(rand() * list.length)]

// ------------------------------------------------------------ itens e cartas

/** Itens segurados: o primeiro é o item de verdade; os outros viram estes pontos. */
export const HELD_BONUS = {
  leftovers: { hp: 12 }, 'sitrus-berry': { hp: 10 }, 'life-orb': { atk: 6, spa: 6 }, 'expert-belt': { atk: 5, spa: 5 },
  'choice-band': { atk: 10 }, 'muscle-band': { atk: 6 }, 'choice-specs': { spa: 10 }, 'wise-glasses': { spa: 6 },
  'choice-scarf': { spe: 10 }, 'assault-vest': { spd: 10 }, 'rocky-helmet': { def: 10 }, 'focus-sash': { def: 5, spd: 5 },
}
/** Vitaminas: EVs sem limite (pontos no atributo). Bottle Cap: IVs sem limite (um pouco em todos). */
export const VITAMINS = { 'hp-up': 'hp', protein: 'atk', iron: 'def', calcium: 'spa', zinc: 'spd', carbos: 'spe' }
export const SHOP = {
  'rare-candy': 150,
  ...Object.fromEntries(Object.keys(VITAMINS).map((k) => [k, 120])),
  'bottle-cap': 250,
  ...Object.fromEntries(Object.keys(HELD_BONUS).map((k) => [k, 300])),
}
export const VITAMIN_POINTS = 6
export const BOTTLE_CAP_POINTS = 3

/** Cartas de bônus (a cada 10 andares, escolhe 1 de 3). */
export const CARDS = {
  atk: { label: '+8 de Ataque e Ataque Especial para o time todo', team: { atk: 8, spa: 8 } },
  def: { label: '+8 de Defesa e Defesa Especial para o time todo', team: { def: 8, spd: 8 } },
  hp: { label: '+15 de HP para o time todo', team: { hp: 15 } },
  spe: { label: '+8 de Velocidade para o time todo', team: { spe: 8 } },
  level: { label: '+3 níveis para o time todo', levels: 3 },
  money: { label: '+50% de dinheiro por Pokémon derrotado', mult: ['money', 0.5] },
  exp: { label: '+50% de XP por Pokémon derrotado', mult: ['exp', 0.5] },
  sale: { label: 'Loja 25% mais barata', mult: ['shop', -0.25] },
}

// ------------------------------------------------------------ meta (entre corridas)

export const emptyFactory = () => ({ best: 0, coins: 0, owned: [], run: null })
export const factoryOf = (league) => ({ ...emptyFactory(), ...(league?.factory ?? {}) })

/** Preço de um Pokémon (em moedas) pela força: total de atributos. */
export const pokemonPrice = (bst) => Math.max(20, Math.round((Math.max(0, bst - 250) ** 1.5) / 10 / 5) * 5)

/** Com quem dá para começar: os iniciais grátis e os comprados. */
export const startersOf = (factory, data) => [...data.starters, ...factory.owned.filter((id) => !data.starters.includes(id))]

/** Compra um Pokémon com as moedas (null se não dá). */
export function buyPokemon(factory, data, id) {
  const info = data.species[id]
  if (!info || factory.owned.includes(id) || data.starters.includes(id)) return null
  const price = pokemonPrice(info[1])
  if (factory.coins < price) return null
  return { ...factory, coins: factory.coins - price, owned: [...factory.owned, id] }
}

/** Moedas que a corrida rende: 5 por andar vencido e 2 por Pokémon derrotado. */
export const runCoins = (run) => (run.floor - 1) * 5 + run.defeated * 2

// ------------------------------------------------------------ Pokémon da corrida

export function newMon(id, level, rand, minIv = 0) {
  return {
    id, level, exp: expAt(level),
    ivs: Object.fromEntries(STATS.map((s) => [s, minIv + Math.floor(rand() * (32 - minIv))])),
    nature: pickOne(NATURE_LIST, rand),
    item: null, extras: [], bonus: zero(),
  }
}

/** Sobe para o nível (com as evoluções que ele alcançar). Devolve [mon, evoluiu para]. */
export function levelTo(mon, level, data, rand) {
  let out = { ...mon, level: Math.min(MAX_LEVEL, level) }
  out.exp = Math.max(out.exp, expAt(out.level))
  let evolved = null
  for (let guard = 0; guard < 3; guard++) {
    const options = (data.evolutions[out.id] ?? []).filter(([, at]) => out.level >= at)
    if (!options.length) break
    const [to] = pickOne(options, rand)
    out = { ...out, id: to }
    evolved = to
  }
  return [out, evolved]
}

/** Ganha XP: sobe os níveis que der. */
function gainExp(mon, exp, data, rand) {
  const total = mon.exp + exp
  let level = mon.level
  while (level < MAX_LEVEL && total >= expAt(level + 1)) level++
  const [out, evolved] = level > mon.level ? levelTo({ ...mon, exp: total }, level, data, rand) : [{ ...mon, exp: total }, null]
  return { mon: out, from: mon.level, evolved }
}

// ------------------------------------------------------------ andares

/** O que aparece no andar: selvagem, treinador ou (a partir do 10º, raro) lendário. */
export function encounterFor(data, floor, rand) {
  // Começa fácil (nível 2 a 3 no 1º andar) e chega perto do 100 no andar 100.
  const level = Math.min(MAX_LEVEL, Math.max(2, Math.floor(1 + floor * 0.9 + rand() * 2)))
  const r = rand()
  const kind = floor >= 10 && r < 0.04 ? 'legendary' : r < 0.36 ? 'trainer' : 'wild'
  const entries = Object.entries(data.species).map(([id, [, bst, rarity]]) => ({ id: Number(id), bst, rarity }))
  const budget = Math.min(720, 290 + floor * 7)
  const pick = (pool) => {
    const fit = pool.filter((p) => p.bst <= budget && p.bst >= budget - 160)
    return pickOne(fit.length ? fit : [...pool].sort((a, b) => Math.abs(a.bst - budget) - Math.abs(b.bst - budget)).slice(0, 20), rand).id
  }
  const common = entries.filter((p) => p.rarity === 0 || p.rarity === 3)
  const iv = Math.min(31, Math.floor(floor / 2))
  const foe = (id, lvl) => ({ id, level: Math.max(1, Math.min(MAX_LEVEL, lvl)), iv })
  if (kind === 'legendary') {
    const legends = entries.filter((p) => p.rarity === 1 || p.rarity === 2)
    return { kind, foes: [foe(pickOne(legends, rand).id, level + 3)] }
  }
  if (kind === 'trainer') {
    const count = Math.min(MAX_TEAM, 1 + Math.floor(floor / 8) + (rand() < 0.3 ? 1 : 0))
    const foes = Array.from({ length: count }, () => foe(pick(common), level - Math.floor(rand() * 3)))
    return { kind, foes, trainerSeed: Math.floor(rand() * 1e9) }
  }
  return { kind, foes: [foe(pick(common), level)] }
}

/** Começa uma corrida com o inicial escolhido (um dos grátis ou comprado). */
export function startRun(factory, data, id, seed) {
  if (!startersOf(factory, data).includes(id)) return null
  const run = { seed: seed >>> 0, floor: 1, money: 0, defeated: 0, team: [], teamBonus: zero(), mult: { money: 1, exp: 1, shop: 1 }, cards: [], encounter: null, pending: null }
  const rand = dice(run)
  // O inicial vem com IVs bons (15 a 31).
  run.team = [newMon(id, START_LEVEL, rand, 15)]
  run.encounter = encounterFor(data, run.floor, rand)
  return run
}

/** Venceu o andar: XP e dinheiro por Pokémon derrotado, depois captura/carta/loja (pending). */
export function winFloor(run, data) {
  const out = { ...run, team: [...run.team] }
  const rand = dice(out)
  const { kind, foes } = run.encounter
  const trainer = kind === 'trainer'
  let exp = 0, money = 0
  for (const f of foes) {
    exp += Math.floor(((data.species[f.id]?.[0] ?? 60) * f.level) / 7 * (trainer ? 1.5 : 1) * out.mult.exp)
    money += Math.floor(f.level * 8 * (trainer ? 2 : 1) * out.mult.money)
  }
  const levels = []
  out.team = out.team.map((m, index) => {
    const r = gainExp(m, exp, data, rand)
    if (r.mon.level > r.from || r.evolved) levels.push({ index, from: r.from, to: r.mon.level, evolved: r.evolved })
    return r.mon
  })
  out.money += money
  out.defeated += foes.length
  const cleared = out.floor
  out.floor += 1
  const capture = kind === 'trainer' ? null : foes[0]
  out.pending = {
    exp, money, levels,
    capture,
    cards: cleared % 10 === 0 ? pickCards(rand) : null,
    shop: cleared % 5 === 0 || rand() < 0.2 ? pickShop(rand) : null,
  }
  out.encounter = null
  return out
}

function pickCards(rand) {
  const ids = Object.keys(CARDS)
  const out = []
  while (out.length < 3) {
    const id = pickOne(ids, rand)
    if (!out.includes(id)) out.push(id)
  }
  return out
}

function pickShop(rand) {
  const ids = Object.keys(SHOP)
  const out = ['rare-candy']
  while (out.length < 5) {
    const id = pickOne(ids, rand)
    if (!out.includes(id)) out.push(id)
  }
  return out
}

/** Captura o selvagem derrotado (replace: posição a trocar com o time cheio). */
export function capture(run, replace = null) {
  const foe = run.pending?.capture
  if (!foe) return run
  const out = { ...run, team: [...run.team], pending: { ...run.pending, capture: null } }
  const rand = dice(out)
  const mon = newMon(foe.id, foe.level, rand)
  if (out.team.length < MAX_TEAM) out.team.push(mon)
  else if (replace != null && replace >= 0 && replace < out.team.length) out.team[replace] = mon
  else return run
  return out
}
export const skipCapture = (run) => (run.pending ? { ...run, pending: { ...run.pending, capture: null } } : run)

/** Escolhe a carta de bônus. */
export function takeCard(run, id, data) {
  const card = CARDS[id]
  if (!card || !run.pending?.cards?.includes(id)) return run
  const out = { ...run, cards: [...run.cards, id], pending: { ...run.pending, cards: null } }
  if (card.team) out.teamBonus = addStats(out.teamBonus, card.team)
  if (card.mult) out.mult = { ...out.mult, [card.mult[0]]: out.mult[card.mult[0]] + card.mult[1] }
  if (card.levels) {
    const rand = dice(out)
    out.team = out.team.map((m) => levelTo(m, m.level + card.levels, data, rand)[0])
  }
  return out
}

export const shopPrice = (run, id) => Math.round(SHOP[id] * run.mult.shop)

/** Compra um item da loja para um Pokémon do time (null se não dá). */
export function buyItem(run, id, index, data) {
  const price = shopPrice(run, id)
  const mon = run.team[index]
  if (!mon || !run.pending?.shop?.includes(id) || run.money < price) return null
  const out = { ...run, money: run.money - price, team: [...run.team] }
  if (id === 'rare-candy') {
    if (mon.level >= MAX_LEVEL) return null
    out.team[index] = levelTo(mon, mon.level + 1, data, dice(out))[0]
  } else if (VITAMINS[id]) {
    out.team[index] = { ...mon, bonus: addStats(mon.bonus, { [VITAMINS[id]]: VITAMIN_POINTS }) }
  } else if (id === 'bottle-cap') {
    out.team[index] = { ...mon, bonus: addStats(mon.bonus, Object.fromEntries(STATS.map((s) => [s, BOTTLE_CAP_POINTS]))) }
  } else if (HELD_BONUS[id]) {
    // Sem item: vira o segurado; já com um: vira pontos (sem limite de itens).
    out.team[index] = mon.item ? { ...mon, extras: [...mon.extras, id], bonus: addStats(mon.bonus, HELD_BONUS[id]) } : { ...mon, item: id }
  } else return null
  return out
}

/** Sai da loja (ou não tinha): o próximo andar. */
export function nextFloor(run, data) {
  const out = { ...run, pending: null }
  out.encounter = encounterFor(data, out.floor, dice(out))
  return out
}

/** Perdeu: a corrida acaba; a pontuação vira moedas e o recorde fica salvo. */
export function endRun(factory, run) {
  const coins = runCoins(run)
  return { ...factory, coins: factory.coins + coins, best: Math.max(factory.best, run.floor - 1), run: null, last: { floor: run.floor - 1, coins } }
}

// ------------------------------------------------------------ para a batalha

/** Golpes que ele sabe no nível (os aprendidos por nível até ali), os melhores 4. */
export function movesAt(formMoves, level, types, moves) {
  const learned = []
  for (const [slug, how] of [...formMoves].filter((m) => m[1] === 'level-up' && m[2] <= level).sort((a, b) => a[2] - b[2])) {
    if (!learned.includes(slug) && moves[slug] && how) learned.push(slug)
  }
  const power = (s) => (moves[s].category !== 'status' && moves[s].power > 0 ? moves[s].power * (types.includes(moves[s].type) ? 1.5 : 1) * ((moves[s].accuracy ?? 100) / 100) : 0)
  const damaging = learned.filter((s) => power(s) > 0).sort((a, b) => power(b) - power(a))
  const chosen = []
  for (const s of damaging) if (chosen.length < 3 && !chosen.some((c) => moves[c].type === moves[s].type)) chosen.push(s)
  for (const s of damaging) if (chosen.length < 3 && !chosen.includes(s)) chosen.push(s)
  for (const s of [...learned].reverse()) if (chosen.length < 4 && !chosen.includes(s)) chosen.push(s)
  return chosen.length ? chosen : ['tackle']
}

/** A Bolsa de cada lado: a sua é a padrão; selvagem não tem itens; treinador tem poucas poções (mais nos andares altos). */
export function bagsFor(run) {
  const floor = run.floor
  const trainer = run.encounter?.kind === 'trainer'
  const foe = trainer
    ? { potion: Math.min(3, 1 + Math.floor(floor / 15)), 'super-potion': floor >= 20 ? 1 : 0, 'hyper-potion': floor >= 40 ? 1 : 0, revive: 0 }
    : { potion: 0, 'super-potion': 0, 'hyper-potion': 0, revive: 0 }
  return [null, foe]
}

/** O Pokémon da corrida como membro de time (battleSetup.battleMons). */
export function memberOf(run, mon, moveList) {
  return {
    id: mon.id,
    set: {
      level: mon.level, levelCap: MAX_LEVEL, nature: mon.nature, ivs: mon.ivs, item: mon.item ?? '', moves: moveList, lockMoves: true,
      bonus: addStats(mon.bonus, run.teamBonus),
    },
  }
}

/** Um adversário do andar como membro de time. */
export function foeMember(foe, moveList) {
  return { id: foe.id, set: { level: foe.level, levelCap: MAX_LEVEL, ivs: Object.fromEntries(STATS.map((s) => [s, foe.iv])), moves: moveList, lockMoves: true } }
}
