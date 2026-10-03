import { describe, expect, it } from 'vitest'
import { active, newBattle, playOnlineTurn } from './turnBattle'
import { pairedActions, packTeam, unpackTeam, battlePerspective, eventPerspective } from './onlineBattle'
const move = (slug, power) => ({ slug, name: slug, type: 'normal', category: 'physical', power, accuracy: 100, pp: 10, maxPp: 10, priority: 0 })
const mon = (id, spe = 80) => ({ id, name: 'Mon ' + id, level: 50, hp: 100, maxHp: 100, spe, types: ['normal'], moves: [move('strong', 25), move('weak', 5)] })
const battle = () => newBattle([mon(1), mon(2)], [mon(3, 60), mon(4, 60)], () => 0.9)
const hit = (att, def, slug) => ({ rolls: [[att.moves.find((m) => m.slug === slug).power]], eff: 1 })
const attack = (index) => ({ kind: 'move', index })
describe('perspectiva da tela compartilhada', () => {
  it('inverte os lados sem restaurar HP, status ou alterar a partida', () => {
    const b = battle(); active(b, 1).hp = 42; active(b, 1).status = 'brn'
    b.weather = 'rain'; b.winner = 1
    const view = battlePerspective(b, 1)
    expect(active(view, 0).hp).toBe(42)
    expect(active(view, 0).status).toBe('brn')
    expect(view.weather).toBe('rain'); expect(view.winner).toBe(0)
    expect(active(b, 0).id).toBe(1); expect(b.winner).toBe(1)
    const event = { t: 'text', side: 1, args: [{ side: 1, name: 'Mon' }] }
    expect(eventPerspective(event, 1)).toEqual({ t: 'text', side: 0, args: [{ side: 0, name: 'Mon' }] })
    expect(event.side).toBe(1)
  })
})
describe('batalha entre dois jogadores', () => {
  it('usa o golpe escolhido pelo segundo jogador, sem CPU', () => {
    const b = battle()
    playOnlineTurn(b, [attack(0), attack(1)], hit)
    expect(active(b, 0).hp).toBe(95)
    expect(active(b, 1).hp).toBe(75)
    expect(active(b, 1).moves.map((m) => m.pp)).toEqual([10, 9])
  })
  it('desmaio aguarda a troca escolhida pelo dono e não consome outro turno', () => {
    const b = battle()
    active(b, 1).hp = 20
    playOnlineTurn(b, [attack(0), attack(1)], hit)
    expect(b.sides[1].active).toBe(0)
    expect(active(b, 0).hp).toBe(100)
    const turn = b.turn
    playOnlineTurn(b, [{ kind: 'wait', index: 0 }, { kind: 'switch', index: 1 }], hit)
    expect(b.sides[1].active).toBe(1)
    expect(b.turn).toBe(turn)
  })
  it('troca dos dois lados após desmaio simultâneo', () => {
    const b = battle()
    active(b, 0).hp = 0; active(b, 1).hp = 0
    playOnlineTurn(b, [{ kind: 'switch', index: 1 }, { kind: 'switch', index: 1 }], hit)
    expect(b.sides.map((s) => s.active)).toEqual([1, 1])
  })
  it('recusa golpe sem PP e troca para Pokémon desmaiado', () => {
    const b = battle()
    active(b, 0).moves[0].pp = 0
    expect(() => playOnlineTurn(b, [attack(0), attack(0)], hit)).toThrow()
    b.sides[0].team[1].hp = 0
    expect(() => playOnlineTurn(b, [{ kind: 'switch', index: 1 }, attack(0)], hit)).toThrow()
  })
  it('retoma apenas rodadas completas e em ordem, mesmo com snapshots desordenados', () => {
    const a = (round, uid) => ({ round, uid, ...attack(0) })
    expect(pairedActions([a(1, 'b'), a(0, 'b'), a(0, 'a'), a(2, 'a')], ['a', 'b'])).toEqual([[a(0, 'a'), a(0, 'b')]])
  })
  it('congela o time enviado sem guardar dados da conta', () => {
    const value = packTeam({ name: 'Time', pokemon: [6, null], sets: [], email: 'private' })
    expect(unpackTeam(value)).toEqual({ name: 'Time', pokemon: [6, null], sets: [] })
    expect(() => unpackTeam('{"pokemon":[-1],"sets":[]}')).toThrow()
  })
})
