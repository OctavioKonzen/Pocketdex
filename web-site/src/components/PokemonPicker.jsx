// Janela para escolher um Pokémon (times, treino de EVs, breeding).

import { useEffect, useMemo, useState } from 'react'
import { getPokedex } from '../lib/data'
import { matchesSearch } from '../pages/PokedexPage'
import { Loader, Modal, SearchInput } from './ui'
import PokemonCard from './PokemonCard'

const PAGE = 120

export default function PokemonPicker({ open, onClose, onPick, title = 'Selecione um Pokémon' }) {
  const [pokedex, setPokedex] = useState(null)
  const [query, setQuery] = useState('')
  const [limit, setLimit] = useState(PAGE)

  useEffect(() => {
    if (open) {
      getPokedex().then(setPokedex)
      setQuery('')
      setLimit(PAGE)
    }
  }, [open])

  const list = useMemo(() => (pokedex ?? []).filter((p) => matchesSearch(p, query)), [pokedex, query])

  return (
    <Modal open={open} onClose={onClose} title={title} wide>
      <SearchInput value={query} onChange={setQuery} placeholder="Procurar por nome ou número" autoFocus className="mb-4" />
      {!pokedex ? (
        <Loader />
      ) : (
        <>
          <div className="grid grid-cols-[repeat(auto-fill,minmax(190px,1fr))] gap-4">
            {list.slice(0, limit).map((p) => (
              <PokemonCard key={p.id} pokemon={p} onClick={() => onPick(p)} />
            ))}
          </div>
          {list.length > limit && (
            <button type="button" onClick={() => setLimit(limit + PAGE)} className="mt-4 w-full cursor-pointer rounded-xl bg-surface py-3 font-semibold hover:bg-white/10">
              Mostrar mais ({list.length - limit})
            </button>
          )}
        </>
      )}
    </Modal>
  )
}
