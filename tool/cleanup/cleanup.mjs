// Limpeza do banco: apaga tudo que é de uma conta que não existe mais.
//
// A exclusão de conta no app e no site já apaga tudo, mas este script
// garante que nenhum vestígio fique (ex.: exclusões antigas, internet que
// caiu no meio). Roda todo dia pelo GitHub (.github/workflows/cleanup.yml)
// com a chave de administrador do Firebase no segredo FIREBASE_SERVICE_ACCOUNT.
//
//   users/{uid}, confirmations/{uid}, ranking/{uid}, weekly|daily/{dia}/scores/{uid} → apaga se a conta não existe
//   usernames/{nome}                → apaga se o dono não existe (ou não tem mais perfil)
//   publicTeams/{id}                → apaga (com votos e denúncias) se o dono não existe
//   friends/{uid}/list/{outro}      → apaga se uma das duas contas não existe
//   chats/{a_b}/messages/{id}       → apaga se a amizade acabou (ou uma conta não existe)
//                                     ou se tem mais de 7 dias (o chat se limpa sozinho);
//                                     a prévia (last) e as não lidas também somem
//   trades/{uid}                    → apaga todas (as Trocas saíram)
//   drafts/{id}                     → apaga se um dos jogadores não existe
//   pushTokens/{uid}                → apaga se a conta não existe
//   matchQueue/{uid}                → apaga se a conta não existe ou parada há 10 min
//   publicTeams/{id}/ratings|reports/{uid} → apaga se a conta não existe e refaz a nota
//                                            e a contagem de denúncias do time
//
// Rodar à mão: GOOGLE_APPLICATION_CREDENTIALS=chave.json npm start
// Só mostrar sem apagar: DRY_RUN=1 npm start

import { initializeApp, cert, applicationDefault } from 'firebase-admin/app'
import { getAuth } from 'firebase-admin/auth'
import { getFirestore } from 'firebase-admin/firestore'

const dryRun = Boolean(process.env.DRY_RUN)
const key = process.env.FIREBASE_SERVICE_ACCOUNT
initializeApp({
  ...(key ? { credential: cert(JSON.parse(key)) } : process.env.FIRESTORE_EMULATOR_HOST ? {} : { credential: applicationDefault() }),
  projectId: process.env.FIREBASE_PROJECT ?? 'pocketdex-ffb4d',
})
const auth = getAuth()
const db = getFirestore()

const accounts = new Set()
let pageToken
do {
  const page = await auth.listUsers(1000, pageToken)
  page.users.forEach((u) => accounts.add(u.uid))
  pageToken = page.pageToken
} while (pageToken)
console.log(`${accounts.size} contas existem.`)

const removed = {}
const remove = async (ref, why) => {
  removed[why] = (removed[why] ?? 0) + 1
  console.log(`${dryRun ? '[teste] ' : ''}apaga ${ref.path} (${why})`)
  if (!dryRun) await db.recursiveDelete(ref)
}

// Perfis (e tudo dentro deles).
const profiles = new Set()
for (const d of (await db.collection('users').get()).docs) {
  if (accounts.has(d.id)) profiles.add(d.id)
  else await remove(d.ref, 'perfil sem conta')
}

// Confirmações por link no e-mail (contas Google).
for (const d of (await db.collection('confirmations').get()).docs) {
  if (!accounts.has(d.id)) await remove(d.ref, 'confirmação sem conta')
}

// Nomes reservados.
for (const d of (await db.collection('usernames').get()).docs) {
  if (!profiles.has(d.data().uid)) await remove(d.ref, 'nome sem conta')
}

// Amizades: somem se uma das duas contas não existe mais.
const friendships = new Set()
for (const d of (await db.collectionGroup('list').get()).docs) {
  const owner = d.ref.parent.parent
  if (owner?.parent.id !== 'friends') continue
  if (!accounts.has(owner.id) || !accounts.has(d.id)) await remove(d.ref, 'amizade com conta que não existe')
  else if (d.data().status === 'friends') friendships.add([owner.id, d.id].sort().join('_'))
}

// Batalhas: convites e histórico somem após sete dias ou exclusão da conta.
for (const d of (await db.collection('onlineBattles').get()).docs) {
  const r = d.data()
  if (!Array.isArray(r.players) || r.players.some((uid) => !accounts.has(uid)) ||
      (r.createdAt?.toMillis?.() ?? 0) < Date.now() - 7 * 24 * 60 * 60 * 1000) {
    await remove(d.ref, 'batalha expirada ou sem conta')
  }
}

// Chats: só ficam enquanto os dois são amigos, e por no máximo 7 dias.
const CHAT_DAYS = 7
const chatLimit = Date.now() - CHAT_DAYS * 24 * 60 * 60 * 1000
const millis = (at) => (typeof at === 'number' ? at : at?.toMillis?.() ?? 0)
for (const d of (await db.collectionGroup('messages').get()).docs) {
  const chat = d.ref.parent.parent
  if (chat?.parent.id !== 'chats') continue
  if (!friendships.has(chat.id)) await remove(d.ref, 'mensagem de chat sem amizade')
  else if (millis(d.data().at) < chatLimit) await remove(d.ref, 'mensagem de chat com mais de 7 dias')
}

// Prévia da última mensagem na lista de amigos: some junto com o chat.
for (const d of (await db.collectionGroup('list').get()).docs) {
  const last = d.data().last
  if (d.ref.parent.parent?.parent.id !== 'friends' || !last || millis(last.at) >= chatLimit) continue
  removed['prévia de chat antiga'] = (removed['prévia de chat antiga'] ?? 0) + 1
  console.log(`${dryRun ? '[teste] ' : ''}limpa a prévia de ${d.ref.path}`)
  if (!dryRun) await d.ref.update({ last: null, unread: 0 }).catch(() => {})
}

// Drafts: somem se um dos dois jogadores não existe mais.
for (const d of (await db.collection('drafts').get()).docs) {
  if (!(d.data().players ?? []).every((p) => accounts.has(p))) await remove(d.ref, 'draft com conta que não existe')
}

// Aparelhos das notificações: somem com a conta.
for (const d of (await db.collection('pushTokens').get()).docs) {
  if (!accounts.has(d.id)) await remove(d.ref, 'aparelhos sem conta')
}

// Fila do adversário aleatório: vaga de conta excluída ou parada há mais de 10 minutos.
const queueLimit = Date.now() - 10 * 60 * 1000
for (const d of (await db.collection('matchQueue').get()).docs) {
  if (!accounts.has(d.id)) await remove(d.ref, 'vaga na fila sem conta')
  else if ((d.data().at?.toMillis?.() ?? 0) < queueLimit) await remove(d.ref, 'vaga velha na fila')
}

// Listas das antigas Trocas (o recurso saiu): apaga todas.
for (const d of (await db.collection('trades').get()).docs) {
  await remove(d.ref, 'lista de trocas (recurso removido)')
}

// Rankings (geral, semanas e dias).
for (const d of (await db.collection('ranking').get()).docs) {
  if (!accounts.has(d.id)) await remove(d.ref, 'ranking sem conta')
}
for (const d of (await db.collectionGroup('scores').get()).docs) {
  if (!accounts.has(d.id)) await remove(d.ref, 'ranking da semana/dia sem conta')
}

// Times públicos, votos e denúncias.
for (const team of (await db.collection('publicTeams').get()).docs) {
  if (!accounts.has(team.data().ownerUid)) {
    await remove(team.ref, 'time sem dono')
    continue
  }
  let ratingSum = 0
  let ratingCount = 0
  for (const vote of (await team.ref.collection('ratings').get()).docs) {
    if (!accounts.has(vote.id)) await remove(vote.ref, 'voto sem conta')
    else {
      ratingSum += vote.data().stars ?? 0
      ratingCount++
    }
  }
  let reportCount = 0
  for (const report of (await team.ref.collection('reports').get()).docs) {
    if (!accounts.has(report.id)) await remove(report.ref, 'denúncia sem conta')
    else reportCount++
  }
  const t = team.data()
  if (t.ratingSum !== ratingSum || t.ratingCount !== ratingCount || (t.reportCount ?? 0) !== reportCount) {
    console.log(`${dryRun ? '[teste] ' : ''}refaz nota/denúncias de ${team.ref.path}`)
    if (!dryRun) await team.ref.update({ ratingSum, ratingCount, reportCount })
  }
}

console.log(Object.keys(removed).length ? removed : 'Nada para apagar: nenhum vestígio de conta excluída.')
