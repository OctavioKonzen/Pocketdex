// Sincroniza os dados do usuário (favoritos, times, treinos, recorde e tema)
// com a conta dele no Firestore. Assim os dados aparecem em qualquer
// computador (e, no futuro, no app) em que a pessoa entrar.

import { loadUserData, saveUserData, signOut, useAuth } from './auth'
import { useStore } from './store'

const KEYS = ['theme', 'favorites', 'teams', 'training', 'quizRecord']
const pick = (state) => Object.fromEntries(KEYS.map((k) => [k, state[k]]))

let stopStore = null
let timer = null
let currentUid = null

function stop() {
  stopStore?.()
  stopStore = null
  clearTimeout(timer)
}

function scheduleSave(uid) {
  clearTimeout(timer)
  timer = setTimeout(() => {
    timer = null
    saveUserData(uid, pick(useStore.getState())).catch(() => {})
  }, 800)
}

async function start(uid) {
  stop()
  currentUid = uid
  // Já ouve as mudanças desde o começo; as feitas enquanto a conta carrega
  // são salvas logo depois (senão se perderiam).
  let ready = false
  let changedWhileLoading = false
  stopStore = useStore.subscribe((state, previous) => {
    if (KEYS.every((k) => state[k] === previous[k])) return
    if (ready) scheduleSave(uid)
    else changedWhileLoading = true
  })
  try {
    const remote = await loadUserData(uid)
    if (currentUid !== uid) return
    if (remote) {
      // A conta já tem dados: eles valem neste computador também.
      useStore.setState({ ...pick({ ...useStore.getState(), ...remote }), quizGame: null })
      changedWhileLoading = false
    } else {
      // Primeira vez: o que já estava salvo neste navegador vai para a conta.
      await saveUserData(uid, pick(useStore.getState()))
    }
  } catch {
    // Sem conexão: continua com os dados locais e tenta salvar depois.
    changedWhileLoading = true
  }
  if (currentUid !== uid) return
  ready = true
  if (changedWhileLoading) scheduleSave(uid)
}

/** Salva na hora o que ainda estiver esperando (antes de sair da conta). */
export async function flushSync() {
  if (!timer || !currentUid) return
  clearTimeout(timer)
  timer = null
  await saveUserData(currentUid, pick(useStore.getState())).catch(() => {})
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
