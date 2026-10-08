// Battle Factory, um roguelike: você escolhe um inicial no nível 5 e vai
// subindo andares (sem fim). Cada andar é um Pokémon selvagem (dá para
// capturar com Poké Ball: começa com 5, as outras se compram), um treinador
// ou, mais raro, um lendário; a cada 10 andares vem um chefe (os líderes de
// ginásio com o rival e os vilões no meio, a Elite Four e o Campeão de um
// jogo sorteado, na ordem da história; depois do Campeão, outro jogo; os
// times deles crescem conforme a corrida sobe). O time NÃO é curado entre os
// andares: o HP e quem desmaiou continuam (Bolsa, loja e, com 5% de chance, a Enfermeira Joy).
// Cada Pokémon derrotado dá XP e EVs (só para quem está de pé) e dinheiro
// para a loja, que aparece a cada 5 andares (uma delas logo antes do chefe)
// e com 20% de chance nos outros.
// Depois de cada chefe, uma carta de bônus. Sem limite de nível, IVs, EVs ou
// itens: um item é o segurado (efeito de verdade) e os outros dão uma versão
// bem mais fraca do bônus (porcentagem no atributo certo).
// Perdeu: a corrida acaba e a pontuação vira moedas, que compram Pokémon para
// começar as próximas corridas (os mais fortes custam mais). Os iniciais
// também aparecem para capturar, mas isso não libera para começar; capturar um
// inicial shiny libera a versão shiny dele (shiny dá +10% nos atributos), que
// também se compra com moedas, bem caro.
//
// A dificuldade (andar f; simulação em tool/factory_balance.mjs):
//   nível dos adversários  2 + 0,8·(f−1) (+0 a 1), sem teto
//   EVs dos adversários    2·f por atributo; IVs 31 a partir do andar 62 e
//                          +1 a cada 10 andares depois do 100 (sem limite)
//   depois do andar 50     +2% em todos os atributos a cada 10 andares (as
//                          cartas dão ~1,5%: lá em cima a corrida sempre acaba)
//   XP                     fórmula da 5ª geração: quem está abaixo do nível do
//                          adversário ganha mais, quem está acima ganha menos,
//                          então o time acompanha os andares
//   dinheiro e preços      os dois crescem com o andar (a loja não fica de graça)
// Dados: assets/database/factory.json (tool/build_factory_data.py). Igual ao
// app (lib/services/factory_run.dart).

export const STATS = ['hp', 'atk', 'def', 'spa', 'spd', 'spe']
export const NATURE_LIST = ['Hardy', 'Lonely', 'Brave', 'Adamant', 'Naughty', 'Bold', 'Docile', 'Relaxed', 'Impish', 'Lax', 'Timid', 'Hasty', 'Serious',
  'Jolly', 'Naive', 'Modest', 'Mild', 'Quiet', 'Bashful', 'Rash', 'Calm', 'Gentle', 'Sassy', 'Careful', 'Quirky']
export const MAX_TEAM = 6
export const START_LEVEL = 5
export const START_BALLS = 5
/** A Bolsa do começo da corrida (os itens gastos na batalha não voltam). */
export const START_BAG = { potion: 4, 'super-potion': 1, 'hyper-potion': 0, 'max-potion': 0, revive: 1 }
/** Quanto cada item da Bolsa cura (parte do HP máximo; igual na batalha: healPct do motor). */
export const HEAL_SHARE = { potion: 0.25, 'super-potion': 0.5, 'hyper-potion': 0.75, 'max-potion': 1 }
export const JOY_CHANCE = 0.05
/** Selvagens e lendários shiny: 2% de chance; shiny tem +10% em todos os atributos. */
export const SHINY_CHANCE = 0.02
export const SHINY_BOOST = 0.1
export const BOSS_EVERY = 10

const zero = () => Object.fromEntries(STATS.map((s) => [s, 0]))
const addStats = (a, b) => Object.fromEntries(STATS.map((s) => [s, (a?.[s] ?? 0) + (b?.[s] ?? 0)]))
const round3 = (n) => Math.round(n * 1000) / 1000
// Potências com multiplicação e raiz (dão o mesmo resultado no app, em Dart).
const pow15 = (x) => x * Math.sqrt(x)
const pow6 = (x) => { const x2 = x * x; return x2 * x2 * x2 }

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

// ------------------------------------------------------------ dificuldade

/** Nível base dos adversários no andar (sem teto). */
export const foeLevelAt = (floor) => 2 + Math.floor((floor - 1) * 0.8)
/** EVs (por atributo) dos adversários: sobem sem limite. */
export const foeEvsAt = (floor) => 2 * floor
/** IVs dos adversários: chegam a 31 e, depois do andar 100, passam do limite. */
export const foeIvsAt = (floor) => Math.min(31, Math.floor(floor / 2)) + Math.max(0, Math.floor((floor - 100) / 10))
/** Porcentagem a mais em todos os atributos dos adversários depois do andar 50 (um pouco mais que as cartas: um dia a corrida acaba). */
export const foeBoostAt = (floor) => Math.round(Math.max(0, floor - 50) * 0.002 * 1000) / 1000
/** Preço da loja no andar (cresce junto com o dinheiro que os adversários dão). */
export const priceScale = (floor) => 1 + (floor - 1) / 20

// ------------------------------------------------------------ itens e cartas

/** Itens de segurar: o principal tem o efeito de verdade; cada um a mais dá esta porcentagem (bem mais fraca). */
export const HELD_BOOST = {
  'choice-band': { atk: 0.05 }, 'choice-specs': { spa: 0.05 }, 'choice-scarf': { spe: 0.05 },
  'life-orb': { atk: 0.03, spa: 0.03 }, 'expert-belt': { atk: 0.02, spa: 0.02 }, 'muscle-band': { atk: 0.02 }, 'wise-glasses': { spa: 0.02 },
  leftovers: { hp: 0.04 }, 'sitrus-berry': { hp: 0.03 }, 'assault-vest': { spd: 0.05 }, 'rocky-helmet': { def: 0.04 },
  eviolite: { def: 0.04, spd: 0.04 }, 'focus-sash': { hp: 0.02, def: 0.01, spd: 0.01 }, 'quick-claw': { spe: 0.03 },
}
/** Vitaminas: EVs sem limite. Bottle Cap: IVs sem limite (em todos). */
export const VITAMINS = { 'hp-up': 'hp', protein: 'atk', iron: 'def', calcium: 'spa', zinc: 'spd', carbos: 'spe' }
export const VITAMIN_EVS = 24
export const BOTTLE_CAP_IVS = 3
/** Preço no 1º andar (priceScale aumenta com o andar). */
export const SHOP = {
  'poke-ball': 50,
  potion: 40, 'super-potion': 90, 'hyper-potion': 160, 'max-potion': 300, revive: 180,
  'rare-candy': 120,
  ...Object.fromEntries(Object.keys(VITAMINS).map((k) => [k, 90])),
  'bottle-cap': 200,
  ...Object.fromEntries(Object.keys(HELD_BOOST).map((k) => [k, 250])),
}
/** Itens que vão para a Bolsa (não precisam de um Pokémon). */
export const BAG_ITEMS = Object.keys(START_BAG)

/** Cartas de bônus (depois de cada chefe, escolhe 1 de 3). */
export const CARDS = {
  atk: { label: '+6% de Ataque e Ataque Especial para o time todo', team: { atk: 0.06, spa: 0.06 } },
  def: { label: '+6% de Defesa e Defesa Especial para o time todo', team: { def: 0.06, spd: 0.06 } },
  hp: { label: '+8% de HP para o time todo', team: { hp: 0.08 } },
  spe: { label: '+6% de Velocidade para o time todo', team: { spe: 0.06 } },
  level: { label: '+3 níveis para o time todo', levels: 3 },
  money: { label: '+50% de dinheiro por Pokémon derrotado', mult: ['money', 0.5] },
  exp: { label: '+50% de XP por Pokémon derrotado', mult: ['exp', 0.5] },
  sale: { label: 'Loja 20% mais barata', mult: ['shop', -0.2] },
  balls: { label: '+5 Poké Balls', balls: 5 },
  heal: { label: 'Cura o time todo e +1 Max Potion', heal: true },
}

// ------------------------------------------------------------ meta (entre corridas)

export const emptyFactory = () => ({ best: 0, coins: 0, owned: [], shinies: [], run: null })
export const factoryOf = (league) => ({ ...emptyFactory(), ...(league?.factory ?? {}) })

/** Preço de um Pokémon (em moedas) pela força: total de atributos. */
export const pokemonPrice = (bst) => Math.max(20, Math.round(pow15(Math.max(0, bst - 250)) / 10 / 5) * 5)

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

/** Preço para transformar um inicial em shiny (bem caro). */
export const shinyPrice = (bst) => Math.max(3000, pokemonPrice(bst) * 20)

/** Transforma um inicial (grátis ou comprado) em shiny com as moedas (null se não dá). */
export function buyShiny(factory, data, id) {
  const info = data.species[id]
  const shinies = factory.shinies ?? []
  if (!info || shinies.includes(id) || !startersOf(factory, data).includes(id)) return null
  const price = shinyPrice(info[1])
  if (factory.coins < price) return null
  return { ...factory, coins: factory.coins - price, shinies: [...shinies, id] }
}

/** Capturou um shiny: se é um dos iniciais dele, libera o shiny para começar. */
export function unlockShiny(factory, data, mon) {
  const shinies = factory.shinies ?? []
  if (!mon?.shiny || shinies.includes(mon.id) || !startersOf(factory, data).includes(mon.id)) return factory
  return { ...factory, shinies: [...shinies, mon.id] }
}

/** Moedas que a corrida rende: 5 por andar vencido, 2 por Pokémon derrotado e 25 por chefe. */
export const runCoins = (run) => (run.floor - 1) * 5 + run.defeated * 2 + (run.bosses ?? 0) * 25

// ------------------------------------------------------------ Pokémon da corrida

/** Espécie (para XP, EVs e evolução) de um id, que pode ser uma forma regional de chefe. */
const speciesOf = (data, id) => data.species[id] ?? data.species[data.forms?.[id]] ?? null

export function newMon(id, level, rand, minIv = 0, shiny = false) {
  return {
    id, level, exp: expAt(level), ...(shiny ? { shiny: true } : {}),
    ivs: Object.fromEntries(STATS.map((s) => [s, minIv + Math.floor(rand() * (32 - minIv))])),
    evs: zero(),
    nature: pickOne(NATURE_LIST, rand),
    item: null, extras: [], hp: 1,
  }
}

/** Sobe para o nível (com as evoluções que ele alcançar). Devolve [mon, evoluiu para]. */
export function levelTo(mon, level, data, rand) {
  let out = { ...mon, level: Math.max(1, level) }
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

/**
 * XP de derrotar um adversário. No mesmo nível, um adversário comum (XP base
 * 100) dá ~1,7 nível. Quem está abaixo dele ganha bem mais e quem está
 * acima, bem menos ((F+10)/(L+10))^6: com 1 a 6 adversários por andar, o time
 * fica de 10% a 25% acima do nível dos andares em vez de disparar.
 */
export function expFor(baseExp, foeLevel, level, factor = 1) {
  const scale = pow6((foeLevel + 10) / (level + 10))
  const species = Math.min(1.6, Math.max(0.6, Math.sqrt(baseExp / 100)))
  return Math.floor(5 * foeLevel * foeLevel * species * scale * factor)
}

/** Ganha XP: sobe os níveis que der. */
function gainExp(mon, exp, data, rand) {
  const total = mon.exp + exp
  let level = mon.level
  while (total >= expAt(level + 1)) level++
  const [out, evolved] = level > mon.level ? levelTo({ ...mon, exp: total }, level, data, rand) : [{ ...mon, exp: total }, null]
  return { mon: out, from: mon.level, evolved }
}

// ------------------------------------------------------------ andares

/** O chefe da vez: o jogo sorteado no começo, na ordem da história (líderes com rival e vilões no meio, Elite Four, Campeão). */
export function bossOf(data, run) {
  const game = data.bosses[run.boss.region]
  return { region: game.region, game: game.game, ...game.leaders[run.boss.step] }
}

/**
 * O time do chefe: o da batalha do jogo (os do rival e dos vilões crescem a
 * cada vez) e, conforme os andares sobem, completado com os outros Pokémon
 * que o personagem usa no jogo (pool), até 6: ninguém fica com 1 só.
 */
export function bossTeam(boss, floor) {
  const team = [...boss.team]
  const want = Math.min(MAX_TEAM, Math.max(team.length, 2 + Math.floor(floor / 25)))
  const pool = boss.pool?.length ? boss.pool : boss.team
  const extra = pool.filter((id) => !team.includes(id))
  for (let i = 0; team.length < want && pool.length; i++) team.push(i < extra.length ? extra[i] : pool[(i - extra.length) % pool.length])
  return team
}

/** Força (total de atributos) das espécies do andar: mais fortes conforme sobe (depois do andar 60, qualquer uma). */
export const speciesBudget = (floor) => 290 + floor * 7

/** O que aparece no andar: chefe (a cada 10), selvagem, treinador ou lendário (a partir do 15º, mais comum lá em cima). */
export function encounterFor(data, floor, rand, boss = null) {
  const level = Math.max(2, foeLevelAt(floor) + Math.floor(rand() * 2))
  const iv = foeIvsAt(floor), ev = foeEvsAt(floor), boost = foeBoostAt(floor)
  const foe = (id, lvl, extra = {}) => ({ id, level: Math.max(2, lvl), iv, ev, ...(boost ? { boost } : {}), ...extra })
  if (boss) {
    // Os times dos chefes são de Pokémon evoluídos: quem é mais forte que as espécies do andar vem com nível menor.
    const bonus = { gym: 1, rival: 1, villain: 2, elite: 2, champion: 3 }[boss.kind] ?? 1
    const team = bossTeam(boss, floor)
    const levelOf = (id, i) => {
      const bst = speciesOf(data, id)?.[1] ?? 400
      const lvl = level + bonus + (i === team.length - 1 ? 1 : 0)
      return Math.max(2, Math.round(lvl * pow15(Math.min(1, speciesBudget(floor) / bst))))
    }
    const foes = team.map((id, i) => foe(id, levelOf(id, i), { iv: Math.max(31, iv), ev: Math.round(ev * 1.25) }))
    return { kind: 'boss', foes, boss: { id: boss.id, name: boss.name, trainer: boss.trainer, kind: boss.kind, region: boss.region, game: boss.game } }
  }
  const r = rand()
  const legendChance = floor >= 15 ? 0.03 + Math.min(0.07, (floor - 15) / 2000) : 0
  const kind = r < legendChance ? 'legendary' : r < legendChance + 0.35 ? 'trainer' : 'wild'
  // Nos primeiros andares, nada de Fantasma (imune aos golpes Normal que os iniciais têm no começo).
  const entries = Object.entries(data.species)
    .filter(([, info]) => floor >= 8 || !info[4]?.includes('ghost'))
    .map(([id, [, bst, rarity]]) => ({ id: Number(id), bst, rarity }))
  const budget = speciesBudget(floor)
  const pick = (pool) => {
    const fit = pool.filter((p) => p.bst <= budget && p.bst >= Math.min(budget, 600) - 160)
    return pickOne(fit.length ? fit : [...pool].sort((a, b) => Math.abs(a.bst - budget) - Math.abs(b.bst - budget)).slice(0, 20), rand).id
  }
  const common = entries.filter((p) => p.rarity === 0 || p.rarity === 3)
  if (kind === 'legendary') {
    const legends = entries.filter((p) => p.rarity === 1 || p.rarity === 2)
    const id = pickOne(legends, rand).id
    return { kind, foes: [foe(id, level + 3, rand() < SHINY_CHANCE ? { shiny: true } : {})] }
  }
  if (kind === 'trainer') {
    const count = Math.min(MAX_TEAM, 1 + Math.floor(floor / 12) + (rand() < 0.3 ? 1 : 0))
    const foes = Array.from({ length: count }, () => foe(pick(common), level - Math.floor(rand() * 3)))
    return { kind, foes, trainerSeed: Math.floor(rand() * 1e9) }
  }
  const id = pick(common)
  return { kind, foes: [foe(id, level, rand() < SHINY_CHANCE ? { shiny: true } : {})] }
}

/** O encontro do andar atual da corrida (chefe nos múltiplos de 10). */
function encounterOf(run, data, rand) {
  return encounterFor(data, run.floor, rand, run.floor % BOSS_EVERY === 0 ? bossOf(data, run) : null)
}

/** Começa uma corrida com o inicial escolhido (um dos grátis ou comprado). */
export function startRun(factory, data, id, seed, shiny = false) {
  if (!startersOf(factory, data).includes(id) || (shiny && !(factory.shinies ?? []).includes(id))) return null
  const run = {
    seed: seed >>> 0, floor: 1, money: 0, defeated: 0, bosses: 0, balls: START_BALLS, bag: { ...START_BAG },
    team: [], teamBoost: zero(), mult: { money: 1, exp: 1, shop: 1 }, cards: [], boss: { region: 0, step: 0 }, encounter: null, pending: null,
  }
  const rand = dice(run)
  // O inicial vem com IVs bons (15 a 31).
  run.team = [newMon(id, START_LEVEL, rand, 15, shiny)]
  run.boss = { region: Math.floor(rand() * data.bosses.length), step: 0 }
  run.encounter = encounterOf(run, data, rand)
  return run
}

/** O próximo chefe: depois do Campeão, outro jogo (sorteado). */
function nextBoss(run, data, rand) {
  const step = run.boss.step + 1
  if (step < data.bosses[run.boss.region].leaders.length) return { ...run.boss, step }
  const others = data.bosses.map((_, i) => i).filter((i) => i !== run.boss.region || data.bosses.length === 1)
  return { region: pickOne(others, rand), step: 0 }
}

/**
 * Venceu o andar. after = como o time terminou a batalha: {hp: [parte do HP de
 * cada um do time, na ordem da corrida], bag}. Quem está de pé ganha XP e EVs;
 * depois vêm captura, carta (chefe), loja e, às vezes, a Enfermeira Joy (pending).
 */
export function winFloor(run, data, after = {}) {
  const out = { ...run, team: run.team.map((m, i) => ({ ...m, hp: after.hp?.[i] ?? m.hp ?? 1 })), bag: { ...(after.bag ?? run.bag) } }
  const rand = dice(out)
  const { kind, foes } = run.encounter
  const factor = kind === 'boss' ? 1.5 : kind === 'trainer' ? 1.5 : 1
  const moneyFactor = kind === 'boss' ? 3 : kind === 'trainer' ? 2 : 1
  let money = 0
  const evs = zero()
  for (const f of foes) {
    money += Math.floor((f.level * 6 + 10) * moneyFactor * out.mult.money)
    const yields = speciesOf(data, f.id)?.[3] ?? [0, 0, 0, 0, 0, 0]
    STATS.forEach((s, i) => { evs[s] += yields[i] * 3 })
  }
  const levels = []
  let exp = 0
  out.team = out.team.map((m, index) => {
    if (!(m.hp > 0)) return m
    const gained = foes.reduce((sum, f) => sum + expFor(speciesOf(data, f.id)?.[0] ?? 60, f.level, m.level, factor * out.mult.exp), 0)
    exp = Math.max(exp, gained)
    const r = gainExp({ ...m, evs: addStats(m.evs, evs) }, gained, data, rand)
    if (r.mon.level > r.from || r.evolved) levels.push({ index, from: r.from, to: r.mon.level, evolved: r.evolved })
    return r.mon
  })
  out.money += money
  out.defeated += foes.length
  const cleared = out.floor
  out.floor += 1
  if (kind === 'boss') {
    out.bosses = (out.bosses ?? 0) + 1
    out.boss = nextBoss(out, data, rand)
  }
  const joy = rand() < JOY_CHANCE
  if (joy) out.team = out.team.map((m) => ({ ...m, hp: 1 }))
  out.pending = {
    exp, money, levels, joy,
    capture: kind === 'wild' || kind === 'legendary' ? foes[0] : null,
    cards: kind === 'boss' ? pickCards(rand) : null,
    // A loja: garantida a cada 5 andares (logo antes de cada chefe e no meio) e com 20% de chance nos outros.
    shop: cleared % 5 === 4 || rand() < 0.2 ? pickShop(rand) : null,
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
  const ids = Object.keys(SHOP).filter((id) => id !== 'poke-ball')
  const out = ['poke-ball', pickOne(['potion', 'super-potion', 'hyper-potion', 'max-potion', 'revive'], rand)]
  while (out.length < 6) {
    const id = pickOne(ids, rand)
    if (!out.includes(id)) out.push(id)
  }
  return out
}

/** Captura o selvagem derrotado com uma Poké Ball (replace: posição a trocar com o time cheio). */
export function capture(run, replace = null) {
  const foe = run.pending?.capture
  if (!foe || !(run.balls > 0)) return run
  const out = { ...run, balls: run.balls - 1, team: [...run.team], pending: { ...run.pending, capture: null } }
  const rand = dice(out)
  const mon = newMon(foe.id, foe.level, rand, 0, Boolean(foe.shiny))
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
  if (card.team) out.teamBoost = Object.fromEntries(STATS.map((s) => [s, round3((out.teamBoost?.[s] ?? 0) + (card.team[s] ?? 0))]))
  if (card.mult) out.mult = { ...out.mult, [card.mult[0]]: Math.max(0.4, round3(out.mult[card.mult[0]] + card.mult[1])) }
  if (card.balls) out.balls += card.balls
  if (card.heal) {
    out.team = out.team.map((m) => ({ ...m, hp: 1 }))
    out.bag = { ...out.bag, 'max-potion': (out.bag['max-potion'] ?? 0) + 1 }
  }
  if (card.levels) {
    const rand = dice(out)
    out.team = out.team.map((m) => levelTo(m, m.level + card.levels, data, rand)[0])
  }
  return out
}

/** Preço do item no andar (com o desconto das cartas). O Rare Candy também sobe com o nível do time (cada nível pede mais XP). */
export function shopPrice(run, id) {
  const top = id === 'rare-candy' ? Math.max(START_LEVEL, ...run.team.map((m) => m.level)) : START_LEVEL
  return Math.max(1, Math.round(SHOP[id] * priceScale(run.floor) * (top / START_LEVEL) * run.mult.shop))
}

/** Compra um item da loja (index: o Pokémon que recebe; itens da Bolsa e Poké Ball não precisam). null se não dá. */
export function buyItem(run, id, index, data) {
  const price = shopPrice(run, id)
  if (!run.pending?.shop?.includes(id) || run.money < price) return null
  const out = { ...run, money: run.money - price, team: [...run.team] }
  if (id === 'poke-ball') return { ...out, balls: out.balls + 1 }
  if (BAG_ITEMS.includes(id)) return { ...out, bag: { ...out.bag, [id]: (out.bag[id] ?? 0) + 1 } }
  const mon = run.team[index]
  if (!mon) return null
  if (id === 'rare-candy') {
    out.team[index] = levelTo(mon, mon.level + 1, data, dice(out))[0]
  } else if (VITAMINS[id]) {
    out.team[index] = { ...mon, evs: addStats(mon.evs, { [VITAMINS[id]]: VITAMIN_EVS }) }
  } else if (id === 'bottle-cap') {
    out.team[index] = { ...mon, ivs: addStats(mon.ivs, Object.fromEntries(STATS.map((s) => [s, BOTTLE_CAP_IVS]))) }
  } else if (HELD_BOOST[id]) {
    // Sem item: vira o segurado; já com um: entra nos extras (sem limite de itens).
    out.team[index] = mon.item ? { ...mon, extras: [...mon.extras, id] } : { ...mon, item: id }
  } else return null
  return out
}

/** Troca o item principal pelo extra da posição (o principal volta para os extras). */
export function setMainItem(run, index, extra) {
  const mon = run.team[index]
  const id = mon?.extras?.[extra]
  if (!id) return run
  const extras = [...mon.extras]
  if (mon.item) extras[extra] = mon.item
  else extras.splice(extra, 1)
  const team = [...run.team]
  team[index] = { ...mon, item: id, extras }
  return { ...run, team }
}

/** Usa um item da Bolsa fora da batalha (poção em quem está ferido, Revive em quem desmaiou). null se não dá. */
export function applyBagItem(run, id, index) {
  const mon = run.team[index]
  if (!mon || !(run.bag[id] > 0)) return null
  const hp = mon.hp ?? 1
  let next
  if (id === 'revive') {
    if (hp > 0) return null
    next = 0.5
  } else if (HEAL_SHARE[id]) {
    if (!(hp > 0) || hp >= 1) return null
    next = Math.min(1, round3(hp + HEAL_SHARE[id]))
  } else return null
  const team = [...run.team]
  team[index] = { ...mon, hp: next }
  return { ...run, team, bag: { ...run.bag, [id]: run.bag[id] - 1 } }
}

/** O time inteiro desmaiado (não dá para seguir). */
export const teamDown = (run) => run.team.every((m) => !((m.hp ?? 1) > 0))

/** Sai da loja (ou não tinha): o próximo andar. */
export function nextFloor(run, data) {
  const out = { ...run, pending: null }
  out.encounter = encounterOf(out, data, dice(out))
  return out
}

/** Perdeu: a corrida acaba; a pontuação vira moedas e o recorde fica salvo. */
export function endRun(factory, run) {
  const coins = runCoins(run)
  return { ...factory, coins: factory.coins + coins, best: Math.max(factory.best, run.floor - 1), run: null, last: { floor: run.floor - 1, coins } }
}

// ------------------------------------------------------------ para a batalha

/**
 * Nível mínimo para um golpe pelo poder: os evoluídos aprendem muita coisa
 * forte "no nível 1" (Explosion, Heavy Slam...), o que num nível baixo seria
 * covardia; assim um golpe de 90 de poder só vem a partir do nível 30.
 */
export const movePowerLevel = (power) => Math.max(0, Math.floor((power - 40) * 0.6))
/** Golpes que dobram de força a cada turno contam como mais fortes. */
const ESCALATING = { rollout: 80, 'ice-ball': 80 }

/** Golpes que ele sabe no nível (os aprendidos por nível até ali), os melhores 4. */
export function movesAt(formMoves, level, types, moves) {
  const learned = []
  for (const [slug, how] of [...formMoves].filter((m) => m[1] === 'level-up' && m[2] <= level).sort((a, b) => a[2] - b[2])) {
    if (!learned.includes(slug) && moves[slug] && how && level >= movePowerLevel(ESCALATING[slug] ?? moves[slug].power ?? 0)) learned.push(slug)
  }
  const power = (s) => (moves[s].category !== 'status' && moves[s].power > 0 ? moves[s].power * (types.includes(moves[s].type) ? 1.5 : 1) * ((moves[s].accuracy ?? 100) / 100) : 0)
  const damaging = learned.filter((s) => power(s) > 0).sort((a, b) => power(b) - power(a))
  const chosen = []
  for (const s of damaging) if (chosen.length < 3 && !chosen.some((c) => moves[c].type === moves[s].type)) chosen.push(s)
  for (const s of damaging) if (chosen.length < 3 && !chosen.includes(s)) chosen.push(s)
  for (const s of [...learned].reverse()) if (chosen.length < 4 && !chosen.includes(s)) chosen.push(s)
  return chosen.length ? chosen : ['tackle']
}

/** A Bolsa de cada lado: a sua é a da corrida; selvagem não tem itens; treinador e chefe têm mais nos andares altos. */
export function bagsFor(run) {
  const floor = run.floor
  const kind = run.encounter?.kind
  const none = { potion: 0, 'super-potion': 0, 'hyper-potion': 0, 'max-potion': 0, revive: 0 }
  const foe = kind === 'boss'
    ? { ...none, 'hyper-potion': 1 + Math.floor(floor / 40), 'max-potion': floor >= 60 ? 1 : 0, revive: floor >= 100 ? 1 : 0 }
    : kind === 'trainer'
      ? { ...none, potion: Math.min(3, 1 + Math.floor(floor / 15)), 'super-potion': floor >= 20 ? 1 : 0, 'hyper-potion': floor >= 40 ? 1 : 0 }
      : none
  return [{ ...none, ...run.bag }, foe]
}

/** A ordem na batalha: quem está de pé primeiro (o primeiro entra em campo). Posições no time da corrida. */
export const battleOrder = (run) => [...run.team.keys()].sort((a, b) => Number((run.team[b].hp ?? 1) > 0) - Number((run.team[a].hp ?? 1) > 0))

/**
 * Sem limite de IVs e EVs: o motor aceita até 31 e 252; o que passa disso vira
 * pontos no atributo pela conta dos jogos (IV + EV/4) × nível / 100.
 */
export function overflowPoints(ivs, evs, level) {
  return Object.fromEntries(STATS.map((s) => [s, Math.floor(((Math.max(0, (ivs?.[s] ?? 0) - 31) + Math.max(0, (evs?.[s] ?? 0) - 252) / 4) * level) / 100)]))
}
const capStats = (stats, max) => Object.fromEntries(STATS.map((s) => [s, Math.min(max, Math.max(0, Math.floor(stats?.[s] ?? 0)))]))

const shinyBoost = () => Object.fromEntries(STATS.map((s) => [s, SHINY_BOOST]))

/** A porcentagem a mais nos atributos: os itens extras, as cartas do time e o shiny. */
export function boostOf(run, mon) {
  let out = { ...zero(), ...(run.teamBoost ?? {}) }
  if (mon.shiny) out = addStats(out, shinyBoost())
  for (const id of mon.extras ?? []) out = addStats(out, HELD_BOOST[id])
  return Object.fromEntries(STATS.map((s) => [s, round3(out[s])]))
}

/** O Pokémon da corrida como membro de time (battleSetup.battleMons). */
export function memberOf(run, mon, moveList) {
  return {
    id: mon.id,
    set: {
      level: mon.level, levelCap: 'none', nature: mon.nature, ivs: capStats(mon.ivs, 31), evs: capStats(mon.evs, 252), item: mon.item ?? '',
      moves: moveList, lockMoves: true, shiny: Boolean(mon.shiny),
      bonus: overflowPoints(mon.ivs, mon.evs, mon.level), boost: boostOf(run, mon), hpRatio: mon.hp ?? 1,
    },
  }
}

/** Um adversário do andar como membro de time. */
export function foeMember(foe, moveList) {
  const ivs = Object.fromEntries(STATS.map((s) => [s, foe.iv])), evs = Object.fromEntries(STATS.map((s) => [s, foe.ev ?? 0]))
  return {
    id: foe.id,
    set: {
      level: foe.level, levelCap: 'none', ivs: capStats(ivs, 31), evs: capStats(evs, 252), moves: moveList, lockMoves: true, bonus: overflowPoints(ivs, evs, foe.level),
      ...(foe.boost || foe.shiny ? { boost: Object.fromEntries(STATS.map((s) => [s, round3((foe.boost ?? 0) + (foe.shiny ? SHINY_BOOST : 0))])) } : {}),
      ...(foe.shiny ? { shiny: true } : {}),
    },
  }
}
