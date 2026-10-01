// Teste da conta Google como no app (lib/services/auth_service.dart), nos
// emuladores do Firebase, com as regras de verdade (firestore.rules):
//   1. entra com Google e escolhe o nome (chooseName → _claimName);
//   2. usa a conta: favoritos e times (no perfil, como o app sincroniza),
//      ranking geral, da semana e do dia, e um time público;
//   3. exclui a conta pelo app (deleteAccount: apaga tudo e o login) e confere
//      que nada disso sobrou;
//   4. entra de novo com a MESMA conta Google: tem que pedir o nome de novo
//      (conta nova, sem nada da antiga) e aceitar o mesmo nome.
// Rode com: npm test (junto com o teste do site).

import assert from 'node:assert/strict'
import { initializeApp } from '../web-site/node_modules/firebase/app/dist/index.mjs'
import * as fbAuth from '../web-site/node_modules/firebase/auth/dist/index.mjs'
import * as fs from '../web-site/node_modules/firebase/firestore/dist/index.mjs'

const app = initializeApp({ apiKey: 'fake-api-key', projectId: 'pocketdex-ffb4d', authDomain: 'localhost' }, 'app-google')
const auth = fbAuth.getAuth(app)
fbAuth.connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true })
const db = fs.getFirestore(app)
fs.connectFirestoreEmulator(db, '127.0.0.1', 8085)

// Mesma conta Google nas duas vezes (o emulador aceita um "token do Google" falso).
const sub = `app${Date.now()}`
const email = `${sub}@gmail.com`
const name = `Gapp${Date.now() % 100000}`
const google = () => fbAuth.signInWithCredential(auth, fbAuth.GoogleAuthProvider.credential(JSON.stringify({ sub, email, email_verified: true })))

// Igual a AuthService.nameKey (sem acento, espaços juntos, minúsculas).
const nameKey = (n) => n.trim().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/\s+/g, ' ').toLowerCase()

// Igual a AuthService._claimName.
async function claimName(u, n) {
  const nameRef = fs.doc(db, 'usernames', nameKey(n))
  const userRef = fs.doc(db, 'users', u.uid)
  await fs.runTransaction(db, async (tx) => {
    await tx.get(nameRef)
    tx.set(nameRef, { uid: u.uid, name: n })
    tx.set(userRef, { name: n, nameKey: nameKey(n), email: u.email ?? '', createdAt: fs.serverTimestamp() }, { merge: true })
  })
}

// Status do app ao entrar: com nome no perfil, entra; sem, pede o nome.
async function status(u) {
  const profile = await fs.getDoc(fs.doc(db, 'users', u.uid))
  return profile.data()?.name ? 'signedIn' : 'needsName'
}

// Semana e dia dos rankings ("AAAA-MM-DD"), como League.weekKey/dayKey.
const day = new Date().toISOString().slice(0, 10)

// Igual a AuthService.deleteAccount (os pedaços que esta conta usou).
async function deleteAccount(u) {
  await fbAuth.reauthenticateWithCredential(u, fbAuth.GoogleAuthProvider.credential(JSON.stringify({ sub, email, email_verified: true })))
  const profile = await fs.getDoc(fs.doc(db, 'users', u.uid))
  const keys = new Set([profile.data()?.nameKey, profile.data()?.name && nameKey(profile.data().name)].filter(Boolean))
  const teams = await fs.getDocs(fs.collection(db, 'publicTeams'))
  for (const team of teams.docs) if (team.data().ownerUid === u.uid) await fs.deleteDoc(team.ref)
  await Promise.all([...keys].map((k) => fs.deleteDoc(fs.doc(db, 'usernames', k))))
  await fs.deleteDoc(fs.doc(db, 'ranking', u.uid))
  await fs.deleteDoc(fs.doc(db, 'weekly', day, 'scores', u.uid))
  await fs.deleteDoc(fs.doc(db, 'daily', day, 'scores', u.uid))
  await fs.deleteDoc(fs.doc(db, 'confirmations', u.uid)).catch(() => {})
  await fs.deleteDoc(fs.doc(db, 'users', u.uid))
  await u.delete()
}

// Times públicos de um dono (lidos como dono do banco, sem regras).
async function ownedTeams(uid) {
  const res = await fetch('http://127.0.0.1:8085/v1/projects/pocketdex-ffb4d/databases/(default)/documents:runQuery', {
    method: 'POST',
    headers: { Authorization: 'Bearer owner', 'Content-Type': 'application/json' },
    body: JSON.stringify({ structuredQuery: { from: [{ collectionId: 'publicTeams' }], where: { fieldFilter: { field: { fieldPath: 'ownerUid' }, op: 'EQUAL', value: { stringValue: uid } } } } }),
  })
  return (await res.json()).filter((r) => r.document)
}

async function emulatorDocs(path) {
  const res = await fetch(`http://127.0.0.1:8085/v1/projects/pocketdex-ffb4d/databases/(default)/documents/${path}`, {
    headers: { Authorization: 'Bearer owner' },
  })
  return ((await res.json()).documents ?? []).map((d) => d.name.split('/').slice(-1)[0])
}

let step = ''
try {
  step = '1. entrar com Google e escolher o nome'
  const first = (await google()).user
  assert.equal(await status(first), 'needsName', `${step}: conta nova devia pedir o nome`)
  await claimName(first, name)
  assert.equal(await status(first), 'signedIn', step)

  step = '2. usar a conta (favoritos, times, rankings e time público)'
  // Favoritos e times ficam no perfil (lib/services/account_sync.dart).
  await fs.setDoc(fs.doc(db, 'users', first.uid), { data: { favorites: [6, 25], teams: [{ id: 't1', name: 'Time', pokemon: [6, 25, 0, 0, 0, 0] }] } }, { merge: true })
  await fs.setDoc(fs.doc(db, 'ranking', first.uid), { name, score: 12 })
  await fs.setDoc(fs.doc(db, 'weekly', day, 'scores', first.uid), { name, score: 12 })
  await fs.setDoc(fs.doc(db, 'daily', day, 'scores', first.uid), { name, score: 12, correct: 3 })
  await fs.addDoc(fs.collection(db, 'publicTeams'), {
    ownerUid: first.uid, ownerName: name, ownerKey: nameKey(name), name: 'Time', color: null, pokemon: [6, 25, 0, 0, 0, 0], ratingSum: 0, ratingCount: 0, reportCount: 0,
  })
  assert.equal((await ownedTeams(first.uid)).length, 1, `${step}: o time público não foi criado`)

  step = '3. excluir a conta pelo app'
  const oldUid = first.uid
  await deleteAccount(first)
  assert.equal(auth.currentUser, null, `${step}: continuou logado`)
  assert.ok(!(await emulatorDocs('users')).includes(oldUid), `${step}: sobrou o perfil`)
  assert.ok(!(await emulatorDocs('usernames')).includes(nameKey(name)), `${step}: o nome ficou reservado`)
  assert.ok(!(await emulatorDocs('ranking')).includes(oldUid), `${step}: sobrou o ranking`)
  assert.ok(!(await emulatorDocs(`weekly/${day}/scores`)).includes(oldUid), `${step}: sobrou o ranking da semana`)
  assert.ok(!(await emulatorDocs(`daily/${day}/scores`)).includes(oldUid), `${step}: sobrou o desafio do dia`)
  assert.equal((await ownedTeams(oldUid)).length, 0, `${step}: sobrou o time público`)

  step = '4. entrar de novo com a mesma conta Google'
  const again = (await google()).user
  assert.notEqual(again.uid, oldUid, `${step}: voltou a conta apagada`)
  assert.equal(await status(again), 'needsName', `${step}: devia pedir o nome (conta nova)`)
  await claimName(again, name)
  assert.equal(await status(again), 'signedIn', `${step}: não entrou depois de escolher o nome`)
  assert.equal((await fs.getDoc(fs.doc(db, 'usernames', nameKey(name)))).data()?.uid, again.uid, `${step}: o nome não ficou com a conta nova`)
  assert.equal((await fs.getDoc(fs.doc(db, 'ranking', again.uid))).exists(), false, `${step}: a conta nova herdou o ranking`)
  const fresh = (await fs.getDoc(fs.doc(db, 'users', again.uid))).data()
  assert.equal(fresh.data, undefined, `${step}: a conta nova herdou favoritos e times`)

  console.log('TUDO CERTO (app, Google): entrou, escolheu o nome, salvou favoritos, times e rankings, excluiu a conta (nada sobrou) e criou de novo com a mesma conta Google e o mesmo nome, vazia.')
} catch (error) {
  console.error(`FALHOU em "${step}":`, error.message)
  process.exitCode = 1
} finally {
  await fbAuth.signOut(auth).catch(() => {})
  await fs.terminate(db).catch(() => {})
}
