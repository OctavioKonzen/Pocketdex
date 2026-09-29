// Coleção por jogo: marca os Pokémon que você já pegou em cada jogo (normal e
// shiny) e mostra o progresso. Fica salva na conta (app e site).

import { useEffect, useMemo, useState } from 'react'
import { getPokedex } from '../lib/data'
import { GAME_BY_KEY, displayName, generationBackground } from '../lib/pokemon'
import { useStore } from '../lib/store'
import GamePicker from './GamePicker'
import Sprite from './Sprite'
import { Loader } from './ui'

const FILTERS = [
  { key: 'all', label: 'Todos' },
  { key: 'missing', label: 'Faltando' },
  { key: 'caught', label: 'Pegos' },
]

export default function Collection() {
  const collection = useStore((s) => s.collection)
  const toggleCaught = useStore((s) => s.toggleCaught)
  const [pokedex, setPokedex] = useState(null)
  const [game, setGame] = useState(() => localStorage.getItem('pocketdex-collection-game') || 'sv')
  const [filter, setFilter] = useState('all')
  const [shinyMode, setShinyMode] = useState(false)

  useEffect(() => {
    getPokedex().then(setPokedex)
  }, [])

  const choose = (key) => {
    if (!key) return
    setGame(key)
    try {
      localStorage.setItem('pocketdex-collection-game', key)
    } catch {
      // sem localStorage
    }
  }

  const entry = collection?.[game] ?? { c: [], s: [] }
  const caught = useMemo(() => new Set(entry.c ?? []), [entry.c])
  const shiny = useMemo(() => new Set(entry.s ?? []), [entry.s])
  const inGame = useMemo(() => (pokedex ?? []).filter((p) => p.games?.includes(game)), [pokedex, game])
  const done = inGame.filter((p) => caught.has(p.id)).length
  const doneShiny = inGame.filter((p) => shiny.has(p.id)).length
  const shown = inGame.filter((p) => (filter === 'missing' ? !caught.has(p.id) : filter === 'caught' ? caught.has(p.id) : true))
  const percent = inGame.length ? Math.round((done / inGame.length) * 100) : 0
  const info = GAME_BY_KEY[game]

  if (!pokedex) return <Loader />
  return (
    <div>
      <div className="mb-4 flex flex-wrap items-center gap-3">
        <GamePicker value={game} onChange={choose} />
        <div className="flex rounded-full bg-card p-1 shadow">
          {FILTERS.map((f) => (
            <button
              key={f.key}
              type="button"
              onClick={() => setFilter(f.key)}
              className={`cursor-pointer rounded-full px-3.5 py-1.5 text-sm font-semibold ${filter === f.key ? 'bg-sky-500 text-white' : 'text-muted hover:text-text'}`}
            >
              {f.label}
            </button>
          ))}
        </div>
        <button
          type="button"
          onClick={() => setShinyMode(!shinyMode)}
          aria-pressed={shinyMode}
          className={`cursor-pointer rounded-full px-4 py-2 text-sm font-bold shadow ${shinyMode ? 'bg-yellow-400 text-[#3e2723]' : 'bg-card text-text'}`}
        >
          ✨ Marcar shiny
        </button>
      </div>

      <div className="mb-5 rounded-2xl p-4 text-white shadow" style={{ background: info ? generationBackground(info) : '#546E7A' }}>
        <div className="flex flex-wrap items-end justify-between gap-2">
          <div className="text-lg font-black">{info?.name}</div>
          <div className="text-sm font-semibold">{`${done}/${inGame.length} pegos · ${doneShiny} shiny`}</div>
        </div>
        <div className="mt-2 h-3 overflow-hidden rounded-full bg-black/30">
          <div className="h-full rounded-full bg-white transition-all" style={{ width: `${percent}%` }} />
        </div>
        <p className="mt-2 text-xs opacity-90">
          {shinyMode ? 'Toque num Pokémon para marcar que você o pegou shiny.' : 'Toque num Pokémon para marcar que você o pegou neste jogo.'}
        </p>
      </div>

      <div className="grid grid-cols-[repeat(auto-fill,minmax(88px,1fr))] gap-2">
        {shown.map((p) => {
          const isCaught = caught.has(p.id)
          const isShiny = shiny.has(p.id)
          const on = shinyMode ? isShiny : isCaught
          return (
            <button
              key={p.id}
              type="button"
              onClick={() => toggleCaught(game, p.id, shinyMode)}
              aria-pressed={on}
              title={p.name}
              className={`relative flex cursor-pointer flex-col items-center rounded-2xl p-2 shadow transition hover:scale-105 ${on ? 'bg-card ring-2 ring-sky-400' : 'bg-card/60'}`}
            >
              <span className="absolute top-1 left-2 text-[10px] text-muted">#{p.id}</span>
              {isShiny && <span className="absolute top-0.5 right-1.5 text-sm">✨</span>}
              <div className={`h-16 w-16 ${isCaught || isShiny ? '' : 'opacity-40 grayscale'}`}>
                <Sprite path={p.sprite} box={p.box} />
              </div>
              <span className="w-full truncate text-center text-xs font-semibold">{displayName(p.name)}</span>
            </button>
          )
        })}
      </div>
    </div>
  )
}
