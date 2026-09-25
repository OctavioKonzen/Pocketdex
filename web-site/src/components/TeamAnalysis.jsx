// Análise do time (defesa e ataque por tipo) e a nota da comunidade (estrelas).

import { m } from 'framer-motion'
import { useState } from 'react'
import { rowSummary } from '../lib/pokemon'
import { TypeBadge } from './ui'

/** Linha: tipo + resumo ("3 fracos · 1 resiste"). */
function TypeRow({ type, text, tone }) {
  const colors = { bad: 'bg-red-500/10 ring-red-500/40', good: 'bg-green-500/10 ring-green-500/40', neutral: 'bg-surface ring-line' }
  return (
    <div className={`flex items-center gap-2 rounded-xl px-2 py-1.5 ring-1 ${colors[tone]}`}>
      <TypeBadge type={type} small />
      <span className="text-xs">{text}</span>
    </div>
  )
}

function Section({ title, hint, children, empty }) {
  return (
    <div>
      <div className="text-sm font-bold">{title}</div>
      {hint && <div className="mb-2 text-xs text-muted">{hint}</div>}
      {children ?? <span className="text-sm text-muted">{empty}</span>}
    </div>
  )
}

/** Resumo em frases do que o time faz bem e mal. */
function tips(analysis) {
  const out = []
  const worst = analysis.weaknesses[0]
  if (worst) {
    const [type, row] = worst
    const cover = row.resist + row.immune
    out.push({
      tone: 'bad',
      text: `${row.weak} de ${analysis.size} Pokémon ${row.weak === 1 ? 'é fraco' : 'são fracos'} a ${type} e ${cover === 0 ? 'ninguém aguenta' : `só ${cover} ${cover === 1 ? 'aguenta' : 'aguentam'}`}.`,
    })
  }
  if (analysis.missing.length > 6)
    out.push({ tone: 'bad', text: `O time não tem golpes super efetivos (STAB) contra ${analysis.missing.length} tipos.` })
  if (!analysis.weaknesses.length) out.push({ tone: 'good', text: 'Nenhum tipo deixa o time em desvantagem. Ótima defesa!' })
  if (analysis.strengths.length >= 6) out.push({ tone: 'good', text: `Boa defesa: aguenta bem ${analysis.strengths.length} tipos.` })
  if (analysis.missing.length <= 3) out.push({ tone: 'good', text: 'Ótima cobertura: acerta quase todos os tipos com dano super efetivo.' })
  return out
}

export default function TeamAnalysis({ analysis }) {
  if (!analysis) return <p className="mt-6 text-muted">Adicione Pokémon para ver a análise.</p>
  return (
    <div className="mt-4 space-y-5">
      <ul className="space-y-1.5">
        {tips(analysis).map((t, i) => (
          <li key={i} className={`text-sm font-semibold ${t.tone === 'bad' ? 'text-red-400' : 'text-green-400'}`}>
            {t.tone === 'bad' ? '⚠️' : '✅'} {t.text}
          </li>
        ))}
      </ul>

      <Section title="Fraquezas" hint="Tipos em que o time tem mais Pokémon fracos do que Pokémon que aguentam." empty="Nenhuma 🎉">
        {analysis.weaknesses.length > 0 && (
          <div className="grid gap-1.5 sm:grid-cols-2">
            {analysis.weaknesses.map(([type, row]) => (
              <TypeRow key={type} type={type} text={rowSummary(row)} tone="bad" />
            ))}
          </div>
        )}
      </Section>

      <Section title="Defesa forte" hint="Tipos que pelo menos 2 Pokémon aguentam (resistem ou são imunes)." empty="Nenhuma">
        {analysis.strengths.length > 0 && (
          <div className="grid gap-1.5 sm:grid-cols-2">
            {analysis.strengths.map(([type, row]) => (
              <TypeRow key={type} type={type} text={rowSummary(row)} tone="good" />
            ))}
          </div>
        )}
      </Section>

      <Section title="Ataque" hint="Quantos Pokémon acertam cada tipo com dano super efetivo usando golpes do próprio tipo (STAB).">
        <div className="flex flex-wrap gap-2">
          {Object.entries(analysis.advantages)
            .sort((a, b) => b[1] - a[1])
            .map(([type, n]) => (
              <span key={type} className="flex items-center gap-1">
                <TypeBadge type={type} small />
                <span className="text-xs text-muted">{n}×</span>
              </span>
            ))}
        </div>
      </Section>

      <Section title="Sem cobertura" hint="Nenhum Pokémon acerta estes tipos com dano super efetivo (STAB)." empty="Nenhum 🎉">
        {analysis.missing.length > 0 && (
          <div className="flex flex-wrap gap-1.5">
            {analysis.missing.map((t) => (
              <TypeBadge key={t} type={t} small />
            ))}
          </div>
        )}
      </Section>
    </div>
  )
}

/** Estrelas da nota (só mostra, ou deixa votar com `onRate`). */
export function Stars({ value = 0, onRate, size = 24 }) {
  const [hover, setHover] = useState(null)
  const shown = hover ?? value
  return (
    <div className="flex" onMouseLeave={() => setHover(null)}>
      {[1, 2, 3, 4, 5].map((n) => {
        const fill = Math.max(0, Math.min(1, shown - n + 1))
        return (
          <m.button
            key={n}
            type="button"
            disabled={!onRate}
            whileHover={onRate ? { scale: 1.2 } : undefined}
            whileTap={onRate ? { scale: 0.9 } : undefined}
            onMouseEnter={() => onRate && setHover(n)}
            onClick={() => onRate?.(n)}
            aria-label={`${n} estrela${n > 1 ? 's' : ''}`}
            className={`relative ${onRate ? 'cursor-pointer' : 'cursor-default'}`}
            style={{ width: size, height: size, fontSize: size * 0.9, lineHeight: 1 }}
          >
            <span className="absolute inset-0" style={{ color: 'var(--line)' }}>
              ★
            </span>
            <span className="absolute inset-0 overflow-hidden text-yellow-400" style={{ width: `${fill * 100}%` }}>
              ★
            </span>
          </m.button>
        )
      })}
    </div>
  )
}

/** "★ 4,3 (12 votos)" ou "Sem notas ainda". */
export function RatingText({ rating, count, className = '' }) {
  if (!count) return <span className={`text-sm text-muted ${className}`}>Sem notas ainda</span>
  return (
    <span className={`text-sm ${className}`}>
      <b className="text-yellow-400">★ {rating.toFixed(1).replace('.', ',')}</b>{' '}
      <span className="text-muted">
        ({count} {count === 1 ? 'voto' : 'votos'})
      </span>
    </span>
  )
}
