// Página aberta pelo link de confirmação mandado ao e-mail (contas Google):
// confirma a conta e continua o que a pessoa pediu — criar a conta (escolher
// o nome), criar/trocar a senha ou excluir a conta. Funciona também quando o
// link foi pedido no app: a confirmação fica gravada e o app segue sozinho.

import { useEffect, useState } from 'react'
import { completeConfirmation, confirmationEmail, deleteAccount, errorMessage, setPasswordAfterLink } from '../lib/auth'
import { imageUrl } from '../lib/data'
import { dayKey, weekKey } from '../lib/league'
import { useStore } from '../lib/store'
import { pauseSync, resumeSync } from '../lib/sync'
import { Button } from './ui'

const TITLES = { signup: 'Confirmar conta', password: 'Criar ou trocar senha', delete: 'Excluir conta' }
const input = 'mt-3 w-full rounded-xl bg-surface px-4 py-3 outline-none focus:ring-2 focus:ring-sky-400'

export default function EmailLinkPage({ purpose, onDone }) {
  const [email, setEmail] = useState('')
  const [askEmail, setAskEmail] = useState(false)
  const [confirmed, setConfirmed] = useState(false)
  const [busy, setBusy] = useState(true)
  const [error, setError] = useState('')
  const [info, setInfo] = useState('')
  const [password, setPassword] = useState('')
  const [confirm, setConfirm] = useState('')

  const confirmWith = async (address) => {
    setBusy(true)
    setError('')
    try {
      await completeConfirmation(purpose, address)
      setConfirmed(true)
      if (purpose === 'signup') setInfo('E-mail confirmado! Agora é só escolher o seu nome.')
    } catch (e) {
      setError(errorMessage(e))
    }
    setBusy(false)
  }

  // Abriu o link no mesmo navegador: já sabe o e-mail e confirma sozinho.
  useEffect(() => {
    confirmationEmail().then((known) => {
      if (known) confirmWith(known)
      else {
        setAskEmail(true)
        setBusy(false)
      }
    })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const savePassword = async () => {
    if (password.length < 6) return setError('A senha precisa ter pelo menos 6 caracteres.')
    if (password !== confirm) return setError('As senhas não são iguais.')
    setBusy(true)
    setError('')
    try {
      await setPasswordAfterLink(password)
      setInfo('Senha salva! Agora você também pode entrar com o e-mail e essa senha.')
    } catch (e) {
      setError(errorMessage(e))
    }
    setBusy(false)
  }

  const remove = async () => {
    setBusy(true)
    setError('')
    const stats = useStore.getState().stats ?? {}
    pauseSync()
    try {
      await deleteAccount({ confirmedByLink: true, weeks: [...(stats.weeks ?? []), weekKey()], days: [...(stats.days ?? []), dayKey()] })
      setInfo('Sua conta foi excluída. Nenhum dado seu ficou guardado.')
      setConfirmed(false)
    } catch (e) {
      resumeSync()
      setError(errorMessage(e))
    }
    setBusy(false)
  }

  const done = info && (purpose !== 'delete' || !confirmed) && (purpose !== 'password' || info.startsWith('Senha'))

  return (
    <div className="grid min-h-screen place-items-center bg-surface px-5 py-10">
      <div className="w-full max-w-md rounded-3xl bg-card p-6 shadow-2xl">
        <img src={imageUrl('poke_logo.png')} alt="PocketDex" className="mx-auto mb-5 h-16" />
        <h1 className="text-2xl font-black">{TITLES[purpose]}</h1>

        {askEmail && !confirmed && (
          <>
            <p className="mt-2 text-muted">Para confirmar, digite o e-mail da conta (o mesmo que recebeu o link).</p>
            <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} autoComplete="email" placeholder="E-mail" className={input} />
          </>
        )}
        {busy && !askEmail && !confirmed && <p className="mt-3 text-muted">Confirmando…</p>}

        {confirmed && purpose === 'password' && !info && (
          <>
            <p className="mt-2 text-muted">E-mail confirmado. Escolha a senha nova.</p>
            <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} autoComplete="new-password" placeholder="Nova senha" className={input} />
            <input type="password" value={confirm} onChange={(e) => setConfirm(e.target.value)} autoComplete="new-password" placeholder="Confirmar nova senha" className={input} />
          </>
        )}
        {confirmed && purpose === 'delete' && (
          <p className="mt-2">
            E-mail confirmado. Isso apaga <b>para sempre</b> sua conta, favoritos, times, treinos, recordes, conquistas e suas linhas nos rankings. No app e
            no site. Não dá para desfazer.
          </p>
        )}

        {info && <p className="mt-3 text-sm text-green-400">{info}</p>}
        {error && <p className="mt-3 text-sm text-red-400">{error}</p>}

        <div className="mt-5 flex flex-wrap justify-end gap-3">
          {!done && (
            <button type="button" onClick={onDone} disabled={busy} className="cursor-pointer px-4 text-muted">
              Cancelar
            </button>
          )}
          {askEmail && !confirmed && (
            <Button color="#2196f3" onClick={() => confirmWith(email)} disabled={busy || !email.trim()}>
              Confirmar
            </Button>
          )}
          {confirmed && purpose === 'password' && !info && (
            <Button color="#2196f3" onClick={savePassword} disabled={busy}>
              Salvar senha
            </Button>
          )}
          {confirmed && purpose === 'delete' && (
            <Button color="#b71c1c" onClick={remove} disabled={busy}>
              {busy ? 'Excluindo...' : 'Excluir para sempre'}
            </Button>
          )}
          {done && (
            <Button color="#FF5252" onClick={onDone}>
              Continuar
            </Button>
          )}
        </div>
      </div>
    </div>
  )
}
