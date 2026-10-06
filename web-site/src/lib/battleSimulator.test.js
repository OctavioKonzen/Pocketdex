import {describe, it, expect} from 'vitest'
import {newBattle, playOnlineTurn, playTurn, replace, canGimmick, lineOf, startBattle} from './turnBattle'
import {battlePerspective} from './onlineBattle'
import {simulatorDispose, simulatorRecommend} from './battleSimulator'

const mon = (species, moves, extra = {}) => ({id: 1, name: species, maxHp: 100, hp: 100, spe: 100, types: ['normal'], moves: [], simulation: {set: {species, moves, level: 50}}, ...extra})
const seed = () => { let n = 0; return () => ++n / 65536 }
const attack = index => ({kind: 'move', index, gimmick: ''})
const hit = () => ({rolls: [[1]], eff: 1})

describe('shared simulator integration', () => {
  it('NPC bag use does not stall offline combat and uses its only action', () => {
    const b=newBattle([mon('Mew',['seismictoss','recover'])],[mon('Mew',['seismictoss'])],seed())
    try {
      startBattle(b)
      playTurn(b,{move:0},hit)
      playTurn(b,{move:0},hit)
      const turn=b.turn
      const events=playTurn(b,{move:1},hit)
      expect(b.turn).toBe(turn+1)
      expect(b.bags[1].potion+b.bags[1]['super-potion']+b.bags[1]['hyper-potion']).toBe(5)
      expect(events.filter(e=>e.key==='used' && e.args[0].side===1)).toHaveLength(0)
      playTurn(b,{move:0},hit)
      expect(b.turn).toBe(turn+2)
    } finally {simulatorDispose(b)}
  })
  it.each([
    ['uturn','swift','recover','protect'],['voltswitch','thunderbolt','recover','protect'],
    ['batonpass','swordsdance','swift','protect'],['hyperbeam','swift','recover','protect'],
    ['fly','swift','recover','protect'],['outrage','swift','recover','protect'],
    ['encore','disable','taunt','swift'],['meanlook','toxic','stealthrock','swift'],
  ])('offline turns and replacements continue with %s', (...moves) => {
    const b=newBattle(Array.from({length:3},()=>mon('Mew',moves)),Array.from({length:3},()=>mon('Mew',moves)),seed())
    try {
      startBattle(b)
      for(let step=0;step<24 && b.winner==null;step++) {
        const choice=simulatorRecommend(b,0)[0],turn=b.turn,wasSwitch=b.needSwitch
        const events=wasSwitch ? replace(b,choice.index) : playTurn(b,{move:choice.index,switch:choice.kind==='switch'?choice.index:undefined,gimmick:'none'},hit)
        events.filter(e=>e.t==='text').forEach(lineOf)
        expect(b.turn>turn || b.needSwitch || wasSwitch || b.winner!=null).toBe(true)
        expect(b.simulator.state.sides[0].wait).toBe(false)
      }
    } finally {simulatorDispose(b)}
  })
  it('recharge remains a selectable action and returns to the original moves', () => {
    const b = newBattle([mon('Mew', ['hyperbeam'])], [mon('Blissey', ['splash'])], seed())
    try {
      playOnlineTurn(b, [attack(0), attack(0)], hit)
      expect(b.sides[0].team[0].moves[0].slug).toBe('recharge')
      playOnlineTurn(b, [attack(0), attack(0)], hit)
      expect(b.sides[0].team[0].moves[0].slug).toBe('hyper-beam')
    } finally { simulatorDispose(b) }
  })
  it('the second player sees their own transformation request and pivot selection', () => {
    const b = newBattle([mon('Blissey', ['splash'])], [mon('Scizor', ['uturn'], {gimmick: 'tera', teraType: 'fire'}), mon('Pikachu', ['splash'])], seed())
    try {
      expect(canGimmick(battlePerspective(b, 1), 0, 'tera', 0)).toBe(true)
      expect(canGimmick(battlePerspective(b, 0), 0, 'tera', 0)).toBe(false)
      playOnlineTurn(b, [attack(0), attack(0)], hit)
      expect(battlePerspective(b, 1).needSwitch).toBe(true)
      expect(battlePerspective(b, 0).needSwitch).toBe(false)
      playOnlineTurn(b, [{kind: 'wait'}, {kind: 'switch', index: 1}], hit)
      expect(b.sides[1].active).toBe(1)
      expect(b.turn).toBe(2)
    } finally { simulatorDispose(b) }
  })
  it('a completed battle ends its event sequence with the victory text', () => {
    const b = newBattle([mon('Mewtwo', ['psychic'])], [mon('Magikarp', ['splash'])], seed())
    try {
      startBattle(b)
      const events = playOnlineTurn(b, [attack(0), attack(0)], hit)
      expect(b.winner).toBe(0)
      expect(lineOf(events.at(-1))[0]).toBe('Você venceu a batalha!')
    } finally { simulatorDispose(b) }
  })
})
