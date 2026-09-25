// Regras de Pokémon usadas pelo site: cores dos tipos, fraquezas/resistências,
// análise de times e formatação — as mesmas do app.

export const TYPE_COLORS = {
  normal: '#A8A77A',
  fire: '#EE8130',
  water: '#6390F0',
  electric: '#F7D02C',
  grass: '#7AC74C',
  ice: '#96D9D6',
  fighting: '#C22E28',
  poison: '#A33EA1',
  ground: '#E2BF65',
  flying: '#A98FF3',
  psychic: '#F95587',
  bug: '#A6B91A',
  rock: '#B6A136',
  ghost: '#735797',
  dragon: '#6F35FC',
  dark: '#705746',
  steel: '#B7B7CE',
  fairy: '#D685AD',
}

export const ALL_TYPES = Object.keys(TYPE_COLORS)

export const typeColor = (type) => TYPE_COLORS[type?.toLowerCase()] ?? '#616161'

/**
 * Fundo de acordo com a tipagem: a cor do tipo, ou um gradiente entre as duas
 * cores quando o Pokémon tem dois tipos.
 */
export function typeBackground(types = []) {
  const [first, second] = types
  if (!second) return typeColor(first)
  return `linear-gradient(135deg, ${typeColor(first)} 20%, ${typeColor(second)} 85%)`
}

export const STAT_LABELS = ['Hp', 'Attack', 'Defense', 'Sp. Atk', 'Sp. Def', 'Speed']

// Cada geração com a região, os 3 iniciais e as cores dos jogos principais
// daquela geração (usadas em gradiente no seletor de geração).
export const GENERATIONS = [
  { id: 1, name: 'Generation I', region: 'Kanto', starters: [1, 4, 7], colors: ['#E3350D', '#3B7BD4'] }, // Red / Blue
  { id: 2, name: 'Generation II', region: 'Johto', starters: [152, 155, 158], colors: ['#C9A227', '#9EA3A8'] }, // Gold / Silver
  { id: 3, name: 'Generation III', region: 'Hoenn', starters: [252, 255, 258], colors: ['#B3122E', '#1F4FA8'] }, // Ruby / Sapphire
  { id: 4, name: 'Generation IV', region: 'Sinnoh', starters: [387, 390, 393], colors: ['#5F8FD0', '#C98AA0'] }, // Diamond / Pearl
  { id: 5, name: 'Generation V', region: 'Unova', starters: [495, 498, 501], colors: ['#2B2B2B', '#9A9A9A'] }, // Black / White
  { id: 6, name: 'Generation VI', region: 'Kalos', starters: [650, 653, 656], colors: ['#1E5AA8', '#C8102E'] }, // X / Y
  { id: 7, name: 'Generation VII', region: 'Alola', starters: [722, 725, 728], colors: ['#F28C28', '#5B3F9E'] }, // Sun / Moon
  { id: 8, name: 'Generation VIII', region: 'Galar', starters: [810, 813, 816], colors: ['#0091D5', '#D8006F'] }, // Sword / Shield
  { id: 9, name: 'Generation IX', region: 'Paldea', starters: [906, 909, 912], colors: ['#D0342C', '#7B3FA0'] }, // Scarlet / Violet
]

export const generationBackground = (gen) => `linear-gradient(135deg, ${gen.colors[0]} 15%, ${gen.colors[1]} 90%)`

export const capitalize = (text = '') => (text ? text[0].toUpperCase() + text.slice(1) : text)

/** "charizard-mega-x" → "Charizard mega x"; usado em golpes, itens, etc. */
export const prettyName = (name = '') => capitalize(name.replace(/-/g, ' '))

/** Nome curto exibido nos cards ("deoxys-normal" → "Deoxys"). */
export const displayName = (name = '') => capitalize(name.split('-')[0])

export function heightToFeet(decimetres) {
  const inches = decimetres * 3.93701
  const feet = Math.floor(inches / 12)
  const rest = Math.round(inches % 12)
  return `${feet}' ${String(rest).padStart(2, '0')}"`
}

export const weightToLbs = (hectograms) => `${(hectograms * 0.220462).toFixed(1)} lbs`

/**
 * Multiplicador de dano recebido por cada tipo atacante, para uma combinação
 * de tipos defensores.
 */
export function damageTaken(defenderTypes, typeData) {
  const result = Object.fromEntries(ALL_TYPES.map((t) => [t, 1]))
  for (const type of defenderTypes) {
    const rel = typeData[type]
    if (!rel) continue
    for (const t of rel.double_damage_from) result[t] *= 2
    for (const t of rel.half_damage_from) result[t] *= 0.5
    for (const t of rel.no_damage_from) result[t] *= 0
  }
  return result
}

/** Fraquezas, resistências, imunidades e vantagens de um Pokémon. */
export function typeRelations(types, typeData) {
  const taken = damageTaken(types, typeData)
  const weaknesses = {}
  const resistances = {}
  const immunities = []
  for (const [type, mult] of Object.entries(taken)) {
    if (mult === 0) immunities.push(type)
    else if (mult >= 2) weaknesses[type] = mult
    else if (mult < 1) resistances[type] = mult
  }
  const advantages = {}
  for (const type of types) {
    for (const t of typeData[type]?.double_damage_to ?? []) advantages[t] = 1
  }
  return { weaknesses, resistances, immunities, advantages }
}

/**
 * Análise de um time (mesma lógica do app, lib/utils/team_analysis.dart).
 * Para cada tipo de ataque conta quantos membros são fracos, resistem ou são
 * imunes; o time é fraco a um tipo quando tem mais fracos do que quem aguenta.
 * No ataque, conta quantos membros acertam cada tipo com dano super efetivo
 * usando golpes do próprio tipo (STAB).
 */
export function analyzeTeam(membersTypes, typeData) {
  if (membersTypes.length === 0) return null
  const rows = {}
  for (const attacking of ALL_TYPES) rows[attacking] = { weak: 0, x4: 0, resist: 0, immune: 0 }
  const advantages = {}
  for (const types of membersTypes) {
    const taken = damageTaken(types, typeData)
    for (const attacking of ALL_TYPES) {
      const mult = taken[attacking]
      const row = rows[attacking]
      if (mult === 0) row.immune++
      else if (mult > 1) {
        row.weak++
        if (mult >= 4) row.x4++
      } else if (mult < 1) row.resist++
    }
    for (const type of new Set(types)) {
      for (const t of typeData[type]?.double_damage_to ?? []) advantages[t] = (advantages[t] ?? 0) + 1
    }
  }
  const severity = (r) => r.weak + r.x4 - r.resist - r.immune
  const weaknesses = ALL_TYPES.filter((t) => rows[t].weak > rows[t].resist + rows[t].immune)
    .sort((a, b) => severity(rows[b]) - severity(rows[a]))
    .map((t) => [t, rows[t]])
  const strengths = ALL_TYPES.filter((t) => rows[t].resist + rows[t].immune >= 2 && rows[t].resist + rows[t].immune > rows[t].weak)
    .sort((a, b) => severity(rows[a]) - severity(rows[b]))
    .map((t) => [t, rows[t]])
  const immunities = ALL_TYPES.filter((t) => rows[t].immune > 0)
  const missing = ALL_TYPES.filter((t) => !advantages[t])
  return { rows, weaknesses, strengths, immunities, advantages, missing, size: membersTypes.length }
}

/** Texto curto de uma linha da análise: "3 fracos · 1 resiste". */
export function rowSummary(row) {
  const parts = []
  if (row.weak) parts.push(`${row.weak} ${row.weak === 1 ? 'fraco' : 'fracos'}${row.x4 ? ` (${row.x4} ×4)` : ''}`)
  if (row.resist) parts.push(`${row.resist} ${row.resist === 1 ? 'resiste' : 'resistem'}`)
  if (row.immune) parts.push(`${row.immune} ${row.immune === 1 ? 'imune' : 'imunes'}`)
  return parts.join(' · ')
}

/** Golpes aprendidos por nível (ou G-Max), ordenados — igual à aba Moves do app. */
export function levelUpMoves(form) {
  const isGmax = form.name.includes('gmax')
  const byMove = new Map()
  for (const [name, method, level] of form.moves) {
    if (isGmax ? name.includes('gmax') : method === 'level-up' && level > 0) {
      byMove.set(name, Math.max(level, byMove.get(name) ?? 0))
    }
  }
  return [...byMove.entries()].map(([name, level]) => ({ name, level })).sort((a, b) => a.level - b.level)
}

export const NATURES = [
  ['Hardy', 'Attack', 'Attack'],
  ['Lonely', 'Attack', 'Defense'],
  ['Brave', 'Attack', 'Speed'],
  ['Adamant', 'Attack', 'Sp. Atk'],
  ['Naughty', 'Attack', 'Sp. Def'],
  ['Bold', 'Defense', 'Attack'],
  ['Docile', 'Defense', 'Defense'],
  ['Relaxed', 'Defense', 'Speed'],
  ['Impish', 'Defense', 'Sp. Atk'],
  ['Lax', 'Defense', 'Sp. Def'],
  ['Timid', 'Speed', 'Attack'],
  ['Hasty', 'Speed', 'Defense'],
  ['Serious', 'Speed', 'Speed'],
  ['Jolly', 'Speed', 'Sp. Atk'],
  ['Naive', 'Speed', 'Sp. Def'],
  ['Modest', 'Sp. Atk', 'Attack'],
  ['Mild', 'Sp. Atk', 'Defense'],
  ['Quiet', 'Sp. Atk', 'Speed'],
  ['Bashful', 'Sp. Atk', 'Sp. Atk'],
  ['Rash', 'Sp. Atk', 'Sp. Def'],
  ['Calm', 'Sp. Def', 'Attack'],
  ['Gentle', 'Sp. Def', 'Defense'],
  ['Sassy', 'Sp. Def', 'Speed'],
  ['Careful', 'Sp. Def', 'Sp. Atk'],
  ['Quirky', 'Sp. Def', 'Sp. Def'],
].map(([name, increases, decreases]) => ({ name, increases, decreases, neutral: increases === decreases }))

export const EV_STATS = [
  { key: 'hp', label: 'HP', color: '#4caf50' },
  { key: 'attack', label: 'Attack', color: '#f44336' },
  { key: 'defense', label: 'Defense', color: '#2196f3' },
  { key: 'special-attack', label: 'Sp. Atk', color: '#9c27b0' },
  { key: 'special-defense', label: 'Sp. Def', color: '#fbc02d' },
  { key: 'speed', label: 'Speed', color: '#e91e63' },
]

export const MAX_TOTAL_EVS = 510
export const MAX_STAT_EVS = 252
