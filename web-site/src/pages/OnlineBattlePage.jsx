import { useEffect, useMemo, useRef, useState } from 'react'
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom'
import { Button, Empty, PageHeader } from '../components/ui'
import { Battle } from './TurnBattlePage'
import { useAuth, errorMessage } from '../lib/auth'
import { useFriends, friendsOnly } from '../lib/friends'
import { useStore } from '../lib/store'
import { teamMembers } from '../lib/teamBattle'
import { battleMons, battleHitter } from '../lib/battleSetup'
import { seededRandom } from '../lib/league'
import { active, newBattle, playOnlineTurn, startBattle } from '../lib/turnBattle'
import { inviteBattle, acceptBattle, closeBattle, watchBattles, watchBattle, watchActions, submitAction, pairedActions, unpackTeam, MAX_ROUNDS, battlePerspective, eventPerspective } from '../lib/onlineBattle'

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
  return <label className="block space-y-2"><span>Seu time</span><select aria-label="Seu time" className={SELECT} value={value} onChange={(e) => onChange(e.target.value)}>
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
  const friendList = useFriends((s) => s.list)
  const friends = friendsOnly(friendList)
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
      <label className="block space-y-2"><span>Amigo</span><select aria-label="Amigo" className={SELECT} value={friend} onChange={(e) => setFriend(e.target.value)}>
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
  const [hit, setHit] = useState(null)
  const [playback, setPlayback] = useState({ events: [], before: null })
  const replayedRound = useRef(null)
  const navigate = useNavigate()
  const [busy, setBusy] = useState(false)
  const [replaying, setReplaying] = useState(true)
  const [error, setError] = useState('')
  const pairs = useMemo(() => room && actions ? pairedActions(actions, room.players) : [], [room, actions])
  const side = room?.players.indexOf(user.uid) ?? 0
  const viewBattle = battle && battlePerspective(battle, side)
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
      startBattle(b)
      const freshEvents = []
      let before = null
      for (const [i, pair] of pairs.entries()) {
        const animate = replayedRound.current != null && i >= replayedRound.current
        if (animate && !before) before = [active(b, side).id, active(b, 1 - side).id]
        const events = playOnlineTurn(b, pair, hit)
        if (animate) freshEvents.push(...events.map((e) => eventPerspective(e, side)))
      }
      if (live) {
        replayedRound.current = pairs.length
        setBattle(b); setRound(pairs.length); setHit(() => hit)
        setPlayback({ events: freshEvents, before }); setError(''); setReplaying(false)
      }
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
  const message = closed ? room.endedBy === user.uid ? 'Você encerrou a partida.' : 'Seu amigo encerrou a partida.' :
    battle?.winner != null ? battle.winner === side ? 'Você venceu! 🎉' : 'Seu amigo venceu!' :
    expired ? 'Esta partida expirou. Crie uma nova batalha.' : round >= MAX_ROUNDS ? 'Limite de turnos atingido. Partida encerrada.' :
    ownAction ? 'Você já enviou sua ação. Aguardando seu amigo…' : replaying ? 'Atualizando batalha…' :
    replacing ? active(battle, side).hp <= 0 ? 'Escolha o próximo Pokémon.' : 'Seu amigo precisa trocar de Pokémon.' : 'Escolha sua ação.'
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
    {closed && !battle && <p className={CARD}>{room.endedBy === user.uid ? 'Você encerrou a partida.' : 'Seu amigo encerrou a partida.'}</p>}
    {room.status !== 'pending' && viewBattle && hit && <Battle
      battle={viewBattle} hit={hit} foeName={room.names[room.players[other]]}
      onExit={() => navigate('/amigos/online')}
      online={{ side, round, ...playback, locked: disabled, message,
        waitForSwitch: replacing && active(battle, side).hp > 0,
        onAction: send, onClose: () => run(() => closeBattle(id)) }}
    />}
    {room.status === 'active' && <Button disabled={busy} onClick={() => run(() => closeBattle(id))}>Desistir / encerrar partida</Button>}
  </div>
}

export function BattleInvites() {
  const uid = useAuth((s) => s.status === 'signedIn' ? s.user?.uid : null)
  const [rooms] = useFeed(watchBattles, uid)
  const current = rooms?.filter((r) => r.status !== 'closed' && r.createdAt && Date.now() < r.createdAt.toMillis() + 7 * 86400000).slice(0, 10) ?? []
  if (!current.length) return null
  return <section className={CARD}><h2 className="mb-2 font-bold">Batalhas com amigos</h2>{current.map((r) => {
    const other = r.players.find((p) => p !== uid)
    return <Link key={r.id} to={'/amigos/online/' + r.id} className="mb-2 block rounded-xl bg-sky-500/10 p-3">
      {r.names[other]} · {r.status === 'pending' ? r.players[0] === uid ? 'Convite enviado' : 'Te desafiou para uma batalha!' : 'Continuar partida'}
    </Link>
  })}</section>
}
