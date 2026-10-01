// Sprite de Pokémon com tamanho visual igual para todos.
//
// Os sprites têm bordas transparentes diferentes (o Bulbasaur ocupa bem menos
// da imagem que o Charizard). `box` diz onde o Pokémon está dentro da imagem
// (calculado em tool/build_web_data.py); com isso o Pokémon é ampliado para
// preencher a caixa quadrada em que ele é desenhado.

import { useEffect, useRef, useState } from 'react'
import { getAnimatedSprites, spriteUrl } from '../lib/data'
import { usePrefs } from '../lib/prefs'

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
function animatedOf(path, set, back) {
  const m = /^pokemon\/(shiny\/)?(\d+)\.png$/.exec(path ?? '')
  if (!m || !set) return null
  const kind = back ? (m[1] ? 'back-shiny' : 'back') : m[1] ? 'shiny' : 'front'
  if (!set[kind].has(Number(m[2]))) return null
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
 * @param prefetch outro sprite para já baixar (o shiny na página do Pokémon:
 *                 trocar para ele não fica parado esperando chegar)
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
  // Limita o zoom para a animação inteira caber na caixa (quem pula ou abre
  // as asas não invade o que está em volta; apoiado embaixo, nada passa do topo).
  const [z, dx, dy, wr = 1, hr = 1] = anim.fit
  const maxY = align === 'bottom' ? (1 + fill) / (2 * fill * hr) : 1 / (fill * hr)
  const zoom = Math.max(1, Math.min(z, 1 / (fill * wr), maxY))
  const side = fill * zoom // lado do GIF, em fração da caixa
  // Centraliza o quadro típico, sem a animação sair da caixa (onde o card
  // recorta, cortaria asas e caudas no meio do movimento).
  const shift = (d, r) => Math.max(-Math.max(0, (1 - side * r) / 2), Math.min(Math.max(0, (1 - side * r) / 2), d * side))
  // Na batalha, quem pula ou flutua no meio da animação desce o "pé" para pisar na plataforma.
  const foot = props.battle && align === 'bottom' ? anim.foot * side : 0
  const top = align === 'bottom' ? 1 - (1 - fill) / 2 - side + foot : 0.5 - side / 2 - shift(dy, hr)
  // Com a caixa medida: tamanho exato em pixels (escala inteira); senão encaixa.
  const dpr = typeof window === 'undefined' ? 1 : window.devicePixelRatio || 1
  const [gw, gh] = anim.size ?? [0, 0]
  const k = pixelArt && boxWidth ? Math.max(1, Math.floor((side * boxWidth * dpr) / Math.max(gw, gh))) / dpr : 0
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
        {on ? (
          <img src={spriteUrl(gif)} alt={alt} loading="lazy" decoding="async" draggable={false} onError={() => setFailed(gif)} {...imgProps} />
        ) : (
          <FirstFrame key={gif} src={spriteUrl(gif)} alt={alt} onError={() => setFailed(gif)} {...imgProps} />
        )}
      </div>
    </div>
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
