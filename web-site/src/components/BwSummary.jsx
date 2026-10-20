// Os dados de um Pokémon como no Black & White (a tela "Dados" do time):
// nome, nível, tipos, HP, status, habilidade, item, atributos (com os
// estágios da batalha) e os golpes com PP. Igual ao app
// (lib/widgets/bw_summary.dart).

import PokeIcon from './PokeIcon'
import { TypeBadge } from './ui'
import { t } from '../lib/i18n'

export const SUMMARY_STATS = [['atk', 'Ataque'], ['def', 'Defesa'], ['spa', 'At. Esp.'], ['spd', 'Def. Esp.'], ['spe', 'Velocidade']]

/** data: { id, shiny, name, level, hp, maxHp, status, types, ability, item, stats, boosts, moves: [{ name, type, pp, maxPp }] } */
export default function BwSummary({ data: d, onBack, onSwitch }) {
  const hp = d.maxHp > 0 ? Math.max(0, Math.min(1, d.hp / d.maxHp)) : 0
  return (
    <div className="bw-party flex flex-col gap-2 p-2" data-testid="bw-summary">
      <p className="bw-party-title flex justify-between rounded-lg px-3 py-1.5 font-black text-white">
        <span className="truncate" data-no-translate>{d.name}</span>
        <span data-no-translate>Lv{d.level}</span>
      </p>
      <div className="flex gap-2">
        <div className="h-20 w-20 shrink-0 rounded-xl border-2 border-sky-900 bg-sky-100">
          <PokeIcon id={d.id} shiny={Boolean(d.shiny)} className="h-full w-full" />
        </div>
        <div className="min-w-0 flex-1 text-xs font-black text-white">
          <div className="flex flex-wrap gap-1">{d.types.map((type) => <TypeBadge key={type} type={type} small />)}</div>
          <div className="mt-1 flex items-center gap-1">
            HP
            <span className="block h-1.5 flex-1 overflow-hidden rounded bg-slate-800">
              <span className={`block h-full ${hp > 0.5 ? 'bg-emerald-400' : hp > 0.2 ? 'bg-amber-400' : 'bg-red-500'}`} style={{ width: `${hp * 100}%` }} />
            </span>
            <span className="tabular-nums">{d.hp}/{d.maxHp}</span>
          </div>
          {d.status && d.hp > 0 && <p>{t('Status')}: <span className="text-violet-300">{d.status.toUpperCase()}</span></p>}
          {d.ability && <p className="truncate">{t('Habilidade')}: <span className="text-amber-200" data-no-translate>{d.ability}</span></p>}
          <p className="truncate">{t('Item')}: <span className="text-amber-200" data-no-translate>{d.item && d.item !== 'No Item' ? d.item : '—'}</span></p>
        </div>
      </div>
      {/* Os atributos (com os estágios da batalha: ▲ subiu, ▼ caiu). */}
      <div className="rounded-lg border-2 border-sky-900 bg-sky-50 p-1.5 text-xs font-bold text-slate-900">
        {SUMMARY_STATS.map(([key, label]) => (
          <p key={key} className="flex justify-between">
            <span>{t(label)}</span>
            <span className="tabular-nums">
              {d.boosts?.[key] ? <span className={d.boosts[key] > 0 ? 'text-red-600' : 'text-blue-600'}>{d.boosts[key] > 0 ? '▲' : '▼'}{Math.abs(d.boosts[key])} </span> : null}
              {d.stats?.[key] ?? '—'}
            </span>
          </p>
        ))}
      </div>
      {d.moves.map((mv, k) => (
        <p key={k} className="flex items-center gap-1.5 rounded-lg border-2 border-sky-900 bg-white px-2 py-0.5 text-xs font-black text-slate-900">
          {mv.type && <TypeBadge type={mv.type} small />}
          <span className="min-w-0 flex-1 truncate" data-no-translate>{mv.name}</span>
          <span className="tabular-nums">PP {mv.pp}/{mv.maxPp}</span>
        </p>
      ))}
      <div className="flex justify-end gap-2">
        {onSwitch && <button type="button" onClick={onSwitch} className="cursor-pointer rounded-lg bg-green-600 px-3 py-1 text-sm font-black text-white" data-testid="bw-summary-switch">{t('TROCAR')}</button>}
        <button type="button" onClick={onBack} className="cursor-pointer rounded-lg bg-red-600 px-3 py-1 text-sm font-black text-white" data-testid="bw-summary-back">✕ {t('Voltar')}</button>
      </div>
    </div>
  )
}

/** Os dados do Pokémon i do lado side da batalha (o motor dá os atributos, a habilidade e o item). */
export function summaryOf(battle, side, i) {
  const mon = battle.sides[side].team[i]
  const st = battle.simulator?.state?.sides?.[side]?.team?.[i]
  return {
    id: mon.id, shiny: mon.shiny, name: mon.name, level: mon.level, hp: mon.hp, maxHp: mon.maxHp, status: mon.status ?? '',
    types: (st?.types ?? mon.types ?? []).map((x) => String(x).toLowerCase()),
    ability: st?.ability ?? mon.ability ?? '', item: st?.item ?? '',
    stats: Object.fromEntries(Object.entries(st?.stats ?? {}).filter(([k]) => k !== 'hp')),
    boosts: mon.boosts ?? {},
    moves: mon.moves.map((m, k) => ({ name: m.name, type: m.type, pp: st?.moves?.[k]?.pp ?? m.pp, maxPp: st?.moves?.[k]?.maxPp ?? m.maxPp })),
  }
}
