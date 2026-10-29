import { describe, expect, test } from 'vitest'
import { koTextPt, newField, newMoveOptions, newSide, run, speciesName } from './damageCalc'

const garchomp = { name: 'garchomp', types: ['dragon', 'ground'], stats: [108, 130, 95, 80, 85, 102], weight: 950 }
const tyranitar = { name: 'tyranitar', types: ['rock', 'dark'], stats: [100, 134, 110, 95, 100, 61], weight: 2020 }
const charizard = { name: 'charizard', types: ['fire', 'flying'], stats: [78, 84, 78, 109, 85, 100], weight: 905 }

const calc = (over) =>
  run({
    attacker: garchomp,
    attackerSide: { ...newSide({ atk: 252 }), level: 100, nature: 'Jolly' },
    defender: tyranitar,
    defenderSide: { ...newSide({ hp: 252, def: 252 }), level: 100, nature: 'Impish' },
    moveSlug: 'earthquake',
    moveOptions: newMoveOptions(),
    field: newField(),
    ...over,
  })

describe('calculadora de dano (Showdown)', () => {
  test('nomes das formas', () => {
    expect(speciesName('tauros-paldea-combat-breed')).toBe('Tauros-Paldea-Combat')
    expect(speciesName('deoxys-normal')).toBe('Deoxys')
    expect(speciesName('charizard-mega-x')).toBe('Charizard-Mega-X')
    expect(speciesName('ogerpon-wellspring-mask')).toBe('Ogerpon-Wellspring')
  })

  test('Earthquake do Garchomp no Tyranitar (igual ao Showdown)', () => {
    const r = calc()
    expect(r.name).toBe('Earthquake')
    expect(r.rolls[0]).toHaveLength(16)
    // 252+ Atk Garchomp Earthquake vs. 252 HP / 252+ Def Tyranitar
    expect(r.min).toBeGreaterThan(0)
    expect(r.desc).toContain('Earthquake vs.')
    expect(r.koText).toMatch(/derrota/i)
  })

  test('habilidade e item mudam a conta', () => {
    const base = calc().max
    const band = calc({ attackerSide: { ...newSide({ atk: 252 }), level: 100, nature: 'Jolly', item: 'Choice Band' } }).max
    expect(band).toBeGreaterThan(base)
    const levitate = calc({ defenderSide: { ...newSide(), ability: 'Levitate' } })
    expect(levitate.noDamage).toBe(true)
  })

  test('golpe de vários acertos e crítico', () => {
    const r = calc({ moveSlug: 'scale-shot', moveOptions: { ...newMoveOptions(), hits: 5 } })
    expect(r.hits).toBe(5)
    expect(r.rolls).toHaveLength(5)
    const crit = calc({ moveOptions: { ...newMoveOptions(), crit: true } })
    expect(crit.max).toBeGreaterThan(calc().max)
  })

  test('HP atual, Stealth Rock e clima', () => {
    const half = calc({ defenderSide: { ...newSide({ hp: 252, def: 252 }), level: 100, nature: 'Impish', hpPct: 50 } })
    expect(half.curHP).toBeLessThan(half.hp)
    const sun = run({
      attacker: charizard,
      attackerSide: newSide({ spa: 252 }),
      defender: garchomp,
      defenderSide: newSide(),
      moveSlug: 'flamethrower',
      moveOptions: newMoveOptions(),
      field: { ...newField(), weather: 'Sun', stealthRock: true },
    })
    const plain = run({
      attacker: charizard,
      attackerSide: newSide({ spa: 252 }),
      defender: garchomp,
      defenderSide: newSide(),
      moveSlug: 'flamethrower',
      moveOptions: newMoveOptions(),
      field: newField(),
    })
    expect(sun.max).toBeGreaterThan(plain.max)
  })

  test('texto da chance de derrotar em português', () => {
    expect(koTextPt({ chance: 1, n: 1, text: 'guaranteed OHKO' }, 10)).toBe('Derrota com 1 golpe, garantido.')
    expect(koTextPt({ chance: 0.125, n: 1, text: '12.5% chance to OHKO' }, 10)).toBe('12,5% de chance de derrotar com 1 golpe.')
    expect(koTextPt({ chance: 1, n: 2, text: 'guaranteed 2HKO after Stealth Rock and Leftovers recovery' }, 10)).toBe(
      'Derrota com 2 golpes, garantido, depois de Stealth Rock e recuperação do Leftovers.',
    )
    expect(koTextPt({ chance: 0.3, n: 2, text: '30% chance to 2HKO after 2 layers of Spikes (guaranteed 2HKO after sandstorm damage)' }, 10)).toBe(
      '30% de chance de derrotar com 2 golpes, depois de 2 camadas de Spikes (derrota com 2 golpes, garantido, depois de dano de tempestade de areia).',
    )
    expect(koTextPt({ chance: 0, n: 0, text: '' }, 0)).toBe('Não causa dano.')
  })
})
