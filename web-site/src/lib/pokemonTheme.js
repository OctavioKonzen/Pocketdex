// Tema de Pokémon (Configurações → Tema de Pokémon), igual ao app
// (lib/widgets/pokemon_theme_art.dart e SiteColors.tinted):
//   • as cores do site puxadas para a cor do Pokémon (theme_colors.json,
//     feito por tool/build_theme_colors.py);
//   • o desenho dele no fundo, no lugar da Pokébola: os traços (o contorno e
//     as linhas escuras do sprite BW) e o corpo pintado na cor do tema.

import { getThemeColors, spriteUrl } from './data'
import { dailyPokemonId } from './dailyPokemon'

/** O tema "Pokémon do dia" (themePokemon −1): troca sozinho todo dia. */
export const DAILY_THEME = -1
/** O Pokémon do tema escolhido (o do dia, se for o tema do dia). */
export const themeIdOf = (raw) => (raw === DAILY_THEME ? dailyPokemonId() : raw)

/** "#rrggbb" → [matiz 0–360] */
function hueOf(hex) {
  const [r, g, b] = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255)
  const max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min
  if (!d) return 0
  const h = max === r ? ((g - b) / d) % 6 : max === g ? (b - r) / d + 2 : (r - g) / d + 4
  return (h * 60 + 360) % 360
}
const hsl = (h, s, l) => `hsl(${h.toFixed(0)} ${(s * 100).toFixed(0)}% ${(l * 100).toFixed(0)}%)`

/** As variáveis de cor do site (index.css) na cor do Pokémon, no claro e no escuro. */
export function themeVars(hex, dark) {
  const h = hueOf(hex)
  return dark
    ? { '--bg': hsl(h, 0.3, 0.07), '--surface': hsl(h, 0.28, 0.09), '--card': hsl(h, 0.24, 0.13), '--sidebar': hsl(h, 0.28, 0.09), '--muted': hsl(h, 0.14, 0.68), '--line': hsl(h, 0.2, 0.2) }
    : { '--bg': hsl(h, 0.45, 0.95), '--surface': '#fff', '--card': '#fff', '--sidebar': '#fff', '--muted': hsl(h, 0.12, 0.4), '--line': hsl(h, 0.3, 0.87) }
}

let colors = null
/** A cor do tema do Pokémon (do shiny: "s<id>", o tema liberado ao capturá-lo shiny no Pokelike). */
export async function themeColor(id, shiny = false) {
  colors ??= getThemeColors().catch(() => ({}))
  const all = await colors
  return (shiny && all[`s${id}`]) || all[id] || null
}

/** O tema shiny está liberado: o Pokémon foi capturado shiny no Pokelike. */
export const shinyUnlocked = (league, id) => Boolean(league?.factory?.shinies?.map(Number).includes(Number(id)))

/** Scale2x (EPX): cada célula vira 2×2, arredondando as diagonais. */
function scale2x(src, w, h) {
  const at = (x, y) => src[Math.min(h - 1, Math.max(0, y)) * w + Math.min(w - 1, Math.max(0, x))]
  const out = new Uint8Array(w * h * 4), ow = w * 2
  for (let y = 0; y < h; y++)
    for (let x = 0; x < w; x++) {
      const p = at(x, y), a = at(x, y - 1), b = at(x + 1, y), c = at(x - 1, y), d = at(x, y + 1)
      out[2 * y * ow + 2 * x] = c === a && c !== d && a !== b ? a : p
      out[2 * y * ow + 2 * x + 1] = a === b && a !== c && b !== d ? b : p
      out[(2 * y + 1) * ow + 2 * x] = d === c && d !== b && c !== a ? c : p
      out[(2 * y + 1) * ow + 2 * x + 1] = b === d && b !== a && d !== c ? d : p
    }
  return [out, w * 2, h * 2]
}

const arts = new Map()
/** O desenho do Pokémon (data URL de um PNG), com o corpo em [fill] e os traços em [line]. */
export function themeArt(id, fill, line, shiny = false) {
  const key = `${id} ${fill} ${line} ${shiny}`
  if (!arts.has(key)) arts.set(key, draw(id, fill, line, shiny).catch(() => null))
  return arts.get(key)
}

async function draw(id, fill, line, shiny) {
  const img = new Image()
  img.crossOrigin = 'anonymous'
  img.src = spriteUrl(`pokemon/${shiny ? 'shiny/' : ''}${id}.png`)
  await img.decode()
  const { width: w, height: h } = img
  const ctx = Object.assign(document.createElement('canvas'), { width: w, height: h }).getContext('2d')
  ctx.drawImage(img, 0, 0)
  const px = ctx.getImageData(0, 0, w, h).data
  // Recorta justo no Pokémon.
  let x0 = w, y0 = h, x1 = 0, y1 = 0
  for (let y = 0; y < h; y++)
    for (let x = 0; x < w; x++)
      if (px[(y * w + x) * 4 + 3] >= 128) {
        x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x + 1); y1 = Math.max(y1, y + 1)
      }
  if (x1 <= x0) return null
  // 0 vazio, 1 corpo, 2 traço (as linhas quase pretas do sprite).
  let gw = x1 - x0, gh = y1 - y0
  let grid = new Uint8Array(gw * gh)
  for (let y = y0; y < y1; y++)
    for (let x = x0; x < x1; x++) {
      const i = (y * w + x) * 4
      if (px[i + 3] < 128) continue
      const light = (0.299 * px[i] + 0.587 * px[i + 1] + 0.114 * px[i + 2]) / 255
      grid[(y - y0) * gw + (x - x0)] = light < 0.13 ? 2 : 1
    }
  for (let pass = 0; pass < 2; pass++) [grid, gw, gh] = scale2x(grid, gw, gh)
  const out = Object.assign(document.createElement('canvas'), { width: gw, height: gh })
  const octx = out.getContext('2d')
  const data = octx.createImageData(gw, gh)
  const rgb = (hex) => [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16))
  const [cf, cl] = [rgb(fill), rgb(line)]
  const at = (x, y) => (x < 0 || y < 0 || x >= gw || y >= gh ? 0 : grid[y * gw + x])
  for (let y = 0; y < gh; y++)
    for (let x = 0; x < gw; x++) {
      const v = at(x, y)
      if (!v) continue
      const edge = !at(x - 1, y) || !at(x + 1, y) || !at(x, y - 1) || !at(x, y + 1)
      const [r, g, b] = v === 2 || edge ? cl : cf
      const o = (y * gw + x) * 4
      data.data.set([r, g, b, 255], o)
    }
  octx.putImageData(data, 0, 0)
  return out.toDataURL()
}

/** A cor dos traços: a do tema bem escura. */
export function lineColor(hex) {
  return '#' + [1, 3, 5].map((i) => Math.round(parseInt(hex.slice(i, i + 2), 16) * 0.15).toString(16).padStart(2, '0')).join('')
}

/** O fundo de campeão está liberado: entrou no Hall da Fama de alguma região. */
export const championUnlocked = (league) => Boolean(league?.hall?.length)

/** Dourado do fundo de campeão. */
export const CHAMPION_GOLD = '#f5c518'
