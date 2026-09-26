// Testa as regras do Firestore (firestore.rules) no emulador do Firebase.
// Rodar: cd firestore-tests && npm ci && npm test
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing'
import { readFileSync } from 'node:fs'
import { doc, setDoc, getDoc, getDocs, collection, deleteDoc, writeBatch, serverTimestamp, updateDoc, query, where } from 'firebase/firestore'

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

// times públicos e nota da comunidade
const pub = (db, id, data) => setDoc(doc(db, 'publicTeams', id), data)
const teamA = { ownerUid: 'alice', ownerName: 'Ash Ketchum', ownerKey: 'ash ketchum', avatar: 25, name: 'Time A', color: '#FF5252',
  pokemon: [6, 9, null, null, null, null], ratingSum: 0, ratingCount: 0, updatedAt: serverTimestamp() }
await check('publica time', pub(A, 'tA', teamA), true)
await check('publica time com nome de outro', pub(B, 'tB', { ...teamA, ownerUid: 'bob' }), false)
await check('publica com nota inventada', pub(B, 'tB', { ...teamA, ownerUid: 'bob', ownerName: 'João', ownerKey: 'joao', ratingSum: 50, ratingCount: 10 }), false)
await check('publica time do bob', pub(B, 'tB', { ...teamA, ownerUid: 'bob', ownerName: 'João', ownerKey: 'joao', name: 'Time B' }), true)
await check('dono edita', setDoc(doc(A, 'publicTeams', 'tA'), { ...teamA, name: 'Novo nome' }), true)
await check('dono mexe na nota', setDoc(doc(A, 'publicTeams', 'tA'), { ...teamA, ratingSum: 5, ratingCount: 1 }), false)
await check('outro edita o time', setDoc(doc(B, 'publicTeams', 'tA'), { ...teamA, name: 'hack' }), false)
const vote = (db, uid, team, stars, sum, count) => {
  const b = writeBatch(db)
  b.set(doc(db, 'publicTeams', team, 'ratings', uid), { stars })
  b.update(doc(db, 'publicTeams', team), { ratingSum: sum, ratingCount: count })
  return b.commit()
}
await check('bob vota 4 no time da alice', vote(B, 'bob', 'tA', 4, 4, 1), true)
await check('bob muda voto para 5', vote(B, 'bob', 'tA', 5, 5, 1), true)
await check('bob vota com soma errada', vote(B, 'bob', 'tA', 3, 10, 1), false)
await check('bob conta 2 votos', vote(B, 'bob', 'tA', 5, 10, 2), false)
await check('voto sem mexer na nota', setDoc(doc(B, 'publicTeams', 'tA', 'ratings', 'bob'), { stars: 1 }), false)
await check('nota sem voto', updateDoc(doc(B, 'publicTeams', 'tA'), { ratingSum: 100, ratingCount: 20 }), false)
await check('alice vota no próprio time', vote(A, 'alice', 'tA', 5, 10, 2), false)
await check('voto 6 estrelas', vote(A, 'alice', 'tB', 6, 6, 1), false)
await check('ler voto de outro', getDoc(doc(A, 'publicTeams', 'tA', 'ratings', 'bob')), false)
await check('buscar times pelo nome', getDocs(query(collection(B, 'publicTeams'), where('ownerKey', '==', 'ash ketchum'))), true)
await check('buscar times sem login', getDocs(collection(anon, 'publicTeams')), false)
const report = (db, uid, team, count) => {
  const b = writeBatch(db)
  b.set(doc(db, 'publicTeams', team, 'reports', uid), { reason: 'nome ofensivo', createdAt: serverTimestamp() })
  b.update(doc(db, 'publicTeams', team), { reportCount: count })
  return b.commit()
}
await check('bob denuncia time da alice', report(B, 'bob', 'tA', 1), true)
await check('bob denuncia de novo', report(B, 'bob', 'tA', 2), false)
await check('denúncia sem +1', setDoc(doc(anon, 'publicTeams', 'tA', 'reports', 'x'), { reason: 'x' }), false)
await check('+1 sem denúncia', updateDoc(doc(B, 'publicTeams', 'tA'), { reportCount: 5 }), false)
await check('alice denuncia o próprio', report(A, 'alice', 'tA', 2), false)
await check('dono zera denúncias', setDoc(doc(A, 'publicTeams', 'tA'), { ...teamA, ratingSum: 5, ratingCount: 1, reportCount: 0 }), false)
await check('dono edita mantendo denúncias', setDoc(doc(A, 'publicTeams', 'tA'), { ...teamA, name: 'Outro', ratingSum: 5, ratingCount: 1, reportCount: 1 }), true)
await check('outro apaga time', deleteDoc(doc(B, 'publicTeams', 'tA')), false)
await check('dono apaga time', deleteDoc(doc(A, 'publicTeams', 'tA')), true)

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
