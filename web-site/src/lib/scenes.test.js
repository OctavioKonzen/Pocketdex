import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { bossCity, sceneLines, sceneRegion, storyLine } from './factoryRun.js'

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

  it('a história de cada jogo (docs/historia): as falas do jogo primeiro, as da região quando ele não tem; sem a língua, o inglês', () => {
    const rb = data.bosses.find((b) => b.game === 'Red/Blue')
    const yellow = data.bosses.find((b) => b.game === 'Yellow')
    expect(sceneRegion(rb)).toBe('Kanto|Red/Blue')
    expect(sceneLines(data, sceneRegion(rb), 'before', 'Brock@Pewter City')[0][1]).toContain('defesa sólida')
    expect(sceneLines(data, sceneRegion(rb), 'before', 'Brock@Pewter City', 'fr')[0][1]).toContain('rock-hard defense')
    // O Yellow tem a fala do Blue com o Eevee; a do Brock é a de Red/Blue; o "último Pokémon" vem da região.
    expect(sceneLines(data, sceneRegion(yellow), 'before', 'Blue@Pewter City')[0][1]).toContain('Eevee')
    expect(sceneLines(data, sceneRegion(yellow), 'before', 'Brock@Pewter City')).toEqual(sceneLines(data, sceneRegion(rb), 'before', 'Brock@Pewter City'))
    expect(sceneLines(data, sceneRegion(yellow), 'last', 'Brock@Pewter City')).toEqual(sceneLines(data, 'Kanto', 'last', 'Brock@Pewter City'))
    // Todo chefe de todo jogo tem a fala dele antes e depois da luta.
    for (const g of data.bosses) {
      g.leaders.forEach((l) => {
        for (const kind of ['before', 'after']) expect(sceneLines(data, sceneRegion(g), kind, `${l.name}@${l.city}`).length, `${g.game} ${l.name}@${l.city} ${kind}`).toBeGreaterThan(0)
      })
      expect(storyLine(data, sceneRegion(g), 'intro').length, g.game).toBeGreaterThan(40)
    }
    expect(storyLine(data, sceneRegion(yellow), 'intro')).toContain('Pikachu')
    expect(storyLine(data, sceneRegion(yellow), 'gym', 'Brock')).toBe(storyLine(data, 'Kanto', 'gym', 'Brock'))
  })
})
