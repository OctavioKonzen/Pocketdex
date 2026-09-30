// Chat com um amigo: as últimas 100 mensagens, em tempo real.
// Só existe enquanto os dois são amigos (as regras do Firestore conferem).

import { useEffect, useRef, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { Avatar } from '../components/AccountAvatar'
import { Empty, Icon } from '../components/ui'
import { CHAT_MAX, errorMessage, markChatRead, sendMessage, useAuth, watchChat } from '../lib/auth'
import { useFriends } from '../lib/friends'

const time = (ms) => {
  const d = new Date(ms)
  const today = new Date().toDateString() === d.toDateString()
  return today
    ? d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
    : d.toLocaleString([], { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' })
}

export default function ChatPage() {
  const { uid } = useParams()
  const user = useAuth((s) => (s.status === 'signedIn' ? s.user : null))
  const friend = useFriends((s) => s.list.find((f) => f.uid === uid && f.status === 'friends'))
  const ready = useFriends((s) => s.ready)
  const [messages, setMessages] = useState(null)
  const [text, setText] = useState('')
  const [error, setError] = useState(null)
  const bottom = useRef(null)
  const me = user?.uid
  const isFriend = Boolean(friend)

  useEffect(() => {
    if (!me || !isFriend) return
    let stop = null
    let alive = true
    watchChat(me, uid, setMessages, (e) => setError(errorMessage(e)))
      .then((s) => (alive ? (stop = s) : s()))
      .catch(() => {})
    return () => {
      alive = false
      stop?.()
    }
  }, [me, uid, isFriend])

  // Com o chat aberto, o que chega já conta como lido.
  const unread = friend?.unread ?? 0
  useEffect(() => {
    if (me && unread > 0) markChatRead(me, uid).catch(() => {})
  }, [me, uid, unread])

  useEffect(() => {
    bottom.current?.scrollIntoView({ block: 'end' })
  }, [messages])

  if (!user) return <Empty>Entre na sua conta para conversar com os amigos.</Empty>
  if (!ready) return null
  if (!friend) return <Empty>Vocês não são amigos (ou a amizade foi desfeita).</Empty>

  const send = async (e) => {
    e.preventDefault()
    const body = text.trim()
    if (!body) return
    setText('')
    setError(null)
    try {
      await sendMessage({ uid: user.uid, name: user.name }, uid, body)
    } catch (err) {
      setText(body)
      setError(errorMessage(err))
    }
  }

  return (
    <div className="mx-auto flex h-[calc(100dvh-7.5rem)] max-w-2xl flex-col overflow-hidden rounded-2xl bg-card shadow">
      <header className="flex items-center gap-3 border-b border-line px-3 py-2.5">
        <Link to="/amigos" aria-label="Voltar" className="rounded-full p-1.5 text-muted hover:bg-surface hover:text-text">
          <Icon name="back" size={22} />
        </Link>
        <Avatar pokemonId={friend.avatar ?? null} name={friend.name} size={38} />
        <div className="min-w-0 flex-1 truncate font-bold" data-no-translate>
          {friend.name}
        </div>
      </header>

      <div className="flex-1 space-y-2 overflow-y-auto px-3 py-4" data-chat>
        {messages === null ? (
          <p className="text-center text-sm text-muted">...</p>
        ) : !messages.length ? (
          <p className="mt-8 text-center text-sm text-muted">Nenhuma mensagem ainda. Diga oi! 👋</p>
        ) : (
          messages.map((m) => {
            const mine = m.from === me
            return (
              <div key={m.id} className={`flex ${mine ? 'justify-end' : 'justify-start'}`}>
                <div
                  className={`max-w-[80%] rounded-2xl px-3.5 py-2 ${mine ? 'rounded-br-md bg-sky-600 text-white' : 'rounded-bl-md bg-surface'}`}
                >
                  <div className="whitespace-pre-wrap break-words" data-no-translate>
                    {m.text}
                  </div>
                  <div className={`mt-0.5 text-right text-[10px] ${mine ? 'text-white/70' : 'text-muted'}`} data-no-translate>
                    {time(m.at)}
                  </div>
                </div>
              </div>
            )
          })
        )}
        <div ref={bottom} />
      </div>

      {error && <p className="px-3 pb-1 text-sm text-red-400">{error}</p>}
      <form onSubmit={send} className="flex items-end gap-2 border-t border-line p-2.5">
        <textarea
          value={text}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && !e.shiftKey) send(e)
          }}
          rows={1}
          maxLength={CHAT_MAX}
          placeholder="Mensagem"
          aria-label="Mensagem"
          className="max-h-32 min-w-0 flex-1 resize-none rounded-xl bg-surface px-4 py-2.5 outline-none focus:ring-2 focus:ring-sky-400"
        />
        <button
          type="submit"
          aria-label="Enviar"
          disabled={!text.trim()}
          className="grid h-11 w-11 shrink-0 cursor-pointer place-items-center rounded-full bg-sky-600 text-white disabled:cursor-default disabled:opacity-40"
        >
          <Icon name="send" size={20} />
        </button>
      </form>
    </div>
  )
}
