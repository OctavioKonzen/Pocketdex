// Sprite de um Pokémon pelo id (usa o índice do banco local).

import { shinyPath } from '../lib/data'
import { usePokemonIndex } from '../lib/pokemonIndex'
import Sprite from './Sprite'

// variant: a forma do sprite (a letra do Unown, o padrão do Vivillon): pokemon/201.png → pokemon/201-b.png.
export default function PokeIcon({ id, shiny = false, className = 'h-12 w-12', fill = 0.9, align, lite = false, variant = '' }) {
  const byId = usePokemonIndex()
  const p = byId?.get(id)
  const path = p ? (shiny ? shinyPath(p.sprite) : p.sprite).replace(/\.png$/, variant ? `-${variant}.png` : '.png') : ''
  return <div className={`shrink-0 ${className}`}>{p && <Sprite key={path} path={path} box={p.box} fill={fill} align={align} alt={p.name} lite={lite} />}</div>
}
