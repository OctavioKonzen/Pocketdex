// Comparar direto da Pokédex: o botão ⇄ do card marca até dois Pokémon e a
// barra de baixo (PokedexPage → CompareTray) abre a comparação com os dois.

import { create } from 'zustand'

export const useCompareTray = create((set) => ({
  ids: [],
  // Marca ou desmarca; com dois marcados, o terceiro entra no lugar do mais antigo.
  toggle: (id) => set(({ ids }) => ({ ids: ids.includes(id) ? ids.filter((x) => x !== id) : [...ids.slice(-1), id] })),
  clear: () => set({ ids: [] }),
}))
