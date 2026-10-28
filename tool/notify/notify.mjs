// Notificações no celular (push, Firebase Cloud Messaging) sem Cloud
// Functions (o projeto está no plano gratuito): de tempos em tempos o GitHub
// roda este script (.github/workflows/notify.yml), que olha o que mudou
// desde a última vez e avisa quem tem o app:
//
//   friends/{uid}/list/{outro}  status 'received' novo  → pedido de amizade
//                               last.from == outro, novo → mensagem no chat
//                               challenge.at novo        → desafio no jogo
//   onlineBattles/{id}          'pending' novo           → convite para batalhar
//   drafts/{id}                 novo                     → convite para o draft
//
// Os aparelhos ficam em pushTokens/{uid} = { tokens: [...], lang } (o app
// grava ao entrar na conta). A última rodada fica em meta/notify.
//
// Rodar à mão: GOOGLE_APPLICATION_CREDENTIALS=chave.json npm start

import { initializeApp, cert, applicationDefault } from 'firebase-admin/app'
import { getFirestore, Timestamp } from 'firebase-admin/firestore'
import { getMessaging } from 'firebase-admin/messaging'
import { pathToFileURL } from 'node:url'

/** Os textos de cada aviso, nas línguas do app. */
export const TEXTS = {
  friend: { pt: ['Pedido de amizade', '{0} quer ser seu amigo.'], en: ['Friend request', '{0} wants to be your friend.'], fr: ["Demande d'ami", '{0} veut être ton ami.'], es: ['Solicitud de amistad', '{0} quiere ser tu amigo.'] },
  message: { pt: ['{0}', '{1}'], en: ['{0}', '{1}'], fr: ['{0}', '{1}'], es: ['{0}', '{1}'] },
  challenge: { pt: ['Desafio', '{0} te desafiou: faça {1} pontos!'], en: ['Challenge', '{0} challenged you: score {1} points!'], fr: ['Défi', '{0} te défie : fais {1} points !'], es: ['Desafío', '¡{0} te desafió: haz {1} puntos!'] },
  battle: { pt: ['Batalha online', '{0} te chamou para batalhar!'], en: ['Online battle', '{0} invited you to battle!'], fr: ['Combat en ligne', '{0} t’invite à combattre !'], es: ['Batalla en línea', '¡{0} te invitó a batallar!'] },
  draft: { pt: ['Draft', '{0} te chamou para um draft!'], en: ['Draft', '{0} invited you to a draft!'], fr: ['Draft', '{0} t’invite à un draft !'], es: ['Draft', '¡{0} te invitó a un draft!'] },
}

const ms = (t) => (t?.toMillis ? t.toMillis() : typeof t === 'number' ? t : 0)

/** O que aconteceu entre `since` e `now` (ms): [{uid, kind, args, data}]. */
export async function collect(db, since, now) {
  const out = []
  const fresh = (t) => ms(t) > since && ms(t) <= now
  const friends = await db.collectionGroup('list').get()
  for (const doc of friends.docs) {
    const owner = doc.ref.parent.parent?.id
    if (doc.ref.parent.parent?.parent.id !== 'friends' || !owner) continue
    const d = doc.data()
    const other = doc.id
    if (d.status === 'received' && fresh(d.since)) out.push({ uid: owner, kind: 'friend', args: [d.name], data: { screen: 'friends' } })
    if (d.status === 'friends' && d.last?.from === other && (d.unread ?? 0) > 0 && fresh(d.last.at)) {
      out.push({ uid: owner, kind: 'message', args: [d.name, String(d.last.text ?? '').slice(0, 100)], data: { screen: 'chat', uid: other } })
    }
    if (d.challenge && fresh(d.challenge.at)) out.push({ uid: owner, kind: 'challenge', args: [d.name, String(d.challenge.score ?? '')], data: { screen: 'friends' } })
  }
  const battles = await db.collection('onlineBattles').where('createdAt', '>', Timestamp.fromMillis(since)).get()
  for (const doc of battles.docs) {
    const d = doc.data()
    if (d.status !== 'pending' || !fresh(d.createdAt)) continue
    const host = d.players?.[0]
    for (const uid of d.players ?? []) if (uid !== host && !(uid in (d.teams ?? {}))) out.push({ uid, kind: 'battle', args: [d.names?.[host] ?? ''], data: { screen: 'online', battle: doc.id } })
  }
  const drafts = await db.collection('drafts').where('createdAt', '>', Timestamp.fromMillis(since)).get()
  for (const doc of drafts.docs) {
    const d = doc.data()
    if (!fresh(d.createdAt)) continue
    const host = d.players?.[0]
    for (const uid of d.players ?? []) if (uid !== host) out.push({ uid, kind: 'draft', args: [d.names?.[host] ?? ''], data: { screen: 'draft', draft: doc.id } })
  }
  return out
}

/** Título e texto na língua do aparelho. */
export function render(note, lang = 'pt') {
  const [title, body] = (TEXTS[note.kind][lang] ?? TEXTS[note.kind].pt).map((s) => note.args.reduce((acc, a, i) => acc.replaceAll(`{${i}}`, a), s))
  return { title, body }
}

/**
 * Manda os avisos e tira os aparelhos que não existem mais.
 * send(message) → { responses: [{success, error?}] } (firebase-admin sendEachForMulticast).
 */
export async function deliver(db, notes, send) {
  let sent = 0
  for (const note of notes) {
    const ref = db.doc(`pushTokens/${note.uid}`)
    const snap = await ref.get()
    const tokens = snap.exists ? (snap.data().tokens ?? []) : []
    if (!tokens.length) continue
    const { title, body } = render(note, snap.data().lang)
    const result = await send({
      tokens,
      notification: { title, body },
      data: Object.fromEntries(Object.entries({ kind: note.kind, ...note.data }).map(([k, v]) => [k, String(v)])),
      android: { priority: 'high', notification: { channelId: 'pocketdex', tag: `${note.kind}-${note.data?.uid ?? note.data?.battle ?? note.data?.draft ?? ''}` } },
    })
    const dead = tokens.filter((_, i) => {
      const code = result.responses[i]?.error?.code ?? ''
      return code.includes('registration-token-not-registered') || code.includes('invalid-registration-token') || code.includes('invalid-argument')
    })
    if (dead.length) await ref.update({ tokens: tokens.filter((t) => !dead.includes(t)) })
    sent += result.responses.filter((r) => r.success).length
  }
  return sent
}

/** Uma rodada: o que mudou desde a última, avisa e guarda a hora. */
export async function run(db, send, now = Date.now()) {
  const state = db.doc('meta/notify')
  const snap = await state.get()
  // Primeira vez: só daqui para frente (sem avisar o passado inteiro).
  const since = snap.exists ? ms(snap.data().last) : now - 10 * 60 * 1000
  const notes = await collect(db, since, now)
  const sent = await deliver(db, notes, send)
  await state.set({ last: Timestamp.fromMillis(now) })
  return { notes: notes.length, sent }
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const key = process.env.FIREBASE_SERVICE_ACCOUNT
  initializeApp({
    ...(key ? { credential: cert(JSON.parse(key)) } : { credential: applicationDefault() }),
    projectId: process.env.FIREBASE_PROJECT ?? 'pocketdex-ffb4d',
  })
  const messaging = getMessaging()
  const result = await run(getFirestore(), (message) => messaging.sendEachForMulticast(message))
  console.log(`${result.notes} avisos, ${result.sent} entregues`)
}
