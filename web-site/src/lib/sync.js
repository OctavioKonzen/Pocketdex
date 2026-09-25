// Sincroniza os dados do usuário (favoritos, times, treinos, recordes, jogo e
// tema) com a conta dele no Firestore, em tempo real e nos dois sentidos:
// uma mudança feita no app de celular aparece no site na hora, e vice-versa.
//
// Formato em users/{uid}.data (o app usa o mesmo):
//   theme: 'dark' | 'light'
//   favorites: [id]                       ids de Pokémon (números)
//   teams: [{ id, name, color, pokemon: [id | null] x6 }]
//   training: [{ id, pokemonId, name, sprite, box, evs: { hp, attack, defense,
//               'special-attack', 'special-defense', speed } }]
//   quizRecord, rankedRecord: número
//   quizGame: jogo normal em andamento ou null
//   avatar: id do Pokémon usado como foto de perfil, ou null
//   stats: contadores das conquistas (ver achievements.js)

import { create } from 'zustand'
import { publishTeams, saveRanking, saveUserData, signOut, useAuth, watchUserData } from './auth'
import { useStore } from './store'

const KEYS = ['theme', 'favorites', 'teams', 'training', 'quizRecord', 'rankedRecord', 'quizGame', 'avatar', 'stats']
const same = (a, b) => JSON.stringify(a ?? null) === JSON.stringify(b ?? null)

let currentUid = null
let stopRemote = null
let stopStore = null
let timer = null
let dirty = new Set() // campos mudados aqui e ainda não gravados
let applyingRemote = false

/** Muda sempre que o ranking é atualizado (a tela do jogo recarrega a lista). */
export const useRankingVersion = create(() => ({ version: 0 }))

/** Leva o recorde do modo Ranked para o ranking público. */
function updateRanking(uid) {
  const name = useAuth.getState().user?.name
  if (!name) return
  const { rankedRecord, avatar } = useStore.getState()
  saveRanking(uid, name, rankedRecord, avatar)
    .then(() => useRankingVersion.setState((s) => ({ version: s.version + 1 })))
    .catch(() => {})
}

/** Leva os times para a lista pública (busca de times e nota da comunidade). */
let publishTimer = null
function schedulePublish(uid) {
  clearTimeout(publishTimer)
  publishTimer = setTimeout(() => {
    const name = useAuth.getState().user?.name
    if (!name || currentUid !== uid) return
    const { teams, avatar } = useStore.getState()
    publishTeams(uid, name, avatar, teams)
      .then(() => useTeamsVersion.setState((s) => ({ version: s.version + 1 })))
      .catch(() => {})
  }, 1500)
}

/** Muda quando os times públicos da pessoa são atualizados. */
export const useTeamsVersion = create(() => ({ version: 0 }))

async function flush(uid) {
  clearTimeout(timer)
  timer = null
  if (!dirty.size) return
  const state = useStore.getState()
  const changes = Object.fromEntries([...dirty].map((k) => [k, state[k] ?? null]))
  dirty = new Set()
  await saveUserData(uid, changes).catch(() => {
    // Sem conexão: tenta de novo na próxima mudança.
    Object.keys(changes).forEach((k) => dirty.add(k))
  })
}

function scheduleSave(uid) {
  clearTimeout(timer)
  timer = setTimeout(() => flush(uid), 600)
}

function stop() {
  stopRemote?.()
  stopStore?.()
  stopRemote = stopStore = null
  clearTimeout(timer)
  clearTimeout(publishTimer)
  timer = null
  dirty = new Set()
}

async function start(uid) {
  stop()
  currentUid = uid
  let ready = false

  stopStore = useStore.subscribe((state, previous) => {
    if (applyingRemote) return
    const changed = KEYS.filter((k) => state[k] !== previous[k])
    if (!changed.length) return
    changed.forEach((k) => dirty.add(k))
    if (!ready) return // grava depois de receber a conta
    if (changed.includes('rankedRecord') || changed.includes('avatar')) updateRanking(uid)
    if (changed.includes('teams') || changed.includes('avatar')) schedulePublish(uid)
    scheduleSave(uid)
  })

  const unsubscribe = await watchUserData(
    uid,
    (remote) => {
      if (currentUid !== uid) return
      if (!remote) {
        // Conta nova: o que já estava neste navegador vai para ela.
        KEYS.forEach((k) => dirty.add(k))
      } else {
        const state = useStore.getState()
        const incoming = {}
        for (const k of KEYS) {
          // O que foi mudado aqui e ainda não foi gravado tem preferência.
          if (k in remote && !dirty.has(k) && !same(remote[k], state[k])) incoming[k] = remote[k]
        }
        if (Object.keys(incoming).length) {
          applyingRemote = true
          useStore.setState(incoming)
          applyingRemote = false
        }
      }
      if (!ready) {
        ready = true
        updateRanking(uid)
        schedulePublish(uid)
      }
      if (dirty.size) scheduleSave(uid)
    },
    () => {},
  ).catch(() => null)

  if (currentUid !== uid) unsubscribe?.()
  else stopRemote = unsubscribe
}

/** Salva na hora o que ainda estiver esperando (antes de sair da conta). */
export async function flushSync() {
  if (currentUid) await flush(currentUid)
}

/** Sai da conta, salvando antes o que faltava. */
export async function logout() {
  await flushSync()
  await signOut()
}

/** Para a sincronização (ex.: enquanto a conta é excluída, para não recriar os dados). */
export function pauseSync() {
  stop()
  currentUid = null
}

/** Volta a sincronizar a conta conectada (se a exclusão não foi até o fim). */
export function resumeSync() {
  const { status, user } = useAuth.getState()
  if (status === 'signedIn' && user) start(user.uid)
}

let started = false

/** Liga a sincronização conforme a pessoa entra ou sai da conta. */
export function startSync() {
  if (started) return
  started = true
  useAuth.subscribe((auth, previous) => {
    const uid = auth.status === 'signedIn' ? auth.user?.uid : null
    const prevUid = previous.status === 'signedIn' ? previous.user?.uid : null
    if (uid === prevUid) return
    if (uid) start(uid)
    else {
      stop()
      currentUid = null
      // Saiu da conta: os dados dela não ficam neste navegador.
      if (prevUid) useStore.getState().clearAll()
    }
  })
}
