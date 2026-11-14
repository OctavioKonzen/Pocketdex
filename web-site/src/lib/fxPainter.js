// Desenha as camadas de um golpe (battleFx.js) num <canvas>, no instante [ms], com a câmera do golpe.
// Tudo é desenhado em coordenadas do mundo (960 × 540) e a câmera leva para a tela. Igual ao app (battle_fx_painter.dart).

import { fxCamera, fxEase, fxRand, fxShake } from './battleFx'

const clamp = (v, a = 0, b = 1) => Math.max(a, Math.min(b, v))
const lerp = (a, b, k) => a + (b - a) * k
/** Um número da camada no ponto [k] (0 a 1): fixo ou [de, até]. */
const at = (v, k) => (Array.isArray(v) && typeof v[0] === 'number' ? lerp(v[0], v[1], fxEase(k)) : v)
const lin = (v, k) => (Array.isArray(v) && typeof v[0] === 'number' ? lerp(v[0], v[1], k) : v)

/** Cor com transparência. */
function rgba(hex, a) {
  if (hex.startsWith('rgba')) return hex
  const n = parseInt(hex.slice(1), 16)
  const [r, g, b] = hex.length === 4 ? [((n >> 8) & 15) * 17, ((n >> 4) & 15) * 17, (n & 15) * 17] : [(n >> 16) & 255, (n >> 8) & 255, n & 255]
  return `rgba(${r},${g},${b},${clamp(a)})`
}

/** Aplica a câmera do golpe ao contexto (o mundo fica na tela). [w, h] o tamanho da tela. */
export function applyCamera(g, plan, ms, w, h) {
  const [cx, cy, z, r] = fxCamera(plan, ms)
  const [sx, sy] = fxShake(plan, ms)
  const [ww, wh] = plan.world ?? [960, 540]
  const fit = Math.min(w / ww, h / wh)
  g.translate(w / 2 + sx * fit, h / 2 + sy * fit)
  g.rotate((r * Math.PI) / 180)
  g.scale(z * fit, z * fit)
  g.translate(-cx, -cy)
}

/** A transformação CSS do mundo (os sprites e o fundo, num <div> de 960 × 540) para a mesma câmera. */
export function cameraCss(plan, ms, w, h) {
  const [cx, cy, z, r] = fxCamera(plan, ms)
  const [sx, sy] = fxShake(plan, ms)
  const [ww, wh] = plan.world ?? [960, 540]
  const fit = Math.min(w / ww, h / wh)
  return `translate(${w / 2 + sx * fit}px,${h / 2 + sy * fit}px) rotate(${r}deg) scale(${z * fit}) translate(${-cx}px,${-cy}px)`
}

/** A mesma câmera para um campo cujos filhos já estão em pixels da tela (a batalha): sem a escala do mundo. */
export function cameraCssPx(plan, ms, w, h) {
  const [cx, cy, z, r] = fxCamera(plan, ms)
  const [sx, sy] = fxShake(plan, ms)
  const f = w / (plan.world ?? [960, 540])[0]
  return `translate(${w / 2 + sx * f}px,${h / 2 + sy * f}px) rotate(${r}deg) scale(${z}) translate(${-cx * f}px,${-cy * f}px)`
}

/** O tamanho do mundo do golpe que está sendo desenhado (as camadas de tela usam). */
let VW = 960
let VH = 540

/** Desenha as camadas. Camadas de tela (tint, fill) ficam sem câmera. */
export function paintFx(g, plan, ms, w, h) {
  g.clearRect(0, 0, w, h)
  ;[VW, VH] = plan.world ?? [960, 540]
  for (const L of plan.layers) {
    if (ms < L.t0 || ms > L.t1) continue
    const k = (ms - L.t0) / Math.max(1, L.t1 - L.t0)
    g.save()
    if (L.s === 'tint' || L.s === 'fill' || L.s === 'wave') {
      g.scale(w / VW, h / VH)
      SCREEN[L.s](g, L, k, ms)
    } else {
      applyCamera(g, plan, ms, w, h)
      const f = SHAPES[L.s]
      if (f) f(g, L, k, ms)
    }
    g.restore()
  }
}

/** Brilho redondo (bola de energia, impacto): miolo claro até a borda. */
function glow(g, L, k, ms) {
  const x = at(L.x, k)
  const y = at(L.y, k)
  const r = at(L.r, k)
  const a = at(L.a, k)
  if (r <= 0 || a <= 0) return
  const c = L.c
  if (L.trail) {
    // Rastro atrás da bola, quando ela voa.
    const x0 = at(L.x, Math.max(0, k - 0.25))
    const y0 = at(L.y, Math.max(0, k - 0.25))
    const lg = g.createLinearGradient(x0, y0, x, y)
    lg.addColorStop(0, rgba(c[c.length - 1], 0))
    lg.addColorStop(1, rgba(c[1], 0.7 * a))
    g.strokeStyle = lg
    g.lineWidth = r * 1.2
    g.lineCap = 'round'
    g.beginPath()
    g.moveTo(x0, y0)
    g.lineTo(x, y)
    g.stroke()
  }
  const rg = g.createRadialGradient(x - r * 0.15, y - r * 0.15, r * 0.05, x, y, r)
  const core = L.core ?? 0.15
  rg.addColorStop(0, rgba(c[0], a))
  rg.addColorStop(core, rgba(c[0], a))
  rg.addColorStop(Math.min(0.95, core + 0.3), rgba(c[1], a))
  if (c[2]) rg.addColorStop(0.85, rgba(c[2], a * 0.9))
  rg.addColorStop(1, rgba(c[3] ?? c[2] ?? c[1], 0))
  g.fillStyle = rg
  g.beginPath()
  g.arc(x, y, r, 0, Math.PI * 2)
  g.fill()
  if (L.swirl) {
    // Riscos girando por dentro (energia viva).
    g.strokeStyle = rgba(c[0], 0.7 * a)
    g.lineWidth = Math.max(1, r * 0.06)
    for (let i = 0; i < 3; i++) {
      const s = ms / 160 + (i * Math.PI * 2) / 3
      g.beginPath()
      g.arc(x, y, r * (0.45 + i * 0.15), s, s + 1.6)
      g.stroke()
    }
  }
}

/** Raios de luz saindo de um ponto e girando. */
function rays(g, L, k) {
  const x = at(L.x, k)
  const y = at(L.y, k)
  const a = at(L.a, k)
  const rot = lin(L.rot ?? 0, k)
  for (let i = 0; i < L.n; i++) {
    const ang = (i / L.n) * Math.PI * 2 + rot + fxRand(i) * 0.3
    const r0 = at(L.r0 ?? 0, k)
    const r1 = at(L.r1, k) * (0.6 + 0.6 * fxRand(i + 20))
    const lg = g.createLinearGradient(x + Math.cos(ang) * r0, y + Math.sin(ang) * r0, x + Math.cos(ang) * r1, y + Math.sin(ang) * r1)
    lg.addColorStop(0, rgba(L.c, a))
    lg.addColorStop(1, rgba(L.c2 ?? L.c, 0))
    g.strokeStyle = lg
    g.lineWidth = at(L.w, k) * (0.5 + fxRand(i + 40))
    g.beginPath()
    g.moveTo(x + Math.cos(ang) * r0, y + Math.sin(ang) * r0)
    g.lineTo(x + Math.cos(ang) * r1, y + Math.sin(ang) * r1)
    g.stroke()
  }
}

/** Anéis (ondas de som, de mente, fios enrolando, redoma). n anéis, um depois do outro; spiral: giram. */
function ring(g, L, k, ms) {
  const n = L.n ?? 1
  for (let i = 0; i < n; i++) {
    const kk = L.stagger || L.spiral ? clamp(k * (1 + (n - 1) * 0.35) - i * 0.35) : k
    if (kk <= 0 || kk >= 1) continue
    const x = at(L.x, kk)
    const y = at(L.y, kk)
    const r = at(L.r, kk)
    const a = at(L.a, kk)
    g.strokeStyle = rgba(L.c, a)
    g.lineWidth = at(L.w, kk)
    g.beginPath()
    if (L.spiral) {
      const s = ms / 120 + i
      g.ellipse(x, y, r, r * (L.ratio ?? 1), 0, s, s + Math.PI * 1.5)
    } else g.ellipse(x, y, r, r * (L.ratio ?? 1), 0, 0, Math.PI * 2)
    g.stroke()
  }
}

/** Uma partícula no estilo do tipo. */
function particle(g, style, x, y, s, color, a, rot) {
  g.globalAlpha = clamp(a)
  g.fillStyle = color
  g.strokeStyle = color
  switch (style) {
    case 'ember':
    case 'spark':
    case 'dust':
    case 'glint':
      // Quadradinhos de pixel (como no jogo).
      g.fillRect(x - s / 2, y - s / 2, s, s)
      if (style === 'glint' || style === 'spark') {
        g.fillRect(x - s * 1.4, y - s / 6, s * 2.8, s / 3)
        g.fillRect(x - s / 6, y - s * 1.4, s / 3, s * 2.8)
      }
      break
    case 'smoke': {
      const rg = g.createRadialGradient(x, y, 0, x, y, s * 2.5)
      rg.addColorStop(0, rgba(color, a * 0.6))
      rg.addColorStop(1, rgba(color, 0))
      g.globalAlpha = 1
      g.fillStyle = rg
      g.beginPath()
      g.arc(x, y, s * 2.5, 0, Math.PI * 2)
      g.fill()
      break
    }
    case 'bubble':
      g.lineWidth = Math.max(1.5, s * 0.2)
      g.beginPath()
      g.arc(x, y, s * 0.7, 0, Math.PI * 2)
      g.stroke()
      g.fillRect(x - s * 0.3, y - s * 0.35, s * 0.2, s * 0.2)
      break
    case 'droplet':
      g.beginPath()
      g.ellipse(x, y, s * 0.4, s * 0.7, rot, 0, Math.PI * 2)
      g.fill()
      break
    case 'flame': {
      const rg = g.createRadialGradient(x, y, 0, x, y, s)
      rg.addColorStop(0, rgba(color, a))
      rg.addColorStop(1, rgba(color, 0))
      g.globalAlpha = 1
      g.fillStyle = rg
      g.beginPath()
      g.arc(x, y, s, 0, Math.PI * 2)
      g.fill()
      break
    }
    case 'leaf':
    case 'feather':
      g.save()
      g.translate(x, y)
      g.rotate(rot)
      g.beginPath()
      g.ellipse(0, 0, s * 0.35, s * (style === 'feather' ? 0.9 : 0.7), 0, 0, Math.PI * 2)
      g.fill()
      g.globalAlpha = clamp(a) * 0.5
      g.strokeStyle = '#ffffff'
      g.lineWidth = 1
      g.beginPath()
      g.moveTo(0, -s * 0.6)
      g.lineTo(0, s * 0.6)
      g.stroke()
      g.restore()
      break
    case 'shard':
    case 'crystal':
      g.save()
      g.translate(x, y)
      g.rotate(rot)
      g.beginPath()
      g.moveTo(0, -s)
      g.lineTo(s * 0.6, s * 0.2)
      g.lineTo(0, s * 0.8)
      g.lineTo(-s * 0.5, 0)
      g.closePath()
      g.fill()
      g.globalAlpha = clamp(a) * 0.6
      g.fillStyle = '#ffffff'
      g.beginPath()
      g.moveTo(0, -s)
      g.lineTo(s * 0.25, -s * 0.1)
      g.lineTo(-s * 0.15, 0)
      g.closePath()
      g.fill()
      g.restore()
      break
    case 'wisp': {
      const rg = g.createRadialGradient(x, y, 0, x, y, s * 1.6)
      rg.addColorStop(0, rgba(color, a))
      rg.addColorStop(0.5, rgba(color, a * 0.5))
      rg.addColorStop(1, rgba(color, 0))
      g.globalAlpha = 1
      g.fillStyle = rg
      g.beginPath()
      g.arc(x, y, s * 1.6, 0, Math.PI * 2)
      g.fill()
      break
    }
    case 'streak':
      g.save()
      g.translate(x, y)
      g.rotate(rot)
      g.fillRect(-s * 1.8, -s * 0.12, s * 3.6, s * 0.24)
      g.restore()
      break
    case 'star': {
      g.beginPath()
      for (let i = 0; i < 8; i++) {
        const r = i % 2 ? s * 0.28 : s
        const an = rot + (i * Math.PI) / 4
        g[i ? 'lineTo' : 'moveTo'](x + Math.cos(an) * r, y + Math.sin(an) * r)
      }
      g.closePath()
      g.fill()
      break
    }
    case 'arrowUp':
    case 'arrowDown': {
      const d = style === 'arrowUp' ? -1 : 1
      g.beginPath()
      g.moveTo(x, y + d * s)
      g.lineTo(x + s * 0.8, y)
      g.lineTo(x + s * 0.3, y)
      g.lineTo(x + s * 0.3, y - d * s)
      g.lineTo(x - s * 0.3, y - d * s)
      g.lineTo(x - s * 0.3, y)
      g.lineTo(x - s * 0.8, y)
      g.closePath()
      g.fill()
      break
    }
    case 'pokeball': {
      // A Poké Ball girando (vermelha em cima, branca embaixo, a faixa e o botão).
      g.save()
      g.translate(x, y)
      g.rotate(rot)
      g.globalAlpha = 1
      g.fillStyle = '#ef4444'
      g.beginPath()
      g.arc(0, 0, s, Math.PI, 0)
      g.fill()
      g.fillStyle = '#f8fafc'
      g.beginPath()
      g.arc(0, 0, s, 0, Math.PI)
      g.fill()
      g.strokeStyle = '#111827'
      g.lineWidth = Math.max(2, s * 0.16)
      g.beginPath()
      g.arc(0, 0, s, 0, Math.PI * 2)
      g.moveTo(-s, 0)
      g.lineTo(s, 0)
      g.stroke()
      g.fillStyle = '#f8fafc'
      g.beginPath()
      g.arc(0, 0, s * 0.32, 0, Math.PI * 2)
      g.fill()
      g.stroke()
      g.restore()
      break
    }
    case 'heart': {
      g.beginPath()
      g.moveTo(x, y + s * 0.7)
      g.bezierCurveTo(x - s * 1.2, y - s * 0.1, x - s * 0.5, y - s * 0.95, x, y - s * 0.35)
      g.bezierCurveTo(x + s * 0.5, y - s * 0.95, x + s * 1.2, y - s * 0.1, x, y + s * 0.7)
      g.fill()
      break
    }
    case 'note': {
      g.fillRect(x + s * 0.25, y - s, s * 0.14, s * 1.1)
      g.fillRect(x + s * 0.25, y - s, s * 0.55, s * 0.18)
      g.beginPath()
      g.ellipse(x, y + s * 0.1, s * 0.34, s * 0.24, -0.4, 0, Math.PI * 2)
      g.fill()
      break
    }
    case 'zzz':
      g.font = `900 ${Math.round(s)}px sans-serif`
      g.fillText('Z', x, y)
      break
    case 'gear': {
      g.save()
      g.translate(x, y)
      g.rotate(rot)
      g.beginPath()
      for (let i = 0; i < 16; i++) {
        const r = i % 2 ? s * 0.7 : s
        const a0 = (i / 16) * Math.PI * 2
        g.lineTo(Math.cos(a0) * r, Math.sin(a0) * r)
      }
      g.closePath()
      g.fill()
      g.globalCompositeOperation = 'destination-out'
      g.beginPath()
      g.arc(0, 0, s * 0.3, 0, Math.PI * 2)
      g.fill()
      g.restore()
      break
    }
    case 'moon':
      g.beginPath()
      g.arc(x, y, s, 0.6, Math.PI * 2 - 0.6)
      g.arc(x + s * 0.55, y - s * 0.1, s * 0.75, Math.PI * 2 - 0.9, 0.9, true)
      g.closePath()
      g.fill()
      break
    case 'sun': {
      g.beginPath()
      g.arc(x, y, s * 0.55, 0, Math.PI * 2)
      g.fill()
      g.lineWidth = Math.max(2, s * 0.14)
      for (let i = 0; i < 8; i++) {
        const an = rot + (i * Math.PI) / 4
        g.beginPath()
        g.moveTo(x + Math.cos(an) * s * 0.75, y + Math.sin(an) * s * 0.75)
        g.lineTo(x + Math.cos(an) * s * 1.15, y + Math.sin(an) * s * 1.15)
        g.stroke()
      }
      break
    }
    case 'goo':
      g.beginPath()
      g.arc(x, y, s * 0.6, 0, Math.PI * 2)
      g.fill()
      g.globalAlpha = clamp(a) * 0.7
      g.fillStyle = '#ffffff'
      g.fillRect(x - s * 0.3, y - s * 0.35, s * 0.18, s * 0.18)
      break
    case 'rain':
      g.lineWidth = 2
      g.beginPath()
      g.moveTo(x, y)
      g.lineTo(x - s * 0.3, y + s)
      g.stroke()
      break
    case 'fist':
    case 'foot':
    case 'head':
    case 'body':
    case 'wing':
      drawIcon(g, style, x, y, s, color, rot)
      break
    default: {
      // dot: bolinha de luz.
      const rg = g.createRadialGradient(x, y, 0, x, y, s)
      rg.addColorStop(0, rgba('#ffffff', a))
      rg.addColorStop(0.4, rgba(color, a))
      rg.addColorStop(1, rgba(color, 0))
      g.globalAlpha = 1
      g.fillStyle = rg
      g.beginPath()
      g.arc(x, y, s, 0, Math.PI * 2)
      g.fill()
    }
  }
  g.globalAlpha = 1
}

/**
 * Partículas. mode:
 *   burst    saem todas juntas do ponto (impacto)
 *   stream   nascem o tempo todo na área e andam com v/vy/g (brasas, poeira, chuva)
 *   converge vêm de longe (r) até o ponto (energia juntando)
 *   swirl    giram em volta do ponto (redemoinho)
 *   trail    rastro ao longo do caminho x/y
 *   travel   vão de x[0], y[0] até x[1], y[1] (absorver, pó)
 *   jet      jato: saem de x[0] e vão até x[1] abrindo (Flamethrower)
 */
function particles(g, L, k, ms) {
  const span = L.t1 - L.t0
  const age0 = ms - L.t0
  const life = L.life
  for (let i = 0; i < L.n; i++) {
    const r1 = fxRand(L.seed * 7.3 + i)
    const r2 = fxRand(L.seed * 3.1 + i * 1.7)
    const r3 = fxRand(L.seed * 5.9 + i * 2.3)
    const born = L.mode === 'burst' ? r1 * 60 : L.mode === 'orbit' ? 0 : r1 * Math.max(1, span - life)
    const t = (age0 - born) / life
    if (t < 0 || t > 1) continue
    const sec = (age0 - born) / 1000
    let x
    let y
    const ox = Array.isArray(L.x) ? L.x[0] : L.x
    const oy = Array.isArray(L.y) ? L.y[0] : L.y
    if (L.mode === 'burst') {
      const ang = r2 * Math.PI * 2
      const sp = L.v * (0.4 + r3)
      x = ox + Math.cos(ang) * sp * sec + (r1 - 0.5) * L.sx
      y = oy + Math.sin(ang) * sp * sec + (L.vy ?? 0) * sec + 0.5 * (L.g ?? 0) * sec * sec + (r3 - 0.5) * L.sy
    } else if (L.mode === 'converge') {
      const ang = r2 * Math.PI * 2
      const d = L.r * (1 - fxEase(t)) * (0.6 + r3 * 0.6)
      x = ox + Math.cos(ang + t * 1.5) * d
      y = oy + Math.sin(ang + t * 1.5) * d
    } else if (L.mode === 'orbit') {
      const ang = (i / L.n) * Math.PI * 2 + (age0 / 1000) * 4
      x = ox + Math.cos(ang) * L.r
      y = oy + Math.sin(ang) * L.r * 0.4
    } else if (L.mode === 'swirl') {
      const ang = r2 * Math.PI * 2 + t * 6
      const d = L.r * (0.3 + 0.7 * (1 - t)) * (0.6 + r3 * 0.6)
      x = ox + Math.cos(ang) * d
      y = oy + Math.sin(ang) * d * 0.5 - t * 80
    } else if (L.mode === 'trail' || L.mode === 'travel' || L.mode === 'jet') {
      const x1 = Array.isArray(L.x) ? L.x[1] : L.x
      const y1 = Array.isArray(L.y) ? L.y[1] : L.y
      const p = L.mode === 'trail' ? clamp((born + life * 0.3) / span) : L.mode === 'jet' ? t : fxEase(t)
      const open = L.mode === 'jet' ? (L.spread ?? 20) * p : 1
      const wob = L.mode === 'travel' ? Math.sin(t * 6 + i) * 18 : 0
      x = lerp(ox, x1, p) + (r2 - 0.5) * (L.sx + open * 2) + wob
      y = lerp(oy, y1, p) + (r3 - 0.5) * (L.sy + open * 2) - (L.mode === 'trail' ? sec * 40 : 0)
    } else {
      // stream
      x = ox + (r2 - 0.5) * 2 * L.sx + (L.v ?? 0) * (r3 - 0.5) * sec * 2
      y = oy + (r3 - 0.5) * 2 * L.sy + (L.vy ?? 0) * (0.6 + r1 * 0.6) * sec + 0.5 * (L.g ?? 0) * sec * sec
    }
    const size = lerp(L.size[0], L.size[1], t) * (0.7 + r2 * 0.6)
    const ci = Math.min(L.c.length - 1, Math.floor(t * L.c.length + r3 * 0.6))
    const fade = L.mode === 'converge' ? Math.min(1, t * 3) : L.mode === 'orbit' ? Math.min(1, t * 5, (1 - t) * 5) : 1 - t * t
    particle(g, L.style, x, y, size, L.c[ci], fade, r1 * 6 + t * 4 * (r2 - 0.5))
  }
}

/** Relâmpago: linha quebrada (de cima até o alvo, ou vários em volta do ponto quando r > 0), piscando. */
function bolt(g, L, k, ms) {
  const flick = L.flicker ? Math.floor(ms / 50) : 0
  const paths = []
  if (L.from) paths.push([L.from, { x: L.x, y: L.y }])
  else
    for (let i = 0; i < L.n; i++) {
      const ang = fxRand(i * 3 + flick) * Math.PI * 2
      paths.push([{ x: L.x, y: L.y }, { x: L.x + Math.cos(ang) * L.r, y: L.y + Math.sin(ang) * L.r * 0.8 }])
    }
  g.lineCap = 'round'
  g.lineJoin = 'round'
  paths.forEach(([p, q], j) => {
    if (L.flicker && fxRand(j + flick * 7) < 0.25) return
    const steps = L.from ? L.n : 5
    const pts = [p]
    for (let i = 1; i < steps; i++) {
      const u = i / steps
      const nx = -(q.y - p.y)
      const ny = q.x - p.x
      const len = Math.hypot(nx, ny) || 1
      const off = (fxRand(i * 11 + j * 5 + flick * 3) - 0.5) * (L.from ? 70 : 26)
      pts.push({ x: lerp(p.x, q.x, u) + (nx / len) * off, y: lerp(p.y, q.y, u) + (ny / len) * off })
    }
    pts.push(q)
    for (const [w, c, a] of [[L.w * 4, L.c2, 0.35], [L.w * 1.6, L.c2, 0.8], [L.w * 0.7, L.c, 1]]) {
      g.strokeStyle = rgba(c, a * (1 - k * 0.3))
      g.lineWidth = w
      g.beginPath()
      pts.forEach((pt, i) => g[i ? 'lineTo' : 'moveTo'](pt.x, pt.y))
      g.stroke()
    }
  })
}

/** Feixe de energia de um ponto ao outro, com borda brilhante e ondulando. */
function beam(g, L, k, ms) {
  const grow = clamp(((ms - L.t0) / (L.grow ?? 1)))
  const x1 = lerp(L.x0, L.x1, grow)
  const y1 = lerp(L.y0, L.y1, grow)
  const w = at(L.w, Math.min(1, k * 4)) * (1 - Math.max(0, k - 0.8) * 5)
  if (w <= 0) return
  const wob = Math.sin(ms / 30) * (L.wobble ?? 0)
  g.lineCap = 'round'
  for (const [m, c, a] of [[2.2, L.c[2], 0.35], [1.3, L.c[1], 0.8], [0.55, L.c[0], 1]]) {
    g.strokeStyle = rgba(c, a)
    g.lineWidth = Math.max(1, w * m + wob)
    g.beginPath()
    g.moveTo(L.x0, L.y0)
    g.lineTo(x1, y1)
    g.stroke()
  }
}

/** Teia (Electroweb, String Shot): fios do meio para fora e voltas em polígono; fica eletrificada em [charge]. */
function web(g, L, k, ms) {
  const r = at(L.r, Math.min(1, k * 2.5))
  const a = k < 0.75 ? 1 : 1 - (k - 0.75) * 4
  const t = L.t0 + k * (L.t1 - L.t0)
  const charged = L.charge && t >= L.charge[0] && t <= L.charge[1] && Math.floor(ms / 60) % 3 !== 0
  const col = charged ? L.c2 : L.c
  g.strokeStyle = rgba(col, a)
  g.lineWidth = L.w * (charged ? 1.4 : 1)
  const ang = (i) => (i / L.n) * Math.PI * 2 + 0.2
  g.beginPath()
  for (let i = 0; i < L.n; i++) {
    g.moveTo(L.x, L.y)
    g.lineTo(L.x + Math.cos(ang(i)) * r, L.y + Math.sin(ang(i)) * r * 0.8)
  }
  for (let j = 1; j <= L.rings; j++) {
    const rr = (r * j) / L.rings
    for (let i = 0; i <= L.n; i++) {
      const sag = i % 2 ? 0.92 : 1
      const x = L.x + Math.cos(ang(i)) * rr * sag
      const y = L.y + Math.sin(ang(i)) * rr * 0.8 * sag
      if (i) g.lineTo(x, y)
      else g.moveTo(x, y)
    }
  }
  g.stroke()
  if (charged) {
    g.strokeStyle = rgba('#ffffff', a * 0.6)
    g.lineWidth = 1
    g.stroke()
  }
}

/** Corte em arco (Slash, Night Slash): um risco curvo que aparece e some. */
function arc(g, L, k) {
  const a1 = at(L.a1, Math.min(1, k * 2.2))
  const a0 = L.a0 + (a1 - L.a0) * Math.max(0, (k - 0.45) * 1.8)
  const fade = k < 0.6 ? 1 : 1 - (k - 0.6) * 2.5
  g.save()
  g.translate(L.x, L.y)
  if (L.flip) g.scale(-1, 1)
  for (const [w, c, a] of [[L.w * 2.4, L.c2, 0.45], [L.w, L.c, 1]]) {
    g.strokeStyle = rgba(c, a * fade)
    g.lineWidth = w
    g.lineCap = 'round'
    g.beginPath()
    g.arc(0, 0, L.r, a0, a1)
    g.stroke()
  }
  g.restore()
}

/** Dentes fechando (Bite, Crunch). */
function fangs(g, L, k) {
  const c = at(L.close, Math.min(1, k * 2))
  const fade = k < 0.6 ? 1 : 1 - (k - 0.6) * 2.5
  for (const d of [-1, 1]) {
    const y = L.y + d * L.r * (1 - c) * 0.9
    g.fillStyle = rgba(L.c, fade)
    g.strokeStyle = rgba(L.c2, fade)
    g.lineWidth = 3
    g.beginPath()
    for (let i = 0; i < 4; i++) {
      const x = L.x - L.r * 0.75 + i * L.r * 0.5
      g.moveTo(x - L.r * 0.2, y - d * L.r * 0.35)
      g.lineTo(x, y + d * L.r * 0.3)
      g.lineTo(x + L.r * 0.2, y - d * L.r * 0.35)
    }
    g.closePath()
    g.fill()
    g.stroke()
  }
}

/** Ponta de luz (estocada, mergulho): um cone que desce/atravessa. */
function cone(g, L, k) {
  const x = at(L.x, k)
  const y = at(L.y, k)
  const lg = g.createLinearGradient(x, y - 160, x, y)
  lg.addColorStop(0, rgba(L.c, 0))
  lg.addColorStop(1, rgba(L.c, L.a ?? 1))
  g.fillStyle = lg
  g.beginPath()
  g.moveTo(x - L.w / 2, y - 160)
  g.lineTo(x + L.w / 2, y - 160)
  g.lineTo(x, y)
  g.closePath()
  g.fill()
  g.fillStyle = rgba('#ffffff', 0.9)
  g.beginPath()
  g.arc(x, y, L.w * 0.18, 0, Math.PI * 2)
  g.fill()
}

/** Tiro (semente, pedra, meteoro): voa com rastro. */
function shot(g, L, k) {
  const lift = (u) => (L.arc ? Math.sin(u * Math.PI) * L.arc : 0)
  const x = at(L.x, k)
  const y = at(L.y, k) - lift(k)
  const x0 = at(L.x, Math.max(0, k - 0.3))
  const y0 = at(L.y, Math.max(0, k - 0.3)) - lift(Math.max(0, k - 0.3))
  if (L.trail) {
    const lg = g.createLinearGradient(x0, y0, x, y)
    lg.addColorStop(0, rgba(L.c[2], 0))
    lg.addColorStop(1, rgba(L.c[1], 0.8))
    g.strokeStyle = lg
    g.lineWidth = L.r * 1.1
    g.lineCap = 'round'
    g.beginPath()
    g.moveTo(x0, y0)
    g.lineTo(x, y)
    g.stroke()
  }
  if (!['dot', 'ember', 'flame', 'spark', 'bubble', 'droplet', 'goo', 'wisp', 'glint', 'dust', 'streak'].includes(L.style)) particle(g, L.style, x, y, L.r * 1.3, L.style === 'shard' || L.style === 'crystal' ? L.c[2] : L.c[1], 1, k * 8 * (L.spin ?? 1))
  else {
    const rg = g.createRadialGradient(x, y, 0, x, y, L.r)
    rg.addColorStop(0, L.c[0])
    rg.addColorStop(0.5, L.c[1])
    rg.addColorStop(1, rgba(L.c[2], 0.2))
    g.fillStyle = rg
    g.beginPath()
    g.arc(x, y, L.r, 0, Math.PI * 2)
    g.fill()
  }
}

/** Rachaduras no chão (Earthquake), saindo do ponto. */
function crack(g, L, k) {
  const r = at(L.r, Math.min(1, k * 2))
  const a = at(L.a, k)
  for (let i = 0; i < L.n; i++) {
    const ang = Math.PI + (i / (L.n - 1)) * Math.PI + (fxRand(i) - 0.5) * 0.3
    let x = L.x
    let y = L.y
    g.beginPath()
    g.moveTo(x, y)
    const steps = 6
    for (let j = 1; j <= steps; j++) {
      const d = (r * j) / steps
      x = L.x + Math.cos(ang + (fxRand(i * 9 + j) - 0.5) * 0.5) * d * 1.6
      y = L.y + Math.abs(Math.sin(ang)) * 0 + (fxRand(i * 5 + j) - 0.5) * 18 + Math.sin(ang) * d * 0.25
      g.lineTo(x, y)
    }
    g.strokeStyle = rgba(L.c2, a * 0.5)
    g.lineWidth = 9
    g.stroke()
    g.strokeStyle = rgba(L.c, a)
    g.lineWidth = 4
    g.stroke()
  }
}

/** Tela inteira de uma cor (escurecer, clarão). */
function tint(g, L, k) {
  g.fillStyle = rgba(L.color, at(L.a, k))
  g.fillRect(0, 0, VW, VH)
}

/** Explosão em pixels varrendo a tela (como no jogo). */
function fill(g, L, k, ms) {
  const fade = k < 0.6 ? 1 : 1 - (k - 0.6) * 2.5
  const B = 16
  const front = L.from === 'center' ? null : L.from === 'right' ? VW * (1.1 - k * 1.7) : VW * (-0.1 + k * 1.7)
  for (let by = 0; by < VH; by += B)
    for (let bx = 0; bx < VW; bx += B) {
      let d
      if (front === null) d = 260 * k * 3 - Math.hypot(bx - 480, by - 270) + fxRand(by * 7 + bx) * 120
      else d = (L.from === 'right' ? bx - front : front - bx) + fxRand(by * 7 + bx) * 140
      if (d < 0) continue
      const c = fxRand(bx * 3 + by * 11 + Math.floor(ms / 80))
      g.fillStyle = L.c[Math.floor(c * L.c.length)]
      g.globalAlpha = Math.min(1, d / 120) * L.a * fade
      g.fillRect(bx, by, B, B)
    }
  g.globalAlpha = 1
}

/** Parede de água atravessando a tela (Surf). */
function wave(g, L, k, ms) {
  const dir = L.dir
  const x = dir > 0 ? lerp(-500, 1200, k) : lerp(1460, -240, k)
  const h = lerp(L.h[0], L.h[1], Math.sin(k * Math.PI)) * VH
  for (let band = 0; band < 4; band++) {
    const off = band * 60 * -dir
    const lg = g.createLinearGradient(0, VH - h, 0, VH)
    lg.addColorStop(0, rgba(L.c[Math.min(3, band)], 0.85))
    lg.addColorStop(1, rgba(L.c[3], 0.95))
    g.fillStyle = lg
    g.beginPath()
    g.moveTo(x + off - 600 * dir, VH)
    for (let i = 0; i <= 30; i++) {
      const px = x + off - 600 * dir + (i / 30) * 600 * dir
      const crest = Math.pow(i / 30, 2.4)
      const py = VH - h * (0.25 + 0.75 * crest) * (1 - band * 0.12) + Math.sin(i * 0.9 + ms / 90 + band) * 8
      g.lineTo(px, py)
    }
    g.lineTo(x + off, VH)
    g.closePath()
    g.fill()
  }
  // Espuma na crista.
  g.fillStyle = 'rgba(255,255,255,0.85)'
  for (let i = 0; i < 18; i++) {
    const px = x - dir * fxRand(i) * 120
    const py = VH - h + fxRand(i + 5) * 40
    g.fillRect(px, py, 8, 8)
  }
}

/** Uma forma grande com brilho (o punho no soco, o pé no chute, a lua no Moonblast...). */
function icon(g, L, k) {
  const x = at(L.x, k)
  const y = at(L.y, k)
  const s = at(L.size, k)
  const a = at(L.a, k)
  const rg = g.createRadialGradient(x, y, 0, x, y, s * 1.3)
  rg.addColorStop(0, rgba(L.c[0], 0.7 * a))
  rg.addColorStop(1, rgba(L.c[1], 0))
  g.fillStyle = rg
  g.beginPath()
  g.arc(x, y, s * 1.3, 0, Math.PI * 2)
  g.fill()
  particle(g, L.style, x, y, s * 0.6, L.c[1], a, L.rot ?? 0)
}

/** Punho, pé, cabeça (estrela de impacto), corpo e asa, desenhados. */
function drawIcon(g, style, x, y, s, color, rot) {
  g.save()
  g.translate(x, y)
  g.rotate(rot)
  g.fillStyle = color
  g.strokeStyle = 'rgba(0,0,0,0.55)'
  g.lineWidth = Math.max(2, s * 0.08)
  const shape = () => {
    g.fill()
    g.stroke()
  }
  if (style === 'fist') {
    g.beginPath()
    g.roundRect(-s * 0.7, -s * 0.55, s * 1.25, s * 1.05, s * 0.3)
    shape()
    for (let i = 0; i < 3; i++) {
      g.beginPath()
      g.moveTo(-s * 0.35 + i * s * 0.32, -s * 0.55)
      g.lineTo(-s * 0.35 + i * s * 0.32, -s * 0.1)
      g.stroke()
    }
    g.beginPath()
    g.roundRect(-s * 0.95, -s * 0.15, s * 0.45, s * 0.55, s * 0.18)
    shape()
  } else if (style === 'foot') {
    g.beginPath()
    g.ellipse(0, 0, s * 0.45, s * 0.85, 0.3, 0, Math.PI * 2)
    shape()
    for (let i = 0; i < 3; i++) {
      g.beginPath()
      g.arc(-s * 0.35 + i * s * 0.3, -s * 0.85, s * 0.16, 0, Math.PI * 2)
      shape()
    }
  } else if (style === 'wing') {
    for (let i = 0; i < 4; i++) {
      g.beginPath()
      g.ellipse(-s * 0.2 + i * s * 0.18, -s * 0.1 + i * s * 0.12, s * 0.22, s * (0.9 - i * 0.15), -0.7, 0, Math.PI * 2)
      shape()
    }
  } else {
    // head / body: estrela de impacto.
    g.beginPath()
    for (let i = 0; i < 16; i++) {
      const r = i % 2 ? s * 0.45 : s
      const an = (i * Math.PI) / 8
      g.lineTo(Math.cos(an) * r, Math.sin(an) * r)
    }
    g.closePath()
    shape()
  }
  g.restore()
}

const SHAPES = { glow, rays, ring, particles, bolt, beam, web, arc, fangs, cone, shot, crack, icon }
const SCREEN = { tint, fill, wave }
