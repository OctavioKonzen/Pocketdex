// Bolinha do chat: o último amigo com quem a pessoa abriu uma conversa fica
// num canto da tela, em qualquer página, com as mensagens não lidas. O X
// tira a bolinha (igual ao app, chat_bubble.dart).
//
// No celular, clicar leva para a página do chat. No PC, como no Facebook, a
// conversa abre numa janelinha no canto de baixo, que dá para minimizar
// (volta a ser a bolinha), abrir em tela cheia ou fechar.

import { lazy, Suspense, useEffect, useState } from 'react'
import { Link, useLocation, useNavigate } from 'react-router-dom'
import { useAuth } from '../lib/auth'
import { isDesktop, minimizeChatWindow, openChatWindow, setChatBubble, useChatBubble, useFriends } from '../lib/friends'
import { t } from '../lib/i18n'
import { Avatar } from './AccountAvatar'
import { Icon } from './ui'

const ChatBox = lazy(() => import('../pages/ChatPage').then((m) => ({ default: m.ChatBox })))

/** Acompanha se a tela é de PC (muda ao redimensionar). */
function useDesktop() {
  const [desktop, setDesktop] = useState(isDesktop)
  useEffect(() => {
    let query
    try {
      query = window.matchMedia('(min-width: 1024px)')
    } catch {
      return undefined
    }
    const change = () => setDesktop(query.matches)
    query.addEventListener?.('change', change)
    return () => query.removeEventListener?.('change', change)
  }, [])
  return desktop
}

const headerButton = 'grid h-8 w-8 cursor-pointer place-items-center rounded-full text-muted hover:bg-surface hover:text-text'

export default function ChatBubble() {
  const signedIn = useAuth((s) => s.status === 'signedIn')
  const uid = useChatBubble((s) => s.uid)
  const open = useChatBubble((s) => s.open)
  const friend = useFriends((s) => s.list.find((f) => f.uid === uid && f.status === 'friends'))
  const { pathname } = useLocation()
  const navigate = useNavigate()
  const desktop = useDesktop()
  const onChatPage = pathname === `/amigos/chat/${uid}`
  // Abriu a conversa em tela cheia: ao sair dela, volta a ser a bolinha.
  useEffect(() => {
    if (onChatPage) minimizeChatWindow()
  }, [onChatPage])
  if (!signedIn || !friend || onChatPage) return null

  if (desktop && open) {
    return (
      <div
        className="fixed right-6 bottom-0 z-40 flex h-[min(480px,calc(100dvh-6rem))] w-[340px] flex-col overflow-hidden rounded-t-2xl shadow-2xl ring-1 ring-black/10"
        data-testid="chat-window"
      >
        <Suspense fallback={<div className="flex-1 bg-card" />}>
          <ChatBox
            uid={uid}
            className="h-full"
            header={(f) => (
              <header className="flex items-center gap-2 border-b border-line bg-card px-2.5 py-2">
                <Avatar pokemonId={f.avatar ?? null} name={f.name} size={32} />
                <div className="min-w-0 flex-1 truncate font-bold" data-no-translate>
                  {f.name}
                </div>
                <Link to={`/amigos/chat/${uid}`} aria-label="Abrir em tela cheia" title="Abrir em tela cheia" className={headerButton}>
                  <Icon name="openNew" size={16} />
                </Link>
                <button type="button" onClick={minimizeChatWindow} aria-label="Minimizar" title="Minimizar" className={headerButton}>
                  <Icon name="minimize" size={18} />
                </button>
                <button type="button" onClick={() => setChatBubble(null)} aria-label="Fechar" title="Fechar" className={headerButton}>
                  <Icon name="close" size={18} />
                </button>
              </header>
            )}
          />
        </Suspense>
      </div>
    )
  }

  return (
    <div className="fixed right-4 bottom-4 z-40 sm:right-6 sm:bottom-6" data-testid="chat-bubble">
      <button
        type="button"
        onClick={() => (desktop ? openChatWindow(uid) : navigate(`/amigos/chat/${uid}`))}
        aria-label={`${t('Conversar')}: ${friend.name}`}
        title={friend.name}
        className="relative grid h-14 w-14 cursor-pointer place-items-center rounded-full bg-card shadow-lg ring-2 ring-sky-500 transition hover:scale-105"
      >
        <Avatar pokemonId={friend.avatar ?? null} name={friend.name} size={48} />
        {friend.unread > 0 && (
          <span className="absolute -top-1 -left-1 grid h-5 min-w-5 place-items-center rounded-full bg-red-500 px-1 text-[11px] font-bold text-white">
            {friend.unread > 9 ? '9+' : friend.unread}
          </span>
        )}
      </button>
      <button
        type="button"
        onClick={() => setChatBubble(null)}
        aria-label="Fechar"
        title="Fechar"
        className="absolute -top-1.5 -right-1.5 grid h-5 w-5 cursor-pointer place-items-center rounded-full bg-surface text-muted shadow ring-1 ring-black/10 hover:text-text"
      >
        <Icon name="close" size={14} />
      </button>
    </div>
  )
}
