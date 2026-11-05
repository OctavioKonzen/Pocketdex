// O PC do Centro Pokémon (Pokelike), como nos jogos: à esquerda o seu time
// (só os sprites), à direita a caixa de 6×6 (com nome; ◀ ▶ troca de caixa).
// Arraste um Pokémon para outra vaga: com alguém nela, pergunta se quer
// trocar (com os dois nomes); vazia, ele vai para lá. Segurando em cima de ◀ ▶
// durante o arrasto, muda de caixa. Tocar num e depois em outra vaga também
// funciona. Igual ao app (factory_panels.dart, _PcPanel).
import { useEffect, useRef, useState } from 'react'
import PokeIcon from './PokeIcon'
import { t } from '../lib/i18n'
import { boxName, pcMove, pcSlots, PC_BOX, PC_BOXES, renameBox, teamRoom } from '../lib/factoryRun'

const key = (l) => (l ? `${l.where}:${l.index}` : '')

export default function PcPanel({ run, nameOf, onSave }) {
  const [box, setBox] = useState(0)
  const [picked, setPicked] = useState(null) // tocou num (o próximo toque é o destino)
  const [drag, setDrag] = useState(null) // { from, id, shiny, x, y, moved }
  const [ask, setAsk] = useState(null) // { from, to } a confirmar
  const dragRef = useRef(null)
  dragRef.current = drag
  const navTimer = useRef(null)
  const slots = pcSlots(run)
  const room = teamRoom(run)
  const monAt = (l) => (l.where === 'team' ? run.team[l.index] : slots[l.index]) ?? null

  // Soltou (ou tocou no destino): com alguém lá, pergunta; vazia, já move.
  const dropOn = (from, to) => {
    if (!to || key(from) === key(to)) return
    if (monAt(to)) setAsk({ from, to })
    else {
      const next = pcMove(run, from, to)
      if (next) onSave(next)
    }
  }

  const slotAt = (x, y) => {
    const el = document.elementFromPoint(x, y)?.closest('[data-pc-slot]')
    if (!el) return null
    const [where, index] = el.getAttribute('data-pc-slot').split(':')
    return { where, index: Number(index) }
  }

  useEffect(() => {
    if (!drag) return undefined
    const move = (e) => {
      setDrag((d) => (d ? { ...d, x: e.clientX, y: e.clientY, moved: d.moved || Math.hypot(e.clientX - d.sx, e.clientY - d.sy) > 8 } : d))
      // Em cima de ◀ ▶: depois de um tempinho, muda de caixa (como nos jogos).
      const nav = document.elementFromPoint(e.clientX, e.clientY)?.closest('[data-pc-nav]')?.getAttribute('data-pc-nav')
      if (nav && !navTimer.current) {
        navTimer.current = setTimeout(() => {
          setBox((b) => (b + (nav === 'next' ? 1 : -1) + PC_BOXES) % PC_BOXES)
          navTimer.current = null
        }, 500)
      } else if (!nav && navTimer.current) {
        clearTimeout(navTimer.current)
        navTimer.current = null
      }
    }
    const up = (e) => {
      clearTimeout(navTimer.current)
      navTimer.current = null
      const d = dragRef.current
      setDrag(null)
      if (!d) return
      const moved = d.moved || Math.hypot(e.clientX - d.sx, e.clientY - d.sy) > 8
      if (moved) dropOn(d.from, slotAt(e.clientX, e.clientY))
      else if (picked && key(picked) !== key(d.from)) { dropOn(picked, d.from); setPicked(null) }
      else setPicked(key(picked) === key(d.from) ? null : d.from)
    }
    window.addEventListener('pointermove', move)
    window.addEventListener('pointerup', up)
    window.addEventListener('pointercancel', up)
    return () => {
      window.removeEventListener('pointermove', move)
      window.removeEventListener('pointerup', up)
      window.removeEventListener('pointercancel', up)
    }
  })

  const start = (e, from) => {
    const mon = monAt(from)
    if (!mon) {
      // Vaga vazia: destino de quem foi tocado antes.
      if (picked) { dropOn(picked, from); setPicked(null) }
      return
    }
    e.preventDefault()
    setDrag({ from, id: mon.id, shiny: Boolean(mon.shiny), x: e.clientX, y: e.clientY, sx: e.clientX, sy: e.clientY, moved: false })
  }

  const cell = (l, mon, small = false) => {
    const isPicked = key(picked) === key(l)
    const dragging = drag?.moved && key(drag.from) === key(l)
    return (
      <div key={key(l)} data-pc-slot={key(l)} data-testid={`pc-slot-${l.where}-${l.index}`} onPointerDown={(e) => start(e, l)}
        className={`relative grid min-h-0 min-w-0 cursor-pointer overflow-hidden ${small ? 'flex-1' : ''} touch-none select-none place-items-center rounded-lg border-2 ${isPicked ? 'border-amber-400 bg-amber-200/60' : mon ? 'border-sky-900/60 bg-sky-100/80' : 'border-dashed border-sky-900/30 bg-white/15'}`}
        title={mon ? nameOf(mon.id) : ''}>
        {mon && <PokeIcon id={mon.id} shiny={Boolean(mon.shiny)} fill={0.85} className={`pointer-events-none aspect-square h-full max-h-full max-w-full ${dragging ? 'opacity-30' : ''}`} />}
        {mon && !small && <span className="pointer-events-none absolute right-0.5 bottom-0 text-[8px] font-black text-slate-800">{mon.level}</span>}
      </div>
    )
  }

  const rename = () => {
    const name = window.prompt(t('Nome da caixa'), boxName(run, box))
    if (name != null) onSave(renameBox(run, box, name))
  }
  const teamSlots = Array.from({ length: room }, (_, i) => ({ where: 'team', index: i }))
  const askFrom = ask && monAt(ask.from)
  const askTo = ask && monAt(ask.to)

  return (
    <div className="bw-party relative flex h-full min-h-full gap-1.5 p-1.5" data-testid="factory-pc">
      {/* O seu time: pequeno, só os sprites. */}
      <div className="flex min-h-0 w-[16%] shrink-0 flex-col gap-1" data-testid="pc-team">
        <p className="bw-party-title truncate rounded-md px-1 py-0.5 text-center text-[10px] font-black text-white">{t('Time')}</p>
        {teamSlots.map((l) => cell(l, run.team[l.index] ?? null, true))}
      </div>
      {/* A caixa: 6×6, com o nome (toque para mudar) e ◀ ▶. */}
      <div className="flex min-w-0 flex-1 flex-col gap-1" data-testid="pc-box">
        <div className="flex items-center gap-1">
          <button type="button" data-pc-nav="prev" onClick={() => setBox((b) => (b + PC_BOXES - 1) % PC_BOXES)} className="bw-party-title cursor-pointer rounded-md px-2 py-0.5 text-sm font-black text-white" data-testid="pc-box-prev">◀</button>
          <button type="button" onClick={rename} className="bw-party-title min-w-0 flex-1 cursor-pointer truncate rounded-md px-2 py-0.5 text-sm font-black text-white" data-testid="pc-box-name">
            💻 {boxName(run, box)} <span className="text-[10px] opacity-80">✏️</span>
          </button>
          <button type="button" data-pc-nav="next" onClick={() => setBox((b) => (b + 1) % PC_BOXES)} className="bw-party-title cursor-pointer rounded-md px-2 py-0.5 text-sm font-black text-white" data-testid="pc-box-next">▶</button>
        </div>
        <div className="grid min-h-0 flex-1 grid-cols-6 grid-rows-6 gap-1">
          {Array.from({ length: PC_BOX }, (_, k) => {
            const l = { where: 'pc', index: box * PC_BOX + k }
            return cell(l, slots[l.index])
          })}
        </div>
        <p className="shrink-0 text-center text-[10px] leading-tight font-bold text-white/90">{t('Arraste um Pokémon para outra vaga para trocar.')}</p>
      </div>
      {/* Arrastando: o sprite segue o dedo. */}
      {drag?.moved && (
        <div className="pointer-events-none fixed z-50 h-14 w-14 -translate-x-1/2 -translate-y-1/2" style={{ left: drag.x, top: drag.y }}>
          <PokeIcon id={drag.id} shiny={drag.shiny} className="h-full w-full drop-shadow-lg" />
        </div>
      )}
      {/* A pergunta de trocar (com os dois nomes). */}
      {ask && askFrom && askTo && (
        <div className="absolute inset-x-2 bottom-2 z-10 rounded-xl border-4 border-slate-800 bg-white p-2 text-slate-900 shadow-xl" data-testid="pc-ask">
          <p className="text-sm font-black" data-no-translate>{t('Trocar {0} por {1}?').replace('{0}', nameOf(askFrom.id)).replace('{1}', nameOf(askTo.id))}</p>
          <div className="mt-1 flex justify-end gap-2">
            <button type="button" data-testid="pc-ask-no" onClick={() => setAsk(null)} className="cursor-pointer rounded-lg bg-slate-500 px-3 py-1 text-sm font-black text-white">{t('NÃO')}</button>
            <button type="button" data-testid="pc-ask-yes" onClick={() => { const next = pcMove(run, ask.from, ask.to); setAsk(null); if (next) onSave(next) }} className="cursor-pointer rounded-lg bg-emerald-600 px-3 py-1 text-sm font-black text-white">{t('SIM')}</button>
          </div>
        </div>
      )}
    </div>
  )
}
