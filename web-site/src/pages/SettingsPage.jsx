import { m } from 'framer-motion'
import { useEffect, useState } from 'react'
import { Button, Icon, Modal, PageHeader } from '../components/ui'
import { getLatestRelease, RELEASES_URL } from '../lib/appRelease'
import { changePassword, deleteAccount, errorMessage, sendConfirmationLink, usesGoogle, useAuth } from '../lib/auth'
import AccountAvatar from '../components/AccountAvatar'
import { achievementsOf } from '../lib/achievements'
import { installSite, useCanInstall } from '../lib/install'
import { dayKey, weekKey } from '../lib/league'
import { pixCode, pixEnabled, PIX } from '../lib/pix'
import { useStore } from '../lib/store'
import { logout, pauseSync, resumeSync } from '../lib/sync'

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
        {pixEnabled() && <SupportCard />}
        <Achievements />
        <AndroidAppCard />
        <InstallSiteCard />
        {user && <ChangePasswordCard />}
        {user && <DeleteAccountCard />}
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

/** Instalar o site como app (computador, iPhone ou Android sem o APK). */
function InstallSiteCard() {
  const canInstall = useCanInstall()
  if (!canInstall) return null
  return (
    <div className="flex flex-wrap items-center justify-between gap-4 rounded-2xl bg-card p-5 shadow">
      <div className="flex items-center gap-4">
        <img src={`${import.meta.env.BASE_URL}icons/icon-192.png`} alt="" className="h-12 w-12 shrink-0 rounded-2xl" />
        <div>
          <div className="font-bold">Instalar o site</div>
          <div className="text-sm text-muted">Abre em janela própria, com ícone, e funciona até sem internet.</div>
        </div>
      </div>
      <Button onClick={installSite}>Instalar</Button>
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
        {release?.url32 && (
          <>
            Celular muito antigo (32 bits)?{' '}
            <a href={release.url32} className="underline hover:text-text">
              Baixe esta versão
            </a>
            .{' '}
          </>
        )}
        <a href={RELEASES_URL} className="underline hover:text-text" target="_blank" rel="noreferrer">
          Todas as versões
        </a>
      </p>
    </div>
  )
}

/** Pix para apoiar o projeto (QR Code e "copia e cola"). */
function SupportCard() {
  const [qr, setQr] = useState(null)
  const [copied, setCopied] = useState('')
  const code = pixCode()

  useEffect(() => {
    import('qrcode').then((QR) => QR.toDataURL(code, { margin: 1, width: 360 })).then(setQr).catch(() => {})
  }, [code])

  const copy = async (text, what) => {
    try {
      await navigator.clipboard.writeText(text)
      setCopied(what)
      setTimeout(() => setCopied(''), 1800)
    } catch {
      setCopied('')
    }
  }

  return (
    <div className="rounded-2xl bg-card p-5 shadow" style={{ borderLeft: '6px solid #32BCAD' }}>
      <div className="flex flex-wrap items-center gap-5">
        {qr && <img src={qr} alt="QR Code do Pix" className="h-36 w-36 rounded-xl bg-white p-1" />}
        <div className="min-w-0 flex-1">
          <div className="font-bold">💚 Apoie o PocketDex</div>
          <p className="mt-1 text-sm text-muted">
            O PocketDex é gratuito e sem anúncios. Se ele te ajuda, uma contribuição por Pix (de qualquer valor) ajuda a manter o projeto.
          </p>
          <p className="mt-2 text-sm">
            Chave: <b className="break-all">{PIX.key}</b>
          </p>
          <div className="mt-3 flex flex-wrap gap-2">
            <Button color="#32BCAD" onClick={() => copy(code, 'code')}>
              {copied === 'code' ? 'Copiado!' : 'Copiar Pix copia e cola'}
            </Button>
            <Button color="#546E7A" onClick={() => copy(PIX.key, 'key')}>
              {copied === 'key' ? 'Copiada!' : 'Copiar chave'}
            </Button>
          </div>
        </div>
      </div>
    </div>
  )
}

/** Medalhas conquistadas no jogo, na Pokédex e nos times. */
function Achievements() {
  const stats = useStore((s) => s.stats)
  const rankedRecord = useStore((s) => s.rankedRecord)
  const favorites = useStore((s) => s.favorites)
  const teams = useStore((s) => s.teams)
  const list = achievementsOf({ stats, rankedRecord, favorites, teams })
  const unlocked = list.filter((a) => a.unlocked).length
  return (
    <div className="rounded-2xl bg-card p-5 shadow">
      <div className="mb-4 flex items-center justify-between gap-4">
        <div>
          <div className="font-bold">Conquistas</div>
          <div className="text-sm text-muted">Jogue, monte times e favorite Pokémon para liberar medalhas.</div>
        </div>
        <span className="rounded-full bg-yellow-400 px-3 py-1 text-sm font-black text-[#3e2723]">
          {unlocked}/{list.length}
        </span>
      </div>
      <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
        {list.map((a) => (
          <div
            key={a.id}
            title={a.text}
            className={`flex items-center gap-3 rounded-xl p-3 ${a.unlocked ? 'bg-yellow-400/15 ring-1 ring-yellow-400/60' : 'bg-surface opacity-50 grayscale'}`}
          >
            <span className="text-2xl">{a.icon}</span>
            <div className="min-w-0">
              <div className="truncate text-sm font-bold">{a.title}</div>
              <div className="text-xs text-muted">{a.text}</div>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}

/** Apaga a conta e todos os dados dela (senha atual, ou link no e-mail para contas Google). */
function DeleteAccountCard() {
  const [open, setOpen] = useState(false)
  const [google, setGoogle] = useState(false)
  const [password, setPassword] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  const openModal = async () => {
    setGoogle(await usesGoogle())
    setPassword('')
    setError('')
    setInfo('')
    setOpen(true)
  }

  const [info, setInfo] = useState('')
  const sendLink = async () => {
    setBusy(true)
    setError('')
    try {
      await sendConfirmationLink('delete')
      setInfo('Mandamos um link para o e-mail da conta. Abra o link (confira também o spam) para confirmar a exclusão.')
    } catch (e) {
      setError(errorMessage(e))
    }
    setBusy(false)
  }

  const run = async () => {
    if (google) return sendLink()
    setBusy(true)
    setError('')
    const stats = useStore.getState().stats ?? {}
    pauseSync()
    try {
      await deleteAccount({
        password,
        weeks: [...(stats.weeks ?? []), weekKey()],
        days: [...(stats.days ?? []), dayKey()],
      })
      setOpen(false)
    } catch (e) {
      resumeSync()
      setError(errorMessage(e))
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="flex flex-wrap items-center justify-between gap-4 rounded-2xl bg-card p-5 shadow">
      <div>
        <div className="font-bold">Excluir conta</div>
        <div className="text-sm text-muted">Apaga para sempre sua conta, seus dados e suas posições nos rankings.</div>
      </div>
      <Button color="#b71c1c" onClick={openModal}>
        Excluir
      </Button>
      <Modal open={open} onClose={() => !busy && setOpen(false)} title="Excluir conta">
        <p>
          Isso apaga <b>para sempre</b> sua conta, favoritos, times, treinos, recordes, conquistas e suas linhas nos rankings. No app e no
          site. Não dá para desfazer.
        </p>
        {google ? (
          <p className="mt-3 text-sm text-muted">Para confirmar, vamos mandar um link para o e-mail da sua conta Google.</p>
        ) : (
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            placeholder="Digite sua senha para confirmar"
            className="mt-4 w-full rounded-xl bg-surface px-4 py-3 outline-none focus:ring-2 focus:ring-red-500"
          />
        )}
        {info && !error && <p className="mt-3 text-sm text-green-400">{info}</p>}
        {error && <p className="mt-3 text-sm text-red-400">{error}</p>}
        <div className="mt-5 flex justify-end gap-3">
          <button type="button" onClick={() => setOpen(false)} disabled={busy} className="cursor-pointer px-4 text-muted">
            {info ? 'Fechar' : 'Cancelar'}
          </button>
          <Button color="#b71c1c" onClick={run} disabled={busy || (!google && !password)}>
            {google ? (busy ? 'Enviando...' : info ? 'Reenviar link' : 'Enviar link de confirmação') : busy ? 'Excluindo...' : 'Excluir para sempre'}
          </Button>
        </div>
      </Modal>
    </div>
  )
}

/** Trocar senha: senha atual (conta com e-mail) ou link no e-mail (conta Google). */
function ChangePasswordCard() {
  const [open, setOpen] = useState(false)
  const [google, setGoogle] = useState(false)
  const [current, setCurrent] = useState('')
  const [password, setPassword] = useState('')
  const [confirm, setConfirm] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [info, setInfo] = useState('')

  const openModal = async () => {
    setGoogle(await usesGoogle())
    setCurrent('')
    setPassword('')
    setConfirm('')
    setError('')
    setInfo('')
    setOpen(true)
  }

  const run = async () => {
    setError('')
    if (!google) {
      if (password.length < 6) return setError('A senha precisa ter pelo menos 6 caracteres.')
      if (password !== confirm) return setError('As senhas não são iguais.')
    }
    setBusy(true)
    try {
      if (google) {
        await sendConfirmationLink('password')
        setInfo('Mandamos um link para o e-mail da conta. Abra o link (confira também o spam) para escolher a senha.')
      } else {
        await changePassword({ current, password })
        setInfo('Senha trocada!')
        setTimeout(() => setOpen(false), 1200)
      }
    } catch (e) {
      setError(errorMessage(e))
    }
    setBusy(false)
  }

  const input = 'mt-3 w-full rounded-xl bg-surface px-4 py-3 outline-none focus:ring-2 focus:ring-sky-400'
  return (
    <div className="flex flex-wrap items-center justify-between gap-4 rounded-2xl bg-card p-5 shadow">
      <div>
        <div className="font-bold">Trocar senha</div>
        <div className="text-sm text-muted">Com a senha atual, ou por um link no e-mail se você entra com Google.</div>
      </div>
      <Button color="#546E7A" onClick={openModal}>
        Trocar
      </Button>
      <Modal open={open} onClose={() => !busy && setOpen(false)} title="Trocar senha">
        {google ? (
          <p className="text-sm text-muted">Você entra com Google. Vamos mandar um link para o seu e-mail; abrindo, você cria ou troca a senha.</p>
        ) : (
          <>
            <input type="password" value={current} onChange={(e) => setCurrent(e.target.value)} autoComplete="current-password" placeholder="Senha atual" className={input} />
            <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} autoComplete="new-password" placeholder="Nova senha" className={input} />
            <input type="password" value={confirm} onChange={(e) => setConfirm(e.target.value)} autoComplete="new-password" placeholder="Confirmar nova senha" className={input} />
          </>
        )}
        {info && !error && <p className="mt-3 text-sm text-green-400">{info}</p>}
        {error && <p className="mt-3 text-sm text-red-400">{error}</p>}
        <div className="mt-5 flex justify-end gap-3">
          <button type="button" onClick={() => setOpen(false)} disabled={busy} className="cursor-pointer px-4 text-muted">
            {info ? 'Fechar' : 'Cancelar'}
          </button>
          <Button color="#2196f3" onClick={run} disabled={busy || (!google && (!current || !password))}>
            {busy ? 'Aguarde...' : google ? (info ? 'Reenviar link' : 'Enviar link') : 'Trocar senha'}
          </Button>
        </div>
      </Modal>
    </div>
  )
}
