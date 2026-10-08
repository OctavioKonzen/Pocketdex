// As telas da Battle Factory (lib/factoryRun.js): o começo (o inicial grátis,
// comprar Pokémon e shiny com as moedas, continuar a corrida, a história da
// região) e o que vem depois de vencer um andar (XP, Enfermeira Joy, captura
// com Poké Ball, drops, carta de bônus, loja, Bolsa, itens, golpes e
// mecânicas). Igual ao app (lib/screens/factory_panels.dart).

import { useEffect, useMemo, useState } from 'react'
import PokeIcon from './PokeIcon'
import { Button, SearchInput } from './ui'
import { getFactoryData, spriteUrl } from '../lib/data'
import { learnsetOf, movesFor } from '../lib/factoryBattle'
import {
  BAG_ITEMS, BOSS_EVERY, bossOf, BOTTLE_CAP_IVS, buyItem, buyPokemon, canEvolveWith, capture, CARDS, claimStarter, endRun, equipFromStash, factoryOf,
  freePick, gimmickOf, gimmicksOf, HEAL_SHARE, HELD_BOOST, MAX_TEAM, nextFloor, pokemonPrice, setGimmick, setMainItem, shinyPrice, shopOwned, shopPrice,
  skipCapture, startersOf, startRun, storyLine, takeCard, teachMove, teamDown, applyBagItem, unlockShiny, VITAMIN_EVS, VITAMINS, buyShiny,
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

/**
 * O time: o item principal de cada um (efeito de verdade) e os extras
 * (porcentagem bem menor), a mecânica (Mega, Z, Dynamax, Tera), ensinar
 * golpes (TM, Move Tutor, Move Reminder) e os itens guardados (drops).
 */
function TeamPanel({ run, data, byId, save }) {
  const [teaching, setTeaching] = useState(null)
  const [stashItem, setStashItem] = useState(null)
  const canTeach = Object.values(run.tms ?? {}).some((n) => n > 0) || Object.values(run.tokens ?? {}).some((n) => n > 0)
  return (
    <details className="rounded-xl bg-bg p-2" data-testid="factory-items">
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
  const [lucky, setLucky] = useState(null)
  const run = factory.run
  const save = (next) => next && saveFactory({ ...factory, run: next })

  const shopList = useMemo(() => {
    if (!data || !byId) return []
    const q = query.trim().toLowerCase()
    return Object.entries(data.species)
      .map(([id, [, bst]]) => ({ id: Number(id), bst, price: pokemonPrice(bst), name: byId.get(Number(id))?.name ?? '' }))
      .filter((p) => !factory.owned.includes(p.id) && (!q || p.name.includes(q)))
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
          {t('Um roguelike sem fim com a história de cada região: escolha um inicial no nível 5 e suba andares contra Pokémon selvagens (capture com Poké Ball: você começa com 5) e treinadores. A cada 10 andares vem um chefe da história: líderes de ginásio, rival e vilões (com times cada vez maiores), a Elite Four e o Campeão; nos andares 5, 15, 25... pode aparecer uma Mega, um Gigantamax ou um lendário. Acabou a história, começa a de outra região. O time não é curado entre os andares (só com a Bolsa, a loja ou, com 5% de chance, a Enfermeira Joy). Sem limite de nível, IVs, EVs ou itens; shiny é 1 em 4096. Perdeu: a pontuação vira moedas para comprar Pokémon e começar com eles.')}
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
          <StoryPanel run={run} data={data} />
          <NextBoss run={run} data={data} />
          <div className="flex flex-wrap gap-1">{run.team.map((m, i) => <MonChip key={i} mon={m} byId={byId} />)}</div>
          {run.cards.length > 0 && <p className="text-xs text-muted">{t('Cartas')}: {run.cards.map((c) => t(CARDS[c].label)).join(' · ')}</p>}
          {!run.pending && <BagPanel run={run} byId={byId} save={save} />}
          {!run.pending && <TeamPanel run={run} data={data} byId={byId} save={save} />}
          {down && !run.pending && <p className="text-sm font-bold text-red-500">{t('O time todo está desmaiado: use um Revive ou desista.')}</p>}
          <div className="flex flex-wrap gap-2">
            <Button data-testid="factory-fight" disabled={busy || Boolean(run.pending) || down} onClick={() => onBattle(run)}>⚔️ {t('Lutar no andar {0}').replace('{0}', run.floor)}</Button>
            <Button color="#64748b" onClick={() => saveFactory(endRun(factory, run))}>{t('Desistir (recebe as moedas)')}</Button>
          </div>
          {run.pending && <FactoryAfter run={run} data={data} onNext={onBattle} />}
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
        <p className="my-2 text-xs text-muted">{t('Os mais fortes custam mais. Comprado, ele aparece entre os iniciais (sempre no nível 5). Tem 1 chance em 4096 de vir shiny.')}</p>
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
      {p.drop && (
        <p className="flex items-center gap-2 rounded-xl bg-emerald-500/15 p-2 text-sm font-bold" data-testid="factory-drop">
          <img src={itemIcon(p.drop)} alt="" className="pixelated h-8 w-8" onError={hide} />
          🎁 {t('Ganhou {0}! (está nos itens guardados)').replace('{0}', itemName(p.drop))}
        </p>
      )}
      {p.story && (
        <div className="space-y-1 rounded-xl bg-indigo-500/10 p-2 text-sm" data-testid="factory-story-end">
          {p.story.split('\n\n').map((line, k) => <p key={k}>📖 {line}</p>)}
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
                    <img src={itemIcon(id)} alt="" className="pixelated h-8 w-8" onError={hide} />
                    <div className="min-w-0 flex-1">
                      <p className="font-bold" data-no-translate>{itemName(id)}</p>
                      <p className="text-xs text-muted">{shopOwned(run, id) ? t('Você já tem') : itemHelp(id)}</p>
                    </div>
                    <Button data-testid={`buy-${id}`}
                      disabled={run.money < shopPrice(run, id) || shopOwned(run, id) || (id.startsWith('evo:') && !canEvolveWith(data, run.team[Math.min(target, run.team.length - 1)], id.slice(4)).length)}
                      onClick={() => save(buyItem(run, id, Math.min(target, run.team.length - 1), data))}>
                      💰{shopPrice(run, id)}
                    </Button>
                  </div>
                ))}
              </div>
            </div>
          )}
          <BagPanel run={run} byId={byId} save={save} />
          <TeamPanel run={run} data={data} byId={byId} save={save} />
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
  if (id.startsWith('tm:')) return t('Ensina o golpe a quem aprende por TM (uma vez)')
  if (id.startsWith('evo:')) return t('Evolui na hora quem evolui com ela (escolha acima)')
  if (id === 'move-tutor') return t('Ensina um golpe de tutor ou de ovo (uma vez)')
  if (id === 'move-reminder') return t('Lembra um golpe do nível (uma vez)')
  if (id === 'dynamax-band') return t('Libera o Dynamax (e o Gigantamax) para o time')
  if (id === 'tera-orb') return t('Libera a Terastalização para o time')
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
