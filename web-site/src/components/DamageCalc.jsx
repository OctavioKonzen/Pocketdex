// Calculadora de dano completa (Treino → Calculadora de dano), com a conta
// oficial do Pokémon Showdown (lib/damageCalc.js).

import { m } from 'framer-motion'
import { useEffect, useMemo, useState } from 'react'
import { getMoves } from '../lib/data'
import { prettyName } from '../lib/pokemon'
import { Slot, usePokemonForm } from './BattleTools'
import PokemonPicker from './PokemonPicker'
import { Loader, TypeBadge } from './ui'

const TYPES = ['normal', 'fire', 'water', 'electric', 'grass', 'ice', 'fighting', 'poison', 'ground', 'flying', 'psychic', 'bug', 'rock', 'ghost', 'dragon', 'dark', 'steel', 'fairy', 'stellar']
const NATURES = {
  Hardy: [0, 0], Lonely: [1, 2], Brave: [1, 5], Adamant: [1, 3], Naughty: [1, 4],
  Bold: [2, 1], Docile: [0, 0], Relaxed: [2, 5], Impish: [2, 3], Lax: [2, 4],
  Timid: [5, 1], Hasty: [5, 2], Serious: [0, 0], Jolly: [5, 3], Naive: [5, 4],
  Modest: [3, 1], Mild: [3, 2], Quiet: [3, 5], Bashful: [0, 0], Rash: [3, 4],
  Calm: [4, 1], Gentle: [4, 2], Sassy: [4, 5], Careful: [4, 3], Quirky: [0, 0],
}
const STAT_SHORT = ['HP', 'Atk', 'Def', 'SpA', 'SpD', 'Spe']
const natureLabel = (name) => {
  const [up, down] = NATURES[name]
  return up === down ? `${name} (neutra)` : `${name} (+${STAT_SHORT[up]} −${STAT_SHORT[down]})`
}
const inputClass = 'w-full rounded-lg bg-surface px-2 py-1.5 text-sm outline-none focus:ring-2 focus:ring-sky-400'

function Field({ label, children, className = '' }) {
  return (
    <label className={`block ${className}`}>
      <span className="mb-1 block text-xs font-semibold text-muted">{label}</span>
      {children}
    </label>
  )
}

function Select({ value, onChange, options, className = inputClass }) {
  return (
    <select value={value} onChange={(e) => onChange(e.target.value)} className={className}>
      {options.map(([v, label]) => (
        <option key={v} value={v}>
          {label}
        </option>
      ))}
    </select>
  )
}

function Num({ value, onChange, min, max, step = 1, className = inputClass }) {
  return (
    <input
      type="number"
      value={value}
      min={min}
      max={max}
      step={step}
      onChange={(e) => onChange(Math.max(min, Math.min(max, Number(e.target.value) || 0)))}
      className={className}
    />
  )
}

function Check({ checked, onChange, children }) {
  return (
    <label className="flex cursor-pointer items-center gap-2 text-sm select-none">
      <input type="checkbox" checked={checked} onChange={(e) => onChange(e.target.checked)} className="h-4 w-4 accent-sky-500" />
      {children}
    </label>
  )
}

/** Caixa de texto com sugestões (habilidade, item, golpe). */
function Suggest({ id, value, onChange, options, placeholder }) {
  const [text, setText] = useState(value)
  useEffect(() => setText(value), [value])
  return (
    <>
      <input
        list={id}
        value={text}
        placeholder={placeholder}
        onChange={(e) => {
          setText(e.target.value)
          onChange(e.target.value)
        }}
        className={inputClass}
      />
      <datalist id={id}>
        {options.map((o) => (
          <option key={o} value={o} />
        ))}
      </datalist>
    </>
  )
}

const BOOSTS = Array.from({ length: 13 }, (_, i) => i - 6).map((s) => [String(s), s > 0 ? `+${s}` : String(s)])

/** Status base de uma forma no formato da calculadora. */
const baseOf = (pokemon, form) => ({ name: form.name ?? pokemon.name, types: form.types, stats: form.stats.map((s) => s[0]), weight: form.weight })

/** Configuração de um lado (os dois lados têm as mesmas opções). */
function SidePanel({ title, calc, pokemon, form, side, setSide, accent }) {
  const set = (changes) => setSide({ ...side, ...changes })
  const setIn = (group, key, value) => set({ [group]: { ...side[group], [key]: value } })
  const own = (form?.abilities ?? []).map(([slug]) => calc.abilityName(slug)).filter(Boolean)
  const stats = pokemon && form ? calc.sideStats(baseOf(pokemon, form), side) : null
  const evTotal = Object.values(side.evs).reduce((a, b) => a + b, 0)
  const toggle = calc.TOGGLE_ABILITIES[side.ability]
  return (
    <div className="rounded-3xl bg-card p-5 shadow-lg">
      <h3 className="mb-3 font-bold" style={{ color: accent }}>
        {title}
        {pokemon ? ` · ${prettyName(pokemon.name)}` : ''}
      </h3>
      <div className="grid grid-cols-2 gap-3">
        <Field label="Nível">
          <Num value={side.level} min={1} max={100} onChange={(v) => set({ level: v })} />
        </Field>
        <Field label="Nature">
          <Select value={side.nature} onChange={(v) => set({ nature: v })} options={Object.keys(NATURES).map((n) => [n, natureLabel(n)])} />
        </Field>

        <Field label="Habilidade" className="col-span-2">
          <Suggest id={`ab-${title}`} value={side.ability} onChange={(v) => set({ ability: calc.abilityName(v) || v, abilityOn: false })} options={[...own, ...calc.ALL_ABILITIES]} placeholder="Nenhuma" />
          {own.length > 1 && (
            <div className="mt-1 flex flex-wrap gap-1">
              {own.map((a) => (
                <button
                  key={a}
                  type="button"
                  onClick={() => set({ ability: a, abilityOn: false })}
                  className={`cursor-pointer rounded-full px-2 py-0.5 text-xs font-bold ${side.ability === a ? 'bg-sky-500 text-white' : 'bg-surface'}`}
                >
                  {a}
                </button>
              ))}
            </div>
          )}
        </Field>
        {toggle && (
          <div className="col-span-2">
            <Check checked={side.abilityOn} onChange={(v) => set({ abilityOn: v })}>
              {toggle}
            </Check>
          </div>
        )}

        <Field label="Item" className="col-span-2">
          <Suggest id={`it-${title}`} value={side.item} onChange={(v) => set({ item: calc.itemName(v) || (v ? v : '') })} options={calc.ALL_ITEMS} placeholder="Nenhum" />
        </Field>

        <Field label="Tipo Tera">
          <Select value={side.teraType} onChange={(v) => set({ teraType: v, terastallized: Boolean(v) })} options={[['', '—'], ...TYPES.map((t) => [t, prettyName(t)])]} />
        </Field>
        <div className="flex items-end pb-1.5">
          <Check checked={side.terastallized} onChange={(v) => set({ terastallized: v })}>
            Terastalizado
          </Check>
        </div>

        <Field label="Status">
          <Select value={side.status} onChange={(v) => set({ status: v })} options={calc.STATUSES} />
        </Field>
        <Field label={`HP atual: ${side.hpPct}%${stats ? ` (${stats.curHP}/${stats.maxHP})` : ''}`}>
          <input type="range" min={1} max={100} value={side.hpPct} onChange={(e) => set({ hpPct: Number(e.target.value) })} className="w-full accent-green-500" />
        </Field>
      </div>

      <div className="mt-4 overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="text-xs text-muted">
              <th className="text-left font-semibold" />
              <th className="font-semibold">EVs</th>
              <th className="font-semibold">IVs</th>
              <th className="font-semibold">Estágio</th>
              <th className="text-right font-semibold">Final</th>
            </tr>
          </thead>
          <tbody>
            {calc.STAT_KEYS.map((key, i) => {
              const [up, down] = NATURES[side.nature]
              const mark = up !== down && i === up ? '+' : up !== down && i === down ? '−' : ''
              return (
                <tr key={key}>
                  <td className="py-0.5 pr-2 font-bold whitespace-nowrap">
                    {calc.STAT_LABELS[key]}
                    <span className={mark === '+' ? 'text-green-500' : 'text-red-500'}>{mark}</span>
                  </td>
                  <td className="px-1 py-0.5">
                    <Num value={side.evs[key]} min={0} max={252} step={4} onChange={(v) => setIn('evs', key, v)} className={`${inputClass} w-16`} />
                  </td>
                  <td className="px-1 py-0.5">
                    <Num value={side.ivs[key]} min={0} max={31} onChange={(v) => setIn('ivs', key, v)} className={`${inputClass} w-14`} />
                  </td>
                  <td className="px-1 py-0.5">
                    {key === 'hp' ? null : (
                      <Select value={String(side.boosts[key])} onChange={(v) => setIn('boosts', key, Number(v))} options={BOOSTS} className={`${inputClass} w-16`} />
                    )}
                  </td>
                  <td className="py-0.5 text-right font-bold tabular-nums">{stats ? (key === 'hp' ? stats.maxHP : stats.stats[key]) : '—'}</td>
                </tr>
              )
            })}
          </tbody>
        </table>
        <p className={`mt-1 text-xs ${evTotal > 510 ? 'font-bold text-red-500' : 'text-muted'}`}>EVs usados: {evTotal} de 510</p>
      </div>

      <details className="mt-3 text-sm">
        <summary className="cursor-pointer text-muted">Mais opções</summary>
        <div className="mt-2">
          <Field label="Aliados já derrotados (Supreme Overlord, Last Respects)">
            <Num value={side.alliesFainted} min={0} max={5} onChange={(v) => set({ alliesFainted: v })} />
          </Field>
        </div>
      </details>
    </div>
  )
}

const FIELD_BOXES = {
  gerais: [
    ['trickRoom', 'Trick Room'],
    ['gravity', 'Gravity'],
    ['magicRoom', 'Magic Room'],
    ['wonderRoom', 'Wonder Room'],
    ['fairyAura', 'Fairy Aura'],
    ['darkAura', 'Dark Aura'],
    ['auraBreak', 'Aura Break'],
    ['swordOfRuin', 'Sword of Ruin'],
    ['beadsOfRuin', 'Beads of Ruin'],
    ['tabletsOfRuin', 'Tablets of Ruin'],
    ['vesselOfRuin', 'Vessel of Ruin'],
  ],
  atacante: [
    ['helpingHand', 'Helping Hand'],
    ['charge', 'Charge'],
    ['battery', 'Battery (aliado)'],
    ['powerSpot', 'Power Spot (aliado)'],
    ['steelySpirit', 'Steely Spirit (aliado)'],
    ['flowerGift', 'Flower Gift (aliado)'],
    ['attackerTailwind', 'Tailwind'],
  ],
  defensor: [
    ['reflect', 'Reflect'],
    ['lightScreen', 'Light Screen'],
    ['auroraVeil', 'Aurora Veil'],
    ['friendGuard', 'Friend Guard (aliado)'],
    ['protect', 'Protect'],
    ['stealthRock', 'Stealth Rock'],
    ['saltCure', 'Salt Cure'],
    ['leechSeed', 'Leech Seed'],
    ['defenderTailwind', 'Tailwind'],
    ['switchingOut', 'Saindo da batalha (Pursuit)'],
  ],
}

function FieldPanel({ calc, field, setField }) {
  const set = (changes) => setField({ ...field, ...changes })
  const boxes = (list) => (
    <div className="grid grid-cols-2 gap-x-3 gap-y-1.5">
      {list.map(([key, label]) => (
        <Check key={key} checked={field[key]} onChange={(v) => set({ [key]: v })}>
          {label}
        </Check>
      ))}
    </div>
  )
  return (
    <div className="rounded-3xl bg-card p-5 shadow-lg">
      <h3 className="mb-3 font-bold">Campo</h3>
      <div className="grid grid-cols-2 gap-3">
        <Field label="Batalha">
          <Select value={field.gameType} onChange={(v) => set({ gameType: v })} options={[['Singles', 'Simples'], ['Doubles', 'Dupla']]} />
        </Field>
        <Field label="Spikes no defensor">
          <Select value={String(field.spikes)} onChange={(v) => set({ spikes: Number(v) })} options={[0, 1, 2, 3].map((n) => [String(n), n ? `${n} camada${n > 1 ? 's' : ''}` : 'Nenhum'])} />
        </Field>
        <Field label="Clima">
          <Select value={field.weather} onChange={(v) => set({ weather: v })} options={calc.WEATHERS} />
        </Field>
        <Field label="Terreno">
          <Select value={field.terrain} onChange={(v) => set({ terrain: v })} options={calc.TERRAINS} />
        </Field>
      </div>
      <div className="mt-4 space-y-3 text-sm">
        <div>
          <div className="mb-1 text-xs font-bold text-muted">Campo todo</div>
          {boxes(FIELD_BOXES.gerais)}
        </div>
        <div>
          <div className="mb-1 text-xs font-bold text-muted">Lado do atacante</div>
          {boxes(FIELD_BOXES.atacante)}
        </div>
        <div>
          <div className="mb-1 text-xs font-bold text-muted">Lado do defensor</div>
          {boxes(FIELD_BOXES.defensor)}
        </div>
      </div>
    </div>
  )
}

const barColor = (pct) => (pct >= 100 ? '#e53935' : pct >= 50 ? '#fb8c00' : '#43a047')

/** Um golpe na lista: nome, tipo e quanto tira. */
function MoveRow({ result, active, onClick }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`flex w-full cursor-pointer items-center gap-2 rounded-xl px-3 py-2 text-left text-sm transition ${active ? 'bg-sky-500/20 ring-2 ring-sky-400' : 'hover:bg-surface'}`}
    >
      <TypeBadge type={result.type} small />
      <span className="min-w-0 flex-1 truncate font-bold">{result.name}</span>
      <span className="text-xs text-muted tabular-nums">{result.noDamage ? '—' : `${result.minPct}–${result.maxPct}%`}</span>
    </button>
  )
}

export default function DamageCalc() {
  const [calc, setCalc] = useState(null)
  const [moves, setMoves] = useState(null)
  const [attacker, setAttacker] = useState(null)
  const [defender, setDefender] = useState(null)
  const [picking, setPicking] = useState(null)
  const [aSide, setASide] = useState(null)
  const [dSide, setDSide] = useState(null)
  const [field, setField] = useState(null)
  const [moveSlug, setMoveSlug] = useState('')
  const [moveOptions, setMoveOptions] = useState(null)
  const [otherMove, setOtherMove] = useState('')
  const [copied, setCopied] = useState(false)
  const a = usePokemonForm(attacker)
  const d = usePokemonForm(defender)

  // Trocar para uma habilidade de clima/terreno muda o campo (como no Showdown).
  const withFieldAbility = (setSide) => (next) =>
    setSide((prev) => {
      const value = typeof next === 'function' ? next(prev) : next
      const effect = calc?.ABILITY_FIELD[value.ability]
      if (effect && value.ability !== prev?.ability) setField((f) => ({ ...f, ...effect }))
      return value
    })
  const setAttackerSide = withFieldAbility(setASide)
  const setDefenderSide = withFieldAbility(setDSide)

  useEffect(() => {
    import('../lib/damageCalc').then((mod) => {
      setCalc(mod)
      setASide(mod.newSide({ atk: 252, spa: 252, spe: 4 }))
      setDSide(mod.newSide({ hp: 252, def: 4 }))
      setField(mod.newField())
      setMoveOptions(mod.newMoveOptions())
    })
    getMoves().then(setMoves)
  }, [])

  // Habilidade padrão: a primeira da forma escolhida.
  const firstAbility = (form) => (calc && form?.abilities?.length ? calc.abilityName(form.abilities[0][0]) : '')
  useEffect(() => {
    if (a && calc) setAttackerSide((s) => ({ ...s, ability: firstAbility(a) }))
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [a, calc])
  useEffect(() => {
    if (d && calc) setDefenderSide((s) => ({ ...s, ability: firstAbility(d) }))
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [d, calc])

  const ready = calc && aSide && dSide && field && moveOptions
  const aBase = attacker && a ? baseOf(attacker, a) : null
  const dBase = defender && d ? baseOf(defender, d) : null

  // Todos os golpes de dano que o atacante aprende, do que mais tira ao que menos tira.
  const results = useMemo(() => {
    if (!ready || !aBase || !dBase || !moves) return []
    const slugs = [...new Set(a.moves.map((mv) => mv[0]))].filter((slug) => {
      const mv = moves[slug]
      const data = calc.moveData(slug)
      return mv && data && data.category !== 'Status'
    })
    const base = { attacker: aBase, attackerSide: aSide, defender: dBase, defenderSide: dSide, field, moveOptions: calc.newMoveOptions() }
    return slugs
      .map((slug) => ({ slug, result: calc.run({ ...base, moveSlug: slug }) }))
      .filter((x) => x.result)
      .sort((x, y) => y.result.maxPct - x.result.maxPct || x.result.name.localeCompare(y.result.name))
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ready, aBase?.name, dBase?.name, a, d, moves, aSide, dSide, field])

  const current = moveSlug || results[0]?.slug || ''
  const hitRange = ready && current ? calc.hitRange(current) : null
  const result =
    ready && aBase && dBase && current
      ? calc.run({ attacker: aBase, attackerSide: aSide, defender: dBase, defenderSide: dSide, moveSlug: current, moveOptions, field })
      : null

  const pickMove = (slug) => {
    setMoveSlug(slug)
    setMoveOptions(calc.newMoveOptions())
    setCopied(false)
  }

  const swap = () => {
    setAttacker(defender)
    setDefender(attacker)
    setASide(dSide)
    setDSide(aSide)
    setField((f) => ({ ...f, attackerTailwind: f.defenderTailwind, defenderTailwind: f.attackerTailwind }))
    setMoveSlug('')
  }

  if (!ready) return <Loader className="mx-auto" />

  const setOpt = (changes) => setMoveOptions((o) => ({ ...o, ...changes }))
  const speedA = result?.attackerStats?.spe
  const speedD = result?.defenderStats?.spe

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

      {a && d && (
        <div className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.3fr)]">
          <div className="rounded-3xl bg-card p-4 shadow-lg">
            <h3 className="mb-2 px-1 font-bold">Golpes de {prettyName(attacker.name)}</h3>
            <div className="max-h-[28rem] space-y-1 overflow-y-auto pr-1">
              {results.map(({ slug, result: r }) => (
                <MoveRow key={slug} result={r} active={slug === current} onClick={() => pickMove(slug)} />
              ))}
              {!results.length && <p className="px-1 text-sm text-muted">Nenhum golpe de dano.</p>}
            </div>
            <div className="mt-3">
              <Field label="Outro golpe (qualquer um)">
                <Suggest
                  id="other-move"
                  value={otherMove}
                  onChange={(v) => {
                    setOtherMove(v)
                    const slug = moves && Object.keys(moves).find((k) => calc.toId(k) === calc.toId(v))
                    if (slug && calc.moveData(slug)) pickMove(slug)
                  }}
                  options={moves ? Object.keys(moves).map(prettyName) : []}
                  placeholder="Digite o nome do golpe"
                />
              </Field>
            </div>
          </div>

          {result && (
            <m.div key={current} initial={{ scale: 0.98, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} className="rounded-3xl bg-card p-6 shadow-lg">
              <div className="flex flex-wrap items-center gap-2 text-sm">
                <span className="text-lg font-black">{result.name}</span>
                <TypeBadge type={result.type} small />
                <span className="text-muted">
                  {result.category === 'Physical' ? 'Físico' : 'Especial'} · poder {result.bp}
                  {result.hits > 1 ? ` · ${result.hits} acertos` : ''}
                </span>
              </div>
              {result.noDamage ? (
                <p className="mt-4 text-2xl font-black">Não causa dano.</p>
              ) : (
                <>
                  <div className="mt-4 text-4xl font-black">
                    {result.minPct}% – {result.maxPct}%
                  </div>
                  <div className="text-sm text-muted">
                    {result.min}–{result.max} de {result.hp} HP
                    {result.curHP < result.hp ? ` (HP atual: ${result.curHP})` : ''}
                  </div>
                  <div className="mt-3 h-4 overflow-hidden rounded-full bg-surface">
                    <m.div className="h-full rounded-full" style={{ background: barColor(result.maxPct) }} animate={{ width: `${Math.min(100, result.maxPct)}%` }} />
                  </div>
                  <p className="mt-3 text-lg font-bold">{result.koText}</p>
                </>
              )}
              {speedA != null && speedD != null && (
                <p className="mt-2 text-sm text-muted">
                  Velocidade: {prettyName(attacker.name)} {speedA} × {speedD} {prettyName(defender.name)} —{' '}
                  {speedA === speedD
                    ? 'empate'
                    : `${prettyName((speedA > speedD !== field.trickRoom ? attacker : defender).name)} age primeiro${field.trickRoom ? ' (Trick Room)' : ''}`}
                </p>
              )}

              <div className="mt-4 flex flex-wrap gap-x-4 gap-y-2 border-t border-white/10 pt-4">
                <Check checked={moveOptions.crit} onChange={(v) => setOpt({ crit: v })}>
                  Golpe crítico
                </Check>
                {hitRange && hitRange[0] !== hitRange[1] && (
                  <label className="flex items-center gap-2 text-sm">
                    Acertos
                    <Select
                      value={String(moveOptions.hits || '')}
                      onChange={(v) => setOpt({ hits: Number(v) })}
                      options={[['', 'Padrão'], ...Array.from({ length: hitRange[1] - hitRange[0] + 1 }, (_, i) => [String(hitRange[0] + i), String(hitRange[0] + i)])]}
                      className={`${inputClass} w-24`}
                    />
                  </label>
                )}
                <label className="flex items-center gap-2 text-sm">
                  Vezes seguidas
                  <Num value={moveOptions.timesUsed} min={1} max={5} onChange={(v) => setOpt({ timesUsed: v })} className={`${inputClass} w-16`} />
                </label>
                {aSide.item === 'Metronome' && (
                  <label className="flex items-center gap-2 text-sm">
                    Usos com Metronome
                    <Num value={moveOptions.metronome} min={1} max={6} onChange={(v) => setOpt({ metronome: v })} className={`${inputClass} w-16`} />
                  </label>
                )}
                {aSide.terastallized && aSide.teraType === 'stellar' && (
                  <Check checked={moveOptions.stellarFirst} onChange={(v) => setOpt({ stellarFirst: v })}>
                    Primeiro uso do tipo (Stellar)
                  </Check>
                )}
              </div>

              {result.desc && (
                <div className="mt-4 rounded-xl bg-surface p-3 text-xs">
                  <div className="mb-1 flex items-center justify-between gap-2">
                    <span className="font-bold text-muted">Descrição no formato do Showdown</span>
                    <button
                      type="button"
                      onClick={() => {
                        navigator.clipboard?.writeText(result.desc)
                        setCopied(true)
                      }}
                      className="cursor-pointer rounded-md bg-card px-2 py-0.5 font-bold"
                    >
                      {copied ? 'Copiado!' : 'Copiar'}
                    </button>
                  </div>
                  <p className="break-words">{result.desc}</p>
                </div>
              )}
              {!result.noDamage && (
                <details className="mt-3 text-sm text-muted">
                  <summary className="cursor-pointer">Os 16 danos possíveis</summary>
                  {result.rolls.map((hit, i) => (
                    <p key={i} className="mt-1 break-words">
                      {result.rolls.length > 1 ? `Acerto ${i + 1}: ` : ''}
                      {hit.join(', ')}
                    </p>
                  ))}
                </details>
              )}
            </m.div>
          )}
        </div>
      )}

      {(attacker || defender) && (
        <div className="grid gap-4 lg:grid-cols-3">
          <SidePanel title="Atacante" calc={calc} pokemon={attacker} form={a} side={aSide} setSide={setAttackerSide} accent="#ef5350" />
          <SidePanel title="Defensor" calc={calc} pokemon={defender} form={d} side={dSide} setSide={setDefenderSide} accent="#42a5f5" />
          <FieldPanel calc={calc} field={field} setField={setField} />
        </div>
      )}

      <p className="text-center text-xs text-muted">Conta oficial do Pokémon Showdown (geração 9), com habilidades, itens, campo e golpes especiais.</p>

      <PokemonPicker
        open={picking !== null}
        onClose={() => setPicking(null)}
        onPick={(p) => {
          if (picking === 'attacker') {
            setAttacker(p)
            setMoveSlug('')
          } else setDefender(p)
          setPicking(null)
        }}
      />
    </div>
  )
}
