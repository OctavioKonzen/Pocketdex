import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { BIOME_TRAINERS, genericTrainer, isPairTrainer, pairTrainer, trainerClass, trainerPersona, TRAINER_INTROS, TRAINER_BEATS } from './trainers'

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
  it('treinador comum com nome e fala, sempre os mesmos para a mesma semente (igual ao app)', () => {
    const swimmer = list.find((t) => t.id === 'sd-swimmerf')
    const p = trainerPersona(swimmer, 123456)
    expect(p).toEqual(trainerPersona(swimmer, 123456))
    expect(p.name.startsWith('Swimmer ')).toBe(true)
    expect(TRAINER_INTROS).toContain(p.intro)
    expect(TRAINER_BEATS).toContain(p.beat)
    // Fixo para conferir com o app.
    expect(trainerPersona(list.find((t) => t.id === 'youngster'), 987654321)).toEqual({ name: `Youngster ${['Joel', 'Ben', 'Tim', 'Eli', 'Theo', 'Lucas', 'Rafa', 'Davi', 'Leo', 'Noah', 'Hugo', 'Igor', 'Caio', 'Enzo', 'Gabe', 'Otto', 'Bruno', 'Dante', 'Felix', 'Ivo'][(987654321 >>> 3) % 20]}`, intro: TRAINER_INTROS[(987654321 >>> 7) % 8], beat: TRAINER_BEATS[(987654321 >>> 11) % 6] })
  })
})
