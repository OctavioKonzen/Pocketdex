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

import { create } from 'zustand'
import { saveRanking, saveUserData, signOut, useAuth, watchUserData } from './auth'
import { useStore } from './store'

const KEYS = ['theme', 'favorites', 'teams', 'training', 'quizRecord', 'rankedRecord', 'quizGame', 'avatar']
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
  saveRanking(uid, name, useStore.getState().rankedRecord)
    .then(() => useRankingVersion.setState((s) => ({ version: s.version + 1 })))
    .catch(() => {})
}

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
    if (changed.includes('rankedRecord')) updateRanking(uid)
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
