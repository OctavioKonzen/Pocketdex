// Times oficiais dos personagens (assets/database/official_teams.json, feito por
// tool/build_official_teams.py a partir das desmontagens do pret): separados
// por jogo, com todas as lutas de cada um. Igual ao app
// (lib/services/official_teams.dart).

const DV_LABELS = { hp: 'HP', atk: 'Atk', def: 'Def', spe: 'Spe', spc: 'Spc' }
const STAT_LABELS = { hp: 'HP', atk: 'Atk', def: 'Def', spa: 'SpA', spd: 'SpD', spe: 'Spe' }
const perStat = (values) => Object.keys(STAT_LABELS).map((k) => `${STAT_LABELS[k]} ${values[k]}`).join(' · ')

/** As gerações que têm jogos, em ordem. */
export const generationsOf = (games) => [...new Set(games.map((g) => g.generation))].sort((a, b) => a - b)

/** Todas as vezes que o personagem aparece (mesmo nome), em ordem de jogo. */
export function appearances(games, name) {
  return games.flatMap((game) => game.trainers.filter((t) => t.name === name).map((trainer) => ({ game, trainer })))
}

/** Personagens do jogo que batem com a busca (nome ou classe). */
export function filterTrainers(game, query) {
  const q = query.trim().toLowerCase()
  if (!q) return game.trainers
  return game.trainers.filter((t) => t.name.toLowerCase().includes(q) || t.class.toLowerCase().includes(q))
}

/** "IVs: 30 em todos", um por status, sorteados (o jogo sorteia) ou os DVs da 1ª/2ª geração. */
export function ivText(mon) {
  if (mon.dv) return `DVs: ${Object.keys(DV_LABELS).map((k) => `${DV_LABELS[k]} ${mon.dv[k]}`).join(' · ')}`
  if (mon.ivNote) return `IVs: ${mon.ivNote}`
  return typeof mon.iv === 'object' ? `IVs: ${perStat(mon.iv)}` : `IVs: ${mon.iv} em todos`
}

/** Na 1ª/2ª geração os treinadores não têm stat exp; nas outras, os EVs (iguais ou um por status). */
export function evText(mon) {
  if (mon.dv) return 'Stat Exp: 0'
  return typeof mon.ev === 'object' ? `EVs: ${Object.keys(STAT_LABELS).filter((k) => mon.ev[k]).map((k) => `${mon.ev[k]} ${STAT_LABELS[k]}`).join(' / ')}` : `EVs: ${mon.ev} em todos`
}

/** A habilidade, ou as opções quando o jogo sorteia. */
export const abilityText = (mon, pretty) =>
  mon.ability ? pretty(mon.ability) : mon.abilityOptions ? `${mon.abilityOptions.map(pretty).join(' ou ')} (sorteada)` : null
