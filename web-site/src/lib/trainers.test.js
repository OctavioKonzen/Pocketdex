import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { BIOME_TRAINERS, genericTrainer, isPairTrainer, pairTrainer, trainerClass } from './trainers'

const list = JSON.parse(readFileSync(new URL('../../../assets/database/trainers.json', import.meta.url), 'utf8'))

describe('treinadores', () => {
  it('treinador comum do lugar: nadador na água, esquiador na neve; um contra um só com quem está sozinho (igual ao app)', () => {
    for (let seed = 0; seed < 30; seed++) {
      expect(BIOME_TRAINERS.water).toContain(trainerClass(genericTrainer(list, seed, 'water')))
      expect(BIOME_TRAINERS.snow).toContain(trainerClass(genericTrainer(list, seed, 'snow')))
      expect(isPairTrainer(genericTrainer(list, seed, 'city'))).toBe(false)
      expect(isPairTrainer(pairTrainer(list, seed))).toBe(true)
    }
    // Lugar sem lista (ou nenhum): qualquer treinador comum.
    expect(genericTrainer(list, 3, 'base-rocket')).not.toBeNull()
    expect(genericTrainer(list, 3)).not.toBeNull()
  })
})
