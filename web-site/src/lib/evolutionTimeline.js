// A linha do tempo da evolução (igual ao app: lib/utils/evolution_timeline.dart):
// a cadeia em etapas (1ª forma, 2ª, 3ª...) e a condição de cada evolução.

const TRIGGERS = {
  trade: ['🔄', 'Troca'],
  'level up': ['⬆️', 'Subir de nível (condição especial)'],
  'use move': ['🥋', 'Usar um golpe específico'],
  'agile style move': ['🥋', 'Golpe no estilo ágil'],
  'strong style move': ['🥋', 'Golpe no estilo forte'],
  shed: ['🐚', 'Lugar livre no time e uma Poké Ball'],
  spin: ['🌀', 'Girar com um doce'],
  'three critical hits': ['🎯', 'Três acertos críticos numa batalha'],
  'take damage': ['💢', 'Receber dano e passar por um arco'],
  'recoil damage': ['💢', 'Receber dano de recuo'],
  'gimmighoul coins': ['🪙', '999 moedas de Gimmighoul'],
  'meltan candies': ['🍬', '400 doces de Meltan'],
  'three defeated bisharp': ['⚔️', 'Derrotar três Bisharp líderes'],
  'tower of darkness': ['🏯', 'Torre da Escuridão'],
  'in battle level up': ['⬆️', 'Subir de nível numa batalha'],
}

/** A condição de "(Level 16)", "(water stone)", "(trade)"...: {icon, text, item?, level?}. */
export function evoCondition(trigger) {
  const raw = (trigger ?? '').replace(/^\(|\)$/g, '')
  const level = raw.match(/^Level (\d+)$/)
  if (level) return { icon: '⬆️', text: 'Nível {0}', level: Number(level[1]) }
  if (TRIGGERS[raw]) return { icon: TRIGGERS[raw][0], text: TRIGGERS[raw][1] }
  if (!raw || raw === 'Unknown') return { icon: '❔', text: 'Condição especial' }
  // Um item: o nome dele (não traduz) e o ícone da Bolsa.
  return { icon: '🎒', text: raw.replace(/\b\w/g, (c) => c.toUpperCase()), item: raw.replaceAll(' ', '-') }
}

/** As etapas da cadeia: [[{p, from, cond}]], a primeira com a forma inicial. */
export function evoStages(edges) {
  if (!edges.length) return []
  const targets = new Set(edges.map((e) => e.to.id))
  const roots = [...new Map(edges.filter((e) => !targets.has(e.from.id)).map((e) => [e.from.id, e.from])).values()]
  const stages = [roots.map((p) => ({ p, from: null, cond: null }))]
  const seen = new Set(roots.map((p) => p.id))
  for (;;) {
    const prev = new Set(stages.at(-1).map((s) => s.p.id))
    const next = edges.filter((e) => prev.has(e.from.id) && !seen.has(e.to.id)).map((e) => ({ p: e.to, from: e.from, cond: evoCondition(e.trigger) }))
    if (!next.length) break
    next.forEach((s) => seen.add(s.p.id))
    stages.push(next)
  }
  return stages
}
