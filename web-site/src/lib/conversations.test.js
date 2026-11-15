import { describe, expect, it } from 'vitest'
import { chatTime, conversationOrder } from './friends'

describe('Conversas', () => {
  it('mais recente primeiro; sem mensagem no fim, por nome', () => {
    const list = [{ name: 'bia' }, { name: 'Ana' }, { name: 'Caio', last: { at: 10 } }, { name: 'Duda', last: { at: 20 } }]
    expect(conversationOrder(list).map((f) => f.name)).toEqual(['Duda', 'Caio', 'Ana', 'bia'])
  })
  it('hora da última mensagem', () => {
    const now = new Date(2026, 8, 30, 15, 0)
    expect(chatTime(now - 20000, now)).toBe('agora')
    expect(chatTime(now - 5 * 60000, now)).toBe('5 min')
    expect(chatTime(new Date(2026, 8, 30, 11, 30).getTime(), now)).toBe('3 h')
    expect(chatTime(new Date(2026, 8, 29, 23, 0).getTime(), now)).toBe('ontem')
    expect(chatTime(new Date(2026, 8, 3, 9, 0).getTime(), now)).toBe('03/09')
  })
})
