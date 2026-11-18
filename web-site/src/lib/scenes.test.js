import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { bossCity, sceneLines } from './factoryRun.js'

const data = JSON.parse(readFileSync(new URL('../../../assets/database/factory.json', import.meta.url), 'utf8'))

describe('a história em cenas (igual ao app)', () => {
  it('ao chegar na cidade, antes, no meio e depois da luta; na língua escolhida', () => {
    expect(sceneLines(data, 'Kanto', 'city', 'Saffron City')[0][1]).toContain('Silph Co.')
    expect(sceneLines(data, 'Kanto', 'city', 'Saffron City', 'en')[0][1]).toContain('Saffron City is locked down')
    const before = sceneLines(data, 'Kanto', 'before', 'Giovanni@Saffron City', 'fr')
    expect(before[0][0]).toBe('Giovanni')
    expect(before[0][1]).toContain('Master Ball')
    expect(sceneLines(data, 'Kanto', 'last', 'Brock@Pewter City', 'es')[0][1]).toContain('último')
    expect(sceneLines(data, 'Kanto', 'after', 'Blue@Indigo Plateau').map((l) => l[0])).toEqual(['Blue', 'Oak'])
    expect(sceneLines(data, 'Johto', 'city', 'Nowhere')).toEqual([])
  })

  it('cada chefe de Kanto tem a sua fala antes, no meio e depois da luta, nas 4 línguas', () => {
    for (const g of data.bosses.filter((b) => b.region === 'Kanto')) {
      g.leaders.forEach((l, step) => {
        const key = `${l.name}@${bossCity(data, { boss: { region: data.bosses.indexOf(g), step } })}`
        for (const kind of ['before', 'last', 'after']) {
          const list = data.scenes.Kanto.bosses[key]?.[kind]
          expect(list?.length, `${g.game} ${key} ${kind}`).toBeGreaterThan(0)
          for (const line of list) expect(line.length, key).toBe(5)
        }
      })
    }
  })
})
