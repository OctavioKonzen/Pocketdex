// Desafio do dia e rankings da semana. O app (lib/services/league.dart) usa
// exatamente as mesmas contas, então o desafio é o mesmo no site e no celular.
//
//   • O dia e a semana seguem o horário de Brasília (UTC−3).
//   • A semana é identificada pela segunda-feira dela ("AAAA-MM-DD").
//   • Os 10 Pokémon do dia saem de um sorteio com semente = a data.

export const DAILY_ROUNDS = 10
export const DAILY_SECONDS = 10
export const DAILY_SPECIES = 1025 // Pokémon nacionais usados no desafio

const BRASILIA = -3 * 60 * 60 * 1000

function brasiliaDate(now = Date.now()) {
  return new Date(now + BRASILIA)
}

const iso = (d) => d.toISOString().slice(0, 10)

/** "2026-09-25" — o dia de hoje em Brasília. */
export function dayKey(now = Date.now()) {
  return iso(brasiliaDate(now))
}

/** "2026-09-21" — a segunda-feira da semana de hoje em Brasília. */
export function weekKey(now = Date.now()) {
  const d = brasiliaDate(now)
  const sinceMonday = (d.getUTCDay() + 6) % 7
  d.setUTCDate(d.getUTCDate() - sinceMonday)
  return iso(d)
}

/** Sorteio com semente (mulberry32): mesma semente, mesma sequência. */
export function seededRandom(seed) {
  let a = seed | 0
  return () => {
    a = (a + 0x6d2b79f5) | 0
    let t = Math.imul(a ^ (a >>> 15), 1 | a)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

/** Semente a partir de um texto (ex.: a data). */
export function seedOf(text) {
  let h = 0
  for (const ch of text) h = (Math.imul(31, h) + ch.charCodeAt(0)) | 0
  return h
}

/** Os ids dos 10 Pokémon do desafio de um dia (iguais para todo mundo). */
export function dailyAnswers(day = dayKey()) {
  const random = seededRandom(seedOf(`pocketdex-${day}`))
  const ids = []
  while (ids.length < DAILY_ROUNDS) {
    const id = 1 + Math.floor(random() * DAILY_SPECIES)
    if (!ids.includes(id)) ids.push(id)
  }
  return ids
}

/** Pontos de uma resposta certa no desafio: 1000 + décimos de segundo que sobraram. */
export function dailyPoints(msLeft) {
  return 1000 + Math.max(0, Math.min(DAILY_SECONDS * 10, Math.floor(msLeft / 100)))
}
