// Speed no jogo (igual ao app, speed_tiers_screen.dart).

/** Treinos de Speed: [nome, IV, EVs, Nature]. */
export const SPEED_SPREADS = [
  ['Máx. com Nature', 31, 252, 1.1],
  ['Máx. neutra', 31, 252, 1],
  ['Sem EVs', 31, 0, 1],
  ['Mínima', 0, 0, 0.9],
]

/** Speed final, arredondando para baixo a cada passo como no jogo. */
export function speedStat(base, level, iv, ev, nature, { scarf = false, boost = false, tailwind = false } = {}) {
  let v = Math.floor((Math.floor(((2 * base + iv + Math.floor(ev / 4)) * level) / 100) + 5) * nature)
  if (boost) v = Math.floor(v * 1.5)
  if (scarf) v = Math.floor(v * 1.5)
  if (tailwind) v *= 2
  return v
}
