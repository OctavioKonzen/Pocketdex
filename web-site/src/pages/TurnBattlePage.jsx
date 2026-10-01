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
import { getMoveAnims, shinyPath, spriteUrl } from '../lib/data'
import { t } from '../lib/i18n'
import { seededRandom } from '../lib/league'
import { typeColor } from '../lib/pokemon'
import { usePokemonIndex } from '../lib/pokemonIndex'
import { useStore } from '../lib/store'
import { teamMembers } from '../lib/teamBattle'
import { fxPlan, moveAnim } from '../lib/moveAnim'
import { active, canUseItem, forfeit, ITEMS, lineOf, newBattle, playTurn, replace, usableMoves } from '../lib/turnBattle'
import Sprite from '../components/Sprite'

const CARD = 'rounded-2xl bg-card p-5 shadow'
const SELECT = 'w-full rounded-xl bg-surface px-3 py-2.5 outline-none focus:ring-2 focus:ring-sky-400'
const RANDOM = '__random__'
const STEP_MS = 1100

const format = (event) => {
  const [line, args] = lineOf(event)
  return args.reduce((text, arg, i) => text.replace(`{${i}}`, arg), t(line))
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

function InfoBox({ mon, hp, mine }) {
  return (
    <div className="w-full rounded-xl rounded-br-3xl border-4 border-slate-700 bg-amber-50 px-3 py-1.5 text-slate-900 shadow-lg">
      <div className="flex items-baseline justify-between gap-2 font-black">
        <span className="truncate">{mon.name}</span>
        <span className="shrink-0 text-sm">{`Nv.${mon.level}`}</span>
      </div>
      <HpBar hp={hp} max={mon.maxHp} />
      {mine && <div className="text-right text-sm font-black tabular-nums">{`${hp}/${mon.maxHp}`}</div>}
    </div>
  )
}

// Sprites animados no estilo Black & White, de frente e de costas (e shiny),
// do repositório de sprites da PokeAPI: os oficiais do jogo do #1 ao #649 e,
// do #650 em diante (e formas), os do Pokémon Showdown (Smogon Sprite
// Project). Sem sprite animado (ou sem internet) fica o parado de sempre,
// balançando de leve. Igual ao app.
const SPRITES = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon'
const bwAnimated = (id, back, shiny) => {
  if (!(id >= 1)) return null
  const dir = id <= 649 ? `${SPRITES}/versions/generation-v/black-white/animated` : `${SPRITES}/other/showdown`
  return `${dir}/${back ? 'back/' : ''}${shiny ? 'shiny/' : ''}${id}.gif`
}

const BattleSprite = forwardRef(function BattleSprite({ mon, back, fainted, byId }, ref) {
  const p = byId?.get(mon.id)
  const url = bwAnimated(mon.id, back, mon.shiny)
  const box = useRef(null)
  const [boxWidth, setBoxWidth] = useState(0)
  const [gif, setGif] = useState(null) // {url, w} quando carrega; {url, failed} se não der
  useEffect(() => {
    const el = box.current
    if (!el) return undefined
    const observer = new ResizeObserver(() => setBoxWidth(el.clientWidth))
    observer.observe(el)
    return () => observer.disconnect()
  }, [])
  const loaded = gif?.url === url && gif.w
  const failed = !url || (gif?.url === url && gif.failed)
  return (
    <div ref={box} className={`aspect-square w-full transition-all duration-500 ${fainted ? 'translate-y-10 opacity-0' : ''}`}>
      <div ref={ref} className="relative h-full w-full">
        {!failed && (
          // Tamanho de verdade do sprite (os pequenos continuam pequenos, como no jogo).
          <img
            src={url}
            alt={mon.name}
            draggable={false}
            onLoad={(e) => setGif({ url, w: e.currentTarget.naturalWidth })}
            onError={() => setGif({ url, failed: true })}
            className="pixelated pointer-events-none absolute bottom-0 left-1/2 max-w-none -translate-x-1/2"
            style={{ width: loaded ? (gif.w * boxWidth) / 96 : 0, visibility: loaded ? 'visible' : 'hidden' }}
          />
        )}
        {(failed || !loaded) && p && (
          // O seu fica de costas (espelhado), como nos jogos.
          <div className={`battle-idle h-full w-full ${back ? '-scale-x-100' : ''} ${!failed ? 'opacity-0' : ''}`}>
            <Sprite path={mon.shiny ? shinyPath(p.sprite) : p.sprite} box={p.box} fill={0.95} align="bottom" alt={mon.name} />
          </div>
        )}
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
    fainted: [false, false],
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

  const play = async (events) => {
    setBusy(true)
    for (const e of events) {
      if (e.t === 'attack') {
        // Cada golpe com a sua animação (moveAnim.js), nas cores do tipo.
        const [kind, icon, variant] = anims.current?.[e.slug] ?? [moveAnim(e.slug, e.type, e.category), null, 0]
        const plan = fxPlan(kind, e.type, e.side, CENTER[e.side], CENTER[1 - e.side], icon, variant)
        pulse(sprites[e.side].current, CONTACT.has(kind) ? `battle-dash-${e.side}` : `battle-lunge-${e.side}`, 450)
        setEffect({ plan, color: typeColor(e.type), key: ++effectKey.current })
        if (plan.shake) pulse(field.current, 'battle-shake', 650)
        if (plan.flash) setTimeout(() => setFlash((n) => n + 1), 250)
        await wait(plan.duration + 80)
        setEffect(null)
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
        setShown((s) => ({ ...s, active: s.active.map((a, i) => (i === e.side ? e.index : a)), fainted: s.fainted.map((f, i) => (i === e.side ? false : f)) }))
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

  const fight = (i) => play(playTurn(battle, { move: i }, hit))
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
          <InfoBox mon={foe} hp={shown.hp[1][shown.active[1]]} />
        </div>
        <div className="absolute top-[38%] right-[6%] h-[9%] w-[35%] rounded-[50%] bg-green-800/35" />
        <div className="absolute top-[3%] right-[10%] w-[27%]">
          <BattleSprite ref={sprites[1]} mon={foe} fainted={shown.fainted[1]} byId={byId} />
        </div>
        <div className="absolute bottom-[3%] left-[3%] h-[11%] w-[41%] rounded-[50%] bg-green-800/35" />
        <div className="absolute bottom-[5%] left-[7%] w-[33%]">
          <BattleSprite ref={sprites[0]} mon={me} back fainted={shown.fainted[0]} byId={byId} />
        </div>
        {effect && <MoveFx key={effect.key} plan={effect.plan} color={effect.color} />}
        {flash > 0 && <div key={`flash-${flash}`} className="battle-flash pointer-events-none absolute inset-0 bg-white" />}
        <div className="absolute right-[4%] bottom-[8%] w-[46%] max-w-[260px]">
          <InfoBox mon={me} hp={shown.hp[0][shown.active[0]]} mine />
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
            {current.moves.map((m, i) => (
              <button
                key={m.slug}
                type="button"
                disabled={m.pp <= 0}
                onClick={() => fight(i)}
                className="cursor-pointer rounded-lg px-2 py-1.5 text-left text-white disabled:cursor-default disabled:opacity-40"
                style={{ background: typeColor(m.type) }}
                data-no-translate
              >
                <div className="truncate text-sm font-black">{m.name}</div>
                <div className="text-[11px] font-semibold opacity-90">{`PP ${m.pp}/${m.maxPp}`}</div>
              </button>
            ))}
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
          <div className="grid gap-2 sm:grid-cols-2" data-testid="party">
            {battle.sides[0].team.map((m, i) => {
              const isActive = i === battle.sides[0].active
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
                    <div className="truncate font-bold">{m.name}</div>
                    <HpBar hp={m.hp} max={m.maxHp} />
                    <div className="text-xs text-muted tabular-nums">{m.hp > 0 ? `${m.hp}/${m.maxHp}` : t('Desmaiado')}</div>
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
