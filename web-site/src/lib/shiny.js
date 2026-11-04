// Chance de shiny por método (a mesma lista no app).

export const SHINY_METHODS = [
  { key: 'full', label: 'Encontro normal (Gen 6+)', odds: 4096 },
  { key: 'old', label: 'Encontro normal (Gen 2–5)', odds: 8192 },
  { key: 'charm', label: 'Com Shiny Charm', odds: 1365 },
  { key: 'masuda', label: 'Método Masuda (ovos)', odds: 683 },
  { key: 'masuda-charm', label: 'Masuda + Shiny Charm', odds: 512 },
  { key: 'outbreak', label: 'Surto em massa + Shiny Charm (SV)', odds: 512 },
  { key: 'sandwich', label: 'Sanduíche Sparkling + surto + Charm (SV)', odds: 410 },
  { key: 'sos', label: 'Chamado SOS (31+) + Shiny Charm', odds: 273 },
]

export const METHOD_BY_KEY = Object.fromEntries(SHINY_METHODS.map((m) => [m.key, m]))

/** Chance (0–1) de já ter aparecido um shiny depois de `count` encontros. */
export const chanceSoFar = (count, odds) => 1 - Math.pow(1 - 1 / odds, count)
