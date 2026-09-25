// Login com Firebase: e-mail e senha ou Google, com "Manter conectado".
//
// Banco de dados (Firestore):
//   users/{uid}          → { name, email, createdAt, data: {favoritos, times...} }
//   usernames/{nomeNorm} → { uid, name }   (garante que não existam 2 pessoas
//                                           com o mesmo nome)
//
// O Firebase só é baixado quando o login está configurado, então o site
// continua leve para quem já entrou.

import { create } from 'zustand'
import { firebaseConfig, isConfigured } from './firebaseConfig'

let services = null

async function firebase() {
  if (services) return services
  const [{ initializeApp }, authMod, fsMod] = await Promise.all([
    import('firebase/app'),
    import('firebase/auth'),
    import('firebase/firestore'),
  ])
  const app = initializeApp(firebaseConfig)
  const auth = authMod.getAuth(app)
  auth.languageCode = 'pt-BR'
  services = { auth, db: fsMod.getFirestore(app), ...authMod, ...fsMod }
  return services
}

/** Estado do login: 'loading' | 'signedOut' | 'needsName' | 'signedIn'. */
export const useAuth = create(() => ({
  status: isConfigured ? 'loading' : 'disabled',
  user: null, // { uid, email, name, photo }
}))

// ---------------------------------------------------------------- nomes

export const NAME_MIN = 3
export const NAME_MAX = 20

/** Chave usada para comparar nomes: "Ash  Ketchum" e "ash ketchum" são o mesmo nome. */
export function nameKey(name) {
  return name
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .trim()
    .replace(/\s+/g, ' ')
    .toLowerCase()
}

/** Retorna uma mensagem de erro ou null se o nome for válido. */
export function validateName(name) {
  const clean = name.trim().replace(/\s+/g, ' ')
  if (clean.length < NAME_MIN) return `O nome precisa ter pelo menos ${NAME_MIN} letras.`
  if (clean.length > NAME_MAX) return `O nome pode ter no máximo ${NAME_MAX} letras.`
  if (!/^[\p{L}\p{N} _.-]+$/u.test(clean)) return 'Use só letras, números, espaço, ponto, - ou _.'
  return null
}

class AuthError extends Error {
  constructor(code) {
    super(code)
    this.code = code
  }
}

export async function isNameAvailable(name) {
  const { db, doc, getDoc } = await firebase()
  const snap = await getDoc(doc(db, 'usernames', nameKey(name)))
  return !snap.exists() || snap.data().uid === services.auth.currentUser?.uid
}

/** Reserva o nome para o usuário e cria o perfil dele, tudo de uma vez. */
async function claimName(user, name) {
  const { db, doc, runTransaction, serverTimestamp } = await firebase()
  const clean = name.trim().replace(/\s+/g, ' ')
  const nameRef = doc(db, 'usernames', nameKey(clean))
  const userRef = doc(db, 'users', user.uid)
  await runTransaction(db, async (tx) => {
    const taken = await tx.get(nameRef)
    if (taken.exists() && taken.data().uid !== user.uid) throw new AuthError('name-taken')
    tx.set(nameRef, { uid: user.uid, name: clean })
    tx.set(userRef, { name: clean, email: user.email ?? '', createdAt: serverTimestamp() }, { merge: true })
  })
  return clean
}

// ---------------------------------------------------------------- sessão

async function setKeepSignedIn(keep) {
  const { auth, setPersistence, browserLocalPersistence, browserSessionPersistence } = await firebase()
  await setPersistence(auth, keep ? browserLocalPersistence : browserSessionPersistence)
}

let started = false
// Durante o cadastro o perfil ainda está sendo criado: o ouvinte espera.
let signingUp = false

/** Começa a ouvir o login (chamado uma vez ao abrir o site). */
export async function startAuth() {
  if (!isConfigured || started) return
  started = true
  try {
    const { auth, db, doc, getDoc, onAuthStateChanged } = await firebase()
    onAuthStateChanged(auth, async (user) => {
      if (signingUp) return
      if (!user) {
        useAuth.setState({ status: 'signedOut', user: null })
        return
      }
      const base = { uid: user.uid, email: user.email, photo: user.photoURL, name: null }
      try {
        const profile = await getDoc(doc(db, 'users', user.uid))
        const name = profile.exists() ? profile.data().name : null
        useAuth.setState({ status: name ? 'signedIn' : 'needsName', user: { ...base, name } })
      } catch {
        useAuth.setState({ status: 'needsName', user: base })
      }
    })
  } catch {
    useAuth.setState({ status: 'signedOut', user: null })
  }
}

export async function signUp({ name, email, password, keep }) {
  const nameError = validateName(name)
  if (nameError) throw new AuthError(nameError)
  if (!(await isNameAvailable(name))) throw new AuthError('name-taken')
  await setKeepSignedIn(keep)
  const { auth, createUserWithEmailAndPassword, updateProfile, deleteUser } = await firebase()
  signingUp = true
  let user
  try {
    ;({ user } = await createUserWithEmailAndPassword(auth, email.trim(), password))
  } catch (error) {
    signingUp = false
    throw error
  }
  try {
    const clean = await claimName(user, name)
    await updateProfile(user, { displayName: clean })
    useAuth.setState({ status: 'signedIn', user: { uid: user.uid, email: user.email, photo: null, name: clean } })
  } catch (error) {
    // Alguém pegou o nome no mesmo instante: desfaz a conta criada.
    await deleteUser(user).catch(() => {})
    useAuth.setState({ status: 'signedOut', user: null })
    throw error
  } finally {
    signingUp = false
  }
}

export async function signIn({ email, password, keep }) {
  await setKeepSignedIn(keep)
  const { auth, signInWithEmailAndPassword } = await firebase()
  await signInWithEmailAndPassword(auth, email.trim(), password)
}

export async function signInWithGoogle({ keep }) {
  await setKeepSignedIn(keep)
  const { auth, GoogleAuthProvider, signInWithPopup } = await firebase()
  const provider = new GoogleAuthProvider()
  provider.setCustomParameters({ prompt: 'select_account' })
  await signInWithPopup(auth, provider)
}

/** Primeiro login com Google: a pessoa escolhe o nome dela. */
export async function chooseName(name) {
  const nameError = validateName(name)
  if (nameError) throw new AuthError(nameError)
  const { auth, updateProfile } = await firebase()
  const user = auth.currentUser
  const clean = await claimName(user, name)
  await updateProfile(user, { displayName: clean }).catch(() => {})
  useAuth.setState((s) => ({ status: 'signedIn', user: { ...s.user, name: clean } }))
}

export async function resetPassword(email) {
  const { auth, sendPasswordResetEmail } = await firebase()
  await sendPasswordResetEmail(auth, email.trim())
}

export async function signOut() {
  const { auth, signOut: logout } = await firebase()
  await logout(auth)
}

// ---------------------------------------------------------------- dados

/** Lê os dados salvos (favoritos, times...) da conta. */
export async function loadUserData(uid) {
  const { db, doc, getDoc } = await firebase()
  const snap = await getDoc(doc(db, 'users', uid))
  return snap.exists() ? snap.data().data ?? null : null
}

export async function saveUserData(uid, data) {
  const { db, doc, setDoc, serverTimestamp } = await firebase()
  await setDoc(doc(db, 'users', uid), { data, updatedAt: serverTimestamp() }, { merge: true })
}

// ---------------------------------------------------------------- ranking
//   ranking/{uid} → { name, score, updatedAt }   (recorde do "Quem é esse Pokémon?")

/** Coloca (ou tira, se for 0) o recorde da pessoa no ranking. */
export async function saveRanking(uid, name, score) {
  const { db, doc, setDoc, deleteDoc, serverTimestamp } = await firebase()
  const ref = doc(db, 'ranking', uid)
  if (score > 0) await setDoc(ref, { name, score, updatedAt: serverTimestamp() })
  else await deleteDoc(ref)
}

/** Os melhores recordes, do maior para o menor. */
export async function getRanking(count = 10) {
  const { db, collection, query, orderBy, limit, getDocs } = await firebase()
  const snap = await getDocs(query(collection(db, 'ranking'), orderBy('score', 'desc'), limit(count)))
  return snap.docs.map((d) => ({ uid: d.id, name: d.data().name, score: d.data().score }))
}

/** Posição de quem tem essa pontuação (quantos têm mais + 1). */
export async function getRankingPosition(score) {
  const { db, collection, query, where, getCountFromServer } = await firebase()
  const snap = await getCountFromServer(query(collection(db, 'ranking'), where('score', '>', score)))
  return snap.data().count + 1
}

// ---------------------------------------------------------------- mensagens

const MESSAGES = {
  'name-taken': 'Esse nome já está sendo usado. Escolha outro.',
  'auth/invalid-email': 'E-mail inválido.',
  'auth/missing-email': 'Digite o seu e-mail.',
  'auth/missing-password': 'Digite a sua senha.',
  'auth/email-already-in-use': 'Já existe uma conta com esse e-mail.',
  'auth/weak-password': 'A senha precisa ter pelo menos 6 caracteres.',
  'auth/invalid-credential': 'E-mail ou senha incorretos.',
  'auth/wrong-password': 'E-mail ou senha incorretos.',
  'auth/user-not-found': 'E-mail ou senha incorretos.',
  'auth/user-disabled': 'Essa conta foi desativada.',
  'auth/too-many-requests': 'Muitas tentativas. Espere um pouco e tente de novo.',
  'auth/network-request-failed': 'Sem conexão com a internet.',
  'auth/popup-closed-by-user': 'A janela do Google foi fechada antes de terminar.',
  'auth/cancelled-popup-request': 'A janela do Google foi fechada antes de terminar.',
  'auth/popup-blocked': 'O navegador bloqueou a janela do Google. Libere pop-ups para este site.',
  'auth/unauthorized-domain': 'Este endereço não está autorizado no Firebase (Authentication → Domínios autorizados).',
  'auth/operation-not-allowed': 'Esse tipo de login não está ativado no Firebase.',
  'permission-denied': 'Sem permissão no banco de dados. Confira as regras do Firestore.',
}

export function errorMessage(error) {
  const code = error?.code ?? ''
  return MESSAGES[code] ?? (error instanceof AuthError ? code : 'Algo deu errado. Tente de novo.')
}
