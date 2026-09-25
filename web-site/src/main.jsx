import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import '@fontsource/roboto/400.css'
import '@fontsource/roboto/500.css'
import '@fontsource/roboto/700.css'
import '@fontsource/roboto/900.css'
import './index.css'
import { LazyMotion } from 'framer-motion'
import App from './App.jsx'

const loadMotion = () => import('./lib/motionFeatures').then((mod) => mod.default)

createRoot(document.getElementById('root')).render(
  <StrictMode>
    {/* Animações carregam em segundo plano; `strict` garante que só usamos <m.*>. */}
    <LazyMotion features={loadMotion} strict>
      <App />
    </LazyMotion>
  </StrictMode>,
)
