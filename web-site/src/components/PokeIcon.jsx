// Sprite de um Pokémon pelo id (usa o índice do banco local).

import { shinyPath } from '../lib/data'
import { usePokemonIndex } from '../lib/pokemonIndex'
import Sprite from './Sprite'

export default function PokeIcon({ id, shiny = false, className = 'h-12 w-12', fill = 0.9 }) {
  const byId = usePokemonIndex()
  const p = byId?.get(id)
  return <div className={`shrink-0 ${className}`}>{p && <Sprite path={shiny ? shinyPath(p.sprite) : p.sprite} box={p.box} fill={fill} alt={p.name} />}</div>
}
