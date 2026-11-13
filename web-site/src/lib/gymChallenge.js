// Desafio dos Líderes como jornada (dados da conta: 'league'). Igual ao app
// (lib/services/gym_challenge.dart):
//   badges: {região: [id do líder]}   insígnias (líderes de ginásio e kahunas vencidos)
//   hall: [{region, at, team: [id do Pokémon], trainer}]   Hall da Fama (Liga vencida)
//   tower: {best, streak}   Torre de Batalha
//   factory: {best, coins, owned, shinies, run}   Battle Factory (lib/factoryRun.js)
// A Liga (Elite dos Quatro e o Campeão em sequência) fica liberada com 8 insígnias
// da região (ou todas, se a região tem menos de 8, como os 4 kahunas de Alola).

export const emptyLeague = () => ({ badges: {}, hall: [], tower: { best: 0, streak: 0 }, factory: { best: 0, coins: 0, owned: [], shinies: [], run: null } })

/** Quem dá insígnia na região (líderes de ginásio e kahunas). */
export const regionGyms = (region) => region.leaders.filter((l) => l.kind === 'gym' || l.kind === 'kahuna')

/** A Liga: a Elite dos Quatro e, no fim, o Campeão (o último da região). */
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
// Os campeões com tema próprio (champion_<nome>), conforme vão sendo refeitos; os outros
// tocam o tema da região deles. Igual ao app.
// Os rivais com tema próprio (rival_<nome>, "Brendan/May" vira brendan-may), conforme vão sendo feitos;
// os outros tocam o tema da região. Igual ao app.
export const RIVAL_THEMES = ['blue', 'silver', 'brendan-may', 'wally', 'barry', 'cheren', 'bianca', 'hugh', 'n', 'serena-calem', 'shauna', 'tierno', 'trevor', 'hau', 'gladion', 'hop', 'bede', 'marnie', 'nemona', 'arven', 'red', 'lillie', 'az', 'anabel', 'dexio', 'sina', 'benga', 'eusine', 'ryuki', 'sordward-e-shielbert']
// Os vilões: os personagens importantes com tema próprio (villain_<nome>) e as equipes (villain_team_<equipe>),
// que os comandantes dividem, conforme vão sendo feitos; os outros tocam o tema da região. Igual ao app.
export const VILLAIN_THEMES = ['giovanni', 'maxie', 'archie', 'cyrus', 'colress', 'lysandre', 'guzma', 'lusamine', 'ghetsis', 'giacomo', 'ortega', 'penny', 'rose', 'jessie-e-james']
/** As regiões com tema de ginásio e com tema da Elite dos Quatro (os outros: o tema da região). Igual ao app. */
export const GYM_THEMES = ['kanto', 'johto', 'hoenn', 'sinnoh', 'unova', 'kalos', 'alola', 'galar', 'paldea', 'hisui']
/** Galar não tem Elite dos Quatro (os líderes lutam de novo na Copa). */
export const ELITE_THEMES = ['kanto', 'johto', 'hoenn', 'sinnoh', 'unova', 'kalos', 'alola', 'paldea']
export const TEAM_THEMES = ['rocket', 'magma', 'aqua', 'galactic', 'plasma', 'flare', 'skull', 'aether', 'ultra', 'star', 'macro', 'yell']
export const VILLAIN_TEAMS = {
  giovanni: 'rocket', proton: 'rocket', ariana: 'rocket', archer: 'rocket', petrel: 'rocket', executiva: 'rocket',
  executivo: 'rocket', maxie: 'magma', tabitha: 'magma', courtney: 'magma', archie: 'aqua', shelly: 'aqua',
  matt: 'aqua', cyrus: 'galactic', mars: 'galactic', jupiter: 'galactic', saturn: 'galactic', kamado: 'galactic', n: 'plasma',
  zinzolin: 'plasma', colress: 'plasma', ghetsis: 'plasma', lysandre: 'flare', bryony: 'flare', mable: 'flare',
  aliana: 'flare', celosia: 'flare', xerosic: 'flare', guzma: 'skull', plumeria: 'skull', faba: 'aether',
  lusamine: 'aether', soliera: 'ultra', dulse: 'ultra', giacomo: 'star', ortega: 'star', mela: 'star',
  atticus: 'star', eri: 'star', penny: 'star', rose: 'macro', oleana: 'macro', 'equipe-yell': 'yell',
}
// Rivais que dividem o tema (o mesmo papel, conforme o personagem escolhido no jogo).
export const RIVAL_ALIAS = { brendan: 'brendan-may', may: 'brendan-may', serena: 'serena-calem', calem: 'serena-calem' }
export const CHAMPION_THEMES = ['blue', 'lance', 'steven', 'wallace', 'cynthia', 'alder', 'iris', 'diantha', 'kukui', 'leon', 'geeta', 'volo']

/** O último número da Pokédex de cada região. */
export const DEX_REGIONS = [[151, 'kanto'], [251, 'johto'], [386, 'hoenn'], [493, 'sinnoh'], [649, 'unova'], [721, 'kalos'], [809, 'alola'], [905, 'galar'], [1025, 'paldea']]

/**
 * O tema da região do Pokémon [id] (o mesmo do mapa do Pokelike); as formas (Mega, regionais: o número não diz a região)
 * ficam com uma região sorteada pela semente da batalha (sempre a mesma na mesma batalha). Igual ao app.
 */
export function regionTheme(id, seed = 0) {
  const found = DEX_REGIONS.find(([last]) => id >= 1 && id <= last)
  return `map_${(found ?? DEX_REGIONS[Math.abs(seed) % DEX_REGIONS.length])[1]}`
}

/**
 * A música da batalha (temas originais, nenhum copiado dos jogos): o tema do campeão, o da região para
 * líderes, Elite dos Quatro e kahunas; sem líder, o tema de batalha da região do primeiro Pokémon do
 * adversário [foe] (como num ginásio daquela região).
 */
export function musicOf(leader, foe = 0, seed = 0) {
  if (!leader) return regionTheme(foe, seed)
  const champion = leader.name.toLowerCase()
  if (leader.kind === 'champion' && CHAMPION_THEMES.includes(champion)) return `champion_${champion}`
  const slug = champion.replace(/\//g, '-').replace(/ /g, '-')
  const rival = RIVAL_ALIAS[slug] ?? slug
  // Jessie e James (aparecem como a dupla de rivais da rota): o tema deles.
  if (slug === 'jessie-e-james' && VILLAIN_THEMES.includes(slug)) return `villain_${slug}`
  // O rival que vira Campeão (o Hau em Ultra Sun/Ultra Moon): o tema dele de rival.
  if ((leader.kind === 'rival' || leader.kind === 'champion') && RIVAL_THEMES.includes(rival)) return `rival_${rival}`
  // Um campeão que você enfrenta fora da Liga (a Cynthia em Unova, o Alder depois da Liga): o tema dele.
  if (leader.kind === 'rival' && CHAMPION_THEMES.includes(champion)) return `champion_${champion}`
  if (leader.kind === 'villain') {
    if (VILLAIN_THEMES.includes(slug)) return `villain_${slug}`
    if (slug === 'n' && RIVAL_THEMES.includes('n')) return 'rival_n' // N, rei da Equipe Plasma: o tema dele
    const team = VILLAIN_TEAMS[slug]
    if (team && TEAM_THEMES.includes(team)) return `villain_team_${team}`
  }
  // Líderes de ginásio (capitães e kahunas) e a Elite dos Quatro: o tema de ginásio e o da Elite dos Quatro da região.
  const region = leader.id.split('-')[0]
  if ((leader.kind === 'gym' || leader.kind === 'kahuna') && GYM_THEMES.includes(region)) return `gym_${region}`
  if (leader.kind === 'elite' && ELITE_THEMES.includes(region)) return `elite_${region}`
  return `map_${region}` // o tema da região (o mesmo do mapa do Pokelike)
}
