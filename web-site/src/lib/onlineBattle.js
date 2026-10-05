import { firebaseServices, useAuth } from './auth'

export const BATTLE_PROTOCOL = 4
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
export async function inviteBattle(friend, team) {
  const { db, collection, addDoc, serverTimestamp } = await firebaseServices()
  const me = useAuth.getState().user
  const ref = await addDoc(collection(db, 'onlineBattles'), {
    protocol: BATTLE_PROTOCOL, players: [me.uid, friend.uid],
    names: { [me.uid]: me.name, [friend.uid]: friend.name },
    teams: { [me.uid]: packTeam(team) }, status: 'pending',
    seed: Math.floor(Math.random() * 2 ** 31), createdAt: serverTimestamp(), endedBy: null,
  })
  return ref.id
}
export async function acceptBattle(id, team) {
  const { db, doc, updateDoc } = await firebaseServices()
  const uid = useAuth.getState().user.uid
  await updateDoc(doc(db, 'onlineBattles', id), { [`teams.${uid}`]: packTeam(team), status: 'active' })
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
  return onSnapshot(query(collection(db, 'onlineBattles', id, 'actions'), limit(MAX_ROUNDS * 2)),
    (s) => next(s.docs.map((d) => d.data())), error)
}
export async function submitAction(id, round, action) {
  const { db, doc, runTransaction, serverTimestamp } = await firebaseServices()
  const uid = useAuth.getState().user.uid
  const ref = doc(db, 'onlineBattles', id, 'actions', `${round}_${uid}`)
  await runTransaction(db, async (tx) => {
    const old = await tx.get(ref)
    if (old.exists()) throw new Error('Você já enviou sua ação neste turno.')
    tx.set(ref, { uid, round, ...action, at: serverTimestamp() })
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
    if (!r?.[players[0]] || !r?.[players[1]]) break
    pairs.push(players.map((p) => r[p]))
  }
  return pairs
}

// A tela existente usa sempre o lado 0 para quem está jogando.
// A ordem original da sala continua sendo usada para calcular os turnos.
export function battlePerspective(battle, side) {
  const order = [side, 1 - side]
  return { ...battle, sides: order.map((s) => battle.sides[s]),
    usedGimmicks: order.map((s) => battle.usedGimmicks[s]),
    bags: order.map((s) => battle.bags[s]), gimmicks: order.map((s) => battle.gimmicks[s]),
    winner: battle.winner == null ? null : battle.winner === side ? 0 : 1,
    forceSwitch: battle.forceSwitch ? order.map(s => battle.forceSwitch[s]) : undefined,
    needSwitch: battle.winner == null && (battle.forceSwitch?.[side] ?? battle.sides[side].team[battle.sides[side].active].hp <= 0) }
}
export function eventPerspective(event, side) {
  return { ...event, ...(event.side == null ? {} : { side: event.side < 0 ? event.side : event.side === side ? 0 : 1 }),
    ...(event.args ? { args: event.args.map((v) => v && typeof v === 'object' && 'side' in v ? { ...v, side: v.side === side ? 0 : 1 } : v) } : {}) }
}
