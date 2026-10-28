// Calculadora de IVs: nível, Nature, EVs e os status mostrados no jogo.

import { useState } from 'react'
import { STAT_LABELS, NATURES, displayName } from '../../lib/pokemon'
import { possibleIvs } from '../../lib/ivs'
import PokemonPicker from '../PokemonPicker'
import Sprite from '../Sprite'
import { Button } from '../ui'

const FIELD = 'w-full rounded-xl bg-surface px-3 py-2 outline-none focus:ring-2 focus:ring-sky-400'
const clamp = (v, min, max) => Math.max(min, Math.min(max, Number(v) || 0))

export default function IvCalc() {
  const [pokemon, setPokemon] = useState(null)
  const [picking, setPicking] = useState(false)
  const [level, setLevel] = useState(50)
  const [nature, setNature] = useState('Hardy')
  const [evs, setEvs] = useState([0, 0, 0, 0, 0, 0])
  const [stats, setStats] = useState(['', '', '', '', '', ''])

  const base = pokemon?.stats ?? null
  const result = (i) => {
    if (!base || stats[i] === '') return null
    return possibleIvs(i, base[i], Number(stats[i]), evs[i], level, nature)
  }

  return (
    <div className="grid gap-5 lg:grid-cols-[320px_1fr]">
      <div className="space-y-3 rounded-3xl bg-card p-5 shadow">
        <button type="button" onClick={() => setPicking(true)} className="flex w-full cursor-pointer items-center gap-3 rounded-2xl bg-surface p-3 text-left">
          <div className="h-16 w-16 shrink-0">{pokemon && <Sprite path={pokemon.sprite} box={pokemon.box} />}</div>
          <div>
            <div className="font-bold">{pokemon ? displayName(pokemon.name) : 'Escolher Pokémon'}</div>
            {base && <div className="text-xs text-muted">{`Base: ${base.join(' / ')}`}</div>}
          </div>
        </button>
        <label className="block text-sm">
          <span className="mb-1 block text-muted">Nível</span>
          <input type="number" min={1} max={100} value={level} onChange={(e) => setLevel(clamp(e.target.value, 1, 100))} className={FIELD} />
        </label>
        <label className="block text-sm">
          <span className="mb-1 block text-muted">Nature</span>
          <select value={nature} onChange={(e) => setNature(e.target.value)} className={FIELD}>
            {NATURES.map((n) => (
              <option key={n.name} value={n.name}>
                {n.neutral ? `${n.name} (neutra)` : `${n.name} (+${n.increases}, −${n.decreases})`}
              </option>
            ))}
          </select>
        </label>
        <p className="text-xs text-muted">Coloque os status que aparecem no resumo do Pokémon no jogo e os EVs que ele já tem (0 se nunca treinou).</p>
      </div>

      <div className="rounded-3xl bg-card p-5 shadow">
        <div className="grid grid-cols-[1fr_1fr_1fr_1.4fr] gap-2 text-xs font-bold text-muted">
          <span>Status</span>
          <span>No jogo</span>
          <span>EVs</span>
          <span>IV possível</span>
        </div>
        {STAT_LABELS.map((label, i) => {
          const ivs = result(i)
          return (
            <div key={label} className="mt-2 grid grid-cols-[1fr_1fr_1fr_1.4fr] items-center gap-2">
              <span className="font-semibold">{label}</span>
              <input
                type="number"
                min={1}
                value={stats[i]}
                onChange={(e) => setStats(stats.map((v, j) => (j === i ? e.target.value : v)))}
                className={FIELD}
                aria-label={`${label} no jogo`}
              />
              <input
                type="number"
                min={0}
                max={252}
                value={evs[i]}
                onChange={(e) => setEvs(evs.map((v, j) => (j === i ? clamp(e.target.value, 0, 252) : v)))}
                className={FIELD}
                aria-label={`EVs de ${label}`}
              />
              <span className={`text-center text-sm font-black ${ivs && !ivs.length ? 'text-red-400' : ivs?.includes(31) ? 'text-green-400' : ''}`}>
                {ivs === null ? '—' : !ivs.length ? 'Não bate' : ivs.length === 1 ? ivs[0] : `${ivs[0]}–${ivs.at(-1)}`}
              </span>
            </div>
          )
        })}
        {!pokemon && (
          <div className="mt-5">
            <Button onClick={() => setPicking(true)}>Escolher Pokémon</Button>
          </div>
        )}
      </div>

      <PokemonPicker
        open={picking}
        title="Escolha o Pokémon"
        onClose={() => setPicking(false)}
        onPick={(p) => {
          setPokemon(p)
          setPicking(false)
        }}
      />
    </div>
  )
}
