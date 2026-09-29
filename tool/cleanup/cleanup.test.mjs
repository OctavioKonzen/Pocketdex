// Teste da limpeza nos emuladores do Firebase: uma conta que existe (viva) e
// sobras de uma conta excluída (morta). Depois da limpeza só a viva sobra.
// Rodar (da pasta e2e): npx firebase emulators:exec --only auth,firestore \
//   --project pocketdex-ffb4d "node ../tool/cleanup/cleanup.test.mjs"
import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import { initializeApp } from 'firebase-admin/app'
import { getAuth } from 'firebase-admin/auth'
import { getFirestore } from 'firebase-admin/firestore'

process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8085'
process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9099'
initializeApp({ projectId: 'pocketdex-ffb4d' })
const db = getFirestore()
await getAuth().createUser({ uid: 'viva', email: 'viva@example.com' })

const set = (path, data) => db.doc(path).set(data)
await set('users/viva', { name: 'Viva' })
await set('users/morta', { name: 'Morta' })
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

execFileSync('node', [new URL('./cleanup.mjs', import.meta.url).pathname], { stdio: 'inherit', env: { ...process.env, FIREBASE_SERVICE_ACCOUNT: '' } })

const ids = async (path) => (await db.collection(path).get()).docs.map((d) => d.id).sort()
assert.deepEqual(await ids('users'), ['viva'])
assert.deepEqual(await ids('usernames'), ['viva'])
assert.deepEqual(await ids('ranking'), ['viva'])
assert.deepEqual(await ids('weekly/2026-09-21/scores'), [])
assert.deepEqual(await ids('daily/2026-09-25/scores'), ['viva'])
assert.deepEqual(await ids('publicTeams'), ['daViva'])
assert.deepEqual(await ids('publicTeams/daMorta/ratings'), [])
assert.deepEqual(await ids('publicTeams/daViva/reports'), [])
// "outra" também não existe: a nota do time fica zerada.
const team = (await db.doc('publicTeams/daViva').get()).data()
assert.deepEqual([team.ratingSum, team.ratingCount, team.reportCount], [0, 0, 0])
console.log('LIMPEZA CERTA: só a conta que existe sobrou.')
