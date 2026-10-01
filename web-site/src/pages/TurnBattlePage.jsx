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
import { active, canGimmick, canUseItem, effectLabel, forfeit, ITEMS, lineOf, MAX_MOVES, maxPower, moveEffect, newBattle, playTurn, replace, STAT_NAMES, switchMatchup, usableMoves, weaknesses, Z_MOVES, zPower } from '../lib/turnBattle'
import Sprite from '../components/Sprite'

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
  const [mine, setMine] = useState('')
  const [friend, setFriend] = useState(RANDOM)
  const [friendTeams, setFriendTeams] = useState([])
  const [theirs, setTheirs] = useState('')
  const [busy, setBusy] = useState(false)

  const pickFriend = (uid) => {
    setFriend(uid)
    setTheirs('')
    setFriendTeams(null)
    if (uid === RANDOM) setFriendTeams([])
    else teamsOf(uid).then((x) => setFriendTeams(x.filter((y) => teamMembers(y).length))).catch(() => setFriendTeams([]))
  }
  const myTeam = myTeams.find((x) => x.id === mine)
  const theirTeam = friendTeams?.find((x) => x.id === theirs)
  const ready = myTeam && (friend === RANDOM || theirTeam)
  const start = async () => {
    setBusy(true)
    const seed = Math.floor(Math.random() * 2 ** 31)
    const random = seededRandom(seed)
    const foeName = friend === RANDOM ? '' : friends.find((f) => f.uid === friend)?.name ?? ''
    const [a, b] = await Promise.all([battleMons(teamMembers(myTeam)), battleMons(friend === RANDOM ? await randomTeam(random) : teamMembers(theirTeam))])
    setBusy(false)
    if (a.length && b.length) onStart(newBattle(a, b, random), foeName)
  }

  return (
    <section className={`${CARD} space-y-4`}>
      {!myTeams.length ? (
        <p className="text-muted">Monte um time em Times para batalhar.</p>
      ) : (
        <label className="block space-y-1.5">
          <span className="text-sm font-semibold text-muted">Seu time</span>
          <select value={mine} onChange={(e) => setMine(e.target.value)} className={SELECT}>
            <option value="">Escolha…</option>
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
        <select value={friend} onChange={(e) => pickFriend(e.target.value)} className={SELECT} data-no-translate>
          <option value={RANDOM}>{t('🎲 Time aleatório')}</option>
          {friends.map((f) => (
            <option key={f.uid} value={f.uid}>
              {f.name}
            </option>
          ))}
        </select>
      </label>
      {friend !== RANDOM &&
        (friendTeams === null ? (
          <p className="text-sm text-muted">...</p>
        ) : !friendTeams.length ? (
          <p className="text-sm text-muted">Esse amigo ainda não montou nenhum time.</p>
        ) : (
          <label className="block space-y-1.5">
            <span className="text-sm font-semibold text-muted">Time do amigo</span>
            <select value={theirs} onChange={(e) => setTheirs(e.target.value)} className={SELECT}>
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
        O computador joga pelo adversário. Batalha simplificada: só golpes de dano (com PP, precisão, prioridade e crítico), sem status nem clima.
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
      <div className="h-2.5 flex-1 overflow-hidden rounded-full border border-slate-700 bg-slate-700">
        <div className="h-full rounded-full transition-[width] duration-700 ease-out" style={{ width: `${pct}%`, background: color }} />
      </div>
    </div>
  )
}

/** Selo do status, como no Showdown. */
const STATUS_BADGE = { brn: '#EE8130', par: '#C9A400', psn: '#A33EA1', tox: '#7B2E7A', slp: '#78716C', frz: '#4FB3D9' }

function InfoBox({ mon, hp, mine, status, dmax }) {
  return (
    <div className="w-full rounded-xl rounded-br-3xl border-4 border-slate-700 bg-amber-50 px-3 py-1.5 text-slate-900 shadow-lg">
      <div className="flex items-baseline justify-between gap-2 font-black">
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
        <span className="shrink-0 text-sm">{`Nv.${mon.level}`}</span>
      </div>
      <HpBar hp={hp} max={mon.maxHp} />
      {mine && <div className="text-right text-sm font-black tabular-nums">{`${hp}/${mon.maxHp}`}</div>}
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
        style={dmax ? { transform: 'scale(1.45)', filter: 'drop-shadow(0 0 6px #e11d48) drop-shadow(0 0 2px #e11d48)' } : undefined}
      >
        <div ref={ref} className="relative h-full w-full">
          {p && <Sprite key={`${p.id}-${mon.shiny}`} path={mon.shiny ? shinyPath(p.sprite) : p.sprite} box={p.box} fill={0.95} align="bottom" back={back} alt={mon.name} />}
        </div>
      </div>
    </div>
  )
})

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
function Battle({ battle, foeName, hit, onExit, onAgain }) {
  const byId = usePokemonIndex()
  const [, redraw] = useState(0)
  // O que está na tela (anda atrás do motor enquanto os eventos passam).
  const [shown, setShown] = useState(() => ({
    active: [battle.sides[0].active, battle.sides[1].active],
    hp: battle.sides.map((s) => s.team.map((m) => m.hp)),
    status: battle.sides.map((s) => s.team.map(() => '')),
    fainted: [false, false],
    // Forma na tela (Mega / Gigantamax) e se está dinamaxizado.
    form: [null, null],
    dmax: [false, false],
  }))
  const [text, setText] = useState(() => (foeName ? t('{0} quer batalhar!').replace('{0}', foeName) : t('Um treinador quer batalhar!')))
  const [busy, setBusy] = useState(false)
  const [menu, setMenu] = useState('main') // main | fight | party | bag
  const [item, setItem] = useState(null) // item da Bolsa escolhido (falta escolher em quem)
  const skip = useRef(null)
  const sprites = [useRef(null), useRef(null)]
  const [effect, setEffect] = useState(null) // {plan, color} da animação do golpe
  const [flash, setFlash] = useState(0)
  const effectKey = useRef(0)
  const field = useRef(null)
  // A animação de cada golpe (estilo, símbolo e variação).
  const anims = useRef(null)
  useEffect(() => {
    getMoveAnims()
      .then((table) => (anims.current = table))
      .catch(() => {})
  }, [])

  // before: o id de cada lado antes do turno (o motor já mudou a Mega; a tela muda no evento).
  const play = async (events, before = null) => {
    setBusy(true)
    if (before) setShown((s) => ({ ...s, form: s.form.map((f, i) => (s.dmax[i] ? f : before[i])) }))
    for (const e of events) {
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
        if (plan.flash) setTimeout(() => setFlash((n) => n + 1), 250)
        await wait(plan.duration + 80)
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
        setText(format(e))
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
      }
    }
    setBusy(false)
    setMenu(battle.needSwitch ? 'party' : 'main')
    redraw((n) => n + 1)
  }

  // Seu Pokémon desmaiou: a lista abre sozinha.
  useEffect(() => {
    if (!busy && battle.needSwitch) setText(t('Escolha o próximo Pokémon.'))
  }, [busy, battle.needSwitch])

  const me = battle.sides[0].team[shown.active[0]]
  const foe = battle.sides[1].team[shown.active[1]]
  const current = active(battle, 0)
  const usable = usableMoves(current)
  const waiting = !busy && battle.winner == null

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

  const fight = (i) => {
    const before = [active(battle, 0).id, active(battle, 1).id]
    play(playTurn(battle, { move: i }, hit), before)
  }
  // A mecânica do set (montador) ativa sozinha no primeiro ataque, como nos
  // jogos: o menu já mostra os Z-Moves / Max Moves que vão sair.
  const auto = current.gimmick && !battle.gimmicks[0] ? current.gimmick : null
  const maxed = current.dmax > 0 || (auto === 'dmax' && canGimmick(battle, 0, 'dmax'))
  const choose = (i) => {
    if (item) {
      setItem(null)
      return play(playTurn(battle, { item, target: i }, hit))
    }
    return play(battle.needSwitch ? replace(battle, i) : playTurn(battle, { switch: i }, hit))
  }
  const run = () => {
    if (window.confirm(t('Fugir da batalha? Conta como derrota.'))) play(forfeit(battle))
  }

  return (
    <div className="mx-auto max-w-3xl select-none">
      {/* Campo */}
      <div
        ref={field}
        className="battle-field relative aspect-[16/10] overflow-hidden sm:aspect-[16/9] rounded-t-2xl border-4 border-b-0 border-slate-800"
        style={{ background: 'linear-gradient(#bfe6ff 0%, #e8f6ff 45%, #b9e59a 46%, #8fd16b 100%)' }}
      >
        <div className="absolute top-[6%] left-[4%] w-[46%] max-w-[260px]">
          <InfoBox mon={foe} hp={shown.hp[1][shown.active[1]]} status={shown.status[1][shown.active[1]]} dmax={shown.dmax[1]} />
        </div>
        <div className="absolute top-[38%] right-[6%] h-[9%] w-[35%] rounded-[50%] bg-green-800/35" />
        <div className="absolute top-[3%] right-[10%] w-[27%]">
          <BattleSprite ref={sprites[1]} mon={foe} id={shown.form[1] ?? foe.id} dmax={shown.dmax[1]} fainted={shown.fainted[1]} byId={byId} />
        </div>
        <div className="absolute bottom-[3%] left-[3%] h-[11%] w-[41%] rounded-[50%] bg-green-800/35" />
        <div className="absolute bottom-[5%] left-[7%] w-[33%]">
          <BattleSprite ref={sprites[0]} mon={me} id={shown.form[0] ?? me.id} dmax={shown.dmax[0]} back fainted={shown.fainted[0]} byId={byId} />
        </div>
        {effect && <MoveFx key={effect.key} plan={effect.plan} color={effect.color} />}
        {flash > 0 && <div key={`flash-${flash}`} className="battle-flash pointer-events-none absolute inset-0 bg-white" />}
        <div className="absolute right-[4%] bottom-[8%] w-[46%] max-w-[260px]">
          <InfoBox mon={me} hp={shown.hp[0][shown.active[0]]} status={shown.status[0][shown.active[0]]} dmax={shown.dmax[0]} mine />
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
          {text}
        </button>
        {waiting && menu === 'main' && !battle.needSwitch && (
          <div className="grid grid-cols-2 gap-1.5 rounded-xl border-4 border-slate-600 bg-white p-2 sm:w-64">
            <MenuButton onClick={() => (usable.length ? setMenu('fight') : fight(-1))}>LUTAR</MenuButton>
            <MenuButton onClick={() => setMenu('bag')}>BOLSA</MenuButton>
            <MenuButton onClick={() => (setItem(null), setMenu('party'))}>POKÉMON</MenuButton>
            <MenuButton onClick={run}>FUGIR</MenuButton>
          </div>
        )}
        {waiting && menu === 'fight' && (
          <div className="grid grid-cols-2 gap-1.5 rounded-xl border-4 border-slate-600 bg-white p-2 sm:w-96" data-testid="moves">
            <Weak mon={rival} list={foeWeak} />
            {current.moves.map((m, i) => {
              const eff = moveEffect(hit, current, rival, m)
              const z = auto === 'z' && canGimmick(battle, 0, 'z', i)
              const max = maxed && m.category !== 'status'
              return (
                <button
                  key={m.slug}
                  type="button"
                  disabled={m.pp <= 0}
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
                  disabled={item ? !canUseItem(battle, 0, item, i) : m.hp <= 0 || isActive}
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
          <Button color="linear-gradient(90deg,#DC2626,#9333EA)" onClick={onAgain}>
            Batalhar de novo
          </Button>
          <Button color="#546E7A" onClick={onExit}>
            Trocar os times
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

function MenuButton({ children, onClick, className = '' }) {
  return (
    <button type="button" onClick={onClick} className={`cursor-pointer rounded-lg px-3 py-2 text-left font-black text-slate-900 hover:bg-amber-100 ${className}`}>
      {`▸ ${t(children)}`}
    </button>
  )
}

export default function TurnBattlePage() {
  const user = useAuth((s) => (s.status === 'signedIn' ? s.user : null))
  const [game, setGame] = useState(null) // {battle, foeName, key, setup}
  const [hit, setHit] = useState(null)

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
    setGame({ ...game, battle: newBattle(fresh(b.sides[0].team), fresh(b.sides[1].team), random), key: game.key + 1 })
  }

  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <PageHeader title="Batalha" subtitle="Batalha por turnos como nos jogos: seu time contra o de um amigo (ou um aleatório), com o computador jogando pelo outro lado." />
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
