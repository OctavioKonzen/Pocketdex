import { describe, expect, it } from 'vitest'
import { challengeRounds, decodeChallenge, encodeChallenge } from './challenge'
import { possibleIvs, statValue } from './ivs'
import { chanceSoFar } from './shiny'
import { suggestMembers } from './pokemon'
import { encountersByGame, methodLabel } from './encounters'

describe('desafio entre amigos', () => {
  it('mesma sequência do app (test/challenge_test.dart)', () => {
    const pool = Array.from({ length: 1025 }, (_, i) => ({ id: i + 1 }))
    const rounds = challengeRounds(pool, 123456789)
    expect(rounds).toHaveLength(10)
    expect(rounds[0]).toEqual({ answerId: 265, options: [265, 212, 805, 996] })
    expect(rounds[9].options).toEqual([395, 444, 161, 156])
  })
  it('código: ida e volta, com acento', () => {
    const code = encodeChallenge({ seed: 42, gen: 1, hint: 'cry', name: 'Ásh', score: 7 })
    expect(code).toBe('eyJzIjo0MiwiZyI6MSwiaCI6ImNyeSIsIm4iOiLDgXNoIiwicCI6N30')
    expect(decodeChallenge(`https://x/#/jogo?desafio=${code}`)).toEqual({ seed: 42, gen: 1, hint: 'cry', name: 'Ásh', score: 7 })
    expect(decodeChallenge('lixo')).toBeNull()
  })
})

describe('calculadora de IVs', () => {
  it('Garchomp nível 50 Jolly, 252 de Speed, IV 31 → 169', () => {
    expect(statValue(5, 102, 31, 252, 50, 'Jolly')).toBe(169)
    expect(possibleIvs(5, 102, 169, 252, 50, 'Jolly')).toEqual([31])
    expect(possibleIvs(0, 108, 183, 0, 50, 'Jolly')).toEqual([30, 31])
    expect(possibleIvs(1, 130, 999, 0, 50, 'Jolly')).toEqual([])
  })
})

describe('shiny e locais', () => {
  it('chance acumulada', () => {
    expect(chanceSoFar(0, 4096)).toBe(0)
    expect(Math.round(chanceSoFar(4096, 4096) * 100)).toBe(63)
  })
  it('agrupa encontros por jogo e nomeia métodos', () => {
    const g = encountersByGame([['route-1', 'rb', 'walk', 3, 5, 20, []], ['route-2', 'rb', 'surf', 10, 10, 100, ['Red']]])
    expect(g.rb).toHaveLength(2)
    expect(methodLabel('walk')).toBe('Andando na grama')
    expect(methodLabel('new-method')).toBe('New method')
  })
})

describe('sugestões de time', () => {
  const typeData = {
    fire: { double_damage_from: ['water', 'ground', 'rock'], half_damage_from: ['fire', 'grass'], no_damage_from: [], double_damage_to: ['grass'], half_damage_to: [], no_damage_to: [] },
    water: { double_damage_from: ['grass', 'electric'], half_damage_from: ['fire', 'water'], no_damage_from: [], double_damage_to: ['fire', 'ground', 'rock'], half_damage_to: [], no_damage_to: [] },
    grass: { double_damage_from: ['fire'], half_damage_from: ['water', 'ground', 'electric', 'grass'], no_damage_from: [], double_damage_to: ['water', 'ground', 'rock'], half_damage_to: [], no_damage_to: [] },
    ground: { double_damage_from: ['water', 'grass'], half_damage_from: ['rock'], no_damage_from: ['electric'], double_damage_to: ['fire', 'electric', 'rock'], half_damage_to: [], no_damage_to: [] },
  }
  it('fogo fraco a água: sugere grama, não outro fogo', () => {
    const strong = [100, 100, 100, 100, 100, 100]
    const candidates = [
      { id: 1, types: ['grass'], stats: strong },
      { id: 2, types: ['fire'], stats: strong },
      { id: 3, types: ['grass'], stats: [10, 10, 10, 10, 10, 10] },
    ]
    const out = suggestMembers([['fire']], typeData, candidates)
    expect(out.map((s) => s.pokemon.id)).toEqual([1])
    expect(out[0].resists).toContain('water')
  })
})
