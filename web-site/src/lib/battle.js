// Contas de batalha (iguais no app: lib/services/battle.dart).
// Fórmula de dano das gerações 5+ (com Tera da geração 9), arredondando para
// baixo a cada passo. É uma aproximação muito boa do jogo; não inclui
// habilidades nem os casos especiais de golpes.

export const LEVEL = 50

// Nature → [status que aumenta, status que diminui] (1 Atk, 2 Def, 3 SpA, 4 SpD, 5 Spe).
export const NATURES = {
  Hardy: [0, 0], Lonely: [1, 2], Brave: [1, 5], Adamant: [1, 3], Naughty: [1, 4],
  Bold: [2, 1], Docile: [0, 0], Relaxed: [2, 5], Impish: [2, 3], Lax: [2, 4],
  Timid: [5, 1], Hasty: [5, 2], Serious: [0, 0], Jolly: [5, 3], Naive: [5, 4],
  Modest: [3, 1], Mild: [3, 2], Quiet: [3, 5], Bashful: [0, 0], Rash: [3, 4],
  Calm: [4, 1], Gentle: [4, 2], Sassy: [4, 5], Careful: [4, 3], Quirky: [0, 0],
}

export const ITEMS = {
  none: 'Nenhum',
  lifeOrb: 'Life Orb (×1.3)',
  choice: 'Choice Band / Specs (×1.5 no ataque)',
  expertBelt: 'Expert Belt (×1.2 se super efetivo)',
  typeBoost: 'Item do tipo do golpe (×1.2)',
}

export const DEFENDER_ITEMS = {
  none: 'Nenhum',
  assaultVest: 'Assault Vest (×1.5 Sp. Def)',
  eviolite: 'Eviolite (×1.5 Def e Sp. Def)',
}

export const WEATHERS = { none: 'Nenhum', sun: 'Sol', rain: 'Chuva', sand: 'Tempestade de areia', snow: 'Neve' }

const natureMult = (nature, index) => {
  const [up, down] = NATURES[nature] ?? [0, 0]
  if (up === down) return 1
  return index === up ? 1.1 : index === down ? 0.9 : 1
}

/** Status final (HP é o index 0 e tem outra fórmula). */
export function statAt(base, index, ev = 0, level = LEVEL, { iv = 31, nature = 'Hardy' } = {}) {
  const core = Math.floor(((2 * base + iv + Math.floor(ev / 4)) * level) / 100)
  if (index === 0) return base === 1 ? 1 : core + level + 10 // Shedinja
  return Math.floor((core + 5) * natureMult(nature, index))
}

/** Multiplicador de estágio (-6 a +6). */
export const stageMult = (stage) => (stage >= 0 ? (2 + stage) / 2 : 2 / (2 - stage))

/** Multiplicador de um tipo de golpe contra os tipos do defensor. */
export function effectiveness(moveType, defenderTypes, typeData) {
  let mult = 1
  for (const type of defenderTypes) {
    const rel = typeData[type]
    if (!rel) continue
    if (rel.double_damage_from.includes(moveType)) mult *= 2
    if (rel.half_damage_from.includes(moveType)) mult *= 0.5
    if (rel.no_damage_from.includes(moveType)) mult *= 0
  }
  return mult
}

/** Chance (0 a 1) de derrotar com `hits` golpes, somando as 16 variações de dano. */
export function koChance(rolls, hp, hits) {
  // Distribuição da soma dos danos (limitada ao HP, que já basta).
  let dist = new Map([[0, 1]])
  for (let h = 0; h < hits; h++) {
    const next = new Map()
    for (const [sum, p] of dist) {
      for (const r of rolls) {
        const s = Math.min(hp, sum + r)
        next.set(s, (next.get(s) ?? 0) + p / rolls.length)
      }
    }
    dist = next
  }
  return dist.get(hp) ?? 0
}

/**
 * Dano de um golpe.
 * attacker/defender: {types, stats: [hp, atk, def, spa, spd, spe] (base), level,
 *   nature, evs: {hp, atk, def, spa, spd}, ivs (mesmo formato; padrão 31),
 *   stage (estágio do status usado), item, tera (tipo ou null), burned}
 * move: {type, category, power}
 * field: {weather, crit, screen, spread}
 */
export function damage({ attacker, defender, move, typeData, field = {} }) {
  const physical = move.category === 'physical'
  const aIdx = physical ? 1 : 3
  const dIdx = physical ? 2 : 4
  const aKey = physical ? 'atk' : 'spa'
  const dKey = physical ? 'def' : 'spd'
  const aLevel = attacker.level ?? LEVEL
  const dLevel = defender.level ?? LEVEL
  const iv = (who, key) => who.ivs?.[key] ?? 31

  // Status com Nature, estágios e itens.
  let a = statAt(attacker.stats[aIdx], aIdx, attacker.evs?.[aKey] ?? 0, aLevel, { iv: iv(attacker, aKey), nature: attacker.nature })
  let d = statAt(defender.stats[dIdx], dIdx, defender.evs?.[dKey] ?? 0, dLevel, { iv: iv(defender, dKey), nature: defender.nature })
  const hp = statAt(defender.stats[0], 0, defender.evs?.hp ?? 0, dLevel, { iv: iv(defender, 'hp') })
  // No crítico, estágios ruins do atacante e bons do defensor são ignorados.
  const aStage = field.crit ? Math.max(0, attacker.stage ?? 0) : attacker.stage ?? 0
  const dStage = field.crit ? Math.min(0, defender.stage ?? 0) : defender.stage ?? 0
  a = Math.floor(a * stageMult(aStage))
  d = Math.floor(d * stageMult(dStage))
  if (attacker.item === 'choice') a = Math.floor(a * 1.5)
  if (!physical && (defender.item === 'assaultVest' || defender.item === 'eviolite')) d = Math.floor(d * 1.5)
  if (physical && defender.item === 'eviolite') d = Math.floor(d * 1.5)

  const defTypes = defender.tera ? [defender.tera] : defender.types
  if (field.weather === 'sand' && !physical && defTypes.includes('rock')) d = Math.floor(d * 1.5)
  if (field.weather === 'snow' && physical && defTypes.includes('ice')) d = Math.floor(d * 1.5)

  const mult = effectiveness(move.type, defTypes, typeData)
  // STAB: tipo original 1.5; com Tera do mesmo tipo do golpe, 2 se também era original.
  const original = attacker.types.includes(move.type)
  const teraMatch = attacker.tera === move.type
  const stab = teraMatch ? (original ? 2 : 1.5) : original ? 1.5 : 1

  let base = Math.floor(Math.floor((Math.floor((2 * aLevel) / 5 + 2) * move.power * a) / d) / 50) + 2
  if (field.spread) base = Math.floor(base * 0.75)
  if (field.weather === 'sun') base = Math.floor(base * (move.type === 'fire' ? 1.5 : move.type === 'water' ? 0.5 : 1))
  if (field.weather === 'rain') base = Math.floor(base * (move.type === 'water' ? 1.5 : move.type === 'fire' ? 0.5 : 1))
  if (field.crit) base = Math.floor(base * 1.5)

  const rolls = []
  for (let r = 85; r <= 100; r++) {
    let x = Math.floor((base * r) / 100)
    x = Math.floor(x * stab)
    x = Math.floor(x * mult)
    if (physical && attacker.burned) x = Math.floor(x * 0.5)
    if (field.screen && !field.crit) x = Math.floor(x * 0.5)
    if (attacker.item === 'lifeOrb') x = Math.floor(x * 1.3)
    if (attacker.item === 'expertBelt' && mult > 1) x = Math.floor(x * 1.2)
    if (attacker.item === 'typeBoost') x = Math.floor(x * 1.2)
    if (mult > 0 && x < 1) x = 1
    rolls.push(x)
  }
  const min = rolls[0]
  const max = rolls[rolls.length - 1]
  const pct = (n) => Math.round((n / hp) * 1000) / 10
  // Menor número de golpes com chance de derrotar, e a chance.
  let hits = null
  let chance = 0
  if (max > 0) {
    for (let n = 1; n <= 10; n++) {
      const c = koChance(rolls, hp, n)
      if (c > 0) {
        hits = n
        chance = c
        break
      }
    }
  }
  return { min, max, hp, minPct: pct(min), maxPct: pct(max), mult, stab: stab > 1, stabMult: stab, rolls, hits, chance, attack: a, defense: d }
}

/** "Derrota com 1 golpe garantido" / "62,5% de chance de derrotar com 2 golpes". */
export function koText(result) {
  if (!result.hits) return 'Não causa dano.'
  const n = result.hits === 1 ? '1 golpe' : `${result.hits} golpes`
  if (result.chance >= 0.9999) return `Derrota com ${n}, garantido.`
  return `${(result.chance * 100).toFixed(1).replace('.', ',')}% de chance de derrotar com ${n}.`
}
