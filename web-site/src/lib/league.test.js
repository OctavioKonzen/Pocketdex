import { describe, expect, it } from 'vitest'
import { achievementsOf } from './achievements'
import { damage, koText, statAt } from './battle'
import { pixCode } from './pix'
import { isOffensive } from './profanity'
import { dailyAnswers, dailyPoints, dayKey, seededRandom, seedOf, weekKey } from './league'
import { decodeTeam, encodeTeam, fromShowdown, showdownName } from './teamShare'

describe('desafio do dia', () => {
  it('usa o dia e a semana de Brasília', () => {
    // 25/09/2026 01:00 UTC ainda é 24/09 em Brasília (quinta-feira).
    const t = Date.UTC(2026, 8, 25, 1, 0)
    expect(dayKey(t)).toBe('2026-09-24')
    expect(weekKey(t)).toBe('2026-09-21')
    // Domingo é o último dia da semana.
    expect(weekKey(Date.UTC(2026, 8, 27, 15))).toBe('2026-09-21')
    expect(weekKey(Date.UTC(2026, 8, 28, 15))).toBe('2026-09-28')
  })

  it('sorteia sempre os mesmos 10 Pokémon no mesmo dia (igual ao app)', () => {
    const a = dailyAnswers('2026-09-25')
    expect(a).toEqual(dailyAnswers('2026-09-25'))
    expect(new Set(a).size).toBe(10)
    expect(a.every((id) => id >= 1 && id <= 1025)).toBe(true)
    expect(dailyAnswers('2026-09-26')).not.toEqual(a)
    // Valores conferidos com a versão em Dart (test/league_test.dart).
    expect(seedOf('pocketdex-2026-09-25')).toBe(SEED)
    expect(Math.floor(seededRandom(SEED)() * 1e9)).toBe(FIRST)
    expect(a).toEqual(ANSWERS)
  })

  it('dá mais pontos para quem responde rápido', () => {
    expect(dailyPoints(10000)).toBe(1100)
    expect(dailyPoints(0)).toBe(1000)
    expect(dailyPoints(4550)).toBe(1045)
  })
})

describe('compartilhar time', () => {
  const index = [
    { id: 6, name: 'charizard', default: true },
    { id: 10034, name: 'charizard-mega-x', default: false },
    { id: 645, name: 'landorus-incarnate', default: true },
    { id: 122, name: 'mr-mime', default: true },
  ]

  it('código vai e volta igual', () => {
    const team = { name: 'Time Ação ⚡', color: '#FF5252', pokemon: [6, null, 645, null, null, 122] }
    const back = decodeTeam(`https://site/#/times/importar/${encodeTeam(team)}`)
    expect(back).toEqual({ name: team.name, color: team.color, pokemon: team.pokemon })
    expect(decodeTeam('lixo')).toBeNull()
  })

  it('lê o formato do Showdown', () => {
    const text = `=== [gen9ou] Meu Time ===

Zard (Charizard-Mega-X) (M) @ Charizardite X
Ability: Tough Claws
- Dragon Dance

Landorus @ Life Orb
- Earthquake

Mr. Mime
`
    expect(fromShowdown(text, index)).toEqual({ name: 'Meu Time', color: null, pokemon: [10034, 645, 122, null, null, null] })
    expect(showdownName('charizard-mega-x')).toBe('Charizard-Mega-X')
  })
})

describe('conquistas', () => {
  it('libera conforme os dados', () => {
    const list = achievementsOf({ stats: { correct: 120, bestStreak: 12 }, rankedRecord: 150, favorites: [], teams: [] })
    const on = list.filter((a) => a.unlocked).map((a) => a.id)
    expect(on).toEqual(['first', 'trainer', 'streak', 'ranked'])
  })
})

// Preenchidos a partir da execução (e iguais aos do teste em Dart).
const SEED = 1444911752
const FIRST = 956775411
const ANSWERS = [981, 470, 966, 342, 245, 178, 721, 937, 647, 563]

describe('calculadora de dano', () => {
  const typeData = {
    fire: { double_damage_from: ['water'], half_damage_from: ['fire', 'grass'], no_damage_from: [] },
    grass: { double_damage_from: ['fire'], half_damage_from: ['water', 'grass'], no_damage_from: [] },
  }
  it('calcula status e dano no nível 50', () => {
    expect(statAt(78, 0)).toBe(153) // HP do Charizard
    expect(statAt(109, 3, 252)).toBe(161) // Sp. Atk com 252 EVs
    expect(statAt(109, 3, 252, 50, { nature: 'Modest' })).toBe(177)
    expect(statAt(109, 3, 252, 50, { nature: 'Adamant' })).toBe(144)
    const attacker = { types: ['fire'], stats: [78, 84, 78, 109, 85, 100], evs: { spa: 252 } }
    const defender = { types: ['grass'], stats: [80, 82, 83, 100, 100, 80] }
    const move = { type: 'fire', category: 'special', power: 90 }
    const r = damage({ attacker, defender, move, typeData })
    expect(r.mult).toBe(2)
    expect(r.stab).toBe(true)
    expect([r.min, r.max, r.hp]).toEqual([RESULT.min, RESULT.max, 155])
    expect(r.rolls).toHaveLength(16)
    expect(r.hits).toBe(1)
    expect(r.chance).toBe(0.375) // 6 das 16 variações passam de 155
    expect(koText(r)).toBe('37,5% de chance de derrotar com 1 golpe.')
    // Crítico, chuva, Tera e tela
    expect(damage({ attacker, defender, move, typeData, field: { crit: true } }).max).toBeGreaterThan(r.max)
    expect(damage({ attacker, defender, move, typeData, field: { weather: 'rain' } }).max).toBeLessThan(r.max)
    expect(damage({ attacker: { ...attacker, tera: 'fire' }, defender, move, typeData }).stabMult).toBe(2)
    expect(damage({ attacker, defender, move, typeData, field: { screen: true } }).max).toBeLessThan(r.max)
    expect(koText({ hits: 2, chance: 1 })).toBe('Derrota com 2 golpes, garantido.')
  })
})

const RESULT = { min: 138, max: 164 }

describe('Pix', () => {
  it('gera o BR Code igual ao exemplo do Banco Central', () => {
    expect(pixCode({ key: '123e4567-e12b-12d1-a456-426655440000', name: 'Fulano de Tal', city: 'BRASILIA' })).toBe(
      '00020126580014br.gov.bcb.pix0136123e4567-e12b-12d1-a456-4266554400005204000053039865802BR5913Fulano de Tal6008BRASILIA62070503***63041D3D',
    )
  })
})

describe('filtro de palavrões', () => {
  it('bloqueia palavrões, mesmo disfarçados', () => {
    for (const bad of ['Porra', 'P0RR4', 'poooorra', 'p o r r a', 'Filho da Puta', 'FdP', 'fuck you', 'Time do Caralho', 'Vai tnc', 'f.d.p'])
      expect(isOffensive(bad), bad).toBe(true)
  })
  it('deixa nomes normais', () => {
    for (const ok of ['Ash Ketchum', 'Computador', 'Time Rolagem', 'Raposa', 'Mestre Pokémon', 'Team Rocket', 'Rapel', 'Pintura', 'Dragões'])
      expect(isOffensive(ok), ok).toBe(false)
  })
})
