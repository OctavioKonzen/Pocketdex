import { useEffect, useMemo, useState } from 'react'
import Collection from '../components/Collection'
import PokedexGrid from '../components/PokedexGrid'
import { Loader, PageHeader } from '../components/ui'
import { getPokedex } from '../lib/data'
import { useStore } from '../lib/store'

const TABS = [
  { key: 'favoritos', label: '⭐ Favoritos' },
  { key: 'colecao', label: '📦 Coleção por jogo' },
]

export default function FavoritesPage() {
  const favorites = useStore((s) => s.favorites)
  const [pokedex, setPokedex] = useState(null)
  const [tab, setTab] = useState(() => (window.location.hash.includes('colecao') ? 'colecao' : 'favoritos'))
  useEffect(() => {
    getPokedex().then(setPokedex)
  }, [])

  const list = useMemo(() => (pokedex ? pokedex.filter((p) => favorites.includes(p.id)) : []), [pokedex, favorites])

  return (
    <div>
      <PageHeader
        title={tab === 'colecao' ? 'Coleção' : 'Favoritos'}
        subtitle={
          tab === 'colecao'
            ? 'Marque os Pokémon que você já pegou em cada jogo, normais e shiny.'
            : 'Dê um duplo clique em um card da Pokédex (ou use a estrela nos detalhes) para favoritar.'
        }
      >
        <div className="flex rounded-full bg-card p-1 shadow">
          {TABS.map((t) => (
            <button
              key={t.key}
              type="button"
              onClick={() => setTab(t.key)}
              className={`cursor-pointer rounded-full px-4 py-2 text-sm font-bold ${tab === t.key ? 'bg-amber-400 text-[#3e2723]' : 'text-muted hover:text-text'}`}
            >
              {t.label}
            </button>
          ))}
        </div>
      </PageHeader>
      {tab === 'colecao' ? (
        <Collection />
      ) : pokedex ? (
        <PokedexGrid pokemon={list} emptyText="Você ainda não favoritou nenhum Pokémon." />
      ) : (
        <Loader />
      )}
    </div>
  )
}
