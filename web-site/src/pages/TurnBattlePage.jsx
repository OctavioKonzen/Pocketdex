import {simulatorDispose} from '../lib/battleSimulator'
// Batalha por turnos (como nos jogos de GBA), igual ao app
// (turn_battle_screen.dart): seu time contra o time de um amigo (ou um time
// aleatório), com o computador jogando pelo outro lado. O motor fica em
// lib/turnBattle.js e os Pokémon são montados em lib/battleSetup.js.

import { forwardRef, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react'
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
import { active, critChance, damageRange, fieldConditions, monDetails, lockedMove, canGimmick, canUseItem, effectLabel, forfeit, HEAL_SHARE, ITEMS, lineOf, MAX_MOVES, maxPower, moveEffect, newBattle, playTurn, replace, startBattle, STAT_NAMES, switchMatchup, usableMoves, weaknesses, Z_MOVES, zPower } from '../lib/turnBattle'
import Sprite, { pixelRatio } from '../components/Sprite'
import BwBag from '../components/BwBag'
import BwSummary, { summaryOf } from '../components/BwSummary'
import { BattleBackground, battleScale, battleScene, farPerson, foeBottom, nearPerson, PlatformBase, sceneOfBoss } from '../components/BattleScene'
import { TrainerBack, TrainerSprite } from '../components/Trainer'
import { genericTrainer, randomTrainer, useMyTrainer, useTrainers } from '../lib/trainers'
import { battleRecord } from '../lib/battleLog'
import { playSound, soundOf, startMusic, stopMusic } from '../lib/battleSound'
import {simulatorTargets, simulatorTurn} from '../lib/battleSimulator'
import {newPartyBattle, playPartyTurn, describeEvents} from '../lib/partyBattle'
import { FactoryHub, FactoryScreen, saveFactory } from '../components/FactoryPanels'
import { expBarOf, factoryAfter, factoryBattle, factoryFoe } from '../lib/factoryBattle'
import { endRun, escapeRope, factoryOf, placeMusic, winFloor } from '../lib/factoryRun'
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

function Setup({ onStart, onFactory, onFactoryRun }) {
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

  const foeKind = friend === RANDOM ? 'random' : friend === TOWER ? 'tower' : friend === FACTORY ? 'factory' : friend.startsWith(GYM) ? 'gym' : 'friend'
  const foeOptions = [
    { key: 'random', label: 'Time aleatório', hint: 'Um time sorteado', pokemon: 201, value: RANDOM, color: '#64748b' },
    { key: 'tower', label: 'Torre de Batalha', hint: 'Vitórias seguidas', pokemon: 376, value: TOWER, color: '#38bdf8' },
    { key: 'factory', label: 'Pokelike', hint: 'Suba andares com um inicial', pokemon: 133, value: FACTORY, color: '#f59e0b' },
    { key: 'gym', label: 'Líderes e campeões', hint: 'Insígnias e a Liga', pokemon: 95, value: regions[0]?.leaders[0] ? GYM + regions[0].leaders[0].id : null, color: '#ef4444' },
    { key: 'friend', label: 'Time de um amigo', hint: friends.length ? 'O computador joga por ele' : 'Adicione amigos primeiro', pokemon: 25, value: friends[0]?.uid ?? null, color: '#a855f7' },
  ]

  return (
    <section className="space-y-5">
      {error && <p role="alert" className="text-red-400">{error}</p>}
      <div className={CARD}>
        <h2 className="font-display mb-3 text-lg font-semibold">Contra quem?</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
          {foeOptions.map((o) => {
            const on = foeKind === o.key
            return (
              <button
                key={o.key}
                type="button"
                data-testid={`foe-${o.key}`}
                aria-pressed={on}
                disabled={!o.value}
                onClick={() => !on && pickFriend(o.value)}
                className={`group relative flex cursor-pointer flex-col items-center gap-1 rounded-2xl border bg-surface px-2 pt-2 pb-3 text-center transition disabled:cursor-not-allowed disabled:opacity-40 ${on ? '' : 'border-line hover:border-text/20'}`}
                style={on ? { borderColor: o.color, boxShadow: `0 0 0 1px ${o.color}`, background: `${o.color}14` } : undefined}
              >
                <PokeIcon id={o.pokemon} fill={0.95} align="bottom" className="h-20 w-20 transition-transform group-hover:scale-105" />
                <span className="text-sm font-bold">{t(o.label)}</span>
                <span className="text-xs leading-tight text-muted">{t(o.hint)}</span>
              </button>
            )
          })}
        </div>
        {foeKind === 'gym' && (
          <label className="mt-4 block space-y-1.5">
            <span className="text-sm font-semibold text-muted">Adversário</span>
            <select aria-label="Adversário" value={friend} onChange={(e) => pickFriend(e.target.value)} className={SELECT} data-no-translate>
              {regions.map((r) => (
                <optgroup key={r.region} label={r.region}>
                  {r.leaders.map((l) => (
                    <option key={l.id} value={GYM + l.id}>
                      {`${l.name} · ${t(KIND_LABEL[l.kind])}${l.type ? ` (${l.type})` : ''}`}
                    </option>
                  ))}
                </optgroup>
              ))}
            </select>
          </label>
        )}
        {foeKind === 'friend' && (
          <label className="mt-4 block space-y-1.5">
            <span className="text-sm font-semibold text-muted">Adversário</span>
            <select aria-label="Adversário" value={friend} onChange={(e) => pickFriend(e.target.value)} className={SELECT} data-no-translate>
              {friends.map((f) => (
                <option key={f.uid} value={f.uid}>
                  {f.name}
                </option>
              ))}
            </select>
          </label>
        )}
        {friend === FACTORY && <div className="mt-4"><FactoryHub onContinue={onFactoryRun} busy={busy} /></div>}
        {leader && <div className="mt-4"><LeaderCard leader={leader} /></div>}
        {streak && <div className="mt-4"><StreakCard kind={streak} /></div>}
        {leader && regionOf(regions, leader.id) && (
          <div className="mt-4">
            <RegionProgress region={regionOf(regions, leader.id)} busy={busy} ready={mine === RANDOM || Boolean(myTeam)} onLeague={(first, region) => start(first, { kind: 'league', region: region.region, step: 0, difficulty })} />
          </div>
        )}
        {foeKind === 'friend' &&
          (friendTeams === null ? (
            <p className="mt-4 text-sm text-muted">...</p>
          ) : !friendTeams.length ? (
            <p className="mt-4 text-sm text-muted">Esse amigo ainda não montou nenhum time.</p>
          ) : (
            <label className="mt-4 block space-y-1.5">
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
      </div>

      {friend !== FACTORY && (
        <div className={`${CARD} grid gap-5 md:grid-cols-2`}>
          <div className="space-y-2">
            <h2 className="font-display text-lg font-semibold">Formato</h2>
            <div role="radiogroup" aria-label="Formato" className="grid grid-cols-3 gap-2">
              {[[1, 'Individual'], [2, 'Dupla'], [3, 'Tripla']].map(([n, label]) => (
                <button
                  key={n}
                  type="button"
                  role="radio"
                  aria-checked={count === n}
                  onClick={() => setCount(n)}
                  className={`flex cursor-pointer flex-col items-center gap-1 rounded-xl border py-2.5 text-sm font-bold transition ${count === n ? 'border-[#ef3b36] bg-[#ef3b36]/10 text-text' : 'border-line bg-surface text-muted hover:text-text'}`}
                >
                  <span className="flex gap-0.5">{Array.from({ length: n }, (_, i) => <Icon key={i} name="pokeball" size={14} />)}</span>
                  {t(label)}
                </button>
              ))}
            </div>
            {count > 1 && (
              <label className="flex items-center gap-2 pt-1 text-sm text-muted">
                <input type="checkbox" checked={npcPartner} onChange={(e) => setNpcPartner(e.target.checked)} />
                Jogar com parceiros NPC (desmarcado: você controla todos)
              </label>
            )}
          </div>
          <label className="block space-y-2">
            <h2 className="font-display text-lg font-semibold">Seu time</h2>
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
          {(friend === RANDOM || streak || leader || npcPartner) && (
            <div className="space-y-2 md:col-span-2">
              <h2 className="font-display text-lg font-semibold">Dificuldade dos NPCs</h2>
              <div role="radiogroup" aria-label="Dificuldade dos NPCs" className="grid gap-2 sm:grid-cols-3">
                {[['easy', 'Fácil', 'Ataca ao acaso, sem trocas nem itens', '#22c55e'], ['normal', 'Normal', 'IVs e EVs aleatórios', '#38bdf8'], ['hard', 'Difícil', 'Sets competitivos', '#ef4444']].map(([key, label, hint, color]) => (
                  <button
                    key={key}
                    type="button"
                    role="radio"
                    aria-checked={difficulty === key}
                    onClick={() => setDifficulty(key)}
                    className={`cursor-pointer rounded-xl border px-3 py-2.5 text-left transition ${difficulty === key ? '' : 'border-line bg-surface hover:border-text/20'}`}
                    style={difficulty === key ? { borderColor: color, background: `${color}14` } : undefined}
                  >
                    <span className="flex items-center gap-2 text-sm font-bold"><span className="h-2 w-2 rounded-full" style={{ background: color }} />{t(label)}</span>
                    <span className="mt-0.5 block text-xs text-muted">{t(hint)}</span>
                  </button>
                ))}
              </div>
            </div>
          )}
        </div>
      )}
      {friend !== FACTORY && (
        <div className="space-y-2">
          <Button color="linear-gradient(90deg,#DC2626,#9333EA)" className="w-full py-3.5 text-lg" disabled={busy || !ready} onClick={() => start()}>
            {busy ? 'Preparando...' : '⚔️ Começar batalha'}
          </Button>
          <p className="text-center text-xs text-muted">
            O computador joga pelo adversário. Golpes com PP, precisão, prioridade, crítico, status, mudanças de atributo e clima.
          </p>
        </div>
      )}
    </section>
  )
}

function HpBar({ hp, max, bw = false }) {
  const pct = Math.max(0, Math.min(100, (hp / max) * 100))
  const color = pct > 50 ? '#22c55e' : pct > 20 ? '#eab308' : '#ef4444'
  if (bw) {
    // Como no Black & White: "HP" num selo e a barra fina em cima do fundo escuro.
    return (
      <div className="flex items-center" data-testid="hp-bar">
        <span className="rounded-l-sm bg-[#f8b830] px-1 text-[9px] leading-[11px] font-black text-[#5a3a00]">HP</span>
        <div className="h-[7px] flex-1 overflow-hidden rounded-r-sm border border-[#202020] bg-[#384838]">
          <div className="h-full transition-[width] duration-700 ease-out" style={{ width: `${pct}%`, background: `linear-gradient(${color} 60%, rgba(0,0,0,.25) 60%)`, backgroundColor: color }} />
        </div>
      </div>
    )
  }
  return (
    <div className="flex items-center gap-1.5">
      <span className="text-[10px] font-black text-amber-600">HP</span>
      <div className="h-2 flex-1 overflow-hidden rounded-sm border border-slate-700 bg-slate-700">
        <div className="h-full rounded-full transition-[width] duration-700 ease-out" style={{ width: `${pct}%`, background: color }} />
      </div>
    </div>
  )
}

/** A barra de XP (azul, embaixo da vida, só no seu), como nos jogos. */
function ExpBar({ value }) {
  return (
    <div className="mt-0.5 flex items-center" data-testid="exp-bar">
      <span className="pr-1 text-[8px] leading-[9px] font-black text-[#7ec8ff]">EXP</span>
      <div className="h-[4px] flex-1 overflow-hidden rounded-sm bg-[#202830]">
        <div className="h-full bg-[#38a8f8] transition-[width] duration-1000 ease-out" style={{ width: `${Math.round(value * 100)}%` }} />
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
  const chips = (list, color) => list.map((x) => <span key={x} className="rounded-full px-2 py-0.5 text-[11px] font-bold text-white" style={{ background: color }}>{x}</span>)
  return (
    // Sempre a mesma altura (uma linha que rola de lado): aparecer um efeito não empurra a tela de baixo.
    <div className="flex h-7 items-center gap-1 overflow-x-auto whitespace-nowrap border-x-4 border-slate-800 bg-slate-700 px-2" data-testid="field-bar" data-no-translate>
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

function InfoBox({ mon, hp, mine, status, dmax, boosts, hpTestId, exp = null, bw = false }) {
  if (bw) {
    // Caixa do Black & White: escura, encostada na borda (a do adversário em cima à esquerda, a sua à direita), com o XP embaixo da vida.
    return (
      <div className={`bw-box w-full px-2 pt-0.5 pb-1 text-white ${mine ? 'rounded-l-xl pl-3' : 'rounded-r-xl pr-3'}`}>
        <div className="bw-text flex items-baseline gap-1 text-[12px] font-bold sm:text-sm">
          <span className="truncate">{mon.name}</span>
          {mon.terastal && (
            <span className="shrink-0 rounded px-1 text-[9px] font-black uppercase" style={{ background: typeColor(mon.teraType) }} data-testid="tera-badge">
              {`Tera ${mon.teraType}`}
            </span>
          )}
          {dmax && <span className="shrink-0 rounded bg-rose-600 px-1 text-[9px] font-black">DMAX</span>}
          {status && (
            <span className="shrink-0 rounded px-1 text-[9px] font-black" style={{ background: STATUS_BADGE[status] }} data-testid="status-badge">
              {status.toUpperCase()}
            </span>
          )}
          <span className="ml-auto shrink-0 text-[11px] sm:text-xs">{`Lv${mon.level}`}</span>
        </div>
        <HpBar hp={hp} max={mon.maxHp} bw />
        <BoostTags boosts={boosts} />
        {(mine || hpTestId) && <div data-testid={hpTestId} className="bw-text text-right text-[11px] leading-tight font-bold tabular-nums sm:text-xs">{`${hp}/${mon.maxHp}`}</div>}
        {exp != null && <ExpBar value={exp} />}
      </div>
    )
  }
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
  // A Mega (ou outra forma) com o mesmo tamanho de pixel da forma de antes: uma mais larga não encolhe.
  const base = byId?.get(mon.orig?.id ?? mon.id)
  const scale = battleScale(p?.height) * (!dmax && base && p && base.id !== p.id ? pixelRatio(base.sprite, p.sprite, back) : 1)
  return (
    <div className={`aspect-square w-full transition-all duration-500 ${fainted ? 'translate-y-10 opacity-0' : ''}`} style={{ transform: `scale(${scale})`, transformOrigin: '50% 100%' }} data-scale={scale}>
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

/** O clima caindo por cima do campo (chuva, areia, granizo, neve) ou o brilho do sol. */
/** Onde fica cada efeito do lugar no cenário. */
const PLACE_ZONE = { miasma: 'ground', haunt: 'ground', current: 'ground', quicksand: 'ground', aurora: 'sky', storm: 'sky' }
function WeatherFx({ weather, terrain = '', place = '' }) {
  return (
    <>
    {/* Terreno: o chão muda de cor e brilha. Efeito do lugar: diamantes, pedras e cinzas caindo, névoa, frio, aura, correnteza. */}
    {terrain && <div className={`terrain-layer terrain-${terrain}`} aria-hidden="true" data-testid="terrain-fx" />}
    {/* No cenário: no chão (névoa, correnteza, areia), no céu (aurora, tempestade) ou caindo por trás dos Pokémon. */}
    {place && <div className={`place-layer place-${place} place-${PLACE_ZONE[place] ?? 'all'} pointer-events-none absolute`} aria-hidden="true" data-testid="place-fx" />}
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
      {weather === 'wind' && <div className="weather-layer weather-wind absolute inset-0" />}
    </div>
    </>
  )
}

/** Onde fica o meio de cada Pokémon no campo (em %), se não der para medir na tela (centerOf). */
const CENTER = [
  { x: 24, y: 60 },
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
const fieldWidth = (field) => field.current?.clientWidth || 480

// Um treinador sorteado por batalha (o mesmo enquanto ela durar).
const drawn = new WeakMap()
function randomOnce(list, mine, battle) {
  if (!list?.length) return null
  if (!drawn.has(battle)) drawn.set(battle, randomTrainer(list, mine))
  return drawn.get(battle)
}

/** A Poké Ball: lançada até a plataforma ('throw') ou abrindo nela ('open'). */
/** A Poké Ball na batalha: o sprite dela (do jogo, em pixel art), de cada tipo (Great Ball, Ultra Ball...). */
function PokeBall({ side, phase, kind = 'poke-ball' }) {
  return (
    <div className={`pokeball-${phase}-${side} pointer-events-none absolute bottom-[8%] left-1/2 w-[18%]`} data-testid={`pokeball-${side}`} aria-hidden="true">
      <img src={spriteUrl(`items/${kind}.png`)} alt="" className="pixelated block w-full" draggable={false} />
    </div>
  )
}

/** A batalha em si. */
export function Battle(props) {
  return props.battle.mode && props.battle.mode !== 'singles' ? <MultiBattle {...props} /> : <SingleBattle {...props} />
}
/** As cores da tela VS de cada chefe (líder, Elite Four, Campeão, rival, vilão). */
const VS_KIND = {
  gym: ['Líder de ginásio', '#f97316'], elite: ['Elite Four', '#7c3aed'], champion: ['Campeão', '#eab308'], rival: ['Rival', '#2563eb'], villain: ['Vilão', '#dc2626'],
  // Toda batalha tem a tela VS: treinador comum, Pokémon selvagem e online.
  trainer: ['Treinador', '#0d9488'], wild: ['Pokémon selvagem', '#16a34a'], online: ['Online', '#0284c7'],
}
/** O nome do jogador cadastrado (a conta), senão "Você". */
const useMyName = () => useAuth((s) => s.user?.name) || t('Você')
/** A tela VS (como no Black & White): as faixas entram dos lados, os treinadores e o nome do chefe; toque para pular. */
function VsSplash({ me, coach, vs, myName, foeMon = null, onSkip }) {
  const [label, color] = VS_KIND[vs.kind] ?? VS_KIND.trainer
  return (
    <button type="button" className="vs-splash absolute inset-0 z-50 cursor-pointer overflow-hidden bg-slate-950" onClick={onSkip} data-testid="vs-splash" aria-label={t('Pular')}>
      <div className="vs-band vs-band-foe absolute inset-x-0 top-[10%] h-[36%]" style={{ background: `linear-gradient(100deg, transparent 8%, ${color} 8%, ${color} 92%, transparent 92%)` }} />
      <div className="vs-band vs-band-me absolute inset-x-0 bottom-[10%] h-[36%]" style={{ background: 'linear-gradient(100deg, transparent 8%, #1e293b 8%, #1e293b 92%, transparent 92%)' }} />
      <div className="vs-foe absolute right-[10%] top-[10%] flex h-[36%] items-center gap-3">
        <span className="text-right font-black leading-tight text-white drop-shadow">
          <span className="block text-xs uppercase sm:text-sm">{t(label)}</span>
          <span className="block text-xl sm:text-3xl" data-no-translate>{vs.name}</span>
        </span>
        {coach ? <TrainerSprite trainer={coach} box={120} /> : foeMon && <PokeIcon id={foeMon.id} shiny={Boolean(foeMon.shiny)} className="h-28 w-28" />}
      </div>
      <div className="vs-me absolute bottom-[10%] left-[10%] flex h-[36%] items-center gap-3">
        {me && <TrainerSprite trainer={me} box={120} flip />}
        <span className="font-black leading-tight text-white drop-shadow">
          <span className="block text-xs uppercase sm:text-sm">{t('Treinador')}</span>
          <span className="block text-xl sm:text-3xl" data-no-translate data-testid="vs-my-name">{myName}</span>
        </span>
      </div>
      <span className="vs-text absolute inset-0 grid place-items-center text-6xl font-black italic text-white sm:text-8xl">VS</span>
    </button>
  )
}

function SingleBattle({ battle, foeName, foeTrainer = null, hit, onExit, onAgain, onFinish, online = null, music = 'battle_music', endNote = '', next = null, wild = false, vs = null, keepMine = false }) {
  const byId = usePokemonIndex()
  // Os treinadores: o seu (de costas, lançando a Poké Ball) e o do adversário.
  const myTrainer = useMyTrainer()
  const trainers = useTrainers()
  const [foeCoach] = useState(() => foeTrainer)
  // Pokémon selvagem (Battle Factory): sem treinador do outro lado.
  // "generic:<semente>": um treinador comum (de rota), nunca um líder ou um personagem importante.
  const coach = wild ? null : (typeof foeCoach === 'string' ? (foeCoach.startsWith('generic:') ? genericTrainer(trainers, Number(foeCoach.slice(8))) : trainers?.find((x) => x.id === foeCoach)) : foeCoach) ?? randomOnce(trainers, myTrainer?.id, battle)
  // A abertura (treinadores e Poké Balls) só no começo de uma batalha nova.
  // keepMine (Battle Factory): o seu Pokémon já está em campo (veio da tela da corrida): sem o treinador e a Poké Ball do seu lado.
  const [intro, setIntro] = useState(() => (!online && battle.turn <= 1 ? { foe: 'in', me: keepMine ? 'gone' : 'in', back: 0 } : null))
  // A tela VS antes da luta contra um chefe (só no começo).
  // A tela VS no começo da batalha contra treinador, chefe e online, com o nome de quem joga. Contra Pokémon selvagem
  // não tem (ele aparece direto, como nos jogos). Igual ao app.
  const [vsOn, setVsOn] = useState(() => battle.turn <= 1 && !wild)
  const vsDone = useRef(null)
  const myName = useMyName()
  const vsInfo = vs?.name ? vs : wild
    ? { kind: 'wild', name: active(battle, 1).name }
    : { kind: online ? 'online' : 'trainer', name: foeName || coach?.name || t('Treinador') }
  // Online (sem a abertura): a tela VS some sozinha (ou com um toque).
  useEffect(() => {
    if (!vsOn || !online) return
    vsDone.current = () => setVsOn(false)
    const id = setTimeout(() => setVsOn(false), 2000)
    return () => clearTimeout(id)
  }, [vsOn, online])
  // Cada Pokémon: '' na tela, 'hidden' dentro da Poké Ball, 'release' saindo, 'recall' voltando.
  const [poke, setPoke] = useState(() => (!online && battle.turn <= 1 ? [keepMine ? '' : 'hidden', 'hidden'] : ['', '']))
  const [ball, setBall] = useState([null, null]) // 'throw' | 'open' | Battle Factory: 'catch' | 'still' | 'shake' | 'caught'
  // Qual Poké Ball cada lado jogou (o sprite dela).
  // A sua Poké Ball: a escolhida na loja de cosméticos da Battle Factory (senão, a Poké Ball).
  const [ballKind, setBallKind] = useState(() => [factoryOf(useStore.getState().league).ball || 'poke-ball', 'poke-ball'])
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
    terrain: battle.terrain ?? '',
    place: battle.place ?? '',
    boosts: battle.sides.map((s) => boostsOf(s.team[s.active])),
    tera: battle.sides.map((s) => teraOf(s.team[s.active])),
  }))
  const [text, setText] = useState(() => (wild ? t('Um {0} selvagem apareceu!').replace('{0}', active(battle, 1).name) : foeName ? t('{0} quer batalhar!').replace('{0}', foeName) : t('Um treinador quer batalhar!')))
  const [busy, setBusy] = useState(false)
  const [ability, setAbility] = useState(null) // a faixa da habilidade em ação ({side, name, ability})
  const [menu, setMenu] = useState(() => battle.needSwitch ? 'party' : 'main') // main | fight | party | bag
  const actionBusy = useRef(false)
  const [item, setItem] = useState(null) // item da Bolsa escolhido (falta escolher em quem)
  // Na tela do time: o tocado (com as opções TROCAR / DADOS) e os dados abertos.
  const [partyPick, setPartyPick] = useState(null)
  const [summary, setSummary] = useState(null)
  const [bagPick, setBagPick] = useState(null) // o item tocado na Bolsa (mostra a ajuda)
  const [gimmickPick, setGimmickPick] = useState(null)
  const skip = useRef(null)
  // A caixa de texto (para dividir as falas que não cabem).
  const dialogRef = useRef(null)
  const sprites = [useRef(null), useRef(null)]
  const [effect, setEffect] = useState(null) // {plan, color} da animação do golpe
  const [flash, setFlash] = useState(0)
  // A transformação em andamento (Mega, Dynamax, Tera): a aura em volta do Pokémon.
  const [morph, setMorph] = useState(null)
  // O brilho de quem é shiny ao entrar.
  const [shine, setShine] = useState(null)
  // O impacto do golpe (na cor do tipo) e a cor do último golpe que acertou.
  const [impact, setImpact] = useState(null)
  const lastHit = useRef(null)
  // O chefe já falou ao mandar o último Pokémon (só uma vez).
  const lastWords = useRef(false)
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
  // O meio do corpo de quem está em campo (em % do campo), medido na tela: os golpes saem dele e
  // acertam o outro, seja ele pequeno ou grande (escala pela altura, Dinamax, plataforma do lugar).
  const centerOf = (side) => {
    const box = sprites[side].current?.getBoundingClientRect(), all = field.current?.getBoundingClientRect()
    if (!box?.width || !all?.width) return CENTER[side]
    return { x: ((box.left + box.width / 2 - all.left) / all.width) * 100, y: ((box.top + box.height * (side === 0 ? 0.6 : 0.55) - all.top) / all.height) * 100 }
  }
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
    await sparkleIfShiny(side)
  }
  /** Shiny entrando: estrelinhas em volta dele e o som de brilho, como nos jogos. */
  const sparkleIfShiny = async (side) => {
    const mon = battle.sides[side].team[shownRef.current.active[side]]
    if (!mon?.shiny) return
    playSound('shiny', 0.7)
    setShine({ side, n: Date.now() })
    await wait(900)
    setShine(null)
  }

  /** A abertura: os treinadores aparecem, lançam a Poké Ball e os Pokémon saem. */
  const runIntro = async () => {
    if (vsOn) {
      // Espera a tela VS (ou o toque para pular).
      await Promise.race([wait(vs?.name ? 2200 : 1600), new Promise((resolve) => (vsDone.current = resolve))])
      setVsOn(false)
    }
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
      await sparkleIfShiny(1)
      await wait(900)
    } else {
      setText(t('{0} enviou {1}!').replace('{0}', foeName || coachRef.current?.name || t('O adversário')).replace('{1}', foeMon.name))
      playSound('throw')
      setSide(setBall, 1, 'throw')
      await wait(520)
      await release(1)
    }
    if (!live.current) return
    if (keepMine) {
      setIntro(null)
      return
    }
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
        const plan = fxPlan(kind, e.type, e.side, centerOf(e.side), centerOf(1 - e.side), icon, variant)
        if (!SELF_KINDS.has(kind)) pulse(sprites[e.side].current, CONTACT.has(kind) ? `battle-dash-${e.side}` : `battle-lunge-${e.side}`, 450)
        setEffect({ plan, color: typeColor(e.type), key: ++effectKey.current })
        if (e.category !== 'status') lastHit.current = typeColor(e.type)
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
        // Habilidade em ação: a faixa do lado do Pokémon, como nos jogos.
        if (e.key === 'abilityShow' && (who === 0 || who === 1)) {
          const shownAbility = { side: who, name: e.args[0].name, ability: e.args[1], k: Date.now() }
          setAbility(shownAbility)
          setTimeout(() => setAbility((a) => (a?.k === shownAbility.k ? null : a)), 2200)
          // Como no Black & White: só a faixa (sem repetir "Habilidade de Fulano!" na caixa de texto).
          await wait(900)
          continue
        }
        const line = format(e)
        if (!line) continue
        // Não cabe na caixa: em partes, uma depois da outra (como nos jogos; a caixa não aumenta).
        for (const page of dialogPages(line, dialogRef.current)) {
          if (!live.current) return
          setText(page)
          await new Promise((resolve) => {
            const id = setTimeout(resolve, STEP_MS)
            skip.current = () => (clearTimeout(id), resolve())
          })
          skip.current = null
        }
      } else if (e.t === 'hp') {
        pulse(sprites[e.side].current, 'battle-hurt', 520)
        // O impacto do golpe na cor do tipo, bem onde ele acerta (só quando perde HP depois de um ataque).
        if (lastHit.current && e.hp < shownRef.current.hp[e.side][shownRef.current.active[e.side]]) {
          const at = centerOf(e.side)
          setImpact({ ...at, color: lastHit.current, n: Date.now() })
          lastHit.current = null
        }
        setShown((s) => ({ ...s, hp: s.hp.map((side, i) => (i === e.side ? side.map((hp, j) => (j === s.active[i] ? e.hp : hp)) : side)) }))
        // Espera piscar e a barra de HP descer.
        await wait(550)
      } else if (e.t === 'faint') {
        setShown((s) => ({ ...s, fainted: s.fainted.map((f, i) => (i === e.side ? true : f)) }))
      } else if (e.t === 'switch') {
        // Personagem importante (chefe com tela VS): fala no meio da batalha, como nos jogos, quando manda o último Pokémon.
        if (e.side === 1 && vs?.name && !lastWords.current && battle.sides[1].team.length > 1
          && !battle.sides[1].team.some((_, k) => k !== e.index && shownRef.current.hp[1][k] > 0)) {
          lastWords.current = true
          setText(`${vs.name}: ${t(LAST_LINES[(vs.name.length + battle.sides[1].team.length) % LAST_LINES.length])}`)
          await new Promise((resolve) => {
            const id = setTimeout(resolve, 1800)
            skip.current = () => (clearTimeout(id), resolve())
          })
          skip.current = null
          if (!live.current) return
        }
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
        // Como nos jogos: a aura envolve o Pokémon, ele muda no meio dela e ela some.
        setMorph({ side: e.side, kind: 'mega', n: Date.now() })
        await wait(700)
        setFlash((n) => n + 1)
        setShown((s) => ({ ...s, form: s.form.map((f, i) => (i === e.side ? e.id : f)) }))
        await wait(650)
        setMorph(null)
      } else if (e.t === 'form') {
        // Forma que muda na batalha (Aegislash, Mimikyu, Darmanitan, Palafin...).
        setShown((s) => ({ ...s, form: s.form.map((f, i) => (i === e.side && !s.dmax[i] ? e.id : f)) }))
        await wait(400)
      } else if (e.t === 'dmax') {
        if (e.on) {
          setMorph({ side: e.side, kind: 'dmax', n: Date.now() })
          await wait(700)
        }
        setShown((s) => ({ ...s, form: s.form.map((f, i) => (i === e.side ? e.id : f)), dmax: s.dmax.map((d, i) => (i === e.side ? e.on : d)) }))
        await wait(e.on ? 650 : 700)
        if (e.on) setMorph(null)
      } else if (e.t === 'tera') {
        setMorph({ side: e.side, kind: 'tera', n: Date.now(), type: e.type || 'normal' })
        await wait(700)
        setFlash((n) => n + 1)
        setShown((s) => ({ ...s, tera: s.tera.map((x, i) => (i === e.side ? e.type || 'normal' : x)) }))
        await wait(650)
        setMorph(null)
      } else if (e.t === 'ball') {
        // Battle Factory: a bola no selvagem; ele entra nela, ela balança (até 3 vezes) e pega ou abre.
        playSound('throw')
        setSide(setBallKind, 1, e.ball || 'poke-ball')
        setSide(setBall, 1, 'catch')
        await wait(520)
        playSound('recall')
        setSide(setPoke, 1, 'recall')
        await wait(380)
        setSide(setPoke, 1, 'hidden')
        setSide(setBall, 1, 'still')
        for (let k = 0; k < e.shakes; k++) {
          await wait(250)
          setSide(setBall, 1, 'shake')
          await wait(520)
          setSide(setBall, 1, 'still')
        }
        await wait(300)
        if (e.caught) setSide(setBall, 1, 'caught')
        else await release(1)
      } else if (e.t === 'weather') {
        // O cenário muda com o clima (céu, chão, chuva caindo...).
        setShown((s) => ({ ...s, weather: e.weather }))
        await wait(600)
      } else if (e.t === 'terrain') {
        // Terreno (do lugar ou de um golpe): o chão do campo muda.
        setShown((s) => ({ ...s, terrain: e.terrain }))
        await wait(500)
      } else if (e.t === 'place') {
        // O efeito do lugar (Battle Factory): diamantes caindo, névoa tóxica...
        setShown((s) => ({ ...s, place: e.place }))
        await wait(500)
      }
    }
    } finally {
      actionBusy.current = false
      if (live.current) {
        setShown({active:battle.sides.map(s=>s.active),hp:battle.sides.map(s=>s.team.map(m=>m.hp)),status:battle.sides.map(s=>s.team.map(m=>m.status)),fainted:battle.sides.map(s=>s.team[s.active].hp<=0),form:battle.sides.map(s=>{const mon=s.team[s.active];return mon.dmax>0?mon.gmax??mon.id:mon.id}),dmax:battle.sides.map(s=>s.team[s.active].dmax>0),weather:battle.weather,terrain:battle.terrain??'',place:battle.place??'',boosts:battle.sides.map(s=>boostsOf(s.team[s.active])),tera:battle.sides.map(s=>teraOf(s.team[s.active]))})
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
  const scene = battleScene(battle.scene, battle.seed ?? battle.turn)
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
  const bagPockets = [
    { id: 'medicine', label: 'Remédios', img: 'potion', ball: false },
    { id: 'balls', label: 'Poké Balls', img: 'poke-ball', ball: true },
  ].map((pocket) => ({
    ...pocket,
    items: ITEMS.filter((it) => Boolean(it.ball) === pocket.ball && (battle.bags[0][it.slug] ?? 0) > 0).map((it) => ({
      id: it.slug,
      name: it.name,
      count: battle.bags[0][it.slug] ?? 0,
      icon: spriteUrl(`items/${it.slug}.png`),
      help: itemHelp(it, battle.healPct),
      disabled: !battle.sides[0].team.some((_, i) => canUseItem(battle, 0, it.slug, i)),
      use: it.ball ? t('JOGAR') : t('USAR'),
      // A bola vai direto no selvagem; os remédios perguntam em quem.
      onUse: () => (setBagPick(null), it.ball ? throwBall(it.slug) : (setItem(it.slug), setPartyPick(null), setSummary(null), setMenu('party'))),
    })),
  }))
  const bagPicked = bagPockets.flatMap((p) => p.items).find((it) => it.id === bagPick)

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
    setPartyPick(null)
    setSummary(null)
    if (online) return online.onAction({ kind: 'switch', index: i })
    if (item) {
      setItem(null)
      return act(() => playTurn(battle, { item, target: i }, hit))
    }
    return act(() => battle.needSwitch ? replace(battle, i) : playTurn(battle, { switch: i }, hit))
  }
  const throwBall = (slug) => {
    if (actionBusy.current || busy || online) return
    setMenu('main')
    return act(() => playTurn(battle, { item: slug, target: battle.sides[1].active }, hit))
  }
  const run = () => {
    if (window.confirm(t('Fugir da batalha? Conta como derrota.'))) {
      if (online) online.onClose()
      else play(forfeit(battle))
    }
  }

  return (
    <div className="screen-fade mx-auto max-w-3xl select-none">
      {/* Campo */}
      <div
        ref={field}
        className="battle-field relative aspect-[4/3] overflow-hidden rounded-t-2xl border-4 border-b-0 border-slate-800"
        style={{ background: '#9fdcff' }}
        data-layout="bw"
      >
        {/* Como no Black & White: o adversário lá atrás à direita (menor), o seu de costas na frente à esquerda (grande, cortado pela caixa do texto). */}
        <BattleBackground weather={shown.weather} scene={scene} layout="bw" />
        {/* Clima, terreno e efeito do lugar fazem parte do cenário: atrás dos Pokémon e das caixas. */}
        <WeatherFx weather={shown.weather} terrain={shown.terrain} place={shown.place} />
        {vsOn && <VsSplash me={myTrainer} coach={coach} vs={vsInfo} myName={myName} foeMon={wild ? active(battle, 1) : null} onSkip={() => vsDone.current?.()} />}
        <div className={`absolute z-20 top-[5%] left-0 w-[50%] max-w-[300px] transition-opacity ${intro && poke[1] === 'hidden' ? 'opacity-0' : ''}`}>
          <button type="button" className="block w-full cursor-pointer text-left" onClick={() => setInspect(1)} aria-label={t('Ver detalhes do adversário')} data-testid="inspect-foe">
            <InfoBox bw mon={foe} hp={shown.hp[1][shown.active[1]]} status={shown.status[1][shown.active[1]]} dmax={shown.dmax[1]} boosts={shown.boosts[1]} hpTestId={online ? "online-hp-" + (1 - online.side) : undefined} />
          </button>
        </div>
        {/* O inimigo fica mais longe: menor e com os pés na frente do meio da plataforma (pisando nela, como o seu). */}
        <div className="absolute right-[11%] w-[26%]" style={{ bottom: `${foeBottom(scene) * 100}%` }}>
          <PlatformBase scene={scene} side="foe" scale={battleScale(byId?.get(shown.form[1] ?? foe.id)?.height)} />
          <div className={`poke-${poke[1] || 'shown'}`}>
            <BattleSprite ref={sprites[1]} mon={foe} id={shown.form[1] ?? foe.id} dmax={shown.dmax[1]} tera={shown.tera[1]} fainted={shown.fainted[1]} byId={byId} />
          </div>
          {morph?.side === 1 && <Morph key={morph.n} kind={morph.kind} type={morph.type} />}
          {shine?.side === 1 && <Sparkles key={shine.n} />}
          {ball[1] && <PokeBall side={1} phase={ball[1]} kind={ballKind[1]} />}
          {intro && coach && (
            <div className={`trainer-foe absolute inset-x-0 bottom-0 flex justify-center ${intro.foe === 'out' ? 'trainer-leave-1' : ''}`} data-testid="foe-trainer">
              <TrainerSprite trainer={coach} height={farPerson(fieldWidth(field))} />
            </div>
          )}
        </div>
        <div className="absolute bottom-[22%] left-[1%] w-[58%]">
          <PlatformBase scene={scene} side="mine" scale={battleScale(byId?.get(shown.form[0] ?? me.id)?.height)} />
          <div className={`poke-${poke[0] || 'shown'}`}>
            <BattleSprite ref={sprites[0]} mon={me} id={shown.form[0] ?? me.id} dmax={shown.dmax[0]} tera={shown.tera[0]} back fainted={shown.fainted[0]} byId={byId} />
          </div>
          {morph?.side === 0 && <Morph key={morph.n} kind={morph.kind} type={morph.type} />}
          {shine?.side === 0 && <Sparkles key={shine.n} />}
          {ball[0] && <PokeBall side={0} phase={ball[0]} kind={ballKind[0]} />}
        </div>
        {intro && intro.me !== 'gone' && myTrainer && (
          <div className={`absolute bottom-0 left-[2%] ${intro.me === 'out' ? 'trainer-leave-0' : ''}`} data-testid="my-trainer">
            {/* Na frente de tudo (mais perto que o seu Pokémon): a mesma escala de uma pessoa, um pouco maior pela perspectiva. */}
            <TrainerBack trainer={myTrainer} frame={intro.back} box={nearPerson(fieldWidth(field)) * 0.94} />
          </div>
        )}
        {/* A habilidade em ação: a faixa sai do lado do Pokémon (o adversário à direita, o seu à esquerda), como nos jogos. */}
        {ability && (
          <div key={ability.k} className={`ability-banner absolute z-20 ${ability.side === 1 ? 'ability-banner-1 right-0 top-[30%] rounded-l-lg' : 'ability-banner-0 left-0 bottom-[34%] rounded-r-lg'} bw-box px-3 py-1 text-white`} data-testid="ability-banner">
            <p className="bw-text text-[10px] font-bold leading-tight opacity-90 sm:text-xs" data-no-translate>{ability.name}</p>
            <p className="bw-text text-sm font-black leading-tight sm:text-base" data-no-translate>{ability.ability}</p>
          </div>
        )}
        {effect && <MoveFx key={effect.key} plan={effect.plan} color={effect.color} />}
        {impact && <span key={impact.n} className="move-impact pointer-events-none absolute z-20" style={{ left: `${impact.x}%`, top: `${impact.y}%`, '--c': impact.color }} data-testid="move-impact" />}
        {flash > 0 && <div key={`flash-${flash}`} className="battle-flash pointer-events-none absolute inset-0 bg-white" />}
        <div className={`absolute z-20 right-0 bottom-[24%] w-[50%] max-w-[300px] transition-opacity ${intro && poke[0] === 'hidden' ? 'opacity-0' : ''}`}>
          <button type="button" className="block w-full cursor-pointer text-left" onClick={() => setInspect(0)} aria-label={t('Ver detalhes do seu Pokémon')} data-testid="inspect-me">
            <InfoBox bw mon={me} hp={shown.hp[0][shown.active[0]]} status={shown.status[0][shown.active[0]]} dmax={shown.dmax[0]} boosts={shown.boosts[0]} mine hpTestId={online ? "online-hp-" + online.side : undefined}
              exp={expBarOf(battle, shown.active[0], shown.hp[1])} />
          </button>
        </div>
        {/* A mensagem dentro da tela, embaixo, como nos jogos (tocar passa o texto). */}
        <BattleDialog boxRef={dialogRef} onSkip={() => skip.current?.()}
          text={!busy && online?.message ? t(online.message)
            // A Bolsa: a descrição do item tocado (ou a pergunta) na caixa.
            : waiting && menu === 'bag' ? (bagPicked ? `${bagPicked.name}: ${bagPicked.help}` : t('Escolha um item.'))
            // O time aberto: a pergunta dele na caixa (como no jogo).
            : waiting && menu === 'party' && summary == null ? (battle.needSwitch ? t('Escolha o próximo Pokémon') : item ? t('Usar em qual Pokémon?') : t('Escolha um Pokémon.'))
            // Hora de escolher (como no jogo e na dupla): "O que Charizard vai fazer?".
            : waiting && !locked && (menu === 'main' || menu === 'fight') && !battle.needSwitch ? `${t('O que')} ${current.name} ${t('vai fazer?')}`
            // No fim, o recado do resultado também vem na caixa (em partes, se precisar).
            : !busy && battle.winner != null && endNote ? `${text} ${endNote}` : text} />
        {/* A Bolsa e o time abrem por cima do campo (a mesma tela, como no jogo; dá para jogar com o celular de lado). */}
        {waiting && menu === 'bag' && (
          // A Bolsa do Black & White, em bolsos: em cima da caixa de texto (a descrição do item aparece nela); USAR e
          // Voltar nos botões fixos de baixo.
          <div className="panel-in absolute inset-x-0 top-0 bottom-[22.5%] z-30"><BwBag testid="bag" external selected={bagPick} onSelect={setBagPick} pockets={bagPockets} /></div>
        )}
        {waiting && menu === 'party' && summary != null && (
          // Os dados do Pokémon (como no jogo).
          <div className="field-overlay overflow-y-auto">
            <BwSummary data={summaryOf(battle, 0, summary)} onBack={() => setSummary(null)}
              onSwitch={!item && (battle.sides[0].switchOptions ? battle.sides[0].switchOptions.includes(summary) : battle.sides[0].team[summary].hp > 0 && summary !== battle.sides[0].active)
                ? () => { const i = summary; setSummary(null); setPartyPick(null); choose(i) } : null} />
          </div>
        )}
        {waiting && menu === 'party' && summary == null && (
          // A tela do time do Black & White: os 6 cabem exatamente na tela, em cima da caixa de texto (a pergunta aparece
          // nela); tocou num Pokémon, as opções ficam nos botões fixos de baixo (como no jogo).
          <PartyGrid team={battle.sides[0].team} active={battle.sides[0].active} picked={item ? null : partyPick} testPrefix="party"
            disabled={(i) => item ? !canUseItem(battle, 0, item, i) : false}
            dim={(i, m) => !item && (battle.sides[0].switchOptions ? !battle.sides[0].switchOptions.includes(i) : m.hp <= 0 || i === battle.sides[0].active)}
            onTap={(i) => (item ? choose(i) : setPartyPick(i))}
            badge={(m) => {
              const match = !item && m.hp > 0 ? switchMatchup(hit, m, rival, typeEff) : null
              return match && <span className="flex gap-1 text-[10px] font-bold" data-testid="matchup">
                {match.attack != null && <EffectTag eff={match.attack} prefix={t('Ataca')} />}
                <DefenseTag mult={match.defense} />
              </span>
            }} />
        )}
      </div>

      <FieldBar battle={battle} />
      <Modal open={inspect != null} onClose={() => setInspect(null)} title={inspect === 1 ? foe.name : me.name}>
        {inspect != null && <MonDetails battle={battle} side={inspect} mon={inspect === 1 ? foe : me} />}
      </Modal>
      {/* Texto e menus: a tela de baixo (como no DS), sempre do mesmo tamanho e cada coisa no seu lugar. */}
      <BottomScreen
        info={waiting && !locked && (menu === 'fight' || menu === 'party' && !item) ? <Weak mon={rival} list={foeWeak} /> : null}
        grid={waiting && online?.waitForSwitch
          ? null
          : waiting && menu === 'bag' && bagPicked
            // Tocou num item: USAR (ou JOGAR) e CANCELAR nos botões fixos.
            ? <MenuGrid>
                <MenuButton testId="bag-use" disabled={bagPicked.disabled} onClick={() => bagPicked.onUse(bagPicked)}>{bagPicked.use ?? t('USAR')}</MenuButton>
                <MenuButton testId="bag-cancel" onClick={() => setBagPick(null)}>CANCELAR</MenuButton>
              </MenuGrid>
          : waiting && menu === 'party' && summary == null && partyPick != null && !item
            // Tocou num Pokémon do time: as opções nos botões fixos (como no jogo).
            ? <MenuGrid>
                <MenuButton testId="party-pick" disabled={battle.sides[0].switchOptions ? !battle.sides[0].switchOptions.includes(partyPick) : battle.sides[0].team[partyPick].hp <= 0 || partyPick === battle.sides[0].active}
                  onClick={() => { const i = partyPick; setPartyPick(null); choose(i) }}>TROCAR</MenuButton>
                <MenuButton testId="party-info" onClick={() => setSummary(partyPick)}>DADOS</MenuButton>
                <MenuButton testId="party-close" onClick={() => setPartyPick(null)}>CANCELAR</MenuButton>
              </MenuGrid>
          : waiting && !locked && !online?.waitForSwitch && menu === 'main' && !battle.needSwitch
            ? <MenuGrid>
                <MenuButton onClick={() => (usable.length ? setMenu('fight') : fight(-1))}>LUTAR</MenuButton>
                <MenuButton disabled={Boolean(online)} onClick={() => setMenu('bag')}>BOLSA</MenuButton>
                <MenuButton onClick={() => (setItem(null), setPartyPick(null), setSummary(null), setMenu('party'))}>POKÉMON</MenuButton>
                <MenuButton onClick={run}>FUGIR</MenuButton>
              </MenuGrid>
            : waiting && !locked && menu === 'fight'
              ? <div className="relative grid h-full grid-cols-2 grid-rows-2 gap-1.5" data-testid="moves">
            {current.moves.map((m, i) => {
              const eff = moveEffect(hit, current, rival, m)
              const z = selected === 'z' && canGimmick(battle, 0, 'z', i)
              const max = maxed && m.category !== 'status'
              return (
                <MoveButton
                  key={m.slug}
                  disabled={m.pp <= 0 || m.disabled}
                  onClick={() => fight(i)}
                  color={typeColor(m.type)}
                  label={z ? Z_MOVES[m.type] : max ? MAX_MOVES[m.type] : m.name}
                  note={(z || max) ? `${m.name} · ${t('Poder')} ${z ? zPower(m.power) : maxPower(m.power, m.type)}` : null}
                >
                    <span className="opacity-90">{`PP ${m.pp}/${m.maxPp}`}</span>
                    {/* A chance de crítico (dano 1,5×). */}
                    {!z && !max && critChance(current, m) != null && <span className="tabular-nums opacity-90" title={t('Chance de crítico')} data-testid="crit-chance">💥{critChance(current, m)}%</span>}
                    {(() => {
                      const range = !z && !max ? damageRange(hit, current, rival, m, shown.weather) : null
                      return range && <span className="tabular-nums opacity-95" data-testid="damage-range">{range[0] === range[1] ? `${range[0]}%` : `${range[0]}–${range[1]}%`}</span>
                    })()}
                    <EffectTag eff={eff} />
                </MoveButton>
              )
            })}
            {/* A mecânica (Mega, Z, Dynamax, Tera): o botão redondo no meio dos 4 golpes; ligado, ativa no ataque. */}
            {options.map(([kind, label]) => (
              <button
                key={kind}
                type="button"
                onClick={() => setGimmickPick(selected === kind ? null : { id: current.id, kind })}
                aria-pressed={selected === kind}
                aria-label={`${t(label)}${kind === 'tera' ? ` ${current.teraType}` : ''}`}
                className={`gimmick-button gimmick-${kind} absolute left-1/2 top-1/2 z-10 flex h-14 w-14 -translate-x-1/2 -translate-y-1/2 cursor-pointer items-center justify-center rounded-full border-[3px] text-xs font-black ${selected === kind ? 'on text-white' : ''}`}
                data-testid={kind}
              >
                {{ mega: 'MEGA', dmax: 'MAX', tera: 'TERA', z: 'Z' }[kind]}{selected === kind ? ' ✓' : ''}
              </button>
            ))}
                </div>
              : null}
        footer={waiting && !locked && menu === 'fight' ? <MenuButton onClick={() => setMenu('main')} className="h-full w-full text-sm">Voltar</MenuButton>
          : waiting && menu === 'bag'
            ? <MenuButton testId="bag-close" onClick={() => { setBagPick(null); setMenu('main') }} className="h-full w-full text-sm">Voltar</MenuButton>
          : waiting && menu === 'party' && summary == null && !battle.needSwitch
            ? <MenuButton testId="party-back" onClick={() => { setPartyPick(null); if (item) { setItem(null); setMenu('bag') } else setMenu('main') }} className="h-full w-full text-sm">Voltar</MenuButton> : null}
        // As outras escolhas: embaixo dos botões fixos.
        extra={waiting && online?.waitForSwitch ? <Button onClick={() => online.onAction({ kind: 'wait', index: 0 })}>Aguardar troca do amigo</Button>
          : !busy && battle.winner != null && !(keepMine && battle.winner === 0) ? (
          <div className="flex w-full flex-col gap-2">
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
        ) : null}
      />

    </div>
  )
}

/** O brilho do shiny: estrelinhas abrindo em volta do Pokémon e sumindo (igual ao app). */
function Sparkles() {
  return (
    <div className="pointer-events-none absolute inset-0" data-testid="shiny-sparkles">
      {Array.from({ length: 8 }, (_, k) => (
        <span key={k} className="shiny-star absolute left-1/2 top-[60%] text-lg text-amber-200" style={{ '--a': `${k * 45}deg` }}>✦</span>
      ))}
    </div>
  )
}

/** O que o chefe diz ao mandar o último Pokémon (igual ao app). */
const LAST_LINES = [
  'Ainda não acabou! Este é o meu último Pokémon!',
  'Você é bom... mas agora eu vou com tudo!',
  'Meu parceiro mais forte vai decidir esta batalha!',
]

/** A aura da transformação em volta do Pokémon: Mega (arco-íris), Dynamax (vermelha) e Tera (cristais na cor do tipo). Igual ao app. */
function Morph({ kind, type }) {
  return (
    <div className={`morph morph-${kind} pointer-events-none absolute inset-0`} style={kind === 'tera' ? { '--tera': typeColor(type) } : undefined} data-testid="morph">
      <span className="morph-ring" /><span className="morph-ring r2" /><span className="morph-ring r3" />
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
    <div className={`col-span-2 flex items-center gap-1 whitespace-nowrap text-[11px] font-bold text-slate-700 ${className}`} data-testid="weak">
      <span>{t('{0} é fraco contra:').replace('{0}', mon.name)}</span>
      {list.map((w) => (
        <span key={w.type} className="rounded px-1 py-px font-black text-white uppercase" style={{ background: typeColor(w.type) }}>
          {`${w.type} ×${w.mult}`}
        </span>
      ))}
    </div>
  )
}

export function MultiBattle({battle, hit = null, onExit, onAgain, onFinish, online = null, foeName = '', startMenu = 'main'}) {
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
  // Como na batalha normal: o menu (LUTAR / POKÉMON), os golpes e a troca.
  const [menu,setMenu] = useState(startMenu)
  const [gimmickOn,setGimmickOn] = useState(false)
  const [error,setError] = useState('')
  const [history,setHistory] = useState([])
  const [,redraw] = useState(0)
  // O turno na tela, uma ação de cada vez: a frase, a vida e quem está em cada posição como a tela mostra agora.
  const [shown,setShown] = useState(null)
  const skip = useRef(null)
  // A caixa de texto (para dividir as falas que não cabem), o tocado na tela do time e os dados abertos.
  const dialogRef = useRef(null)
  const [partyPick,setPartyPick] = useState(null)
  const [summary,setSummary] = useState(null)
  // A Bolsa (como na batalha normal): o item tocado e o escolhido para usar (aí o time pergunta em quem).
  const [bagPick,setBagPick] = useState(null)
  const [item,setItem] = useState(null)
  const timers = useRef(new Set())
  useEffect(()=>()=>{for(const id of timers.current) clearTimeout(id)},[])
  const wait = ms => new Promise(resolve=>{const id=setTimeout(()=>{timers.current.delete(id);resolve()},ms);timers.current.add(id);skip.current=()=>{clearTimeout(id);timers.current.delete(id);resolve()}})
  const snapshot = () => ({
    hp: battle.sides.map(s=>s.team.map(m=>m.hp)),
    status: battle.sides.map(s=>s.team.map(m=>m.status)),
    slots: battle.simulator.state.sides.map(s=>s.slots.map(slot=>slot.index)),
    text: '',
  })
  const play = async (events, before) => {
    let view = before ? {...before, hp: before.hp.map(r=>[...r]), status: before.status.map(r=>[...r]), slots: before.slots.map(r=>[...r])} : {...snapshot(), text: ''}
    const show = change => {view = {...view, ...change(view)}; setShown(view)}
    show(()=>({}))
    const at = e => e.at ?? (e.side >= 0 && e.pos >= 0 ? view.slots[e.side]?.[e.pos] ?? -1 : -1)
    for (const e of events) {
      const index = at(e)
      if (e.t === 'text') {
        // Não cabe na caixa: em partes, uma depois da outra (como nos jogos; a caixa não aumenta).
        for (const page of dialogPages(format(e), dialogRef.current)) {
          show(()=>({text: page}))
          await wait(e.key === 'turnOrder' ? 1600 : 1000)
        }
      } else if ((e.t === 'hp' || e.t === 'heal') && (index >= 0 || e.index >= 0)) {
        const i = index >= 0 ? index : e.index
        show(v=>({hp: v.hp.map((r,s)=>s===e.side ? r.map((hp,k)=>k===i ? e.hp : hp) : r)}))
        await wait(600)
      } else if (e.t === 'faint' && index >= 0) {
        show(v=>({hp: v.hp.map((r,s)=>s===e.side ? r.map((hp,k)=>k===index ? 0 : hp) : r)}))
        await wait(500)
      } else if (e.t === 'status' && index >= 0) {
        show(v=>({status: v.status.map((r,s)=>s===e.side ? r.map((st,k)=>k===index ? e.status : st) : r)}))
      } else if (e.t === 'switch' && e.pos >= 0) {
        show(v=>({slots: v.slots.map((r,s)=>s===e.side ? r.map((x,k)=>k===e.pos ? e.index : x) : r)}))
        await wait(500)
      } else await wait(e.t === 'attack' ? 450 : 300)
    }
    setShown(null)
  }
  const playing = shown != null
  const playedOnline = useRef(null)
  useEffect(()=>{
    if (!online?.events?.length || playedOnline.current === online.events) return
    playedOnline.current = online.events
    play(online.events)
  // eslint-disable-next-line react-hooks/exhaustive-deps
  },[online?.events])
  // A tela VS no começo (duplas/trios e online também), com o nome de quem joga.
  const [vsOn,setVsOn] = useState(() => state.turn <= 1)
  const myTrainer = useMyTrainer()
  const myName = useMyName()
  useEffect(()=>{if(!vsOn)return;const id=setTimeout(()=>setVsOn(false),1600);return()=>clearTimeout(id)},[vsOn])
  const choicePhase = JSON.stringify([state.turn, online?.round, own.wait, owned.map(slot => [slot.slot, slot.index, slot.forceSwitch, slot.pass])])
  useEffect(()=>{setChoices({});setAim(null);setGimmickOn(false);setError('');setMenu(startMenu);setItem(null);setBagPick(null)},[choicePhase, startMenu])
  const forced = own.slots.some(slot=>slot.forceSwitch)
  // Desmaiou e não sobrou ninguém para entrar (o outro já chamou o último do banco): a posição fica vazia. Igual ao app.
  const noBench = slot => slot.forceSwitch && !choices[slot.slot] && !(slot.switchOptions ?? []).some(i => !Object.values(choices).some(c => c.kind === 'switch' && c.index === i))
  const automatic = slot => own.wait ? {kind:'wait',index:0} : slot.pass || forced && !slot.forceSwitch || noBench(slot) ? {kind:'pass',index:0} : slot.locked && !forced ? {kind:'move',index:0,gimmick:'none'} : null
  const locked = Boolean(online?.locked) || state.winner != null || playing
  const pending = owned.filter(slot => !automatic(slot))
  const current = pending.find(slot => !choices[slot.slot])
  const send = (picks = choices) => {
    const submitted = owned.map(slot=>({seat:side*count+slot.slot,...(automatic(slot) || picks[slot.slot])}))
    const switches = submitted.filter(a=>a.kind === 'switch').map(a=>a.index)
    if (new Set(switches).size !== switches.length) {setError('Escolha Pokémon diferentes para as substituições.');setChoices({});return}
    const action = {kind:'team',choices:submitted}
    if (online) {setChoices(picks);online.onAction(action);return}
    const before = snapshot()
    try {
      const events = playPartyTurn(battle,[action],{order: true})
      for(let attempt=0;attempt<12 && battle.winner == null;attempt++) {
        const s=battle.simulator.state.sides[side]
        const requiresChoice=s.slots.some(slot=>battle.controllers[side][slot.slot] === uid && !s.wait && !slot.pass && (!s.slots.some(x=>x.forceSwitch) || slot.forceSwitch))
        if(requiresChoice) break
        const waiting={kind:'team',choices:s.slots.filter(slot=>battle.controllers[side][slot.slot] === uid).map(slot=>({seat:side*count+slot.slot,kind:s.wait?'wait':'pass',index:0}))}
        events.push(...playPartyTurn(battle,[waiting]))
      }
      setHistory(describeEvents(events));setChoices({});setError('');setMenu(startMenu);redraw(x=>x+1)
      play(events, before)
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
    setAim(null);setGimmickOn(false);setMenu(startMenu);setPartyPick(null);setSummary(null);setItem(null);setBagPick(null)
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
    // Do time escolhendo em quem usar o item: volta para a Bolsa.
    if (menu !== 'main') {setMenu(menu === 'party' && item ? 'bag' : 'main');setItem(null);setBagPick(null);setGimmickOn(false);setPartyPick(null);setSummary(null);return}
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
    if (c.kind === 'item') return `${mon.name}: ${ITEMS.find(it=>it.slug===c.item)?.name ?? c.item} → ${battle.sides[side].team[c.index].name}`
    return `${mon.name}: ${t(c.kind === 'shift' ? 'trocar de posição' : 'passar')}`
  }
  const trainer = controller => controller === uid ? 'Você' : online?.names?.[controller] || 'NPC'
  // Acabou (Battle Factory: o andar): avisa uma vez.
  const finished = useRef(false)
  useEffect(()=>{if(state.winner != null && !playing && !online && !finished.current){finished.current=true;onFinish?.(null)}},[state.winner, playing, online, onFinish])
  const fieldSlots = teamSide => (shown?.slots[teamSide] ?? state.sides[teamSide].slots.map(slot=>slot.index)).map((index,slot)=>({slot,index})).filter(slot=>slot.index>=0)
  const hpOf = (teamSide,index) => shown?.hp[teamSide]?.[index] ?? battle.sides[teamSide].team[index].hp
  const info = teamSide => <div className={`absolute z-20 space-y-1 ${teamSide===side?`bottom-[23.5%] right-0 ${count===3?'w-[34%]':'w-[38%]'}`:`top-[2%] left-0 ${count===3?'w-[34%]':'w-[44%]'}`}`}>
    {fieldSlots(teamSide).map(slot=>{
      const mon=battle.sides[teamSide].team[slot.index]
      return <div key={slot.slot} aria-label={`${trainer(battle.controllers[teamSide][slot.slot])} · posição ${slot.slot+1}`}>
        <InfoBox bw mon={mon} hp={hpOf(teamSide,slot.index)} mine={teamSide===side} status={shown?.status[teamSide]?.[slot.index] ?? mon.status} dmax={mon.dmax>0} hpTestId={`multi-hp-${teamSide}-${slot.slot}`}/>
      </div>
    })}
  </div>
  // O cenário do lugar (o mesmo do mapa, como na batalha de um contra um), com a plataforma embaixo de cada um.
  const scene = battleScene(battle.scene, battle.seed ?? 0)
  const sprites = teamSide => <div className={`absolute z-10 grid items-end ${teamSide===side?`left-0 ${count===3?'bottom-[25%] w-[66%]':'bottom-[19%] w-[64%]'}`:`right-0 ${count===3?'bottom-[62%] w-[66%]':'bottom-[55%] w-[58%]'}`}`} style={{gridTemplateColumns:`repeat(${count},minmax(0,1fr))`}} data-testid={`multi-sprites-${teamSide}`}>
    {fieldSlots(teamSide).map(slot=>{const mon=battle.sides[teamSide].team[slot.index],id=mon.dmax && mon.gmax || mon.id;return <div key={slot.slot} className="relative">
      <PlatformBase scene={scene} side={teamSide===side?'mine':'foe'} scale={battleScale(byId?.get(id)?.height)}/>
      <BattleSprite mon={mon} id={id} back={teamSide===side} fainted={hpOf(teamSide,slot.index)<=0} dmax={mon.dmax>0} tera={teraOf(mon)} byId={byId}/>
    </div>})}
  </div>
  // As fraquezas e a eficácia (como na batalha normal).
  const [typeData, setTypeData] = useState(null)
  useEffect(() => { getTypes().then(setTypeData).catch(() => {}) }, [])
  const typeEff = (type, types) => (typeData ? damageTaken(types, typeData)[type] : 1)
  const typesOf = mon => mon.terastal && mon.teraType ? [mon.teraType] : mon.types
  const foesOnField = state.sides[1-side].slots.filter(slot=>slot.index>=0).map(slot=>battle.sides[1-side].team[slot.index]).filter(mon=>mon.hp>0)
  // Quantos ainda tem do item (tirando o que outro Pokémon seu já vai usar neste turno). Na dupla não tem captura.
  const left = slug => (battle.bags?.[side]?.[slug] ?? 0) - Object.values(choices).filter(c=>c.kind==='item' && c.item===slug).length
  const canItem = (slug, i) => left(slug) > 0 && canUseItem(battle, side, slug, i) && !(slug === 'revive' && Object.values(choices).some(c=>c.kind==='item' && c.item==='revive' && c.index===i))
  const bagPockets = [{id: 'medicine', label: 'Remédios', img: 'potion', items: ITEMS.filter(it=>!it.ball && left(it.slug) > 0).map(it=>({
    id: it.slug, name: it.name, count: left(it.slug), icon: spriteUrl(`items/${it.slug}.png`), help: itemHelp(it, battle.healPct),
    disabled: !battle.sides[side].team.some((_, i) => canItem(it.slug, i)), use: t('USAR'),
    onUse: () => {setItem(it.slug);setBagPick(null);setPartyPick(null);setSummary(null);setMenu('party')},
  }))}]
  const bagPicked = bagPockets[0].items.find(it=>it.id===bagPick)
  // Fugir (como na batalha normal): conta como derrota.
  const run = () => {
    if (!window.confirm(t('Fugir da batalha? Conta como derrota.'))) return
    if (online) online.onClose()
    // O motor encerra a partida (a tela usa o estado dele) e a fala de quem fugiu.
    else {const events = [{t: 'text', key: 'ran', args: []}, ...(simulatorTurn(battle, [{kind: 'forfeit'}]) ?? [])];redraw(x=>x+1);play(events)}
  }
  const switchOptions = slot => {const taken=new Set(Object.values(choices).filter(c=>c.kind==='switch').map(c=>c.index));return slot.switchOptions.filter(index=>!taken.has(index))}
  // Online travado (aguardando o amigo, partida encerrada...): a mensagem da partida na caixa de texto, sem menu.
  const choosing = state.winner == null && pending.length > 0 && !playing && Boolean(current) && !online?.locked
  const view = current?.forceSwitch ? 'party' : menu
  const canBack = !locked && (Boolean(aim) || view === 'fight' || view === 'bag' || view === 'party' && !current?.forceSwitch || pending.some(slot=>choices[slot.slot]) && (view === 'main' || Boolean(current?.forceSwitch)))
  // A tela do time do Black & White por cima do campo (a mesma da batalha normal).
  // A tela do time (a mesma da batalha normal): os 6 cabem exatamente na tela; tocou num Pokémon, as opções nos botões fixos.
  const party = choosing && !aim && view === 'party' && (()=>{
    const slot=current, options=switchOptions(slot)
    if (summary != null) return <div className="field-overlay"><BwSummary data={summaryOf(battle, side, summary)} onBack={() => setSummary(null)} /></div>
    return <PartyGrid team={battle.sides[side].team} active={slot.index} picked={partyPick} testPrefix={`battle-switch-${slot.slot}`}
      dim={(i) => (item ? !canItem(item, i) : !options.includes(i))} onTap={(i) => setPartyPick(i)} />
  })()
  // A Bolsa abre no mesmo lugar (a descrição do item vai para a caixa de texto).
  const bag = choosing && !aim && view === 'bag' && <div className="panel-in absolute inset-x-0 top-0 bottom-[22.5%] z-30"><BwBag testid="bag" external selected={bagPick} onSelect={setBagPick} pockets={bagPockets} /></div>
  const status = online?.message || (state.winner != null ? state.winner === -1 ? 'Empate!' : state.winner === side ? 'Você venceu!' : 'A equipe adversária venceu!' : `${t('Turno')} ${state.turn}`)
  // A pergunta na caixa de texto enquanto escolhe ("O que Pikachu vai fazer?").
  const prompt = (()=>{
    if (!current) return ''
    const mon = battle.sides[side].team[current.index], step = pending.length > 1 ? ` (${pending.indexOf(current)+1}/${pending.length})` : ''
    if (aim) return `${t('Em quem')} ${mon.name} ${t('vai usar')} ${current.request?.moves?.[aim.choice.index]?.move ?? ''}?${step}`
    if (current.forceSwitch) return `${t('Quem entra no lugar de')} ${mon.name}?${step}`
    if (menu === 'bag') return bagPicked ? `${bagPicked.name}: ${bagPicked.help}` : `${t('Escolha um item.')}${step}`
    if (menu === 'party') return `${t(item ? 'Usar em qual Pokémon?' : 'Escolha um Pokémon.')}${step}`
    return `${t('O que')} ${mon.name} ${t('vai fazer?')}${step}`
  })()
  return <section className="mx-auto max-w-3xl space-y-2">
    {/* Sempre do mesmo tamanho da batalha normal (4:3), em dupla e em tripla. */}
    <div className="battle-field relative aspect-[4/3] overflow-hidden rounded-t-2xl border-4 border-b-0 border-slate-800" data-testid="multi-battle-field" data-layout="bw" style={{background:'#9fdcff'}}>
      <BattleBackground weather={battle.weather} scene={scene} layout="bw"/>{sprites(1-side)}{sprites(side)}{info(1-side)}{info(side)}<WeatherFx weather={battle.weather}/>
      {/* A mensagem dentro da tela, embaixo, como na batalha normal (tocar passa o texto). */}
      {/* Todo texto na caixa (o erro também); se não couber, em partes. */}
      <BattleDialog boxRef={dialogRef} onSkip={()=>skip.current?.()} text={shown ? shown.text : (error || online?.error) ? (error || online.error) : choosing ? prompt : status}/>
      {party}{bag}
      {vsOn && <VsSplash me={myTrainer} coach={null} vs={{kind: online ? 'online' : 'trainer', name: foeName || t('Adversários')}} myName={myName} onSkip={()=>setVsOn(false)}/>}
    </div>
    {/* Embaixo da tela: a mesma tela de baixo da batalha normal (do mesmo tamanho, cada coisa no seu lugar). */}
    {(()=>{
      const slots = choosing ? (()=>{
        const slot=current, mon=battle.sides[side].team[slot.index], req=slot.request
        const mechanic=mon.gimmick
        const reserved=Object.values(choices).some(c=>c.gimmick===mechanic)
        const available=mechanic==='mega'?req?.canMegaEvo:mechanic==='tera'?req?.canTerastallize:mechanic==='dmax'?req?.canDynamax:mechanic==='z'?req?.canZMove?.some(Boolean):false
        const footer = canBack ? <MenuButton onClick={back} className="h-full w-full text-sm" testId="battle-back">Voltar</MenuButton> : null
        if (aim) {
          const targets=simulatorTargets(battle,side,slot.slot,aim.choice.index,aim.choice.gimmick).targets
          const move=mon.moves[aim.choice.index]
          const row=ally=>targets.filter(target=>!!target.ally===ally).sort((a,b)=>a.slot-b.slot)
          // Os alvos com o mesmo botão dos golpes: os adversários em vermelho, o aliado em azul.
          return {footer, grid: <div className="grid h-full auto-rows-[calc(50%-0.1875rem)] grid-cols-2 gap-1.5 overflow-y-auto" data-testid="multi-targets">
            {[false,true].flatMap(ally=>row(ally)).map(target=>{
              const who=battle.sides[target.side]?.team[target.index]
              return <MoveButton key={target.loc} testId={`battle-target-${target.loc}`} disabled={locked} onClick={()=>commit(slot,{...aim.choice,target:target.loc})}
                color={target.ally?'#0369a1':'#b91c1c'} label={target.name}>
                <span className="opacity-90">{`${t(target.ally?'Aliado':'Adversário')} · ${target.slot+1}`}</span>
                {/* O dano estimado neste alvo (em % da vida dele), como na batalha normal. */}
                {(()=>{const range = hit && move && who ? damageRange(hit, mon, who, move, battle.weather) : null
                  return range && <span className="tabular-nums font-black" data-testid={`damage-range-target-${target.loc}`}>{range[0] === range[1] ? `${range[0]}%` : `${range[0]}–${range[1]}%`}</span>})()}
                {move && move.power > 0 && move.category !== 'status' && who && <EffectTag eff={typeEff(move.type, typesOf(who))}/>}
              </MoveButton>
            })}
          </div>}
        }
        if (view === 'fight') return {footer,
          // As fraquezas de cada adversário em campo, na linha de cima.
          info: <div className="space-y-0.5">{foesOnField.map(foe=><Weak key={foe.name+foe.id} mon={foe} list={typeData ? weaknesses(typesOf(foe), ALL_TYPES, typeEff) : []}/>)}</div>,
          grid: <div className="relative grid h-full grid-cols-2 grid-rows-2 gap-1.5" data-testid="multi-moves" aria-label={`Golpes de ${mon.name} ${slot.slot+1}`}>
            {(req?.moves || []).map((m,index)=>{
              const move=mon.moves[index]
              return <MoveButton key={`move${index}`} testId={`battle-move-${slot.slot}-${index}`} disabled={locked || m.disabled || m.pp===0}
                onClick={()=>chooseMove(slot,index)} color={typeColor(move?.type || 'normal')} label={m.move}>
                <span className="opacity-90">{`PP ${m.pp ?? '—'}/${move?.maxPp ?? m.pp ?? '—'}`}</span>
                {move && critChance(mon, move) != null && <span className="tabular-nums opacity-90" title={t('Chance de crítico')}>💥{critChance(mon, move)}%</span>}
                {/* Como pega em cada adversário e o dano estimado em cada um (em % da vida dele), como na batalha normal. */}
                {move && move.power > 0 && move.category !== 'status' && <span className="flex gap-0.5">{foesOnField.map((foe,k)=>{
                  const range = hit ? damageRange(hit, mon, foe, move, battle.weather) : null
                  return <span key={foe.name+foe.id} className="flex items-center gap-0.5" data-testid={`damage-range-${slot.slot}-${index}-${k}`}>
                    {range && <span className="tabular-nums font-black">{range[0] === range[1] ? `${range[0]}%` : `${range[0]}–${range[1]}%`}</span>}
                    <EffectTag eff={typeEff(move.type, typesOf(foe))}/>
                  </span>})}</span>}
              </MoveButton>
            })}
            {/* A mecânica (Mega, Z, Dynamax, Tera): o botão redondo no meio dos golpes, como na batalha normal. */}
            {available && !reserved && <button type="button" onClick={()=>setGimmickOn(v=>!v)} aria-pressed={gimmickOn} disabled={locked}
              className={`gimmick-button gimmick-${mechanic} absolute left-1/2 top-1/2 z-10 flex h-14 w-14 -translate-x-1/2 -translate-y-1/2 cursor-pointer items-center justify-center rounded-full border-[3px] text-xs font-black ${gimmickOn ? 'on text-white' : ''}`}
              data-testid={mechanic}>{{ mega: 'MEGA', dmax: 'MAX', tera: 'TERA', z: 'Z' }[mechanic]}{gimmickOn ? ' ✓' : ''}</button>}
          </div>}
        if (view === 'bag') return {footer,
          // Tocou num item: USAR e CANCELAR nos botões fixos (como na batalha normal).
          grid: bagPicked ? <MenuGrid>
            <MenuButton testId="bag-use" disabled={locked || bagPicked.disabled} onClick={bagPicked.onUse}>{bagPicked.use}</MenuButton>
            <MenuButton testId="bag-cancel" onClick={()=>setBagPick(null)}>CANCELAR</MenuButton>
          </MenuGrid> : null}
        if (view === 'party') {
          const options = switchOptions(slot)
          return {footer,
            info: foesOnField[0] && typeData ? <Weak mon={foesOnField[0]} list={weaknesses(typesOf(foesOnField[0]), ALL_TYPES, typeEff)}/> : null,
            // Tocou num Pokémon: as opções nos botões fixos (como no jogo).
            grid: partyPick != null && summary == null ? <MenuGrid>
              {item && !slot.forceSwitch
                ? <MenuButton testId={`battle-switch-${slot.slot}-pick`} disabled={locked || !canItem(item, partyPick)} onClick={()=>commit(slot,{kind:'item',item,index:partyPick})}>USAR</MenuButton>
                : <MenuButton testId={`battle-switch-${slot.slot}-pick`} disabled={locked || !options.includes(partyPick)} onClick={()=>commit(slot,{kind:'switch',index:partyPick})}>TROCAR</MenuButton>}
              <MenuButton testId={`battle-switch-${slot.slot}-info`} onClick={()=>setSummary(partyPick)}>DADOS</MenuButton>
              <MenuButton testId={`battle-switch-${slot.slot}-close`} onClick={()=>setPartyPick(null)}>CANCELAR</MenuButton>
            </MenuGrid> : null,
            // O que a tela do time não tem: embaixo dos botões fixos.
            extra: (slot.canShift || slot.forceSwitch && !options.length) ? <>
              {slot.canShift && <Button disabled={locked} onClick={()=>commit(slot,{kind:'shift',index:0})}>{t('Trocar posição com o centro')}</Button>}
              {slot.forceSwitch && !options.length && <Button disabled={locked} onClick={()=>commit(slot,{kind:'pass',index:0})}>{t('Sem reservas: passar')}</Button>}
            </> : null}
        }
        return {footer,
          // Quem já escolheu (e o quê), na linha de cima.
          info: pending.some(slot=>choices[slot.slot]) ? <ul className="space-y-0.5 text-xs text-slate-300" data-testid="multi-chosen">{pending.filter(slot=>choices[slot.slot]).map(slot=><li key={slot.slot}>✓ {describe(slot)}</li>)}</ul> : null,
          grid: <MenuGrid testId="multi-menu">
            <MenuButton onClick={()=>setMenu('fight')} disabled={locked} testId="battle-fight">LUTAR</MenuButton>
            <MenuButton onClick={()=>{setItem(null);setBagPick(null);setMenu('bag')}} disabled={locked || Boolean(online)} testId="battle-bag">BOLSA</MenuButton>
            <MenuButton onClick={()=>{setItem(null);setMenu('party')}} disabled={locked} testId="battle-party">POKÉMON</MenuButton>
            <MenuButton onClick={run} disabled={locked} testId="battle-run">FUGIR</MenuButton>
          </MenuGrid>}
      })() : {}
      const more = state.winner==null && pending.length===0 && !playing && !online?.locked
      const end = !online && state.winner!=null && !playing && !onFinish
      return <BottomScreen testId="multi-actions" data-turn={state.turn} data-round={online?.round ?? state.turn} data-playing={playing ? 1 : 0}
        info={slots.info} grid={slots.grid} footer={slots.footer}
        // As outras escolhas: embaixo dos botões fixos (no fim, como na batalha normal; a Factory abre a tela do andar sozinha).
        extra={(slots.extra || more || end) ? <>
          {slots.extra}
          {more && <Button disabled={locked} onClick={()=>send()}>Continuar</Button>}
          {end && <><Button color="linear-gradient(90deg,#DC2626,#9333EA)" onClick={onAgain}>Batalhar de novo</Button><Button color="#546E7A" onClick={onExit}>Sair</Button></>}
        </> : null}/>
    })()}
    <div className="max-h-44 overflow-auto rounded-xl bg-card p-3 text-sm" aria-live="polite">{(online?.events?describeEvents(online.events):history).map((line,index)=><p key={index}>{line}</p>)}</div>
  </section>
}

/**
 * A tela de baixo da batalha (como a do DS), a mesma na normal e na dupla/tripla: sempre do mesmo tamanho e cada coisa
 * no seu lugar — em cima a linha de informação (fraquezas, quem já escolheu), no meio a grade 2×2 (o menu ou os golpes,
 * no mesmo lugar) e embaixo o Voltar. Nada empurra nada. No fim da batalha, os botões do resultado.
 */
function BottomScreen({ info, grid, footer, extra, testId = 'battle-bottom', ...rest }) {
  return (
    <>
      <div className="flex h-[15.5rem] flex-col gap-1.5 rounded-b-2xl border-4 border-slate-800 bg-slate-800 p-2 text-white" data-testid={testId} {...rest}>
        <div className="h-10 shrink-0 overflow-x-auto overflow-y-hidden" data-testid="battle-bottom-info">{info}</div>
        {/* Sem nada para escolher agora: o menu fica no lugar dele, apagado (os botões não somem nem mudam de lugar). */}
        <div className="h-[8.5rem] shrink-0" data-testid="battle-bottom-grid">{grid ?? <IdleMenu />}</div>
        <div className="h-10 shrink-0" data-testid="battle-bottom-footer">{footer}</div>
      </div>
      {/* Outras escolhas (Continuar, Batalhar de novo, Sair...): embaixo dos botões fixos, sem mexer neles. */}
      {extra && <div className="mt-2 flex w-full flex-col gap-2" data-testid="battle-extra">{extra}</div>}
    </>
  )
}

/** O menu apagado (enquanto o turno acontece ou é a vez do outro). */
function IdleMenu() {
  return <div aria-hidden="true" className="h-full"><MenuGrid>{['LUTAR', 'BOLSA', 'POKÉMON', 'FUGIR'].map(label => <MenuButton key={label} disabled>{label}</MenuButton>)}</MenuGrid></div>
}

/** Divide a fala em partes que cabem na caixa de texto (como nos jogos: a caixa não aumenta; o resto vem depois). */
function dialogPages(text, box) {
  if (!box || !text || typeof document === 'undefined') return [text]
  const style = getComputedStyle(box)
  const width = box.clientWidth - parseFloat(style.paddingLeft) - parseFloat(style.paddingRight)
  const height = box.clientHeight - parseFloat(style.paddingTop) - parseFloat(style.paddingBottom)
  if (!(width > 0 && height > 0)) return [text]
  const probe = document.createElement('div')
  Object.assign(probe.style, { position: 'absolute', visibility: 'hidden', left: '-9999px', top: '0', width: `${width}px`, font: style.font, lineHeight: style.lineHeight, letterSpacing: style.letterSpacing, whiteSpace: 'normal', overflowWrap: 'break-word' })
  document.body.appendChild(probe)
  const fits = part => { probe.textContent = part; return probe.scrollHeight <= height + 1 }
  const pages = []
  if (fits(text)) pages.push(text)
  else {
    let page = ''
    for (const word of text.split(' ')) {
      const next = page ? `${page} ${word}` : word
      if (!page || fits(next)) page = next
      else { pages.push(page); page = word }
    }
    if (page) pages.push(page)
  }
  probe.remove()
  return pages
}

/** A caixa de texto da batalha (a mesma na normal e na dupla): sempre do mesmo tamanho; toda fala aparece nela e, se não couber, em partes (tocar passa para a próxima parte; na última, passa a fala). */
function BattleDialog({ text, onSkip, boxRef }) {
  const own = useRef(null)
  const ref = boxRef ?? own
  const [pages, setPages] = useState([text])
  const [page, setPage] = useState(0)
  useLayoutEffect(() => { setPages(dialogPages(text, ref.current)); setPage(0) }, [text, ref])
  const shown = pages[Math.min(page, pages.length - 1)] ?? text
  const more = page < pages.length - 1
  return (
    <button ref={ref} type="button" onClick={() => (more ? setPage(page + 1) : onSkip?.())}
      className="bw-message absolute inset-x-[1.5%] bottom-[1.5%] z-30 h-[21%] cursor-pointer overflow-hidden rounded-lg px-3 py-1.5 text-left text-sm leading-snug font-bold sm:px-4 sm:text-lg"
      data-testid="battle-text">
      {shown}
      {more && <span className="absolute right-2 bottom-1 animate-pulse text-xs" data-testid="battle-text-more">▼</span>}
    </button>
  )
}

/** A tela do time na batalha (como no jogo): os 6 cabem exatamente na tela (3 linhas × 2 colunas, sem rolar), em cima da caixa de texto. */
function PartyGrid({ team, active, picked, disabled, dim, onTap, testPrefix, badge }) {
  return (
    <div className="bw-party panel-in absolute inset-x-0 top-0 bottom-[22.5%] z-30 p-1.5" data-testid={`${testPrefix}-screen`}>
      <div className="grid h-full grid-cols-2 grid-rows-3 gap-1.5" data-testid={testPrefix}>
        {team.map((m, i) => (
          <button key={i} type="button" data-testid={`${testPrefix}-${i}`} disabled={disabled?.(i)} onClick={() => onTap(i)}
            className={`bw-party-slot flex min-h-0 min-w-0 cursor-pointer items-center gap-1.5 overflow-hidden rounded-xl border-2 p-1 text-left disabled:cursor-default disabled:opacity-50 ${dim?.(i, m) ? 'opacity-60' : ''} ${picked === i ? 'selected' : i === active ? 'lead' : ''}`}>
            <PokeIcon id={m.id} shiny={m.shiny} className="h-9 w-9 shrink-0 sm:h-12 sm:w-12" />
            <div className="min-w-0 flex-1">
              <div className="flex items-center gap-1.5 text-sm font-bold">
                <span className="truncate">{m.name}</span>
                {m.status && m.hp > 0 && <span className="shrink-0 rounded px-1 text-[10px] font-black text-white" style={{ background: STATUS_BADGE[m.status] }}>{m.status.toUpperCase()}</span>}
              </div>
              <HpBar hp={m.hp} max={m.maxHp} />
              <div className="flex items-center gap-1 text-[11px] font-bold tabular-nums opacity-80"><span>{m.hp > 0 ? `${m.hp}/${m.maxHp}` : t('Desmaiado')}</span>{badge?.(m, i)}</div>
            </div>
          </button>
        ))}
      </div>
    </div>
  )
}

/** O menu (LUTAR, BOLSA / POKÉMON, FUGIR) em 2×2, no mesmo lugar dos golpes. */
function MenuGrid({ children, testId }) {
  return <div className="dlg-box grid h-full grid-cols-2 grid-rows-2 gap-1.5 rounded-xl border-4 p-1.5 [&>button]:h-full" data-testid={testId}>{children}</div>
}

/** O que o item da Bolsa faz (na caixa de texto, ao tocar nele). Igual ao app. */
function itemHelp(it, healPct) {
  if (it.ball) return t('Jogar no Pokémon selvagem')
  if (it.revive) return t('Revive com metade do HP')
  if (it.heal >= 9999) return t('Recupera todo o HP')
  return healPct ? t('Recupera {0}% do HP').replace('{0}', Math.round(HEAL_SHARE[it.slug] * 100)) : t('Recupera {0} de HP').replace('{0}', it.heal)
}

/** O botão de golpe (e de alvo): o mesmo na batalha normal e na dupla/tripla. */
function MoveButton({ label, note, color, disabled = false, onClick, testId, children }) {
  return (
    <button type="button" disabled={disabled} onClick={onClick} data-testid={testId}
      className="h-full min-h-0 cursor-pointer overflow-hidden rounded-lg px-2 py-1 text-left text-white disabled:cursor-default disabled:opacity-40"
      style={{ background: color }} data-no-translate>
      <div className="truncate text-sm font-black">{label}</div>
      {note && <div className="truncate text-[10px] font-bold opacity-90">{note}</div>}
      <div className="flex items-center justify-between gap-1 text-[11px] font-semibold">{children}</div>
    </button>
  )
}

function MenuButton({ children, onClick, className = '', disabled = false, testId }) {
  return (
    <button type="button" onClick={onClick} disabled={disabled} data-testid={testId} className={`disabled:cursor-default disabled:opacity-40 dlg-btn cursor-pointer rounded-lg px-2 py-2 text-left font-black whitespace-nowrap ${className}`}>
      {`▸ ${t(children)}`}
    </button>
  )
}

export default function TurnBattlePage() {
  const user = useAuth((s) => (s.status === 'signedIn' ? s.user : null))
  const [game, setGame] = useState(null) // {battle, foeName, foeTrainer, challenge, endNote, next, key}
  const [factoryMode, setFactoryMode] = useState(false)
  const [factoryBusy, setFactoryBusy] = useState(false)
  const [factoryError, setFactoryError] = useState('')
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

  // Battle Factory: a corrida em tela cheia (resultado, loja, mapa) e a batalha do caminho escolhido.
  const openFactory = () => setGame((g) => ({ factory: true, key: (g?.key ?? 0) + 1 }))
  const factoryFloor = async (run) => {
    setFactoryBusy(true)
    setFactoryError('')
    try {
      const battle = await factoryBattle(run)
      setGame((g) => ({ battle, ...factoryFoe(run), key: (g?.key ?? 0) + 1 }))
    } catch (e) {
      setFactoryError(e.message || 'Não foi possível iniciar a batalha. Tente novamente.')
    } finally {
      setFactoryBusy(false)
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
        // Uma tela de vitória só: a do resultado do andar (XP, níveis, dinheiro), logo depois.
        endNote = ''
      } else {
        // Com uma Escape Rope na Bolsa, o time foge (pouco HP) e a corrida continua.
        const data = await getFactoryData()
        const escaped = escapeRope(run, data, factoryAfter(game.battle, run))
        if (escaped) {
          saveFactory({ ...factory, run: escaped })
          endNote = `🪢 ${t('Escape Rope! O time fugiu com pouco HP e a corrida continua.')}`
        } else {
          const after = endRun(factory, run)
          saveFactory(after)
          endNote = t('A corrida acabou no andar {0}: +{1} moedas. Recorde: andar {2}.').replace('{0}', run.floor).replace('{1}', after.last.coins).replace('{2}', after.best)
        }
      }
      // A batalha vira a tela da corrida sozinha (resultado, Enfermeira Joy, captura, carta, loja e mapa), no mesmo lugar.
      setGame((g) => (g ? { ...g, endNote, next: { label: `${t('Continuar')} →`, onClick: openFactory } } : g))
      const key = game.key
      setTimeout(() => setGame((g) => (g && !g.factory && g.key === key ? { factory: true, key: key + 1 } : g)), won ? 700 : 1800)
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
    <div className="space-y-6">
      <PageHeader
        eyebrow="Arena"
        title="Batalha"
        subtitle={
          factoryMode || game?.factory || challenge?.kind === 'factory'
            ? 'Pokelike: sem nível máximo. Batalha por turnos como nos jogos, com o computador jogando pelo outro lado.'
            : 'Nível máximo 50. Batalha por turnos como nos jogos: seu time contra o de um amigo (ou um aleatório), com o computador jogando pelo outro lado.'
        }
      />
      <Link to="/batalha" className="inline-flex items-center gap-1 text-sm text-muted hover:text-text">
        <Icon name="back" size={16} /> Centro de Batalha
      </Link>
      {game?.factory ? (
        <>
          {factoryError && <p className="text-sm font-bold text-red-500">{t(factoryError)}</p>}
          <div key={`factory-${game.key}`} className="screen-fade"><FactoryScreen key={game.key} onBattle={factoryFloor} onExit={() => setGame(null)} busy={factoryBusy} /></div>
        </>
      ) : !game || !hit ? (
        <Setup onFactory={setFactoryMode} onFactoryRun={openFactory} onStart={(battle, foeName, foeTrainer = null, challenge = null) => setGame({ battle, foeName, foeTrainer, challenge, key: 1 })} />
      ) : (
        <Battle
          key={game.key}
          // O lugar: o ginásio do líder, a Liga (Elite Four e Campeão) ou o da Battle Factory.
          battle={Object.assign(game.battle, { scene: game.battle.scene ?? sceneOfBoss(challenge?.kind) ?? undefined })}
          foeName={game.foeName}
          foeTrainer={game.foeTrainer}
          hit={hit}
          onExit={() => setGame(null)}
          onAgain={['league', 'tower', 'factory'].includes(challenge?.kind) ? null : again}
          // Na Battle Factory, sem chefe: a música do lugar.
          keepMine={challenge?.kind === 'factory'}
          vs={foeLeader ?? (VS_KIND[challenge?.boss?.kind] ? challenge.boss : null)}
          music={!foeLeader && !challenge?.boss && challenge?.kind === 'factory' ? placeMusic(game.battle.scene) : musicOf(foeLeader ?? challenge?.boss)}
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
    </div>
  )
}
