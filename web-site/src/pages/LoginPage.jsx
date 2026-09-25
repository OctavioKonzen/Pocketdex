// Tela de login: aparece antes do site para quem não entrou na conta.
// E-mail e senha ou Google, com "Manter conectado". No cadastro a pessoa
// escolhe um nome, que não pode ser igual ao de outra pessoa.

import { AnimatePresence, m } from 'framer-motion'
import { useState } from 'react'
import { SpinningPokeball } from '../components/ui'
import { imageUrl, spriteUrl } from '../lib/data'
import {
  chooseName,
  errorMessage,
  NAME_MAX,
  resetPassword,
  signIn,
  signInWithGoogle,
  signOut,
  signUp,
  useAuth,
  validateName,
} from '../lib/auth'

const HERO = [
  { id: 6, x: '4%', y: '16%', size: 190, delay: 0 },
  { id: 9, x: '58%', y: '8%', size: 170, delay: 0.8 },
  { id: 3, x: '52%', y: '58%', size: 200, delay: 1.6 },
  { id: 25, x: '10%', y: '60%', size: 150, delay: 2.4 },
]

function Hero() {
  return (
    <div className="relative hidden overflow-hidden lg:block" style={{ background: 'linear-gradient(135deg, #e53935 0%, #b71c1c 55%, #4a0d0d 100%)' }}>
      <SpinningPokeball size={760} opacity={0.12} slow className="absolute -right-48 -bottom-48" />
      <SpinningPokeball size={260} opacity={0.1} className="absolute -top-16 -left-16" />
      <div className="relative z-10 flex h-full flex-col p-12">
        <img src={imageUrl('poke_logo.png')} alt="PocketDex" className="h-28 self-start" />
        <div className="relative mt-6 flex-1">
          {HERO.map((p) => (
            <img
              key={p.id}
              src={spriteUrl(`pokemon/other/official-artwork/${p.id}.png`)}
              alt=""
              className="login-float absolute drop-shadow-2xl"
              style={{ left: p.x, top: p.y, width: p.size, animationDelay: `${p.delay}s` }}
            />
          ))}
        </div>
        <h2 className="max-w-md text-4xl leading-tight font-black text-white">Sua Pokédex, seus times e seus treinos em qualquer lugar.</h2>
        <p className="mt-3 max-w-md text-white/80">Entre na sua conta para salvar tudo e acessar do computador ou do app.</p>
      </div>
    </div>
  )
}

function Field({ label, type = 'text', value, onChange, autoComplete, autoFocus, maxLength, hint }) {
  const [show, setShow] = useState(false)
  const isPassword = type === 'password'
  return (
    <label className="block">
      <span className="mb-1.5 block text-sm font-semibold text-muted">{label}</span>
      <span className="flex items-center rounded-2xl bg-bg ring-1 ring-line transition focus-within:ring-2 focus-within:ring-red-500">
        <input
          type={isPassword && show ? 'text' : type}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          autoComplete={autoComplete}
          autoFocus={autoFocus}
          maxLength={maxLength}
          required
          className="w-full bg-transparent px-4 py-3 text-text outline-none"
        />
        {isPassword && (
          <button type="button" onClick={() => setShow(!show)} className="cursor-pointer px-4 text-sm font-semibold text-muted hover:text-text">
            {show ? 'Ocultar' : 'Mostrar'}
          </button>
        )}
      </span>
      {hint && <span className="mt-1 block text-xs text-muted">{hint}</span>}
    </label>
  )
}

function Checkbox({ checked, onChange, children }) {
  return (
    <label className="flex cursor-pointer items-center gap-2 text-sm select-none">
      <input type="checkbox" checked={checked} onChange={(e) => onChange(e.target.checked)} className="h-4 w-4 cursor-pointer accent-red-600" />
      {children}
    </label>
  )
}

function SubmitButton({ busy, children }) {
  return (
    <m.button
      type="submit"
      disabled={busy}
      whileHover={busy ? undefined : { scale: 1.03 }}
      whileTap={busy ? undefined : { scale: 0.97 }}
      className="flex w-full cursor-pointer items-center justify-center gap-2 rounded-2xl bg-red-600 py-3.5 text-lg font-bold text-white shadow-lg shadow-red-900/30 disabled:cursor-default disabled:opacity-60"
    >
      {busy && <SpinningPokeball size={22} opacity={1} style={{ filter: 'none' }} />}
      {children}
    </m.button>
  )
}

function GoogleButton({ onClick, busy }) {
  return (
    <m.button
      type="button"
      onClick={onClick}
      disabled={busy}
      whileHover={busy ? undefined : { scale: 1.03 }}
      whileTap={busy ? undefined : { scale: 0.97 }}
      className="flex w-full cursor-pointer items-center justify-center gap-3 rounded-2xl bg-white py-3.5 font-bold text-gray-800 shadow-md ring-1 ring-black/10 disabled:cursor-default disabled:opacity-60"
    >
      <svg viewBox="0 0 48 48" width="22" height="22" aria-hidden>
        <path fill="#FFC107" d="M43.6 20.5H42V20H24v8h11.3C33.7 32.7 29.2 36 24 36c-6.6 0-12-5.4-12-12s5.4-12 12-12c3.1 0 5.8 1.2 7.9 3.1l5.7-5.7C34 6.1 29.3 4 24 4 12.9 4 4 12.9 4 24s8.9 20 20 20 20-8.9 20-20c0-1.3-.1-2.4-.4-3.5z" />
        <path fill="#FF3D00" d="m6.3 14.7 6.6 4.8C14.7 15.1 19 12 24 12c3.1 0 5.8 1.2 7.9 3.1l5.7-5.7C34 6.1 29.3 4 24 4 16.3 4 9.7 8.3 6.3 14.7z" />
        <path fill="#4CAF50" d="M24 44c5.2 0 9.9-2 13.4-5.2l-6.2-5.2C29.2 35.1 26.7 36 24 36c-5.2 0-9.6-3.3-11.3-7.9l-6.5 5C9.5 39.6 16.2 44 24 44z" />
        <path fill="#1976D2" d="M43.6 20.5H42V20H24v8h11.3c-.8 2.2-2.2 4.2-4.1 5.6l6.2 5.2C37 39.2 44 34 44 24c0-1.3-.1-2.4-.4-3.5z" />
      </svg>
      Entrar com Google
    </m.button>
  )
}

function Message({ error, info }) {
  return (
    <AnimatePresence mode="wait">
      {(error || info) && (
        <m.p
          key={error || info}
          initial={{ opacity: 0, y: -6 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0 }}
          role={error ? 'alert' : 'status'}
          className={`rounded-xl px-4 py-2.5 text-sm font-semibold ${error ? 'bg-red-500/15 text-red-400' : 'bg-green-500/15 text-green-400'}`}
        >
          {error || info}
        </m.p>
      )}
    </AnimatePresence>
  )
}

const TABS = [
  { key: 'login', label: 'Entrar' },
  { key: 'signup', label: 'Criar conta' },
]

function AuthForm() {
  const [mode, setMode] = useState('login') // login | signup | forgot
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [confirm, setConfirm] = useState('')
  const [keep, setKeep] = useState(true)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [info, setInfo] = useState('')

  const switchMode = (next) => {
    setMode(next)
    setError('')
    setInfo('')
  }

  const run = async (action) => {
    setBusy(true)
    setError('')
    setInfo('')
    try {
      await action()
    } catch (e) {
      setError(errorMessage(e))
    } finally {
      setBusy(false)
    }
  }

  const onSubmit = (e) => {
    e.preventDefault()
    if (mode === 'forgot') {
      run(async () => {
        await resetPassword(email)
        setInfo('Enviamos um e-mail com o link para criar uma nova senha.')
      })
      return
    }
    if (mode === 'signup') {
      const nameError = validateName(name)
      if (nameError) return setError(nameError)
      if (password !== confirm) return setError('As senhas não são iguais.')
      run(() => signUp({ name, email, password, keep }))
      return
    }
    run(() => signIn({ email, password, keep }))
  }

  return (
    <div className="w-full max-w-md">
      <img src={imageUrl('poke_logo.png')} alt="PocketDex" className="mx-auto mb-8 h-24 lg:hidden" />
      <h1 className="text-3xl font-black">{mode === 'forgot' ? 'Recuperar senha' : mode === 'signup' ? 'Crie sua conta' : 'Bem-vindo de volta!'}</h1>
      <p className="mt-1 mb-6 text-muted">
        {mode === 'forgot' ? 'Digite o e-mail da sua conta para receber o link.' : mode === 'signup' ? 'Leva menos de um minuto.' : 'Entre para continuar na sua Pokédex.'}
      </p>

      {mode !== 'forgot' && (
        <div className="relative mb-6 grid grid-cols-2 rounded-2xl bg-bg p-1 ring-1 ring-line">
          {TABS.map((t) => (
            <button key={t.key} type="button" onClick={() => switchMode(t.key)} className="relative z-10 cursor-pointer py-2.5 font-bold" style={{ color: mode === t.key ? '#fff' : 'var(--muted)' }}>
              {mode === t.key && <m.span layoutId="login-tab" className="absolute inset-0 -z-10 rounded-xl bg-red-600 shadow" transition={{ type: 'spring', stiffness: 500, damping: 38 }} />}
              {t.label}
            </button>
          ))}
        </div>
      )}

      <form onSubmit={onSubmit} className="space-y-4" noValidate>
        <AnimatePresence initial={false}>
          {mode === 'signup' && (
            <m.div key="name" initial={{ height: 0, opacity: 0 }} animate={{ height: 'auto', opacity: 1 }} exit={{ height: 0, opacity: 0 }} className="overflow-hidden">
              <Field label="Seu nome" value={name} onChange={setName} autoComplete="nickname" maxLength={NAME_MAX} hint="É assim que os outros vão te ver. Cada nome só pode ser usado por uma pessoa." />
            </m.div>
          )}
        </AnimatePresence>
        <Field label="E-mail" type="email" value={email} onChange={setEmail} autoComplete="email" />
        {mode !== 'forgot' && (
          <Field label="Senha" type="password" value={password} onChange={setPassword} autoComplete={mode === 'signup' ? 'new-password' : 'current-password'} hint={mode === 'signup' ? 'Pelo menos 6 caracteres.' : null} />
        )}
        <AnimatePresence initial={false}>
          {mode === 'signup' && (
            <m.div key="confirm" initial={{ height: 0, opacity: 0 }} animate={{ height: 'auto', opacity: 1 }} exit={{ height: 0, opacity: 0 }} className="overflow-hidden">
              <Field label="Confirmar senha" type="password" value={confirm} onChange={setConfirm} autoComplete="new-password" />
            </m.div>
          )}
        </AnimatePresence>

        {mode !== 'forgot' && (
          <div className="flex items-center justify-between gap-3">
            <Checkbox checked={keep} onChange={setKeep}>
              Manter conectado
            </Checkbox>
            {mode === 'login' && (
              <button type="button" onClick={() => switchMode('forgot')} className="cursor-pointer text-sm font-semibold text-red-500 hover:underline">
                Esqueci minha senha
              </button>
            )}
          </div>
        )}

        <Message error={error} info={info} />

        <SubmitButton busy={busy}>{mode === 'forgot' ? 'Enviar link' : mode === 'signup' ? 'Criar conta' : 'Entrar'}</SubmitButton>
      </form>

      {mode === 'forgot' ? (
        <button type="button" onClick={() => switchMode('login')} className="mt-5 w-full cursor-pointer text-center font-semibold text-muted hover:text-text">
          ← Voltar para o login
        </button>
      ) : (
        <>
          <div className="my-6 flex items-center gap-3 text-sm text-muted">
            <span className="h-px flex-1 bg-line" />
            ou
            <span className="h-px flex-1 bg-line" />
          </div>
          <GoogleButton busy={busy} onClick={() => run(() => signInWithGoogle({ keep }))} />
        </>
      )}
    </div>
  )
}

/** Primeiro login com Google: falta escolher o nome. */
function ChooseNameForm() {
  const user = useAuth((s) => s.user)
  const [name, setName] = useState(user?.name ?? '')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  const onSubmit = async (e) => {
    e.preventDefault()
    const nameError = validateName(name)
    if (nameError) return setError(nameError)
    setBusy(true)
    setError('')
    try {
      await chooseName(name)
    } catch (err) {
      setError(errorMessage(err))
      setBusy(false)
    }
  }

  return (
    <div className="w-full max-w-md">
      <img src={imageUrl('poke_logo.png')} alt="PocketDex" className="mx-auto mb-8 h-24 lg:hidden" />
      <h1 className="text-3xl font-black">Como quer ser chamado?</h1>
      <p className="mt-1 mb-6 text-muted">
        Entrou como <b className="text-text">{user?.email}</b>. Escolha o seu nome no PocketDex.
      </p>
      <form onSubmit={onSubmit} className="space-y-4" noValidate>
        <Field label="Seu nome" value={name} onChange={setName} autoComplete="nickname" autoFocus maxLength={NAME_MAX} hint="Cada nome só pode ser usado por uma pessoa." />
        <Message error={error} />
        <SubmitButton busy={busy}>Continuar</SubmitButton>
      </form>
      <button type="button" onClick={() => signOut()} className="mt-5 w-full cursor-pointer text-center font-semibold text-muted hover:text-text">
        Usar outra conta
      </button>
    </div>
  )
}

export default function LoginPage() {
  const status = useAuth((s) => s.status)
  return (
    <div className="grid min-h-screen bg-surface lg:grid-cols-[1.1fr_1fr]">
      <Hero />
      <div className="flex items-center justify-center px-5 py-10 sm:px-10">
        <m.div initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.4 }} className="flex w-full justify-center">
          {status === 'needsName' ? <ChooseNameForm /> : <AuthForm />}
        </m.div>
      </div>
    </div>
  )
}
