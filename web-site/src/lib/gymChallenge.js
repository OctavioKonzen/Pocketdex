// Desafio dos Líderes como jornada (dados da conta: 'league'). Igual ao app
// (lib/services/gym_challenge.dart):
//   badges: {região: [id do líder]}   insígnias (líderes de ginásio e kahunas vencidos)
//   hall: [{region, at, team: [id do Pokémon], trainer}]   Hall da Fama (Liga vencida)
//   tower: {best, streak}   Torre de Batalha
//   factory: {best, coins, owned, shinies, run}   Battle Factory (lib/factoryRun.js)
// A Liga (Elite Four e o Campeão em sequência) fica liberada com 8 insígnias
// da região (ou todas, se a região tem menos de 8, como os 4 kahunas de Alola).

export const emptyLeague = () => ({ badges: {}, hall: [], tower: { best: 0, streak: 0 }, factory: { best: 0, coins: 0, owned: [], shinies: [], run: null } })

/** Quem dá insígnia na região (líderes de ginásio e kahunas). */
export const regionGyms = (region) => region.leaders.filter((l) => l.kind === 'gym' || l.kind === 'kahuna')

/** A Liga: a Elite Four e, no fim, o Campeão (o último da região). */
export function leagueOrder(region) {
  const champion = region.leaders.filter((l) => l.kind === 'champion').at(-1)
  return [...region.leaders.filter((l) => l.kind === 'elite'), ...(champion ? [champion] : [])]
}

export const badgesOf = (league, region) => league?.badges?.[region.region] ?? []
export const badgesNeeded = (region) => Math.min(8, regionGyms(region).length)
export const leagueOpen = (league, region) => badgesOf(league, region).length >= badgesNeeded(region)

/** A região de um líder. */
export const regionOf = (regions, leaderId) => regions.find((r) => r.leaders.some((l) => l.id === leaderId)) ?? null

/** Venceu um líder: ganha a insígnia (se for de ginásio ou kahuna). */
export function winBadge(league, regions, leader) {
  const region = regionOf(regions, leader.id)
  const base = { ...emptyLeague(), ...league }
  if (!region || !(leader.kind === 'gym' || leader.kind === 'kahuna')) return base
  const have = badgesOf(base, region)
  if (have.includes(leader.id)) return base
  return { ...base, badges: { ...base.badges, [region.region]: [...have, leader.id] } }
}

/** Venceu a Liga: entra no Hall da Fama (as entradas mais novas primeiro, até 30). */
export function addHallOfFame(league, region, team, trainer, now = Date.now()) {
  const base = { ...emptyLeague(), ...league }
  return { ...base, hall: [{ region: region.region, at: now, team, trainer }, ...base.hall].slice(0, 30) }
}

/** Resultado numa sequência (Torre/Factory): vitória soma, derrota zera; guarda o recorde. */
export function streakResult(league, kind, won) {
  const base = { ...emptyLeague(), ...league }
  const now = base[kind] ?? { best: 0, streak: 0 }
  const streak = won ? now.streak + 1 : 0
  return { ...base, [kind]: { best: Math.max(now.best, streak), streak } }
}

/** Campeões com tema próprio (tool/build_battle_sounds.py). */
export const CHAMPION_THEMES = ['blue', 'lance', 'steven', 'cynthia', 'alder', 'iris', 'diantha', 'kukui', 'leon', 'geeta']

/**
 * A música da batalha (temas originais, nenhum copiado dos jogos): o tema do
 * campeão, o da região para líderes, Elite Four e kahunas, ou a normal.
 */
export function musicOf(leader) {
  if (!leader) return 'battle_music'
  const champion = leader.name.toLowerCase()
  if (leader.kind === 'champion' && CHAMPION_THEMES.includes(champion)) return `champion_${champion}`
  return `gym_${leader.id.split('-')[0]}`
}
