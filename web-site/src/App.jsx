import { AnimatePresence, m } from 'framer-motion'
import { createContext, lazy, Suspense, useContext, useEffect, useState } from 'react'
import { HashRouter, NavLink, Route, Routes, useLocation, useNavigate } from 'react-router-dom'
import { imageUrl } from './lib/data'
import { getDownloadUrl, RELEASES_URL } from './lib/appRelease'
import { useStore } from './lib/store'
import { startAuth, useAuth } from './lib/auth'
import { logout, startSync } from './lib/sync'
import { Icon, Loader, SpinningPokeball } from './components/ui'
import PokedexPage from './pages/PokedexPage'

const FavoritesPage = lazy(() => import('./pages/FavoritesPage'))
const TeamsPage = lazy(() => import('./pages/TeamsPage'))
const TeamBuilderPage = lazy(() => import('./pages/TeamBuilderPage'))
const GamePage = lazy(() => import('./pages/GamePage'))
const EncyclopediaPage = lazy(() => import('./pages/EncyclopediaPage'))
const TrainingPage = lazy(() => import('./pages/TrainingPage'))
const SettingsPage = lazy(() => import('./pages/SettingsPage'))
const LoginPage = lazy(() => import('./pages/LoginPage'))

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
      <m.span
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
      </m.span>
    </NavLink>
  )
}

function TopBar() {
  const { search, setSearch } = useSearch()
  const apkUrl = useDownloadUrl()
  const navigate = useNavigate()
  const { pathname } = useLocation()

  const onSearch = (value) => {
    setSearch(value)
    if (pathname !== '/') navigate('/')
  }

  return (
    <header className="sticky top-0 z-40 bg-surface shadow-lg">
      <div className="flex h-[72px] items-center gap-2 px-3 sm:gap-4 sm:px-6">
        <m.button type="button" onClick={() => navigate('/')} whileHover={{ scale: 1.08 }} className="shrink-0 cursor-pointer" aria-label="PocketDex">
          <img src={imageUrl('poke_logo.png')} alt="PocketDex" className="h-10 md:h-[52px]" />
        </m.button>
        <nav className="flex min-w-0 flex-1 gap-1 overflow-x-auto py-2">
          {SECTIONS.map((s) => (
            <NavButton key={s.path} section={s} />
          ))}
        </nav>
        <label className="hidden w-[210px] shrink-0 items-center gap-2 rounded-full bg-bg px-4 py-2.5 lg:flex 2xl:w-[280px]">
          <Icon name="search" className="text-muted" />
          <input
            value={search}
            onChange={(e) => onSearch(e.target.value)}
            placeholder="Procurar Pokémon por nome ou número"
            className="w-full bg-transparent text-sm outline-none placeholder:text-muted"
          />
        </label>
        <m.a
          href={apkUrl}
          whileHover={{ scale: 1.08 }}
          whileTap={{ scale: 0.95 }}
          title="Baixar o app para Android"
          className="flex shrink-0 items-center gap-1.5 rounded-full bg-[#3DDC84] px-2.5 py-2 text-sm font-bold text-[#073042] 2xl:px-4"
        >
          <Icon name="android" size={20} />
          <span className="hidden 2xl:inline">Baixar app</span>
        </m.a>
        <ThemeToggle />
        <UserMenu />
        <m.button type="button" whileHover={{ scale: 1.15, rotate: 45 }} onClick={() => navigate('/configuracoes')} aria-label="Configurações" title="Configurações" className="shrink-0 cursor-pointer text-text">
          <Icon name="settings" size={26} />
        </m.button>
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

/** Link do APK mais recente (GitHub Releases). */
function useDownloadUrl() {
  const [url, setUrl] = useState(RELEASES_URL)
  useEffect(() => {
    getDownloadUrl().then(setUrl)
  }, [])
  return url
}

/** Botão de tema claro/escuro no menu (sol ↔ lua). */
function ThemeToggle() {
  const theme = useStore((s) => s.theme)
  const setTheme = useStore((s) => s.setTheme)
  const dark = theme === 'dark'
  return (
    <m.button
      type="button"
      onClick={() => setTheme(dark ? 'light' : 'dark')}
      whileHover={{ scale: 1.15 }}
      whileTap={{ scale: 0.9 }}
      aria-label={dark ? 'Mudar para tema claro' : 'Mudar para tema escuro'}
      title={dark ? 'Tema claro' : 'Tema escuro'}
      className="grid h-10 w-10 shrink-0 cursor-pointer place-items-center rounded-full bg-bg text-text"
    >
      <AnimatePresence mode="wait" initial={false}>
        <m.span
          key={theme}
          initial={{ rotate: -90, scale: 0, opacity: 0 }}
          animate={{ rotate: 0, scale: 1, opacity: 1 }}
          exit={{ rotate: 90, scale: 0, opacity: 0 }}
          transition={{ duration: 0.25 }}
          className={dark ? 'text-yellow-300' : 'text-indigo-500'}
        >
          <Icon name={dark ? 'sun' : 'moon'} size={22} />
        </m.span>
      </AnimatePresence>
    </m.button>
  )
}

/** Pessoa logada: inicial do nome e menu com "Sair". */
function UserMenu() {
  const user = useAuth((s) => (s.status === 'signedIn' ? s.user : null))
  const [open, setOpen] = useState(false)
  useEffect(() => {
    if (!open) return
    const close = () => setOpen(false)
    window.addEventListener('click', close)
    return () => window.removeEventListener('click', close)
  }, [open])
  if (!user) return null
  return (
    <div className="relative shrink-0">
      <m.button
        type="button"
        whileHover={{ scale: 1.1 }}
        whileTap={{ scale: 0.92 }}
        onClick={(e) => {
          e.stopPropagation()
          setOpen(!open)
        }}
        title={user.name}
        aria-label={`Conta de ${user.name}`}
        className="flex cursor-pointer items-center gap-2 rounded-full bg-bg py-1 pr-1 pl-1 xl:pr-4"
      >
        <span className="grid h-9 w-9 place-items-center overflow-hidden rounded-full bg-red-600 text-lg font-black text-white">
          {user.photo ? <img src={user.photo} alt="" referrerPolicy="no-referrer" className="h-full w-full object-cover" /> : user.name?.[0]?.toUpperCase()}
        </span>
        <span className="hidden max-w-[140px] truncate font-semibold xl:inline">{user.name}</span>
      </m.button>
      <AnimatePresence>
        {open && (
          <m.div
            initial={{ opacity: 0, y: -8, scale: 0.96 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: -8, scale: 0.96 }}
            transition={{ duration: 0.15 }}
            onClick={(e) => e.stopPropagation()}
            className="absolute right-0 mt-2 w-64 rounded-2xl bg-card p-4 shadow-2xl ring-1 ring-line"
          >
            <div className="truncate text-lg font-bold">{user.name}</div>
            <div className="mb-4 truncate text-sm text-muted">{user.email}</div>
            <button type="button" onClick={logout} className="flex w-full cursor-pointer items-center justify-center gap-2 rounded-xl bg-red-600 py-2.5 font-bold text-white transition hover:scale-[1.03]">
              <Icon name="logout" size={20} />
              Sair da conta
            </button>
          </m.div>
        )}
      </AnimatePresence>
    </div>
  )
}

/** Tela de abertura enquanto o login é verificado. */
function Splash() {
  return (
    <div className="grid min-h-screen place-items-center bg-bg">
      <div className="flex flex-col items-center gap-6">
        <img src={imageUrl('poke_logo.png')} alt="PocketDex" className="h-20" />
        <SpinningPokeball size={56} opacity={0.8} />
      </div>
    </div>
  )
}

/** Sem login aparece a tela de entrar; logado, vai direto para o site. */
function AuthGate({ children }) {
  const status = useAuth((s) => s.status)
  useEffect(() => {
    startSync()
    startAuth()
  }, [])
  if (status === 'disabled' || status === 'signedIn') return children
  if (status === 'loading') return <Splash />
  return (
    <Suspense fallback={<Splash />}>
      <LoginPage />
    </Suspense>
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
    <AuthGate>
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
    </AuthGate>
  )
}
