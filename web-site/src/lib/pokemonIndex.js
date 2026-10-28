// Índice dos Pokémon (id → {name, species, sprite, box...}) como hook.

import { useEffect, useState } from 'react'
import { getPokemonById } from './data'

let cached = null

export function usePokemonIndex() {
  const [byId, setById] = useState(cached)
  useEffect(() => {
    if (cached) return
    getPokemonById().then((m) => {
      cached = m
      setById(m)
    })
  }, [])
  return byId
}
