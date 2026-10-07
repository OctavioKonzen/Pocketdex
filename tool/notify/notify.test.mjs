// Teste das notificações nos emuladores do Firebase (sem mandar push de
// verdade: um "send" falso guarda as mensagens).
// Rodar (da pasta e2e): npx firebase emulators:exec --only firestore \
//   --project pocketdex-ffb4d "node ../tool/notify/notify.test.mjs"
import assert from 'node:assert/strict'
import { initializeApp } from 'firebase-admin/app'
import { getFirestore, Timestamp } from 'firebase-admin/firestore'
import { render, run } from './notify.mjs'

process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8085'
initializeApp({ projectId: 'pocketdex-ffb4d' })
const db = getFirestore()
const now = Date.now()
const old = Timestamp.fromMillis(now - 60 * 60 * 1000)
const recent = Timestamp.fromMillis(now - 60 * 1000)
const set = (path, data) => db.doc(path).set(data)

await set('meta/notify', { last: Timestamp.fromMillis(now - 5 * 60 * 1000) })
await set('pushTokens/ana', { tokens: ['tok-ana', 'tok-velho'], lang: 'pt' })
await set('pushTokens/bia', { tokens: ['tok-bia'], lang: 'en' })
// Ana: um pedido novo, uma mensagem nova da Bia, um desafio antigo.
await set('friends/ana/list/caio', { name: 'Caio', status: 'received', since: recent })
await set('friends/ana/list/bia', { name: 'Bia', status: 'friends', since: old, unread: 2, last: { text: 'Bora batalhar?', at: recent, from: 'bia' }, challenge: { code: 'x', score: 12, at: old } })
// Bia: a mensagem que ela mandou (não avisa a própria Bia) e um convite de batalha da Ana.
await set('friends/bia/list/ana', { name: 'Ana', status: 'friends', since: old, unread: 0, last: { text: 'Bora batalhar?', at: recent, from: 'bia' } })
await set('onlineBattles/b1', { players: ['ana', 'bia'], names: { ana: 'Ana', bia: 'Bia' }, teams: { ana: '{}' }, status: 'pending', createdAt: recent })
await set('drafts/d1', { players: ['bia', 'ana'], names: { ana: 'Ana', bia: 'Bia' }, createdAt: old })

const sent = []
const send = async (message) => {
  sent.push(message)
  return { responses: message.tokens.map((t) => (t === 'tok-velho' ? { success: false, error: { code: 'messaging/registration-token-not-registered' } } : { success: true })) }
}
const result = await run(db, send, now)
const bodies = sent.map((m) => `${m.tokens.includes('tok-ana') ? 'ana' : m.tokens.join(',')}|${m.notification.title}|${m.notification.body}`).sort()
assert.deepEqual(bodies, [
  'ana|Bia|Bora batalhar?',
  'ana|Pedido de amizade|Caio quer ser seu amigo.',
  'tok-bia|Online battle|Ana invited you to battle!',
])
assert.equal(result.notes, 3)
// O aparelho que não existe mais saiu da lista.
assert.deepEqual((await db.doc('pushTokens/ana').get()).data().tokens, ['tok-ana'])
// A próxima rodada não repete nada.
sent.length = 0
await run(db, send, now + 1000)
assert.equal(sent.length, 0)
assert.deepEqual(render({ kind: 'challenge', args: ['Bia', '12'] }, 'es'), { title: 'Desafío', body: '¡Bia te desafió: haz 12 puntos!' })
console.log('notificações: ok')
process.exit(0)
