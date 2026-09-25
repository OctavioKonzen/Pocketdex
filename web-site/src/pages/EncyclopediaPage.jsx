import { motion } from 'framer-motion'
import { useEffect, useMemo, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import DetailsPanel from '../components/DetailsPanel'
import { AbilityModal, CategoryIcon, ItemModal, MoveModal } from '../components/EntryModals'
import { Icon, Loader, Modal, PageHeader, SearchInput, TypeBadge } from '../components/ui'
import { getAbilities, getItems, getMoves, spriteUrl } from '../lib/data'
import { ALL_TYPES, capitalize, prettyName } from '../lib/pokemon'

const TABS = [
  { key: 'golpes', label: 'Golpes', color: '#FFA726' },
  { key: 'habilidades', label: 'Habilidades', color: '#42A5F5' },
  { key: 'itens', label: 'Itens', color: '#8D6E63' },
]

const PAGE = 150

export default function EncyclopediaPage() {
  const { tab = 'golpes' } = useParams()
  const navigate = useNavigate()
  const [query, setQuery] = useState('')
  const [pokemonOpen, setPokemonOpen] = useState(null)

  useEffect(() => setQuery(''), [tab])

  return (
    <div>
      <PageHeader title="Enciclopédia" subtitle="Todos os golpes, habilidades e itens do banco de dados." />
      <div className="mb-5 flex flex-wrap items-center gap-3">
        {TABS.map((t) => (
          <motion.button
            key={t.key}
            type="button"
            whileHover={{ scale: 1.06 }}
            onClick={() => navigate(`/enciclopedia/${t.key}`)}
            className="cursor-pointer rounded-full px-5 py-2 font-bold"
            animate={{ backgroundColor: tab === t.key ? t.color : 'var(--surface)', color: tab === t.key ? '#fff' : 'var(--text)' }}
          >
            {t.label}
          </motion.button>
        ))}
        <SearchInput value={query} onChange={setQuery} placeholder={`Procurar ${TABS.find((t) => t.key === tab)?.label.toLowerCase() ?? ''}`} className="min-w-[240px] flex-1" />
      </div>

      {tab === 'golpes' && <MovesList query={query} onPokemon={setPokemonOpen} />}
      {tab === 'habilidades' && <AbilitiesList query={query} onPokemon={setPokemonOpen} />}
      {tab === 'itens' && <ItemsList query={query} />}

      <Modal open={Boolean(pokemonOpen)} onClose={() => setPokemonOpen(null)} title="Pokémon" wide>
        {pokemonOpen && <DetailsPanel speciesId={pokemonOpen} compact onNavigate={setPokemonOpen} />}
      </Modal>
    </div>
  )
}

const matches = (name, query) => name.replace(/-/g, ' ').includes(query.trim().toLowerCase())

function useLimited(list) {
  const [limit, setLimit] = useState(PAGE)
  useEffect(() => setLimit(PAGE), [list])
  const more =
    list.length > limit ? (
      <button type="button" onClick={() => setLimit(limit + PAGE)} className="mt-4 w-full cursor-pointer rounded-xl bg-surface py-3 font-semibold hover:bg-white/10">
        Mostrar mais ({list.length - limit})
      </button>
    ) : null
  return [list.slice(0, limit), more]
}

function ListRow({ onClick, children }) {
  return (
    <motion.button type="button" onClick={onClick} whileHover={{ scale: 1.015 }} className="flex w-full cursor-pointer items-center gap-3 rounded-2xl bg-card px-4 py-3 text-left shadow-sm">
      {children}
      <Icon name="right" className="ml-auto shrink-0 text-muted" />
    </motion.button>
  )
}

function MovesList({ query, onPokemon }) {
  const [moves, setMoves] = useState(null)
  const [type, setType] = useState('')
  const [open, setOpen] = useState(null)
  useEffect(() => {
    getMoves().then((m) => setMoves(Object.values(m)))
  }, [])
  const list = useMemo(() => (moves ?? []).filter((m) => matches(m.name, query) && (!type || m.type === type)), [moves, query, type])
  const [shown, more] = useLimited(list)
  if (!moves) return <Loader />
  return (
    <>
      <select value={type} onChange={(e) => setType(e.target.value)} className="mb-4 cursor-pointer rounded-full bg-surface px-4 py-2 text-sm font-semibold ring-1 ring-line outline-none">
        <option value="">Todos os tipos</option>
        {ALL_TYPES.map((t) => (
          <option key={t} value={t}>
            {capitalize(t)}
          </option>
        ))}
      </select>
      <div className="grid gap-2 md:grid-cols-2 xl:grid-cols-3">
        {shown.map((m) => (
          <ListRow key={m.name} onClick={() => setOpen(m.name)}>
            <div className="min-w-0">
              <div className="truncate font-bold">{prettyName(m.name)}</div>
              <div className="mt-1 flex items-center gap-2">
                <TypeBadge type={m.type} small />
                <CategoryIcon category={m.category} />
                <span className="text-xs text-muted">
                  {m.power ? `Poder ${m.power}` : ''} {m.accuracy ? `· Precisão ${m.accuracy}` : ''}
                </span>
              </div>
            </div>
          </ListRow>
        ))}
      </div>
      {more}
      <MoveModal name={open} onClose={() => setOpen(null)} onSelectPokemon={(p) => (setOpen(null), onPokemon(p.species))} />
    </>
  )
}

function AbilitiesList({ query, onPokemon }) {
  const [abilities, setAbilities] = useState(null)
  const [open, setOpen] = useState(null)
  useEffect(() => {
    getAbilities().then(setAbilities)
  }, [])
  const list = useMemo(() => (abilities ?? []).filter((a) => matches(a.name, query)), [abilities, query])
  const [shown, more] = useLimited(list)
  if (!abilities) return <Loader />
  return (
    <>
      <div className="grid gap-2 md:grid-cols-2 xl:grid-cols-3">
        {shown.map((a) => (
          <ListRow key={a.name} onClick={() => setOpen(a.name)}>
            <div className="min-w-0">
              <div className="font-bold">{prettyName(a.name)}</div>
              <div className="truncate text-xs text-muted">{a.effect}</div>
            </div>
          </ListRow>
        ))}
      </div>
      {more}
      <AbilityModal name={open} onClose={() => setOpen(null)} onSelectPokemon={(p) => (setOpen(null), onPokemon(p.species))} />
    </>
  )
}

function ItemsList({ query }) {
  const [items, setItems] = useState(null)
  const [open, setOpen] = useState(null)
  useEffect(() => {
    getItems().then(setItems)
  }, [])
  const list = useMemo(() => (items ?? []).filter((i) => matches(i.name, query)), [items, query])
  const [shown, more] = useLimited(list)
  if (!items) return <Loader />
  return (
    <>
      <div className="grid gap-2 md:grid-cols-2 xl:grid-cols-3">
        {shown.map((item) => (
          <ListRow key={item.id} onClick={() => setOpen(item)}>
            <div className="grid h-10 w-10 shrink-0 place-items-center">
              {item.sprite ? <img src={spriteUrl(item.sprite)} alt="" loading="lazy" className="pixelated h-10 w-10" /> : <Icon name="status" className="text-muted" />}
            </div>
            <div className="min-w-0">
              <div className="truncate font-bold">{prettyName(item.name)}</div>
              <div className="text-xs text-muted">{prettyName(item.category)}</div>
            </div>
          </ListRow>
        ))}
      </div>
      {more}
      <ItemModal item={open} onClose={() => setOpen(null)} />
    </>
  )
}
