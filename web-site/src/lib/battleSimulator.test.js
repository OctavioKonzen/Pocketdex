import {describe, it, expect} from 'vitest'
import {newBattle, playOnlineTurn, canGimmick, lineOf, startBattle} from './turnBattle'
import {battlePerspective} from './onlineBattle'
import {simulatorDispose} from './battleSimulator'

const mon = (species, moves, extra = {}) => ({id: 1, name: species, maxHp: 100, hp: 100, spe: 100, types: ['normal'], moves: [], simulation: {set: {species, moves, level: 50}}, ...extra})
const seed = () => { let n = 0; return () => ++n / 65536 }
const attack = index => ({kind: 'move', index, gimmick: ''})
const hit = () => ({rolls: [[1]], eff: 1})

describe('shared simulator integration', () => {
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
