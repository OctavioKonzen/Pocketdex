// Tabela de tipos: escolha 1 ou 2 tipos para ver fraquezas e resistências, ou
// veja a tabela inteira (ataque × defesa).

import { useEffect, useState } from 'react'
import { getTypes } from '../../lib/data'
import { ALL_TYPES, capitalize, damageTaken, typeColor } from '../../lib/pokemon'
import { Loader, TypeBadge } from '../ui'

const GROUPS = [
  { mult: 4, label: 'Muito fraco (×4)', color: '#b91c1c' },
  { mult: 2, label: 'Fraco (×2)', color: '#ef4444' },
  { mult: 0.5, label: 'Resiste (×½)', color: '#22c55e' },
  { mult: 0.25, label: 'Resiste muito (×¼)', color: '#15803d' },
  { mult: 0, label: 'Imune (×0)', color: '#64748b' },
]
const CELL = { 0: ['0', '#334155'], 0.5: ['½', '#15803d'], 2: ['2', '#dc2626'] }

export default function TypeChart() {
  const [typeData, setTypeData] = useState(null)
  const [picked, setPicked] = useState(['fire'])
  useEffect(() => {
    getTypes().then(setTypeData)
  }, [])
  if (!typeData) return <Loader />

  const taken = damageTaken(picked, typeData)
  const toggle = (t) => setPicked((cur) => (cur.includes(t) ? (cur.length > 1 ? cur.filter((x) => x !== t) : cur) : [...cur.slice(-1), t]))
  const attack = (a, d) => {
    const rel = typeData[a]
    if (rel.no_damage_to.includes(d)) return 0
    if (rel.double_damage_to.includes(d)) return 2
    if (rel.half_damage_to.includes(d)) return 0.5
    return 1
  }

  return (
    <div className="space-y-6">
      <div className="rounded-3xl bg-card p-5 shadow">
        <p className="mb-3 text-sm text-muted">Escolha 1 ou 2 tipos (defesa):</p>
        <div className="grid grid-cols-3 gap-2 sm:grid-cols-6 lg:grid-cols-9">
          {ALL_TYPES.map((t) => (
            <button
              key={t}
              type="button"
              onClick={() => toggle(t)}
              className="cursor-pointer rounded-xl py-2 text-sm font-bold text-white"
              style={{ background: typeColor(t), opacity: picked.includes(t) ? 1 : 0.45, outline: picked.includes(t) ? '3px solid white' : 'none' }}
            >
              {capitalize(t)}
            </button>
          ))}
        </div>
        <div className="mt-5 grid gap-3 md:grid-cols-2">
          {GROUPS.map((g) => {
            const list = ALL_TYPES.filter((t) => taken[t] === g.mult)
            if (!list.length) return null
            return (
              <div key={g.mult} className="rounded-2xl bg-surface p-3">
                <div className="mb-2 text-sm font-bold" style={{ color: g.color }}>
                  {g.label}
                </div>
                <div className="flex flex-wrap gap-1.5">
                  {list.map((t) => (
                    <TypeBadge key={t} type={t} small />
                  ))}
                </div>
              </div>
            )
          })}
        </div>
      </div>

      <div className="overflow-x-auto rounded-3xl bg-card p-4 shadow">
        <p className="mb-2 text-sm text-muted">Tabela completa: linha = tipo do golpe, coluna = tipo de quem recebe.</p>
        <table className="border-separate border-spacing-0.5 text-[11px]">
          <thead>
            <tr>
              <th />
              {ALL_TYPES.map((d) => (
                <th key={d} className="h-16 w-7 align-bottom">
                  <span className="inline-block origin-bottom-left translate-x-3 -rotate-60 font-bold whitespace-nowrap" style={{ color: typeColor(d) }}>
                    {capitalize(d)}
                  </span>
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {ALL_TYPES.map((a) => (
              <tr key={a}>
                <th className="pr-2 text-right font-bold whitespace-nowrap" style={{ color: typeColor(a) }}>
                  {capitalize(a)}
                </th>
                {ALL_TYPES.map((d) => {
                  const v = attack(a, d)
                  const [text, bg] = CELL[v] ?? ['', 'transparent']
                  return (
                    <td
                      key={d}
                      className={`h-7 w-7 rounded text-center font-black text-white ${picked.includes(d) ? 'ring-1 ring-white/70' : ''}`}
                      style={{ background: v === 1 ? 'var(--surface)' : bg }}
                    >
                      {text}
                    </td>
                  )
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
