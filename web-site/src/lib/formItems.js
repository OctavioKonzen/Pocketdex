// Itens que formas e mecânicas precisam (igual ao app, lib/services/form_items.dart):
// Mega Pedras (com duas Megas, como Charizard X/Y, quem monta o time escolhe),
// Cristais Z e as formas que só existem segurando um item (Primal, Origin,
// Crowned, máscaras da Ogerpon...). Dados em battle_items.json
// (tool/build_battle_items.mjs, do Pokémon Showdown).

/** "Charizardite X" / "charizardite-x" → "charizarditex" (id do Showdown). */
export const toId = (s) => (s ?? '').toLowerCase().replace(/--held$/, '').replace(/[^a-z0-9]/g, '')

/** id do item → slug do nosso banco ("firiumz" → "firium-z--held"). */
export function itemSlug(id, items) {
  return items?.find((i) => toId(i.name) === id)?.name ?? id
}

/**
 * Megas que esse Pokémon pode ter: [{stone: id da pedra, form: forma Mega}].
 * byId: índice dos Pokémon (para achar as formas da mesma espécie).
 */
export function megaOptions(pokemon, byId, battleItems) {
  if (!pokemon || !byId || !battleItems) return []
  const species = byId.get(pokemon.id)?.species ?? pokemon.id
  const forms = new Set([...byId.values()].filter((p) => p.species === species).map((p) => p.name))
  const seen = new Set()
  const out = []
  for (const [stone, form] of Object.entries(battleItems.mega ?? {})) {
    if (!forms.has(form) || seen.has(stone)) continue
    seen.add(stone)
    // A Mega da forma dele (Tatsugiri Droopy → Mega Tatsugiri Droopy), se existir.
    const own = `${pokemon.name}-mega`
    out.push({ stone, form: forms.has(own) ? own : form })
  }
  return out
}

/** Nome da Mega para mostrar: "charizard-mega-x" → "X"; uma só → "Mega". */
export const megaLabel = (form) => {
  const letter = form.split(/-mega-?/)[1]
  return letter ? `Mega ${letter.toUpperCase()}` : 'Mega'
}

/** Itens que essa forma precisa segurar (ids), ou []. */
export const requiredItems = (pokemonName, battleItems) => battleItems?.forms?.[pokemonName] ?? []

/** Cristal Z de um tipo ("fire" → "firiumz"). */
export const zCrystalOf = (type, battleItems) => Object.entries(battleItems?.z ?? {}).find(([, t]) => t === type)?.[0] ?? null
