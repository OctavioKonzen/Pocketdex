import { describe, expect, it } from 'vitest'
import { nameKey, validateName } from './auth'

describe('nomes de usuário', () => {
  it('trata maiúsculas, acentos e espaços como o mesmo nome', () => {
    expect(nameKey('  Ash   Ketchum ')).toBe('ash ketchum')
    expect(nameKey('JOÃO')).toBe(nameKey('joao'))
  })

  it('valida tamanho e caracteres', () => {
    expect(validateName('Al')).toMatch(/pelo menos/)
    expect(validateName('a'.repeat(21))).toMatch(/no máximo/)
    expect(validateName('Ash<script>')).toMatch(/Use só/)
    expect(validateName('Mestre Pokémon_1')).toBeNull()
  })
})
