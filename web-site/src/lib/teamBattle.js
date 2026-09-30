// Batalha de times (igual ao app, lib/services/team_battle.dart): cada
// Pokémon de um time contra cada um do outro, 1 contra 1. Com a calculadora
// de dano do Showdown, vê o melhor golpe de cada lado e quantos golpes precisa
// para derrotar o outro; ganha quem derruba em menos golpes (empate: o mais
// rápido ataca primeiro e ganha).

import { getPokemonById, getSpecies } from './data'

const NONE = { move: '', pct: 0, hits: 99 }

/** 1 = o primeiro ganha, -1 = perde, 0 = empate. */
export function duelResult(d) {
  if (d.mine.hits === 99 && d.theirs.hits === 99) return 0
  if (d.mine.hits !== d.theirs.hits) return d.mine.hits < d.theirs.hits ? 1 : -1
  if (d.sameSpeed) return 0
  return d.faster ? 1 : -1
}

async function fighter(calc, byId, { id, set }) {
  const entry = byId.get(id)
  if (!entry) return null
  const species = await getSpecies(entry.species ?? id)
  const form = species.forms.find((f) => f.id === id) ?? species.forms[0]
  const base = { name: form.name, types: form.types, stats: form.stats.map((s) => s[0]), weight: form.weight }
  const side = {
    ...calc.newSide(),
    level: set?.level ?? 50,
    nature: set?.nature || 'Hardy',
    ability: calc.abilityName(set?.ability ?? '') || calc.abilityName(form.abilities?.[0]?.[0] ?? ''),
    item: calc.itemName(set?.item ?? ''),
  }
  if (set?.evs) side.evs = { ...side.evs, ...set.evs }
  if (set?.ivs) side.ivs = { ...side.ivs, ...set.ivs }
  const damaging = (slug) => {
    const m = calc.moveData(slug)
    return m && m.category !== 'Status'
  }
  const chosen = (set?.moves ?? []).filter((s) => s && damaging(s))
  const moves = chosen.length ? chosen : trim(calc, [...new Set(form.moves.map((m) => m[0]))].filter(damaging))
  const speed = calc.sideStats(base, side)?.stats.spe ?? 0
  return { id, base, side, moves, speed }
}

/** Sem set: os 2 golpes mais fortes de cada tipo e categoria (e os de dano fixo), como no app. */
function trim(calc, slugs) {
  const groups = new Map()
  const fixed = []
  for (const slug of slugs) {
    const m = calc.moveData(slug)
    if (!m.basePower) fixed.push(slug)
    else {
      const key = `${m.type}/${m.category}`
      groups.set(key, [...(groups.get(key) ?? []), slug])
    }
  }
  return [...[...groups.values()].flatMap((g) => g.sort((x, y) => calc.moveData(y).basePower - calc.moveData(x).basePower).slice(0, 2)), ...fixed]
}

function best(calc, a, b) {
  const top = calc.bestHit(a.base, a.side, b.base, b.side, a.moves)
  return top ? { move: top.move, pct: top.pct, hits: Math.min(98, Math.max(1, Math.ceil(100 / top.pct))) } : NONE
}

const duel = (calc, x, y) => {
  const d = { mine: best(calc, x, y), theirs: best(calc, y, x), faster: x.speed > y.speed, sameSpeed: x.speed === y.speed }
  return { ...d, result: duelResult(d) }
}

/** Todos os confrontos: [i][j] = Pokémon i do primeiro time contra o j do outro. Membros: {id, set}. */
export async function runBattle(mine, theirs) {
  const calc = await import('./damageCalc')
  const byId = await getPokemonById()
  const a = await Promise.all(mine.map((m) => fighter(calc, byId, m)))
  const b = await Promise.all(theirs.map((m) => fighter(calc, byId, m)))
  return a.map((x) =>
    b.map((y) => {
      if (!x || !y) return null
      return duel(calc, x, y)
    }),
  )
}

/**
 * Quem vence o Pokémon [targetId]: todos os totalmente evoluídos contra ele,
 * 1 contra 1 (nível 50, sem set). Devolve [{id, duel}] dos que ganham, os com
 * mais folga primeiro. progress(0..1) vai sendo chamado.
 */
export async function counters(targetId, { legendaries = false, progress } = {}) {
  const calc = await import('./damageCalc')
  const byId = await getPokemonById()
  const target = await fighter(calc, byId, { id: targetId })
  if (!target) return []
  const pool = [...byId.values()].filter(
    (p) => p.default && p.id !== targetId && (legendaries || !p.tag || p.tag === 'baby') && !calc.isNfe(p.name),
  )
  const out = []
  for (let i = 0; i < pool.length; i++) {
    const x = await fighter(calc, byId, { id: pool[i].id })
    if (x) {
      const d = duel(calc, x, target)
      if (d.result === 1) out.push({ id: x.id, duel: d })
    }
    if (i % 6 === 5) {
      progress?.((i + 1) / pool.length)
      await new Promise((r) => setTimeout(r, 0))
    }
  }
  progress?.(1)
  return out.sort((a, b) => b.duel.theirs.hits - b.duel.mine.hits - (a.duel.theirs.hits - a.duel.mine.hits) || b.duel.mine.pct - a.duel.mine.pct)
}

/** Membros de um time ({pokemon: [id|null], sets}) para a batalha. */
export const teamMembers = (team) =>
  (team?.pokemon ?? []).map((id, i) => (id == null ? null : { id, set: team.sets?.[i] ?? null })).filter(Boolean)
