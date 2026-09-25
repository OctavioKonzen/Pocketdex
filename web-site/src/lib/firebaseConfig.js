// Configuração do Firebase (login e banco de dados dos usuários).
//
// Cole aqui os dados do seu projeto (Console do Firebase → Configurações do
// projeto → Seus apps → App da Web). Esses valores não são segredo: a
// segurança fica nas regras do Firestore (firestore.rules) e nos domínios
// autorizados do Authentication. Também dá para passar por variáveis de
// ambiente VITE_FIREBASE_* no build.
//
// Se estiver vazio, o site funciona sem login.

const env = import.meta.env

// Projeto do Firebase: pocketdex-ffb4d
export const firebaseConfig = {
  apiKey: env.VITE_FIREBASE_API_KEY || 'AIzaSyAQyM-St8S7SxElu9_qL8mp3Xd4AmQW5W4',
  authDomain: env.VITE_FIREBASE_AUTH_DOMAIN || 'pocketdex-ffb4d.firebaseapp.com',
  projectId: env.VITE_FIREBASE_PROJECT_ID || 'pocketdex-ffb4d',
  storageBucket: env.VITE_FIREBASE_STORAGE_BUCKET || 'pocketdex-ffb4d.firebasestorage.app',
  messagingSenderId: env.VITE_FIREBASE_MESSAGING_SENDER_ID || '49935016224',
  appId: env.VITE_FIREBASE_APP_ID || '1:49935016224:web:1bc98d9cb15ae14faff745',
}

export const isConfigured = Boolean(firebaseConfig.apiKey && firebaseConfig.projectId)
