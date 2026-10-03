import { useEffect, useMemo, useState } from 'react'
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom'
import { Button, Empty, PageHeader } from '../components/ui'
import Sprite from '../components/Sprite'
import { useAuth, errorMessage } from '../lib/auth'
import { useFriends, friendsOnly } from '../lib/friends'
import { useStore } from '../lib/store'
import { usePokemonIndex } from '../lib/pokemonIndex'
import { shinyPath } from '../lib/data'
import { teamMembers } from '../lib/teamBattle'
import { battleMons, battleHitter } from '../lib/battleSetup'
import { seededRandom } from '../lib/league'
import { active, newBattle, playOnlineTurn, startBattle, lineOf, usableMoves, canGimmick, GIMMICKS } from '../lib/turnBattle'
import { inviteBattle, acceptBattle, closeBattle, watchBattles, watchBattle, watchActions, submitAction, pairedActions, unpackTeam, MAX_ROUNDS } from '../lib/onlineBattle'

const CARD = 'rounded-2xl bg-card p-4 shadow'
const SELECT = 'w-full rounded-xl bg-surface p-3'
function useFeed(subscribe, key) {
  const [data, setData] = useState(null)
  const [error, setError] = useState('')
  useEffect(() => {
    let live = true, stop
    setData(null)
    setError('')
    if (!key) return
    subscribe(key, (v) => live && setData(v), (e) => live && setError(errorMessage(e)))
      .then((s) => { if (live) stop = s; else s() }).catch((e) => live && setError(errorMessage(e)))
    return () => { live = false; stop?.() }
  }, [subscribe, key])
  return [data, error]
}
function TeamChoice({ value, onChange }) {
  const teams = useStore((s) => s.teams).filter((t) => teamMembers(t).length)
  return <label className="block space-y-2"><span>Seu time</span><select className={SELECT} value={value} onChange={(e) => onChange(e.target.value)}>
    <option value="">Escolha seu time…</option>{teams.map((t) => <option key={t.id} value={t.id}>{t.name}</option>)}
  </select>{!teams.length && <Link to="/times">Monte um time em Times para batalhar.</Link>}</label>
}
export default function OnlineBattlePage() {
  const { id } = useParams()
  const user = useAuth((s) => s.status === 'signedIn' ? s.user : null)
  if (!user) return <Empty>Entre na sua conta para desafiar amigos.</Empty>
  return id ? <BattleRoom key={id} id={id} user={user} /> : <Lobby user={user} />
}
function Lobby({ user }) {
  const navigate = useNavigate()
  const [params] = useSearchParams()
  const friends = useFriends((s) => friendsOnly(s.list))
  const teams = useStore((s) => s.teams)
  const [friend, setFriend] = useState(params.get('amigo') ?? '')
  const [team, setTeam] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [rooms, feedError] = useFeed(watchBattles, user.uid)
  const invite = async () => {
    setBusy(true); setError('')
    try {
      const f = friends.find((f) => f.uid === friend), t = teams.find((t) => t.id === team)
      if (!f || !t) throw new Error('Escolha um amigo e seu time.')
      navigate('/amigos/online/' + await inviteBattle(f, t))
    } catch (e) { setError(errorMessage(e)) }
    finally { setBusy(false) }
  }
  return <div className="mx-auto max-w-2xl space-y-4">
    <PageHeader title="Batalha online" subtitle="Convide um amigo. Cada jogador controla seu próprio time." />
    <section className={CARD + ' space-y-3'}>
      <label className="block space-y-2"><span>Amigo</span><select className={SELECT} value={friend} onChange={(e) => setFriend(e.target.value)}>
        <option value="">Escolha um amigo…</option>{friends.map((f) => <option key={f.uid} value={f.uid}>{f.name}</option>)}
      </select></label>
      <TeamChoice value={team} onChange={setTeam} />
      <Button disabled={busy || !friend || !team} onClick={invite}>{busy ? 'Enviando…' : 'Desafiar para batalha'}</Button>
      {(error || feedError) && <p role="alert" className="text-red-400">{error || feedError}</p>}
    </section>
    <section className={CARD}><h2 className="mb-3 font-bold">Convites e partidas</h2>
      {rooms == null ? <p>Carregando…</p> : !rooms.length ? <p>Nenhum convite ainda.</p> : rooms.slice(0, 50).map((r) => {
        const other = r.players.find((p) => p !== user.uid)
        return <Link key={r.id} to={'/amigos/online/' + r.id} className="mb-2 flex items-center justify-between gap-3 rounded-xl bg-surface p-3">
          <span>{r.names[other]}</span><span className="text-sm">{r.status === 'pending' ? r.players[0] === user.uid ? 'Convite enviado' : 'Convite recebido' : r.status === 'closed' ? 'Encerrada' : 'Continuar batalha'}</span>
        </Link>
      })}
    </section>
  </div>
}
function BattleRoom({ id, user }) {
  const [room, roomError] = useFeed(watchBattle, id)
  const [actions, actionsError] = useFeed(watchActions, id)
  const teams = useStore((s) => s.teams)
  const [team, setTeam] = useState('')
  const [battle, setBattle] = useState(null)
  const [round, setRound] = useState(0)
  const [logs, setLogs] = useState([])
  const [busy, setBusy] = useState(false)
  const [replaying, setReplaying] = useState(true)
  const [error, setError] = useState('')
  const [gimmick, setGimmick] = useState('')
  const pairs = useMemo(() => room && actions ? pairedActions(actions, room.players) : [], [room, actions])
  const side = room?.players.indexOf(user.uid) ?? 0
  const byId = usePokemonIndex()
  useEffect(() => {
    let live = true
    if (!room || !actions || room.status === 'pending' || !room.teams[room.players[1]]) return
    setReplaying(true)
    const replay = async () => {
      if (room.protocol !== 1) throw new Error('Atualize o PocketDex para abrir esta partida.')
      const mons = await Promise.all(room.players.map((p) => battleMons(teamMembers(unpackTeam(room.teams[p])))))
      if (mons.some((t) => !t.length)) throw new Error('Não foi possível preparar os times.')
      const hit = await battleHitter()
      const b = newBattle(mons[0], mons[1], seededRandom(room.seed))
      let events = startBattle(b)
      for (const pair of pairs) events = [...events, ...playOnlineTurn(b, pair, hit)]
      const text = events.filter((e) => e.t === 'text').map((e) => {
        const args = e.args.map((v) => v && typeof v === 'object' && 'side' in v ? { ...v, side: v.side === side ? 0 : 1 } : v)
        const [line, values] = lineOf({ ...e, args })
        return values.reduce((s, value, i) => s.replace('{' + i + '}', value), line)
      })
      if (live) { setBattle(b); setRound(pairs.length); setLogs(text.slice(-10)); setError(''); setReplaying(false) }
    }
    replay().catch((e) => { if (live) { setError(errorMessage(e)); setReplaying(false) } })
    return () => { live = false }
  }, [room, actions, pairs, side])
  const run = async (fn) => {
    setBusy(true); setError('')
    try { await fn() } catch (e) { setError(errorMessage(e)) } finally { setBusy(false) }
  }
  if (!room) return <div className={CARD}>{roomError || 'Carregando partida…'}</div>
  const other = 1 - side
  const ownAction = actions?.some((a) => a.round === round && a.uid === user.uid)
  const closed = room.status === 'closed'
  const expired = room.createdAt && Date.now() > room.createdAt.toMillis() + 7 * 86400000
  const send = (action) => run(() => submitAction(id, round, action))
  const disabled = busy || ownAction || replaying || closed || expired || round >= MAX_ROUNDS || battle?.winner != null
  const replacing = battle && [0, 1].some((s) => active(battle, s).hp <= 0)
  const mon = battle && active(battle, side)
  return <div className="mx-auto max-w-3xl space-y-4">
    <PageHeader title={'Batalha com ' + room.names[room.players[other]]} subtitle="Escolham uma ação. O turno acontece quando os dois enviarem." />
    <Link to="/amigos/online">← Convites e partidas</Link>
    {(roomError || actionsError || error) && <p role="alert" className="text-red-400">{roomError || actionsError || error}</p>}
    {expired && <p>Este convite expirou. Crie uma nova batalha.</p>}
    {room.status === 'pending' && !expired && <section className={CARD + ' space-y-3'}>
      {side === 0 ? <p>Convite enviado. Aguardando seu amigo aceitar e escolher o time.</p> : <>
        <p>Você recebeu um convite para batalhar!</p><TeamChoice value={team} onChange={setTeam} />
        <Button disabled={busy || !team} onClick={() => run(() => acceptBattle(id, teams.find((t) => t.id === team)))}>Aceitar e entrar</Button>
      </>}
      <Button disabled={busy} onClick={() => run(() => closeBattle(id))}>{side === 0 ? 'Cancelar convite' : 'Recusar'}</Button>
    </section>}
    {closed && <p className={CARD}>{room.endedBy === user.uid ? 'Você encerrou a partida.' : 'Seu amigo encerrou a partida.'}</p>}
    {room.status !== 'pending' && battle && <>
      <div className="grid grid-cols-2 gap-3">{[other, side].map((s) => {
        const p = active(battle, s), row = byId?.get(p.id)
        return <section key={s} className={CARD + ' text-center'}>
          <p className="font-bold">{room.names[room.players[s]]}</p>
          {row && <Sprite path={p.shiny ? shinyPath(row.sprite) : row.sprite} box={row.box} back={s === side} battle className="mx-auto h-40 w-40 max-w-full" />}
          <p>{p.name} {p.status && '(' + p.status.toUpperCase() + ')'}</p>
          <progress className="w-full" value={p.hp} max={p.maxHp} aria-label={'HP de ' + p.name} />
          <p>{p.hp}/{p.maxHp} HP</p>
        </section>
      })}</div>
      <section className={CARD + ' space-y-3'}>
        {battle.winner != null ? <p className="text-xl font-bold">{battle.winner === side ? 'Você venceu! 🎉' : 'Seu amigo venceu!'}</p> :
          round >= MAX_ROUNDS ? <p>Limite de turnos atingido. Partida encerrada.</p> :
          ownAction ? <p>Você já enviou sua ação. Aguardando seu amigo…</p> : <p>{replaying ? 'Atualizando batalha…' : replacing ? mon.hp <= 0 ? 'Escolha outro Pokémon.' : 'Seu amigo precisa trocar de Pokémon.' : 'Escolha sua ação para o turno ' + battle.turn}</p>}
        {!replacing && mon && <><div className="flex flex-wrap gap-2">
          {usableMoves(mon).length ? mon.moves.map((m, i) => <Button key={i} disabled={disabled || m.pp <= 0} onClick={() => send({ kind: 'move', index: i, ...(gimmick ? { gimmick } : {}) })}>{m.name} · PP {m.pp}/{m.maxPp}</Button>) :
            <Button disabled={disabled} onClick={() => send({ kind: 'move', index: -1 })}>Struggle</Button>}
        </div><select aria-label="Mecânica especial" className={SELECT} value={gimmick} onChange={(e) => setGimmick(e.target.value)} disabled={disabled}>
          <option value="">Mecânica do time</option>{GIMMICKS.filter((g) => canGimmick(battle, side, g, 0)).map((g) => <option key={g} value={g}>{g}</option>)}
        </select></>}
        {replacing && mon.hp > 0 && <Button disabled={disabled} onClick={() => send({ kind: 'wait', index: 0 })}>Aguardar troca do amigo</Button>}
        {(!replacing || mon.hp <= 0) && <div className="flex flex-wrap gap-2">{battle.sides[side].team.map((p, i) => <Button key={i} disabled={disabled || p.hp <= 0 || i === battle.sides[side].active} onClick={() => send({ kind: 'switch', index: i })}>Trocar: {p.name} ({p.hp} HP)</Button>)}</div>}
      </section>
      <section className={CARD} aria-live="polite">{logs.map((text, i) => <p key={i} className="text-sm">{text}</p>)}</section>
    </>}
    {room.status === 'active' && <Button disabled={busy} onClick={() => run(() => closeBattle(id))}>Desistir / encerrar partida</Button>}
  </div>
}
