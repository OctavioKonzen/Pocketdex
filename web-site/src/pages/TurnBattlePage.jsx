import {simulatorDispose} from '../lib/battleSimulator'
// Batalha por turnos (como nos jogos de GBA), igual ao app
// (turn_battle_screen.dart): seu time contra o time de um amigo (ou um time
// aleatório), com o computador jogando pelo outro lado. O motor fica em
// lib/turnBattle.js e os Pokémon são montados em lib/battleSetup.js.

import { forwardRef, useEffect, useMemo, useRef, useState } from 'react'
import { Link, useLocation } from 'react-router-dom'
import PokeIcon from '../components/PokeIcon'
import { Button, Empty, Icon, PageHeader } from '../components/ui'
import { teamsOf, useAuth } from '../lib/auth'
import { battleHitter, battleMons, randomTeam } from '../lib/battleSetup'
import { friendsOnly, useFriends } from '../lib/friends'
import { getMoveAnims, getTypes, shinyPath, spriteUrl } from '../lib/data'
import { t } from '../lib/i18n'
import { seededRandom } from '../lib/league'
import { ALL_TYPES, damageTaken, typeColor } from '../lib/pokemon'
import { usePokemonIndex } from '../lib/pokemonIndex'
import { useStore } from '../lib/store'
import { teamMembers } from '../lib/teamBattle'
import { fxPlan, moveAnim } from '../lib/moveAnim'
import { active, canGimmick, canUseItem, effectLabel, forfeit, ITEMS, lineOf, MAX_MOVES, maxPower, moveEffect, newBattle, playTurn, replace, startBattle, STAT_NAMES, switchMatchup, usableMoves, weaknesses, Z_MOVES, zPower } from '../lib/turnBattle'
import Sprite from '../components/Sprite'
import {simulatorTargets} from '../lib/battleSimulator'
import {newPartyBattle, playPartyTurn, describeEvents} from '../lib/partyBattle'

const CARD = 'rounded-2xl bg-card p-5 shadow'
const SELECT = 'w-full rounded-xl bg-surface px-3 py-2.5 outline-none focus:ring-2 focus:ring-sky-400'
const RANDOM = '__random__'
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
function Setup({ onStart }) {
  const teams = useStore((s) => s.teams)
  const list = useFriends((s) => s.list)
  const friends = useMemo(() => friendsOnly(list), [list])
  const myTeams = teams.filter((x) => teamMembers(x).length)
  const [mine, setMine] = useState(RANDOM)
  const [friend, setFriend] = useState(RANDOM)
  const [friendTeams, setFriendTeams] = useState([])
  const [theirs, setTheirs] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [count, setCount] = useState(1)
  const [difficulty, setDifficulty] = useState('normal')
  const [npcPartner, setNpcPartner] = useState(false)

  const pickFriend = (uid) => {
    setFriend(uid)
    setTheirs('')
    setFriendTeams(null)
    if (uid === RANDOM) setFriendTeams([])
    else teamsOf(uid).then((x) => setFriendTeams(x.filter((y) => teamMembers(y).length))).catch(() => setFriendTeams([]))
  }
  const myTeam = myTeams.find((x) => x.id === mine)
  const theirTeam = friendTeams?.find((x) => x.id === theirs)
  const ready = (mine === RANDOM || myTeam && teamMembers(myTeam).length >= (npcPartner ? 1 : count)) && (friend === RANDOM || theirTeam && teamMembers(theirTeam).length >= count)
  const start = async () => {
    setBusy(true)
    setError('')
    try {
    const seed = Math.floor(Math.random() * 2 ** 31)
    const random = seededRandom(seed)
    const foeName = friend === RANDOM ? '' : friends.find((f) => f.uid === friend)?.name ?? ''
    const [a, b] = await Promise.all([battleMons(mine === RANDOM ? await randomTeam(random, difficulty) : teamMembers(myTeam)), battleMons(friend === RANDOM ? await randomTeam(random, difficulty) : teamMembers(theirTeam))])
    if (a.length && b.length) {
      if (count === 1) onStart(newBattle(a,b,random),foeName)
      else {
        const rosters = {me:a,npc3:b}
        const own = Array.from({length:count},(_,i) => i && npcPartner ? `npc${i}` : 'me')
        for (const uid of own.filter(x => x !== 'me')) rosters[uid] = await battleMons(await randomTeam(random, difficulty))
        onStart(newPartyBattle(rosters,[...own,...Array(count).fill('npc3')],count,random),foeName)
      }
    }
    } catch(e) {setError(e.message || 'Não foi possível iniciar a batalha. Tente novamente.')}
    finally {setBusy(false)}
  }

  return (
    <section className={`${CARD} space-y-4`}>
      {error && <p role="alert" className="text-red-400">{error}</p>}
      <label className="block space-y-1.5"><span>Formato</span><select aria-label="Formato" className={SELECT} value={count} onChange={e=>setCount(Number(e.target.value))}>
        <option value={1}>Individual</option><option value={2}>Dupla</option><option value={3}>Tripla</option>
      </select></label>
      {count > 1 && <label className="flex gap-2"><input type="checkbox" checked={npcPartner} onChange={e=>setNpcPartner(e.target.checked)} />Jogar com parceiros NPC (desmarcado: você controla todos)</label>}
      {(
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
          {friends.map((f) => (
            <option key={f.uid} value={f.uid}>
              {f.name}
            </option>
          ))}
        </select>
      </label>
      {(friend === RANDOM || npcPartner) && <label className="block space-y-1.5"><span>Dificuldade dos NPCs</span><select aria-label="Dificuldade dos NPCs" className={SELECT} value={difficulty} onChange={e=>setDifficulty(e.target.value)}><option value="normal">Normal · IVs e EVs aleatórios</option><option value="hard">Difícil · sets competitivos</option></select></label>}
      {friend !== RANDOM &&
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
      <p className="text-xs text-muted">
        O computador joga pelo adversário. Golpes com PP, precisão, prioridade, crítico, status, mudanças de atributo e clima.
      </p>
      <Button color="linear-gradient(90deg,#DC2626,#9333EA)" className="w-full" disabled={busy || !ready} onClick={start}>
        {busy ? 'Preparando...' : '⚔️ Começar batalha'}
      </Button>
    </section>
  )
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
const STATUS_BADGE = { brn: '#EE8130', par: '#C9A400', psn: '#A33EA1', tox: '#7B2E7A', slp: '#78716C', frz: '#4FB3D9' }

function InfoBox({ mon, hp, mine, status, dmax, hpTestId }) {
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
      {(mine || hpTestId) && <div data-testid={hpTestId} className="text-right text-[11px] font-black tabular-nums">{`${hp}/${mon.maxHp}`}</div>}
    </div>
  )
}

// O Pokémon no campo: o GIF do nosso banco (de frente ou de costas), todos do
// mesmo tamanho, como na Pokédex. Igual ao app.
// Mega: a forma nova; Dinamax: gigante e avermelhado (Gigantamax: a forma dele).
const BattleSprite = forwardRef(function BattleSprite({ mon, id, back, fainted, dmax, byId }, ref) {
  const p = byId?.get(id) ?? byId?.get(mon.id)
  return (
    <div className={`aspect-square w-full transition-all duration-500 ${fainted ? 'translate-y-10 opacity-0' : ''}`}>
      <div
        className="h-full w-full origin-bottom transition-transform duration-700"
        style={dmax ? { transform: 'scale(1.35)', filter: 'drop-shadow(0 0 6px #e11d48) drop-shadow(0 0 2px #e11d48)' } : undefined}
      >
        <div ref={ref} className="relative h-full w-full">
          {p && <Sprite key={`${p.id}-${mon.shiny}`} path={mon.shiny ? shinyPath(p.sprite) : p.sprite} box={p.box} fill={0.95} align="bottom" back={back} battle alt={mon.name} />}
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

/** A batalha em si. */
export function Battle(props) {
  return props.battle.mode && props.battle.mode !== 'singles' ? <MultiBattle {...props} /> : <SingleBattle {...props} />
}
function SingleBattle({ battle, foeName, hit, onExit, onAgain, online = null }) {
  const byId = usePokemonIndex()
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
  const seenRound = useRef(online?.round)
  useEffect(() => { live.current = true; return () => { live.current = false; skip.current?.() } }, [])
  useEffect(() => {
    getMoveAnims()
      .then((table) => (anims.current = table))
      .catch(() => {})
  }, [])

  // before: o id de cada lado antes do turno (o motor já mudou a Mega; a tela muda no evento).
  const play = async (events, before = null) => {
    actionBusy.current = true
    setBusy(true)
    try {
    if (before) setShown((s) => ({ ...s, form: s.form.map((f, i) => (s.dmax[i] ? f : before[i])) }))
    for (const e of events) {
      if (!live.current) return
      if (e.t === 'attack') {
        // Cada golpe com a sua animação (moveAnim.js), nas cores do tipo.
        const [kind, icon, variant] = anims.current?.[e.slug] ?? [moveAnim(e.slug, e.type, e.category), null, 0]
        // Golpe de status: anéis em quem usa (Swords Dance, Recover) ou no alvo (Will-O-Wisp, Toxic).
        const rules = active(battle, e.side).moves.find((m) => m.slug === e.slug)?.rules
        const self = e.category === 'status' && (rules?.t === 'self' || rules?.h)
        const plan =
          e.category === 'status'
            ? fxPlan('rings', e.type, e.side, CENTER[e.side], CENTER[self ? e.side : 1 - e.side], self ? '✨' : null, variant)
            : fxPlan(kind, e.type, e.side, CENTER[e.side], CENTER[1 - e.side], icon, variant)
        pulse(sprites[e.side].current, CONTACT.has(kind) ? `battle-dash-${e.side}` : `battle-lunge-${e.side}`, 450)
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
        setShown((s) => ({
          ...s,
          active: s.active.map((a, i) => (i === e.side ? e.index : a)),
          fainted: s.fainted.map((f, i) => (i === e.side ? false : f)),
          form: s.form.map((f, i) => (i === e.side ? null : f)),
          dmax: s.dmax.map((d, i) => (i === e.side ? false : d)),
        }))
      } else if (e.t === 'mega') {
        setFlash((n) => n + 1)
        setShown((s) => ({ ...s, form: s.form.map((f, i) => (i === e.side ? e.id : f)) }))
        await wait(500)
      } else if (e.t === 'dmax') {
        setShown((s) => ({ ...s, form: s.form.map((f, i) => (i === e.side ? e.id : f)), dmax: s.dmax.map((d, i) => (i === e.side ? e.on : d)) }))
        await wait(700)
      } else if (e.t === 'tera') {
        setFlash((n) => n + 1)
        await wait(400)
      } else if (e.t === 'weather') {
        // O cenário muda com o clima (céu, chão, chuva caindo...).
        setShown((s) => ({ ...s, weather: e.weather }))
        await wait(600)
      }
    }
    } finally {
      actionBusy.current = false
      if (live.current) {
        setShown({active:battle.sides.map(s=>s.active),hp:battle.sides.map(s=>s.team.map(m=>m.hp)),status:battle.sides.map(s=>s.team.map(m=>m.status)),fainted:battle.sides.map(s=>s.team[s.active].hp<=0),form:battle.sides.map(s=>s.team[s.active].id),dmax:battle.sides.map(s=>s.team[s.active].dmax>0),weather:battle.weather})
        setEffect(null)
        skip.current = null
        setBusy(false)
        setMenu(battle.needSwitch ? 'party' : 'main')
        redraw((n) => n + 1)
      }
    }
  }

  // Começo: as habilidades de clima de quem entrou (Drizzle, Drought...).
  const opening = useRef(null)
  useEffect(() => {
    if (online) return
    const events = (opening.current ??= startBattle(battle))
    if (!events.length) return
    actionBusy.current = true
    setBusy(true)
    const id = setTimeout(() => play(events), STEP_MS)
    return () => clearTimeout(id)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [battle])

  useEffect(() => {
    if (!online || online.round === seenRound.current) return
    seenRound.current = online.round
    const events = online.events, before = online.before
    setBusy(true)
    queued.current = queued.current.then(() => live.current ? play(events, before) : undefined).catch(() => { if(live.current) setText(t('Não foi possível exibir esta ação.')) })
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
        <div className="absolute top-[6%] left-[4%] w-[46%] max-w-[260px]">
          <InfoBox mon={foe} hp={shown.hp[1][shown.active[1]]} status={shown.status[1][shown.active[1]]} dmax={shown.dmax[1]} hpTestId={online ? "online-hp-" + (1 - online.side) : undefined} />
        </div>
        {/* O inimigo fica mais longe: menor e com os pés na frente do meio da plataforma (pisando nela, como o seu). */}
        <div className="absolute right-[11%] bottom-[53%] w-[25%]">
          <BattleSprite ref={sprites[1]} mon={foe} id={shown.form[1] ?? foe.id} dmax={shown.dmax[1]} fainted={shown.fainted[1]} byId={byId} />
        </div>
        <div className="absolute bottom-[5%] left-[7%] w-[33%]">
          <BattleSprite ref={sprites[0]} mon={me} id={shown.form[0] ?? me.id} dmax={shown.dmax[0]} back fainted={shown.fainted[0]} byId={byId} />
        </div>
        <WeatherFx weather={shown.weather} />
        {effect && <MoveFx key={effect.key} plan={effect.plan} color={effect.color} />}
        {flash > 0 && <div key={`flash-${flash}`} className="battle-flash pointer-events-none absolute inset-0 bg-white" />}
        <div className="absolute right-[4%] bottom-[8%] w-[46%] max-w-[260px]">
          <InfoBox mon={me} hp={shown.hp[0][shown.active[0]]} status={shown.status[0][shown.active[0]]} dmax={shown.dmax[0]} mine hpTestId={online ? "online-hp-" + online.side : undefined} />
        </div>
      </div>

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
        {waiting && !online?.waitForSwitch && menu === 'main' && !battle.needSwitch && (
          <div className="grid grid-cols-2 gap-1.5 rounded-xl border-4 border-slate-600 bg-white p-2 sm:w-72">
            <MenuButton onClick={() => (usable.length ? setMenu('fight') : fight(-1))}>LUTAR</MenuButton>
            <MenuButton disabled={Boolean(online)} onClick={() => setMenu('bag')}>BOLSA</MenuButton>
            <MenuButton onClick={() => (setItem(null), setMenu('party'))}>POKÉMON</MenuButton>
            <MenuButton onClick={run}>FUGIR</MenuButton>
          </div>
        )}
        {waiting && menu === 'fight' && (
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
            {ITEMS.map((it) => {
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
                    <div className="text-xs text-muted">{it.revive ? t('Revive com metade do HP') : t('Recupera {0} de HP').replace('{0}', it.heal)}</div>
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

      {!busy && battle.winner != null && (
        <div className="mt-4 flex flex-wrap justify-center gap-3">
          {!online && <Button color="linear-gradient(90deg,#DC2626,#9333EA)" onClick={onAgain}>
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
  const [error,setError] = useState('')
  const [history,setHistory] = useState([])
  const [,redraw] = useState(0)
  const choicePhase = JSON.stringify([state.turn, online?.round, own.wait, owned.map(slot => [slot.slot, slot.index, slot.forceSwitch, slot.pass])])
  useEffect(()=>{setChoices({});setError('')},[choicePhase])
  const forced = own.slots.some(slot=>slot.forceSwitch)
  const automatic = slot => own.wait ? {kind:'wait',index:0} : slot.pass || forced && !slot.forceSwitch ? {kind:'pass',index:0} : null
  const picked = slot => automatic(slot) || choices[slot.slot]
  const locked = Boolean(online?.locked) || state.winner != null
  const setChoice = (slot,kind,index,gimmick = choices[slot.slot]?.gimmick || '') => {
    const result = kind === 'move' ? simulatorTargets(battle,side,slot.slot,index,gimmick) : {targets:[],automatic:true}
    const target = result.targets.find(t=>!t.ally) || result.targets[0]
    setChoices(old=>({...old,[slot.slot]:{kind,index,gimmick:kind === 'move' ? gimmick : '',target:target?.loc || 0}}))
  }
  const send = () => {
    const submitted = owned.map(slot=>({seat:side*count+slot.slot,...picked(slot)}))
    const switches = submitted.filter(a=>a.kind === 'switch').map(a=>a.index)
    if (new Set(switches).size !== switches.length) {setError('Escolha Pokémon diferentes para as substituições.');return}
    const action = {kind:'team',choices:submitted}
    if (online) {online.onAction(action);return}
    try {
      const events = playPartyTurn(battle,[action])
      for(let attempt=0;attempt<12 && battle.winner == null;attempt++) {
        const s=battle.simulator.state.sides[side]
        const requiresChoice=s.slots.some(slot=>battle.controllers[side][slot.slot] === uid && !s.wait && !slot.pass && (!s.slots.some(x=>x.forceSwitch) || slot.forceSwitch))
        if(requiresChoice) break
        const waiting={kind:'team',choices:s.slots.filter(slot=>battle.controllers[side][slot.slot] === uid).map(slot=>({seat:side*count+slot.slot,kind:s.wait?'wait':'pass',index:0}))}
        events.push(...playPartyTurn(battle,[waiting]))
      }
      setHistory(describeEvents(events));setChoices({});redraw(x=>x+1)
    } catch(e) {setError(e.message)}
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
    {fieldSlots(teamSide).map(slot=>{const mon=battle.sides[teamSide].team[slot.index];return <BattleSprite key={slot.slot} mon={mon} id={mon.dmax && mon.gmax || mon.id} back={teamSide===side} fainted={mon.hp<=0} dmax={mon.dmax>0} byId={byId}/>})}
  </div>
  return <section className="mx-auto max-w-3xl space-y-2">
    <div className="battle-field relative aspect-[16/10] overflow-hidden border-4 border-slate-800" data-testid="multi-battle-field" style={{aspectRatio:count===3?'1':'16 / 10',minHeight:count===3?'22rem':'14rem'}}>
      <BattleBackground weather={battle.weather}/>{sprites(1-side)}{sprites(side)}{info(1-side)}{info(side)}<WeatherFx weather={battle.weather}/>
    </div>
    <p className="rounded-xl bg-card p-3 font-bold" data-testid="multi-turn" data-turn={state.turn} data-round={online?.round ?? state.turn}>{online?.message || (state.winner != null ? state.winner === -1 ? 'Empate!' : state.winner === side ? 'Você venceu!' : 'A equipe adversária venceu!' : `Turno ${state.turn}: escolha uma ação por Pokémon.`)}</p>
    {state.winner == null && owned.map(slot=>{
      const mon=battle.sides[side].team[slot.index], action=picked(slot)
      const targets=action?.kind === 'move' ? simulatorTargets(battle,side,slot.slot,action.index,action.gimmick) : {targets:[],automatic:true}
      const req=slot.request
      const mechanic=battle.sides[side].team[slot.index].gimmick
      const available=mechanic==='mega'?req?.canMegaEvo:mechanic==='tera'?req?.canTerastallize:mechanic==='dmax'?req?.canDynamax:mechanic==='z'?req?.canZMove?.[action?.index ?? 0]:false
      const reserved=Object.entries(choices).some(([other,c])=>Number(other)!==slot.slot && c.gimmick===mechanic)
      return <div key={slot.slot} className="space-y-2 rounded-xl border-4 border-slate-800 bg-slate-800 p-2 text-white" data-testid="multi-actions">
        <h3 className="font-bold">{mon.name} · posição {slot.slot+1}</h3>
        {automatic(slot) ? <p>{own.wait ? 'Aguardando as substituições.' : 'Esta posição passa durante a substituição.'}</p> : <>
          {!slot.forceSwitch && <div className="grid grid-cols-2 gap-1.5 rounded-xl border-4 border-slate-600 bg-white p-2" data-testid="multi-moves" aria-label={`Golpes de ${mon.name} ${slot.slot+1}`}>
            {(req?.moves || []).map((m,index)=>{
              const move=mon.moves[index]
              const selected=action?.kind==='move' && action.index===index
              return <button key={`move${index}`} type="button" data-testid={`battle-move-${slot.slot}-${index}`} disabled={locked || m.disabled || m.pp===0}
                aria-pressed={selected} onClick={()=>setChoice(slot,'move',index)}
                className={`rounded-lg border-2 px-2 py-2 text-left text-white disabled:opacity-40 ${selected?'border-amber-300 ring-2 ring-amber-400':'border-transparent'}`}
                style={{background:typeColor(move?.type || 'normal')}}>
                <span className="block text-sm font-black" data-no-translate>{m.move}</span>
                <span className="text-xs">PP {m.pp ?? '—'}/{move?.maxPp ?? m.pp ?? '—'}{selected?' ✓':''}</span>
              </button>
            })}
          </div>}
          {(slot.switchOptions.length>0 || slot.canShift || slot.forceSwitch) && <label className="block text-sm font-bold">POKÉMON
            <select aria-label={`Troca de ${mon.name} ${slot.slot+1}`} className={SELECT} disabled={locked} value={action && action.kind!=='move'?`${action.kind}:${action.index}`:''} onChange={e=>{const [kind,index]=e.target.value.split(':');if(kind)setChoice(slot,kind,Number(index))}}>
              <option value="">{slot.forceSwitch?'Escolha o substituto…':'Trocar Pokémon (gasta a ação)'}</option>
              {slot.switchOptions.map(index=><option key={`switch${index}`} value={`switch:${index}`}>{slot.revival?'Reviver':'Trocar para'} {battle.sides[side].team[index].name}</option>)}
              {slot.canShift && <option value="shift:0">Trocar posição com o centro</option>}
              {slot.forceSwitch && !slot.switchOptions.length && <option value="pass:0">Sem reservas: passar</option>}
            </select>
          </label>}
          {action?.kind==='move' && !targets.automatic && <label className="block">Alvo<select aria-label={`Alvo de ${mon.name} ${slot.slot+1}`} className={SELECT} disabled={locked} value={action.target} onChange={e=>setChoices(old=>({...old,[slot.slot]:{...action,target:Number(e.target.value)}}))}>
            {targets.targets.map(target=><option key={target.loc} value={target.loc}>{target.ally?'Aliado':'Adversário'}: {target.name} · posição {target.slot+1}</option>)}
          </select></label>}
          {action?.kind==='move' && targets.automatic && <p className="text-xs text-muted">O golpe aplica seus alvos automaticamente.</p>}
          {available && <button className="rounded-lg bg-violet-600 px-3 py-2 font-bold text-white disabled:opacity-40" disabled={locked || reserved} aria-pressed={action?.gimmick===mechanic} onClick={()=>setChoice(slot,'move',action?.index ?? 0,action?.gimmick===mechanic?'':mechanic)}>{mechanic==='dmax' && mon.gmax?'Gigantamax':{mega:'Mega',tera:'Terastal',dmax:'Dynamax',z:'Z-Move'}[mechanic]}{action?.gimmick===mechanic?' ✓':''}</button>}
        </>}
      </div>
    })}
    <p className="text-xs text-muted">A reserva é compartilhada pela equipe. Os itens equipados mantêm seus efeitos.</p>
    {(error || online?.error) && <p role="alert" className="text-red-400">{error || online.error}</p>}
    {state.winner==null && <Button className="w-full" disabled={locked || owned.some(slot=>!picked(slot))} onClick={send}>{owned.every(slot=>automatic(slot))?'Continuar':'Confirmar ações'}</Button>}
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
  const [game, setGame] = useState(null) // {battle, foeName, key, setup}
  const [hit, setHit] = useState(null)
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
    const random = seededRandom(Math.floor(Math.random() * 2 ** 31))
    Promise.all([battleMons(fromDraft.mine.map((id) => ({ id }))), battleMons(fromDraft.theirs.map((id) => ({ id })))]).then(([a, b]) => {
      if (alive && a.length && b.length) setGame({ battle: newBattle(a, b, random), foeName: fromDraft.foeName, key: 1 })
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
    const random = seededRandom(Math.floor(Math.random() * 2 ** 31))
    setGame({ ...game, battle: newBattle(fresh(b.sides[0].team), fresh(b.sides[1].team), random, {mode:b.mode,controllers:b.controllers}), key: game.key + 1 })
  }

  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <PageHeader title="Batalha" subtitle="Nível máximo 50. Batalha por turnos como nos jogos: seu time contra o de um amigo (ou um aleatório), com o computador jogando pelo outro lado." />
      <Link to="/amigos" className="inline-flex items-center gap-1 text-sm text-muted hover:text-text">
        <Icon name="back" size={16} /> Amigos
      </Link>
      {!game || !hit ? (
        <Setup onStart={(battle, foeName) => setGame({ battle, foeName, key: 1 })} />
      ) : (
        <Battle key={game.key} battle={game.battle} foeName={game.foeName} hit={hit} onExit={() => setGame(null)} onAgain={again} />
      )}
    </div>
  )
}
