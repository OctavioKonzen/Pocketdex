import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import '@fontsource/roboto/400.css'
import '@fontsource/roboto/500.css'
import '@fontsource/roboto/700.css'
import '@fontsource/roboto/900.css'
import './index.css'
import { LazyMotion } from 'framer-motion'
import App from './App.jsx'
import { ErrorBoundary } from './lib/staleBuild'
import './lib/install'
import { language, loadPokemonNames, loadTexts, startTranslating } from './lib/i18n'
import { getPokemonIndex } from './lib/data'

const loadMotion = () => import('./lib/motionFeatures').then((mod) => mod.default)

// Francês e espanhol: carrega antes os nomes oficiais dos Pokémon no idioma.
// Outro idioma: carrega também as descrições de golpes, habilidades e itens.
const namesReady = Promise.all([
  language === 'fr' || language === 'es' ? getPokemonIndex().then(loadPokemonNames).catch(() => {}) : null,
  loadTexts(),
])

namesReady.then(() => {
  createRoot(document.getElementById('root')).render(
    <StrictMode>
      {/* Animações carregam em segundo plano; `strict` garante que só usamos <m.*>. */}
      {/* Qualquer erro fora das páginas (menu, login...) mostra um aviso em vez da tela vazia. */}
      <ErrorBoundary>
        <LazyMotion features={loadMotion} strict>
          <App />
        </LazyMotion>
      </ErrorBoundary>
    </StrictMode>,
  )
  // Outro idioma: os textos da tela são trocados assim que aparecem.
  startTranslating()
})

// Site instalável (PWA) e abrindo sem internet. Só no site publicado.
if (import.meta.env.PROD && 'serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register(`${import.meta.env.BASE_URL}sw.js`).catch(() => {})
  })
}
