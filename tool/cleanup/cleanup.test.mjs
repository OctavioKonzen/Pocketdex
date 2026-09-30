// Teste da limpeza nos emuladores do Firebase: uma conta que existe (viva) e
// sobras de uma conta excluída (morta). Depois da limpeza só a viva sobra.
// Rodar (da pasta e2e): npx firebase emulators:exec --only auth,firestore \
//   --project pocketdex-ffb4d "node ../tool/cleanup/cleanup.test.mjs"
import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import { initializeApp } from 'firebase-admin/app'
import { getAuth } from 'firebase-admin/auth'
import { getFirestore, Timestamp } from 'firebase-admin/firestore'

process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8085'
process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9099'
initializeApp({ projectId: 'pocketdex-ffb4d' })
const db = getFirestore()
await getAuth().createUser({ uid: 'viva', email: 'viva@example.com' })
await getAuth().createUser({ uid: 'amiga', email: 'amiga@example.com' })

const set = (path, data) => db.doc(path).set(data)
await set('users/viva', { name: 'Viva' })
await set('users/morta', { name: 'Morta' })
await set('confirmations/morta', { delete: 1 })
await set('confirmations/viva', { signup: 1 })
await set('usernames/viva', { uid: 'viva', name: 'Viva' })
await set('usernames/morta', { uid: 'morta', name: 'Morta' })
await set('ranking/viva', { name: 'Viva', score: 10 })
await set('ranking/morta', { name: 'Morta', score: 20 })
await set('weekly/2026-09-21/scores/morta', { name: 'Morta', score: 5 })
await set('daily/2026-09-25/scores/morta', { name: 'Morta', score: 5 })
await set('daily/2026-09-25/scores/viva', { name: 'Viva', score: 5 })
await set('publicTeams/daMorta', { ownerUid: 'morta', ratingSum: 0, ratingCount: 0 })
await set('publicTeams/daMorta/ratings/viva', { stars: 5 })
await set('publicTeams/daViva', { ownerUid: 'viva', ratingSum: 9, ratingCount: 2, reportCount: 1 })
await set('publicTeams/daViva/ratings/morta', { stars: 4 })
await set('publicTeams/daViva/ratings/outra', { stars: 5 })
await set('publicTeams/daViva/reports/morta', { reason: 'x' })
await set('friends/viva/list/morta', { name: 'Morta', status: 'friends' })
await set('friends/morta/list/viva', { name: 'Viva', status: 'friends' })
await set('friends/viva/list/amiga', { name: 'Amiga', status: 'friends' })
await set('friends/amiga/list/viva', { name: 'Viva', status: 'friends' })
await set('drafts/bom', { players: ['viva', 'amiga'], picks: {} })
await set('drafts/ruim', { players: ['viva', 'morta'], picks: {} })
await set('trades/viva', { dupes: [1], caught: [1] })
await set('trades/morta', { dupes: [2], caught: [2] })
await set('chats/amiga_viva/messages/m1', { from: 'viva', text: 'oi', at: Timestamp.now() })
await set('chats/amiga_viva/messages/velha', { from: 'viva', text: 'faz tempo', at: Timestamp.fromMillis(Date.now() - 8 * 86400000) })
await set('friends/amiga/list/viva', { name: 'Viva', status: 'friends', unread: 1, last: { text: 'faz tempo', at: Date.now() - 8 * 86400000, from: 'viva' } })
await set('chats/morta_viva/messages/m1', { from: 'morta', text: 'oi', at: 1 })

execFileSync('node', [new URL('./cleanup.mjs', import.meta.url).pathname], { stdio: 'inherit', env: { ...process.env, FIREBASE_SERVICE_ACCOUNT: '' } })

const ids = async (path) => (await db.collection(path).get()).docs.map((d) => d.id).sort()
assert.deepEqual(await ids('users'), ['viva'])
assert.deepEqual(await ids('confirmations'), ['viva'])
assert.deepEqual(await ids('usernames'), ['viva'])
assert.deepEqual(await ids('ranking'), ['viva'])
assert.deepEqual(await ids('weekly/2026-09-21/scores'), [])
assert.deepEqual(await ids('daily/2026-09-25/scores'), ['viva'])
assert.deepEqual(await ids('publicTeams'), ['daViva'])
assert.deepEqual(await ids('publicTeams/daMorta/ratings'), [])
assert.deepEqual(await ids('publicTeams/daViva/reports'), [])
assert.deepEqual(await ids('friends/viva/list'), ['amiga'])
assert.deepEqual(await ids('friends/morta/list'), [])
assert.deepEqual(await ids('chats/amiga_viva/messages'), ['m1'])
const preview = (await db.doc('friends/amiga/list/viva').get()).data()
assert.deepEqual([preview.last, preview.unread], [null, 0])
assert.deepEqual(await ids('chats/morta_viva/messages'), [])
assert.deepEqual(await ids('trades'), [])
assert.deepEqual(await ids('drafts'), ['bom'])
// "outra" também não existe: a nota do time fica zerada.
const team = (await db.doc('publicTeams/daViva').get()).data()
assert.deepEqual([team.ratingSum, team.ratingCount, team.reportCount], [0, 0, 0])
console.log('LIMPEZA CERTA: só a conta que existe sobrou.')
