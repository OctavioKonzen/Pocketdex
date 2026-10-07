// Sprite de Pokémon com tamanho visual igual para todos.
//
// Os sprites têm bordas transparentes diferentes (o Bulbasaur ocupa bem menos
// da imagem que o Charizard). `box` diz onde o Pokémon está dentro da imagem
// (calculado em tool/build_web_data.py); com isso o Pokémon é ampliado para
// preencher a caixa quadrada em que ele é desenhado.

import { useEffect, useRef, useState } from 'react'
import { getAnimatedSprites, spriteUrl } from '../lib/data'
import { usePrefs } from '../lib/prefs'
import { gifFrames } from '../lib/gifFrames'
import { crystalLayer, drawCrystal } from '../lib/teraCrystal'

// Sprites animados (GIF) no estilo Black & White, do banco do site
// (sprites/animated), igual ao app (lib/services/animated_sprites.dart): os
// oficiais do BW, a animação BW do Showdown ou, sem animação, a arte BW parada.
let animated = null
let loading = null
// Frente, shiny e as costas (para a batalha).
const KINDS = ['front', 'shiny', 'back', 'back-shiny']
const describe = (d = {}, folder) => ({
  folder,
  ...Object.fromEntries(KINDS.map((k) => [k, new Set(d[k] ?? [])])),
  still: Object.fromEntries(KINDS.map((k) => [k, new Set(d.still?.[k] ?? [])])),
  fit: d.fit ?? {},
  foot: d.foot ?? {},
  size: d.size ?? {},
  hash: d.hash ?? {},
  // Formas só de aparência (Vivillon, Unown, Alcremie...): { front: { "666-polar": {size, hash, fit, foot, still} } }.
  forms: d.forms ?? {},
})
function useAnimated() {
  const [sets, setSets] = useState(animated)
  useEffect(() => {
    if (animated) return undefined
    let alive = true
    loading ??= getAnimatedSprites()
      .then((d) => (animated = describe(d, 'animated')))
      .catch(() => (animated = describe({}, 'animated')))
    loading.then((a) => alive && setSets(a))
    return () => {
      alive = false
    }
  }, [])
  return sets
}

/**
 * "pokemon/6.png" ou "pokemon/shiny/6.png" → GIF animado (se existir), o
 * ajuste [zoom, dx, dy] de quem se mexe muito e ficaria pequeno e o pé (na
 * batalha, quanto descer para pisar na plataforma).
 */
export function animatedOf(path, set, back) {
  const m = /^pokemon\/(?:other\/official-artwork\/)?(shiny\/)?(\d+)(-[a-z0-9-]+)?\.(?:png|webp)$/.exec(path ?? '')
  if (!m || !set) return null
  const kind = back ? (m[1] ? 'back-shiny' : 'back') : m[1] ? 'shiny' : 'front'
  const front = m[1] ? 'shiny' : 'front'
  if (m[3]) {
    // Forma só de aparência: GIF com o nome do sprite ("666-polar.gif").
    const key = m[2] + m[3]
    const info = set.forms[kind]?.[key]
    if (!info) return null
    const frontInfo = set.forms[front]?.[key]
    if (back && info.still && frontInfo && !frontInfo.still) return null
    return {
      gif: `${set.folder}/${kind}/${key}.gif?v=${info.hash}`,
      fit: info.fit ?? [1, 0, 0],
      foot: info.foot ?? 0,
      size: info.size ?? null,
    }
  }
  const id = Number(m[2])
  if (!set[kind].has(id)) return null
  // De costas: se as costas são só a arte parada e a frente é animada, usa a
  // frente espelhada (que se mexe).
  if (back && set.still[kind].has(id) && set[front].has(id) && !set.still[front].has(id)) return null
  // ?v=impressão digital: quando o GIF muda no banco, o navegador baixa de novo.
  const v = set.hash[kind]?.[m[2]]
  return {
    gif: `${set.folder}/${kind}/${m[2]}.gif${v ? `?v=${v}` : ''}`,
    fit: set.fit[kind]?.[m[2]] ?? [1, 0, 0],
    foot: set.foot[kind]?.[m[2]] ?? 0,
    size: set.size[kind]?.[m[2]] ?? null,
  }
}

/**
 * @param fill   quanto da caixa o Pokémon ocupa (0 a 1)
 * @param align  'center' ou 'bottom' (Pokémon "apoiado" embaixo)
 * @param back   de costas (batalha)
 * @param battle na batalha (o pé do GIF desce para pisar na plataforma)
 * @param whole  a animação inteira cabe na caixa (onde nada recorta, como os mascotes dos seletores)
 * @param prefetch outro sprite para já baixar (o shiny na página do Pokémon:
 *                 trocar para ele não fica parado esperando chegar)
 * @param crown  algo para pôr no topo da cabeça (a coroa do Terastal), que
 *               acompanha a animação quadro a quadro
 * @param crystal cor do Tera Type: o corpo fica cristalizado (facetas e reflexo)
 */
export default function Sprite(props) {
  const on = usePrefs((s) => s.animatedSprites)
  const sets = useAnimated()
  const [failed, setFailed] = useState(null)
  // Se ele se mexe vem das Configurações; parado, fica no primeiro quadro do mesmo GIF.
  const anim = animatedOf(props.path, sets, props.back)
  const next = props.prefetch ? animatedOf(props.prefetch, sets, props.back)?.gif : null
  useEffect(() => {
    if (next) new Image().src = spriteUrl(next)
  }, [next])
  // Largura da caixa na tela: o sprite é ampliado por um número inteiro de
  // pixels da tela (cada pixel do mesmo tamanho, nítido, sem borrar).
  const box = useRef(null)
  const [boxWidth, setBoxWidth] = useState(0)
  const pixelArt = anim && anim.size
  useEffect(() => {
    const el = box.current
    if (!pixelArt || !el || typeof ResizeObserver === 'undefined') return undefined
    const observer = new ResizeObserver(([entry]) => setBoxWidth(entry.contentRect.width))
    observer.observe(el)
    return () => observer.disconnect()
  }, [pixelArt])
  const gif = anim?.gif
  if (!gif || failed === gif) {
    // De costas sem as costas no banco: a frente espelhada.
    if (props.back) {
      return (
        <div className="-scale-x-100">
          <Sprite {...props} back={false} />
        </div>
      )
    }
    return <StaticSprite {...props} />
  }
  const { alt = '', fill = 0.9, align = 'center', className = '', imgClassName = '', style } = props
  // O GIF já vem recortado justo: encaixa na caixa (do tamanho do parado),
  // ampliado para o quadro típico ocupar a caixa (fit).
  // Na batalha (e com whole) limita o zoom para a animação inteira caber na
  // caixa (quem pula ou abre as asas não invade o que está em volta).
  const [z, dx, dy, wr = 1, hr = 1] = anim.fit
  const maxY = align === 'bottom' ? (1 + fill) / (2 * fill * hr) : 1 / (fill * hr)
  // Fora da batalha (e sem whole) o quadro típico ocupa a caixa (o card recorta o que passa).
  const inside = props.battle || props.whole
  const zoom = inside ? Math.max(1, Math.min(z, 1 / (fill * wr), maxY)) : Math.max(1, z)
  const side = fill * zoom // lado do GIF, em fração da caixa
  // Centraliza o quadro típico (na batalha e com whole, sem a animação sair da caixa).
  const shift = (d, r) => (inside ? Math.max(-Math.max(0, (1 - side * r) / 2), Math.min(Math.max(0, (1 - side * r) / 2), d * side)) : d * side)
  // Na batalha, quem pula ou flutua no meio da animação desce o "pé" para pisar na plataforma.
  const foot = props.battle && align === 'bottom' ? anim.foot * side : 0
  const top = align === 'bottom' ? 1 - (1 - fill) / 2 - side + foot : 0.5 - side / 2 - shift(dy, hr)
  // Com a caixa medida: tamanho exato em pixels (escala inteira); senão encaixa.
  const dpr = typeof window === 'undefined' ? 1 : window.devicePixelRatio || 1
  const [gw, gh] = anim.size ?? [0, 0]
  // Escala inteira (pixels nítidos) quando perde pouco tamanho; senão a exata,
  // para os pequenos não encolherem pela metade (1,9× virava 1×) e os grandes
  // caberem na caixa.
  const fitScale = pixelArt && boxWidth ? (side * boxWidth * dpr) / Math.max(gw, gh) : 0
  const whole = Math.floor(fitScale)
  const k = fitScale ? (whole >= 1 && whole >= 0.85 * fitScale ? whole : fitScale) / dpr : 0
  const imgProps = {
    className: `pixelated pointer-events-none max-w-none ${k ? '' : `h-full w-full object-contain ${align === 'bottom' ? 'object-bottom' : ''}`} ${imgClassName}`,
    style: k ? { width: `${gw * k}px`, height: `${gh * k}px` } : undefined,
  }
  return (
    <div ref={box} className={`relative aspect-square ${className}`} style={style}>
      <div
        className={`absolute flex justify-center ${align === 'bottom' ? 'items-end' : 'items-center'}`}
        style={{
          width: `${side * 100}%`,
          height: `${side * 100}%`,
          left: `${(0.5 - side / 2 - shift(dx, wr)) * 100}%`,
          top: `${top * 100}%`,
        }}
      >
        {props.crown && k ? (
          <CrownedGif key={gif} src={spriteUrl(gif)} alt={alt} animate={on} crown={props.crown} crystal={props.crystal} crownSize={boxWidth * 0.26} onError={() => setFailed(gif)} {...imgProps} />
        ) : on ? (
          <img src={spriteUrl(gif)} alt={alt} loading="lazy" decoding="async" draggable={false} onError={() => setFailed(gif)} {...imgProps} />
        ) : (
          <FirstFrame key={gif} src={spriteUrl(gif)} alt={alt} onError={() => setFailed(gif)} {...imgProps} />
        )}
      </div>
    </div>
  )
}

/**
 * O GIF desenhado quadro a quadro num canvas, com `crown` no topo da cabeça
 * de cada quadro (lib/headAnchor.js): a coroa sobe, desce e anda junto. Com
 * `crystal`, o corpo fica cristalizado (lib/teraCrystal.js).
 */
function CrownedGif({ src, alt, animate, crown, crystal, crownSize, onError, className, style }) {
  const canvas = useRef(null)
  const holder = useRef(null)
  useEffect(() => {
    let stop = false
    let timer = 0
    fetch(src)
      .then((res) => {
        if (!res.ok) throw new Error(res.statusText)
        return res.arrayBuffer()
      })
      .then((buffer) => {
        const c = canvas.current
        if (stop || !c) return
        const { width, height, frames } = gifFrames(buffer)
        if (!frames.length) throw new Error('GIF vazio')
        c.width = width
        c.height = height
        const ctx = c.getContext('2d')
        const images = frames.map((f) => new ImageData(f.data, width, height))
        const layer = crystal ? crystalLayer(width, height, crystal) : null
        const moving = animate && frames.length > 1
        const start = performance.now()
        let i = 0
        let shown = -1
        let next = start
        const draw = () => {
          if (stop) return
          const now = performance.now()
          if (moving && shown >= 0 && now >= next) {
            i = (i + 1) % frames.length
            next = now + frames[i].delay
          } else if (shown < 0) next = now + frames[i].delay
          shown = i
          ctx.putImageData(images[i], 0, 0)
          // O reflexo do cristal passa a cada 2,4 s.
          if (layer) drawCrystal(ctx, layer, width, height, ((now - start) % 2400) / 2400)
          const head = frames[i].head
          const el = holder.current
          if (el) {
            el.style.visibility = head ? 'visible' : 'hidden'
            if (head) {
              el.style.left = `${head.x * 100}%`
              el.style.top = `${head.y * 100}%`
            }
          }
          if (layer) timer = setTimeout(draw, Math.min(60, Math.max(0, next - now)) || 60)
          else if (moving) timer = setTimeout(draw, frames[i].delay)
        }
        draw()
      })
      .catch(() => !stop && onError?.())
    return () => {
      stop = true
      clearTimeout(timer)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [src, animate, crystal])
  return (
    <span className="relative inline-block" style={style}>
      <canvas ref={canvas} role="img" aria-label={alt} className={className} style={{ width: '100%', height: '100%', display: 'block' }} />
      <span
        ref={holder}
        className="pointer-events-none absolute"
        style={{ visibility: 'hidden', width: crownSize, transform: 'translate(-50%, -78%)' }}
        data-testid="sprite-crown"
      >
        {crown}
      </span>
    </span>
  )
}

/** Só o primeiro quadro do GIF (sprite parado no estilo escolhido), desenhado num canvas. */
function FirstFrame({ src, alt, onError, className, style }) {
  const canvas = useRef(null)
  useEffect(() => {
    const img = new Image()
    img.onload = () => {
      const c = canvas.current
      if (!c) return
      c.width = img.naturalWidth
      c.height = img.naturalHeight
      c.getContext('2d').drawImage(img, 0, 0)
    }
    img.onerror = onError
    img.src = src
    return () => {
      img.onload = null
      img.onerror = null
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [src])
  return <canvas ref={canvas} role="img" aria-label={alt} className={className} style={style} />
}

function StaticSprite({ path, box, alt = '', fill = 0.9, align = 'center', className = '', imgClassName = '', style }) {
  const src = spriteUrl(path)
  if (!src) return null

  if (!box) {
    return (
      <div className={`relative aspect-square ${className}`} style={style}>
        <img src={src} alt={alt} loading="lazy" decoding="async" className={`pixelated pointer-events-none absolute inset-0 h-full w-full object-contain ${imgClassName}`} />
      </div>
    )
  }

  const [x0, y0, x1, y1, w, h] = box
  const bw = x1 - x0
  const bh = y1 - y0
  const m = Math.max(bw, bh) / fill // lado da caixa, em pixels do sprite
  const left = (-x0 + (m - bw) / 2) / m
  const top = align === 'bottom' ? (-y0 + m - bh - (m * (1 - fill)) / 2) / m : (-y0 + (m - bh) / 2) / m

  return (
    <div className={`relative aspect-square ${className}`} style={style}>
      <img
        src={src}
        alt={alt}
        loading="lazy"
        decoding="async"
        draggable={false}
        className={`pixelated pointer-events-none absolute max-w-none ${imgClassName}`}
        style={{ width: `${(w / m) * 100}%`, height: `${(h / m) * 100}%`, left: `${left * 100}%`, top: `${top * 100}%` }}
      />
    </div>
  )
}
