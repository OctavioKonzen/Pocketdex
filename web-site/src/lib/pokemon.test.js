import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import { analyzeTeam, levelUpMoves, teamScore, typeRelations, heightToFeet, weightToLbs } from './pokemon'

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

  it('analisa um time e dá nota entre 0 e 10', () => {
    const analysis = analyzeTeam([['fire', 'flying'], ['water'], ['grass', 'poison']], typeData)
    expect(analysis.immunities).toContain('ground')
    const score = teamScore(analysis)
    expect(score).toBeGreaterThan(0)
    expect(score).toBeLessThanOrEqual(10)
    expect(teamScore(null)).toBe(0)
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
