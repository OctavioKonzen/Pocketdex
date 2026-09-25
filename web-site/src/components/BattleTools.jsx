// Ferramentas de batalha do Treino: comparar 2 Pokémon e calculadora de dano.

import { m } from 'framer-motion'
import { useEffect, useMemo, useState } from 'react'
import { damage } from '../lib/battle'
import { getMoves, getSpecies, getTypes } from '../lib/data'
import { STAT_LABELS, damageTaken, prettyName, typeBackground } from '../lib/pokemon'
import PokemonPicker from './PokemonPicker'
import Sprite from './Sprite'
import { Icon, Loader, TypeBadge } from './ui'

/** Pokémon escolhido + dados da forma dele (status e golpes). */
function usePokemonForm(pokemon) {
  const [loaded, setLoaded] = useState(null) // {id, form}
  useEffect(() => {
    if (!pokemon) return
    let alive = true
    getSpecies(pokemon.species ?? pokemon.id).then((sp) => {
      if (alive) setLoaded({ id: pokemon.id, form: sp.forms.find((f) => f.id === pokemon.id) ?? sp.forms[0] })
    })
    return () => {
      alive = false
    }
  }, [pokemon])
  return pokemon && loaded?.id === pokemon.id ? loaded.form : null
}

function Slot({ pokemon, label, onPick }) {
  return (
    <m.button
      type="button"
      whileHover={{ scale: 1.03 }}
      onClick={onPick}
      className="flex w-full cursor-pointer flex-col items-center gap-2 rounded-3xl p-4 text-white shadow-lg"
      style={{ background: pokemon ? typeBackground(pokemon.types) : 'var(--surface)' }}
    >
      {pokemon ? (
        <>
          <Sprite path={pokemon.sprite} box={pokemon.box} fill={0.85} className="h-28 w-28" />
          <span className="text-lg font-black">{prettyName(pokemon.name)}</span>
          <span className="flex gap-1">
            {pokemon.types.map((t) => (
              <TypeBadge key={t} type={t} small />
            ))}
          </span>
        </>
      ) : (
        <span className="grid h-40 place-items-center text-muted">
          <span className="flex flex-col items-center gap-2">
            <Icon name="add" size={40} />
            {label}
          </span>
        </span>
      )}
    </m.button>
  )
}

/** Dois Pokémon lado a lado: status, total e fraquezas. */
export function Compare() {
  const [left, setLeft] = useState(null)
  const [right, setRight] = useState(null)
  const [picking, setPicking] = useState(null)
  const [typeData, setTypeData] = useState(null)
  const a = usePokemonForm(left)
  const b = usePokemonForm(right)

  useEffect(() => {
    getTypes().then(setTypeData)
  }, [])

  const weak = (p) =>
    typeData && p
      ? Object.entries(damageTaken(p.types, typeData))
          .filter(([, v]) => v >= 2)
          .sort((x, y) => y[1] - x[1])
      : []

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 gap-4">
        <Slot pokemon={left} label="Escolher Pokémon" onPick={() => setPicking('left')} />
        <Slot pokemon={right} label="Escolher Pokémon" onPick={() => setPicking('right')} />
      </div>
      {a && b ? (
        <div className="rounded-3xl bg-card p-6 shadow-lg">
          <h3 className="mb-4 text-lg font-bold">Status base</h3>
          <div className="space-y-3">
            {STAT_LABELS.map((label, i) => {
              const x = a.stats[i][0]
              const y = b.stats[i][0]
              return (
                <div key={label} className="grid grid-cols-[1fr_auto_1fr] items-center gap-3 text-sm">
                  <div className="flex items-center justify-end gap-2">
                    <span className={`font-black ${x > y ? 'text-green-400' : ''}`}>{x}</span>
                    <div className="h-3 w-full max-w-[220px] overflow-hidden rounded-full bg-surface">
                      <m.div className="ml-auto h-full rounded-full bg-sky-500" animate={{ width: `${Math.min(100, (x / 200) * 100)}%` }} />
                    </div>
                  </div>
                  <span className="w-16 text-center text-muted">{label}</span>
                  <div className="flex items-center gap-2">
                    <div className="h-3 w-full max-w-[220px] overflow-hidden rounded-full bg-surface">
                      <m.div className="h-full rounded-full bg-orange-500" animate={{ width: `${Math.min(100, (y / 200) * 100)}%` }} />
                    </div>
                    <span className={`font-black ${y > x ? 'text-green-400' : ''}`}>{y}</span>
                  </div>
                </div>
              )
            })}
            {(() => {
              const tx = a.stats.reduce((s, v) => s + v[0], 0)
              const ty = b.stats.reduce((s, v) => s + v[0], 0)
              return (
                <div className="grid grid-cols-[1fr_auto_1fr] items-center gap-3 border-t border-line pt-3 font-black">
                  <span className={`text-right ${tx > ty ? 'text-green-400' : ''}`}>{tx}</span>
                  <span className="w-16 text-center text-muted">Total</span>
                  <span className={ty > tx ? 'text-green-400' : ''}>{ty}</span>
                </div>
              )
            })()}
          </div>
          <div className="mt-6 grid gap-4 sm:grid-cols-2">
            {[left, right].map((p, i) => (
              <div key={i}>
                <div className="mb-2 text-sm text-muted">Fraquezas de {prettyName(p.name)}</div>
                <div className="flex flex-wrap gap-1.5">
                  {weak(p).map(([t, v]) => (
                    <span key={t} className="flex items-center gap-1">
                      <TypeBadge type={t} small />
                      <span className="text-xs font-bold">×{v}</span>
                    </span>
                  ))}
                </div>
              </div>
            ))}
          </div>
        </div>
      ) : (
        (left || right) && (left && right ? <Loader size={56} /> : <p className="text-center text-muted">Escolha o outro Pokémon para comparar.</p>)
      )}
      <PokemonPicker
        open={picking !== null}
        onClose={() => setPicking(null)}
        onPick={(p) => {
          if (picking === 'left') setLeft(p)
          else setRight(p)
          setPicking(null)
        }}
      />
    </div>
  )
}

const EV_OPTIONS = [
  { value: 0, label: 'Sem EVs' },
  { value: 252, label: '252 EVs' },
]

function EvToggle({ label, value, onChange }) {
  return (
    <label className="flex items-center justify-between gap-3 text-sm">
      <span className="text-muted">{label}</span>
      <select value={value} onChange={(e) => onChange(Number(e.target.value))} className="rounded-lg bg-surface px-2 py-1 outline-none">
        {EV_OPTIONS.map((o) => (
          <option key={o.value} value={o.value}>
            {o.label}
          </option>
        ))}
      </select>
    </label>
  )
}

/** Quanto de dano um golpe do atacante tira do defensor (nível 50). */
export function DamageCalc() {
  const [attacker, setAttacker] = useState(null)
  const [defender, setDefender] = useState(null)
  const [picking, setPicking] = useState(null)
  const [moveName, setMoveName] = useState('')
  const [moves, setMoves] = useState(null)
  const [typeData, setTypeData] = useState(null)
  const [attackEv, setAttackEv] = useState(252)
  const [defenseEv, setDefenseEv] = useState(0)
  const [hpEv, setHpEv] = useState(0)
  const a = usePokemonForm(attacker)
  const d = usePokemonForm(defender)

  useEffect(() => {
    getMoves().then(setMoves)
    getTypes().then(setTypeData)
  }, [])

  // Golpes de dano que o atacante aprende, do mais forte ao mais fraco.
  const options = useMemo(() => {
    if (!a || !moves) return []
    const names = [...new Set(a.moves.map((mv) => mv[0]))]
    return names
      .map((n) => moves[n])
      .filter((mv) => mv && mv.power > 0 && mv.category !== 'status')
      .sort((x, y) => y.power - x.power || x.name.localeCompare(y.name))
  }, [a, moves])

  const move = options.find((mv) => mv.name === moveName) ?? options[0]
  const result =
    a && d && move && typeData
      ? damage({
          attacker: { types: attacker.types, stats: a.stats.map((s) => s[0]) },
          defender: { types: defender.types, stats: d.stats.map((s) => s[0]) },
          move,
          typeData,
          attackEv,
          defenseEv,
          hpEv,
        })
      : null

  const multText = (mult) => (mult === 0 ? 'Não tem efeito' : mult >= 2 ? 'Super efetivo' : mult < 1 ? 'Pouco efetivo' : 'Efetivo')

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 gap-4">
        <div className="space-y-2">
          <div className="text-center text-sm font-bold text-muted">Atacante</div>
          <Slot pokemon={attacker} label="Escolher atacante" onPick={() => setPicking('attacker')} />
        </div>
        <div className="space-y-2">
          <div className="text-center text-sm font-bold text-muted">Defensor</div>
          <Slot pokemon={defender} label="Escolher defensor" onPick={() => setPicking('defender')} />
        </div>
      </div>

      {a && (
        <div className="grid gap-4 rounded-3xl bg-card p-6 shadow-lg sm:grid-cols-2">
          <label className="block sm:col-span-2">
            <span className="mb-1 block text-sm font-bold">Golpe</span>
            <select
              value={move?.name ?? ''}
              onChange={(e) => setMoveName(e.target.value)}
              className="w-full rounded-xl bg-surface px-3 py-2 outline-none"
            >
              {options.map((mv) => (
                <option key={mv.name} value={mv.name}>
                  {prettyName(mv.name)} · {mv.type} · {mv.category === 'physical' ? 'físico' : 'especial'} · {mv.power}
                </option>
              ))}
            </select>
          </label>
          <EvToggle label={`EVs em ${move?.category === 'special' ? 'Sp. Atk' : 'Attack'} do atacante`} value={attackEv} onChange={setAttackEv} />
          <EvToggle label="EVs em HP do defensor" value={hpEv} onChange={setHpEv} />
          <EvToggle label={`EVs em ${move?.category === 'special' ? 'Sp. Def' : 'Defense'} do defensor`} value={defenseEv} onChange={setDefenseEv} />
          <p className="text-xs text-muted sm:col-span-2">Nível 50, IVs máximos e Nature neutra, sem crítico, clima ou itens.</p>
        </div>
      )}

      {result && (
        <m.div key={`${move.name}-${result.max}`} initial={{ scale: 0.95, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} className="rounded-3xl bg-card p-6 shadow-lg">
          <div className="flex flex-wrap items-center gap-2 text-sm">
            <TypeBadge type={move.type} small />
            <span className="font-bold">{multText(result.mult)}</span>
            {result.mult !== 1 && result.mult !== 0 && <span className="text-muted">×{result.mult}</span>}
            {result.stab && <span className="rounded-full bg-sky-500/20 px-2 py-0.5 text-xs font-bold text-sky-400">STAB ×1.5</span>}
          </div>
          <div className="mt-4 text-4xl font-black">
            {result.minPct}% – {result.maxPct}%
          </div>
          <div className="text-sm text-muted">
            {result.min}–{result.max} de {result.hp} HP no nível 50
          </div>
          <div className="mt-3 h-4 overflow-hidden rounded-full bg-surface">
            <m.div
              className="h-full rounded-full"
              style={{ background: result.maxPct >= 100 ? '#e53935' : result.maxPct >= 50 ? '#fb8c00' : '#43a047' }}
              animate={{ width: `${Math.min(100, result.maxPct)}%` }}
            />
          </div>
          <p className="mt-3 font-bold">
            {result.hits == null ? 'Não causa dano.' : result.hits === 1 ? 'Pode derrotar com 1 golpe!' : `Derrota em cerca de ${result.hits} golpes.`}
          </p>
        </m.div>
      )}

      <PokemonPicker
        open={picking !== null}
        onClose={() => setPicking(null)}
        onPick={(p) => {
          if (picking === 'attacker') {
            setAttacker(p)
            setMoveName('')
          } else setDefender(p)
          setPicking(null)
        }}
      />
    </div>
  )
}
