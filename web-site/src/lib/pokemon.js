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

export const STAT_LABELS = ['Hp', 'Attack', 'Defense', 'Sp. Atk', 'Sp. Def', 'Speed']

export const GENERATIONS = [
  { id: 1, name: 'Generation I', starters: [1, 4, 7] },
  { id: 2, name: 'Generation II', starters: [152, 155, 158] },
  { id: 3, name: 'Generation III', starters: [252, 255, 258] },
  { id: 4, name: 'Generation IV', starters: [387, 390, 393] },
  { id: 5, name: 'Generation V', starters: [495, 498, 501] },
  { id: 6, name: 'Generation VI', starters: [650, 653, 656] },
  { id: 7, name: 'Generation VII', starters: [722, 725, 728] },
  { id: 8, name: 'Generation VIII', starters: [810, 813, 816] },
  { id: 9, name: 'Generation IX', starters: [906, 909, 912] },
]

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
 * Análise de um time (mesma lógica do Montador de Times do app): combina os
 * multiplicadores dos membros e conta quantos membros têm vantagem sobre cada
 * tipo.
 */
export function analyzeTeam(membersTypes, typeData) {
  if (membersTypes.length === 0) return null
  const combined = Object.fromEntries(ALL_TYPES.map((t) => [t, 1]))
  const advantages = {}
  for (const types of membersTypes) {
    const rel = typeRelations(types, typeData)
    for (const attacking of ALL_TYPES) {
      if (rel.immunities.includes(attacking)) combined[attacking] = 0
      else if (combined[attacking] !== 0) {
        if (rel.weaknesses[attacking]) combined[attacking] *= rel.weaknesses[attacking]
        if (rel.resistances[attacking]) combined[attacking] *= rel.resistances[attacking]
      }
    }
    for (const type of types) {
      for (const t of typeData[type]?.double_damage_to ?? []) advantages[t] = (advantages[t] ?? 0) + 1
    }
  }
  const weaknesses = {}
  const resistances = {}
  const immunities = []
  for (const [type, mult] of Object.entries(combined)) {
    if (mult === 0) immunities.push(type)
    else if (mult > 1.5) weaknesses[type] = mult
    else if (mult < 0.75) resistances[type] = mult
  }
  immunities.sort()
  return { weaknesses, resistances, immunities, advantages }
}

/** Nota do time de 0 a 10 (mesma fórmula do app). */
export function teamScore(analysis) {
  if (!analysis) return 0
  let score = 5
  for (const mult of Object.values(analysis.weaknesses)) score -= (mult - 1) * 0.4
  for (const mult of Object.values(analysis.resistances)) score += (1 - mult) * 0.2
  score += analysis.immunities.length * 0.5
  score += (Object.keys(analysis.advantages).length / ALL_TYPES.length) * 2.5
  return Math.max(0, Math.min(10, score))
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
