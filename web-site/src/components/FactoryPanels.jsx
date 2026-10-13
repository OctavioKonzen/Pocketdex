// As telas da Battle Factory (lib/factoryRun.js): o começo (o inicial grátis,
// comprar Pokémon e shiny com as moedas, continuar a corrida, a história da
// região) e a corrida em tela cheia, no lugar da batalha (FactoryScreen): o
// resultado do andar (XP, Enfermeira Joy, drops), o capturado, a carta de
// bônus, a loja com "Continuar" e o mapa com os caminhos de cada andar (Bolsa,
// itens, golpes e mecânicas em todos). Igual ao app (lib/screens/factory_panels.dart).

import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import PokeIcon from './PokeIcon'
import Sprite from './Sprite'
import { BattleBackground, battleScale, battleScene, foeBottom, PlatformBase } from './BattleScene'
import BwBag from './BwBag'
import BwParty from './BwParty'
import { TrainerSprite } from './Trainer'
import { Button, SearchInput } from './ui'
import { getFactoryData, shinyPath, spriteUrl } from '../lib/data'
import { learnsetOf, movesFor } from '../lib/factoryBattle'
import {
  BAG_ITEMS, bossOf, FORKS, ROUTE_LENGTH, routePos, targetOf, BOTTLE_CAP_IVS, buyItem, buyPokemon, canEvolveWith, capture, CARDS, chooseNode, claimStarter, endRun, equipFromStash,
  factoryOf, freePick, gimmickOf, gimmicksOf, HEAL_SHARE, HELD_BOOST, isBattleNode, MAX_TEAM, nextFloor, pokemonPrice, routeCities, setGimmick, setMainItem,
  shinyPrice, shopOwned, shopPrice, skipCapture, startersOf, startRun, storyLine, takeCard, teachMove, teamDown, applyBagItem, unlockShiny, VITAMIN_EVS, VITAMINS,
  buyShiny, forSale, normalizeOwned, UPGRADES, upgradeLevel, upgradePrice, upgradeValue, buyUpgrade,
  tradeMon, skipTrade, TRADE_LEVELS, progress, ACHIEVEMENTS, LUCKY_EGG, ESCAPE_HP, BALL_TIERS, rerollRoute, setLead, blindPick, bossScene,
} from '../lib/factoryRun'
import { t } from '../lib/i18n'
import { prettyName } from '../lib/pokemon'
import { usePokemonIndex } from '../lib/pokemonIndex'
import { prettySlug } from '../lib/teamSets'
import { useStore } from '../lib/store'
import { useMyTrainer, useTrainers } from '../lib/trainers'

/** Salva a Factory (meta e corrida) na conta. */
export const saveFactory = (factory) => useStore.getState().updateLeague((l) => ({ ...l, factory }))
// Só nos testes com os emuladores: deixa o teste montar uma corrida (por exemplo, numa bifurcação).
if (import.meta.env.VITE_EMULATORS && typeof window !== 'undefined') window.__factory = { saveFactory, get: () => factoryOf(useStore.getState().league) }
export const useFactory = () => factoryOf(useStore((s) => s.league))

export function useFactoryData() {
  const [data, setData] = useState(null)
  useEffect(() => {
    getFactoryData().then(setData).catch(() => setData(null))
  }, [])
  return data
}

const STAT_LABEL = { hp: 'HP', atk: 'Atk', def: 'Def', spa: 'SpA', spd: 'SpD', spe: 'Spe' }

/** Nome de um item da corrida (TM, pedra, Cristal Z...), como nos jogos (não traduz). */
const itemName = (id) => (id.startsWith('tm:') ? `TM ${prettySlug(id.slice(3))}` : prettySlug(id.startsWith('evo:') ? id.slice(4) : id))
/** O sprite do item (TM, ficha de serviço e Cristal Z têm nomes próprios). */
function itemIcon(id) {
  if (id.startsWith('tm:')) return spriteUrl('items/tm-normal.png')
  if (id.startsWith('evo:')) return spriteUrl(`items/${id.slice(4)}.png`)
  const own = { 'move-tutor': 'tm-case', 'move-reminder': 'heart-scale', 'dynamax-band': 'wishing-piece', 'tera-orb': 'tera-orb' }[id]
  return spriteUrl(`items/${own ?? (id.endsWith('-z') ? `${id}--held` : id)}.png`)
}
const hide = (e) => { e.currentTarget.style.visibility = 'hidden' }
const GIMMICK_LABEL = { mega: 'Mega', z: 'Z-Move', dmax: 'Dynamax', tera: 'Tera' }

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
          @ {itemName(mon.item)}
          {mon.extras?.length ? ` +${mon.extras.length}` : ''}
        </span>
      )}
    </button>
  )
}

/** O dinheiro e a Bolsa da corrida (Poké Balls e remédios). */
function RunStatus({ run }) {
  return (
    <p className="flex flex-wrap items-center gap-x-3 gap-y-1 text-sm font-bold">
      <span>💰 {run.money}</span>
      {BAG_ITEMS.filter((id) => run.bag[id] > 0).map((id) => (
        <span key={id} className="inline-flex items-center gap-1" data-no-translate title={prettySlug(id)}>
          <img src={spriteUrl(`items/${id}.png`)} alt="" className="pixelated h-6 w-6" />×{run.bag[id]}
        </span>
      ))}
    </p>
  )
}

/** Os bolsos da Bolsa da corrida (como no Black & White). */
const BAG_POCKETS = [
  { id: 'items', label: 'Itens', img: 'leftovers' },
  { id: 'medicine', label: 'Remédios', img: 'potion' },
  { id: 'balls', label: 'Poké Balls', img: 'poke-ball' },
  { id: 'tms', label: 'TMs e golpes', img: 'tm-normal' },
  { id: 'key', label: 'Itens-chave', img: 'key-stone' },
]
const pocketOf = (id) => (BALL_TIERS.includes(id) || id.endsWith('-ball') ? 'balls' : id === 'revive' || HEAL_SHARE[id] ? 'medicine' : 'items')

/**
 * A Bolsa fora da batalha, separada em bolsos: remédios em quem está ferido,
 * Revive em quem desmaiou, segurar os itens guardados e ensinar os TMs.
 */
function BagPanel({ run, byId, save, onClose }) {
  const [selected, setSelected] = useState(null)
  const [using, setUsing] = useState(null) // { kind, id }: falta escolher em quem
  const [teaching, setTeaching] = useState(null)
  const items = Object.fromEntries(BAG_POCKETS.map((p) => [p.id, []]))
  for (const id of BAG_ITEMS) {
    if (!(run.bag[id] > 0)) continue
    const pocket = pocketOf(id)
    const usable = pocket === 'medicine' && run.team.some((_, i) => applyBagItem(run, id, i))
    items[pocket].push({ id, name: prettySlug(id), count: run.bag[id], icon: spriteUrl(`items/${id}.png`), help: itemHelp(id),
      ...(pocket === 'medicine' ? { onUse: () => setUsing({ kind: 'bag', id }), disabled: !usable } : {}) })
  }
  ;(run.stash ?? []).forEach((id, k) => {
    items.items.push({ id: `stash:${k}`, name: itemName(id), icon: itemIcon(id), help: `${itemHelp(id)} ${t('(guardado: escolha quem segura)')}`, use: t('SEGURAR'), onUse: () => setUsing({ kind: 'stash', id: k }) })
  })
  for (const [move, n] of Object.entries(run.tms ?? {})) {
    if (n > 0) items.tms.push({ id: `tm:${move}`, name: itemName(`tm:${move}`), count: n, icon: itemIcon(`tm:${move}`), help: itemHelp(`tm:${move}`), use: t('ENSINAR'), onUse: () => setUsing({ kind: 'teach' }) })
  }
  for (const [token, n] of Object.entries(run.tokens ?? {})) {
    if (n > 0) items.tms.push({ id: token, name: prettySlug(token), count: n, icon: itemIcon(token), help: itemHelp(token), use: t('ENSINAR'), onUse: () => setUsing({ kind: 'teach' }) })
  }
  for (const [flag, id] of [['townMap', 'town-map'], ['dmax', 'dynamax-band'], ['tera', 'tera-orb'], ['expShare', 'exp-share']]) {
    if (run[flag]) items.key.push({ id, name: prettySlug(id), icon: itemIcon(id), help: itemHelp(id) })
  }
  const pockets = BAG_POCKETS.map((p) => ({ ...p, items: items[p.id] }))
  const pick = (i) => {
    if (using.kind === 'bag') save(applyBagItem(run, using.id, i))
    else if (using.kind === 'stash') save(equipFromStash(run, using.id, i))
    else { setTeaching(i); setUsing(null); return }
    setUsing(null)
    setSelected(null)
  }
  if (teaching != null) {
    return (
      <div className="p-2">
        <OverlayClose title={`📀 ${t('Ensinar golpe')}`} onClose={() => setTeaching(null)} />
        <MoveTeacher run={run} index={teaching} save={save} onClose={() => setTeaching(null)} />
      </div>
    )
  }
  // Escolher em quem: a tela do time do Black & White, no mesmo lugar.
  if (using) {
    return (
      <BwParty
        title={using.kind === 'stash' ? t('Quem vai segurar?') : using.kind === 'teach' ? t('Ensinar a quem?') : t('Usar em qual Pokémon?')}
        team={partyOf(run, byId)}
        testid="bag-target"
        disabled={(i) => using.kind === 'bag' && !applyBagItem(run, using.id, i)}
        onPick={pick}
        onCancel={() => setUsing(null)}
      />
    )
  }
  return <BwBag pockets={pockets} onClose={onClose} selected={selected} onSelect={(id) => { setSelected(id); setUsing(null) }} testid="factory-bag" />
}

/** O time da corrida para a tela do time (BwParty). */
const partyOf = (run, byId) => run.team.map((m) => ({ id: m.id, shiny: m.shiny, name: t(prettyName(byId?.get(m.id)?.name ?? '')), level: m.level, hp: m.hp ?? 1, sub: m.item ? itemName(m.item) : undefined }))

/**
 * O time: o item principal de cada um (efeito de verdade) e os extras
 * (porcentagem bem menor), a mecânica (Mega, Z, Dynamax, Tera), ensinar
 * golpes (TM, Move Tutor, Move Reminder) e os itens guardados (drops).
 */
function TeamPanel({ run, data, byId, save, open = false }) {
  const [teaching, setTeaching] = useState(null)
  const [stashItem, setStashItem] = useState(null)
  const canTeach = Object.values(run.tms ?? {}).some((n) => n > 0) || Object.values(run.tokens ?? {}).some((n) => n > 0)
  return (
    <details open={open} className="rounded-xl bg-bg p-2" data-testid="factory-items">
      <summary className="cursor-pointer text-sm font-bold">🧩 {t('Time: itens, golpes e mecânicas')}</summary>
      <p className="my-1 text-xs text-muted">{t('O principal tem o efeito de verdade; os outros dão só uma porcentagem pequena no atributo. Toque num extra para ele virar o principal.')}</p>
      {(run.stash ?? []).length > 0 && (
        <div className="mt-2 rounded-lg bg-card p-2 text-xs" data-testid="factory-stash">
          <p className="font-bold">🎁 {t('Itens guardados (toque e escolha quem segura)')}</p>
          <div className="mt-1 flex flex-wrap gap-1">
            {run.stash.map((id, k) => (
              <button key={k} type="button" onClick={() => setStashItem(k)} aria-pressed={stashItem === k}
                className={`flex items-center gap-1 rounded-lg bg-bg px-2 py-1 font-bold ring-2 ${stashItem === k ? 'ring-amber-500' : 'ring-transparent'}`} data-no-translate>
                <img src={itemIcon(id)} alt="" className="pixelated h-6 w-6" onError={hide} />{itemName(id)}
              </button>
            ))}
          </div>
          {stashItem != null && (
            <div className="mt-1 flex flex-wrap gap-1">
              {run.team.map((m, i) => <MonChip key={i} mon={m} byId={byId} onClick={() => { save(equipFromStash(run, stashItem, i)); setStashItem(null) }} testid={`equip-${i}`} />)}
            </div>
          )}
        </div>
      )}
      {run.team.map((m, i) => {
        const options = gimmicksOf(data, run, m)
        return (
          <div key={i} className="mt-2 flex flex-wrap items-center gap-1 text-xs">
            <PokeIcon id={m.id} shiny={Boolean(m.shiny)} className="h-8 w-8" />
            {i === 0 ? (
              <span className="rounded-lg bg-emerald-500/20 px-2 py-1 font-bold">{t('Abre a batalha')}</span>
            ) : (
              <button type="button" onClick={() => save(setLead(run, i))} className="cursor-pointer rounded-lg bg-card px-2 py-1 font-bold hover:ring-2 hover:ring-emerald-500" data-testid={`lead-${i}`}>
                ⬆ {t('Primeiro na batalha')}
              </button>
            )}
            {m.item && <span className="rounded-lg bg-amber-500/20 px-2 py-1 font-bold" data-no-translate>★ {itemName(m.item)}</span>}
            {(m.extras ?? []).map((id, k) => (
              <button key={k} type="button" onClick={() => save(setMainItem(run, i, k))} className="cursor-pointer rounded-lg bg-card px-2 py-1 hover:ring-2 hover:ring-amber-500" data-no-translate>
                {itemName(id)}
              </button>
            ))}
            {options.length > 0 && (
              <select aria-label={t('Mecânica')} value={gimmickOf(data, run, m) || 'none'} onChange={(e) => save(setGimmick(run, i, e.target.value))}
                className="rounded-lg border border-line bg-card px-1 py-1">
                <option value="none">{t('Sem mecânica')}</option>
                {options.map((g) => <option key={g} value={g}>{GIMMICK_LABEL[g]}</option>)}
              </select>
            )}
            {canTeach && <Button onClick={() => setTeaching(i)} data-testid={`teach-${i}`}>📀 {t('Ensinar golpe')}</Button>}
            {teaching === i && <MoveTeacher run={run} index={i} save={save} onClose={() => setTeaching(null)} />}
          </div>
        )
      })}
    </details>
  )
}

/** Ensinar um golpe: TM (os que ele aprende por máquina), Move Tutor (tutor e ovo) ou Move Reminder (os do nível). */
function MoveTeacher({ run, index, save, onClose }) {
  const mon = run.team[index]
  const [info, setInfo] = useState(null)
  const [choice, setChoice] = useState(null)
  useEffect(() => {
    let live = true
    Promise.all([learnsetOf(mon.id), mon.moves?.length ? mon.moves : movesFor(mon.id, mon.level)]).then(([learnset, current]) => live && setInfo({ learnset, current }))
    return () => { live = false }
  }, [mon.id, mon.level, mon.moves])
  if (!info) return <p className="w-full text-muted">...</p>
  const has = (move, ...ways) => info.learnset.some((m) => m[0] === move && ways.includes(m[1]))
  const unique = (list) => [...new Set(list)].filter((m) => !info.current.includes(m))
  const sources = [
    ['tm', unique(Object.entries(run.tms ?? {}).filter(([move, n]) => n > 0 && has(move, 'machine')).map(([move]) => move))],
    ['move-tutor', run.tokens?.['move-tutor'] > 0 ? unique(info.learnset.filter((m) => m[1] === 'tutor' || m[1] === 'egg').map((m) => m[0])) : []],
    ['move-reminder', run.tokens?.['move-reminder'] > 0 ? unique(info.learnset.filter((m) => m[1] === 'level-up' && m[2] <= mon.level).map((m) => m[0])) : []],
  ].filter(([, list]) => list.length)
  const label = { tm: t('TM'), 'move-tutor': 'Move Tutor', 'move-reminder': 'Move Reminder' }
  const teach = (slot, picked = choice) => {
    const next = teachMove(run, index, picked.move, info.current, slot, picked.source)
    if (next) save(next)
    onClose()
  }
  return (
    <div className="w-full space-y-1 rounded-lg bg-card p-2" data-testid="move-teacher">
      {!sources.length && <p className="text-muted">{t('Nada para ensinar a ele agora (TM que ele aprende ou fichas de Move Tutor/Reminder).')}</p>}
      {!choice && sources.map(([source, list]) => (
        <div key={source}>
          <p className="font-bold">{label[source]}</p>
          <div className="flex max-h-32 flex-wrap gap-1 overflow-y-auto">
            {list.map((move) => (
              <button key={move} type="button" onClick={() => (info.current.length < 4 ? teach(-1, { move, source }) : setChoice({ move, source }))}
                className="rounded-lg bg-bg px-2 py-1 hover:ring-2 hover:ring-amber-500" data-no-translate>{prettySlug(move)}</button>
            ))}
          </div>
        </div>
      ))}
      {choice && (
        <div>
          <p className="font-bold">{t('Esquecer qual golpe para aprender {0}?').replace('{0}', prettySlug(choice.move))}</p>
          <div className="flex flex-wrap gap-1">
            {info.current.map((move, slot) => (
              <button key={move} type="button" onClick={() => teach(slot)} className="rounded-lg bg-bg px-2 py-1 hover:ring-2 hover:ring-red-500" data-no-translate>{prettySlug(move)}</button>
            ))}
          </div>
        </div>
      )}
      <button type="button" onClick={onClose} className="text-muted underline">{t('Cancelar')}</button>
    </div>
  )
}

/** O texto da história: o começo da região (1º chefe) e quem vem a seguir. */
function StoryPanel({ run, data }) {
  const boss = bossOf(data, run)
  const intro = run.boss.step === 0 ? storyLine(data, boss.region, 'intro') : ''
  return (
    <div className="space-y-1 rounded-xl bg-indigo-500/10 p-2 text-sm" data-testid="factory-story">
      <p className="font-black">📖 <span data-no-translate>{boss.region} · {boss.game}</span></p>
      {intro && <p>{intro}</p>}
      <p className="text-muted">{storyLine(data, boss.region, boss.kind, boss.name)}</p>
    </div>
  )
}

export const bossKindLabel = (kind) => ({ gym: t('Líder de ginásio'), rival: t('Rival'), villain: t('Vilão'), elite: t('Elite Four'), champion: t('Campeão') })[kind] ?? ''

/** O próximo chefe de cidade (o destino da rota). */
function NextBoss({ run, data }) {
  const boss = targetOf(data, run)
  return (
    <p className="text-xs text-muted">
      👑 {t('Chefe em {0}:').replace('{0}', boss.city ?? '')}{' '}
      <b data-no-translate>{boss.name}</b> · {bossKindLabel(boss.kind)} · <span data-no-translate>{boss.region ?? data.bosses[run.boss.region].region} ({data.bosses[run.boss.region].game})</span>
    </p>
  )
}

/** O começo: corrida em andamento (continuar no mapa), ou escolher o inicial; e a loja de Pokémon (moedas). */
export function FactoryHub({ onContinue, busy }) {
  const factory = useFactory()
  const data = useFactoryData()
  const byId = usePokemonIndex()
  const [pick, setPick] = useState(null)
  const [query, setQuery] = useState('')
  const [lucky, setLucky] = useState(null)
  const run = factory.run

  const shopList = useMemo(() => {
    if (!data || !byId) return []
    const q = query.trim().toLowerCase()
    return Object.entries(data.species)
      .map(([id, [, bst]]) => ({ id: Number(id), bst, price: pokemonPrice(bst), name: byId.get(Number(id))?.name ?? '' }))
      // Só a primeira forma está à venda (a evolução vem jogando).
      .filter((p) => forSale(data, p.id) && !factory.owned.includes(p.id) && (!q || p.name.includes(q)))
      .sort((a, b) => a.price - b.price || a.id - b.id)
      .slice(0, 24)
  }, [data, byId, query, factory.owned])

  // Contas antigas que compraram uma forma evoluída: ficam com a primeira forma dela.
  useEffect(() => {
    if (!data) return
    const fixed = normalizeOwned(factory, data)
    if (fixed !== factory) saveFactory(fixed)
  }, [data, factory])

  if (!data) return <p className="text-sm text-muted">...</p>
  return (
    <div className="space-y-4" data-testid="factory-hub">
      <div className="rounded-2xl bg-bg p-3 text-sm">
        <p className="font-black">🏭 {t('Battle Factory')}</p>
        <p className="text-muted">
          {t('Um roguelike sem fim com a história de cada região: escolha um inicial no nível 5 e siga o mapa de cidade em cidade. Em cada andar você escolhe o caminho: Pokémon selvagem do bioma da rota (capture jogando a bola na batalha, antes de ele desmaiar; cada bola tem a sua chance), treinador, treinador forte (sempre deixa um item), Poké Mart, Centro Pokémon (raro) ou um evento. A cada 10 andares, na cidade, vem um chefe da história: líderes de ginásio, rival e vilões (com times cada vez maiores), a Elite Four e o Campeão; nos andares 5, 15, 25... pode aparecer uma Mega, um Gigantamax ou um lendário. O time não é curado entre os andares (só com a Bolsa, a loja, o Centro Pokémon ou, com 5% de chance, a Enfermeira Joy). Sem limite de nível, IVs, EVs ou itens; shiny é 1 em 4096. Perdeu: a pontuação vira moedas para comprar Pokémon e começar com eles.')}
        </p>
        <p className="mt-1 font-bold">
          {t('Recorde: andar {0}').replace('{0}', factory.best)} · 🪙 {factory.coins} {t('moedas')}
        </p>
        {factory.refunded > 0 && (
          <p className="mt-1 rounded-lg bg-amber-500/15 px-2 py-1 font-bold" data-testid="factory-refunded">
            🪙 {t('Agora só a primeira forma fica à venda: devolvemos {0} moedas dos evoluídos que você tinha comprado.').replace('{0}', factory.refunded)}{' '}
            <button type="button" className="cursor-pointer underline" onClick={() => saveFactory({ ...factory, refunded: 0 })}>{t('OK')}</button>
          </p>
        )}
        {factory.last && !run && <p className="text-muted">{t('Última corrida: andar {0}, +{1} moedas.').replace('{0}', factory.last.floor).replace('{1}', factory.last.coins)}</p>}
      </div>

      {run ? (
        <div className="space-y-3 rounded-2xl bg-bg p-3" data-testid="factory-run">
          <p className="font-black">{t('Corrida em andamento: andar {0}').replace('{0}', run.floor)}</p>
          <RunStatus run={run} />
          <StoryPanel run={run} data={data} />
          <NextBoss run={run} data={data} />
          <div className="flex flex-wrap gap-1">{run.team.map((m, i) => <MonChip key={i} mon={m} byId={byId} />)}</div>
          {run.cards.length > 0 && <p className="text-xs text-muted">{t('Cartas')}: {run.cards.map((c) => t(CARDS[c].label)).join(' · ')}</p>}
          <div className="flex flex-wrap gap-2">
            <Button data-testid="factory-continue-run" disabled={busy} onClick={onContinue}>🗺️ {t('Continuar a corrida')}</Button>
            <Button color="#64748b" onClick={() => window.confirm(t('Desistir da corrida? A pontuação vira moedas.')) && saveFactory(endRun(factory, run))}>{t('Desistir (recebe as moedas)')}</Button>
          </div>
        </div>
      ) : (
        <div className="space-y-2">
          <p className="text-sm font-semibold text-muted">
            {freePick(factory) ? t('Escolha o seu inicial grátis (de qualquer geração). Os outros você compra com moedas.') : t('Escolha com quem começar')}
          </p>
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
              const meta = claimStarter(factory, data, pick.id)
              const next = startRun(meta, data, pick.id, Math.floor(Math.random() * 2 ** 31), pick.shiny)
              if (!next) return
              saveFactory({ ...meta, run: next })
              onContinue()
            }}
          >
            🏭 {t('Começar a corrida')}
          </Button>
        </div>
      )}

      <details className="rounded-2xl bg-bg p-3" data-testid="factory-upgrades" open={!run}>
        <summary className="cursor-pointer font-bold">⬆️ {t('Melhorias permanentes')}</summary>
        <p className="my-2 text-xs text-muted">{t('Compradas com moedas, valem em todas as próximas corridas. Cada nível custa mais.')}</p>
        <div className="grid gap-2 sm:grid-cols-2">
          {Object.entries(UPGRADES).map(([id, up]) => {
            const level = upgradeLevel(factory, id)
            const price = upgradePrice(factory, id)
            const next = (up.offset ?? 0) + (level + 1) * up.per
            return (
              <div key={id} className="flex items-center gap-2 rounded-xl bg-card p-2 text-xs" data-testid={`upgrade-${id}`}>
                <div className="min-w-0 flex-1">
                  <p className="font-bold">{t(up.label).replace('{0}', price == null ? (up.offset ?? 0) + upgradeValue(factory, id) : next)}</p>
                  <p className="text-muted">
                    {'★'.repeat(level)}{'☆'.repeat(up.max - level)} · {price == null ? t('No máximo') : `🪙 ${price}`}
                  </p>
                </div>
                {price != null && (
                  <Button disabled={factory.coins < price} onClick={() => { const n = buyUpgrade(factory, id); if (n) saveFactory(n) }}>
                    {t('Comprar')}
                  </Button>
                )}
              </div>
            )
          })}
        </div>
      </details>

      <details className="rounded-2xl bg-bg p-3" data-testid="factory-achievements">
        <summary className="cursor-pointer font-bold">🏆 {t('Conquistas')} ({(factory.achievements ?? []).length}/{Object.keys(ACHIEVEMENTS).length})</summary>
        <p className="my-2 text-xs text-muted">{t('Cada conquista dá moedas uma vez.')}</p>
        <div className="grid gap-1 sm:grid-cols-2">
          {Object.entries(ACHIEVEMENTS).map(([id, a]) => {
            const done = (factory.achievements ?? []).includes(id)
            return (
              <p key={id} className={`rounded-lg px-2 py-1 text-xs ${done ? 'bg-amber-500/15 font-bold' : 'bg-card text-muted'}`}>
                {done ? '🏆' : '🔒'} {t(a.label)} · 🪙{a.coins}
              </p>
            )
          })}
        </div>
      </details>

      {(factory.hall ?? []).length > 0 && (
        <details className="rounded-2xl bg-bg p-3" data-testid="factory-hall">
          <summary className="cursor-pointer font-bold">👑 {t('Hall da Fama')}</summary>
          <div className="mt-2 space-y-2">
            {factory.hall.map((h) => (
              <div key={h.key} className="rounded-xl bg-card p-2">
                <p className="text-xs font-bold">{t('Campeão no andar {0}').replace('{0}', h.floor)}</p>
                <div className="mt-1 flex flex-wrap gap-1">{h.team.map((m, i) => <MonChip key={i} mon={m} byId={byId} />)}</div>
              </div>
            ))}
          </div>
        </details>
      )}

      <details className="rounded-2xl bg-bg p-3" data-testid="factory-shiny-shop">
        <summary className="cursor-pointer font-bold">✨ {t('Inicial shiny')}</summary>
        <p className="my-2 text-xs text-muted">{t('Shiny tem +10% em todos os atributos. Capture um inicial shiny na corrida para liberar o shiny dele, ou transforme com moedas (bem caro).')}</p>
        <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
          {factory.owned.filter((id) => !(factory.shinies ?? []).includes(id)).map((id) => {
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
        <p className="my-2 text-xs text-muted">{t('Só a primeira forma de cada um (a evolução vem jogando). Os mais fortes custam mais. Comprado, ele aparece entre os iniciais. Tem 1 chance em 4096 de vir shiny.')}</p>
        {freePick(factory) && <p className="mb-2 text-xs font-bold text-amber-500">{t('Primeiro escolha o seu inicial grátis.')}</p>}
        {lucky && <p className="mb-2 rounded-lg bg-amber-500/15 p-2 text-sm font-bold">✨ {t('{0} veio shiny!').replace('{0}', t(prettyName(byId?.get(lucky)?.name ?? '')))}</p>}
        <SearchInput value={query} onChange={setQuery} placeholder={t('Buscar Pokémon')} />
        <div className="mt-2 grid grid-cols-2 gap-2 sm:grid-cols-3">
          {shopList.map((p) => (
            <div key={p.id} className="flex items-center gap-2 rounded-xl bg-card p-2">
              <PokeIcon id={p.id} className="h-10 w-10" />
              <div className="min-w-0 flex-1 text-xs">
                <p className="truncate font-bold" data-no-translate>{t(prettyName(p.name))}</p>
                <p className="text-muted">🪙 {p.price}</p>
              </div>
              <Button disabled={factory.coins < p.price || freePick(factory)} onClick={() => {
                const next = buyPokemon(factory, data, p.id, Math.random())
                if (!next) return
                if (next.shinies.length > (factory.shinies ?? []).length) setLucky(p.id)
                saveFactory(next)
              }}>
                {t('Comprar')}
              </Button>
            </div>
          ))}
        </div>
      </details>
    </div>
  )
}

/** Os biomas das rotas: nome, símbolo e as cores do caminho no mapa. */
const BIOME_INFO = {
  grass: { label: 'Campo', icon: '🌾', color: '#65a30d' },
  forest: { label: 'Floresta', icon: '🌲', color: '#15803d' },
  water: { label: 'Mar', icon: '🌊', color: '#0284c7' },
  cave: { label: 'Caverna', icon: '🪨', color: '#57534e' },
  mountain: { label: 'Montanha', icon: '⛰️', color: '#78716c' },
  volcano: { label: 'Vulcão', icon: '🌋', color: '#dc2626' },
  city: { label: 'Cidade', icon: '🏙️', color: '#6366f1' },
  snow: { label: 'Neve', icon: '❄️', color: '#38bdf8' },
  tower: { label: 'Torre', icon: '👻', color: '#7c3aed' },
  sky: { label: 'Céu', icon: '☁️', color: '#0ea5e9' },
  beach: { label: 'Praia', icon: '🏖️', color: '#d97706' },
  underwater: { label: 'Fundo do mar', icon: '🐠', color: '#1e40af' },
  swamp: { label: 'Pântano', icon: '🪵', color: '#4d7c0f' },
  sewer: { label: 'Esgoto', icon: '🚰', color: '#475569' },
  icecave: { label: 'Caverna de gelo', icon: '🧊', color: '#0891b2' },
  desert: { label: 'Deserto', icon: '🏜️', color: '#b45309' },
  // As bases das equipes vilãs (só capangas).
  'base-rocket': { label: 'Base da Equipe Rocket', icon: '🏴', color: '#b91c1c' },
  'base-aqua': { label: 'Base da Equipe Aqua', icon: '🏴', color: '#1d4ed8' },
  'base-magma': { label: 'Base da Equipe Magma', icon: '🏴', color: '#c2410c' },
  'base-galactic': { label: 'Base da Equipe Galáctica', icon: '🏴', color: '#0e7490' },
  'base-plasma': { label: 'Castelo da Equipe Plasma', icon: '🏴', color: '#1e40af' },
  'base-flare': { label: 'Laboratório da Equipe Flare', icon: '🏴', color: '#dc2626' },
  'base-skull': { label: 'Base da Equipe Skull', icon: '🏴', color: '#6b21a8' },
  'base-aether': { label: 'Paraíso Aether', icon: '🏴', color: '#ca8a04' },
  'base-star': { label: 'Base da Equipe Estrela', icon: '🏴', color: '#db2777' },
}
/** Cada ponto do mapa: símbolo, nome e o que tem nele. */
const NODE_INFO = {
  wild: { icon: '🌿', label: 'Pokémon selvagem', help: 'Dá para capturar: jogue a bola antes de ele desmaiar.' },
  trainer: { icon: '🧢', label: 'Treinador', help: 'Dinheiro em dobro.' },
  ace: { icon: '💪', label: 'Treinador forte', help: 'Um Pokémon a mais e mais forte; sempre deixa um item.' },
  mart: { icon: '🛒', label: 'Poké Mart', help: 'Uma loja maior (sem batalha, sem XP).' },
  center: { icon: '🏥', label: 'Centro Pokémon', help: 'Cura o time todo, até quem desmaiou (sem batalha).' },
  event: { icon: '❓', label: 'Evento', help: 'Itens, dinheiro, frutas ou uma ficha de Move Tutor (sem batalha).' },
  trade: { icon: '🔁', label: 'Troca', help: 'Alguém da rota troca um Pokémon com você: o que vem chega 3 níveis acima (com o item de quem foi).' },
  wildboss: { icon: '🐉', label: 'Chefe sem treinador', help: 'Uma Mega, um Gigantamax ou um lendário. Dá para capturar.' },
  boss: { icon: '👑', label: 'Chefe', help: '' },
}
const CITY_KIND_SET = new Set(['gym', 'elite', 'champion'])
const EVENT_TEXT = {
  items: 'Você achou {1}× {0} no caminho!',
  money: 'Um treinador perdeu 💰{0} e não voltou para buscar.',
  berries: 'Frutas no caminho: o time recuperou 30% do HP.',
  tutor: 'Um velho professor te deu uma ficha de Move Tutor.',
}

/** O passo da tela depois do andar: o que ainda falta ver ou escolher (ou nada: o mapa). */
function stepOf(p) {
  if (!p) return null
  if (!p.seen && (p.exp != null || p.center || p.event)) return 'result'
  if (p.capture) return 'capture'
  if (p.cards) return 'cards'
  if (p.trade) return 'trade'
  if (p.shop) return 'shop'
  return null
}

/** A largura de um elemento (os sprites de treinador são em px). */
function useWidth() {
  const [width, setWidth] = useState(640)
  const observer = useRef(null)
  const ref = useCallback((el) => {
    observer.current?.disconnect()
    if (!el || typeof ResizeObserver === 'undefined') return
    observer.current = new ResizeObserver(([entry]) => setWidth(entry.contentRect.width))
    observer.current.observe(el)
  }, [])
  return [ref, width]
}

/** O campo da batalha (o mesmo cenário dela, no mesmo tamanho: 4:3, como no Black & White), no lugar em que você está. */
function Field({ biome = 'grass', fieldRef, children, testid }) {
  return (
    <div ref={fieldRef} className="relative aspect-[4/3] overflow-hidden rounded-t-2xl border-4 border-b-0 border-slate-800" style={{ background: '#9fdcff' }} data-testid={testid} data-layout="bw">
      <BattleBackground scene={battleScene(biome)} layout="bw" />
      {children}
    </div>
  )
}

/**
 * Um Pokémon da corrida no campo, no mesmo lugar da batalha: o seu de costas
 * (grande, na frente à esquerda) ou de frente lá atrás à direita, do tamanho
 * dele (pela altura) e em cima da base dele.
 */
function FieldMon({ mon, byId, back = false, scene }) {
  const p = byId?.get(mon.id)
  if (!p) return null
  const scale = battleScale(p.height)
  return (
    <div className={back ? 'absolute bottom-[22%] left-[1%] w-[58%]' : 'absolute right-[11%] w-[26%]'} style={back ? undefined : { bottom: `${foeBottom(battleScene(scene)) * 100}%` }}>
      <PlatformBase scene={battleScene(scene)} side={back ? 'mine' : 'foe'} scale={scale} />
      <div className="aspect-square w-full" style={{ transform: `scale(${scale})`, transformOrigin: '50% 100%' }}>
        <Sprite key={`${p.id}-${mon.shiny}`} path={mon.shiny ? shinyPath(p.sprite) : p.sprite} box={p.box} fill={0.95} align="bottom" back={back} battle alt={p.name} />
      </div>
    </div>
  )
}

/** Alguém de pé na base de cima (Enfermeira Joy, o chefe, os vendedores...). */
function FarStand({ children, scene }) {
  return (
    <div className="absolute right-[6%] flex w-[36%] items-end justify-center" style={{ bottom: `${foeBottom(battleScene(scene)) * 100}%` }}>
      {scene && <PlatformBase scene={battleScene(scene)} side="foe" scale={0.8} />}
      <div className="relative flex w-full items-end justify-center">{children}</div>
    </div>
  )
}

/** Os botões do menu, como os da batalha ("▸ LUTAR"); sub: uma linha menor embaixo. */
function MenuButton({ children, sub, onClick, disabled = false, testid, active = false }) {
  return (
    <button type="button" onClick={onClick} disabled={disabled} data-testid={testid}
      className={`dlg-btn cursor-pointer rounded-lg px-2 py-2 text-left disabled:cursor-default disabled:opacity-40 ${active ? 'active' : ''}`}>
      <span className="block font-black">▸ {children}</span>
      {sub && <span className="dlg-sub block pl-3 text-[11px] font-semibold leading-tight">{sub}</span>}
    </button>
  )
}

/** Ao entrar na rota: uma frase do lugar. */
const ROUTE_FLAVOR = {
  grass: 'O vento balança o mato alto: tem Pokémon por toda parte.',
  forest: 'As árvores fecham o céu; algo se mexe entre as folhas.',
  water: 'As ondas batem forte; os Pokémon de Água estão agitados.',
  beach: 'A areia esquenta os pés e o mar brilha ao longe.',
  underwater: 'Tudo fica azul e silencioso lá embaixo.',
  swamp: 'O pântano cheira a veneno e a lama prende os passos.',
  sewer: 'Canos pingando e olhos brilhando no escuro.',
  cave: 'Está escuro e frio; ecos vêm do fundo da caverna.',
  icecave: 'O gelo estala sob os pés; cuidado para não escorregar.',
  mountain: 'O caminho sobe pelas pedras; o ar fica mais fino.',
  desert: 'O sol queima e a areia apaga as pegadas.',
  volcano: 'O chão treme e a lava borbulha por perto.',
  snow: 'A neve cai sem parar e cobre o caminho.',
  city: 'Ruas cheias de treinadores querendo um desafio.',
  sky: 'Nuvens por todo lado: só os que voam passam por aqui.',
  tower: 'Velas acesas e um frio estranho: dizem que a torre é assombrada.',
}
/** O rival e os vilões antes da luta. */
const RIVAL_LINES = [
  'Achou que ia passar sem me enfrentar? Mostre o que aprendeu!',
  'Treinei sem parar desde a última vez. Agora é a minha vez de ganhar!',
  'O seu time melhorou... mas o meu também!',
  'Só um de nós vai chegar ao Campeão. Vamos decidir aqui!',
]
const VILLAIN_LINES = [
  'Os seus Pokémon seriam muito úteis para os nossos planos...',
  'Saia do caminho, criança! Não temos tempo para heróis.',
  'Ninguém atrapalha a nossa equipe e sai ileso!',
]

/**
 * O mapa da cidade (como o Town Map do Black & White) na bifurcação: a rota da
 * cidade de onde veio até a do chefe, você no andar de agora e os caminhos
 * abrindo na frente; toque num caminho para ir por ele.
 */
function TownMap({ route, pos, from, to, title, me, width, fieldRef, onPick, blocked }) {
  const W = 160
  const H = 120
  const END = ROUTE_LENGTH + 1
  const here = pos + 1
  const y0 = 64
  // O que já passou à esquerda; os caminhos com espaço no meio; o resto até a cidade do chefe.
  const left = 14
  const hx = left + (here / END) * 70
  const ox = hx + 30
  const x = (k) => (k <= here ? left + (k / END) * 70 : ox + 14 + ((k - here - 1) / Math.max(1, END - here - 1)) * (W - 14 - ox - 14))
  const n = route.options.length
  const ys = route.options.map((_, k) => y0 + (k - (n - 1) / 2) * Math.min(30, 84 / n))
  return (
    <div ref={fieldRef} className="town-map relative aspect-[4/3] overflow-hidden rounded-t-2xl border-4 border-b-0 border-slate-800" data-testid="factory-map" data-fork="1">
      <svg viewBox={`0 0 ${W} ${H}`} className="absolute inset-0 h-full w-full" aria-hidden="true">
        {/* A rota (o que já passou mais clara) e as cidades nas pontas. */}
        <line x1={x(0)} y1={y0} x2={x(here)} y2={y0} stroke="#fde68a" strokeWidth="3" strokeLinecap="round" />
        <line x1={ox + 14} y1={y0} x2={x(END)} y2={y0} stroke="#93c5fd" strokeWidth="3" strokeDasharray="3 2" strokeLinecap="round" />
        {ys.map((y, k) => (
          <path key={k} d={`M${x(here)} ${y0} C ${x(here) + 12} ${y0}, ${ox - 12} ${y}, ${ox} ${y} C ${ox + 8} ${y}, ${ox + 6} ${y0}, ${ox + 14} ${y0}`} stroke="#fbbf24" strokeWidth="2" fill="none" strokeDasharray="2 1.5" />
        ))}
        {Array.from({ length: END + 1 }, (_, k) => {
          const city = k === 0 || k === END
          return city
            ? <rect key={k} x={x(k) - 5} y={y0 - 5} width="10" height="10" rx="2" fill="#ef4444" stroke="#fff" strokeWidth="1.2" />
            : <circle key={k} cx={x(k)} cy={y0} r="2.4" fill={k < here ? '#fde68a' : '#bfdbfe'} stroke="#1e3a8a" strokeWidth="0.8" />
        })}
      </svg>
      <div className="absolute inset-x-0 top-0 flex items-center justify-between bg-slate-900/80 px-3 py-1 text-xs font-black text-white sm:text-sm">
        <span data-no-translate>🗺️ {title}</span>
        <span>{t('O caminho se divide')}</span>
      </div>
      <span className="absolute -translate-x-1/2 rounded bg-white/90 px-1 text-[10px] font-bold text-slate-900 sm:text-xs" style={{ left: `${(x(0) / W) * 100}%`, top: `${((y0 + 8) / H) * 100}%` }} data-no-translate>🏠 {from ?? t('Início')}</span>
      <span className="absolute -translate-x-1/2 rounded bg-white/90 px-1 text-[10px] font-bold text-slate-900 sm:text-xs" style={{ left: `${(x(END) / W) * 100}%`, top: `${((y0 + 8) / H) * 100}%` }} data-no-translate>👑 {to}</span>
      {me && (
        <span className="absolute -translate-x-1/2 -translate-y-full" style={{ left: `${(x(here) / W) * 100}%`, top: `${((y0 + 2) / H) * 100}%` }}>
          <TrainerSprite trainer={me} box={width * 0.12} />
        </span>
      )}
      {/* Os caminhos: botões no próprio mapa. */}
      {route.options.map((node, k) => {
        const info = NODE_INFO[node.kind]
        const b = node.biome ? BIOME_INFO[node.biome] : null
        return (
          <button key={k} type="button" disabled={!onPick || blocked(node)} onClick={() => onPick(k)} data-testid={`map-pin-${k}`}
            className="absolute flex -translate-x-1/2 -translate-y-1/2 cursor-pointer items-center gap-1 rounded-full border-2 border-white bg-blue-900/90 py-0.5 pl-0.5 pr-2 text-[10px] font-black text-white shadow-lg hover:bg-amber-500 disabled:cursor-default disabled:opacity-50 sm:text-xs"
            style={{ left: `${(ox / W) * 100}%`, top: `${(ys[k] / H) * 100}%` }}>
            <span className="flex h-6 w-6 items-center justify-center rounded-full bg-white text-sm sm:h-7 sm:w-7 sm:text-base">{b ? b.icon : info.icon}</span>
            {t(info.label)}
          </button>
        )
      })}
    </div>
  )
}

/** O título e o "fechar" do que abre por cima do campo. */
function OverlayClose({ title, onClose }) {
  return (
    <div className="sticky top-0 z-10 -mx-2 -mt-2 mb-2 flex items-center justify-between gap-2 bg-slate-900 px-3 py-1.5 text-sm font-black text-white">
      <span className="truncate">{title}</span>
      <button type="button" onClick={onClose} className="cursor-pointer rounded bg-red-600 px-2" aria-label={t('Fechar')} data-testid="overlay-close">✕</button>
    </div>
  )
}

/** A moldura da batalha: o campo, a barra da corrida (dinheiro, Bolsa e time) e a caixa de texto com o menu. */
function BattleFrame({ field, run, byId, text, menu, wideMenu = false, panel = null }) {
  return (
    <div className="select-none">
      {/* A Bolsa, o time, a loja e a troca abrem por cima do campo (a mesma tela, como no jogo; dá para jogar com o celular de lado). */}
      <div className="relative">
        {field}
        {panel && <div className="field-overlay factory-overlay rounded-t-2xl border-4 border-b-0 border-slate-800 bg-bg text-text" data-testid="factory-panel">{panel}</div>}
      </div>
      {run && (
        <div className="flex flex-wrap items-center gap-x-3 gap-y-1 border-x-4 border-slate-800 bg-slate-700 px-2 py-1 text-xs font-bold text-white" data-testid="factory-bar">
          <span>🏭 {t('Andar {0}').replace('{0}', run.floor)}</span>
          <span>💰 {run.money}</span>
          {BAG_ITEMS.filter((id) => run.bag[id] > 0).map((id) => (
            <span key={id} className="inline-flex items-center" data-no-translate title={prettySlug(id)}>
              <img src={spriteUrl(`items/${id}.png`)} alt="" className="pixelated h-5 w-5" />×{run.bag[id]}
            </span>
          ))}
          <span className="ml-auto flex gap-0.5">
            {run.team.map((m, i) => (
              <span key={i} className="flex flex-col items-center" title={t(prettyName(byId?.get(m.id)?.name ?? ''))}>
                <PokeIcon id={m.id} shiny={Boolean(m.shiny)} className={`h-7 w-7 ${(m.hp ?? 1) > 0 ? '' : 'opacity-40 grayscale'}`} />
                <span className="block h-1 w-6 overflow-hidden rounded bg-slate-900">
                  <span className={`block h-full ${(m.hp ?? 1) > 0.5 ? 'bg-emerald-400' : (m.hp ?? 1) > 0.2 ? 'bg-amber-400' : 'bg-red-500'}`} style={{ width: `${Math.max(0, Math.min(1, m.hp ?? 1)) * 100}%` }} />
                </span>
              </span>
            ))}
          </span>
        </div>
      )}
      <div className="flex min-h-36 flex-col gap-2 rounded-b-2xl border-4 border-slate-800 bg-slate-800 p-2">
        <div className="flex flex-col gap-2 sm:flex-row">
          <div className="dlg-box min-h-20 flex-1 space-y-1 rounded-xl border-4 px-4 py-3 text-left text-base font-bold sm:text-lg" data-testid="factory-text">
            {text}
          </div>
          {menu && <div className={`dlg-box grid content-start gap-1 rounded-xl border-4 p-2 ${wideMenu ? 'sm:w-96' : 'grid-cols-2 sm:w-72'}`}>{menu}</div>}
        </div>
      </div>
    </div>
  )
}

/**
 * A corrida em tela cheia, no lugar da batalha e com a cara dela: o campo, a
 * caixa de texto e o menu. O resultado do andar, o capturado, a carta, a loja
 * (com "Continuar") e o mapa com os caminhos do próximo andar.
 * onBattle(run): começa a batalha do caminho escolhido.
 */
export function FactoryScreen({ onBattle, onExit, busy = false }) {
  const factory = useFactory()
  const data = useFactoryData()
  const byId = usePokemonIndex()
  const trainers = useTrainers()
  const me = useMyTrainer()
  const [fieldRef, width] = useWidth()
  const [panel, setPanel] = useState(null) // embaixo do menu: 'bag' | 'team' (na loja, a lista de compras)
  const [unlocked, setUnlocked] = useState(null)
  const [target, setTarget] = useState(0)
  // Conquistas novas (com as moedas) e o Hall da Fama, conforme a corrida anda.
  const [earned, setEarned] = useState([])
  useEffect(() => {
    if (!factory.run) return
    const [next, ids] = progress(factory, factory.run)
    if (next === factory) return
    saveFactory(next)
    if (ids.length) setEarned((list) => [...list, ...ids])
  }, [factory])
  const run = factory.run
  if (!data) return <p className="text-sm text-muted">...</p>
  const name = (id) => t(prettyName(byId?.get(id)?.name ?? ''))
  const save = (next) => {
    if (!next) return
    const out = next.pending && !stepOf(next.pending) ? nextFloor(next, data) : next
    saveFactory({ ...factory, run: out })
  }
  const lead = run?.team.find((m) => (m.hp ?? 1) > 0) ?? run?.team[0]
  const links = run && (
    <div className="mt-2 flex flex-wrap justify-between gap-2 text-sm">
      <button type="button" onClick={onExit} className="cursor-pointer text-muted hover:text-text">← {t('Sair (a corrida fica salva)')}</button>
      <button type="button" onClick={() => window.confirm(t('Desistir da corrida? A pontuação vira moedas.')) && saveFactory(endRun(factory, run))} className="cursor-pointer text-muted hover:text-red-500">
        {t('Desistir (recebe as moedas)')}
      </button>
    </div>
  )
  const extras = run && (panel === 'bag' || panel === 'team') && (
    panel === 'bag' ? (
      <BagPanel run={run} byId={byId} save={save} onClose={() => setPanel(null)} />
    ) : (
      <div className="p-2">
        <OverlayClose onClose={() => setPanel(null)} title={`🧩 ${t('Time: itens, golpes e mecânicas')}`} />
        <TeamPanel run={run} data={data} byId={byId} save={save} open />
      </div>
    )
  )
  const tools = (
    <>
      <MenuButton onClick={() => setPanel(panel === 'bag' ? null : 'bag')} active={panel === 'bag'} testid="factory-menu-bag">{t('BOLSA')}</MenuButton>
      <MenuButton onClick={() => setPanel(panel === 'team' ? null : 'team')} active={panel === 'team'} testid="factory-menu-team">{t('TIME')}</MenuButton>
    </>
  )

  // Acabou: o andar, as moedas e o recorde.
  if (!run) {
    return (
      <section data-testid="factory-over">
        <BattleFrame
          field={<Field biome="over" fieldRef={fieldRef}><div className="absolute inset-0 flex items-center justify-center text-7xl">🏁</div></Field>}
          text={<>
            <p>{t('A corrida acabou')}</p>
            {factory.last && <p className="text-sm">{t('Andar {0} · +{1} moedas').replace('{0}', factory.last.floor).replace('{1}', factory.last.coins)}</p>}
            <p className="dlg-sub text-sm">{t('Recorde: andar {0}').replace('{0}', factory.best)} · 🪙 {factory.coins} {t('moedas')}</p>
          </>}
          menu={<MenuButton onClick={onExit} testid="factory-over-exit">{t('VOLTAR')}</MenuButton>}
        />
      </section>
    )
  }

  const p = run.pending
  const step = stepOf(p)
  const nurse = <img src={spriteUrl('trainers/sd-nurse.png')} alt="" className="pixelated w-full object-contain object-bottom" style={{ maxHeight: width * 0.3 }} />
  let field, text, menu, below = null, wideMenu = false

  if (step === 'result') {
    const event = p.event
    const here = p.center ? 'center' : run.scene ?? 'grass'
    const shown = p.center || p.joy ? nurse : [p.drop, p.reward].filter(Boolean).length ? <img src={itemIcon(p.drop ?? p.reward)} alt="" className="pixelated w-1/2" onError={hide} /> : null
    field = (
      <Field biome={here} fieldRef={fieldRef} testid="factory-result">
        {shown && <FarStand scene={here}>{shown}</FarStand>}
        {!shown && event && <FarStand scene={here}><span className="text-7xl">{event.kind === 'money' ? '💰' : event.kind === 'berries' ? '🍒' : event.kind === 'tutor' ? '📀' : '🎁'}</span></FarStand>}
        {lead && <FieldMon mon={lead} byId={byId} back scene={here} />}
      </Field>
    )
    text = (
      <>
        {p.center ? (
          <p data-testid="factory-center">🏥 {t('Centro Pokémon: o seu time foi curado!')}</p>
        ) : event ? (
          <p data-testid="factory-event">{t(EVENT_TEXT[event.kind]).replace('{0}', event.kind === 'money' ? event.money : itemName(event.item ?? '')).replace('{1}', event.count ?? '')}</p>
        ) : (
          <>
            <p>🏆 {t('Andar vencido!')} +{p.exp} XP · +💰{p.money}</p>
            {p.levels?.map((l) => (
              <p key={l.index} className="text-sm" data-no-translate>{name(run.team[l.index]?.id)}: Nv. {l.from} → {l.to}{l.evolved ? ` · ${t('evoluiu!')}` : ''}</p>
            ))}
          </>
        )}
        {p.joy && <p className="text-sm" data-testid="factory-joy">💗 {t('A Enfermeira Joy apareceu e curou o time todo!')}</p>}
        {[p.drop, p.reward].filter(Boolean).map((id) => <p key={id} className="text-sm" data-testid="factory-drop">🎁 {t('Ganhou {0}!').replace('{0}', itemName(id))}</p>)}
        {p.story && p.story.split('\n\n').map((line, k) => <p key={k} className="text-sm font-semibold" data-testid="factory-story-end">📖 {line}</p>)}
      </>
    )
    menu = <MenuButton onClick={() => save({ ...run, pending: { ...p, seen: true } })} testid="factory-continue">{t('CONTINUAR')}</MenuButton>
  } else if (step === 'capture') {
    const mon = p.capture
    const full = run.team.length >= MAX_TEAM
    const keep = (replace) => {
      const next = capture(run, replace)
      if (next === run) return
      const meta = unlockShiny(factory, data, mon)
      if (meta !== factory) setUnlocked(mon.id)
      const out = next.pending && !stepOf(next.pending) ? nextFloor(next, data) : next
      saveFactory({ ...meta, run: out })
    }
    field = (
      <Field biome={run.scene ?? 'grass'} fieldRef={fieldRef} testid="factory-capture">
        <FieldMon mon={mon} byId={byId} scene={run.scene} />
        {lead && <FieldMon mon={lead} byId={byId} back scene={run.scene} />}
      </Field>
    )
    text = (
      <>
        <p>{mon.shiny ? '✨ ' : ''}{t('Pegou! {0} foi capturado!').replace('{0}', name(mon.id))} <span className="dlg-sub">Nv. {mon.level}</span></p>
        {mon.shiny && <p className="text-sm text-amber-600">{t('É shiny! (+10% em todos os atributos)')}</p>}
        {full && <p className="text-sm">{t('Time cheio: escolha quem sai.')}</p>}
      </>
    )
    // Time cheio: a tela do time do Black & White, por cima do campo, para escolher quem sai.
    if (full && !panel) {
      below = <BwParty title={t('Time cheio: escolha quem sai para {0} entrar.').replace('{0}', name(mon.id))} team={partyOf(run, byId)} testid="replace" onPick={keep} onCancel={() => save(skipCapture(run))} cancelLabel={t('SOLTAR')} />
    }
    menu = full ? (
      <>
        <MenuButton onClick={() => save(skipCapture(run))} testid="factory-release">{t('SOLTAR')}</MenuButton>
        {tools}
      </>
    ) : <MenuButton onClick={() => keep(null)} testid="factory-continue">{t('CONTINUAR')}</MenuButton>
  } else if (step === 'cards') {
    field = (
      <Field biome={run.scene ?? 'grass'} fieldRef={fieldRef} testid="factory-cards">
        <div className="absolute inset-0 grid grid-cols-3 items-center gap-2 p-3 sm:gap-4 sm:p-6">
          {p.cards.map((c) => (
            <button key={c} type="button" data-testid={`card-${c}`} onClick={() => save(takeCard(run, c, data))}
              className="flex h-[85%] cursor-pointer flex-col items-center justify-center gap-1 rounded-xl border-4 border-slate-800 bg-gradient-to-b from-amber-200 to-white p-1 text-center text-[11px] font-black text-slate-900 shadow-lg transition hover:-translate-y-1 sm:text-sm">
              <span className="text-2xl sm:text-4xl">🃏</span>
              {t(CARDS[c].label)}
            </button>
          ))}
        </div>
      </Field>
    )
    text = <p>🃏 {t('Escolha uma carta de bônus')}</p>
  } else if (step === 'trade') {
    // Troca: escolhe quem dar; o oferecido vem TRADE_LEVELS níveis acima, com o item de quem foi.
    const offer = p.trade
    field = (
      <Field biome={run.scene ?? 'grass'} fieldRef={fieldRef} testid="factory-trade">
        <FieldMon mon={offer} byId={byId} scene={run.scene} />
        {lead && <FieldMon mon={lead} byId={byId} back scene={run.scene} />}
      </Field>
    )
    text = (
      <>
        <p>🔁 {t('Um treinador quer trocar o {0} dele com você!').replace('{0}', `${offer.shiny ? '✨ ' : ''}${name(offer.id)}`)}</p>
        <p className="text-sm">{t('Quem você der vai embora; o {0} vem {1} níveis acima, com o item de quem foi.').replace('{0}', name(offer.id)).replace('{1}', TRADE_LEVELS)}</p>
      </>
    )
    // Quem dar: a tela do time, por cima do campo.
    if (panel === 'trade') {
      below = (
        <BwParty title={t('Quem você dá em troca do {0}?').replace('{0}', name(offer.id))} testid="trade"
          team={partyOf(run, byId).map((m, i) => ({ ...m, sub: `Lv${run.team[i].level} → Lv${run.team[i].level + TRADE_LEVELS}` }))}
          onPick={(i) => { setPanel(null); save(tradeMon(run, i, data)) }} onCancel={() => setPanel(null)} />
      )
    }
    menu = (
      <>
        <MenuButton onClick={() => setPanel(panel === 'trade' ? null : 'trade')} active={panel === 'trade'} testid="trade-open">{t('TROCAR')}</MenuButton>
        <MenuButton onClick={() => save(skipTrade(run))} testid="trade-skip">{t('NÃO TROCAR')}</MenuButton>
      </>
    )
  } else if (step === 'shop') {
    const pick = Math.min(target, run.team.length - 1)
    field = (
      <Field biome="city" fieldRef={fieldRef} testid="factory-shop">
        <div className="absolute inset-x-0 bottom-[22%] flex items-end justify-center gap-1">
          <img src={spriteUrl('trainers/sd-clerk.png')} alt="" className="pixelated object-contain object-bottom" style={{ height: width * 0.32 }} />
          <img src={spriteUrl('trainers/sd-clerkf.png')} alt="" className="pixelated object-contain object-bottom" style={{ height: width * 0.32 }} />
        </div>
        <div className="absolute inset-x-0 bottom-0 h-[26%] border-t-[6px] border-amber-400 bg-gradient-to-b from-amber-600 to-amber-800" />
        <div className="absolute left-3 top-2 rounded-lg bg-white/80 px-2 py-0.5 text-sm font-black text-slate-900">🛒 Poké Mart</div>
      </Field>
    )
    text = <p>{t('Bem-vindo! Do que você precisa?')} <span className="dlg-sub">💰{run.money}</span></p>
    menu = (
      <>
        <MenuButton onClick={() => setPanel(panel === 'buy' ? null : 'buy')} active={panel === 'buy'} testid="factory-menu-buy">{t('COMPRAR')}</MenuButton>
        {tools}
        <MenuButton onClick={() => { setPanel(null); save({ ...run, pending: { ...p, shop: null } }) }} testid="factory-continue">{t('CONTINUAR')}</MenuButton>
      </>
    )
    if (panel === 'buy') {
      below = (
        <div className="space-y-2 p-2">
          <OverlayClose onClose={() => setPanel(null)} title={`🛒 Poké Mart · 💰${run.money}`} />
          <p className="text-xs text-muted">{t('Para quem é a compra (bolas e itens da Bolsa vão para a Bolsa):')}</p>
          <div className="flex flex-wrap gap-1">{run.team.map((m, i) => <MonChip key={i} mon={m} byId={byId} selected={pick === i} onClick={() => setTarget(i)} testid={`target-${i}`} />)}</div>
          <div className="grid gap-2 sm:grid-cols-2">
            {p.shop.map((id) => (
              <div key={id} className="flex items-center justify-between gap-2 rounded-xl bg-surface p-2 text-sm">
                <img src={itemIcon(id)} alt="" className="pixelated h-8 w-8" onError={hide} />
                <div className="min-w-0 flex-1">
                  <p className="font-bold" data-no-translate>{itemName(id)}</p>
                  <p className="text-xs text-muted">{shopOwned(run, id) ? t('Você já tem') : itemHelp(id)}</p>
                </div>
                <Button data-testid={`buy-${id}`}
                  disabled={run.money < shopPrice(run, id) || shopOwned(run, id) || (id.startsWith('evo:') && !canEvolveWith(data, run.team[pick], id.slice(4)).length)}
                  onClick={() => save(buyItem(run, id, pick, data))}>
                  💰{shopPrice(run, id)}
                </Button>
              </div>
            ))}
          </div>
        </div>
      )
    }
  } else if (!p && run.route) {
    const boss = bossOf(data, run)
    const target = targetOf(data, run)
    const { from, to } = routeCities(data, run)
    const route = run.route
    const biome = BIOME_INFO[route.biome] ?? BIOME_INFO.grass
    const pos = Math.min(ROUTE_LENGTH, routePos(run))
    const down = teamDown(run)
    const meeting = route.options.length === 1 && route.options[0].kind === 'boss'
    const coach = trainers?.find((x) => x.id === boss.trainer) ?? null
    const intro = run.boss.step === 0 && pos === 0 ? storyLine(data, boss.region, 'intro') : ''
    const pickNode = (index) => {
      const next = chooseNode(run, data, index)
      if (next === run) return
      saveFactory({ ...factoryOf(useStore.getState().league), run: next })
      if (next.encounter) onBattle(next)
    }
    // A rota no campo: da cidade de onde veio (esquerda) até a do chefe (direita); você no andar de agora.
    const x = (k) => 8 + (k / (ROUTE_LENGTH + 1)) * 84
    const END = ROUTE_LENGTH + 1
    const fork = route.options.length > 1
    // O líder no ginásio do tipo dele, a Elite Four na Liga, o Campeão na sala dele; rival e vilões na rota (o vilão, na base da equipe).
    const meetScene = meeting && CITY_KIND_SET.has(boss.kind) ? bossScene(data, boss, route.biome) : route.biome
    // Sem o Mapa: nada do mapa e, na bifurcação, segue às cegas.
    const hasMap = Boolean(run.townMap)
    field = fork && hasMap ? (
      <TownMap route={route} pos={pos} from={from} to={to} title={`${boss.region} · ${boss.game}`} me={me} width={width} fieldRef={fieldRef}
        onPick={busy ? null : pickNode} blocked={(node) => isBattleNode(node) && down} />
    ) : (
      // O líder espera no ginásio da cidade; a Elite Four e o Campeão, na Liga (nunca no meio da rota).
      <Field biome={meetScene} fieldRef={fieldRef} testid="factory-map">
        <div className="absolute left-3 top-2 rounded-lg bg-white/85 px-2 py-0.5 text-xs font-black text-slate-900 sm:text-sm">
          <span data-no-translate>{boss.region} · {boss.game}</span> · {biome.icon} {t('Rota para {0}').replace('{0}', to)}
        </div>
        {hasMap && <div className="absolute inset-x-0 top-[34%] h-0" data-testid="route-strip">
          <div className="absolute h-2 rounded-full bg-amber-800/60" style={{ left: `${x(0)}%`, right: `${100 - x(END)}%` }} />
          {/* As cidades nas pontas; cada andar da rota é um ponto (os das bifurcações em forma de losango). */}
          {Array.from({ length: END + 1 }, (_, k) => {
            const end = k === 0 || k === END
            const fork = !end && FORKS.includes(k - 1)
            return (
              <span key={k} className={`absolute -translate-x-1/2 border-2 border-slate-800 ${end ? '-mt-2 h-6 w-6 rounded-full bg-amber-400' : fork ? `-mt-1.5 h-5 w-5 rotate-45 ${k - 1 < pos ? 'bg-white' : 'bg-sky-300'}` : `-mt-1 h-4 w-4 rounded-full ${k - 1 < pos ? 'bg-white' : 'bg-white/40'}`}`} style={{ left: `${x(k)}%` }} />
            )
          })}
          <span className="absolute mt-4 -translate-x-1/2 rounded bg-white/85 px-1 text-[10px] font-bold text-slate-900 sm:text-xs" style={{ left: `${x(0)}%` }} data-no-translate>🏠 {from ?? t('Início')}</span>
          <span className="absolute mt-4 -translate-x-1/2 rounded bg-white/85 px-1 text-[10px] font-bold text-slate-900 sm:text-xs" style={{ left: `${x(END)}%` }} data-no-translate>👑 {to}</span>
          {me && (
            <span className="absolute -translate-x-1/2 -translate-y-full transition-all duration-700" style={{ left: `${x(pos + 1)}%` }}>
              <TrainerSprite trainer={me} box={width * 0.14} />
            </span>
          )}
        </div>}
        {coach && meeting && <FarStand scene={meetScene}><TrainerSprite trainer={coach} box={width * 0.24} /></FarStand>}
        {lead && <FieldMon mon={lead} byId={byId} back scene={meetScene} />}
      </Field>
    )
    text = (
      <>
        {intro && <p className="text-sm font-semibold">📖 {intro}</p>}
        {pos === 0 && !meeting && (
          <p className="text-sm font-semibold" data-testid="factory-route-story">
            🧭 {t('Você sai de {0} e entra em {1}, rumo a {2}.').replace('{0}', from ?? t('casa')).replace('{1}', t(biome.label)).replace('{2}', to)}
            {' '}{t(ROUTE_FLAVOR[route.biome] ?? ROUTE_FLAVOR.grass)}
          </p>
        )}
        {meeting && boss.kind === 'rival' && <p className="text-sm italic" data-testid="factory-rival-line">💬 {t(RIVAL_LINES[(run.floor + run.seed) % RIVAL_LINES.length])}</p>}
        {meeting && boss.kind === 'villain' && <p className="text-sm italic">💬 {t(VILLAIN_LINES[(run.floor + run.seed) % VILLAIN_LINES.length])}</p>}
        {meeting && (boss.kind === 'rival' || boss.kind === 'villain') ? (
          <>
            <p>{t('{0} apareceu no caminho!').replace('{0}', boss.name)}</p>
            <p className="text-sm font-semibold">{storyLine(data, boss.region, boss.kind, boss.name)}</p>
          </>
        ) : meeting ? (
          <>
            <p>{t('O chefe espera')}</p>
            <p className="text-sm font-semibold">{storyLine(data, boss.region, boss.kind, boss.name)}</p>
          </>
        ) : (
          <p>{!fork ? t('O caminho segue.') : hasMap ? t('O caminho se divide: escolha por onde ir') : t('O caminho se divide, mas sem o Mapa você não sabe para onde cada um vai. Compre um Mapa na loja!')}</p>
        )}
        <p className="dlg-sub text-sm">{t('Chefe em {0}:').replace('{0}', to)} <b data-no-translate>{target.name}</b> · {bossKindLabel(target.kind)}</p>
        {down && <p className="text-sm text-red-600">{t('O time todo está desmaiado: use um Revive ou desista.')}</p>}
      </>
    )
    wideMenu = true
    menu = (
      <>
        {fork && !hasMap && (
          <MenuButton testid="map-node-blind" disabled={busy} onClick={() => pickNode(blindPick(run))} sub={t('Sem o Mapa: um dos caminhos, às cegas.')}>
            {t('SEGUIR')} ❓
          </MenuButton>
        )}
        {(hasMap || !fork) && route.options.map((node, k) => {
          const info = NODE_INFO[node.kind]
          const b = node.biome ? BIOME_INFO[node.biome] : null
          return (
            <MenuButton key={k} testid={`map-node-${k}`} disabled={busy || (isBattleNode(node) && down)} onClick={() => pickNode(k)}
              sub={node.kind === 'boss' ? `${bossKindLabel(boss.kind)}${CITY_KIND_SET.has(boss.kind) ? ` · ${to}` : ''}` : t(info.help)}>
              {route.options.length === 1 && node.kind !== 'boss' ? `${t('SEGUIR')}: ` : ''}{node.biome === 'underwater' && route.biome !== 'underwater' ? `🤿 ${t('MERGULHAR')}: ` : ''}{b ? b.icon : info.icon} {node.kind === 'boss' ? <span data-no-translate>{boss.name}</span> : t(info.label)}{b ? ` · ${t(b.label)}` : ''}
            </MenuButton>
          )
        })}
        {(run.rerolls ?? 0) > 0 && !meeting && hasMap && (
          <MenuButton testid="factory-reroll" disabled={busy} onClick={() => { const next = rerollRoute(run, data); if (next) save(next) }} sub={t('Restam {0} nesta corrida').replace('{0}', run.rerolls)}>
            🎲 {t('SORTEAR O CAMINHO DE NOVO')}
          </MenuButton>
        )}
        <div className="grid grid-cols-2">{tools}</div>
      </>
    )
  } else if (!p && run.encounter) {
    field = <Field biome={run.scene} fieldRef={fieldRef}>{lead && <FieldMon mon={lead} byId={byId} back scene={run.scene} />}</Field>
    text = <p>{t('Lutar no andar {0}').replace('{0}', run.floor)}</p>
    menu = <MenuButton testid="factory-fight" disabled={busy || teamDown(run)} onClick={() => onBattle(run)}>{t('LUTAR')}</MenuButton>
  } else {
    field = <Field fieldRef={fieldRef} />
    text = <p>...</p>
  }

  return (
    <section data-testid="factory-screen">
      <BattleFrame field={field} run={run} byId={byId} wideMenu={wideMenu} menu={menu} panel={below || extras || null}
        text={<>
          {text}
          {unlocked != null && <p className="text-sm text-amber-600" data-testid="factory-shiny-unlocked">✨ {t('{0} shiny liberado para começar as próximas corridas!').replace('{0}', name(unlocked))}</p>}
          {earned.map((id) => (
            <p key={id} className="text-sm text-amber-600" data-testid={`achievement-${id}`}>
              🏆 {t('Conquista: {0}').replace('{0}', t(ACHIEVEMENTS[id].label))} (+🪙{ACHIEVEMENTS[id].coins})
            </p>
          ))}
        </>} />
      {links}
    </section>
  )
}

const BALL_HELP = {
  'poke-ball': 'Para capturar os selvagens (jogue na batalha)',
  'great-ball': 'Captura 1,5× melhor',
  'ultra-ball': 'Captura 2× melhor',
  'quick-ball': '5× melhor no primeiro turno',
  'net-ball': '3,5× melhor em Água e Inseto',
  'dusk-ball': '3× melhor em cavernas e torres',
  'timer-ball': 'Melhora a cada turno (até 4×)',
}

function itemHelp(id) {
  if (id === 'master-ball') return t('Captura sempre')
  if (BALL_HELP[id]) return t(BALL_HELP[id])
  if (id.startsWith('tm:')) return t('Ensina o golpe a quem aprende por TM (uma vez)')
  if (id.startsWith('evo:')) return t('Evolui na hora quem evolui com ela (escolha acima)')
  if (id === 'move-tutor') return t('Ensina um golpe de tutor ou de ovo (uma vez)')
  if (id === 'move-reminder') return t('Lembra um golpe do nível (uma vez)')
  if (id === 'dynamax-band') return t('Libera o Dynamax (e o Gigantamax) para o time')
  if (id === 'tera-orb') return t('Libera a Terastalização para o time')
  if (id === 'escape-rope') return t('Se perder uma batalha, o time foge com {0}% do HP e a corrida continua (gasta uma)').replace('{0}', Math.round(ESCAPE_HP * 100))
  if (id === 'lucky-egg') return t('Quem segura ganha +{0}% de XP (como extra, +{1}%)').replace('{0}', Math.round((LUCKY_EGG.held - 1) * 100)).replace('{1}', Math.round((LUCKY_EGG.extra - 1) * 100))
  if (id === 'exp-share') return t('O time todo ganha XP (quem não lutou, a metade)')
  if (id === 'town-map') return t('Mostra o mapa da rota e deixa escolher o caminho nas bifurcações (sem ele, vai às cegas)')
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
