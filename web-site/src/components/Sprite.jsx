// Sprite de Pokémon com tamanho visual igual para todos.
//
// Os sprites têm bordas transparentes diferentes (o Bulbasaur ocupa bem menos
// da imagem que o Charizard). `box` diz onde o Pokémon está dentro da imagem
// (calculado em tool/build_web_data.py); com isso o Pokémon é ampliado para
// preencher a caixa quadrada em que ele é desenhado.

import { useEffect, useState } from 'react'
import { getAnimatedSprites, spriteUrl } from '../lib/data'
import { usePrefs } from '../lib/prefs'

// Sprites animados (GIF, estilo Black & White) do banco do site
// (sprites/animated, tool/fetch_animated_sprites.py): quando o Pokémon tem um e
// a opção está ligada, ele aparece no lugar do parado.
let animated = null
let loading = null
function useAnimated() {
  const [sets, setSets] = useState(animated)
  useEffect(() => {
    if (animated) return undefined
    let alive = true
    loading ??= getAnimatedSprites()
      .then((d) => (animated = { front: new Set(d.front), shiny: new Set(d.shiny), fit: d.fit ?? {}, hash: d.hash ?? {} }))
      .catch(() => (animated = { front: new Set(), shiny: new Set(), fit: {}, hash: {} }))
    loading.then((a) => alive && setSets(a))
    return () => {
      alive = false
    }
  }, [])
  return sets
}

/**
 * "pokemon/6.png" ou "pokemon/shiny/6.png" → GIF animado (se existir) e o
 * ajuste [zoom, dx, dy] de quem se mexe muito e ficaria pequeno.
 */
function animatedOf(path, sets) {
  const m = /^pokemon\/(shiny\/)?(\d+)\.png$/.exec(path ?? '')
  if (!m || !sets) return null
  const kind = m[1] ? 'shiny' : 'front'
  if (!sets[kind].has(Number(m[2]))) return null
  // ?v=impressão digital: quando o GIF muda no banco, o navegador baixa de novo.
  const v = sets.hash[kind]?.[m[2]]
  return { gif: `animated/${kind}/${m[2]}.gif${v ? `?v=${v}` : ''}`, fit: sets.fit[kind]?.[m[2]] ?? [1, 0, 0] }
}

/**
 * @param fill   quanto da caixa o Pokémon ocupa (0 a 1)
 * @param align  'center' ou 'bottom' (Pokémon "apoiado" embaixo)
 */
export default function Sprite(props) {
  const on = usePrefs((s) => s.animatedSprites)
  const sets = useAnimated()
  const [failed, setFailed] = useState(null)
  const anim = on ? animatedOf(props.path, sets) : null
  const gif = anim?.gif
  if (!gif || failed === gif) return <StaticSprite {...props} />
  const { alt = '', fill = 0.9, align = 'center', className = '', imgClassName = '', style } = props
  // O GIF já vem recortado justo: encaixa na caixa (do tamanho do parado),
  // ampliado para o quadro típico ocupar a caixa (fit).
  // Limita o zoom para a animação inteira caber na caixa (quem pula ou abre
  // as asas não invade o que está em volta; apoiado embaixo, nada passa do topo).
  const [z, dx, dy, wr = 1, hr = 1] = anim.fit
  const maxY = align === 'bottom' ? (1 + fill) / (2 * fill * hr) : 1.1 / (fill * hr)
  const zoom = Math.max(1, Math.min(z, 1.1 / (fill * wr), maxY))
  const side = fill * zoom // lado do GIF, em fração da caixa
  // Centraliza o quadro típico, sem a animação sair da caixa por mais de 5% de cada lado.
  const shift = (d, r) => Math.max(-Math.max(0, (1.1 - side * r) / 2), Math.min(Math.max(0, (1.1 - side * r) / 2), d * side))
  const top = align === 'bottom' ? 1 - (1 - fill) / 2 - side : 0.5 - side / 2 - shift(dy, hr)
  return (
    <div className={`relative aspect-square ${className}`} style={style}>
      <img
        src={spriteUrl(gif)}
        alt={alt}
        loading="lazy"
        decoding="async"
        draggable={false}
        onError={() => setFailed(gif)}
        className={`pixelated pointer-events-none absolute max-w-none object-contain ${align === 'bottom' ? 'object-bottom' : ''} ${imgClassName}`}
        style={{
          width: `${side * 100}%`,
          height: `${side * 100}%`,
          left: `${(0.5 - side / 2 - shift(dx, wr)) * 100}%`,
          top: `${top * 100}%`,
        }}
      />
    </div>
  )
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
