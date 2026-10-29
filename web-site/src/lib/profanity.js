// Filtro de palavrões para nomes de treinador e de time. Igual no app
// (lib/utils/profanity.dart). Compara o começo de cada palavra, depois de
// tirar acentos, "leetspeak" (p0rr4 → porra) e letras repetidas.

// Começos de palavra proibidos (sem acento, minúsculos).
export const BAD_STEMS = [
  // português
  'porra', 'caralh', 'buceta', 'boceta', 'xoxota', 'xota', 'puta', 'puto', 'putinh', 'fdp', 'vsf', 'vtnc', 'tnc',
  'foda', 'fode', 'foder', 'fodid', 'fuder', 'fudid', 'merda', 'bosta', 'cuzao', 'cuzinh', 'arrombad', 'viado', 'viadinh',
  'bicha', 'traveco', 'piroca', 'pinto', 'rola', 'punheta', 'siririca', 'vagabund', 'vadia', 'corno', 'otario',
  'babaca', 'retardad', 'mongoloid', 'escroto', 'desgracad', 'paunocu', 'filhodaputa', 'filhadaputa', 'macaco',
  'crioulo', 'estupr', 'pedofil', 'nazi', 'hitler',
  // inglês
  'fuck', 'shit', 'bitch', 'cunt', 'dick', 'cock', 'pussy', 'asshole', 'bastard', 'whore', 'slut', 'nigg', 'fag',
  'retard', 'rape', 'porn',
]

// Palavras curtas só contam quando são a palavra inteira ("rola" sim, "rolagem" não).
const EXACT_ONLY = new Set(['rola', 'pinto', 'bicha', 'puto', 'tnc', 'fag', 'dick', 'cock', 'macaco', 'corno', 'rape'])

const LEET = { 0: 'o', 1: 'i', 3: 'e', 4: 'a', 5: 's', 7: 't', 8: 'b', '@': 'a', $: 's', '!': 'i' }

function normalize(text) {
  return (text ?? '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[0134578@$!]/g, (c) => LEET[c])
    .replace(/[^a-z\s]/g, '')
}

const squeeze = (word) => word.replace(/(.)\1+/g, '$1') // "poorraaa" → "pora"

function matches(word) {
  for (const stem of BAD_STEMS) {
    const exact = EXACT_ONLY.has(stem)
    for (const w of [word, squeeze(word)]) {
      const s = w === word ? stem : squeeze(stem)
      if (exact ? w === s : w.startsWith(s)) return true
    }
  }
  return false
}

/** O texto tem palavrão? (também pega palavras separadas por espaço ou ponto: "p o r r a"). */
export function isOffensive(text) {
  const clean = normalize(text)
  const words = clean.split(/\s+/).filter(Boolean)
  if (words.some(matches)) return true
  // Letras soltas juntas ("p o r r a", "f.d.p") viram uma palavra só.
  const joined = clean.replace(/\s+/g, '')
  return words.length > 1 && words.every((w) => w.length <= 2) && matches(joined)
}
