// Selos da Pokédex: completar os Pokémon de uma região (geração) ou de um tipo.
// "Capturado" é o mesmo da Pokédex (lib/dexMarks.js). Só as formas normais
// contam. Igual ao app (lib/services/dex_seals.dart).

export const SEAL_REGIONS = [
  ['kanto', 'Kanto', 151], ['johto', 'Johto', 251], ['hoenn', 'Hoenn', 386], ['sinnoh', 'Sinnoh', 493], ['unova', 'Unova', 649],
  ['kalos', 'Kalos', 721], ['alola', 'Alola', 809], ['galar', 'Galar', 905], ['paldea', 'Paldea', 1025],
]
export const SEAL_TYPES = ['normal', 'fire', 'water', 'grass', 'electric', 'ice', 'fighting', 'poison', 'ground', 'flying', 'psychic', 'bug', 'rock', 'ghost', 'dragon', 'dark', 'steel', 'fairy']
const TYPE_ICONS = {
  normal: '⚪', fire: '🔥', water: '💧', grass: '🌿', electric: '⚡', ice: '❄️', fighting: '🥊', poison: '☠️', ground: '⛰️',
  flying: '🪶', psychic: '🔮', bug: '🐛', rock: '🪨', ghost: '👻', dragon: '🐉', dark: '🌑', steel: '⚙️', fairy: '🧚',
}

/** Os 27 selos (9 regiões e 18 tipos) a partir das linhas de pokemon.json: {id, icon, label, ids}. */
export function buildSeals(rows) {
  // As linhas do banco (is_default) ou o índice do site (default).
  const base = rows.filter((r) => (r.is_default ?? r.default) && r.id <= 1025)
  const out = []
  let from = 1
  for (const [id, label, last] of SEAL_REGIONS) {
    out.push({ id, icon: '🗺️', label, ids: new Set(base.filter((r) => r.id >= from && r.id <= last).map((r) => r.id)) })
    from = last + 1
  }
  for (const t of SEAL_TYPES) out.push({ id: `type-${t}`, icon: TYPE_ICONS[t], label: t[0].toUpperCase() + t.slice(1), ids: new Set(base.filter((r) => (r.types ?? []).includes(t)).map((r) => r.id)) })
  return out
}

export const sealHave = (seal, caught) => [...seal.ids].filter((id) => caught.has(id)).length
export const sealDone = (seal, caught) => seal.ids.size > 0 && sealHave(seal, caught) === seal.ids.size
/** Os selos completos (para o perfil público). */
export const doneSeals = (seals, caught) => seals.filter((s) => sealDone(s, caught)).map((s) => s.id)
