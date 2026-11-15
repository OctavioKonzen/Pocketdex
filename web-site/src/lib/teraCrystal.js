// O corpo cristalizado do Terastal: facetas de cristal na cor do Tera Type e
// um reflexo passando, desenhados só por cima dos pixels do Pokémon
// (source-atop). Igual ao app (lib/widgets/pokemon_sprite.dart, _CrystalPainter).

// Número "aleatório" fixo por posição (as facetas não mudam de um quadro para o outro).
const hash = (a, b, c) => {
  let n = (a * 374761393 + b * 668265263 + c * 2147483647) | 0
  n = Math.imul(n ^ (n >>> 13), 1274126177)
  return ((n ^ (n >>> 16)) >>> 0) / 4294967296
}

/**
 * As facetas de um sprite w × h: triângulos de uma grade com os cantos
 * mexidos, cada um claro, da cor ou escuro.
 * @returns {{points: number[], shade: 0 | 1 | 2}[]}
 */
export function crystalFacets(w, h) {
  const s = Math.max(5, Math.round(Math.max(w, h) / 9))
  const cols = Math.ceil(w / s) + 1
  const rows = Math.ceil(h / s) + 1
  const at = (i, j) => {
    const edge = i === 0 || j === 0 || i === cols || j === rows
    const jx = edge ? 0 : (hash(i, j, 1) - 0.5) * s * 0.7
    const jy = edge ? 0 : (hash(i, j, 2) - 0.5) * s * 0.7
    return [i * s + jx, j * s + jy]
  }
  const facets = []
  for (let j = 0; j < rows; j++) {
    for (let i = 0; i < cols; i++) {
      const a = at(i, j)
      const b = at(i + 1, j)
      const c = at(i + 1, j + 1)
      const d = at(i, j + 1)
      const tris = hash(i, j, 3) < 0.5 ? [[a, b, c], [a, c, d]] : [[a, b, d], [b, c, d]]
      tris.forEach((t, k) => {
        const v = hash(i, j, 4 + k)
        facets.push({ points: t.flat(), shade: v < 0.3 ? 0 : v < 0.75 ? 1 : 2 })
      })
    }
  }
  return facets
}

/** As facetas já pintadas (para desenhar por cima de cada quadro). */
export function crystalLayer(w, h, color) {
  const layer = document.createElement('canvas')
  layer.width = w
  layer.height = h
  const ctx = layer.getContext('2d')
  // Tinge o corpo todo com a cor do tipo.
  ctx.globalAlpha = 0.3
  ctx.fillStyle = color
  ctx.fillRect(0, 0, w, h)
  const fills = [
    ['#ffffff', 0.26],
    [color, 0.2],
    ['#000000', 0.12],
  ]
  for (const f of crystalFacets(w, h)) {
    const [x0, y0, x1, y1, x2, y2] = f.points
    ctx.beginPath()
    ctx.moveTo(x0, y0)
    ctx.lineTo(x1, y1)
    ctx.lineTo(x2, y2)
    ctx.closePath()
    ctx.globalAlpha = fills[f.shade][1]
    ctx.fillStyle = fills[f.shade][0]
    ctx.fill()
    // Aresta clara entre as facetas.
    ctx.globalAlpha = 0.2
    ctx.strokeStyle = '#ffffff'
    ctx.lineWidth = 0.6
    ctx.stroke()
  }
  return layer
}

/** Por cima do quadro já desenhado no canvas: o cristal e o reflexo (t de 0 a 1). */
export function drawCrystal(ctx, layer, w, h, t) {
  ctx.save()
  ctx.globalCompositeOperation = 'source-atop'
  ctx.drawImage(layer, 0, 0)
  // O reflexo: uma faixa branca na diagonal atravessando o corpo.
  const x = -w + 3 * w * t
  const g = ctx.createLinearGradient(x, 0, x + w * 0.45, h * 0.45)
  g.addColorStop(0, 'rgba(255,255,255,0)')
  g.addColorStop(0.5, 'rgba(255,255,255,0.5)')
  g.addColorStop(1, 'rgba(255,255,255,0)')
  ctx.fillStyle = g
  ctx.fillRect(0, 0, w, h)
  ctx.restore()
}
