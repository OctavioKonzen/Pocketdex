import { describe, it, expect } from 'vitest'
import characters from '../i18n/characters.json'

describe('nomes dos personagens (igual ao app)', () => {
  it('os oficiais de cada língua: [francês, espanhol]', () => {
    expect(characters.Brock).toEqual(['Pierre', 'Brock'])
    expect(characters.Falkner).toEqual(['Albert', 'Pegaso'])
    expect(characters.Leon).toEqual(['Tarak', 'Lionel'])
    for (const [en, local] of Object.entries(characters)) expect(local, en).toHaveLength(2)
  })
})
