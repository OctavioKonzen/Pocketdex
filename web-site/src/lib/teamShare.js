// Compartilhar times. Mesmo formato no app (lib/services/team_share.dart):
//   • código: "PDX1" + base64url do JSON {n: nome, c: cor, p: [ids x6]};
//   • link: <site>/#/times/importar/<código>;
//   • texto do Pokémon Showdown (um Pokémon por bloco).

const PREFIX = 'PDX1'

function toBase64Url(text) {
  const bytes = new TextEncoder().encode(text)
  let binary = ''
  bytes.forEach((b) => (binary += String.fromCharCode(b)))
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

function fromBase64Url(code) {
  const base64 = code.replace(/-/g, '+').replace(/_/g, '/')
  const binary = atob(base64 + '='.repeat((4 - (base64.length % 4)) % 4))
  return new TextDecoder().decode(Uint8Array.from(binary, (c) => c.charCodeAt(0)))
}

/** Time → código curto. */
export function encodeTeam(team) {
  const pokemon = Array.from({ length: 6 }, (_, i) => team.pokemon?.[i] ?? null)
  return PREFIX + toBase64Url(JSON.stringify({ n: team.name, c: team.color ?? null, p: pokemon }))
}

/** Código (ou link com o código) → {name, color, pokemon} ou null. */
export function decodeTeam(text) {
  const match = /PDX1([A-Za-z0-9_-]+)/.exec(text ?? '')
  if (!match) return null
  try {
    const data = JSON.parse(fromBase64Url(match[1]))
    const pokemon = Array.from({ length: 6 }, (_, i) => (Number.isInteger(data.p?.[i]) ? data.p[i] : null))
    const color = typeof data.c === 'string' && /^#[0-9a-fA-F]{6}$/.test(data.c) ? data.c : null
    const name = String(data.n ?? 'Time').slice(0, 40) || 'Time'
    return { name, color, pokemon }
  } catch {
    return null
  }
}

/** Link que abre o site já importando o time. */
export function shareLink(team) {
  return `${window.location.origin}${import.meta.env.BASE_URL}#/times/importar/${encodeTeam(team)}`
}

/** "charizard-mega-x" → "Charizard-Mega-X" (nome no Showdown). */
export const showdownName = (name) =>
  name
    .split('-')
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join('-')

/** Time → texto para colar no Pokémon Showdown. */
export function toShowdown(team, byId) {
  const sets = team.pokemon
    .filter((id) => id != null && byId.get(id))
    .map((id) => `${showdownName(byId.get(id).name)}\n`)
  return `=== ${team.name} ===\n\n${sets.join('\n')}`.trim() + '\n'
}

const simple = (name) => name.toLowerCase().replace(/[^a-z0-9]/g, '')

/**
 * Texto do Showdown → {name, pokemon}. Aceita "Apelido (Espécie) (M) @ Item"
 * e ignora o resto (golpes, EVs...). Pokémon desconhecidos são pulados.
 */
export function fromShowdown(text, index) {
  const byName = new Map()
  for (const p of index) byName.set(simple(p.name), p.id)
  // "Landorus" → "landorus-incarnate", "Deoxys" → "deoxys-normal"...
  for (const p of index) {
    const base = simple(p.name.split('-')[0])
    if (p.default && !byName.has(base)) byName.set(base, p.id)
  }
  const header = /===\s*(?:\[[^\]]*\]\s*)?(.+?)\s*===/.exec(text)
  const blocks = text
    .replace(/===.*?===/g, '')
    .split(/\n\s*\n/)
    .map((b) => b.trim())
    .filter(Boolean)
  const pokemon = []
  for (const block of blocks) {
    let first = block.split('\n')[0].split('@')[0].trim()
    first = first.replace(/\((M|F)\)/g, '').trim()
    const inner = /\(([^()]+)\)\s*$/.exec(first)
    const species = inner ? inner[1] : first
    const key = simple(species)
    const id = byName.get(key) ?? byName.get(simple(species.split('-')[0]))
    if (id != null) pokemon.push(id)
    if (pokemon.length === 6) break
  }
  if (!pokemon.length) return null
  return { name: header?.[1] ?? 'Time importado', color: null, pokemon: [...pokemon, ...Array(6 - pokemon.length).fill(null)] }
}

/** Qualquer coisa colada (código, link ou Showdown) → time ou null. */
export function parseSharedTeam(text, index) {
  return decodeTeam(text) ?? fromShowdown(text ?? '', index)
}
