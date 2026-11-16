// Toca a animação de um golpe (battleFx.js) dentro da batalha: mede onde cada Pokémon está no campo, move a câmera
// sobre o campo inteiro (fundo, bases e sprites), desenha os efeitos num <canvas> por cima e muda os sprites (cor do
// golpe, recuo, silhueta branca, sumir). Os HPs somem e voltam (data-fx-hud). Igual ao app (battle_fx_player.dart).

import { fxHud, fxSprite } from './battleFx'
import { cameraCssPx, paintFx } from './fxPainter'

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
export function runFx({ field, world, canvas, spriteEls, plan, rate = 1, live = () => true, endHidden = null }) {
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
    // A cor do golpe fica numa camada DENTRO de cada sprite, em cima da imagem: anda, recua e amassa junto com ele
    // (antes era uma cópia desenhada à parte, que não acompanhava e parecia um segundo Pokémon).
    const overlays = spriteEls.map((el, i) => {
      const img = imgs[i]
      if (!el || !img) return null
      const er = el.getBoundingClientRect()
      const b = boxes[i]
      const fr = field.getBoundingClientRect()
      const c = document.createElement('canvas')
      c.setAttribute('aria-hidden', 'true')
      c.dataset.fxTint = '1'
      // O retângulo desenhado da imagem, relativo ao sprite (sem a câmera: medido antes dela mexer).
      const left = b.left - (er.left - fr.left)
      const top = b.top - (er.top - fr.top)
      Object.assign(c.style, { position: 'absolute', left: `${left}px`, top: `${top}px`, width: `${b.w}px`, height: `${b.h}px`, pointerEvents: 'none', imageRendering: 'pixelated', display: 'none' })
      c.width = Math.max(1, Math.ceil(b.w * dpr))
      c.height = Math.max(1, Math.ceil(b.h * dpr))
      if (getComputedStyle(el).position === 'static') el.style.position = 'relative'
      el.appendChild(c)
      return c
    })
    const start = performance.now()
    const reset = () => {
      world.style.transform = ''
      for (const el of huds) el.style.filter = ''
      spriteEls.forEach((el, i) => {
        if (!el) return
        el.style.translate = ''
        el.style.scale = ''
        el.style.filter = ''
        // Voltou para a Poké Ball ou desmaiou: continua fora até a próxima cena dele.
        el.style.opacity = i === endHidden ? '0' : ''
      })
      g.setTransform(1, 0, 0, 1, 0, 0)
      g.clearRect(0, 0, canvas.width, canvas.height)
      for (const c of overlays) c?.remove()
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
      // filter (e não opacity): multiplica com a da própria caixa (a sua ainda escondida antes do seu Pokémon sair).
      for (const el of huds) el.style.filter = hud < 1 ? `opacity(${hud})` : ''
      const looks = who.map((w) => fxSprite(plan, w, ms))
      looks.forEach((s, i) => {
        const el = spriteEls[i]
        if (!el) return
        el.style.translate = `${s.dx * f}px ${s.dy * f}px`
        el.style.scale = `${s.sx} ${s.sy}`
        el.style.filter = s.white ? 'brightness(0) invert(1)' : ''
        el.style.opacity = s.hidden ? '0' : s.alpha < 1 ? String(s.alpha) : ''
      })
      g.setTransform(dpr, 0, 0, dpr, 0, 0)
      paintFx(g, plan, ms, W, H)
      // A cor do golpe por cima do sprite (ele fica vermelho no Fusion Flare, amarelo no Thunderbolt...), na camada dele.
      looks.forEach((s, i) => {
        const c = overlays[i]
        const img = imgs[i]
        const b = boxes[i]
        if (!c) return
        if (!s.tintA || s.hidden || !img || !b?.w) {
          c.style.display = 'none'
          return
        }
        const cg = c.getContext('2d')
        cg.setTransform(1, 0, 0, 1, 0, 0)
        cg.globalCompositeOperation = 'source-over'
        cg.clearRect(0, 0, c.width, c.height)
        cg.imageSmoothingEnabled = false
        cg.save()
        if (b.mirrored) {
          cg.translate(c.width, 0)
          cg.scale(-1, 1)
        }
        cg.drawImage(img, 0, 0, c.width, c.height)
        cg.restore()
        cg.globalCompositeOperation = 'source-atop'
        cg.globalAlpha = s.tintA
        cg.fillStyle = s.tint
        cg.fillRect(0, 0, c.width, c.height)
        cg.globalAlpha = 1
        c.style.display = 'block'
      })
      requestAnimationFrame(frame)
    }
    requestAnimationFrame(frame)
  })
}
