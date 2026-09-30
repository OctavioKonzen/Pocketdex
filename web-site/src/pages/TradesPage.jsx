// Trocas entre amigos (igual ao app, trades_screen.dart): marque os Pokémon
// que você tem repetidos e veja, para cada amigo, o que você pode dar
// (repetidos seus que ele não pegou) e o que pode receber (repetidos dele que
// faltam para você). "Pegos" vem da Coleção de cada um.

import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { Avatar } from '../components/AccountAvatar'
import PokeIcon from '../components/PokeIcon'
import PokemonModal from '../components/PokemonModal'
import PokemonPicker from '../components/PokemonPicker'
import { Button, Empty, Icon, PageHeader } from '../components/ui'
import { allCaught, friendTrades, saveTrades, useAuth, watchMyTrades } from '../lib/auth'
import { friendsOnly, useFriends } from '../lib/friends'
import { useStore } from '../lib/store'

const CARD = 'rounded-2xl bg-card p-5 shadow'

function Icons({ ids, onRemove, onOpen }) {
  return (
    <div className="flex flex-wrap gap-1.5">
      {ids.map((id) => (
        <div key={id} className="relative">
          <button type="button" onClick={() => onOpen(id)} className="cursor-pointer rounded-xl bg-surface p-0.5 transition hover:scale-105" title={`#${id}`}>
            <PokeIcon id={id} />
          </button>
          {onRemove && (
            <button
              type="button"
              aria-label="Tirar"
              onClick={() => onRemove(id)}
              className="absolute -top-1.5 -right-1.5 grid h-5 w-5 cursor-pointer place-items-center rounded-full bg-red-500 text-white"
            >
              <Icon name="close" size={12} />
            </button>
          )}
        </div>
      ))}
    </div>
  )
}

export default function TradesPage() {
  const user = useAuth((s) => (s.status === 'signedIn' ? s.user : null))
  const collection = useStore((s) => s.collection)
  const list = useFriends((s) => s.list)
  const friends = useMemo(() => friendsOnly(list), [list])
  const [mine, setMine] = useState(null)
  const [theirs, setTheirs] = useState(null)
  const [picking, setPicking] = useState(false)
  const [open, setOpen] = useState(null)
  const caught = useMemo(() => allCaught(collection), [collection])
  const me = user?.uid
  const friendIds = friends.map((f) => f.uid).join(',')

  useEffect(() => {
    if (!me) return
    let stop = null
    let alive = true
    watchMyTrades(me, setMine).then((s) => (alive ? (stop = s) : s()))
    return () => {
      alive = false
      stop?.()
    }
  }, [me])

  // Os pegos ficam em dia com a Coleção.
  const caughtKey = caught.join(',')
  useEffect(() => {
    if (!me || !mine) return
    if (mine.caught.join(',') !== caughtKey) saveTrades(me, mine.dupes, caughtKey ? caughtKey.split(',').map(Number) : []).catch(() => {})
  }, [me, mine, caughtKey])

  useEffect(() => {
    friendTrades(friendIds ? friendIds.split(',') : []).then(setTheirs)
  }, [friendIds])

  if (!user) return <Empty>Entre na sua conta para trocar com os amigos.</Empty>
  const dupes = mine?.dupes ?? []
  const setDupes = (next) => saveTrades(me, [...new Set(next)].sort((a, b) => a - b), caught).catch(() => {})
  const have = new Set(caught)

  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <PageHeader title="Trocas" subtitle="Marque seus repetidos e veja o que dá para trocar com cada amigo." />
      <Link to="/amigos" className="inline-flex items-center gap-1 text-sm text-muted hover:text-text">
        <Icon name="back" size={16} /> Amigos
      </Link>

      <section className={CARD}>
        <div className="mb-1 font-bold">{`Meus repetidos (${dupes.length})`}</div>
        <p className="mb-3 text-sm text-muted">Marque os Pokémon que você tem sobrando para trocar. O que você já pegou vem da sua Coleção.</p>
        <Icons ids={dupes} onOpen={setOpen} onRemove={(id) => setDupes(dupes.filter((x) => x !== id))} />
        <Button className="mt-3" onClick={() => setPicking(true)}>
          + Adicionar repetido
        </Button>
      </section>

      {!friends.length ? (
        <Empty>Adicione amigos para ver as trocas possíveis.</Empty>
      ) : (
        friends.map((f) => {
          const t = theirs?.[f.uid]
          const theyHave = new Set(t?.caught ?? [])
          const give = dupes.filter((id) => !theyHave.has(id))
          const get = (t?.dupes ?? []).filter((id) => !have.has(id))
          return (
            <section key={f.uid} className={CARD}>
              <div className="mb-3 flex items-center gap-3">
                <Avatar pokemonId={f.avatar ?? null} name={f.name} size={38} />
                <span className="font-bold" data-no-translate>
                  {f.name}
                </span>
              </div>
              {theirs === null ? (
                <p className="text-sm text-muted">...</p>
              ) : !t ? (
                <p className="text-sm text-muted">{`${f.name} ainda não abriu as Trocas.`}</p>
              ) : (
                <div className="space-y-4">
                  <div>
                    <div className="mb-1.5 text-sm font-semibold text-green-400">{`Você pode dar (${give.length})`}</div>
                    {give.length ? <Icons ids={give} onOpen={setOpen} /> : <p className="text-sm text-muted">Nenhum dos seus repetidos falta para essa pessoa.</p>}
                  </div>
                  <div>
                    <div className="mb-1.5 text-sm font-semibold text-sky-400">{`Pode te dar (${get.length})`}</div>
                    {get.length ? <Icons ids={get} onOpen={setOpen} /> : <p className="text-sm text-muted">Nenhum repetido dessa pessoa falta para você.</p>}
                  </div>
                </div>
              )}
            </section>
          )
        })
      )}

      <PokemonModal id={open} onClose={() => setOpen(null)} />
      <PokemonPicker
        open={picking}
        onClose={() => setPicking(false)}
        onPick={(p) => {
          setDupes([...dupes, p.id])
          setPicking(false)
        }}
      />
    </div>
  )
}
