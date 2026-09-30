// Bolinha do chat: o último amigo com quem a pessoa abriu uma conversa fica
// num canto da tela, em qualquer página, com as mensagens não lidas. Clicar
// volta para o chat; o X tira a bolinha (igual ao app, chat_bubble.dart).

import { useLocation, useNavigate } from 'react-router-dom'
import { useAuth } from '../lib/auth'
import { setChatBubble, useChatBubble, useFriends } from '../lib/friends'
import { Avatar } from './AccountAvatar'
import { t } from '../lib/i18n'
import { Icon } from './ui'

export default function ChatBubble() {
  const signedIn = useAuth((s) => s.status === 'signedIn')
  const uid = useChatBubble((s) => s.uid)
  const friend = useFriends((s) => s.list.find((f) => f.uid === uid && f.status === 'friends'))
  const { pathname } = useLocation()
  const navigate = useNavigate()
  if (!signedIn || !friend || pathname === `/amigos/chat/${uid}`) return null
  return (
    <div className="fixed right-4 bottom-4 z-40 sm:right-6 sm:bottom-6" data-testid="chat-bubble">
      <button
        type="button"
        onClick={() => navigate(`/amigos/chat/${uid}`)}
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
