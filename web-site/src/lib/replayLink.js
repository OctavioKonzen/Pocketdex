// Replay por link: a batalha inteira (semente, times e jogadas, lib/battleLog.js)
// comprimida (deflate) em base64url num link do site. Quem abre assiste sem
// precisar de conta. Igual ao app (lib/services/replay_link.dart).

const FIELDS = ['seed', 'ai', 'foe', 'foeTrainer', 'mine', 'theirs', 'actions', 'result', 'turns', 'at']

const toBase64Url = (bytes) => {
  let text = ''
  for (const b of bytes) text += String.fromCharCode(b)
  return btoa(text).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}
const fromBase64Url = (code) => {
  const text = atob(code.replace(/-/g, '+').replace(/_/g, '/') + '==='.slice((code.length + 3) % 4))
  return Uint8Array.from(text, (c) => c.charCodeAt(0))
}

async function pipe(bytes, stream) {
  const out = new Blob([bytes]).stream().pipeThrough(stream)
  return new Uint8Array(await new Response(out).arrayBuffer())
}

/** O código do replay (só o que precisa para refazer a batalha). */
export async function encodeReplay(record) {
  const data = Object.fromEntries(FIELDS.filter((k) => record[k] != null).map((k) => [k, record[k]]))
  return toBase64Url(await pipe(new TextEncoder().encode(JSON.stringify(data)), new CompressionStream('deflate-raw')))
}

/** De volta ao registro da batalha (null se o código não vale). */
export async function decodeReplay(code) {
  try {
    const record = JSON.parse(new TextDecoder().decode(await pipe(fromBase64Url(code), new DecompressionStream('deflate-raw'))))
    return record?.seed != null && record.mine?.length && record.theirs?.length ? { id: 'link', ...record } : null
  } catch {
    return null
  }
}

/** O link para assistir (no site publicado; o app usa o mesmo). */
export const SITE_URL = 'https://octaviokonzen.github.io/Pocketdex/'
export const replayUrl = (code) => `${SITE_URL}#/batalha/replay?d=${code}`
