// Editor completo de um Pokémon do time: apelido, nível, gênero, shiny,
// habilidade, item, Nature, tipo Tera, 4 golpes, EVs e IVs (com os status
// finais). Salva a cada mudança.

import { useEffect, useMemo, useState } from 'react'
import { getItems, getMoves } from '../lib/data'
import { prettyName } from '../lib/pokemon'
import { evTotal, NATURES, natureLabel, normalizeSet, POPULAR_ITEMS, prettySlug, STAT_KEYS, STAT_NAMES, statValue, TERA_TYPES } from '../lib/teamSets'
import { usePokemonForm } from './BattleTools'
import Sprite from './Sprite'
import { Button, Modal, TypeBadge } from './ui'

const input = 'w-full rounded-lg bg-surface px-2 py-1.5 text-sm outline-none focus:ring-2 focus:ring-sky-400'
const HELD_CATEGORIES = new Set(['standard-balls', 'special-balls', 'apricorn-balls', 'all-machines', 'plot-advancement', 'event-items', 'gameplay', 'unused', 'data-cards', 'dex-completion', 'mulch', 'apricorn-box', 'spelunking', 'curry-ingredients', 'sandwich-ingredients', 'picnic', 'tm-materials', 'catching-bonus', 'z-crystals', 'dynamax-crystals', 'nature-mint', 'species-candies', 'collectibles', 'loot'])

function Field({ label, children, className = '' }) {
  return (
    <label className={`block ${className}`}>
      <span className="mb-1 block text-xs font-semibold text-muted">{label}</span>
      {children}
    </label>
  )
}

function Num({ value, min, max, onChange, className = input }) {
  return (
    <input
      type="number"
      inputMode="numeric"
      min={min}
      max={max}
      value={value}
      onChange={(e) => {
        const n = Number(e.target.value)
        if (Number.isFinite(n)) onChange(Math.min(max, Math.max(min, Math.round(n))))
      }}
      className={className}
    />
  )
}

/** Campo com sugestões: mostra nomes bonitos e guarda o slug. */
function SlugInput({ id, value, onChange, options, placeholder }) {
  const [text, setText] = useState(prettySlug(value))
  useEffect(() => setText(prettySlug(value)), [value])
  const bySimple = useMemo(() => new Map(options.map((o) => [prettySlug(o).toLowerCase(), o])), [options])
  return (
    <>
      <input
        list={id}
        value={text}
        placeholder={placeholder}
        onChange={(e) => {
          setText(e.target.value)
          const slug = bySimple.get(e.target.value.trim().toLowerCase())
          if (slug) onChange(slug)
          else if (!e.target.value.trim()) onChange('')
        }}
        onBlur={() => setText(prettySlug(value))}
        className={input}
      />
      <datalist id={id}>
        {options.map((o) => (
          <option key={o} value={prettySlug(o)} />
        ))}
      </datalist>
    </>
  )
}

export default function TeamMemberEditor({ open, pokemon, set, onChange, onClose, onRemove, onSwap }) {
  const form = usePokemonForm(open ? pokemon : null)
  const [moves, setMoves] = useState(null)
  const [items, setItems] = useState(null)

  useEffect(() => {
    if (!open) return
    getMoves().then(setMoves)
    getItems().then((all) => {
      const held = all.filter((i) => i.attributes?.includes('holdable') && !HELD_CATEGORIES.has(i.category)).map((i) => i.name)
      setItems([...new Set([...POPULAR_ITEMS.filter((p) => held.includes(p)), ...held.sort()])])
    })
  }, [open])

  if (!pokemon || !set) return null
  const s = normalizeSet(set)
  const update = (changes) => onChange({ ...s, ...changes })
  const setStat = (group, key, value) => update({ [group]: { ...s[group], [key]: value } })
  const base = form?.stats?.map((x) => x[0]) ?? null
  const learnable = form ? [...new Set(form.moves.map((mv) => mv[0]))].sort() : []
  const [up, down] = NATURES[s.nature]
  const total = evTotal(s)
  const sprite = s.shiny && form?.sprites?.[1] ? form.sprites[1] : pokemon.sprite

  return (
    <Modal open={open} onClose={onClose} title={s.nickname || prettyName(pokemon.name)} wide>
      <div className="grid gap-5 overflow-y-auto px-6 pb-6 md:grid-cols-[220px_1fr]">
        <div className="flex flex-col items-center gap-2">
          <Sprite path={sprite} box={s.shiny ? form?.boxes?.[1] : pokemon.box} fill={0.9} className="h-40 w-40" />
          <div className="text-lg font-black">{prettyName(pokemon.name)}</div>
          <div className="flex gap-1">
            {pokemon.types.map((t) => (
              <TypeBadge key={t} type={t} small />
            ))}
          </div>
          <div className="mt-2 flex flex-wrap justify-center gap-2">
            <Button color="#546E7A" onClick={onSwap}>
              Trocar Pokémon
            </Button>
            <Button color="#e53935" onClick={onRemove}>
              Remover
            </Button>
          </div>
        </div>

        <div className="space-y-4">
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
            <Field label="Apelido" className="col-span-2">
              <input value={s.nickname} maxLength={18} onChange={(e) => update({ nickname: e.target.value })} placeholder={prettyName(pokemon.name)} className={input} />
            </Field>
            <Field label="Nível">
              <Num value={s.level} min={1} max={100} onChange={(v) => update({ level: v })} />
            </Field>
            <Field label="Gênero">
              <select value={s.gender} onChange={(e) => update({ gender: e.target.value })} className={input}>
                <option value="">—</option>
                <option value="M">♂ Macho</option>
                <option value="F">♀ Fêmea</option>
              </select>
            </Field>
            <Field label="Habilidade" className="col-span-2">
              <select value={s.ability} onChange={(e) => update({ ability: e.target.value })} className={input}>
                <option value="">—</option>
                {(form?.abilities ?? []).map(([slug, hidden]) => (
                  <option key={slug} value={slug}>
                    {prettySlug(slug)}
                    {hidden ? ' (oculta)' : ''}
                  </option>
                ))}
                {s.ability && form && !form.abilities.some(([a]) => a === s.ability) && <option value={s.ability}>{prettySlug(s.ability)}</option>}
              </select>
            </Field>
            <Field label="Item" className="col-span-2">
              <SlugInput id="member-items" value={s.item} onChange={(v) => update({ item: v })} options={items ?? []} placeholder="Nenhum" />
            </Field>
            <Field label="Nature" className="col-span-2">
              <select value={s.nature} onChange={(e) => update({ nature: e.target.value })} className={input}>
                {Object.keys(NATURES).map((n) => (
                  <option key={n} value={n}>
                    {natureLabel(n)}
                  </option>
                ))}
              </select>
            </Field>
            <Field label="Tipo Tera">
              <select value={s.tera} onChange={(e) => update({ tera: e.target.value })} className={input}>
                <option value="">—</option>
                {TERA_TYPES.map((t) => (
                  <option key={t} value={t}>
                    {prettySlug(t)}
                  </option>
                ))}
              </select>
            </Field>
            <label className="flex items-end gap-2 pb-2 text-sm">
              <input type="checkbox" checked={s.shiny} onChange={(e) => update({ shiny: e.target.checked })} className="h-4 w-4 accent-yellow-400" />
              Shiny ✨
            </label>
          </div>

          <div>
            <div className="mb-1 text-xs font-semibold text-muted">Golpes</div>
            <div className="grid gap-2 sm:grid-cols-2">
              {s.moves.map((mv, i) => {
                const info = mv && moves?.[mv]
                return (
                  <div key={i} className="flex items-center gap-2">
                    <div className="flex-1">
                      <SlugInput
                        id="member-moves"
                        value={mv}
                        onChange={(v) => update({ moves: s.moves.map((x, j) => (j === i ? v : x)) })}
                        options={learnable}
                        placeholder={`Golpe ${i + 1}`}
                      />
                    </div>
                    {info && (
                      <span className="flex shrink-0 items-center gap-1 text-xs text-muted">
                        <TypeBadge type={info.type} small />
                        {info.power ?? '—'}
                      </span>
                    )}
                  </div>
                )
              })}
            </div>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-xs text-muted">
                  <th className="text-left font-semibold">Status</th>
                  <th className="font-semibold">Base</th>
                  <th className="font-semibold">EVs</th>
                  <th className="font-semibold">IVs</th>
                  <th className="text-right font-semibold">Final</th>
                </tr>
              </thead>
              <tbody>
                {STAT_KEYS.map((key, i) => {
                  const mark = up !== down && i === up ? '+' : up !== down && i === down ? '−' : ''
                  return (
                    <tr key={key}>
                      <td className="py-0.5 pr-2 font-bold whitespace-nowrap">
                        {STAT_NAMES[key]}
                        <span className={mark === '+' ? 'text-green-500' : 'text-red-500'}>{mark}</span>
                      </td>
                      <td className="text-center text-muted tabular-nums">{base ? base[i] : '—'}</td>
                      <td className="px-1 py-0.5">
                        <Num value={s.evs[key]} min={0} max={252} onChange={(v) => setStat('evs', key, v)} className={`${input} w-20`} />
                      </td>
                      <td className="px-1 py-0.5">
                        <Num value={s.ivs[key]} min={0} max={31} onChange={(v) => setStat('ivs', key, v)} className={`${input} w-16`} />
                      </td>
                      <td className="py-0.5 text-right font-bold tabular-nums">{base ? statValue(base, i, s) : '—'}</td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
            <p className={`mt-1 text-xs ${total > 510 ? 'font-bold text-red-500' : 'text-muted'}`}>EVs usados: {total} de 510</p>
          </div>
        </div>
      </div>
    </Modal>
  )
}
