// Álbum de medalhas (igual ao app: lib/services/medals.dart): marcos grandes,
// cada um com o desenho de um Pokémon (o mesmo dos temas, lib/pokemonTheme.js),
// pintado na cor dele quando liberado.

const len = (x) => (Array.isArray(x) ? x.length : 0)
const caughtCount = (collection) => new Set(Object.values(collection ?? {}).flatMap((g) => [...(g?.c ?? []), ...(g?.s ?? [])])).size

export const MEDALS = [
  { id: 'shiny1', pokemon: 130, title: 'Primeiro shiny', text: 'Capture um shiny no Pokelike.', done: (s) => len(s.league?.factory?.shinies) >= 1 },
  { id: 'shiny10', pokemon: 384, title: 'Caçador de shiny', text: 'Capture 10 shiny no Pokelike.', done: (s) => len(s.league?.factory?.shinies) >= 10 },
  { id: 'shiny100', pokemon: 493, title: 'Lenda brilhante', text: 'Capture 100 shiny no Pokelike.', done: (s) => len(s.league?.factory?.shinies) >= 100 },
  { id: 'floor25', pokemon: 133, title: 'Explorador', text: 'Chegue ao andar 25 do Pokelike.', done: (s) => (s.league?.factory?.best ?? 0) >= 25 },
  { id: 'floor100', pokemon: 149, title: 'Desbravador', text: 'Chegue ao andar 100 do Pokelike.', done: (s) => (s.league?.factory?.best ?? 0) >= 100 },
  { id: 'missions30', pokemon: 25, title: 'Missão cumprida', text: 'Cumpra 30 missões diárias do Pokelike.', done: (s) => (s.league?.factory?.missionsDone ?? 0) >= 30 },
  { id: 'badges8', pokemon: 95, title: 'Oito insígnias', text: 'Junte 8 insígnias numa região.', done: (s) => Object.values(s.league?.badges ?? {}).some((b) => len(b) >= 8) },
  { id: 'champion', pokemon: 6, title: 'Campeão', text: 'Entre no Hall da Fama.', done: (s) => len(s.league?.hall) >= 1 },
  { id: 'champions', pokemon: 150, title: 'Lenda das regiões', text: 'Entre no Hall da Fama de 5 regiões.', done: (s) => new Set((s.league?.hall ?? []).map((h) => h.region)).size >= 5 },
  { id: 'tower10', pokemon: 376, title: 'Torre de aço', text: 'Vença 10 seguidas na Torre de Batalha.', done: (s) => (s.league?.tower?.best ?? 0) >= 10 },
  { id: 'weekly', pokemon: 445, title: 'Desafiante da semana', text: 'Vença um desafio semanal.', done: (s) => s.league?.weeklyBattle?.best != null },
  { id: 'kanto', pokemon: 151, title: 'Pokédex de Kanto', text: 'Marque 151 Pokémon como pegos na coleção.', done: (s) => caughtCount(s.collection) >= 151 },
]

/** As medalhas com `unlocked` para o estado atual ({league, collection}). */
export const medalsOf = (state) => MEDALS.map((m) => ({ ...m, unlocked: Boolean(m.done(state)) }))
