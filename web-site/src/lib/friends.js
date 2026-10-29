// Amigos da conta conectada, em tempo real (pedidos, amigos e desafios).
// Formato no Firestore: friends/{uid}/list/{outro} (ver lib/auth.js).

import { create } from 'zustand'
import { useAuth, watchFriends } from './auth'

/** list: [{ uid, name, avatar, status, since, challenge }] */
export const useFriends = create(() => ({ list: [], ready: false }))

// Bolinha do chat: depois de abrir uma conversa, o amigo fica numa bolinha
// no canto da tela (em qualquer página) até a pessoa fechar no X. No PC,
// como no Facebook, a conversa abre numa janelinha no canto (open) que dá
// para minimizar de volta para a bolinha.
const BUBBLE_KEY = 'pocketdex-chat-bubble'
const readBubble = () => {
  try {
    return localStorage.getItem(BUBBLE_KEY) || null
  } catch {
    return null
  }
}
export const useChatBubble = create(() => ({ uid: readBubble(), open: false }))
export function setChatBubble(uid, open = false) {
  useChatBubble.setState({ uid, open: Boolean(uid) && open })
  try {
    if (uid) localStorage.setItem(BUBBLE_KEY, uid)
    else localStorage.removeItem(BUBBLE_KEY)
  } catch {
    // Sem armazenamento: a bolinha vale só até fechar a aba.
  }
}
/** Abre a janelinha do chat no canto (PC). */
export const openChatWindow = (uid) => setChatBubble(uid, true)
export const minimizeChatWindow = () => useChatBubble.setState({ open: false })

/** Tela larga (PC): o chat abre na janelinha em vez da página inteira. */
export const isDesktop = () => {
  try {
    return window.matchMedia('(min-width: 1024px)').matches
  } catch {
    return false
  }
}

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
/** Quantos avisos (pedidos recebidos + desafios esperando + mensagens não lidas). */
export const pendingCount = (list) =>
  requestsIn(list).length +
  list.filter((f) => f.status === 'friends' && f.challenge?.code).length +
  list.filter((f) => f.status === 'friends').reduce((n, f) => n + (f.unread ?? 0), 0)

/** Amigos em ordem de conversa: quem mandou por último primeiro; quem ainda
 *  não conversou vai para o fim, em ordem alfabética (igual ao app). */
export const conversationOrder = (friends) =>
  [...friends].sort((a, b) => (b.last?.at ?? 0) - (a.last?.at ?? 0) || (a.name ?? '').toLowerCase().localeCompare((b.name ?? '').toLowerCase()))

/** "agora", "5 min", "3 h", "ontem" ou a data (dd/mm). */
export function chatTime(at, now = new Date()) {
  const minutes = Math.floor((now - at) / 60000)
  if (minutes < 1) return 'agora'
  if (minutes < 60) return `${minutes} min`
  const when = new Date(at)
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
  const day = new Date(when.getFullYear(), when.getMonth(), when.getDate())
  if (day.getTime() === today.getTime()) return `${Math.floor(minutes / 60)} h`
  if (Math.round((today - day) / 86400000) === 1) return 'ontem'
  return `${String(when.getDate()).padStart(2, '0')}/${String(when.getMonth() + 1).padStart(2, '0')}`
}
