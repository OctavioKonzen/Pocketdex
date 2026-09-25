import { m } from 'framer-motion'
import { useEffect, useState } from 'react'
import { Button, Icon, Modal, PageHeader } from '../components/ui'
import { getLatestRelease, RELEASES_URL } from '../lib/appRelease'
import { useAuth } from '../lib/auth'
import AccountAvatar from '../components/AccountAvatar'
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
            <AccountAvatar size={48} />
            <div className="min-w-0 flex-1">
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
        <AndroidAppCard />
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

/** Download do app Android (APK), com a versão mais recente. */
function AndroidAppCard() {
  const [release, setRelease] = useState(undefined)
  useEffect(() => {
    getLatestRelease().then(setRelease)
  }, [])
  return (
    <div className="rounded-2xl bg-card p-5 shadow">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div className="flex items-center gap-4">
          <span className="grid h-12 w-12 shrink-0 place-items-center rounded-2xl bg-[#3DDC84] text-[#073042]">
            <Icon name="android" size={28} />
          </span>
          <div>
            <div className="font-bold">App para Android</div>
            <div className="text-sm text-muted">
              {release === undefined
                ? 'Procurando a última versão...'
                : release
                  ? `Versão ${release.version} · ${release.sizeMb} MB · ${release.date}`
                  : 'A primeira versão ainda vai ser publicada.'}
            </div>
          </div>
        </div>
        {release ? (
          <a href={release.url} className="flex items-center gap-2 rounded-xl bg-[#3DDC84] px-5 py-2.5 font-bold text-[#073042] shadow-md transition hover:scale-105">
            <Icon name="download" size={20} /> Baixar APK
          </a>
        ) : null}
      </div>
      <p className="mt-3 text-sm text-muted">
        Entre com a mesma conta do site: favoritos, times, treinos e recordes aparecem nos dois. No celular, abra o arquivo baixado e
        permita instalar apps desta fonte. As próximas versões são avisadas e instaladas pelo próprio app.{' '}
        <a href={RELEASES_URL} className="underline hover:text-text" target="_blank" rel="noreferrer">
          Todas as versões
        </a>
      </p>
    </div>
  )
}
