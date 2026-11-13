// A Bolsa como no Black & White. Em cima, como a tela de cima do DS: o item escolhido grande, com o nome e a descrição
// (sem item escolhido, a bolsa e o nome do bolso). No meio, os itens em pílulas brancas de borda azul (ícone, nome e
// ×quantidade), em duas colunas, com o escolhido em laranja. Embaixo, os bolsos em botões redondos, as setas « » e o
// botão vermelho de voltar. Igual ao app (lib/widgets/bw_bag.dart).

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
    <div className="bw-bag flex min-h-full flex-col overflow-hidden rounded-xl border-4 border-slate-900 text-slate-900" data-testid={testid}>
      {/* A "tela de cima": o item escolhido (ícone grande, nome e descrição) ou a bolsa com o nome do bolso. */}
      {!external && (
        <div className="bw-bag-top m-2 mb-0 flex min-h-[4.5rem] items-center gap-2 rounded-lg border-2 border-sky-800 bg-white/95 p-2" data-testid={picked ? `${testid}-help` : `${testid}-top`}>
          {picked ? (
            <>
              {picked.icon ? <img src={picked.icon} alt="" className="pixelated h-12 w-12 shrink-0" onError={(e) => { e.currentTarget.style.visibility = 'hidden' }} /> : <span className="text-4xl">🎒</span>}
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-black" data-no-translate>{picked.name}{picked.count != null && <span className="ml-1 tabular-nums text-sky-700">×{picked.count}</span>}</p>
                <p className="text-xs font-semibold leading-snug">{picked.help}</p>
                {picked.onUse && (
                  <button type="button" onClick={() => picked.onUse(picked)} disabled={picked.disabled}
                    className="bw-bag-use mt-1 cursor-pointer rounded-full border-2 border-sky-900 bg-sky-600 px-3 py-0.5 text-xs font-black text-white disabled:cursor-default disabled:opacity-40" data-testid={`${testid}-use`}>
                    ▸ {picked.use ?? t('USAR')}
                  </button>
                )}
              </div>
            </>
          ) : (
            <>
              <span className="text-4xl drop-shadow">🎒</span>
              <div className="min-w-0 flex-1">
                <p className="flex items-center gap-1 text-sm font-black uppercase tracking-wide">{current && <PocketIcon p={current} size="h-5 w-5" />} {current ? t(current.label) : ''}</p>
                <p className="text-xs font-semibold text-slate-600">{t('Toque num item para ver o que ele faz.')}</p>
              </div>
            </>
          )}
        </div>
      )}
      {/* Os itens: pílulas brancas de borda azul, em duas colunas (o escolhido em laranja). */}
      <div className="flex min-h-40 flex-1 flex-col gap-1.5 p-2">
        {current?.items.length ? (
          <ul className="grid max-h-64 grid-cols-1 gap-1.5 overflow-y-auto pr-1 min-[420px]:grid-cols-2" data-testid={`${testid}-${current.id}`}>
            {current.items.map((it) => (
              <li key={it.id}>
                <button
                  type="button"
                  onClick={() => onSelect?.(selected === it.id ? null : it.id)}
                  className={`bw-bag-row flex w-full cursor-pointer items-center gap-1.5 rounded-full border-2 py-0.5 pl-1 pr-3 text-left text-sm font-black shadow-[0_2px_0_rgba(15,23,42,0.35)] ${selected === it.id ? 'border-orange-600 bg-amber-300' : 'border-sky-800 bg-white'}`}
                  data-testid={`${testid}-item-${it.id}`}
                >
                  {it.icon ? <img src={it.icon} alt="" className="pixelated h-7 w-7 shrink-0" onError={(e) => { e.currentTarget.style.visibility = 'hidden' }} /> : <span className="h-7 w-1" />}
                  <span className="min-w-0 flex-1 truncate" data-no-translate>{it.name}</span>
                  {it.count != null && <span className="tabular-nums text-sky-800">×{it.count}</span>}
                </button>
              </li>
            ))}
          </ul>
        ) : (
          <p className="rounded-full border-2 border-sky-800 bg-white/90 px-3 py-1 text-sm font-bold">{t('Nada neste bolso.')}</p>
        )}
        {children}
      </div>
      {/* A barra de baixo: os bolsos em botões redondos, as setas « » e o botão vermelho de voltar. */}
      <div className="bw-bag-bar flex items-center gap-1.5 border-t-2 border-slate-900 px-2 py-1.5 text-sm font-black text-white">
        <button type="button" onClick={() => go(-1)} className="cursor-pointer rounded-full bg-sky-900/70 px-2 text-sky-200 hover:bg-sky-900" aria-label={t('Bolso anterior')} data-testid={`${testid}-prev`}>«</button>
        <div className="flex min-w-0 flex-1 items-center justify-center gap-1">
          {shown.map((p) => (
            <button key={p.id} type="button" onClick={() => open(p)} aria-label={t(p.label)} title={t(p.label)} aria-pressed={p.id === current?.id}
              className={`flex cursor-pointer items-center justify-center rounded-full border-2 border-slate-900 text-lg transition-transform ${p.id === current?.id ? 'h-10 w-10 scale-105 bg-amber-400' : 'h-8 w-8 bg-white/85 opacity-80 hover:opacity-100'}`}
              data-testid={`${testid}-tab-${p.id}`}>
              <PocketIcon p={p} size={p.id === current?.id ? 'h-7 w-7' : 'h-5 w-5'} />
            </button>
          ))}
        </div>
        <button type="button" onClick={() => go(1)} className="cursor-pointer rounded-full bg-sky-900/70 px-2 text-sky-200 hover:bg-sky-900" aria-label={t('Próximo bolso')} data-testid={`${testid}-next`}>»</button>
        {onClose && <button type="button" onClick={onClose} className="ml-1 flex h-9 w-9 shrink-0 cursor-pointer items-center justify-center rounded-full border-2 border-slate-900 bg-red-600 text-white" aria-label={t('Fechar')}>↩</button>}
      </div>
    </div>
  )
}
