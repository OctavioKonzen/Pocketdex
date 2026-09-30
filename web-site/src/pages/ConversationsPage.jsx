// Conversas: todos os chats com os amigos, do mais recente para o mais
// antigo, com a última mensagem e as não lidas (igual ao app,
// conversations_screen.dart). Clicar abre o chat.

import { useMemo } from 'react'
import { Link } from 'react-router-dom'
import { Avatar } from '../components/AccountAvatar'
import { Empty, Icon, PageHeader } from '../components/ui'
import { useAuth } from '../lib/auth'
import { chatTime, conversationOrder, friendsOnly, useFriends } from '../lib/friends'
import { t } from '../lib/i18n'

export default function ConversationsPage() {
  const user = useAuth((s) => (s.status === 'signedIn' ? s.user : null))
  const list = useFriends((s) => s.list)
  const ready = useFriends((s) => s.ready)
  const friends = useMemo(() => conversationOrder(friendsOnly(list)), [list])

  if (!user) return <Empty>Entre na sua conta para conversar com os amigos.</Empty>
  const now = new Date()

  return (
    <div className="mx-auto max-w-2xl">
      <PageHeader title="Conversas" subtitle="Seus chats com os amigos, do mais recente para o mais antigo.">
        <Link to="/amigos" className="flex items-center gap-1 text-sm font-semibold text-sky-400 hover:text-sky-300">
          <Icon name="left" size={18} />
          Amigos
        </Link>
      </PageHeader>
      {!ready ? (
        <p className="text-sm text-muted">...</p>
      ) : !friends.length ? (
        <Empty>Você ainda não tem amigos aqui. Adicione alguém pelo nome.</Empty>
      ) : (
        <ul className="space-y-2">
          {friends.map((f) => {
            const unread = f.unread > 0
            return (
              <li key={f.uid}>
                <Link to={`/amigos/chat/${f.uid}`} className="flex items-center gap-3 rounded-2xl bg-card p-3 shadow transition hover:scale-[1.01]">
                  <Avatar pokemonId={f.avatar ?? null} name={f.name} size={44} />
                  <div className="min-w-0 flex-1">
                    <div className="truncate font-bold" data-no-translate>
                      {f.name}
                    </div>
                    {f.last?.text ? (
                      <div className={`truncate text-sm ${unread ? 'font-bold text-text' : 'text-muted'}`}>
                        {f.last.from === user.uid && <span>{`${t('Você')}: `}</span>}
                        <span data-no-translate>{f.last.text}</span>
                      </div>
                    ) : (
                      <div className="text-sm text-muted">Nenhuma mensagem ainda. Diga oi!</div>
                    )}
                  </div>
                  <div className="flex shrink-0 flex-col items-end gap-1">
                    {f.last?.at && <span className="text-xs text-muted">{t(chatTime(f.last.at, now))}</span>}
                    {unread && (
                      <span className="grid h-5 min-w-5 place-items-center rounded-full bg-red-500 px-1.5 text-[11px] font-bold text-white">
                        {f.unread > 9 ? '9+' : f.unread}
                      </span>
                    )}
                  </div>
                </Link>
              </li>
            )
          })}
        </ul>
      )}
    </div>
  )
}
