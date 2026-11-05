// Faixas de velocidade (igual ao app, speed_tiers_screen.dart): todos os
// Pokémon em ordem de Speed no nível 50 ou 100, com o treino escolhido
// (máximo com Nature a favor, máximo neutro, sem EVs, mínimo) e os efeitos de
// batalha (Choice Scarf, Tailwind, +1 e Trick Room, que inverte a ordem).

import { useEffect, useMemo, useState } from 'react'
import { getPokedex } from '../../lib/data'
import { baseSpeed, isNfe } from '../../lib/damageCalc'
import { t } from '../../lib/i18n'
import { prettyName } from '../../lib/pokemon'
import PokeIcon from '../PokeIcon'
import PokemonModal from '../PokemonModal'
import { Loader, SearchInput } from '../ui'

/** Treinos de Speed: [nome, IV, EVs, Nature]. */
const SPREADS = [
  ['Máx. com Nature', 31, 252, 1.1],
  ['Máx. neutra', 31, 252, 1.0],
  ['Sem EVs', 31, 0, 1.0],
  ['Mínima', 0, 0, 0.9],
]

/** Speed final: status do nível, depois os multiplicadores (arredondando para baixo a cada passo, como no jogo). */
export function speedStat(base, level, iv, ev, nature, { scarf = false, boost = false, tailwind = false } = {}) {
  let v = Math.floor((Math.floor(((2 * base + iv + Math.floor(ev / 4)) * level) / 100) + 5) * nature)
  if (boost) v = Math.floor(v * 1.5)
  if (scarf) v = Math.floor(v * 1.5)
  if (tailwind) v *= 2
  return v
}

function Chip({ on, onClick, children }) {
  return (
    <button type="button" onClick={onClick} aria-pressed={on}
      className={`cursor-pointer rounded-full border px-3 py-1 text-sm font-semibold transition ${on ? 'border-sky-600 bg-sky-600 text-white' : 'border-line bg-surface text-text hover:bg-card'}`}>
      {children}
    </button>
  )
}

export default function SpeedTiers() {
  const [all, setAll] = useState(null) // [{id, name, base, final}]
  const [level, setLevel] = useState(50)
  const [spread, setSpread] = useState(0)
  const [fx, setFx] = useState({ scarf: false, boost: false, tailwind: false, trickRoom: false, finalOnly: true })
  const [query, setQuery] = useState('')
  const [open, setOpen] = useState(null)
  useEffect(() => {
    let live = true
    getPokedex().then((dex) => {
      const list = dex.map((p) => ({ id: p.id, name: p.name, base: baseSpeed(p.name), final: !isNfe(p.name) })).filter((p) => p.base != null)
      if (live) setAll(list)
    })
    return () => {
      live = false
    }
  }, [])
  const [, iv, ev, nature] = SPREADS[spread]
  const list = useMemo(() => {
    if (!all) return []
    const rows = all.filter((p) => !fx.finalOnly || p.final).map((p) => ({ ...p, speed: speedStat(p.base, level, iv, ev, nature, fx) }))
    return rows.sort((a, b) => (fx.trickRoom ? a.speed - b.speed : b.speed - a.speed)).map((p, i) => ({ ...p, rank: i + 1 }))
  }, [all, level, iv, ev, nature, fx])
  const q = query.trim().toLowerCase()
  const shown = q ? list.filter((p) => prettyName(p.name).toLowerCase().includes(q) || String(p.id) === q) : list
  const toggle = (k) => setFx((f) => ({ ...f, [k]: !f[k] }))
  return (
    <div className="mx-auto max-w-3xl space-y-3" data-testid="speed-tiers">
      <p className="text-muted">{t('Quem ataca primeiro: todos os Pokémon em ordem de Speed.')}</p>
      <div className="flex flex-wrap gap-1.5">
        {[50, 100].map((l) => <Chip key={l} on={level === l} onClick={() => setLevel(l)}>{t('Nível {0}').replace('{0}', l)}</Chip>)}
      </div>
      <div className="flex flex-wrap gap-1.5">
        {SPREADS.map(([label], i) => <Chip key={label} on={spread === i} onClick={() => setSpread(i)}>{t(label)}</Chip>)}
      </div>
      <div className="flex flex-wrap gap-1.5">
        <Chip on={fx.scarf} onClick={() => toggle('scarf')}>Choice Scarf</Chip>
        <Chip on={fx.boost} onClick={() => toggle('boost')}>+1 Speed</Chip>
        <Chip on={fx.tailwind} onClick={() => toggle('tailwind')}>Tailwind</Chip>
        <Chip on={fx.trickRoom} onClick={() => toggle('trickRoom')}>Trick Room</Chip>
        <Chip on={fx.finalOnly} onClick={() => toggle('finalOnly')}>{t('Só evoluídos')}</Chip>
      </div>
      <SearchInput value={query} onChange={setQuery} placeholder={t('Procurar Pokémon')} />
      {!all ? (
        <Loader />
      ) : (
        <ul className="divide-y divide-line overflow-hidden rounded-2xl bg-card shadow">
          {shown.slice(0, 300).map((p) => (
            <li key={p.id}>
              <button type="button" onClick={() => setOpen(p.id)} className="flex w-full cursor-pointer items-center gap-3 px-3 py-1.5 text-left hover:bg-surface">
                <span className="w-9 text-sm font-bold text-muted">{p.rank}</span>
                <PokeIcon id={p.id} className="h-10 w-10" />
                <span className="min-w-0 flex-1">
                  <span className="block truncate font-semibold" data-no-translate>{prettyName(p.name)}</span>
                  <span className="block text-xs text-muted">{t('Base {0}').replace('{0}', p.base)}</span>
                </span>
                <span className="text-lg font-black tabular-nums">{p.speed}</span>
              </button>
            </li>
          ))}
        </ul>
      )}
      {open && <PokemonModal id={open} onClose={() => setOpen(null)} />}
    </div>
  )
}
