// Instalar o site como app (PWA). O navegador avisa com `beforeinstallprompt`
// só uma vez, logo ao abrir; guardamos o aviso para o botão das Configurações.
import { useSyncExternalStore } from 'react'

let deferred = null
const listeners = new Set()
const emit = () => listeners.forEach((fn) => fn())

if (typeof window !== 'undefined') {
  window.addEventListener('beforeinstallprompt', (event) => {
    event.preventDefault()
    deferred = event
    emit()
  })
  window.addEventListener('appinstalled', () => {
    deferred = null
    emit()
  })
}

const subscribe = (fn) => {
  listeners.add(fn)
  return () => listeners.delete(fn)
}

/** O navegador deixa instalar o site agora? */
export const useCanInstall = () => useSyncExternalStore(subscribe, () => deferred !== null, () => false)

/** Abre a janela do navegador para instalar o site. */
export async function installSite() {
  const event = deferred
  if (!event) return
  deferred = null
  emit()
  await event.prompt()
}
