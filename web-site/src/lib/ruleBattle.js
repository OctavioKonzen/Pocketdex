// Desafio com regra (igual ao app: lib/services/rule_battle.dart): uma regra
// nova toda semana (só um tipo, só uma geração, só os pequenos...), a mesma
// para todo mundo. O seu time e o do adversário seguem a regra.
//
//   league.ruleBattle = {week, wins}: as vitórias na regra desta semana.

import { seededRandom, seedOf, weekKey } from './league'
import { ALL_TYPES } from './pokemon'

/** As regras: {key, label, arg?, fits(p)} (p: {types, gen, height}). */
export const RULES = [
  ...ALL_TYPES.map((type) => ({ key: `type:${type}`, label: 'Só Pokémon do tipo {0}', arg: type, fits: (p) => p.types.includes(type) })),
  ...Array.from({ length: 9 }, (_, i) => ({ key: `gen:${i + 1}`, label: 'Só Pokémon da geração {0}', arg: String(i + 1), fits: (p) => p.gen === i + 1 })),
  { key: 'small', label: 'Só Pokémon de até 1 metro', fits: (p) => (p.height ?? 99) <= 10 },
  { key: 'mono', label: 'Só Pokémon de um tipo só', fits: (p) => p.types.length === 1 },
]

/** A regra da semana (a mesma para todos). */
export function ruleOfWeek(week = weekKey()) {
  return RULES[Math.floor(seededRandom(seedOf(`pocketdex-rule-${week}`))() * RULES.length)]
}

/** As vitórias na regra desta semana. */
export const ruleWins = (league, week = weekKey()) => (league?.ruleBattle?.week === week ? league.ruleBattle.wins : 0)

/** A liga com mais uma vitória na regra da semana. */
export const ruleWin = (league, week = weekKey()) => ({ ...league, ruleBattle: { week, wins: ruleWins(league, week) + 1 } })
