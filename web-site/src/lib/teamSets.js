// Dados completos de cada Pokémon do time (mesmo formato no app,
// lib/services/team_sets.dart). O time guarda `sets`: 6 posições, uma para
// cada Pokémon de `pokemon`, com:
//   {nickname, level, gender ('M'|'F'|''), shiny, ability (slug), item (slug),
//    nature ('Jolly'...), tera (tipo), gimmick (mecânica na batalha: '' | mega | z | dmax | tera),
//    moves: [slug x4], evs: {hp..spe}, ivs: {hp..spe}}

export const STAT_KEYS = ['hp', 'atk', 'def', 'spa', 'spd', 'spe']
export const STAT_LABELS = { hp: 'HP', atk: 'Atk', def: 'Def', spa: 'SpA', spd: 'SpD', spe: 'Spe' }
export const STAT_NAMES = { hp: 'HP', atk: 'Attack', def: 'Defense', spa: 'Sp. Atk', spd: 'Sp. Def', spe: 'Speed' }

/** Nature → [status que sobe, status que desce] (índices de STAT_KEYS). */
export const NATURES = {
  Hardy: [0, 0], Lonely: [1, 2], Brave: [1, 5], Adamant: [1, 3], Naughty: [1, 4],
  Bold: [2, 1], Docile: [0, 0], Relaxed: [2, 5], Impish: [2, 3], Lax: [2, 4],
  Timid: [5, 1], Hasty: [5, 2], Serious: [0, 0], Jolly: [5, 3], Naive: [5, 4],
  Modest: [3, 1], Mild: [3, 2], Quiet: [3, 5], Bashful: [0, 0], Rash: [3, 4],
  Calm: [4, 1], Gentle: [4, 2], Sassy: [4, 5], Careful: [4, 3], Quirky: [0, 0],
}
export const natureLabel = (name) => {
  const [up, down] = NATURES[name] ?? [0, 0]
  return up === down ? `${name} (neutra)` : `${name} (+${STAT_LABELS[STAT_KEYS[up]]} −${STAT_LABELS[STAT_KEYS[down]]})`
}

/** Mecânica que o Pokémon usa na batalha (ativa sozinha no primeiro ataque, uma por time). */
export const GIMMICKS = ['mega', 'z', 'dmax', 'tera']

export const TERA_TYPES = ['normal', 'fire', 'water', 'electric', 'grass', 'ice', 'fighting', 'poison', 'ground', 'flying', 'psychic', 'bug', 'rock', 'ghost', 'dragon', 'dark', 'steel', 'fairy', 'stellar']

/** Itens mais usados em batalha (aparecem primeiro). */
export const POPULAR_ITEMS = [
  'choice-band', 'choice-specs', 'choice-scarf', 'life-orb', 'leftovers', 'focus-sash', 'assault-vest', 'heavy-duty-boots',
  'expert-belt', 'eviolite', 'booster-energy', 'rocky-helmet', 'sitrus-berry', 'lum-berry', 'black-sludge', 'loaded-dice',
  'clear-amulet', 'covert-cloak', 'air-balloon', 'weakness-policy', 'light-clay', 'punching-glove', 'mirror-herb', 'throat-spray',
]

const stats = (value) => Object.fromEntries(STAT_KEYS.map((k) => [k, value]))
const clamp = (n, min, max, fallback) => (Number.isFinite(Number(n)) ? Math.min(max, Math.max(min, Math.round(Number(n)))) : fallback)

/** Set novo para um Pokémon (habilidade: a primeira da forma). */
export function newSet(ability = '') {
  return { nickname: '', level: 50, gender: '', shiny: false, ability, item: '', nature: 'Hardy', tera: '', gimmick: '', moves: ['', '', '', ''], evs: stats(0), ivs: stats(31) }
}

/** Corrige um set vindo de fora (conta, código, outra versão): sempre completo e válido. */
export function normalizeSet(s) {
  if (!s || typeof s !== 'object') return null
  const str = (v, max = 40) => (typeof v === 'string' ? v.slice(0, max) : '')
  const moves = Array.from({ length: 4 }, (_, i) => str(s.moves?.[i]))
  return {
    nickname: str(s.nickname, 18),
    level: clamp(s.level, 1, 100, 50),
    gender: s.gender === 'M' || s.gender === 'F' ? s.gender : '',
    shiny: s.shiny === true,
    ability: str(s.ability),
    item: str(s.item),
    nature: NATURES[s.nature] ? s.nature : 'Hardy',
    tera: TERA_TYPES.includes(s.tera) ? s.tera : '',
    gimmick: GIMMICKS.includes(s.gimmick) ? s.gimmick : '',
    moves,
    evs: Object.fromEntries(STAT_KEYS.map((k) => [k, clamp(s.evs?.[k], 0, 252, 0)])),
    ivs: Object.fromEntries(STAT_KEYS.map((k) => [k, clamp(s.ivs?.[k], 0, 31, 31)])),
  }
}

/** Os 6 sets de um time (null onde não tem Pokémon). */
export const teamSets = (team) => Array.from({ length: 6 }, (_, i) => (team.pokemon?.[i] != null ? normalizeSet(team.sets?.[i]) : null))

/** Status final (fórmula dos jogos). base: [hp, atk, def, spa, spd, spe]. */
export function statValue(base, index, set) {
  const key = STAT_KEYS[index]
  const core = Math.floor(((2 * base[index] + set.ivs[key] + Math.floor(set.evs[key] / 4)) * set.level) / 100)
  if (index === 0) return base[0] === 1 ? 1 : core + set.level + 10 // Shedinja
  const [up, down] = NATURES[set.nature] ?? [0, 0]
  const mult = up === down ? 1 : index === up ? 1.1 : index === down ? 0.9 : 1
  return Math.floor((core + 5) * mult)
}

export const evTotal = (set) => STAT_KEYS.reduce((sum, k) => sum + (set.evs[k] ?? 0), 0)

/** "choice-band" → "Choice Band"; "u-turn" → "U-turn". */
export function prettySlug(slug) {
  if (!slug) return ''
  const special = { 'u-turn': 'U-turn', 'x-scissor': 'X-Scissor', 'v-create': 'V-create', 'kings-rock': "King's Rock", 'double-edge': 'Double-Edge', 'will-o-wisp': 'Will-O-Wisp', 'freeze-dry': 'Freeze-Dry', 'self-destruct': 'Self-Destruct', 'soft-boiled': 'Soft-Boiled', 'lock-on': 'Lock-On', 'wake-up-slap': 'Wake-Up Slap', 'baby-doll-eyes': 'Baby-Doll Eyes', 'power-up-punch': 'Power-Up Punch', 'mud-slap': 'Mud-Slap', 'trick-or-treat': 'Trick-or-Treat' }
  if (special[slug]) return special[slug]
  return slug
    .split('-')
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
    .join(' ')
}

const simple = (name) => String(name ?? '').toLowerCase().replace(/[^a-z0-9]/g, '')

// ------------------------------------------------------------------ texto dos simuladores

/** Um Pokémon no formato de texto de times (Showdown, PKHeX e outros). */
export function setToText(speciesName, set) {
  if (!set) return `${speciesName}\n`
  const lines = []
  let first = set.nickname ? `${set.nickname} (${speciesName})` : speciesName
  if (set.gender) first += ` (${set.gender})`
  if (set.item) first += ` @ ${prettySlug(set.item)}`
  lines.push(first)
  if (set.ability) lines.push(`Ability: ${prettySlug(set.ability)}`)
  if (set.level !== 100) lines.push(`Level: ${set.level}`)
  if (set.shiny) lines.push('Shiny: Yes')
  if (set.tera) lines.push(`Tera Type: ${prettySlug(set.tera)}`)
  const evs = STAT_KEYS.filter((k) => set.evs[k]).map((k) => `${set.evs[k]} ${STAT_LABELS[k]}`)
  if (evs.length) lines.push(`EVs: ${evs.join(' / ')}`)
  lines.push(`${set.nature} Nature`)
  const ivs = STAT_KEYS.filter((k) => set.ivs[k] !== 31).map((k) => `${set.ivs[k]} ${STAT_LABELS[k]}`)
  if (ivs.length) lines.push(`IVs: ${ivs.join(' / ')}`)
  for (const mv of set.moves) if (mv) lines.push(`- ${prettySlug(mv)}`)
  return `${lines.join('\n')}\n`
}

const STAT_FROM_TEXT = { hp: 'hp', atk: 'atk', def: 'def', spa: 'spa', spd: 'spd', spe: 'spe' }

/**
 * Bloco de texto de um Pokémon → {species, set}. `lookups` (opcional): Maps
 * nome simplificado → slug para moves, abilities e items.
 */
export function textToSet(block, lookups = {}) {
  const rows = block.split('\n').map((l) => l.trim()).filter(Boolean)
  if (!rows.length) return null
  const set = { ...newSet(), level: 100 } // sem "Level:" no texto = nível 100
  let first = rows[0]
  const at = first.indexOf('@')
  if (at >= 0) {
    set.item = slugFor(first.slice(at + 1).trim(), lookups.items)
    first = first.slice(0, at).trim()
  }
  const gender = /\((M|F)\)\s*$/.exec(first)
  if (gender) {
    set.gender = gender[1]
    first = first.slice(0, gender.index).trim()
  }
  let species = first
  const inner = /^(.*?)\s*\(([^()]+)\)\s*$/.exec(first)
  if (inner) {
    set.nickname = inner[1].slice(0, 18)
    species = inner[2]
  }
  for (const row of rows.slice(1)) {
    let m
    if ((m = /^Ability:\s*(.+)$/i.exec(row))) set.ability = slugFor(m[1], lookups.abilities)
    else if ((m = /^Level:\s*(\d+)/i.exec(row))) set.level = clamp(m[1], 1, 100, 50)
    else if (/^Shiny:\s*Yes/i.test(row)) set.shiny = true
    else if ((m = /^Tera Type:\s*(.+)$/i.exec(row))) set.tera = TERA_TYPES.find((t) => simple(t) === simple(m[1])) ?? ''
    else if ((m = /^(EVs|IVs):\s*(.+)$/i.exec(row))) {
      const target = m[1].toUpperCase() === 'EVS' ? set.evs : set.ivs
      for (const part of m[2].split('/')) {
        const pm = /(\d+)\s*([A-Za-z]+)/.exec(part.trim())
        const key = pm && STAT_FROM_TEXT[pm[2].toLowerCase()]
        if (key) target[key] = Number(pm[1])
      }
    } else if ((m = /^(\w+)\s+Nature$/i.exec(row))) {
      const nature = Object.keys(NATURES).find((n) => n.toLowerCase() === m[1].toLowerCase())
      if (nature) set.nature = nature
    } else if ((m = /^[-~]\s*(.+)$/.exec(row))) {
      const i = set.moves.findIndex((x) => !x)
      if (i >= 0) set.moves[i] = slugFor(m[1].replace(/\s*\[.*\]$/, ''), lookups.moves)
    }
  }
  return { species, set: normalizeSet(set) }
}

function slugFor(name, lookup) {
  const clean = String(name).trim()
  const key = simple(clean)
  if (lookup?.get(key)) return lookup.get(key)
  return clean.toLowerCase().replace(/'/g, '').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '')
}

/** Mapas para textToSet a partir de listas de slugs. */
export const lookupOf = (slugs) => new Map([...slugs].map((s) => [simple(s), s]))
