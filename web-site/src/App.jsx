import { AnimatePresence, m } from 'framer-motion'
import { createContext, Suspense, useContext, useEffect, useState } from 'react'
import { HashRouter, Navigate, NavLink, Route, Routes, useLocation, useNavigate } from 'react-router-dom'
import { SHINY_AVATAR, imageUrl } from './lib/data'
import { getDownloadUrl, RELEASES_URL } from './lib/appRelease'
import { useStore } from './lib/store'
import { TEXT_SIZES, usePrefs, useResolvedTheme } from './lib/prefs'
import { confirmationFromUrl, startAuth, useAuth } from './lib/auth'
import { logout, startSync } from './lib/sync'
import { pendingCount, startFriends, useFriends } from './lib/friends'
import ChatBubble from './components/ChatBubble'
import { Icon, Loader, SpinningPokeball } from './components/ui'
import AccountAvatar from './components/AccountAvatar'
import { TrainerPicker } from './components/Trainer'
import PokedexPage from './pages/PokedexPage'
import { ErrorBoundary, lazyPage } from './lib/staleBuild'
import { t } from './lib/i18n'

const FavoritesPage = lazyPage(() => import('./pages/FavoritesPage'))
const TeamsPage = lazyPage(() => import('./pages/TeamsPage'))
const TeamBuilderPage = lazyPage(() => import('./pages/TeamBuilderPage'))
const CommunityTeamsPage = lazyPage(() => import('./pages/CommunityTeamsPage'))
const OfficialTeamsPage = lazyPage(() => import('./pages/OfficialTeamsPage'))
const GamePage = lazyPage(() => import('./pages/GamePage'))
const EncyclopediaPage = lazyPage(() => import('./pages/EncyclopediaPage'))
const TrainingPage = lazyPage(() => import('./pages/TrainingPage'))
const SettingsPage = lazyPage(() => import('./pages/SettingsPage'))
const AchievementsPage = lazyPage(() => import('./pages/AchievementsPage'))
const FriendsPage = lazyPage(() => import('./pages/FriendsPage'))
const ChatPage = lazyPage(() => import('./pages/ChatPage'))
const BattlePage = lazyPage(() => import('./pages/BattlePage'))
const TurnBattlePage = lazyPage(() => import('./pages/TurnBattlePage'))
const BattleHistoryPage = lazyPage(() => import('./pages/BattleHistoryPage'))
const ReplayLinkPage = lazyPage(() => import('./pages/BattleHistoryPage').then((m) => ({ default: m.ReplayLinkPage })))
const OnlineBattlePage = lazyPage(() => import('./pages/OnlineBattlePage'))
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

/** Título da seção aberta (no topo). */
function useSectionTitle() {
  const { pathname } = useLocation()
  const extra = { '/conquistas': 'Conquistas', '/configuracoes': 'Configurações' }
  for (const [path, label] of Object.entries(extra)) if (pathname.startsWith(path)) return label
  return [...SECTIONS].reverse().find((s) => (s.path === '/' ? pathname === '/' : pathname.startsWith(s.path)))?.label ?? 'Pokédex'
}

/** Um item do menu lateral. Recolhido: só o ícone, e o nome aparece ao passar o mouse (onTip). */
function SideLink({ section, onNavigate, compact, onTip }) {
  const { pathname } = useLocation()
  const active = section.path === '/' ? pathname === '/' : pathname.startsWith(section.path)
  return (
    <NavLink
      to={section.path}
      onClick={onNavigate}
      aria-label={compact ? section.label : undefined}
      {...(compact ? tipHandlers(onTip, section.label) : {})}
      className={`relative flex h-10 items-center gap-3 rounded-xl text-[15px] font-semibold transition ${compact ? 'justify-center px-0' : 'px-3'} ${active ? 'bg-card text-text' : 'text-muted hover:bg-card/60 hover:text-text'}`}
    >
      {active && <span className={`absolute top-2 bottom-2 w-1 rounded-full ${compact ? '-left-2' : '-left-3'}`} style={{ background: section.color }} />}
      <Icon name={section.icon} size={20} style={{ color: active ? section.color : undefined }} />
      {!compact && section.label}
    </NavLink>
  )
}

/** Mouse em cima de um botão do menu recolhido: mostra o nome dele ao lado. */
function tipHandlers(onTip, label) {
  if (!onTip) return {}
  const show = (e) => {
    const r = e.currentTarget.getBoundingClientRect()
    onTip({ label, top: r.top + r.height / 2, left: r.right + 10 })
  }
  return { onMouseEnter: show, onFocus: show, onMouseLeave: () => onTip(null), onBlur: () => onTip(null) }
}

/**
 * Menu lateral: fixo no PC (dá para recolher, deixando só os ícones e mais
 * espaço para a tela); no celular abre como gaveta pelo botão ☰.
 */
function Sidebar({ open, onClose, collapsed, onToggle }) {
  const apkUrl = useDownloadUrl()
  const navigate = useNavigate()
  const signedIn = useAuth((s) => s.status === 'signedIn')
  // Nome do botão embaixo do mouse, no menu recolhido ({label, top, left}).
  const [tip, setTip] = useState(null)
  // Recolhido ou aberto, cada botão fica na mesma altura (logo, itens e os de
  // baixo com o mesmo tamanho): só os nomes somem.
  const body = (compact, toggle) => {
    const onTip = compact ? setTip : null
    return (
    <div className={`flex h-full flex-col gap-1 bg-sidebar py-5 ${compact ? 'px-2' : 'px-4'}`}>
      <button type="button" onClick={() => { navigate('/'); onClose() }} className="mb-3 flex h-16 cursor-pointer items-center justify-center px-2" aria-label="PocketDex">
        <img src={imageUrl('poke_logo.png')} alt="PocketDex" className={`logo transition-all ${compact ? 'h-11' : 'h-16'}`} />
      </button>
      <nav className="flex flex-col gap-1">
        {SECTIONS.map((s) => <SideLink key={s.path} section={s} onNavigate={onClose} compact={compact} onTip={onTip} />)}
      </nav>
      <div className="mt-auto flex flex-col gap-2 pt-5">
        <div className={`flex ${compact ? 'justify-center gap-1' : 'gap-2'}`}>
          {toggle && (
            <button
              type="button"
              onClick={toggle}
              title={compact ? undefined : 'Recolher o menu'}
              aria-label={compact ? 'Abrir o menu lateral' : 'Recolher o menu lateral'}
              {...tipHandlers(onTip, 'Abrir o menu')}
              className={`grid h-10 shrink-0 cursor-pointer place-items-center rounded-xl border border-line bg-card text-muted transition hover:text-text ${compact ? 'w-[34px]' : 'w-10'}`}
            >
              <Icon name={compact ? 'right' : 'left'} size={20} />
            </button>
          )}
          <ThemeToggle narrow={compact} {...tipHandlers(onTip, 'Trocar o tema')} />
        </div>
        <a href={apkUrl} aria-label={compact ? 'Baixar app' : undefined} {...tipHandlers(onTip, 'Baixar app')} className={`flex h-16 items-center gap-3 rounded-2xl bg-card font-semibold ${compact ? 'justify-center px-0' : 'px-3'}`}>
          <span className="grid h-10 w-10 place-items-center rounded-xl bg-[#3DDC84]/15 text-[#3DDC84]"><Icon name="android" size={22} /></span>
          {!compact && <span className="leading-tight">Baixar app<span className="block text-xs font-normal text-muted">Android</span></span>}
        </a>
        {signedIn && (
          <button type="button" onClick={logout} aria-label={compact ? 'Sair da conta' : undefined} {...tipHandlers(onTip, 'Sair da conta')} className={`flex h-10 cursor-pointer items-center gap-3 rounded-xl text-left font-semibold text-muted hover:text-text ${compact ? 'justify-center px-0' : 'px-3'}`}>
            <Icon name="logout" size={20} />
            {!compact && 'Sair da conta'}
          </button>
        )}
      </div>
    </div>
    )
  }
  return (
    <>
      <aside className={`fixed inset-y-0 left-0 z-40 hidden overflow-x-clip overflow-y-auto border-r border-line transition-[width] duration-200 lg:block ${collapsed ? 'w-[88px]' : 'w-64'}`}>
        {body(collapsed, () => { setTip(null); onToggle() })}
      </aside>
      {tip && (
        <div role="tooltip" className="pointer-events-none fixed z-50 hidden -translate-y-1/2 rounded-lg bg-card px-3 py-1.5 text-sm font-semibold whitespace-nowrap text-text shadow-xl ring-1 ring-line lg:block" style={{ top: tip.top, left: tip.left }}>
          {t(tip.label)}
        </div>
      )}
      <AnimatePresence>
        {open && (
          <>
            <m.div key="fundo" className="fixed inset-0 z-50 bg-black/60 lg:hidden" onClick={onClose} initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} />
            <m.aside key="gaveta" className="fixed inset-y-0 left-0 z-50 w-72 max-w-[85vw] overflow-y-auto lg:hidden" initial={{ x: '-100%' }} animate={{ x: 0 }} exit={{ x: '-100%' }} transition={{ duration: 0.22 }}>
              {body(false)}
            </m.aside>
          </>
        )}
      </AnimatePresence>
    </>
  )
}

function TopBar({ onMenu }) {
  const { search, setSearch } = useSearch()
  const navigate = useNavigate()
  const { pathname } = useLocation()
  const title = useSectionTitle()
  const signedIn = useAuth((s) => s.status === 'signedIn')

  const onSearch = (value) => {
    setSearch(value)
    if (pathname !== '/') navigate('/')
  }

  return (
    <header className="sticky top-0 z-30 border-b border-line bg-bg/85 backdrop-blur">
      <div className="flex h-16 items-center gap-3 px-4 sm:px-6">
        <button type="button" onClick={onMenu} className="grid h-10 w-10 shrink-0 cursor-pointer place-items-center rounded-xl text-text hover:bg-card lg:hidden" aria-label="Abrir o menu">
          <Icon name="menu" size={24} />
        </button>
        <button type="button" onClick={() => navigate('/')} className="shrink-0 cursor-pointer lg:hidden" aria-label="PocketDex">
          <img src={imageUrl('poke_logo.png')} alt="PocketDex" className="logo h-10" />
        </button>
        <h1 className="font-display hidden text-lg font-bold lg:block">{title}</h1>
        <label className="ml-auto hidden w-full max-w-sm items-center gap-2 rounded-xl border border-line bg-card px-3 py-2 md:flex">
          <Icon name="search" className="text-muted" />
          <input value={search} onChange={(e) => onSearch(e.target.value)} placeholder="Buscar Pokémon por nome ou número" className="w-full bg-transparent text-sm outline-none placeholder:text-muted" />
        </label>
        <div className="ml-auto flex items-center gap-2 md:ml-0">
          <UserMenu />
          {!signedIn && (
            <button type="button" onClick={() => navigate('/configuracoes')} aria-label="Configurações" title="Configurações" className="grid h-10 w-10 cursor-pointer place-items-center rounded-xl text-text hover:bg-card">
              <Icon name="settings" size={22} />
            </button>
          )}
        </div>
      </div>
      <div className="px-4 pb-3 md:hidden">
        <label className="flex items-center gap-2 rounded-xl border border-line bg-card px-3 py-2">
          <Icon name="search" className="text-muted" />
          <input value={search} onChange={(e) => onSearch(e.target.value)} placeholder="Buscar Pokémon" className="w-full bg-transparent text-sm outline-none placeholder:text-muted" />
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

/** Botão de tema claro/escuro no menu lateral (sol ↔ lua). */
function ThemeToggle({ narrow = false, ...hover }) {
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
      title={narrow ? undefined : dark ? 'Tema claro' : 'Tema escuro'}
      {...hover}
      className={`grid h-10 shrink-0 cursor-pointer place-items-center rounded-xl border border-line bg-card text-text ${narrow ? 'w-[34px]' : 'w-10'}`}
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
  const [pickingTrainer, setPickingTrainer] = useState(false)
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
            <MenuItem
              icon="groups"
              onClick={() => {
                setOpen(false)
                setPickingTrainer(true)
              }}
            >
              Meu treinador
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
          extras
          onClose={() => setPicking(false)}
          onPick={(p, { shiny } = {}) => {
            setAvatar(shiny ? p.id + SHINY_AVATAR : p.id)
            setPicking(false)
          }}
        />
        <TrainerPicker open={pickingTrainer} onClose={() => setPickingTrainer(false)} />
      </Suspense>
    </div>
  )
}

/** Tela de abertura enquanto o login é verificado. */
function Splash() {
  return (
    <div className="grid min-h-screen place-items-center bg-bg">
      <div className="flex flex-col items-center gap-6">
        <img src={imageUrl('poke_logo.png')} alt="PocketDex" className="logo h-20" />
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
  // Replay por link: abre sem conta (só a batalha, sem o resto do site).
  if (window.location.hash.startsWith('#/batalha/replay')) {
    return (
      <HashRouter>
        <Suspense fallback={<Splash />}>
          <main className="p-4">
            <ReplayLinkPage />
          </main>
        </Suspense>
      </HashRouter>
    )
  }
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

/**
 * No Android, um link de time, replay ou desafio oferece abrir no app
 * (lib/services/deep_links.dart). Sem o app instalado, o Chrome fica no site.
 */
const APP_LINK = /^\/(times\/importar\/|batalha\/replay|jogo$)/
function OpenInApp() {
  const { pathname, search } = useLocation()
  const [closed, setClosed] = useState(false)
  const route = pathname + search
  if (closed || typeof navigator === 'undefined' || !/Android/i.test(navigator.userAgent)) return null
  if (!APP_LINK.test(pathname) || (pathname === '/jogo' && !search.includes('desafio='))) return null
  const fallback = encodeURIComponent(window.location.href)
  const href = `intent://open?u=${encodeURIComponent(route)}#Intent;scheme=pocketdex;package=com.octaviokonzen.pocketdex;S.browser_fallback_url=${fallback};end`
  return (
    <div className="mx-auto mt-3 flex max-w-[1920px] items-center justify-between gap-3 px-4 sm:px-6" data-testid="open-in-app">
      <a href={href} className="flex-1 rounded-xl bg-emerald-500 px-4 py-2 text-center font-bold text-white">📱 {t('Abrir no app')}</a>
      <button type="button" onClick={() => setClosed(true)} className="cursor-pointer text-muted" aria-label={t('Fechar')}>✕</button>
    </div>
  )
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

/** A troca de página: um fade curto (sem corte seco). */
function PageFade({ children }) {
  const { pathname } = useLocation()
  return <div key={pathname} className="page-in">{children}</div>
}

export default function App() {
  const [search, setSearch] = useState('')
  const [menuOpen, setMenuOpen] = useState(false)
  // Menu lateral recolhido (só no PC), lembrado neste navegador.
  const [collapsed, setCollapsed] = useState(() => {
    try {
      return localStorage.getItem('sidebar-collapsed') === '1'
    } catch {
      return false
    }
  })
  const toggleSidebar = () => {
    setCollapsed((c) => {
      try {
        localStorage.setItem('sidebar-collapsed', c ? '0' : '1')
      } catch {
        // Sem armazenamento: vale só nesta visita.
      }
      return !c
    })
  }
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
          <Sidebar open={menuOpen} onClose={() => setMenuOpen(false)} collapsed={collapsed} onToggle={toggleSidebar} />
          <div className={`transition-[padding] duration-200 ${collapsed ? 'lg:pl-[88px]' : 'lg:pl-64'}`}>
          <TopBar onMenu={() => setMenuOpen(true)} />
          <OpenInApp />
          <main className="mx-auto max-w-[1600px] px-4 py-6 sm:px-8">
            <PageBoundary>
              <Suspense fallback={<Loader />}>
                <PageFade>
                <Routes>
                  <Route path="/" element={<PokedexPage />} />
                  <Route path="/favoritos" element={<FavoritesPage />} />
                  <Route path="/times" element={<TeamsPage />} />
                  <Route path="/times/importar/:code" element={<TeamsPage />} />
                  <Route path="/times/comunidade" element={<CommunityTeamsPage />} />
                  <Route path="/times/personagens" element={<OfficialTeamsPage />} />
                  <Route path="/times/:id" element={<TeamBuilderPage />} />
                  <Route path="/jogo" element={<GamePage />} />
                  <Route path="/enciclopedia" element={<EncyclopediaPage />} />
                  <Route path="/enciclopedia/:tab" element={<EncyclopediaPage />} />
                  <Route path="/batalha" element={<BattlePage />} />
                  <Route path="/batalha/computador" element={<TurnBattlePage />} />
                  <Route path="/batalha/historico" element={<BattleHistoryPage />} />
                  <Route path="/batalha/replay" element={<ReplayLinkPage />} />
                  <Route path="/batalha/online" element={<OnlineBattlePage />} />
                  <Route path="/batalha/online/:id" element={<OnlineBattlePage />} />
                  <Route path="/batalha/draft" element={<DraftPage />} />
                  <Route path="/batalha/draft/:id" element={<DraftPage />} />
                  <Route path="/batalha/:tool" element={<BattlePage />} />
                  <Route path="/treino" element={<TrainingPage />} />
                  <Route path="/treino/:tool" element={<TrainingPage />} />
                  <Route path="/configuracoes" element={<SettingsPage />} />
                  <Route path="/conquistas" element={<AchievementsPage />} />
                  <Route path="/amigos" element={<FriendsPage />} />
                  <Route path="/amigos/chat/:uid" element={<ChatPage />} />
                  {/* As Trocas saíram (as conversas ficam em Amigos): link antigo vai para lá. */}
                  <Route path="/amigos/trocas" element={<Navigate to="/amigos" replace />} />
                  {/* Endereços antigos dos modos de batalha (convites e links já enviados). */}
                  <Route path="/amigos/batalha" element={<TurnBattlePage />} />
                  <Route path="/amigos/online" element={<OnlineBattlePage />} />
                  <Route path="/amigos/online/:id" element={<OnlineBattlePage />} />
                  <Route path="/amigos/draft" element={<DraftPage />} />
                  <Route path="/amigos/draft/:id" element={<DraftPage />} />
                  <Route path="*" element={<PokedexPage />} />
                </Routes>
                </PageFade>
              </Suspense>
            </PageBoundary>
          </main>
          </div>
          <ChatBubble />
        </SearchContext.Provider>
      </HashRouter>
    </AuthGate>
  )
}
