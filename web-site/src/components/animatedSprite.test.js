import { describe, expect, it } from 'vitest'
import { animatedOf } from './Sprite'

describe('animação de formas sem PNG', () => {
  const set = {
    folder: 'animated',
    front: new Set([10301]), shiny: new Set([10301]),
    back: new Set(), 'back-shiny': new Set(),
    forms: {}, still: { front: new Set(), shiny: new Set(), back: new Set(), 'back-shiny': new Set() },
    fit: {}, foot: {}, size: {}, hash: {},
  }
  it('usa o GIF do Mega Zygarde a partir da arte oficial', () => {
    expect(animatedOf('pokemon/other/official-artwork/10301.png', set, false)?.gif).toBe('animated/front/10301.gif')
    expect(animatedOf('pokemon/other/official-artwork/shiny/10301.webp', set, false)?.gif).toBe('animated/shiny/10301.gif')
  })
})
