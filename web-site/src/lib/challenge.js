// Desafio entre amigos: um código com a semente da sequência de Pokémon, a
// geração, o modo e a pontuação de quem desafiou. Quem recebe joga os mesmos
// 10 Pokémon e compara. Não precisa de banco: tudo vai no próprio código.

export const CHALLENGE_ROUNDS = 10

/** Gerador de números com semente (mesma sequência no app e no site). */
export function seeded(seed) {
  let a = seed >>> 0
  return () => {
    a = (a + 0x6d2b79f5) >>> 0
    let t = a
    t = Math.imul(t ^ (t >>> 15), t | 1)
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

/** As 10 rodadas do desafio: [{answerId, options}] a partir da semente. */
export function challengeRounds(pool, seed) {
  const rng = seeded(seed)
  const ids = [...pool.map((p) => p.id)].sort((a, b) => a - b)
  const rounds = []
  const used = new Set()
  while (rounds.length < Math.min(CHALLENGE_ROUNDS, ids.length)) {
    const answerId = ids[Math.floor(rng() * ids.length)]
    if (used.has(answerId)) continue
    used.add(answerId)
    const options = [answerId]
    while (options.length < Math.min(4, ids.length)) {
      const id = ids[Math.floor(rng() * ids.length)]
      if (!options.includes(id)) options.push(id)
    }
    // Embaralha as opções com a mesma semente.
    for (let i = options.length - 1; i > 0; i--) {
      const j = Math.floor(rng() * (i + 1))
      ;[options[i], options[j]] = [options[j], options[i]]
    }
    rounds.push({ answerId, options })
  }
  return rounds
}

const toBase64Url = (text) => btoa(unescape(encodeURIComponent(text))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
const fromBase64Url = (code) => decodeURIComponent(escape(atob(code.replace(/-/g, '+').replace(/_/g, '/'))))

/** Código do desafio: {seed, gen, hint, name, score}. */
export function encodeChallenge({ seed, gen, hint, name, score }) {
  return toBase64Url(JSON.stringify({ s: seed, g: gen, h: hint, n: name, p: score }))
}

/** Lê um código (ou link) de desafio; null se não for válido. */
export function decodeChallenge(text) {
  try {
    const code = (text.match(/desafio=([\w-]+)/)?.[1] ?? text).trim()
    const d = JSON.parse(fromBase64Url(code))
    if (!Number.isInteger(d.s)) return null
    return { seed: d.s, gen: Number(d.g) || 0, hint: d.h || 'silhouette', name: String(d.n || '').slice(0, 20), score: Number(d.p) || 0 }
  } catch {
    return null
  }
}

export const challengeLink = (code) => `${window.location.origin}${import.meta.env.BASE_URL}#/jogo?desafio=${code}`

/** Modos de pista do jogo normal e do desafio. */
export const HINTS = [
  { key: 'silhouette', label: 'Silhueta', icon: '👤' },
  { key: 'cry', label: 'Grito', icon: '🔊' },
  { key: 'description', label: 'Descrição', icon: '📖' },
  { key: 'types', label: 'Tipos', icon: '🔥' },
]
