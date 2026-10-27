// Quando sai uma versão nova do site, os arquivos da versão antiga somem do
// servidor. Uma aba aberta antes disso, ao trocar de página, tenta baixar um
// arquivo que não existe mais e a tela ficava cinza até recarregar na mão.
// Aqui a página recarrega sozinha (uma vez) para pegar a versão nova.

import { Component, lazy } from 'react'

const KEY = 'pocketdex-stale-reload'

/** Recarrega a página, no máximo uma vez a cada 10 segundos. */
export function reloadForNewVersion() {
  try {
    const last = Number(sessionStorage.getItem(KEY) || 0)
    if (Date.now() - last < 10000) return false
    sessionStorage.setItem(KEY, String(Date.now()))
  } catch {
    // sem sessionStorage: recarrega mesmo assim
  }
  window.location.reload()
  return true
}

// Falha ao pré-carregar arquivos do Vite (CSS/JS) também é sinal de versão nova.
if (typeof window !== 'undefined') {
  window.addEventListener('vite:preloadError', (event) => {
    if (reloadForNewVersion()) event.preventDefault()
  })
}

/** Igual ao React.lazy, mas recarrega a página se o arquivo sumiu. */
export function lazyPage(load) {
  return lazy(() =>
    load().catch((error) => {
      if (reloadForNewVersion()) return new Promise(() => {})
      throw error
    }),
  )
}

/** Se mesmo assim algo quebrar, mostra um aviso em vez da tela vazia. */
export class ErrorBoundary extends Component {
  state = { failed: false, message: '' }

  static getDerivedStateFromError(error) {
    return { failed: true, message: String(error?.message ?? error ?? '').slice(0, 300) }
  }

  componentDidCatch(error) {
    console.error(error)
  }

  render() {
    if (!this.state.failed) return this.props.children
    return (
      <div className="grid min-h-[60vh] place-items-center p-6 text-center text-text">
        <div>
          <p className="mb-2 text-lg font-bold">Algo deu errado ao abrir esta página.</p>
          {this.state.message && <p className="mx-auto mb-4 max-w-md text-xs break-words opacity-60">Erro: {this.state.message}</p>}
          <button
            type="button"
            onClick={() => window.location.reload()}
            className="cursor-pointer rounded-full bg-[#FF5252] px-6 py-2 font-bold text-white"
          >
            Recarregar
          </button>
        </div>
      </div>
    )
  }
}
