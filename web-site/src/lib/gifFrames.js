// Os quadros de um GIF já montados (cada um com a imagem inteira), o tempo de
// cada um e onde fica a cabeça (headAnchor.js) — para desenhar o sprite num
// canvas sabendo em que quadro ele está (a coroa do Terastal acompanha).
import { decompressFrames, parseGIF } from 'gifuct-js'
import { HeadTracker } from './headAnchor.js'

/** @returns {{width: number, height: number, frames: {data: Uint8ClampedArray, delay: number, head: {x: number, y: number} | null}[]}} */
export function gifFrames(buffer) {
  const gif = parseGIF(buffer)
  const { width, height } = gif.lsd
  const parts = decompressFrames(gif, true)
  const canvas = new Uint8ClampedArray(width * height * 4)
  const frames = []
  let tracker = null
  for (const part of parts) {
    const { left, top, width: pw, height: ph } = part.dims
    const before = part.disposalType === 3 ? canvas.slice() : null
    for (let y = 0; y < ph; y++) {
      const cy = top + y
      if (cy < 0 || cy >= height) continue
      for (let x = 0; x < pw; x++) {
        const cx = left + x
        if (cx < 0 || cx >= width) continue
        const s = (y * pw + x) * 4
        if (part.patch[s + 3] === 0) continue
        const d = (cy * width + cx) * 4
        canvas[d] = part.patch[s]
        canvas[d + 1] = part.patch[s + 1]
        canvas[d + 2] = part.patch[s + 2]
        canvas[d + 3] = part.patch[s + 3]
      }
    }
    const data = canvas.slice()
    // Como os navegadores: tempo 0 ou 10 ms vira 100 ms.
    tracker ??= new HeadTracker(data, width, height)
    frames.push({ data, delay: part.delay > 10 ? part.delay : 100, head: tracker.track(data) })
    if (part.disposalType === 2) {
      for (let y = Math.max(0, top); y < Math.min(height, top + ph); y++) canvas.fill(0, (y * width + Math.max(0, left)) * 4, (y * width + Math.min(width, left + pw)) * 4)
    } else if (before) canvas.set(before)
  }
  return { width, height, frames }
}
