// Contas de batalha (iguais no app: lib/services/battle.dart).
// Nível 50, IVs 31 e Nature neutra; EVs 0 ou 252 conforme a escolha.

export const LEVEL = 50

/** Status final: HP (index 0) tem outra fórmula. */
export function statAt(base, index, ev = 0, level = LEVEL) {
  const core = Math.floor(((2 * base + 31 + Math.floor(ev / 4)) * level) / 100)
  return index === 0 ? core + level + 10 : core + 5
}

/** Multiplicador de um tipo de golpe contra os tipos do defensor. */
export function effectiveness(moveType, defenderTypes, typeData) {
  let mult = 1
  for (const type of defenderTypes) {
    const rel = typeData[type]
    if (!rel) continue
    if (rel.double_damage_from.includes(moveType)) mult *= 2
    if (rel.half_damage_from.includes(moveType)) mult *= 0.5
    if (rel.no_damage_from.includes(moveType)) mult *= 0
  }
  return mult
}

/**
 * Dano de um golpe (fórmula das gerações 5+), sem crítico, clima ou itens.
 * attacker/defender: {types, stats: [hp, atk, def, spa, spd, spe]} (base).
 * Devolve {min, max, hp, minPct, maxPct, mult, stab, hits}.
 */
export function damage({ attacker, defender, move, typeData, attackEv = 0, defenseEv = 0, hpEv = 0 }) {
  const physical = move.category === 'physical'
  const a = statAt(attacker.stats[physical ? 1 : 3], physical ? 1 : 3, attackEv)
  const d = statAt(defender.stats[physical ? 2 : 4], physical ? 2 : 4, defenseEv)
  const hp = statAt(defender.stats[0], 0, hpEv)
  const mult = effectiveness(move.type, defender.types, typeData)
  const stab = attacker.types.includes(move.type) ? 1.5 : 1
  const base = Math.floor(Math.floor((Math.floor((2 * LEVEL) / 5 + 2) * move.power * a) / d) / 50) + 2
  const roll = (r) => Math.floor(Math.floor(Math.floor(base * r) * stab) * mult)
  const min = roll(0.85)
  const max = roll(1)
  const pct = (n) => Math.round((n / hp) * 1000) / 10
  return { min, max, hp, minPct: pct(min), maxPct: pct(max), mult, stab: stab > 1, hits: max > 0 ? Math.ceil(hp / max) : null }
}
