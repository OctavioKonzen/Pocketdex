import { existsSync, readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { addHallOfFame, badgesNeeded, badgesOf, emptyLeague, leagueOpen, leagueOrder, musicOf, regionGyms, streakResult, winBadge } from './gymChallenge'

const regions = JSON.parse(readFileSync(new URL('../../../assets/database/gym_leaders.json', import.meta.url), 'utf8'))
const byName = (name) => regions.find((r) => r.region === name)

describe('jornada do Desafio dos Líderes', () => {
  it('insígnias liberam a Liga (8, ou todas as de Alola)', () => {
    const kanto = byName('Kanto')
    let league = emptyLeague()
    expect(leagueOpen(league, kanto)).toBe(false)
    for (const gym of regionGyms(kanto)) league = winBadge(league, regions, gym)
    // Repetir não duplica; Elite Four e campeão não dão insígnia.
    league = winBadge(league, regions, regionGyms(kanto)[0])
    league = winBadge(league, regions, leagueOrder(kanto)[0])
    expect(badgesOf(league, kanto)).toHaveLength(8)
    expect(leagueOpen(league, kanto)).toBe(true)
    expect(badgesNeeded(byName('Alola'))).toBe(4)
    expect(badgesNeeded(byName('Unova'))).toBe(8)
  })
  it('a Liga é a Elite Four e o último campeão', () => {
    expect(leagueOrder(byName('Kanto')).map((l) => l.name)).toEqual(['Lorelei', 'Bruno', 'Agatha', 'Lance', 'Blue'])
    expect(leagueOrder(byName('Unova')).at(-1).name).toBe('Iris')
    expect(leagueOrder(byName('Alola')).map((l) => l.name)).toEqual(['Kukui'])
  })
  it('Hall da Fama, sequências e música', () => {
    const league = addHallOfFame(emptyLeague(), byName('Johto'), [6, 9], 'red', 5)
    expect(league.hall).toEqual([{ region: 'Johto', at: 5, team: [6, 9], trainer: 'red' }])
    let l = streakResult(league, 'tower', true)
    l = streakResult(l, 'tower', true)
    l = streakResult(l, 'tower', false)
    expect(l.tower).toEqual({ best: 2, streak: 0 })
    expect(musicOf(null)).toBe('battle_music')
    expect(musicOf(leagueOrder(byName('Kanto')).at(-1))).toBe('champion_blue')
    expect(musicOf(leagueOrder(byName('Sinnoh')).at(-1))).toBe('champion_cynthia')
    expect(musicOf(regionGyms(byName('Kanto'))[0])).toBe('gym_kanto')
    expect(musicOf(regionGyms(byName('Galar'))[0])).toBe('gym_galar')
    expect(musicOf(null)).toBe('battle_music')
    // Todo líder tem a música no banco.
    for (const leader of regions.flatMap((r) => r.leaders)) {
      expect(existsSync(new URL(`../../../assets/database/sounds/${musicOf(leader)}.mp3`, import.meta.url)), leader.id).toBe(true)
    }
  })
})
