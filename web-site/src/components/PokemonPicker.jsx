// Janela para escolher um Pokémon (times, treino de EVs, breeding).

import { useEffect, useMemo, useState } from 'react'
import { getPokedex, spriteUrl } from '../lib/data'
import { displayName, typeColor } from '../lib/pokemon'
import { matchesSearch } from '../pages/PokedexPage'
import { Loader, Modal, SearchInput } from './ui'

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
          <div className="grid grid-cols-[repeat(auto-fill,minmax(110px,1fr))] gap-3">
            {list.slice(0, limit).map((p) => (
              <button
                key={p.id}
                type="button"
                onClick={() => onPick(p)}
                className="flex cursor-pointer flex-col items-center rounded-2xl p-2 text-white transition hover:scale-105"
                style={{ background: typeColor(p.types[0]) }}
              >
                <img src={spriteUrl(p.sprite)} alt="" loading="lazy" className="pixelated h-20 w-20" />
                <span className="w-full truncate text-center text-xs font-bold">{displayName(p.name)}</span>
                <span className="text-[10px] opacity-80">#{p.id}</span>
              </button>
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
