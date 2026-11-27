// Conquistas (medalhas). Iguais no app (lib/services/achievements.dart).
// São calculadas a partir dos dados da conta; `stats` guarda os contadores:
//   stats: { correct, bestStreak, rankedGames, dailyDone, dailyPerfect,
//            lastDaily: 'AAAA-MM-DD', days: ['AAAA-MM-DD'], weeks: ['AAAA-MM-DD'] }

export const EMPTY_STATS = {
  correct: 0,
  bestStreak: 0,
  rankedGames: 0,
  dailyDone: 0,
  dailyPerfect: 0,
  lastDaily: null,
  days: [],
  weeks: [],
}

const fullTeam = (t) => (t.pokemon ?? []).filter((p) => p != null).length === 6

export const ACHIEVEMENTS = [
  { id: 'first', icon: '🎯', title: 'Primeiro acerto', text: 'Acerte um Pokémon no jogo.', done: (s) => s.stats.correct >= 1 },
  { id: 'trainer', icon: '🎒', title: 'Treinador', text: 'Acerte 100 Pokémon no jogo.', done: (s) => s.stats.correct >= 100 },
  { id: 'master', icon: '🎓', title: 'Mestre Pokémon', text: 'Acerte 1000 Pokémon no jogo.', done: (s) => s.stats.correct >= 1000 },
  { id: 'streak', icon: '🔥', title: 'Em chamas', text: 'Faça uma sequência de 10 acertos.', done: (s) => s.stats.bestStreak >= 10 },
  { id: 'unstoppable', icon: '☄️', title: 'Imparável', text: 'Faça uma sequência de 50 acertos.', done: (s) => s.stats.bestStreak >= 50 },
  { id: 'ranked', icon: '🏆', title: 'Competidor', text: 'Faça 100 pontos no Ranked.', done: (s) => s.rankedRecord >= 100 },
  { id: 'lightning', icon: '⚡', title: 'Relâmpago', text: 'Chegue a 400 pontos no Ranked (2 s por Pokémon).', done: (s) => s.rankedRecord >= 400 },
  { id: 'daily', icon: '📅', title: 'Desafiante', text: 'Complete um desafio do dia.', done: (s) => s.stats.dailyDone >= 1 },
  { id: 'loyal', icon: '🗓️', title: 'Fiel', text: 'Complete 7 desafios do dia.', done: (s) => s.stats.dailyDone >= 7 },
  { id: 'perfect', icon: '💯', title: 'Perfeito', text: 'Acerte os 10 Pokémon de um desafio do dia.', done: (s) => s.stats.dailyPerfect >= 1 },
  { id: 'collector', icon: '⭐', title: 'Colecionador', text: 'Tenha 10 Pokémon favoritos.', done: (s) => s.favorites.length >= 10 },
  { id: 'team', icon: '🛡️', title: 'Time completo', text: 'Monte um time com 6 Pokémon.', done: (s) => s.teams.some(fullTeam) },
  { id: 'strategist', icon: '♟️', title: 'Estrategista', text: 'Tenha 5 times completos.', done: (s) => s.teams.filter(fullTeam).length >= 5 },
]

/** Lista de conquistas com `unlocked` para o estado atual. */
export function achievementsOf({ stats, rankedRecord = 0, favorites = [], teams = [] }) {
  const state = { stats: { ...EMPTY_STATS, ...(stats ?? {}) }, rankedRecord, favorites, teams }
  return ACHIEVEMENTS.map((a) => ({ ...a, unlocked: a.done(state) }))
}
