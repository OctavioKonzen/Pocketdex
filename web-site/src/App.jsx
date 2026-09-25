import { motion } from 'framer-motion'
import { createContext, lazy, Suspense, useContext, useEffect, useState } from 'react'
import { HashRouter, NavLink, Route, Routes, useLocation, useNavigate } from 'react-router-dom'
import { imageUrl } from './lib/data'
import { useStore } from './lib/store'
import { Icon, Loader } from './components/ui'
import PokedexPage from './pages/PokedexPage'

const FavoritesPage = lazy(() => import('./pages/FavoritesPage'))
const TeamsPage = lazy(() => import('./pages/TeamsPage'))
const TeamBuilderPage = lazy(() => import('./pages/TeamBuilderPage'))
const GamePage = lazy(() => import('./pages/GamePage'))
const EncyclopediaPage = lazy(() => import('./pages/EncyclopediaPage'))
const TrainingPage = lazy(() => import('./pages/TrainingPage'))
const SettingsPage = lazy(() => import('./pages/SettingsPage'))

// Mesmas cores dos cards do menu do app.
export const SECTIONS = [
  { path: '/', label: 'Pokédex', color: '#26A69A', icon: 'pokeball' },
  { path: '/favoritos', label: 'Favoritos', color: '#FFCA28', icon: 'star' },
  { path: '/times', label: 'Times', color: '#FF5252', icon: 'groups' },
  { path: '/jogo', label: 'Jogo', color: '#42A5F5', icon: 'gamepad' },
  { path: '/enciclopedia', label: 'Enciclopédia', color: '#AB47BC', icon: 'book' },
  { path: '/treino', label: 'Treino', color: '#FFA726', icon: 'fitness' },
]

/** Texto da busca do topo (filtra a Pokédex). */
const SearchContext = createContext({ search: '', setSearch: () => {} })
export const useSearch = () => useContext(SearchContext)

function NavButton({ section }) {
  const { pathname } = useLocation()
  const active = section.path === '/' ? pathname === '/' : pathname.startsWith(section.path)
  const [hover, setHover] = useState(false)
  return (
    <NavLink to={section.path} onMouseEnter={() => setHover(true)} onMouseLeave={() => setHover(false)}>
      <motion.span
        whileHover={{ scale: 1.08 }}
        whileTap={{ scale: 0.95 }}
        title={section.label}
        className="flex items-center gap-2 rounded-full px-3 py-2 text-[15px] font-semibold whitespace-nowrap md:px-4"
        animate={{
          backgroundColor: active ? section.color : hover ? `${section.color}33` : `${section.color}00`,
          color: active ? '#ffffff' : 'var(--text)',
          boxShadow: active ? `0 4px 12px ${section.color}70` : '0 0 0 rgba(0,0,0,0)',
        }}
        transition={{ duration: 0.2 }}
      >
        <Icon name={section.icon} size={20} style={{ color: active || hover ? undefined : section.color }} />
        {/* No celular aparecem só os ícones. */}
        <span className="hidden md:inline">{section.label}</span>
      </motion.span>
    </NavLink>
  )
}

function TopBar() {
  const { search, setSearch } = useSearch()
  const navigate = useNavigate()
  const { pathname } = useLocation()

  const onSearch = (value) => {
    setSearch(value)
    if (pathname !== '/') navigate('/')
  }

  return (
    <header className="sticky top-0 z-40 bg-surface shadow-lg">
      <div className="flex h-[72px] items-center gap-2 px-3 sm:gap-4 sm:px-6">
        <motion.button type="button" onClick={() => navigate('/')} whileHover={{ scale: 1.08 }} className="shrink-0 cursor-pointer" aria-label="PocketDex">
          <img src={imageUrl('poke_logo.png')} alt="PocketDex" className="h-10 md:h-[52px]" />
        </motion.button>
        <nav className="flex min-w-0 flex-1 gap-1 overflow-x-auto py-2">
          {SECTIONS.map((s) => (
            <NavButton key={s.path} section={s} />
          ))}
        </nav>
        <label className="hidden w-[280px] shrink-0 items-center gap-2 rounded-full bg-bg px-4 py-2.5 lg:flex">
          <Icon name="search" className="text-muted" />
          <input
            value={search}
            onChange={(e) => onSearch(e.target.value)}
            placeholder="Procurar Pokémon por nome ou número"
            className="w-full bg-transparent text-sm outline-none placeholder:text-muted"
          />
        </label>
        <motion.button type="button" whileHover={{ scale: 1.15, rotate: 45 }} onClick={() => navigate('/configuracoes')} aria-label="Configurações" title="Configurações" className="shrink-0 cursor-pointer text-text">
          <Icon name="settings" size={26} />
        </motion.button>
      </div>
      {/* Busca em telas menores */}
      <div className="px-4 pb-3 lg:hidden">
        <label className="flex items-center gap-2 rounded-full bg-bg px-4 py-2">
          <Icon name="search" className="text-muted" />
          <input value={search} onChange={(e) => onSearch(e.target.value)} placeholder="Procurar Pokémon" className="w-full bg-transparent text-sm outline-none placeholder:text-muted" />
        </label>
      </div>
    </header>
  )
}

function ScrollToTop() {
  const { pathname } = useLocation()
  useEffect(() => window.scrollTo(0, 0), [pathname])
  return null
}

export default function App() {
  const [search, setSearch] = useState('')
  const theme = useStore((s) => s.theme)
  useEffect(() => {
    document.documentElement.dataset.theme = theme
  }, [theme])

  return (
    <HashRouter>
      <SearchContext.Provider value={{ search, setSearch }}>
        <ScrollToTop />
        <TopBar />
        <main className="mx-auto max-w-[1920px] px-4 py-5 sm:px-6">
          <Suspense fallback={<Loader />}>
            <Routes>
              <Route path="/" element={<PokedexPage />} />
              <Route path="/favoritos" element={<FavoritesPage />} />
              <Route path="/times" element={<TeamsPage />} />
              <Route path="/times/:id" element={<TeamBuilderPage />} />
              <Route path="/jogo" element={<GamePage />} />
              <Route path="/enciclopedia" element={<EncyclopediaPage />} />
              <Route path="/enciclopedia/:tab" element={<EncyclopediaPage />} />
              <Route path="/treino" element={<TrainingPage />} />
              <Route path="/treino/:tool" element={<TrainingPage />} />
              <Route path="/configuracoes" element={<SettingsPage />} />
              <Route path="*" element={<PokedexPage />} />
            </Routes>
          </Suspense>
        </main>
      </SearchContext.Provider>
    </HashRouter>
  )
}
