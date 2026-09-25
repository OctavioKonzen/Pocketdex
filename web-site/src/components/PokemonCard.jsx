// Card de Pokémon da Pokédex.
//
// Para mudar o visual do card, edite CARD_STYLE logo abaixo.

import { AnimatePresence, motion } from 'framer-motion'
import { useRef, useState } from 'react'
import { prefetchSpecies } from '../lib/data'
import Sprite from './Sprite'
import { displayName, typeBackground, typeColor } from '../lib/pokemon'
import { useStore } from '../lib/store'
import { Icon, SpinningPokeball } from './ui'

export const CARD_STYLE = {
  height: 132, // altura do card (px)
  radius: 18, // cantos arredondados
  spriteSize: 104, // caixa do Pokémon (todos ocupam o mesmo espaço nela)
  spriteRight: 6, // distância da borda direita
  spriteBottom: 6, // distância da borda de baixo
  pokeballSize: 118, // Pokébola girando atrás
  hoverScale: 1.05, // card ao passar o mouse
  hoverSpriteScale: 1.15, // Pokémon ao passar o mouse
}

/** @param note  etiqueta extra no card (ex.: "oculta" para habilidade oculta) */
export default function PokemonCard({ pokemon, onClick, hidden = false, selected = false, note }) {
  const isFavorite = useStore((s) => s.favorites.includes(pokemon.id))
  const toggleFavorite = useStore((s) => s.toggleFavorite)
  const background = typeBackground(pokemon.types)
  // Pokébola centralizada atrás do Pokémon.
  const ballRight = CARD_STYLE.spriteRight + (CARD_STYLE.spriteSize - CARD_STYLE.pokeballSize) / 2
  const ballBottom = CARD_STYLE.spriteBottom + (CARD_STYLE.spriteSize - CARD_STYLE.pokeballSize) / 2
  const clickTimer = useRef(null)
  const [pop, setPop] = useState(0)

  // Espera um instante para saber se é clique simples (abrir) ou duplo (favoritar).
  const handleClick = () => {
    clearTimeout(clickTimer.current)
    clickTimer.current = setTimeout(onClick, 220)
  }
  const handleDoubleClick = () => {
    clearTimeout(clickTimer.current)
    toggleFavorite(pokemon.id)
    setPop((n) => n + 1)
  }

  return (
    <motion.button
      type="button"
      layout={false}
      onClick={handleClick}
      onDoubleClick={handleDoubleClick}
      onMouseEnter={() => prefetchSpecies(pokemon.species)}
      title="Clique para ver detalhes · clique duplo para favoritar"
      initial={false}
      animate={hidden ? { opacity: 0, scale: 1.35 } : { opacity: 1, scale: 1 }}
      whileHover={hidden ? undefined : 'hover'}
      whileTap={{ scale: 0.97 }}
      variants={{ hover: { scale: CARD_STYLE.hoverScale, boxShadow: '0 10px 22px rgba(0,0,0,.45)' } }}
      transition={{ type: 'spring', stiffness: 300, damping: 22 }}
      className="group relative w-full cursor-pointer overflow-hidden text-left shadow-[0_4px_10px_rgba(0,0,0,.25)]"
      style={{
        height: CARD_STYLE.height,
        borderRadius: CARD_STYLE.radius,
        background,
        outline: selected ? '3px solid white' : 'none',
        pointerEvents: hidden ? 'none' : undefined,
      }}
    >
      <SpinningPokeball size={CARD_STYLE.pokeballSize} opacity={0.22} className="absolute" style={{ right: ballRight, bottom: ballBottom }} />
      {pokemon.sprite && (
        <div className="absolute" style={{ width: CARD_STYLE.spriteSize, right: CARD_STYLE.spriteRight, bottom: CARD_STYLE.spriteBottom }}>
          <Sprite
            path={pokemon.sprite}
            box={pokemon.box}
            align="bottom"
            fill={0.92}
            imgClassName="origin-bottom"
            motionProps={{ variants: { hover: { scale: CARD_STYLE.hoverSpriteScale } }, transition: { type: 'spring', stiffness: 400, damping: 12 } }}
          />
        </div>
      )}
      <div className="absolute top-3.5 right-3 flex items-center gap-1 text-xs font-extrabold text-black/35">
        {isFavorite && <Icon name="star" size={16} className="text-yellow-300" />}#{pokemon.id}
      </div>
      <AnimatePresence>
        {pop > 0 && (
          <motion.div
            key={pop}
            className="pointer-events-none absolute inset-0 grid place-items-center text-yellow-300"
            initial={{ scale: 0.3, opacity: 1 }}
            animate={{ scale: 1.8, opacity: 0 }}
            transition={{ duration: 0.6 }}
            onAnimationComplete={() => setPop(0)}
          >
            <Icon name={isFavorite ? 'star' : 'starOutline'} size={48} />
          </motion.div>
        )}
      </AnimatePresence>
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
    </motion.button>
  )
}
