// A Bolsa no layout do jogo, na cor do app. À esquerda, os bolsos em quadrados (o aberto claro) e o nome do bolso
// com « »; à direita, a lista escura com o item escolhido em contorno ciano; embaixo, o ícone grande do item e a
// descrição com USAR; e o botão de voltar. Igual ao app (lib/widgets/bw_bag.dart).

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
// external: na batalha (como no jogo), a descrição vai para a caixa de texto e USAR para os botões fixos de baixo.
export default function BwBag({ pockets, onClose, pocket: start, onPocket, selected, onSelect, children, testid = 'bw-bag', external = false }) {
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
      <div className="flex flex-1 gap-1.5 p-2">
        {/* Os bolsos à esquerda (como no jogo): ícones em quadrados, o aberto claro e maior; embaixo, o nome com « ». */}
        <div className="flex w-28 shrink-0 flex-col gap-1.5">
          <div className="grid grid-cols-3 gap-1">
            {shown.map((p) => (
              <button key={p.id} type="button" onClick={() => open(p)} aria-label={t(p.label)} title={t(p.label)} aria-pressed={p.id === current?.id}
                className={`flex aspect-square cursor-pointer items-center justify-center rounded-md border-2 text-xl transition-transform ${p.id === current?.id ? 'scale-105 border-white bg-white/60' : 'border-slate-900/40 bg-white/25 opacity-75 hover:opacity-100'}`}
                data-testid={`${testid}-tab-${p.id}`}>
                <PocketIcon p={p} size="h-6 w-6" />
              </button>
            ))}
          </div>
          <div className="flex items-center rounded bg-slate-950 text-xs font-black">
            <button type="button" onClick={() => go(-1)} className="cursor-pointer px-1 text-cyan-300" aria-label={t('Bolso anterior')} data-testid={`${testid}-prev`}>«</button>
            <span className="min-w-0 flex-1 truncate py-1 text-center">{current ? t(current.label) : ''}</span>
            <button type="button" onClick={() => go(1)} className="cursor-pointer px-1 text-cyan-300" aria-label={t('Próximo bolso')} data-testid={`${testid}-next`}>»</button>
          </div>
        </div>
        {/* A lista à direita: fundo escuro, o item escolhido com contorno ciano. */}
        <div className="bw-bag-list flex min-h-32 min-w-0 flex-1 flex-col gap-1 rounded-md border-2 border-slate-900 p-1">
          {current?.items.length ? (
            <ul className="flex max-h-64 flex-col gap-0.5 overflow-y-auto pr-1" data-testid={`${testid}-${current.id}`}>
              {current.items.map((it) => (
                <li key={it.id}>
                  <button
                    type="button"
                    onClick={() => onSelect?.(selected === it.id ? null : it.id)}
                    className={`flex w-full cursor-pointer items-center gap-1.5 rounded-full border-2 py-0.5 pl-1 pr-2 text-left text-sm font-bold ${selected === it.id ? 'border-cyan-400 bg-white/10 shadow-[0_0_6px_rgba(34,211,238,0.7)]' : 'border-transparent hover:bg-white/5'}`}
                    data-testid={`${testid}-item-${it.id}`}
                  >
                    {it.icon ? <img src={it.icon} alt="" className="pixelated h-7 w-7 shrink-0" onError={(e) => { e.currentTarget.style.visibility = 'hidden' }} /> : <span className="h-7 w-1" />}
                    <span className="min-w-0 flex-1 truncate" data-no-translate>{it.name}</span>
                    {it.count != null && <span className="text-xs tabular-nums text-slate-300">×{it.count}</span>}
                  </button>
                </li>
              ))}
            </ul>
          ) : (
            <p className="px-2 py-1 text-sm font-bold text-slate-300">{t('Nada neste bolso.')}</p>
          )}
          {children}
        </div>
      </div>
      {/* Embaixo, como no jogo: o ícone grande do item escolhido e a descrição (na batalha, vai para a caixa de texto). */}
      {!external && (
        <div className="bw-bag-desc flex min-h-[4.5rem] gap-2 border-t-2 border-slate-900 p-2 text-sm" data-testid={picked ? `${testid}-help` : `${testid}-top`}>
          <div className="flex h-14 w-14 shrink-0 items-center justify-center border-2 border-white bg-slate-950">
            {picked?.icon ? <img src={picked.icon} alt="" className="pixelated h-12 w-12" onError={(e) => { e.currentTarget.style.visibility = 'hidden' }} /> : current && !picked ? <PocketIcon p={current} size="h-10 w-10" /> : <span className="text-3xl">🎒</span>}
          </div>
          <div className="min-w-0 flex-1">
            {picked ? (
              <>
                <p className="truncate font-black" data-no-translate>{picked.name}{picked.count != null && <span className="ml-1 tabular-nums">×{picked.count}</span>}</p>
                <p className="text-xs leading-snug">{picked.help}</p>
                {picked.onUse && (
                  <button type="button" onClick={() => picked.onUse(picked)} disabled={picked.disabled}
                    className="mt-1 cursor-pointer rounded-full border-2 border-slate-900 bg-cyan-500 px-3 py-0.5 text-xs font-black text-white disabled:cursor-default disabled:opacity-40" data-testid={`${testid}-use`}>
                    ▸ {picked.use ?? t('USAR')}
                  </button>
                )}
              </>
            ) : (
              <>
                <p className="font-black">{current ? t(current.label) : ''}</p>
                <p className="text-xs text-slate-300">{t('Toque num item para ver o que ele faz.')}</p>
              </>
            )}
          </div>
        </div>
      )}
      {onClose && <button type="button" onClick={onClose} className="cursor-pointer bg-slate-900 py-1.5 text-sm font-black text-slate-200 hover:bg-slate-800" aria-label={t('Fechar')}>↩ {t('Voltar')}</button>}
    </div>
  )
}
