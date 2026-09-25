// Card de Pokémon (Pokédex e todas as telas que mostram Pokémon).
//
// Para mudar o visual do card, edite CARD_STYLE logo abaixo.
//
// Desempenho: o card aparece centenas de vezes na tela, então as animações
// (hover, sumir ao abrir, estrela ao favoritar) são feitas em CSS e o card é
// memorizado (memo) — só é redesenhado quando algo dele muda.

import { memo, useRef, useState } from 'react'
import { prefetchSpecies } from '../lib/data'
import { displayName, typeBackground, typeColor } from '../lib/pokemon'
import { useStore } from '../lib/store'
import Sprite from './Sprite'
import { Icon, SpinningPokeball } from './ui'

export const CARD_STYLE = {
  height: 132, // altura do card (px)
  radius: 18, // cantos arredondados
  spriteSize: 104, // caixa do Pokémon (todos ocupam o mesmo espaço nela)
  spriteRight: 6, // distância da borda direita
  spriteBottom: 6, // distância da borda de baixo
  pokeballSize: 118, // Pokébola girando atrás
}

/**
 * @param onClick  recebe o Pokémon clicado
 * @param note     etiqueta extra no card (ex.: "oculta" para habilidade oculta)
 */
function PokemonCard({ pokemon, onClick, hidden = false, note }) {
  const isFavorite = useStore((s) => s.favorites.includes(pokemon.id))
  const toggleFavorite = useStore((s) => s.toggleFavorite)
  const clickTimer = useRef(null)
  const [pop, setPop] = useState(0)

  // Pokébola centralizada atrás do Pokémon.
  const ballRight = CARD_STYLE.spriteRight + (CARD_STYLE.spriteSize - CARD_STYLE.pokeballSize) / 2
  const ballBottom = CARD_STYLE.spriteBottom + (CARD_STYLE.spriteSize - CARD_STYLE.pokeballSize) / 2

  // Espera um instante para saber se é clique simples (abrir) ou duplo (favoritar).
  const handleClick = () => {
    clearTimeout(clickTimer.current)
    clickTimer.current = setTimeout(() => onClick?.(pokemon), 220)
  }
  const handleDoubleClick = () => {
    clearTimeout(clickTimer.current)
    toggleFavorite(pokemon.id)
    setPop((n) => n + 1)
  }

  return (
    <button
      type="button"
      onClick={handleClick}
      onDoubleClick={handleDoubleClick}
      onMouseEnter={() => prefetchSpecies(pokemon.species)}
      title="Clique para ver detalhes · clique duplo para favoritar"
      className={`pokemon-card group relative w-full cursor-pointer overflow-hidden text-left ${hidden ? 'is-hidden' : ''}`}
      style={{ height: CARD_STYLE.height, borderRadius: CARD_STYLE.radius, background: typeBackground(pokemon.types) }}
    >
      <SpinningPokeball size={CARD_STYLE.pokeballSize} opacity={0.22} className="absolute" style={{ right: ballRight, bottom: ballBottom }} />
      {pokemon.sprite && (
        <div
          className="pokemon-card-sprite absolute origin-bottom"
          style={{ width: CARD_STYLE.spriteSize, right: CARD_STYLE.spriteRight, bottom: CARD_STYLE.spriteBottom }}
        >
          <Sprite path={pokemon.sprite} box={pokemon.box} align="bottom" fill={0.92} />
        </div>
      )}
      <div className="absolute top-3.5 right-3 flex items-center gap-1 text-xs font-extrabold text-black/35">
        {isFavorite && <Icon name="star" size={16} className="text-yellow-300" />}#{pokemon.id}
      </div>
      {pop > 0 && (
        <div key={pop} className="favorite-pop pointer-events-none absolute inset-0 grid place-items-center text-yellow-300">
          <Icon name={isFavorite ? 'star' : 'starOutline'} size={48} />
        </div>
      )}
      <div className="relative p-4 pt-3.5">
        <div className="truncate pr-10 text-[16px] font-bold text-white drop-shadow">{displayName(pokemon.name)}</div>
        <div className="mt-2 flex flex-col items-start gap-1.5">
          {pokemon.types.map((type) => (
            <span
              key={type}
              className="rounded-xl px-2.5 py-0.5 text-[11px] font-semibold text-white shadow-sm ring-1 ring-white/60"
              style={{ background: typeColor(type) }}
            >
              {type}
            </span>
          ))}
          {note && <span className="rounded-xl bg-black/30 px-2.5 py-0.5 text-[11px] font-semibold text-white">{note}</span>}
        </div>
      </div>
    </button>
  )
}

export default memo(PokemonCard)
