// Ferramentas de batalha do Treino: comparar 2 Pokémon (a calculadora de dano
// fica em DamageCalc.jsx).

import { m } from 'framer-motion'
import { useEffect, useState } from 'react'
import { getSpecies, getTypes } from '../lib/data'
import { STAT_LABELS, damageTaken, prettyName, typeBackground } from '../lib/pokemon'
import PokemonPicker from './PokemonPicker'
import Sprite from './Sprite'
import { Icon, Loader, TypeBadge } from './ui'

/** Pokémon escolhido + dados da forma dele (status e golpes). */
export function usePokemonForm(pokemon) {
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

export function Slot({ pokemon, label, onPick }) {
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
