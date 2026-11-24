// Visto × capturado na Pokédex (igual ao app, lib/services/dex_marks.dart):
//   • capturado: a Coleção (todos os jogos, normal e shiny) e o Pokelike
//     (os comprados, os shinies e os capturados nas corridas);
//   • visto: os adversários das batalhas do Pokelike (e todo capturado).

export function caughtIds(collection, league) {
  const ids = new Set()
  for (const entry of Object.values(collection ?? {})) for (const id of [...(entry?.c ?? []), ...(entry?.s ?? [])]) ids.add(Number(id))
  const f = league?.factory
  for (const id of [...(f?.owned ?? []), ...(f?.shinies ?? []), ...(f?.caught ?? [])]) ids.add(Number(id))
  return ids
}

export function seenIds(collection, league) {
  const ids = caughtIds(collection, league)
  for (const id of league?.factory?.seen ?? []) ids.add(Number(id))
  return ids
}
