import { useEffect, useMemo, useState } from 'react'
import PokedexGrid from '../components/PokedexGrid'
import { Loader, PageHeader } from '../components/ui'
import { getPokedex } from '../lib/data'
import { useStore } from '../lib/store'

export default function FavoritesPage() {
  const favorites = useStore((s) => s.favorites)
  const [pokedex, setPokedex] = useState(null)
  useEffect(() => {
    getPokedex().then(setPokedex)
  }, [])

  const list = useMemo(() => (pokedex ? pokedex.filter((p) => favorites.includes(p.id)) : []), [pokedex, favorites])

  return (
    <div>
      <PageHeader title="Favoritos" subtitle="Dê um duplo clique em um card da Pokédex (ou use a estrela nos detalhes) para favoritar." />
      {pokedex ? (
        <PokedexGrid pokemon={list} emptyText="Você ainda não favoritou nenhum Pokémon." />
      ) : (
        <Loader />
      )}
    </div>
  )
}
