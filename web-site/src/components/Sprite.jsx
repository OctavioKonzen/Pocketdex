// Sprite de Pokémon com tamanho visual igual para todos.
//
// Os sprites têm bordas transparentes diferentes (o Bulbasaur ocupa bem menos
// da imagem que o Charizard). `box` diz onde o Pokémon está dentro da imagem
// (calculado em tool/build_web_data.py); com isso o Pokémon é ampliado para
// preencher a caixa quadrada em que ele é desenhado.

import { spriteUrl } from '../lib/data'

/**
 * @param fill   quanto da caixa o Pokémon ocupa (0 a 1)
 * @param align  'center' ou 'bottom' (Pokémon "apoiado" embaixo)
 */
export default function Sprite({ path, box, alt = '', fill = 0.9, align = 'center', className = '', imgClassName = '', style }) {
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
