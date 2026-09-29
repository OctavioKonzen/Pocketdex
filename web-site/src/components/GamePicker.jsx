// Seletor de jogo (ao lado do de geração): mostra só os Pokémon que aparecem
// no jogo escolhido, com as cores e os mascotes de cada jogo.

import { AnimatePresence, m } from 'framer-motion'
import { useEffect, useRef, useState } from 'react'
import { getPokemonById } from '../lib/data'
import { GAMES, GAME_BY_KEY, generationBackground } from '../lib/pokemon'
import Sprite from './Sprite'
import { Icon, SpinningPokeball } from './ui'

const ALL = { key: null, name: 'Todos os jogos', mascots: [25], colors: ['#546E7A', '#37474F'] }

function Mascots({ ids, byId, size }) {
  return (
    <div className="flex shrink-0 items-end">
      {ids.map((id) => {
        const p = byId?.get(id)
        return p ? (
          <div key={id} style={{ width: size }}>
            <Sprite path={p.sprite} box={p.box} align="bottom" fill={0.95} />
          </div>
        ) : null
      })}
    </div>
  )
}

/** @param value chave do jogo (null = todos) */
export default function GamePicker({ value, onChange }) {
  const [open, setOpen] = useState(false)
  const [byId, setById] = useState(null)
  const ref = useRef(null)
  const current = (value && GAME_BY_KEY[value]) || ALL

  useEffect(() => {
    getPokemonById().then(setById)
  }, [])

  useEffect(() => {
    if (!open) return
    const onDown = (e) => ref.current && !ref.current.contains(e.target) && setOpen(false)
    const onKey = (e) => e.key === 'Escape' && setOpen(false)
    document.addEventListener('mousedown', onDown)
    window.addEventListener('keydown', onKey)
    return () => {
      document.removeEventListener('mousedown', onDown)
      window.removeEventListener('keydown', onKey)
    }
  }, [open])

  const choose = (game) => {
    onChange(game.key)
    setOpen(false)
  }

  return (
    <div ref={ref} className="relative">
      <button
        type="button"
        onClick={() => setOpen(!open)}
        aria-expanded={open}
        aria-label="Filtrar por jogo"
        className="generation-option flex cursor-pointer items-center gap-2 rounded-full py-1.5 pr-3 pl-4 text-sm font-bold text-white"
        style={{ background: generationBackground(current) }}
      >
        <span className="max-w-[46vw] truncate drop-shadow">{current.name}</span>
        <Mascots ids={current.mascots.slice(0, 2)} byId={byId} size={28} />
        <Icon name={open ? 'up' : 'down'} size={20} />
      </button>

      <AnimatePresence>
        {open && (
          <div className="absolute right-0 z-30 mt-2 sm:right-0">
            <m.div
              initial={{ opacity: 0, y: -8, scale: 0.96 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, y: -8, scale: 0.96 }}
              transition={{ duration: 0.18 }}
              className="max-h-[70vh] w-[min(calc(100vw-2rem),460px)] origin-top overflow-y-auto rounded-3xl bg-card p-3 shadow-2xl ring-1 ring-line"
            >
              <div className="flex flex-col gap-2">
                {[ALL, ...GAMES].map((game) => (
                  <button
                    key={game.key ?? 'all'}
                    type="button"
                    onClick={() => choose(game)}
                    className={`generation-option relative flex w-full cursor-pointer items-center gap-3 overflow-hidden rounded-2xl px-5 py-3 text-left text-white ${game.key === current.key ? 'is-selected' : ''}`}
                    style={{ background: generationBackground(game) }}
                  >
                    <SpinningPokeball size={100} opacity={0.15} slow className="absolute -right-4 -bottom-8" />
                    <div className="relative min-w-0 flex-1">
                      <div className="text-base font-black drop-shadow">{game.name}</div>
                      <div className="text-xs font-semibold opacity-90 drop-shadow">
                        {game.gen ? `Geração ${game.gen}${game.spinoff ? ' · jogo secundário' : ''}` : 'Pokédex Nacional'}
                      </div>
                    </div>
                    <div className="relative">
                      <Mascots ids={game.mascots} byId={byId} size={52} />
                    </div>
                  </button>
                ))}
              </div>
            </m.div>
          </div>
        )}
      </AnimatePresence>
    </div>
  )
}
