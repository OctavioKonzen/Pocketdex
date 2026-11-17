import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { canEvolveWith, genderOf, levelTo, regionalEncounter, regionOf } from './factoryRun'

const data = JSON.parse(readFileSync(new URL('../../../assets/database/factory.json', import.meta.url), 'utf8'))
const mon = (id, level, extra = {}) => ({ id, level, exp: level ** 3, nature: 'Hardy', ivs: { hp: 0, atk: 0, def: 0, spa: 0, spd: 0, spe: 0 }, evs: { hp: 0, atk: 0, def: 0, spa: 0, spd: 0, spe: 0 }, ...extra })
const region = (name) => data.bosses.findIndex((b) => b.region === name)
const run = (name) => ({ boss: { region: region(name), step: 0 } })
// Um Pokémon desse gênero (o gênero vem dos IVs).
const withGender = (id, level, g) => {
  for (let hp = 0; hp < 32; hp++) {
    const m = mon(id, level, { ivs: { hp, atk: 0, def: 0, spa: 0, spd: 0, spe: 0 } })
    if (genderOf(data, m) === g) return m
  }
  throw new Error('sem gênero ' + g)
}
const at = (m, lvl, where) => levelTo(m, lvl, data, () => 0, where)[0].id

describe('evoluções como nos jogos (igual ao app)', () => {
  it('formas regionais: os selvagens na forma da região; os chefes, não', () => {
    expect(regionOf(data, run('Galar'))).toBe('Galar')
    const enc = { kind: 'wild', foes: [{ id: 52, level: 10 }] }
    expect(regionalEncounter(data, run('Galar'), enc).foes[0].id).toBe(10161)
    expect(regionalEncounter(data, run('Alola'), enc).foes[0].id).toBe(10107)
    expect(regionalEncounter(data, run('Kanto'), enc).foes[0].id).toBe(52)
    expect(regionalEncounter(data, run('Galar'), { ...enc, kind: 'boss' }).foes[0].id).toBe(52)
    // Hisui é uma região própria (em Sinnoh, a forma comum); Paldea tem o Wooper de Paldea.
    expect(regionalEncounter(data, run('Hisui'), { kind: 'wild', foes: [{ id: 215, level: 30 }] }).foes[0].id).toBe(10235)
    expect(regionalEncounter(data, run('Sinnoh'), { kind: 'wild', foes: [{ id: 215, level: 30 }] }).foes[0].id).toBe(215)
    expect(regionalEncounter(data, run('Paldea'), { kind: 'trainer', foes: [{ id: 194, level: 10 }] }).foes[0].id).toBe(10253)
  })

  it('cada forma evolui na dela (Meowth de Galar → Perrserker; o comum → Persian), onde evoluir', () => {
    expect(at(mon(52, 27), 28, 'Galar')).toBe(53)
    expect(at(mon(10161, 27), 28, 'Kanto')).toBe(863)
    expect(at(mon(562, 33), 34)).toBe(563)
    expect(at(mon(10179, 33), 34)).toBe(867)
    expect(at(mon(194, 19), 20)).toBe(195)
    expect(at(mon(10253, 19), 20)).toBe(980)
    expect(at(mon(10091, 19), 20)).toBe(10092)
  })

  it('evoluindo na região, vira a forma dela (Pikachu → Raichu de Alola; Quilava → Typhlosion de Hisui)', () => {
    expect(canEvolveWith(data, mon(25, 20), 'thunder-stone', 'Alola')).toEqual([10100])
    expect(canEvolveWith(data, mon(25, 20), 'thunder-stone', 'Kanto')).toEqual([26])
    expect(canEvolveWith(data, mon(102, 20), 'leaf-stone', 'Alola')).toEqual([10114])
    expect(at(mon(156, 35), 36, 'Hisui')).toBe(10233)
    expect(at(mon(156, 35), 36, 'Sinnoh')).toBe(157)
    expect(at(mon(156, 35), 36, 'Johto')).toBe(157)
    expect(at(mon(109, 34), 35, 'Galar')).toBe(10167)
    // Só na região: Stantler → Wyrdeer em Hisui; Ursaring com o Peat Block em Hisui e Paldea.
    expect(at(mon(234, 24), 30, 'Hisui')).toBe(899)
    expect(at(mon(234, 24), 30, 'Sinnoh')).toBe(234)
    expect(at(mon(234, 24), 30, 'Kanto')).toBe(234)
    expect(canEvolveWith(data, mon(217, 40), 'peat-block', 'Paldea')).toEqual([901])
    expect(canEvolveWith(data, mon(217, 40), 'peat-block', 'Kanto')).toEqual([])
  })

  it('por gênero: Combee, Burmy, Salandit, as pedras do Kirlia e do Snorunt e as formas femininas', () => {
    expect(at(withGender(415, 20, 'F'), 21)).toBe(416)
    expect(at(withGender(415, 20, 'M'), 21)).toBe(415)
    expect(at(withGender(412, 19, 'F'), 20)).toBe(413)
    expect(at(withGender(412, 19, 'M'), 20)).toBe(414)
    expect(at(withGender(757, 32, 'M'), 40)).toBe(757)
    expect(canEvolveWith(data, withGender(281, 30, 'M'), 'dawn-stone')).toEqual([475])
    expect(canEvolveWith(data, withGender(281, 30, 'F'), 'dawn-stone')).toEqual([])
    expect(canEvolveWith(data, withGender(361, 30, 'F'), 'dawn-stone')).toEqual([478])
    expect(at(withGender(677, 24, 'F'), 25)).toBe(10025)
    expect(at(withGender(677, 24, 'M'), 25)).toBe(678)
    expect(genderOf(data, mon(81, 10))).toBe(null)
  })

  it('Tyrogue pelo Ataque e pela Defesa; Wurmple e Clamperl continuam no sorteio', () => {
    const iv = (atk, def) => ({ hp: 0, atk, def, spa: 0, spd: 0, spe: 0 })
    expect(at(mon(236, 19, { ivs: iv(31, 0) }), 20)).toBe(106)
    expect(at(mon(236, 19, { ivs: iv(0, 31) }), 20)).toBe(107)
    expect(at(mon(236, 19, { ivs: iv(10, 10) }), 20)).toBe(237)
    expect(at(mon(236, 19, { ivs: iv(10, 10), nature: 'Adamant' }), 20)).toBe(106)
    expect(new Set([0, 0.99].map((r) => levelTo(mon(265, 6), 7, data, () => r)[0].id))).toEqual(new Set([266, 268]))
    // O Slowking (troca) não esconde o Slowbro: os dois no 37.
    expect(data.evolutions[79]).toEqual([[80, 37], [199, 37]])
  })
})
