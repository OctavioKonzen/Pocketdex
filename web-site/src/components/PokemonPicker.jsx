// Janela para escolher um Pokémon (times, treino de EVs, breeding, foto de perfil).

import { useEffect, useMemo, useState } from 'react'
import { getPokedex, getPokemonIndex, shinyPath } from '../lib/data'
import { matchesSearch } from '../pages/PokedexPage'
import { Loader, Modal, SearchInput } from './ui'
import PokemonCard from './PokemonCard'

const PAGE = 120

/**
 * @param extras true: botões de shiny e de formas alternativas (Mega, regionais...);
 *               onPick recebe (pokémon, { shiny }).
 */
export default function PokemonPicker({ open, onClose, onPick, title = 'Selecione um Pokémon', extras = false }) {
  const [pokedex, setPokedex] = useState(null)
  const [query, setQuery] = useState('')
  const [limit, setLimit] = useState(PAGE)
  const [shiny, setShiny] = useState(false)
  const [forms, setForms] = useState(false)

  useEffect(() => {
    if (open) {
      ;(extras && forms ? getPokemonIndex().then((all) => [...all].sort((a, b) => a.species - b.species || b.default - a.default || a.id - b.id)) : getPokedex()).then(setPokedex)
      setQuery('')
      setLimit(PAGE)
    }
  }, [open, extras, forms])

  const list = useMemo(() => (pokedex ?? []).filter((p) => matchesSearch(p, query)), [pokedex, query])
  const toggle = (on) => `cursor-pointer rounded-full px-4 py-2 text-sm font-bold ${on ? 'bg-amber-400 text-slate-900' : 'bg-surface text-muted hover:text-text'}`

  return (
    <Modal open={open} onClose={onClose} title={title} wide>
      <SearchInput value={query} onChange={setQuery} placeholder="Procurar por nome ou número" autoFocus className="mb-4" />
      {extras && (
        <div className="mb-4 flex flex-wrap gap-2">
          <button type="button" aria-pressed={shiny} onClick={() => setShiny(!shiny)} className={toggle(shiny)}>
            ✨ Shiny
          </button>
          <button type="button" aria-pressed={forms} onClick={() => setForms(!forms)} className={toggle(forms)}>
            Formas alternativas
          </button>
        </div>
      )}
      {!pokedex ? (
        <Loader />
      ) : (
        <>
          <div className="grid grid-cols-[repeat(auto-fill,minmax(190px,1fr))] gap-4">
            {list.slice(0, limit).map((p) => (
              <PokemonCard key={p.id} pokemon={shiny ? { ...p, sprite: shinyPath(p.sprite), box: null } : p} onClick={() => onPick(p, { shiny })} />
            ))}
          </div>
          {list.length > limit && (
            <button type="button" onClick={() => setLimit(limit + PAGE)} className="mt-4 w-full cursor-pointer rounded-xl bg-surface py-3 font-semibold hover:bg-white/10">
              {`Mostrar mais (${list.length - limit})`}
            </button>
          )}
        </>
      )}
    </Modal>
  )
}
