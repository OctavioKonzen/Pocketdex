import { describe, expect, test } from 'vitest'
import ui from '../i18n/ui.json'

describe('dicionário de idiomas', () => {
  test('todo texto tem inglês, francês e espanhol com os mesmos marcadores', () => {
    for (const [pt, tr] of Object.entries(ui)) {
      const marks = (s) => (s.match(/\{\d+\}/g) ?? []).sort().join()
      for (const text of tr.slice(0, 3)) {
        expect(text, pt).toBeTruthy()
        expect(marks(text), pt).toBe(marks(pt))
      }
    }
  })
})
