// Servidor do PocketDex (Firebase Cloud Functions): código de 6 números por
// e-mail para criar conta, trocar/recuperar senha e apagar conta. O site e o
// app chamam estas funções (web-site/src/lib/auth.js, lib/services/auth_service.dart).
//
//   sendCode({purpose, email?})          → manda o código (10 min, 5 tentativas)
//   signUpWithCode({email, password, code}) → cria a conta com e-mail confirmado
//   confirmSignup({code})                → conta Google nova: libera escolher o nome
//   resetPassword({email, code, password}) → troca a senha
//   deleteAccount({code})                → apaga a conta e TUDO dela
//
// Os códigos ficam em emailCodes/ (só com a versão cifrada) e quem confirmou o
// cadastro em verifiedSignups/ — nenhum dos dois pode ser lido pelo site/app.
//
// E-mail: SMTP (ex.: Gmail com senha de app). Variáveis em functions/.env:
//   SMTP_USER, SMTP_PASS, SMTP_HOST (padrão smtp.gmail.com), SMTP_PORT (465)
// No emulador os e-mails não são enviados: ficam em emulatorOutbox/{e-mail}.

import { createHash, randomInt } from 'node:crypto'
import { initializeApp } from 'firebase-admin/app'
import { getAuth } from 'firebase-admin/auth'
import { FieldValue, getFirestore } from 'firebase-admin/firestore'
import { setGlobalOptions } from 'firebase-functions/v2'
import { HttpsError, onCall } from 'firebase-functions/v2/https'
import nodemailer from 'nodemailer'

initializeApp()
setGlobalOptions({ region: 'southamerica-east1', maxInstances: 5 })
const db = getFirestore()
const auth = getAuth()
const emulator = process.env.FUNCTIONS_EMULATOR === 'true'

const CODE_MINUTES = 10
const MAX_ATTEMPTS = 5
const RESEND_SECONDS = emulator ? 2 : 60 // no emulador (testes) a espera é curta
const MAX_PER_HOUR = 5
const PURPOSES = { signup: 'criar sua conta', reset: 'trocar sua senha', delete: 'apagar sua conta' }

const sha = (text) => createHash('sha256').update(text).digest('hex')
const cleanEmail = (email) => String(email ?? '').trim().toLowerCase()
const validEmail = (email) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) && email.length <= 254
const codeRef = (purpose, email) => db.collection('emailCodes').doc(sha(`${purpose}:${email}`))

async function findUser(email) {
  try {
    return await auth.getUserByEmail(email)
  } catch {
    return null
  }
}

// ------------------------------------------------------------------ e-mail

let transport = null
async function sendMail(to, subject, code, action) {
  if (emulator) {
    await db.collection('emulatorOutbox').doc(to).set({ code, subject, at: Date.now() })
    return
  }
  if (!process.env.SMTP_USER || !process.env.SMTP_PASS) throw new HttpsError('failed-precondition', 'O envio de e-mails não está configurado.')
  transport ??= nodemailer.createTransport({
    host: process.env.SMTP_HOST || 'smtp.gmail.com',
    port: Number(process.env.SMTP_PORT || 465),
    secure: Number(process.env.SMTP_PORT || 465) === 465,
    auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
  })
  const text = `Seu código do PocketDex para ${action} é ${code}.\n\nEle vale por ${CODE_MINUTES} minutos. Se não foi você, é só ignorar este e-mail.`
  const html = `<div style="font-family:Arial,sans-serif;max-width:420px;margin:auto;padding:24px;border-radius:16px;background:#1e1e2e;color:#fff">
  <h2 style="margin:0 0 8px;color:#ff5252">PocketDex</h2>
  <p>Seu código para <b>${action}</b>:</p>
  <p style="font-size:34px;letter-spacing:8px;font-weight:bold;text-align:center;background:#2b2b3d;border-radius:12px;padding:14px">${code}</p>
  <p style="color:#bbb;font-size:13px">Ele vale por ${CODE_MINUTES} minutos. Se não foi você, é só ignorar este e-mail.</p>
</div>`
  await transport.sendMail({ from: `PocketDex <${process.env.SMTP_USER}>`, to, subject, text, html })
}

// ------------------------------------------------------------------ códigos

/** Cria e manda um código novo (com limite de envios). */
async function issueCode(purpose, email) {
  const ref = codeRef(purpose, email)
  const now = Date.now()
  const code = String(randomInt(0, 1_000_000)).padStart(6, '0')
  await db.runTransaction(async (tx) => {
    const old = (await tx.get(ref)).data()
    const recent = (old?.sends ?? []).filter((t) => now - t < 3600_000)
    if (recent.length && now - recent[recent.length - 1] < RESEND_SECONDS * 1000) {
      throw new HttpsError('resource-exhausted', 'Espere um minuto para pedir outro código.')
    }
    if (recent.length >= MAX_PER_HOUR) throw new HttpsError('resource-exhausted', 'Muitos códigos pedidos. Tente de novo mais tarde.')
    tx.set(ref, { hash: sha(`${code}:${ref.id}`), expires: now + CODE_MINUTES * 60_000, attempts: 0, sends: [...recent, now] })
  })
  await sendMail(email, `Seu código do PocketDex: ${code}`, code, PURPOSES[purpose])
}

/** Confere o código; se certo, ele não vale mais. */
async function checkCode(purpose, email, code) {
  const ref = codeRef(purpose, email)
  const ok = await db.runTransaction(async (tx) => {
    const data = (await tx.get(ref)).data()
    if (!data?.hash || Date.now() > data.expires) throw new HttpsError('deadline-exceeded', 'O código expirou. Peça outro.')
    if (data.attempts >= MAX_ATTEMPTS) throw new HttpsError('resource-exhausted', 'Muitas tentativas erradas. Peça outro código.')
    const right = sha(`${String(code ?? '').trim()}:${ref.id}`) === data.hash
    tx.update(ref, right ? { hash: FieldValue.delete(), expires: 0 } : { attempts: data.attempts + 1 })
    return right
  })
  if (!ok) throw new HttpsError('invalid-argument', 'Código errado. Confira no seu e-mail.')
}

// ------------------------------------------------------------------ funções

export const sendCode = onCall(async (req) => {
  const purpose = req.data?.purpose
  if (!PURPOSES[purpose]) throw new HttpsError('invalid-argument', 'Pedido inválido.')
  // Logado: o código vai sempre para o e-mail da própria conta.
  const email = cleanEmail(req.auth?.token.email ?? req.data?.email)
  if (!validEmail(email)) throw new HttpsError('invalid-argument', 'E-mail inválido.')
  if (purpose === 'delete' && !req.auth) throw new HttpsError('unauthenticated', 'Entre na conta para apagá-la.')
  if (purpose === 'signup' && !req.auth && (await findUser(email))) {
    throw new HttpsError('already-exists', 'Já existe uma conta com esse e-mail.')
  }
  // Recuperar senha de um e-mail sem conta: responde igual, sem mandar nada
  // (assim ninguém descobre quais e-mails têm conta).
  if (purpose === 'reset' && !(await findUser(email))) return { sent: true }
  await issueCode(purpose, email)
  return { sent: true }
})

export const signUpWithCode = onCall(async (req) => {
  const email = cleanEmail(req.data?.email)
  const password = String(req.data?.password ?? '')
  if (!validEmail(email)) throw new HttpsError('invalid-argument', 'E-mail inválido.')
  if (password.length < 6) throw new HttpsError('invalid-argument', 'A senha precisa ter pelo menos 6 caracteres.')
  await checkCode('signup', email, req.data?.code)
  let user
  try {
    user = await auth.createUser({ email, password, emailVerified: true })
  } catch (e) {
    if (e.code === 'auth/email-already-exists') throw new HttpsError('already-exists', 'Já existe uma conta com esse e-mail.')
    throw e
  }
  await db.collection('verifiedSignups').doc(user.uid).set({ at: FieldValue.serverTimestamp() })
  return { uid: user.uid }
})

export const confirmSignup = onCall(async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Entre na conta primeiro.')
  const email = cleanEmail(req.auth.token.email)
  await checkCode('signup', email, req.data?.code)
  await db.collection('verifiedSignups').doc(req.auth.uid).set({ at: FieldValue.serverTimestamp() })
  return { ok: true }
})

export const resetPassword = onCall(async (req) => {
  const email = cleanEmail(req.auth?.token.email ?? req.data?.email)
  const password = String(req.data?.password ?? '')
  if (password.length < 6) throw new HttpsError('invalid-argument', 'A senha precisa ter pelo menos 6 caracteres.')
  await checkCode('reset', email, req.data?.code)
  const user = await findUser(email)
  if (!user) throw new HttpsError('not-found', 'Não existe conta com esse e-mail.')
  await auth.updateUser(user.uid, { password })
  // Sai de todos os aparelhos: quem tinha a senha antiga precisa entrar de novo.
  await auth.revokeRefreshTokens(user.uid)
  return { ok: true }
})

export const deleteAccount = onCall({ timeoutSeconds: 300 }, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Entre na conta para apagá-la.')
  await checkCode('delete', cleanEmail(req.auth.token.email), req.data?.code)
  await purgeAccount(req.auth.uid)
  return { ok: true }
})

// ------------------------------------------------------------------ apagar tudo

/** Apaga a conta e tudo dela, sem deixar nenhum vestígio. */
async function purgeAccount(uid) {
  const profile = (await db.collection('users').doc(uid).get()).data()

  // Nomes reservados pela pessoa.
  for (const d of (await db.collection('usernames').where('uid', '==', uid).get()).docs) await d.ref.delete()
  if (profile?.nameKey) await db.collection('usernames').doc(profile.nameKey).delete().catch(() => {})

  // Rankings: geral, todas as semanas e todos os dias.
  await db.collection('ranking').doc(uid).delete()
  for (const board of ['weekly', 'daily']) {
    for (const period of await db.collection(board).listDocuments()) await period.collection('scores').doc(uid).delete()
  }

  // Times: os dela somem inteiros; nos dos outros, o voto e a denúncia dela
  // saem e a nota e a contagem voltam.
  for (const team of (await db.collection('publicTeams').get()).docs) {
    if (team.data().ownerUid === uid) {
      await db.recursiveDelete(team.ref)
      continue
    }
    await db.runTransaction(async (tx) => {
      const vote = await tx.get(team.ref.collection('ratings').doc(uid))
      const report = await tx.get(team.ref.collection('reports').doc(uid))
      const changes = {}
      if (vote.exists) {
        changes.ratingSum = FieldValue.increment(-(vote.data().stars ?? 0))
        changes.ratingCount = FieldValue.increment(-1)
        tx.delete(vote.ref)
      }
      if (report.exists) {
        changes.reportCount = FieldValue.increment(-1)
        tx.delete(report.ref)
      }
      if (Object.keys(changes).length) tx.update(team.ref, changes)
    })
  }

  await db.collection('verifiedSignups').doc(uid).delete()
  await db.recursiveDelete(db.collection('users').doc(uid))
  const email = cleanEmail((await auth.getUser(uid).catch(() => null))?.email)
  if (email) for (const p of Object.keys(PURPOSES)) await codeRef(p, email).delete()
  await auth.deleteUser(uid).catch((e) => {
    if (e.code !== 'auth/user-not-found') throw e
  })
}
