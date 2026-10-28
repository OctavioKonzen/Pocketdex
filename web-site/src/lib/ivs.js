// Calculadora de IVs (a mesma conta no app): a partir do nível, da Nature,
// dos EVs e dos status que aparecem no jogo, descobre os IVs possíveis.

import { NATURES } from './pokemon'

const STAT_NAMES = ['HP', 'Attack', 'Defense', 'Sp. Atk', 'Sp. Def', 'Speed']

/** Multiplicador da Nature para o status i (0 = HP). */
export function natureMultiplier(nature, i) {
  const n = NATURES.find((x) => x.name === nature)
  if (!n || n.neutral || i === 0) return 1
  if (n.increases === STAT_NAMES[i]) return 1.1
  if (n.decreases === STAT_NAMES[i]) return 0.9
  return 1
}

/** Status final (fórmula dos jogos a partir da Gen 3). */
export function statValue(i, base, iv, ev, level, nature) {
  const core = Math.floor(((2 * base + iv + Math.floor(ev / 4)) * level) / 100)
  if (i === 0) return base === 1 ? 1 : core + level + 10 // Shedinja
  return Math.floor((core + 5) * natureMultiplier(nature, i))
}

/** IVs (0–31) que dão exatamente o status mostrado; [] se nenhum. */
export function possibleIvs(i, base, shown, ev, level, nature) {
  const out = []
  for (let iv = 0; iv <= 31; iv++) if (statValue(i, base, iv, ev, level, nature) === shown) out.push(iv)
  return out
}
