// Calculadora de dano: usa a calculadora oficial do Pokémon Showdown
// (@smogon/calc, licença MIT), geração 9. Aqui só traduzimos os nossos dados
// (nomes do PokeAPI, status base, tipos e peso) para ela e o resultado para
// português. É carregado só na página da calculadora.
//
// O app usa a mesma conta, portada para Dart em lib/services/damage_calc.dart
// (testada contra esta biblioteca).

import { calculate, Field, Generations, Move, Pokemon } from '@smogon/calc'

const gen = Generations.get(9)

export const toId = (s) => String(s ?? '').toLowerCase().replace(/[^a-z0-9]/g, '')
const cap = (s) => s.charAt(0).toUpperCase() + s.slice(1)

// ------------------------------------------------------------------ nomes

const SPECIES = new Map([...gen.species].map((s) => [toId(s.name), s.name]))
// Formas cujo nome no PokeAPI não bate com o do Showdown nem cortando o fim.
const SPECIES_ALIASES = {
  'necrozma-dusk': 'Necrozma-Dusk-Mane',
  'necrozma-dawn': 'Necrozma-Dawn-Wings',
  'zygarde-10-power-construct': 'Zygarde-10%',
  'zygarde-10': 'Zygarde-10%',
  'zygarde-50-power-construct': 'Zygarde',
  'meowstic-female': 'Meowstic-F',
  'indeedee-female': 'Indeedee-F',
  'basculegion-female': 'Basculegion-F',
  'oinkologne-female': 'Oinkologne-F',
  'ogerpon-wellspring-mask': 'Ogerpon-Wellspring',
  'ogerpon-hearthflame-mask': 'Ogerpon-Hearthflame',
  'ogerpon-cornerstone-mask': 'Ogerpon-Cornerstone',
  'greninja-battle-bond': 'Greninja-Bond',
  'rockruff-own-tempo': 'Rockruff',
  'minior-red-meteor': 'Minior-Meteor',
}

/** Nome da espécie no Showdown ("tauros-paldea-combat-breed" → "Tauros-Paldea-Combat"). */
export function speciesName(slug) {
  if (SPECIES_ALIASES[slug]) return SPECIES_ALIASES[slug]
  const parts = String(slug).split('-')
  for (let n = parts.length; n > 0; n--) {
    const name = SPECIES.get(toId(parts.slice(0, n).join('-')))
    if (name) return name
  }
  return 'Mew' // qualquer um: os status, tipos e peso vêm dos nossos dados
}

const MOVES = new Map([...gen.moves].map((m) => [toId(m.name), m]))
const ABILITIES = new Map([...gen.abilities].map((a) => [toId(a.name), a.name]))
const ITEM_NAMES = new Map([...gen.items].map((i) => [toId(i.name), i.name]))

/** Golpe do Showdown pelo nome do PokeAPI ("close-combat"), ou null. */
export const moveData = (slug) => MOVES.get(toId(slug)) ?? null
export const abilityName = (slug) => ABILITIES.get(toId(slug)) ?? ''
export const itemName = (text) => ITEM_NAMES.get(toId(text)) ?? ''

/** Todas as habilidades e itens (para as listas de busca). */
export const ALL_ABILITIES = [...ABILITIES.values()].sort()
const HELD = [...gen.items].filter((i) => !/ Ball$|^TR\d|^TM\d/.test(i.name))
// Itens mais usados em batalha primeiro.
export const POPULAR_ITEMS = [
  'Choice Band', 'Choice Specs', 'Choice Scarf', 'Life Orb', 'Leftovers', 'Focus Sash', 'Assault Vest', 'Heavy-Duty Boots',
  'Expert Belt', 'Eviolite', 'Booster Energy', 'Rocky Helmet', 'Sitrus Berry', 'Lum Berry', 'Black Sludge', 'Loaded Dice',
  'Clear Amulet', 'Covert Cloak', 'Air Balloon', 'Weakness Policy', 'Light Clay', 'Punching Glove', 'Mirror Herb', 'Throat Spray',
]
export const ALL_ITEMS = [...new Set([...POPULAR_ITEMS, ...HELD.map((i) => i.name).sort()])]

// ------------------------------------------------------------------ opções

export const WEATHERS = [
  ['', 'Nenhum'],
  ['Sun', 'Sol'],
  ['Rain', 'Chuva'],
  ['Sand', 'Tempestade de areia'],
  ['Snow', 'Neve'],
  ['Harsh Sunshine', 'Sol extremo (Desolate Land)'],
  ['Heavy Rain', 'Chuva forte (Primordial Sea)'],
  ['Strong Winds', 'Ventos fortes (Delta Stream)'],
]
export const TERRAINS = [
  ['', 'Nenhum'],
  ['Electric', 'Electric Terrain'],
  ['Grassy', 'Grassy Terrain'],
  ['Psychic', 'Psychic Terrain'],
  ['Misty', 'Misty Terrain'],
]
export const STATUSES = [
  ['', 'Saudável'],
  ['brn', 'Queimado'],
  ['par', 'Paralisado'],
  ['psn', 'Envenenado'],
  ['tox', 'Muito envenenado'],
  ['slp', 'Dormindo'],
  ['frz', 'Congelado'],
]
export const STAT_KEYS = ['hp', 'atk', 'def', 'spa', 'spd', 'spe']
export const STAT_LABELS = { hp: 'HP', atk: 'Atk', def: 'Def', spa: 'Sp. Atk', spd: 'Sp. Def', spe: 'Speed' }

// Habilidades que dependem de algo que a conta não vê (ligar/desligar).
export const TOGGLE_ABILITIES = {
  'Flash Fire': 'Flash Fire ativado',
  Protosynthesis: 'Protosynthesis ativa',
  'Quark Drive': 'Quark Drive ativa',
  Stakeout: 'O alvo acabou de entrar',
  Analytic: 'Age depois do alvo',
  'Slow Start': 'Slow Start ativo',
  Intimidate: 'Intimidate no adversário',
  Unburden: 'Unburden ativo',
  Plus: 'Aliado com Plus/Minus',
  Minus: 'Aliado com Plus/Minus',
  Electromorphosis: 'Carregado (Electromorphosis)',
  'Intrepid Sword': 'Intrepid Sword ao entrar',
  'Dauntless Shield': 'Dauntless Shield ao entrar',
  'Teraform Zero': 'Teraform Zero ativo',
  'Wind Rider': 'Wind Rider ativado',
}

// Habilidades que mudam o clima ou o terreno ao entrar (como no Showdown).
export const ABILITY_FIELD = {
  Drought: { weather: 'Sun' },
  'Orichalcum Pulse': { weather: 'Sun' },
  Drizzle: { weather: 'Rain' },
  'Sand Stream': { weather: 'Sand' },
  'Snow Warning': { weather: 'Snow' },
  'Desolate Land': { weather: 'Harsh Sunshine' },
  'Primordial Sea': { weather: 'Heavy Rain' },
  'Delta Stream': { weather: 'Strong Winds' },
  'Electric Surge': { terrain: 'Electric' },
  'Hadron Engine': { terrain: 'Electric' },
  'Grassy Surge': { terrain: 'Grassy' },
  'Psychic Surge': { terrain: 'Psychic' },
  'Misty Surge': { terrain: 'Misty' },
}

export const newSide = (evs = {}) => ({
  level: 50,
  nature: 'Hardy',
  ability: '',
  abilityOn: false,
  item: '',
  teraType: '',
  terastallized: false,
  status: '',
  hpPct: 100,
  evs: { hp: 0, atk: 0, def: 0, spa: 0, spd: 0, spe: 0, ...evs },
  ivs: { hp: 31, atk: 31, def: 31, spa: 31, spd: 31, spe: 31 },
  boosts: { atk: 0, def: 0, spa: 0, spd: 0, spe: 0 },
  alliesFainted: 0,
})

export const newField = () => ({
  gameType: 'Singles',
  weather: '',
  terrain: '',
  gravity: false,
  trickRoom: false,
  magicRoom: false,
  wonderRoom: false,
  swordOfRuin: false,
  beadsOfRuin: false,
  tabletsOfRuin: false,
  vesselOfRuin: false,
  fairyAura: false,
  darkAura: false,
  auraBreak: false,
  // Lado de quem ataca.
  helpingHand: false,
  battery: false,
  powerSpot: false,
  steelySpirit: false,
  flowerGift: false,
  charge: false,
  attackerTailwind: false,
  // Lado de quem defende.
  reflect: false,
  lightScreen: false,
  auroraVeil: false,
  friendGuard: false,
  stealthRock: false,
  spikes: 0,
  saltCure: false,
  leechSeed: false,
  protect: false,
  defenderTailwind: false,
  switchingOut: false,
})

export const newMoveOptions = () => ({ crit: false, hits: 0, timesUsed: 1, metronome: 1, stellarFirst: true })

// ------------------------------------------------------------------ conta

/**
 * Pokémon da calculadora.
 * base: {name (PokeAPI), types, stats: [hp, atk, def, spa, spd, spe] (base), weight (hectogramas)}
 */
function makePokemon(base, side) {
  const [hp, atk, def, spa, spd, spe] = base.stats
  const ability = side.ability || undefined
  const options = {
    level: side.level,
    nature: side.nature,
    ability,
    abilityOn: side.abilityOn,
    item: side.item || undefined,
    teraType: side.terastallized && side.teraType ? cap(side.teraType) : undefined,
    status: side.status || '',
    evs: side.evs,
    ivs: side.ivs,
    boosts: side.boosts,
    alliesFainted: side.alliesFainted,
    overrides: {
      baseStats: { hp, atk, def, spa, spd, spe },
      types: base.types.map(cap),
      weightkg: (base.weight ?? 100) / 10,
    },
  }
  if (ability === 'Protosynthesis' || ability === 'Quark Drive') options.boostedStat = 'auto'
  const pokemon = new Pokemon(gen, speciesName(base.name), options)
  // Ativada sem sol / Electric Terrain / Booster Energy: o maior status sobe.
  if (options.boostedStat && side.abilityOn) {
    let best = 'atk'
    for (const stat of ['def', 'spa', 'spd', 'spe']) if (pokemon.stats[stat] > pokemon.stats[best]) best = stat
    pokemon.boostedStat = best
  }
  pokemon.originalCurHP = Math.max(1, Math.floor((pokemon.maxHP() * side.hpPct) / 100))
  return pokemon
}

function makeField(f) {
  return new Field({
    gameType: f.gameType,
    weather: f.weather || undefined,
    terrain: f.terrain || undefined,
    isGravity: f.gravity,
    isMagicRoom: f.magicRoom,
    isWonderRoom: f.wonderRoom,
    isSwordOfRuin: f.swordOfRuin,
    isBeadsOfRuin: f.beadsOfRuin,
    isTabletsOfRuin: f.tabletsOfRuin,
    isVesselOfRuin: f.vesselOfRuin,
    isFairyAura: f.fairyAura,
    isDarkAura: f.darkAura,
    isAuraBreak: f.auraBreak,
    attackerSide: {
      isHelpingHand: f.helpingHand,
      isBattery: f.battery,
      isPowerSpot: f.powerSpot,
      isSteelySpirit: f.steelySpirit,
      isFlowerGift: f.flowerGift,
      isCharge: f.charge,
      isTailwind: f.attackerTailwind,
    },
    defenderSide: {
      isReflect: f.reflect,
      isLightScreen: f.lightScreen,
      isAuroraVeil: f.auroraVeil,
      isFriendGuard: f.friendGuard,
      isSR: f.stealthRock,
      spikes: f.spikes,
      isSaltCured: f.saltCure,
      isSeeded: f.leechSeed,
      isProtected: f.protect,
      isTailwind: f.defenderTailwind,
      isSwitching: f.switchingOut ? 'out' : undefined,
    },
  })
}

/** Status do Pokémon com Nature, EVs, IVs e estágios (sem itens nem campo). */
export function sideStats(base, side) {
  try {
    const p = makePokemon(base, side)
    return { stats: p.stats, maxHP: p.maxHP(), curHP: p.curHP() }
  } catch {
    return null
  }
}

/** Número de acertos que o golpe pode ter ([2, 5], 3...) ou null. */
export function hitRange(slug) {
  const mv = moveData(slug)
  if (!mv?.multihit) return null
  return Array.isArray(mv.multihit) ? mv.multihit : [mv.multihit, mv.multihit]
}

/**
 * Dano de um golpe.
 * Devolve null se o golpe não existir, ou
 * {rolls (por acerto), min, max, minPct, maxPct, hp, curHP, ko: {chance, n, text}, desc, noDamage}.
 */
export function run({ attacker, attackerSide, defender, defenderSide, moveSlug, moveOptions, field }) {
  const data = moveData(moveSlug)
  if (!data) return null
  try {
    const a = makePokemon(attacker, attackerSide)
    const d = makePokemon(defender, defenderSide)
    const opts = { isCrit: moveOptions.crit, isStellarFirstUse: moveOptions.stellarFirst }
    if (moveOptions.hits) opts.hits = moveOptions.hits
    if (moveOptions.timesUsed > 1) opts.timesUsed = moveOptions.timesUsed
    if (moveOptions.metronome > 1) opts.timesUsedWithMetronome = moveOptions.metronome
    const move = new Move(gen, data.name, { ...opts, ability: a.ability, item: a.item })
    const result = calculate(gen, a, d, move, makeField(field))
    const [min, max] = result.range()
    const hp = result.defender.maxHP()
    const curHP = result.defender.curHP()
    const pct = (n) => Math.round((n / hp) * 1000) / 10
    let ko = { chance: 0, n: 0, text: '' }
    let desc = ''
    if (max > 0) {
      try {
        ko = result.kochance()
        desc = result.fullDesc('%', false)
      } catch {
        // sem dano
      }
    }
    const raw = result.damage
    const rolls = typeof raw === 'number' ? [[raw]] : typeof raw[0] === 'number' ? [raw] : raw
    return {
      name: data.name,
      type: result.move.type.toLowerCase(),
      category: result.move.category,
      bp: result.move.bp,
      hits: result.move.hits,
      rolls,
      min,
      max,
      hp,
      curHP,
      minPct: pct(min),
      maxPct: pct(max),
      ko,
      koText: koTextPt(ko, max),
      desc,
      noDamage: max === 0,
      attackerStats: result.attacker.stats,
      defenderStats: result.defender.stats,
    }
  } catch (error) {
    console.error(error)
    return null
  }
}

// ------------------------------------------------------------------ texto

const EOT_PT = [
  [/^Stealth Rock$/, 'Stealth Rock'],
  [/^(\d) layers? of Spikes$/, (m) => `${m[1]} ${m[1] === '1' ? 'camada' : 'camadas'} de Spikes`],
  [/^Spikes$/, 'Spikes'],
  [/^Steelsurge$/, 'Steelsurge'],
  [/^(.+) recovery$/, (m) => `recuperação do ${m[1]}`],
  [/^(.+) damage$/, (m) => `dano de ${DAMAGE_PT[m[1]] ?? m[1]}`],
  [/^Leech Seed damage$/, 'Leech Seed'],
]
const DAMAGE_PT = {
  sandstorm: 'tempestade de areia',
  hail: 'granizo',
  burn: 'queimadura',
  poison: 'veneno',
  toxic: 'veneno',
  'Salt Cure': 'Salt Cure',
  'Sticky Barb': 'Sticky Barb',
  'Black Sludge': 'Black Sludge',
}
const translatePart = (text) => {
  for (const [rx, to] of EOT_PT) {
    const m = text.match(rx)
    if (m) return typeof to === 'function' ? to(m) : to
  }
  return text
}
const translateAfter = (after) =>
  after
    .split(/, and |, | and /)
    .map((part) => translatePart(part.trim()))
    .filter(Boolean)
    .reduce((acc, part, i, all) => acc + (i === 0 ? '' : i === all.length - 1 ? ' e ' : ', ') + part, '')

const hitsText = (n, turns) => (turns ? `${n} turnos` : n === 1 ? '1 golpe' : `${n} golpes`)
const pctText = (x) => `${String(x).replace('.', ',')}%`

/** "Derrota com 1 golpe, garantido" / "12,5% de chance de derrotar com 2 golpes, depois de Stealth Rock". */
export function koTextPt(ko, max) {
  if (!max) return 'Não causa dano.'
  const text = ko?.text ?? ''
  if (!text) return 'Não derrota.'
  const one = (part) => {
    let m = part.match(/^(approx\. )?(guaranteed|possible|not a KO|([\d.]+)% chance to) ?(OHKO|(\d+)HKO|KO in (\d+) turns)?(?: after (.+))?$/)
    if (!m) return part
    const approx = m[1] ? 'aprox. ' : ''
    if (m[2] === 'not a KO') return 'Não derrota.'
    const n = m[4] === 'OHKO' ? 1 : Number(m[5] ?? m[6])
    const how = hitsText(n, Boolean(m[6]))
    const after = m[7] ? `, depois de ${translateAfter(m[7])}` : ''
    if (m[2] === 'guaranteed') return `Derrota com ${how}, garantido${after}.`
    if (m[2] === 'possible') return `${approx}Pode derrotar com ${how}${after}.`
    return `${approx}${pctText(m[3])} de chance de derrotar com ${how}${after}.`
  }
  // "30% chance to 2HKO after Stealth Rock (guaranteed 2HKO after Leftovers recovery)"
  const paren = text.match(/^(.*?) \((.*)\)$/)
  if (paren) {
    const inner = one(paren[2]).replace(/\.$/, '')
    return `${one(paren[1]).replace(/\.$/, '')} (${inner.charAt(0).toLowerCase()}${inner.slice(1)}).`
  }
  return one(text)
}
