import { firebaseServices, useAuth } from './auth'
import {isNpc, countOf, seatsOf} from './partyBattle'
import {randomTeam} from './battleSetup'

export const BATTLE_PROTOCOL = 5
export const MAX_ROUNDS = 500

export function packTeam(team) {
  const pokemon = team.pokemon.slice(0, 6)
  const sets = (team.sets ?? []).slice(0, 6)
  if (!pokemon.some((id) => Number.isInteger(id) && id > 0)) throw new Error('Escolha um time com Pokémon.')
  const value = JSON.stringify({ name: String(team.name ?? 'Time').slice(0, 60), pokemon, sets })
  if (value.length > 20000) throw new Error('Time muito grande.')
  return value
}
export function unpackTeam(value) {
  const team = JSON.parse(value)
  if (!Array.isArray(team.pokemon) || team.pokemon.length > 6 || !team.pokemon.some((id) => Number.isInteger(id) && id > 0) ||
    team.pokemon.some((id) => id != null && (!Number.isInteger(id) || id < 1 || id > 20000)) ||
    !Array.isArray(team.sets) || team.sets.length > 6) throw new Error('Time inválido.')
  return team
}
export async function inviteBattle(friend, team, layout = null) {
  const { db, collection, addDoc, serverTimestamp } = await firebaseServices()
  const me = useAuth.getState().user
  const mode = layout?.mode || 'singles'
  const seats = layout?.seats || [me.uid,friend.uid]
  const players = [me.uid,...[...new Set(seats)].filter(uid=>uid!==me.uid && !isNpc(uid))]
  const count=countOf({mode})
  if(players.length<2 || players.length>6 || seats.length!==count*2 || seats[0]!==me.uid || players.some(uid=>seats.slice(0,count).includes(uid)&&seats.slice(count).includes(uid))) throw new Error('Escolha os participantes de cada equipe, com pelo menos um amigo.')
  validateParticipantTeam(team,seats,me.uid)
  const npcTeams={}
  for(const uid of [...new Set(seats)].filter(isNpc)) {
    const members=await randomTeam(Math.random)
    npcTeams[uid]=packTeam({name:'NPC',pokemon:members.map(m=>m.id),sets:members.map(()=>({gimmick:'tera'}))})
  }
  const ref = await addDoc(collection(db, 'onlineBattles'), {
    protocol: BATTLE_PROTOCOL, players, mode, seats, npcTeams,
    names: layout?.names || { [me.uid]: me.name, [friend.uid]: friend.name },
    teams: { [me.uid]: packTeam(team) }, status: 'pending',
    seed: Math.floor(Math.random() * 2 ** 31), createdAt: serverTimestamp(), endedBy: null,
  })
  return ref.id
}
export async function acceptBattle(id, team) {
  const { db, doc, runTransaction } = await firebaseServices()
  const uid = useAuth.getState().user.uid
  const ref=doc(db,'onlineBattles',id)
  await runTransaction(db,async tx=>{
    const room=(await tx.get(ref)).data()
    if(!room || room.status!=='pending' || room.teams[uid]) throw new Error('Este convite já foi respondido.')
    validateParticipantTeam(team,seatsOf(room),uid)
    const teams={...room.teams,[uid]:packTeam(team)}
    tx.update(ref,{teams,status:room.players.every(p=>teams[p])?'active':'pending'})
  })
}
export async function closeBattle(id) {
  const { db, doc, updateDoc } = await firebaseServices()
  await updateDoc(doc(db, 'onlineBattles', id), { status: 'closed', endedBy: useAuth.getState().user.uid })
}
export async function watchBattles(uid, next, error) {
  const { db, collection, query, where, onSnapshot } = await firebaseServices()
  return onSnapshot(query(collection(db, 'onlineBattles'), where('players', 'array-contains', uid)),
    (s) => next(s.docs.map((d) => ({ id: d.id, ...d.data() })).sort((a, b) => (b.createdAt?.seconds ?? 0) - (a.createdAt?.seconds ?? 0))), error)
}
export async function watchBattle(id, next, error) {
  const { db, doc, onSnapshot } = await firebaseServices()
  return onSnapshot(doc(db, 'onlineBattles', id), (s) => next(s.exists() ? { id: s.id, ...s.data() } : null), error)
}
export async function watchActions(id, next, error) {
  const { db, collection, onSnapshot, query, limit } = await firebaseServices()
  return onSnapshot(query(collection(db, 'onlineBattles', id, 'actions'), limit(MAX_ROUNDS * 6)),
    (s) => next(s.docs.map((d) => d.data())), error)
}
export async function submitAction(id, round, action) {
  const { db, doc, runTransaction, serverTimestamp } = await firebaseServices()
  const uid = useAuth.getState().user.uid
  const ref = doc(db, 'onlineBattles', id, 'actions', `${round}_${uid}`)
  await runTransaction(db, async (tx) => {
    const room=(await tx.get(doc(db,'onlineBattles',id))).data()
    const old = await tx.get(ref)
    if (old.exists()) throw new Error('Você já enviou sua ação neste turno.')
    const count=countOf(room), seats=seatsOf(room), side=Math.floor(seats.indexOf(uid)/count)
    const choices=(action.kind==='team'?action.choices:[{seat:seats.indexOf(uid),...action}]).map(c=>({...c,index:c.index??0,gimmick:c.gimmick||'none',target:c.target||0}))
    const teammates=[...new Set(seats.slice(side*count,(side+1)*count))].filter(p=>p!==uid&&!isNpc(p))
    const others=await Promise.all(teammates.map(p=>tx.get(doc(db,'onlineBattles',id,'actions',`${round}_${p}`))))
    const existing=others.filter(d=>d.exists()).flatMap(d=>d.data().choices)
    validateGroupChoices([...existing,...choices])
    tx.set(ref, { uid, round, kind:'team',choices, at: serverTimestamp() })
  })
}
export function pairedActions(actions, players) {
  const rounds = new Map()
  for (const a of actions) {
    if (!rounds.has(a.round)) rounds.set(a.round, {})
    rounds.get(a.round)[a.uid] = a
  }
  const pairs = []
  for (let round = 0; round < MAX_ROUNDS; round++) {
    const r = rounds.get(round)
    if (!r || !players.every(p=>r[p])) break
    pairs.push(players.map((p) => r[p]))
  }
  return pairs
}
export function validateParticipantTeam(team,seats,uid) {
  const required=seats.filter(p=>p===uid).length
  const available=team.pokemon.slice(0,6).filter(id=>Number.isInteger(id)&&id>0).length
  if(!required || available<required) throw new Error(`Escolha um time com pelo menos ${required || 1} Pokémon para suas posições.`)
}
export function validateGroupChoices(choices) {
  const switches=choices.filter(c=>c.kind==='switch').map(c=>c.index)
  if(new Set(switches).size!==switches.length) throw new Error('Esse Pokémon já foi escolhido para outra posição. Escolha outra reserva.')
  const mechanics=choices.filter(c=>c.kind==='move'&&c.gimmick&&c.gimmick!=='none').map(c=>c.gimmick)
  if(new Set(mechanics).size!==mechanics.length) throw new Error('Seu parceiro já escolheu essa transformação neste turno.')
}

// A tela existente usa sempre o lado 0 para quem está jogando.
// A ordem original da sala continua sendo usada para calcular os turnos.
export function battlePerspective(battle, side) {
  const order = [side, 1 - side]
  return { ...battle, sides: order.map((s) => battle.sides[s]),
    usedGimmicks: order.map((s) => battle.usedGimmicks[s]),
    bags: order.map((s) => battle.bags[s]), gimmicks: order.map((s) => battle.gimmicks[s]),
    winner: battle.winner == null ? null : battle.winner === -1 ? -1 : battle.winner === side ? 0 : 1,
    simulator: battle.simulator ? {...battle.simulator, state: {...battle.simulator.state, sides: order.map(s => battle.simulator.state.sides[s])}} : undefined,
    forceSwitch: battle.forceSwitch ? order.map(s => battle.forceSwitch[s]) : undefined,
    needSwitch: battle.winner == null && (battle.forceSwitch?.[side] ?? battle.sides[side].team[battle.sides[side].active].hp <= 0) }
}
export function eventPerspective(event, side) {
  return { ...event, ...(event.side == null ? {} : { side: event.side < 0 ? event.side : event.side === side ? 0 : 1 }),
    ...(event.args ? { args: event.args.map((v) => v && typeof v === 'object' && 'side' in v ? { ...v, side: v.side === side ? 0 : 1 } : v) } : {}) }
}
