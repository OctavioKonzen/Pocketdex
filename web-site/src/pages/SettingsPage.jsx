import { m } from 'framer-motion'
import { useState } from 'react'
import { Button, Modal, PageHeader } from '../components/ui'
import { useAuth } from '../lib/auth'
import { useStore } from '../lib/store'
import { logout } from '../lib/sync'

export default function SettingsPage() {
  const theme = useStore((s) => s.theme)
  const setTheme = useStore((s) => s.setTheme)
  const clearCollections = useStore((s) => s.clearCollections)
  const [confirm, setConfirm] = useState(null)
  const [message, setMessage] = useState('')
  const user = useAuth((s) => (s.status === 'signedIn' ? s.user : null))

  const actions = {
    all: { title: 'Limpar dados', text: 'Isso apaga seus favoritos, times e treinos. Continuar?', run: clearCollections, done: 'Preferências de usuário limpas!' },
  }

  return (
    <div className="mx-auto max-w-2xl">
      <PageHeader title="Configurações" />
      <div className="space-y-3">
        {user && (
          <div className="flex items-center justify-between gap-4 rounded-2xl bg-card p-5 shadow">
            <div className="min-w-0">
              <div className="font-bold">Conta</div>
              <div className="truncate text-sm text-muted">
                {user.name} · {user.email}
              </div>
            </div>
            <Button color="#e53935" onClick={logout}>
              Sair
            </Button>
          </div>
        )}
        <div className="flex items-center justify-between rounded-2xl bg-card p-5 shadow">
          <div>
            <div className="font-bold">Modo Escuro</div>
            <div className="text-sm text-muted">Ative para uma experiência com cores escuras.</div>
          </div>
          <button
            type="button"
            role="switch"
            aria-checked={theme === 'dark'}
            onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}
            className={`relative h-8 w-14 cursor-pointer rounded-full transition-colors ${theme === 'dark' ? 'bg-sky-500' : 'bg-gray-400'}`}
          >
            <m.span layout className="absolute top-1 h-6 w-6 rounded-full bg-white shadow" style={{ left: theme === 'dark' ? 28 : 4 }} />
          </button>
        </div>
        <div className="flex items-center justify-between rounded-2xl bg-card p-5 shadow">
          <div>
            <div className="font-bold">Dados salvos</div>
            <div className="text-sm text-muted">{user ? 'Favoritos, times e treinos ficam salvos na sua conta.' : 'Favoritos, times e treinos ficam salvos neste navegador.'}</div>
          </div>
          <Button color="#e53935" onClick={() => setConfirm('all')}>
            Limpar
          </Button>
        </div>
        {message && <p className="text-center text-green-400">{message}</p>}
        <p className="pt-6 text-center text-sm text-muted">PocketDex · Site feito em JavaScript (React) com dados gerados em Python.</p>
      </div>

      <Modal open={Boolean(confirm)} onClose={() => setConfirm(null)} title="Confirmar Ação">
        <p>{confirm && actions[confirm].text}</p>
        <div className="mt-5 flex justify-end gap-3">
          <button type="button" onClick={() => setConfirm(null)} className="cursor-pointer px-4 text-muted">
            Cancelar
          </button>
          <Button
            color="#e53935"
            onClick={() => {
              actions[confirm].run()
              setMessage(actions[confirm].done)
              setConfirm(null)
            }}
          >
            {confirm && actions[confirm].title}
          </Button>
        </div>
      </Modal>
    </div>
  )
}
