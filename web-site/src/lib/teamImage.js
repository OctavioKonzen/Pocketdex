// Imagem do time para compartilhar (igual ao app, team_image.dart): nome do
// time e cada Pokémon com item, habilidade, Tera e golpes, na cor do time.
// Desenhada num canvas (1080 px de largura).

import { imageUrl, memberSprite, spriteUrl } from './data'
import { TYPE_COLORS } from './pokemon'

const W = 1080
const PAD = 48
const GAP = 24
const TILE = (W - PAD * 2 - GAP) / 2
const LINE = 38

const pretty = (slug = '') =>
  String(slug)
    .split('-')
    .map((w) => (w ? w[0].toUpperCase() + w.slice(1) : w))
    .join(' ')

function load(src) {
  return new Promise((resolve) => {
    const img = new Image()
    img.onload = () => resolve(img)
    img.onerror = () => resolve(null)
    img.src = src
  })
}

function round(ctx, x, y, w, h, r) {
  ctx.beginPath()
  ctx.roundRect(x, y, w, h, r)
}

function shade(hex, amount) {
  const n = parseInt(hex.slice(1), 16)
  const f = (c) => Math.round(c * (1 - amount))
  return `rgb(${f(n >> 16)}, ${f((n >> 8) & 255)}, ${f(n & 255)})`
}

function fit(ctx, text, max) {
  if (ctx.measureText(text).width <= max) return text
  let t = text
  while (t.length > 1 && ctx.measureText(`${t}…`).width > max) t = t.slice(0, -1)
  return `${t}…`
}

/** Monta a imagem e devolve um Blob PNG. byId: índice dos Pokémon (lib/data). */
export async function teamImage(team, byId) {
  const members = (team.pokemon ?? [])
    .map((id, i) => (id == null ? null : { id, set: team.sets?.[i] ?? null, p: byId.get(id) }))
    .filter((m) => m?.p)
  const lines = (m) => (m.set?.ability ? 1 : 0) + (m.set?.moves ?? []).filter(Boolean).length
  const tileH = (m) => 24 + 156 + lines(m) * LINE + 24
  const rows = []
  for (let i = 0; i < members.length; i += 2) rows.push(members.slice(i, i + 2))
  const rowH = rows.map((r) => Math.max(...r.map(tileH)))
  const H = PAD + 90 + 24 + rowH.reduce((a, b) => a + b + GAP, 0) + 90

  const canvas = document.createElement('canvas')
  canvas.width = W
  canvas.height = H
  const ctx = canvas.getContext('2d')
  const base = /^#[0-9a-f]{6}$/i.test(team.color ?? '') ? team.color : '#3949AB'
  const grad = ctx.createLinearGradient(0, 0, W, H)
  grad.addColorStop(0, base)
  grad.addColorStop(1, shade(base, 0.55))
  round(ctx, 0, 0, W, H, 72)
  ctx.fillStyle = grad
  ctx.fill()

  const font = (size, weight = 400) => `${weight} ${size}px system-ui, -apple-system, Segoe UI, Roboto, sans-serif`
  ctx.fillStyle = '#fff'
  ctx.textBaseline = 'top'
  ctx.font = font(72, 900)
  ctx.fillText(fit(ctx, team.name || 'Time', W - PAD * 2), PAD, PAD)

  const sprites = await Promise.all(members.map((m) => load(spriteUrl(memberSprite(m.p, m.set)))))
  let y = PAD + 90 + 24
  members.forEach((m, i) => {
    const row = Math.floor(i / 2)
    if (i % 2 === 0 && i > 0) y += rowH[row - 1] + GAP
    const x = PAD + (i % 2) * (TILE + GAP)
    round(ctx, x, y, TILE, tileH(m), 48)
    ctx.fillStyle = 'rgba(255,255,255,0.12)'
    ctx.fill()
    // Sprite recortado pela caixa (como o componente Sprite).
    const img = sprites[i]
    if (img) {
      ctx.imageSmoothingEnabled = false
      const [x0, y0, x1, y1] = m.p.box ?? [0, 0, img.width, img.height]
      const side = Math.max(x1 - x0, y1 - y0) / 0.95
      const sx = x0 - (side - (x1 - x0)) / 2
      const sy = y0 - (side - (y1 - y0)) / 2
      ctx.drawImage(img, sx, sy, side, side, x + 18, y + 18, 156, 156)
    }
    const tx = x + 186
    const tw = TILE - 186 - 18
    ctx.fillStyle = '#fff'
    ctx.font = font(39, 700)
    ctx.fillText(fit(ctx, m.set?.nickname?.trim() || pretty(m.p.name.split('-')[0]), tw), tx, y + 36)
    let ty = y + 84
    if (m.set?.item) {
      ctx.font = font(33)
      ctx.fillText(fit(ctx, `@ ${pretty(m.set.item)}`, tw), tx, ty)
      ty += 42
    }
    if (m.set?.tera) {
      ctx.font = font(27, 700)
      const label = `Tera ${pretty(m.set.tera)}`
      const w = ctx.measureText(label).width + 30
      round(ctx, tx, ty, w, 42, 21)
      ctx.fillStyle = TYPE_COLORS[m.set.tera] ?? '#888'
      ctx.fill()
      ctx.fillStyle = '#fff'
      ctx.fillText(label, tx + 15, ty + 7)
    }
    let ly = y + 18 + 156 + 6
    if (m.set?.ability) {
      ctx.font = font(33)
      ctx.fillStyle = 'rgba(255,255,255,0.75)'
      ctx.fillText(fit(ctx, pretty(m.set.ability), TILE - 48), x + 24, ly)
      ly += LINE
    }
    ctx.fillStyle = '#fff'
    for (const mv of (m.set?.moves ?? []).filter(Boolean)) {
      ctx.font = font(33)
      ctx.fillText(fit(ctx, `• ${pretty(mv)}`, TILE - 48), x + 24, ly)
      ly += LINE
    }
  })

  const logo = await load(imageUrl('poke_logo.png'))
  if (logo) ctx.drawImage(logo, PAD, H - 84, (logo.width / logo.height) * 60, 60)
  ctx.font = font(27)
  ctx.fillStyle = 'rgba(255,255,255,0.7)'
  ctx.textAlign = 'right'
  ctx.fillText('octaviokonzen.github.io/Pocketdex', W - PAD, H - 66)
  return new Promise((resolve) => canvas.toBlob(resolve, 'image/png'))
}
