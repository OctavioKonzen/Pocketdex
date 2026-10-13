// A Bolsa como no Black & White: separada em bolsos (Itens, Remédios, Poké
// Balls, TMs, Itens-chave), a lista de itens em abas brancas à direita, a
// bolsa à esquerda e, embaixo, a barra com o nome do bolso e as setas « ».
// Igual ao app (lib/widgets/bw_bag.dart).

import { useState } from 'react'
import { spriteUrl } from '../lib/data'
import { t } from '../lib/i18n'

/** O ícone do bolso: o sprite de um item (img) ou um emoji. */
const PocketIcon = ({ p, size = 'h-6 w-6' }) => (p.img ? <img src={spriteUrl(`items/${p.img}.png`)} alt="" className={`pixelated inline-block ${size}`} /> : <span>{p.icon}</span>)

/**
 * pockets: [{ id, label, icon, items: [{ id, name, count, icon, help, onUse?, use? }] }]
 * Tocar num item mostra a ajuda; onUse(item) faz o que ele faz (quem chama pergunta em quem).
 * children: aparece embaixo da lista (por exemplo, escolher em quem usar).
 */
export default function BwBag({ pockets, onClose, pocket: start, onPocket, selected, onSelect, children, testid = 'bw-bag' }) {
  // Todos os bolsos aparecem (como no jogo), mesmo vazios.
  const shown = pockets
  // Abre no primeiro bolso com alguma coisa.
  const [own, setOwn] = useState(start ?? (shown.find((p) => p.items.length) ?? shown[0])?.id)
  const current = shown.find((p) => p.id === own) ?? shown[0]
  const at = Math.max(0, shown.indexOf(current))
  const open = (next) => {
    setOwn(next.id)
    onPocket?.(next.id)
    onSelect?.(null)
  }
  const go = (d) => open(shown[(at + d + shown.length) % shown.length])
  const picked = current?.items.find((it) => it.id === selected)
  return (
    <div className="bw-bag flex min-h-full flex-col overflow-hidden rounded-xl border-4 border-slate-900 text-white" data-testid={testid}>
      {/* No celular: os bolsos em abas em cima. */}
      <div className="flex gap-1 px-2 pt-2 sm:hidden">
        {shown.map((p) => (
          <button key={p.id} type="button" onClick={() => open(p)} aria-label={t(p.label)} aria-pressed={p.id === current?.id}
            className={`flex flex-1 cursor-pointer justify-center rounded-t-lg border-2 border-b-0 border-slate-900 py-1 text-lg ${p.id === current?.id ? 'bg-amber-400' : 'bg-slate-800/60'}`} data-testid={`${testid}-tab-${p.id}`}>
            <PocketIcon p={p} />
          </button>
        ))}
      </div>
      <div className="flex min-h-48 flex-1 gap-2 p-2">
        {/* A bolsa, com o bolso de agora aceso. */}
        <div className="hidden w-28 shrink-0 flex-col items-center justify-center gap-2 sm:flex">
          <span className="text-6xl drop-shadow">🎒</span>
          <div className="flex flex-wrap justify-center gap-1">
            {shown.map((p) => (
              <button key={p.id} type="button" onClick={() => open(p)} aria-label={t(p.label)} title={t(p.label)}
                className={`cursor-pointer rounded-md px-1 text-lg ${p.id === current?.id ? 'bg-amber-400 ring-2 ring-white' : 'opacity-60 hover:opacity-100'}`}><PocketIcon p={p} size="h-7 w-7" /></button>
            ))}
          </div>
        </div>
        <div className="flex min-w-0 flex-1 flex-col gap-1.5">
          {current?.items.length ? (
            <ul className="max-h-64 space-y-1.5 overflow-y-auto pr-1" data-testid={`${testid}-${current.id}`}>
              {current.items.map((it) => (
                <li key={it.id}>
                  <button
                    type="button"
                    onClick={() => onSelect?.(selected === it.id ? null : it.id)}
                    className={`bw-bag-row flex w-full cursor-pointer items-center gap-2 rounded-l-full rounded-r-lg border-2 px-2 py-1 text-left text-sm font-black text-slate-900 ${selected === it.id ? 'border-amber-500 bg-amber-100' : 'border-slate-800 bg-white'}`}
                    data-testid={`${testid}-item-${it.id}`}
                  >
                    {it.icon && <img src={it.icon} alt="" className="pixelated h-7 w-7 shrink-0" onError={(e) => { e.currentTarget.style.visibility = 'hidden' }} />}
                    <span className="min-w-0 flex-1 truncate" data-no-translate>{it.name}</span>
                    {it.count != null && <span className="tabular-nums">×{it.count}</span>}
                  </button>
                </li>
              ))}
            </ul>
          ) : (
            <p className="rounded-lg bg-white/15 p-2 text-sm font-bold">{t('Nada neste bolso.')}</p>
          )}
          {picked && (
            <div className="rounded-lg border-2 border-slate-800 bg-white p-2 text-xs font-semibold text-slate-900" data-testid={`${testid}-help`}>
              <p>{picked.help}</p>
              {picked.onUse && (
                <button type="button" onClick={() => picked.onUse(picked)} disabled={picked.disabled}
                  className="mt-1 cursor-pointer rounded-md bg-slate-800 px-3 py-1 font-black text-white disabled:cursor-default disabled:opacity-40" data-testid={`${testid}-use`}>
                  ▸ {picked.use ?? t('USAR')}
                </button>
              )}
            </div>
          )}
          {children}
        </div>
      </div>
      {/* A barra de baixo: « BOLSO » e fechar. */}
      <div className="flex items-center gap-2 bg-slate-900 px-2 py-1.5 text-sm font-black">
        <button type="button" onClick={() => go(-1)} className="cursor-pointer rounded px-2 text-sky-300 hover:bg-white/10" aria-label={t('Bolso anterior')} data-testid={`${testid}-prev`}>«</button>
        <span className="flex min-w-0 flex-1 items-center justify-center gap-1 truncate text-center uppercase tracking-wide">{current && <PocketIcon p={current} size="h-5 w-5" />} {current ? t(current.label) : ''}</span>
        <button type="button" onClick={() => go(1)} className="cursor-pointer rounded px-2 text-sky-300 hover:bg-white/10" aria-label={t('Próximo bolso')} data-testid={`${testid}-next`}>»</button>
        <span className="flex gap-1">
          {shown.map((p, i) => <span key={p.id} className={`h-2 w-2 rounded-full ${i === at ? 'bg-amber-400' : 'bg-slate-600'}`} />)}
        </span>
        {onClose && <button type="button" onClick={onClose} className="ml-1 cursor-pointer rounded bg-red-600 px-2 text-white" aria-label={t('Fechar')}>✕</button>}
      </div>
    </div>
  )
}
