import { AnimatePresence, m } from 'framer-motion'
import { useEffect, useMemo, useState } from 'react'
import { useSearch } from '../App'
import PokedexGrid from '../components/PokedexGrid'
import { Icon, Loader, PageHeader } from '../components/ui'
import { getPokedex, getPokemonIndex } from '../lib/data'
import { ALL_TYPES, capitalize, typeColor } from '../lib/pokemon'
import GenerationPicker from '../components/GenerationPicker'

/** Filtra por nome ou número (igual à busca do app). */
export function matchesSearch(p, query) {
  const q = query.trim().toLowerCase()
  return !q || p.name.includes(q) || String(p.id) === q
}

export default function PokedexPage() {
  const { search } = useSearch()
  const [pokedex, setPokedex] = useState(null)
  const [allForms, setAllForms] = useState(null)
  const [generation, setGeneration] = useState(null)
  const [types, setTypes] = useState([])
  const [showFilters, setShowFilters] = useState(false)

  useEffect(() => {
    getPokedex().then(setPokedex)
    getPokemonIndex().then(setAllForms)
  }, [])

  const list = useMemo(() => {
    if (!pokedex) return []
    // Com filtro de tipo, entram também as formas (Alola, Mega...), como no app.
    const source = types.length ? allForms ?? pokedex : pokedex
    return source.filter(
      (p) =>
        (!generation || p.gen === generation) &&
        types.every((t) => p.types.includes(t)) &&
        matchesSearch(p, search),
    )
  }, [pokedex, allForms, generation, types, search])

  const toggleType = (type) =>
    setTypes((current) => (current.includes(type) ? current.filter((t) => t !== type) : [...current.slice(-1), type]))

  const filtersActive = generation || types.length

  return (
    <div>
      <PageHeader title="Pokédex" subtitle={pokedex ? `${list.length} Pokémon` : null}>
        <div className="flex flex-wrap items-center gap-2">
          <GenerationPicker value={generation} onChange={setGeneration} />
          <m.button
            type="button"
            whileHover={{ scale: 1.05 }}
            onClick={() => setShowFilters(!showFilters)}
            className={`flex cursor-pointer items-center gap-1 rounded-full px-4 py-2 text-sm font-semibold ring-1 ring-line ${types.length ? 'bg-sky-600 text-white' : 'bg-surface'}`}
          >
            <Icon name="filter" size={18} />
            Tipos{types.length ? `: ${types.map(capitalize).join(' + ')}` : ''}
          </m.button>
          {filtersActive ? (
            <button
              type="button"
              onClick={() => {
                setGeneration(null)
                setTypes([])
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
              <p className="mb-3 text-sm text-muted">Selecione até dois tipos</p>
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
            </div>
          </m.div>
        )}
      </AnimatePresence>

      {pokedex ? <PokedexGrid pokemon={list} /> : <Loader />}
    </div>
  )
}
