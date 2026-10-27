// Dados do usuário salvos no navegador (localStorage): favoritos, times,
// treinos de EV, recorde/jogo do quiz e tema. Quando houver login, esta é a
// parte que passa a sincronizar com o servidor.

import { emptyLeague } from './gymChallenge'
import { create } from 'zustand'
import { persist } from 'zustand/middleware'
import { EMPTY_STATS } from './achievements'
import { MAX_STAT_EVS, MAX_TOTAL_EVS } from './pokemon'

const uid = () => (crypto.randomUUID ? crypto.randomUUID() : `${Date.now()}-${Math.random()}`)

export const useStore = create(
  persist(
    (set, get) => ({
      // Tema
      theme: 'dark',
      setTheme: (theme) => set({ theme }),

      // Favoritos (ids de Pokémon)
      favorites: [],
      isFavorite: (id) => get().favorites.includes(id),
      toggleFavorite: (id) =>
        set(({ favorites }) => ({
          favorites: favorites.includes(id) ? favorites.filter((f) => f !== id) : [...favorites, id],
        })),

      // Times: {id, name, color, pokemon: [id|null x6], sets: [set|null x6]} (sets: lib/teamSets.js)
      teams: [],
      createTeam: (name) => {
        const team = { id: uid(), name, color: null, pokemon: Array(6).fill(null), sets: Array(6).fill(null) }
        set(({ teams }) => ({ teams: [...teams, team] }))
        return team.id
      },
      /** Time recebido de outra pessoa (código, link ou Showdown). */
      importTeam: ({ name, color, pokemon, sets }) => {
        const team = {
          id: uid(),
          name,
          color: color ?? null,
          pokemon: Array.from({ length: 6 }, (_, i) => pokemon?.[i] ?? null),
          sets: Array.from({ length: 6 }, (_, i) => sets?.[i] ?? null),
        }
        set(({ teams }) => ({ teams: [...teams, team] }))
        return team.id
      },
      updateTeam: (id, changes) =>
        set(({ teams }) => ({ teams: teams.map((t) => (t.id === id ? { ...t, ...changes } : t)) })),
      deleteTeam: (id) => set(({ teams }) => ({ teams: teams.filter((t) => t.id !== id) })),

      // Treino de EVs: {id, pokemonId, name, sprite, evs: {hp, attack, ...}}
      training: [],
      addTraining: (pokemon) =>
        set(({ training }) => ({
          training: [
            ...training,
            { id: uid(), pokemonId: pokemon.id, name: pokemon.name, sprite: pokemon.sprite, box: pokemon.box, evs: {} },
          ],
        })),
      removeTraining: (id) => set(({ training }) => ({ training: training.filter((t) => t.id !== id) })),
      /** Soma os EVs de um Pokémon derrotado, respeitando os limites (252 por atributo, 510 no total). */
      addEvs: (id, gained) =>
        set(({ training }) => ({
          training: training.map((t) => {
            if (t.id !== id) return t
            const evs = { ...t.evs }
            let total = Object.values(evs).reduce((a, b) => a + b, 0)
            for (const [stat, value] of Object.entries(gained)) {
              const add = Math.min(value, MAX_STAT_EVS - (evs[stat] ?? 0), MAX_TOTAL_EVS - total)
              if (add > 0) {
                evs[stat] = (evs[stat] ?? 0) + add
                total += add
              }
            }
            return { ...t, evs }
          }),
        })),
      resetEvs: (id) => set(({ training }) => ({ training: training.map((t) => (t.id === id ? { ...t, evs: {} } : t)) })),

      // Coleção por jogo: {jogo: {c: [ids pegos], s: [ids pegos shiny]}}
      collection: {},
      /** Marca/desmarca um Pokémon como pego (shiny: na lista de shiny) num jogo. */
      toggleCaught: (game, id, shiny = false) =>
        set(({ collection }) => {
          const entry = collection[game] ?? { c: [], s: [] }
          const key = shiny ? 's' : 'c'
          const list = entry[key] ?? []
          const next = { ...entry, [key]: list.includes(id) ? list.filter((x) => x !== id) : [...list, id] }
          return { collection: { ...collection, [game]: next } }
        }),

      // Shiny hunts: {id, pokemonId, game, method, count, found, startedAt, foundAt}
      hunts: [],
      addHunt: (hunt) => set(({ hunts }) => ({ hunts: [{ id: uid(), count: 0, found: false, startedAt: Date.now(), foundAt: null, ...hunt }, ...hunts] })),
      updateHunt: (id, changes) => set(({ hunts }) => ({ hunts: hunts.map((h) => (h.id === id ? { ...h, ...changes } : h)) })),
      deleteHunt: (id) => set(({ hunts }) => ({ hunts: hunts.filter((h) => h.id !== id) })),

      // Nuzlockes: {id, name, game, createdAt, entries: [{area, pokemonId, nickname, status}]}
      //   status: 'caught' (no time/caixa) | 'dead' | 'missed' (fugiu/nenhum)
      nuzlockes: [],
      addNuzlocke: (run) => {
        const id = uid()
        set(({ nuzlockes }) => ({ nuzlockes: [{ id, createdAt: Date.now(), entries: [], ...run }, ...nuzlockes] }))
        return id
      },
      updateNuzlocke: (id, changes) => set(({ nuzlockes }) => ({ nuzlockes: nuzlockes.map((r) => (r.id === id ? { ...r, ...changes } : r)) })),
      deleteNuzlocke: (id) => set(({ nuzlockes }) => ({ nuzlockes: nuzlockes.filter((r) => r.id !== id) })),

      // Quiz "Quem é esse Pokémon?"
      quizRecord: 0, // recorde do modo normal
      rankedRecord: 0, // recorde do modo Ranked (é o que vai para o ranking)
      quizGame: null, // {generation, score, lives, answerId, options}

      // Foto de perfil: id de um Pokémon (a mesma no app e no site)
      avatar: null,
      setAvatar: (avatar) => set({ avatar }),
      // Seu treinador na batalha (id de trainers.json; o mesmo no app e no site)
      trainer: 'red',
      setTrainer: (trainer) => set({ trainer }),
      // Histórico das batalhas contra o computador (lib/battleLog.js), as mais novas primeiro.
      battles: [],
      addBattle: (record) => set(({ battles }) => ({ battles: [record, ...battles].slice(0, 30) })),
      deleteBattle: (id) => set(({ battles }) => ({ battles: battles.filter((b) => b.id !== id) })),
      // Desafio dos Líderes, Torre e Factory (lib/gymChallenge.js): insígnias, Hall da Fama e recordes.
      league: emptyLeague(),
      updateLeague: (change) => set(({ league }) => ({ league: change({ ...emptyLeague(), ...league }) })),
      saveQuizGame: (game) => set({ quizGame: game }),
      finishQuiz: (score) =>
        set(({ quizRecord }) => ({ quizGame: null, quizRecord: Math.max(quizRecord, score) })),
      finishRanked: (score) => set(({ rankedRecord }) => ({ rankedRecord: Math.max(rankedRecord, score) })),

      // Contadores das conquistas (ver achievements.js)
      stats: EMPTY_STATS,
      /** Uma resposta no jogo (qualquer modo). */
      countAnswer: (correct, streak) =>
        set(({ stats }) => {
          const s = { ...EMPTY_STATS, ...stats }
          return {
            stats: {
              ...s,
              correct: s.correct + (correct ? 1 : 0),
              bestStreak: Math.max(s.bestStreak, streak),
            },
          }
        }),
      /** Um Ranked terminado na semana `week` (guarda as semanas para poder apagar depois). */
      countRanked: (week) =>
        set(({ stats }) => {
          const s = { ...EMPTY_STATS, ...stats }
          const weeks = s.weeks.includes(week) ? s.weeks : [...s.weeks, week].slice(-60)
          return { stats: { ...s, rankedGames: s.rankedGames + 1, weeks } }
        }),
      /** Desafio do dia terminado. */
      countDaily: (day, correct) =>
        set(({ stats }) => {
          const s = { ...EMPTY_STATS, ...stats }
          if (s.lastDaily === day) return {}
          return {
            stats: {
              ...s,
              dailyDone: s.dailyDone + 1,
              dailyPerfect: s.dailyPerfect + (correct === 10 ? 1 : 0),
              lastDaily: day,
              days: [...s.days, day].slice(-60),
            },
          }
        }),

      /** Limpa favoritos, times e treinos (os recordes ficam). */
      clearCollections: () => set({ favorites: [], teams: [], training: [] }),
      /** Tudo, ao sair da conta. */
      clearAll: () =>
        set({
          favorites: [],
          teams: [],
          training: [],
          quizRecord: 0,
          rankedRecord: 0,
          quizGame: null,
          avatar: null,
          trainer: 'red',
          battles: [],
          league: emptyLeague(),
          stats: EMPTY_STATS,
          collection: {},
          hunts: [],
          nuzlockes: [],
        }),
    }),
    { name: 'pocketdex' },
  ),
)
