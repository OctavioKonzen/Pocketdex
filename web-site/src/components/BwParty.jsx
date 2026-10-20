// A tela do time como no Black & White: os 6 em duas colunas, cada um num
// cartão com o ícone, o nome, o nível e a barra de HP; o escolhido fica laranja.
// Abre por cima do campo (a mesma tela), para escolher em quem usar um item,
// quem trocar, quem sai do time ou quem entra na batalha. Igual ao app
// (lib/widgets/bw_party.dart).

import PokeIcon from './PokeIcon'
import { t } from '../lib/i18n'

const hpColor = (hp) => (hp > 0.5 ? 'bg-emerald-400' : hp > 0.2 ? 'bg-amber-400' : 'bg-red-500')

/**
 * team: [{ id, shiny, name, level, hp (0 a 1), hpText?, sub? }]
 * onPick(i); disabled(i) → true deixa o cartão apagado; selected: a posição em destaque.
 */
export default function BwParty({ team, title, onPick, disabled = () => false, selected = null, onCancel, cancelLabel, testid = 'bw-party' }) {
  return (
    <div className="bw-party flex h-full min-h-full flex-col gap-2 p-2" data-testid={testid}>
      {title && <p className="bw-party-title rounded-lg px-3 py-1.5 text-sm font-black text-white sm:text-base">{title}</p>}
      <div className="grid flex-1 grid-cols-2 content-start gap-1.5 sm:gap-2">
        {team.map((m, i) => {
          const off = disabled(i)
          const hp = Math.max(0, Math.min(1, m.hp ?? 1))
          return (
            <button key={i} type="button" disabled={off} onClick={() => onPick(i)} data-testid={`${testid}-${i}`}
              className={`bw-party-slot flex min-w-0 cursor-pointer items-center gap-1 rounded-xl border-2 px-1.5 py-1 text-left disabled:cursor-default disabled:opacity-45 ${selected === i ? 'selected' : ''} ${i === 0 ? 'lead' : ''}`}>
              <PokeIcon id={m.id} shiny={Boolean(m.shiny)} className={`h-9 w-9 shrink-0 sm:h-11 sm:w-11 ${hp > 0 ? '' : 'grayscale'}`} />
              <span className="min-w-0 flex-1">
                <span className="flex items-baseline justify-between gap-1">
                  <span className="truncate text-xs font-black sm:text-sm" data-no-translate>{m.name}</span>
                  <span className="shrink-0 text-[10px] font-black sm:text-xs">Lv{m.level}</span>
                </span>
                <span className="mt-0.5 flex items-center gap-1">
                  <span className="rounded bg-amber-500 px-0.5 text-[8px] font-black text-white">HP</span>
                  <span className="block h-1.5 flex-1 overflow-hidden rounded bg-slate-800">
                    <span className={`block h-full ${hpColor(hp)}`} style={{ width: `${hp * 100}%` }} />
                  </span>
                </span>
                <span className="block truncate text-[10px] font-bold opacity-90">{m.sub ?? m.hpText ?? (hp > 0 ? `${Math.round(hp * 100)}%` : t('Desmaiado'))}</span>
              </span>
            </button>
          )
        })}
      </div>
      {onCancel && (
        <button type="button" onClick={onCancel} className="self-end cursor-pointer rounded-lg bg-red-600 px-3 py-1 text-sm font-black text-white" data-testid={`${testid}-cancel`}>
          ✕ {cancelLabel ?? t('Voltar')}
        </button>
      )}
    </div>
  )
}
