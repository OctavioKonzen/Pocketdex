// Testa as regras do Firestore (firestore.rules) no emulador do Firebase.
// Rodar: cd firestore-tests && npm ci && npm test
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing'
import { readFileSync } from 'node:fs'
import { doc, setDoc, getDoc, getDocs, collection, deleteDoc, writeBatch, serverTimestamp } from 'firebase/firestore'

const env = await initializeTestEnvironment({
  projectId: 'demo-pocketdex',
  firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8085 },
})
let fails = 0
const check = async (label, p, ok) => {
  try { await (ok ? assertSucceeds(p) : assertFails(p)); console.log('OK  ', label) }
  catch (e) { fails++; console.log('FAIL', label, e.message.slice(0, 200)) }
}
const A = env.authenticatedContext('alice').firestore()
const B = env.authenticatedContext('bob').firestore()
const anon = env.unauthenticatedContext().firestore()

const claim = (db, uid, name, key) => {
  const b = writeBatch(db)
  b.set(doc(db, 'usernames', key), { uid, name })
  b.set(doc(db, 'users', uid), { name, nameKey: key, email: 'x@y.z', createdAt: serverTimestamp() }, { merge: true })
  return b.commit()
}

await check('cadastro com nome', claim(A, 'alice', 'Ash Ketchum', 'ash ketchum'), true)
await check('cadastro com acento', claim(B, 'bob', 'João', 'joao'), true)
await check('outro pega nome usado', claim(B, 'bob', 'ASH ketchum', 'ash ketchum'), false)
await check('chave falsa p/ nome de outro', claim(B, 'bob', 'Ash Ketchum', 'fake'), false)
await check('trocar nome direto no perfil', setDoc(doc(B, 'users', 'bob'), { name: 'Ash Ketchum' }, { merge: true }), false)
await check('trocar nome usando chave de outro', setDoc(doc(B, 'users', 'bob'), { name: 'Ash Ketchum', nameKey: 'ash ketchum' }, { merge: true }), false)
await check('salvar dados (sem mudar nome)', setDoc(doc(B, 'users', 'bob'), { data: { favorites: [1] }, updatedAt: serverTimestamp() }, { merge: true }), true)
// perfil antigo sem nameKey
await env.withSecurityRulesDisabled(async (ctx) => setDoc(doc(ctx.firestore(), 'users', 'old'), { name: 'Velho', email: '' }))
const O = env.authenticatedContext('old').firestore()
await check('perfil antigo salva dados', setDoc(doc(O, 'users', 'old'), { data: { teams: [] } }, { merge: true }), true)
await check('ler perfil de outro', getDoc(doc(B, 'users', 'alice')), false)

await check('ranking com nome certo + avatar', setDoc(doc(A, 'ranking', 'alice'), { name: 'Ash Ketchum', score: 50, avatar: 25, updatedAt: serverTimestamp() }), true)
await check('ranking com nome de outro', setDoc(doc(B, 'ranking', 'bob'), { name: 'Ash Ketchum', score: 50 }), false)
await check('ranking na linha de outro', setDoc(doc(B, 'ranking', 'alice'), { name: 'João', score: 60 }), false)
await check('ler ranking logado', getDocs(collection(B, 'ranking')), true)
await check('ler ranking sem login', getDocs(collection(anon, 'ranking')), false)

await check('semana cria', setDoc(doc(A, 'weekly', '2026-09-21', 'scores', 'alice'), { name: 'Ash Ketchum', score: 30, avatar: null }), true)
await check('semana sobe', setDoc(doc(A, 'weekly', '2026-09-21', 'scores', 'alice'), { name: 'Ash Ketchum', score: 40, avatar: null }), true)
await check('semana desce', setDoc(doc(A, 'weekly', '2026-09-21', 'scores', 'alice'), { name: 'Ash Ketchum', score: 10, avatar: null }), false)

const daily = { name: 'Ash Ketchum', score: 4357, correct: 4, seconds: 31, avatar: 25, updatedAt: serverTimestamp() }
await check('desafio cria', setDoc(doc(A, 'daily', '2026-09-25', 'scores', 'alice'), daily), true)
await check('desafio 2a vez', setDoc(doc(A, 'daily', '2026-09-25', 'scores', 'alice'), { ...daily, score: 9000 }), false)
await check('desafio pontos demais', setDoc(doc(B, 'daily', '2026-09-25', 'scores', 'bob'), { ...daily, name: 'João', score: 20000 }), false)

await check('conferir 1 nome sem login', getDoc(doc(anon, 'usernames', 'ash ketchum')), true)
await check('listar nomes', getDocs(collection(anon, 'usernames')), false)

// excluir conta
await check('apaga ranking', deleteDoc(doc(A, 'ranking', 'alice')), true)
await check('apaga semana', deleteDoc(doc(A, 'weekly', '2026-09-21', 'scores', 'alice')), true)
await check('apaga desafio', deleteDoc(doc(A, 'daily', '2026-09-25', 'scores', 'alice')), true)
await check('apaga nome', deleteDoc(doc(A, 'usernames', 'ash ketchum')), true)
await check('apaga perfil', deleteDoc(doc(A, 'users', 'alice')), true)
await check('apaga nome de outro', deleteDoc(doc(A, 'usernames', 'joao')), false)

await env.cleanup()
console.log(fails ? `${fails} FALHAS` : 'TUDO CERTO')
process.exit(fails ? 1 : 0)
