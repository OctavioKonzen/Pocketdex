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

const loadMotion = () => import('./lib/motionFeatures').then((mod) => mod.default)

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
