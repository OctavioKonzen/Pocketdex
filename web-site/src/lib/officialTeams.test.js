import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { abilityText, appearances, evText, filterTrainers, generationsOf, ivText } from './officialTeams'

const games = JSON.parse(readFileSync(new URL('../../../assets/database/official_teams.json', import.meta.url), 'utf8'))
const game = (id) => games.find((g) => g.id === id)
const person = (gid, name, cls) => game(gid).trainers.find((t) => t.name === name && (!cls || t.class === cls))

describe('times oficiais dos personagens', () => {
  it('separa por jogo: da 1ª à 4ª geração e Scarlet/Violet', () => {
    expect(games.map((g) => g.id)).toEqual(['red-blue', 'yellow', 'gold-silver', 'crystal', 'ruby-sapphire', 'emerald', 'firered-leafgreen', 'platinum', 'scarlet-violet'])
    expect(generationsOf(games)).toEqual([1, 2, 3, 4, 9])
    for (const g of games) {
      expect(g.trainers.length).toBeGreaterThan(10)
      for (const t of g.trainers) for (const b of t.battles) expect(b.team.length).toBeGreaterThan(0)
    }
  })

  it('Cynthia (Platinum): níveis, item, IVs e nature como no jogo', () => {
    const team = person('platinum', 'Cynthia').battles[0].team
    expect(team.map((m) => m.level)).toEqual([58, 58, 60, 60, 58, 62])
    const garchomp = team[5]
    expect(garchomp.id).toBe(445)
    expect(garchomp.item).toBe('sitrus-berry')
    expect(garchomp.iv).toBe(30)
    expect(garchomp.nature).toBeTruthy()
    expect(ivText(garchomp)).toMatch(/^IVs: 30 em todos/)
    expect(evText(garchomp)).toBe('EVs: 0 em todos')
  })

  it('Red/Blue: golpe especial do líder e DVs de treinador', () => {
    const onix = person('red-blue', 'Brock').battles[0].team[1]
    expect(onix.moves).toEqual(['tackle', 'screech', 'bide'])
    expect(ivText(onix)).toBe('DVs: HP 8 · Atk 9 · Def 8 · Spe 8 · Spc 8')
    expect(evText(onix)).toBe('Stat Exp: 0')
    // O rival muda o inicial conforme o seu.
    const labels = person('red-blue', 'Blue', 'Campeão').battles.map((b) => b.label)
    expect(labels).toEqual(expect.arrayContaining(['Liga Pokémon (se você escolheu Charmander)']))
  })

  it('Geeta (Scarlet/Violet): Tera, EVs e habilidade definidos pelo jogo', () => {
    const team = person('scarlet-violet', 'Geeta').battles[0].team
    expect(team.map((m) => m.level)).toEqual([61, 61, 61, 61, 61, 62])
    const glimmora = team[5]
    expect(glimmora.id).toBe(970)
    expect(glimmora.tera).toBe('rock')
    expect(glimmora.moves).toEqual(['tera-blast', 'sludge-wave', 'earth-power', 'dazzling-gleam'])
    expect(ivText(glimmora)).toBe('IVs: 30 em todos')
    expect(evText(glimmora)).toBe('EVs: 252 HP')
    expect(abilityText(glimmora, (s) => s)).toBe('toxic-debris')
    expect(abilityText({ abilityOptions: ['a', 'b'] }, (s) => s)).toBe('a ou b (sorteada)')
    expect(ivText({ iv: null, ivNote: 'sorteados' })).toBe('IVs: sorteados')
  })

  it('mostra todas as aparições do personagem', () => {
    const brock = appearances(games, 'Brock').map((a) => a.game.id)
    expect(brock).toEqual(['red-blue', 'yellow', 'gold-silver', 'crystal', 'firered-leafgreen'])
    expect(filterTrainers(game('crystal'), 'elite').map((t) => t.name)).toEqual(['Will', 'Koga', 'Bruno', 'Karen'])
  })
})
