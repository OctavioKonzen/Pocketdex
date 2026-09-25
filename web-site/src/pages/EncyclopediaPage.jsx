import { m } from 'framer-motion'
import { useEffect, useMemo, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { AbilityDetails, CategoryIcon, ItemDetails, MoveDetails } from '../components/EntryModals'
import ExpandableList from '../components/ExpandableList'
import { Icon, Loader, PageHeader, SearchInput, TypeBadge } from '../components/ui'
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

  useEffect(() => setQuery(''), [tab])

  return (
    <div>
      <PageHeader title="Enciclopédia" subtitle="Todos os golpes, habilidades e itens do banco de dados." />
      <div className="mb-5 flex flex-wrap items-center gap-3">
        {TABS.map((t) => (
          <m.button
            key={t.key}
            type="button"
            whileHover={{ scale: 1.06 }}
            onClick={() => navigate(`/enciclopedia/${t.key}`)}
            className="cursor-pointer rounded-full px-5 py-2 font-bold"
            animate={{ backgroundColor: tab === t.key ? t.color : 'var(--surface)', color: tab === t.key ? '#fff' : 'var(--text)' }}
          >
            {t.label}
          </m.button>
        ))}
        <SearchInput value={query} onChange={setQuery} placeholder={`Procurar ${TABS.find((t) => t.key === tab)?.label.toLowerCase() ?? ''}`} className="min-w-[240px] flex-1" />
      </div>

      {/* Clicar em um item abre os detalhes logo abaixo dele, empurrando os outros. */}
      {tab === 'golpes' && <MovesList query={query} />}
      {tab === 'habilidades' && <AbilitiesList query={query} />}
      {tab === 'itens' && <ItemsList query={query} />}
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
  return [useMemo(() => list.slice(0, limit), [list, limit]), more]
}

// Funções fixas (fora dos componentes) para as linhas da lista não serem
// redesenhadas à toa.
const byName = (entry) => entry.name
const titleOf = (entry) => prettyName(entry.name)

const renderMove = (m) => (
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
)
const renderMoveDetails = (m) => <MoveDetails key={m.name} name={m.name} inline />

const renderAbility = (a) => (
  <div className="min-w-0">
    <div className="font-bold">{prettyName(a.name)}</div>
    <div className="truncate text-xs text-muted">{a.effect}</div>
  </div>
)
const renderAbilityDetails = (a) => <AbilityDetails key={a.name} name={a.name} inline />

const itemKey = (item) => item.id
const renderItem = (item) => (
  <>
    <div className="grid h-10 w-10 shrink-0 place-items-center">
      {item.sprite ? <img src={spriteUrl(item.sprite)} alt="" loading="lazy" className="pixelated h-10 w-10" /> : <Icon name="status" className="text-muted" />}
    </div>
    <div className="min-w-0">
      <div className="truncate font-bold">{prettyName(item.name)}</div>
      <div className="text-xs text-muted">{prettyName(item.category)}</div>
    </div>
  </>
)
const renderItemDetails = (item) => <ItemDetails item={item} />

function MovesList({ query }) {
  const [moves, setMoves] = useState(null)
  const [type, setType] = useState('')
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
      <ExpandableList items={shown} getKey={byName} getTitle={titleOf} renderItem={renderMove} renderDetails={renderMoveDetails} accent="#FFA726" />
      {more}
    </>
  )
}

function AbilitiesList({ query }) {
  const [abilities, setAbilities] = useState(null)
  useEffect(() => {
    getAbilities().then(setAbilities)
  }, [])
  const list = useMemo(() => (abilities ?? []).filter((a) => matches(a.name, query)), [abilities, query])
  const [shown, more] = useLimited(list)
  if (!abilities) return <Loader />
  return (
    <>
      <ExpandableList items={shown} getKey={byName} getTitle={titleOf} renderItem={renderAbility} renderDetails={renderAbilityDetails} accent="#42A5F5" />
      {more}
    </>
  )
}

function ItemsList({ query }) {
  const [items, setItems] = useState(null)
  useEffect(() => {
    getItems().then(setItems)
  }, [])
  const list = useMemo(() => (items ?? []).filter((i) => matches(i.name, query)), [items, query])
  const [shown, more] = useLimited(list)
  if (!items) return <Loader />
  return (
    <>
      <ExpandableList items={shown} getKey={itemKey} getTitle={titleOf} renderItem={renderItem} renderDetails={renderItemDetails} accent="#8D6E63" />
      {more}
    </>
  )
}
