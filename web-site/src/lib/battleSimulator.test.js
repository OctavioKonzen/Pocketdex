import {describe, it, expect} from 'vitest'
import {newBattle, playOnlineTurn, playTurn, replace, canGimmick, lineOf, startBattle, lockedMove, fieldConditions, monDetails, damageRange} from './turnBattle'
import {battlePerspective} from './onlineBattle'
import {simulatorDispose, simulatorRecommend} from './battleSimulator'

const mon = (species, moves, extra = {}) => ({id: 1, name: species, maxHp: 100, hp: 100, spe: 100, types: ['normal'], moves: [], simulation: {set: {species, moves, level: 50}}, ...extra})
const seed = () => { let n = 0; return () => ++n / 65536 }
const attack = index => ({kind: 'move', index, gimmick: ''})
const hit = () => ({rolls: [[1]], eff: 1})

describe('shared simulator integration', () => {
  it('o campo e o que o adversário já mostrou (Stealth Rock, Reflect, Leftovers, golpes usados)', () => {
    const named = (species, moves, item) => ({...mon(species, moves, {simulation: {set: {species, moves, level: 50, item}}}), moves: moves.map(m => ({slug: m, name: m, pp: 10, maxPp: 10}))})
    const b=newBattle([named('Skarmory',['stealthrock','roost'],'Leftovers'), named('Blissey',['softboiled'])],[named('Klefki',['reflect','spikes'],'Leftovers'), named('Chansey',['softboiled'])],seed())
    try {
      startBattle(b)
      expect(monDetails(b,1).moves).toEqual([])
      expect(monDetails(b,1).item).toBe(null)
      expect(monDetails(b,0).item).toBe('Leftovers')
      playTurn(b,{move:0,gimmick:'none'},hit)
      const [mine, theirs] = fieldConditions(b)
      expect(theirs).toContain('Stealth Rock')
      // O computador usou Reflect (no lado dele) ou Spikes (no seu).
      expect([...mine, ...theirs].some(x => /Reflect|Spikes/.test(x))).toBe(true)
      expect(monDetails(b,1).moves.length).toBe(1)
      expect(monDetails(b,1).ability).toBe(null)
    } finally {simulatorDispose(b)}
  })
  it.each([['outrage', 'outrage'], ['hyperbeam', 'recharge']])('golpe em sequência (%s): o turno seguinte vem preso e o motor usa ele', (move, slug) => {
    const named = (species, moves) => ({...mon(species, moves), moves: moves.map(m => ({slug: m, name: m, pp: 10, maxPp: 10}))})
    const b=newBattle([named('Dragonite',[move,'extremespeed','roost','earthquake'])],[named('Blissey',['softboiled']),named('Chansey',['softboiled']),named('Snorlax',['rest'])],seed())
    try {
      startBattle(b)
      expect(lockedMove(b)).toBeNull()
      playTurn(b,{move:0,gimmick:'none'},hit)
      expect(lockedMove(b)?.slug).toBe(slug)
      // Pedindo outro golpe, o motor usa o preso (a tela nem pergunta).
      const used=playTurn(b,{move:2,gimmick:'none'},hit).filter(e=>e.key==='used'&&e.args[0].side===0).map(e=>e.args[1])
      expect(used.some(name=>/roost/i.test(name))).toBe(false)
    } finally {simulatorDispose(b)}
  })
  it('NPC bag use does not stall offline combat and uses its only action', () => {
    const b=newBattle([mon('Mew',['seismictoss','recover'])],[mon('Mew',['seismictoss'])],seed())
    // Seismic Toss tira 50: o NPC só usa poção quando está com pouco HP e desmaiaria neste turno.
    const toss=()=>({rolls:[[50]],eff:1})
    try {
      startBattle(b)
      let events=[],turn=b.turn
      for(let i=0;i<6;i++) {
        turn=b.turn
        events=playTurn(b,{move:i<3?0:1},toss)
        if(events.some(e=>e.key==='usedItem' && e.args[0].side===1)) break
      }
      expect(events.some(e=>e.key==='usedItem' && e.args[0].side===1)).toBe(true)
      expect(b.turn).toBe(turn+1)
      expect(b.bags[1].potion+b.bags[1]['super-potion']+b.bags[1]['hyper-potion']).toBe(5)
      expect(events.filter(e=>e.key==='used' && e.args[0].side===1)).toHaveLength(0)
      playTurn(b,{move:1},toss)
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
  it('each offline turn starts with the turn order (who acts first)', () => {
    const b = newBattle([mon('Jolteon', ['swift'])], [mon('Snorlax', ['tackle'])], seed())
    try {
      startBattle(b)
      const events = playTurn(b, {move: 0, gimmick: 'none'}, hit)
      expect(events[0].key).toBe('turnOrder')
      const [line, [queue]] = lineOf(events[0])
      expect(line).toBe('Ordem do turno: {0}')
      expect(queue.indexOf('Jolteon')).toBeLessThan(queue.indexOf('Snorlax'))
      expect(queue.startsWith('🔵')).toBe(true)
    } finally { simulatorDispose(b) }
  })
  it('items and abilities show their own text, like the games (no raw simulator lines)', () => {
    const b=newBattle([mon('Gyarados',['waterfall'],{simulation:{set:{species:'Gyarados',moves:['waterfall'],level:50,ability:'Intimidate',item:'Life Orb'}}})],[mon('Pelipper',['hurricane'],{simulation:{set:{species:'Pelipper',moves:['hurricane'],level:50,ability:'Drizzle',item:'Leftovers'}}})],seed())
    try {
      const keys=[...startBattle(b),...playTurn(b,{move:0},hit)].filter(e=>e.t==='text').map(e=>e.key)
      expect(keys).toEqual(expect.arrayContaining(['abilityShow','rainStart','hurtBy','healedBy']))
      expect(keys).not.toContain('sim')
    } finally {simulatorDispose(b)}
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
