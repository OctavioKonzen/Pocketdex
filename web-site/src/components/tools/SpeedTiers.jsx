// Faixas de velocidade (igual ao app): todos os Pokémon em ordem de Speed no
// nível 50 ou 100, com o treino escolhido e os efeitos de batalha.

import { useEffect, useMemo, useState } from 'react'
import { getPokedex } from '../../lib/data'
import { t } from '../../lib/i18n'
import { prettyName } from '../../lib/pokemon'
import { SPEED_SPREADS, speedStat } from '../../lib/speed'
import PokeIcon from '../PokeIcon'
import PokemonModal from '../PokemonModal'
import { Icon } from '../ui'

const PAGE = 120

function Chip({ on, onClick, children }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`cursor-pointer rounded-full px-3 py-1.5 text-sm font-semibold transition ${on ? 'bg-sky-600 text-white' : 'bg-card text-text hover:bg-surface'}`}
    >
      {children}
    </button>
  )
}

export default function SpeedTiers() {
  const [pokedex, setPokedex] = useState(null)
  const [nfe, setNfe] = useState(null)
  const [level, setLevel] = useState(50)
  const [spread, setSpread] = useState(0)
  const [mods, setMods] = useState({ scarf: false, boost: false, tailwind: false, trickRoom: false, finalOnly: true })
  const [query, setQuery] = useState('')
  const [limit, setLimit] = useState(PAGE)
  const [open, setOpen] = useState(null)

  useEffect(() => {
    getPokedex().then(setPokedex)
    import('../../lib/damageCalc').then((calc) => setNfe(() => calc.isNfe))
  }, [])

  const list = useMemo(() => {
    if (!pokedex) return []
    const [, iv, ev, nat] = SPEED_SPREADS[spread]
    return pokedex
      .filter((p) => !mods.finalOnly || !nfe?.(p.name))
      .map((p) => ({ ...p, speed: speedStat(p.stats[5], level, iv, ev, nat, mods) }))
      .sort((a, b) => (mods.trickRoom ? a.speed - b.speed : b.speed - a.speed))
      .map((p, i) => ({ ...p, rank: i + 1 }))
  }, [pokedex, nfe, level, spread, mods])

  const q = query.trim().toLowerCase()
  const shown = q ? list.filter((p) => p.name.includes(q) || t(prettyName(p.name)).toLowerCase().includes(q) || String(p.id) === q) : list
  const toggle = (k) => setMods({ ...mods, [k]: !mods[k] })

  return (
    <div className="mx-auto max-w-3xl space-y-4">
      <p className="text-muted">Quem ataca primeiro: todos os Pokémon em ordem de Speed.</p>
      <div className="flex flex-wrap gap-2">
        {[50, 100].map((l) => (
          <Chip key={l} on={level === l} onClick={() => setLevel(l)}>{`Nível ${l}`}</Chip>
        ))}
        <span className="w-2" />
        {SPEED_SPREADS.map(([label], i) => (
          <Chip key={label} on={spread === i} onClick={() => setSpread(i)}>
            {label}
          </Chip>
        ))}
      </div>
      <div className="flex flex-wrap gap-2">
        <Chip on={mods.scarf} onClick={() => toggle('scarf')}>
          Choice Scarf
        </Chip>
        <Chip on={mods.boost} onClick={() => toggle('boost')}>
          +1 Speed
        </Chip>
        <Chip on={mods.tailwind} onClick={() => toggle('tailwind')}>
          Tailwind
        </Chip>
        <Chip on={mods.trickRoom} onClick={() => toggle('trickRoom')}>
          Trick Room
        </Chip>
        <Chip on={mods.finalOnly} onClick={() => toggle('finalOnly')}>
          Só evoluídos
        </Chip>
      </div>
      <label className="flex items-center gap-2 rounded-full bg-card px-4 py-2.5">
        <Icon name="search" className="text-muted" />
        <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Procurar Pokémon" className="w-full bg-transparent outline-none" />
      </label>
      <div className="overflow-hidden rounded-2xl bg-card shadow">
        {shown.slice(0, limit).map((p) => (
          <button
            key={p.id}
            type="button"
            onClick={() => setOpen(p.id)}
            className="flex w-full cursor-pointer items-center gap-3 border-b border-line px-3 py-1.5 text-left last:border-0 hover:bg-surface"
          >
            <span className="w-9 text-sm font-bold text-muted">{p.rank}</span>
            <PokeIcon id={p.id} className="h-10 w-10" />
            <span className="min-w-0 flex-1">
              <span className="block truncate font-semibold">{prettyName(p.name)}</span>
              <span className="block text-xs text-muted">{`Base ${p.stats[5]}`}</span>
            </span>
            <span className="text-lg font-black">{p.speed}</span>
          </button>
        ))}
      </div>
      {shown.length > limit && (
        <button type="button" onClick={() => setLimit(limit + PAGE)} className="mx-auto block cursor-pointer rounded-full bg-card px-5 py-2 font-semibold">
          Mostrar mais
        </button>
      )}
      <PokemonModal id={open} onClose={() => setOpen(null)} />
    </div>
  )
}
