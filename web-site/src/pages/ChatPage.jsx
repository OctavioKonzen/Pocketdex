// Chat com um amigo: as últimas 100 mensagens, em tempo real.
// Só existe enquanto os dois são amigos (as regras do Firestore conferem).

import { useEffect, useRef, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { Avatar } from '../components/AccountAvatar'
import PokeIcon from '../components/PokeIcon'
import PokemonModal from '../components/PokemonModal'
import PokemonPicker from '../components/PokemonPicker'
import { Empty, Icon } from '../components/ui'
import { CHAT_MAX, errorMessage, markChatRead, sendMessage, useAuth, watchChat } from '../lib/auth'
import { setChatBubble, useFriends } from '../lib/friends'
import { usePokemonIndex } from '../lib/pokemonIndex'
import { t } from '../lib/i18n'
import { prettyName } from '../lib/pokemon'
import { useStore } from '../lib/store'
import { decodeTeam, encodeTeam } from '../lib/teamShare'

const time = (ms) => {
  const d = new Date(ms)
  const today = new Date().toDateString() === d.toDateString()
  return today
    ? d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
    : d.toLocaleString([], { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' })
}

/** Cartão de Pokémon (abre a página dele) ou de time (dá para salvar). */
function CardView({ card, light, onOpen }) {
  const importTeam = useStore((s) => s.importTeam)
  const navigate = useNavigate()
  if (card.kind === 'pokemon' && Number.isInteger(card.id)) {
    return (
      <button type="button" onClick={() => onOpen(card.id)} className="flex w-full cursor-pointer items-center gap-2 text-left">
        <PokeIcon id={card.id} className="h-14 w-14" />
        <span className="flex-1 font-bold" data-no-translate>
          {card.name}
        </span>
        <Icon name="right" size={20} />
      </button>
    )
  }
  const save = () => {
    const team = decodeTeam(card.code)
    if (team) navigate(`/times/${importTeam(team)}`)
  }
  return (
    <div>
      <div className="flex items-center gap-1.5 font-bold" data-no-translate>
        <Icon name="groups" size={18} />
        {card.name}
      </div>
      <div className="mt-1 flex flex-wrap">
        {(card.ids ?? []).map((id, i) => (
          <PokeIcon key={i} id={id} className="h-10 w-10" />
        ))}
      </div>
      <button type="button" onClick={save} className={`mt-1 cursor-pointer text-sm font-semibold underline ${light ? 'text-white' : 'text-sky-400'}`}>
        Salvar nos meus times
      </button>
    </div>
  )
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
  const [attaching, setAttaching] = useState(false)
  const [picking, setPicking] = useState(false)
  const [open, setOpen] = useState(null)
  const teams = useStore((s) => s.teams)
  const byId = usePokemonIndex()
  const me = user?.uid
  const isFriend = Boolean(friend)

  // Abriu a conversa: o amigo vira a bolinha do chat.
  useEffect(() => {
    if (me && isFriend) setChatBubble(uid)
  }, [me, isFriend, uid])

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

  const sendCard = async (body, card) => {
    setAttaching(false)
    setError(null)
    try {
      await sendMessage({ uid: user.uid, name: user.name }, uid, body, card)
    } catch (err) {
      setError(errorMessage(err))
    }
  }
  const sendPokemon = (p) => {
    setPicking(false)
    const name = t(prettyName(byId?.get(p.id)?.name ?? p.name ?? `#${p.id}`)).slice(0, 60)
    sendCard(`📎 ${name}`, { kind: 'pokemon', id: p.id, name })
  }
  const sendTeam = (team) => {
    const name = (team.name || 'Time').slice(0, 60)
    sendCard(`📎 ${t('Time')}: ${name}`, { kind: 'team', name, ids: team.pokemon.filter((x) => x != null), code: encodeTeam(team) })
  }
  const usableTeams = teams.filter((x) => x.pokemon?.some((p) => p != null))

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
                  {m.card ? (
                    <CardView card={m.card} light={mine} onOpen={setOpen} />
                  ) : (
                    <div className="whitespace-pre-wrap break-words" data-no-translate>
                      {m.text}
                    </div>
                  )}
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
      {attaching && (
        <div className="max-h-60 space-y-1 overflow-y-auto border-t border-line p-2.5">
          <button type="button" onClick={() => setPicking(true)} className="flex w-full cursor-pointer items-center gap-2 rounded-xl px-3 py-2 hover:bg-surface">
            <Icon name="pokeball" size={20} /> Mandar um Pokémon
          </button>
          {usableTeams.length > 0 && <div className="px-3 pt-2 text-xs font-bold text-muted">Mandar um time</div>}
          {usableTeams.map((team) => (
            <button
              key={team.id}
              type="button"
              onClick={() => sendTeam(team)}
              className="flex w-full cursor-pointer items-center gap-2 rounded-xl px-3 py-1.5 hover:bg-surface"
            >
              <span className="min-w-0 flex-1 truncate text-left" data-no-translate>
                {team.name}
              </span>
              {team.pokemon
                .filter((x) => x != null)
                .map((id, i) => (
                  <PokeIcon key={i} id={id} className="h-8 w-8" />
                ))}
            </button>
          ))}
        </div>
      )}
      <form onSubmit={send} className="flex items-end gap-2 border-t border-line p-2.5">
        <button
          type="button"
          aria-label="Mandar Pokémon ou time"
          title="Mandar Pokémon ou time"
          onClick={() => setAttaching(!attaching)}
          className={`grid h-11 w-11 shrink-0 cursor-pointer place-items-center rounded-full ${attaching ? 'bg-sky-600 text-white' : 'text-muted hover:bg-surface'}`}
        >
          <Icon name="add" size={22} />
        </button>
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
      <PokemonPicker open={picking} onClose={() => setPicking(false)} onPick={sendPokemon} />
      <PokemonModal id={open} onClose={() => setOpen(null)} />
    </div>
  )
}
