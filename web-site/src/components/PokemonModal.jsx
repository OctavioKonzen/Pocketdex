// Página de um Pokémon por cima da tela (trocas, chat...). id pode ser de uma forma.

import { useEffect, useState } from 'react'
import DetailsPanel from './DetailsPanel'
import { usePokemonIndex } from '../lib/pokemonIndex'

export default function PokemonModal({ id, onClose }) {
  if (id == null) return null
  return <Modal key={id} id={id} onClose={onClose} />
}

function Modal({ id, onClose }) {
  const byId = usePokemonIndex()
  const [picked, setPicked] = useState(null) // outro Pokémon aberto pela evolução
  const speciesId = picked ?? byId?.get(id)?.species ?? (byId ? id : null)
  const [wide, setWide] = useState(() => window.innerWidth >= 900)
  useEffect(() => {
    const onResize = () => setWide(window.innerWidth >= 900)
    window.addEventListener('resize', onResize)
    return () => window.removeEventListener('resize', onResize)
  }, [])
  useEffect(() => {
    const onKey = (e) => e.key === 'Escape' && onClose()
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onClose])
  if (speciesId == null) return null
  return (
    <div className="fixed inset-0 z-50 grid place-items-center overflow-y-auto bg-black/60 p-3" onClick={onClose}>
      <div className="w-full max-w-5xl" onClick={(e) => e.stopPropagation()}>
        <DetailsPanel speciesId={speciesId} compact={!wide} height={wide ? 620 : 560} onClose={onClose} onNavigate={setPicked} />
      </div>
    </div>
  )
}
