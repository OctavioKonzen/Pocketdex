import { AnimatePresence, m } from 'framer-motion'
import { createContext, Suspense, useContext, useEffect, useState } from 'react'
import { HashRouter, Navigate, NavLink, Route, Routes, useLocation, useNavigate } from 'react-router-dom'
import { imageUrl } from './lib/data'
import { getDownloadUrl, RELEASES_URL } from './lib/appRelease'
import { useStore } from './lib/store'
import { TEXT_SIZES, usePrefs, useResolvedTheme } from './lib/prefs'
import { confirmationFromUrl, startAuth, useAuth } from './lib/auth'
import { logout, startSync } from './lib/sync'
import { pendingCount, startFriends, useFriends } from './lib/friends'
import ChatBubble from './components/ChatBubble'
import { Icon, Loader, SpinningPokeball } from './components/ui'
import AccountAvatar from './components/AccountAvatar'
import PokedexPage from './pages/PokedexPage'
import { ErrorBoundary, lazyPage } from './lib/staleBuild'

const FavoritesPage = lazyPage(() => import('./pages/FavoritesPage'))
const TeamsPage = lazyPage(() => import('./pages/TeamsPage'))
const TeamBuilderPage = lazyPage(() => import('./pages/TeamBuilderPage'))
const CommunityTeamsPage = lazyPage(() => import('./pages/CommunityTeamsPage'))
const GamePage = lazyPage(() => import('./pages/GamePage'))
const EncyclopediaPage = lazyPage(() => import('./pages/EncyclopediaPage'))
const TrainingPage = lazyPage(() => import('./pages/TrainingPage'))
const SettingsPage = lazyPage(() => import('./pages/SettingsPage'))
const AchievementsPage = lazyPage(() => import('./pages/AchievementsPage'))
const FriendsPage = lazyPage(() => import('./pages/FriendsPage'))
const ChatPage = lazyPage(() => import('./pages/ChatPage'))
const BattlePage = lazyPage(() => import('./pages/BattlePage'))
const TurnBattlePage = lazyPage(() => import('./pages/TurnBattlePage'))
const DraftPage = lazyPage(() => import('./pages/DraftPage'))
const LoginPage = lazyPage(() => import('./pages/LoginPage'))
const PokemonPicker = lazyPage(() => import('./components/PokemonPicker'))
const EmailLinkPage = lazyPage(() => import('./components/EmailLinkPage'))

// Mesmas cores dos cards do menu do app.
export const SECTIONS = [
  { path: '/', label: 'Pokédex', color: '#26A69A', icon: 'pokeball' },
  { path: '/favoritos', label: 'Favoritos', color: '#FFCA28', icon: 'star' },
  { path: '/times', label: 'Times', color: '#FF5252', icon: 'groups' },
  { path: '/jogo', label: 'Jogo', color: '#42A5F5', icon: 'gamepad' },
  { path: '/batalha', label: 'Batalha', color: '#607D8B', icon: 'physical' },
  { path: '/enciclopedia', label: 'Enciclopédia', color: '#AB47BC', icon: 'book' },
  { path: '/treino', label: 'Treino', color: '#FFA726', icon: 'fitness' },
  { path: '/amigos', label: 'Amigos', color: '#5C6BC0', icon: 'chat' },
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
        {/* Em telas menores aparecem só os ícones. */}
        <span className="hidden min-[1440px]:inline">{section.label}</span>
      </m.span>
    </NavLink>
  )
}

function TopBar() {
  const { search, setSearch } = useSearch()
  const apkUrl = useDownloadUrl()
  const navigate = useNavigate()
  const { pathname } = useLocation()
  const signedIn = useAuth((s) => s.status === 'signedIn')

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
        {/* Com os 8 botões do menu, a busca só cabe no topo em telas bem largas. */}
        <label className="hidden w-[280px] shrink-0 items-center gap-2 rounded-full bg-bg px-4 py-2.5 min-[1760px]:flex">
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
          className="flex shrink-0 items-center gap-1.5 rounded-full bg-[#3DDC84] px-2.5 py-2 text-sm font-bold text-[#073042] min-[1760px]:px-4"
        >
          <Icon name="android" size={20} />
          <span className="hidden min-[1760px]:inline">Baixar app</span>
        </m.a>
        <ThemeToggle />
        <UserMenu />
        {/* Sem conta: as Configurações ficam na engrenagem (com conta, no menu do avatar). */}
        {!signedIn && (
          <m.button type="button" whileHover={{ scale: 1.15, rotate: 45 }} onClick={() => navigate('/configuracoes')} aria-label="Configurações" title="Configurações" className="shrink-0 cursor-pointer text-text">
            <Icon name="settings" size={26} />
          </m.button>
        )}
      </div>
      {/* Busca em telas menores */}
      <div className="px-4 pb-3 min-[1760px]:hidden">
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
  const theme = useResolvedTheme(useStore((s) => s.theme))
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

/** Uma linha do menu do avatar. */
function MenuItem({ icon, danger = false, onClick, badge = 0, children }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`flex w-full cursor-pointer items-center gap-3 rounded-xl px-3 py-2.5 text-left font-semibold transition hover:bg-surface ${danger ? 'text-red-500' : 'text-text'}`}
    >
      <Icon name={icon} size={20} className={danger ? '' : 'text-muted'} />
      {children}
      {badge > 0 && <span className="ml-auto grid h-5 min-w-5 place-items-center rounded-full bg-red-500 px-1.5 text-xs font-black text-white">{badge}</span>}
    </button>
  )
}

/** Pessoa logada: foto de perfil; o menu tem a foto, conquistas, configurações e sair. */
function UserMenu() {
  const user = useAuth((s) => (s.status === 'signedIn' ? s.user : null))
  const avatar = useStore((s) => s.avatar)
  const setAvatar = useStore((s) => s.setAvatar)
  const [open, setOpen] = useState(false)
  const [picking, setPicking] = useState(false)
  const pending = useFriends((s) => pendingCount(s.list))
  const navigate = useNavigate()
  const go = (path) => {
    setOpen(false)
    navigate(path)
  }
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
        <span className="relative">
          <AccountAvatar size={36} />
          {/* Pedidos de amizade e desafios esperando. */}
          {pending > 0 && <span className="absolute -top-1 -right-1 h-3.5 w-3.5 rounded-full bg-red-500 ring-2 ring-surface" />}
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
            <div className="mb-4 flex items-center gap-3">
              <AccountAvatar size={56} />
              <div className="min-w-0">
                <div className="truncate text-lg font-bold">{user.name}</div>
                <div className="truncate text-sm text-muted">{user.email}</div>
              </div>
            </div>
            <MenuItem
              icon="pokeball"
              onClick={() => {
                setOpen(false)
                setPicking(true)
              }}
            >
              Trocar foto de perfil
            </MenuItem>
            {avatar != null && (
              <MenuItem icon="close" onClick={() => setAvatar(null)}>
                Tirar a foto
              </MenuItem>
            )}
            <MenuItem icon="groups" onClick={() => go('/amigos')} badge={pending}>
              Amigos
            </MenuItem>
            <MenuItem icon="trophy" onClick={() => go('/conquistas')}>
              Conquistas
            </MenuItem>
            <MenuItem icon="settings" onClick={() => go('/configuracoes')}>
              Configurações
            </MenuItem>
            <div className="my-2 h-px bg-line" />
            <MenuItem icon="logout" danger onClick={logout}>
              Sair da conta
            </MenuItem>
          </m.div>
        )}
      </AnimatePresence>
      <Suspense fallback={null}>
        <PokemonPicker
          open={picking}
          title="Escolha sua foto de perfil"
          onClose={() => setPicking(false)}
          onPick={(p) => {
            setAvatar(p.id)
            setPicking(false)
          }}
        />
      </Suspense>
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
  // Aberto pelo link de confirmação do e-mail (contas Google).
  const [linkPurpose, setLinkPurpose] = useState(() => confirmationFromUrl())
  useEffect(() => {
    startSync()
    startFriends()
    startAuth()
  }, [])
  if (status === 'loading') return <Splash />
  if (linkPurpose && status !== 'disabled') {
    return (
      <Suspense fallback={<Splash />}>
        <EmailLinkPage
          purpose={linkPurpose}
          onDone={() => {
            window.history.replaceState(null, '', `${import.meta.env.BASE_URL}${window.location.hash}`)
            setLinkPurpose(null)
          }}
        />
      </Suspense>
    )
  }
  if (status === 'disabled' || status === 'signedIn') return children
  return (
    <Suspense fallback={<Splash />}>
      <LoginPage />
    </Suspense>
  )
}

/** Um erro numa página não derruba o site; ao trocar de aba ela tenta de novo. */
function PageBoundary({ children }) {
  const { pathname } = useLocation()
  return <ErrorBoundary key={pathname}>{children}</ErrorBoundary>
}

function ScrollToTop() {
  const { pathname } = useLocation()
  // Chaves: o efeito não pode devolver o resultado do scrollTo (no Opera GX ele
  // não é undefined e o React tentava chamá-lo ao trocar de página → tela vazia).
  useEffect(() => {
    window.scrollTo(0, 0)
  }, [pathname])
  return null
}

export default function App() {
  const [search, setSearch] = useState('')
  const theme = useResolvedTheme(useStore((s) => s.theme))
  const textSize = usePrefs((s) => s.textSize)
  const backgroundAnimation = usePrefs((s) => s.backgroundAnimation)
  useEffect(() => {
    document.documentElement.dataset.theme = theme
  }, [theme])
  // Tamanho do texto (Configurações): tudo no site é medido em rem.
  useEffect(() => {
    const scale = TEXT_SIZES.find((t) => t.key === textSize)?.scale ?? 1
    document.documentElement.style.fontSize = scale === 1 ? '' : `${scale * 100}%`
  }, [textSize])

  return (
    <AuthGate>
      <HashRouter>
        <SearchContext.Provider value={{ search, setSearch }}>
          <ScrollToTop />
          <div className={`pokeball-backdrop ${backgroundAnimation ? '' : 'still'}`} aria-hidden="true" />
          <TopBar />
          <main className="mx-auto max-w-[1920px] px-4 py-5 sm:px-6">
            <PageBoundary>
              <Suspense fallback={<Loader />}>
                <Routes>
                  <Route path="/" element={<PokedexPage />} />
                  <Route path="/favoritos" element={<FavoritesPage />} />
                  <Route path="/times" element={<TeamsPage />} />
                  <Route path="/times/importar/:code" element={<TeamsPage />} />
                  <Route path="/times/comunidade" element={<CommunityTeamsPage />} />
                  <Route path="/times/:id" element={<TeamBuilderPage />} />
                  <Route path="/jogo" element={<GamePage />} />
                  <Route path="/enciclopedia" element={<EncyclopediaPage />} />
                  <Route path="/enciclopedia/:tab" element={<EncyclopediaPage />} />
                  <Route path="/batalha" element={<BattlePage />} />
                  <Route path="/batalha/:tool" element={<BattlePage />} />
                  <Route path="/treino" element={<TrainingPage />} />
                  <Route path="/treino/:tool" element={<TrainingPage />} />
                  <Route path="/configuracoes" element={<SettingsPage />} />
                  <Route path="/conquistas" element={<AchievementsPage />} />
                  <Route path="/amigos" element={<FriendsPage />} />
                  <Route path="/amigos/chat/:uid" element={<ChatPage />} />
                  {/* As Trocas saíram (as conversas ficam em Amigos): link antigo vai para lá. */}
                  <Route path="/amigos/trocas" element={<Navigate to="/amigos" replace />} />
                  <Route path="/amigos/batalha" element={<TurnBattlePage />} />
                  <Route path="/amigos/draft" element={<DraftPage />} />
                  <Route path="/amigos/draft/:id" element={<DraftPage />} />
                  <Route path="*" element={<PokedexPage />} />
                </Routes>
              </Suspense>
            </PageBoundary>
          </main>
          <ChatBubble />
        </SearchContext.Provider>
      </HashRouter>
    </AuthGate>
  )
}
