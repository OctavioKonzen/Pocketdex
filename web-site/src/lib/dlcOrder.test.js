import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { startRun, emptyFactory, nextFloor, chooseNode, winFloor, CITY_BOSS } from './factoryRun.js'

const data = JSON.parse(readFileSync(new URL('../../../assets/database/factory.json', import.meta.url), 'utf8'))
const at = (name) => data.bosses.findIndex((b) => b.region === name)
/** Vence o último chefe da região e devolve a corrida já na próxima. */
function finish(region, played) {
  const last = data.bosses[region].leaders.length - 1
  let run = { ...startRun(emptyFactory(), data, 4, 3), floor: 1 + CITY_BOSS, leg: 1, boss: { region, step: last }, played }
  run = winFloor(chooseNode(nextFloor(run, data), data, 0), data)
  return run
}

describe('ordem das regiões (igual ao app)', () => {
  it('a corrida nunca começa numa expansão (Kitakami, Blueberry)', () => {
    for (let seed = 1; seed < 60; seed++) expect(data.bosses[startRun(emptyFactory(), data, 1, seed).boss.region].after).toBeUndefined()
  })

  it('a expansão vem logo depois do jogo dela: Paldea → Kitakami → Blueberry', () => {
    const kita = finish(at('Paldea'), ['Paldea'])
    expect(data.bosses[kita.boss.region].region).toBe('Kitakami')
    const blue = finish(at('Kitakami'), ['Paldea', 'Kitakami'])
    expect(data.bosses[blue.boss.region].region).toBe('Blueberry')
    // As Ilhas Sevii vêm depois de Kanto no FireRed/LeafGreen (nos outros jogos de Kanto, não).
    const frlg = data.bosses.findIndex((b) => b.game === 'FireRed/LeafGreen')
    expect(data.bosses[finish(frlg, ['Kanto']).boss.region].region).toBe('Sevii')
    // Galar → Ilha da Armadura → Terras da Coroa; Kanto (Red/Blue) → Ilhas Laranja, como no anime.
    expect(data.bosses[finish(at('Galar'), ['Galar']).boss.region].region).toBe('Armor')
    expect(data.bosses[finish(at('Armor'), ['Galar', 'Armor']).boss.region].region).toBe('Crown')
    expect(data.bosses[finish(at('Kanto'), ['Kanto']).boss.region].region).toBe('Orange')
    const other = finish(at('Johto'), ['Johto'])
    expect(data.bosses[other.boss.region].after).toBeUndefined()
  })
})
