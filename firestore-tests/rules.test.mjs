// Testa as regras do Firestore (firestore.rules) no emulador do Firebase.
// Rodar: cd firestore-tests && npm ci && npm test
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing'
import { readFileSync } from 'node:fs'
import { doc, setDoc, getDoc, getDocs, collection, deleteDoc, writeBatch, serverTimestamp, updateDoc, query, where, increment } from 'firebase/firestore'

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
const fullSet = { nickname: 'Chama', level: 50, gender: 'M', shiny: true, ability: 'blaze', item: 'life-orb', nature: 'Timid',
  tera: 'fire', moves: ['flamethrower', 'air-slash', '', ''], evs: { hp: 0, atk: 0, def: 0, spa: 252, spd: 4, spe: 252 },
  ivs: { hp: 31, atk: 0, def: 31, spa: 31, spd: 31, spe: 31 } }
await check('time com dados completos', setDoc(doc(A, 'publicTeams', 'tA'), { ...teamA, sets: [fullSet, null, null, null, null, null] }), true)
await check('sets com tamanho errado', setDoc(doc(A, 'publicTeams', 'tA'), { ...teamA, sets: [fullSet] }), false)
await check('sets que não é lista', setDoc(doc(A, 'publicTeams', 'tA'), { ...teamA, sets: 'x' }), false)
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
await check('ler voto de outro', getDoc(doc(anon, 'publicTeams', 'tA', 'ratings', 'bob')), false)
await check('dono lê voto no próprio time', getDoc(doc(A, 'publicTeams', 'tA', 'ratings', 'bob')), true)
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

// excluir conta: voto e denúncia saem dos times dos outros
const unvote = (db, uid, team, stars) => {
  const b = writeBatch(db)
  b.update(doc(db, 'publicTeams', team), { ratingSum: increment(-stars), ratingCount: increment(-1) })
  b.delete(doc(db, 'publicTeams', team, 'ratings', uid))
  return b.commit()
}
await check('tirar voto sem mexer na nota', deleteDoc(doc(B, 'publicTeams', 'tA', 'ratings', 'bob')), false)
await check('tirar voto com nota errada', unvote(B, 'bob', 'tA', 2), false)
await check('outro tira voto do bob', unvote(A, 'bob', 'tA', 5), false)
await check('bob tira o voto (nota volta)', unvote(B, 'bob', 'tA', 5), true)
await check('bob vota de novo', vote(B, 'bob', 'tA', 3, 3, 1), true)
const unreport = (db, uid, team) => {
  const b = writeBatch(db)
  b.update(doc(db, 'publicTeams', team), { reportCount: increment(-1) })
  b.delete(doc(db, 'publicTeams', team, 'reports', uid))
  return b.commit()
}
await check('outro apaga denúncia do bob', deleteDoc(doc(anon, 'publicTeams', 'tA', 'reports', 'bob')), false)
await check('bob apaga denúncia sem -1', deleteDoc(doc(B, 'publicTeams', 'tA', 'reports', 'bob')), false)
await check('-1 denúncia sem apagar a denúncia', updateDoc(doc(B, 'publicTeams', 'tA'), { reportCount: 0 }), false)
await check('bob tira a própria denúncia (-1)', unreport(B, 'bob', 'tA'), true)
await check('bob denuncia de novo', report(B, 'bob', 'tA', 1), true)
await check('dono lista votos do próprio time', getDocs(collection(A, 'publicTeams', 'tA', 'ratings')), true)
await check('outro lista votos do time', getDocs(collection(B, 'publicTeams', 'tB', 'ratings')), true)
await check('bob lista votos do time da alice', getDocs(collection(B, 'publicTeams', 'tA', 'ratings')), false)
await check('dono apaga votos do próprio time', deleteDoc(doc(A, 'publicTeams', 'tA', 'ratings', 'bob')), true)
await check('dono apaga denúncias do próprio time', deleteDoc(doc(A, 'publicTeams', 'tA', 'reports', 'bob')), true)
await check('dono apaga time', deleteDoc(doc(A, 'publicTeams', 'tA')), true)

// excluir conta
await check('apaga ranking', deleteDoc(doc(A, 'ranking', 'alice')), true)
await check('apaga semana', deleteDoc(doc(A, 'weekly', '2026-09-21', 'scores', 'alice')), true)
await check('apaga desafio', deleteDoc(doc(A, 'daily', '2026-09-25', 'scores', 'alice')), true)
await check('apaga nome', deleteDoc(doc(A, 'usernames', 'ash ketchum')), true)
await check('apaga perfil', deleteDoc(doc(A, 'users', 'alice')), true)
await check('apaga nome de outro', deleteDoc(doc(A, 'usernames', 'joao')), false)

// Nome preso de uma conta já excluída (perfil não existe mais): fica livre.
await env.withSecurityRulesDisabled(async (ctx) => setDoc(doc(ctx.firestore(), 'usernames', 'misty'), { uid: 'gone', name: 'Misty' }))
const C = env.authenticatedContext('carol').firestore()
await check('nova conta pega nome de conta excluída', claim(C, 'carol', 'Misty', 'misty'), true)
await check('nome de conta ativa continua preso', claim(C, 'carol', 'João', 'joao'), false)
await check('apaga nome de conta ativa', deleteDoc(doc(anon, 'usernames', 'joao')), false)

// Confirmação por link (contas Google): só a própria pessoa.
await check('grava a própria confirmação', setDoc(doc(A, 'confirmations', 'alice'), { signup: serverTimestamp() }), true)
await check('lê a própria confirmação', getDoc(doc(A, 'confirmations', 'alice')), true)
await check('confirmação de outro', setDoc(doc(B, 'confirmations', 'alice'), { delete: serverTimestamp() }), false)
await check('ler confirmação de outro', getDoc(doc(B, 'confirmations', 'alice')), false)
await check('confirmação com campo estranho', setDoc(doc(A, 'confirmations', 'alice'), { hack: 1 }), false)

// Amigos
await claim(A, 'alice', 'Ash Ketchum', 'ash ketchum').catch(() => {})
await env.withSecurityRulesDisabled(async (ctx) => setDoc(doc(ctx.firestore(), 'users', 'alice'), { name: 'Ash Ketchum' }))
const ask = (db, from, fromName, to, toName) => {
  const b = writeBatch(db)
  b.set(doc(db, 'friends', from, 'list', to), { name: toName, avatar: null, status: 'sent', since: serverTimestamp() })
  b.set(doc(db, 'friends', to, 'list', from), { name: fromName, avatar: 25, status: 'received', since: serverTimestamp() })
  return b.commit()
}
await check('pedido de amizade com nome falso', ask(A, 'alice', 'Outro Nome', 'bob', 'João'), false)
await check('pedido de amizade em nome de outro', ask(C, 'alice', 'Ash Ketchum', 'bob', 'João'), false)
await check('pedido de amizade', ask(A, 'alice', 'Ash Ketchum', 'bob', 'João'), true)
await check('quem pediu não pode aceitar sozinho', updateDoc(doc(A, 'friends', 'alice', 'list', 'bob'), { status: 'friends' }), false)
await check('terceiro lê lista', getDocs(collection(C, 'friends', 'bob', 'list')), false)
await check('lê a própria lista', getDocs(collection(B, 'friends', 'bob', 'list')), true)
const accept = (db) => {
  const b = writeBatch(db)
  b.update(doc(db, 'friends', 'bob', 'list', 'alice'), { status: 'friends' })
  b.update(doc(db, 'friends', 'alice', 'list', 'bob'), { status: 'friends', name: 'João', avatar: 7 })
  return b.commit()
}
await check('aceitar amizade', accept(B), true)
await check('amigo manda desafio', updateDoc(doc(B, 'friends', 'alice', 'list', 'bob'), { challenge: { code: 'abc', score: 7, at: 1 } }), true)
await check('desafio com campo estranho', updateDoc(doc(B, 'friends', 'alice', 'list', 'bob'), { challenge: { code: 'abc', hack: 1 } }), false)
await check('amigo não troca o nome dele por outro', updateDoc(doc(B, 'friends', 'alice', 'list', 'bob'), { name: 'Ash Ketchum' }), false)
// Chat entre amigos
const send = (db, from, to, text, extra = {}) => {
  const chat = [from, to].sort().join('_')
  const b = writeBatch(db)
  b.set(doc(collection(db, 'chats', chat, 'messages')), { from, text, at: serverTimestamp(), ...extra })
  b.update(doc(db, 'friends', to, 'list', from), { unread: increment(1), last: { text: text.slice(0, 100), at: 1, from } })
  return b.commit()
}
await check('amigo manda mensagem', send(A, 'alice', 'bob', 'Oi, bora batalhar?'), true)
await check('mensagem em nome de outro', setDoc(doc(collection(A, 'chats', 'alice_bob', 'messages')), { from: 'bob', text: 'oi', at: serverTimestamp() }), false)
await check('mensagem vazia', setDoc(doc(collection(A, 'chats', 'alice_bob', 'messages')), { from: 'alice', text: '', at: serverTimestamp() }), false)
await check('mensagem grande demais', setDoc(doc(collection(A, 'chats', 'alice_bob', 'messages')), { from: 'alice', text: 'x'.repeat(501), at: serverTimestamp() }), false)
await check('mensagem com hora falsa', setDoc(doc(collection(A, 'chats', 'alice_bob', 'messages')), { from: 'alice', text: 'oi', at: 5 }), false)
await check('mensagem com campo estranho', send(A, 'alice', 'bob', 'oi', { hack: 1 }), false)
await check('chat com id fora de ordem', setDoc(doc(collection(A, 'chats', 'bob_alice', 'messages')), { from: 'alice', text: 'oi', at: serverTimestamp() }), false)
await check('amigo lê o chat', getDocs(collection(B, 'chats', 'alice_bob', 'messages')), true)
await check('terceiro lê o chat', getDocs(collection(C, 'chats', 'alice_bob', 'messages')), false)
await check('terceiro manda no chat', setDoc(doc(collection(C, 'chats', 'alice_bob', 'messages')), { from: 'carol', text: 'oi', at: serverTimestamp() }), false)
await check('zera as não lidas', updateDoc(doc(B, 'friends', 'bob', 'list', 'alice'), { unread: 0 }), true)
let msgs
await env.withSecurityRulesDisabled(async (ctx) => { msgs = await getDocs(collection(ctx.firestore(), 'chats', 'alice_bob', 'messages')) })
await check('não edita mensagem', updateDoc(doc(A, 'chats', 'alice_bob', 'messages', msgs.docs[0].id), { text: 'mudei' }), false)
await check('terceiro apaga mensagem', deleteDoc(doc(C, 'chats', 'alice_bob', 'messages', msgs.docs[0].id)), false)
await check('amigo apaga mensagem', deleteDoc(doc(B, 'chats', 'alice_bob', 'messages', msgs.docs[0].id)), true)
await check('quem não é amigo não manda', setDoc(doc(collection(C, 'chats', 'bob_carol', 'messages')), { from: 'carol', text: 'oi', at: serverTimestamp() }), false)

await check('terceiro apaga amizade', deleteDoc(doc(C, 'friends', 'alice', 'list', 'bob')), false)
await check('desfaz amizade (o outro lado)', deleteDoc(doc(B, 'friends', 'alice', 'list', 'bob')), true)
await check('desfaz amizade (o próprio lado)', deleteDoc(doc(B, 'friends', 'bob', 'list', 'alice')), true)

await env.cleanup()
console.log(fails ? `${fails} FALHAS` : 'TUDO CERTO')
process.exit(fails ? 1 : 0)
