// Amigos: adicionar pelo nome, pedidos recebidos e enviados, desafios que
// os amigos deixaram e a lista com o recorde do Ranked de cada um.

import { useEffect, useMemo, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { Avatar } from '../components/AccountAvatar'
import { Button, Empty, Icon, PageHeader } from '../components/ui'
import { acceptFriend, clearChallenge, errorMessage, findAccount, friendRecords, removeFriend, sendFriendRequest, useAuth } from '../lib/auth'
import { decodeChallenge } from '../lib/challenge'
import { chatTime, conversationOrder, friendsOnly, isDesktop, openChatWindow, requestsIn, requestsOut, useFriends } from '../lib/friends'
import { t } from '../lib/i18n'
import { BattleInvites } from './OnlineBattlePage'
import { useStore } from '../lib/store'

const CARD = 'rounded-2xl bg-card p-5 shadow'

export default function FriendsPage() {
  const user = useAuth((s) => (s.status === 'signedIn' ? s.user : null))
  const avatar = useStore((s) => s.avatar)
  const rankedRecord = useStore((s) => s.rankedRecord)
  const list = useFriends((s) => s.list)
  const ready = useFriends((s) => s.ready)
  const navigate = useNavigate()
  const [name, setName] = useState('')
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState(null) // { ok, text }
  const [records, setRecords] = useState({})

  const friends = useMemo(() => friendsOnly(list), [list])
  const incoming = requestsIn(list)
  const outgoing = requestsOut(list)
  const challenges = friends.filter((f) => f.challenge?.code)
  const chats = useMemo(() => conversationOrder(friends), [friends])
  const unreadTotal = friends.reduce((n, f) => n + (f.unread ?? 0), 0)
  const friendIds = friends.map((f) => f.uid).join(',')

  // Recorde do Ranked de cada amigo.
  useEffect(() => {
    if (!friendIds) return
    friendRecords(friendIds.split(',')).then(setRecords).catch(() => {})
  }, [friendIds])

  if (!user) return <Empty>Entre na sua conta para ter amigos.</Empty>
  const me = { uid: user.uid, name: user.name, avatar }
  const now = new Date()

  const add = async (e) => {
    e.preventDefault()
    const typed = name.trim()
    if (!typed) return
    setBusy(true)
    setMessage(null)
    try {
      const other = await findAccount(typed)
      if (!other) setMessage({ ok: false, text: 'Ninguém com esse nome. Confira como está escrito.' })
      else if (other.uid === user.uid) setMessage({ ok: false, text: 'Esse é você!' })
      else {
        const existing = list.find((f) => f.uid === other.uid)
        if (existing?.status === 'friends') setMessage({ ok: false, text: 'Vocês já são amigos.' })
        else if (existing?.status === 'sent') setMessage({ ok: false, text: 'Você já mandou um pedido para essa pessoa.' })
        else if (existing?.status === 'received') {
          await acceptFriend(me, other.uid)
          setMessage({ ok: true, text: 'Essa pessoa já tinha te chamado: agora vocês são amigos!' })
        } else {
          await sendFriendRequest(me, other)
          setMessage({ ok: true, text: 'Pedido enviado! Quando a pessoa aceitar, ela aparece na sua lista.' })
        }
        setName('')
      }
    } catch (err) {
      // Com o pedido antigo já limpo, o que ainda bloqueia é a conta não existir
      // mais (excluída; o nome dela ficou registrado).
      setMessage({ ok: false, text: err?.code === 'permission-denied' ? t('Essa conta não existe mais (foi excluída).') : errorMessage(err) })
    }
    setBusy(false)
  }

  const play = (friend) => {
    const code = friend.challenge.code
    clearChallenge(user.uid, friend.uid).catch(() => {})
    navigate(`/jogo?desafio=${code}&amigo=${friend.uid}`)
  }

  // Ranking entre amigos (eu incluído), pelo recorde do Ranked.
  const board = [...friends.map((f) => ({ ...f, score: records[f.uid] ?? 0 })), { uid: user.uid, name: user.name, avatar, score: rankedRecord, me: true }].sort(
    (a, b) => b.score - a.score,
  )

  return (
    <div className="mx-auto max-w-2xl space-y-6">
      <PageHeader title="Amigos" subtitle="Adicione amigos pelo nome, compare recordes e mande desafios." />

      {/* Os modos de batalha (computador, online e draft) ficam no menu Batalha. */}
      <Link to="/batalha" className="block rounded-2xl bg-gradient-to-r from-red-600 to-purple-600 px-4 py-3 text-center font-bold text-white shadow transition hover:scale-[1.02]">
        ⚔️ Batalhar
      </Link>

      <BattleInvites />
      <form onSubmit={add} className={CARD}>
        <div className="mb-2 font-bold">Adicionar amigo</div>
        <div className="flex gap-2">
          <input
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Nome da pessoa no PocketDex"
            maxLength={20}
            className="min-w-0 flex-1 rounded-xl bg-surface px-4 py-2.5 outline-none focus:ring-2 focus:ring-sky-400"
          />
          <Button type="submit" disabled={busy || !name.trim()}>
            {busy ? 'Enviando...' : 'Enviar pedido'}
          </Button>
        </div>
        {message && <p className={`mt-2 text-sm ${message.ok ? 'text-green-400' : 'text-red-400'}`}>{message.text}</p>}
      </form>

      {incoming.length > 0 && (
        <section className={CARD}>
          <div className="mb-3 font-bold">{`Pedidos recebidos (${incoming.length})`}</div>
          <ul className="space-y-2">
            {incoming.map((f) => (
              <li key={f.uid} className="flex items-center gap-3">
                <Avatar pokemonId={f.avatar ?? null} name={f.name} size={40} />
                <span className="min-w-0 flex-1 truncate font-semibold">{f.name}</span>
                <Button color="#43a047" onClick={() => acceptFriend(me, f.uid)}>
                  Aceitar
                </Button>
                <button type="button" onClick={() => removeFriend(user.uid, f.uid)} className="cursor-pointer px-2 text-sm text-muted hover:text-red-400">
                  Recusar
                </button>
              </li>
            ))}
          </ul>
        </section>
      )}

      {challenges.length > 0 && (
        <section className={CARD}>
          <div className="mb-3 font-bold">Desafios dos amigos</div>
          <ul className="space-y-2">
            {challenges.map((f) => {
              const c = decodeChallenge(f.challenge.code)
              return (
                <li key={f.uid} className="flex items-center gap-3 rounded-xl bg-violet-500/10 p-2">
                  <Avatar pokemonId={f.avatar ?? null} name={f.name} size={40} />
                  <div className="min-w-0 flex-1">
                    <div className="truncate font-semibold">{`🤝 ${f.name} te desafiou!`}</div>
                    <div className="text-xs text-muted">{c ? `Fez ${c.score}/10` : ''}</div>
                  </div>
                  <Button color="#7C3AED" onClick={() => play(f)}>
                    Jogar
                  </Button>
                  <button type="button" aria-label="Dispensar" onClick={() => clearChallenge(user.uid, f.uid)} className="cursor-pointer text-muted hover:text-text">
                    <Icon name="close" size={18} />
                  </button>
                </li>
              )
            })}
          </ul>
        </section>
      )}

      {/* Conversas (como no WhatsApp): cada amigo com a última mensagem; clicar abre o chat. */}
      <section className={CARD}>
        <div className="mb-1 font-bold">{unreadTotal > 0 ? `💬 ${t('Conversas')} (${unreadTotal})` : '💬 Conversas'}</div>
        <p className="mb-2 text-xs text-muted">As mensagens somem sozinhas depois de 7 dias.</p>
        {!ready ? (
          <p className="text-sm text-muted">...</p>
        ) : !friends.length ? (
          <p className="text-sm text-muted">Você ainda não tem amigos aqui. Adicione alguém pelo nome.</p>
        ) : (
          <ul className="-mx-2 divide-y divide-black/5 dark:divide-white/5">
            {chats.map((f) => {
              const unread = f.unread > 0
              return (
                <li key={f.uid}>
                  <Link
                    to={`/amigos/chat/${f.uid}`}
                    onClick={(e) => {
                      // No PC a conversa abre na janelinha do canto (como no Facebook).
                      if (isDesktop()) {
                        e.preventDefault()
                        openChatWindow(f.uid)
                      }
                    }}
                    aria-label={`${t('Conversar')}: ${f.name}`}
                    className="flex items-center gap-3 rounded-xl px-2 py-2.5 transition hover:bg-surface"
                  >
                    <Avatar pokemonId={f.avatar ?? null} name={f.name} size={48} />
                    <div className="min-w-0 flex-1">
                      <div className="flex items-baseline gap-2">
                        <span className="min-w-0 flex-1 truncate font-bold" data-no-translate>
                          {f.name}
                        </span>
                        {f.last?.at && <span className={`shrink-0 text-xs ${unread ? 'font-bold text-green-500' : 'text-muted'}`}>{t(chatTime(f.last.at, now))}</span>}
                      </div>
                      <div className="flex items-center gap-2">
                        <span className={`min-w-0 flex-1 truncate text-sm ${unread ? 'font-semibold text-text' : 'text-muted'}`}>
                          {f.last?.text ? (
                            <>
                              {f.last.from === user.uid && <span>{`${t('Você')}: `}</span>}
                              <span data-no-translate>{f.last.text}</span>
                            </>
                          ) : (
                            'Nenhuma mensagem ainda. Diga oi!'
                          )}
                        </span>
                        {unread && (
                          <span className="grid h-5 min-w-5 shrink-0 place-items-center rounded-full bg-green-500 px-1.5 text-[11px] font-bold text-white">
                            {f.unread > 99 ? '99+' : f.unread}
                          </span>
                        )}
                      </div>
                    </div>
                  </Link>
                </li>
              )
            })}
          </ul>
        )}
      </section>

      <section className={CARD}>
        <div className="mb-1 font-bold">{`Amigos (${friends.length})`}</div>
        <p className="mb-3 text-xs text-muted">Ranking entre vocês pelo recorde do Ranked. No fim de um desafio no Jogo, dá para mandar o desafio para um amigo.</p>
        {!ready ? (
          <p className="text-sm text-muted">...</p>
        ) : !friends.length ? (
          <p className="text-sm text-muted">Você ainda não tem amigos aqui. Adicione alguém pelo nome.</p>
        ) : (
          <ol className="space-y-2">
            {board.map((f, i) => (
              <li key={f.uid} className={`flex items-center gap-3 rounded-xl px-2 py-1.5 ${f.me ? 'bg-yellow-400/15 ring-1 ring-yellow-400' : ''}`}>
                <span className="w-6 text-center font-black text-muted">{i + 1}</span>
                <Avatar pokemonId={f.avatar ?? null} name={f.name} size={38} />
                <div className="min-w-0 flex-1">
                  <div className="truncate font-semibold">
                    <span data-no-translate>{f.name}</span>
                    {f.me && <span className="ml-2 text-xs text-yellow-400">você</span>}
                  </div>
                </div>
                <span className="font-black text-yellow-400">{`🏆 ${f.score}`}</span>
                {!f.me && (
                  <div className="flex flex-wrap gap-2">
                    <Link to={`/batalha/online?amigo=${f.uid}`} className="rounded-full bg-sky-600 px-3 py-1 text-xs font-bold text-white">Batalha</Link>
                    <Link to={`/jogo?amigo=${f.uid}`} className="rounded-full bg-violet-600 px-3 py-1 text-xs font-bold text-white">Quiz</Link>
                  </div>
                )}
                {!f.me && (
                  <button type="button" aria-label="Desfazer amizade" title="Desfazer amizade" onClick={() => removeFriend(user.uid, f.uid)} className="cursor-pointer text-muted hover:text-red-400">
                    <Icon name="delete" size={18} />
                  </button>
                )}
              </li>
            ))}
          </ol>
        )}
      </section>

      {outgoing.length > 0 && (
        <section className={CARD}>
          <div className="mb-3 font-bold">{`Pedidos enviados (${outgoing.length})`}</div>
          <ul className="space-y-2">
            {outgoing.map((f) => (
              <li key={f.uid} className="flex items-center gap-3">
                <Avatar pokemonId={null} name={f.name} size={36} />
                <span className="min-w-0 flex-1 truncate">{f.name}</span>
                <button type="button" onClick={() => removeFriend(user.uid, f.uid)} className="cursor-pointer text-sm text-muted hover:text-red-400">
                  Cancelar
                </button>
              </li>
            ))}
          </ul>
        </section>
      )}
    </div>
  )
}
