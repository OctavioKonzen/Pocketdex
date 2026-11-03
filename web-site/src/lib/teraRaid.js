// Guia de Tera Raids (igual ao app, tera_raid_screen.dart): na raid o chefe só
// tem o tipo Tera na defesa, mas ataca com os tipos dele e com o Tera. Os
// melhores atacantes batem super efetivo no Tera com o próprio tipo (STAB),
// têm ataque alto e resistem aos golpes do chefe.

import { damageTaken } from './pokemon'

/**
 * Melhores atacantes. pokemon: [{id, name, types, stats}] (índice do banco),
 * typeData: types.json. Devolve [{id, name, attackType, offense, taken, score}].
 */
export function teraRaidPicks(pokemon, typeData, bossTypes, tera, { allowed = () => true, count = 24 } = {}) {
  const againstTera = damageTaken([tera], typeData)
  const bossAttacks = [...new Set([...bossTypes, tera])]
  const picks = []
  for (const p of pokemon) {
    if (!allowed(p)) continue
    let offense = 0
    let attackType = p.types[0]
    for (const t of p.types) {
      if (againstTera[t] > offense) {
        offense = againstTera[t]
        attackType = t
      }
    }
    if (offense < 2) continue // só quem bate super efetivo com o próprio tipo
    const taken = damageTaken(p.types, typeData)
    const worst = Math.max(...bossAttacks.map((b) => taken[b]))
    const [hp, atk, def, spa, spd] = p.stats
    const bulk = hp + (def + spd) / 2
    const score = (offense * Math.max(atk, spa) * (bulk / 100)) / Math.max(worst, 0.25)
    picks.push({ id: p.id, name: p.name, attackType, offense, taken: worst, score })
  }
  return picks.sort((a, b) => b.score - a.score).slice(0, count)
}
