// Coleção por jogo: marca os Pokémon que você já pegou em cada jogo (normal e
// shiny) e mostra o progresso. Fica salva na conta (app e site).

import { useEffect, useMemo, useState } from 'react'
import { getPokedex, getPokemonIndex } from '../lib/data'
import { GAME_BY_KEY, displayName, generationBackground } from '../lib/pokemon'
import { useStore } from '../lib/store'
import GamePicker from './GamePicker'
import VersionPicker, { inVersion } from './VersionPicker'
import Sprite from './Sprite'
import { Loader } from './ui'

const FILTERS = [
  { key: 'all', label: 'Todos' },
  { key: 'missing', label: 'Faltando' },
  { key: 'caught', label: 'Pegos' },
]

/** "Por jogo" ou "Formas" (Living Dex das formas). */
function ModeSwitch({ forms, onChange }) {
  return (
    <div className="mb-4 inline-flex rounded-full bg-card p-1 shadow">
      {[
        [false, 'Por jogo'],
        [true, 'Formas'],
      ].map(([value, label]) => (
        <button
          key={label}
          type="button"
          onClick={() => onChange(value)}
          className={`cursor-pointer rounded-full px-4 py-1.5 text-sm font-semibold ${forms === value ? 'bg-violet-600 text-white' : 'text-muted hover:text-text'}`}
        >
          {label}
        </button>
      ))}
    </div>
  )
}

/** Chave da Coleção para as formas (igual ao app). */
const FORMS_KEY = 'forms'
const FORM_CATEGORIES = ['Regionais', 'Mega e Primal', 'Gigantamax', 'Outras formas']
const formCategory = (name) =>
  /-(alola|galar|hisui|paldea)/.test(name)
    ? 'Regionais'
    : name.includes('-mega') || name.includes('-primal')
      ? 'Mega e Primal'
      : name.endsWith('-gmax')
        ? 'Gigantamax'
        : 'Outras formas'
const formLabel = (name) =>
  name
    .split('-')
    .map((w) => w[0].toUpperCase() + w.slice(1))
    .join(' ')

/** Living Dex das formas: regionais, Megas, Gigantamax e outras (normal e shiny). */
function FormsCollection({ header }) {
  const collection = useStore((s) => s.collection)
  const toggleCaught = useStore((s) => s.toggleCaught)
  const [forms, setForms] = useState(null)
  const [category, setCategory] = useState(FORM_CATEGORIES[0])
  const [shinyMode, setShinyMode] = useState(false)

  useEffect(() => {
    getPokemonIndex().then((index) => setForms(index.filter((p) => !p.default && !p.name.includes('-totem') && !p.name.endsWith('-cap'))))
  }, [])

  const entry = collection?.[FORMS_KEY] ?? { c: [], s: [] }
  const caught = new Set(entry.c ?? [])
  const shiny = new Set(entry.s ?? [])
  if (!forms) return <Loader />
  const shown = forms.filter((f) => formCategory(f.name) === category)
  const done = shown.filter((f) => caught.has(f.id)).length
  const all = forms.filter((f) => caught.has(f.id)).length
  return (
    <div>
      {header}
      <div className="mb-4 flex flex-wrap items-center gap-2">
        {FORM_CATEGORIES.map((cat) => (
          <button
            key={cat}
            type="button"
            onClick={() => setCategory(cat)}
            className={`cursor-pointer rounded-full px-3.5 py-1.5 text-sm font-semibold shadow ${category === cat ? 'bg-sky-500 text-white' : 'bg-card text-text'}`}
          >
            {cat}
          </button>
        ))}
        <button
          type="button"
          onClick={() => setShinyMode(!shinyMode)}
          aria-pressed={shinyMode}
          className={`cursor-pointer rounded-full px-4 py-1.5 text-sm font-bold shadow ${shinyMode ? 'bg-yellow-400 text-[#3e2723]' : 'bg-card text-text'}`}
        >
          ✨ Marcar shiny
        </button>
      </div>
      <div className="mb-5 rounded-2xl bg-gradient-to-r from-violet-600 to-pink-600 p-4 text-white shadow">
        <div className="flex flex-wrap items-end justify-between gap-2">
          <div className="text-lg font-black">{category}</div>
          <div className="text-sm font-semibold">{`${done}/${shown.length}`}</div>
        </div>
        <div className="mt-2 h-3 overflow-hidden rounded-full bg-black/30">
          <div className="h-full rounded-full bg-white transition-all" style={{ width: `${shown.length ? (done / shown.length) * 100 : 0}%` }} />
        </div>
        <p className="mt-2 text-xs opacity-90">{`${all} de ${forms.length} formas no total`}</p>
      </div>
      <div className="grid grid-cols-[repeat(auto-fill,minmax(96px,1fr))] gap-2">
        {shown.map((f) => {
          const isCaught = caught.has(f.id)
          const isShiny = shiny.has(f.id)
          const on = shinyMode ? isShiny : isCaught
          const dash = f.name.indexOf('-')
          return (
            <button
              key={f.id}
              type="button"
              onClick={() => toggleCaught(FORMS_KEY, f.id, shinyMode)}
              aria-pressed={on}
              title={f.name}
              className={`relative flex cursor-pointer flex-col items-center rounded-2xl p-2 shadow transition hover:scale-105 ${on ? 'bg-card ring-2 ring-sky-400' : 'bg-card/60'}`}
            >
              {isShiny && <span className="absolute top-0.5 right-1.5 text-sm">✨</span>}
              <div className={`h-16 w-16 ${isCaught || isShiny ? '' : 'opacity-40 grayscale'}`}>
                <Sprite path={f.sprite} box={f.box} />
              </div>
              <span className="w-full truncate text-center text-xs font-semibold">{displayName(f.name)}</span>
              <span className="w-full truncate text-center text-[10px] text-muted">{formLabel(f.name.slice(dash + 1))}</span>
            </button>
          )
        })}
      </div>
    </div>
  )
}

export default function Collection() {
  const collection = useStore((s) => s.collection)
  const toggleCaught = useStore((s) => s.toggleCaught)
  const [pokedex, setPokedex] = useState(null)
  const [game, setGame] = useState(() => localStorage.getItem('pocketdex-collection-game') || 'sv')
  const [filter, setFilter] = useState('all')
  const [shinyMode, setShinyMode] = useState(false)
  const [version, setVersion] = useState(null)
  const [forms, setForms] = useState(false)

  useEffect(() => {
    getPokedex().then(setPokedex)
  }, [])

  const choose = (key) => {
    if (!key) return
    setGame(key)
    setVersion(null)
    try {
      localStorage.setItem('pocketdex-collection-game', key)
    } catch {
      // sem localStorage
    }
  }

  const entry = collection?.[game] ?? { c: [], s: [] }
  const caught = useMemo(() => new Set(entry.c ?? []), [entry.c])
  const shiny = useMemo(() => new Set(entry.s ?? []), [entry.s])
  const inGame = useMemo(() => (pokedex ?? []).filter((p) => p.games?.includes(game) && inVersion(p, game, version)), [pokedex, game, version])
  const done = inGame.filter((p) => caught.has(p.id)).length
  const doneShiny = inGame.filter((p) => shiny.has(p.id)).length
  const shown = inGame.filter((p) => (filter === 'missing' ? !caught.has(p.id) : filter === 'caught' ? caught.has(p.id) : true))
  const percent = inGame.length ? Math.round((done / inGame.length) * 100) : 0
  const info = GAME_BY_KEY[game]

  if (forms) return <FormsCollection header={<ModeSwitch forms={forms} onChange={setForms} />} />
  if (!pokedex) return <Loader />
  return (
    <div>
      <ModeSwitch forms={forms} onChange={setForms} />
      <div className="mb-4 flex flex-wrap items-center gap-3">
        <GamePicker value={game} onChange={choose} />
        <VersionPicker game={game} value={version} onChange={setVersion} />
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
          <div className="text-lg font-black">{version ?? info?.name}</div>
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
              {!version && p.only?.[game] && (
                <span className="absolute right-1 bottom-6 rounded-full bg-black/60 px-1.5 text-[9px] font-bold text-white">{p.only[game]}</span>
              )}
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
