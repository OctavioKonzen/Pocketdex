// Pokémon do dia (igual ao app, daily_pokemon_card.dart): um card no topo da
// Pokédex com o Pokémon de hoje, uma curiosidade e o grito.

import { useEffect, useState } from 'react'
import { cryUrl, getSpecies } from '../lib/data'
import { dailyPokemonId } from '../lib/dailyPokemon'
import { pick } from '../lib/i18n'
import { usePokemonIndex } from '../lib/pokemonIndex'
import { prettyName, typeBackground } from '../lib/pokemon'
import PokeIcon from './PokeIcon'
import PokemonModal from './PokemonModal'
import { Icon } from './ui'

export default function DailyPokemonCard() {
  const id = dailyPokemonId()
  const byId = usePokemonIndex()
  const [species, setSpecies] = useState(null)
  const [open, setOpen] = useState(false)
  useEffect(() => {
    getSpecies(id)
      .then(setSpecies)
      .catch(() => {})
  }, [id])
  const p = byId?.get(id)
  if (!p) return null
  const play = (e) => {
    e.stopPropagation()
    const audio = new Audio(cryUrl(id))
    audio.volume = 0.6
    audio.play().catch(() => {})
  }
  return (
    <>
      <div
        role="button"
        tabIndex={0}
        onClick={() => setOpen(true)}
        onKeyDown={(e) => e.key === 'Enter' && setOpen(true)}
        className="mb-5 flex cursor-pointer items-center gap-3 rounded-2xl p-3 text-white shadow transition hover:scale-[1.005]"
        style={{ background: typeBackground(p.types) }}
      >
        <PokeIcon id={id} className="h-20 w-20" fill={0.95} />
        <div className="min-w-0 flex-1">
          <div className="text-xs font-bold opacity-90">⭐ Pokémon do dia</div>
          <div className="text-xl font-black drop-shadow">{`${prettyName(p.name.split('-')[0])} #${String(id).padStart(3, '0')}`}</div>
          {species && (
            <p className="line-clamp-2 text-sm opacity-95" data-no-translate>
              {pick(species.flavor, species.flavors)}
            </p>
          )}
        </div>
        <button type="button" onClick={play} aria-label="Ouvir o grito" title="Ouvir o grito" className="grid h-11 w-11 shrink-0 cursor-pointer place-items-center rounded-full bg-white/20 hover:bg-white/30">
          <Icon name="volume" />
        </button>
      </div>
      <PokemonModal id={open ? id : null} onClose={() => setOpen(false)} />
    </>
  )
}
