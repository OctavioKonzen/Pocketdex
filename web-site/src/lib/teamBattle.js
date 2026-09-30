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
  const moves = chosen.length ? chosen : [...new Set(form.moves.map((m) => m[0]))].filter(damaging)
  const speed = calc.sideStats(base, side)?.stats.spe ?? 0
  return { base, side, moves, speed }
}

function best(calc, a, b) {
  let top = NONE
  for (const slug of a.moves) {
    const r = calc.run({
      attacker: a.base,
      attackerSide: a.side,
      defender: b.base,
      defenderSide: b.side,
      moveSlug: slug,
      moveOptions: calc.newMoveOptions(),
      field: calc.newField(),
    })
    if (!r || r.noDamage) continue
    const pct = (r.minPct + r.maxPct) / 2
    if (pct > top.pct) top = { move: r.name, pct, hits: Math.min(98, Math.max(1, Math.ceil(100 / pct))) }
  }
  return top
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
      const d = { mine: best(calc, x, y), theirs: best(calc, y, x), faster: x.speed > y.speed, sameSpeed: x.speed === y.speed }
      return { ...d, result: duelResult(d) }
    }),
  )
}

/** Membros de um time ({pokemon: [id|null], sets}) para a batalha. */
export const teamMembers = (team) =>
  (team?.pokemon ?? []).map((id, i) => (id == null ? null : { id, set: team.sets?.[i] ?? null })).filter(Boolean)
