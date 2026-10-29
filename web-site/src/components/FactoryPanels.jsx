// As telas da Battle Factory (lib/factoryRun.js): o começo (o inicial grátis,
// comprar Pokémon e shiny com as moedas, continuar a corrida, a história da
// região) e a corrida em tela cheia, no lugar da batalha (FactoryScreen): o
// resultado do andar (XP, Enfermeira Joy, drops), o capturado, a carta de
// bônus, a loja com "Continuar" e o mapa com os caminhos de cada andar (Bolsa,
// itens, golpes e mecânicas em todos). Igual ao app (lib/screens/factory_panels.dart).

import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react'
import PokeIcon from './PokeIcon'
import Sprite from './Sprite'
import { BattleBackground, battleScale, battleScene, farPerson, foeBottom, nearPerson, PlatformBase } from './BattleScene'
import BwBag from './BwBag'
import BwParty from './BwParty'
import { SUMMARY_STATS } from './BwSummary'
import { TRAINER_ADULT_PX, TrainerSprite } from './Trainer'
import { Button, SearchInput, TypeBadge } from './ui'
import { getFactoryData, getMoves, shinyPath, spriteUrl } from '../lib/data'
import { learnsetOf, movesFor } from '../lib/factoryBattle'
import { battleMons } from '../lib/battleSetup'
import {
  BAG_ITEMS, bossOf, unequipItem, ROUTE_LENGTH, CITY_LENGTH, routePos, targetOf, BOTTLE_CAP_IVS, buyItem, buyPokemon, canEvolveWith, capture, CARDS, chooseNode, claimStarter, endRun, equipFromStash,
  factoryOf, freePick, gimmickOf, gimmicksOf, HEAL_SHARE, HELD_BOOST, isBattleNode, MAX_TEAM, nextFloor, pokemonPrice, routeCities, setGimmick, setMainItem,
  shinyPrice, shopOwned, shopPrice, skipCapture, startersOf, startRun, storyLine, takeCard, teachMove, teamDown, applyBagItem, unlockShiny, VITAMIN_EVS, VITAMINS,
  buyShiny, forSale, normalizeOwned, UPGRADES, upgradeLevel, upgradePrice, upgradeValue, buyUpgrade, upgradeNeeds, UPGRADE_BRANCHES, UPGRADE_TREE, UPGRADE_FX, MINOR_BASE, isMinor, isKeystone,
  tradeMon, skipTrade, TRADE_LEVELS, RELICS, cardLabel, progress, ACHIEVEMENTS, LUCKY_EGG, ESCAPE_HP, BALL_TIERS, rerollRoute, setLead, bossScene,
  resolveChoice, regionLegend, leaderType, villainTeam, rivalBoss, placeInfo, routeInfo, DUNGEON_LENGTH, dungeonPos, townShop, townCenter,
  weeklyOf, startWeekly, COSMETIC_BALLS, COSMETIC_FRAMES, hasCosmetic, buyCosmetic, equipCosmetic,
  boostOf, memberOf, learnMove, movesLearnedBetween,
  cutPath, nodeBlocked, hasHm, clockOf, healerOf, inTown, DARK_BIOMES, dexOf, dexRewardFor, leaveDaycare, takeDaycare, DAYCARE_EGG, EGG_BATTLES,
} from '../lib/factoryRun'
import { t } from '../lib/i18n'
import { prettyName, typeColor } from '../lib/pokemon'
import { usePokemonIndex } from '../lib/pokemonIndex'
import { prettySlug } from '../lib/teamSets'
import { useStore } from '../lib/store'
import { saveWeekly, useAuth, watchRanking } from '../lib/auth'
import { weekKey } from '../lib/league'
import { dailyMissions, dailyOf, missionLabel, trackDaily } from '../lib/factoryDaily'
import { useMyTrainer, useTrainers } from '../lib/trainers'

/** Salva a Factory (meta e corrida) na conta. */
export const saveFactory = (factory) => {
  // As missões do dia andam com o que mudou na corrida.
  factory = trackDaily(factoryOf(useStore.getState().league), factory)
  // Acabou a corrida da semana: o andar vai para o ranking dela (uma vez, com a conta conectada).
  const last = factory?.last
  if (last?.weekly && !last.posted) {
    factory = { ...factory, last: { ...last, posted: true } }
    const user = useAuth.getState().user
    if (user?.uid && user.name && last.floor > 0) saveWeekly(user.uid, user.name, last.weekly, last.floor, useStore.getState().avatar, 'factory').catch(() => {})
  }
  useStore.getState().updateLeague((l) => ({ ...l, factory }))
}
// Só nos testes com os emuladores: deixa o teste montar uma corrida (por exemplo, numa bifurcação).
if (import.meta.env.VITE_EMULATORS && typeof window !== 'undefined') window.__factory = { saveFactory, get: () => factoryOf(useStore.getState().league), set: (patch) => useStore.setState(patch) }
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

const CATEGORY_LABEL = { physical: 'Físico', special: 'Especial', status: 'Status' }

/**
 * Esquecer um golpe (como nos jogos): o Pokémon à esquerda e os 5 golpes à direita (os 4 de agora e o novo), no lugar
 * do campo (como a Bolsa); toque num para ver o poder e a precisão no título e confirme embaixo. Igual ao app.
 */
function ForgetPanel({ mon, move, moves, name, types, pick, onPick }) {
  const current = mon.moves ?? []
  const five = [...current, move]
  const pm = pick == null ? null : moves[five[pick]]
  return (
    <div className="bw-party flex min-h-full flex-col gap-1.5 p-1.5" data-testid="forget-panel">
      <p className="bw-party-title truncate rounded-lg px-3 py-1 text-sm font-black text-white" data-testid="forget-title" data-no-translate>
        {pm ? `${prettySlug(five[pick])} · ${t('Poder')} ${pm.power ?? '—'} · ${t('Precisão')} ${pm.accuracy ?? '—'} · ${t(CATEGORY_LABEL[pm.category] ?? '')}` : t('Esquecer qual golpe?')}
      </p>
      <div className="flex gap-1.5">
        {/* O Pokémon à esquerda (como nos jogos). */}
        <div className="flex w-20 shrink-0 flex-col items-center gap-0.5 text-white">
          <div className="h-[4.5rem] w-[4.5rem] rounded-xl border-2 border-sky-900 bg-sky-100"><PokeIcon id={mon.id} shiny={Boolean(mon.shiny)} className="h-full w-full" /></div>
          <p className="w-full truncate text-center text-xs font-black" data-no-translate>{name}</p>
          <p className="text-[11px] font-bold" data-no-translate>Lv{mon.level}</p>
          <div className="flex flex-wrap justify-center gap-0.5">{types.map((type) => <TypeBadge key={type} type={type} small />)}</div>
        </div>
        <div className="flex min-w-0 flex-1 flex-col gap-1">
          {five.map((slug, k) => {
            const m = moves[slug] ?? {}
            const isNew = k === current.length
            return (
              <button key={slug} type="button" onClick={() => onPick(k)} data-testid={`forget-${k}`}
                className={`flex cursor-pointer items-center gap-1.5 rounded-lg border-2 border-sky-900 px-2 py-0.5 text-left text-xs font-black text-slate-900 ${pick === k ? 'bg-orange-300' : isNew ? 'bg-amber-100' : 'bg-white'}`}>
                {m.type && <TypeBadge type={m.type} small />}
                <span className="min-w-0 flex-1 truncate" data-no-translate>{prettySlug(slug)}</span>
                {isNew && <span className="rounded bg-amber-600 px-1 text-[9px] text-white">{t('NOVO')}</span>}
                <span className="tabular-nums">PP {m.pp ?? '—'}</span>
              </button>
            )
          })}
        </div>
      </div>
    </div>
  )
}

/** Os dados do Pokémon da corrida (como a tela DADOS da batalha): monta como na batalha e lê os atributos (com os bônus da corrida). */
async function summaryOfRun(run, i, data, byId) {
  const m = run.team[i]
  const moves = m.moves?.length ? m.moves : await movesFor(m.id, m.level)
  const [mon] = await battleMons([memberOf(run, m, moves, data)])
  if (!mon) return null
  const calc = await import('../lib/damageCalc')
  const stats = calc.sideStats(mon.base, { ...mon.side, hpPct: 100 })?.stats ?? {}
  const boost = boostOf(run, m)
  const stat = (k) => (stats[k] != null ? Math.round(stats[k] * (1 + (boost[k] ?? 0))) : undefined)
  const maxHp = Math.round(mon.maxHp * (1 + (boost.hp ?? 0)))
  return {
    id: m.id, shiny: m.shiny, name: t(prettyName(byId?.get(m.id)?.name ?? '')), level: m.level, hp: Math.round((m.hp ?? 1) * maxHp), maxHp,
    types: mon.types ?? [], ability: mon.side?.ability ?? '', item: m.item ? itemName(m.item) : '',
    stats: Object.fromEntries(['atk', 'def', 'spa', 'spd', 'spe'].map((k) => [k, stat(k)])),
    moves: mon.moves.map((mv) => ({ name: mv.name, type: mv.type, pp: mv.maxPp, maxPp: mv.maxPp })),
  }
}

/** Um item na lista (ícone, nome e os botões); tocando nele aparece o que ele faz. Igual ao app. */
function ItemRow({ id, main = false, children, testid }) {
  const [open, setOpen] = useState(false)
  return (
    <div onClick={() => setOpen(!open)} className={`flex cursor-pointer items-center gap-2 rounded-lg border-2 border-sky-900 px-2 py-0.5 text-slate-900 ${main ? 'bg-amber-100' : 'bg-white'}`} data-testid={testid}>
      <img src={itemIcon(id)} alt="" className="pixelated h-6 w-6 shrink-0" onError={hide} />
      <div className="min-w-0 flex-1">
        <p className="truncate text-xs font-black" data-no-translate>{main ? '★ ' : ''}{itemName(id)} {open ? '▴' : '▾'}</p>
        {open && itemHelp(id) && <p className="text-[10.5px] leading-tight text-slate-600" data-testid={`${testid}-info`}>{itemHelp(id)}</p>}
      </div>
      {children}
    </div>
  )
}

const BwButton = ({ color, onClick, children, testid }) => (
  <button type="button" onClick={(e) => { e.stopPropagation(); onClick() }} className={`shrink-0 cursor-pointer rounded-lg px-2.5 py-1 text-xs font-black text-white ${color}`} data-testid={testid}>{children}</button>
)

/**
 * Os itens e as opções de quem foi aberto no time: o item principal (o efeito de verdade), os extras (só um pouco no
 * atributo), segurar um item guardado, quem abre a batalha, a mecânica e ensinar golpe. Igual ao app.
 */
function MonOptions({ run, data, i, save, onLead, part = 'items' }) {
  const [teaching, setTeaching] = useState(false)
  const m = run.team[i]
  const extras = m.extras ?? []
  const canTeach = Object.values(run.tms ?? {}).some((n) => n > 0) || Object.values(run.tokens ?? {}).some((n) => n > 0)
  const options = gimmicksOf(data, run, m)
  // A página OPÇÕES: quem abre a batalha, ensinar golpe e a mecânica.
  if (part === 'actions') {
    return (
      <div className="bw-party-title h-full space-y-1 rounded-lg p-1.5 text-white" data-testid="team-actions">
        <div className="flex flex-wrap items-center gap-1.5">
          {i === 0
            ? <span className="rounded-lg bg-emerald-500 px-2 py-1 text-xs font-black text-slate-900">{t('Abre a batalha')}</span>
            : <BwButton color="bg-blue-600" onClick={() => { save(setLead(run, i)); onLead() }} testid="team-lead">⬆ {t('PRIMEIRO NA BATALHA')}</BwButton>}
          {canTeach && <BwButton color="bg-violet-600" onClick={() => setTeaching(true)} testid="team-teach">📀 {t('ENSINAR GOLPE')}</BwButton>}
          {options.length > 0 && (
            <select aria-label={t('Mecânica')} value={gimmickOf(data, run, m) || 'none'} onChange={(e) => save(setGimmick(run, i, e.target.value))}
              className="rounded-lg bg-white px-1 py-1 text-xs font-black text-slate-900" data-testid="team-gimmick">
              <option value="none">{t('Sem mecânica')}</option>
              {options.map((g) => <option key={g} value={g}>{GIMMICK_LABEL[g]}</option>)}
            </select>
          )}
        </div>
        {teaching && <div className="text-xs text-text"><MoveTeacher run={run} index={i} save={save} onClose={() => setTeaching(false)} /></div>}
      </div>
    )
  }
  return (
    <div className="bw-party-title space-y-1 rounded-lg p-1.5 text-white" data-testid="team-options">
      <p className="text-xs font-black">🎒 {t('Itens que ele segura')} (★ {t('o principal')})</p>
      {!m.item && !extras.length && <p className="text-[11px] text-slate-300">{t('Nenhum item. Escolha um dos guardados abaixo.')}</p>}
      {m.item && (
        <ItemRow id={m.item} main testid="team-item-main">
          <BwButton color="bg-red-600" onClick={() => save(unequipItem(run, i))} testid="team-unequip">{t('TIRAR')}</BwButton>
        </ItemRow>
      )}
      {extras.map((id, k) => (
        <ItemRow key={k} id={id} testid={`team-item-extra-${k}`}>
          <BwButton color="bg-amber-600" onClick={() => save(setMainItem(run, i, k))} testid={`team-main-${k}`}>★</BwButton>
          <BwButton color="bg-red-600" onClick={() => save(unequipItem(run, i, k))} testid={`team-unequip-${k}`}>{t('TIRAR')}</BwButton>
        </ItemRow>
      ))}
      {(run.stash ?? []).length > 0 && (
        <>
          <p className="pt-1 text-xs font-black">🎁 {t('Guardados: toque para ele segurar')}</p>
          {run.stash.map((id, k) => (
            <ItemRow key={k} id={id} testid={`team-stash-${k}`}>
              <BwButton color="bg-green-600" onClick={() => save(equipFromStash(run, k, i))} testid={`team-equip-${k}`}>{t('SEGURAR')}</BwButton>
            </ItemRow>
          ))}
        </>
      )}
    </div>
  )
}

const TEAM_TABS = ['DADOS', 'GOLPES', 'ITENS', 'OPÇÕES']

/**
 * Os dados de um Pokémon do time em páginas de tamanho fixo, como o resumo dos jogos: DADOS, GOLPES, ITENS e OPÇÕES,
 * trocando arrastando para o lado (ou pelas setas e abas). Igual ao app.
 */
function TeamPages({ d, items, actions, onBack }) {
  const ref = useRef(null)
  const [page, setPage] = useState(0)
  const go = (k) => { const el = ref.current; if (el && k >= 0 && k < TEAM_TABS.length) el.scrollTo({ left: k * el.clientWidth, behavior: 'smooth' }) }
  const hp = d.maxHp > 0 ? Math.max(0, Math.min(1, d.hp / d.maxHp)) : 0
  return (
    <div className="bw-party flex h-full flex-col gap-1.5 p-1.5" data-testid="team-pages">
      <div className="bw-party-title flex items-center gap-1 rounded-lg px-1 py-0.5 text-white">
        <button type="button" onClick={() => go(page - 1)} disabled={page === 0} className="cursor-pointer px-1 font-black disabled:opacity-30" data-testid="team-prev">◀</button>
        <span className="truncate text-sm font-black" data-no-translate>{d.name} Lv{d.level}</span>
        <span className="flex flex-1 justify-center gap-0.5">
          {TEAM_TABS.map((tab, k) => (
            <button key={tab} type="button" onClick={() => go(k)} data-testid={`team-tab-${k}`}
              className={`cursor-pointer rounded px-1.5 py-0.5 text-[10px] font-black ${k === page ? 'bg-orange-500' : 'bg-white/10'}`}>{t(tab)}</button>
          ))}
        </span>
        <button type="button" onClick={() => go(page + 1)} disabled={page === TEAM_TABS.length - 1} className="cursor-pointer px-1 font-black disabled:opacity-30" data-testid="team-next">▶</button>
        <button type="button" onClick={onBack} className="cursor-pointer px-1 font-black text-red-300" data-testid="bw-summary-back">✕</button>
      </div>
      {/* As páginas: arrastar para o lado troca (cada uma do tamanho do campo). */}
      <div ref={ref} onScroll={(e) => setPage(Math.round(e.currentTarget.scrollLeft / Math.max(1, e.currentTarget.clientWidth)))}
        className="flex min-h-0 flex-1 snap-x snap-mandatory overflow-x-auto overflow-y-hidden [scrollbar-width:none]">
        <div className="flex w-full shrink-0 snap-start flex-col gap-1.5">
          <div className="flex gap-2">
            <div className="h-16 w-16 shrink-0 rounded-xl border-2 border-sky-900 bg-sky-100"><PokeIcon id={d.id} shiny={Boolean(d.shiny)} className="h-full w-full" /></div>
            <div className="min-w-0 flex-1 text-[11px] font-black text-white">
              <div className="flex flex-wrap gap-1">{d.types.map((type) => <TypeBadge key={type} type={type} small />)}</div>
              <div className="mt-1 flex items-center gap-1">HP
                <span className="block h-1.5 flex-1 overflow-hidden rounded bg-slate-800"><span className={`block h-full ${hp > 0.5 ? 'bg-emerald-400' : hp > 0.2 ? 'bg-amber-400' : 'bg-red-500'}`} style={{ width: `${hp * 100}%` }} /></span>
                <span className="tabular-nums">{d.hp}/{d.maxHp}</span>
              </div>
              <p className="truncate">{t('Habilidade')}: <span className="text-amber-200" data-no-translate>{d.ability || '—'}</span></p>
              <p className="truncate">{t('Item')}: <span className="text-amber-200" data-no-translate>{d.item || '—'}</span></p>
            </div>
          </div>
          <div className="grid flex-1 grid-cols-2 content-center gap-x-3 rounded-lg border-2 border-sky-900 bg-sky-50 px-2 py-1 text-[11px] font-bold text-slate-900">
            {SUMMARY_STATS.map(([key, label]) => (
              <p key={key} className="flex justify-between"><span>{t(label)}</span><span className="tabular-nums font-black">{d.stats?.[key] ?? '—'}</span></p>
            ))}
          </div>
        </div>
        <div className="flex w-full shrink-0 snap-start flex-col gap-1">
          {d.moves.map((mv, k) => (
            <p key={k} className="flex flex-1 items-center gap-1.5 rounded-lg border-2 border-sky-900 bg-white px-2 text-xs font-black text-slate-900">
              {mv.type && <TypeBadge type={mv.type} small />}
              <span className="min-w-0 flex-1 truncate" data-no-translate>{mv.name}</span>
              <span className="tabular-nums">PP {mv.pp}/{mv.maxPp}</span>
            </p>
          ))}
        </div>
        {/* Muitos itens guardados: só esta página rola. */}
        <div className="w-full shrink-0 snap-start overflow-y-auto">{items}</div>
        <div className="w-full shrink-0 snap-start">{actions}</div>
      </div>
    </div>
  )
}

/** O time como a tela de trocar da batalha (Black & White): toque num Pokémon para ver os dados dele e equipar itens. Igual ao app. */
function TeamView({ run, data, byId, save }) {
  const [sel, setSel] = useState(null)
  const [summary, setSummary] = useState(null)
  // Os dados de quem está aberto (refeitos quando o item, o nível ou o time mudam).
  useEffect(() => {
    let live = true
    if (sel == null || sel >= run.team.length) return
    summaryOfRun(run, sel, data, byId).then((d) => live && setSummary(d)).catch(() => live && setSummary(null))
    return () => { live = false }
  }, [run, sel, data, byId])
  if (sel != null && sel < run.team.length) {
    if (!summary) return <div className="bw-party p-6 text-center text-white">...</div>
    const lead = () => { setSummary(null); setSel(0) }
    return <TeamPages d={summary} onBack={() => { setSel(null); setSummary(null) }}
      items={<MonOptions run={run} data={data} i={sel} save={save} onLead={lead} />}
      actions={<MonOptions run={run} data={data} i={sel} save={save} onLead={lead} part="actions" />} />
  }
  const team = run.team.map((m) => ({
    id: m.id, shiny: m.shiny, name: t(prettyName(byId?.get(m.id)?.name ?? '')), level: m.level, hp: m.hp ?? 1,
    // O item que ele segura (★ o principal; +N os extras).
    sub: m.item ? `★ ${itemName(m.item)}${(m.extras ?? []).length ? ` +${m.extras.length}` : ''}` : undefined,
  }))
  return <BwParty team={team} testid="factory-team" onPick={(i) => { setSummary(null); setSel(i) }} />
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
/** As missões de hoje, com o progresso e as moedas de cada uma. */
function DailyMissions({ factory }) {
  const daily = dailyOf(factory)
  return (
    <div className="rounded-2xl bg-bg p-3 text-sm" data-testid="factory-daily">
      <p className="font-black">📅 {t('Missões de hoje')}</p>
      <ul className="mt-2 space-y-2">
        {dailyMissions().map(({ kind, count, coins }) => {
          const value = Math.min(count, daily.p[kind] ?? 0)
          const done = daily.done.includes(kind)
          return (
            <li key={kind} data-testid={`daily-${kind}`}>
              <div className="flex items-center justify-between gap-2">
                <span className={done ? 'text-muted line-through' : 'font-semibold'}>{done ? '✅' : '▫️'} {t(missionLabel(kind, count)).replace('{0}', count)}</span>
                <span className="shrink-0 font-bold">{value}/{count} · 🪙{coins}</span>
              </div>
              <div className="mt-1 h-1.5 overflow-hidden rounded-full bg-line">
                <div className={`h-full rounded-full transition-all ${done ? 'bg-emerald-500' : 'bg-amber-500'}`} style={{ width: `${(value / count) * 100}%` }} />
              </div>
            </li>
          )
        })}
      </ul>
    </div>
  )
}

/** A galeria das melhores corridas: o andar, o time e o dia. */
function BestRuns({ gallery }) {
  return (
    <div className="rounded-2xl bg-bg p-3 text-sm" data-testid="factory-gallery">
      <p className="font-black">🖼️ {t('Suas melhores corridas')}</p>
      <ol className="mt-2 space-y-1.5">
        {gallery.map((g, k) => (
          <li key={k} className="flex items-center gap-2 rounded-xl bg-card px-2 py-1">
            <span className="w-6 text-center text-base">{['🥇', '🥈', '🥉'][k] ?? `${k + 1}.`}</span>
            <span className="w-20 shrink-0 font-bold">{t('Andar {0}').replace('{0}', g.floor)}</span>
            <span className="flex min-w-0 flex-1 flex-wrap">
              {g.team.map(([id, level, shiny], i) => <span key={i} title={`Lv. ${level}`}><PokeIcon id={id} shiny={Boolean(shiny)} className="h-9 w-9" /></span>)}
            </span>
            <span className="shrink-0 text-right text-xs text-muted">
              {g.nuzlocke && '🕯️ '}{g.weekly && '🏆 '}{g.date.split('-').reverse().join('/')}
            </span>
          </li>
        ))}
      </ol>
    </div>
  )
}

export function FactoryHub({ onContinue, busy }) {
  const factory = useFactory()
  const data = useFactoryData()
  const byId = usePokemonIndex()
  const [pick, setPick] = useState(null)
  // Nuzlocke: quem desmaia vai embora e só um capturado por rota.
  const [nuzlocke, setNuzlocke] = useState(false)
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
        <p className="font-black">🎲 {t('Pokelike')}</p>
        <p className="text-muted">
          {t('Um roguelike sem fim pela história de cada região: escolha um inicial no nível 5 e viaje de cidade em cidade, como nos jogos. Cada rota tem 10 andares e um chefe no último; depois vem a cidade, com 10 andares, o Poké Mart, o Centro Pokémon, a Creche e o líder no fim. Nas bifurcações você escolhe o caminho ou entra num lugar (cavernas, florestas, o mar, esgotos, museus...): 10 andares, um chefe e você volta para o andar em que entrou. Capture jogando a bola na batalha; nos lugares sem treinadores, até o chefe dá para capturar. O time não é curado entre os andares. Sem limite de nível, IVs, EVs ou itens; shiny é 1 em 4096. Perdeu: os andares viram moedas para comprar Pokémon e melhorias.')}
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

      <DailyMissions factory={factory} />
      {factory.gallery?.length > 0 && <BestRuns gallery={factory.gallery} />}

      {run ? (
        <div className="space-y-3 rounded-2xl bg-bg p-3" data-testid="factory-run">
          <p className="font-black">{t('Corrida em andamento: andar {0}').replace('{0}', run.floor)}</p>
          <RunStatus run={run} />
          <StoryPanel run={run} data={data} />
          <NextBoss run={run} data={data} />
          <div className="flex flex-wrap gap-1">{run.team.map((m, i) => <MonChip key={i} mon={m} byId={byId} />)}</div>
          {run.cards.length > 0 && <p className="text-xs text-muted">{t('Cartas')}: {run.cards.map((c) => t(CARDS[c].label)).join(' · ')}</p>}
          {(run.relics ?? []).length > 0 && <p className="text-xs text-muted" data-testid="factory-relics">🏺 {t('Relíquias')}: {run.relics.map((c) => `${RELICS[c].icon} ${t(RELICS[c].label)}`).join(' · ')}</p>}
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
          <label className="flex items-center gap-2 text-sm font-semibold" data-testid="factory-nuzlocke">
            <input type="checkbox" checked={nuzlocke} onChange={(e) => setNuzlocke(e.target.checked)} />
            🕯️ {t('Modo Nuzlocke: quem desmaia vai embora e só um capturado por rota')}
          </label>
          <Button
            data-testid="factory-start"
            disabled={busy || pick == null}
            onClick={() => {
              const meta = claimStarter(factory, data, pick.id)
              const next = startRun(meta, data, pick.id, Math.floor(Math.random() * 2 ** 31), pick.shiny, { nuzlocke })
              if (!next) return
              saveFactory({ ...meta, run: next })
              onContinue()
            }}
          >
            🎲 {t('Começar a corrida')}
          </Button>
        </div>
      )}

      {!run && <WeeklyCard factory={factory} data={data} byId={byId} onContinue={onContinue} />}

      <details className="rounded-2xl bg-bg p-3" data-testid="factory-cosmetics">
        <summary className="cursor-pointer font-bold">🎨 {t('Loja de cosméticos')}</summary>
        <p className="my-2 text-xs text-muted">{t('Com as moedas: a Poké Ball que você joga nas batalhas e a moldura da caixa de texto.')}</p>
        <div className="grid grid-cols-3 gap-2 sm:grid-cols-4">
          {Object.entries(COSMETIC_BALLS).map(([id, price]) => {
            const have = hasCosmetic(factory, 'ball', id)
            const using = factory.ball === id
            return (
              <button key={id} type="button" data-testid={`cosmetic-${id}`} disabled={!have && factory.coins < price}
                onClick={() => saveFactory(have ? equipCosmetic(factory, 'ball', using ? null : id) : buyCosmetic(factory, 'ball', id) ?? factory)}
                className={`flex cursor-pointer flex-col items-center rounded-xl border-2 p-1 text-[11px] font-bold disabled:opacity-40 ${using ? 'border-amber-400 bg-amber-500/15' : 'border-transparent bg-card'}`}>
                <img src={spriteUrl(`items/${id}.png`)} alt="" className="pixelated h-8 w-8" />
                <span data-no-translate>{prettySlug(id)}</span>
                <span className="text-muted">{using ? `✓ ${t('Usando')}` : have ? t('Usar') : `🪙 ${price}`}</span>
              </button>
            )
          })}
        </div>
        <div className="mt-2 grid grid-cols-2 gap-2 sm:grid-cols-4">
          {Object.entries(COSMETIC_FRAMES).map(([id, price]) => {
            const have = hasCosmetic(factory, 'frame', id)
            const using = factory.frame === id
            return (
              <button key={id} type="button" data-testid={`frame-${id}`} disabled={!have && factory.coins < price}
                onClick={() => saveFactory(have ? equipCosmetic(factory, 'frame', using ? null : id) : buyCosmetic(factory, 'frame', id) ?? factory)}
                className={`frame-${id} dlg-box cursor-pointer rounded-xl border-4 p-2 text-xs font-bold disabled:opacity-40 ${using ? 'ring-2 ring-amber-400' : ''}`}>
                {t(FRAME_NAMES[id])} · {using ? `✓ ${t('Usando')}` : have ? t('Usar') : `🪙 ${price}`}
              </button>
            )
          })}
        </div>
      </details>

      <details className="rounded-2xl bg-bg p-3" data-testid="factory-upgrades" open={!run}>
        <summary className="cursor-pointer font-bold">⬆️ {t('Árvore de melhorias')} <span className="text-xs text-muted" data-testid="upgrades-progress">★ {Object.keys(UPGRADES).reduce((n, id) => n + upgradeLevel(factory, id), 0)}/{Object.values(UPGRADES).reduce((n, u) => n + u.max, 0)}</span></summary>
        <p className="my-2 text-xs text-muted">{t('Compradas com moedas, valem em todas as próximas corridas. Cada ramo começa na raiz; para avançar, a anterior, um andar recorde e Pokémon para começar.')}</p>
        <SkillTree factory={factory} />
      </details>

      {(factory.hall ?? []).length > 0 && (
        <details className="rounded-2xl bg-bg p-3" data-testid="factory-hall">
          <summary className="cursor-pointer font-bold">👑 {t('Hall da Fama')}</summary>
          <div className="mt-2 space-y-2">
            {factory.hall.map((h) => (
              // A foto do time campeão (no cenário do Campeão), como a tela do Hall da Fama dos jogos.
              <div key={h.key} className="overflow-hidden rounded-xl border-4 border-amber-300 bg-card shadow" data-testid="hall-photo">
                <div className="relative aspect-[3/1]">
                  <BattleBackground scene={battleScene('champion-kanto')} layout="bw" />
                  <div className="absolute inset-x-0 bottom-1 flex items-end justify-center gap-1">
                    {h.team.map((m, i) => <PokeIcon key={i} id={m.id} shiny={Boolean(m.shiny)} className="h-12 w-12 drop-shadow sm:h-16 sm:w-16" />)}
                  </div>
                </div>
                <p className="px-2 py-1 text-xs font-bold">👑 {t('Campeão no andar {0}').replace('{0}', h.floor)} · {h.team.map((m) => `Nv. ${m.level}`).join(' · ')}</p>
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

/** O nome curto de cada melhoria (nos requisitos da árvore). */
const UPGRADE_NAMES = {
  level: 'Treino', ivs: 'Genética', balls: 'Poké Balls', potions: 'Potions', revive: 'Revives', money: 'Dinheiro',
  shop: 'Desconto', exp: 'XP extra', expShare: 'Exp. Share', reroll: 'Sortear caminho', cards: 'Carta a mais', shiny: 'Shiny',
  greatBalls: 'Great Balls', rope: 'Escape Rope', coins: 'Moedas', map: 'Mapa', dmax: 'Dynamax Band', tera: 'Tera Orb',
  superPotions: 'Super Potions', hyperPotions: 'Hyper Potions', maxPotions: 'Max Potions', sitrus: 'Sitrus Berry', lum: 'Lum Berry', leftovers: 'Leftovers',
  sash: 'Focus Sash', ultraBalls: 'Ultra Balls', masterBall: 'Master Ball', quickBalls: 'Mão firme', netBalls: 'Mira certeira', timerBalls: 'Paciência',
  duskBalls: 'Isca', expPlus: 'XP avançado', luckyEgg: 'Lucky Egg', hpBoost: 'Vigor', speBoost: 'Agilidade', tutor: 'Move Tutor',
  reminder: 'Move Reminder', atk: 'Força', spa: 'Foco', def: 'Couraça', spd: 'Escudo', allStats: 'Mestre',
  band: 'Choice Band', scarf: 'Choice Scarf', specs: 'Choice Specs', lifeOrb: 'Life Orb', vest: 'Assault Vest', helmet: 'Rocky Helmet',
  quickClaw: 'Quick Claw', balloon: 'Air Balloon', brightPowder: 'Bright Powder', boots: 'Heavy-Duty Boots', kingsRock: 'King\'s Rock', loot: 'Recompensas',
  expertBelt: 'Expert Belt', bonusCoins: 'Tesouro', policy: 'Weakness Policy', muscleBand: 'Muscle Band', wiseGlasses: 'Wise Glasses', shellBell: 'Shell Bell',
  scopeLens: 'Scope Lens', eviolite: 'Eviolite', victoryHeal: 'Recuperação',
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
  lavacave: { label: 'Caverna de lava', icon: '🌋', color: '#c2410c' },
  poisoncave: { label: 'Caverna venenosa', icon: '🍄', color: '#7e22ce' },
  seacave: { label: 'Caverna aquática', icon: '🐚', color: '#0e7490' },
  desert: { label: 'Deserto', icon: '🏜️', color: '#b45309' },
  ruins: { label: 'Ruínas', icon: '🏛️', color: '#a16207' },
  flowers: { label: 'Campo de flores', icon: '🌸', color: '#db2777' },
  plant: { label: 'Usina', icon: '⚡', color: '#ca8a04' },
  crystal: { label: 'Mina de cristal', icon: '💎', color: '#7c3aed' },
  dunes: { label: 'Deserto à noite', icon: '🌙', color: '#4338ca' },
  bamboo: { label: 'Bambuzal', icon: '🎋', color: '#4d7c0f' },
  temple: { label: 'Templo', icon: '⛩️', color: '#b91c1c' },
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
  mart: { icon: '🎒', label: 'Vendedor ambulante', help: 'Vende o mesmo que o Poké Mart (sem batalha, sem XP).' },
  center: { icon: '⛺', label: 'Parada para descanso', help: 'Alguém do caminho cura o time todo, até quem desmaiou (sem batalha).' },
  event: { icon: '❓', label: 'Evento', help: 'Itens, dinheiro, frutas ou uma ficha de Move Tutor (sem batalha).' },
  trade: { icon: '🔁', label: 'Troca', help: 'Alguém da rota troca um Pokémon com você: o que vem chega 3 níveis acima (com o item de quem foi).' },
  wildboss: { icon: '🐉', label: 'Chefe sem treinador', help: 'Uma Mega, um Gigantamax ou um lendário. Dá para capturar.' },
  meteor: { icon: '☄️', label: 'Chuva de meteoros', help: 'Um Clefairy apareceu com os meteoros (mais chance de shiny).' },
  mythic: { icon: '✨', label: 'Pokémon mítico', help: 'Um Pokémon mítico, raríssimo. Dá para capturar.' },
  boss: { icon: '👑', label: 'Chefe', help: '' },
  rematch: { icon: '🏆', label: 'Revanche do Campeão', help: 'O Campeão que você venceu quer revanche: time mais forte, prêmio maior.' },
  rival: { icon: '⚔️', label: 'Rival', help: 'O seu rival te seguiu pela rota: quer ver quem ficou mais forte (prêmio maior).' },
  leave: { icon: '↩️', label: 'Voltar', help: 'Sai da água e volta para onde você entrou.' },
  area: { icon: '👑', label: 'Chefe do lugar', help: 'O Pokémon mais forte daqui (sem treinador): dá para capturar.' },
  dboss: { icon: '💀', label: 'Chefe', help: '' },
}
/** As MOs: o nome (do jogo, sem traduzir) e o que fazem na corrida. */
const HM_INFO = {
  cut: { name: 'Cut', icon: '✂️', help: 'Uma vez por rota, corta uma árvore e abre um caminho escondido (um selvagem raro).' },
  flash: { name: 'Flash', icon: '💡', help: 'Ilumina cavernas, esgotos e torres: dá para ver os caminhos sem o Mapa, e a caverna secreta sempre tem algo.' },
  surf: { name: 'Surf', icon: '🌊', help: 'Deixa mergulhar no mar (o caminho para o fundo do mar).' },
}
const CUT_INFO = { icon: '🌳', label: 'Caminho escondido', help: 'Aberto com Cut: um selvagem raro do lugar.' }
const CITY_KIND_SET = new Set(['gym', 'elite', 'champion'])
const EVENT_TEXT = {
  items: 'Você achou {1}× {0} no caminho!',
  money: 'Um treinador perdeu 💰{0} e não voltou para buscar.',
  berries: 'Frutas no caminho: o time recuperou 30% do HP.',
  tutor: 'Um velho professor te deu uma ficha de Move Tutor.',
  declined: 'Você seguiu o seu caminho.',
  helped: 'O treinador agradeceu e te deu {0}!',
  secretFound: 'Na caverna secreta: {0} e 💰{1}!',
  secretEmpty: 'A caverna estava vazia... e escura demais para procurar.',
  bought: 'O mercador sorriu e te entregou {0}.',
  betWon: 'Você ganhou a aposta: +💰{0}!',
  betLost: 'Você perdeu a aposta: −💰{0}.',
  injuredJoined: 'Você usou {0} e o Pokémon ferido quis ir com você!',
  noPotion: 'Sem nenhuma poção na Bolsa, não deu para curar o Pokémon ferido.',
}
const EVENT_ICON = { money: '💰', berries: '🍒', tutor: '📀', declined: '👣', helped: '🤝', secretFound: '💎', secretEmpty: '🕳️', bought: '🧳', betWon: '🎰', betLost: '🎰', injuredJoined: '💚', noPotion: '🩹' }
/** O símbolo de cada melhoria (no círculo da árvore). */
const UPGRADE_ICONS = {
  level: '🎓', ivs: '🧬', balls: '⚪', potions: '🧪', revive: '💖', money: '💰', shop: '🏷️', exp: '✨',
  expShare: '📡', reroll: '🎲', cards: '🃏', shiny: '🌟', greatBalls: '🔵', rope: '🪢', coins: '🪙', map: '🗺️',
  dmax: '🔴', tera: '💎', superPotions: '💧', hyperPotions: '🧴', maxPotions: '🍶', sitrus: '🍋', lum: '🫐', leftovers: '🍎',
  sash: '🎗️', ultraBalls: '🟡', masterBall: '🟣', quickBalls: '🎯', netBalls: '🫳', timerBalls: '⏳', duskBalls: '🍓', expPlus: '🌠',
  luckyEgg: '🥚', hpBoost: '❤️', speBoost: '💨', tutor: '📜', reminder: '🧠', atk: '⚔️', spa: '🔮', def: '🛡️',
  spd: '🔰', allStats: '👑', band: '🎀', scarf: '🧣', specs: '👓', lifeOrb: '🟠', vest: '🦺', helmet: '⛑️',
  quickClaw: '🦅', balloon: '🎈', brightPowder: '💫', boots: '👢', kingsRock: '🪨', loot: '💵', expertBelt: '🥋', bonusCoins: '🏆',
  policy: '📋', muscleBand: '💪', wiseGlasses: '🤓', shellBell: '🐚', scopeLens: '🔭', eviolite: '💠', victoryHeal: '💚',
}
/** A cor de cada ramo (as linhas e os círculos comprados), na ordem de UPGRADE_BRANCHES. */
const BRANCH_COLORS = ['#22c55e', '#38bdf8', '#f59e0b', '#ef4444', '#a855f7', '#eab308', '#ec4899']
/** A árvore em círculo (como as árvores de habilidade dos jogos): os ramos saem do centro para todos os lados. Igual ao app. */
// gap: a distância mínima entre os centros de dois nós vizinhos do mesmo anel (o maior círculo, com o brilho e o selo).
const TREE = { first: 190, step: 70, pad: 230, from: 90, to: -270, gap: 66 }
/** A melhoria grande que dá nome e símbolo (os nós pequenos usam os da melhoria do mesmo efeito). */
const upgradeKey = (id) => (isMinor(id) ? MINOR_BASE[UPGRADE_FX[id].join(':')] : id)
/**
 * As posições (árvore radial): cada ramo ganha um pedaço do círculo do tamanho
 * das pontas dele; cada melhoria fica no meio do pedaço do pai, mais longe do
 * centro a cada nível. Igual ao app.
 */
export function skillTreeLayout() {
  const parentOf = (id) => UPGRADE_TREE[id]?.needs?.[0] ?? null
  const kidsOf = {}
  for (const [, , ids] of UPGRADE_BRANCHES) for (const id of ids) { const p = parentOf(id); if (p) (kidsOf[p] ??= []).push(id) }
  const tipsMemo = {}
  const tips = (id) => (tipsMemo[id] ??= (kidsOf[id] ?? []).reduce((n, k) => n + tips(k), 0) || 1)
  const total = UPGRADE_BRANCHES.reduce((n, [, , ids]) => n + tips(ids[0]), 0)
  const rad = (d) => (d * Math.PI) / 180
  // 1º: o ângulo de cada um (o meio do pedaço do pai) e o nível (a distância do centro).
  const angles = []
  const mids = []
  let start = rad(TREE.from)
  UPGRADE_BRANCHES.forEach(([, , ids], b) => {
    const place = (id, a, z, depth, parent) => {
      angles.push({ branch: b, id, parent, angle: (a + z) / 2, depth })
      let x = a
      for (const k of kidsOf[id] ?? []) {
        const span = ((z - a) * tips(k)) / tips(id)
        place(k, x, x + span, depth + 1, id)
        x += span
      }
    }
    const span = ((rad(TREE.to) - rad(TREE.from)) * tips(ids[0])) / total
    place(ids[0], start, start + span, 0, null)
    mids.push(start + span / 2)
    start += span
  })
  // 2º: o raio de cada anel, grande o bastante para os vizinhos do mesmo anel não encostarem (nada um em cima do outro).
  const maxDepth = Math.max(...angles.map((n) => n.depth))
  const radii = []
  for (let d = 0; d <= maxDepth; d++) {
    const ring = angles.filter((n) => n.depth === d).map((n) => n.angle).sort((x, y) => x - y)
    let gap = 2 * Math.PI
    ring.forEach((a, k) => { if (ring.length > 1) gap = Math.min(gap, Math.abs((k + 1 < ring.length ? ring[k + 1] : ring[0] + 2 * Math.PI) - a)) })
    const need = ring.length > 1 ? TREE.gap / (2 * Math.sin(Math.min(gap, Math.PI) / 2)) : 0
    radii.push(Math.max(d === 0 ? TREE.first : radii[d - 1] + TREE.step, need))
  }
  const radius = radii[maxDepth]
  const size = 2 * (radius + TREE.pad)
  const c = size / 2
  const out = UPGRADE_BRANCHES.map(([icon, branch, ids], b) => ({
    icon, branch, ids, color: BRANCH_COLORS[b % BRANCH_COLORS.length], mid: mids[b],
    nodes: angles.filter((n) => n.branch === b).map((n) => ({ id: n.id, parent: n.parent, angle: n.angle, pos: [c + Math.cos(n.angle) * radii[n.depth], c - Math.sin(n.angle) * radii[n.depth]] })),
  }))
  return { branches: out, size, c, radius }
}

/**
 * A árvore de melhorias (como as árvores de habilidade dos jogos): fundo escuro,
 * os ramos saem do centro em todas as direções; os círculos grandes são as
 * melhorias (com o selo do nível), os pequenos são os nós da trilha delas.
 * Comprado: aceso na cor do ramo; para comprar: contorno claro; bloqueado:
 * apagado. Tocando, abre o que faz e o botão de comprar. Igual ao app.
 */
function SkillTree({ factory }) {
  const { branches: layout, size, c, radius } = useMemo(() => skillTreeLayout(), [])
  const firstOpen = layout.flatMap((b) => b.ids).find((id) => upgradePrice(factory, id) != null && !upgradeNeeds(factory, id).length)
  const [picked, setPicked] = useState(null)
  const [zoom, setZoom] = useState(0.4)
  // Tela cheia: a árvore ocupa a tela toda (Esc ou ✕ fecha).
  const [full, setFull] = useState(false)
  useEffect(() => {
    if (!full) return
    const close = (e) => e.key === 'Escape' && setFull(false)
    window.addEventListener('keydown', close)
    return () => window.removeEventListener('keydown', close)
  }, [full])
  const box = useRef(null)
  const id = picked ?? firstOpen ?? 'level'
  const up = UPGRADES[id]
  const level = upgradeLevel(factory, id)
  const price = upgradePrice(factory, id)
  const next = (up.offset ?? 0) + (level + 1) * up.per
  const needs = price == null ? [] : upgradeNeeds(factory, id)
  const stateOf = (u) => (upgradeLevel(factory, u) ? 'have' : upgradeNeeds(factory, u).some((n) => n.kind === 'up') ? 'locked' : 'open')
  const posOf = Object.fromEntries(layout.flatMap((b) => b.nodes.map((n) => [n.id, n.pos])))
  const spent = Object.values(factory.upgrades ?? {}).reduce((n, v) => n + v, 0)
  const all = Object.values(UPGRADES).reduce((n, u) => n + u.max, 0)
  // Começa no centro da árvore; dá para arrastar e dar zoom.
  useEffect(() => {
    const el = box.current
    if (el) { el.scrollLeft = (el.scrollWidth - el.clientWidth) / 2; el.scrollTop = (el.scrollHeight - el.clientHeight) / 2 }
  }, [zoom, full])
  const key = upgradeKey(id)
  const buyable = layout.flatMap((b) => b.ids).map((k) => [k, upgradePrice(factory, k)]).filter(([k, p]) => p != null && p <= (factory.coins ?? 0) && !upgradeNeeds(factory, k).length).sort((a, b) => a[1] - b[1])
  // Leva a árvore até o nó (no zoom de agora), para quem escolhe pela lista.
  const focus = (k) => {
    const el = box.current, pos = posOf[k]
    if (el && pos) { el.scrollLeft = pos[0] * zoom - el.clientWidth / 2; el.scrollTop = pos[1] * zoom - el.clientHeight / 2 }
  }
  return (
    <div className={full ? 'fixed inset-0 z-50 flex flex-col gap-2 bg-[#05070d] p-2' : 'space-y-2'} data-testid="skill-tree">
      <div className={full ? 'relative min-h-0 flex-1' : 'relative'}>
        <div ref={box} className={`${full ? 'h-full' : 'max-h-[34rem]'} overflow-auto rounded-xl`} style={{ background: 'radial-gradient(circle at center, #1e1b4b 0%, #0b1020 55%, #05070d 100%)' }}>
          <svg width={size * zoom} height={size * zoom} viewBox={`0 0 ${size} ${size}`} role="img" aria-label={t('Árvore de melhorias')}>
            {/* Anéis de fundo (a distância do centro). */}
            {[1, 2, 3, 4, 5].map((k) => <circle key={`ring-${k}`} cx={c} cy={c} r={(k * (size / 2 - TREE.pad)) / 5} fill="none" stroke="#1e293b" strokeWidth="2" strokeDasharray="6 10" />)}
            {layout.map((b) => b.nodes.map((n) => {
              const [x1, y1] = n.parent ? posOf[n.parent] : [c, c]
              const lit = upgradeLevel(factory, n.id) > 0
              return <line key={`l-${n.id}`} x1={x1} y1={y1} x2={n.pos[0]} y2={n.pos[1]} stroke={lit ? b.color : '#334155'} strokeOpacity={lit ? 1 : 0.7} strokeWidth={lit ? 5 : isMinor(n.id) ? 2 : 3} strokeLinecap="round" />
            }))}
            <circle cx={c} cy={c} r="54" fill="#0f172a" stroke="#fde047" strokeWidth="4" />
            <text x={c} y={c - 4} textAnchor="middle" fontSize="30">⭐</text>
            <text x={c} y={c + 30} textAnchor="middle" fontSize="15" fontWeight="900" fill="#fde047">{spent}/{all}</text>
            {layout.map((b) => {
              const have = b.ids.reduce((k, u) => k + upgradeLevel(factory, u), 0)
              const total = b.ids.reduce((k, u) => k + UPGRADES[u].max, 0)
              // O nome do ramo e os pontos, na borda, no meio do pedaço dele.
              const r = radius + 55
              return (
                <text key={`t-${b.branch}`} x={c + Math.cos(b.mid) * r} y={c - Math.sin(b.mid) * r + 10} textAnchor="middle" fontSize="30" fontWeight="900" fill={b.color} stroke="#05070d" strokeWidth="6" paintOrder="stroke">
                  {b.icon} {t(b.branch)} · {have}/{total}
                </text>
              )
            })}
            {layout.map((b) => b.nodes.map((n) => {
              const u = UPGRADES[n.id]
              const lv = upgradeLevel(factory, n.id)
              const state = stateOf(n.id)
              const sel = n.id === id
              const minor = isMinor(n.id)
              // O nó-chave (o último da trilha): maior e com o contorno dourado.
              const keystone = isKeystone(n.id)
              const r = keystone ? 17 : minor ? 11 : 24
              return (
                <g key={n.id} onClick={() => setPicked(n.id)} className="cursor-pointer" data-testid={`upgrade-${n.id}`} role="button" aria-label={t(UPGRADE_NAMES[upgradeKey(n.id)])}>
                  {state === 'have' && <circle cx={n.pos[0]} cy={n.pos[1]} r={r + 7} fill={b.color} opacity="0.25" />}
                  <circle cx={n.pos[0]} cy={n.pos[1]} r={sel ? r + 4 : r} fill={state === 'have' ? b.color : '#111827'} stroke={sel ? '#fde047' : keystone ? '#f59e0b' : state === 'locked' ? '#334155' : state === 'open' ? '#f8fafc' : b.color} strokeWidth={sel ? 5 : keystone ? 4 : minor ? 2 : 3} opacity={state === 'locked' ? 0.55 : 1} />
                  <text x={n.pos[0]} y={n.pos[1] + (minor ? 4 : 7)} textAnchor="middle" fontSize={keystone ? 15 : minor ? 11 : 20} opacity={state === 'locked' ? 0.5 : 1}>{state === 'locked' && !minor ? '🔒' : UPGRADE_ICONS[upgradeKey(n.id)]}</text>
                  {/* O nível (comprado/máximo), num selo embaixo (só nas melhorias grandes). */}
                  {!minor && (
                    <>
                      <rect x={n.pos[0] - 15} y={n.pos[1] + r - 4} width="30" height="15" rx="7.5" fill="#0f172a" stroke={b.color} strokeWidth="1.5" />
                      <text x={n.pos[0]} y={n.pos[1] + r + 7} textAnchor="middle" fontSize="10" fontWeight="900" fill="#f8fafc">{lv}/{u.max}</text>
                    </>
                  )}
                </g>
              )
            }))}
          </svg>
        </div>
        <div className="absolute right-2 top-2 flex gap-1">
          <button type="button" className="h-8 w-8 cursor-pointer rounded-full bg-slate-800 font-black text-white" onClick={() => setZoom((z) => Math.max(0.2, Math.round((z - 0.1) * 100) / 100))} aria-label={t('Diminuir')} data-testid="tree-zoom-out">−</button>
          <button type="button" className="h-8 w-8 cursor-pointer rounded-full bg-slate-800 font-black text-white" onClick={() => setZoom((z) => Math.min(1.5, Math.round((z + 0.1) * 100) / 100))} aria-label={t('Aumentar')} data-testid="tree-zoom-in">+</button>
          {/* Tela cheia (abre a árvore na tela toda; nela, fecha). */}
          <button type="button" className="h-8 w-8 cursor-pointer rounded-full bg-slate-800 font-black text-white" onClick={() => setFull((f) => !f)} aria-label={t(full ? 'Fechar' : 'Tela cheia')} data-testid={full ? 'tree-full-close' : 'tree-full'}>{full ? '✕' : '⛶'}</button>
        </div>
      </div>
      {/* Prático: o que dá para comprar agora (do mais barato), sem procurar na árvore; tocar leva até ele. */}
      {buyable.length > 0 && (
        <div className="flex items-center gap-1.5 overflow-x-auto whitespace-nowrap pb-1 text-xs" data-testid="upgrade-buyable">
          <span className="font-bold text-muted">{t('Dá para comprar')}:</span>
          {buyable.map(([k, p]) => (
            <button key={k} type="button" className="cursor-pointer rounded-full border border-amber-400/60 bg-card px-2 py-1 font-extrabold" data-testid={`buyable-${k}`}
              onClick={() => { setPicked(k); focus(k) }}>
              {UPGRADE_ICONS[upgradeKey(k)]} {t(UPGRADE_NAMES[upgradeKey(k)])} · 🪙{p}
            </button>
          ))}
        </div>
      )}
      {/* O que a melhoria escolhida faz, o que falta e o botão de comprar. */}
      <div className="flex items-center gap-2 rounded-xl border-2 border-amber-400/60 bg-card p-2 text-xs" data-testid="upgrade-detail">
        <span className="text-2xl">{UPGRADE_ICONS[key]}</span>
        <div className="min-w-0 flex-1">
          <p className="font-black">{t(UPGRADE_NAMES[key])}{isKeystone(id) ? ` · ${t('nó-chave')}` : isMinor(id) ? ` · ${t('nó pequeno')}` : ''}</p>
          <p className="font-bold">{t(up.label).replace('{0}', price == null ? (up.offset ?? 0) + upgradeValue(factory, id) : next)}</p>
          <p className="text-muted">{'★'.repeat(level)}{'☆'.repeat(up.max - level)} · {price == null ? t('No máximo') : `🪙 ${price}`}</p>
          {needs.map((n) => (
            <p key={n.kind} className="text-[11px] text-red-500" data-testid={`need-${id}-${n.kind}`}>
              ✖ {n.kind === 'up' ? t('{0} no nível {1}').replace('{0}', t(UPGRADE_NAMES[upgradeKey(n.id)])).replace('{1}', n.level) : n.kind === 'best' ? t('Chegar ao andar {0} (recorde: {1})').replace('{0}', n.floor).replace('{1}', factory.best ?? 0) : t('Ter {0} Pokémon para começar (tem {1})').replace('{0}', n.count).replace('{1}', factory.owned?.length ?? 0)}
            </p>
          ))}
        </div>
        {price != null && (
          <Button disabled={factory.coins < price || needs.length > 0} onClick={() => { const n = buyUpgrade(factory, id); if (n) saveFactory(n) }} data-testid="upgrade-buy">
            {t('Comprar')}
          </Button>
        )}
      </div>
    </div>
  )
}

/** O texto de um evento do mapa (com o item, o dinheiro ou a quantidade). */
function eventText(event) {
  const item = itemName(event.item ?? '')
  if (event.kind === 'money' || event.kind === 'betWon' || event.kind === 'betLost') return t(EVENT_TEXT[event.kind]).replace('{0}', event.money)
  if (event.kind === 'secretFound') return t(EVENT_TEXT.secretFound).replace('{0}', item).replace('{1}', event.money)
  return t(EVENT_TEXT[event.kind]).replace('{0}', item).replace('{1}', event.count ?? '')
}
/** As escolhas da rota: o que aparece, o ícone e os botões. */
const CHOICE_INFO = {
  help: { icon: '🙋', text: 'Um treinador perdeu as Poké Balls e pede ajuda: dar 💰{0} para ele?', yes: 'AJUDAR', no: 'RECUSAR' },
  follow: { icon: '🐾', text: 'Um Pokémon ferido foge para dentro do mato. Seguir ele?', yes: 'SEGUIR', no: 'DEIXAR' },
  secret: { icon: '🕳️', text: 'Uma entrada escondida entre as pedras: entrar na caverna secreta?', yes: 'ENTRAR', no: 'NÃO ENTRAR' },
  merchant: { icon: '🧳', text: 'Um mercador misterioso oferece {2} por 💰{0}. Comprar?', yes: 'COMPRAR', no: 'RECUSAR' },
  bet: { icon: '🎰', text: 'Um apostador te desafia: 💰{0} no cara ou coroa. Dobra ou perde tudo!', yes: 'APOSTAR', no: 'RECUSAR' },
  injured: { icon: '🩹', text: 'Um {1} ferido na beira do caminho. Usar uma poção nele? Curado, ele quer ir com você.', yes: 'CURAR', no: 'DEIXAR' },
}
/** A missão da rota. */
const MISSION_TEXT = {
  defeat: 'Derrote {0} Pokémon do tipo {1}',
  catch: 'Capture um Pokémon do tipo {1}',
  grunts: 'Derrote {0} capangas da base',
}
function missionText(m) {
  return t(MISSION_TEXT[m.kind]).replace('{0}', m.need).replace('{1}', m.type ? m.type[0].toUpperCase() + m.type.slice(1) : '')
}
/** As pistas do lendário da região, conforme a história anda (a última: na rota para a Liga). */
const LEGEND_CLUES = [
  'Os moradores falam de um Pokémon lendário que vive nesta região...',
  'Pegadas enormes no caminho: algo muito poderoso passou por aqui.',
  'Um velho conta que o lendário só aparece para quem chega perto da Liga.',
  'O ar está pesado: o lendário espera num dos caminhos para a Liga!',
]
/** O líder antes da luta, pelo tipo do ginásio. */
const LEADER_LINES = {
  normal: 'Força bruta e simplicidade: o meu time não tem fraquezas escondidas!',
  fire: 'As chamas do meu ginásio vão testar a sua coragem!',
  water: 'Vamos ver se você aguenta a força da correnteza!',
  grass: 'A natureza tem paciência... e raízes fortes. Prepare-se!',
  electric: 'Sente o choque? É a energia do meu ginásio!',
  ice: 'Frio e calma: assim se vence uma batalha.',
  fighting: 'Treino todo dia desde o nascer do sol. Mostre a sua garra!',
  poison: 'Um passo em falso e o veneno decide a luta.',
  ground: 'Pise firme: aqui o chão é meu aliado!',
  flying: 'Vamos ver se você consegue acompanhar o vento!',
  psychic: 'Eu já vi como esta batalha termina... mas venha mesmo assim.',
  bug: 'Pequenos, mas espertos: os insetos sempre surpreendem!',
  rock: 'Duro como pedra: o meu time não cede!',
  ghost: 'Hehe... os meus Pokémon adoram visitas.',
  dragon: 'Os dragões só respeitam quem é forte de verdade!',
  dark: 'Nas sombras, quem ataca primeiro vence.',
  steel: 'Aço polido e estratégia: nenhum golpe passa fácil.',
  fairy: 'Encanto e poder: não se engane com a aparência!',
}
/** Depois da luta: o líder entrega a insígnia, o rival reage (conforme perde), o vilão foge. */
const BEAT_LINES = {
  gym: 'Você venceu de forma justa. Esta insígnia é sua!',
  elite: 'Impressionante... siga em frente: o próximo da Elite espera.',
  champion: 'Você é o novo Campeão! O seu nome vai para o Hall da Fama.',
  villain: 'Isso não acaba aqui! Os nossos planos continuam...',
}
const RIVAL_BEAT = [
  'Hmpf... foi sorte! Da próxima vez eu ganho.',
  'De novo?! Vou treinar em dobro, pode esperar.',
  'Você ficou forte de verdade... mas eu não desisto.',
  'Tudo bem, você é melhor. Te espero na Liga!',
]
/** O plano de cada equipe vilã (contado quando ela aparece). */
const VILLAIN_PLANS = {
  rocket: 'A Equipe Rocket quer roubar Pokémon raros e dominar o mundo!',
  aqua: 'A Equipe Aqua quer despertar o lendário e cobrir a terra com o mar!',
  magma: 'A Equipe Magma quer secar os mares e aumentar a terra firme!',
  galactic: 'A Equipe Galáctica quer apagar o mundo e criar um novo, sem espírito!',
  plasma: 'A Equipe Plasma quer separar os Pokémon de todos os treinadores!',
  flare: 'A Equipe Flare quer um mundo belo... só para eles!',
  skull: 'A Equipe Skull só quer bagunça e roubar Pokémon por aí!',
  aether: 'A Fundação Aether esconde segredos sobre as Ultra Beasts!',
  star: 'A Equipe Star tem os próprios motivos... prove que merece saber!',
}
/** A estação e a hora (do relógio de quem joga): mudam os Pokémon que aparecem e o clima. */
const SEASON_LABEL = { spring: '🌸 Primavera', summer: '☀️ Verão', autumn: '🍂 Outono', winter: '❄️ Inverno' }
const LEGEND_INFO = { icon: '🌟', label: 'Lendário', help: 'O lendário da região espera aqui. Dá para capturar.' }

/** O passo da tela depois do andar: o que ainda falta ver ou escolher (ou nada: o mapa). */
function stepOf(p) {
  if (!p) return null
  if (p.choice) return 'choice'
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
    <div ref={fieldRef} className="relative aspect-[4/3] overflow-hidden rounded-t-2xl border-4 border-b-0 hud-edge" style={{ background: '#9fdcff' }} data-testid={testid} data-layout="bw">
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
function FieldMon({ mon, byId, back = false, follower = false, scene }) {
  const p = byId?.get(mon.id)
  if (!p) return null
  const scale = battleScale(p.height)
  // follower: andando com você na cidade (de frente, do tamanho dele perto de você, sem base).
  const place = follower ? 'absolute bottom-[23%] left-[42%] w-[58%]' : back ? 'absolute bottom-[22%] left-[1%] w-[58%]' : 'absolute right-[11%] w-[26%]'
  return (
    <div className={place} style={back || follower ? undefined : { bottom: `${foeBottom(battleScene(scene)) * 100}%` }} data-testid={follower ? 'follower' : undefined}>
      {!follower && <PlatformBase scene={battleScene(scene)} side={back ? 'mine' : 'foe'} scale={scale} />}
      <div className="aspect-square w-full" style={{ transform: `scale(${scale})`, transformOrigin: '50% 100%' }}>
        <Sprite key={`${p.id}-${mon.shiny}`} path={mon.shiny ? shinyPath(p.sprite) : p.sprite} box={p.box} fill={0.95} align="bottom" back={back} battle alt={p.name} />
      </div>
    </div>
  )
}

/**
 * A evolução, como nos jogos: o Pokémon fica branco e pisca alternando com a
 * forma nova, cada vez mais rápido, até ela aparecer com brilho.
 */
function EvolutionFx({ from, to, byId }) {
  const sprite = (id, cls) => {
    const p = byId?.get(id)
    return p ? <div className={`absolute inset-0 ${cls}`}><Sprite path={p.sprite} box={p.box} fill={0.9} align="bottom" battle alt={p.name} /></div> : null
  }
  // A tela escurece e o Pokémon fica grande no meio, girando e piscando até virar a forma nova; depois a tela volta.
  return (
    <div className="evo-stage pointer-events-none absolute inset-0 z-30 flex items-center justify-center" data-testid="evolution-fx">
      <div className="evo-glow absolute aspect-square w-[70%] rounded-full" />
      <div className="evo-spin relative aspect-square w-[55%]">
        {sprite(from, 'evo-from')}
        {sprite(to, 'evo-to')}
      </div>
    </div>
  )
}
/** Quem evolui para id (a forma anterior), pelos dados da Factory. */
const preEvolution = (data, id) => Number(Object.keys(data?.evolutions ?? {}).find((k) => data.evolutions[k].some((e) => e[0] === id))) || null

/** Alguém de pé na base de cima (Enfermeira Joy, o chefe, os vendedores...). */
/** Alguém lá atrás (vendedor, Enfermeira...) da altura de uma pessoa perto dos Pokémon. Igual ao app. */
function FarPerson({ id, trainers, width }) {
  const t = trainers?.find((x) => x.id === id)
  if (t) return <TrainerSprite trainer={t} height={farPerson(width)} />
  return <img src={spriteUrl(`trainers/${id}.png`)} alt="" className="pixelated max-w-none object-contain object-bottom" style={{ height: (farPerson(width) * 80) / TRAINER_ADULT_PX }} />
}

function FarStand({ children, scene, plain = false }) {
  return (
    <div className="absolute right-[6%] flex w-[36%] items-end justify-center" style={{ bottom: `${foeBottom(battleScene(scene)) * 100}%` }}>
      {scene && !plain && <PlatformBase scene={battleScene(scene)} side="foe" scale={0.8} />}
      <div className="relative flex w-full items-end justify-center">{children}</div>
    </div>
  )
}

/** A cor de cada região (o tema dela na barra da corrida). Igual ao app. */
const REGION_THEME = {
  Kanto: '#b91c1c', Johto: '#a16207', Hoenn: '#15803d', Sinnoh: '#1d4ed8', Unova: '#3f3f46', Kalos: '#0369a1', Alola: '#ea580c', Galar: '#7e22ce', Paldea: '#be123c',
}

/**
 * O mapa da região: as cidades da história, na ordem, acendendo conforme você
 * ganha as insígnias (a de agora piscando). Igual ao app.
 */
function RegionMap({ data, run, onClose }) {
  const game = data.bosses[run.boss.region]
  const cities = []
  game.leaders.forEach((l, k) => {
    if (!l.city) return
    const last = cities[cities.length - 1]
    if (last?.city === l.city) last.steps.push(k)
    else cities.push({ city: l.city, steps: [k], kind: l.kind })
  })
  const color = REGION_THEME[game.region] ?? '#334155'
  return (
    <div className="space-y-2 p-2" data-testid="region-map">
      <OverlayClose onClose={onClose} title={`🗺️ ${game.region} · ${game.game}`} />
      <div className="relative rounded-xl p-3" style={{ background: `linear-gradient(135deg, ${color}33, #0f172a22)` }}>
        <div className="absolute bottom-6 left-7 top-6 w-1 rounded bg-slate-500/40" />
        {cities.map((c, i) => {
          const done = c.steps.every((k) => k < run.boss.step)
          const here = !done && c.steps.some((k) => k >= run.boss.step) && (i === 0 || cities[i - 1].steps.every((k) => k < run.boss.step))
          return (
            <div key={i} className="relative flex items-center gap-3 py-1" data-testid={done ? 'city-lit' : here ? 'city-here' : 'city-dark'}>
              <span className={`z-10 inline-block h-5 w-5 rounded-full border-2 ${done ? 'border-amber-300 bg-amber-400 shadow-[0_0_8px_#fbbf24]' : here ? 'animate-pulse border-white bg-sky-400' : 'border-slate-500 bg-slate-700'}`} />
              <span className={`text-sm font-bold ${done ? '' : 'text-muted'}`} data-no-translate>{c.city}</span>
              {here && <span className="text-xs text-sky-500">◀ {t('você está indo para cá')}</span>}
            </div>
          )
        })}
      </div>
    </div>
  )
}

/** A ajuda para quem está começando: tipos, clima, efeitos, status, mecânicas e captura. Igual ao app. */
const HELP = [
  ['🔥', 'Tipos', 'Cada golpe tem um tipo. Contra um tipo fraco a ele, causa o dobro (super efetivo); contra um que resiste, a metade. Alguns tipos são imunes (Normal não acerta Fantasma). A tabela de tipos fica na Enciclopédia.'],
  ['🌦️', 'Clima', 'Sol fortalece Fogo e enfraquece Água; chuva faz o contrário; areia e neve machucam quem não é do tipo certo a cada turno. Alguns lugares já têm clima.'],
  ['🌿', 'Terrenos e efeitos do lugar', 'Terrenos (Grassy, Electric, Psychic, Misty) mudam o poder de alguns golpes. Alguns lugares têm efeitos próprios, como ventos fortes ou névoa tóxica.'],
  ['💤', 'Status', 'Queimado perde HP e bate mais fraco; envenenado perde HP; paralisado fica lento e às vezes não se mexe; dormindo e congelado não atacam. Status ajuda a capturar.'],
  ['✨', 'Mega, Z, Dynamax e Tera', 'Com o item certo, o botão no meio dos golpes ativa a mecânica uma vez por batalha: Mega Evolução, Movimento Z (só em Alola), Dynamax (Dynamax Band) e Terastal (Tera Orb).'],
  ['🎯', 'Captura', 'Quanto menos HP e com status, mais fácil. Selvagens de nível baixo são mais fáceis; de nível acima do seu Pokémon, bem mais difíceis. Bolas melhores ajudam.'],
  ['🏙️', 'Cidades e lugares', 'A cada rota de 10 andares você chega numa cidade: ginásio, Poké Mart, Centro Pokémon e Creche. Perto dela há um lugar com 10 andares e um chefe; depois, de volta à cidade.'],
  ['💞', 'Amizade e habilidades', 'Quem fica no time ganha amizade e alguns evoluem por ela. Pickup acha itens, Intimidate espanta selvagens e Synchronize passa a Nature para o capturado.'],
]
function HelpPanel({ onClose }) {
  return (
    <div className="space-y-2 p-2" data-testid="help-panel">
      <OverlayClose onClose={onClose} title={`❓ ${t('Ajuda')}`} />
      {HELP.map(([icon, title, text]) => (
        <div key={title} className="rounded-xl bg-card p-2">
          <p className="text-sm font-bold">{icon} {t(title)}</p>
          <p className="text-xs text-muted">{t(text)}</p>
        </div>
      ))}
    </div>
  )
}

/** As molduras da caixa de texto (loja de cosméticos). */
const FRAME_NAMES = { gold: 'Dourada', crystal: 'Cristal', night: 'Noite', sakura: 'Sakura' }
/** As regras da corrida da semana. */
const WEEKLY_RULE_TEXT = {
  normal: 'Sem regra especial: chegue o mais longe que puder.',
  nuzlocke: 'Nuzlocke: quem desmaia vai embora e só um capturado por rota.',
  noItems: 'Sem itens: a corrida começa com a Bolsa vazia.',
}

/**
 * A corrida da semana (o torneio entre amigos): a mesma semente, o mesmo
 * inicial e a mesma regra para todo mundo; o ranking é o andar alcançado.
 */
function WeeklyCard({ factory, data, byId, onContinue }) {
  const week = weekKey()
  const w = weeklyOf(data, week)
  const [list, setList] = useState([])
  const user = useAuth((a) => a.user)
  useEffect(() => {
    if (!user) return undefined
    let stop = null, live = true
    watchRanking(10, 'factory', week, (rows) => live && setList(rows), () => {}).then((s) => (live ? (stop = s) : s?.()))
    return () => { live = false; stop?.() }
  }, [user, week])
  return (
    <div className="space-y-2 rounded-2xl bg-bg p-3" data-testid="factory-weekly">
      <p className="font-bold">🏆 {t('Corrida da semana')}</p>
      <div className="flex items-center gap-2">
        <PokeIcon id={w.starter} className="h-12 w-12" />
        <div className="min-w-0 flex-1 text-sm">
          <p className="font-bold" data-no-translate>{t(prettyName(byId?.get(w.starter)?.name ?? ''))}</p>
          <p className="text-xs text-muted">{t(WEEKLY_RULE_TEXT[w.rule])}</p>
          <p className="text-xs text-muted">{t('A mesma corrida para todo mundo nesta semana: veja quem chega mais longe.')}</p>
        </div>
        <Button data-testid="factory-weekly-start" onClick={() => { const next = startWeekly(factory, data, week); if (next) { saveFactory({ ...factory, run: next }); onContinue() } }}>{t('Jogar')}</Button>
      </div>
      {user ? (
        <ol className="space-y-0.5 text-xs" data-testid="factory-weekly-ranking">
          {list.map((row, k) => (
            <li key={row.uid} className={`flex justify-between rounded px-2 py-0.5 ${row.uid === user.uid ? 'bg-amber-500/15 font-bold' : 'bg-card'}`}>
              <span data-no-translate>{k + 1}. {row.name}</span>
              <span>{t('Andar {0}').replace('{0}', row.score)}</span>
            </li>
          ))}
          {!list.length && <li className="text-muted">{t('Ninguém jogou ainda nesta semana.')}</li>}
        </ol>
      ) : (
        <p className="text-xs text-muted">{t('Entre na conta para aparecer no ranking.')}</p>
      )}
    </div>
  )
}

/** O nome de cada equipe vilã (nomes dos jogos). */
const TEAM_NAMES = {
  rocket: 'Equipe Rocket', aqua: 'Equipe Aqua', magma: 'Equipe Magma', galactic: 'Equipe Galáctica', plasma: 'Equipe Plasma',
  flare: 'Equipe Flare', skull: 'Equipe Skull', aether: 'Fundação Aether', star: 'Equipe Star',
}

/**
 * As falas uma de cada vez, no mesmo lugar (a caixa não cresce), como nos jogos:
 * tocar passa para a próxima (▼). Sem falas, o texto de fallback. Igual ao app.
 */
function Dialogue({ lines, fallback = null }) {
  const [k, setK] = useState(0)
  if (!lines.length) return fallback ? <p>{fallback}</p> : null
  const last = k >= lines.length - 1
  return (
    <button type="button" onClick={() => !last && setK(k + 1)} className={`block w-full text-left ${last ? 'cursor-default' : 'cursor-pointer'}`} data-testid="factory-dialogue">
      <span className="block min-h-[3.2em]">{lines[Math.min(k, lines.length - 1)]}</span>
      {!last && <span className="dlg-sub block animate-pulse text-right text-xs">▼ {k + 1}/{lines.length}</span>}
    </button>
  )
}

/** Os botões do menu, como os da batalha ("▸ LUTAR"); sub: uma linha menor embaixo. */
/** Um botão da linha fixa de ferramentas (BOLSA, TIME, MAPA, AJUDA). Igual ao app. */
function ToolButton({ icon, children, onClick, testid, active = false }) {
  return (
    <button type="button" onClick={onClick} data-testid={testid}
      className={`dlg-btn tool-btn cursor-pointer truncate rounded-lg px-1 text-xs font-black ${active ? 'active' : ''}`}>
      {icon} {children}
    </button>
  )
}

function MenuButton({ children, sub, onClick, disabled = false, testid, active = false }) {
  return (
    <button type="button" onClick={onClick} disabled={disabled} data-testid={testid}
      className={`dlg-btn cursor-pointer rounded-lg px-2 py-2 text-left disabled:cursor-default disabled:opacity-40 ${active ? 'active' : ''}`}>
      <span className="block font-black">▸ {children}</span>
      {sub && <span className="dlg-sub block pl-3 text-[11px] font-semibold leading-tight">{sub}</span>}
    </button>
  )
}

/**
 * Os botões de baixo da corrida como os da batalha: cada um sempre no mesmo lugar, sem rolar. O que não cabe na caixa
 * vai para a página seguinte (◀ 1/2 ▶ embaixo), com as fileiras inteiras (nunca um botão cortado). Igual ao app.
 */
function PagedMenu({ children, wide = false }) {
  const box = useRef(null)
  const grid = useRef(null)
  const [pages, setPages] = useState([])
  const [page, setPage] = useState(0)
  const nav = 30
  useLayoutEffect(() => {
    const b = box.current, g = grid.current
    if (!b || !g) return
    const limit = b.clientHeight - nav
    const items = [...g.children].map((el) => [el.offsetTop, el.offsetTop + el.offsetHeight]).sort((x, y) => x[0] - y[0])
    const total = g.scrollHeight
    let next = []
    if (total <= b.clientHeight + 0.5 || !items.length || !(limit > 0)) next = [[0, total]]
    else {
      let start = 0, end = 0
      for (const [top, bottom] of items) {
        if (bottom - start > limit + 0.5 && end > start) { next.push([start, end]); start = top }
        end = Math.max(end, bottom)
      }
      next.push([start, Math.max(end, start)])
    }
    const at = Math.min(page, next.length - 1)
    // Fora da página: não dá para tocar nem chegar pelo teclado.
    for (const el of g.children) el.inert = next.length > 1 && (el.offsetTop < next[at][0] - 0.5 || el.offsetTop + el.offsetHeight > next[at][1] + 0.5)
    if (JSON.stringify(next) !== JSON.stringify(pages)) setPages(next)
  })
  const paged = pages.length > 1
  const at = Math.min(page, Math.max(0, pages.length - 1))
  const [start, end] = paged ? pages[at] : [0, 0]
  return (
    <div ref={box} className="flex h-full flex-col">
      <div className="relative overflow-hidden" style={{ height: paged ? Math.min(end - start, 9999) : '100%' }}>
        <div ref={grid} className={`relative grid content-start gap-1 ${wide ? '' : 'grid-cols-2'}`} style={{ transform: `translateY(${-start}px)` }}>{children}</div>
      </div>
      {paged && (
        <div className="mt-auto flex h-[30px] shrink-0 items-center justify-center gap-4 font-black">
          <button type="button" className="cursor-pointer px-2 disabled:opacity-30" disabled={at === 0} onClick={() => setPage(at - 1)} data-testid="factory-menu-prev" aria-label={t('Anterior')}>◀</button>
          <span className="text-xs tabular-nums" data-testid="factory-menu-page">{at + 1}/{pages.length}</span>
          <button type="button" className="cursor-pointer px-2 disabled:opacity-30" disabled={at === pages.length - 1} onClick={() => setPage(at + 1)} data-testid="factory-menu-next" aria-label={t('Próxima')}>▶</button>
        </div>
      )}
    </div>
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
  lavacave: 'O calor sobe do chão e rios de lava iluminam as paredes.',
  poisoncave: 'Uma névoa roxa cobre o chão; melhor não respirar fundo.',
  seacave: 'A água bate nas pedras e ecoa por toda a caverna.',
  mountain: 'O caminho sobe pelas pedras; o ar fica mais fino.',
  desert: 'O sol queima e a areia apaga as pegadas.',
  volcano: 'O chão treme e a lava borbulha por perto.',
  snow: 'A neve cai sem parar e cobre o caminho.',
  city: 'Ruas cheias de treinadores querendo um desafio.',
  sky: 'Nuvens por todo lado: só os que voam passam por aqui.',
  tower: 'Velas acesas e um frio estranho: dizem que a torre é assombrada.',
  ruins: 'Colunas quebradas e inscrições antigas: dizem que algo dorme aqui.',
  flowers: 'Um mar de flores balança com o vento; o pólen deixa tudo sonolento.',
  plant: 'Máquinas zumbem e faíscas pulam dos cabos: cuidado com os raios.',
  crystal: 'Cristais brilham nas paredes da mina; às vezes eles caem do teto.',
  dunes: 'A lua ilumina as dunas e a areia engole os passos.',
  bamboo: 'Os bambus estalam ao vento e a luz entra em faixas.',
  temple: 'Incenso e silêncio: o templo guarda Pokémon antigos.',
}
/** O rival e os vilões antes da luta. */
/** O rival de surpresa na rota (fora os da história). */
const RIVAL_RACE_LINES = [
  'Ei! Te alcancei! Vamos ver quem treinou mais desde a última vez!',
  'Você de novo? Ótimo, eu estava te procurando!',
  'Não vou deixar você chegar no próximo ginásio sem uma revanche!',
]
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
function TownMap({ route, pos, from, to, title, me, width, fieldRef, onPick, blocked, placeName }) {
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
    <div ref={fieldRef} className="town-map relative aspect-[4/3] overflow-hidden rounded-t-2xl border-4 border-b-0 hud-edge" data-testid="factory-map" data-fork="1">
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
          <TrainerSprite trainer={me} box={width * 0.17} />
        </span>
      )}
      {/* Os caminhos: botões no próprio mapa. */}
      {route.options.map((node, k) => {
        const info = node.kind === 'dungeon' ? { icon: (BIOME_INFO[node.scene] ?? BIOME_INFO.cave).icon, label: placeName(node.place) } : node.legend != null ? LEGEND_INFO : node.cut ? CUT_INFO : NODE_INFO[node.kind]
        const b = node.biome && !node.cut ? BIOME_INFO[node.biome] : null
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
/**
 * As insígnias da região de agora: uma por líder de ginásio, na cor do tipo
 * dele; as ganhas acesas, as que faltam apagadas. Igual ao app.
 */
function Badges({ data, run }) {
  const leaders = data.bosses[run.boss.region]?.leaders ?? []
  const gyms = leaders.map((l, k) => [l, k]).filter(([l]) => l.kind === 'gym')
  if (!gyms.length) return null
  return (
    <span className="flex items-center gap-0.5 rounded bg-slate-900/50 px-1 py-0.5" data-testid="factory-badges" title={t('Insígnias')}>
      {gyms.map(([l, k]) => {
        const won = k < run.boss.step
        return (
          <span key={k} title={`${t('Insígnia de {0}').replace('{0}', l.name)}${won ? '' : ` (${t('falta')})`}`} data-testid={won ? 'badge-won' : 'badge-missing'}
            className={`inline-block h-3.5 w-3.5 rotate-45 rounded-[3px] border ${won ? 'border-white shadow-[0_0_4px_#fff8]' : 'border-white/30 opacity-40'}`}
            style={{ background: won ? typeColor(leaderType(data, l)) : 'transparent' }} />
        )
      })}
    </span>
  )
}

// tools: BOLSA, TIME, MAPA e AJUDA numa linha fixa no alto da tela de baixo; os caminhos e o resto, nas páginas (◀ ▶).
function BattleFrame({ field, run, byId, data = null, frame = null, text, menu, wideMenu = false, panel = null, tools = null }) {
  // A moldura comprada na loja de cosméticos e a cor da região (o tema dela na barra).
  const theme = data && run ? REGION_THEME[data.bosses[run.boss.region]?.region] : null
  return (
    <div className="select-none">
      {/* A Bolsa, o time, a loja e a troca abrem por cima do campo (a mesma tela, como no jogo; dá para jogar com o celular de lado). */}
      <div className="relative">
        {/* Sem corte seco: a tela do lugar troca com um fade (mapa, loja, resultado...). */}
        <div key={field?.props?.testid ?? ''} className="page-in">{field}</div>
        {/* A fala dentro da tela, embaixo, no mesmo lugar e do mesmo tamanho da batalha (o que não cabe: tocar passa). */}
        <div className={`dlg-box absolute inset-x-[1.5%] bottom-[1.5%] z-20 h-[21%] cursor-pointer space-y-1 overflow-hidden rounded-lg border-4 px-3 py-1.5 text-left text-sm leading-snug font-bold sm:px-4 sm:text-lg ${frame ? `frame-${frame}` : ''}`}
          data-testid="factory-text" onClick={(e) => { const el = e.currentTarget; el.scrollTop = el.scrollTop + el.clientHeight >= el.scrollHeight - 1 ? 0 : el.scrollTop + el.clientHeight - 8 }}>
          {text}
        </div>
        {panel && <div key={panel?.key ?? panel?.props?.testid ?? 'panel'} className="field-overlay factory-overlay panel-in rounded-t-2xl border-4 border-b-0 hud-edge bg-bg text-text" data-testid="factory-panel">{panel}</div>}
      </div>
      {!run && <div className="h-7 border-x-4 hud-edge hud-bar" />}
      {run && (
        <div className="flex h-7 items-center gap-x-2 whitespace-nowrap border-x-4 hud-edge hud-bar px-2 text-xs font-bold text-white" style={theme ? { background: `linear-gradient(90deg, ${theme}, color-mix(in srgb, #334155 78%, var(--hud-accent, #334155)) 70%)` } : undefined} data-testid="factory-bar">
          {/* As informações rolam de lado; o time fica sempre à direita. A Bolsa é só a contagem (o que tem dentro: em BOLSA). Igual ao app. */}
          <span className="flex min-w-0 flex-1 items-center gap-x-3 overflow-x-auto">
            <span>🎲 {t('Andar {0}').replace('{0}', run.floor)}</span>
            <span>💰 {run.money}</span>
            <span title={t('Bolsa')} data-testid="factory-bag-count">🎒 {BAG_ITEMS.reduce((n, id) => n + (run.bag[id] ?? 0), 0)}</span>
            {/* Os ovos que vão junto: quantas vitórias faltam para chocar. */}
            {(run.eggs ?? []).map((e, i) => <span key={i} title={t('Choca em {0} vitórias').replace('{0}', e.left)} data-testid="factory-egg">🥚{e.left}</span>)}
            <span title={t('Pokédex da corrida')} data-testid="factory-dex">📖 {dexOf(run).length}</span>
            {data && <Badges data={data} run={run} />}
            {(run.hms ?? []).map((hm) => <span key={hm} title={HM_INFO[hm]?.name}>{HM_INFO[hm]?.icon}</span>)}
            {run.daycare && <span title={t('Creche')}>🏡</span>}
          </span>
          <span className="flex shrink-0 gap-0.5">
            {run.team.map((m, i) => (
              <span key={i} className="flex flex-col items-center" title={t(prettyName(byId?.get(m.id)?.name ?? ''))}>
                <PokeIcon id={m.id} shiny={Boolean(m.shiny)} className={`h-5 w-5 ${(m.hp ?? 1) > 0 ? '' : 'opacity-40 grayscale'}`} />
                <span className="block h-1 w-6 overflow-hidden rounded bg-slate-900">
                  <span className={`block h-full ${(m.hp ?? 1) > 0.5 ? 'bg-emerald-400' : (m.hp ?? 1) > 0.2 ? 'bg-amber-400' : 'bg-red-500'}`} style={{ width: `${Math.max(0, Math.min(1, m.hp ?? 1)) * 100}%` }} />
                </span>
              </span>
            ))}
          </span>
        </div>
      )}
      {/* A tela de baixo: da altura da tela de baixo da batalha (nada muda de tamanho entre a corrida e a batalha). */}
      {/* Os botões ficam sempre nos mesmos lugares (como na batalha): o que não cabe vai para a próxima página (◀ ▶). */}
      <div className="h-[15.5rem] rounded-b-2xl border-4 hud-edge hud-base p-2" data-testid="factory-bottom">
        {menu && (
          <div className="dlg-box flex h-full flex-col rounded-xl border-4 p-2">
            {tools && <div className="mb-1.5 grid h-[30px] shrink-0 grid-cols-4 gap-1 border-b border-[var(--dlg-sub)]/35 pb-1.5" data-testid="factory-tools">{tools}</div>}
            <div className="min-h-0 flex-1"><PagedMenu key={field?.props?.testid ?? ''} wide={wideMenu}>{menu}</PagedMenu></div>
          </div>
        )}
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
  // Os golpes que o time aprende subindo de nível (como nos jogos), um de cada vez: queue [[posição, golpe, entrou sozinho]];
  // step 'ask' (quer aprender?) ou 'forget' (a tela dos 5 golpes); msg: o que aconteceu (com CONTINUAR); pick: o golpe tocado.
  const [learn, setLearn] = useState(null)
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
  // Saiu no meio da batalha do andar: voltando, ela continua de onde parou (direto, sem passar pelo mapa). Igual ao app.
  const resumeAsked = useRef(false)
  useEffect(() => {
    const r = factory.run
    if (resumeAsked.current || busy || !r?.encounter || stepOf(r.pending) || r.battle?.floor !== r.floor) return
    resumeAsked.current = true
    onBattle(r)
  }, [factory.run, busy, onBattle])
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
  const extras = run && (panel === 'bag' || panel === 'team' || panel === 'region' || panel === 'help') && (
    panel === 'region' ? (
      <RegionMap data={data} run={run} onClose={() => setPanel(null)} />
    ) : panel === 'help' ? (
      <HelpPanel onClose={() => setPanel(null)} />
    ) : panel === 'bag' ? (
      <BagPanel run={run} byId={byId} save={save} onClose={() => setPanel(null)} />
    ) : (
      // O time com o tamanho do campo (sem rolar): a lista e as páginas cabem nele.
      <div className="flex h-full flex-col p-2">
        <OverlayClose onClose={() => setPanel(null)} title={`🧩 ${t('Time')}`} />
        <div className="min-h-0 flex-1"><TeamView run={run} data={data} byId={byId} save={save} /></div>
      </div>
    )
  )
  // As ferramentas (numa linha fixa da tela de baixo, sempre no mesmo lugar). Igual ao app.
  const tools = (
    <>
      <ToolButton icon="🎒" onClick={() => setPanel(panel === 'bag' ? null : 'bag')} active={panel === 'bag'} testid="factory-menu-bag">{t('BOLSA')}</ToolButton>
      <ToolButton icon="🧩" onClick={() => setPanel(panel === 'team' ? null : 'team')} active={panel === 'team'} testid="factory-menu-team">{t('TIME')}</ToolButton>
      <ToolButton icon="🗺️" onClick={() => setPanel(panel === 'region' ? null : 'region')} active={panel === 'region'} testid="factory-menu-region">{t('MAPA')}</ToolButton>
      <ToolButton icon="❓" onClick={() => setPanel(panel === 'help' ? null : 'help')} active={panel === 'help'} testid="factory-menu-help">{t('AJUDA')}</ToolButton>
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
  // Depois do resultado do andar: os golpes novos de quem subiu de nível. Com vaga, aprende sozinho; com 4, pergunta.
  // Os golpes de quem subiu ficam guardados (não mudam mais sozinhos). Igual ao app.
  const afterResult = async () => {
    const moves = await getMoves()
    let next = run
    const queue = []
    for (const l of p.levels ?? []) {
      if (l.friend) continue
      const i = l.index
      const m = next.team[i]
      if (!m) continue
      const form = await learnsetOf(m.id)
      let current = m.moves?.length ? m.moves : await movesFor(m.id, l.from)
      for (const move of movesLearnedBetween(form, l.from, l.to, moves)) {
        if (current.includes(move)) continue
        if (current.length < 4) {
          current = [...current, move]
          queue.push([i, move, true])
        } else queue.push([i, move, false])
      }
      next = { ...next, team: next.team.map((x, k) => (k === i ? { ...x, moves: current } : x)) }
    }
    if (!queue.length) return save({ ...next, pending: { ...p, seen: true } })
    setLearn({ queue, step: 'ask', msg: null, pick: null, moves })
    save(next)
  }
  // O próximo golpe da fila (sem mais nenhum, segue o andar).
  const nextLearn = () => {
    const queue = learn.queue.slice(1)
    if (!queue.length) {
      setLearn(null)
      save({ ...run, pending: { ...p, seen: true } })
    } else setLearn({ ...learn, queue, step: 'ask', msg: null, pick: null })
  }
  // Confirma o golpe tocado na tela dos 5 golpes: esquece ele e aprende o novo (o novo tocado: não aprende).
  const confirmForget = () => {
    const [i, move] = learn.queue[0]
    const m = run.team[i]
    const current = m.moves ?? []
    const nm = name(m.id)
    const mv = prettySlug(move)
    if (learn.pick >= current.length) return setLearn({ ...learn, step: 'ask', pick: null, msg: t('{0} não aprendeu {1}.').replace('{0}', nm).replace('{1}', mv) })
    setLearn({ ...learn, step: 'ask', pick: null, msg: t('1, 2 e... Pronto! {0} esqueceu {1} e aprendeu {2}!').replace('{0}', nm).replace('{1}', prettySlug(current[learn.pick])).replace('{2}', mv) })
    save(learnMove(run, i, move, current, learn.pick))
  }
  const step = stepOf(p)
  // A Enfermeira Joy só na cidade; na rota, quem cura é alguém do caminho (Pokémon Breeder, Doctor...).
  const town = run && inTown(run.scene ?? 'grass')
  const [healerSprite, healerName] = run ? (town ? ['sd-nurse', 'Enfermeira Joy'] : healerOf(run)) : ['sd-nurse', '']
  const nurse = <FarPerson id={healerSprite} trainers={trainers} width={width} />
  let field, text, menu, below = null, wideMenu = false, toolRow = false
  // A Creche (um lugar da cidade, separado do Poké Mart): quem fica e o ovo.
  const daycareView = () => {
      const care = run.daycare
      const steps = care ? Math.max(0, run.floor - care.floor) : 0
      return care ? (
        <div className="space-y-2 p-2" data-testid="daycare">
          <OverlayClose onClose={() => setPanel(null)} title={`🏡 ${t('Creche')}`} />
          <div className="flex items-center gap-2 rounded-xl bg-surface p-2">
            <PokeIcon id={care.mon.id} shiny={Boolean(care.mon.shiny)} className="h-12 w-12" />
            <div className="min-w-0 flex-1 text-sm">
              <p className="font-bold" data-no-translate>{name(care.mon.id)} · Nv. {care.mon.level} → {care.mon.level + steps}</p>
              <p className="text-xs text-muted">{steps >= DAYCARE_EGG ? t('Tem um ovo esperando por você! Ele vai junto e choca depois de {0} vitórias.').replace('{0}', EGG_BATTLES) : t('Mais {0} andares e aparece um ovo.').replace('{0}', DAYCARE_EGG - steps)}</p>
            </div>
            <Button data-testid="daycare-take" disabled={run.team.length >= MAX_TEAM} onClick={() => { setPanel(null); save(takeDaycare(run, data)) }}>{t('BUSCAR')}</Button>
          </div>
          {run.team.length >= MAX_TEAM && <p className="text-xs text-red-600">{t('Time cheio: abra espaço para buscar.')}</p>}
        </div>
      ) : (
        <BwParty title={t('Creche: quem fica? Ganha um nível por andar e, depois de {0} andares, aparece um ovo.').replace('{0}', DAYCARE_EGG)} team={partyOf(run, byId)} testid="daycare"
          disabled={() => run.team.length < 2} onPick={(i) => { setPanel(null); save(leaveDaycare(run, i)) }} onCancel={() => setPanel(null)} />
      )
  }

  if (step === 'result' && learn?.queue?.length) {
    // "Fulano quer aprender X": aprendeu sozinho (tinha vaga), ou a pergunta (SIM abre a tela dos 5 golpes).
    const [i, move, auto] = learn.queue[0]
    const mon = run.team[i]
    const nm = name(mon.id)
    const mv = prettySlug(move)
    const msg = learn.msg ?? (auto ? `✨ ${t('{0} aprendeu {1}!').replace('{0}', nm).replace('{1}', mv)}` : null)
    field = <Field biome={run.scene ?? 'grass'} fieldRef={fieldRef} testid="factory-learn"><FieldMon mon={mon} byId={byId} back scene={run.scene} /></Field>
    text = <p data-testid="factory-learn-text">{msg ?? t('{0} quer aprender {1}, mas já sabe 4 golpes. Esquecer um?').replace('{0}', nm).replace('{1}', mv)}</p>
    const current = mon.moves ?? []
    menu = msg ? (
      <MenuButton onClick={nextLearn} testid="learn-continue">{t('CONTINUAR')}</MenuButton>
    ) : learn.step === 'forget' ? (
      // Na tela dos 5 golpes: confirmar o tocado (ESQUECER ou NÃO APRENDER) e VOLTAR, nos botões de baixo.
      <>
        <MenuButton disabled={learn.pick == null} onClick={confirmForget} testid="forget-confirm">
          {learn.pick == null ? t('Escolha um golpe') : learn.pick >= current.length ? t('NÃO APRENDER') : `${t('ESQUECER')} ${prettySlug(current[learn.pick])}`}
        </MenuButton>
        <MenuButton onClick={() => setLearn({ ...learn, step: 'ask', pick: null })} testid="forget-back">{t('VOLTAR')}</MenuButton>
      </>
    ) : (
      <>
        <MenuButton onClick={() => setLearn({ ...learn, step: 'forget' })} testid="learn-yes">{t('SIM')}</MenuButton>
        <MenuButton onClick={() => setLearn({ ...learn, msg: t('{0} não aprendeu {1}.').replace('{0}', nm).replace('{1}', mv) })} testid="learn-no">{t('NÃO')}</MenuButton>
      </>
    )
    if (learn.step === 'forget' && !msg) {
      below = <ForgetPanel mon={mon} move={move} moves={learn.moves} name={nm} types={data.species[mon.id]?.[4] ?? []} pick={learn.pick} onPick={(k) => setLearn({ ...learn, pick: k })} />
    }
  } else if (step === 'result') {
    const event = p.event
    const here = run.scene ?? 'grass'
    const shown = p.center || p.joy ? nurse : [p.drop, p.reward].filter(Boolean).length ? <img src={itemIcon(p.drop ?? p.reward)} alt="" className="pixelated w-1/2" onError={hide} /> : null
    // A primeira evolução do andar, com a animação dos jogos.
    const evo = p.levels?.find((l) => l.evolved)
    const evoFrom = evo ? preEvolution(data, evo.evolved) : null
    field = (
      <Field biome={here} fieldRef={fieldRef} testid="factory-result">
        {shown && <FarStand scene={here}>{shown}</FarStand>}
        {!shown && event && <FarStand scene={here}><span className="text-7xl">{EVENT_ICON[event.kind] ?? '🎁'}</span></FarStand>}
        {lead && <FieldMon mon={lead} byId={byId} back scene={here} />}
        {evo && evoFrom && <EvolutionFx from={evoFrom} to={evo.evolved} byId={byId} />}
      </Field>
    )
    text = (
      <>
        {evo && evoFrom && <p className="text-sm font-semibold text-amber-600" data-testid="factory-evolved" data-no-translate>✨ {t('{0} evoluiu para {1}!').replace('{0}', name(evoFrom)).replace('{1}', name(evo.evolved))}</p>}
        {p.center ? (
          <p data-testid="factory-center">{town ? `🏥 ${t('Centro Pokémon: o seu time foi curado!')}` : <>⛺ {t('{0} cuidou do seu time: todos curados!').replace('{0}', healerName)}</>}</p>
        ) : event ? (
          <p data-testid="factory-event">{eventText(event)}</p>
        ) : (
          <>
            <p>🏆 {t('Andar vencido!')} +{p.exp} XP · +💰{p.money}</p>
            {p.levels?.map((l, k) => (
              <p key={k} className="text-sm" data-no-translate>{l.friend ? `💞 ${name(l.evolved)}: ${t('evoluiu pela amizade!')}` : `${name(run.team[l.index]?.id)}: Nv. ${l.from} → ${l.to}${l.evolved ? ` · ${t('evoluiu!')}` : ''}`}</p>
            ))}
          </>
        )}
        {p.picked?.map((x, k) => <p key={k} className="text-sm" data-testid="factory-pickup">🎒 {t('{0} achou {1} (Pickup)!').replace('{0}', name(x.id)).replace('{1}', itemName(x.item))}</p>)}
        {p.lost?.map((id) => <p key={id} className="text-sm text-red-600" data-testid="factory-lost">🕯️ {t('Nuzlocke: {0} desmaiou e foi embora.').replace('{0}', name(id))}</p>)}
        {p.joy && <p className="text-sm" data-testid="factory-joy">💗 {town ? t('A Enfermeira Joy apareceu e curou o time todo!') : t('{0} apareceu e curou o time todo!').replace('{0}', healerName)}</p>}
        {[p.drop, p.reward].filter(Boolean).map((id) => <p key={id} className="text-sm" data-testid="factory-drop">🎁 {t('Ganhou {0}!').replace('{0}', itemName(id))}{itemHelp(id) && <span className="block text-xs text-muted">{itemHelp(id)}</span>}</p>)}
        {p.beat && (
          <p className="text-sm italic" data-testid="factory-beat-line">
            💬 <span data-no-translate>{p.beat.name}</span>: {t(p.beat.kind === 'rival' ? RIVAL_BEAT[Math.min(RIVAL_BEAT.length, run.rivalWins ?? 1) - 1] : BEAT_LINES[p.beat.kind] ?? BEAT_LINES.gym)}
          </p>
        )}
        {p.hm && (
          <p className="text-sm text-amber-600" data-testid="factory-hm">
            {HM_INFO[p.hm].icon} {t('Com a insígnia, você ganhou a MO {0}!').replace('{0}', HM_INFO[p.hm].name)} {t(HM_INFO[p.hm].help)}
          </p>
        )}
        {p.mission && (
          <p className="text-sm text-amber-600" data-testid="factory-mission-done">
            📋 {t('Missão cumprida: {0}!').replace('{0}', missionText(p.mission))} +💰{p.mission.money} · 🎁 {itemName(p.mission.item)}
          </p>
        )}
        {p.story && p.story.split('\n\n').map((line, k) => <p key={k} className="text-sm font-semibold" data-testid="factory-story-end">📖 {line}</p>)}
      </>
    )
    menu = <MenuButton onClick={afterResult} testid="factory-continue">{t('CONTINUAR')}</MenuButton>
  } else if (step === 'choice') {
    // Uma escolha na rota: aceitar ou seguir o caminho.
    const choice = p.choice
    const info = CHOICE_INFO[choice.kind]
    const poor = ['help', 'merchant', 'bet'].includes(choice.kind) && run.money < choice.cost
    const decide = (accept) => {
      const next = resolveChoice(run, data, accept)
      if (next.encounter) {
        saveFactory({ ...factoryOf(useStore.getState().league), run: next })
        onBattle(next)
      } else save(next)
    }
    field = (
      <Field biome={run.scene ?? 'grass'} fieldRef={fieldRef} testid="factory-choice">
        {choice.mon ? <FieldMon mon={choice.mon} byId={byId} scene={run.scene} /> : <FarStand scene={run.scene ?? 'grass'}><span className="text-7xl">{info.icon}</span></FarStand>}
        {lead && <FieldMon mon={lead} byId={byId} back scene={run.scene} />}
      </Field>
    )
    text = (
      <>
        <p data-testid={`factory-choice-${choice.kind}`}>{info.icon} {t(info.text).replace('{0}', choice.cost ?? '').replace('{1}', choice.mon ? `${choice.mon.shiny ? '✨ ' : ''}${name(choice.mon.id)}` : '').replace('{2}', choice.item ? itemName(choice.item) : '')}</p>
        {choice.kind === 'secret' && !run.flash && <p className="dlg-sub text-sm">{t('Está escuro lá dentro: sem Flash, pode não achar nada.')}</p>}
        {poor && <p className="text-sm text-red-600">{t('Você não tem dinheiro suficiente.')}</p>}
      </>
    )
    menu = (
      <>
        <MenuButton onClick={() => decide(true)} disabled={busy || poor || (choice.kind === 'follow' && teamDown(run))} testid="choice-yes">{t(info.yes)}</MenuButton>
        <MenuButton onClick={() => decide(false)} disabled={busy} testid="choice-no">{t(info.no)}</MenuButton>
      </>
    )
  } else if (step === 'capture') {
    const mon = p.capture
    const full = run.team.length >= MAX_TEAM
    const dexReward = dexRewardFor(run, mon.id)
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
        {/* Capturado: ele está dentro da Poké Ball (na base dele), não mais no campo. Do ovo da Creche, ele mesmo. */}
        {mon.egg ? <FieldMon mon={mon} byId={byId} scene={run.scene} /> : (
          <FarStand scene={run.scene ?? 'grass'}><img src={spriteUrl(`items/${p.ball ?? 'poke-ball'}.png`)} alt="" className="pixelated w-[22%]" data-testid="captured-ball" /></FarStand>
        )}
        {lead && <FieldMon mon={lead} byId={byId} back scene={run.scene} />}
      </Field>
    )
    text = (
      <>
        <p>{mon.shiny ? '✨ ' : ''}{(mon.egg ? t('O ovo da Creche chocou: é um {0}!') : t('Pegou! {0} foi capturado!')).replace('{0}', name(mon.id))} <span className="dlg-sub">Nv. {mon.level}</span></p>
        {!dexOf(run).includes(mon.id) && (
          <p className="text-sm" data-testid="factory-dex-new">
            📖 {t('Novo na Pokédex da corrida ({0})').replace('{0}', dexOf(run).length + 1)}
            {dexReward && <> · 🎁 {dexReward.count}× {itemName(dexReward.item)} +💰{dexReward.money}</>}
          </p>
        )}
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
      </>
    ) : <MenuButton onClick={() => keep(null)} testid="factory-continue">{t('CONTINUAR')}</MenuButton>
    toolRow = full
  } else if (step === 'cards') {
    field = (
      <Field biome={run.scene ?? 'grass'} fieldRef={fieldRef} testid="factory-cards">
        <div className="absolute inset-0 grid grid-cols-3 items-center gap-2 p-3 sm:gap-4 sm:p-6">
          {p.cards.map((c) => (
            <button key={c} type="button" data-testid={`card-${c}`} onClick={() => save(takeCard(run, c, data))}
              className={`flex h-[85%] cursor-pointer flex-col items-center justify-center gap-1 rounded-xl border-4 p-1 text-center text-[11px] font-black shadow-lg transition hover:-translate-y-1 sm:text-sm ${RELICS[c] ? 'border-violet-900 bg-gradient-to-b from-violet-300 to-fuchsia-100 text-violet-950' : 'border-slate-800 bg-gradient-to-b from-amber-200 to-white text-slate-900'}`}>
              <span className="text-2xl sm:text-4xl">{RELICS[c] ? RELICS[c].icon : '🃏'}</span>
              {RELICS[c] && <span className="text-[10px] tracking-widest uppercase">{t('Relíquia')}</span>}
              {t(cardLabel(c))}
            </button>
          ))}
        </div>
      </Field>
    )
    text = <p>🃏 {t(p.cards.some((c) => RELICS[c]) ? 'Escolha uma carta de bônus (ou a relíquia: muda a regra da corrida)' : 'Escolha uma carta de bônus')}</p>
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
    // O Poké Mart só na cidade; na rota, o vendedor ambulante (vende o mesmo), no próprio lugar.
    const vendor = Boolean(p.mart)
    field = vendor ? (
      // O vendedor aparece no próprio lugar (o cenário não muda e não tem as plataformas da batalha).
      <Field biome={run.scene ?? 'grass'} fieldRef={fieldRef} testid="factory-shop">
        <FarStand scene={run.scene ?? 'grass'} plain><FarPerson id="sd-backpacker" trainers={trainers} width={width} /></FarStand>
        {me && <div className="absolute bottom-[23%] left-[6%] flex"><TrainerSprite trainer={me} height={nearPerson(width)} /></div>}
        <div className="absolute left-3 top-2 rounded-lg bg-white/80 px-2 py-0.5 text-sm font-black text-slate-900">🎒 {t('Vendedor ambulante')}</div>
      </Field>
    ) : (
      <Field biome="city" fieldRef={fieldRef} testid="factory-shop">
        <div className="absolute inset-x-0 bottom-[22%] flex items-end justify-center gap-1">
          <img src={spriteUrl('trainers/sd-clerk.png')} alt="" className="pixelated object-contain object-bottom" style={{ height: width * 0.4 }} />
          <img src={spriteUrl('trainers/sd-clerkf.png')} alt="" className="pixelated object-contain object-bottom" style={{ height: width * 0.4 }} />
        </div>
        <div className="absolute inset-x-0 bottom-0 h-[26%] border-t-[6px] border-amber-400 bg-gradient-to-b from-amber-600 to-amber-800" />
        <div className="absolute left-3 top-2 rounded-lg bg-white/80 px-2 py-0.5 text-sm font-black text-slate-900">🛒 Poké Mart</div>
      </Field>
    )
    text = <p>{vendor ? t('Um vendedor ambulante! Tenho o mesmo que o Poké Mart. Do que você precisa?') : t('Bem-vindo! Do que você precisa?')} <span className="dlg-sub">💰{run.money}</span></p>
    menu = (
      <>
        <MenuButton onClick={() => setPanel(panel === 'buy' ? null : 'buy')} active={panel === 'buy'} testid="factory-menu-buy">{t('COMPRAR')}</MenuButton>
        <MenuButton onClick={() => { setPanel(null); save({ ...run, pending: { ...p, shop: null } }) }} testid="factory-continue">{t('CONTINUAR')}</MenuButton>
      </>
    )
    toolRow = true
    if (panel === 'buy') {
      below = (
        <div className="space-y-2 p-2">
          <OverlayClose onClose={() => setPanel(null)} title={`${vendor ? `🎒 ${t('Vendedor ambulante')}` : '🛒 Poké Mart'} · 💰${run.money}`} />
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
    const pos = routePos(run)
    const down = teamDown(run)
    // Na cidade (o ginásio, o Poké Mart, o Centro, a Creche e o lugar perto dela) ou dentro de um lugar (10 andares e um chefe).
    const town = Boolean(route.town)
    const baseName = t('Base da {0}').replace('{0}', TEAM_NAMES[villainTeam(boss.name)] ?? 'Equipe Rocket')
    const inside = run.dungeon ? (run.dungeon.place === 'base' ? { name: baseName, scene: run.dungeon.scene } : placeInfo(data, run, run.dungeon.place)) : null
    // Saindo de um lugar, você volta para o andar em que entrou (na rota ou na cidade).
    const entered = run.dungeon ? routePos({ ...run, floor: run.dungeon.entry ?? run.dungeon.start }) : pos
    const backTo = entered >= ROUTE_LENGTH ? t('a cidade, no mesmo andar') : t('a rota, no mesmo andar')
    // O nome da rota do jogo (Route 1 · Route 2...).
    const routeName = routeInfo(data, run)?.name
    const meeting = !town && route.options.length === 1 && route.options[0].kind === 'boss'
    // O rival de surpresa no meio da rota.
    const rival = route.options.length === 1 && route.options[0].kind === 'rival' ? rivalBoss(data, run) : null
    const coach = trainers?.find((x) => x.id === (rival ?? boss).trainer) ?? null
    const intro = run.boss.step === 0 && pos === 0 ? storyLine(data, boss.region, 'intro') : ''
    const legend = regionLegend(data, run)
    const clock = clockOf()
    const pickNode = (index) => {
      const next = chooseNode(run, data, index, clockOf())
      if (next === run) return
      saveFactory({ ...factoryOf(useStore.getState().league), run: next })
      if (next.encounter) onBattle(next)
    }
    const fork = !town && route.options.length > 1
    // O líder no ginásio do tipo dele, a Elite Four na Liga, o Campeão na sala dele; rival e vilões na rota (o vilão, na base da equipe).
    const meetScene = town ? 'city' : meeting && CITY_KIND_SET.has(boss.kind) ? bossScene(data, boss, route.biome) : route.biome
    // Sem o Mapa: nada do mapa e, na bifurcação, segue às cegas.
    const hasMap = Boolean(run.townMap) || (hasHm(run, 'flash') && DARK_BIOMES.includes(route.biome))
    const cut = !meeting && !town ? cutPath(run) : null
    // O andar (pequeno, num canto): na rota, até a cidade; num lugar, até o chefe dele.
    const floorTag = inside ? `${Math.min(DUNGEON_LENGTH, dungeonPos(run) + 1)}/${DUNGEON_LENGTH}` : town ? `${Math.min(CITY_LENGTH, pos - ROUTE_LENGTH + 1)}/${CITY_LENGTH}` : `${pos + 1}/${ROUTE_LENGTH}`
    field = fork && hasMap ? (
      <TownMap route={route} pos={pos % ROUTE_LENGTH} from={from} to={to} title={`${boss.region} · ${boss.game}`} me={me} width={width} fieldRef={fieldRef} placeName={(id) => placeInfo(data, run, id).name}
        onPick={busy ? null : pickNode} blocked={(node) => (isBattleNode(node) && down) || nodeBlocked(run, node)} />
    ) : (
      // O líder espera no ginásio da cidade; a Elite Four e o Campeão, na Liga (nunca no meio da rota).
      <Field biome={meetScene} fieldRef={fieldRef} testid="factory-map">
        <div className="absolute left-3 top-2 rounded-lg bg-white/85 px-2 py-0.5 text-xs font-black text-slate-900 sm:text-sm">
          {town ? <span data-no-translate>🏙️ {to}</span>
            : inside ? <>{biome.icon} {t(inside.name)}</>
            : <><span data-no-translate>{boss.region} · {boss.game}</span> · {biome.icon} {routeName ? <span data-no-translate>{routeName} → {to}</span> : t('Rota para {0}').replace('{0}', to)}</>}
        </div>
        {floorTag && <span className="absolute right-3 top-2 rounded bg-slate-900/70 px-1.5 text-[10px] font-black text-white sm:text-xs" data-testid="route-floor">{floorTag}</span>}
        {coach && (meeting || rival) && <FarStand scene={meetScene}><TrainerSprite trainer={coach} height={farPerson(width)} /></FarStand>}
        {town && me && <div className="absolute bottom-[23%] left-[2%] flex"><TrainerSprite trainer={me} height={nearPerson(width)} /></div>}
        {/* Quem vai na frente acompanha você na cidade (como o Pokémon que segue o treinador). */}
        {town && lead && <FieldMon mon={lead} byId={byId} follower scene={run.scene} />}
        {!town && lead && <FieldMon mon={lead} byId={byId} back scene={meetScene} />}
      </Field>
    )
    // As falas (uma por vez, tocando para passar, como nos jogos).
    const lines = [
      intro && `📖 ${intro}`,
      !town && !inside && pos === 0 && !meeting && `🧭 ${t('Você sai de {0} e entra em {1}, rumo a {2}.').replace('{0}', from ?? t('casa')).replace('{1}', t(biome.label)).replace('{2}', to)} ${t(ROUTE_FLAVOR[route.biome] ?? ROUTE_FLAVOR.grass)}`,
      !town && !inside && pos === 0 && !meeting && legend != null && `🌟 ${t(LEGEND_CLUES[target.kind === 'elite' ? LEGEND_CLUES.length - 1 : Math.min(LEGEND_CLUES.length - 2, run.badges ?? 0)])}`,
      inside && dungeonPos(run) === 0 && `🕳️ ${t('Você entrou em {0}: {1} andares, sem desvios, e um chefe no fim. Depois, de volta para {2}.').replace('{0}', t(inside.name)).replace('{1}', DUNGEON_LENGTH).replace('{2}', backTo)}`,
      meeting && boss.kind === 'rival' && `💬 ${boss.name}: ${t(RIVAL_LINES[Math.min(RIVAL_LINES.length - 1, run.rivalWins ?? 0)])}`,
      meeting && boss.kind === 'villain' && `💬 ${boss.name}: ${t(VILLAIN_LINES[(run.floor + run.seed) % VILLAIN_LINES.length])}`,
      meeting && boss.kind === 'villain' && `💬 ${t(VILLAIN_PLANS[villainTeam(boss.name)] ?? VILLAIN_PLANS.rocket)}`,
      meeting && boss.kind === 'gym' && `💬 ${boss.name}: ${t(LEADER_LINES[leaderType(data, boss)] ?? LEADER_LINES.normal)}`,
      meeting && (boss.kind === 'rival' || boss.kind === 'villain') && t('{0} apareceu no caminho!').replace('{0}', boss.name),
      meeting && !(boss.kind === 'rival' || boss.kind === 'villain') && t('O chefe espera'),
      meeting && storyLine(data, boss.region, boss.kind, boss.name),
      rival && `💬 ${rival.name}: ${t(RIVAL_RACE_LINES[(run.rivalRaces ?? 0) % RIVAL_RACE_LINES.length])}`,
      rival && t('{0} apareceu no caminho!').replace('{0}', rival.name),
      route.options.length === 1 && route.options[0].meteor && `☄️ ${t('Uma chuva de meteoros! Algo caiu bem perto daqui...')}`,
      route.options.length === 1 && route.options[0].mythic && `✨ ${t('Uma presença misteriosa... um Pokémon mítico está aqui!')}`,
      town && boss.kind === 'villain' && `💬 ${t('A {0} tomou conta da cidade! O líder do ginásio só volta quando ela for embora.').replace('{0}', TEAM_NAMES[villainTeam(boss.name)] ?? 'Equipe Rocket')}`,
      town && pos === ROUTE_LENGTH && boss.kind !== 'villain' && t('Bem-vindo a {0}! O Poké Mart, o Centro Pokémon e a Creche ficam aqui; o líder espera no último andar da cidade.').replace('{0}', to),
      inside && run.dungeon.cleared && `🌊 ${t('Você venceu o chefe daqui! Dá para seguir mais fundo ou voltar.')}`,
    ].filter(Boolean)
    // A entrada de um lugar: a base vilã e o lugar da cidade (na cidade) ou o lugar no caminho (na rota).
    const placeButton = (node, k) => (
      <MenuButton key={k} testid={`map-node-${k}`} disabled={busy || down} onClick={() => pickNode(k)}
        sub={node.place === 'base' ? t('A equipe vilã está na cidade: {0} andares e o chefe dela no fim.').replace('{0}', DUNGEON_LENGTH)
          : node.deeper ? t('Mais {0} andares e um chefe.').replace('{0}', DUNGEON_LENGTH)
          : town ? t('{0} andares e um chefe; depois volta para a cidade, no mesmo andar.').replace('{0}', DUNGEON_LENGTH)
          : t('{0} andares e um chefe; depois volta para a rota, no mesmo andar.').replace('{0}', DUNGEON_LENGTH)}>
        🕳️ {(BIOME_INFO[node.scene] ?? biome).icon} {node.place === 'base' ? baseName : <span data-no-translate>{placeInfo(data, run, node.place).name}</span>}
      </MenuButton>
    )
    text = (
      <>
        <Dialogue key={`${run.floor}-${run.dungeon?.place ?? ''}-${route.options.map((o) => o.kind).join()}`} lines={lines}
          fallback={town ? null : !fork ? t('O caminho segue.') : hasMap ? t('O caminho se divide: escolha por onde ir') : t('O caminho se divide! Sem o Mapa, você não sabe aonde cada caminho leva.')} />
        {run.mission && run.mission.leg === (run.leg ?? 1) && (
          <p className="text-sm" data-testid="factory-mission">
            📋 {t('Missão')}: {missionText(run.mission)} ({run.mission.done}/{run.mission.need}){run.mission.done >= run.mission.need ? ' ✔' : ''}
          </p>
        )}
        <p className="dlg-sub text-xs" data-testid="factory-clock">
          {t(SEASON_LABEL[clock.season])} · {clock.night ? `🌙 ${t('Noite: mais Fantasma e Sombrio')}` : `🌤️ ${t('Dia')}`} · {t('Chefe em {0}:').replace('{0}', to)} <b data-no-translate>{target.name}</b>
        </p>
        {down && <p className="text-sm text-red-600">{t('O time todo está desmaiado: use um Revive ou desista.')}</p>}
      </>
    )
    wideMenu = true
    menu = (
      <>
        {/* Sem o Mapa: dá para seguir em frente ou pegar outro caminho, sem saber aonde ele leva (a entrada de um lugar dá para ver). */}
        {fork && !hasMap && route.options.map((node, k) => node.kind === 'dungeon' ? placeButton(node, k) : (
          <MenuButton key={k} testid={`map-node-${k}`} disabled={busy || nodeBlocked(run, node) || (isBattleNode(node) && down)} onClick={() => pickNode(k)}
            sub={nodeBlocked(run, node) ? t('Precisa da MO Surf (3ª insígnia).') : k === 0 ? t('Continuar por onde você está') : t('Não dá para saber aonde ele leva (o Mapa mostra)')}>
            {k === 0 ? `➡️ ${t('SEGUIR EM FRENTE')}` : `↗️ ${t('OUTRO CAMINHO')}${route.options.length > 2 ? ` ${k}` : ''}`}
          </MenuButton>
        ))}
        {(hasMap || !fork) && route.options.map((node, k) => {
          if (node.kind === 'dungeon') return placeButton(node, k)
          const info = node.area ? NODE_INFO.area : node.mythic ? NODE_INFO.mythic : node.meteor ? NODE_INFO.meteor : node.legend != null ? LEGEND_INFO : node.cut ? CUT_INFO : NODE_INFO[node.kind]
          const b = node.biome && !node.cut ? BIOME_INFO[node.biome] : null
          const noSurf = nodeBlocked(run, node)
          return (
            <MenuButton key={k} testid={`map-node-${k}`} disabled={busy || (isBattleNode(node) && down) || noSurf} onClick={() => pickNode(k)}
              sub={noSurf ? t('Precisa da MO Surf (3ª insígnia).') : node.kind === 'boss' ? `${bossKindLabel(boss.kind)}${CITY_KIND_SET.has(boss.kind) ? ` · ${to}` : ''}` : node.kind === 'dboss' ? (inside ? t('O chefe do lugar: vencendo, volta para {0}.').replace('{0}', backTo) : t('O chefe da rota: vencendo, você chega em {0}.').replace('{0}', to)) : t(info.help)}>
              {route.options.length === 1 && !['boss', 'rival', 'dboss'].includes(node.kind) ? `${t('SEGUIR')}: ` : ''}{node.biome === 'underwater' && route.biome !== 'underwater' ? `🤿 ${t('MERGULHAR')}: ` : ''}{town && node.kind === 'boss' ? '🏟️' : b ? b.icon : info.icon} {node.kind === 'boss' || (node.kind === 'rival' && rival) ? <span data-no-translate>{(node.kind === 'rival' ? rival : boss).name}</span> : t(info.label)}{b ? ` · ${t(b.label)}` : ''}
            </MenuButton>
          )
        })}
        {/* Na cidade: o Poké Mart, o Centro Pokémon e a Creche (cada um no seu lugar). */}
        {town && (
          <div className="grid grid-cols-3 gap-1">
            <MenuButton testid="town-mart" disabled={busy} onClick={() => save(townShop(run))}>🛒 Poké Mart</MenuButton>
            <MenuButton testid="town-center" disabled={busy} onClick={() => save(townCenter(run))}>🏥 {t('CENTRO')}</MenuButton>
            <MenuButton testid="town-daycare" disabled={busy} onClick={() => setPanel(panel === 'daycare' ? null : 'daycare')} active={panel === 'daycare'}>🏡 {t('CRECHE')}</MenuButton>
          </div>
        )}
        {cut && hasMap && (
          <MenuButton testid="factory-cut" disabled={busy} onClick={() => save(cut)} sub={t(HM_INFO.cut.help)}>
            ✂️ {t('USAR {0}').replace('{0}', 'Cut')}
          </MenuButton>
        )}
        {(run.rerolls ?? 0) > 0 && !meeting && !town && hasMap && (
          <MenuButton testid="factory-reroll" disabled={busy} onClick={() => { const next = rerollRoute(run, data); if (next) save(next) }} sub={t('Restam {0} nesta corrida').replace('{0}', run.rerolls)}>
            🎲 {t('SORTEAR O CAMINHO DE NOVO')}
          </MenuButton>
        )}
      </>
    )
    toolRow = true
    if (town && panel === 'daycare') below = daycareView()
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
      <BattleFrame field={field} run={run} byId={byId} data={data} frame={factory.frame} wideMenu={wideMenu} menu={menu} tools={toolRow ? tools : null} panel={below || extras || null}
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

/** O que cada item segurado faz na batalha (como nos jogos). */
const HELD_EFFECT = {
  'choice-band': 'Ataque ×1,5, mas só usa o primeiro golpe escolhido até trocar',
  'choice-specs': 'Ataque Especial ×1,5, mas só usa o primeiro golpe escolhido até trocar',
  'choice-scarf': 'Velocidade ×1,5, mas só usa o primeiro golpe escolhido até trocar',
  'life-orb': 'Golpes 30% mais fortes; perde 10% do HP a cada ataque',
  'expert-belt': 'Golpes super efetivos 20% mais fortes',
  'muscle-band': 'Golpes físicos 10% mais fortes',
  'wise-glasses': 'Golpes especiais 10% mais fortes',
  'leftovers': 'Recupera 1/16 do HP no fim de cada turno',
  'sitrus-berry': 'Com metade do HP ou menos, come e recupera 1/4 do HP',
  'assault-vest': 'Defesa Especial ×1,5, mas só pode usar golpes de ataque',
  'rocky-helmet': 'Quem acerta um golpe de contato perde 1/6 do HP',
  'eviolite': 'Defesa e Defesa Especial ×1,5 se ele ainda pode evoluir',
  'focus-sash': 'Com o HP cheio, aguenta com 1 de HP um golpe que o derrubaria',
  'quick-claw': '20% de chance de agir primeiro no turno',
  'shell-bell': 'Recupera 1/8 do dano que causa',
  'black-sludge': 'Tipo Veneno recupera 1/16 do HP por turno; os outros perdem 1/8',
  'weakness-policy': 'Levou um golpe super efetivo: Ataque e Ataque Especial +2',
  'lum-berry': 'Cura qualquer problema de status (uma vez)',
  'scope-lens': 'Mais chance de acerto crítico (+1 nível)',
  'bright-powder': 'Golpes do adversário erram 10% mais',
  'air-balloon': 'Flutua: imune a golpes de Terra até levar um golpe',
  'heavy-duty-boots': 'Não sofre dano das armadilhas do campo (Stealth Rock, Spikes...)',
  'kings-rock': 'Golpes de dano têm 10% de chance de fazer o adversário recuar',
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
    const extra = t('Segura o item; se já tem um, vira extra ({0})').replace('{0}', boost)
    return HELD_EFFECT[id] ? `${t(HELD_EFFECT[id])}. ${extra}` : extra
  }
  // Mega Pedras e Cristais Z (drops dos chefes).
  if (/-z$/.test(id)) return t('Cristal Z: um golpe do tipo dele vira Movimento Z (uma vez por batalha)')
  if (/ite(-[xy])?$/.test(id) && id !== 'eviolite') return t('Mega Pedra: o Pokémon dela megaevolui (uma vez por batalha)')
  return ''
}
