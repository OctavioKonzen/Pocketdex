// Onde fica o topo da cabeça em cada quadro do sprite, para a coroa do
// Terastal acompanhar a animação. Igual ao app (lib/widgets/pokemon_sprite.dart,
// headAnchor e HeadTracker).
//
// No primeiro quadro, o topo é a primeira linha com pixels suficientes
// (pontinhas finas como antenas, orelhas e chifres não contam) e o meio é o
// centro do que aparece logo abaixo. Nos outros quadros, procura onde aquele
// pedaço da cabeça foi parar (sempre comparando com o primeiro quadro, então
// a coroa não escorrega para a asa ou o rabo com o tempo).

const alpha = (data, w, x, y) => data[(y * w + x) * 4 + 3]

/**
 * @param data RGBA do quadro inteiro (w × h)
 * @returns {{x: number, y: number} | null} em pixels
 */
export function headAnchor(data, w, h) {
  let x0 = w
  let x1 = -1
  let y0 = -1
  let y1 = -1
  const counts = new Array(h).fill(0)
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      if (alpha(data, w, x, y) < 128) continue
      counts[y]++
      if (x < x0) x0 = x
      if (x > x1) x1 = x
      if (y0 < 0) y0 = y
      y1 = y
    }
  }
  if (y0 < 0) return null
  const need = Math.max(2, Math.floor((x1 - x0 + 1) * 0.12))
  let top = y0
  while (top < y1 && counts[top] < need) top++
  const band = Math.max(2, Math.floor((y1 - y0 + 1) * 0.08))
  let lo = w
  let hi = -1
  for (let y = top; y <= Math.min(y1, top + band); y++) {
    for (let x = 0; x < w; x++) {
      if (alpha(data, w, x, y) < 128) continue
      if (x < lo) lo = x
      if (x > hi) hi = x
    }
  }
  return { x: Math.floor((lo + hi + 1) / 2), y: top, x0, x1, y0, y1 }
}

/** Segue a cabeça quadro a quadro (o pedaço dela no primeiro quadro). */
export class HeadTracker {
  constructor(data, w, h) {
    this.w = w
    this.h = h
    const head = headAnchor(data, w, h)
    this.head = head
    if (!head) return
    const pw = Math.max(6, Math.floor((head.x1 - head.x0 + 1) * 0.22))
    const ph = Math.max(6, Math.floor((head.y1 - head.y0 + 1) * 0.18))
    // O pedaço: a cabeça logo abaixo do topo (um pouco de ar em cima).
    this.left = head.x - (pw >> 1)
    this.top = head.y - 2
    this.pw = pw
    this.ph = ph + 2
    this.patch = new Int32Array(this.pw * this.ph * 4)
    for (let y = 0; y < this.ph; y++)
      for (let x = 0; x < this.pw; x++) this.#pixel(data, this.left + x, this.top + y, this.patch, (y * this.pw + x) * 4)
    this.reach = Math.max(4, Math.floor(Math.max(w, h) * 0.12))
    this.dx = 0
    this.dy = 0
  }

  #pixel(data, x, y, out, o) {
    if (x < 0 || y < 0 || x >= this.w || y >= this.h || data[(y * this.w + x) * 4 + 3] < 128) {
      out[o] = out[o + 1] = out[o + 2] = out[o + 3] = 0
      return
    }
    const i = (y * this.w + x) * 4
    out[o] = data[i]
    out[o + 1] = data[i + 1]
    out[o + 2] = data[i + 2]
    out[o + 3] = 255
  }

  /** @returns {{x: number, y: number} | null} a cabeça neste quadro, em fração da imagem */
  track(data) {
    if (!this.head) return null
    const px = new Int32Array(4)
    let best = Infinity
    let bx = this.dx
    let by = this.dy
    // Perto de onde estava no quadro anterior; empate fica com o mais perto dele.
    for (let r = 0; r <= this.reach; r++) {
      for (let oy = -r; oy <= r; oy++) {
        for (let ox = -r; ox <= r; ox++) {
          if (Math.max(Math.abs(ox), Math.abs(oy)) !== r) continue
          const sx = this.dx + ox
          const sy = this.dy + oy
          if (Math.max(Math.abs(sx), Math.abs(sy)) > this.reach * 2) continue
          let cost = 0
          for (let y = 0; y < this.ph && cost < best; y++) {
            for (let x = 0; x < this.pw; x++) {
              this.#pixel(data, this.left + sx + x, this.top + sy + y, px, 0)
              const o = (y * this.pw + x) * 4
              const a = this.patch[o + 3]
              if (a !== px[3]) cost += 300
              else if (a) cost += Math.abs(this.patch[o] - px[0]) + Math.abs(this.patch[o + 1] - px[1]) + Math.abs(this.patch[o + 2] - px[2])
            }
          }
          if (cost < best) {
            best = cost
            bx = sx
            by = sy
          }
        }
      }
      if (best === 0) break
    }
    this.dx = bx
    this.dy = by
    return { x: (this.head.x + bx) / this.w, y: (this.head.y + by) / this.h }
  }
}
