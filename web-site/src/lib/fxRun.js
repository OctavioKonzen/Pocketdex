// Toca a animação de um golpe (battleFx.js) dentro da batalha: mede onde cada Pokémon está no campo, move a câmera
// sobre o campo inteiro (fundo, bases e sprites), desenha os efeitos num <canvas> por cima e muda os sprites (cor do
// golpe, recuo, silhueta branca, sumir). Os HPs somem e voltam (data-fx-hud). Igual ao app (battle_fx_player.dart).

import { fxHud, fxSprite } from './battleFx'
import { applyCamera, cameraCssPx, paintFx } from './fxPainter'

/** Onde a imagem aparece de verdade dentro do <img> (object-contain, embaixo ou no meio), em pixels do campo. */
function drawnRect(img, field) {
  const r = img.getBoundingClientRect()
  const f = field.getBoundingClientRect()
  const nw = img.naturalWidth || img.width || r.width
  const nh = img.naturalHeight || img.height || r.height
  const s = Math.min(r.width / nw, r.height / nh)
  const dw = nw * s
  const dh = nh * s
  const bottom = img.classList?.contains('object-bottom')
  return {
    left: r.left - f.left + (r.width - dw) / 2,
    top: r.top - f.top + (bottom ? r.height - dh : (r.height - dh) / 2),
    w: dw,
    h: dh,
    nw,
    nh,
    mirrored: !!img.closest?.('.-scale-x-100'),
  }
}

/**
 * O palco do golpe em coordenadas do mundo (960 de largura): para cada lado (near = o seu, far = o outro) o pé,
 * a altura, a caixa e de onde saem os golpes (boca e frente, pelo fx_anchors.json).
 */
export function measureStage(field, spriteEls, ids, anchors) {
  const W = field.clientWidth || 960
  const H = field.clientHeight || 720
  const k = 960 / W
  const side = (i) => {
    const img = spriteEls[i]?.querySelector('img, canvas')
    if (!img) return null
    const d = drawnRect(img, field)
    if (!d.w) return null
    const left = d.left * k
    const top = d.top * k
    const sc = (d.w * k) / d.nw
    // O seu (de costas) usa as costas; sem elas no banco, a frente espelhada.
    let v = anchors?.[ids[i]]?.[i === 0 && !d.mirrored ? 'b' : 'f']
    if (v && (Math.abs(v[0] - d.nw) > 2 || Math.abs(v[1] - d.nh) > 2)) v = null
    const fx = (x) => (d.mirrored ? d.nw - x : x)
    const box = { left, top, w: d.w * k, h: d.h * k }
    if (!v) {
      const toward = i === 0 ? 1 : -1
      return { x: left + box.w / 2, y: top + box.h, h: box.h, box, mouth: { x: left + box.w / 2 + box.w * 0.3 * toward, y: top + box.h * 0.3 }, front: { x: left + box.w / 2 + box.w * 0.35 * toward, y: top + box.h * 0.5 } }
    }
    const [, , x0, y0, x1, y1, mx, my, fx0, fy] = v
    return {
      x: left + ((fx(x0) + fx(x1)) / 2) * sc,
      y: top + y1 * sc,
      h: (y1 - y0) * sc,
      box,
      mouth: { x: left + fx(mx) * sc, y: top + my * sc },
      front: { x: left + fx(fx0) * sc, y: top + fy * sc },
    }
  }
  const near = side(0)
  const far = side(1)
  if (!near || !far) return null
  return { w: 960, h: H * k, near, far }
}

/** Dá para desenhar (no navegador de verdade; nos testes sem canvas, não). */
export const canPlayFx = () =>
  typeof window !== 'undefined' && typeof window.requestAnimationFrame === 'function' && !/jsdom/i.test(navigator.userAgent ?? '')

/**
 * Toca o golpe. [world] o elemento que a câmera move (fundo e sprites), [canvas] por cima, [spriteEls] [o seu, o outro],
 * [rate] a velocidade da batalha (1 normal, 0.5 rápido). Resolve quando termina.
 */
export function runFx({ field, world, canvas, spriteEls, plan, rate = 1, live = () => true }) {
  return new Promise((resolve) => {
    const W = field.clientWidth
    const H = field.clientHeight
    const dpr = window.devicePixelRatio || 1
    canvas.width = Math.round(W * dpr)
    canvas.height = Math.round(H * dpr)
    const g = canvas.getContext('2d')
    if (!g) return resolve()
    const f = W / plan.world[0]
    const huds = [...field.querySelectorAll('[data-fx-hud]')]
    // Quem ataca é A e o alvo é T: o seu (0) ou o outro (1), pelo lado de quem usou o golpe.
    const who = plan.from === 0 ? ['A', 'T'] : ['T', 'A']
    const imgs = spriteEls.map((el) => el?.querySelector('img, canvas'))
    const boxes = imgs.map((img) => (img ? drawnRect(img, field) : null))
    const off = document.createElement('canvas')
    const og = off.getContext('2d')
    const start = performance.now()
    const reset = () => {
      world.style.transform = ''
      for (const el of huds) el.style.opacity = ''
      for (const el of spriteEls) {
        if (!el) continue
        el.style.translate = ''
        el.style.scale = ''
        el.style.filter = ''
        el.style.opacity = ''
      }
      g.setTransform(1, 0, 0, 1, 0, 0)
      g.clearRect(0, 0, canvas.width, canvas.height)
    }
    const frame = () => {
      const ms = (performance.now() - start) / rate
      if (!live() || ms > plan.dur) {
        reset()
        resolve()
        return
      }
      world.style.transform = cameraCssPx(plan, ms, W, H)
      const hud = fxHud(plan, ms)
      for (const el of huds) el.style.opacity = String(hud)
      const looks = who.map((w) => fxSprite(plan, w, ms))
      looks.forEach((s, i) => {
        const el = spriteEls[i]
        if (!el) return
        el.style.translate = `${s.dx * f}px ${s.dy * f}px`
        el.style.scale = `${s.sx} ${s.sy}`
        el.style.filter = s.white ? 'brightness(0) invert(1)' : ''
        el.style.opacity = s.hidden ? '0' : ''
      })
      g.setTransform(dpr, 0, 0, dpr, 0, 0)
      paintFx(g, plan, ms, W, H)
      // A cor do golpe por cima do sprite (ele fica vermelho no Fusion Flare, amarelo no Thunderbolt...).
      looks.forEach((s, i) => {
        const img = imgs[i]
        const b = boxes[i]
        if (!s.tintA || s.hidden || !img || !b?.w) return
        off.width = Math.ceil(b.w)
        off.height = Math.ceil(b.h)
        og.imageSmoothingEnabled = false
        og.globalCompositeOperation = 'source-over'
        og.save()
        if (b.mirrored) {
          og.translate(b.w, 0)
          og.scale(-1, 1)
        }
        og.drawImage(img, 0, 0, b.w, b.h)
        og.restore()
        og.globalCompositeOperation = 'source-atop'
        og.globalAlpha = s.tintA
        og.fillStyle = s.tint
        og.fillRect(0, 0, b.w, b.h)
        og.globalAlpha = 1
        g.save()
        g.setTransform(dpr, 0, 0, dpr, 0, 0)
        // Mesma câmera do mundo, em pixels do campo.
        applyCamera(g, plan, ms, W, H)
        g.scale(1 / f, 1 / f)
        g.imageSmoothingEnabled = false
        g.translate(b.left + s.dx * f + b.w / 2, b.top + s.dy * f + b.h)
        g.scale(s.sx, s.sy)
        g.drawImage(off, -b.w / 2, -b.h)
        g.restore()
      })
      requestAnimationFrame(frame)
    }
    requestAnimationFrame(frame)
  })
}
