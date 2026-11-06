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
    // Repetir não duplica; Elite dos Quatro e campeão não dão insígnia.
    league = winBadge(league, regions, regionGyms(kanto)[0])
    league = winBadge(league, regions, leagueOrder(kanto)[0])
    expect(badgesOf(league, kanto)).toHaveLength(8)
    expect(leagueOpen(league, kanto)).toBe(true)
    expect(badgesNeeded(byName('Alola'))).toBe(4)
    expect(badgesNeeded(byName('Unova'))).toBe(8)
  })
  it('a Liga é a Elite dos Quatro e o último campeão', () => {
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
    expect(musicOf(null)).toMatch(/^map_/) // sem líder e sem Pokémon: uma região, nunca a batalha comum antiga
    // O campeão, por enquanto, com o tema da região (os temas de campeão estão sendo refeitos).
    expect(musicOf(leagueOrder(byName('Kanto')).at(-1))).toBe('champion_blue')
    // O Blue como rival tem o tema dele (o "normal"); rival sem tema: o da região.
    expect(musicOf({ id: 'kanto-blue', name: 'Blue', kind: 'rival' })).toBe('rival_blue')
    expect(musicOf({ id: 'johto-silver', name: 'Silver', kind: 'rival' })).toBe('rival_silver')
    expect(musicOf({ id: 'sinnoh-barry', name: 'Barry', kind: 'rival' })).toBe('rival_barry')
    expect(musicOf({ id: 'unova-cheren', name: 'Cheren', kind: 'rival' })).toBe('rival_cheren')
    expect(musicOf({ id: 'unova-hugh', name: 'Hugh', kind: 'rival' })).toBe('rival_hugh')
    expect(musicOf({ id: 'unova-n', name: 'N', kind: 'rival' })).toBe('rival_n')
    // Vilões: o chefe com o tema dele, os comandantes com o da equipe, N com o dele; sem tema: a região.
    expect(musicOf({ id: 'kanto-giovanni', name: 'Giovanni', kind: 'villain' })).toBe('villain_giovanni')
    expect(musicOf({ id: 'johto-archer', name: 'Archer', kind: 'villain' })).toBe('villain_team_rocket')
    expect(musicOf({ id: 'unova-n', name: 'N', kind: 'villain' })).toBe('rival_n')
    expect(musicOf({ id: 'hoenn-maxie', name: 'Maxie', kind: 'villain' })).toBe('villain_maxie')
    expect(musicOf({ id: 'hoenn-shelly', name: 'Shelly', kind: 'villain' })).toBe('villain_team_aqua')
    expect(musicOf({ id: 'sinnoh-cyrus', name: 'Cyrus', kind: 'villain' })).toBe('villain_cyrus')
    expect(musicOf({ id: 'sinnoh-mars', name: 'Mars', kind: 'villain' })).toBe('villain_team_galactic')
    expect(musicOf({ id: 'unova-ghetsis', name: 'Ghetsis', kind: 'villain' })).toBe('villain_ghetsis')
    expect(musicOf({ id: 'paldea-penny', name: 'Penny', kind: 'villain' })).toBe('villain_penny')
    expect(musicOf({ id: 'galar-rose', name: 'Rose', kind: 'villain' })).toBe('villain_rose')
    expect(musicOf({ id: 'alola-hau', name: 'Hau', kind: 'champion' })).toBe('rival_hau')
    expect(musicOf({ id: 'kanto-jessie-e-james', name: 'Jessie e James', kind: 'rival', guest: true, pair: true })).toBe('villain_jessie-e-james')
    expect(musicOf({ id: 'galar-oleana', name: 'Oleana', kind: 'villain' })).toBe('villain_team_macro')
    expect(musicOf({ id: 'galar-equipe-yell', name: 'Equipe Yell', kind: 'villain' })).toBe('villain_team_yell')
    expect(musicOf({ id: 'galar-sordward-e-shielbert', name: 'Sordward e Shielbert', kind: 'rival', guest: true, pair: true })).toBe('rival_sordward-e-shielbert')
    expect(musicOf({ id: 'unova-cynthia', name: 'Cynthia', kind: 'rival', guest: true })).toBe('champion_cynthia')
    expect(musicOf({ id: 'johto-red', name: 'Red', kind: 'rival', guest: true })).toBe('rival_red')
    expect(musicOf({ id: 'alola-lillie', name: 'Lillie', kind: 'rival', guest: true })).toBe('rival_lillie')
    expect(musicOf({ id: 'kalos-az', name: 'AZ', kind: 'rival', guest: true })).toBe('rival_az')
    expect(musicOf({ id: 'alola-anabel', name: 'Anabel', kind: 'rival', guest: true })).toBe('rival_anabel')
    expect(musicOf({ id: 'alola-dexio', name: 'Dexio', kind: 'rival', guest: true })).toBe('rival_dexio')
    expect(musicOf({ id: 'alola-sina', name: 'Sina', kind: 'rival', guest: true })).toBe('rival_sina')
    expect(musicOf({ id: 'unova-benga', name: 'Benga', kind: 'rival', guest: true })).toBe('rival_benga')
    expect(musicOf({ id: 'johto-eusine', name: 'Eusine', kind: 'rival', guest: true })).toBe('rival_eusine')
    expect(musicOf({ id: 'alola-ryuki', name: 'Ryuki', kind: 'rival', guest: true })).toBe('rival_ryuki')
    for (const [name, track] of [['Serena', 'serena-calem'], ['Calem', 'serena-calem'], ['Shauna', 'shauna'], ['Tierno', 'tierno'], ['Trevor', 'trevor']]) {
      expect(musicOf({ id: `kalos-${name.toLowerCase()}`, name, kind: 'rival' })).toBe(`rival_${track}`)
    }
    for (const name of ['Brendan', 'May', 'Brendan/May']) expect(musicOf({ id: 'hoenn-brendan', name, kind: 'rival' })).toBe('rival_brendan-may')
    expect(musicOf({ id: 'hoenn-wally', name: 'Wally', kind: 'rival' })).toBe('rival_wally')
    expect(musicOf(leagueOrder(byName('Sinnoh')).at(-1))).toBe('champion_cynthia')
    // Sem líder: a região do primeiro Pokémon do adversário (como no app).
    expect(musicOf(null, 25)).toBe('map_kanto')
    expect(musicOf(null, 448)).toBe('map_sinnoh')
    expect(musicOf(null, 10034, 7)).toBe(musicOf(null, 10034, 7))
    expect(musicOf(regionGyms(byName('Kanto'))[0])).toBe('gym_kanto') // o tema de ginásio de Kanto
    expect(musicOf(regionGyms(byName('Galar'))[0])).toBe('gym_galar')
    expect(musicOf({ id: 'kalos-malva', name: 'Malva', kind: 'elite' })).toBe('elite_kalos')
    expect(musicOf(null)).toMatch(/^map_/) // sem líder e sem Pokémon: uma região, nunca a batalha comum antiga
    // Todo líder tem a música no banco.
    for (const leader of regions.flatMap((r) => r.leaders)) {
      expect(existsSync(new URL(`../../../assets/database/sounds/music/${musicOf(leader)}.ogg`, import.meta.url)), leader.id).toBe(true)
    }
  })
})
