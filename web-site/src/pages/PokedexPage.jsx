import { AnimatePresence, m } from 'framer-motion'
import { useEffect, useMemo, useState } from 'react'
import { useSearch } from '../App'
import PokedexGrid from '../components/PokedexGrid'
import { Icon, Loader, PageHeader } from '../components/ui'
import { getAbilities, getMoveLearners, getMoves, getPokedex, getPokemonIndex } from '../lib/data'
import { ALL_TYPES, STAT_LABELS, capitalize, prettyName, typeColor } from '../lib/pokemon'
import GenerationPicker from '../components/GenerationPicker'
import GamePicker from '../components/GamePicker'

const FIELD = 'w-full rounded-xl bg-card px-3 py-2 outline-none focus:ring-2 focus:ring-sky-400'

/** Filtra por nome ou número (igual à busca do app). */
export function matchesSearch(p, query) {
  const q = query.trim().toLowerCase()
  // Também pelo nome no outro idioma (Bulbizarre, Bulbasaur...).
  return !q || p.name.includes(q) || String(p.id) === q || Object.values(p.names ?? {}).some((n) => n.toLowerCase().includes(q))
}

export default function PokedexPage() {
  const { search } = useSearch()
  const [pokedex, setPokedex] = useState(null)
  const [allForms, setAllForms] = useState(null)
  const [generation, setGeneration] = useState(null)
  const [game, setGame] = useState(null)
  const [types, setTypes] = useState([])
  const [showFilters, setShowFilters] = useState(false)
  const [tag, setTag] = useState(null) // 'legendary' | 'mythical' | 'baby'
  const [ability, setAbility] = useState('')
  const [move, setMove] = useState('')
  const [sort, setSort] = useState(null) // índice do status (0-5) ou 'total'
  const [learners, setLearners] = useState(null)
  const [options, setOptions] = useState({ abilities: [], moves: [] })

  useEffect(() => {
    getPokedex().then(setPokedex)
    getPokemonIndex().then(setAllForms)
  }, [])

  // Listas para os campos de habilidade e golpe (só quando os filtros abrem).
  useEffect(() => {
    if (!showFilters || options.moves.length) return
    Promise.all([getAbilities(), getMoves()]).then(([abilities, moves]) =>
      setOptions({ abilities: abilities.map((a) => a.name).sort(), moves: Object.keys(moves).sort() }),
    )
  }, [showFilters, options.moves.length])

  const moveKey = move.trim().toLowerCase().replace(/\s+/g, '-')
  const abilityKey = ability.trim().toLowerCase().replace(/\s+/g, '-')
  useEffect(() => {
    if (moveKey && !learners) getMoveLearners().then(setLearners)
  }, [moveKey, learners])
  const learnersOf = useMemo(() => (moveKey && learners?.[moveKey] ? new Set(learners[moveKey]) : null), [moveKey, learners])

  const list = useMemo(() => {
    if (!pokedex) return []
    // Com filtro de tipo ou de jogo, entram também as formas (Alola, Mega...), como no app.
    const source = types.length || game ? allForms ?? pokedex : pokedex
    const filtered = source.filter(
      (p) =>
        (!generation || p.gen === generation) &&
        (!game || p.games?.includes(game)) &&
        types.every((t) => p.types.includes(t)) &&
        (!tag || p.tag === tag) &&
        (!abilityKey || !options.abilities.includes(abilityKey) || p.abilities?.includes(abilityKey)) &&
        (!learnersOf || learnersOf.has(p.id)) &&
        matchesSearch(p, search),
    )
    if (sort === null) return filtered
    const value = (p) => (sort === 'total' ? (p.stats ?? []).reduce((a, b) => a + b, 0) : p.stats?.[sort] ?? 0)
    return [...filtered].sort((a, b) => value(b) - value(a))
  }, [pokedex, allForms, generation, game, types, tag, abilityKey, options.abilities, learnersOf, sort, search])

  // Ordenado por status: o valor aparece no card.
  const noteFor = useMemo(() => {
    if (sort === null) return undefined
    return (p) => `${sort === 'total' ? 'Total' : STAT_LABELS[sort]}: ${sort === 'total' ? (p.stats ?? []).reduce((a, b) => a + b, 0) : p.stats?.[sort]}`
  }, [sort])

  const toggleType = (type) =>
    setTypes((current) => (current.includes(type) ? current.filter((t) => t !== type) : [...current.slice(-1), type]))

  const extraFilters = [tag, abilityKey, moveKey, sort !== null].filter(Boolean).length
  const filtersActive = generation || game || types.length || extraFilters

  return (
    <div>
      <PageHeader title="Pokédex" subtitle={pokedex ? `${list.length} Pokémon` : null}>
        <div className="flex flex-wrap items-center gap-2">
          <GenerationPicker value={generation} onChange={setGeneration} />
          <GamePicker value={game} onChange={setGame} />
          <m.button
            type="button"
            whileHover={{ scale: 1.05 }}
            onClick={() => setShowFilters(!showFilters)}
            className={`flex cursor-pointer items-center gap-1 rounded-full px-4 py-2 text-sm font-semibold ring-1 ring-line ${types.length || extraFilters ? 'bg-sky-600 text-white' : 'bg-surface'}`}
          >
            <Icon name="filter" size={18} />
            {`Filtros${types.length ? `: ${types.map(capitalize).join(' + ')}` : ''}${extraFilters ? ` (+${extraFilters})` : ''}`}
          </m.button>
          {filtersActive ? (
            <button
              type="button"
              onClick={() => {
                setGeneration(null)
                setGame(null)
                setTypes([])
                setTag(null)
                setAbility('')
                setMove('')
                setSort(null)
              }}
              className="cursor-pointer text-sm text-muted underline hover:text-text"
            >
              Limpar filtros
            </button>
          ) : null}
        </div>
      </PageHeader>

      <AnimatePresence>
        {showFilters && (
          <m.div initial={{ height: 0, opacity: 0 }} animate={{ height: 'auto', opacity: 1 }} exit={{ height: 0, opacity: 0 }} className="overflow-hidden">
            <div className="mb-5 rounded-2xl bg-surface p-4">
              <p className="mb-3 text-sm text-muted">Tipos (até dois)</p>
              <div className="grid grid-cols-3 gap-2 sm:grid-cols-6 lg:grid-cols-9">
                {ALL_TYPES.map((type) => {
                  const active = types.includes(type)
                  return (
                    <m.button
                      key={type}
                      type="button"
                      whileHover={{ scale: 1.06 }}
                      whileTap={{ scale: 0.95 }}
                      onClick={() => toggleType(type)}
                      className="cursor-pointer rounded-xl py-2 text-sm font-bold text-white"
                      style={{ background: typeColor(type), opacity: types.length && !active ? 0.45 : 1, outline: active ? '3px solid white' : 'none' }}
                    >
                      {capitalize(type)}
                    </m.button>
                  )
                })}
              </div>

              <div className="mt-5 grid gap-4 md:grid-cols-2 xl:grid-cols-4">
                <label className="block text-sm">
                  <span className="mb-1 block text-muted">Categoria</span>
                  <select value={tag ?? ''} onChange={(e) => setTag(e.target.value || null)} className={FIELD}>
                    <option value="">Todos</option>
                    <option value="legendary">Lendários</option>
                    <option value="mythical">Míticos</option>
                    <option value="baby">Bebês</option>
                  </select>
                </label>
                <label className="block text-sm">
                  <span className="mb-1 block text-muted">Habilidade</span>
                  <input list="pokedex-abilities" value={ability} onChange={(e) => setAbility(e.target.value)} placeholder="Ex.: Intimidate" className={FIELD} />
                  <datalist id="pokedex-abilities">
                    {options.abilities.map((a) => (
                      <option key={a} value={prettyName(a)} />
                    ))}
                  </datalist>
                </label>
                <label className="block text-sm">
                  <span className="mb-1 block text-muted">Aprende o golpe</span>
                  <input list="pokedex-moves" value={move} onChange={(e) => setMove(e.target.value)} placeholder="Ex.: Earthquake" className={FIELD} />
                  <datalist id="pokedex-moves">
                    {options.moves.map((mv) => (
                      <option key={mv} value={prettyName(mv)} />
                    ))}
                  </datalist>
                </label>
                <label className="block text-sm">
                  <span className="mb-1 block text-muted">Ordenar por</span>
                  <select
                    value={sort ?? ''}
                    onChange={(e) => setSort(e.target.value === '' ? null : e.target.value === 'total' ? 'total' : Number(e.target.value))}
                    className={FIELD}
                  >
                    <option value="">Número da Pokédex</option>
                    <option value="total">Total dos status (maior)</option>
                    {STAT_LABELS.map((label, i) => (
                      <option key={label} value={i}>
                        {`${label} (maior)`}
                      </option>
                    ))}
                  </select>
                </label>
              </div>
            </div>
          </m.div>
        )}
      </AnimatePresence>

      {pokedex ? <PokedexGrid pokemon={list} noteFor={noteFor} /> : <Loader />}
    </div>
  )
}
