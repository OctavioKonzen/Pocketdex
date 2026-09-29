// Pista do jogo "Quem é esse Pokémon?" nos modos Grito, Descrição e Tipos.

import { useEffect, useRef, useState } from 'react'
import { cryUrl, getSpecies } from '../lib/data'
import { pick } from '../lib/i18n'
import { TypeBadge } from './ui'

/** Tira o nome do Pokémon da descrição (para não entregar a resposta). */
function hideName(text, names) {
  let out = text
  for (const name of names.filter(Boolean)) {
    out = out.replace(new RegExp(name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'gi'), '???')
  }
  return out
}

export default function GameClue({ pokemon, hint }) {
  const [species, setSpecies] = useState(null)
  const audio = useRef(null)

  useEffect(() => {
    let alive = true
    setSpecies(null)
    if (hint === 'description' || hint === 'types') getSpecies(pokemon.species ?? pokemon.id).then((s) => alive && setSpecies(s)).catch(() => {})
    return () => {
      alive = false
    }
  }, [pokemon, hint])

  const play = () => {
    audio.current?.pause()
    audio.current = new Audio(cryUrl(pokemon.species ?? pokemon.id))
    audio.current.volume = 0.7
    audio.current.play().catch(() => {})
  }
  // O grito toca sozinho a cada Pokémon novo.
  useEffect(() => {
    if (hint !== 'cry') return
    play()
    return () => audio.current?.pause()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [pokemon, hint])

  if (hint === 'cry') {
    return (
      <button type="button" onClick={play} className="relative z-10 grid h-40 w-40 cursor-pointer place-items-center rounded-full bg-white/90 text-7xl shadow-2xl transition hover:scale-105 sm:h-56 sm:w-56">
        🔊
      </button>
    )
  }
  if (!species) return <div className="relative z-10 text-2xl font-bold text-white">...</div>
  if (hint === 'types') {
    return (
      <div className="relative z-10 flex flex-col items-center gap-4 rounded-3xl bg-black/35 p-8 text-white">
        <div className="flex gap-3">
          {pokemon.types.map((t) => (
            <TypeBadge key={t} type={t} />
          ))}
        </div>
        <div className="text-xl font-bold">{`Pokémon ${pick(species.genus, species.genera)}`}</div>
      </div>
    )
  }
  const names = [species.name, species.name.replace(/-/g, ' '), ...Object.values(species.names ?? {})]
  return (
    <p className="relative z-10 max-w-xl rounded-3xl bg-black/35 p-8 text-center text-xl leading-relaxed font-semibold text-white sm:text-2xl" data-no-translate>
      {hideName(pick(species.flavor, species.flavors), names)}
    </p>
  )
}
