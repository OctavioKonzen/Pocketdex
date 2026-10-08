// As telas da Battle Factory (lib/factoryRun.js): o começo (escolher o
// inicial, comprar Pokémon com as moedas, continuar a corrida) e o que vem
// depois de vencer um andar (XP, captura, carta de bônus e loja). Igual ao app
// (lib/screens/factory_panels.dart).

import { useEffect, useMemo, useState } from 'react'
import PokeIcon from './PokeIcon'
import { Button, SearchInput } from './ui'
import { getFactoryData } from '../lib/data'
import {
  buyItem, buyPokemon, capture, CARDS, endRun, factoryOf, HELD_BONUS, MAX_TEAM, nextFloor, pokemonPrice, shopPrice, skipCapture, startersOf,
  startRun, takeCard, VITAMINS,
} from '../lib/factoryRun'
import { t } from '../lib/i18n'
import { prettyName } from '../lib/pokemon'
import { usePokemonIndex } from '../lib/pokemonIndex'
import { prettySlug } from '../lib/teamSets'
import { useStore } from '../lib/store'

/** Salva a Factory (meta e corrida) na conta. */
export const saveFactory = (factory) => useStore.getState().updateLeague((l) => ({ ...l, factory }))
export const useFactory = () => factoryOf(useStore((s) => s.league))

export function useFactoryData() {
  const [data, setData] = useState(null)
  useEffect(() => {
    getFactoryData().then(setData).catch(() => setData(null))
  }, [])
  return data
}

function MonChip({ mon, byId, selected, onClick, testid }) {
  const name = byId?.get(mon.id)?.name ?? ''
  return (
    <button
      type="button"
      onClick={onClick}
      data-testid={testid}
      aria-pressed={selected}
      disabled={!onClick}
      className={`flex flex-col items-center rounded-xl bg-bg p-1.5 ring-2 ${selected ? 'ring-amber-500' : 'ring-transparent'} ${onClick ? 'cursor-pointer hover:ring-line' : ''}`}
    >
      <PokeIcon id={mon.id} className="h-12 w-12" />
      <span className="text-[11px] font-bold" data-no-translate>{t(prettyName(name))}</span>
      {mon.level != null && <span className="text-[10px] text-muted">Nv. {mon.level}</span>}
      {mon.item && <span className="text-[10px] text-muted" data-no-translate>@ {prettySlug(mon.item)}</span>}
    </button>
  )
}

/** O começo: corrida em andamento, ou escolher o inicial; e a loja de Pokémon (moedas). */
export function FactoryHub({ onBattle, busy }) {
  const factory = useFactory()
  const data = useFactoryData()
  const byId = usePokemonIndex()
  const [pick, setPick] = useState(null)
  const [query, setQuery] = useState('')
  const run = factory.run

  const shopList = useMemo(() => {
    if (!data || !byId) return []
    const q = query.trim().toLowerCase()
    return Object.entries(data.species)
      .map(([id, [, bst]]) => ({ id: Number(id), bst, price: pokemonPrice(bst), name: byId.get(Number(id))?.name ?? '' }))
      .filter((p) => !data.starters.includes(p.id) && !factory.owned.includes(p.id) && (!q || p.name.includes(q)))
      .sort((a, b) => a.price - b.price || a.id - b.id)
      .slice(0, 24)
  }, [data, byId, query, factory.owned])

  if (!data) return <p className="text-sm text-muted">...</p>
  return (
    <div className="space-y-4" data-testid="factory-hub">
      <div className="rounded-2xl bg-bg p-3 text-sm">
        <p className="font-black">🏭 {t('Battle Factory')}</p>
        <p className="text-muted">
          {t('Escolha um inicial no nível 5 e suba andares: Pokémon selvagens (dá para capturar até 6), treinadores e, raramente, lendários. Cada Pokémon derrotado dá XP e dinheiro. A loja aparece a cada 5 andares (e com 20% de chance nos outros); a cada 10 andares você escolhe uma carta de bônus. Itens, IVs e EVs sem limite. Perdeu: a pontuação vira moedas para comprar Pokémon e começar com eles.')}
        </p>
        <p className="mt-1 font-bold">
          {t('Recorde: andar {0}').replace('{0}', factory.best)} · 🪙 {factory.coins} {t('moedas')}
        </p>
        {factory.last && !run && <p className="text-muted">{t('Última corrida: andar {0}, +{1} moedas.').replace('{0}', factory.last.floor).replace('{1}', factory.last.coins)}</p>}
      </div>

      {run ? (
        <div className="space-y-3 rounded-2xl bg-bg p-3" data-testid="factory-run">
          <p className="font-black">{t('Corrida em andamento: andar {0}').replace('{0}', run.floor)} · 💰 {run.money}</p>
          <div className="flex flex-wrap gap-1">{run.team.map((m, i) => <MonChip key={i} mon={m} byId={byId} />)}</div>
          {run.cards.length > 0 && <p className="text-xs text-muted">{t('Cartas')}: {run.cards.map((c) => t(CARDS[c].label)).join(' · ')}</p>}
          <div className="flex flex-wrap gap-2">
            <Button disabled={busy || Boolean(run.pending)} onClick={() => onBattle(run)}>⚔️ {t('Lutar no andar {0}').replace('{0}', run.floor)}</Button>
            <Button color="#64748b" onClick={() => saveFactory(endRun(factory, run))}>{t('Desistir (recebe as moedas)')}</Button>
          </div>
          {run.pending && <FactoryAfter run={run} data={data} onNext={onBattle} />}
        </div>
      ) : (
        <div className="space-y-2">
          <p className="text-sm font-semibold text-muted">{t('Escolha o seu inicial')}</p>
          <div className="flex max-h-72 flex-wrap gap-1 overflow-y-auto">
            {startersOf(factory, data).map((id) => (
              <MonChip key={id} mon={{ id }} byId={byId} selected={pick === id} onClick={() => setPick(id)} testid={`starter-${id}`} />
            ))}
          </div>
          <Button
            disabled={busy || pick == null}
            onClick={() => {
              const next = startRun(factory, data, pick, Math.floor(Math.random() * 2 ** 31))
              if (!next) return
              saveFactory({ ...factory, run: next })
              onBattle(next)
            }}
          >
            🏭 {t('Começar a corrida')}
          </Button>
        </div>
      )}

      <details className="rounded-2xl bg-bg p-3">
        <summary className="cursor-pointer font-bold">🪙 {t('Comprar Pokémon com moedas')}</summary>
        <p className="my-2 text-xs text-muted">{t('Os mais fortes custam mais. Comprado, ele aparece entre os iniciais (sempre no nível 5).')}</p>
        <SearchInput value={query} onChange={setQuery} placeholder={t('Buscar Pokémon')} />
        <div className="mt-2 grid grid-cols-2 gap-2 sm:grid-cols-3">
          {shopList.map((p) => (
            <div key={p.id} className="flex items-center gap-2 rounded-xl bg-card p-2">
              <PokeIcon id={p.id} className="h-10 w-10" />
              <div className="min-w-0 flex-1 text-xs">
                <p className="truncate font-bold" data-no-translate>{t(prettyName(p.name))}</p>
                <p className="text-muted">🪙 {p.price}</p>
              </div>
              <Button disabled={factory.coins < p.price} onClick={() => { const next = buyPokemon(factory, data, p.id); if (next) saveFactory(next) }}>
                {t('Comprar')}
              </Button>
            </div>
          ))}
        </div>
      </details>
    </div>
  )
}

/** Depois de vencer um andar: XP/níveis, captura, carta e loja; depois o próximo andar. */
export function FactoryAfter({ run, data, onNext }) {
  const factory = useFactory()
  const byId = usePokemonIndex()
  const [target, setTarget] = useState(0)
  const p = run.pending
  if (!p) return null
  const save = (next) => next && saveFactory({ ...factory, run: next })
  const name = (id) => t(prettyName(byId?.get(id)?.name ?? ''))
  return (
    <section className="space-y-3 rounded-2xl bg-card p-4 shadow-lg ring-1 ring-line" data-testid="factory-after">
      <p className="font-black">🏆 {t('Andar vencido!')} +{p.exp} XP · +💰{p.money}</p>
      {p.levels?.map((l) => (
        <p key={l.index} className="text-sm" data-no-translate>
          {name(run.team[l.index]?.id)}: Nv. {l.from} → {l.to}{l.evolved ? ` · ${t('evoluiu!')}` : ''}
        </p>
      ))}

      {p.capture ? (
        <div className="space-y-2" data-testid="factory-capture">
          <p className="font-bold">{t('Capturar {0} (Nv. {1})?').replace('{0}', name(p.capture.id)).replace('{1}', p.capture.level)}</p>
          <div className="flex items-center gap-2"><PokeIcon id={p.capture.id} className="h-14 w-14" /></div>
          {run.team.length < MAX_TEAM ? (
            <Button onClick={() => save(capture(run))}>🔴 {t('Capturar')}</Button>
          ) : (
            <div className="space-y-1">
              <p className="text-xs text-muted">{t('Time cheio: escolha quem sai.')}</p>
              <div className="flex flex-wrap gap-1">{run.team.map((m, i) => <MonChip key={i} mon={m} byId={byId} onClick={() => save(capture(run, i))} testid={`replace-${i}`} />)}</div>
            </div>
          )}
          <Button color="#64748b" onClick={() => save(skipCapture(run))}>{t('Deixar ir')}</Button>
        </div>
      ) : p.cards ? (
        <div className="space-y-2" data-testid="factory-cards">
          <p className="font-bold">🃏 {t('Escolha uma carta de bônus')}</p>
          <div className="grid gap-2 sm:grid-cols-3">
            {p.cards.map((c) => (
              <button key={c} type="button" data-testid={`card-${c}`} onClick={() => save(takeCard(run, c, data))} className="cursor-pointer rounded-xl bg-bg p-3 text-left text-sm font-bold ring-2 ring-transparent hover:ring-amber-500">
                {t(CARDS[c].label)}
              </button>
            ))}
          </div>
        </div>
      ) : (
        <>
          {p.shop && (
            <div className="space-y-2" data-testid="factory-shop">
              <p className="font-bold">🛒 {t('Loja')} · 💰 {run.money}</p>
              <p className="text-xs text-muted">{t('Para quem é a compra:')}</p>
              <div className="flex flex-wrap gap-1">{run.team.map((m, i) => <MonChip key={i} mon={m} byId={byId} selected={target === i} onClick={() => setTarget(i)} testid={`target-${i}`} />)}</div>
              <div className="grid gap-2 sm:grid-cols-2">
                {p.shop.map((id) => (
                  <div key={id} className="flex items-center justify-between gap-2 rounded-xl bg-bg p-2 text-sm">
                    <div className="min-w-0">
                      <p className="font-bold" data-no-translate>{prettySlug(id)}</p>
                      <p className="text-xs text-muted">{itemHelp(id)}</p>
                    </div>
                    <Button disabled={run.money < shopPrice(run, id)} onClick={() => save(buyItem(run, id, Math.min(target, run.team.length - 1), data))}>
                      💰{shopPrice(run, id)}
                    </Button>
                  </div>
                ))}
              </div>
            </div>
          )}
          <Button className="w-full" color="linear-gradient(90deg,#DC2626,#9333EA)" onClick={() => { const next = nextFloor(run, data); save(next); onNext(next) }} data-testid="factory-next">
            ⚔️ {t('Próximo andar ({0})').replace('{0}', run.floor)}
          </Button>
        </>
      )}
    </section>
  )
}

function itemHelp(id) {
  if (id === 'rare-candy') return t('+1 nível')
  if (VITAMINS[id]) return t('+6 pontos no atributo, sem limite')
  if (id === 'bottle-cap') return t('+3 pontos em todos os atributos, sem limite')
  if (HELD_BONUS[id]) return t('Segura o item; se já tem um, vira pontos de atributo')
  return ''
}
