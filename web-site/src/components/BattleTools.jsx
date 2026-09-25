// Ferramentas de batalha do Treino: comparar 2 Pokémon e calculadora de dano.

import { m } from 'framer-motion'
import { useEffect, useMemo, useState } from 'react'
import { damage, DEFENDER_ITEMS, effectiveness, ITEMS, koText, NATURES, WEATHERS } from '../lib/battle'
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

const TYPES = ['normal', 'fire', 'water', 'electric', 'grass', 'ice', 'fighting', 'poison', 'ground', 'flying', 'psychic', 'bug', 'rock', 'ghost', 'dragon', 'dark', 'steel', 'fairy']
const STAT_NAMES = ['HP', 'Attack', 'Defense', 'Sp. Atk', 'Sp. Def', 'Speed']

const natureLabel = (name) => {
  const [up, down] = NATURES[name]
  return up === down ? `${name} (neutra)` : `${name} (+${STAT_NAMES[up]} −${STAT_NAMES[down]})`
}

const inputClass = 'w-full rounded-lg bg-surface px-2 py-1.5 text-sm outline-none focus:ring-2 focus:ring-sky-400'

function Field({ label, children }) {
  return (
    <label className="block">
      <span className="mb-1 block text-xs font-semibold text-muted">{label}</span>
      {children}
    </label>
  )
}

function Select({ value, onChange, options }) {
  return (
    <select value={value} onChange={(e) => onChange(e.target.value)} className={inputClass}>
      {options.map(([v, label]) => (
        <option key={v} value={v}>
          {label}
        </option>
      ))}
    </select>
  )
}

function NumberInput({ value, onChange, min, max }) {
  return (
    <input
      type="number"
      value={value}
      min={min}
      max={max}
      onChange={(e) => onChange(Math.max(min, Math.min(max, Number(e.target.value) || 0)))}
      className={inputClass}
    />
  )
}

function EvSlider({ label, value, onChange }) {
  return (
    <Field label={`${label}: ${value}`}>
      <div className="flex items-center gap-2">
        <input type="range" min={0} max={252} step={4} value={value} onChange={(e) => onChange(Number(e.target.value))} className="w-full accent-sky-500" />
        <button type="button" onClick={() => onChange(value === 252 ? 0 : 252)} className="cursor-pointer rounded-md bg-surface px-2 py-0.5 text-xs font-bold">
          {value === 252 ? '0' : '252'}
        </button>
      </div>
    </Field>
  )
}

const STAGES = Array.from({ length: 13 }, (_, i) => i - 6).map((s) => [String(s), s > 0 ? `+${s}` : String(s)])
const teraOptions = [['', 'Sem Tera'], ...TYPES.map((t) => [t, `Tera ${t}`])]

const newSide = (evs) => ({ level: 50, nature: 'Hardy', evs, ivs: 31, stage: 0, item: 'none', tera: '', burned: false })

/** Configuração de um lado (atacante ou defensor). */
function SideConfig({ title, side, setSide, attacker, physical }) {
  const set = (changes) => setSide({ ...side, ...changes })
  const setEv = (key, v) => set({ evs: { ...side.evs, [key]: v } })
  const offKey = physical ? 'atk' : 'spa'
  const defKey = physical ? 'def' : 'spd'
  return (
    <div className="rounded-3xl bg-card p-5 shadow-lg">
      <h3 className="mb-3 font-bold">{title}</h3>
      <div className="grid grid-cols-2 gap-3">
        <Field label="Nível">
          <NumberInput value={side.level} min={1} max={100} onChange={(v) => set({ level: v })} />
        </Field>
        <Field label="IVs (0 a 31)">
          <NumberInput value={side.ivs} min={0} max={31} onChange={(v) => set({ ivs: v })} />
        </Field>
        <div className="col-span-2">
          <Field label="Nature">
            <Select value={side.nature} onChange={(v) => set({ nature: v })} options={Object.keys(NATURES).map((n) => [n, natureLabel(n)])} />
          </Field>
        </div>
        {attacker ? (
          <div className="col-span-2">
            <EvSlider label={`EVs em ${physical ? 'Attack' : 'Sp. Atk'}`} value={side.evs[offKey] ?? 0} onChange={(v) => setEv(offKey, v)} />
          </div>
        ) : (
          <>
            <div className="col-span-2">
              <EvSlider label="EVs em HP" value={side.evs.hp ?? 0} onChange={(v) => setEv('hp', v)} />
            </div>
            <div className="col-span-2">
              <EvSlider label={`EVs em ${physical ? 'Defense' : 'Sp. Def'}`} value={side.evs[defKey] ?? 0} onChange={(v) => setEv(defKey, v)} />
            </div>
          </>
        )}
        <Field label={`Estágio de ${attacker ? (physical ? 'Attack' : 'Sp. Atk') : physical ? 'Defense' : 'Sp. Def'}`}>
          <Select value={String(side.stage)} onChange={(v) => set({ stage: Number(v) })} options={STAGES} />
        </Field>
        <Field label="Terastal">
          <Select value={side.tera} onChange={(v) => set({ tera: v })} options={teraOptions} />
        </Field>
        <div className="col-span-2">
          <Field label="Item">
            <Select value={side.item} onChange={(v) => set({ item: v })} options={Object.entries(attacker ? ITEMS : DEFENDER_ITEMS)} />
          </Field>
        </div>
        {attacker && (
          <label className="col-span-2 flex items-center gap-2 text-sm">
            <input type="checkbox" checked={side.burned} onChange={(e) => set({ burned: e.target.checked })} className="h-4 w-4 accent-orange-500" />
            Queimado (golpes físicos tiram metade)
          </label>
        )}
      </div>
    </div>
  )
}

/** Quanto de dano um golpe do atacante tira do defensor. */
export function DamageCalc() {
  const [attacker, setAttacker] = useState(null)
  const [defender, setDefender] = useState(null)
  const [picking, setPicking] = useState(null)
  const [moveName, setMoveName] = useState('')
  const [moves, setMoves] = useState(null)
  const [typeData, setTypeData] = useState(null)
  const [aSide, setASide] = useState(() => newSide({ atk: 252, spa: 252 }))
  const [dSide, setDSide] = useState(() => newSide({ hp: 0, def: 0, spd: 0 }))
  const [field, setField] = useState({ weather: 'none', crit: false, screen: false, spread: false })
  const a = usePokemonForm(attacker)
  const d = usePokemonForm(defender)

  useEffect(() => {
    getMoves().then(setMoves)
    getTypes().then(setTypeData)
  }, [])

  // Golpes de dano que o atacante aprende, do que mais machuca o defensor
  // (poder × STAB × efetividade × Attack ou Sp. Atk) ao que menos machuca.
  const options = useMemo(() => {
    if (!a || !moves) return []
    const names = [...new Set(a.moves.map((mv) => mv[0]))]
    const score = (mv) => {
      const stab = attacker.types.includes(mv.type) ? 1.5 : 1
      const eff = d && typeData ? effectiveness(mv.type, defender.types, typeData) : 1
      const stat = a.stats[mv.category === 'physical' ? 1 : 3][0]
      return mv.power * stab * eff * stat
    }
    return names
      .map((n) => moves[n])
      .filter((mv) => mv && mv.power > 0 && mv.category !== 'status')
      .map((mv) => ({ ...mv, score: score(mv) }))
      .sort((x, y) => y.score - x.score || x.name.localeCompare(y.name))
  }, [a, d, moves, typeData, attacker, defender])

  const move = options.find((mv) => mv.name === moveName) ?? options[0]
  const physical = move?.category !== 'special'
  const side = (s) => ({ ...s, ivs: { hp: s.ivs, atk: s.ivs, def: s.ivs, spa: s.ivs, spd: s.ivs }, tera: s.tera || null })
  const result =
    a && d && move && typeData
      ? damage({
          attacker: { types: attacker.types, stats: a.stats.map((x) => x[0]), ...side(aSide) },
          defender: { types: defender.types, stats: d.stats.map((x) => x[0]), ...side(dSide) },
          move,
          typeData,
          field,
        })
      : null

  const swap = () => {
    setAttacker(defender)
    setDefender(attacker)
    setMoveName('')
  }

  const multText = (mult) => (mult === 0 ? 'Não tem efeito' : mult >= 2 ? 'Super efetivo' : mult < 1 ? 'Pouco efetivo' : 'Efetivo')
  const setF = (changes) => setField((f) => ({ ...f, ...changes }))

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-[1fr_auto_1fr] items-center gap-3">
        <div className="space-y-2">
          <div className="text-center text-sm font-bold text-muted">Atacante</div>
          <Slot pokemon={attacker} label="Escolher atacante" onPick={() => setPicking('attacker')} />
        </div>
        <button
          type="button"
          onClick={swap}
          disabled={!attacker && !defender}
          title="Trocar atacante e defensor"
          className="grid h-11 w-11 cursor-pointer place-items-center rounded-full bg-card text-xl shadow hover:ring-2 hover:ring-sky-400 disabled:opacity-40"
        >
          ⇄
        </button>
        <div className="space-y-2">
          <div className="text-center text-sm font-bold text-muted">Defensor</div>
          <Slot pokemon={defender} label="Escolher defensor" onPick={() => setPicking('defender')} />
        </div>
      </div>

      {a && (
        <div className="rounded-3xl bg-card p-5 shadow-lg">
          <Field label="Golpe (os que mais machucam o defensor primeiro)">
            <select value={move?.name ?? ''} onChange={(e) => setMoveName(e.target.value)} className={inputClass}>
              {options.map((mv) => (
                <option key={mv.name} value={mv.name}>
                  {prettyName(mv.name)} · {mv.type} · {mv.category === 'physical' ? 'físico' : 'especial'} · {mv.power}
                </option>
              ))}
            </select>
          </Field>
        </div>
      )}

      {result && (
        <m.div initial={{ scale: 0.97, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} className="rounded-3xl bg-card p-6 shadow-lg">
          <div className="flex flex-wrap items-center gap-2 text-sm">
            <TypeBadge type={move.type} small />
            <span className="font-bold">{multText(result.mult)}</span>
            {result.mult !== 1 && result.mult !== 0 && <span className="text-muted">×{result.mult}</span>}
            {result.stab && <span className="rounded-full bg-sky-500/20 px-2 py-0.5 text-xs font-bold text-sky-400">STAB ×{result.stabMult}</span>}
            {field.crit && <span className="rounded-full bg-yellow-500/20 px-2 py-0.5 text-xs font-bold text-yellow-400">Crítico</span>}
          </div>
          <div className="mt-4 text-4xl font-black">
            {result.minPct}% – {result.maxPct}%
          </div>
          <div className="text-sm text-muted">
            {result.min}–{result.max} de {result.hp} HP
          </div>
          <div className="mt-3 h-4 overflow-hidden rounded-full bg-surface">
            <m.div
              className="h-full rounded-full"
              style={{ background: result.maxPct >= 100 ? '#e53935' : result.maxPct >= 50 ? '#fb8c00' : '#43a047' }}
              animate={{ width: `${Math.min(100, result.maxPct)}%` }}
            />
          </div>
          <p className="mt-3 text-lg font-bold">{koText(result)}</p>
          <details className="mt-3 text-sm text-muted">
            <summary className="cursor-pointer">Detalhes</summary>
            <p className="mt-2">
              Ataque usado: <b className="text-text">{result.attack}</b> · Defesa usada: <b className="text-text">{result.defense}</b> · HP:{' '}
              <b className="text-text">{result.hp}</b>
            </p>
            <p className="mt-1 break-words">Os 16 danos possíveis: {result.rolls.join(', ')}</p>
          </details>
        </m.div>
      )}

      {(attacker || defender) && (
        <div className="grid gap-4 lg:grid-cols-3">
          <SideConfig title="Atacante" side={aSide} setSide={setASide} attacker physical={physical} />
          <SideConfig title="Defensor" side={dSide} setSide={setDSide} physical={physical} />
          <div className="rounded-3xl bg-card p-5 shadow-lg">
            <h3 className="mb-3 font-bold">Campo</h3>
            <div className="space-y-3">
              <Field label="Clima">
                <Select value={field.weather} onChange={(v) => setF({ weather: v })} options={Object.entries(WEATHERS)} />
              </Field>
              {[
                ['crit', 'Golpe crítico (×1.5)'],
                ['screen', physical ? 'Reflect no defensor (×0.5)' : 'Light Screen no defensor (×0.5)'],
                ['spread', 'Golpe em área em batalha dupla (×0.75)'],
              ].map(([key, label]) => (
                <label key={key} className="flex items-center gap-2 text-sm">
                  <input type="checkbox" checked={field[key]} onChange={(e) => setF({ [key]: e.target.checked })} className="h-4 w-4 accent-sky-500" />
                  {label}
                </label>
              ))}
              <p className="pt-2 text-xs text-muted">Conta aproximada, igual à do jogo; não considera habilidades nem efeitos especiais de golpes.</p>
            </div>
          </div>
        </div>
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
