import { describe, expect, it } from 'vitest'
import { battleRecord, battleStats, canReplay } from './battleLog'
import { simulatorDispose } from './battleSimulator'
import { seededRandom } from './league'
import { newBattle, playTurn, replace, startBattle, usableMoves } from './turnBattle'

const mon = (species, moves, level = 50) => ({ id: 1, name: species, maxHp: 100, hp: 100, spe: 100, types: ['normal'], moves: [], simulation: { set: { species, moves, level } } })
const team = () => [mon('Pikachu', ['thunderbolt', 'quickattack', 'irontail', 'protect']), mon('Gyarados', ['waterfall', 'earthquake', 'dragondance', 'icefang']), mon('Snorlax', ['bodyslam', 'rest', 'crunch', 'earthquake'])]
const foes = () => [mon('Charizard', ['flamethrower', 'airslash', 'roost', 'dragonpulse']), mon('Venusaur', ['gigadrain', 'sludgebomb', 'sleeppowder', 'earthquake']), mon('Blastoise', ['surf', 'icebeam', 'rapidspin', 'protect'])]
const hit = () => ({ rolls: [[1]], eff: 1 })

/** Joga uma batalha inteira (o primeiro golpe que dá; troca quando desmaia) e devolve tudo o que aconteceu. */
function play(battle, actions = null) {
  const log = [startBattle(battle)]
  let i = 0
  for (let n = 0; n < 200 && battle.winner == null; n++) {
    let action
    if (actions) {
      if (i >= actions.length) break
      action = actions[i++]
    } else if (battle.needSwitch) action = { replace: battle.sides[0].team.findIndex((m, j) => m.hp > 0 && j !== battle.sides[0].active) }
    else action = { move: usableMoves(battle.sides[0].team[battle.sides[0].active])[n % 2] ?? 0, gimmick: 'none' }
    log.push(action.replace != null ? replace(battle, action.replace) : playTurn(battle, action, hit))
  }
  return log
}

describe('histórico e replay', () => {
  it('o replay refaz a batalha igual (mesma semente, mesmas jogadas)', () => {
    const seed = 1234567
    const original = newBattle(team(), foes(), seededRandom(seed), { seed })
    const replayed = newBattle(team(), foes(), seededRandom(seed), { seed })
    try {
      const log = play(original)
      expect(original.winner).not.toBeNull()
      original.members = { mine: [{ id: 25, set: null }], theirs: [{ id: 6, set: null }] }
      const record = battleRecord(original, { foeName: 'Brock', foeTrainer: 'brock' })
      expect(canReplay(record)).toBeTruthy()
      // Como fica na conta: JSON.
      const saved = JSON.parse(JSON.stringify(record))
      const again = play(replayed, saved.actions)
      expect(again).toEqual(log)
      expect(replayed.winner).toBe(original.winner)
      expect(replayed.sides.map((s) => s.team.map((m) => m.hp))).toEqual(original.sides.map((s) => s.team.map((m) => m.hp)))
    } finally {
      simulatorDispose(original)
      simulatorDispose(replayed)
    }
  })

  it('estatísticas: vitórias, aproveitamento e o MVP', () => {
    const r = (result, kos) => ({ result, mine: [{ id: 25 }, { id: 6 }], kos })
    const s = battleStats([r('win', { 0: 2 }), r('loss', { 1: 1 }), r('win', { 0: 1, 1: 1 })])
    expect(s).toMatchObject({ battles: 3, wins: 2, rate: 67 })
    expect(s.mvp).toMatchObject({ id: 25, kos: 3, wins: 2, battles: 3 })
  })
})
