// Times oficiais dos personagens (assets/database/official_teams.json, feito por
// tool/build_official_teams.py a partir das desmontagens do pret): separados
// por jogo, com todas as lutas de cada um. Igual ao app
// (lib/services/official_teams.dart).

const DV_LABELS = { hp: 'HP', atk: 'Atk', def: 'Def', spe: 'Spe', spc: 'Spc' }

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

/** "IVs: 30 em todos" (3ª/4ª geração) ou os DVs da 1ª/2ª geração. */
export function ivText(mon) {
  if (mon.dv) return `DVs: ${Object.keys(DV_LABELS).map((k) => `${DV_LABELS[k]} ${mon.dv[k]}`).join(' · ')}`
  return `IVs: ${mon.iv} em todos`
}

/** Na 1ª/2ª geração os treinadores não têm stat exp; nas outras, EVs 0. */
export const evText = (mon) => (mon.dv ? 'Stat Exp: 0' : `EVs: ${mon.ev} em todos`)
