// Desafio semanal da Batalha (igual ao app: lib/services/weekly_battle.dart):
// todo mundo enfrenta o mesmo time na semana (sorteado pela segunda-feira de
// Brasília, com sets competitivos e a mesma semente de batalha) e o ranking
// mostra quem venceu em menos turnos.
//
//   battleWeek/{semana}/scores/{uid} → {name, score, avatar}: score = 1000 − turnos (só sobe).

import { seededRandom, seedOf, weekKey } from './league'

export const WEEKLY_MAX_TURNS = 999

/** O sorteador da semana: o mesmo time e a mesma batalha para todos. */
export const weeklyRandom = (week = weekKey()) => seededRandom(seedOf(`pocketdex-weekly-battle-${week}`))

/** Turnos → pontuação do ranking (menos turnos, mais pontos). */
export const turnsToScore = (turns) => Math.max(1, WEEKLY_MAX_TURNS + 1 - Math.max(1, turns))
/** Pontuação do ranking → turnos. */
export const scoreToTurns = (score) => WEEKLY_MAX_TURNS + 1 - score

/** O recorde (menos turnos) da semana: league.weeklyBattle = {week, best}. */
export const weeklyBest = (league, week = weekKey()) => (league?.weeklyBattle?.week === week ? league.weeklyBattle.best : null)

/** A liga com a vitória em [turns] turnos (guarda o menor da semana). */
export function weeklyWin(league, turns, week = weekKey()) {
  const best = weeklyBest(league, week)
  return best != null && best <= turns ? league : { ...league, weeklyBattle: { week, best: turns } }
}
