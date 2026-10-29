// Sincroniza os dados do usuário (favoritos, times, treinos, recordes, jogo e
// tema) com a conta dele no Firestore, em tempo real e nos dois sentidos:
// uma mudança feita no app de celular aparece no site na hora, e vice-versa.
//
// Formato em users/{uid}.data (o app usa o mesmo):
//   theme: 'dark' | 'light' | 'system' (segue o aparelho)
//   favorites: [id]                       ids de Pokémon (números)
//   teams: [{ id, name, color, pokemon: [id | null] x6 }]
//   training: [{ id, pokemonId, name, sprite, box, evs: { hp, attack, defense,
//               'special-attack', 'special-defense', speed } }]
//   quizRecord, rankedRecord: número
//   quizGame: jogo normal em andamento ou null
//   avatar: id do Pokémon usado como foto de perfil, ou null
//   trainer: id do seu treinador (trainers.json)
//   battles: histórico e replays das batalhas (lib/battleLog.js)
//   league: insígnias, Hall da Fama e recordes da Torre/Factory (lib/gymChallenge.js)
//   stats: contadores das conquistas (ver achievements.js)
//   collection: {jogo: {c: [id], s: [id]}}   Pokémon pegos (e shiny) por jogo
//   hunts: [{ id, pokemonId, game, method, count, found, startedAt, foundAt }]
//   nuzlockes: [{ id, name, game, createdAt, entries: [{ area, pokemonId, nickname, status }] }]

import { create } from 'zustand'
import { publishProfile, publishTeams, setDefense, saveRanking, saveUserData, signOut, useAuth, watchUserData } from './auth'
import { profileOf } from './profile'
import { useStore } from './store'

const KEYS = ['theme', 'themePokemon', 'themeShiny', 'themeChampion', 'defenseTeam', 'favorites', 'teams', 'training', 'quizRecord', 'rankedRecord', 'quizGame', 'avatar', 'stats', 'collection', 'hunts', 'nuzlockes', 'trainer', 'battles', 'league']
const same = (a, b) => JSON.stringify(a ?? null) === JSON.stringify(b ?? null)

let currentUid = null
let stopRemote = null
let stopStore = null
let timer = null
let dirty = new Set() // campos mudados aqui e ainda não gravados
let applyingRemote = false

/** Há coisas feitas aqui que ainda não chegaram na conta há alguns segundos (sem internet, por exemplo): o ☁️ na foto. */
export const useSyncState = create(() => ({ unsynced: false }))
let unsyncedTimer = null

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
      .then(() => {
        if (currentUid === uid) useTeamsVersion.setState((s) => ({ version: s.version + 1, error: null }))
      })
      .catch((e) => {
        if (currentUid === uid) useTeamsVersion.setState({
          error: e?.code === 'permission-denied'
            ? 'Sem permissão para publicar os times. As regras do Firestore precisam ser atualizadas.'
            : 'Não foi possível publicar os times. Tente novamente.',
        })
      })
  }, 1500)
}

/** Leva o perfil público (lib/profile.js) para profiles/{uid}, só quando muda. */
const PROFILE_KEYS = ['avatar', 'trainer', 'themePokemon', 'themeShiny', 'themeChampion', 'rankedRecord', 'league', 'collection']
let profileTimer = null
let lastProfile = null
function scheduleProfile(uid) {
  clearTimeout(profileTimer)
  profileTimer = setTimeout(() => {
    const name = useAuth.getState().user?.name
    if (!name || currentUid !== uid) return
    const fields = profileOf(useStore.getState())
    const key = JSON.stringify([uid, name, fields])
    if (key === lastProfile) return
    publishProfile(uid, name, fields).then(() => { lastProfile = key }).catch(() => {})
  }, 3000)
}

/** Leva o time de defesa (duelo assíncrono) para defense/{uid}, só quando muda. */
let defenseTimer = null
let lastDefense = null
function scheduleDefense(uid) {
  clearTimeout(defenseTimer)
  defenseTimer = setTimeout(() => {
    const name = useAuth.getState().user?.name
    if (!name || currentUid !== uid) return
    const { teams, defenseTeam, avatar } = useStore.getState()
    const team = teams.find((t) => t.id === defenseTeam && t.pokemon?.some((p) => p != null)) ?? null
    const key = JSON.stringify([uid, name, avatar, team])
    if (key === lastDefense) return
    setDefense(uid, name, avatar, team).then(() => { lastDefense = key }).catch(() => {})
  }, 2000)
}

/** Muda quando os times públicos da pessoa são atualizados. */
export const useTeamsVersion = create(() => ({ version: 0, error: null }))

export function retryPublish() {
  if (currentUid) schedulePublish(currentUid)
}

// O que mudou aqui e ainda não foi para a conta fica guardado no navegador: fechando a aba antes de gravar (ou sem
// internet), ao abrir de novo isso vai para a conta, em vez de a conta (mais antiga) apagar o que foi jogado. Igual ao app.
const DIRTY_KEY = 'pocketdex-sync-dirty'
function saveDirty(uid) {
  try {
    if (dirty.size) localStorage.setItem(DIRTY_KEY, JSON.stringify({ uid, keys: [...dirty] }))
    else localStorage.removeItem(DIRTY_KEY)
  } catch { /* sem armazenamento: só a memória */ }
}
function restoreDirty(uid) {
  try {
    const saved = JSON.parse(localStorage.getItem(DIRTY_KEY) ?? 'null')
    if (saved?.uid === uid) saved.keys.filter((k) => KEYS.includes(k)).forEach((k) => dirty.add(k))
  } catch { /* nada guardado */ }
}

async function flush(uid) {
  clearTimeout(timer)
  timer = null
  if (!dirty.size) return
  const state = useStore.getState()
  const changes = Object.fromEntries([...dirty].map((k) => [k, state[k] ?? null]))
  dirty = new Set()
  // Sem resposta da conta em 3 segundos (sem internet, a gravação espera): mostra o ☁️.
  clearTimeout(unsyncedTimer)
  unsyncedTimer = setTimeout(() => useSyncState.setState({ unsynced: true }), 3000)
  await saveUserData(uid, changes).catch(() => {
    // Sem conexão: tenta de novo na próxima mudança.
    Object.keys(changes).forEach((k) => dirty.add(k))
  })
  clearTimeout(unsyncedTimer)
  useSyncState.setState({ unsynced: dirty.size > 0 })
  // Só sai da lista guardada o que a conta recebeu.
  if (currentUid === uid) saveDirty(uid)
}

function scheduleSave(uid) {
  clearTimeout(timer)
  timer = setTimeout(() => flush(uid), 600)
}

function stop() {
  useTeamsVersion.setState({ error: null })
  stopRemote?.()
  stopStore?.()
  stopRemote = stopStore = null
  clearTimeout(timer)
  clearTimeout(publishTimer)
  clearTimeout(profileTimer)
  clearTimeout(defenseTimer)
  clearTimeout(unsyncedTimer)
  timer = null
  dirty = new Set()
  useSyncState.setState({ unsynced: false })
}

async function start(uid) {
  stop()
  currentUid = uid
  let ready = false
  restoreDirty(uid)

  stopStore = useStore.subscribe((state, previous) => {
    if (applyingRemote) return
    const changed = KEYS.filter((k) => state[k] !== previous[k])
    if (!changed.length) return
    changed.forEach((k) => dirty.add(k))
    saveDirty(uid)
    if (!ready) return // grava depois de receber a conta
    if (changed.includes('rankedRecord') || changed.includes('avatar')) updateRanking(uid)
    if (changed.includes('teams') || changed.includes('avatar')) schedulePublish(uid)
    if (changed.some((k) => PROFILE_KEYS.includes(k))) scheduleProfile(uid)
    if (changed.includes('teams') || changed.includes('defenseTeam') || changed.includes('avatar')) scheduleDefense(uid)
    scheduleSave(uid)
  })

  const unsubscribe = await watchUserData(
    uid,
    (remote) => {
      if (currentUid !== uid) return
      if (remote === undefined) {
        // A conta foi excluída (em outro aparelho ou pelo link do e-mail):
        // não grava nada de volta — sai dela e limpa este navegador.
        stop()
        currentUid = null
        signOut().catch(() => {})
        return
      }
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
        scheduleProfile(uid)
        scheduleDefense(uid)
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
      if (prevUid) {
        useStore.getState().clearAll()
        try { localStorage.removeItem(DIRTY_KEY) } catch { /* sem armazenamento */ }
      }
    }
  })
  // Fechando a aba (ou indo para outra): grava na hora o que estiver esperando.
  const leave = () => { if (currentUid) flush(currentUid) }
  document.addEventListener('visibilitychange', () => { if (document.visibilityState === 'hidden') leave() })
  window.addEventListener('pagehide', leave)
}
