import { readFileSync, writeFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { gifFrames } from './gifFrames'
import { HeadTracker, headAnchor } from './headAnchor'

// Os mesmos GIFs que o app confere (test/head_anchor_test.dart): a coroa do
// Terastal fica no mesmo lugar no site e no app.
const GIFS = ['front/6', 'front/94', 'front/282', 'back/25']
const heads = () =>
  Object.fromEntries(
    GIFS.map((name) => {
      const buf = readFileSync(new URL(`../../../assets/database/sprites/animated/${name}.gif`, import.meta.url))
      const { frames } = gifFrames(buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength))
      return [name, frames.map((f) => f.head && [Number(f.head.x.toFixed(4)), Number(f.head.y.toFixed(4))])]
    }),
  )

describe('headAnchor', () => {
  it('acha o topo da cabeça e ignora pontinhas finas', () => {
    // 10 × 6: uma antena de 1 pixel na coluna 2 e a cabeça (colunas 4 a 7) a partir da linha 2.
    const w = 10
    const h = 6
    const data = new Uint8ClampedArray(w * h * 4)
    const put = (x, y) => (data[(y * w + x) * 4 + 3] = 255)
    put(2, 0)
    put(2, 1)
    for (let y = 2; y < h; y++) for (let x = 4; x < 8; x++) put(x, y)
    expect(headAnchor(data, w, h)).toMatchObject({ x: 6, y: 2 })
    expect(headAnchor(new Uint8ClampedArray(w * h * 4), w, h)).toBeNull()
  })

  it('segue a cabeça quando ela anda', () => {
    const w = 20
    const h = 12
    const frame = (dx, dy) => {
      const data = new Uint8ClampedArray(w * h * 4)
      for (let y = 3; y < 10; y++) for (let x = 6; x < 12; x++) data.set([200, (x * 30) % 255, y * 20, 255], ((y + dy) * w + x + dx) * 4)
      return data
    }
    const tracker = new HeadTracker(frame(0, 0), w, h)
    expect(tracker.track(frame(0, 0))).toEqual({ x: 9 / w, y: 3 / h })
    expect(tracker.track(frame(3, 1))).toEqual({ x: 12 / w, y: 4 / h })
    expect(tracker.track(frame(1, -1))).toEqual({ x: 10 / w, y: 2 / h })
  })

  it('igual ao app nos GIFs da batalha', () => {
    const file = new URL('../../../test/fixtures/head_anchor.json', import.meta.url)
    // WRITE_FIXTURE=1 npx vitest run headAnchor → refaz o arquivo.
    if (process.env.WRITE_FIXTURE) writeFileSync(file, `${JSON.stringify(heads())}\n`)
    expect(heads()).toEqual(JSON.parse(readFileSync(file, 'utf8')))
  })
})
