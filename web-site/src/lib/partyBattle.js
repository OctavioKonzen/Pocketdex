import {newBattle, lineOf} from './turnBattle'
import {simulatorRecommend, simulatorTurn} from './battleSimulator'

export const modeOf = count => ['singles','doubles','triples'][count - 1]
export const isNpc = controller => /^npc[0-5]$/.test(controller)
export const countOf = room => room.mode === 'triples' ? 3 : room.mode === 'doubles' ? 2 : 1
export const seatsOf = room => room.seats || room.players
export const sideOf = (room, uid) => Math.floor(seatsOf(room).indexOf(uid) / countOf(room))

// A cooperative team has six places, shared between the trainers' submitted
// parties. Put one Pokémon in each seat first, then fill the shared bench.
export function assembleParty(controllers, rosters) {
  const unique = [...new Set(controllers)], quota = Math.floor(6 / unique.length)
  const pools = Object.fromEntries(unique.map(uid => [uid, rosters[uid].slice(0, quota)]))
  const active = controllers.map(uid => {
    const mon = pools[uid].shift()
    if (!mon) throw new Error('Cada participante precisa de Pokémon suficientes para as posições que controla.')
    return mon
  })
  return [...active, ...unique.flatMap(uid => pools[uid])]
}
export function newPartyBattle(rosters, seats, count, random) {
  const controllers = [seats.slice(0,count), seats.slice(count,count*2)]
  return newBattle(...controllers.map(team => assembleParty(team,rosters)), random, {mode: modeOf(count), controllers})
}
export function groupActions(battle, submissions) {
  return battle.controllers.map((controllers, side) => {
    const choices = submissions.flatMap(s => s.choices || []).filter(c => Math.floor(c.seat / controllers.length) === side)
    const controlledSlots = controllers.map((uid,slot) => isNpc(uid) ? slot : -1).filter(slot => slot >= 0)
    const actions = simulatorRecommend(battle, side, {controlledSlots,
      reservedSwitches: choices.filter(c => c.kind === 'switch').map(c => c.index),
      reservedMechanics: choices.map(c => c.gimmick).filter(Boolean)})
    for (const choice of choices) actions[choice.seat % controllers.length] = choice
    return actions
  })
}
export function playPartyTurn(battle, submissions) {
  return simulatorTurn(battle,groupActions(battle,submissions))
}
export function describeEvents(events) {
  return events.filter(e => e.t === 'text').map(e => {
    const [line,args]=lineOf(e)
    return args.reduce((text,arg,i)=>text.replace(`{${i}}`,arg),line)
  })
}
