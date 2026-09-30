// Amigos da conta conectada, em tempo real (pedidos, amigos e desafios).
// Formato no Firestore: friends/{uid}/list/{outro} (ver lib/auth.js).

import { create } from 'zustand'
import { useAuth, watchFriends } from './auth'

/** list: [{ uid, name, avatar, status, since, challenge }] */
export const useFriends = create(() => ({ list: [], ready: false }))

let stop = null
let started = false

/** Liga a lista de amigos conforme a pessoa entra ou sai da conta. */
export function startFriends() {
  if (started) return
  started = true
  const follow = async (uid) => {
    stop?.()
    stop = null
    useFriends.setState({ list: [], ready: false })
    if (!uid) return
    const unsubscribe = await watchFriends(
      uid,
      (list) => useFriends.setState({ list, ready: true }),
      () => useFriends.setState({ ready: true }),
    ).catch(() => null)
    if (useAuth.getState().user?.uid === uid) stop = unsubscribe
    else unsubscribe?.()
  }
  let current = null
  const check = (auth) => {
    const uid = auth.status === 'signedIn' ? auth.user?.uid : null
    if (uid === current) return
    current = uid
    follow(uid)
  }
  useAuth.subscribe(check)
  check(useAuth.getState())
}

export const friendsOnly = (list) => list.filter((f) => f.status === 'friends')
export const requestsIn = (list) => list.filter((f) => f.status === 'received')
export const requestsOut = (list) => list.filter((f) => f.status === 'sent')
/** Quantos avisos (pedidos recebidos + desafios esperando). */
export const pendingCount = (list) => requestsIn(list).length + list.filter((f) => f.status === 'friends' && f.challenge?.code).length
