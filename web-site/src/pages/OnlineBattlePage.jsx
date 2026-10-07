import {simulatorDispose} from '../lib/battleSimulator'
import { useEffect, useMemo, useRef, useState } from 'react'
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom'
import { Button, Empty, PageHeader } from '../components/ui'
import { Battle } from './TurnBattlePage'
import { useAuth, errorMessage } from '../lib/auth'
import { useFriends, friendsOnly } from '../lib/friends'
import { useStore } from '../lib/store'
import { teamMembers } from '../lib/teamBattle'
import { battleMons, battleHitter, randomTeam } from '../lib/battleSetup'
import { seededRandom } from '../lib/league'
import { active, startBattle } from '../lib/turnBattle'
import { inviteBattle, acceptBattle, closeBattle, watchBattles, watchBattle, watchActions, submitAction, pairedActions, unpackTeam, BATTLE_PROTOCOL, MAX_ROUNDS, battlePerspective, eventPerspective } from '../lib/onlineBattle'
import {newPartyBattle, playPartyTurn, modeOf, countOf, seatsOf, sideOf, isNpc} from '../lib/partyBattle'

const CARD = 'rounded-2xl bg-card p-4 shadow'
const RANDOM = '__random__'
async function selectedTeam(value, teams) {
  if (value !== RANDOM) return teams.find(t => t.id === value)
  const members = await randomTeam(Math.random)
  return {name:'Time aleatório',pokemon:members.map(m=>m.id),sets:members.map(m=>m.set)}
}
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
    <option value="">Escolha seu time…</option><option value={RANDOM}>🎲 Time aleatório</option>{teams.map((t) => <option key={t.id} value={t.id}>{t.name}</option>)}
  </select></label>
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
  const [team, setTeam] = useState(RANDOM)
  const [count,setCount]=useState(1)
  const [npcDifficulty,setNpcDifficulty]=useState('normal')
  const [participants,setParticipants]=useState({})
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [rooms, feedError] = useFeed(watchBattles, user.uid)
  const invite = async () => {
    setBusy(true); setError('')
    try {
      const f = friends.find((f) => f.uid === friend), t = await selectedTeam(team,teams)
      if (!t) throw new Error('Escolha seu time.')
      const seats=Array.from({length:count*2},(_,seat)=>seat===0?user.uid:participants[seat] || (seat<count?user.uid:friend || `npc${seat}`))
      const humans=[...new Set(seats.filter(uid=>!isNpc(uid)))]
      const names=Object.fromEntries(humans.map(uid=>[uid,uid===user.uid?user.name:friends.find(f=>f.uid===uid)?.name]))
      // Quem não está (mais) na lista de amigos não entra: avisa em vez de mandar um nome vazio.
      if (Object.values(names).some(name=>!name)) throw new Error('Escolha amigos da sua lista.')
      navigate('/batalha/online/' + await inviteBattle(f,t,{mode:modeOf(count),seats,names,npcDifficulty}))
    } catch (e) { setError(e?.code ? errorMessage(e) : e?.message || errorMessage(e)) }
    finally { setBusy(false) }
  }
  return <div className="mx-auto max-w-2xl space-y-4">
    <PageHeader title="Batalha online" subtitle="Monte as equipes com amigos e NPCs. Você também pode controlar todas as posições da sua equipe." />
    <section className={CARD + ' space-y-3'}>
      <label className="block space-y-2"><span>Formato</span><select aria-label="Formato" className={SELECT} value={count} onChange={e=>{setCount(Number(e.target.value));setParticipants({})}}><option value={1}>Individual</option><option value={2}>Dupla</option><option value={3}>Tripla</option></select></label>
      {count===1 ? <label className="block space-y-2"><span>Amigo</span><select aria-label="Amigo" className={SELECT} value={friend} onChange={(e) => setFriend(e.target.value)}>
        <option value="">Escolha um amigo…</option>{friends.map((f) => <option key={f.uid} value={f.uid}>{f.name}</option>)}
      </select></label> : <>
        <p className="text-sm">Sua equipe começa com você. Escolha quem controla as outras posições; a mesma pessoa pode controlar mais de uma.</p>
        {Array.from({length:count*2},(_,seat)=>seat).filter(seat=>seat!==0).map(seat=><label key={seat} className="block space-y-1"><span>{seat<count?'Sua equipe':'Equipe adversária'} · posição {seat%count+1}</span><select aria-label={`Participante ${seat}`} className={SELECT} value={participants[seat] || (seat<count?user.uid:friend || `npc${seat}`)} onChange={e=>setParticipants(old=>({...old,[seat]:e.target.value}))}>
          {seat<count && <option value={user.uid}>Você</option>}<option value={`npc${seat}`}>NPC</option>{friends.map(f=><option key={f.uid} value={f.uid}>{f.name}</option>)}
        </select></label>)}
        <p className="text-xs text-muted">Dupla: até quatro jogadores. Tripla: até seis. Também vale você e um amigo contra NPCs.</p>
      </>}
      {count>1 && <label className="block space-y-2"><span>Dificuldade dos NPCs</span><select aria-label="Dificuldade dos NPCs" className={SELECT} value={npcDifficulty} onChange={e=>setNpcDifficulty(e.target.value)}><option value="normal">Normal · IVs e EVs aleatórios</option><option value="hard">Difícil · sets competitivos</option></select></label>}
      <TeamChoice value={team} onChange={setTeam} />
      <Button disabled={busy || count===1&&!friend || !team} onClick={invite}>{busy ? 'Enviando…' : 'Desafiar para batalha'}</Button>
      {(error || feedError) && <p role="alert" className="text-red-400">{error || feedError}</p>}
    </section>
    <section className={CARD}><h2 className="mb-3 font-bold">Convites e partidas</h2>
      {rooms == null ? <p>Carregando…</p> : !rooms.length ? <p>Nenhum convite ainda.</p> : rooms.slice(0, 50).map((r) => {
        const other = r.players.find((p) => p !== user.uid)
        return <Link key={r.id} to={'/batalha/online/' + r.id} className="mb-2 flex items-center justify-between gap-3 rounded-xl bg-surface p-3">
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
  const [team, setTeam] = useState(RANDOM)
  const [battle, setBattle] = useState(null)
  const liveBattle = useRef(null)
  useEffect(() => () => { if (liveBattle.current) simulatorDispose(liveBattle.current) }, [])
  const [round, setRound] = useState(0)
  const [hit, setHit] = useState(null)
  const [playback, setPlayback] = useState({ events: [], before: null })
  const replayedRound = useRef(null)
  const navigate = useNavigate()
  const [busy, setBusy] = useState(false)
  const [replaying, setReplaying] = useState(true)
  const [error, setError] = useState('')
  const pairs = useMemo(() => room && actions ? pairedActions(actions, room.players) : [], [room, actions])
  const side = room ? sideOf(room,user.uid) : 0
  const viewBattle = battle && battlePerspective(battle, side)
  useEffect(() => {
    let live = true
    let pendingBattle = null
    if (!room || !actions || room.status === 'pending' || !room.players.every(p=>room.teams[p])) return
    setReplaying(true)
    const replay = async () => {
      if (room.protocol !== BATTLE_PROTOCOL) throw new Error('Atualize o PocketDex e crie uma nova partida para usar as regras atuais de batalha.')
      const controllers=[...new Set(seatsOf(room))]
      const entries=await Promise.all(controllers.map(async p=>[p,await battleMons(teamMembers(unpackTeam(isNpc(p)?room.npcTeams[p]:room.teams[p])))]))
      if (entries.some(([,t])=>!t.length)) throw new Error('Não foi possível preparar os times.')
      const hit = await battleHitter()
      const b = pendingBattle = newPartyBattle(Object.fromEntries(entries),seatsOf(room),countOf(room),seededRandom(room.seed))
      startBattle(b)
      const freshEvents = []
      let before = null
      for (const [i, pair] of pairs.entries()) {
        const animate = replayedRound.current != null && i >= replayedRound.current
        if (animate && !before) before = [active(b, side).id, active(b, 1 - side).id]
        const events = playPartyTurn(b,pair)
        if (animate) freshEvents.push(...events.map((e) => eventPerspective(e, side)))
      }
      if (live) {
        if (liveBattle.current) simulatorDispose(liveBattle.current)
        liveBattle.current = b
        pendingBattle = null
        replayedRound.current = pairs.length
        setBattle(b); setRound(pairs.length); setHit(() => hit)
        setPlayback({ events: freshEvents, before }); setError(''); setReplaying(false)
      } else { simulatorDispose(b); pendingBattle = null }
    }
    replay().catch((e) => { if (import.meta.env.VITE_EMULATORS) console.error('Falha no replay:',e.stack || e.message); if (pendingBattle) simulatorDispose(pendingBattle); if (live) { setError(errorMessage(e)); setReplaying(false) } })
    return () => { live = false }
  }, [room, actions, pairs, side])
  const run = async (fn) => {
    setBusy(true); setError('')
    try { await fn() } catch (e) { setError(errorMessage(e)) } finally { setBusy(false) }
  }
  if (!room) return <div className={CARD}>{roomError || 'Carregando partida…'}</div>
  const otherName=room.players.filter(uid=>uid!==user.uid).map(uid=>room.names[uid]).join(', ')
  const ownAction = actions?.some((a) => a.round === round && a.uid === user.uid)
  const closed = room.status === 'closed'
  const expired = room.createdAt && Date.now() > room.createdAt.toMillis() + 7 * 86400000
  const send = (action) => run(() => submitAction(id, round, action))
  const disabled = busy || ownAction || replaying || closed || expired || round >= MAX_ROUNDS || battle?.winner != null
  const replacing = battle && [0, 1].some((s) => battle.forceSwitch?.[s] ?? active(battle, s).hp <= 0)
  const message = closed ? room.endedBy === user.uid ? 'Você encerrou a partida.' : 'Seu amigo encerrou a partida.' :
    battle?.winner != null ? battle.winner === -1 ? 'A batalha terminou empatada!' : battle.winner === side ? 'Você venceu! 🎉' : 'Seu amigo venceu!' :
    expired ? 'Esta partida expirou. Crie uma nova batalha.' : round >= MAX_ROUNDS ? 'Limite de turnos atingido. Partida encerrada.' :
    ownAction ? 'Você já enviou sua ação. Aguardando seu amigo…' : replaying ? 'Atualizando batalha…' :
    replacing ? (battle.forceSwitch?.[side] ?? active(battle, side).hp <= 0) ? 'Escolha o próximo Pokémon.' : 'Seu amigo precisa trocar de Pokémon.' : 'Escolha sua ação.'
  return <div className="mx-auto max-w-3xl space-y-4">
    <PageHeader title={'Batalha com ' + otherName} subtitle="Nível máximo 50. O turno acontece quando todos os jogadores enviarem suas escolhas." />
    <Link to="/batalha/online">← Convites e partidas</Link>
    {(roomError || actionsError || error) && <p role="alert" className="text-red-400">{roomError || actionsError || error}</p>}
    {expired && <p>Este convite expirou. Crie uma nova batalha.</p>}
    {room.status === 'pending' && room.protocol === BATTLE_PROTOCOL && !expired && <section className={CARD + ' space-y-3'}>
      {room.players.map(uid=><p key={uid}>{room.names[uid]}: {room.teams[uid]?'pronto':'aguardando aceite e time'}</p>)}
      {room.teams[user.uid] ? <p>Aguardando os outros participantes.</p> : <>
        <p>Você recebeu um convite para batalhar!</p><TeamChoice value={team} onChange={setTeam} />
        <Button disabled={busy || !team} onClick={() => run(async () => acceptBattle(id, await selectedTeam(team,teams)))}>Aceitar e entrar</Button>
      </>}
      <Button disabled={busy} onClick={() => run(() => closeBattle(id))}>{side === 0 ? 'Cancelar convite' : 'Recusar'}</Button>
    </section>}
    {room.protocol !== BATTLE_PROTOCOL && room.status === 'pending' && <section className={CARD}>
      <p>Atualize o PocketDex e crie uma nova partida para usar as regras atuais de batalha.</p>
      <Button disabled={busy} onClick={() => run(() => closeBattle(id))}>Encerrar convite antigo</Button>
    </section>}
    {closed && !battle && <p className={CARD}>{room.endedBy === user.uid ? 'Você encerrou a partida.' : 'Seu amigo encerrou a partida.'}</p>}
    {room.status !== 'pending' && viewBattle && hit && <Battle
      battle={battle.mode==='singles'?viewBattle:battle} hit={hit} foeName={otherName}
      onExit={() => navigate('/batalha/online')}
      online={{ uid:user.uid, names:room.names, side, round, ...playback, locked: disabled, message,
        waitForSwitch: replacing && !(battle.forceSwitch?.[side] ?? active(battle, side).hp <= 0),
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
    return <Link key={r.id} to={'/batalha/online/' + r.id} className="mb-2 block rounded-xl bg-sky-500/10 p-3">
      {r.names[other]} · {r.status === 'pending' ? r.players[0] === uid ? 'Convite enviado' : 'Te desafiou para uma batalha!' : 'Continuar partida'}
    </Link>
  })}</section>
}
