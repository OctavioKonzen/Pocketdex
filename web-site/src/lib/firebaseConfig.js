// Configuração do Firebase (login e banco de dados dos usuários).
//
// Cole aqui os dados do seu projeto (Console do Firebase → Configurações do
// projeto → Seus apps → App da Web). Esses valores não são segredo: a
// segurança fica nas regras do Firestore (firestore.rules) e nos domínios
// autorizados do Authentication. Também dá para passar por variáveis de
// ambiente VITE_FIREBASE_* no build.
//
// Enquanto estiver vazio, o site funciona sem login (como antes).

const env = import.meta.env

export const firebaseConfig = {
  apiKey: env.VITE_FIREBASE_API_KEY ?? '',
  authDomain: env.VITE_FIREBASE_AUTH_DOMAIN ?? '',
  projectId: env.VITE_FIREBASE_PROJECT_ID ?? '',
  storageBucket: env.VITE_FIREBASE_STORAGE_BUCKET ?? '',
  messagingSenderId: env.VITE_FIREBASE_MESSAGING_SENDER_ID ?? '',
  appId: env.VITE_FIREBASE_APP_ID ?? '',
}

export const isConfigured = Boolean(firebaseConfig.apiKey && firebaseConfig.projectId)
