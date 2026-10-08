// The same generated, network-free simulator is bundled into the Android APK.
import '../../../assets/database/battle_engine.js'

const engine = () => globalThis.PocketDexSim
const weatherIds = {raindance: 'rain', sunnyday: 'sun', sandstorm: 'sand', hail: 'hail', snow: 'snow'}
export function simulatorInput(mon) {
  return {...mon.simulation, id: mon.orig?.id ?? mon.id, name: mon.name, mega: mon.mega, gmax: mon.gmax, teraType: mon.teraType, gimmick: mon.gimmick, noDmax: mon.noDmax}
}
export function initializeSimulator(battle) {
  const seed = Array.from({length: 4}, () => Math.floor(battle.random() * 65536))
  const created = engine().create({teams: battle.sides.map(s => s.team.map(simulatorInput)), seed, mode: battle.mode, controllers: battle.controllers, rules: battle.rules ?? []})
  battle.simulator = {handle: created.handle, state: created.state, opening: created.events}
  syncSimulator(battle, created)
}
export function simulatorCanGimmick(battle, side, gimmick, index) {
  const req = battle.simulator.state.sides[side].request
  return Boolean(gimmick === 'mega' ? req?.canMegaEvo : gimmick === 'tera' ? req?.canTerastallize : gimmick === 'dmax' ? req?.canDynamax : gimmick === 'z' ? req?.canZMove?.[index] : false)
}
export function syncSimulator(battle, result) {
  const {state} = result
  battle.simulator.state = state
  battle.turn = state.turn
  battle.winner = state.winner
  battle.terrain = state.terrain
  battle.weather = weatherIds[state.weather] ?? ''
  battle.bags = state.bags
  battle.forceSwitch = state.sides.map(s => s.forceSwitch)
  battle.needSwitch = state.winner == null && state.sides[0].forceSwitch
  for (let side = 0; side < 2; side++) {
    const s = state.sides[side]
    battle.sides[side].active = s.active
    battle.sides[side].switchOptions = s.switchOptions
    battle.sides[side].revival = s.revival
    battle.usedGimmicks[side] = Object.keys(s.used).filter(key => s.used[key])
    for (const p of s.team) {
      const mon = battle.sides[side].team[p.index]
      if (mon.mega && p.species.toLowerCase().includes('-mega')) {
        mon.id = mon.mega.id
        mon.base = mon.mega.base
        mon.side = {...mon.mega.side}
      } else mon.id = p.formId ?? mon.orig?.id ?? mon.id
      Object.assign(mon, {hp: p.hp, maxHp: p.maxHp, spe: p.spe, effectiveSpe: p.actionSpeed, types: p.types.map(t => t.toLowerCase()), status: p.status, boosts: p.boosts, ability: p.ability, terastal: Boolean(p.tera), dmax: p.dmax})
      if (mon.side) mon.side = {...mon.side, item: p.item, ability: p.ability, terastallized: Boolean(p.tera), teraType: p.tera.toLowerCase()}
      const requestMoves = s.slots?.find(slot => slot.index === p.index)?.request?.moves ?? (p.index === s.active ? s.request?.moves : null)
      const slots = requestMoves?.length ? requestMoves : p.moves
      mon.moves = slots.map(slot => {
        const data = engine().move(slot.id || slot.slug)
        const original = p.moves.find(m => m.slug === (slot.id || slot.slug))
        return {...data, pp: slot.pp ?? 1, maxPp: slot.maxpp ?? slot.maxPp ?? original?.maxPp ?? 1, disabled: Boolean(slot.disabled)}
      })
      mon.trapped = p.index === s.active && s.trapped
    }
  }
  return result.events
}
export const simulatorTargets = (battle, side, slot, index, gimmick = '') => engine().targets(battle.simulator.handle, side, slot, index, gimmick)
export const simulatorRecommend = (battle, side, options) => engine().recommend(battle.simulator.handle, side, options).actions
export function simulatorTurn(battle, actions) {
  return syncSimulator(battle, engine().choose(battle.simulator.handle, actions))
}
export function simulatorDispose(battle) {
  if (battle.simulator) engine().dispose(battle.simulator.handle)
}
