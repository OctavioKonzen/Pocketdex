// Depois de publicar o servidor: liga o código por e-mail no site e no app
// (config/app.emailCodes = true). Roda no GitHub com a chave de administrador.
import { initializeApp, cert } from 'firebase-admin/app'
import { getFirestore } from 'firebase-admin/firestore'

initializeApp({ credential: cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)), projectId: 'pocketdex-ffb4d' })
await getFirestore().doc('config/app').set({ emailCodes: true }, { merge: true })
console.log('Código por e-mail ligado.')
