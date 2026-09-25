// Seletor de geração flutuante: botões grandes com a região, os 3 iniciais e
// as cores dos jogos de cada geração.

import { AnimatePresence, m } from 'framer-motion'
import { useEffect, useRef, useState } from 'react'
import { getPokemonById } from '../lib/data'
import { GENERATIONS, generationBackground } from '../lib/pokemon'
import Sprite from './Sprite'
import { Icon, SpinningPokeball } from './ui'

const ALL = { id: 0, name: 'Todas as gerações', region: 'Pokédex Nacional', starters: [25, 133, 150], colors: ['#26A69A', '#42A5F5'] }

function Starters({ ids, byId, size }) {
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

function Option({ gen, byId, selected, onClick }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`generation-option relative flex w-full cursor-pointer items-center gap-3 overflow-hidden rounded-2xl px-5 py-4 text-left text-white ${selected ? 'is-selected' : ''}`}
      style={{ background: generationBackground(gen) }}
    >
      <SpinningPokeball size={110} opacity={0.15} slow className="absolute -right-4 -bottom-8" />
      <div className="relative min-w-0 flex-1">
        <div className="text-lg font-black drop-shadow">{gen.id ? gen.name.replace('Generation', 'Geração') : gen.name}</div>
        <div className="text-sm font-semibold opacity-90 drop-shadow">{gen.region}</div>
      </div>
      <div className="relative">
        <Starters ids={gen.starters} byId={byId} size={64} />
      </div>
    </button>
  )
}

const ALIGN = {
  // Celular: a lista abre para a direita (não sai da tela); PC: alinhada à direita do botão.
  right: 'left-0 sm:left-auto sm:right-0',
  center: 'left-1/2 -translate-x-1/2',
}

/**
 * @param value  id da geração (null/0 = todas)
 * @param align  'right' (padrão) ou 'center'
 */
export default function GenerationPicker({ value, onChange, align = 'right' }) {
  const [open, setOpen] = useState(false)
  const [byId, setById] = useState(null)
  const ref = useRef(null)
  const current = GENERATIONS.find((g) => g.id === value) ?? ALL

  useEffect(() => {
    getPokemonById().then(setById)
  }, [])

  // Fecha ao clicar fora ou apertar Esc.
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

  const choose = (gen) => {
    onChange(gen.id || null)
    setOpen(false)
  }

  return (
    <div ref={ref} className="relative">
      <button
        type="button"
        onClick={() => setOpen(!open)}
        aria-expanded={open}
        aria-label="Filtrar por geração"
        className="generation-option flex cursor-pointer items-center gap-2 rounded-full py-1.5 pr-3 pl-4 text-sm font-bold text-white"
        style={{ background: generationBackground(current) }}
      >
        <span className="drop-shadow">{current.id ? `${current.name.replace('Generation', 'Geração')} · ${current.region}` : current.name}</span>
        <Starters ids={current.starters} byId={byId} size={28} />
        <Icon name={open ? 'up' : 'down'} size={20} />
      </button>

      <AnimatePresence>
        {open && (
          <div className={`absolute z-30 mt-2 ${ALIGN[align]}`}>
          <m.div
            initial={{ opacity: 0, y: -8, scale: 0.96 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: -8, scale: 0.96 }}
            transition={{ duration: 0.18 }}
            className="max-h-[70vh] w-[min(calc(100vw-2rem),460px)] origin-top overflow-y-auto rounded-3xl bg-card p-3 shadow-2xl ring-1 ring-line"
          >
            <div className="flex flex-col gap-2">
              {[ALL, ...GENERATIONS].map((gen) => (
                <Option key={gen.id} gen={gen} byId={byId} selected={gen.id === current.id} onClick={() => choose(gen)} />
              ))}
            </div>
          </m.div>
          </div>
        )}
      </AnimatePresence>
    </div>
  )
}
