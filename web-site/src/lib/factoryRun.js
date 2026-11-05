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
// e os vilões no meio, a Elite dos Quatro e o Campeão de um jogo sorteado; os times
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
/** Shiny: 1 em 4096 (como nos jogos); o seu shiny tem +25% em todos os atributos (o adversário, +10%). Igual ao app. */
export const SHINY_CHANCE = 1 / 4096
export const SHINY_BOOST = 0.25
/** O adversário shiny: +10%. */
export const FOE_SHINY_BOOST = 0.1
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

/** Nível base dos adversários no andar (sem teto): o Campeão do primeiro jogo (andar ~185) fica perto do nível 100. */
export const FOE_LEVEL_SLOPE = 0.53
export const foeLevelAt = (floor) => 2 + Math.floor((floor - 1) * FOE_LEVEL_SLOPE)
/** EVs (por atributo) dos adversários no andar: até 252, como nos jogos (o que passa disso vem do jogo da corrida, GAME_TIER). */
export const foeEvsAt = (floor) => Math.min(252, 3 * floor)
/** IVs dos adversários no andar: até 31 (o que passa disso vem do jogo da corrida, GAME_TIER). */
export const foeIvsAt = (floor) => Math.min(31, Math.floor(floor / 2))
/**
 * A dificuldade sobe a cada jogo da corrida: o primeiro (com o pós-jogo) é só
 * o nível do andar; ao começar o jogo seguinte, os adversários ganham, por
 * jogo já vencido, IVs e EVs acima do limite e uma porcentagem em todos os
 * atributos. Sem teto: as cartas de atributo também crescem (cardPower). Igual ao app.
 */
export const GAME_TIER = { iv: 4, ev: 64, boost: 0.08 }
/** Quantos jogos a corrida já terminou (o degrau da dificuldade). */
export const tierOf = (run) => run?.games ?? 0
/** O bônus de todos os atributos dos adversários no degrau. */
export const foeBoostAt = (tier) => Math.round(tier * GAME_TIER.boost * 1000) / 1000
/**
 * O rival evolui junto (como nos jogos): a cada vez que você o vence, o time
 * dele volta RIVAL_GROWTH nível mais forte (até RIVAL_GROWTH_MAX). Igual ao app.
 */
export const RIVAL_GROWTH = 1
export const RIVAL_GROWTH_MAX = 6
export function rivalGrowth(encounter, run) {
  const wins = Math.min(RIVAL_GROWTH_MAX, (run?.rivalWins ?? 0) * RIVAL_GROWTH)
  if (!wins || encounter?.boss?.kind !== 'rival' || encounter.boss.guest) return encounter
  return { ...encounter, foes: encounter.foes.map((f) => ({ ...f, level: f.level + wins })) }
}
/** Os adversários do encontro com o degrau do jogo da corrida. */
export function tierFoes(encounter, run) {
  const tier = tierOf(run)
  if (!tier || !encounter?.foes) return encounter
  const boost = foeBoostAt(tier)
  return { ...encounter, foes: encounter.foes.map((f) => ({ ...f, iv: (f.iv ?? 0) + tier * GAME_TIER.iv, ev: (f.ev ?? 0) + tier * GAME_TIER.ev, boost: Math.round(((f.boost ?? 0) + boost) * 1000) / 1000 })) }
}
/** Depois do andar WIN_HEAL_FLOOR (os treinadores já vêm com o time quase todo), cada vitória cura WIN_HEAL% do HP de quem está de pé. */
export const WIN_HEAL_FLOOR = 60
export const WIN_HEAL = 25
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
  // Mapa (Town Map): mostra o mapa da rota e deixa escolher o caminho nas bifurcações (sem ele, vai às cegas).
  'town-map': 200,
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

/**
 * Relíquias (itens raros de chefe): às vezes uma delas aparece no lugar de uma
 * carta. Mudam a regra da corrida: um bônus forte com um preço. Igual ao app.
 */
export const RELICS = {
  'relic-ember': { icon: '🔥', label: 'Brasa Antiga: +15% de Ataque e Ataque Especial, mas −10% de Defesa e Defesa Especial', team: { atk: 0.15, spa: 0.15, def: -0.1, spd: -0.1 } },
  'relic-shell': { icon: '🐚', label: 'Casco Antigo: +15% de Defesa e Defesa Especial, mas −10% de Velocidade', team: { def: 0.15, spd: 0.15, spe: -0.1 } },
  'relic-wing': { icon: '🪶', label: 'Pena Antiga: +15% de Velocidade, mas −8% de HP', team: { spe: 0.15, hp: -0.08 } },
  'relic-coin': { icon: '🪙', label: 'Moeda Antiga: o dobro de dinheiro, mas a loja fica 25% mais cara', mults: [['money', 1], ['shop', 0.25]] },
  'relic-scroll': { icon: '📜', label: 'Pergaminho Antigo: +60% de XP, mas −30% de dinheiro', mults: [['exp', 0.6], ['money', -0.3]] },
  'relic-spring': { icon: '⛲', label: 'Fonte Antiga: cura 15% do HP depois de cada vitória, mas −8% de Ataque e Ataque Especial', winHeal: 15, team: { atk: -0.08, spa: -0.08 } },
  'relic-net': { icon: '🕸️', label: 'Rede Antiga: +40% na captura, mas −20% de dinheiro', catchBonus: 40, mults: [['money', -0.2]] },
}
/** Chance de uma relíquia aparecer entre as cartas depois de um chefe. */
export const RELIC_CHANCE = 0.35
/** O texto de uma carta ou relíquia. */
export const cardLabel = (id) => (CARDS[id] ?? RELICS[id])?.label ?? id
/**
 * Força das cartas de atributo no andar: crescem com a profundidade (+1% do valor
 * por andar depois do 30). Os adversários sobem para sempre, e as cartas também:
 * quem escolhe bem acompanha sem fim; quem escolhe mal fica para trás. Igual ao app.
 */
export const cardPower = (floor) => Math.round((1 + Math.max(0, (floor ?? 1) - 30) / 100) * 1000) / 1000
/** O texto (já traduzido) da carta com os números de atributo do andar. */
export const cardText = (text, id, floor) => (CARDS[id]?.team ? text.replace(/\+(\d+)(\s?)%/, (_, n, sp) => `+${Math.round(Number(n) * cardPower(floor))}${sp}%`) : text)

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
  // Os nós da trilha que saíram da árvore (eram 8 por melhoria, agora 2): as moedas voltam (o preço de quando foram comprados).
  const gone = Object.keys(factory.upgrades ?? {}).filter((k) => !UPGRADES[k])
  const back = gone.reduce((n, k) => n + (factory.upgrades[k] > 0 && UPGRADES[minorOf(k)] ? legacyMinorPrice(UPGRADES[minorOf(k)].base, Number(k.split('~')[1])) : 0), 0)
  if (gone.length) factory = { ...factory, upgrades: Object.fromEntries(Object.entries(factory.upgrades).filter(([k]) => UPGRADES[k])), coins: (factory.coins ?? 0) + back, refunded: back }
  // Quem já jogava antes dos itens da árvore: começa com 1 de cada a cada 10 andares do recorde.
  if (!(factory.pieces && typeof factory.pieces === 'object') && (factory.best ?? 0) >= 10) factory = { ...factory, pieces: Object.fromEntries(PIECE_ITEMS.map((item) => [item, Math.floor(factory.best / 10)])) }
  // A dupla de treinadores salva com mais de 6 (os dois times inteiros): a batalha não começava. Fica com 3 de cada.
  const pairFoes = factory.run?.encounter?.pair ? factory.run.encounter.foes ?? [] : []
  if (pairFoes.length > 2 * PAIR_TEAM) factory = { ...factory, run: { ...factory.run, encounter: { ...factory.run.encounter, foes: [...pairFoes.slice(0, PAIR_TEAM), ...pairFoes.slice(-PAIR_TEAM)] } } }
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
  return { ...factory, owned, shinies, coins: (factory.coins ?? 0) + Math.max(0, refund), refunded: Math.max(0, refund) + back }
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
  reroll: { label: '{0}× por corrida: sortear o caminho de novo', per: 1, max: 2, base: 700 },
  cards: { label: 'Uma carta a mais para escolher depois de cada chefe', per: 1, max: 1, base: 2000 },
  shiny: { label: 'Shiny {0}× mais comum', per: 2, max: 5, base: 900, offset: 1 },
  greatBalls: { label: 'Começa com +{0} Great Ball', per: 1, max: 3, base: 250 },
  rope: { label: 'Começa com +{0} Escape Rope', per: 1, max: 2, base: 500 },
  coins: { label: '+{0}% de moedas no fim da corrida', per: 10, max: 5, base: 400 },
  map: { label: 'Começa com o Mapa da Cidade', per: 1, max: 1, base: 900 },
  dmax: { label: 'Começa com a Dynamax Band', per: 1, max: 1, base: 2500 },
  tera: { label: 'Começa com a Tera Orb', per: 1, max: 1, base: 3000 },
  // A árvore grande: itens na Bolsa, itens guardados, bônus no time, XP e dinheiro, fichas (UPGRADE_FX diz o efeito).
  superPotions: { label: 'Começa com +{0} Super Potion', per: 1, max: 3, base: 150 },
  hyperPotions: { label: 'Começa com +{0} Hyper Potion', per: 1, max: 3, base: 300 },
  maxPotions: { label: 'Começa com +{0} Max Potion', per: 1, max: 2, base: 600 },
  sitrus: { label: 'Começa com uma Sitrus Berry guardada', per: 1, max: 1, base: 800 },
  lum: { label: 'Começa com uma Lum Berry guardada', per: 1, max: 1, base: 900 },
  leftovers: { label: 'Começa com Leftovers guardado', per: 1, max: 1, base: 1200 },
  sash: { label: 'Começa com uma Focus Sash guardada', per: 1, max: 1, base: 1500 },
  ultraBalls: { label: 'Começa com +{0} Ultra Ball', per: 1, max: 3, base: 400 },
  masterBall: { label: 'Começa com +{0} Master Ball', per: 1, max: 1, base: 6000 },
  // Captura mais fácil (toda Poké Ball): a taxa de captura sobe.
  quickBalls: { label: 'Captura {0}% mais fácil', per: 8, max: 3, base: 300 },
  netBalls: { label: 'Captura {0}% mais fácil', per: 8, max: 3, base: 250 },
  timerBalls: { label: 'Captura {0}% mais fácil', per: 8, max: 3, base: 250 },
  duskBalls: { label: 'Captura {0}% mais fácil', per: 8, max: 3, base: 250 },
  expPlus: { label: 'Mais +{0}% de XP', per: 3, max: 5, base: 500 },
  luckyEgg: { label: 'Começa com o Lucky Egg guardado', per: 1, max: 1, base: 1500 },
  hpBoost: { label: 'Vigor: +{0}% de HP no time', per: 1, max: 10, base: 200 },
  speBoost: { label: 'Agilidade: +{0}% de Velocidade no time', per: 1, max: 10, base: 250 },
  tutor: { label: 'Começa com +{0} ficha de Move Tutor', per: 1, max: 3, base: 400 },
  reminder: { label: 'Começa com +{0} ficha de Move Reminder', per: 1, max: 3, base: 250 },
  atk: { label: 'Força: +{0}% de Ataque no time', per: 1, max: 10, base: 200 },
  spa: { label: 'Foco: +{0}% de Ataque Especial no time', per: 1, max: 10, base: 200 },
  def: { label: 'Couraça: +{0}% de Defesa no time', per: 1, max: 10, base: 200 },
  spd: { label: 'Escudo: +{0}% de Defesa Especial no time', per: 1, max: 10, base: 200 },
  allStats: { label: 'Mestre: +{0}% em todos os atributos do time', per: 1, max: 5, base: 1500 },
  band: { label: 'Começa com uma Choice Band guardada', per: 1, max: 1, base: 1200 },
  scarf: { label: 'Começa com uma Choice Scarf guardada', per: 1, max: 1, base: 1500 },
  specs: { label: 'Começa com Choice Specs guardado', per: 1, max: 1, base: 1200 },
  lifeOrb: { label: 'Começa com uma Life Orb guardada', per: 1, max: 1, base: 1500 },
  vest: { label: 'Começa com um Assault Vest guardado', per: 1, max: 1, base: 1300 },
  helmet: { label: 'Começa com um Rocky Helmet guardado', per: 1, max: 1, base: 1000 },
  quickClaw: { label: 'Começa com uma Quick Claw guardada', per: 1, max: 1, base: 900 },
  balloon: { label: 'Começa com um Air Balloon guardado', per: 1, max: 1, base: 900 },
  brightPowder: { label: 'Começa com um Bright Powder guardado', per: 1, max: 1, base: 1000 },
  boots: { label: 'Começa com Heavy-Duty Boots guardadas', per: 1, max: 1, base: 900 },
  kingsRock: { label: 'Começa com uma King\'s Rock guardada', per: 1, max: 1, base: 1000 },
  loot: { label: 'Treinadores pagam +{0}% de dinheiro', per: 5, max: 5, base: 300 },
  expertBelt: { label: 'Começa com uma Expert Belt guardada', per: 1, max: 1, base: 1200 },
  bonusCoins: { label: 'Mais +{0}% de moedas no fim da corrida', per: 10, max: 5, base: 900 },
  policy: { label: 'Começa com uma Weakness Policy guardada', per: 1, max: 1, base: 1500 },
  muscleBand: { label: 'Começa com uma Muscle Band guardada', per: 1, max: 1, base: 1000 },
  wiseGlasses: { label: 'Começa com Wise Glasses guardado', per: 1, max: 1, base: 1000 },
  shellBell: { label: 'Começa com um Shell Bell guardado', per: 1, max: 1, base: 1100 },
  scopeLens: { label: 'Começa com uma Scope Lens guardada', per: 1, max: 1, base: 1600 },
  eviolite: { label: 'Começa com um Eviolite guardado', per: 1, max: 1, base: 1600 },
  victoryHeal: { label: 'Depois de cada vitória, o time recupera {0}% do HP', per: 4, max: 3, base: 900 },
}
/**
 * O efeito das melhorias da árvore grande, aplicado no começo da corrida:
 * ['bag', item] (+nível na Bolsa), ['stash', item] (guardado para segurar),
 * ['token', ficha], ['boost', atributo] (+nível% no time), ['boostAll'],
 * ['mult', 'exp' | 'money'] (+valor%) e ['coins'] (+valor% de moedas no fim).
 */
export const UPGRADE_FX = {
  superPotions: ['bag', 'super-potion'],
  hyperPotions: ['bag', 'hyper-potion'],
  maxPotions: ['bag', 'max-potion'],
  sitrus: ['stash', 'sitrus-berry'],
  lum: ['stash', 'lum-berry'],
  leftovers: ['stash', 'leftovers'],
  sash: ['stash', 'focus-sash'],
  ultraBalls: ['bag', 'ultra-ball'],
  masterBall: ['bag', 'master-ball'],
  quickBalls: ['catch', 'rate'],
  netBalls: ['catch', 'rate'],
  timerBalls: ['catch', 'rate'],
  duskBalls: ['catch', 'rate'],
  expPlus: ['mult', 'exp'],
  luckyEgg: ['stash', 'lucky-egg'],
  hpBoost: ['boost', 'hp'],
  speBoost: ['boost', 'spe'],
  tutor: ['token', 'move-tutor'],
  reminder: ['token', 'move-reminder'],
  atk: ['boost', 'atk'],
  spa: ['boost', 'spa'],
  def: ['boost', 'def'],
  spd: ['boost', 'spd'],
  allStats: ['boostAll', 'all'],
  band: ['stash', 'choice-band'],
  scarf: ['stash', 'choice-scarf'],
  specs: ['stash', 'choice-specs'],
  lifeOrb: ['stash', 'life-orb'],
  vest: ['stash', 'assault-vest'],
  helmet: ['stash', 'rocky-helmet'],
  quickClaw: ['stash', 'quick-claw'],
  balloon: ['stash', 'air-balloon'],
  brightPowder: ['stash', 'bright-powder'],
  boots: ['stash', 'heavy-duty-boots'],
  kingsRock: ['stash', 'kings-rock'],
  loot: ['mult', 'money'],
  expertBelt: ['stash', 'expert-belt'],
  bonusCoins: ['coins', 'all'],
  policy: ['stash', 'weakness-policy'],
  muscleBand: ['stash', 'muscle-band'],
  wiseGlasses: ['stash', 'wise-glasses'],
  shellBell: ['stash', 'shell-bell'],
  scopeLens: ['stash', 'scope-lens'],
  eviolite: ['stash', 'eviolite'],
  victoryHeal: ['heal', 'hp'],
}
/**
 * A árvore de melhorias: cada ramo começa numa raiz e o resto pede a anterior
 * num nível (needs), um andar recorde (best) e quantos Pokémon você já tem
 * para começar (owned). Cada nível a mais pede 3 andares a mais de recorde.
 */
export const UPGRADE_TREE = {
  ivs: { needs: ['level', 2], best: 8 },
  revive: { needs: ['potions', 2], best: 6 },
  shop: { needs: ['money', 2], best: 6 },
  exp: { needs: ['ivs', 2], best: 12 },
  expShare: { needs: ['exp', 3], best: 20, owned: 3 },
  reroll: { needs: ['map', 1], best: 15 },
  cards: { needs: ['reroll', 1], best: 25, owned: 8 },
  shiny: { needs: ['greatBalls', 2], best: 15, owned: 5 },
  greatBalls: { needs: ['balls', 2], best: 10 },
  rope: { needs: ['revive', 1], best: 12 },
  coins: { needs: ['shop', 2], best: 12 },
  map: { best: 10 },
  dmax: { best: 20, owned: 4 },
  tera: { needs: ['dmax', 1], best: 30, owned: 6 },
  superPotions: { needs: ['potions', 2], best: 6 },
  hyperPotions: { needs: ['superPotions', 2], best: 14 },
  maxPotions: { needs: ['hyperPotions', 2], best: 24 },
  sitrus: { needs: ['superPotions', 1], best: 10 },
  lum: { needs: ['sitrus', 1], best: 16 },
  leftovers: { needs: ['revive', 2], best: 15 },
  sash: { needs: ['rope', 1], best: 22 },
  ultraBalls: { needs: ['greatBalls', 2], best: 18 },
  masterBall: { needs: ['ultraBalls', 3], best: 40, owned: 10 },
  quickBalls: { needs: ['balls', 3], best: 12 },
  netBalls: { needs: ['quickBalls', 1], best: 14 },
  timerBalls: { needs: ['netBalls', 1], best: 18 },
  duskBalls: { needs: ['quickBalls', 1], best: 14 },
  expPlus: { needs: ['exp', 5], best: 25 },
  luckyEgg: { needs: ['expShare', 1], best: 30 },
  hpBoost: { needs: ['ivs', 2], best: 10 },
  speBoost: { needs: ['hpBoost', 3], best: 15 },
  tutor: { needs: ['level', 2], best: 10 },
  reminder: { needs: ['tutor', 1], best: 12 },
  atk: { best: 5 },
  spa: { needs: ['atk', 2], best: 8 },
  def: { needs: ['atk', 2], best: 8 },
  spd: { needs: ['def', 2], best: 12 },
  allStats: { needs: ['spd', 5], best: 30, owned: 6 },
  band: { needs: ['atk', 5], best: 20 },
  scarf: { needs: ['band', 1], best: 30 },
  specs: { needs: ['spa', 5], best: 20 },
  lifeOrb: { needs: ['spa', 3], best: 25 },
  vest: { needs: ['spd', 3], best: 25 },
  helmet: { needs: ['def', 3], best: 18 },
  quickClaw: { needs: ['map', 1], best: 12 },
  balloon: { needs: ['quickClaw', 1], best: 18 },
  brightPowder: { needs: ['balloon', 1], best: 24 },
  boots: { needs: ['map', 1], best: 14 },
  kingsRock: { needs: ['boots', 1], best: 20 },
  loot: { needs: ['money', 2], best: 8 },
  expertBelt: { needs: ['loot', 3], best: 20 },
  bonusCoins: { needs: ['coins', 5], best: 35 },
  policy: { needs: ['dmax', 1], best: 25 },
  muscleBand: { needs: ['dmax', 1], best: 22 },
  wiseGlasses: { needs: ['muscleBand', 1], best: 24 },
  shellBell: { needs: ['wiseGlasses', 1], best: 28 },
  scopeLens: { needs: ['tera', 1], best: 32 },
  eviolite: { needs: ['tera', 1], best: 34 },
  victoryHeal: { needs: ['revive', 1], best: 10 },
}
/** Os ramos da árvore, na ordem (da raiz para a ponta). */
const BASE_BRANCHES = [
  ['🧪', 'Sobrevivência', ['potions', 'revive', 'rope', 'sash', 'leftovers', 'victoryHeal', 'superPotions', 'hyperPotions', 'maxPotions', 'sitrus', 'lum']],
  ['🎯', 'Captura', ['balls', 'greatBalls', 'shiny', 'ultraBalls', 'masterBall', 'quickBalls', 'netBalls', 'timerBalls', 'duskBalls']],
  ['🎓', 'Treino', ['level', 'ivs', 'exp', 'expShare', 'luckyEgg', 'expPlus', 'hpBoost', 'speBoost', 'tutor', 'reminder']],
  ['⚔️', 'Combate', ['atk', 'spa', 'specs', 'lifeOrb', 'def', 'spd', 'allStats', 'vest', 'helmet', 'band', 'scarf']],
  ['🧭', 'Exploração', ['map', 'reroll', 'cards', 'quickClaw', 'balloon', 'brightPowder', 'boots', 'kingsRock']],
  ['💰', 'Comércio', ['money', 'shop', 'coins', 'bonusCoins', 'loot', 'expertBelt']],
  ['⚡', 'Poder', ['dmax', 'tera', 'scopeLens', 'eviolite', 'policy', 'muscleBand', 'wiseGlasses', 'shellBell']],
]
/**
 * Os nós da trilha de cada melhoria (como nas árvores de habilidade dos jogos):
 * de cada melhoria saem MINOR_LENGTH nós do tema do ramo ("atk~1"...), cada um
 * com um nível só e um efeito que se sente na corrida: atributos, itens na
 * Bolsa, XP e dinheiro, nível e IVs do inicial, dinheiro no começo, desconto
 * na loja, cura depois de cada vitória, fichas de golpe, Sitrus Berry e
 * sortear o caminho. O texto, o nome e o símbolo são os da melhoria grande do
 * mesmo efeito (MINOR_BASE). Eram 8 nós por melhoria; agora é 1, mais
 * forte: cada ramo dá o mesmo total de cada efeito (LEGACY_LENGTH), com bem
 * menos para comprar. Igual ao app.
 */
export const MINOR_LENGTH = 1
/**
 * A árvore fica forte mais para o fim, em curva: a força de um nó pela profundidade (o recorde que ele pede) sobe
 * pouco no começo e cada vez mais depois (8% no começo, 31% no recorde 20, 60% no 30 e 100% no 40). O preço também
 * sobe em curva com a profundidade (1,1× no começo, 9× no recorde 40). Igual ao app.
 */
export const depthPower = (best) => Math.min(1, 0.08 + 0.92 * (best / 40) ** 2)
export const depthPrice = (best) => 1 + (best / 10) ** 1.5
/** O segundo nó da trilha é o nó-chave (só no desenho). */
export const KEYSTONE_EVERY = 2
/**
 * A trilha antiga (8 nós, o 4º e o 8º valendo o dobro): o total de cada efeito
 * no ramo continua o mesmo, e quem tinha nós que saíram recebe as moedas de
 * volta pelo preço de então.
 */
const LEGACY_LENGTH = 8
const LEGACY_KEYSTONE = 4
export const legacyMinorPrice = (parentBase, k) => Math.round((parentBase * 0.4 + 120 * k) / 10) * 10 * (k % LEGACY_KEYSTONE === 0 ? 2 : 1)
/** O máximo de níveis a mais no inicial pelos nós da trilha. */
export const MAX_START_LEVEL = 15
export const MINOR_FX = {
  Sobrevivência: [['heal', 'hp'], ['boost', 'hp'], ['bag', 'potion'], ['boost', 'def'], ['bag', 'revive'], ['boost', 'spd'], ['bag', 'super-potion'], ['stash', 'sitrus-berry']],
  Captura: [['bag', 'poke-ball'], ['catch', 'rate'], ['bag', 'great-ball'], ['catch', 'rate'], ['bag', 'ultra-ball'], ['catch', 'rate'], ['shiny', 'rate']],
  Treino: [['level', 'start'], ['mult', 'exp'], ['ivs', 'start'], ['boost', 'spe'], ['token', 'move-tutor'], ['token', 'move-reminder']],
  Combate: [['boost', 'atk'], ['boost', 'spa'], ['boost', 'spe'], ['boostAll', 'all'], ['boost', 'def'], ['boost', 'spd']],
  Exploração: [['mult', 'money'], ['heal', 'hp'], ['mult', 'exp'], ['boost', 'spe'], ['reroll', 'route']],
  Comércio: [['money', 'start'], ['mult', 'money'], ['discount', 'shop'], ['coins', 'all']],
  Poder: [['boostAll', 'all'], ['boost', 'atk'], ['boost', 'spa'], ['stash', 'life-orb']],
}
/** Quanto cada nó dá (o nó-chave, o dobro). */
export const MINOR_PER = {
  boost: 2, boostAll: 1, mult: 5, coins: 5, level: 1, ivs: 2, money: 150, discount: 2, heal: 2, token: 1, stash: 1, reroll: 1, catch: 5, shiny: 1,
  'bag:poke-ball': 3, 'bag:great-ball': 2, 'bag:ultra-ball': 1,
  'bag:potion': 2, 'bag:super-potion': 1, 'bag:revive': 1, 'bag:escape-rope': 1,
}
/** A melhoria grande que dá o texto, o nome e o símbolo de cada efeito pequeno. */
export const MINOR_BASE = {
  'boost:hp': 'hpBoost', 'boost:atk': 'atk', 'boost:def': 'def', 'boost:spa': 'spa', 'boost:spd': 'spd', 'boost:spe': 'speBoost',
  'boostAll:all': 'allStats', 'mult:exp': 'expPlus', 'mult:money': 'loot', 'coins:all': 'bonusCoins',
  'bag:potion': 'potions', 'bag:revive': 'revive', 'bag:poke-ball': 'balls', 'bag:great-ball': 'greatBalls', 'bag:ultra-ball': 'ultraBalls',
  'bag:quick-ball': 'quickBalls', 'bag:escape-rope': 'rope', 'bag:super-potion': 'superPotions', 'catch:rate': 'quickBalls',
  'token:move-tutor': 'tutor', 'token:move-reminder': 'reminder', 'stash:sitrus-berry': 'sitrus', 'stash:life-orb': 'lifeOrb', 'reroll:route': 'reroll',
  'level:start': 'level', 'ivs:start': 'ivs', 'money:start': 'money', 'discount:shop': 'shop', 'heal:hp': 'victoryHeal',
  'shiny:rate': 'shiny',
}
/** O texto próprio de um efeito pequeno (quando o da melhoria grande não serve). */
export const MINOR_LABEL = { 'shiny:rate': '+{0}× de chance de shiny' }
/** O máximo de shiny mais comum (20×: 1 em ~205). */
export const MAX_SHINY_RATE = 20
/** Efeitos que entraram na trilha depois dos 8 nós (não tiram nada dos antigos): quanto cada nó dá. */
export const NEW_MINOR_FX = { 'shiny:rate': 2 }
/** A melhoria grande de um nó pequeno ("atk~3" → "atk"), ou ele mesmo. */
export const minorOf = (id) => id.split('~')[0]
export const isMinor = (id) => id.includes('~')
/** O nó-chave: o último da trilha (o dobro do efeito). */
export const isKeystone = (id) => isMinor(id) && Number(id.split('~')[1]) % KEYSTONE_EVERY === 0
export const UPGRADE_BRANCHES = BASE_BRANCHES.map(([icon, branch, ids]) => {
  const fx = MINOR_FX[branch]
  const key = ([kind, arg]) => `${kind}:${arg}`
  // Quanto cada efeito dava no ramo inteiro (8 nós por melhoria, sem os efeitos novos) e em quantos nós ele fica agora.
  const old = fx.filter((f) => NEW_MINOR_FX[key(f)] == null)
  const legacy = {}, now = {}
  ids.forEach((_, i) => {
    for (let k = 1; k <= LEGACY_LENGTH; k++) {
      const f = key(old[(i + k - 1) % old.length])
      legacy[f] = (legacy[f] ?? 0) + (k % LEGACY_KEYSTONE === 0 ? 2 : 1)
    }
    for (let k = 1; k <= MINOR_LENGTH; k++) {
      const f = key(fx[(i + k - 1) % fx.length])
      now[f] = (now[f] ?? 0) + 1
    }
  })
  const list = []
  ids.forEach((parent, i) => {
    list.push(parent)
    for (let k = 1; k <= MINOR_LENGTH; k++) {
      const id = `${parent}~${k}`
      const [kind, arg] = fx[(i + k - 1) % fx.length]
      const per = MINOR_PER[`${kind}:${arg}`] ?? MINOR_PER[kind]
      const f = `${kind}:${arg}`
      const best = (UPGRADE_TREE[parent]?.best ?? 0) + 2 * k
      // Forte no fim, não no começo: o nó vale de 15% (os primeiros) a 100% (os do fundo da árvore) e custa mais quanto
      // mais fundo ele está (depthPrice).
      const base = Math.round(((UPGRADES[parent].base * 0.4 + 120 * k) * depthPrice(best)) / 10) * 10
      UPGRADES[id] = { label: MINOR_LABEL[`${kind}:${arg}`] ?? UPGRADES[MINOR_BASE[`${kind}:${arg}`]].label, per: NEW_MINOR_FX[f] ?? Math.max(per, Math.round(((per * legacy[f]) / now[f]) * depthPower(best))), max: 1, base }
      UPGRADE_FX[id] = [kind, arg]
      UPGRADE_TREE[id] = { needs: [k === 1 ? parent : `${parent}~${k - 1}`, 1], best }
      list.push(id)
    }
  })
  return [icon, branch, list]
})
/** A soma das melhorias de um efeito (nível do inicial, desconto, cura...). */
export const fxTotal = (factory, kind) => Object.entries(UPGRADE_FX).reduce((n, [k, [fx]]) => n + (fx === kind ? upgradeValue(factory, k) : 0), 0)
/** O máximo de cura depois de cada vitória e de desconto na loja. */
export const MAX_WIN_HEAL = 50
/** O máximo de captura mais fácil (% a mais na taxa). */
export const MAX_CATCH = 150
export const MAX_DISCOUNT = 50
export const UPGRADE_LEVEL_BEST = 3
/** O que falta para comprar o próximo nível: [{kind: 'up', id, level} | {kind: 'best', floor} | {kind: 'owned', count}] (vazio: pode). */
/**
 * Os itens que caem de chefes específicos e destravam partes da árvore (o nó
 * da trilha e os níveis altos das melhorias grandes): Key Stone (chefe com
 * Mega) para Combate e Poder; Sparkling Stone (Z-Move) para Treino e
 * Sobrevivência; Comet Shard (Dynamax, Gigantamax ou Tera) para Exploração e
 * Comércio; Relic Crown (lendário ou mítico) para Captura. Igual ao app.
 */
export const PIECE_ITEMS = ['key-stone', 'sparkling-stone', 'comet-shard', 'relic-crown']
export const PIECE_OF_BRANCH = {
  Combate: 'key-stone', Poder: 'key-stone', Treino: 'sparkling-stone', Sobrevivência: 'sparkling-stone',
  Exploração: 'comet-shard', Comércio: 'comet-shard', Captura: 'relic-crown',
}
/** O item que a melhoria (ou o nó da trilha dela) pede: o do ramo dela. */
export function pieceOf(id) {
  const branch = BASE_BRANCHES.find(([, , ids]) => ids.includes(minorOf(id)))
  return branch ? PIECE_OF_BRANCH[branch[1]] : PIECE_ITEMS[0]
}
/**
 * Quantos o próximo nível pede: o nó da trilha, 1; a melhoria grande, do 3º
 * nível em diante, 1 a mais por nível (3º: 1, 4º: 2...). Igual ao app.
 */
export const upgradePieces = (factory, id) => (isMinor(id) ? 1 : Math.max(0, upgradeLevel(factory, id) + 1 - 2))
/** Quantos de cada item a conta (ou a corrida) tem. */
export const piecesOf = (owner) => Object.fromEntries(PIECE_ITEMS.map((item) => [item, (owner?.pieces && typeof owner.pieces === 'object' ? owner.pieces[item] : 0) ?? 0]))
const addPieces = (a, b) => Object.fromEntries(PIECE_ITEMS.map((item) => [item, (a[item] ?? 0) + (b[item] ?? 0)]))
/** A troca dos itens da árvore: 3 de um por 1 de outro (null se não tem 3). Igual ao app. */
export const PIECE_TRADE = 3
export function tradePieces(factory, from, to) {
  const have = piecesOf(factory)
  if (from === to || !PIECE_ITEMS.includes(from) || !PIECE_ITEMS.includes(to) || have[from] < PIECE_TRADE) return null
  return { ...factory, pieces: { ...have, [from]: have[from] - PIECE_TRADE, [to]: have[to] + 1 } }
}
/**
 * O que um andar vencido deixa: cada adversário com Mega, Z-Move,
 * Dynamax/Gigantamax/Tera, ou lendário/mítico, um item do tipo dele. Igual ao app.
 */
export function piecesFor(data, run) {
  const out = {}
  for (const f of run.encounter?.foes ?? []) {
    const rarity = speciesOf(data, f.id)?.[2] ?? 0
    const item = f.gimmick === 'mega' ? 'key-stone' : f.gimmick === 'z' ? 'sparkling-stone' : f.gimmick === 'dmax' || f.gimmick === 'tera' ? 'comet-shard'
      : f.title === 'legend' || rarity === 1 || rarity === 2 ? 'relic-crown' : null
    if (item) out[item] = (out[item] ?? 0) + 1
  }
  return out
}
export function upgradeNeeds(factory, id) {
  const node = UPGRADE_TREE[id] ?? {}
  const out = []
  if (node.needs && upgradeLevel(factory, node.needs[0]) < node.needs[1]) out.push({ kind: 'up', id: node.needs[0], level: node.needs[1] })
  const best = (node.best ?? 0) + UPGRADE_LEVEL_BEST * upgradeLevel(factory, id)
  if ((factory.best ?? 0) < best) out.push({ kind: 'best', floor: best })
  if (node.owned && (factory.owned?.length ?? 0) < node.owned) out.push({ kind: 'owned', count: node.owned })
  const pieces = upgradePieces(factory, id)
  if (pieces > piecesOf(factory)[pieceOf(id)]) out.push({ kind: 'pieces', item: pieceOf(id), count: pieces })
  return out
}
export const upgradeLevel = (factory, id) => factory.upgrades?.[id] ?? 0
/** O bônus da melhoria no nível dela (nível × por nível). */
export const upgradeValue = (factory, id) => upgradeLevel(factory, id) * UPGRADES[id].per
/** Preço do próximo nível (null no máximo). */
export function upgradePrice(factory, id) {
  const level = upgradeLevel(factory, id)
  const up = UPGRADES[id]
  // As melhorias grandes: mais caras quanto mais fundo na árvore (os nós da trilha já têm a profundidade no preço).
  return !up || level >= up.max ? null : Math.round((up.base * (level + 1) ** 1.6 * (isMinor(id) ? 1 : 1 + (UPGRADE_TREE[id]?.best ?? 0) / 20)) / 5) * 5
}
/** Compra o próximo nível da melhoria (null se não dá). */
export function buyUpgrade(factory, id) {
  const price = upgradePrice(factory, id)
  if (price == null || factory.coins < price || upgradeNeeds(factory, id).length) return null
  const pieces = upgradePieces(factory, id)
  return { ...factory, coins: factory.coins - price, ...(pieces ? { pieces: { ...piecesOf(factory), [pieceOf(id)]: piecesOf(factory)[pieceOf(id)] - pieces } } : {}), upgrades: { ...factory.upgrades, [id]: upgradeLevel(factory, id) + 1 } }
}

/** Moedas que a corrida rende: 8 por andar vencido, 2 por Pokémon derrotado e 40 por chefe. */
export const runCoins = (run) => (run.floor - 1) * 8 + run.defeated * 2 + (run.bosses ?? 0) * 40
/** O treinador forte do fim da rota: sem mecânica (Mega, Z, Tera, Dynamax) e só 1 nível acima antes deste andar. Igual ao app. */
export const DBOSS_GIMMICK_FLOOR = 30
/** Quantos Pokémon ele traz: 2 até o andar 20, 3 até o 40, 4 até o 60 e depois o time todo. Igual ao app. */
export const dbossTeam = (floor) => (floor < 20 ? 2 : floor < 40 ? 3 : floor < 60 ? 4 : 6)

// ------------------------------------------------------------ Pokémon da corrida

/** Espécie (para XP, EVs e evolução) de um id, que pode ser uma forma regional. */
const speciesOf = (data, id) => data.species[id] ?? data.formSpecies?.[id] ?? data.species[data.forms?.[id]] ?? null

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
/**
 * Habilidades fora da batalha (como nos jogos), de quem as tem no time:
 * Pickup acha itens depois das batalhas; Intimidate (em quem vai na frente)
 * às vezes espanta os selvagens; Synchronize (em quem vai na frente) passa a
 * Nature para o capturado. Igual ao app.
 */
export const PICKUP = [52, 53, 190, 424, 216, 231, 263, 264, 417, 446, 506, 659, 660, 674, 702, 819, 820]
export const INTIMIDATE = [23, 24, 58, 59, 128, 130, 209, 210, 234, 237, 262, 284, 303, 373, 397, 398, 403, 404, 405, 507, 508, 551, 552, 553, 559, 560, 667, 668, 727]
export const SYNCHRONIZE = [63, 64, 65, 151, 177, 178, 196, 197, 280, 281, 282]
export const PICKUP_CHANCE = 0.12
/** A chance de o Pokémon que segue você achar um item depois da vitória. */
export const FOLLOW_FIND = 0.05
/** Um número de 0 a 1 que só depende da semente, do andar e de `k` (igual ao app). */
export const followRoll = (run, k) => (Math.imul(((run.seed ?? 0) ^ (run.floor * 48271)) | 0, k | 0) >>> 0) / 4294967296
export const PICKUP_ITEMS = ['potion', 'poke-ball', 'super-potion', 'great-ball', 'revive', 'hyper-potion', 'ultra-ball']
export const INTIMIDATE_CHANCE = 0.5
/** Quem vai na frente (o primeiro de pé na batalha). */
const leadOf = (run) => run.team[battleOrder(run)[0]]

/**
 * Amizade: quem está no time ganha um ponto a cada andar vencido; com
 * FRIEND_EVOLVE, os que evoluem por amizade evoluem (Eevee: Espeon de dia,
 * Umbreon à noite, pelo relógio). Igual ao app.
 */
export const FRIEND_EVOLVE = 10
export const FRIEND_EVOS = {
  133: [196, 197], 42: 169, 113: 242, 172: 25, 173: 35, 174: 39, 175: 176, 298: 183, 406: 315, 427: 428, 433: 358, 440: 113,
  446: 143, 447: 448, 527: 528, 541: 542, 772: 773, 872: 873,
  // Meowth de Alola: Persian de Alola pela amizade.
  10107: 10108,
}
const friendTargets = (id) => [FRIEND_EVOS[id]].flat()

/** Eevee com um golpe de Fada vira Sylveon pela amizade (como nos jogos). Igual ao app. */
export const FAIRY_MOVES = ['baby-doll-eyes', 'charm', 'disarming-voice', 'draining-kiss', 'fairy-wind', 'dazzling-gleam', 'moonblast', 'play-rough', 'alluring-voice', 'sweet-kiss']

/** Shedinja: quando o Nincada vira Ninjask com vaga no time, ele aparece junto (como nos jogos). Igual ao app. */
export function withShedinja(run, before, after, rand) {
  const out = [...after]
  before.forEach((m, i) => {
    if (m.id === 290 && after[i]?.id === 291 && out.length < teamRoom(run)) out.push(newMon(292, after[i].level, rand, 0, Boolean(m.shiny)))
  })
  return out
}

/** Eventos raros na rota (a partir do andar RARE_FLOOR): chuva de meteoros (Clefairy, com mais chance de shiny) e um Pokémon mítico. */
export const RARE_FLOOR = 8
export const RARE_CHANCE = 0.04
export const MYTHICS = [151, 251, 385, 386, 490, 491, 492, 494, 647, 648, 719, 720, 721, 801, 802, 807, 893]

/** region: a região da perna da corrida (as evoluções de lá: Pikachu → Raichu de Alola, Stantler → Wyrdeer em Hisui). */
export function levelTo(mon, level, data, rand, region = null) {
  let out = { ...mon, level: Math.max(1, level) }
  out.exp = Math.max(out.exp, expAt(out.level))
  let evolved = null
  for (let guard = 0; guard < 3; guard++) {
    // Evoluções por item (pedras) só com o item: canEvolveWith/buyItem.
    // As por amizade (FRIEND_EVOS) não são por nível (a Eevee, só por pedra ou amizade).
    const friends = FRIEND_EVOS[out.id] ? (out.id === 133 ? null : friendTargets(out.id)) : []
    const options = evolutionsOf(data, out, region).filter(([to, at, item]) => !item && out.level >= at && friends && !friends.includes(to))
    if (!options.length) break
    // Tyrogue: como nos jogos, pelo Ataque e pela Defesa (Hitmonlee, Hitmonchan ou Hitmontop).
    const to = out.id === 236 ? tyrogue(out) : pickOne(options, rand)[0]
    out = { ...out, id: evolvedForm(data, out, to, region) }
    evolved = out.id
  }
  return [out, evolved]
}

/**
 * As evoluções de quem está no time: as da espécie (ou da forma regional), as
 * que só existem na região e só as do gênero dele (Combee, Burmy, Salandit,
 * Kirlia e Snorunt com a Dawn Stone). Igual ao app.
 */
export function evolutionsOf(data, mon, region = null) {
  const gender = genderOf(data, mon)
  const rule = data.regional?.gender ?? {}
  return [...(data.evolutions[mon.id] ?? []), ...(data.regional?.regionEvos?.[region]?.[mon.id] ?? [])].filter((e) => rule[e[0]] == null || rule[e[0]] === gender)
}

/** A forma em que ele evolui: a feminina (Meowstic, Oinkologne, Basculegion) e a da região (Raichu de Alola...). */
export function evolvedForm(data, mon, to, region = null) {
  const female = data.regional?.femaleForm?.[to]
  if (female != null && genderOf(data, mon) === 'F') return female
  return data.regional?.evolveIn?.[region]?.[to] ?? to
}

/**
 * O gênero ('M', 'F' ou null sem gênero), pela chance da espécie e fixo para
 * cada Pokémon (pelos IVs e pela Nature, como nos primeiros jogos). Igual ao app.
 */
export function genderOf(data, mon) {
  const rate = speciesOf(data, mon.id)?.[7] ?? -1
  if (rate < 0) return null
  const primes = [7, 3, 5, 11, 13, 17]
  const h = STATS.reduce((n, s, i) => n + (mon.ivs?.[s] ?? 0) * primes[i], NATURE_LIST.indexOf(mon.nature) + 1)
  return h % 8 < rate ? 'F' : 'M'
}

/** Tyrogue: Ataque maior → Hitmonlee; Defesa maior → Hitmonchan; iguais → Hitmontop (o Tyrogue tem 35 nos dois). */
function tyrogue(mon) {
  const n = NATURE_LIST.indexOf(mon.nature)
  const stat = (s, k) => {
    const mod = n < 0 || Math.floor(n / 5) === n % 5 ? 1 : Math.floor(n / 5) === k ? 1.1 : n % 5 === k ? 0.9 : 1
    return Math.floor((Math.floor(((70 + (mon.ivs?.[s] ?? 0) + Math.floor((mon.evs?.[s] ?? 0) / 4)) * mon.level) / 100) + 5) * mod)
  }
  const atk = stat('atk', 0), def = stat('def', 1)
  return atk > def ? 106 : atk < def ? 107 : 237
}

/** A região da perna da corrida (Kanto, Alola, Galar...; Hisui fica nas pernas de Sinnoh). */
export const regionOf = (data, run) => data.bosses?.[run?.boss?.region]?.region ?? null

/**
 * Os selvagens (e os Pokémon dos treinadores do caminho) na forma da região:
 * Meowth de Galar, Vulpix de Alola... Os chefes ficam com os times dos jogos. Igual ao app.
 */
export function regionalEncounter(data, run, encounter) {
  if (['boss', 'rival', 'rematch'].includes(encounter.kind)) return encounter
  // Modo formas regionais: a da região de agora e, sem ela, a primeira que existir (Alola, Galar, Hisui, Paldea).
  const all = data.regional?.forms ?? {}
  const forms = run.regionalAll ? { ...all.Paldea, ...all.Sinnoh, ...all.Galar, ...all.Alola, ...all[regionOf(data, run)] } : all[regionOf(data, run)]
  if (!forms) return encounter
  return { ...encounter, foes: (encounter.foes ?? []).map((f) => ({ ...f, id: forms[f.id] ?? f.id })) }
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
export const expFactor = (kind) => (kind === 'ace' || kind === 'rematch' || kind === 'rival' || kind === 'dboss' ? 1.75 : kind === 'boss' || kind === 'wildboss' || kind === 'trainer' ? 1.5 : 1)

/** A barra de XP: quanto do nível atual já foi (0 a 1), com o XP a mais (extra). */
export function expProgress(mon, extra = 0) {
  const from = expAt(mon.level), to = expAt(mon.level + 1)
  return Math.max(0, Math.min(1, ((mon.exp ?? from) + extra - from) / (to - from)))
}

/** Ganha XP: sobe os níveis que der. */
function gainExp(mon, exp, data, rand, region = null) {
  const total = mon.exp + exp
  let level = mon.level
  while (total >= expAt(level + 1)) level++
  const [out, evolved] = level > mon.level ? levelTo({ ...mon, exp: total }, level, data, rand, region) : [{ ...mon, exp: total }, null]
  return { mon: out, from: mon.level, evolved }
}

// ------------------------------------------------------------ andares

/** O chefe da vez: o jogo sorteado no começo, na ordem da história (líderes com rival e vilões no meio, Elite dos Quatro, Campeão). */
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
  const pre = preEvolutions(data).get(id) ?? preEvolutions(data).get(data.forms?.[id])
  if (!pre) return 1
  return Math.max(pre[1] || ITEM_EVOLUTION_LEVEL, minLevelOf(data, pre[0]))
}
/** Abaixo do nível em que evolui, volta para a forma anterior (um Sceptile nível 2 é um Treecko), como nos jogos. */
export function devolve(data, id, level) {
  let out = id
  for (let guard = 0; guard < 4 && minLevelOf(data, out) > level; guard++) {
    const pre = preEvolutions(data).get(out) ?? preEvolutions(data).get(data.forms?.[out])
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
  ruins: ['rock', 'psychic', 'ground', 'ghost'],
  flowers: ['fairy', 'grass', 'bug', 'normal'],
  plant: ['electric', 'steel'],
  crystal: ['rock', 'steel', 'fairy', 'psychic'],
  dunes: ['ground', 'dark', 'ghost', 'bug'],
  bamboo: ['grass', 'fighting', 'bug', 'dark'],
  temple: ['psychic', 'fighting', 'dragon', 'ghost'],
  lavacave: ['fire', 'rock', 'ground'],
  poisoncave: ['poison', 'dark', 'bug'],
  seacave: ['water', 'rock'],
  waterfall: ['water', 'dragon', 'rock'],
}
/** Os lugares que podem ser de uma rota (a gruta da cachoeira só se entra pelo mar, com Waterfall). */
export const BIOME_IDS = Object.keys(BIOMES).filter((b) => b !== 'waterfall')
/** Quanto a mais aparecem os tipos do lugar (selvagens; nos treinadores, ROUTE_TYPE_TRAINER). */
export const ROUTE_TYPE_WEIGHT = 8
export const ROUTE_TYPE_TRAINER = 3
/** Os lugares possíveis da rota até o ginásio de cada tipo (um deles por rota). */
const TYPE_BIOMES = {
  normal: ['grass', 'city', 'flowers'], fire: ['volcano', 'desert'], water: ['water', 'beach'], grass: ['forest', 'grass', 'swamp', 'bamboo', 'flowers'],
  electric: ['city', 'sewer', 'plant'], ice: ['snow', 'icecave'], fighting: ['mountain', 'cave', 'bamboo', 'temple'], poison: ['swamp', 'sewer', 'forest'],
  ground: ['desert', 'mountain', 'cave', 'dunes'], flying: ['sky', 'grass', 'beach'], psychic: ['tower', 'city', 'temple', 'ruins'], bug: ['forest', 'grass', 'flowers'],
  rock: ['cave', 'mountain', 'desert', 'ruins', 'crystal'], ghost: ['tower', 'ruins', 'dunes'], dragon: ['sky', 'mountain', 'temple'], dark: ['cave', 'tower', 'sewer', 'dunes'],
  steel: ['mountain', 'city', 'cave', 'plant', 'crystal'], fairy: ['sky', 'forest', 'flowers'],
}
/**
 * As equipes vilãs (pelo nome de quem aparece nos jogos). Enquanto o próximo
 * chefe é um vilão, a rota é a base da equipe dele: só capangas, com os
 * Pokémon da equipe (TEAM_POKEMON); os executivos e o chefe aparecem ao longo
 * da história. Igual ao app.
 */
export const VILLAIN_TEAMS = {
  Giovanni: 'rocket', Executiva: 'rocket', Executivo: 'rocket', Proton: 'rocket', Ariana: 'rocket', Archer: 'rocket', Petrel: 'rocket',
  Archie: 'aqua', Shelly: 'aqua', Matt: 'aqua', Maxie: 'magma', Tabitha: 'magma', Courtney: 'magma',
  Mars: 'galactic', Cyrus: 'galactic', Jupiter: 'galactic', Saturn: 'galactic', N: 'plasma', Zinzolin: 'plasma', Colress: 'plasma', Ghetsis: 'plasma',
  Lysandre: 'flare', Bryony: 'flare', Mable: 'flare', Plumeria: 'skull', Guzma: 'skull', Faba: 'aether', Soliera: 'aether', Dulse: 'aether',
  Giacomo: 'star', Ortega: 'star', Mela: 'star', Atticus: 'star', Eri: 'star', Penny: 'star', Aliana: 'flare', Celosia: 'flare', Xerosic: 'flare',
  Rose: 'macro', Oleana: 'macro', 'Equipe Yell': 'yell',
}
export const villainTeam = (name) => VILLAIN_TEAMS[name] ?? 'rocket'
/** Os Pokémon dos capangas de cada equipe (os evoluídos só a partir do nível em que evoluem). */
export const TEAM_POKEMON = {
  rocket: [19, 20, 23, 24, 41, 42, 109, 110, 88, 89, 52, 53, 96, 97, 198, 228, 229],
  aqua: [318, 319, 261, 262, 72, 73, 41, 42, 320, 340],
  magma: [322, 323, 261, 262, 218, 219, 41, 42, 324, 74, 75],
  galactic: [431, 432, 434, 435, 41, 42, 169, 198, 436, 437],
  plasma: [509, 510, 504, 505, 551, 552, 559, 560, 519, 520, 524],
  flare: [667, 668, 659, 660, 686, 687, 228, 229, 674],
  skull: [757, 758, 451, 452, 41, 42, 88, 89, 742, 743],
  aether: [79, 80, 96, 97, 436, 437, 137, 233, 122],
  star: [198, 430, 41, 42, 559, 560, 434, 435, 109, 110, 966],
  // Equipe Yell (Galar): os de Sombrio que torcem pela Marnie (as formas de Galar de Zigzagoon e Linoone).
  yell: [10174, 10175, 827, 828, 509, 510, 559, 560, 261, 262],
  // Macro Cosmos (Rose Tower): os de Aço da empresa.
  macro: [599, 600, 624, 625, 598, 878, 879, 436, 437],
}
/** O tipo do líder de ginásio (o que mais aparece no time dele): o ginásio dele tem o cenário desse tipo. */
export function leaderType(data, boss) {
  const count = {}
  for (const id of boss.team ?? []) for (const t of speciesOf(data, id)?.[4] ?? []) count[t] = (count[t] ?? 0) + 1
  return Object.keys(count).sort((a, b) => count[b] - count[a])[0] ?? 'normal'
}
/**
 * O cenário da luta com o chefe: o líder no ginásio do tipo dele, a Elite dos Quatro
 * na Liga, o Campeão na sala dele (uma por região) e o vilão na base da equipe.
 * boss: o chefe do encontro ({id, kind, region, name}); fallback: o lugar da rota.
 */
export function bossScene(data, boss, fallback = 'grass') {
  if (!boss) return fallback
  if (boss.kind === 'gym') {
    const full = data.bosses.flatMap((g) => g.leaders).find((l) => l.id === boss.id)
    return `gym-${full ? leaderType(data, full) : 'normal'}`
  }
  if (boss.kind === 'champion') return `champion-${String(boss.region ?? '').toLowerCase()}`
  if (boss.kind === 'elite') return 'league'
  if (boss.kind === 'villain') return `base-${villainTeam(boss.name)}`
  return fallback
}

/** Na Dusk Ball (3×): os lugares escuros. */
export const DARK_BIOMES = ['cave', 'tower', 'icecave', 'sewer', 'underwater', 'lavacave', 'poisoncave', 'seacave']

/** Os chefes de cidade (líder no ginásio dele; Elite dos Quatro e Campeão na Liga). Rival e vilões aparecem na rota. */
const CITY_KINDS = ['gym', 'elite', 'champion']
/** Andares da rota (o 10º é o chefe dela); depois, os andares da cidade (o último é o líder). */
export const ROUTE_LENGTH = 10
export const CITY_LENGTH = 10
/** O andar do líder: o último da cidade (posição desde o começo da rota). */
export const CITY_BOSS = ROUTE_LENGTH + CITY_LENGTH - 1
/** Onde a rota se divide (posição na rota, a partir de 0): só ali dá para escolher o caminho. */
export const FORKS = [1, 4, 7]
/** Chance do rival (ou de um vilão) aparecer em cada andar da rota (a partir do 3º: dá tempo de treinar um pouco). */
export const AMBUSH_CHANCE = 0.3
/** O rival aparece bastante: de surpresa na rota (fora os da história), no máximo uma vez por rota, a partir do andar RIVAL_FLOOR. */
export const RIVAL_CHANCE = 0.2
export const RIVAL_FLOOR = 12
/** Jessie e James (Equipe Rocket): sem lugar fixo na história, aparecem de surpresa na rota (uma vez por rota, por sorteio). */
export const ROCKET_CHANCE = 0.05
/** Jessie e James da região (null em Paldea, onde eles não aparecem). Igual ao app. */
export function rocketBoss(data, run) {
  const game = data.bosses[run.boss.region]
  return game.rocket ? { region: game.region, game: game.game, ...game.rocket } : null
}

/** O próximo chefe de cidade (pula rival e vilões): o destino da rota. */
export function targetOf(data, run) {
  const leaders = data.bosses[run.boss.region].leaders
  let step = run.boss.step
  while (step < leaders.length - 1 && !CITY_KINDS.includes(leaders[step].kind)) step++
  return { step, ...leaders[step] }
}

/** Já está na Liga: depois da primeira da Elite dos Quatro, as lutas vêm uma atrás da outra (sem rota). */
const inLeague = (data, run) => {
  const leaders = data.bosses[run.boss.region].leaders
  const prev = leaders[run.boss.step - 1]
  return run.boss.step > 0 && ['elite', 'champion'].includes(leaders[run.boss.step].kind) && prev?.kind === 'elite'
}

/**
 * Onde está: 0 é o primeiro andar da rota depois da última cidade (run.leg);
 * de ROUTE_LENGTH em diante, a cidade (CITY_BOSS é o líder). Os andares feitos
 * num lugar (run.detour) não contam: depois dele, você volta para o andar em que entrou.
 */
export const routePos = (run) => run.floor - (run.leg ?? run.floor - ((run.floor - 1) % (ROUTE_LENGTH + CITY_LENGTH))) - (run.detour ?? 0)

/** Chegou no líder (o último andar da cidade) ou na Liga: o chefe dela é o próximo andar (dentro de um lugar, não). */
export function atCity(data, run) {
  return !run.dungeon && CITY_KINDS.includes(bossOf(data, run).kind) && (inLeague(data, run) || routePos(run) >= CITY_BOSS)
}

/**
 * O bioma da rota até a próxima cidade: o do tipo do ginásio (o tipo que mais
 * aparece no time do líder); para a Liga, um fixo da região.
 */
export function routeBiome(data, run) {
  // Dentro de um lugar (esgoto, casa assombrada, base da equipe vilã...): o cenário dele.
  if (run.dungeon) return run.dungeon.scene
  // A rota do jogo (o mapa da região, tool/factory_routes.py).
  const info = routeInfo(data, run)
  if (info) return info.biome === 'water' && routePos(run) < SHORE ? 'beach' : info.biome
  const boss = targetOf(data, run)
  if (boss.kind === 'gym') {
    const count = {}
    for (const id of boss.team) for (const t of speciesOf(data, id)?.[4] ?? []) count[t] = (count[t] ?? 0) + 1
    const top = Object.keys(count).sort((a, b) => count[b] - count[a])[0]
    // Um dos lugares do tipo, o mesmo na rota inteira (pela semente e o começo da rota), que se ligue ao da rota anterior.
    const all = TYPE_BIOMES[top]
    const linked = all?.filter((b) => biomesLinked(run.prevBiome, b))
    const list = linked?.length ? linked : all
    if (list) return list[((Math.imul(run.leg ?? 1, 2654435761 | 0) ^ run.seed) >>> 0) % list.length]
  }
  return BIOME_IDS[(run.boss.region * 7 + boss.step * 3) % BIOME_IDS.length]
}

/** O id de um lugar pelo nome ("Mt. Moon" → "mt-moon"). */
const placeId = (name) => name.toLowerCase().replace(/[^a-z0-9]+/g, '-')
const placeOf = (row) => (row ? { id: placeId(row[0]), name: row[0], scene: row[1] } : null)
/**
 * O cenário próprio dos lugares da cidade que usam o da cidade (loja, cassino,
 * escola, palco, metrô, navio, ponte, parque): só a imagem muda; os selvagens e
 * as regras continuam os da cidade. Igual ao app.
 */
export const PLACE_SCENES = {
  'nugget-bridge': 'bridge', 's-s-anne': 'ship', 'rocket-game-corner': 'casino', 'celadon-department-store': 'store',
  'goldenrod-department-store': 'store', 'mauville-game-corner': 'casino', 'lavaridge-herb-shop': 'store', 'hearthome-contest-hall': 'stage',
  'veilstone-department-store': 'store', 'veilstone-game-corner': 'casino', 'battle-subway': 'subway', 'nimbasa-amusement-park': 'park',
  'driftveil-market': 'store', 'pok-star-studios': 'stage', 'trainers-school': 'school', 'hau-oli-shopping-district': 'store',
}
/** O cenário que aparece (o próprio do lugar, se ele tiver). */
export const shownScene = (run, scene) => (run?.dungeon && PLACE_SCENES[run.dungeon.place]) || scene

/**
 * A rota até a próxima cidade, como nos jogos (tool/factory_routes.py): o
 * lugar dela, o nome, o lugar no caminho (side) e os da cidade (towns: esgoto,
 * museu, a praia dela...). null se a cidade não estiver no mapa. Igual ao app.
 */
export function routeInfo(data, run) {
  const region = data.bosses[run.boss.region].region
  const city = targetOf(data, run).city ?? ''
  const row = data.routes?.cities?.[`${region}:${city}`] ?? data.routes?.cities?.[city]
  const side = placeOf(row?.[2])
  return row ? { biome: row[0], name: row[1], side: side && { ...side, scene: caveScene(side.scene, row[0]) }, towns: (row[3] ?? []).map(placeOf) } : null
}

/**
 * A água, em ordem (não dá para pular): da praia (a rota ou a da cidade) para
 * o mar, dele para o fundo do mar e dali para a caverna aquática. Cada um é um
 * lugar de 10 andares com um chefe; vencendo, dá para seguir para o próximo ou voltar.
 */
export const WATER_CHAIN = [['beach', 'Praia', 'beach'], ['sea', 'Mar', 'water'], ['deep', 'Fundo do mar', 'underwater'], ['seacave', 'Caverna aquática', 'seacave']]
/** Numa rota de mar, os primeiros andares são a praia (a água começa por ela); depois, o mar. */
export const SHORE = FORKS[1] + 1
/** Os lugares sem treinadores: só selvagens, e o chefe é um selvagem forte de lá (dá para capturar). */
export const WILD_ONLY = ['water', 'underwater', 'seacave', 'icecave', 'lavacave', 'poisoncave', 'crystal', 'waterfall']
/** A gruta atrás da cachoeira: sobe a queda d'água do Mar com Waterfall (10 andares de selvagens e um chefe forte de lá). */
export const WATERFALL_PLACE = { id: 'waterfall', name: 'Gruta da cachoeira', scene: 'waterfall' }
/** A caverna combina com o lugar em volta: no gelo, de gelo; no pântano, venenosa; no vulcão, de lava; no mar, aquática. */
export const CAVE_OF = { snow: 'icecave', icecave: 'icecave', swamp: 'poisoncave', volcano: 'lavacave', beach: 'seacave', water: 'seacave', underwater: 'seacave' }
const caveScene = (scene, around) => (scene === 'cave' ? CAVE_OF[around] ?? 'cave' : scene)
/** O lugar da água depois deste cenário (null se não tem: a caverna aquática é o fim). */
export function waterNext(scene) {
  const k = WATER_CHAIN.findIndex(([, , s]) => s === scene)
  return k >= 0 && k < WATER_CHAIN.length - 1 ? { id: WATER_CHAIN[k + 1][0], name: WATER_CHAIN[k + 1][1], scene: WATER_CHAIN[k + 1][2] } : null
}

/** O nome e o cenário de um lugar (os genéricos, os da água ou os do mapa da região). */
export function placeInfo(data, run, id) {
  if (DUNGEONS[id]) return DUNGEONS[id]
  if (RARE_PLACES[id]) return RARE_PLACES[id]
  if (id === WATERFALL_PLACE.id) return WATERFALL_PLACE
  const water = WATER_CHAIN.find(([w]) => w === id)
  if (water) return { name: water[1], scene: water[2] }
  const info = routeInfo(data, run)
  return [info?.side, ...(info?.towns ?? [])].find((p) => p?.id === id) ?? { name: id, scene: 'cave' }
}

/** Sai do lugar (venceu o chefe ou usou a Escape Rope): volta para o andar em que entrou (na rota ou na cidade). */
function leavePlace(run, out) {
  const start = run.dungeon.entry ?? run.dungeon.start
  out.back = routePos({ ...run, floor: start })
  out.detour = (run.detour ?? 0) + out.floor - start
  out.dungeon = null
}

/**
 * As regiões de lugares que se ligam (a rota seguinte começa num lugar que faz
 * sentido depois da anterior: da caverna não se vai direto para o mar). Grama e
 * cidade se ligam a tudo. Igual ao app.
 */
export const BIOME_ZONES = [
  ['grass', 'flowers', 'forest', 'bamboo', 'swamp', 'city', 'plant', 'ruins', 'temple', 'sky', 'poisoncave'],
  ['beach', 'water', 'underwater', 'swamp', 'grass', 'city', 'seacave'],
  ['mountain', 'cave', 'icecave', 'crystal', 'volcano', 'snow', 'sky', 'temple', 'ruins', 'lavacave'],
  ['desert', 'dunes', 'volcano', 'ruins', 'beach', 'lavacave'],
  ['city', 'sewer', 'tower', 'plant'],
]
export const biomesLinked = (a, b) => !a || a === b || a === 'grass' || a === 'city' || b === 'grass' || b === 'city' || BIOME_ZONES.some((z) => z.includes(a) && z.includes(b))

/**
 * Os lugares com batalha perto das cidades (10 andares e um chefe no fim; depois
 * volta para a cidade). A base da equipe vilã também é um lugar desses (o
 * vilão é o chefe dela). Igual ao app.
 */
export const DUNGEON_LENGTH = 10
export const DUNGEONS = {
  sewer: { scene: 'sewer', name: 'Esgoto' },
  haunted: { scene: 'tower', name: 'Casa assombrada' },
  cave: { scene: 'cave', name: 'Caverna' },
  plant: { scene: 'plant', name: 'Usina abandonada' },
  ruins: { scene: 'ruins', name: 'Ruínas' },
  mine: { scene: 'crystal', name: 'Mina de cristal' },
  temple: { scene: 'temple', name: 'Templo' },
  icecave: { scene: 'icecave', name: 'Caverna de gelo' },
  volcano: { scene: 'volcano', name: 'Vulcão' },
}
export const DUNGEON_IDS = Object.keys(DUNGEONS)
/**
 * Os lugares raros (como nos jogos): às vezes aparecem numa bifurcação da rota
 * (RARE_PLACE_CHANCE). 10 andares só de selvagens e, no fim, o lendário do
 * lugar (dá para capturar); vencer deixa uma Master Ball. Igual ao app.
 */
export const RARE_PLACE_CHANCE = 0.05
export const RARE_PLACE_REWARD = 'master-ball'
export const RARE_PLACES = {
  'faraway-island': { scene: 'forest', name: 'Faraway Island', legends: [151], mythic: true },
  'navel-rock': { scene: 'mountain', name: 'Navel Rock', legends: [249, 250] },
  'bell-tower': { scene: 'tower', name: 'Bell Tower', legends: [250] },
  'distortion-world': { scene: 'ruins', name: 'Distortion World', legends: [487] },
  'cerulean-cave': { scene: 'crystal', name: 'Cerulean Cave', legends: [150] },
}
export const RARE_PLACE_IDS = Object.keys(RARE_PLACES)
/** O lendário que espera no fim do lugar raro (sempre o mesmo na corrida). */
export const rareLegend = (run, place) => { const l = RARE_PLACES[place]?.legends ?? []; return l.length ? l[((run.seed >>> 0) + run.floor) % l.length] : null }
/** O andar do lugar (0 a DUNGEON_LENGTH − 1; o último é o do chefe). */
export const dungeonPos = (run) => (run.dungeon ? run.floor - run.dungeon.start : -1)

/** Nos andares da cidade (fora da Liga): o Poké Mart, o Centro Pokémon, a Creche e os lugares dela; o líder no último. */
export function townHub(data, run) {
  return !run.dungeon && !inLeague(data, run) && routePos(run) >= ROUTE_LENGTH
}

/** Os pontos do mapa (o peso de cada um nas bifurcações). O Centro Pokémon é raro. */
export const NODE_WEIGHTS = [['wild', 34], ['trainer', 28], ['ace', 12], ['mart', 10], ['event', 11], ['center', 5], ['trade', 8]]
const BATTLE_NODES = ['wild', 'trainer', 'ace', 'boss', 'wildboss', 'rematch', 'rival', 'dboss']
export const isBattleNode = (node) => BATTLE_NODES.includes(node?.kind)

/**
 * O que tem no andar. A rota tem ROUTE_LENGTH andares (o último é o chefe
 * dela); depois vem a cidade, com CITY_LENGTH andares (o último é o líder; na
 * Liga, a Elite dos Quatro e o Campeão um atrás do outro). O rival da história pode
 * aparecer em qualquer andar antes do líder. Fora isso, o caminho segue (um
 * ponto só) e só nas bifurcações (FORKS, na rota e na cidade) dá para escolher
 * entre 2 ou 3 caminhos, sempre com uma batalha, ou entrar num lugar: na rota,
 * o lugar no caminho (Mt. Moon...) e o mar depois da praia; na cidade, os
 * lugares dela (esgoto, museu, a praia...). Num lugar não há desvio: 10
 * andares e o chefe; depois, de volta ao andar em que entrou (sem bifurcação).
 */
export function routeOptions(run, data, rand) {
  const boss = bossOf(data, run)
  const inside = Boolean(run.dungeon)
  const city = !inside && townHub(data, run)
  const biome = city ? 'city' : routeBiome(data, run)
  const pos = inside ? dungeonPos(run) : routePos(run)
  const only = (node) => ({ floor: run.floor, biome, ...(city ? { town: true } : {}), options: [node] })
  // Venceu o chefe de um lugar da água: segue para o próximo (o mar depois da praia...) ou volta.
  if (inside && run.dungeon.cleared) {
    const next = waterNext(run.dungeon.scene)
    // No Mar, também dá para subir a cachoeira (com Waterfall) até a gruta atrás dela.
    const fall = run.dungeon.scene === 'water' && !(run.places ?? []).includes(WATERFALL_PLACE.id) ? [{ kind: 'dungeon', place: WATERFALL_PLACE.id, scene: WATERFALL_PLACE.scene, deeper: true }] : []
    return { floor: run.floor, biome, options: [{ kind: 'dungeon', place: next.id, scene: next.scene, deeper: true }, ...fall, { kind: 'leave' }] }
  }
  // Lugares sem treinadores (mar, fundo do mar, cavernas de gelo, lava, veneno, cristal): só selvagens, e o chefe é um selvagem forte (dá para capturar).
  const wildOnly = inside && (WILD_ONLY.includes(biome) || Boolean(RARE_PLACES[run.dungeon.place]))
  // Num lugar (esgoto, base vilã...): no último andar, o chefe (na base, o vilão).
  // No lugar raro: o lendário do lugar.
  if (inside && pos >= DUNGEON_LENGTH - 1 && RARE_PLACES[run.dungeon.place]) return only({ kind: 'wildboss', legend: rareLegend(run, run.dungeon.place), rare: true, ...(RARE_PLACES[run.dungeon.place].mythic ? { mythic: true } : {}) })
  if (inside && pos >= DUNGEON_LENGTH - 1) return only(wildOnly ? { kind: 'wildboss', area: true } : { kind: run.dungeon.place === 'base' ? 'boss' : 'dboss' })
  // O último andar da cidade: o líder (com a equipe vilã na cidade, primeiro a base dela).
  if (city && pos >= CITY_BOSS) return only(boss.kind === 'villain' ? { kind: 'dungeon', place: 'base', scene: `base-${villainTeam(boss.name)}` } : { kind: 'boss' })
  if (atCity(data, run)) return only({ kind: 'boss' })
  // O último andar da rota: o chefe dela.
  if (!inside && !city && pos === ROUTE_LENGTH - 1) return only({ kind: 'dboss' })
  if (!inside && boss.kind === 'rival') {
    // O rival da história: quantos ainda faltam e quantos andares livres sobram até o líder (sem os chefes).
    const leaders = data.bosses[run.boss.region].leaders
    let pending = 0
    while (run.boss.step + pending < leaders.length && leaders[run.boss.step + pending].kind === 'rival') pending++
    const free = CITY_BOSS - pos - (pos < ROUTE_LENGTH - 1 ? 1 : 0)
    if (free <= pending || (pos >= 2 && rand() < AMBUSH_CHANCE)) return only({ kind: 'boss' })
  }
  // Os selvagens são do lugar (o cenário da batalha é ele). Na base de uma equipe vilã, só capangas.
  const base = biome.startsWith('base-')
  const wild = () => (base ? { kind: 'trainer' } : { kind: 'wild', biome })
  // Só a rota e a cidade se dividem (num lugar, não; nem no andar em que você voltou de um lugar).
  if (inside || !FORKS.includes(pos % ROUTE_LENGTH) || run.back === pos) {
    // O rival te seguiu: aparece de surpresa (uma vez por rota, só no caminho para um ginásio).
    if (!inside && !city && run.floor >= RIVAL_FLOOR && pos >= 2 && !base && boss.kind === 'gym' && run.rivalLeg !== legOf(run) && rivalBoss(data, run) && rand() < RIVAL_CHANCE) {
      return only({ kind: 'rival' })
    }
    // Jessie e James te seguiram: aparecem de surpresa (uma vez por rota, por sorteio).
    if (!inside && !city && run.floor >= RIVAL_FLOOR && pos >= 2 && !base && run.rocketLeg !== legOf(run) && rocketBoss(data, run) && rand() < ROCKET_CHANCE) {
      return only({ kind: 'rival', rocket: true })
    }
    // Evento raro: chuva de meteoros (à noite, Clefairy) ou um Pokémon mítico.
    if (!inside && !city && !base && run.floor >= RARE_FLOOR && rand() < RARE_CHANCE) {
      const mythics = MYTHICS.filter((id) => data.species[id])
      const meteor = rand() < 0.5
      if (meteor || mythics.length) return only(meteor ? { kind: 'wild', biome, meteor: true } : { kind: 'wildboss', legend: pickOne(mythics, rand), mythic: true })
    }
    const r = rand()
    // Intimidate em quem vai na frente: às vezes os selvagens fogem (vem um treinador no lugar).
    if (r < 0.55 && !base && !wildOnly && INTIMIDATE.includes(leadOf(run)?.id) && rand() < INTIMIDATE_CHANCE) return only({ kind: 'trainer' })
    if (wildOnly) return only(r < 0.9 ? wild() : { kind: 'event' })
    return only(r < 0.55 ? wild() : r < 0.9 || run.floor <= 2 ? { kind: 'trainer' } : { kind: 'event' })
  }
  const options = [rand() < 0.55 ? wild() : { kind: 'trainer' }]
  const count = run.floor <= 2 ? 2 : 3
  // Na cidade, o Poké Mart e o Centro ficam nela (não no caminho).
  const allowed = NODE_WEIGHTS.filter(([kind]) => (run.floor > 2 || kind === 'wild' || kind === 'trainer') && !(city && ['mart', 'center'].includes(kind)))
  const total = allowed.reduce((sum, [, w]) => sum + w, 0)
  for (let guard = 0; options.length < count && guard < 20; guard++) {
    let roll = rand() * total
    const [kind] = allowed.find(([, w]) => (roll -= w) < 0) ?? allowed[0]
    const node = kind === 'wild' ? wild() : { kind }
    if (options.some((o) => o.kind === node.kind && o.biome === node.biome)) continue
    options.push(node)
  }
  if (!city) {
    // Na rota para a Liga, o lendário da região espera num dos caminhos.
    if (pos === FORKS[1] && targetOf(data, run).kind === 'elite') {
      const legend = regionLegend(data, run)
      if (legend != null) options[options.length - 1] = { kind: 'wildboss', legend }
    }
    if (pos === FORKS[1] && !options.some((o) => o.legend) && rand() < WILD_BOSS_CHANCE) options[options.length - 1] = { kind: 'wildboss' }
    // Depois de virar Campeão: o Campeão vencido quer revanche (num dos caminhos da primeira bifurcação).
    if (run.rematch && pos === FORKS[0]) options[options.length - 1] = { kind: 'rematch' }
  }
  // Os lugares (enquanto não forem vencidos nesta rota): na cidade, os dela (e a base vilã, se a equipe estiver lá);
  // na rota, o mar (numa rota de praia) e o lugar no caminho (Mt. Moon, Rock Tunnel...).
  const info = routeInfo(data, run)
  const done = run.places ?? []
  const add = (place) => { if (place && !done.includes(place.id)) options.push({ kind: 'dungeon', place: place.id, scene: place.scene }) }
  if (city) {
    for (const place of info?.towns ?? []) add(place)
    if (boss.kind === 'villain') options.push({ kind: 'dungeon', place: 'base', scene: `base-${villainTeam(boss.name)}` })
  } else {
    // Numa rota de praia, o mar é opcional; numa rota de mar, o fundo do mar.
    const sea = info?.biome === 'water'
    if (pos === FORKS[sea ? 2 : 1]) add(waterNext(biome))
    if (pos === FORKS[2]) add(info?.side)
    // Às vezes, um lugar raro (como nos jogos).
    if (pos === FORKS[2] && rand() < RARE_PLACE_CHANCE) {
      const id = RARE_PLACE_IDS[Math.floor(rand() * RARE_PLACE_IDS.length)]
      add({ id, scene: RARE_PLACES[id].scene })
    }
  }
  return { floor: run.floor, biome, ...(city ? { town: true } : {}), options }
}

/** A cidade da rota (o destino) e a de onde ela começa (null no começo de uma região). Na Liga, as duas são a Liga. */
export function routeCities(data, run) {
  const leaders = data.bosses[run.boss.region].leaders
  const to = targetOf(data, run).city ?? ''
  if (inLeague(data, run)) return { from: to, to }
  let k = run.boss.step - 1
  while (k >= 0 && !CITY_KINDS.includes(leaders[k].kind)) k--
  // No começo da região: a cidade inicial do jogo (Pallet Town, New Bark Town...).
  const game = data.bosses[run.boss.region]
  const start = data.routes?.start?.[game.game] ?? data.routes?.start?.[game.region] ?? null
  return { from: k >= 0 ? leaders[k].city ?? null : start, to }
}

/** O que o treinador forte deixa (sempre): bolas e remédios vão para a Bolsa, os itens de segurar ficam guardados. */
export const ACE_REWARDS = ['great-ball', 'ultra-ball', 'hyper-potion', 'max-potion', 'revive', 'move-tutor', 'escape-rope', ...Object.keys(HELD_BOOST)]
/** Os eventos do mapa. */
export const EVENTS = ['items', 'money', 'berries', 'tutor']
/** Chance de o evento ser uma escolha (CHOICE_EVENTS). */
export const CHOICE_CHANCE = 0.4

/**
 * Escolhe o caminho: batalha (o encontro do andar) ou, sem batalha, o Poké
 * Mart (loja maior), o Centro Pokémon (cura todo mundo, até quem desmaiou) e
 * os eventos (itens, dinheiro, frutas que curam um pouco, ficha de Move Tutor).
 * Os sem batalha também contam como um andar (sem XP nem dinheiro).
 */
export function chooseNode(run, data, index, clock = null) {
  const node = run.route?.options?.[index]
  if (!node || run.encounter || run.pending || nodeBlocked(run, node)) return run
  const out = { ...run, route: null }
  // Entra num lugar (Mt. Moon, esgoto, base vilã, a praia...): 10 andares e o chefe dele; depois volta para o andar em que entrou.
  // Da praia para o mar (e assim por diante), a volta continua sendo para onde você entrou na água.
  if (node.kind === 'dungeon') {
    out.leg = run.leg ?? legOf(run)
    out.dungeon = { place: node.place, scene: node.scene, start: run.floor, ...(run.dungeon ? { entry: run.dungeon.entry ?? run.dungeon.start } : {}) }
    out.route = routeOptions(out, data, dice(out))
    return out
  }
  // Sai da água (depois de vencer o chefe do lugar): de volta para onde entrou.
  if (node.kind === 'leave') {
    if (run.dungeon) leavePlace(run, out)
    out.route = routeOptions(out, data, dice(out))
    return out
  }
  const rand = dice(out)
  if (isBattleNode(node)) {
    // O cenário da batalha: a cidade do ginásio, a Liga (torre) ou o lugar da rota (os selvagens e os treinadores são de lá).
    const city = node.kind === 'boss' && atCity(data, run)
    const scene = node.biome ?? (city ? (bossOf(data, run).kind === 'gym' ? 'city' : 'tower') : run.route.biome ?? 'grass')
    out.scene = scene
    const when = clock ? { night: clock.night, season: clock.season } : {}
    const roll = () => ({ ...encounterFor(data, out.floor, rand, node.kind === 'boss' ? bossOf(data, out) : null, node.kind === 'wildboss', { ...node, biome: scene, shiny: run.shinyRate ?? 1, ...when, ...huntNode(run) }), scene })
    out.encounter = roll()
    // Nuzlocke (cláusula de repetidos): o primeiro selvagem da área não é de uma linha evolutiva que você já teve.
    if (nuzRule(run, 'dupes') && out.encounter.kind === 'wild' && !areaUsed(run)) {
      const had = new Set(dexOf(run).map((id) => baseForm(data, id)))
      for (let k = 0; k < 8 && out.encounter.foes.every((f) => had.has(baseForm(data, f.id))); k++) out.encounter = roll()
    }
    countHunt(data, out)
    // A revanche: o Campeão vencido, com o time do andar de agora (e mais forte).
    if (node.kind === 'rematch') {
      const champ = rematchBoss(data, run)
      out.encounter = { ...encounterFor(data, out.floor + REMATCH_FLOORS, rand, champ), kind: 'rematch', scene }
    }
    // O chefe do lugar: um treinador forte do lugar, alguns andares à frente (sempre deixa um item).
    if (node.kind === 'dboss') {
      // No começo ele não é um muro (as primeiras corridas paravam todas no andar 9): só 1 nível acima e poucos Pokémon.
      const early = out.floor < DBOSS_GIMMICK_FLOOR
      out.encounter = { ...encounterFor(data, out.floor + (early ? 1 : 3), rand, null, false, { kind: 'ace', biome: scene, shiny: run.shinyRate ?? 1, ...(early ? { gentle: true } : {}) }), kind: 'dboss', scene }
      const foes = out.encounter.foes.slice(-dbossTeam(out.floor))
      // O mais forte dele usa uma mecânica (Mega, Gigantamax, Tera...), mas só a partir de DBOSS_GIMMICK_FLOOR.
      if (!early) foes[foes.length - 1] = bossGimmick(data, foes[foes.length - 1], rand)
      out.encounter = { ...out.encounter, foes }
    }
    // O rival de surpresa: o time dele no andar de agora (não conta como o da história).
    if (node.kind === 'rival') {
      out.encounter = { ...encounterFor(data, out.floor, rand, node.rocket ? rocketBoss(data, run) : rivalBoss(data, run)), kind: 'rival', scene }
      if (node.rocket) out.rocketLeg = legOf(run)
      else out.rivalLeg = legOf(run)
    }
    // Dupla de treinadores: dois treinadores juntos (os dois times na mesma batalha).
    if (node.kind === 'trainer' && !scene.startsWith('base-') && rand() < DOUBLE_CHANCE) {
      const second = encounterFor(data, out.floor, rand, null, false, { ...node, biome: scene, shiny: run.shinyRate ?? 1, ...when })
      // Até 3 de cada (a batalha tem no máximo 6 de cada lado).
      out.encounter = { ...out.encounter, foes: [...out.encounter.foes.slice(0, PAIR_TEAM), ...second.foes.slice(0, PAIR_TEAM)], pair: true }
    }
    // Os selvagens e os treinadores do caminho na forma da região (e com o degrau do jogo da corrida).
    out.encounter = rivalGrowth(tierFoes(regionalEncounter(data, run, out.encounter), run), run)
    // O cenário próprio do lugar (loja, cassino, escola...), se ele tiver.
    out.scene = shownScene(run, out.scene)
    out.encounter = { ...out.encounter, scene: shownScene(run, out.encounter.scene) }
    return out
  }
  out.floor += 1
  // O cenário de onde você está (Poké Mart e Centro na cidade).
  // Na rota não tem Poké Mart nem Centro: o vendedor ambulante e quem cura ficam no próprio lugar.
  out.scene = shownScene(run, run.route.biome ?? 'grass')
  if (node.kind === 'mart') out.pending = { mart: true, shop: pickShop(rand, data, run.floor, 10, Boolean(run.townMap)) }
  else if (node.kind === 'trade') {
    // Troca: alguém da rota oferece um Pokémon (você escolhe quem dar; ele vem TRADE_LEVELS acima).
    const offer = regionalEncounter(data, run, encounterFor(data, out.floor, rand, null, false, { kind: 'wild', biome: run.route?.biome, shiny: run.shinyRate ?? 1 })).foes[0]
    out.pending = { trade: { id: offer.id, ...(offer.shiny ? { shiny: true } : {}) } }
  } else if (node.kind === 'center') {
    out.team = out.team.map((m) => ({ ...m, hp: 1 }))
    out.pending = { center: true }
  } else if (rand() < CHOICE_CHANCE) {
    // Uma escolha na rota: ajudar alguém, seguir um Pokémon ferido ou entrar numa caverna secreta.
    const kind = pickOne(CHOICE_EVENTS, rand)
    const scale = priceScale(out.floor - 1)
    const choice = { kind }
    if (kind === 'help') choice.cost = Math.round(80 * scale)
    // A aposta: dobra ou perde o valor.
    else if (kind === 'bet') choice.cost = Math.round(100 * scale)
    // O mercador misterioso: um item raro, caro.
    else if (kind === 'merchant') Object.assign(choice, { cost: Math.round(250 * scale), item: pickOne(MERCHANT_ITEMS, rand) })
    // O Pokémon ferido: curado com uma poção, ele se junta ao time.
    else if (kind === 'injured') {
      const mon = regionalEncounter(data, run, encounterFor(data, out.floor, rand, null, false, { kind: 'wild', biome: run.route?.biome, shiny: run.shinyRate ?? 1 })).foes[0]
      choice.mon = { id: mon.id, level: mon.level, ...(mon.shiny ? { shiny: true } : {}) }
    }
    out.pending = { choice }
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

/** Os tipos para o Terastal dos chefes dos lugares. */
export const TERA_TYPES = ['normal', 'fire', 'water', 'grass', 'electric', 'ice', 'fighting', 'poison', 'ground', 'flying', 'psychic', 'bug', 'rock', 'ghost', 'dragon', 'dark', 'steel', 'fairy']

/** Os chefes dos lugares (fim da rota, cavernas, mar...): Mega (se ele tiver), senão Gigantamax (se tiver), senão Tera de um tipo ao acaso. */
export function bossGimmick(data, f, rand) {
  const megas = data.megas?.[f.id] ?? []
  if (megas.length) return { ...f, item: pickOne(megas, rand)[0], gimmick: 'mega' }
  if ((data.gmax ?? []).includes(f.id)) return { ...f, gimmick: 'dmax' }
  // Sem Mega nem Gigantamax: Z-Move (com o Cristal Z do tipo dele) ou Tera, meio a meio.
  const crystal = data.zcrystals?.[speciesOf(data, f.id)?.[4]?.[0]]
  if (crystal && rand() < 0.5) return { ...f, item: crystal, gimmick: 'z' }
  return { ...f, gimmick: 'tera', tera: pickOne(TERA_TYPES, rand) }
}

/**
 * O que aparece no andar: chefe da história (a cada 10), chefe sem treinador
 * (wild: Mega, Gigantamax ou lendário), selvagem ou treinador. node: o
 * caminho escolhido no mapa (selvagem do bioma, treinador ou treinador forte);
 * sem ele, selvagem ou treinador ao acaso.
 */
export function encounterFor(data, floor, rand, boss = null, wild = false, node = null) {
  const level = Math.max(2, foeLevelAt(floor) + Math.floor(rand() * 2))
  const iv = foeIvsAt(floor), ev = foeEvsAt(floor)
  // Evoluídos só a partir do nível em que evoluem (abaixo dele, a forma anterior).
  const foe = (id, lvl, extra = {}) => ({ id: devolve(data, id, Math.max(2, lvl)), level: Math.max(2, lvl), iv, ev, ...extra })
  // O chefe de um lugar sem treinadores (mar, cavernas de gelo, lava...): o Pokémon forte de lá, raro e acima do nível (dá para capturar).
  if (wild && node?.area) {
    const f = encounterFor(data, floor + 3, rand, null, false, { kind: 'wild', biome: node.biome, rare: true, shiny: node.shiny }).foes[0]
    return { kind: 'wildboss', area: true, foes: [bossGimmick(data, { ...f, iv: Math.max(31, f.iv), ev: Math.round(f.ev * 1.25) }, rand)] }
  }
  if (wild) {
    // Chefe sem treinador: dá para capturar; a Mega deixa a Mega Pedra.
    const r = rand()
    const strong = { iv: Math.max(31, iv), ev: Math.round(ev * 1.25) }
    let id, extra
    // Mega e Gigantamax só dos que já chegaram ao nível em que evoluem; senão, um lendário.
    const fits = (sid) => minLevelOf(data, sid) <= bossLevel(data, floor, sid, level + 3)
    const megas = Object.keys(data.megas).map(Number).sort((a, b) => a - b).filter(fits)
    const gmax = data.gmax.filter(fits)
    if (node?.legend != null) {
      // O lendário da região (na rota para a Liga) ou o mítico (evento raro).
      id = node.legend
      extra = { title: 'legend', ...(node.mythic ? { mythic: true } : {}) }
    } else if (r < 0.4 && megas.length) {
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
    // Antes do andar 10, o rival vem só com um Pokémon, sem IVs e EVs a mais (como no começo dos jogos).
    const early = floor < 10
    const bonus = early ? 0 : { gym: 2, rival: 2, villain: 3, elite: 6, champion: 9 }[boss.kind] ?? 2
    const full = bossTeam(boss, floor)
    // No começo, o rival só com o inicial dele (o oficial do jogo; sem inicial no time, o mais forte).
    const starterOf = () => { const lines = data.starters.flatMap((id) => starterLine(data, id)); return full.find((id) => lines.includes(id)) }
    const team = early && boss.kind === 'rival' ? [starterOf() ?? full[full.length - 1]] : full
    const levelOf = (id, i) => bossLevel(data, floor, id, level + bonus + (i === team.length - 1 && !early ? 1 : 0))
    const foes = team.map((id, i) => foe(id, levelOf(id, i), early ? {} : { iv: Math.max(31, iv), ev: Math.round(ev * 1.25) }))
    // A partir do andar 10, cada Pokémon do chefe segura um item de verdade (Leftovers, Life Orb, Choice...).
    if (floor >= 10) for (const f of foes) f.item = pickOne(FOE_ITEMS, rand)
    // guest: não é o rival do jogo (Red, Cynthia...); pair: dois treinadores juntos (Jessie e James), em dupla.
    return { kind: 'boss', foes, ...(boss.pair ? { pair: true } : {}), boss: { id: boss.id, name: boss.name, trainer: boss.trainer, kind: boss.kind, region: boss.region, game: boss.game, ...(boss.guest ? { guest: true } : {}) } }
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
  // À noite, mais Fantasma e Sombrio; em cada estação, os tipos dela (node.night, node.season: o relógio de quem joga).
  const types = BIOMES[node?.biome] && [...BIOMES[node.biome], ...(node.night ? NIGHT_TYPES : []), ...(SEASON_TYPES[node.season] ?? [])]
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
    // gentle: o treinador forte do fim da rota no começo (dboss antes de DBOSS_GIMMICK_FLOOR): sem os níveis e os IVs/EVs a mais.
    const strong = ace && !node?.gentle
    const count = Math.min(MAX_TEAM, 1 + Math.floor(floor / 12) + (rand() < 0.3 ? 1 : 0) + (ace ? 1 : 0))
    const extra = strong ? { iv: Math.max(iv, 20), ev: Math.round(ev * 1.15) } : {}
    // Na base de uma equipe vilã: capangas com os Pokémon da equipe.
    const grunt = node?.biome?.startsWith('base-') ? node.biome.slice(5) : null
    const choose = grunt && TEAM_POKEMON[grunt] ? () => pickOne(TEAM_POKEMON[grunt], rand) : () => pick(common, true)
    const foes = Array.from({ length: count }, () => foe(choose(), level + (strong ? 2 : 0) - Math.floor(rand() * 3), extra))
    // O mais forte do treinador forte segura um item de verdade (a partir do andar 15).
    if (ace && floor >= 15) foes[foes.length - 1].item = pickOne(FOE_ITEMS, rand)
    return { kind, foes, trainerSeed: Math.floor(rand() * 1e9), ...(ace ? { reward: pickOne(ACE_REWARDS, rand) } : {}), ...(grunt ? { grunt } : {}) }
  }
  // Selvagem: só os que vivem no lugar (o habitat de cada espécie: dos locais de encontro dos jogos; no fundo do mar,
  // só quem vive debaixo d'água); sem habitat nos dados, pelos tipos do lugar; sem nenhum, qualquer um.
  const lives = node?.biome ? common.filter((p) => data.species[p.id]?.[6]?.includes(node.biome)) : []
  const native = lives.length ? lives : types ? common.filter(local) : []
  // Seguindo o Pokémon ferido: um raro do lugar (taxa de captura baixa).
  const rare = node?.rare ? (native.length ? native : common).filter((p) => p.rate <= 75) : []
  // Chuva de meteoros: um Clefairy (da linha dele, pelo nível), com mais chance de ser shiny.
  const id = node?.meteor ? devolve(data, 36, level) : pick(rare.length ? rare : native.length ? native : common)
  const shinyRate = SHINY_CHANCE * (node?.shiny ?? 1) * (node?.meteor ? 8 : 1) * huntBoost(data, node, id)
  return { kind, foes: [foe(id, level, rand() < shinyRate ? { shiny: true } : {})], ...(node?.biome ? { biome: node.biome } : {}), ...(node?.meteor ? { meteor: true } : {}) }
}

// ------------------------------------------------------------ caça shiny
/**
 * A caça shiny: a cada HUNT_STEP encontros com o Pokémon escolhido (a linha
 * dele), a chance de ele vir shiny sobe (até HUNT_MAX vezes). Achou o shiny: a
 * contagem volta a zero. Igual ao app.
 */
export const HUNT_STEP = 10
export const HUNT_MAX = 8
/** Quantas vezes mais comum fica o shiny com `count` encontros. */
export const huntMultOf = (count) => Math.min(HUNT_MAX, 1 + Math.floor(count / HUNT_STEP))
/** A forma básica (a primeira da linha): é o que a caça conta. */
export const huntBase = (data, id) => devolve(data, id, 1)
const huntBoost = (data, node, id) => (node?.hunt != null && huntBase(data, id) === node.hunt ? node.huntMult ?? 1 : 1)
/** A caça da corrida: {hunt, huntMult} para o encontro. */
export const huntNode = (run) => (run.hunt == null ? {} : { hunt: run.hunt, huntMult: huntMultOf((run.huntCount ?? 0) + (run.huntSeen ?? 0)) })
/** Escolhe o Pokémon da caça (a forma básica; null para parar). Trocar zera a contagem. */
export function setHunt(factory, data, id) {
  if (id == null) return { ...factory, hunt: null }
  const base = huntBase(data, id)
  const old = factory.hunt
  if (old && old.id === base) return factory
  return { ...factory, hunt: { id: base, count: 0, found: old?.found ?? 0 } }
}
function countHunt(data, out) {
  const enc = out.encounter
  if (out.hunt == null || !enc || !String(enc.kind).startsWith('wild')) return
  for (const f of enc.foes ?? []) {
    if (huntBase(data, f.id) !== out.hunt) continue
    out.huntSeen = (out.huntSeen ?? 0) + 1
    if (f.shiny) out.huntFound = true
  }
}
/** A caça no fim da corrida: soma os encontros (ou zera, se achou o shiny). */
export function huntAfter(factory, run) {
  const hunt = factory.hunt
  if (!hunt || hunt.id !== (run.hunt ?? -1)) return hunt ?? null
  if (run.huntFound) return { ...hunt, count: 0, found: (hunt.found ?? 0) + 1 }
  return { ...hunt, count: (hunt.count ?? 0) + (run.huntSeen ?? 0) }
}

/** Começa uma corrida com o inicial escolhido (um dos grátis ou comprado). */
/**
 * Os modos da corrida (além do Nuzlocke): monotipo (só captura quem tem um tipo
 * do inicial), sem itens (começa com a Bolsa vazia) e formas regionais (os
 * selvagens na forma regional de qualquer região). Igual ao app.
 */
export const RUN_MODES = ['mono', 'noItems', 'regionalAll']

/**
 * As regras do Nuzlocke que dá para escolher (sempre valem: quem desmaia vai
 * embora e só um capturado por área). [id, ícone, texto]. Igual ao app.
 */
export const NUZLOCKE_RULES = [
  ['noBattleItems', '🎒', 'Sem itens na batalha: poções e afins só fora dela (as Poké Balls valem)'],
  ['dupes', '🧬', 'Cláusula de repetidos: o primeiro da área nunca é de uma linha evolutiva que você já teve'],
  ['shinyClause', '✨', 'Cláusula do shiny: um shiny pode ser capturado mesmo depois do primeiro da área'],
  ['setMode', '🔁', 'Modo Set: sem trocar de graça quando o adversário cai'],
  ['firstOnly', '1️⃣', 'Só o primeiro encontro: se o primeiro selvagem da área desmaiar, a área acabou'],
  ['levelCap', '📏', 'Limite de nível: ninguém passa do nível do mais forte do próximo líder'],
  ['leaderCount', '👥', 'Contra o líder (e a Liga): no máximo a mesma quantidade de Pokémon que ele tem'],
  ['noLegendary', '🚫', 'Sem lendários: lendários e míticos não podem ser capturados'],
  ['noHeldItems', '💍', 'Sem itens de segurar: o time luta sem itens'],
]
/** As que já vêm ligadas. */
export const NUZLOCKE_DEFAULT = ['noBattleItems', 'dupes', 'shinyClause', 'firstOnly']
/** A regra está ligada nesta corrida (corridas antigas do Nuzlocke: nenhuma). */
export const nuzRule = (run, rule) => Boolean(run?.nuzlocke) && (run.nuzRules ?? []).includes(rule)
/**
 * Nuzlocke com limite de nível: o nível do mais forte do próximo chefe da
 * cidade (líder, Elite dos Quatro ou Campeão); null sem a regra. Igual ao app.
 */
export function levelCapOf(data, run) {
  if (!nuzRule(run, 'levelCap') || !data?.bosses?.[run.boss?.region]) return null
  const boss = targetOf(data, run)
  const floor = Math.max(run.floor, legOf(run) + CITY_BOSS)
  return foeLevelAt(floor) + (floor < 10 ? 0 : { gym: 2, elite: 6, champion: 9 }[boss.kind] ?? 2) + 1
}

export function startRun(factory, data, id, seed, shiny = false, options = {}) {
  // Na corrida da semana, o inicial é o da semana (o mesmo para todos).
  if (!options.weekly && (!startersOf(factory, data).includes(id) || (shiny && !(factory.shinies ?? []).includes(id)))) return null
  // As melhorias compradas com moedas.
  const up = (k) => upgradeValue(factory, k)
  const bag = { ...START_BAG, 'poke-ball': START_BAG['poke-ball'] + up('balls'), potion: START_BAG.potion + up('potions'), revive: START_BAG.revive + up('revive') }
  if (up('greatBalls')) bag['great-ball'] = up('greatBalls')
  if (up('rope')) bag['escape-rope'] = up('rope')
  const run = {
    seed: seed >>> 0, floor: 1, money: up('money') + fxTotal(factory, 'money'), defeated: 0, bosses: 0, bag,
    team: [], teamBoost: zero(), mult: { money: 1, exp: round3(1 + up('exp') / 100), shop: round3(1 - Math.min(MAX_DISCOUNT, up('shop') + fxTotal(factory, 'discount')) / 100) }, cards: [], boss: { region: 0, step: 0 }, played: [],
    ...(up('cards') ? { cardCount: 3 + up('cards') } : {}), ...(up('reroll') + fxTotal(factory, 'reroll') ? { rerolls: up('reroll') + fxTotal(factory, 'reroll') } : {}), ...(up('shiny') + fxTotal(factory, 'shiny') ? { shinyRate: Math.min(MAX_SHINY_RATE, 1 + up('shiny') + fxTotal(factory, 'shiny')) } : {}),
    ...(factory.hunt ? { hunt: factory.hunt.id, huntCount: factory.hunt.count ?? 0 } : {}),
    tms: {}, tokens: { 'move-tutor': 0, 'move-reminder': 0 }, stash: [], dmax: up('dmax') > 0, tera: up('tera') > 0, expShare: up('expShare') > 0, leg: 1, route: null, encounter: null, pending: null,
    ...(up('map') ? { townMap: true } : {}),
    // Cura depois de cada vitória (% do HP de quem está de pé).
    ...(fxTotal(factory, 'heal') ? { winHeal: Math.min(MAX_WIN_HEAL, fxTotal(factory, 'heal')) } : {}),
    // Captura mais fácil (% a mais na taxa de captura, com qualquer Poké Ball).
    ...(fxTotal(factory, 'catch') ? { catchBonus: Math.min(MAX_CATCH, fxTotal(factory, 'catch')) } : {}),
    // O inicial (o rival escolhe o que tem vantagem sobre ele).
    starter: id,
    // Nuzlocke: quem desmaia vai embora e só um capturado por área (rota, cidade e cada lugar).
    ...(options.nuzlocke ? { nuzlocke: true, nuzRules: NUZLOCKE_RULES.map(([r]) => r).filter((r) => (options.nuzRules ?? NUZLOCKE_DEFAULT).includes(r)) } : {}),
    // A corrida da semana (a semana e a regra dela).
    ...(options.weekly ? { weekly: options.weekly, rule: options.rule ?? 'normal' } : {}),
  }
  // A árvore grande: itens, bônus, XP, dinheiro e fichas (na ordem das melhorias).
  for (const [k, [kind, arg]] of Object.entries(UPGRADE_FX)) {
    const v = up(k)
    if (!v) continue
    if (kind === 'bag') run.bag = { ...run.bag, [arg]: (run.bag[arg] ?? 0) + v }
    // Um por nível (os nós da trilha dão vários).
    else if (kind === 'stash') run.stash = [...run.stash, ...Array(v).fill(arg)]
    else if (kind === 'token') run.tokens = { ...run.tokens, [arg]: (run.tokens[arg] ?? 0) + v }
    else if (kind === 'boost') run.teamBoost = { ...run.teamBoost, [arg]: round3(run.teamBoost[arg] + v / 100) }
    else if (kind === 'boostAll') run.teamBoost = Object.fromEntries(STATS.map((st) => [st, round3(run.teamBoost[st] + v / 100)]))
    else if (kind === 'mult') run.mult = { ...run.mult, [arg]: round3(run.mult[arg] + v / 100) }
  }
  // Regra da semana "sem itens": começa com a Bolsa vazia.
  const modes = options.modes ?? []
  if (options.rule === 'noItems' || modes.includes('noItems')) run.bag = Object.fromEntries(Object.keys(run.bag).map((k) => [k, 0]))
  if (modes.includes('noItems')) run.noItems = true
  if (modes.includes('mono')) run.mono = [...(speciesOf(data, id)?.[4] ?? [])]
  if (modes.includes('regionalAll')) run.regionalAll = true
  const rand = dice(run)
  // O inicial vem com IVs bons (15 a 31; com a Genética, mais).
  run.team = [newMon(id, START_LEVEL + up('level') + Math.min(MAX_START_LEVEL, fxTotal(factory, 'level')), rand, Math.min(31, 15 + up('ivs') + fxTotal(factory, 'ivs')), shiny)]
  run.boss = { region: Math.floor(rand() * data.bosses.length), step: 0 }
  run.played = [data.bosses[run.boss.region].region]
  run.route = routeOptions(run, data, rand)
  run.mission = newMission(run, data, rand)
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
  // Depois de cada vitória, a cura da árvore (só em quem está de pé).
  // Lá no fundo (WIN_HEAL_FLOOR), mais WIN_HEAL%: os treinadores vêm com o time todo e o desgaste não pode decidir a corrida.
  const heal = (run.winHeal ?? 0) + (run.floor >= WIN_HEAL_FLOOR ? WIN_HEAL : 0)
  const healed = (hp) => (hp > 0 && heal ? Math.min(1, round3(hp + heal / 100)) : hp)
  // Nuzlocke sem itens na batalha: da batalha só voltam as Poké Balls (o resto ficou guardado na Bolsa).
  const bagAfter = after.bag && nuzRule(run, 'noBattleItems') ? { ...run.bag, ...Object.fromEntries(BALL_IDS.map((id) => [id, after.bag[id] ?? run.bag[id] ?? 0])) } : after.bag ?? run.bag
  const out = { ...run, team: run.team.map((m, i) => ({ ...m, hp: healed(after.hp?.[i] ?? m.hp ?? 1) })), bag: { ...bagAfter, 'escape-rope': run.bag['escape-rope'] ?? 0 } }
  const rand = dice(out)
  const { kind, foes } = run.encounter
  const factor = expFactor(kind)
  const moneyFactor = kind === 'boss' || kind === 'wildboss' || kind === 'rematch' || kind === 'rival' || kind === 'dboss' ? 3 : kind === 'ace' ? 2.5 : kind === 'trainer' ? 2 : 1
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
  // O XP que cada um já ganhou na luta (a batalha dá na hora, ao derrubar cada adversário): vale esse.
  if (after.gained) after.gained.forEach((g, i) => { if (i < gains.length) gains[i] = g })
  // Nuzlocke com limite de nível: o XP para no nível do limite.
  const cap = levelCapOf(data, run)
  if (cap) out.team.forEach((m, i) => { gains[i] = Math.max(0, Math.min(gains[i], expAt(cap) - (m.exp ?? expAt(m.level)))) })
  const levels = []
  const exp = Math.max(0, ...gains)
  const before = out.team
  out.team = out.team.map((m, index) => {
    if (!gains[index]) return m
    const r = gainExp({ ...m, evs: addStats(m.evs, evs[index]) }, gains[index], data, rand, regionOf(data, run))
    if (r.mon.level > r.from || r.evolved) levels.push({ index, from: r.from, to: r.mon.level, evolved: r.evolved })
    // O XP da corrida inteira (para o MVP do resumo no fim). Igual ao app.
    return { ...r.mon, xpRun: (m.xpRun ?? 0) + gains[index] }
  })
  // O Nincada que virou Ninjask deixa o Shedinja (com vaga no time).
  const grown = withShedinja(out, before, out.team, rand)
  const shed = grown.length > out.team.length
  out.team = grown
  // Amizade: quem está de pé ganha um ponto; com FRIEND_EVOLVE, os que evoluem por amizade evoluem.
  out.team = out.team.map((m, index) => {
    if (!((m.hp ?? 1) > 0)) return m
    const friendship = (m.friendship ?? 0) + 1
    const to = FRIEND_EVOS[m.id]
    if (to == null || friendship < FRIEND_EVOLVE) return { ...m, friendship }
    const fairy = m.id === 133 && (m.moves ?? []).some((x) => FAIRY_MOVES.includes(x))
    const id = fairy ? 700 : Array.isArray(to) ? to[after.night ? 1 : 0] : to
    out.friendEvos = (out.friendEvos ?? 0) + 1
    levels.push({ index, from: m.level, to: m.level, evolved: id, friend: true })
    return { ...m, id, friendship }
  })
  // Pickup: quem tem acha um item de vez em quando (melhor conforme o andar).
  const picked = []
  for (const m of out.team) {
    if ((m.hp ?? 1) > 0 && PICKUP.includes(m.id) && rand() < PICKUP_CHANCE) {
      const item = PICKUP_ITEMS[Math.min(PICKUP_ITEMS.length - 1, Math.floor(rand() * Math.min(PICKUP_ITEMS.length, 2 + run.floor / 10)))]
      out.bag = { ...out.bag, [item]: (out.bag[item] ?? 0) + 1 }
      picked.push({ id: m.id, item })
    }
  }
  // O Pokémon que segue você (quem vai na frente) às vezes acha um item também; o dobro se ele já gosta muito de
  // você (a amizade que faz evoluir). Igual ao app.
  const order = battleOrder(run)
  const lead = order.length ? out.team[order[0]] : null
  // O sorteio vem da semente e do andar (sem gastar a sequência da corrida).
  if (lead && (lead.hp ?? 1) > 0 && followRoll(run, 2654435769) < FOLLOW_FIND * ((lead.friendship ?? 0) >= FRIEND_EVOLVE ? 2 : 1)) {
    const item = PICKUP_ITEMS[Math.min(PICKUP_ITEMS.length - 1, Math.floor(followRoll(run, 1597334677) * Math.min(PICKUP_ITEMS.length, 2 + run.floor / 10)))]
    out.bag = { ...out.bag, [item]: (out.bag[item] ?? 0) + 1 }
    picked.push({ id: lead.id, item, follow: true })
  }
  // Nuzlocke: quem desmaiou vai embora (para sempre).
  const fallenMons = run.nuzlocke ? out.team.filter((m) => !((m.hp ?? 1) > 0)) : []
  const lost = fallenMons.map((m) => m.id)
  // Nuzlocke: o encontro desta área já foi (capturado agora; a área é a da batalha, antes de subir de andar).
  // Cláusula do shiny: o shiny não gasta o encontro da área.
  // Só o primeiro encontro: o primeiro selvagem da área gasta a área mesmo sem ser capturado.
  if (run.nuzlocke && (after.captured || (nuzRule(run, 'firstOnly') && kind === 'wild')) && (kind === 'wild' || kind === 'wildboss') && !(nuzRule(run, 'shinyClause') && foes.some((f) => f.shiny))) { out.caughtArea = nuzlockeArea(run); out.caughtAreas = [...new Set([...(run.caughtAreas ?? []), nuzlockeArea(run)])] }
  if (lost.length && lost.length < out.team.length) out.team = out.team.filter((m) => (m.hp ?? 1) > 0)
  if (lost.length) out.fallen = (run.fallen ?? 0) + lost.length
  // O memorial do Nuzlocke: quem caiu, o nível e o andar (como os jogadores anotam).
  if (lost.length) out.memorial = [...(run.memorial ?? []), ...fallenMons.map((m) => ({ id: m.id, level: m.level, floor: run.floor, ...(m.nick ? { nick: m.nick } : {}), ...(m.shiny ? { shiny: true } : {}) }))]
  if (run.encounter.meteor) out.meteors = (run.meteors ?? 0) + 1
  out.money += money
  out.defeated += foes.length
  out.floor += 1
  let drop = null, story = null
  if (kind === 'boss' || kind === 'wildboss') out.bosses = (out.bosses ?? 0) + 1
  // Os itens dos chefes especiais (vão para a conta no fim da corrida, com as moedas).
  const pieces = piecesFor(data, run)
  const dropped = Object.keys(pieces).length > 0
  if (dropped) out.pieces = addPieces(piecesOf(run), pieces)
  let champion = false, hm = null
  // Venceu a revanche: o Campeão some (até o próximo).
  if (kind === 'rival') out.rivalRaces = (run.rivalRaces ?? 0) + 1
  // Venceu o chefe do lugar (ou o vilão na base): volta para a cidade.
  const rarePlace = Boolean(run.dungeon && RARE_PLACES[run.dungeon.place] && kind === 'wildboss')
  if (run.dungeon && (kind === 'dboss' || kind === 'boss' || run.encounter.area || rarePlace)) {
    out.dungeons = (run.dungeons ?? 0) + 1
    if (run.dungeon.place !== 'base') out.places = [...(run.places ?? []), run.dungeon.place]
    // Num lugar da água, dá para seguir para o próximo (o mar depois da praia...); nos outros, volta.
    if (run.dungeon.place !== 'base' && waterNext(run.dungeon.scene)) out.dungeon = { ...run.dungeon, cleared: true }
    else leavePlace(run, out)
  }
  if (kind === 'rematch') {
    out.rematch = null
    out.rematches = (run.rematches ?? 0) + 1
  }
  if (kind === 'boss') {
    const beaten = run.encounter.boss
    // As conquistas (progress): insígnias, ginásio só com o inicial, Campeões.
    if (beaten.kind === 'gym') {
      out.badges = (run.badges ?? 0) + 1
      if (run.team.length === 1) out.soloGym = true
      // As MOs vêm com as insígnias (Cut, Flash, Surf, Rock Smash, Dive, Strength e Waterfall).
      hm = HM_BADGES[out.badges] ?? null
      if (hm && !(run.hms ?? []).includes(hm)) out.hms = [...(run.hms ?? []), hm]
      else hm = null
    }
    if (beaten.kind === 'champion') {
      out.champions = (run.champions ?? 0) + 1
      champion = true
      // O Campeão vencido vai querer revanche na região seguinte.
      out.rematch = { region: run.boss.region }
    }
    // O rival: as falas mudam conforme ele perde.
    if (beaten.kind === 'rival') out.rivalWins = (run.rivalWins ?? 0) + 1
    // Acabou de lutar com o rival da história: ele não aparece de surpresa de novo nesta rota.
    if (beaten.kind === 'rival' && run.encounter.kind === 'boss' && !beaten.guest) out.rivalLeg = legOf(run)
    // Venceu o chefe da cidade (ou da Liga): começa a rota seguinte (num lugar que se liga ao da rota que acabou).
    if (CITY_KINDS.includes(beaten.kind)) {
      out.prevBiome = routeBiome(data, { ...run, dungeon: null })
      out.leg = out.floor
      delete out.detour
      delete out.back
      delete out.places
      out.town = null
    }
    const [boss, played] = nextBoss(out, data, rand)
    // Acabou a história da região: o fim dela e o começo da próxima.
    if (boss.step === 0) out.games = (run.games ?? 0) + 1
    if (boss.step === 0) story = `${storyLine(data, beaten.region, 'end')}\n\n${storyLine(data, data.bosses[boss.region].region, 'intro')}`
    out.boss = boss
    out.played = played
    // Em Alola (onde existem os Z-Moves), o chefe deixa o Cristal Z do tipo do Pokémon mais forte dele.
    const ace = foes[foes.length - 1]
    const crystal = run.encounter.boss.region === 'Alola' ? data.zcrystals?.[speciesOf(data, ace.id)?.[4]?.[0]] : null
    if (crystal && !hasItem(out, crystal)) drop = crystal
  }
  // A Mega deixa a Mega Pedra (derrotando ou capturando).
  if (kind === 'wildboss' && foes[0].item && !hasItem(out, foes[0].item)) drop = foes[0].item
  if (drop) out.stash = [...(out.stash ?? []), drop]
  // O treinador forte deixa um item: bolas e remédios na Bolsa, ficha de Move Tutor, os de segurar guardados.
  // O lugar raro deixa uma Master Ball.
  const reward = rarePlace ? RARE_PLACE_REWARD : kind === 'ace' || kind === 'dboss' ? run.encounter.reward ?? null : null
  if (reward && BAG_ITEMS.includes(reward)) out.bag[reward] = (out.bag[reward] ?? 0) + 1
  else if (reward && TOKENS.includes(reward)) out.tokens = { ...out.tokens, [reward]: (out.tokens?.[reward] ?? 0) + 1 }
  else if (reward) out.stash = [...(out.stash ?? []), reward]
  // A missão da rota: os derrotados (e o capturado) do tipo contam; completa, dá dinheiro e um item.
  let mission = null
  if (run.mission && run.mission.done < run.mission.need) {
    const m = run.mission
    const fits = (f) => (speciesOf(data, f.id)?.[4] ?? []).includes(m.type)
    const add = m.kind === 'grunts' ? (run.encounter.grunt ? 1 : 0) : m.kind === 'defeat' ? foes.filter(fits).length : after.captured && fits(foes[0]) ? 1 : 0
    if (add) {
      out.mission = { ...m, done: Math.min(m.need, m.done + add) }
      if (out.mission.done >= m.need) {
        const item = pickOne(ACE_REWARDS, rand)
        const cash = Math.round(MISSION_MONEY * priceScale(run.floor))
        giveItem(out, item)
        out.money += cash
        mission = { ...out.mission, item, money: cash }
      }
    }
  }
  const joy = rand() < JOY_CHANCE
  if (joy) out.team = out.team.map((m) => ({ ...m, hp: 1 }))
  const born = hatch(out, after.captured && (kind === 'wild' || kind === 'wildboss'))
  out.pending = {
    exp, gains, money, levels, joy, drop, story, reward, ...(champion ? { champion: true } : {}),
    ...(picked.length ? { picked } : {}), ...(lost.length ? { lost } : {}), ...(shed ? { shed: true } : {}), ...(dropped ? { pieces } : {}),
    // O capturado ou o ovo que chocou (a mesma tela).
    capture: after.captured && (kind === 'wild' || kind === 'wildboss') ? foes[0] : born,
    // A Poké Ball em que ele foi capturado (o sprite dela na tela da captura).
    ...(after.captured && after.ball ? { ball: after.ball } : {}),
    cards: kind === 'boss' ? pickCards(rand, run.cardCount ?? 3, run.relics ?? []) : null,
    // A loja da cidade: chegando nela, logo antes do chefe (no resto da rota, os Poké Marts do mapa).
    shop: kind !== 'boss' || !CITY_KINDS.includes(run.encounter.boss.kind) ? (atCity(data, out) && !inLeague(data, out) && !townHub(data, out) ? pickShop(rand, data, run.floor, 8, Boolean(run.townMap)) : null) : null,
    // O chefe que acabou de perder (as falas depois da luta) e a missão completa.
    ...(kind === 'boss' || kind === 'rival' ? { beat: { kind: run.encounter.boss.kind, name: run.encounter.boss.name, region: run.encounter.boss.region } } : {}),
    ...(mission ? { mission } : {}),
    ...(hm ? { hm } : {}),
  }
  out.encounter = null
  return out
}

function pickCards(rand, count = 3, relics = []) {
  const ids = Object.keys(CARDS)
  const out = []
  while (out.length < count) {
    const id = pickOne(ids, rand)
    if (!out.includes(id)) out.push(id)
  }
  // Às vezes uma relíquia (que você ainda não tem) entra no lugar da última carta.
  const free = Object.keys(RELICS).filter((id) => !relics.includes(id))
  if (free.length && rand() < RELIC_CHANCE) out[out.length - 1] = pickOne(free, rand)
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

function pickShop(rand, data, floor, size = 8, hasMap = false) {
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
  // O Mapa aparece fácil (até ser comprado).
  if (!hasMap && rand() < TOWN_MAP_CHANCE) add('town-map')
  const ids = Object.keys(SHOP).filter((id) => !BALL_IDS.includes(id) && !HEAL_TIERS.includes(id) && id !== 'revive' && id !== 'town-map')
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
/** Quem entra no time ao capturar (o mesmo sorteio da captura): a tela mostra o gênero e a Nature antes de decidir. Igual ao app. */
export function capturedMon(run, into = null) {
  const foe = run.pending?.capture
  if (!foe) return null
  // into: a corrida em que o sorteio avança (na captura de verdade).
  const rand = dice(into ?? { ...run })
  let mon = newMon(foe.id, foe.level, rand, foe.egg ? EGG_IVS : 0, Boolean(foe.shiny))
  // Synchronize em quem vai na frente: metade das vezes, o capturado vem com a Nature dele.
  const lead = leadOf(run)
  if (!foe.egg && lead && SYNCHRONIZE.includes(lead.id) && rand() < 0.5) mon = { ...mon, nature: lead.nature }
  return mon
}

export function capture(run, replace = null) {
  const foe = run.pending?.capture
  if (!foe) return run
  const out = { ...run, team: [...run.team], pending: { ...run.pending, capture: null } }
  const mon = capturedMon(run, out)
  if (foe.mythic) out.mythics = (run.mythics ?? 0) + 1
  if (out.team.length < teamRoom(out)) out.team.push(mon)
  else if (replace === 'pc') {
    // Time cheio: o capturado vai para o PC (dá para trocar no Centro Pokémon da cidade).
    const pc = pcPut(run, mon)
    if (!pc) return run
    out.pc = pc
  } else if (replace != null && replace >= 0 && replace < out.team.length) {
    // Quem sai do time vai para o PC.
    const pc = pcPut(run, { ...out.team[replace], hp: 1 })
    if (!pc) return run
    out.pc = pc
    out.team[replace] = mon
  } else return run
  addDex(out, foe.id)
  return out
}

/**
 * O PC (como nos jogos): os capturados que não cabem no time ficam guardados
 * nele, em PC_BOXES caixas de 6×6 (com nome); no Centro Pokémon da cidade dá
 * para mexer: arrastar um Pokémon para outra vaga (do time ou do PC) troca os
 * dois. Quem está no PC fica curado. run.pc: as vagas (null = vazia).
 * Igual ao app.
 */
export const PC_BOX = 36
export const PC_BOXES = 8
export const PC_SIZE = PC_BOX * PC_BOXES
/** As vagas do PC (null = vazia), PC_SIZE no total. */
export const pcSlots = (run) => Array.from({ length: PC_SIZE }, (_, k) => run.pc?.[k] ?? null)
/** Os guardados (sem as vagas vazias). */
export const pcOf = (run) => (run.pc ?? []).filter(Boolean)
/** O nome da caixa (o que você escolheu ou "Box 1"...). */
export const boxName = (run, box) => run.pcNames?.[box] || `Box ${box + 1}`
/** Sem as vagas vazias do fim (para guardar menos). */
const trimPc = (pc) => { const out = [...pc]; while (out.length && !out[out.length - 1]) out.pop(); return out }
/** O PC com o Pokémon na primeira vaga vazia (null: cheio). */
export function pcPut(run, mon) {
  const pc = pcSlots(run)
  const k = pc.indexOf(null)
  if (k < 0) return null
  pc[k] = mon
  return trimPc(pc)
}
/** Está no Centro Pokémon da cidade (onde fica o PC). */
export const atPc = (run) => Boolean(run.pending?.center && run.pending?.town)
/**
 * Arrasta um Pokémon (from) para outra vaga (to): { where: 'team' | 'pc', index }.
 * Vaga com alguém: os dois trocam de lugar; vaga vazia: ele vai para lá (na vaga
 * vazia do time, entra no fim do time). O time nunca fica vazio. Igual ao app.
 */
export function pcMove(run, from, to) {
  if (!atPc(run) || !from || !to || (from.where === to.where && from.index === to.index)) return null
  const team = [...run.team]
  const pc = pcSlots(run)
  const get = (l) => (l.where === 'team' ? team[l.index] : pc[l.index]) ?? null
  const set = (l, m) => { if (l.where === 'team') team[l.index] = m; else pc[l.index] = m }
  const a = get(from)
  if (!a || (to.where === 'pc' && !(to.index >= 0 && to.index < PC_SIZE)) || (to.where === 'team' && !(to.index >= 0))) return null
  const b = get(to)
  if (to.where === 'team' && !b) {
    // Na vaga vazia do time: entra no fim (se couber).
    if (from.where === 'team' || team.length >= teamRoom(run)) return null
    set(from, null)
    team.push(a)
  } else {
    set(to, a)
    set(from, b)
  }
  const nextTeam = team.filter(Boolean).map((m) => ({ ...m, hp: from.where === 'pc' || to.where === 'pc' ? 1 : m.hp }))
  if (!nextTeam.length) return null
  return { ...run, team: nextTeam, pc: trimPc(pc.map((m) => (m ? { ...m, hp: 1 } : null))) }
}
/**
 * Organiza a caixa (as vagas cheias primeiro): pelo número da Pokédex
 * ('dex'), pelo nível (do maior para o menor) ou pelo tipo (o primeiro tipo,
 * depois o número). Igual ao app.
 */
export const PC_SORTS = ['dex', 'level', 'type']
export function sortBox(run, box, by, data) {
  if (!(box >= 0 && box < PC_BOXES) || !PC_SORTS.includes(by)) return run
  const pc = pcSlots(run)
  const start = box * PC_BOX
  const mons = pc.slice(start, start + PC_BOX).filter(Boolean)
  const type = (m) => speciesOf(data, m.id)?.[4]?.[0] ?? 'zzz'
  mons.sort((a, b) => (by === 'level' ? b.level - a.level || a.id - b.id : by === 'type' ? type(a).localeCompare(type(b)) || a.id - b.id : a.id - b.id || b.level - a.level))
  for (let k = 0; k < PC_BOX; k++) pc[start + k] = mons[k] ?? null
  return { ...run, pc: trimPc(pc) }
}
/** Os fundos das caixas do PC (como nos jogos). Igual ao app. */
export const PC_WALLS = ['classic', 'forest', 'cave', 'sea', 'desert', 'snow', 'volcano', 'night']
/** O fundo da caixa. */
export const boxWall = (run, box) => (PC_WALLS.includes(run.pcWalls?.[box]) ? run.pcWalls[box] : PC_WALLS[box % PC_WALLS.length])
/** Troca o fundo da caixa pelo seguinte. */
export function nextWall(run, box) {
  if (!(box >= 0 && box < PC_BOXES)) return run
  const walls = Array.from({ length: PC_BOXES }, (_, k) => boxWall(run, k))
  walls[box] = PC_WALLS[(PC_WALLS.indexOf(walls[box]) + 1) % PC_WALLS.length]
  return { ...run, pcWalls: walls }
}
/** O apelido (até 12 letras; vazio tira) de quem está no time ou no PC: { where: 'team' | 'pc', index }. */
export function setNick(run, at, nick) {
  const clean = String(nick ?? '').trim().slice(0, 12)
  const put = (m) => { const { nick: _old, ...rest } = m; return clean ? { ...rest, nick: clean } : rest }
  if (at?.where === 'team' && run.team[at.index]) return { ...run, team: run.team.map((m, k) => (k === at.index ? put(m) : m)) }
  if (at?.where === 'pc' && run.pc?.[at.index]) return { ...run, pc: run.pc.map((m, k) => (k === at.index && m ? put(m) : m)) }
  return run
}
/** O jogo da corrida (1º, 2º...): cada um é um degrau de dificuldade (GAME_TIER). */
export const gameOf = (run) => tierOf(run) + 1
/** O próximo chefe é a primeira da Elite dos Quatro: depois dele, as lutas da Liga vêm uma atrás da outra. */
export function leagueAhead(data, run) {
  const leaders = data?.bosses?.[run.boss?.region]?.leaders
  if (!leaders) return false
  return leaders[run.boss.step]?.kind === 'elite' && leaders[run.boss.step - 1]?.kind !== 'elite'
}

/** Dá nome à caixa (até 16 letras; vazio volta ao "Box N"). */
export function renameBox(run, box, name) {
  if (!(box >= 0 && box < PC_BOXES)) return run
  const names = Array.from({ length: PC_BOXES }, (_, k) => run.pcNames?.[k] ?? '')
  names[box] = String(name ?? '').trim().slice(0, 16)
  return { ...run, pcNames: names }
}

/**
 * A Pokédex da corrida: quem você já teve (o inicial, os capturados, os
 * trocados e os chocados). A cada marca, um prêmio.
 */
export const DEX_REWARDS = [
  { at: 5, item: 'great-ball', count: 3, money: 200 },
  { at: 10, item: 'ultra-ball', count: 3, money: 400 },
  { at: 15, item: 'max-potion', count: 2, money: 700 },
  { at: 20, item: 'revive', count: 3, money: 1000 },
  { at: 30, item: 'master-ball', count: 1, money: 2000 },
]
export const dexOf = (run) => run.dex ?? (run.starter != null ? [run.starter] : [])
/** O prêmio que entrar com id daria (null se ele já está na Pokédex ou não chega numa marca). */
export function dexRewardFor(run, id) {
  const dex = dexOf(run)
  if (dex.includes(id)) return null
  return DEX_REWARDS.find((r) => r.at === dex.length + 1) ?? null
}
function addDex(out, id) {
  const reward = dexRewardFor(out, id)
  if (dexOf(out).includes(id)) return
  out.dex = [...dexOf(out), id]
  if (!reward) return
  out.bag = { ...out.bag, [reward.item]: (out.bag[reward.item] ?? 0) + reward.count }
  out.money += reward.money
}

/**
 * As MOs (HMs), uma por insígnia até a 7ª. Cut abre um caminho escondido; Flash ilumina cavernas; Surf deixa ir para o
 * mar; Rock Smash quebra uma rocha (um selvagem raro de pedra); Dive leva ao fundo do mar; Strength empurra uma pedra
 * (um treinador forte, que sempre deixa um item); Waterfall sobe a cachoeira do Mar até a gruta atrás dela.
 */
export const HM_BADGES = { 1: 'cut', 2: 'flash', 3: 'surf', 4: 'rock-smash', 5: 'dive', 6: 'strength', 7: 'waterfall' }
/** Tem a MO: ganhou com a insígnia ou um Pokémon do time sabe o golpe (não precisa passar do ginásio). */
export const hasHm = (run, hm) => (run.hms ?? []).includes(hm) || (run.team ?? []).some((m) => (m?.moves ?? []).includes(hm))
/** A MO que falta para ir por este caminho (null se nada falta): o mar pede Surf; o fundo do mar, Dive. */
export function hmNeeded(run, node) {
  const deep = (node?.biome === 'underwater' && run.route?.biome !== 'underwater') || (node?.kind === 'dungeon' && node.scene === 'underwater')
  const place = node?.kind === 'dungeon' ? node.scene : null
  const need = deep ? 'dive' : place === 'water' ? 'surf' : place === 'waterfall' ? 'waterfall' : null
  return need && !hasHm(run, need) ? need : null
}
export const nodeBlocked = (run, node) => hmNeeded(run, node) != null
/** Cut: uma vez por rota, corta a árvore e abre um caminho escondido (um selvagem raro do lugar). null se não dá. */
export function cutPath(run) {
  const route = run.route
  if (!hasHm(run, 'cut') || !route || route.options.length < 2 || run.encounter || run.pending || run.cutLeg === (run.leg ?? 1)) return null
  return { ...run, cutLeg: run.leg ?? 1, route: { ...route, options: [...route.options, { kind: 'wild', biome: route.biome, rare: true, cut: true }] } }
}
/** Onde há rochas para quebrar (Rock Smash) e pedras para empurrar (Strength). */
export const SMASH_BIOMES = ['cave', 'mountain', 'icecave', 'crystal', 'lavacave', 'poisoncave', 'seacave', 'desert', 'dunes', 'ruins', 'volcano', 'waterfall']
export const STRENGTH_BIOMES = ['cave', 'mountain', 'icecave', 'crystal', 'lavacave', 'poisoncave', 'seacave', 'ruins', 'temple', 'waterfall']
const hmPathOk = (run, hm, biomes, leg) => {
  const route = run.route
  return hasHm(run, hm) && route && biomes.includes(route.biome) && route.options.length >= 2 && !route.town && !run.encounter && !run.pending && run[leg] !== (run.leg ?? 1)
}
/** Rock Smash: uma vez por rota, nos lugares de pedra, quebra a rocha e aparece um selvagem raro de lá. null se não dá. */
export function smashPath(run) {
  if (!hmPathOk(run, 'rock-smash', SMASH_BIOMES, 'smashLeg')) return null
  return { ...run, smashLeg: run.leg ?? 1, route: { ...run.route, options: [...run.route.options, { kind: 'wild', biome: run.route.biome, rare: true, smash: true }] } }
}
/** Strength: uma vez por rota, nas cavernas e montanhas, empurra a pedra e abre o caminho de um treinador forte (sempre deixa um item). */
export function strengthPath(run) {
  if (!hmPathOk(run, 'strength', STRENGTH_BIOMES, 'strengthLeg')) return null
  return { ...run, strengthLeg: run.leg ?? 1, route: { ...run.route, options: [...run.route.options, { kind: 'ace', strength: true }] } }
}

/** Dupla de treinadores: chance de um treinador vir acompanhado. */
export const DOUBLE_CHANCE = 0.2
/** Na dupla de treinadores, quantos de cada um (os dois juntos: no máximo 6, o limite da batalha). Igual ao app. */
export const PAIR_TEAM = 3
/** A partir deste andar, a dupla de treinadores é batalha dupla de verdade (2 contra 2), se você tem 2 de pé. */
export const DOUBLE_FLOOR = 15
export const isDoubleBattle = (run) => Boolean(run.encounter?.pair) && run.floor >= DOUBLE_FLOOR && run.team.filter((m) => (m.hp ?? 1) > 0).length >= 2
/** A revanche: o Campeão vencido vem com o time de alguns andares à frente. */
export const REMATCH_FLOORS = 5
/** Na cidade: entra no Poké Mart (o estoque dela; CONTINUAR volta para a cidade). */
export function townShop(run) {
  if (!run.town || run.encounter || run.pending) return run
  return { ...run, pending: { shop: run.town.shop } }
}
/** Na cidade: o Centro Pokémon cura o time todo, até quem desmaiou (de graça). */
export function townCenter(run) {
  if (!run.town || run.encounter || run.pending) return run
  return { ...run, scene: 'center', team: run.team.map((m) => ({ ...m, hp: 1 })), pending: { center: true, town: true } }
}

/** O começo da rota de agora (o andar depois da última cidade). */
export const legOf = (run) => run.floor - routePos(run) - (run.detour ?? 0)
/** A área do Nuzlocke (um capturado em cada): a rota, a cidade dela ou o lugar (caverna, floresta...) em que você está. Igual ao app. */
/**
 * Nuzlocke: a área já deu o encontro dela (vale para sempre na corrida: voltar
 * para a floresta ou para a caverna não dá outra captura). Igual ao app.
 */
export const areaUsed = (run) => (run.caughtAreas ?? []).includes(nuzlockeArea(run)) || run.caughtArea === nuzlockeArea(run)
export const nuzlockeArea = (run) => `${legOf(run)}:${run.dungeon?.place ?? (routePos(run) >= ROUTE_LENGTH ? 'city' : 'route')}`

/** O rival da região que aparece de surpresa: o último que você já enfrentou na história (ou o primeiro). null se a região não tem rival. */
export function rivalBoss(data, run) {
  const game = data.bosses[run.boss.region]
  const rivals = game.leaders.map((l, k) => [l, k]).filter(([l]) => l.kind === 'rival' && !l.guest)
  if (!rivals.length) return null
  const met = rivals.filter(([, k]) => k < run.boss.step)
  return { region: game.region, game: game.game, ...(met.length ? met[met.length - 1] : rivals[0])[0] }
}

export function rematchBoss(data, run) {
  const game = data.bosses[run.rematch?.region ?? run.boss.region]
  const champ = game.leaders.find((l) => l.kind === 'champion') ?? game.leaders[game.leaders.length - 1]
  return { region: game.region, game: game.game, ...champ }
}

/**
 * A Creche (na cidade): deixa um Pokémon, ele ganha um nível por andar; buscando
 * depois de DAYCARE_EGG andares, vem junto um ovo (a forma básica dele, com IVs bons), que vai no time (🥚, ocupando
 * uma vaga, sem lutar) e choca depois de EGG_BATTLES vitórias. Igual ao app.
 */
export const DAYCARE_EGG = 4
export const EGG_BATTLES = 10
/** Vagas para Pokémon no time: cada ovo ocupa uma. */
export const teamRoom = (run) => MAX_TEAM - (run.eggs?.length ?? 0)
export const EGG_IVS = 20
export const EGG_LEVEL = 5
export function leaveDaycare(run, index) {
  if (run.daycare || run.team.length < 2 || !run.team[index]) return null
  const team = run.team.filter((_, i) => i !== index)
  return { ...run, team, daycare: { mon: run.team[index], floor: run.floor } }
}
export function takeDaycare(run, data) {
  const care = run.daycare
  // O Pokémon volta para o time e, com o ovo pronto, ele também precisa de uma vaga.
  const egg = care && Math.max(0, run.floor - care.floor) >= DAYCARE_EGG
  if (!care || run.team.length + (egg ? 1 : 0) >= teamRoom(run)) return null
  const out = { ...run, daycare: null }
  const rand = dice(out)
  const steps = Math.max(0, run.floor - care.floor)
  const [grown] = levelTo(care.mon, care.mon.level + steps, data, rand, regionOf(data, run))
  out.team = [...run.team, grown]
  if (steps >= DAYCARE_EGG) out.eggs = [...(run.eggs ?? []), { id: baseForm(data, care.mon.id), left: EGG_BATTLES }]
  return out
}

/** Mais uma vitória para os ovos; o primeiro pronto choca (se a captura da luta não ocupou a vez, ele espera a próxima). */
function hatch(out, captured) {
  if (!out.eggs?.length) return null
  const eggs = out.eggs.map((e) => ({ ...e, left: Math.max(0, e.left - 1) }))
  const ready = captured ? -1 : eggs.findIndex((e) => e.left <= 0)
  const born = ready >= 0 ? { id: eggs.splice(ready, 1)[0].id, level: EGG_LEVEL, egg: true } : null
  out.eggs = eggs
  return born
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
  const [grown] = levelTo(fresh, mon.level + TRADE_LEVELS, data, rand, regionOf(data, run))
  out.team[index] = { ...grown, item: mon.item ?? null, extras: mon.extras ?? [] }
  addDex(out, grown.id)
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
/**
 * O clima de cada lugar (chances): sol e areia no deserto, chuva no mar e no
 * pântano, neve na neve, sol no vulcão; às vezes sol ou chuva na grama, na
 * floresta e na cidade. Lugares fechados (todas as cavernas e grutas, esgoto,
 * torre, ginásio, Liga) sem clima: lá dentro não chove. Igual ao app.
 */
export const SCENE_WEATHER = {
  desert: [['sand', 0.6], ['sun', 0.25]], volcano: [['sun', 0.6]], snow: [['snow', 0.65]],
  beach: [['sun', 0.35], ['rain', 0.25]], water: [['rain', 0.55], ['sun', 0.1]], swamp: [['rain', 0.5]],
  grass: [['sun', 0.15], ['rain', 0.15]], forest: [['rain', 0.2], ['sun', 0.1]], mountain: [['sand', 0.15], ['snow', 0.15], ['sun', 0.1]],
  sky: [['sun', 0.2], ['rain', 0.2]], city: [['rain', 0.12], ['sun', 0.12]],
  ruins: [['sand', 0.2], ['sun', 0.15]], flowers: [['sun', 0.25], ['rain', 0.1]], dunes: [['sand', 0.55]], bamboo: [['rain', 0.2], ['sun', 0.1]],
}
/** A música do mapa (andando na rota e na cidade): um tema original por região, mais calmo. Igual ao app. */
export const MAP_REGIONS = ['kanto', 'johto', 'hoenn', 'sinnoh', 'unova', 'kalos', 'alola', 'galar', 'paldea']
export function mapMusic(data, run) {
  const region = regionOf(data, run)?.toLowerCase()
  return region == null ? null : `map_${MAP_REGIONS.includes(region) ? region : 'kanto'}`
}
/** A música das batalhas da corrida (selvagens e treinadores; os chefes têm a deles): o tema da região, o mesmo do mapa. Igual ao app. */
export const battleMusic = (data, run) => mapMusic(data, run) ?? 'map_kanto'
/**
 * Quem cura fora da cidade (a Enfermeira Joy só fica no Centro Pokémon da
 * cidade): um por andar, sempre o mesmo para a mesma corrida e andar. Igual ao app.
 */
export const HEALERS = [['sd-pokemonbreederf', 'Pokémon Breeder'], ['sd-doctor', 'Doctor'], ['sd-pokemonrangerf', 'Pokémon Ranger'], ['sd-aromalady', 'Aroma Lady']]
export const healerOf = (run) => HEALERS[((run.seed ?? 0) + run.floor) % HEALERS.length]
/** Os lugares da cidade (onde ficam o Poké Mart e a Enfermeira Joy). */
export const inTown = (scene) => scene === 'city' || scene === 'center' || scene === 'tower' || String(scene).startsWith('gym-') || String(scene).startsWith('champion-')

/** As estações (como no Black & White: mudam a cada mês) e a noite (pelo relógio de verdade). */
export const SEASONS = ['spring', 'summer', 'autumn', 'winter']
/** Os tipos que aparecem mais em cada estação e à noite. */
export const SEASON_TYPES = { spring: ['grass', 'fairy'], summer: ['fire', 'water'], autumn: ['bug', 'ground'], winter: ['ice'] }
export const NIGHT_TYPES = ['ghost', 'dark']
/** No inverno, neva nos lugares abertos. */
export const WINTER_SNOW = ['grass', 'forest', 'flowers', 'bamboo', 'mountain', 'city', 'ruins', 'beach']
/** A hora e a estação de agora: noite das 19h às 6h; a estação pelo mês (jan primavera, fev verão, mar outono, abr inverno...). */
export function clockOf(date = new Date()) {
  const hour = date.getHours()
  return { night: hour >= 19 || hour < 6, season: SEASONS[date.getMonth() % 4] }
}

/** O clima com que a batalha do andar começa ('' sem clima): pelo lugar, sempre o mesmo para a mesma corrida e andar. */
export function weatherOf(run, scene, season = null) {
  const table = season === 'winter' && WINTER_SNOW.includes(scene) ? [['snow', 0.35], ...(SCENE_WEATHER[scene] ?? [])] : SCENE_WEATHER[scene]
  if (!table) return ''
  let roll = (Math.imul(((run.seed ?? 0) ^ (run.floor * 40503)) | 0, 2246822519) >>> 0) / 4294967296
  for (const [weather, chance] of table) {
    if (roll < chance) return weather
    roll -= chance
  }
  return ''
}

/**
 * O efeito de cada lugar (chances): terrenos de verdade (grama na floresta, eletricidade na cidade, névoa, psíquico) e
 * os efeitos do lugar que ferem quem não é do tipo (chuva de diamantes na caverna, cinzas no vulcão, névoa tóxica no
 * pântano, frio na caverna de gelo, desmoronamento na montanha) ou curam quem é (aura sombria na torre, correnteza no
 * fundo do mar); no céu, ventos fortes (Delta Stream). Os ginásios têm o terreno do tipo. Igual ao app.
 */
export const SCENE_FIELD = {
  cave: [['diamonds', 0.3]], mountain: [['rockfall', 0.25]], volcano: [['ashes', 0.4]], swamp: [['miasma', 0.35]], sewer: [['miasma', 0.25]],
  icecave: [['chill', 0.35], ['aurora', 0.1]], snow: [['chill', 0.2], ['aurora', 0.2]], tower: [['haunt', 0.35], ['psychic', 0.15]], underwater: [['current', 0.4]], water: [['current', 0.15]],
  grass: [['grassy', 0.2]], forest: [['grassy', 0.3], ['misty', 0.1]], city: [['electric', 0.25]], beach: [['misty', 0.1]], sky: [['wind', 0.3], ['storm', 0.15]],
  desert: [['quicksand', 0.2]], ruins: [['psychic', 0.2], ['haunt', 0.15]], flowers: [['spores', 0.3], ['misty', 0.15]], plant: [['storm', 0.35], ['electric', 0.25]],
  crystal: [['diamonds', 0.4]], lavacave: [['ashes', 0.4]], poisoncave: [['miasma', 0.4]], seacave: [['current', 0.3]], waterfall: [['current', 0.3]], dunes: [['quicksand', 0.35], ['haunt', 0.1]], bamboo: [['spores', 0.2], ['grassy', 0.2]], temple: [['psychic', 0.3]],
  'gym-grass': [['grassy', 0.6]], 'gym-electric': [['electric', 0.6]], 'gym-psychic': [['psychic', 0.6]], 'gym-fairy': [['misty', 0.6]], 'gym-ghost': [['haunt', 0.6]],
  'gym-rock': [['rockfall', 0.4]], 'gym-fire': [['ashes', 0.4]], 'gym-poison': [['miasma', 0.4]], 'gym-ice': [['chill', 0.4]], 'gym-water': [['current', 0.4]],
}

/** O efeito com que a batalha do andar começa ('' sem efeito): pelo lugar, sempre o mesmo para a mesma corrida e andar. */
export function fieldOf(run, scene) {
  const table = SCENE_FIELD[scene]
  if (!table) return ''
  let roll = (Math.imul(((run.seed ?? 0) ^ (run.floor * 69069)) | 0, 2654435761 | 0) >>> 0) / 4294967296
  for (const [effect, chance] of table) {
    if (roll < chance) return effect
    roll -= chance
  }
  return ''
}

/**
 * Os lendários de cada região: as pistas aparecem ao longo da história e, na
 * rota para a Liga, um deles espera (dá para capturar). Igual ao app.
 */
export const REGION_LEGENDS = {
  Kanto: [150, 144, 145, 146], Johto: [249, 250, 243, 244, 245], Hoenn: [382, 383, 384, 380, 381], Sinnoh: [483, 484, 487, 480, 481, 482],
  Unova: [643, 644, 646, 638, 639, 640], Kalos: [716, 717, 718], Alola: [791, 792, 800, 785], Galar: [888, 889, 890], Paldea: [1007, 1008, 1001, 1002],
}
/** O lendário da região da corrida (sempre o mesmo para a mesma corrida e região). */
export function regionLegend(data, run) {
  const list = REGION_LEGENDS[data.bosses[run.boss.region].region] ?? []
  return list.length ? list[((run.seed >>> 0) + run.boss.region) % list.length] : null
}

/** A linha evolutiva de um inicial: [ele, a 1ª evolução, a 2ª]. */
export function starterLine(data, id) {
  const line = [id]
  for (let k = 0; k < 2; k++) {
    const next = data.evolutions[line[line.length - 1]]?.[0]?.[0]
    if (next == null) break
    line.push(next)
  }
  return line
}

/**
 * Missão da rota: derrotar 3 de um tipo do lugar ou capturar 1 (na base de uma
 * equipe vilã, derrotar 3 capangas). Completa, dá dinheiro e um item.
 */
export const MISSION_MONEY = 150
export function newMission(run, data, rand) {
  const biome = routeBiome(data, run)
  if (biome.startsWith('base-')) return { leg: run.leg ?? 1, kind: 'grunts', type: '', need: 3, done: 0 }
  const types = BIOMES[biome] ?? ['normal']
  const type = pickOne(types, rand)
  return rand() < 0.6 ? { leg: run.leg ?? 1, kind: 'defeat', type, need: 3, done: 0 } : { leg: run.leg ?? 1, kind: 'catch', type, need: 1, done: 0 }
}

/**
 * Escolhas na rota (eventos com escolha): ajudar alguém (paga e ganha um item),
 * seguir um Pokémon ferido (selvagem raro) ou entrar numa caverna secreta
 * (com Flash, sempre acha algo). accept: aceitou. Igual ao app.
 */
export const CHOICE_EVENTS = ['help', 'follow', 'secret', 'merchant', 'bet', 'injured']
/** O que o mercador misterioso vende. */
export const MERCHANT_ITEMS = ['master-ball', 'max-potion', 'revive', 'life-orb', 'leftovers', 'choice-band', 'choice-specs', 'focus-sash']
export function resolveChoice(run, data, accept) {
  const choice = run.pending?.choice
  if (!choice) return run
  const out = { ...run, pending: null }
  const rand = dice(out)
  if (!accept) {
    out.pending = { event: { kind: 'declined' } }
    return out
  }
  if (choice.kind === 'merchant' || choice.kind === 'bet') {
    if (out.money < choice.cost) {
      out.pending = { event: { kind: 'declined' } }
      return out
    }
    if (choice.kind === 'merchant') {
      out.money -= choice.cost
      giveItem(out, choice.item)
      out.pending = { event: { kind: 'bought', item: choice.item } }
    } else if (rand() < 0.5) {
      out.money += choice.cost
      out.pending = { event: { kind: 'betWon', money: choice.cost } }
    } else {
      out.money -= choice.cost
      out.pending = { event: { kind: 'betLost', money: choice.cost } }
    }
    return out
  }
  if (choice.kind === 'injured') {
    // Usa o remédio mais fraco que tiver; sem nenhum, não dá para curar.
    const heal = HEAL_TIERS.find((k) => (out.bag?.[k] ?? 0) > 0)
    if (!heal) {
      out.pending = { event: { kind: 'noPotion' } }
      return out
    }
    out.bag = { ...out.bag, [heal]: out.bag[heal] - 1 }
    out.pending = { event: { kind: 'injuredJoined', item: heal }, capture: choice.mon }
    return out
  }
  if (choice.kind === 'help') {
    if (out.money < choice.cost) {
      out.pending = { event: { kind: 'declined' } }
      return out
    }
    out.money -= choice.cost
    const item = pickOne(ACE_REWARDS, rand)
    giveItem(out, item)
    out.pending = { event: { kind: 'helped', item } }
  } else if (choice.kind === 'follow') {
    // O Pokémon ferido leva a um selvagem raro do lugar (a batalha é neste andar).
    out.floor -= 1
    const scene = out.scene ?? 'grass'
    out.encounter = tierFoes(regionalEncounter(data, run, { ...encounterFor(data, out.floor, rand, null, false, { kind: 'wild', biome: scene, rare: true, shiny: run.shinyRate ?? 1 }), scene }), run)
  } else {
    const found = hasHm(run, 'flash') || rand() < 0.5
    if (found) {
      const item = pickOne(ACE_REWARDS, rand)
      const money = Math.round(80 * priceScale(out.floor - 1))
      giveItem(out, item)
      out.money += money
      out.pending = { event: { kind: 'secretFound', item, money } }
    } else out.pending = { event: { kind: 'secretEmpty' } }
  }
  return out
}
/** Um item ganho: bolas e remédios na Bolsa, ficha de Move Tutor, os de segurar guardados. */
function giveItem(out, item) {
  if (BAG_ITEMS.includes(item)) out.bag = { ...out.bag, [item]: (out.bag[item] ?? 0) + 1 }
  else if (TOKENS.includes(item)) out.tokens = { ...out.tokens, [item]: (out.tokens?.[item] ?? 0) + 1 }
  else out.stash = [...(out.stash ?? []), item]
}

/** Chance de o Mapa estar na loja (até ser comprado). */
export const TOWN_MAP_CHANCE = 0.75

/**
 * Sem o Mapa, na bifurcação você não vê os caminhos: segue por um deles às
 * cegas (sempre o mesmo para a mesma corrida e andar). Igual ao app.
 */
export function blindPick(run) {
  const n = run.route?.options?.length ?? 1
  const first = (Math.imul(((run.seed ?? 0) ^ (run.floor * 2654435761)) | 0, 1597334677) >>> 0) % n
  // Sem Surf, não mergulha: o próximo caminho.
  for (let k = 0; k < n; k++) if (!nodeBlocked(run, run.route?.options?.[(first + k) % n])) return (first + k) % n
  return first
}

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
 * pouco HP (ESCAPE_HP), no mesmo andar, com o mapa de novo (dentro de um lugar, de volta na cidade). after = {hp, bag}
 * da batalha (factoryAfter). null sem a corda (a corrida acaba).
 */
export function escapeRope(run, data, after = {}) {
  if (!((run.bag?.['escape-rope'] ?? 0) > 0)) return null
  const bag = { ...run.bag, ...(after.bag ?? {}), 'escape-rope': run.bag['escape-rope'] - 1 }
  const out = { ...run, bag, team: run.team.map((m, i) => ({ ...m, hp: Math.max(after.hp?.[i] ?? 0, ESCAPE_HP) })), encounter: null, pending: null, ropes: (run.ropes ?? 0) + 1 }
  // Dentro de um lugar (esgoto, base vilã...), a corda leva de volta para onde você entrou (a rota ou a cidade).
  if (run.dungeon) leavePlace(run, out)
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
  dungeon: { label: 'Vencer o chefe de um lugar (esgoto, casa assombrada...)', coins: 120, done: (r) => (r.dungeons ?? 0) >= 1 },
  dungeon5: { label: 'Vencer 5 lugares numa corrida', coins: 400, done: (r) => (r.dungeons ?? 0) >= 5 },
  rival3: { label: 'Vencer o rival de surpresa 3 vezes', coins: 150, done: (r) => (r.rivalRaces ?? 0) >= 3 },
  dex30: { label: '30 na Pokédex da corrida', coins: 300, done: (r) => dexOf(r).length >= 30 },
  friend: { label: 'Evoluir um Pokémon pela amizade', coins: 150, done: (r) => (r.friendEvos ?? 0) >= 1 },
  mythic: { label: 'Capturar um Pokémon mítico', coins: 500, done: (r) => (r.mythics ?? 0) >= 1 },
  meteor: { label: 'Ver uma chuva de meteoros', coins: 100, done: (r) => (r.meteors ?? 0) >= 1 },
  nuzlocke: { label: 'Ganhar uma insígnia no Nuzlocke', coins: 300, done: (r) => Boolean(r.nuzlocke) && (r.badges ?? 0) >= 1 },
  shedinja: { label: 'Ganhar um Shedinja (o Nincada virando Ninjask com vaga no time)', coins: 200, done: (r) => r.team.some((m) => m.id === 292) },
  // Estas contam todas as corridas (os capturados da conta).
  hitmons: { label: 'Ter os três: Hitmonlee, Hitmonchan e Hitmontop', coins: 400, done: (r) => [106, 107, 237].every((id) => metaCaught(r).has(id)) },
  regional5: { label: 'Capturar 5 formas regionais', coins: 300, done: (r) => [...metaCaught(r)].filter(isRegionalForm).length >= 5 },
}

/**
 * As conquistas novas da corrida (com as moedas delas) e o Hall da Fama (o
 * time que venceu o Campeão, um registro por vitória). Devolve [factory, ids novos].
 */
export function progress(factory, run) {
  if (!run) return [factory, []]
  const have = factory.achievements ?? []
  // As conquistas de todas as corridas veem os capturados da conta.
  const ctx = { ...run, _caught: factory.caught ?? [] }
  const earned = Object.keys(ACHIEVEMENTS).filter((id) => !have.includes(id) && ACHIEVEMENTS[id].done(ctx))
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

/** Fica com a relíquia: a regra dela vale até o fim da corrida. */
function takeRelic(run, id) {
  const relic = RELICS[id]
  const out = { ...run, relics: [...(run.relics ?? []), id], pending: { ...run.pending, cards: null } }
  if (relic.team) out.teamBoost = Object.fromEntries(STATS.map((s) => [s, round3((out.teamBoost?.[s] ?? 0) + (relic.team[s] ?? 0))]))
  for (const [k, v] of relic.mults ?? []) out.mult = { ...out.mult, [k]: Math.max(0.4, round3(out.mult[k] + v)) }
  if (relic.winHeal) out.winHeal = Math.min(MAX_WIN_HEAL, (out.winHeal ?? 0) + relic.winHeal)
  if (relic.catchBonus) out.catchBonus = Math.min(MAX_CATCH, (out.catchBonus ?? 0) + relic.catchBonus)
  return out
}

/** Escolhe a carta de bônus. */
export function takeCard(run, id, data) {
  if (RELICS[id] && run.pending?.cards?.includes(id)) return takeRelic(run, id)
  const card = CARDS[id]
  if (!card || !run.pending?.cards?.includes(id)) return run
  const out = { ...run, cards: [...run.cards, id], pending: { ...run.pending, cards: null } }
  if (card.team) out.teamBoost = Object.fromEntries(STATS.map((s) => [s, round3((out.teamBoost?.[s] ?? 0) + (card.team[s] ?? 0) * cardPower(run.floor))]))
  if (card.mult) out.mult = { ...out.mult, [card.mult[0]]: Math.max(0.4, round3(out.mult[card.mult[0]] + card.mult[1])) }
  if (card.balls) out.bag = { ...out.bag, 'poke-ball': (out.bag['poke-ball'] ?? 0) + card.balls }
  if (card.heal) {
    out.team = out.team.map((m) => ({ ...m, hp: 1 }))
    out.bag = { ...out.bag, 'max-potion': (out.bag['max-potion'] ?? 0) + 1 }
  }
  if (card.levels) {
    const rand = dice(out)
    const cap = levelCapOf(data, out)
    out.team = withShedinja(out, out.team, out.team.map((m) => levelTo(m, cap ? Math.max(m.level, Math.min(cap, m.level + card.levels)) : m.level + card.levels, data, rand, regionOf(data, out))[0]), rand)
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
/** Já na forma em que ele vira (a da região, a feminina). Igual ao app. */
export function canEvolveWith(data, mon, item, region = null) {
  return evolutionsOf(data, mon, region).filter((e) => e[2] === item).map((e) => evolvedForm(data, mon, e[0], region))
}

/** Se o item já foi comprado/é inútil agora (Dynamax Band e Tera Orb são uma vez só). */
export function shopOwned(run, id) {
  return (id === 'dynamax-band' && run.dmax) || (id === 'tera-orb' && run.tera) || (id === 'exp-share' && Boolean(run.expShare)) || (id === 'town-map' && Boolean(run.townMap))
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
  if (id === 'town-map') return { ...out, townMap: true }
  if (TOKENS.includes(id)) return { ...out, tokens: { ...out.tokens, [id]: (out.tokens?.[id] ?? 0) + 1 } }
  if (id.startsWith('tm:')) {
    const move = id.slice(3)
    return { ...out, tms: { ...out.tms, [move]: (out.tms?.[move] ?? 0) + 1 } }
  }
  const mon = run.team[index]
  if (!mon) return null
  if (id.startsWith('evo:')) {
    // Pedra de evolução: evolui na hora (se ele evolui com ela).
    const [to] = canEvolveWith(data, mon, id.slice(4), regionOf(data, run))
    if (!to) return null
    out.team[index] = { ...mon, id: to }
    return out
  }
  if (id === 'rare-candy') {
    // Nuzlocke com limite de nível: o Rare Candy não passa do limite.
    const cap = levelCapOf(data, run)
    if (cap && mon.level >= cap) return null
    const rand = dice(out)
    out.team[index] = levelTo(mon, mon.level + 1, data, rand, regionOf(data, out))[0]
    out.team = withShedinja(out, run.team, out.team, rand)
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

/** Tira o item (extra: a posição de um extra; sem ela, o principal) e guarda: dá para equipar em outro. Igual ao app. */
export function unequipItem(run, index, extra = null) {
  const mon = run.team[index]
  const id = extra == null ? mon?.item : mon?.extras?.[extra]
  if (!id) return run
  const team = [...run.team]
  team[index] = extra == null ? { ...mon, item: null } : { ...mon, extras: mon.extras.filter((_, k) => k !== extra) }
  return { ...run, team, stash: [...(run.stash ?? []), id] }
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
  const rand = dice(out)
  // Chegou na cidade: o estoque do Poké Mart dela e o lugar com batalha perto dela.
  if (townHub(data, out) && out.town?.leg !== legOf(out)) {
    out.town = { leg: legOf(out), shop: pickShop(rand, data, out.floor, 8, Boolean(run.townMap)) }
  }
  out.route = routeOptions(out, data, rand)
  // Começo de uma rota nova: a missão dela.
  if (routePos(out) === 0 && !atCity(data, out) && run.mission?.leg !== (out.leg ?? 1)) out.mission = newMission(out, data, rand)
  return out
}

/**
 * A corrida da semana (o torneio entre amigos): a mesma semente, o mesmo
 * inicial e uma regra para todo mundo na semana ({week}: a segunda-feira,
 * "AAAA-MM-DD"); o ranking é o andar alcançado. Igual ao app.
 */
export const WEEKLY_RULES = ['normal', 'nuzlocke', 'noItems']
export function weeklyOf(data, week) {
  let h = 2166136261
  for (const ch of String(week)) h = Math.imul(h ^ ch.charCodeAt(0), 16777619) >>> 0
  return { week, seed: h >>> 0, starter: data.starters[h % data.starters.length], rule: WEEKLY_RULES[(h >>> 8) % WEEKLY_RULES.length] }
}
export function startWeekly(factory, data, week) {
  const w = weeklyOf(data, week)
  return startRun(factory, data, w.starter, w.seed, false, { weekly: week, rule: w.rule, nuzlocke: w.rule === 'nuzlocke' })
}

/**
 * A loja de cosméticos (com as moedas da Factory): a Poké Ball que você joga
 * nas batalhas e a moldura da caixa de texto. Igual ao app.
 */
export const COSMETIC_BALLS = {
  'premier-ball': 300, 'luxury-ball': 600, 'heal-ball': 300, 'friend-ball': 400, 'love-ball': 500, 'moon-ball': 500,
  'fast-ball': 400, 'dusk-ball': 400, 'dream-ball': 1000, 'beast-ball': 1200, 'cherish-ball': 1500,
}
export const COSMETIC_FRAMES = { gold: 500, crystal: 600, night: 400, sakura: 600 }
const cosmeticPrice = (kind, id) => (kind === 'ball' ? COSMETIC_BALLS : COSMETIC_FRAMES)[id]
export const hasCosmetic = (factory, kind, id) => (factory.cosmetics?.[kind] ?? []).includes(id)
/** Compra (com moedas) e já usa; null sem moedas ou se não existe. */
export function buyCosmetic(factory, kind, id) {
  const price = cosmeticPrice(kind, id)
  if (price == null || hasCosmetic(factory, kind, id) || factory.coins < price) return null
  const cosmetics = { ...(factory.cosmetics ?? {}), [kind]: [...(factory.cosmetics?.[kind] ?? []), id] }
  return { ...factory, coins: factory.coins - price, cosmetics, [kind === 'ball' ? 'ball' : 'frame']: id }
}
/** Usa um que já tem (null volta para o padrão). */
export function equipCosmetic(factory, kind, id) {
  if (id != null && !hasCosmetic(factory, kind, id)) return factory
  return { ...factory, [kind === 'ball' ? 'ball' : 'frame']: id }
}

/** Perdeu: a corrida acaba; a pontuação vira moedas e o recorde fica salvo. */
export function endRun(factory, run) {
  // A melhoria de moedas soma uma porcentagem ao que a corrida rendeu.
  // Moedas a mais: a melhoria Moedas e todas as de efeito 'coins' (Tesouro e os nós pequenos).
  const bonus = Object.entries(UPGRADE_FX).reduce((n, [k, [kind]]) => n + (kind === 'coins' ? upgradeValue(factory, k) : 0), upgradeValue(factory, 'coins'))
  const coins = Math.round(runCoins(run) * (1 + bonus / 100))
  return {
    ...factory, coins: factory.coins + coins, ...(run.pieces && typeof run.pieces === 'object' ? { pieces: addPieces(piecesOf(factory), piecesOf(run)) } : {}), best: Math.max(factory.best, run.floor - 1), run: null,
    last: { floor: run.floor - 1, coins, ...(run.games ? { games: run.games } : {}), ...(run.pieces && typeof run.pieces === 'object' ? { pieces: piecesOf(run) } : {}), ...(run.weekly ? { weekly: run.weekly } : {}), summary: runSummary(run) },
    gallery: addToGallery(factory.gallery, run),
    history: addToHistory(factory.history, run, coins),
    ...(factory.hunt ? { hunt: huntAfter(factory, run) } : {}),
    // O PC da conta: só o time da corrida (o PC do Centro Pokémon é da corrida e acaba com ela).
    box: addToBox(factory.box, run.team ?? []),
    // O recorde de jogos zerados numa corrida.
    ...((run.games ?? 0) > (factory.bestGames ?? 0) ? { bestGames: run.games } : {}),
  }
}

/** Quantos Pokémon cabem no PC (os mais antigos saem). */
export const BOX_SIZE = 300

/** O Pokémon como fica guardado no PC: espécie, nível, Nature, IVs, EVs (o gênero sai deles), golpes, item e shiny. Igual ao app. */
export function boxEntry(mon, date = new Date().toISOString().slice(0, 10)) {
  return {
    id: mon.id, level: mon.level ?? 1, nature: mon.nature ?? 'Hardy',
    ivs: Object.fromEntries(STATS.map((s) => [s, mon.ivs?.[s] ?? 0])),
    evs: Object.fromEntries(STATS.map((s) => [s, mon.evs?.[s] ?? 0])),
    moves: (mon.moves ?? []).map(String),
    ...(mon.item ? { item: mon.item } : {}),
    ...(mon.shiny ? { shiny: true } : {}),
    date,
  }
}

/** Põe os Pokémon no PC (os novos primeiro). Igual ao app. */
export function addToBox(box, mons, date) {
  return [...mons.filter((m) => m.id > 0 && !m.egg).map((m) => boxEntry(m, date)), ...(box ?? [])].slice(0, BOX_SIZE)
}

/** Solta o Pokémon da posição `index` do PC. */
export function releaseFromBox(factory, index) {
  const box = [...(factory.box ?? [])]
  if (index < 0 || index >= box.length) return factory
  box.splice(index, 1)
  return { ...factory, box }
}

/** O Pokémon do PC como membro de um time (o formato de teamSets.js). Sem golpes guardados, `moves`. Igual ao app. */
export function boxToSet(entry, moves) {
  const list = entry.moves?.length ? entry.moves : moves
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v))
  return {
    level: clamp(entry.level ?? 50, 1, 100), shiny: entry.shiny === true, nature: entry.nature ?? 'Hardy', item: entry.item ?? '', ability: '',
    moves: [0, 1, 2, 3].map((i) => list[i] ?? ''),
    evs: Object.fromEntries(STATS.map((s) => [s, clamp(entry.evs?.[s] ?? 0, 0, 252)])),
    ivs: Object.fromEntries(STATS.map((s) => [s, clamp(entry.ivs?.[s] ?? 31, 0, 31)])),
  }
}

/**
 * O resumo da corrida que acabou (igual ao app): capturas, treinadores
 * vencidos, chefes, insígnias, quem caiu no Nuzlocke, o time e o MVP (quem
 * mais ganhou XP; sem XP contado, o de nível mais alto) — [id, nível, shiny].
 */
export function runSummary(run) {
  const card = (m) => [m.id, m.level ?? 1, m.shiny ? 1 : 0]
  let mvp = null
  for (const m of run.team ?? []) {
    if (!mvp || (m.xpRun ?? 0) > (mvp.xpRun ?? 0) || ((m.xpRun ?? 0) === (mvp.xpRun ?? 0) && (m.level ?? 1) > (mvp.level ?? 1))) mvp = m
  }
  return {
    captures: Math.max(0, dexOf(run).length - 1),
    defeated: run.defeated ?? 0,
    bosses: run.bosses ?? 0,
    badges: run.badges ?? 0,
    ...(run.nuzlocke ? { fallen: run.fallen ?? 0 } : {}),
    team: (run.team ?? []).map(card),
    ...(mvp ? { mvp: card(mvp) } : {}),
  }
}

/**
 * A Pokédex do Pokelike: os Pokémon vistos (os adversários de cada batalha) e
 * os capturados (os do time e da Pokédex da corrida) ficam na conta, para a
 * Pokédex marcar "visto" e "capturado". Devolve a mesma Factory se não mudou
 * nada. Igual ao app.
 */
export function withSeen(factory, data = null) {
  const run = factory?.run
  if (!run) return factory
  const seen = new Set(factory.seen ?? [])
  const caught = new Set(factory.caught ?? [])
  const before = [seen.size, caught.size]
  // A forma regional marca também a espécie dela (o Meowth de Galar conta como Meowth).
  const species = (id) => data?.formSpecies?.[id]?.[8] || null
  for (const f of run.encounter?.foes ?? []) {
    seen.add(f.id)
    if (species(f.id)) seen.add(species(f.id))
  }
  // Capturados na corrida (e quem evoluiu no time).
  for (const id of dexOf(run)) caught.add(id)
  for (const m of run.team ?? []) caught.add(m.id)
  for (const id of [...caught]) if (species(id)) caught.add(species(id))
  if (seen.size === before[0] && caught.size === before[1]) return factory
  const sorted = (set) => [...set].sort((a, b) => a - b)
  return { ...factory, seen: sorted(seen), caught: sorted(caught) }
}

/** Uma forma regional (Alola, Galar, Hisui, Paldea) pelo id. */
export const isRegionalForm = (id) => id >= 10091 && id <= 10254
const metaCaught = (r) => new Set([...(r._caught ?? []), ...dexOf(r), ...(r.team ?? []).map((m) => m.id)])

/** Quantas corridas o histórico guarda. */
export const HISTORY_SIZE = 10
/** As últimas corridas (a mais nova primeiro): o dia, o andar, as moedas, os itens da árvore, o modo e o resumo. Igual ao app. */
export function addToHistory(history = [], run, coins, date = new Date().toISOString().slice(0, 10)) {
  const entry = {
    date, floor: run.floor - 1, coins,
    ...(run.pieces && typeof run.pieces === 'object' ? { pieces: piecesOf(run) } : {}),
    modes: [...(run.nuzlocke ? ['nuzlocke'] : []), ...RUN_MODES.filter((m) => run[m] != null && run[m] !== false)],
    summary: runSummary(run),
  }
  return [entry, ...history].slice(0, HISTORY_SIZE)
}

/** Quantas corridas a galeria guarda (as melhores). */
export const GALLERY_SIZE = 5

/**
 * A galeria das melhores corridas (igual ao app): o andar, o time ([id, nível,
 * shiny]) e o dia, as de andar mais alto primeiro.
 */
export function addToGallery(gallery = [], run, date = new Date().toISOString().slice(0, 10)) {
  const floor = run.floor - 1
  if (floor < 1) return gallery
  const entry = { floor, team: (run.team ?? []).map((m) => [m.id, m.level ?? 1, m.shiny ? 1 : 0]), date, ...(run.nuzlocke ? { nuzlocke: true } : {}), ...(run.weekly ? { weekly: true } : {}), ...(run.games ? { games: run.games } : {}) }
  return [...gallery, entry].sort((a, b) => b.floor - a.floor).slice(0, GALLERY_SIZE)
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

/**
 * Os golpes novos subindo de from para to (os por nível que ficam liberados no caminho, com a regra do poder), na ordem
 * em que ele aprende. Igual ao app (movesLearnedBetween).
 */
export function movesLearnedBetween(formMoves, from, to, moves) {
  const knows = (m, level) => m[1] === 'level-up' && m[2] <= level && moves[m[0]] && level >= movePowerLevel(ESCALATING[m[0]] ?? moves[m[0]].power ?? 0)
  const levelUp = [...formMoves].sort((a, b) => a[2] - b[2])
  const before = new Set(levelUp.filter((m) => knows(m, from)).map((m) => m[0]))
  const out = []
  for (const m of levelUp) if (knows(m, to) && !before.has(m[0]) && !out.includes(m[0])) out.push(m[0])
  return out
}

/** Aprende move subindo de nível: com vaga entra no fim; com 4, no lugar do golpe slot. current: os golpes de agora. */
export function learnMove(run, index, move, current, slot = -1) {
  const mon = run.team[index]
  if (!mon || current.includes(move)) return run
  const moves = [...current]
  if (moves.length < 4) moves.push(move)
  else if (slot >= 0 && slot < moves.length) moves[slot] = move
  else return run
  return { ...run, team: run.team.map((m, i) => (i === index ? { ...m, moves } : m)) }
}

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
  const mine = { ...none, ...run.bag }
  // Nuzlocke sem itens na batalha: só as Poké Balls entram (as poções ficam para fora dela).
  return [nuzRule(run, 'noBattleItems') ? Object.fromEntries(Object.entries(mine).map(([id, n]) => [id, BALL_IDS.includes(id) ? n : 0])) : mine, foe]
}

/**
 * A captura na batalha (input.capture do motor): só com selvagens. rates: a
 * taxa de captura de cada adversário; dusk: rota escura (Dusk Ball 3×).
 */
export function captureFor(run, data) {
  const { kind, foes, biome } = run.encounter ?? {}
  if (kind !== 'wild' && kind !== 'wildboss') return null
  // Nuzlocke: um capturado por área.
  // Nuzlocke: um capturado por área (a rota, a cidade e cada lugar contam separados).
  if (run.nuzlocke && areaUsed(run) && !(nuzRule(run, 'shinyClause') && foes.some((f) => f.shiny))) return null
  // Nuzlocke sem lendários: lendários e míticos não podem ser capturados.
  if (nuzRule(run, 'noLegendary') && foes.some((f) => [1, 2].includes(speciesOf(data, f.id)?.[2]))) return null
  // Monotipo: só quem tem um tipo do inicial.
  if (run.mono && !foes.some((f) => (speciesOf(data, f.id)?.[4] ?? []).some((t) => run.mono.includes(t)))) return null
  return { rates: foes.map((f) => speciesOf(data, f.id)?.[5] ?? 45), dusk: DARK_BIOMES.includes(biome), ...(run.catchBonus ? { bonus: run.catchBonus } : {}) }
}

/**
 * A ordem na batalha: quem está de pé primeiro (o primeiro entra em campo). Posições no time da corrida.
 * Nuzlocke (leaderCount): contra o líder, a Elite dos Quatro e o Campeão, só tantos quantos ele tem.
 */
export function battleOrder(run) {
  const order = [...run.team.keys()].sort((a, b) => Number((run.team[b].hp ?? 1) > 0) - Number((run.team[a].hp ?? 1) > 0))
  const boss = run.encounter?.kind === 'boss' && CITY_KINDS.includes(run.encounter.boss?.kind)
  return boss && nuzRule(run, 'leaderCount') ? order.slice(0, Math.max(1, run.encounter.foes.length)) : order
}

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
  // Nuzlocke sem itens de segurar: os extras também não contam.
  if (!nuzRule(run, 'noHeldItems')) for (const id of mon.extras ?? []) out = addStats(out, HELD_BOOST[id])
  return Object.fromEntries(STATS.map((s) => [s, round3(out[s])]))
}

/** O Pokémon da corrida como membro de time (battleSetup.battleMons). moveList: os do nível (se ele não aprendeu outros). */
export function memberOf(run, mon, moveList, data = null) {
  const gimmick = data ? gimmickOf(data, run, mon) : ''
  return {
    id: mon.id,
    set: {
      level: mon.level, levelCap: 'none', nature: mon.nature, ivs: capStats(mon.ivs, 31), evs: capStats(mon.evs, 252), item: nuzRule(run, 'noHeldItems') ? '' : mon.item ?? '',
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
      ...(foe.boost || foe.shiny ? { boost: Object.fromEntries(STATS.map((s) => [s, round3((foe.boost ?? 0) + (foe.shiny ? FOE_SHINY_BOOST : 0))])) } : {}),
      ...(foe.shiny ? { shiny: true } : {}),
      ...(foe.item ? { item: foe.item } : {}),
      ...(foe.gimmick ? { gimmick: foe.gimmick } : {}),
      ...(foe.tera ? { tera: foe.tera } : {}),
    },
  }
}
