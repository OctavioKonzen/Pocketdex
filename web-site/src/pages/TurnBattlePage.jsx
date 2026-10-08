import {simulatorDispose} from '../lib/battleSimulator'
// Batalha por turnos (como nos jogos de GBA), igual ao app
// (turn_battle_screen.dart): seu time contra o time de um amigo (ou um time
// aleatório), com o computador jogando pelo outro lado. O motor fica em
// lib/turnBattle.js e os Pokémon são montados em lib/battleSetup.js.

import { forwardRef, useEffect, useMemo, useRef, useState } from 'react'
import { Link, useLocation } from 'react-router-dom'
import PokeIcon from '../components/PokeIcon'
import { Button, Empty, Icon, Modal, PageHeader, TypeBadge } from '../components/ui'
import { teamsOf, useAuth } from '../lib/auth'
import { battleHitter, battleMons, leaderTeam, randomTeam } from '../lib/battleSetup'
import { friendsOnly, useFriends } from '../lib/friends'
import { getGymLeaders, getMoveAnims, getTypes, shinyPath, spriteUrl } from '../lib/data'
import { addHallOfFame, badgesNeeded, badgesOf, leagueOpen, leagueOrder, musicOf, regionGyms, regionOf, streakResult, winBadge } from '../lib/gymChallenge'
import { t } from '../lib/i18n'
import { seededRandom } from '../lib/league'
import { ALL_TYPES, damageTaken, typeColor } from '../lib/pokemon'
import { usePokemonIndex } from '../lib/pokemonIndex'
import { useStore } from '../lib/store'
import { teamMembers } from '../lib/teamBattle'
import { fxPlan, moveAnim, SELF_KINDS } from '../lib/moveAnim'
import { active, damageRange, fieldConditions, monDetails, lockedMove, canGimmick, canUseItem, effectLabel, forfeit, HEAL_SHARE, ITEMS, lineOf, MAX_MOVES, maxPower, moveEffect, newBattle, playTurn, replace, startBattle, STAT_NAMES, switchMatchup, usableMoves, weaknesses, Z_MOVES, zPower } from '../lib/turnBattle'
import Sprite from '../components/Sprite'
import { TrainerBack, TrainerSprite } from '../components/Trainer'
import { randomTrainer, useMyTrainer, useTrainers } from '../lib/trainers'
import { battleRecord } from '../lib/battleLog'
import { playSound, soundOf, startMusic, stopMusic } from '../lib/battleSound'
import {simulatorTargets} from '../lib/battleSimulator'
import {newPartyBattle, playPartyTurn, describeEvents} from '../lib/partyBattle'
import { FactoryAfter, FactoryHub, saveFactory } from '../components/FactoryPanels'
import { factoryAfter, factoryBattle, factoryFoe } from '../lib/factoryBattle'
import { endRun, factoryOf, winFloor } from '../lib/factoryRun'
import { getFactoryData } from '../lib/data'

const CARD = 'rounded-2xl bg-card p-5 shadow'
const SELECT = 'w-full rounded-xl bg-surface px-3 py-2.5 outline-none focus:ring-2 focus:ring-sky-400'
const RANDOM = '__random__'
// Adversário 'gym:<id>': um líder, Elite Four ou campeão (gym_leaders.json).
const GYM = 'gym:'
// Torre (sequência de vitórias com o seu time, lib/gymChallenge.js) e Battle Factory
// (subir andares com um inicial, lib/factoryRun.js).
const TOWER = '__tower__'
const FACTORY = '__factory__'
/** Na sequência, a partir da 4ª batalha o computador usa sets competitivos. */
const streakDifficulty = (wins, difficulty) => (wins >= 3 ? 'hard' : difficulty)
const KIND_LABEL = { gym: 'Líder de Ginásio', elite: 'Elite Four', champion: 'Campeão', kahuna: 'Kahuna' }
const STEP_MS = 1100

const STAT_LABELS = new Set(Object.values(STAT_NAMES))
const format = (event) => {
  const [line, args] = lineOf(event)
  // Nomes dos atributos (Ataque, Defesa...) também são traduzidos.
  return args.reduce((text, arg, i) => text.replace(`{${i}}`, STAT_LABELS.has(arg) ? t(arg) : arg), t(line))
}

function TeamLine({ team }) {
  return (
    <div className="flex items-center gap-1">
      {teamMembers(team).map((m, i) => (
        <PokeIcon key={i} id={m.id} shiny={Boolean(m.set?.shiny)} className="h-9 w-9" />
      ))}
    </div>
  )
}

/** Escolher o seu time e o do adversário. */
/** O líder escolhido: o treinador e o time (todos no nível 50, já evoluídos). */
function LeaderCard({ leader }) {
  const trainers = useTrainers()
  const trainer = trainers?.find((x) => x.id === leader.trainer)
  return (
    <div className="flex items-center gap-3 rounded-2xl bg-bg p-3" data-testid="leader-card">
      {trainer && <TrainerSprite trainer={trainer} box={84} />}
      <div className="min-w-0">
        <p className="font-black" data-no-translate>{leader.name}</p>
        <p className="text-xs text-muted">{t(KIND_LABEL[leader.kind])}{leader.type ? ` · ` : ''}{leader.type && <TypeBadge type={leader.type} small />}</p>
        <div className="mt-1 flex flex-wrap gap-1">
          {leader.team.map((id, i) => (
            <PokeIcon key={i} id={id} className="h-10 w-10" />
          ))}
        </div>
        <p className="text-[11px] text-muted">Time original, já evoluído, todos no nível 50.</p>
      </div>
    </div>
  )
}

/** Torre de Batalha: como funciona e o seu recorde. */
function StreakCard({ kind }) {
  const best = useStore((s) => s.league?.[kind]?.best ?? 0)
  return (
    <div className="rounded-2xl bg-bg p-3 text-sm" data-testid="streak-card">
      <p className="font-black">{`🗼 ${t('Torre de Batalha')}`}</p>
      <p className="text-muted">
        {t('Seu time contra adversários aleatórios em sequência; a partir da 4ª vitória eles usam sets competitivos. Perdeu, a sequência acaba.')}
      </p>
      <p className="mt-1 font-bold">{t('Recorde: {0} vitórias seguidas').replace('{0}', best)}</p>
    </div>
  )
}

/** A região do líder: as insígnias e a Liga (liberada com as insígnias). */
function RegionProgress({ region, busy, ready, onLeague }) {
  const league = useStore((s) => s.league)
  const have = badgesOf(league, region)
  const open = leagueOpen(league, region)
  const order = leagueOrder(region)
  const halls = (league?.hall ?? []).filter((h) => h.region === region.region).length
  return (
    <div className="space-y-2 rounded-2xl bg-bg p-3" data-testid="region-progress">
      <p className="text-sm font-bold">
        {t('Insígnias de {0}').replace('{0}', region.region)}: {have.length}/{badgesNeeded(region)}
        {halls > 0 && <span className="ml-2 text-amber-500">🏆 ×{halls}</span>}
      </p>
      <div className="flex flex-wrap gap-1.5">
        {regionGyms(region).map((l) => (
          <span
            key={l.id}
            title={l.name}
            data-badge={have.includes(l.id) ? 'on' : 'off'}
            className="grid h-7 w-7 place-items-center rounded-full text-[10px] font-black text-white"
            style={{ background: have.includes(l.id) ? typeColor(l.type) : '#64748b55', boxShadow: have.includes(l.id) ? '0 0 0 2px #fbbf24' : 'none' }}
          >
            {have.includes(l.id) ? '★' : ''}
          </span>
        ))}
      </div>
      <Button color="linear-gradient(90deg,#F59E0B,#DC2626)" disabled={!open || busy || !ready || !order.length} onClick={() => onLeague(order[0], region)}>
        🏆 {t('Desafiar a Liga de {0}').replace('{0}', region.region)}
      </Button>
      <p className="text-xs text-muted">
        {open
          ? t('Elite Four e Campeão em sequência ({0} batalhas). Perdeu, recomeça.').replace('{0}', order.length)
          : t('Vença os líderes de ginásio para ganhar as insígnias e liberar a Liga.')}
      </p>
    </div>
  )
}

function Setup({ onStart, onFactory }) {
  const teams = useStore((s) => s.teams)
  const list = useFriends((s) => s.list)
  const friends = useMemo(() => friendsOnly(list), [list])
  const myTeams = teams.filter((x) => teamMembers(x).length)
  const [mine, setMine] = useState(RANDOM)
  const [friend, setFriend] = useState(RANDOM)
  // A página troca o texto de cima: na Battle Factory não há nível máximo.
  useEffect(() => onFactory?.(friend === FACTORY), [friend, onFactory])
  const [friendTeams, setFriendTeams] = useState([])
  const [theirs, setTheirs] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [count, setCount] = useState(1)
  const [difficulty, setDifficulty] = useState('normal')
  const [npcPartner, setNpcPartner] = useState(false)
  // Prévia dos times (como no Showdown): os dois times e você escolhe quem começa.
  const [preview, setPreview] = useState(null) // {a, b, random, foeName, foeTrainer}
  const [regions, setRegions] = useState([])
  useEffect(() => {
    getGymLeaders().then(setRegions).catch(() => setRegions([]))
  }, [])
  const streak = friend === TOWER ? 'tower' : null
  const leader = friend.startsWith(GYM) ? regions.flatMap((r) => r.leaders).find((l) => l.id === friend.slice(GYM.length)) : null

  const pickFriend = (uid) => {
    setFriend(uid)
    setTheirs('')
    setFriendTeams(null)
    if (uid === RANDOM || uid === TOWER || uid === FACTORY || uid.startsWith(GYM)) setFriendTeams([])
    else teamsOf(uid).then((x) => setFriendTeams(x.filter((y) => teamMembers(y).length))).catch(() => setFriendTeams([]))
  }
  const myTeam = myTeams.find((x) => x.id === mine)
  const theirTeam = friendTeams?.find((x) => x.id === theirs)
  const ready = (mine === RANDOM || myTeam && teamMembers(myTeam).length >= (npcPartner ? 1 : count)) && (friend === RANDOM || streak || leader || theirTeam && teamMembers(theirTeam).length >= count)
  // pick: o líder (ou null); challenge: {kind: 'gym' | 'league', ...} para a jornada (lib/gymChallenge.js).
  const start = async (pick = leader, challenge = pick ? { kind: 'gym', leader: pick.id, difficulty } : streak ? { kind: streak, wins: 0, difficulty } : null) => {
    setBusy(true)
    setError('')
    try {
    const seed = Math.floor(Math.random() * 2 ** 31)
    const random = seededRandom(seed)
    const foeName = pick ? pick.name : friend === RANDOM ? '' : friends.find((f) => f.uid === friend)?.name ?? ''
    const foeTrainer = pick?.trainer ?? null
    // Torre: o seu time contra um aleatório.
    const ma = mine === RANDOM ? await randomTeam(random, difficulty) : teamMembers(myTeam)
    const mb = pick ? await leaderTeam(pick, random, difficulty) : friend === RANDOM || streak ? await randomTeam(random, difficulty) : teamMembers(theirTeam)
    if (streak) useStore.getState().updateLeague((l) => ({ ...l, [streak]: { ...l[streak], streak: 0 } }))
    const [a, b] = await Promise.all([battleMons(ma), battleMons(mb)])
    if (a.length && b.length) {
      if (count === 1 || challenge?.kind === 'league' || streak) setPreview({ a, b, ma: ma.slice(0, a.length), mb: mb.slice(0, b.length), random, foeName, foeTrainer, challenge })
      else {
        const rosters = {me:a,npc3:b}
        const own = Array.from({length:count},(_,i) => i && npcPartner ? `npc${i}` : 'me')
        for (const uid of own.filter(x => x !== 'me')) rosters[uid] = await battleMons(await randomTeam(random, difficulty))
        onStart(newPartyBattle(rosters,[...own,...Array(count).fill('npc3')],count,random),foeName,foeTrainer)
      }
    }
    } catch(e) {setError(e.message || 'Não foi possível iniciar a batalha. Tente novamente.')}
    finally {setBusy(false)}
  }

  // Battle Factory: a batalha do andar da corrida.
  const factoryFloor = async (run) => {
    setBusy(true)
    setError('')
    try {
      const battle = await factoryBattle(run)
      const foe = factoryFoe(run)
      onStart(battle, foe.foeName, foe.foeTrainer, foe.challenge)
    } catch (e) {
      setError(e.message || 'Não foi possível iniciar a batalha. Tente novamente.')
    } finally {
      setBusy(false)
    }
  }

  if (preview) {
    const lead = (i) => {
      const first = (list) => [list[i], ...list.filter((_, j) => j !== i)]
      setPreview(null)
      // A batalha com a sua própria semente: o replay refaz tudo igual (lib/battleLog.js).
      const seed = Math.floor(preview.random() * 2 ** 31)
      const battle = newBattle(first(preview.a), preview.b, seededRandom(seed), { ai: difficulty === 'easy' ? 'easy' : 'normal', seed })
      battle.members = { mine: first(preview.ma), theirs: preview.mb }
      onStart(battle, preview.foeName, preview.foeTrainer, preview.challenge)
    }
    return (
      <section className={`${CARD} space-y-4`} data-testid="team-preview">
        <h2 className="text-lg font-black">Prévia dos times</h2>
        <div>
          <p className="mb-2 text-sm font-semibold text-muted">{preview.foeName ? t('Time de {0}').replace('{0}', preview.foeName) : t('Time do adversário')}</p>
          <div className="flex flex-wrap gap-2">
            {preview.b.map((m, i) => (
              <span key={i} className="flex flex-col items-center rounded-xl bg-bg p-1.5" title={m.name}>
                <PokeIcon id={m.id} shiny={m.shiny} className="h-12 w-12" />
                <span className="text-[11px] font-bold" data-no-translate>{m.name}</span>
              </span>
            ))}
          </div>
        </div>
        <div>
          <p className="mb-2 text-sm font-semibold text-muted">Escolha quem começa</p>
          <div className="grid grid-cols-3 gap-2 sm:grid-cols-6">
            {preview.a.map((m, i) => (
              <button
                key={i}
                type="button"
                onClick={() => lead(i)}
                data-testid={`lead-${i}`}
                className="flex cursor-pointer flex-col items-center rounded-xl bg-bg p-2 ring-2 ring-transparent transition hover:ring-red-500"
              >
                <PokeIcon id={m.id} shiny={m.shiny} className="h-14 w-14" />
                <span className="text-xs font-bold" data-no-translate>{m.name}</span>
                <span className="mt-1 flex flex-wrap justify-center gap-0.5">{m.types.map((type) => <TypeBadge key={type} type={type} small />)}</span>
              </button>
            ))}
          </div>
        </div>
        <Button color="#64748b" onClick={() => setPreview(null)}>Voltar</Button>
      </section>
    )
  }

  return (
    <section className={`${CARD} space-y-4`}>
      {error && <p role="alert" className="text-red-400">{error}</p>}
      {friend !== FACTORY && <label className="block space-y-1.5"><span>Formato</span><select aria-label="Formato" className={SELECT} value={count} onChange={e=>setCount(Number(e.target.value))}>
        <option value={1}>Individual</option><option value={2}>Dupla</option><option value={3}>Tripla</option>
      </select></label>}
      {count > 1 && friend !== FACTORY && <label className="flex gap-2"><input type="checkbox" checked={npcPartner} onChange={e=>setNpcPartner(e.target.checked)} />Jogar com parceiros NPC (desmarcado: você controla todos)</label>}
      {friend !== FACTORY && (
        <label className="block space-y-1.5">
          <span className="text-sm font-semibold text-muted">Seu time</span>
          <select aria-label="Seu time" value={mine} onChange={(e) => setMine(e.target.value)} className={SELECT}>
            <option value={RANDOM}>🎲 Time aleatório</option>
            {myTeams.map((x) => (
              <option key={x.id} value={x.id}>
                {x.name}
              </option>
            ))}
          </select>
          {myTeam && <TeamLine team={myTeam} />}
        </label>
      )}
      <label className="block space-y-1.5">
        <span className="text-sm font-semibold text-muted">Adversário</span>
        <select aria-label="Adversário" value={friend} onChange={(e) => pickFriend(e.target.value)} className={SELECT} data-no-translate>
          <option value={RANDOM}>{t('🎲 Time aleatório')}</option>
          <option value={TOWER}>{`🗼 ${t('Torre de Batalha')}`}</option>
          <option value={FACTORY}>{`🏭 ${t('Battle Factory')}`}</option>
          {friends.length > 0 && (
            <optgroup label={t('Amigos')}>
              {friends.map((f) => (
                <option key={f.uid} value={f.uid}>
                  {f.name}
                </option>
              ))}
            </optgroup>
          )}
          {regions.map((r) => (
            <optgroup key={r.region} label={`${t('Líderes e campeões')} · ${r.region}`}>
              {r.leaders.map((l) => (
                <option key={l.id} value={GYM + l.id}>
                  {`${l.name} · ${t(KIND_LABEL[l.kind])}${l.type ? ` (${l.type})` : ''}`}
                </option>
              ))}
            </optgroup>
          ))}
        </select>
      </label>
      {friend === FACTORY && <FactoryHub onBattle={factoryFloor} busy={busy} />}
      {leader && <LeaderCard leader={leader} />}
      {streak && <StreakCard kind={streak} />}
      {leader && regionOf(regions, leader.id) && (
        <RegionProgress region={regionOf(regions, leader.id)} busy={busy} ready={mine === RANDOM || Boolean(myTeam)} onLeague={(first, region) => start(first, { kind: 'league', region: region.region, step: 0, difficulty })} />
      )}
      {(friend === RANDOM || streak || leader || npcPartner) && <label className="block space-y-1.5"><span>Dificuldade dos NPCs</span><select aria-label="Dificuldade dos NPCs" className={SELECT} value={difficulty} onChange={e=>setDifficulty(e.target.value)}><option value="easy">Fácil · ataca ao acaso, sem trocas nem itens</option><option value="normal">Normal · IVs e EVs aleatórios</option><option value="hard">Difícil · sets competitivos</option></select></label>}
      {friend !== RANDOM && friend !== FACTORY && !leader && !streak &&
        (friendTeams === null ? (
          <p className="text-sm text-muted">...</p>
        ) : !friendTeams.length ? (
          <p className="text-sm text-muted">Esse amigo ainda não montou nenhum time.</p>
        ) : (
          <label className="block space-y-1.5">
            <span className="text-sm font-semibold text-muted">Time do amigo</span>
            <select aria-label="Time do amigo" value={theirs} onChange={(e) => setTheirs(e.target.value)} className={SELECT}>
              <option value="">Escolha…</option>
              {friendTeams.map((x) => (
                <option key={x.id} value={x.id}>
                  {x.name}
                </option>
              ))}
            </select>
            {theirTeam && <TeamLine team={theirTeam} />}
          </label>
        ))}
      {friend !== FACTORY && (
        <>
          <p className="text-xs text-muted">
            O computador joga pelo adversário. Golpes com PP, precisão, prioridade, crítico, status, mudanças de atributo e clima.
          </p>
          <Button color="linear-gradient(90deg,#DC2626,#9333EA)" className="w-full" disabled={busy || !ready} onClick={() => start()}>
            {busy ? 'Preparando...' : '⚔️ Começar batalha'}
          </Button>
        </>
      )}
    </section>
  )
}

/** Depois do andar: o painel da corrida (se ainda há algo para escolher). */
function FactoryAfterBattle({ onNext }) {
  const run = useStore((s) => factoryOf(s.league).run)
  const [data, setData] = useState(null)
  useEffect(() => {
    getFactoryData().then(setData)
  }, [])
  if (!run?.pending || !data) return null
  return <FactoryAfter run={run} data={data} onNext={onNext} />
}

function HpBar({ hp, max }) {
  const pct = Math.max(0, Math.min(100, (hp / max) * 100))
  const color = pct > 50 ? '#22c55e' : pct > 20 ? '#eab308' : '#ef4444'
  return (
    <div className="flex items-center gap-1.5">
      <span className="text-[10px] font-black text-amber-600">HP</span>
      <div className="h-2 flex-1 overflow-hidden rounded-sm border border-slate-700 bg-slate-700">
        <div className="h-full rounded-full transition-[width] duration-700 ease-out" style={{ width: `${pct}%`, background: color }} />
      </div>
    </div>
  )
}

/** Selo do status, como no Showdown. */
/** Selo dos estágios de atributo (Swords Dance: Atq +2, +4... até +6). */
const BOOST_SHORT = { atk: 'Atq', def: 'Def', spa: 'AtE', spd: 'DfE', spe: 'Vel', accuracy: 'Pre', evasion: 'Eva' }
/** Quanto o texto do turno muda o estágio (statUp2 = +2...). */
const BOOST_TEXT = { statUp: 1, statUp2: 2, statUp3: 3, statDown: -1, statDown2: -2, statDown3: -3 }
const boostsOf = (mon) => ({ ...(mon.boosts ?? {}) })

function BoostTags({ boosts }) {
  const list = Object.entries(boosts ?? {}).filter(([k, v]) => v && BOOST_SHORT[k])
  if (!list.length) return null
  return (
    <div className="mt-0.5 flex flex-wrap justify-end gap-0.5" data-testid="boost-tags">
      {list.map(([k, v]) => (
        <span key={k} className={`rounded px-1 text-[10px] font-black text-white ${v > 0 ? 'bg-emerald-600' : 'bg-rose-600'}`}>
          {`${t(BOOST_SHORT[k])} ${v > 0 ? '+' : '−'}${Math.abs(v)}`}
        </span>
      ))}
    </div>
  )
}

const STATUS_BADGE = { brn: '#EE8130', par: '#C9A400', psn: '#A33EA1', tox: '#7B2E7A', slp: '#78716C', frz: '#4FB3D9' }

/** Armadilhas, telas e efeitos do campo (como no Showdown), em cima do texto. */
function FieldBar({ battle }) {
  const [mine, theirs, all] = fieldConditions(battle)
  if (!mine.length && !theirs.length && !all.length) return null
  const chips = (list, color) => list.map((x) => <span key={x} className="rounded-full px-2 py-0.5 text-[11px] font-bold text-white" style={{ background: color }}>{x}</span>)
  return (
    <div className="flex flex-wrap items-center gap-1 border-x-4 border-slate-800 bg-slate-700 px-2 py-1" data-testid="field-bar" data-no-translate>
      {theirs.length > 0 && <span className="text-[11px] font-bold text-slate-300">{t('Adversário')}:</span>}
      {chips(theirs, '#b45309')}
      {mine.length > 0 && <span className="text-[11px] font-bold text-slate-300">{t('Você')}:</span>}
      {chips(mine, '#0369a1')}
      {chips(all, '#7c3aed')}
    </div>
  )
}

/** Tocar no Pokémon: o seu mostra tudo; o do adversário, só o que já apareceu na batalha. */
function MonDetails({ battle, side, mon }) {
  const d = monDetails(battle, side)
  if (!d) return <p className="text-sm text-muted">{mon.name}</p>
  const unknown = <span className="text-muted">?</span>
  const STAT = { hp: 'HP', atk: 'Atk', def: 'Def', spa: 'SpA', spd: 'SpD', spe: 'Spe' }
  return (
    <div className="space-y-2 text-sm" data-testid="mon-details">
      <div className="flex flex-wrap gap-1">{d.types.map((x) => <TypeBadge key={x} type={x.toLowerCase()} small />)}</div>
      <p><b>{t('Habilidade')}:</b> <span data-no-translate>{d.ability ?? unknown}</span></p>
      <p><b>{t('Item')}:</b> <span data-no-translate>{d.item || (side === 0 ? '—' : unknown)}</span></p>
      <div>
        <b>{side === 0 ? t('Golpes') : t('Golpes vistos')}:</b>
        <ul className="mt-1 list-disc pl-5" data-no-translate>
          {d.moves.length ? d.moves.map((m) => <li key={m}>{m}</li>) : <li className="text-muted">?</li>}
        </ul>
      </div>
      {d.stats && (
        <p className="tabular-nums" data-no-translate>
          {Object.entries(STAT).filter(([k]) => d.stats[k] != null).map(([k, label]) => `${label} ${d.stats[k]}`).join(' · ')}
        </p>
      )}
      {side === 1 && <p className="text-xs text-muted">{t('Do adversário aparece só o que ele já mostrou na batalha.')}</p>}
    </div>
  )
}

function InfoBox({ mon, hp, mine, status, dmax, boosts, hpTestId }) {
  return (
    <div className="w-full rounded-sm border-2 border-slate-800 bg-[#fffde0] px-2 py-1 font-mono text-slate-900 shadow-[2px_2px_0_#52634a]">
      <div className="flex items-baseline justify-between gap-1 text-xs font-black">
        <span className="truncate">{mon.name}</span>
        {mon.terastal && (
          <span className="shrink-0 rounded px-1 text-[10px] font-black text-white uppercase" style={{ background: typeColor(mon.teraType) }} data-testid="tera-badge">
            {`Tera ${mon.teraType}`}
          </span>
        )}
        {dmax && <span className="shrink-0 rounded bg-rose-600 px-1 text-[10px] font-black text-white">DMAX</span>}
        {status && (
          <span className="shrink-0 rounded px-1 text-[10px] font-black text-white" style={{ background: STATUS_BADGE[status] }} data-testid="status-badge">
            {status.toUpperCase()}
          </span>
        )}
        <span className="shrink-0 text-xs">{`Nv.${mon.level}`}</span>
      </div>
      <HpBar hp={hp} max={mon.maxHp} />
      <BoostTags boosts={boosts} />
      {(mine || hpTestId) && <div data-testid={hpTestId} className="text-right text-[11px] font-black tabular-nums">{`${hp}/${mon.maxHp}`}</div>}
    </div>
  )
}

// O Pokémon no campo: o GIF do nosso banco (de frente ou de costas), todos do
// mesmo tamanho, como na Pokédex. Igual ao app.
// Mega: a forma nova; Dinamax: gigante e avermelhado (Gigantamax: a forma dele).
/** Tipo Tera de quem terastalizou ('' se não terastalizou). */
const teraOf = (mon) => (mon?.terastal ? mon.side?.teraType || mon.teraType || 'normal' : '')

/** A coroa de cristal do Terastal (na cor do Tera Type), presa à cabeça pelo Sprite. */
function TeraCrown({ color }) {
  return (
    <svg viewBox="0 0 24 16" className="block w-full drop-shadow-[0_0_2px_rgba(255,255,255,0.9)]" aria-hidden="true">
      <g stroke="rgba(0,0,0,0.55)" strokeWidth="0.8" strokeLinejoin="round">
        <polygon points="1,15 4,5 8,12" fill={color} />
        <polygon points="16,12 20,5 23,15" fill={color} />
        <polygon points="6,15 12,0 18,15" fill={color} />
        <polygon points="1,15 23,15 21,11 3,11" fill={color} />
      </g>
      <polygon points="12,1.5 12,14 8.5,14" fill="#fff" opacity="0.55" />
      <polygon points="4,6 4.4,12 2.6,13" fill="#fff" opacity="0.5" />
      <polygon points="20,6 19.6,12 17.6,11.6" fill="#fff" opacity="0.35" />
      <rect x="3" y="12" width="18" height="1" fill="#fff" opacity="0.4" />
    </svg>
  )
}

const BattleSprite = forwardRef(function BattleSprite({ mon, id, back, fainted, dmax, tera = '', byId }, ref) {
  const p = byId?.get(id) ?? byId?.get(mon.id)
  const teraColor = tera ? typeColor(tera) : null
  return (
    <div className={`aspect-square w-full transition-all duration-500 ${fainted ? 'translate-y-10 opacity-0' : ''}`}>
      <div
        className="h-full w-full origin-bottom transition-transform duration-700"
        // Dinamax: gigante; o do adversário (lá no alto do campo) cresce menos e desce um pouco, para não passar do topo.
        style={dmax ? { transform: back ? 'scale(1.35)' : 'translateY(6%) scale(1.15)', filter: 'drop-shadow(0 0 6px #e11d48) drop-shadow(0 0 2px #e11d48)' } : undefined}
      >
        {/* Terastal: brilho de cristal na cor do tipo em volta do Pokémon e a coroa na cabeça (as duas seguem a animação). */}
        <div ref={ref} className={`relative h-full w-full ${teraColor ? 'tera-glow' : ''}`} style={teraColor ? { '--tera': teraColor } : undefined} data-tera={tera || undefined}>
          {p && <Sprite key={`${p.id}-${mon.shiny}`} path={mon.shiny ? shinyPath(p.sprite) : p.sprite} box={p.box} fill={0.95} align="bottom" back={back} battle alt={mon.name} crown={teraColor ? <TeraCrown color={teraColor} /> : null} crystal={teraColor} />}
        </div>
      </div>
    </div>
  )
})

/** Campo clássico: cores planas, faixas horizontais e duas bases de grama. */
function BattleBackground({weather=''}) {
  const palettes={rain:['#a1bac4','#d6e3d6'],sun:['#ffe4a1','#e8f6b6'],sand:['#d1bd96','#eee2ad'],hail:['#bacbd8','#eef5e3'],snow:['#bacbd8','#eef5e3']}
  const [top,bottom]=palettes[weather] || ['#b9e6bd','#edf9c8']
  return <svg className="pointer-events-none absolute inset-0 h-full w-full" viewBox="0 0 160 100" preserveAspectRatio="none" aria-hidden="true">
    <defs><linearGradient id="classic-grass" x1="0" y1="0" x2="0" y2="1"><stop stopColor={top}/><stop offset="1" stopColor={bottom}/></linearGradient></defs>
    <rect width="160" height="100" fill="url(#classic-grass)"/>
    {Array.from({length:50},(_,i)=><rect key={i} y={i*2} width="160" height="0.4" fill="#fff" opacity="0.25"/>)}
    <ellipse cx="120" cy="45" rx="32" ry="8" fill="#7eba62"/>
    <ellipse cx="120" cy="44" rx="29" ry="6" fill="#a9d57b"/>
    <ellipse cx="38" cy="91" rx="42" ry="12" fill="#7eba62"/>
    <ellipse cx="38" cy="89" rx="39" ry="9" fill="#a9d57b"/>
  </svg>
}

/** O clima caindo por cima do campo (chuva, areia, granizo, neve) ou o brilho do sol. */
function WeatherFx({ weather }) {
  return (
    <div className="pointer-events-none absolute inset-0 transition-opacity duration-700" style={{ opacity: weather ? 1 : 0 }} aria-hidden="true">
      {weather === 'rain' && (
        <>
          <div className="weather-layer weather-rain-far absolute inset-0" />
          <div className="weather-layer weather-rain absolute inset-0" />
        </>
      )}
      {weather === 'sun' && <div className="weather-sun absolute inset-0" />}
      {weather === 'sand' && <div className="weather-layer weather-sand absolute inset-0" />}
      {weather === 'hail' && <div className="weather-layer weather-hail absolute inset-0" />}
      {weather === 'snow' && <div className="weather-layer weather-snow absolute inset-0" />}
    </div>
  )
}

/** Onde fica o meio de cada Pokémon no campo (em %), para as animações dos golpes. */
const CENTER = [
  { x: 24, y: 70 },
  { x: 76, y: 26 },
]
/** Golpes corpo a corpo: quem ataca vai até o alvo. */
const CONTACT = new Set(['tackle', 'punch', 'kick', 'bite', 'slash'])

/** As peças da animação do golpe por cima do campo (moveAnim.js). */
function MoveFx({ plan, color }) {
  const line = plan.parts.filter((x) => x.shape === 'line')
  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden">
      {plan.parts.map((x, i) =>
        x.shape === 'emoji' ? (
          <span
            key={i}
            className="fx-emoji"
            style={{
              '--x0': `${x.x0}%`,
              '--y0': `${x.y0}%`,
              '--x1': `${x.x1}%`,
              '--y1': `${x.y1}%`,
              '--s0': x.s0,
              '--s1': x.s1,
              '--o0': x.o0,
              '--o1': x.o1,
              '--rot': `${x.rot}deg`,
              '--dur': `${x.dur}ms`,
              '--delay': `${x.delay}ms`,
              fontSize: `${x.size * 0.5}cqw`,
            }}
          >
            {x.char}
          </span>
        ) : x.shape === 'orbit' ? (
          <span
            key={i}
            className="fx-orbit"
            style={{
              '--x': `${x.x}%`,
              '--y': `${x.y}%`,
              '--r': `${x.r}%`,
              '--a0': `${x.a0}deg`,
              '--a1': `${x.a1}deg`,
              '--dur': `${x.dur}ms`,
              '--delay': `${x.delay}ms`,
              fontSize: `${x.size * 0.5}cqw`,
            }}
          >
            {x.char}
          </span>
        ) : x.shape === 'ring' ? (
          <div key={i} className="fx-ring" style={{ left: `${x.x}%`, top: `${x.y}%`, borderColor: color, '--dur': `${x.dur}ms`, '--delay': `${x.delay}ms` }} />
        ) : x.shape === 'wave' ? (
          <div
            key={i}
            className="fx-wave"
            style={{
              background: `linear-gradient(${color}dd, ${color}55)`,
              '--from': x.dir > 0 ? '-60%' : '105%',
              '--to': x.dir > 0 ? '105%' : '-60%',
              '--dur': `${x.dur}ms`,
              '--delay': `${x.delay}ms`,
            }}
          />
        ) : null,
      )}
      {line.length > 0 && (
        <svg viewBox="0 0 100 100" preserveAspectRatio="none" className="absolute inset-0 h-full w-full">
          {line.map((x, i) => (
            <g key={i} style={{ '--dur': `${x.dur}ms`, '--delay': `${x.delay}ms` }}>
              {[
                [color, x.width * 1.6],
                ['#fff', x.width * 0.6],
              ].map(([stroke, width]) => (
                <line
                  key={stroke}
                  x1={x.x0}
                  y1={x.y0}
                  x2={x.x1}
                  y2={x.y1}
                  pathLength={1}
                  stroke={stroke}
                  strokeWidth={width}
                  strokeLinecap="round"
                  vectorEffect="non-scaling-stroke"
                  className="fx-line"
                />
              ))}
            </g>
          ))}
        </svg>
      )}
    </div>
  )
}

/** Reinicia uma animação de CSS num elemento. */
function pulse(el, cls, ms) {
  if (!el) return
  el.classList.remove(cls)
  void el.offsetWidth
  el.classList.add(cls)
  setTimeout(() => el.classList.remove(cls), ms)
}
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

/** Altura e largura do campo na tela (para o tamanho dos treinadores). */
const fieldHeight = (field) => field.current?.clientHeight || 300
const fieldWidth = (field) => field.current?.clientWidth || 480

// Um treinador sorteado por batalha (o mesmo enquanto ela durar).
const drawn = new WeakMap()
function randomOnce(list, mine, battle) {
  if (!list?.length) return null
  if (!drawn.has(battle)) drawn.set(battle, randomTrainer(list, mine))
  return drawn.get(battle)
}

/** A Poké Ball: lançada até a plataforma ('throw') ou abrindo nela ('open'). */
function PokeBall({ side, phase }) {
  return (
    <div className={`pokeball-${phase}-${side} pointer-events-none absolute bottom-[8%] left-1/2 w-[18%]`} data-testid={`pokeball-${side}`} aria-hidden="true">
      <svg viewBox="0 0 20 20" className="block w-full">
        <circle cx="10" cy="10" r="9" fill="#fff" stroke="#1f2937" strokeWidth="1.6" />
        <path d="M1 10a9 9 0 0 1 18 0z" fill="#e3350d" stroke="#1f2937" strokeWidth="1.6" />
        <rect x="1" y="9.2" width="18" height="1.6" fill="#1f2937" />
        <circle cx="10" cy="10" r="2.8" fill="#fff" stroke="#1f2937" strokeWidth="1.4" />
      </svg>
    </div>
  )
}

/** A batalha em si. */
export function Battle(props) {
  return props.battle.mode && props.battle.mode !== 'singles' ? <MultiBattle {...props} /> : <SingleBattle {...props} />
}
function SingleBattle({ battle, foeName, foeTrainer = null, hit, onExit, onAgain, onFinish, online = null, music = 'battle_music', endNote = '', next = null, wild = false }) {
  const byId = usePokemonIndex()
  // Os treinadores: o seu (de costas, lançando a Poké Ball) e o do adversário.
  const myTrainer = useMyTrainer()
  const trainers = useTrainers()
  const [foeCoach] = useState(() => foeTrainer)
  // Pokémon selvagem (Battle Factory): sem treinador do outro lado.
  const coach = wild ? null : (typeof foeCoach === 'string' ? trainers?.find((x) => x.id === foeCoach) : foeCoach) ?? randomOnce(trainers, myTrainer?.id, battle)
  // A abertura (treinadores e Poké Balls) só no começo de uma batalha nova.
  const [intro, setIntro] = useState(() => (!online && battle.turn <= 1 ? { foe: 'in', me: 'in', back: 0 } : null))
  // Cada Pokémon: '' na tela, 'hidden' dentro da Poké Ball, 'release' saindo, 'recall' voltando.
  const [poke, setPoke] = useState(() => (!online && battle.turn <= 1 ? ['hidden', 'hidden'] : ['', '']))
  const [ball, setBall] = useState([null, null]) // 'throw' | 'open'
  // Detalhes do Pokémon tocado (0: o seu, 1: o adversário).
  const [inspect, setInspect] = useState(null)
  const setSide = (setter, side, value) => setter((list) => list.map((x, i) => (i === side ? value : x)))
  const [, redraw] = useState(0)
  // O que está na tela (anda atrás do motor enquanto os eventos passam).
  const [shown, setShown] = useState(() => ({
    active: [battle.sides[0].active, battle.sides[1].active],
    hp: battle.sides.map((s) => s.team.map((m) => m.hp)),
    status: battle.sides.map((s) => s.team.map((m) => m.status ?? '')),
    fainted: battle.sides.map((s) => s.team[s.active].hp <= 0),
    // Forma na tela (Mega / Gigantamax) e se está dinamaxizado.
    form: battle.sides.map((s) => s.team[s.active].id),
    dmax: battle.sides.map((s) => s.team[s.active].dmax > 0),
    weather: battle.weather,
    boosts: battle.sides.map((s) => boostsOf(s.team[s.active])),
    tera: battle.sides.map((s) => teraOf(s.team[s.active])),
  }))
  const [text, setText] = useState(() => (foeName ? t('{0} quer batalhar!').replace('{0}', foeName) : t('Um treinador quer batalhar!')))
  const [busy, setBusy] = useState(false)
  const [menu, setMenu] = useState(() => battle.needSwitch ? 'party' : 'main') // main | fight | party | bag
  const actionBusy = useRef(false)
  const [item, setItem] = useState(null) // item da Bolsa escolhido (falta escolher em quem)
  const [gimmickPick, setGimmickPick] = useState(null)
  const skip = useRef(null)
  const sprites = [useRef(null), useRef(null)]
  const [effect, setEffect] = useState(null) // {plan, color} da animação do golpe
  const [flash, setFlash] = useState(0)
  const effectKey = useRef(0)
  const field = useRef(null)
  // A animação de cada golpe (estilo, símbolo e variação).
  const anims = useRef(null)
  const live = useRef(true)
  const queued = useRef(Promise.resolve())
  // Replay (BattleHistoryPage.jsx): a primeira rodada (o começo da batalha) também passa na tela.
  const seenRound = useRef(online?.replay ? 0 : online?.round)
  useEffect(() => { live.current = true; return () => { live.current = false; skip.current?.() } }, [])
  // A música da batalha (para quando sai da tela).
  useEffect(() => {
    if (battle.winner == null) startMusic(music)
    return () => stopMusic()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [battle])
  useEffect(() => {
    getMoveAnims()
      .then((table) => (anims.current = table))
      .catch(() => {})
  }, [])

  const shownRef = useRef(shown)
  shownRef.current = shown
  const coachRef = useRef(coach)
  coachRef.current = coach
  const finished = useRef(false)

  /** A Poké Ball abre na plataforma e o Pokémon sai dela. */
  const release = async (side) => {
    playSound('open')
    setSide(setBall, side, 'open')
    await wait(260)
    setSide(setBall, side, null)
    setSide(setPoke, side, 'release')
    await wait(420)
    setSide(setPoke, side, '')
  }

  /** A abertura: os treinadores aparecem, lançam a Poké Ball e os Pokémon saem. */
  const runIntro = async () => {
    await wait(700)
    if (!foeName && coachRef.current) setText(t('{0} quer batalhar!').replace('{0}', coachRef.current.name))
    await wait(1100)
    if (!live.current) return
    const foeMon = battle.sides[1].team[battle.sides[1].active]
    const mine = battle.sides[0].team[battle.sides[0].active]
    setIntro((i) => ({ ...i, foe: 'out' }))
    if (wild) {
      // Selvagem: ele já está ali, sem Poké Ball.
      setSide(setPoke, 1, '')
      setText(t('Um {0} selvagem apareceu!').replace('{0}', foeMon.name))
      await wait(900)
    } else {
      setText(t('{0} enviou {1}!').replace('{0}', foeName || coachRef.current?.name || t('O adversário')).replace('{1}', foeMon.name))
      playSound('throw')
      setSide(setBall, 1, 'throw')
      await wait(520)
      await release(1)
    }
    if (!live.current) return
    setText(t('Vai, {0}!').replace('{0}', mine.name))
    for (let f = 1; f < 5; f++) {
      setIntro((i) => ({ ...i, back: f }))
      await wait(90)
    }
    setIntro((i) => ({ ...i, me: 'out' }))
    playSound('throw')
    setSide(setBall, 0, 'throw')
    await wait(520)
    await release(0)
    setIntro(null)
  }

  // before: o id de cada lado antes do turno (o motor já mudou a Mega; a tela muda no evento).
  const play = async (events, before = null) => {
    actionBusy.current = true
    setBusy(true)
    try {
    if (before) setShown((s) => ({ ...s, form: s.form.map((f, i) => (s.dmax[i] ? f : before[i])) }))
    let lastEffect = null
    for (const e of events) {
      if (!live.current) return
      // Som de cada evento (golpe, super efetivo, desmaio, atributos, cura).
      if (e.t === 'text' && (e.key === 'super' || e.key === 'weak')) lastEffect = e.key
      const sound = soundOf(e, lastEffect)
      if (sound) playSound(sound)
      if (e.t === 'hp') lastEffect = null
      if (e.t === 'attack') {
        // Cada golpe com a sua animação (move_anims.json + moveAnim.js), nas cores do tipo:
        // os de status também (Swords Dance sobe, Toxic no alvo, Rain Dance no campo...).
        const entry = anims.current?.[e.slug]
        const rules = active(battle, e.side).moves.find((m) => m.slug === e.slug)?.rules
        const self = rules?.t === 'self' || rules?.h
        const [kind, icon, variant] =
          entry ?? (e.category === 'status' ? [self ? 'boost' : 'status', null, 0] : [moveAnim(e.slug, e.type, e.category), null, 0])
        const plan = fxPlan(kind, e.type, e.side, CENTER[e.side], CENTER[1 - e.side], icon, variant)
        if (!SELF_KINDS.has(kind)) pulse(sprites[e.side].current, CONTACT.has(kind) ? `battle-dash-${e.side}` : `battle-lunge-${e.side}`, 450)
        setEffect({ plan, color: typeColor(e.type), key: ++effectKey.current })
        if (plan.shake) pulse(field.current, 'battle-shake', 650)
        if (plan.flash) setTimeout(() => live.current && setFlash((n) => n + 1), 250)
        await wait(plan.duration + 80)
        if (!live.current) return
        setEffect(null)
      } else if (e.t === 'status') {
        setShown((s) => ({ ...s, status: s.status.map((side, i) => (i === e.side ? side.map((x, j) => (j === s.active[i] ? e.status : x)) : side)) }))
      } else if (e.t === 'heal') {
        setShown((s) => ({
          ...s,
          hp: s.hp.map((side, i) => (i === e.side ? side.map((hp, j) => (j === e.index ? e.hp : hp)) : side)),
          fainted: s.fainted.map((f, i) => (i === e.side && e.index === s.active[i] ? false : f)),
        }))
        await wait(500)
      } else if (e.t === 'miss') {
        pulse(sprites[1 - e.side].current, 'battle-dodge', 420)
        await wait(300)
      } else if (e.t === 'text') {
        // Estágio do atributo na caixa de HP, junto com o texto (o fim do turno confere com o motor).
        const by = BOOST_TEXT[e.key]
        const who = e.args?.[0]?.side
        if (by && (who === 0 || who === 1))
          setShown((s) => ({
            ...s,
            boosts: s.boosts.map((b, i) => (i === who ? { ...b, [e.args[1]]: Math.max(-6, Math.min(6, (b[e.args[1]] ?? 0) + by)) } : b)),
          }))
        if (e.key === 'statsReset') setShown((s) => ({ ...s, boosts: [{}, {}] }))
        if (e.key === 'crit') setFlash((n) => n + 1)
        const line = format(e)
        if (!line) continue
        setText(line)
        await new Promise((resolve) => {
          const id = setTimeout(resolve, STEP_MS)
          skip.current = () => (clearTimeout(id), resolve())
        })
        skip.current = null
      } else if (e.t === 'hp') {
        pulse(sprites[e.side].current, 'battle-hurt', 520)
        setShown((s) => ({ ...s, hp: s.hp.map((side, i) => (i === e.side ? side.map((hp, j) => (j === s.active[i] ? e.hp : hp)) : side)) }))
        // Espera piscar e a barra de HP descer.
        await wait(550)
      } else if (e.t === 'faint') {
        setShown((s) => ({ ...s, fainted: s.fainted.map((f, i) => (i === e.side ? true : f)) }))
      } else if (e.t === 'switch') {
        // Volta para a Poké Ball (se não desmaiou) e o outro sai dela.
        const gone = shownRef.current.fainted[e.side]
        if (!gone && shownRef.current.active[e.side] !== e.index) {
          playSound('recall')
          setSide(setPoke, e.side, 'recall')
          await wait(380)
        }
        setSide(setPoke, e.side, 'hidden')
        setShown((s) => ({
          ...s,
          active: s.active.map((a, i) => (i === e.side ? e.index : a)),
          fainted: s.fainted.map((f, i) => (i === e.side ? false : f)),
          form: s.form.map((f, i) => (i === e.side ? null : f)),
          dmax: s.dmax.map((d, i) => (i === e.side ? false : d)),
          boosts: s.boosts.map((b, i) => (i === e.side ? {} : b)),
          tera: s.tera.map((x, i) => (i === e.side ? '' : x)),
        }))
        await release(e.side)
      } else if (e.t === 'mega') {
        setFlash((n) => n + 1)
        setShown((s) => ({ ...s, form: s.form.map((f, i) => (i === e.side ? e.id : f)) }))
        await wait(500)
      } else if (e.t === 'form') {
        // Forma que muda na batalha (Aegislash, Mimikyu, Darmanitan, Palafin...).
        setShown((s) => ({ ...s, form: s.form.map((f, i) => (i === e.side && !s.dmax[i] ? e.id : f)) }))
        await wait(400)
      } else if (e.t === 'dmax') {
        setShown((s) => ({ ...s, form: s.form.map((f, i) => (i === e.side ? e.id : f)), dmax: s.dmax.map((d, i) => (i === e.side ? e.on : d)) }))
        await wait(700)
      } else if (e.t === 'tera') {
        setFlash((n) => n + 1)
        setShown((s) => ({ ...s, tera: s.tera.map((x, i) => (i === e.side ? e.type || 'normal' : x)) }))
        await wait(700)
      } else if (e.t === 'weather') {
        // O cenário muda com o clima (céu, chão, chuva caindo...).
        setShown((s) => ({ ...s, weather: e.weather }))
        await wait(600)
      }
    }
    } finally {
      actionBusy.current = false
      if (live.current) {
        setShown({active:battle.sides.map(s=>s.active),hp:battle.sides.map(s=>s.team.map(m=>m.hp)),status:battle.sides.map(s=>s.team.map(m=>m.status)),fainted:battle.sides.map(s=>s.team[s.active].hp<=0),form:battle.sides.map(s=>{const mon=s.team[s.active];return mon.dmax>0?mon.gmax??mon.id:mon.id}),dmax:battle.sides.map(s=>s.team[s.active].dmax>0),weather:battle.weather,boosts:battle.sides.map(s=>boostsOf(s.team[s.active])),tera:battle.sides.map(s=>teraOf(s.team[s.active]))})
        setEffect(null)
        skip.current = null
        setBusy(false)
        setMenu(battle.needSwitch ? 'party' : 'main')
        if (battle.winner != null && !finished.current) {
          finished.current = true
          // Fim: a música para; vencendo, a fanfarra.
          stopMusic()
          if (battle.winner === (online?.side ?? 0)) playSound('victory', 0.7)
          if (!online) onFinish?.(coachRef.current?.id ?? null)
        }
        redraw((n) => n + 1)
      }
    }
  }

  // Começo: as habilidades de clima de quem entrou (Drizzle, Drought...).
  const opening = useRef(null)
  useEffect(() => {
    if (online) return
    const withIntro = intro != null
    // Com a abertura, quem entrou já saiu da Poké Ball nela: sem repetir o "enviou".
    const events = (opening.current ??= startBattle(battle)).filter((e) => !withIntro || (e.t !== 'switch' && e.key !== 'go' && e.key !== 'foeSent'))
    if (!events.length && !withIntro) return
    actionBusy.current = true
    setBusy(true)
    const id = setTimeout(async () => {
      try {
        if (withIntro) await runIntro()
        if (!live.current) return
        if (events.length) await play(events)
        else {
          actionBusy.current = false
          setBusy(false)
        }
      } catch {
        if (live.current) setText(t('Não foi possível exibir esta ação.'))
      }
    }, withIntro ? 0 : STEP_MS)
    return () => clearTimeout(id)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [battle])

  useEffect(() => {
    if (!online || online.round === seenRound.current) return
    seenRound.current = online.round
    const events = online.events, before = online.before
    setBusy(true)
    const played = online.onPlayed
    queued.current = queued.current.then(() => live.current ? play(events, before) : undefined).then(() => { if (live.current) played?.() }).catch(() => { if(live.current) setText(t('Não foi possível exibir esta ação.')) })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [online?.round])

  // Seu Pokémon desmaiou: a lista abre sozinha.
  useEffect(() => {
    if (!busy && battle.needSwitch) setText(t('Escolha o próximo Pokémon.'))
  }, [busy, battle.needSwitch])

  const me = battle.sides[0].team[shown.active[0]]
  const foe = battle.sides[1].team[shown.active[1]]
  const current = active(battle, 0)
  const usable = usableMoves(current)
  const waiting = !busy && !online?.locked && battle.winner == null
  // Golpe em sequência (Outrage, recarga, 2º turno de Solar Beam...): sem escolha, sai sozinho.
  const locked = waiting && !online && !battle.needSwitch ? lockedMove(battle) : null

  // Efetividade (como nos jogos): nos golpes, nas fraquezas do inimigo e na troca.
  const [typeData, setTypeData] = useState(null)
  useEffect(() => {
    getTypes()
      .then(setTypeData)
      .catch(() => {})
  }, [])
  const typeEff = (type, types) => (typeData ? damageTaken(types, typeData)[type] : 1)
  const rival = active(battle, 1)
  const foeWeak = typeData ? weaknesses(rival.types, ALL_TYPES, typeEff) : []

  const options = [
    ['mega', 'Mega Evolução'],
    ['tera', 'Tera'],
    ['dmax', current.gmax ? 'Gigantamax' : 'Dynamax'],
    ['z', 'Movimento Z'],
  ].filter(([kind]) => kind === current.gimmick).filter(([kind]) => kind === 'z'
    ? current.moves.some((_, i) => canGimmick(battle, 0, kind, i))
    : canGimmick(battle, 0, kind))
  const selected = gimmickPick?.id === current.id && options.some(([kind]) => kind === gimmickPick.kind)
    ? gimmickPick.kind : 'none'
  const act = async (resolve, before = null) => {
    if (actionBusy.current || online?.locked || battle.winner != null) return
    actionBusy.current = true
    setBusy(true)
    try { await play(resolve(), before) }
    catch { if(live.current) setText(t('Não foi possível executar esta ação. Escolha novamente.')) }
    finally { actionBusy.current=false; if(live.current) setBusy(false) }
  }
  useEffect(() => {
    if (!locked) return undefined
    setText(t('{0} continua com {1}!').replace('{0}', current.name).replace('{1}', locked.name))
    const id = setTimeout(() => {
      const before = [active(battle, 0).id, active(battle, 1).id]
      act(() => playTurn(battle, { move: Math.max(0, locked.index), gimmick: 'none' }, hit), before)
    }, 900)
    return () => clearTimeout(id)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [locked?.slug, battle.turn, waiting])
  const fight = (i) => {
    if (actionBusy.current || busy || battle.needSwitch || online?.locked) return
    const before = [active(battle, 0).id, active(battle, 1).id]
    const gimmick = selected
    setGimmickPick(null)
    if (online) return online.onAction({ kind: 'move', index: i, gimmick })
    act(() => playTurn(battle, { move: i, gimmick }, hit), before)
  }
  const maxed = current.dmax > 0 || selected === 'dmax'
  const choose = (i) => {
    if (actionBusy.current || busy || online?.locked) return
    setGimmickPick(null)
    if (online) return online.onAction({ kind: 'switch', index: i })
    if (item) {
      setItem(null)
      return act(() => playTurn(battle, { item, target: i }, hit))
    }
    return act(() => battle.needSwitch ? replace(battle, i) : playTurn(battle, { switch: i }, hit))
  }
  const run = () => {
    if (window.confirm(t('Fugir da batalha? Conta como derrota.'))) {
      if (online) online.onClose()
      else play(forfeit(battle))
    }
  }

  return (
    <div className="mx-auto max-w-3xl select-none">
      {/* Campo */}
      <div
        ref={field}
        className="battle-field relative aspect-[16/10] overflow-hidden sm:aspect-[16/9] rounded-t-2xl border-4 border-b-0 border-slate-800"
        style={{ background: '#9fdcff' }}
      >
        <BattleBackground weather={shown.weather} />
        <div className={`absolute top-[6%] left-[4%] w-[46%] max-w-[260px] transition-opacity ${intro && poke[1] === 'hidden' ? 'opacity-0' : ''}`}>
          <button type="button" className="block w-full cursor-pointer text-left" onClick={() => setInspect(1)} aria-label={t('Ver detalhes do adversário')} data-testid="inspect-foe">
            <InfoBox mon={foe} hp={shown.hp[1][shown.active[1]]} status={shown.status[1][shown.active[1]]} dmax={shown.dmax[1]} boosts={shown.boosts[1]} hpTestId={online ? "online-hp-" + (1 - online.side) : undefined} />
          </button>
        </div>
        {/* O inimigo fica mais longe: menor e com os pés na frente do meio da plataforma (pisando nela, como o seu). */}
        <div className="absolute right-[11%] bottom-[53%] w-[25%]">
          <div className={`poke-${poke[1] || 'shown'}`}>
            <BattleSprite ref={sprites[1]} mon={foe} id={shown.form[1] ?? foe.id} dmax={shown.dmax[1]} tera={shown.tera[1]} fainted={shown.fainted[1]} byId={byId} />
          </div>
          {ball[1] && <PokeBall side={1} phase={ball[1]} />}
          {intro && coach && (
            <div className={`trainer-foe absolute inset-x-0 bottom-0 flex justify-center ${intro.foe === 'out' ? 'trainer-leave-1' : ''}`} data-testid="foe-trainer">
              <TrainerSprite trainer={coach} box={fieldWidth(field) * 0.34} />
            </div>
          )}
        </div>
        <div className="absolute bottom-[5%] left-[7%] w-[33%]">
          <div className={`poke-${poke[0] || 'shown'}`}>
            <BattleSprite ref={sprites[0]} mon={me} id={shown.form[0] ?? me.id} dmax={shown.dmax[0]} tera={shown.tera[0]} back fainted={shown.fainted[0]} byId={byId} />
          </div>
          {ball[0] && <PokeBall side={0} phase={ball[0]} />}
        </div>
        {intro && myTrainer && (
          <div className={`absolute bottom-0 left-[2%] ${intro.me === 'out' ? 'trainer-leave-0' : ''}`} data-testid="my-trainer">
            <TrainerBack trainer={myTrainer} frame={intro.back} box={fieldHeight(field) * 0.62} />
          </div>
        )}
        <WeatherFx weather={shown.weather} />
        {effect && <MoveFx key={effect.key} plan={effect.plan} color={effect.color} />}
        {flash > 0 && <div key={`flash-${flash}`} className="battle-flash pointer-events-none absolute inset-0 bg-white" />}
        <div className={`absolute right-[4%] bottom-[8%] w-[46%] max-w-[260px] transition-opacity ${intro && poke[0] === 'hidden' ? 'opacity-0' : ''}`}>
          <button type="button" className="block w-full cursor-pointer text-left" onClick={() => setInspect(0)} aria-label={t('Ver detalhes do seu Pokémon')} data-testid="inspect-me">
            <InfoBox mon={me} hp={shown.hp[0][shown.active[0]]} status={shown.status[0][shown.active[0]]} dmax={shown.dmax[0]} boosts={shown.boosts[0]} mine hpTestId={online ? "online-hp-" + online.side : undefined} />
          </button>
        </div>
      </div>

      <FieldBar battle={battle} />
      <Modal open={inspect != null} onClose={() => setInspect(null)} title={inspect === 1 ? foe.name : me.name}>
        {inspect != null && <MonDetails battle={battle} side={inspect} mon={inspect === 1 ? foe : me} />}
      </Modal>
      {/* Texto e menus */}
      <div className="flex min-h-36 flex-col gap-2 rounded-b-2xl border-4 border-slate-800 bg-slate-800 p-2 sm:flex-row">
        <button
          type="button"
          onClick={() => skip.current?.()}
          className="min-h-20 flex-1 cursor-pointer rounded-xl border-4 border-amber-600 bg-white px-4 py-3 text-left text-lg font-bold text-slate-900"
          data-testid="battle-text"
        >
          {!busy && online?.message ? t(online.message) : text}
        </button>
        {waiting && online?.waitForSwitch && <Button onClick={() => online.onAction({ kind: 'wait', index: 0 })}>Aguardar troca do amigo</Button>}
        {waiting && !locked && !online?.waitForSwitch && menu === 'main' && !battle.needSwitch && (
          <div className="grid grid-cols-2 gap-1.5 rounded-xl border-4 border-slate-600 bg-white p-2 sm:w-72">
            <MenuButton onClick={() => (usable.length ? setMenu('fight') : fight(-1))}>LUTAR</MenuButton>
            <MenuButton disabled={Boolean(online)} onClick={() => setMenu('bag')}>BOLSA</MenuButton>
            <MenuButton onClick={() => (setItem(null), setMenu('party'))}>POKÉMON</MenuButton>
            <MenuButton onClick={run}>FUGIR</MenuButton>
          </div>
        )}
        {waiting && !locked && menu === 'fight' && (
          <div className="grid grid-cols-2 gap-1.5 rounded-xl border-4 border-slate-600 bg-white p-2 sm:w-96" data-testid="moves">
            <Weak mon={rival} list={foeWeak} />
            {options.map(([kind, label]) => (
              <button
                key={kind}
                type="button"
                onClick={() => setGimmickPick(selected === kind ? null : { id: current.id, kind })}
                aria-pressed={selected === kind}
                className={`cursor-pointer rounded-lg border-2 px-2 py-1 text-sm font-black uppercase ${selected === kind ? 'border-fuchsia-600 bg-gradient-to-r from-fuchsia-500 via-amber-400 to-sky-500 text-white' : 'border-slate-300 bg-slate-100 text-slate-500'}`}
                data-testid={kind}
              >
                {`${t(label)} ${kind === 'tera' ? current.teraType : ''} ${selected === kind ? '✓' : ''}`}
              </button>
            ))}
            {current.moves.map((m, i) => {
              const eff = moveEffect(hit, current, rival, m)
              const z = selected === 'z' && canGimmick(battle, 0, 'z', i)
              const max = maxed && m.category !== 'status'
              return (
                <button
                  key={m.slug}
                  type="button"
                  disabled={m.pp <= 0 || m.disabled}
                  onClick={() => fight(i)}
                  className="cursor-pointer rounded-lg px-2 py-1.5 text-left text-white disabled:cursor-default disabled:opacity-40"
                  style={{ background: typeColor(m.type) }}
                  data-no-translate
                >
                  <div className="truncate text-sm font-black">{z ? Z_MOVES[m.type] : max ? MAX_MOVES[m.type] : m.name}</div>
                  {(z || max) && <div className="truncate text-[10px] font-bold opacity-90">{`${m.name} · ${t('Poder')} ${z ? zPower(m.power) : maxPower(m.power, m.type)}`}</div>}
                  <div className="flex items-center justify-between gap-1 text-[11px] font-semibold">
                    <span className="opacity-90">{`PP ${m.pp}/${m.maxPp}`}</span>
                    {(() => {
                      const range = !z && !max ? damageRange(hit, current, rival, m, shown.weather) : null
                      return range && <span className="tabular-nums opacity-95" data-testid="damage-range">{range[0] === range[1] ? `${range[0]}%` : `${range[0]}–${range[1]}%`}</span>
                    })()}
                    <EffectTag eff={eff} />
                  </div>
                </button>
              )
            })}
            <MenuButton onClick={() => setMenu('main')} className="col-span-2 text-sm">
              Voltar
            </MenuButton>
          </div>
        )}
      </div>

      {waiting && menu === 'bag' && (
        <div className="mt-3 rounded-2xl bg-card p-3 shadow">
          <div className="mb-2 flex items-center justify-between">
            <b>{t('Bolsa')}</b>
            <button type="button" onClick={() => setMenu('main')} className="cursor-pointer text-sm text-muted hover:text-text">
              Voltar
            </button>
          </div>
          <div className="grid gap-2 sm:grid-cols-2" data-testid="bag">
            {ITEMS.filter((it) => it.count > 0 || (battle.bags[0][it.slug] ?? 0) > 0).map((it) => {
              const left = battle.bags[0][it.slug] ?? 0
              const usableOn = battle.sides[0].team.some((_, i) => canUseItem(battle, 0, it.slug, i))
              return (
                <button
                  key={it.slug}
                  type="button"
                  disabled={!usableOn}
                  onClick={() => (setItem(it.slug), setMenu('party'))}
                  className="flex cursor-pointer items-center gap-3 rounded-xl bg-surface p-2 text-left disabled:cursor-default disabled:opacity-50"
                >
                  <img src={spriteUrl(`items/${it.slug}.png`)} alt="" className="pixelated h-10 w-10" />
                  <div className="min-w-0 flex-1">
                    <div className="font-bold" data-no-translate>
                      {it.name}
                    </div>
                    <div className="text-xs text-muted">
                      {it.revive
                        ? t('Revive com metade do HP')
                        : it.heal >= 9999
                          ? t('Recupera todo o HP')
                          : battle.healPct
                            ? t('Recupera {0}% do HP').replace('{0}', Math.round(HEAL_SHARE[it.slug] * 100))
                            : t('Recupera {0} de HP').replace('{0}', it.heal)}
                    </div>
                  </div>
                  <span className="font-black tabular-nums">{`×${left}`}</span>
                </button>
              )
            })}
          </div>
        </div>
      )}

      {waiting && menu === 'party' && (
        <div className="mt-3 rounded-2xl bg-card p-3 shadow">
          <div className="mb-2 flex items-center justify-between">
            <b>{battle.needSwitch ? t('Escolha o próximo Pokémon') : item ? t('Usar em qual Pokémon?') : t('Trocar de Pokémon')}</b>
            {!battle.needSwitch && (
              <button type="button" onClick={() => (item ? (setItem(null), setMenu('bag')) : setMenu('main'))} className="cursor-pointer text-sm text-muted hover:text-text">
                Voltar
              </button>
            )}
          </div>
          {!item && <Weak mon={rival} list={foeWeak} className="mb-2" />}
          <div className="grid gap-2 sm:grid-cols-2" data-testid="party">
            {battle.sides[0].team.map((m, i) => {
              const isActive = i === battle.sides[0].active
              const match = !item && m.hp > 0 ? switchMatchup(hit, m, rival, typeEff) : null
              return (
                <button
                  key={i}
                  type="button"
                  disabled={item ? !canUseItem(battle, 0, item, i) : battle.sides[0].switchOptions ? !battle.sides[0].switchOptions.includes(i) : m.hp <= 0 || isActive}
                  onClick={() => choose(i)}
                  className={`flex cursor-pointer items-center gap-2 rounded-xl bg-surface p-2 text-left disabled:cursor-default disabled:opacity-50 ${isActive ? 'ring-2 ring-sky-500' : ''}`}
                >
                  <PokeIcon id={m.id} shiny={m.shiny} className="h-12 w-12" />
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-1.5 font-bold">
                      <span className="truncate">{m.name}</span>
                      {m.status && m.hp > 0 && (
                        <span className="shrink-0 rounded px-1 text-[10px] font-black text-white" style={{ background: STATUS_BADGE[m.status] }}>
                          {m.status.toUpperCase()}
                        </span>
                      )}
                    </div>
                    <HpBar hp={m.hp} max={m.maxHp} />
                    <div className="text-xs text-muted tabular-nums">{m.hp > 0 ? `${m.hp}/${m.maxHp}` : t('Desmaiado')}</div>
                    {match && (
                      <div className="mt-1 flex flex-wrap gap-1 text-[10px] font-bold" data-testid="matchup">
                        {match.attack != null && <EffectTag eff={match.attack} prefix={t('Ataca')} />}
                        <DefenseTag mult={match.defense} />
                      </div>
                    )}
                  </div>
                </button>
              )
            })}
          </div>
        </div>
      )}

      {!busy && battle.winner != null && endNote && (
        <p className="mt-4 rounded-xl bg-card p-3 text-center font-bold" data-testid="end-note">{endNote}</p>
      )}
      {!busy && battle.winner != null && (
        <div className="mt-4 flex flex-wrap justify-center gap-3">
          {next && <Button color="linear-gradient(90deg,#F59E0B,#DC2626)" onClick={next.onClick}>
            {next.label}
          </Button>}
          {!online && onAgain && <Button color="linear-gradient(90deg,#DC2626,#9333EA)" onClick={onAgain}>
            Batalhar de novo
          </Button>}
          <Button color="#546E7A" onClick={onExit}>
            {online ? 'Sair' : 'Trocar os times'}
          </Button>
        </div>
      )}
    </div>
  )
}

// Cores da efetividade: verde = bom para quem ataca, vermelho = ruim.
const EFFECT_COLOR = { 'Super efetivo': '#15803d', Efetivo: '#475569', 'Pouco efetivo': '#b45309', 'Não afeta': '#1f2937' }

/** "Super efetivo ×2", "Pouco efetivo ×½", "Não afeta"... (nada para golpe de status). */
function EffectTag({ eff, prefix }) {
  const label = effectLabel(eff)
  if (!label) return null
  const mult = eff === 0 || eff === 1 ? '' : ` ×${fraction(eff)}`
  return (
    <span className="rounded px-1 py-px text-[10px] font-black whitespace-nowrap text-white" style={{ background: EFFECT_COLOR[label] }} data-testid="effect">
      {`${prefix ? `${prefix}: ` : ''}${t(label)}${mult}`}
    </span>
  )
}

/** Quanto ele sofre com os tipos do inimigo. */
function DefenseTag({ mult }) {
  const [label, color] = mult === 0 ? ['Imune', '#15803d'] : mult < 1 ? ['Resiste', '#15803d'] : mult > 1 ? ['Fraco', '#b91c1c'] : ['Neutro', '#475569']
  return (
    <span className="rounded px-1 py-px text-[10px] font-black whitespace-nowrap text-white" style={{ background: color }}>
      {`${t('Recebe')}: ${t(label)}${mult === 0 || mult === 1 ? '' : ` ×${fraction(mult)}`}`}
    </span>
  )
}

const fraction = (x) => ({ 0.25: '¼', 0.5: '½' })[x] ?? String(x)

/** Fraquezas do inimigo (tipos que causam ×2 ou ×4). */
function Weak({ mon, list, className = '' }) {
  if (!mon || !list.length) return null
  return (
    <div className={`col-span-2 flex flex-wrap items-center gap-1 text-[11px] font-bold text-slate-700 ${className}`} data-testid="weak">
      <span>{t('{0} é fraco contra:').replace('{0}', mon.name)}</span>
      {list.map((w) => (
        <span key={w.type} className="rounded px-1 py-px font-black text-white uppercase" style={{ background: typeColor(w.type) }}>
          {`${w.type} ×${w.mult}`}
        </span>
      ))}
    </div>
  )
}

export function MultiBattle({battle, onExit, onAgain, online = null}) {
  const byId = usePokemonIndex()
  const uid = online?.uid || 'me'
  const side = battle.controllers.findIndex(team => team.includes(uid))
  const count = battle.controllers[0].length
  const state = battle.simulator.state
  const own = state.sides[side]
  const owned = own.slots.filter(slot => battle.controllers[side][slot.slot] === uid)
  const [choices,setChoices] = useState({})
  // Como no Showdown: um Pokémon por vez; golpe com alvo abre a escolha do alvo.
  const [aim,setAim] = useState(null)
  const [gimmickOn,setGimmickOn] = useState(false)
  const [error,setError] = useState('')
  const [history,setHistory] = useState([])
  const [,redraw] = useState(0)
  const choicePhase = JSON.stringify([state.turn, online?.round, own.wait, owned.map(slot => [slot.slot, slot.index, slot.forceSwitch, slot.pass])])
  useEffect(()=>{setChoices({});setAim(null);setGimmickOn(false);setError('')},[choicePhase])
  const forced = own.slots.some(slot=>slot.forceSwitch)
  const automatic = slot => own.wait ? {kind:'wait',index:0} : slot.pass || forced && !slot.forceSwitch ? {kind:'pass',index:0} : slot.locked && !forced ? {kind:'move',index:0,gimmick:'none'} : null
  const locked = Boolean(online?.locked) || state.winner != null
  const pending = owned.filter(slot => !automatic(slot))
  const current = pending.find(slot => !choices[slot.slot])
  const send = (picks = choices) => {
    const submitted = owned.map(slot=>({seat:side*count+slot.slot,...(automatic(slot) || picks[slot.slot])}))
    const switches = submitted.filter(a=>a.kind === 'switch').map(a=>a.index)
    if (new Set(switches).size !== switches.length) {setError('Escolha Pokémon diferentes para as substituições.');setChoices({});return}
    const action = {kind:'team',choices:submitted}
    if (online) {setChoices(picks);online.onAction(action);return}
    try {
      const events = playPartyTurn(battle,[action],{order: true})
      for(let attempt=0;attempt<12 && battle.winner == null;attempt++) {
        const s=battle.simulator.state.sides[side]
        const requiresChoice=s.slots.some(slot=>battle.controllers[side][slot.slot] === uid && !s.wait && !slot.pass && (!s.slots.some(x=>x.forceSwitch) || slot.forceSwitch))
        if(requiresChoice) break
        const waiting={kind:'team',choices:s.slots.filter(slot=>battle.controllers[side][slot.slot] === uid).map(slot=>({seat:side*count+slot.slot,kind:s.wait?'wait':'pass',index:0}))}
        events.push(...playPartyTurn(battle,[waiting]))
      }
      setHistory(describeEvents(events));setChoices({});setError('');redraw(x=>x+1)
    } catch(e) {setError(e.message);setChoices({})}
  }
  // Golpe em sequência (Outrage, recarga...) em todos os seus: joga sozinho.
  const autoSent = useRef('')
  const allLocked = !own.wait && !forced && owned.length > 0 && owned.every(slot => automatic(slot)) && owned.some(slot => slot.locked)
  useEffect(()=>{
    if (!allLocked || state.winner != null || autoSent.current === choicePhase) return
    const timer = setTimeout(()=>{autoSent.current = choicePhase;send({})}, 900)
    return () => clearTimeout(timer)
  // eslint-disable-next-line react-hooks/exhaustive-deps
  },[allLocked, choicePhase])
  // Fecha a escolha deste Pokémon; depois do último, manda o turno (como no Showdown).
  const commit = (slot, choice) => {
    const next = {...choices,[slot.slot]:choice}
    setAim(null);setGimmickOn(false)
    if (pending.every(p => next[p.slot])) send(next)
    else setChoices(next)
  }
  const chooseMove = (slot, index) => {
    const mechanic = battle.sides[side].team[slot.index].gimmick
    // Z-Move só nos golpes que têm Z (o motor diz quais).
    const gimmick = gimmickOn && (mechanic !== 'z' || slot.request?.canZMove?.[index]) ? mechanic : ''
    const result = simulatorTargets(battle,side,slot.slot,index,gimmick)
    if (!result.automatic && result.targets.length > 1) {setAim({slot:slot.slot,choice:{kind:'move',index,gimmick}});return}
    commit(slot,{kind:'move',index,gimmick,target:result.targets[0]?.loc || 0})
  }
  const back = () => {
    if (aim) {setAim(null);return}
    const last = [...pending].reverse().find(slot => choices[slot.slot])
    if (last) setChoices(old => {const next={...old};delete next[last.slot];return next})
    setGimmickOn(false)
  }
  const describe = slot => {
    const c = choices[slot.slot], mon = battle.sides[side].team[slot.index]
    if (!c) return ''
    if (c.kind === 'move') {
      const target = simulatorTargets(battle,side,slot.slot,c.index,c.gimmick).targets.find(x=>x.loc===c.target)
      return `${mon.name}: ${slot.request?.moves?.[c.index]?.move ?? ''}${c.gimmick ? ` (${c.gimmick === 'dmax' ? 'Dynamax' : c.gimmick === 'z' ? 'Z-Move' : c.gimmick === 'tera' ? 'Terastal' : 'Mega'})` : ''}${target ? ` → ${target.name}` : ''}`
    }
    if (c.kind === 'switch') return `${mon.name} ⇄ ${battle.sides[side].team[c.index].name}`
    return `${mon.name}: ${t(c.kind === 'shift' ? 'trocar de posição' : 'passar')}`
  }
  const trainer = controller => controller === uid ? 'Você' : online?.names?.[controller] || 'NPC'
  const fieldSlots = teamSide => state.sides[teamSide].slots.filter(slot=>slot.index>=0)
  const info = teamSide => <div className={`absolute z-20 w-[45%] space-y-1 ${teamSide===side?'bottom-[4%] right-[3%]':'top-[4%] left-[3%]'}`}>
    {fieldSlots(teamSide).map(slot=>{
      const mon=battle.sides[teamSide].team[slot.index]
      return <div key={slot.slot} aria-label={`${trainer(battle.controllers[teamSide][slot.slot])} · posição ${slot.slot+1}`}>
        <InfoBox mon={mon} hp={mon.hp} mine={teamSide===side} status={mon.status} dmax={mon.dmax>0} hpTestId={`multi-hp-${teamSide}-${slot.slot}`}/>
      </div>
    })}
  </div>
  const sprites = teamSide => <div className={`absolute z-10 grid w-[45%] items-end ${teamSide===side?'bottom-[5%] left-[1%]':'bottom-[52%] right-[1%]'}`} style={{gridTemplateColumns:`repeat(${count},minmax(0,1fr))`}}>
    {fieldSlots(teamSide).map(slot=>{const mon=battle.sides[teamSide].team[slot.index];return <BattleSprite key={slot.slot} mon={mon} id={mon.dmax && mon.gmax || mon.id} back={teamSide===side} fainted={mon.hp<=0} dmax={mon.dmax>0} tera={teraOf(mon)} byId={byId}/>})}
  </div>
  return <section className="mx-auto max-w-3xl space-y-2">
    <div className="battle-field relative aspect-[16/10] overflow-hidden border-4 border-slate-800" data-testid="multi-battle-field" style={{aspectRatio:count===3?'1':'16 / 10',minHeight:count===3?'22rem':'14rem'}}>
      <BattleBackground weather={battle.weather}/>{sprites(1-side)}{sprites(side)}{info(1-side)}{info(side)}<WeatherFx weather={battle.weather}/>
    </div>
    <p className="rounded-xl bg-card p-3 font-bold" data-testid="multi-turn" data-turn={state.turn} data-round={online?.round ?? state.turn}>{online?.message || (state.winner != null ? state.winner === -1 ? 'Empate!' : state.winner === side ? 'Você venceu!' : 'A equipe adversária venceu!' : `${t('Turno')} ${state.turn}`)}</p>
    {state.winner == null && pending.length > 0 && <div className="space-y-2 rounded-xl border-4 border-slate-800 bg-slate-800 p-2 text-white" data-testid="multi-actions">
      {pending.some(slot=>choices[slot.slot]) && <ul className="space-y-0.5 text-xs text-slate-300" data-testid="multi-chosen">{pending.filter(slot=>choices[slot.slot]).map(slot=><li key={slot.slot}>✓ {describe(slot)}</li>)}</ul>}
      {current ? (()=>{
        const slot=current, mon=battle.sides[side].team[slot.index], req=slot.request
        const step=pending.indexOf(slot)+1
        const mechanic=mon.gimmick
        const reserved=Object.values(choices).some(c=>c.gimmick===mechanic)
        const available=mechanic==='mega'?req?.canMegaEvo:mechanic==='tera'?req?.canTerastallize:mechanic==='dmax'?req?.canDynamax:mechanic==='z'?req?.canZMove?.some(Boolean):false
        // Pokémon que outro já escolheu para entrar não aparece de novo.
        const taken=new Set(Object.values(choices).filter(c=>c.kind==='switch').map(c=>c.index))
        if (aim) {
          const targets=simulatorTargets(battle,side,slot.slot,aim.choice.index,aim.choice.gimmick).targets
          const row=ally=>targets.filter(t=>!!t.ally===ally).sort((a,b)=>a.slot-b.slot)
          return <div className="space-y-2">
            <h3 className="font-bold">{`${t('Em quem')} ${mon.name} ${t('vai usar')} ${req?.moves?.[aim.choice.index]?.move ?? ''}?`} <span className="text-slate-400">{`(${step}/${pending.length})`}</span></h3>
            {[false,true].map(ally=>row(ally).length>0 && <div key={String(ally)} className="grid gap-1.5" style={{gridTemplateColumns:`repeat(${count},minmax(0,1fr))`}}>
              {row(ally).map(target=><button key={target.loc} type="button" data-testid={`battle-target-${target.loc}`} disabled={locked}
                onClick={()=>commit(slot,{...aim.choice,target:target.loc})}
                className={`rounded-lg border-2 px-2 py-2 text-sm font-black text-slate-900 ${ally?'border-sky-400 bg-sky-100':'border-rose-400 bg-rose-100'}`}>
                <span className="block text-[10px] font-bold text-slate-500">{t(ally?'Aliado':'Adversário')} · {target.slot+1}</span>{target.name}
              </button>)}
            </div>)}
          </div>
        }
        return <div className="space-y-2">
          <h3 className="font-bold">{slot.forceSwitch ? `${t('Quem entra no lugar de')} ${mon.name}?` : `${t('O que')} ${mon.name} ${t('vai fazer?')}`} <span className="text-slate-400">{`(${step}/${pending.length})`}</span></h3>
          {!slot.forceSwitch && <div className="grid grid-cols-2 gap-1.5 rounded-xl border-4 border-slate-600 bg-white p-2" data-testid="multi-moves" aria-label={`Golpes de ${mon.name} ${slot.slot+1}`}>
            {(req?.moves || []).map((m,index)=>{
              const move=mon.moves[index]
              return <button key={`move${index}`} type="button" data-testid={`battle-move-${slot.slot}-${index}`} disabled={locked || m.disabled || m.pp===0}
                onClick={()=>chooseMove(slot,index)}
                className="rounded-lg border-2 border-transparent px-2 py-2 text-left text-white disabled:opacity-40"
                style={{background:typeColor(move?.type || 'normal')}}>
                <span className="block text-sm font-black" data-no-translate>{m.move}</span>
                <span className="text-xs">PP {m.pp ?? '—'}/{move?.maxPp ?? m.pp ?? '—'}</span>
              </button>
            })}
          </div>}
          {!slot.forceSwitch && available && <button type="button" className={`rounded-lg px-3 py-2 font-bold text-white disabled:opacity-40 ${gimmickOn?'bg-violet-500 ring-2 ring-amber-300':'bg-violet-700'}`} disabled={locked || reserved} aria-pressed={gimmickOn} onClick={()=>setGimmickOn(v=>!v)}>{mechanic==='dmax' && mon.gmax?'Gigantamax':{mega:'Mega',tera:'Terastal',dmax:'Dynamax',z:'Z-Move'}[mechanic]}{gimmickOn?' ✓':''}</button>}
          {(slot.switchOptions.length>0 || slot.canShift || slot.forceSwitch) && <div className="space-y-1" aria-label={`Troca de ${mon.name} ${slot.slot+1}`}>
            <p className="text-xs font-bold text-slate-300">{t(slot.forceSwitch ? 'POKÉMON' : 'TROCAR (gasta a ação)')}</p>
            <div className="grid grid-cols-2 gap-1.5 sm:grid-cols-3">
              {slot.switchOptions.filter(index=>!taken.has(index)).map(index=>{const other=battle.sides[side].team[index];return <button key={`switch${index}`} type="button" data-testid={`battle-switch-${slot.slot}-${index}`} disabled={locked} onClick={()=>commit(slot,{kind:'switch',index})} className="rounded-lg bg-slate-700 px-2 py-1.5 text-left text-sm font-bold hover:bg-slate-600">{slot.revival?`${t('Reviver')} `:''}{other.name}<span className="block text-[10px] text-slate-300">{`${other.hp}/${other.maxHp}`}</span></button>})}
              {slot.canShift && <button type="button" disabled={locked} onClick={()=>commit(slot,{kind:'shift',index:0})} className="rounded-lg bg-slate-700 px-2 py-1.5 text-sm font-bold">{t('Trocar posição com o centro')}</button>}
              {slot.forceSwitch && !slot.switchOptions.filter(index=>!taken.has(index)).length && <button type="button" disabled={locked} onClick={()=>commit(slot,{kind:'pass',index:0})} className="rounded-lg bg-slate-700 px-2 py-1.5 text-sm font-bold">{t('Sem reservas: passar')}</button>}
            </div>
          </div>}
        </div>
      })() : <p>{t(online?.locked ? 'Aguardando os outros jogadores…' : 'Enviando…')}</p>}
      {(aim || pending.some(slot=>choices[slot.slot])) && !locked && <button type="button" data-testid="battle-back" onClick={back} className="rounded-lg bg-slate-600 px-3 py-1.5 text-sm font-bold">{t('◂ Voltar')}</button>}
    </div>}
    <p className="text-xs text-muted">A reserva é compartilhada pela equipe. Os itens equipados mantêm seus efeitos.</p>
    {(error || online?.error) && <p role="alert" className="text-red-400">{error || online.error}</p>}
    {state.winner==null && pending.length===0 && <Button className="w-full" disabled={locked} onClick={()=>send()}>Continuar</Button>}
    <div className="max-h-44 overflow-auto rounded-xl bg-card p-3 text-sm" aria-live="polite">{(online?.events?describeEvents(online.events):history).map((line,index)=><p key={index}>{line}</p>)}</div>
    <div className="flex gap-3"><Button onClick={online?.onClose || onExit}>{online?'Desistir':'Voltar'}</Button>{!online && state.winner!=null && <Button onClick={onAgain}>Batalhar de novo</Button>}</div>
  </section>
}

function MenuButton({ children, onClick, className = '', disabled = false }) {
  return (
    <button type="button" onClick={onClick} disabled={disabled} className={`disabled:cursor-default disabled:opacity-40 cursor-pointer rounded-lg px-2 py-2 text-left font-black whitespace-nowrap text-slate-900 hover:bg-amber-100 ${className}`}>
      {`▸ ${t(children)}`}
    </button>
  )
}

export default function TurnBattlePage() {
  const user = useAuth((s) => (s.status === 'signedIn' ? s.user : null))
  const [game, setGame] = useState(null) // {battle, foeName, foeTrainer, challenge, endNote, next, key}
  const [factoryMode, setFactoryMode] = useState(false)
  const [hit, setHit] = useState(null)
  const [regions, setRegions] = useState([])
  useEffect(() => {
    getGymLeaders().then(setRegions).catch(() => setRegions([]))
  }, [])
  useEffect(() => {
    const battle = game?.battle
    return () => { if (battle) simulatorDispose(battle) }
  }, [game?.battle])

  useEffect(() => {
    battleHitter().then((h) => setHit(() => h))
  }, [])

  // Vindo do Draft: começa direto com os times escolhidos.
  const { state } = useLocation()
  const fromDraft = state?.mine?.length && state?.theirs?.length ? state : null
  useEffect(() => {
    if (!fromDraft) return
    let alive = true
    const seed = Math.floor(Math.random() * 2 ** 31)
    const ma = fromDraft.mine.map((id) => ({ id, set: null }))
    const mb = fromDraft.theirs.map((id) => ({ id, set: null }))
    Promise.all([battleMons(ma), battleMons(mb)]).then(([a, b]) => {
      if (!alive || !a.length || !b.length) return
      const battle = newBattle(a, b, seededRandom(seed), { seed })
      battle.members = a.length === ma.length && b.length === mb.length ? { mine: ma, theirs: mb } : null
      setGame({ battle, foeName: fromDraft.foeName, key: 1 })
    })
    return () => {
      alive = false
    }
  }, [fromDraft])

  if (!user) return <Empty>Entre na sua conta para batalhar com os amigos.</Empty>

  // "Batalhar de novo": monta tudo outra vez com os mesmos times (HP e PP cheios).
  const again = () => {
    const fresh = (team) => team.map((m) => ({ ...m, hp: m.maxHp, faintShown: false, moves: m.moves.map((mv) => ({ ...mv, pp: mv.maxPp })) }))
    const b = game.battle
    const seed = Math.floor(Math.random() * 2 ** 31)
    const battle = newBattle(fresh(b.sides[0].team), fresh(b.sides[1].team), seededRandom(seed), {mode:b.mode,controllers:b.controllers,ai:b.ai,seed})
    battle.members = b.members
    setGame({ ...game, battle, endNote: '', next: null, key: game.key + 1 })
  }

  const leaders = regions.flatMap((r) => r.leaders)
  const challenge = game?.challenge ?? null
  const foeLeader = challenge ? leaders.find((l) => l.id === (challenge.kind === 'league' ? leagueOrder(regions.find((r) => r.region === challenge.region))[challenge.step]?.id : challenge.leader)) : null

  // Liga: o próximo da Elite Four (ou o Campeão) com o mesmo time seu.
  const nextLeague = async () => {
    const region = regions.find((r) => r.region === challenge.region)
    const step = challenge.step + 1
    const foe = leagueOrder(region)[step]
    const seed = Math.floor(Math.random() * 2 ** 31)
    const random = seededRandom(seed)
    const ma = game.battle.members.mine
    const mb = await leaderTeam(foe, random, challenge.difficulty)
    const [a, b] = await Promise.all([battleMons(ma), battleMons(mb)])
    const battle = newBattle(a, b, seededRandom(seed), { ai: challenge.difficulty === 'easy' ? 'easy' : 'normal', seed })
    battle.members = { mine: ma, theirs: mb.slice(0, b.length) }
    setGame({ battle, foeName: foe.name, foeTrainer: foe.trainer, challenge: { ...challenge, step }, key: game.key + 1 })
  }

  // Torre: o próximo adversário aleatório.
  const nextStreak = async () => {
    const wins = challenge.wins + 1
    const seed = Math.floor(Math.random() * 2 ** 31)
    const random = seededRandom(seed)
    const ma = game.battle.members.mine
    const mb = await randomTeam(random, streakDifficulty(wins, challenge.difficulty))
    const [a, b] = await Promise.all([battleMons(ma), battleMons(mb)])
    const battle = newBattle(a, b, seededRandom(seed), { ai: challenge.difficulty === 'easy' && wins < 3 ? 'easy' : 'normal', seed })
    battle.members = a.length === ma.length && b.length === mb.length ? { mine: ma, theirs: mb } : null
    setGame({ battle, foeName: '', foeTrainer: null, challenge: { ...challenge, wins }, key: game.key + 1 })
  }

  // Battle Factory: o próximo andar (depois de captura, carta e loja).
  const nextFactoryFloor = async (run) => {
    try {
      const battle = await factoryBattle(run)
      setGame({ battle, ...factoryFoe(run), key: (game?.key ?? 0) + 1 })
    } catch {
      setGame(null)
    }
  }

  // Fim de uma batalha da jornada: insígnia, próxima da Liga ou Hall da Fama; Torre: a sequência; Factory: o andar.
  const finishChallenge = async () => {
    if (challenge?.kind === 'factory') {
      const factory = factoryOf(useStore.getState().league)
      const run = factory.run
      if (!run?.encounter) return
      const won = game.battle.winner === 0
      let endNote
      if (won) {
        const data = await getFactoryData()
        const next = winFloor(run, data, factoryAfter(game.battle, run))
        saveFactory({ ...factory, run: next })
        endNote = run.encounter.boss
          ? `🏅 ${t('Você venceu {0}!').replace('{0}', run.encounter.boss.name)} ${t('Andar {0} vencido!').replace('{0}', run.floor)}`
          : `🏆 ${t('Andar {0} vencido!').replace('{0}', run.floor)}`
      } else {
        const after = endRun(factory, run)
        saveFactory(after)
        endNote = t('A corrida acabou no andar {0}: +{1} moedas. Recorde: andar {2}.').replace('{0}', run.floor).replace('{1}', after.last.coins).replace('{2}', after.best)
      }
      setGame((g) => (g ? { ...g, endNote, next: null } : g))
      return
    }
    if (challenge?.kind === 'tower') {
      const won = game.battle.winner === 0
      const { updateLeague } = useStore.getState()
      updateLeague((l) => streakResult(l, challenge.kind, won))
      const best = useStore.getState().league[challenge.kind].best
      const endNote = won
        ? `🔥 ${t('{0} vitórias seguidas!').replace('{0}', challenge.wins + 1)}`
        : t('A sequência terminou com {0} vitórias. Recorde: {1}.').replace('{0}', challenge.wins).replace('{1}', best)
      const next = won && game.battle.members ? { label: `⚔️ ${t('Próximo adversário')}`, onClick: () => nextStreak() } : null
      setGame((g) => (g ? { ...g, endNote, next } : g))
      return
    }
    if (!challenge || !foeLeader) return
    const won = game.battle.winner === 0
    const { league, updateLeague, trainer } = useStore.getState()
    const region = regionOf(regions, foeLeader.id)
    let endNote = '', next = null
    if (challenge.kind === 'gym') {
      if (won) {
        const had = badgesOf(league, region).includes(foeLeader.id)
        const after = winBadge(league, regions, foeLeader)
        updateLeague(() => after)
        if (!had && badgesOf(after, region).length > badgesOf(league, region).length) {
          endNote = `🏅 ${t('Você ganhou a insígnia de {0}!').replace('{0}', foeLeader.name)}`
          if (!leagueOpen(league, region) && leagueOpen(after, region)) endNote += ` ${t('A Liga de {0} foi liberada!').replace('{0}', region.region)}`
        }
      }
    } else if (challenge.kind === 'league') {
      const order = leagueOrder(region)
      if (!won) endNote = t('A Liga acabou. Tente de novo!')
      else if (challenge.step < order.length - 1) {
        const foe = order[challenge.step + 1]
        endNote = t('Próximo desafiante: {0}').replace('{0}', foe.name)
        if (game.battle.members) next = { label: `⚔️ ${t('Enfrentar {0}').replace('{0}', foe.name)}`, onClick: nextLeague }
      } else {
        updateLeague((l) => addHallOfFame(l, region, game.battle.members?.mine.map((m) => m.id) ?? [], trainer))
        endNote = `🏆 ${t('Você venceu a Liga de {0} e entrou no Hall da Fama!').replace('{0}', region.region)}`
      }
    }
    setGame((g) => (g ? { ...g, endNote, next } : g))
  }

  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <PageHeader
        title="Batalha"
        subtitle={
          factoryMode || challenge?.kind === 'factory'
            ? 'Battle Factory: sem nível máximo. Batalha por turnos como nos jogos, com o computador jogando pelo outro lado.'
            : 'Nível máximo 50. Batalha por turnos como nos jogos: seu time contra o de um amigo (ou um aleatório), com o computador jogando pelo outro lado.'
        }
      />
      <Link to="/batalha" className="inline-flex items-center gap-1 text-sm text-muted hover:text-text">
        <Icon name="back" size={16} /> Centro de Batalha
      </Link>
      {!game || !hit ? (
        <Setup onFactory={setFactoryMode} onStart={(battle, foeName, foeTrainer = null, challenge = null) => setGame({ battle, foeName, foeTrainer, challenge, key: 1 })} />
      ) : (
        <Battle
          key={game.key}
          battle={game.battle}
          foeName={game.foeName}
          foeTrainer={game.foeTrainer}
          hit={hit}
          onExit={() => setGame(null)}
          onAgain={['league', 'tower', 'factory'].includes(challenge?.kind) ? null : again}
          music={musicOf(foeLeader ?? challenge?.boss)}
          wild={Boolean(challenge?.wild)}
          endNote={game.endNote}
          next={game.next}
          onFinish={(foeTrainer) => {
            // Histórico e replay (lib/battleLog.js): só batalhas individuais que dá para refazer.
            // A Factory fica fora do histórico: o replay não refaz as bolsas da corrida.
            if (game.battle.members && game.battle.seed != null && challenge?.kind !== 'factory') useStore.getState().addBattle(battleRecord(game.battle, { foeName: game.foeName, foeTrainer }))
            finishChallenge()
          }}
        />
      )}
      {challenge?.kind === 'factory' && game?.endNote && <FactoryAfterBattle onNext={nextFactoryFloor} />}
    </div>
  )
}
