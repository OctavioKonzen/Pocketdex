import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import { analyzeTeam, levelUpMoves, rowSummary, typeRelations, heightToFeet, weightToLbs } from './pokemon'

const typeData = JSON.parse(readFileSync(new URL('../../public/data/types.json', import.meta.url)))
const species = (id) => JSON.parse(readFileSync(new URL(`../../public/data/pokemon/${id}.json`, import.meta.url)))

describe('tipos', () => {
  it('calcula fraquezas e imunidades do Charizard', () => {
    const rel = typeRelations(['fire', 'flying'], typeData)
    expect(rel.weaknesses.rock).toBe(4)
    expect(rel.weaknesses.water).toBe(2)
    expect(rel.immunities).toContain('ground')
    expect(rel.resistances.grass).toBe(0.25)
  })

  it('analisa o time contando quem é fraco, resiste e é imune a cada tipo', () => {
    // Charizard, Blastoise e Venusaur
    const analysis = analyzeTeam([['fire', 'flying'], ['water'], ['grass', 'poison']], typeData)
    expect(analysis.immunities).toEqual(['ground'])
    expect(analysis.rows.electric).toEqual({ weak: 2, x4: 0, resist: 1, immune: 0 })
    expect(rowSummary(analysis.rows.electric)).toBe('2 fracos · 1 resiste')
    expect(rowSummary(analysis.rows.rock)).toBe('1 fraco (1 ×4)')
    const weak = analysis.weaknesses.map(([t]) => t)
    expect(weak).toContain('electric')
    expect(weak).toContain('rock')
    expect(weak).not.toContain('ice') // 1 fraco e 1 resiste: empate não é fraqueza
    expect(weak).not.toContain('ground') // Charizard é imune
    expect(analysis.strengths.map(([t]) => t)).toContain('grass')
    expect(analyzeTeam([], typeData)).toBeNull()
  })
})

describe('dados do site', () => {
  it('tem as formas e a evolução do Charizard', () => {
    const charizard = species(6)
    expect(charizard.forms.map((f) => f.formName)).toEqual(['Default', 'Mega X', 'Mega Y', 'Gmax'])
    expect(charizard.evolution.map((e) => e.trigger)).toEqual(['(Level 16)', '(Level 36)'])
  })

  it('lista golpes por nível em ordem', () => {
    const moves = levelUpMoves(species(25).forms[0])
    expect(moves.length).toBeGreaterThan(5)
    expect(moves.map((m) => m.level)).toEqual([...moves.map((m) => m.level)].sort((a, b) => a - b))
  })

  it('formata altura e peso como o app', () => {
    expect(heightToFeet(17)).toBe(`5' 07"`)
    expect(weightToLbs(905)).toBe('199.5 lbs')
  })
})
