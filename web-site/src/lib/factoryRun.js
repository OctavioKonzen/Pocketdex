// Battle Factory, um roguelike: na primeira vez você escolhe um inicial
// grátis (de qualquer geração); os outros se compram com moedas. Ele começa no
// nível 5 e vai subindo andares (sem fim), seguindo a história de uma região
// (tool/factory_stories.py) pelo mapa: de cidade em cidade (cada chefe fica
// numa cidade), cada andar é um ponto da rota, escolhido entre 2 ou 3 caminhos
// (routeOptions): Pokémon selvagem do bioma da rota (captura na batalha,
// jogando a bola antes de ele desmaiar; cada bola tem a sua chance), treinador,
// treinador forte (mais Pokémon, sempre deixa um item), Poké Mart, Centro
// Pokémon (raro: cura o time) ou um evento;
// a cada 10 andares vem um chefe da história (os líderes de ginásio com o rival
// e os vilões no meio, a Elite Four e o Campeão de um jogo sorteado; os times
// deles crescem conforme a corrida sobe); nos andares 5, 15, 25... pode vir um
// chefe sem treinador (uma Mega, um Gigantamax ou um lendário: lendários só
// aparecem assim). Acabou a história, começa a de outra região.
// O time NÃO é curado entre os andares: o HP e quem desmaiou continuam (Bolsa,
// loja, Centro Pokémon e, com 5% de chance, a Enfermeira Joy). Cada Pokémon
// derrotado dá XP e EVs (só para quem está de pé) e dinheiro para a loja, que
// aparece ao chegar na cidade (logo antes do chefe) e nos Poké Marts: além
// dos itens, TMs, Move Tutor, Move Reminder, pedras de evolução, Dynamax Band
// e Tera Orb. Chefes deixam Cristais Z e as Megas deixam a Mega Pedra.
// Depois de cada chefe, uma carta de bônus. Sem limite de nível, IVs, EVs ou
// itens: um item é o segurado (efeito de verdade) e os outros dão uma versão
// bem mais fraca do bônus (porcentagem no atributo certo).
// Shiny: 1 em 4096 (nos selvagens e ao comprar um Pokémon), +10% nos
// atributos; capturar um inicial shiny libera o shiny dele, que também se
// compra com moedas, bem caro.
// Perdeu: a corrida acaba e a pontuação vira moedas, que compram Pokémon para
// começar as próximas corridas (os mais fortes custam mais).
//
// A dificuldade (andar f; simulação em tool/factory_balance.mjs):
//   nível dos adversários  2 + 0,8·(f−1) (+0 a 1), sem teto
//   EVs dos adversários    3·f por atributo; IVs 31 a partir do andar 62 e
//                          +1 a cada 10 andares depois do 100 (sem limite)
//   depois do andar 30     +3% em todos os atributos a cada 10 andares (as
//                          cartas dão ~1,5%: lá em cima a corrida sempre acaba)
//   XP                     quem está abaixo do nível do adversário ganha bem
//                          mais e quem está acima bem menos (expFor), então o
//                          time acompanha os andares sem disparar
//   dinheiro e preços      os dois crescem com o andar (priceScale); mais
//                          dinheiro nos 10 primeiros andares (earlyMoney)
// Dados: assets/database/factory.json (tool/build_factory_data.py). Igual ao
// app (lib/services/factory_run.dart).

export const STATS = ['hp', 'atk', 'def', 'spa', 'spd', 'spe']
export const NATURE_LIST = ['Hardy', 'Lonely', 'Brave', 'Adamant', 'Naughty', 'Bold', 'Docile', 'Relaxed', 'Impish', 'Lax', 'Timid', 'Hasty', 'Serious',
  'Jolly', 'Naive', 'Modest', 'Mild', 'Quiet', 'Bashful', 'Rash', 'Calm', 'Gentle', 'Sassy', 'Careful', 'Quirky']
export const MAX_TEAM = 6
export const START_LEVEL = 5
export const START_BALLS = 5
/** As Poké Balls (a chance de cada uma está no motor de batalha: BALLS em tool/battle-engine/engine.mjs). */
export const BALL_IDS = ['poke-ball', 'great-ball', 'ultra-ball', 'quick-ball', 'net-ball', 'dusk-ball', 'timer-ball', 'master-ball']
/** A Bolsa do começo da corrida (os itens gastos na batalha não voltam). */
export const START_BAG = { 'poke-ball': START_BALLS, potion: 4, 'super-potion': 1, 'hyper-potion': 0, 'max-potion': 0, revive: 1 }
/** Quanto cada item da Bolsa cura (parte do HP máximo; igual na batalha: healPct do motor). */
export const HEAL_SHARE = { potion: 0.25, 'super-potion': 0.5, 'hyper-potion': 0.75, 'max-potion': 1 }
export const JOY_CHANCE = 0.05
/** Shiny: 1 em 4096 (como nos jogos); shiny tem +10% em todos os atributos. */
export const SHINY_CHANCE = 1 / 4096
export const SHINY_BOOST = 0.1
export const BOSS_EVERY = 10
/** Nos andares 5, 15, 25...: chance de um chefe sem treinador (Mega, Gigantamax ou lendário). */
export const WILD_BOSS_CHANCE = 0.4

const zero = () => Object.fromEntries(STATS.map((s) => [s, 0]))
const addStats = (a, b) => Object.fromEntries(STATS.map((s) => [s, (a?.[s] ?? 0) + (b?.[s] ?? 0)]))
const round3 = (n) => Math.round(n * 1000) / 1000
// Potências com multiplicação e raiz (dão o mesmo resultado no app, em Dart).
const pow15 = (x) => x * Math.sqrt(x)
const pow8 = (x) => { const x2 = x * x, x4 = x2 * x2; return x4 * x4 }

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
/** Um da lista, com a chance de cada um proporcional ao peso. */
function pickWeighted(list, weights, rand) {
  let roll = rand() * weights.reduce((a, b) => a + b, 0)
  for (let i = 0; i < list.length; i++) {
    roll -= weights[i]
    if (roll < 0) return list[i]
  }
  return list[list.length - 1]
}

// ------------------------------------------------------------ dificuldade

/** Nível base dos adversários no andar (sem teto). */
export const foeLevelAt = (floor) => 2 + Math.floor((floor - 1) * 0.8)
/** EVs (por atributo) dos adversários: sobem sem limite. */
export const foeEvsAt = (floor) => 3 * floor
/** IVs dos adversários: chegam a 31 e, depois do andar 100, passam do limite. */
export const foeIvsAt = (floor) => Math.min(31, Math.floor(floor / 2)) + Math.max(0, Math.floor((floor - 100) / 10))
/** Porcentagem a mais em todos os atributos dos adversários depois do andar 30 (um pouco mais que as cartas: um dia a corrida acaba). */
export const foeBoostAt = (floor) => Math.round(Math.max(0, floor - 30) * 0.003 * 1000) / 1000
/**
 * Preço da loja no andar: cresce junto com o dinheiro que os adversários dão
 * (o nível sobe e os treinadores ganham 1 Pokémon a cada 12 andares, até 6):
 * cada visita à loja compra mais ou menos a mesma coisa do começo ao fim.
 */
export const priceScale = (floor) => (1 + (floor - 1) / 20) * (1 + 0.4 * Math.min(5, Math.floor(floor / 12)))
/** Nos 10 primeiros andares, mais dinheiro (até o dobro no 1º) para preparar o time para o primeiro chefe. */
export const earlyMoney = (floor) => 1 + Math.max(0, 11 - floor) / 10

// ------------------------------------------------------------ itens e cartas

/** Itens de segurar: o principal tem o efeito de verdade; cada um a mais dá esta porcentagem (bem mais fraca). */
export const HELD_BOOST = {
  'choice-band': { atk: 0.05 }, 'choice-specs': { spa: 0.05 }, 'choice-scarf': { spe: 0.05 },
  'life-orb': { atk: 0.03, spa: 0.03 }, 'expert-belt': { atk: 0.02, spa: 0.02 }, 'muscle-band': { atk: 0.02 }, 'wise-glasses': { spa: 0.02 },
  leftovers: { hp: 0.04 }, 'sitrus-berry': { hp: 0.03 }, 'assault-vest': { spd: 0.05 }, 'rocky-helmet': { def: 0.04 },
  eviolite: { def: 0.04, spd: 0.04 }, 'focus-sash': { hp: 0.02, def: 0.01, spd: 0.01 }, 'quick-claw': { spe: 0.03 },
  'shell-bell': { hp: 0.02 }, 'black-sludge': { hp: 0.03 }, 'weakness-policy': { atk: 0.02, spa: 0.02 }, 'lum-berry': { hp: 0.02 },
  'scope-lens': { atk: 0.02, spa: 0.02 }, 'bright-powder': { spe: 0.02 }, 'air-balloon': { spe: 0.02 }, 'heavy-duty-boots': { def: 0.01, spd: 0.01 },
  'kings-rock': { atk: 0.02 },
  // Lucky Egg: sem atributo; quem segura ganha mais XP (LUCKY_EGG).
  'lucky-egg': {},
}
/** Os itens que os chefes e o treinador forte seguram (efeito de verdade na batalha). */
export const FOE_ITEMS = ['leftovers', 'sitrus-berry', 'life-orb', 'choice-band', 'choice-specs', 'choice-scarf', 'focus-sash', 'assault-vest', 'rocky-helmet', 'expert-belt', 'lum-berry', 'weakness-policy', 'scope-lens', 'air-balloon']
/** Lucky Egg: XP a mais para quem segura (como extra, menos). */
export const LUCKY_EGG = { held: 1.5, extra: 1.2 }
const eggOf = (m) => (m.item === 'lucky-egg' ? LUCKY_EGG.held : (m.extras ?? []).includes('lucky-egg') ? LUCKY_EGG.extra : 1)
/** Vitaminas: EVs sem limite. Bottle Cap: IVs sem limite (em todos). */
export const VITAMINS = { 'hp-up': 'hp', protein: 'atk', iron: 'def', calcium: 'spa', zinc: 'spd', carbos: 'spe' }
export const VITAMIN_EVS = 24
export const BOTTLE_CAP_IVS = 3
/** Preço no 1º andar (priceScale aumenta com o andar). */
export const SHOP = {
  'poke-ball': 50, 'great-ball': 120, 'ultra-ball': 250, 'quick-ball': 200, 'net-ball': 150, 'dusk-ball': 150, 'timer-ball': 150,
  // Rara na loja (3%): sempre captura.
  'master-ball': 5000,
  potion: 40, 'super-potion': 90, 'hyper-potion': 160, 'max-potion': 300, revive: 180,
  'rare-candy': 120,
  ...Object.fromEntries(Object.keys(VITAMINS).map((k) => [k, 90])),
  'bottle-cap': 200,
  ...Object.fromEntries(Object.keys(HELD_BOOST).map((k) => [k, 250])),
  // Serviços e chaves das mecânicas.
  'move-tutor': 300, 'move-reminder': 150, 'dynamax-band': 2500, 'tera-orb': 2500,
  'escape-rope': 450,
  // Exp. Share: o time todo ganha XP (quem não lutou, a metade).
  'exp-share': 800,
}
/** Preço base de um TM ("tm:<golpe>") e de uma pedra de evolução ("evo:<item>"). */
export const TM_PRICE = 220
export const EVO_PRICE = 400
/** Fichas de serviço (gastas ao ensinar um golpe). */
export const TOKENS = ['move-tutor', 'move-reminder']
/** Itens que vão para a Bolsa (não precisam de um Pokémon). */
/** Escape Rope: se perder uma batalha, o time foge com pouco HP (ESCAPE_HP) em vez de a corrida acabar. */
export const ESCAPE_HP = 0.1
export const BAG_ITEMS = [...BALL_IDS, ...Object.keys(START_BAG).filter((k) => !BALL_IDS.includes(k)), 'escape-rope']

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

export const emptyFactory = () => ({ best: 0, coins: 0, owned: [], shinies: [], upgrades: {}, run: null })
/** Na primeira vez escolhe um inicial grátis; depois só os que tem (os outros se compram). */
export const freePick = (factory) => !(factory.owned?.length)
export function factoryOf(league) {
  const out = { ...emptyFactory(), ...(league?.factory ?? {}) }
  // Corridas antigas: as Poké Balls ficavam fora da Bolsa (run.balls).
  if (out.run && out.run.balls != null) {
    const { balls, ...run } = out.run
    out.run = { ...run, bag: { ...run.bag, 'poke-ball': (run.bag?.['poke-ball'] ?? 0) + balls } }
  }
  return out
}

/** Preço de um Pokémon (em moedas) pela força: total de atributos. */
export const pokemonPrice = (bst) => Math.max(20, Math.round(pow15(Math.max(0, bst - 250)) / 10 / 5) * 5)

/** Com quem dá para começar: na primeira vez, qualquer inicial (grátis); depois, os que você tem. */
export const startersOf = (factory, data) => (freePick(factory) ? [...data.starters] : [...factory.owned])

/** Escolhe o inicial grátis (só na primeira vez). */
export function claimStarter(factory, data, id) {
  if (!freePick(factory) || !data.starters.includes(id)) return factory
  return { ...factory, owned: [id] }
}

/** A primeira forma da linha evolutiva (Charizard → Charmander, Pikachu → Pichu). */
export function baseForm(data, id) {
  let out = id
  for (let guard = 0; guard < 4; guard++) {
    const pre = preEvolutions(data).get(out)
    if (!pre) break
    out = pre[0]
  }
  return out
}

/** Só a primeira forma está à venda: a evolução vem jogando. */
export const forSale = (data, id) => Boolean(data.species[id]) && baseForm(data, id) === id

/**
 * Contas antigas (que compraram uma forma evoluída): ficam com a primeira
 * forma dela, sem repetir (o shiny também). Devolve a mesma Factory se não mudou nada.
 */
export function normalizeOwned(factory, data) {
  const fix = (list) => [...new Set((list ?? []).map((id) => baseForm(data, id)))]
  const owned = fix(factory.owned)
  const shinies = fix(factory.shinies)
  const same = (a, b) => a.length === (b ?? []).length && a.every((x, i) => x === b[i])
  if (same(owned, factory.owned) && same(shinies, factory.shinies)) return factory
  // Devolve as moedas: a diferença para a primeira forma (ou tudo, se a primeira forma já era dele).
  const price = (id) => pokemonPrice(data.species[id]?.[1] ?? 0)
  let refund = 0
  const kept = []
  for (const id of factory.owned ?? []) {
    const base = baseForm(data, id)
    if (id === base) { kept.push(id); continue }
    refund += kept.includes(base) || (factory.owned ?? []).includes(base) ? price(id) : price(id) - price(base)
    kept.push(base)
  }
  return { ...factory, owned, shinies, coins: (factory.coins ?? 0) + Math.max(0, refund), refunded: Math.max(0, refund) }
}

/** Compra um Pokémon com as moedas (null se não dá). roll (0 a 1): 1 em 4096 de vir shiny. */
export function buyPokemon(factory, data, id, roll = 1) {
  const info = data.species[id]
  if (!info || !forSale(data, id) || factory.owned.includes(id) || freePick(factory)) return null
  const price = pokemonPrice(info[1])
  if (factory.coins < price) return null
  const shinies = factory.shinies ?? []
  return { ...factory, coins: factory.coins - price, owned: [...factory.owned, id], shinies: roll < SHINY_CHANCE && !shinies.includes(id) ? [...shinies, id] : shinies }
}

/** Preço para transformar um inicial em shiny (bem caro). */
export const shinyPrice = (bst) => Math.max(3000, pokemonPrice(bst) * 20)

/** Transforma um inicial (grátis ou comprado) em shiny com as moedas (null se não dá). */
export function buyShiny(factory, data, id) {
  const info = data.species[id]
  const shinies = factory.shinies ?? []
  if (!info || shinies.includes(id) || !factory.owned.includes(id)) return null
  const price = shinyPrice(info[1])
  if (factory.coins < price) return null
  return { ...factory, coins: factory.coins - price, shinies: [...shinies, id] }
}

/** Capturou um shiny: se é um dos iniciais dele, libera o shiny para começar. */
export function unlockShiny(factory, data, mon) {
  const shinies = factory.shinies ?? []
  if (!mon?.shiny || shinies.includes(mon.id) || !(data.starters.includes(mon.id) || factory.owned.includes(mon.id))) return factory
  return { ...factory, shinies: [...shinies, mon.id] }
}

/**
 * Melhorias permanentes (compradas com moedas antes da corrida, valem em todas
 * as próximas). Cada nível custa mais (upgradePrice): dá para ficar mais forte
 * aos poucos, sem deixar o começo fácil.
 */
export const UPGRADES = {
  level: { label: 'Treino: o inicial começa {0} nível acima', per: 1, max: 5, base: 150 },
  ivs: { label: 'Genética: IVs mínimos do inicial +{0}', per: 3, max: 5, base: 120 },
  balls: { label: 'Começa com +{0} Poké Ball', per: 1, max: 5, base: 60 },
  potions: { label: 'Começa com +{0} Potion', per: 1, max: 5, base: 60 },
  revive: { label: 'Começa com +{0} Revive', per: 1, max: 3, base: 200 },
  money: { label: 'Começa com +{0} de dinheiro', per: 100, max: 5, base: 100 },
  shop: { label: 'Loja {0}% mais barata', per: 4, max: 5, base: 250 },
  exp: { label: '+{0}% de XP', per: 5, max: 5, base: 250 },
  // As que mudam o jeito de jogar.
  expShare: { label: 'Começa com o Exp. Share', per: 1, max: 1, base: 1200 },
  cards: { label: 'Uma carta a mais para escolher depois de cada chefe', per: 1, max: 1, base: 2000 },
  reroll: { label: '{0}× por corrida: sortear o caminho de novo', per: 1, max: 2, base: 700 },
  shiny: { label: 'Shiny {0}× mais comum', per: 1, max: 3, base: 900, offset: 1 },
}
export const upgradeLevel = (factory, id) => factory.upgrades?.[id] ?? 0
/** O bônus da melhoria no nível dela (nível × por nível). */
export const upgradeValue = (factory, id) => upgradeLevel(factory, id) * UPGRADES[id].per
/** Preço do próximo nível (null no máximo). */
export function upgradePrice(factory, id) {
  const level = upgradeLevel(factory, id)
  const up = UPGRADES[id]
  return !up || level >= up.max ? null : Math.round((up.base * (level + 1) ** 1.6) / 5) * 5
}
/** Compra o próximo nível da melhoria (null se não dá). */
export function buyUpgrade(factory, id) {
  const price = upgradePrice(factory, id)
  if (price == null || factory.coins < price) return null
  return { ...factory, coins: factory.coins - price, upgrades: { ...factory.upgrades, [id]: upgradeLevel(factory, id) + 1 } }
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
    // Evoluções por item (pedras) só com o item: canEvolveWith/buyItem.
    const options = (data.evolutions[out.id] ?? []).filter(([, at, item]) => !item && out.level >= at)
    if (!options.length) break
    const [to] = pickOne(options, rand)
    out = { ...out, id: to }
    evolved = to
  }
  return [out, evolved]
}

/**
 * XP de derrotar um adversário. No mesmo nível, um adversário comum (XP base
 * 100) dá ~1 nível. Quem está abaixo dele ganha mais (até 30×: quem acabou de
 * ser capturado alcança o time rápido) e quem está acima, menos
 * ((2F+10)/(F+L+10))^8: 5 níveis acima de um nível 7, ainda ~1/3. Só quem
 * lutou contra ele ganha (ou o time todo, metade, com o Exp. Share).
 */
export function expFor(baseExp, foeLevel, level, factor = 1) {
  const scale = Math.min(30, pow8((2 * foeLevel + 10) / (foeLevel + level + 10)))
  const species = Math.min(1.6, Math.max(0.6, Math.sqrt(baseExp / 100)))
  return Math.floor(6 * foeLevel * foeLevel * species * scale * factor) + 1
}

/** Exp. Share: quem não lutou ganha essa parte do XP (e os EVs). */
export const EXP_SHARE = 0.5

/** O XP de um derrotado para cada um do time (posição na corrida): fought = quem lutou contra ele; sem fought, todos de pé. */
export function expShares(run, data, foe, fought, factor = 1) {
  const base = speciesOf(data, foe.id)?.[0] ?? 60
  return run.team.map((m, i) => {
    if (!(m.hp > 0)) return 0
    const share = !fought || fought.includes(i) ? 1 : run.expShare ? EXP_SHARE : 0
    return share ? Math.floor(expFor(base, foe.level, m.level, factor * run.mult.exp) * share * eggOf(m)) : 0
  })
}

/** O fator de XP do tipo de andar (treinadores e chefes dão mais). */
export const expFactor = (kind) => (kind === 'ace' ? 1.75 : kind === 'boss' || kind === 'wildboss' || kind === 'trainer' ? 1.5 : 1)

/** A barra de XP: quanto do nível atual já foi (0 a 1), com o XP a mais (extra). */
export function expProgress(mon, extra = 0) {
  const from = expAt(mon.level), to = expAt(mon.level + 1)
  return Math.max(0, Math.min(1, ((mon.exp ?? from) + extra - from) / (to - from)))
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
 * que o personagem usa no jogo (pool), até 6: ninguém fica com 1 só (a não
 * ser nos primeiros andares).
 */
export function bossTeam(boss, floor) {
  const team = [...boss.team]
  const want = Math.min(MAX_TEAM, Math.max(team.length, 2 + Math.floor(floor / 25)))
  const pool = boss.pool?.length ? boss.pool : boss.team
  const extra = pool.filter((id) => !team.includes(id))
  for (let i = 0; team.length < want && pool.length; i++) team.push(i < extra.length ? extra[i] : pool[(i - extra.length) % pool.length])
  // Antes do andar 10 (o rival e os vilões já aparecem na rota), times pequenos, como no começo dos jogos: fica o mais forte.
  const cap = floor < 10 ? 1 + Math.floor(floor / 4) : MAX_TEAM
  return team.length > cap ? team.slice(team.length - cap) : team
}

/** Força (total de atributos) das espécies do andar: mais fortes conforme sobe (depois do andar 60, qualquer uma). */
export const speciesBudget = (floor) => 290 + floor * 7

/** Nível de quem evolui por item (pedra), sem nível no jogo: a partir dele já aparece evoluído. */
export const ITEM_EVOLUTION_LEVEL = 20
const preCache = new WeakMap()
/** De quem cada espécie evolui: espécie → [pré-evolução, nível (0: por item)]. A primeira que aparecer. */
function preEvolutions(data) {
  let out = preCache.get(data)
  if (!out) {
    out = new Map()
    for (const [from, list] of Object.entries(data.evolutions)) for (const [to, level] of list) if (!out.has(to)) out.set(to, [Number(from), level])
    preCache.set(data, out)
  }
  return out
}
/** O nível mínimo em que a espécie (ou forma) aparece: o nível de cada evolução até ela (por item: ITEM_EVOLUTION_LEVEL). */
export function minLevelOf(data, id) {
  const pre = preEvolutions(data).get(data.forms?.[id] ?? id)
  if (!pre) return 1
  return Math.max(pre[1] || ITEM_EVOLUTION_LEVEL, minLevelOf(data, pre[0]))
}
/** Abaixo do nível em que evolui, volta para a forma anterior (um Sceptile nível 2 é um Treecko), como nos jogos. */
export function devolve(data, id, level) {
  let out = id
  for (let guard = 0; guard < 4 && minLevelOf(data, out) > level; guard++) {
    const pre = preEvolutions(data).get(data.forms?.[out] ?? out)
    if (!pre) break
    out = pre[0]
  }
  return out
}

/** Nível de um chefe: quem é mais forte que as espécies do andar vem com nível menor. */
const bossLevel = (data, floor, id, lvl) => Math.max(2, Math.round(lvl * pow15(Math.min(1, speciesBudget(floor) / (speciesOf(data, id)?.[1] ?? 400)))))

// ------------------------------------------------------------ mapa

/**
 * Os lugares das rotas (cada um é também o cenário da batalha) e os tipos que
 * mais aparecem neles: numa rota de floresta aparece bem mais Inseto e Grama
 * (ROUTE_TYPE_WEIGHT), mas os outros ainda aparecem.
 */
export const BIOMES = {
  grass: ['normal', 'grass', 'bug', 'flying'],
  forest: ['bug', 'grass', 'poison', 'fairy'],
  water: ['water', 'flying'],
  beach: ['water', 'ground', 'flying', 'rock'],
  underwater: ['water'],
  swamp: ['poison', 'water', 'grass', 'bug'],
  sewer: ['poison', 'dark', 'electric', 'normal'],
  cave: ['rock', 'ground', 'dark', 'poison'],
  icecave: ['ice', 'rock', 'water'],
  mountain: ['rock', 'fighting', 'ground', 'steel', 'dragon'],
  desert: ['ground', 'rock', 'fire', 'bug'],
  volcano: ['fire', 'rock', 'ground'],
  city: ['electric', 'steel', 'psychic', 'normal'],
  snow: ['ice', 'water'],
  tower: ['ghost', 'psychic', 'dark'],
  sky: ['flying', 'dragon', 'fairy'],
}
export const BIOME_IDS = Object.keys(BIOMES)
/** Quanto a mais aparecem os tipos do lugar (selvagens; nos treinadores, ROUTE_TYPE_TRAINER). */
export const ROUTE_TYPE_WEIGHT = 8
export const ROUTE_TYPE_TRAINER = 3
/** Os lugares possíveis da rota até o ginásio de cada tipo (um deles por rota). */
const TYPE_BIOMES = {
  normal: ['grass', 'city'], fire: ['volcano', 'desert'], water: ['water', 'beach', 'underwater'], grass: ['forest', 'grass', 'swamp'],
  electric: ['city', 'sewer'], ice: ['snow', 'icecave'], fighting: ['mountain', 'cave'], poison: ['swamp', 'sewer', 'forest'],
  ground: ['desert', 'mountain', 'cave'], flying: ['sky', 'grass', 'beach'], psychic: ['tower', 'city'], bug: ['forest', 'grass'],
  rock: ['cave', 'mountain', 'desert'], ghost: ['tower'], dragon: ['sky', 'mountain'], dark: ['cave', 'tower', 'sewer'],
  steel: ['mountain', 'city', 'cave'], fairy: ['sky', 'forest'],
}
/** Na Dusk Ball (3×): os lugares escuros. */
export const DARK_BIOMES = ['cave', 'tower', 'icecave', 'sewer', 'underwater']

/** Os chefes de cidade (líder no ginásio dele; Elite Four e Campeão na Liga). Rival e vilões aparecem na rota. */
const CITY_KINDS = ['gym', 'elite', 'champion']
/** Andares de rota antes de cada cidade (o 10º é o chefe dela). */
export const ROUTE_LENGTH = 9
/** Onde a rota se divide (posição na rota, a partir de 0): só ali dá para escolher o caminho. */
export const FORKS = [1, 4, 7]
/** Chance do rival (ou de um vilão) aparecer em cada andar da rota (a partir do 3º: dá tempo de treinar um pouco). */
export const AMBUSH_CHANCE = 0.3

/** O próximo chefe de cidade (pula rival e vilões): o destino da rota. */
export function targetOf(data, run) {
  const leaders = data.bosses[run.boss.region].leaders
  let step = run.boss.step
  while (step < leaders.length - 1 && !CITY_KINDS.includes(leaders[step].kind)) step++
  return { step, ...leaders[step] }
}

/** Já está na Liga: depois da primeira da Elite Four, as lutas vêm uma atrás da outra (sem rota). */
const inLeague = (data, run) => {
  const leaders = data.bosses[run.boss.region].leaders
  const prev = leaders[run.boss.step - 1]
  return run.boss.step > 0 && ['elite', 'champion'].includes(leaders[run.boss.step].kind) && prev?.kind === 'elite'
}

/** Onde está na rota: 0 é o primeiro andar depois da última cidade (run.leg); ROUTE_LENGTH é a cidade. */
export const routePos = (run) => run.floor - (run.leg ?? run.floor - ((run.floor - 1) % 10))

/** Chegou na cidade (ou na Liga): o chefe dela é o próximo andar. */
export function atCity(data, run) {
  return CITY_KINDS.includes(bossOf(data, run).kind) && (inLeague(data, run) || routePos(run) >= ROUTE_LENGTH)
}

/**
 * O bioma da rota até a próxima cidade: o do tipo do ginásio (o tipo que mais
 * aparece no time do líder); para a Liga, um fixo da região.
 */
export function routeBiome(data, run) {
  const boss = targetOf(data, run)
  if (boss.kind === 'gym') {
    const count = {}
    for (const id of boss.team) for (const t of speciesOf(data, id)?.[4] ?? []) count[t] = (count[t] ?? 0) + 1
    const top = Object.keys(count).sort((a, b) => count[b] - count[a])[0]
    // Um dos lugares do tipo, o mesmo na rota inteira (pela semente e o começo da rota).
    const list = TYPE_BIOMES[top]
    if (list) return list[((Math.imul(run.leg ?? 1, 2654435761 | 0) ^ run.seed) >>> 0) % list.length]
  }
  return BIOME_IDS[(run.boss.region * 7 + boss.step * 3) % BIOME_IDS.length]
}

/** Os pontos do mapa (o peso de cada um nas bifurcações). O Centro Pokémon é raro. */
export const NODE_WEIGHTS = [['wild', 34], ['trainer', 28], ['ace', 12], ['mart', 10], ['event', 11], ['center', 5], ['trade', 8]]
const BATTLE_NODES = ['wild', 'trainer', 'ace', 'boss', 'wildboss']
export const isBattleNode = (node) => BATTLE_NODES.includes(node?.kind)

/**
 * O que tem no andar. Na cidade, o líder dela (na Liga, a Elite Four e o
 * Campeão um atrás do outro). Na rota, o rival e os vilões podem aparecer em
 * qualquer andar (sempre antes de chegar na cidade). Fora isso, o caminho
 * segue (um ponto só: selvagem, treinador ou um evento) e só nas bifurcações
 * (FORKS) dá para escolher entre 2 ou 3 caminhos, sempre com uma batalha; na
 * do meio, às vezes um chefe sem treinador. No começo da corrida, só batalhas comuns.
 */
export function routeOptions(run, data, rand) {
  const biome = routeBiome(data, run)
  const pos = routePos(run)
  const boss = bossOf(data, run)
  if (atCity(data, run)) return { floor: run.floor, biome, options: [{ kind: 'boss' }] }
  if (!CITY_KINDS.includes(boss.kind)) {
    // Rival e vilões: quantos ainda faltam antes da cidade e quantos andares de rota sobram.
    const leaders = data.bosses[run.boss.region].leaders
    let pending = 0
    while (run.boss.step + pending < leaders.length && !CITY_KINDS.includes(leaders[run.boss.step + pending].kind)) pending++
    if (ROUTE_LENGTH - pos <= pending || (pos >= 2 && rand() < AMBUSH_CHANCE)) return { floor: run.floor, biome, options: [{ kind: 'boss' }] }
  }
  // Os selvagens são do lugar da rota (o cenário da batalha é ele).
  const wildBiome = () => biome
  if (!FORKS.includes(pos)) {
    const r = rand()
    return { floor: run.floor, biome, options: [r < 0.55 ? { kind: 'wild', biome: wildBiome() } : r < 0.9 || run.floor <= 2 ? { kind: 'trainer' } : { kind: 'event' }] }
  }
  const options = [rand() < 0.55 ? { kind: 'wild', biome: wildBiome() } : { kind: 'trainer' }]
  const count = run.floor <= 2 ? 2 : 3
  const allowed = NODE_WEIGHTS.filter(([kind]) => run.floor > 2 || kind === 'wild' || kind === 'trainer')
  const total = allowed.reduce((sum, [, w]) => sum + w, 0)
  for (let guard = 0; options.length < count && guard < 20; guard++) {
    let roll = rand() * total
    const [kind] = allowed.find(([, w]) => (roll -= w) < 0) ?? allowed[0]
    const node = kind === 'wild' ? { kind, biome: wildBiome() } : { kind }
    if (options.some((o) => o.kind === node.kind && o.biome === node.biome)) continue
    options.push(node)
  }
  if (pos === FORKS[1] && rand() < WILD_BOSS_CHANCE) options[options.length - 1] = { kind: 'wildboss' }
  return { floor: run.floor, biome, options }
}

/** A cidade da rota (o destino) e a de onde ela começa (null no começo de uma região). Na Liga, as duas são a Liga. */
export function routeCities(data, run) {
  const leaders = data.bosses[run.boss.region].leaders
  const to = targetOf(data, run).city ?? ''
  if (inLeague(data, run)) return { from: to, to }
  let k = run.boss.step - 1
  while (k >= 0 && !CITY_KINDS.includes(leaders[k].kind)) k--
  return { from: k >= 0 ? leaders[k].city ?? null : null, to }
}

/** O que o treinador forte deixa (sempre): bolas e remédios vão para a Bolsa, os itens de segurar ficam guardados. */
export const ACE_REWARDS = ['great-ball', 'ultra-ball', 'hyper-potion', 'max-potion', 'revive', 'move-tutor', 'escape-rope', ...Object.keys(HELD_BOOST)]
/** Os eventos do mapa. */
export const EVENTS = ['items', 'money', 'berries', 'tutor']

/**
 * Escolhe o caminho: batalha (o encontro do andar) ou, sem batalha, o Poké
 * Mart (loja maior), o Centro Pokémon (cura todo mundo, até quem desmaiou) e
 * os eventos (itens, dinheiro, frutas que curam um pouco, ficha de Move Tutor).
 * Os sem batalha também contam como um andar (sem XP nem dinheiro).
 */
export function chooseNode(run, data, index) {
  const node = run.route?.options?.[index]
  if (!node || run.encounter || run.pending) return run
  const out = { ...run, route: null }
  const rand = dice(out)
  if (isBattleNode(node)) {
    // O cenário da batalha: a cidade do ginásio, a Liga (torre) ou o lugar da rota (os selvagens e os treinadores são de lá).
    const city = node.kind === 'boss' && atCity(data, run)
    const scene = node.biome ?? (city ? (bossOf(data, run).kind === 'gym' ? 'city' : 'tower') : run.route.biome ?? 'grass')
    out.scene = scene
    out.encounter = { ...encounterFor(data, out.floor, rand, node.kind === 'boss' ? bossOf(data, out) : null, node.kind === 'wildboss', { ...node, biome: scene, shiny: run.shinyRate ?? 1 }), scene }
    return out
  }
  out.floor += 1
  // O cenário de onde você está (Poké Mart e Centro na cidade).
  out.scene = node.kind === 'mart' ? 'city' : node.kind === 'center' ? 'center' : run.route.biome ?? 'grass'
  if (node.kind === 'mart') out.pending = { mart: true, shop: pickShop(rand, data, run.floor, 10) }
  else if (node.kind === 'trade') {
    // Troca: alguém da rota oferece um Pokémon (você escolhe quem dar; ele vem TRADE_LEVELS acima).
    const offer = encounterFor(data, out.floor, rand, null, false, { kind: 'wild', biome: run.route?.biome, shiny: run.shinyRate ?? 1 }).foes[0]
    out.pending = { trade: { id: offer.id, ...(offer.shiny ? { shiny: true } : {}) } }
  } else if (node.kind === 'center') {
    out.team = out.team.map((m) => ({ ...m, hp: 1 }))
    out.pending = { center: true }
  } else {
    const kind = pickOne(EVENTS, rand)
    const event = { kind }
    if (kind === 'items') {
      // Bolas ou remédios, melhores conforme o andar.
      event.item = rand() < 0.5 ? tierPick(BALL_TIERS, run.floor, 25, rand) : tierPick(HEAL_TIERS.slice(0, 3), run.floor, 20, rand)
      event.count = 2
      out.bag = { ...out.bag, [event.item]: (out.bag[event.item] ?? 0) + event.count }
    } else if (kind === 'money') {
      event.money = Math.round(60 * priceScale(out.floor - 1) * (0.5 + rand()))
      out.money += event.money
    } else if (kind === 'berries') {
      out.team = out.team.map((m) => ((m.hp ?? 1) > 0 ? { ...m, hp: Math.min(1, round3((m.hp ?? 1) + 0.3)) } : m))
    } else out.tokens = { ...out.tokens, 'move-tutor': (out.tokens?.['move-tutor'] ?? 0) + 1 }
    out.pending = { event }
  }
  return out
}

/**
 * O que aparece no andar: chefe da história (a cada 10), chefe sem treinador
 * (wild: Mega, Gigantamax ou lendário), selvagem ou treinador. node: o
 * caminho escolhido no mapa (selvagem do bioma, treinador ou treinador forte);
 * sem ele, selvagem ou treinador ao acaso.
 */
export function encounterFor(data, floor, rand, boss = null, wild = false, node = null) {
  const level = Math.max(2, foeLevelAt(floor) + Math.floor(rand() * 2))
  const iv = foeIvsAt(floor), ev = foeEvsAt(floor), boost = foeBoostAt(floor)
  // Evoluídos só a partir do nível em que evoluem (abaixo dele, a forma anterior).
  const foe = (id, lvl, extra = {}) => ({ id: devolve(data, id, Math.max(2, lvl)), level: Math.max(2, lvl), iv, ev, ...(boost ? { boost } : {}), ...extra })
  if (wild) {
    // Chefe sem treinador: dá para capturar; a Mega deixa a Mega Pedra.
    const r = rand()
    const strong = { iv: Math.max(31, iv), ev: Math.round(ev * 1.25) }
    let id, extra
    // Mega e Gigantamax só dos que já chegaram ao nível em que evoluem; senão, um lendário.
    const fits = (sid) => minLevelOf(data, sid) <= bossLevel(data, floor, sid, level + 3)
    const megas = Object.keys(data.megas).map(Number).sort((a, b) => a - b).filter(fits)
    const gmax = data.gmax.filter(fits)
    if (r < 0.4 && megas.length) {
      id = pickOne(megas, rand)
      const [stone] = pickOne(data.megas[id], rand)
      extra = { item: stone, gimmick: 'mega', title: 'mega' }
    } else if (r >= 0.4 && r < 0.7 && gmax.length) {
      id = pickOne(gmax, rand)
      extra = { gimmick: 'dmax', title: 'gmax' }
    } else {
      const legends = Object.entries(data.species).filter(([, info]) => info[2] === 1 || info[2] === 2).map(([k]) => Number(k))
      id = pickOne(legends, rand)
      extra = { title: 'legend' }
    }
    return { kind: 'wildboss', foes: [foe(id, bossLevel(data, floor, id, level + 3), { ...strong, ...extra, ...(rand() < SHINY_CHANCE * (node?.shiny ?? 1) ? { shiny: true } : {}) })] }
  }
  if (boss) {
    // Os times dos chefes são de Pokémon evoluídos: quem é mais forte que as espécies do andar vem com nível menor.
    // Antes do andar 10, sem o bônus de nível (o rival aparece cedo, como no começo dos jogos).
    const bonus = floor < 10 ? 0 : { gym: 2, rival: 2, villain: 3, elite: 4, champion: 5 }[boss.kind] ?? 2
    const team = bossTeam(boss, floor)
    const levelOf = (id, i) => bossLevel(data, floor, id, level + bonus + (i === team.length - 1 ? 1 : 0))
    const foes = team.map((id, i) => foe(id, levelOf(id, i), { iv: Math.max(31, iv), ev: Math.round(ev * 1.25) }))
    // A partir do andar 10, cada Pokémon do chefe segura um item de verdade (Leftovers, Life Orb, Choice...).
    if (floor >= 10) for (const f of foes) f.item = pickOne(FOE_ITEMS, rand)
    return { kind: 'boss', foes, boss: { id: boss.id, name: boss.name, trainer: boss.trainer, kind: boss.kind, region: boss.region, game: boss.game } }
  }
  // Lendários só aparecem como chefes (wild).
  const kind = node?.kind ?? (rand() < 0.35 ? 'trainer' : 'wild')
  // Nos primeiros andares, nada de Fantasma (imune aos golpes Normal que os iniciais têm no começo).
  const entries = Object.entries(data.species)
    .filter(([id, info]) => (floor >= 8 || !info[4]?.includes('ghost')) && minLevelOf(data, Number(id)) <= level)
    .map(([id, [, bst, rarity, , , rate]]) => ({ id: Number(id), bst, rarity, rate: rate ?? 45 }))
  const budget = speciesBudget(floor)
  // A chance de cada espécie segue a raridade dela (a taxa de captura dos jogos: Pidgey 255 aparece muito, Dratini 45 pouco, Beldum 3 quase nunca);
  // os treinadores escolhem com menos diferença (raiz da taxa).
  // Os tipos do lugar aparecem bem mais (ROUTE_TYPE_WEIGHT; nos treinadores, ROUTE_TYPE_TRAINER).
  const types = BIOMES[node?.biome]
  const local = (p) => Boolean(types && (data.species[p.id]?.[4] ?? []).some((t) => types.includes(t)))
  const pick = (pool, trainer = false) => {
    const fit = pool.filter((p) => p.bst <= budget && p.bst >= Math.min(budget, 600) - 160)
    const list = fit.length ? fit : [...pool].sort((a, b) => Math.abs(a.bst - budget) - Math.abs(b.bst - budget)).slice(0, 20)
    return pickWeighted(list, list.map((p) => (trainer ? Math.sqrt(p.rate) * (local(p) ? ROUTE_TYPE_TRAINER : 1) : p.rate * (local(p) ? ROUTE_TYPE_WEIGHT : 1))), rand).id
  }
  const common = entries.filter((p) => p.rarity === 0 || p.rarity === 3)
  if (kind === 'trainer' || kind === 'ace') {
    // O treinador forte: um Pokémon a mais, 2 níveis acima, mais EVs; sempre deixa um item.
    const ace = kind === 'ace'
    const count = Math.min(MAX_TEAM, 1 + Math.floor(floor / 12) + (rand() < 0.3 ? 1 : 0) + (ace ? 1 : 0))
    const extra = ace ? { iv: Math.max(iv, 20), ev: Math.round(ev * 1.15) } : {}
    const foes = Array.from({ length: count }, () => foe(pick(common, true), level + (ace ? 2 : 0) - Math.floor(rand() * 3), extra))
    // O mais forte do treinador forte segura um item de verdade (a partir do andar 15).
    if (ace && floor >= 15) foes[foes.length - 1].item = pickOne(FOE_ITEMS, rand)
    return { kind, foes, trainerSeed: Math.floor(rand() * 1e9), ...(ace ? { reward: pickOne(ACE_REWARDS, rand) } : {}) }
  }
  // Selvagem: os do lugar da rota aparecem bem mais.
  const id = pick(common)
  return { kind, foes: [foe(id, level, rand() < SHINY_CHANCE * (node?.shiny ?? 1) ? { shiny: true } : {})], ...(node?.biome ? { biome: node.biome } : {}) }
}

/** Começa uma corrida com o inicial escolhido (um dos grátis ou comprado). */
export function startRun(factory, data, id, seed, shiny = false) {
  if (!startersOf(factory, data).includes(id) || (shiny && !(factory.shinies ?? []).includes(id))) return null
  // As melhorias compradas com moedas.
  const up = (k) => upgradeValue(factory, k)
  const bag = { ...START_BAG, 'poke-ball': START_BAG['poke-ball'] + up('balls'), potion: START_BAG.potion + up('potions'), revive: START_BAG.revive + up('revive') }
  const run = {
    seed: seed >>> 0, floor: 1, money: up('money'), defeated: 0, bosses: 0, bag,
    team: [], teamBoost: zero(), mult: { money: 1, exp: round3(1 + up('exp') / 100), shop: round3(1 - up('shop') / 100) }, cards: [], boss: { region: 0, step: 0 }, played: [],
    ...(up('cards') ? { cardCount: 3 + up('cards') } : {}), ...(up('reroll') ? { rerolls: up('reroll') } : {}), ...(up('shiny') ? { shinyRate: 1 + up('shiny') } : {}),
    tms: {}, tokens: { 'move-tutor': 0, 'move-reminder': 0 }, stash: [], dmax: false, tera: false, expShare: up('expShare') > 0, leg: 1, route: null, encounter: null, pending: null,
  }
  const rand = dice(run)
  // O inicial vem com IVs bons (15 a 31; com a Genética, mais).
  run.team = [newMon(id, START_LEVEL + up('level'), rand, Math.min(31, 15 + up('ivs')), shiny)]
  run.boss = { region: Math.floor(rand() * data.bosses.length), step: 0 }
  run.played = [data.bosses[run.boss.region].region]
  run.route = routeOptions(run, data, rand)
  return run
}

/** O próximo chefe: depois do Campeão, a história de outra região (uma que ainda não saiu na corrida). Devolve [boss, played]. */
function nextBoss(run, data, rand) {
  const step = run.boss.step + 1
  if (step < data.bosses[run.boss.region].leaders.length) return [{ ...run.boss, step }, run.played ?? []]
  let played = run.played ?? []
  let options = data.bosses.map((_, i) => i).filter((i) => !played.includes(data.bosses[i].region))
  if (!options.length) {
    played = []
    options = data.bosses.map((_, i) => i).filter((i) => data.bosses[i].region !== data.bosses[run.boss.region].region)
  }
  if (!options.length) options = [run.boss.region]
  const region = pickOne(options, rand)
  return [{ region, step: 0 }, [...played, data.bosses[region].region]]
}

/** O texto da história (tool/factory_stories.py) para a região e o momento ({0}: o nome do chefe). */
export function storyLine(data, region, key, name = '') {
  return (data.stories?.[region]?.[key] ?? '').replace('{0}', name)
}

/**
 * Venceu o andar. after = como o time terminou a batalha: {hp: [parte do HP de
 * cada um do time, na ordem da corrida], bag, captured: capturou o selvagem}.
 * Quem está de pé ganha XP e EVs (capturar conta como derrotar); depois vêm o
 * capturado (entra no time), a carta (chefe), a loja (ao chegar na cidade) e,
 * às vezes, a Enfermeira Joy (pending).
 */
export function winFloor(run, data, after = {}) {
  // A Escape Rope não entra na batalha: fica a da Bolsa.
  const out = { ...run, team: run.team.map((m, i) => ({ ...m, hp: after.hp?.[i] ?? m.hp ?? 1 })), bag: { ...(after.bag ?? run.bag), 'escape-rope': run.bag['escape-rope'] ?? 0 } }
  const rand = dice(out)
  const { kind, foes } = run.encounter
  const factor = expFactor(kind)
  const moneyFactor = kind === 'boss' || kind === 'wildboss' ? 3 : kind === 'ace' ? 2.5 : kind === 'trainer' ? 2 : 1
  let money = 0
  // XP e EVs de cada derrotado: para quem lutou contra ele (after.fought[j]: posições na corrida) e, com o Exp. Share, para o resto do time.
  const gains = out.team.map(() => 0)
  const evs = out.team.map(() => zero())
  foes.forEach((f, j) => {
    money += Math.floor((f.level * 6 + 10) * moneyFactor * out.mult.money * earlyMoney(run.floor))
    const yields = speciesOf(data, f.id)?.[3] ?? [0, 0, 0, 0, 0, 0]
    expShares(out, data, f, after.fought?.[j], factor).forEach((e, i) => {
      if (!e) return
      gains[i] += e
      STATS.forEach((s, k) => { evs[i][s] += yields[k] * 3 })
    })
  })
  const levels = []
  const exp = Math.max(0, ...gains)
  out.team = out.team.map((m, index) => {
    if (!gains[index]) return m
    const r = gainExp({ ...m, evs: addStats(m.evs, evs[index]) }, gains[index], data, rand)
    if (r.mon.level > r.from || r.evolved) levels.push({ index, from: r.from, to: r.mon.level, evolved: r.evolved })
    return r.mon
  })
  out.money += money
  out.defeated += foes.length
  out.floor += 1
  let drop = null, story = null
  if (kind === 'boss' || kind === 'wildboss') out.bosses = (out.bosses ?? 0) + 1
  let champion = false
  if (kind === 'boss') {
    const beaten = run.encounter.boss
    // As conquistas (progress): insígnias, ginásio só com o inicial, Campeões.
    if (beaten.kind === 'gym') {
      out.badges = (run.badges ?? 0) + 1
      if (run.team.length === 1) out.soloGym = true
    }
    if (beaten.kind === 'champion') {
      out.champions = (run.champions ?? 0) + 1
      champion = true
    }
    // Venceu o chefe da cidade (ou da Liga): começa a rota seguinte.
    if (CITY_KINDS.includes(beaten.kind)) out.leg = out.floor
    const [boss, played] = nextBoss(out, data, rand)
    // Acabou a história da região: o fim dela e o começo da próxima.
    if (boss.step === 0) story = `${storyLine(data, beaten.region, 'end')}\n\n${storyLine(data, data.bosses[boss.region].region, 'intro')}`
    out.boss = boss
    out.played = played
    // O chefe deixa o Cristal Z do tipo do Pokémon mais forte dele.
    const ace = foes[foes.length - 1]
    const crystal = data.zcrystals?.[speciesOf(data, ace.id)?.[4]?.[0]]
    if (crystal && !hasItem(out, crystal)) drop = crystal
  }
  // A Mega deixa a Mega Pedra (derrotando ou capturando).
  if (kind === 'wildboss' && foes[0].item && !hasItem(out, foes[0].item)) drop = foes[0].item
  if (drop) out.stash = [...(out.stash ?? []), drop]
  // O treinador forte deixa um item: bolas e remédios na Bolsa, ficha de Move Tutor, os de segurar guardados.
  const reward = kind === 'ace' ? run.encounter.reward ?? null : null
  if (reward && BAG_ITEMS.includes(reward)) out.bag[reward] = (out.bag[reward] ?? 0) + 1
  else if (reward && TOKENS.includes(reward)) out.tokens = { ...out.tokens, [reward]: (out.tokens?.[reward] ?? 0) + 1 }
  else if (reward) out.stash = [...(out.stash ?? []), reward]
  const joy = rand() < JOY_CHANCE
  if (joy) out.team = out.team.map((m) => ({ ...m, hp: 1 }))
  out.pending = {
    exp, gains, money, levels, joy, drop, story, reward, ...(champion ? { champion: true } : {}),
    capture: after.captured && (kind === 'wild' || kind === 'wildboss') ? foes[0] : null,
    cards: kind === 'boss' ? pickCards(rand, run.cardCount ?? 3) : null,
    // A loja da cidade: chegando nela, logo antes do chefe (no resto da rota, os Poké Marts do mapa).
    shop: kind !== 'boss' || !CITY_KINDS.includes(run.encounter.boss.kind) ? (atCity(data, out) && !inLeague(data, out) ? pickShop(rand, data, run.floor) : null) : null,
  }
  out.encounter = null
  return out
}

function pickCards(rand, count = 3) {
  const ids = Object.keys(CARDS)
  const out = []
  while (out.length < count) {
    const id = pickOne(ids, rand)
    if (!out.includes(id)) out.push(id)
  }
  return out
}

/** Alguém do time (ou guardado) já tem esse item. */
const hasItem = (run, id) => (run.stash ?? []).includes(id) || run.team.some((m) => m.item === id || (m.extras ?? []).includes(id))

/** As bolas e os remédios em escada (do pior ao melhor) e as bolas especiais. */
export const BALL_TIERS = ['poke-ball', 'great-ball', 'ultra-ball']
export const HEAL_TIERS = ['potion', 'super-potion', 'hyper-potion', 'max-potion']
export const SPECIAL_BALLS = ['quick-ball', 'net-ball', 'dusk-ball', 'timer-ball']

/**
 * Um item da escada: conforme o andar, os melhores ficam mais prováveis (um
 * degrau a cada `step` andares; o de baixo nunca some de vez). Bolas: Great
 * Ball em destaque no andar 25 e Ultra Ball no 50; remédios: um degrau a cada 20.
 */
export function tierPick(list, floor, step, rand) {
  const p = Math.min(list.length - 1, floor / step)
  const weights = list.map((_, i) => Math.max(0.08, 1 - Math.abs(i - p)))
  let roll = rand() * weights.reduce((a, b) => a + b, 0)
  for (let i = 0; i < list.length; i++) {
    roll -= weights[i]
    if (roll < 0) return list[i]
  }
  return list[list.length - 1]
}

function pickShop(rand, data, floor, size = 8) {
  const out = []
  const add = (id) => { if (!out.includes(id)) out.push(id) }
  // Dois tipos de bola (melhores conforme o andar), às vezes uma especial; a Master Ball é rara (um pouco menos lá em cima).
  for (let k = 0; k < 4 && out.length < 2; k++) add(tierPick(BALL_TIERS, floor, 25, rand))
  if (floor >= 5 && rand() < 0.6) add(pickOne(SPECIAL_BALLS, rand))
  if (rand() < Math.min(0.08, 0.01 + floor / 1500)) add('master-ball')
  // Dois remédios (melhores conforme o andar) e, às vezes, Revive.
  const before = out.length
  for (let k = 0; k < 4 && out.length < before + 2; k++) add(tierPick(HEAL_TIERS, floor, 20, rand))
  if (rand() < 0.5) add('revive')
  const ids = Object.keys(SHOP).filter((id) => !BALL_IDS.includes(id) && !HEAL_TIERS.includes(id) && id !== 'revive')
  // TM e pedra de evolução, às vezes.
  if (data.tms?.length && rand() < 0.6) out.push(`tm:${pickOne(data.tms, rand)}`)
  if (data.stones?.length && rand() < 0.45) out.push(`evo:${pickOne(data.stones, rand)}`)
  while (out.length < size) {
    const id = pickOne(ids, rand)
    if (!out.includes(id)) out.push(id)
  }
  return out
}

/** O Pokémon capturado na batalha entra no time (replace: posição a trocar com o time cheio). */
export function capture(run, replace = null) {
  const foe = run.pending?.capture
  if (!foe) return run
  const out = { ...run, team: [...run.team], pending: { ...run.pending, capture: null } }
  const rand = dice(out)
  const mon = newMon(foe.id, foe.level, rand, 0, Boolean(foe.shiny))
  if (out.team.length < MAX_TEAM) out.team.push(mon)
  else if (replace != null && replace >= 0 && replace < out.team.length) out.team[replace] = mon
  else return run
  return out
}
/** Solta o capturado (o time está cheio e você não quer trocar ninguém). */
export const skipCapture = (run) => (run.pending ? { ...run, pending: { ...run.pending, capture: null } } : run)

/** A troca: quem está na posição index vai e vem o oferecido, TRADE_LEVELS níveis acima (evolui se der), com o item dele. */
export const TRADE_LEVELS = 3
export function tradeMon(run, index, data) {
  const offer = run.pending?.trade
  const mon = run.team[index]
  if (!offer || !mon) return run
  const out = { ...run, team: [...run.team], pending: { ...run.pending, trade: null }, trades: (run.trades ?? 0) + 1 }
  const rand = dice(out)
  const fresh = newMon(devolve(data, offer.id, mon.level), mon.level, rand, 10, Boolean(offer.shiny))
  const [grown] = levelTo(fresh, mon.level + TRADE_LEVELS, data, rand)
  out.team[index] = { ...grown, item: mon.item ?? null, extras: mon.extras ?? [] }
  return out
}
/** Sorteia os caminhos do andar de novo (melhoria "reroll": algumas vezes por corrida). null se não dá. */
export function rerollRoute(run, data) {
  if (!((run.rerolls ?? 0) > 0) || !run.route || run.encounter || run.pending) return null
  const out = { ...run, rerolls: run.rerolls - 1 }
  out.route = routeOptions(out, data, dice(out))
  return out
}

/** Recusa a troca. */
export const skipTrade = (run) => (run.pending ? { ...run, pending: { ...run.pending, trade: null } } : run)

/** Quem abre a batalha: passa o Pokémon da posição para a frente do time (para treinar os mais fracos). Igual ao app. */
export function setLead(run, index) {
  if (!(index > 0) || !run.team[index]) return run
  const team = [...run.team]
  const [mon] = team.splice(index, 1)
  return { ...run, team: [mon, ...team] }
}

/**
 * Perdeu a batalha com uma Escape Rope na Bolsa: gasta ela e o time foge com
 * pouco HP (ESCAPE_HP), no mesmo andar, com o mapa de novo. after = {hp, bag}
 * da batalha (factoryAfter). null sem a corda (a corrida acaba).
 */
export function escapeRope(run, data, after = {}) {
  if (!((run.bag?.['escape-rope'] ?? 0) > 0)) return null
  const bag = { ...run.bag, ...(after.bag ?? {}), 'escape-rope': run.bag['escape-rope'] - 1 }
  const out = { ...run, bag, team: run.team.map((m, i) => ({ ...m, hp: Math.max(after.hp?.[i] ?? 0, ESCAPE_HP) })), encounter: null, pending: null, ropes: (run.ropes ?? 0) + 1 }
  out.route = routeOptions(out, data, dice(out))
  return out
}

/**
 * Conquistas da Battle Factory: cada uma dá moedas uma vez só (fica na conta).
 * Olham o estado da corrida (progress).
 */
export const ACHIEVEMENTS = {
  badge: { label: 'Primeira insígnia', coins: 50, done: (r) => (r.badges ?? 0) >= 1 },
  badges8: { label: '8 insígnias numa corrida', coins: 300, done: (r) => (r.badges ?? 0) >= 8 },
  solo: { label: 'Vencer um ginásio só com o inicial', coins: 250, done: (r) => Boolean(r.soloGym) },
  champion: { label: 'Vencer um Campeão (Hall da Fama)', coins: 600, done: (r) => (r.champions ?? 0) >= 1 },
  champion2: { label: 'Vencer o Campeão de duas regiões', coins: 1500, done: (r) => (r.champions ?? 0) >= 2 },
  floor25: { label: 'Chegar ao andar 25', coins: 100, done: (r) => r.floor > 25 },
  floor50: { label: 'Chegar ao andar 50', coins: 300, done: (r) => r.floor > 50 },
  floor100: { label: 'Chegar ao andar 100', coins: 1000, done: (r) => r.floor > 100 },
  full: { label: 'Time completo (6 Pokémon)', coins: 80, done: (r) => r.team.length >= MAX_TEAM },
  shiny: { label: 'Um shiny no time', coins: 200, done: (r) => r.team.some((m) => m.shiny) },
  level50: { label: 'Um Pokémon no nível 50', coins: 150, done: (r) => r.team.some((m) => m.level >= 50) },
  level100: { label: 'Um Pokémon no nível 100', coins: 400, done: (r) => r.team.some((m) => m.level >= 100) },
  trade: { label: 'Fazer uma troca', coins: 40, done: (r) => (r.trades ?? 0) >= 1 },
  rope: { label: 'Escapar com a Escape Rope', coins: 40, done: (r) => (r.ropes ?? 0) >= 1 },
}

/**
 * As conquistas novas da corrida (com as moedas delas) e o Hall da Fama (o
 * time que venceu o Campeão, um registro por vitória). Devolve [factory, ids novos].
 */
export function progress(factory, run) {
  if (!run) return [factory, []]
  const have = factory.achievements ?? []
  const earned = Object.keys(ACHIEVEMENTS).filter((id) => !have.includes(id) && ACHIEVEMENTS[id].done(run))
  let out = factory
  if (earned.length) out = { ...out, achievements: [...have, ...earned], coins: out.coins + earned.reduce((sum, id) => sum + ACHIEVEMENTS[id].coins, 0) }
  if (run.pending?.champion) {
    const key = `${run.seed}-${run.floor}`
    if (!(out.hall ?? []).some((h) => h.key === key)) {
      const entry = { key, floor: run.floor - 1, champions: run.champions ?? 1, team: run.team.map((m) => ({ id: m.id, level: m.level, ...(m.shiny ? { shiny: true } : {}) })) }
      out = { ...out, hall: [entry, ...(out.hall ?? [])].slice(0, 20) }
    }
  }
  return [out, earned]
}

/** Escolhe a carta de bônus. */
export function takeCard(run, id, data) {
  const card = CARDS[id]
  if (!card || !run.pending?.cards?.includes(id)) return run
  const out = { ...run, cards: [...run.cards, id], pending: { ...run.pending, cards: null } }
  if (card.team) out.teamBoost = Object.fromEntries(STATS.map((s) => [s, round3((out.teamBoost?.[s] ?? 0) + (card.team[s] ?? 0))]))
  if (card.mult) out.mult = { ...out.mult, [card.mult[0]]: Math.max(0.4, round3(out.mult[card.mult[0]] + card.mult[1])) }
  if (card.balls) out.bag = { ...out.bag, 'poke-ball': (out.bag['poke-ball'] ?? 0) + card.balls }
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
  // O Rare Candy sobe com o nível do time (e não com o tamanho dos times dos treinadores).
  const candy = id === 'rare-candy'
  const top = candy ? Math.max(START_LEVEL, ...run.team.map((m) => m.level)) : START_LEVEL
  const base = id.startsWith('tm:') ? TM_PRICE : id.startsWith('evo:') ? EVO_PRICE : SHOP[id] ?? 0
  const scale = candy ? 1 + (run.floor - 1) / 20 : priceScale(run.floor)
  return Math.max(1, Math.round(base * scale * (top / START_LEVEL) * run.mult.shop))
}

/** Evoluções que o Pokémon faz com o item (pedra): [para, ...]. */
export function canEvolveWith(data, mon, item) {
  return (data.evolutions[mon.id] ?? []).filter((e) => e[2] === item).map((e) => e[0])
}

/** Se o item já foi comprado/é inútil agora (Dynamax Band e Tera Orb são uma vez só). */
export function shopOwned(run, id) {
  return (id === 'dynamax-band' && run.dmax) || (id === 'tera-orb' && run.tera) || (id === 'exp-share' && Boolean(run.expShare))
}

/** Compra um item da loja (index: o Pokémon que recebe; itens da Bolsa e Poké Ball não precisam). null se não dá. */
export function buyItem(run, id, index, data) {
  const price = shopPrice(run, id)
  if (!run.pending?.shop?.includes(id) || run.money < price) return null
  const out = { ...run, money: run.money - price, team: [...run.team] }
  if (shopOwned(run, id)) return null
  if (BAG_ITEMS.includes(id)) return { ...out, bag: { ...out.bag, [id]: (out.bag[id] ?? 0) + 1 } }
  if (id === 'dynamax-band') return { ...out, dmax: true }
  if (id === 'tera-orb') return { ...out, tera: true }
  if (id === 'exp-share') return { ...out, expShare: true }
  if (TOKENS.includes(id)) return { ...out, tokens: { ...out.tokens, [id]: (out.tokens?.[id] ?? 0) + 1 } }
  if (id.startsWith('tm:')) {
    const move = id.slice(3)
    return { ...out, tms: { ...out.tms, [move]: (out.tms?.[move] ?? 0) + 1 } }
  }
  const mon = run.team[index]
  if (!mon) return null
  if (id.startsWith('evo:')) {
    // Pedra de evolução: evolui na hora (se ele evolui com ela).
    const [to] = canEvolveWith(data, mon, id.slice(4))
    if (!to) return null
    out.team[index] = { ...mon, id: to }
    return out
  }
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

/**
 * Ensina um golpe (TM, Move Tutor ou Move Reminder): gasta o TM ou a ficha e
 * troca o golpe da posição slot (ou acrescenta, se ele sabe menos de 4).
 * current: os golpes que ele usa agora (os do nível, se nunca mudou). A tela
 * confere se ele pode aprender (lista de golpes da espécie). null se não dá.
 */
export function teachMove(run, index, move, current, slot, source) {
  const mon = run.team[index]
  if (!mon || !move || current.includes(move)) return null
  const out = { ...run, team: [...run.team] }
  if (source === 'tm') {
    if (!(run.tms?.[move] > 0)) return null
    out.tms = { ...run.tms, [move]: run.tms[move] - 1 }
  } else if (TOKENS.includes(source)) {
    if (!(run.tokens?.[source] > 0)) return null
    out.tokens = { ...run.tokens, [source]: run.tokens[source] - 1 }
  } else return null
  const moves = [...current]
  if (moves.length < 4) moves.push(move)
  else if (slot >= 0 && slot < moves.length) moves[slot] = move
  else return null
  out.team[index] = { ...mon, moves }
  return out
}

/** Dá um item guardado (Mega Pedra, Cristal Z) para um Pokémon: vira o principal (o antigo vai para os extras). */
export function equipFromStash(run, stashIndex, index) {
  const id = run.stash?.[stashIndex]
  const mon = run.team[index]
  if (!id || !mon) return run
  const stash = run.stash.filter((_, i) => i !== stashIndex)
  const team = [...run.team]
  team[index] = { ...mon, item: id, extras: mon.item ? [...(mon.extras ?? []), mon.item] : [...(mon.extras ?? [])] }
  return { ...run, team, stash }
}

/** As mecânicas que ele pode usar: Mega (com a Mega Pedra dele), Z (com Cristal Z), Dynamax (Band) e Tera (Orb). */
export function gimmicksOf(data, run, mon) {
  const out = []
  const species = data.forms?.[mon.id] ?? mon.id
  if (mon.item && (data.megas?.[species] ?? []).some(([stone]) => stone === mon.item)) out.push('mega')
  if (mon.item && Object.values(data.zcrystals ?? {}).includes(mon.item)) out.push('z')
  if (run.dmax) out.push('dmax')
  if (run.tera) out.push('tera')
  return out
}

/** A mecânica dele na batalha: a escolhida (se ainda pode) ou a primeira que tiver. */
export function gimmickOf(data, run, mon) {
  const options = gimmicksOf(data, run, mon)
  return options.includes(mon.gimmick) ? mon.gimmick : mon.gimmick === 'none' ? '' : options[0] ?? ''
}

/** Escolhe a mecânica ('none' = nenhuma). */
export function setGimmick(run, index, gimmick) {
  const team = [...run.team]
  team[index] = { ...team[index], gimmick }
  return { ...run, team }
}

/** O time inteiro desmaiado (não dá para seguir). */
export const teamDown = (run) => run.team.every((m) => !((m.hp ?? 1) > 0))

/** Sai da loja (ou não tinha): os caminhos do próximo andar no mapa. */
export function nextFloor(run, data) {
  const out = { ...run, pending: null, encounter: null }
  out.route = routeOptions(out, data, dice(out))
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

/** A Bolsa de cada lado: a sua é a da corrida; só os chefes da história usam itens (mais nos andares altos). */
export function bagsFor(run) {
  const floor = run.floor
  const kind = run.encounter?.kind
  const none = { ...Object.fromEntries(BALL_IDS.map((id) => [id, 0])), potion: 0, 'super-potion': 0, 'hyper-potion': 0, 'max-potion': 0, revive: 0 }
  const foe = kind === 'boss'
    ? { ...none, 'hyper-potion': 1 + Math.floor(floor / 40), 'max-potion': floor >= 60 ? 1 : 0, revive: floor >= 100 ? 1 : 0 }
    : none
  return [{ ...none, ...run.bag }, foe]
}

/**
 * A captura na batalha (input.capture do motor): só com selvagens. rates: a
 * taxa de captura de cada adversário; dusk: rota escura (Dusk Ball 3×).
 */
export function captureFor(run, data) {
  const { kind, foes, biome } = run.encounter ?? {}
  if (kind !== 'wild' && kind !== 'wildboss') return null
  return { rates: foes.map((f) => speciesOf(data, f.id)?.[5] ?? 45), dusk: DARK_BIOMES.includes(biome) }
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

/** O Pokémon da corrida como membro de time (battleSetup.battleMons). moveList: os do nível (se ele não aprendeu outros). */
export function memberOf(run, mon, moveList, data = null) {
  const gimmick = data ? gimmickOf(data, run, mon) : ''
  return {
    id: mon.id,
    set: {
      level: mon.level, levelCap: 'none', nature: mon.nature, ivs: capStats(mon.ivs, 31), evs: capStats(mon.evs, 252), item: mon.item ?? '',
      moves: mon.moves?.length ? mon.moves : moveList, lockMoves: true, shiny: Boolean(mon.shiny), ...(gimmick ? { gimmick } : {}),
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
      ...(foe.item ? { item: foe.item } : {}),
      ...(foe.gimmick ? { gimmick: foe.gimmick } : {}),
    },
  }
}
