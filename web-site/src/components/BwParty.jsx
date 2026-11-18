// A tela do time como no port de Black & White: o primeiro (quem vai na frente) grande à esquerda e os outros cinco um
// embaixo do outro à direita, nas caixas escuras de borda cinza da HUD (cor fixa). Arrastar um em cima do outro troca
// os dois de lugar (onMove). Abre por cima do campo, para escolher em quem usar um item, quem trocar, quem sai do time
// ou quem entra na batalha. Igual ao app (lib/widgets/bw_party.dart).

import { useRef, useState } from 'react'
import PokeIcon from './PokeIcon'
import { t } from '../lib/i18n'

const STATUS_COLOR = { brn: '#ea580c', par: '#ca8a04', psn: '#9333ea', tox: '#7e22ce', slp: '#64748b', frz: '#0891b2' }
const hpColor = (hp) => (hp > 0.5 ? '#4ade80' : hp > 0.2 ? '#facc15' : '#ef4444')

/**
 * team: [{ id, shiny, name, level, hp (0 a 1), hpText?, sub? }]
 * onPick(i); disabled(i) → true deixa o cartão apagado; selected: a posição em destaque.
 * onMove(de, para): arrastou um em cima do outro (sem onMove, não arrasta).
 * eggs: os ovos no time (Battle Factory), cada um numa vaga depois dos Pokémon, com as vitórias que faltam para chocar
 * (um número, ou { left, mystery } para o ovo misterioso, que aparece como ❔).
 * hearts (em cada um do time): a amizade, de 0 a 5 corações.
 * Na batalha: active (quem está em campo, borda verde), dim(i) (não dá para trocar: apagado, mas toca para ver os dados)
 * e status (QUE, PAR...) no cartão. leads: quem está em campo (posições no time), à esquerda, um embaixo do outro (1 na
 * normal, 2 na dupla, 3 na tripla); os outros à direita, na ordem do time. Igual ao app (PortParty).
 */
export default function BwParty({ team, title, onPick, onMove, disabled = () => false, dim = () => false, selected = null, active = null, footer = null, leads = null, onCancel, cancelLabel, testid = 'bw-party', eggs = [] }) {
  const [drag, setDrag] = useState(null) // { from, over, x, y }
  const start = useRef(null)
  const moved = useRef(false)
  const slotAt = (x, y) => {
    const el = document.elementFromPoint(x, y)?.closest?.('[data-slot]')
    return el ? Number(el.dataset.slot) : null
  }
  const down = (i) => (e) => {
    if (!onMove || disabled(i)) return
    start.current = { i, x: e.clientX, y: e.clientY }
    moved.current = false
  }
  const move = (e) => {
    const s = start.current
    if (!s) return
    if (!moved.current && Math.hypot(e.clientX - s.x, e.clientY - s.y) < 8) return
    moved.current = true
    setDrag({ from: s.i, over: slotAt(e.clientX, e.clientY), x: e.clientX, y: e.clientY })
  }
  const up = (e) => {
    const s = start.current
    start.current = null
    if (s && moved.current) {
      const to = slotAt(e.clientX, e.clientY)
      if (to != null && to !== s.i && to < team.length) onMove(s.i, to)
    }
    setDrag(null)
  }
  const slots = [...team.map((m, i) => ({ m, i })), ...eggs.map((egg, k) => ({ egg, i: team.length + k }))]
  const slot = ({ m, egg, i }, big = false) => {
    if (egg != null) {
      const left = egg?.left ?? egg
      const mystery = Boolean(egg?.mystery)
      return (
        <div key={`egg-${i}`} className={`party-box flex min-h-0 items-center gap-[1.5cqw] px-[1.5cqw] ${big ? 'flex-col justify-center' : ''}`} data-testid="party-egg" data-slot={i}>
          <span className="grid shrink-0 place-items-center text-[3.5cqw]">{mystery ? '❔' : '🥚'}</span>
          <span className="min-w-0">
            <span className="block truncate text-[1.9cqw]">{t(mystery ? 'Ovo misterioso' : 'Ovo')}</span>
            <span className="block truncate text-[1.4cqw] text-slate-300">{t('Choca em {0} vitórias').replace('{0}', left)}</span>
          </span>
        </div>
      )
    }
    const off = disabled(i)
    const hp = Math.max(0, Math.min(1, m.hp ?? 1))
    const isOver = drag && drag.over === i && drag.from !== i
    return (
      <button key={i} type="button" disabled={off} data-slot={i} data-testid={`${testid}-${i}`}
        onClick={() => { if (!moved.current) onPick(i) }} onPointerDown={down(i)}
        className={`party-box flex min-h-0 min-w-0 cursor-pointer text-left disabled:cursor-default disabled:opacity-45 ${big ? 'flex-col items-center justify-center gap-[1cqw] px-[2cqw]' : 'items-center gap-[1.2cqw] px-[1.2cqw]'} ${selected === i ? 'selected' : active === i || leads?.includes(i) ? 'lead' : ''} ${dim(i) ? 'opacity-60' : ''} ${isOver ? 'over' : ''} ${drag?.from === i ? 'opacity-40' : ''}`}
        style={{ touchAction: onMove ? 'none' : undefined }}>
        <PokeIcon id={m.id} shiny={Boolean(m.shiny)} className={`shrink-0 ${big ? 'h-[11cqw] w-[11cqw]' : 'h-[5.5cqw] w-[5.5cqw]'} ${hp > 0 ? '' : 'grayscale'}`} />
        <span className={`min-w-0 ${big ? 'w-full' : 'flex-1'}`}>
          <span className="flex items-baseline justify-between gap-[1cqw]">
            <span className={`truncate ${big ? 'text-[2.6cqw]' : 'text-[1.9cqw]'}`} data-no-translate>{m.name}{m.status && hp > 0 && <span className="ml-[0.8cqw] rounded-sm px-[0.5cqw] text-[1.2cqw]" style={{ background: STATUS_COLOR[m.status] ?? '#64748b' }}>{m.status.toUpperCase()}</span>}</span>
            <span className="shrink-0 text-[1.5cqw]">Lv.{m.level}{m.max && <span className="ml-[0.5cqw] bg-amber-400 px-[0.4cqw] text-[1.1cqw] text-slate-900" data-testid={`${testid}-max-${i}`}>MÁX</span>}</span>
          </span>
          {m.hearts != null && (
            <span className="block text-[1.2cqw] leading-none text-pink-400" title={t('Amizade')} data-testid={`${testid}-hearts-${i}`}>
              {'♥'.repeat(m.hearts)}<span className="opacity-40">{'♥'.repeat(Math.max(0, 5 - m.hearts))}</span>
            </span>
          )}
          <span className="port-hp-bar"><b>HP</b><i><u style={{ width: `${hp * 100}%`, background: hpColor(hp) }} /></i></span>
          <span className="block truncate text-[1.3cqw] text-slate-300">{m.sub ?? m.hpText ?? (hp > 0 ? `${Math.round(hp * 100)}%` : t('Desmaiado'))}</span>
        </span>
      </button>
    )
  }
  const [lead, ...rest] = slots
  return (
    <div className="bw-party port-field flex h-full min-h-full flex-col gap-[1.2cqw] p-[1.5cqw]" data-testid={testid} onPointerMove={move} onPointerUp={up} onPointerCancel={() => { start.current = null; setDrag(null) }}>
      {title && <p className="party-title px-[1.5cqw] py-[0.6cqw] text-[1.8cqw]">{title}</p>}
      {leads ? (() => {
        // Na batalha: quem está em campo à esquerda (um grande, ou dois/três um embaixo do outro); o resto à direita.
        const front = leads.filter((i) => i >= 0 && i < team.length)
        const back = slots.filter(({ i }) => !front.includes(i))
        const rows = Math.max(back.length, 6 - front.length)
        return (
          <div className="flex min-h-0 flex-1 gap-[1.5cqw]">
            <div className={`flex w-[44%] shrink-0 flex-col ${front.length === 1 ? 'justify-center' : 'gap-[1cqw] py-[2cqw]'}`}>
              {front.length === 1 ? <div className="flex h-[62%]">{slot(slots[front[0]], true)}</div> : front.map((i) => <div key={i} className="flex min-h-0 flex-1">{slot(slots[i])}</div>)}
            </div>
            <div className="grid min-h-0 flex-1 gap-[1cqw]" style={{ gridTemplateRows: `repeat(${rows}, minmax(0, 1fr))` }}>
              {Array.from({ length: rows }, (_, k) => back[k] ? slot(back[k]) : <div key={`empty-${k}`} className="party-box empty" />)}
            </div>
          </div>
        )
      })() : <div className="flex min-h-0 flex-1 gap-[1.5cqw]">
        {/* O primeiro (quem vai na frente) grande, à esquerda. */}
        <div className="flex w-[44%] shrink-0 flex-col justify-center">{lead && <div className="flex h-[62%]">{slot(lead, true)}</div>}</div>
        {/* Os outros, um embaixo do outro. */}
        <div className="grid min-h-0 flex-1 grid-rows-5 gap-[1cqw]">
          {Array.from({ length: 5 }, (_, k) => rest[k] ? slot(rest[k]) : <div key={`empty-${k}`} className="party-box empty" />)}
        </div>
      </div>}
      {/* Na batalha: a fala e os botões TROCAR / DADOS / CANCELAR, com o time na tela inteira. Igual ao app. */}
      {footer && <div className="flex h-[7.5cqw] shrink-0 gap-[1cqw]">{footer}</div>}
      {onMove && <p className="text-center text-[1.3cqw] text-slate-300">{t(leads ? 'Arraste um Pokémon para cima de quem está em campo para trocar.' : 'Arraste um Pokémon em cima de outro para trocar de lugar.')}</p>}
      {onCancel && (
        <button type="button" onClick={onCancel} className="party-box self-end cursor-pointer px-[2cqw] py-[0.6cqw] text-[1.6cqw]" data-testid={`${testid}-cancel`}>
          ✕ {cancelLabel ?? t('Voltar')}
        </button>
      )}
    </div>
  )
}
