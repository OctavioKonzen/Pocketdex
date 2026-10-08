// As telas da Battle Factory (lib/factoryRun.js): o começo (escolher o
// inicial, comprar Pokémon com as moedas, continuar a corrida) e o que vem
// depois de vencer um andar (XP, Enfermeira Joy, captura com Poké Ball, carta
// de bônus, loja, Bolsa e itens). Igual ao app (lib/screens/factory_panels.dart).

import { useEffect, useMemo, useState } from 'react'
import PokeIcon from './PokeIcon'
import { Button, SearchInput } from './ui'
import { getFactoryData, spriteUrl } from '../lib/data'
import {
  BAG_ITEMS, BOSS_EVERY, bossOf, BOTTLE_CAP_IVS, buyItem, buyPokemon, capture, CARDS, endRun, factoryOf, HEAL_SHARE, HELD_BOOST, MAX_TEAM, nextFloor,
  pokemonPrice, setMainItem, shinyPrice, shopPrice, skipCapture, startersOf, startRun, takeCard, teamDown, applyBagItem, unlockShiny, VITAMIN_EVS, VITAMINS,
  buyShiny,
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

const STAT_LABEL = { hp: 'HP', atk: 'Atk', def: 'Def', spa: 'SpA', spd: 'SpD', spe: 'Spe' }

function HpBar({ hp }) {
  const value = Math.max(0, Math.min(1, hp ?? 1))
  const color = value > 0.5 ? 'bg-emerald-500' : value > 0.2 ? 'bg-amber-500' : 'bg-red-500'
  return (
    <span className="mt-0.5 block h-1.5 w-12 overflow-hidden rounded bg-line" title={`${Math.round(value * 100)}%`}>
      <span className={`block h-full ${color}`} style={{ width: `${value * 100}%` }} />
    </span>
  )
}

function MonChip({ mon, byId, selected, onClick, testid }) {
  const name = byId?.get(mon.id)?.name ?? ''
  const down = mon.hp != null && !(mon.hp > 0)
  return (
    <button
      type="button"
      onClick={onClick}
      data-testid={testid}
      aria-pressed={selected}
      disabled={!onClick}
      className={`flex flex-col items-center rounded-xl bg-bg p-1.5 ring-2 ${selected ? 'ring-amber-500' : 'ring-transparent'} ${onClick ? 'cursor-pointer hover:ring-line' : ''}`}
    >
      <PokeIcon id={mon.id} shiny={Boolean(mon.shiny)} className={`h-12 w-12 ${down ? 'opacity-40 grayscale' : ''}`} />
      <span className="text-[11px] font-bold" data-no-translate>{mon.shiny ? '✨ ' : ''}{t(prettyName(name))}</span>
      {mon.level != null && <span className="text-[10px] text-muted">Nv. {mon.level}</span>}
      {mon.hp != null && (down ? <span className="text-[10px] font-bold text-red-500">{t('Desmaiado')}</span> : <HpBar hp={mon.hp} />)}
      {mon.item && (
        <span className="text-[10px] text-muted" data-no-translate>
          @ {prettySlug(mon.item)}
          {mon.extras?.length ? ` +${mon.extras.length}` : ''}
        </span>
      )}
    </button>
  )
}

/** Poké Balls, dinheiro e a Bolsa da corrida. */
function RunStatus({ run }) {
  return (
    <p className="flex flex-wrap items-center gap-x-3 gap-y-1 text-sm font-bold">
      <span>💰 {run.money}</span>
      <span className="inline-flex items-center gap-1">
        <img src={spriteUrl('items/poke-ball.png')} alt="" className="pixelated h-6 w-6" />×{run.balls}
      </span>
      {BAG_ITEMS.filter((id) => run.bag[id] > 0).map((id) => (
        <span key={id} className="inline-flex items-center gap-1" data-no-translate title={prettySlug(id)}>
          <img src={spriteUrl(`items/${id}.png`)} alt="" className="pixelated h-6 w-6" />×{run.bag[id]}
        </span>
      ))}
    </p>
  )
}

/** Usar a Bolsa fora da batalha: poções em quem está ferido, Revive em quem desmaiou. */
function BagPanel({ run, byId, save }) {
  const [item, setItem] = useState(null)
  const usable = BAG_ITEMS.filter((id) => run.bag[id] > 0 && run.team.some((_, i) => applyBagItem(run, id, i)))
  if (!usable.length) return null
  return (
    <details className="rounded-xl bg-bg p-2" data-testid="factory-bag">
      <summary className="cursor-pointer text-sm font-bold">🎒 {t('Usar a Bolsa')}</summary>
      <div className="mt-2 flex flex-wrap gap-2">
        {usable.map((id) => (
          <button key={id} type="button" onClick={() => setItem(id)} aria-pressed={item === id}
            className={`flex items-center gap-1 rounded-lg bg-card px-2 py-1 text-xs font-bold ring-2 ${item === id ? 'ring-amber-500' : 'ring-transparent'}`}>
            <img src={spriteUrl(`items/${id}.png`)} alt="" className="pixelated h-6 w-6" />
            <span data-no-translate>{prettySlug(id)}</span> ×{run.bag[id]}
          </button>
        ))}
      </div>
      {item && (
        <div className="mt-2 flex flex-wrap gap-1">
          {run.team.map((m, i) => (
            <MonChip key={i} mon={m} byId={byId} onClick={applyBagItem(run, item, i) ? () => { save(applyBagItem(run, item, i)); setItem(null) } : null} testid={`bag-target-${i}`} />
          ))}
        </div>
      )}
    </details>
  )
}

/** O item principal de cada um (efeito de verdade) e os extras (porcentagem bem menor). */
function ItemsPanel({ run, byId, save }) {
  const holders = run.team.map((m, i) => [m, i]).filter(([m]) => m.extras?.length)
  if (!holders.length) return null
  return (
    <details className="rounded-xl bg-bg p-2" data-testid="factory-items">
      <summary className="cursor-pointer text-sm font-bold">🎒 {t('Itens segurados')}</summary>
      <p className="my-1 text-xs text-muted">{t('O principal tem o efeito de verdade; os outros dão só uma porcentagem pequena no atributo. Toque num extra para ele virar o principal.')}</p>
      {holders.map(([m, i]) => (
        <div key={i} className="mt-2 flex flex-wrap items-center gap-1 text-xs">
          <PokeIcon id={m.id} className="h-8 w-8" />
          <span className="rounded-lg bg-amber-500/20 px-2 py-1 font-bold" data-no-translate>★ {prettySlug(m.item)}</span>
          {m.extras.map((id, k) => (
            <button key={k} type="button" onClick={() => save(setMainItem(run, i, k))} className="cursor-pointer rounded-lg bg-card px-2 py-1 hover:ring-2 hover:ring-amber-500" data-no-translate>
              {prettySlug(id)}
            </button>
          ))}
        </div>
      ))}
    </details>
  )
}

export const bossKindLabel = (kind) => ({ gym: t('Líder de ginásio'), rival: t('Rival'), villain: t('Vilão'), elite: t('Elite Four'), champion: t('Campeão') })[kind] ?? ''

/** O próximo chefe (a cada 10 andares). */
function NextBoss({ run, data }) {
  const boss = bossOf(data, run)
  const floor = Math.ceil(run.floor / BOSS_EVERY) * BOSS_EVERY
  return (
    <p className="text-xs text-muted">
      👑 {t('Próximo chefe (andar {0}):').replace('{0}', floor)}{' '}
      <b data-no-translate>{boss.name}</b> · {bossKindLabel(boss.kind)} · <span data-no-translate>{boss.region} ({boss.game})</span>
    </p>
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
  const save = (next) => next && saveFactory({ ...factory, run: next })

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
  const down = run && teamDown(run)
  return (
    <div className="space-y-4" data-testid="factory-hub">
      <div className="rounded-2xl bg-bg p-3 text-sm">
        <p className="font-black">🏭 {t('Battle Factory')}</p>
        <p className="text-muted">
          {t('Um roguelike sem fim: escolha um inicial no nível 5 e suba andares contra Pokémon selvagens (capture com Poké Ball: você começa com 5), treinadores e lendários. A cada 10 andares vem um chefe, na ordem da história de um jogo sorteado: líderes de ginásio, rival e vilões (com times cada vez maiores), a Elite Four e o Campeão. O time não é curado entre os andares (só com a Bolsa, a loja ou, com 5% de chance, a Enfermeira Joy). Sem limite de nível, IVs, EVs ou itens. Perdeu: a pontuação vira moedas para comprar Pokémon e começar com eles.')}
        </p>
        <p className="mt-1 font-bold">
          {t('Recorde: andar {0}').replace('{0}', factory.best)} · 🪙 {factory.coins} {t('moedas')}
        </p>
        {factory.last && !run && <p className="text-muted">{t('Última corrida: andar {0}, +{1} moedas.').replace('{0}', factory.last.floor).replace('{1}', factory.last.coins)}</p>}
      </div>

      {run ? (
        <div className="space-y-3 rounded-2xl bg-bg p-3" data-testid="factory-run">
          <p className="font-black">{t('Corrida em andamento: andar {0}').replace('{0}', run.floor)}</p>
          <RunStatus run={run} />
          <NextBoss run={run} data={data} />
          <div className="flex flex-wrap gap-1">{run.team.map((m, i) => <MonChip key={i} mon={m} byId={byId} />)}</div>
          {run.cards.length > 0 && <p className="text-xs text-muted">{t('Cartas')}: {run.cards.map((c) => t(CARDS[c].label)).join(' · ')}</p>}
          {!run.pending && <BagPanel run={run} byId={byId} save={save} />}
          {!run.pending && <ItemsPanel run={run} byId={byId} save={save} />}
          {down && !run.pending && <p className="text-sm font-bold text-red-500">{t('O time todo está desmaiado: use um Revive ou desista.')}</p>}
          <div className="flex flex-wrap gap-2">
            <Button disabled={busy || Boolean(run.pending) || down} onClick={() => onBattle(run)}>⚔️ {t('Lutar no andar {0}').replace('{0}', run.floor)}</Button>
            <Button color="#64748b" onClick={() => saveFactory(endRun(factory, run))}>{t('Desistir (recebe as moedas)')}</Button>
          </div>
          {run.pending && <FactoryAfter run={run} data={data} onNext={onBattle} />}
        </div>
      ) : (
        <div className="space-y-2">
          <p className="text-sm font-semibold text-muted">{t('Escolha o seu inicial')}</p>
          <div className="flex max-h-72 flex-wrap gap-1 overflow-y-auto">
            {startersOf(factory, data).flatMap((id) => [
              <MonChip key={id} mon={{ id }} byId={byId} selected={pick?.id === id && !pick.shiny} onClick={() => setPick({ id, shiny: false })} testid={`starter-${id}`} />,
              (factory.shinies ?? []).includes(id) && (
                <MonChip key={`${id}-s`} mon={{ id, shiny: true }} byId={byId} selected={pick?.id === id && pick.shiny} onClick={() => setPick({ id, shiny: true })} testid={`starter-${id}-shiny`} />
              ),
            ])}
          </div>
          <Button
            data-testid="factory-start"
            disabled={busy || pick == null}
            onClick={() => {
              const next = startRun(factory, data, pick.id, Math.floor(Math.random() * 2 ** 31), pick.shiny)
              if (!next) return
              saveFactory({ ...factory, run: next })
              onBattle(next)
            }}
          >
            🏭 {t('Começar a corrida')}
          </Button>
        </div>
      )}

      <details className="rounded-2xl bg-bg p-3" data-testid="factory-shiny-shop">
        <summary className="cursor-pointer font-bold">✨ {t('Inicial shiny')}</summary>
        <p className="my-2 text-xs text-muted">{t('Shiny tem +10% em todos os atributos. Capture um inicial shiny na corrida para liberar o shiny dele, ou transforme com moedas (bem caro).')}</p>
        <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
          {startersOf(factory, data).filter((id) => !(factory.shinies ?? []).includes(id)).map((id) => {
            const price = shinyPrice(data.species[id][1])
            return (
              <div key={id} className="flex items-center gap-2 rounded-xl bg-card p-2">
                <PokeIcon id={id} shiny className="h-10 w-10" />
                <div className="min-w-0 flex-1 text-xs">
                  <p className="truncate font-bold" data-no-translate>✨ {t(prettyName(byId?.get(id)?.name ?? ''))}</p>
                  <p className="text-muted">🪙 {price}</p>
                </div>
                <Button disabled={factory.coins < price} onClick={() => { const next = buyShiny(factory, data, id); if (next) saveFactory(next) }}>
                  {t('Comprar')}
                </Button>
              </div>
            )
          })}
        </div>
      </details>

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

/** Depois de vencer um andar: XP/níveis, Enfermeira Joy, captura, carta e loja; depois o próximo andar. */
export function FactoryAfter({ run, data, onNext }) {
  const factory = useFactory()
  const byId = usePokemonIndex()
  const [target, setTarget] = useState(0)
  const [unlocked, setUnlocked] = useState(null)
  const p = run.pending
  if (!p) return null
  const save = (next) => next && saveFactory({ ...factory, run: next })
  const name = (id) => t(prettyName(byId?.get(id)?.name ?? ''))
  const down = teamDown(run)
  // Captura; se for um inicial shiny, libera o shiny dele para começar as próximas corridas.
  const catchIt = (replace = null) => {
    const next = capture(run, replace)
    if (next === run) return
    const meta = unlockShiny(factory, data, p.capture)
    if (meta !== factory) setUnlocked(p.capture.id)
    saveFactory({ ...meta, run: next })
  }
  return (
    <section className="space-y-3 rounded-2xl bg-card p-4 shadow-lg ring-1 ring-line" data-testid="factory-after">
      <p className="font-black">🏆 {t('Andar vencido!')} +{p.exp} XP · +💰{p.money}</p>
      {p.levels?.map((l) => (
        <p key={l.index} className="text-sm" data-no-translate>
          {name(run.team[l.index]?.id)}: Nv. {l.from} → {l.to}{l.evolved ? ` · ${t('evoluiu!')}` : ''}
        </p>
      ))}
      {p.joy && (
        <div className="flex items-center gap-3 rounded-xl bg-pink-500/15 p-2 text-sm font-bold" data-testid="factory-joy">
          <img src={spriteUrl('trainers/sd-nurse.png')} alt="" className="pixelated h-16 w-16 object-contain" />
          <span>💗 {t('A Enfermeira Joy apareceu e curou o time todo!')}</span>
        </div>
      )}
      {unlocked != null && (
        <p className="rounded-xl bg-amber-500/15 p-2 text-sm font-bold" data-testid="factory-shiny-unlocked">
          ✨ {t('{0} shiny liberado para começar as próximas corridas!').replace('{0}', name(unlocked))}
        </p>
      )}
      <RunStatus run={run} />
      <div className="flex flex-wrap gap-1">{run.team.map((m, i) => <MonChip key={i} mon={m} byId={byId} />)}</div>

      {p.capture ? (
        <div className="space-y-2" data-testid="factory-capture">
          <p className="font-bold">{p.capture.shiny ? '✨ ' : ''}{t('Capturar {0} (Nv. {1})?').replace('{0}', name(p.capture.id)).replace('{1}', p.capture.level)}</p>
          {p.capture.shiny && <p className="text-sm font-bold text-amber-500">{t('É shiny! (+10% em todos os atributos)')}</p>}
          <div className="flex items-center gap-2"><PokeIcon id={p.capture.id} shiny={Boolean(p.capture.shiny)} className="h-14 w-14" /></div>
          {!(run.balls > 0) ? (
            <p className="text-sm text-muted">{t('Sem Poké Balls: compre mais na loja.')}</p>
          ) : run.team.length < MAX_TEAM ? (
            <Button onClick={() => catchIt()}>🔴 {t('Capturar')} (×{run.balls})</Button>
          ) : (
            <div className="space-y-1">
              <p className="text-xs text-muted">{t('Time cheio: escolha quem sai.')}</p>
              <div className="flex flex-wrap gap-1">{run.team.map((m, i) => <MonChip key={i} mon={m} byId={byId} onClick={() => catchIt(i)} testid={`replace-${i}`} />)}</div>
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
              <ShopCounter money={run.money} />
              <p className="text-xs text-muted">{t('Para quem é a compra (Poké Ball e itens da Bolsa vão para a Bolsa):')}</p>
              <div className="flex flex-wrap gap-1">{run.team.map((m, i) => <MonChip key={i} mon={m} byId={byId} selected={target === i} onClick={() => setTarget(i)} testid={`target-${i}`} />)}</div>
              <div className="grid gap-2 sm:grid-cols-2">
                {p.shop.map((id) => (
                  <div key={id} className="flex items-center justify-between gap-2 rounded-xl bg-bg p-2 text-sm">
                    <img src={spriteUrl(`items/${id}.png`)} alt="" className="pixelated h-8 w-8" onError={(e) => { e.currentTarget.style.visibility = 'hidden' }} />
                    <div className="min-w-0 flex-1">
                      <p className="font-bold" data-no-translate>{prettySlug(id)}</p>
                      <p className="text-xs text-muted">{itemHelp(id)}</p>
                    </div>
                    <Button data-testid={`buy-${id}`} disabled={run.money < shopPrice(run, id)} onClick={() => save(buyItem(run, id, Math.min(target, run.team.length - 1), data))}>
                      💰{shopPrice(run, id)}
                    </Button>
                  </div>
                ))}
              </div>
            </div>
          )}
          <BagPanel run={run} byId={byId} save={save} />
          <ItemsPanel run={run} byId={byId} save={save} />
          {down && <p className="text-sm font-bold text-red-500">{t('O time todo está desmaiado: use um Revive ou desista.')}</p>}
          <Button className="w-full" disabled={down} color="linear-gradient(90deg,#DC2626,#9333EA)" onClick={() => { const next = nextFloor(run, data); save(next); onNext(next) }} data-testid="factory-next">
            ⚔️ {t('Próximo andar ({0})').replace('{0}', run.floor)}
          </Button>
        </>
      )}
    </section>
  )
}

/** A loja: os vendedores atrás do balcão. */
function ShopCounter({ money }) {
  return (
    <div className="relative overflow-hidden rounded-xl bg-gradient-to-b from-sky-300 to-sky-100 text-slate-900">
      <div className="absolute left-3 top-2 rounded-lg bg-white/80 px-2 py-0.5 text-sm font-black">🛒 Poké Mart</div>
      <div className="absolute right-3 top-2 rounded-lg bg-white/80 px-2 py-0.5 text-sm font-black">💰 {money}</div>
      <div className="flex items-end justify-center gap-2 pt-6">
        <img src={spriteUrl('trainers/sd-clerk.png')} alt="" className="pixelated h-36 w-36 object-contain object-bottom" />
        <img src={spriteUrl('trainers/sd-clerkf.png')} alt="" className="pixelated h-36 w-36 object-contain object-bottom" />
      </div>
      <div className="relative -mt-14 h-14 border-t-[6px] border-amber-400 bg-gradient-to-b from-amber-600 to-amber-800 shadow-inner">
        <p className="pt-4 text-center text-xs font-bold text-amber-50">{t('Bem-vindo! Do que você precisa?')}</p>
      </div>
    </div>
  )
}

function itemHelp(id) {
  if (id === 'poke-ball') return t('Para capturar os selvagens')
  if (id === 'revive') return t('Revive com metade do HP')
  if (HEAL_SHARE[id]) return HEAL_SHARE[id] >= 1 ? t('Recupera todo o HP') : t('Recupera {0}% do HP').replace('{0}', Math.round(HEAL_SHARE[id] * 100))
  if (id === 'rare-candy') return t('+1 nível')
  if (VITAMINS[id]) return t('+{0} EVs em {1}, sem limite').replace('{0}', VITAMIN_EVS).replace('{1}', STAT_LABEL[VITAMINS[id]])
  if (id === 'bottle-cap') return t('+{0} IVs em todos os atributos, sem limite').replace('{0}', BOTTLE_CAP_IVS)
  if (HELD_BOOST[id]) {
    const boost = Object.entries(HELD_BOOST[id]).map(([s, v]) => `+${Math.round(v * 100)}% ${STAT_LABEL[s]}`).join(', ')
    return t('Segura o item; se já tem um, vira extra ({0})').replace('{0}', boost)
  }
  return ''
}
