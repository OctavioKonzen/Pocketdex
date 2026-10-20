// Draft entre amigos (igual ao app, draft_screen.dart): você e um amigo
// escolhem Pokémon um de cada vez, sem repetir; no fim, batalham com os times
// que saíram e dá para salvar o seu.

import { useEffect, useMemo, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import PokeIcon from '../components/PokeIcon'
import PokemonPicker from '../components/PokemonPicker'
import { Button, Empty, Icon, PageHeader } from '../components/ui'
import { createDraft, deleteDraft, errorMessage, pickDraft, useAuth, watchDraft, watchMyDrafts } from '../lib/auth'
import { friendsOnly, useFriends } from '../lib/friends'
import { usePokemonIndex } from '../lib/pokemonIndex'
import { prettyName } from '../lib/pokemon'
import { useStore } from '../lib/store'

const CARD = 'rounded-2xl bg-card p-5 shadow'

/** Ouve um snapshot do Firestore (start devolve a função que para). */
function follow(start, set) {
  let stop = null
  let alive = true
  start(set)?.then((s) => (alive ? (stop = s) : s?.()))
  return () => {
    alive = false
    stop?.()
  }
}

/** Um lado do draft: as escolhas de cada jogador. */
function Side({ title, ids, size, active, name }) {
  return (
    <div className={`${CARD} ${active ? 'ring-2 ring-sky-400' : ''}`}>
      <div className="mb-2 truncate font-bold" data-no-translate>
        {title}
      </div>
      <ul className="space-y-1">
        {Array.from({ length: size }, (_, i) => (
          <li key={i} className="flex h-11 items-center gap-2">
            {ids[i] ? (
              <>
                <PokeIcon id={ids[i]} className="h-10 w-10" />
                <span className="truncate text-sm">{name(ids[i])}</span>
              </>
            ) : (
              <span className="text-muted">—</span>
            )}
          </li>
        ))}
      </ul>
    </div>
  )
}

export default function DraftPage() {
  const { id } = useParams()
  return id ? <DraftRoom id={id} /> : <DraftList />
}

function DraftList() {
  const user = useAuth((s) => (s.status === 'signedIn' ? s.user : null))
  const list = useFriends((s) => s.list)
  const friends = useMemo(() => friendsOnly(list), [list])
  const [drafts, setDrafts] = useState(undefined)
  const uid = user?.uid
  useEffect(() => (uid ? follow((set) => watchMyDrafts(uid, set), setDrafts) : undefined), [uid])
  const [size, setSize] = useState(6)
  const [error, setError] = useState(null)
  const navigate = useNavigate()
  if (!user) return <Empty>Entre na sua conta para fazer drafts com os amigos.</Empty>
  const start = async (f) => {
    try {
      navigate(`/batalha/draft/${await createDraft({ uid: user.uid, name: user.name }, f, size)}`)
    } catch (e) {
      setError(errorMessage(e))
    }
  }
  return (
    <div className="mx-auto max-w-2xl space-y-6">
      <PageHeader title="Draft" subtitle="Você e um amigo escolhem Pokémon um de cada vez, sem repetir. Depois, batalhem com os times que saíram!" />
      <Link to="/batalha" className="inline-flex items-center gap-1 text-sm text-muted hover:text-text">
        <Icon name="back" size={16} /> Centro de Batalha
      </Link>
      <section className={CARD}>
        <div className="mb-2 font-bold">Novo draft</div>
        <div className="mb-3 flex items-center gap-2 text-sm">
          Pokémon para cada um:
          {[3, 6].map((n) => (
            <button
              key={n}
              type="button"
              onClick={() => setSize(n)}
              className={`cursor-pointer rounded-full px-3 py-1 font-bold ${size === n ? 'bg-sky-600 text-white' : 'bg-surface'}`}
            >
              {n}
            </button>
          ))}
        </div>
        {!friends.length ? (
          <p className="text-sm text-muted">Adicione amigos para fazer um draft.</p>
        ) : (
          <div className="flex flex-wrap gap-2">
            {friends.map((f) => (
              <Button key={f.uid} onClick={() => start(f)}>
                <span data-no-translate>{f.name}</span>
              </Button>
            ))}
          </div>
        )}
        {error && <p className="mt-2 text-sm text-red-400">{error}</p>}
      </section>
      <section className={CARD}>
        <div className="mb-3 font-bold">Meus drafts</div>
        {drafts === undefined ? (
          <p className="text-sm text-muted">...</p>
        ) : !drafts.length ? (
          <p className="text-sm text-muted">Nenhum draft ainda.</p>
        ) : (
          <ul className="space-y-2">
            {drafts.map((d) => {
              const other = d.players.find((p) => p !== user.uid)
              const myTurn = d.status !== 'done' && d.turn === user.uid
              return (
                <li key={d.id}>
                  <Link to={`/batalha/draft/${d.id}`} className="flex items-center gap-3 rounded-xl bg-surface p-3 hover:ring-2 hover:ring-sky-400">
                    <div className="min-w-0 flex-1">
                      <div className="truncate font-semibold" data-no-translate>{`Com ${d.names?.[other] ?? '?'}`}</div>
                      <div className={`text-xs ${myTurn ? 'font-bold text-red-400' : 'text-muted'}`}>
                        {d.status === 'done' ? 'Acabou · pronto para batalhar' : myTurn ? 'Sua vez de escolher!' : 'Vez do amigo'}
                      </div>
                    </div>
                    {(d.picks[user.uid] ?? []).map((id) => (
                      <PokeIcon key={id} id={id} className="h-8 w-8" />
                    ))}
                  </Link>
                </li>
              )
            })}
          </ul>
        )}
      </section>
    </div>
  )
}

function DraftRoom({ id }) {
  const user = useAuth((s) => (s.status === 'signedIn' ? s.user : null))
  const [draft, setDraft] = useState(undefined)
  useEffect(() => follow((set) => watchDraft(id, set), setDraft), [id])
  const byId = usePokemonIndex()
  const importTeam = useStore((s) => s.importTeam)
  const navigate = useNavigate()
  const [picking, setPicking] = useState(false)
  const [error, setError] = useState(null)
  if (!user) return <Empty>Entre na sua conta para fazer drafts com os amigos.</Empty>
  if (draft === undefined) return null
  if (draft === null) return <Empty>Esse draft foi apagado.</Empty>
  const me = user.uid
  const other = draft.players.find((p) => p !== me)
  const mine = draft.picks[me] ?? []
  const theirs = draft.picks[other] ?? []
  const done = draft.status === 'done'
  const myTurn = !done && draft.turn === me
  const name = (pid) => prettyName(byId?.get(pid)?.name?.split('-')[0] ?? `#${pid}`)

  const pick = async (p) => {
    setPicking(false)
    setError(null)
    if (p.id > 1025) return setError('No draft vale só a forma normal de cada Pokémon.')
    try {
      await pickDraft(me, id, p.id)
    } catch (e) {
      setError(errorMessage(e))
    }
  }
  // Batalha por turnos com os times do draft (o computador joga pelo amigo).
  const fight = () => navigate('/batalha/computador', { state: { mine, theirs, foeName: draft.names?.[other] ?? '' } })
  return (
    <div className="mx-auto max-w-3xl space-y-5">
      <Link to="/batalha/draft" className="inline-flex items-center gap-1 text-sm text-muted hover:text-text">
        <Icon name="back" size={16} /> Drafts
      </Link>
      <div className="text-2xl font-black">
        {done ? 'Draft completo! Hora de batalhar.' : myTurn ? 'Sua vez de escolher!' : `Vez de ${draft.names?.[other] ?? ''} escolher...`}
      </div>
      <div className="grid grid-cols-2 gap-3">
        <Side title="Você" ids={mine} size={draft.size} active={myTurn} name={name} />
        <Side title={draft.names?.[other] ?? '?'} ids={theirs} size={draft.size} active={!done && draft.turn === other} name={name} />
      </div>
      {error && <p className="text-sm text-red-400">{error}</p>}
      {myTurn && (
        <Button className="w-full" onClick={() => setPicking(true)}>
          Escolher Pokémon
        </Button>
      )}
      {done && (
        <div className="flex flex-wrap gap-2">
          <Button color="linear-gradient(90deg,#DC2626,#9333EA)" className="flex-1" onClick={fight}>
            ⚔️ Batalhar!
          </Button>
          <Button
            color="#546E7A"
            onClick={() => navigate(`/times/${importTeam({ name: `Draft com ${draft.names?.[other] ?? ''}`, pokemon: mine, sets: [] })}`)}
          >
            Salvar meu time
          </Button>
        </div>
      )}
      <button
        type="button"
        onClick={async () => {
          await deleteDraft(id).catch(() => {})
          navigate('/batalha/draft')
        }}
        className="cursor-pointer text-sm text-red-400 hover:underline"
      >
        Apagar draft
      </button>
      <PokemonPicker open={picking} onClose={() => setPicking(false)} onPick={pick} />
    </div>
  )
}
