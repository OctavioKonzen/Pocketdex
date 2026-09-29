// Idiomas do site: português (original), inglês, francês e espanhol.
//
// O site é escrito em português; o dicionário (src/i18n/ui.json, gerado de
// tool/i18n/ui.json — o mesmo do app) tem a tradução de cada texto. Com outro
// idioma escolhido, os textos da tela são trocados na hora em que aparecem
// (inclusive os com partes variáveis, como "123 Pokémon"), e os nomes dos
// Pokémon viram os oficiais do idioma (Bulbasaur → Bulbizarre em francês).
// Nomes de golpes, habilidades e itens continuam os originais.

import ui from '../i18n/ui.json'

export const LANGUAGES = [
  { code: 'pt', label: 'Português', flag: '🇧🇷' },
  { code: 'en', label: 'English', flag: '🇺🇸' },
  { code: 'fr', label: 'Français', flag: '🇫🇷' },
  { code: 'es', label: 'Español', flag: '🇪🇸' },
]
const INDEX = { en: 0, fr: 1, es: 2, pt: 3 }
const KEY = 'pocketdex-language'

function detect() {
  try {
    const saved = localStorage.getItem(KEY)
    if (saved && INDEX[saved] !== undefined) return saved
  } catch {
    // sem localStorage
  }
  const nav = (navigator.language || 'pt').slice(0, 2)
  return INDEX[nav] !== undefined ? nav : 'pt'
}

export const language = detect()

/** Troca o idioma (recarrega a página para tudo aparecer no idioma novo). */
export function setLanguage(code) {
  try {
    localStorage.setItem(KEY, code)
  } catch {
    // sem localStorage: vale só até recarregar
  }
  window.location.reload()
}

// ------------------------------------------------------------------ dicionário

const exact = new Map()
const patterns = []
for (const [pt, tr] of Object.entries(ui)) {
  const text = language === 'pt' ? tr[3] : tr[INDEX[language]]
  if (!text || text === pt) continue
  if (/\{\d+\}/.test(pt)) {
    const parts = pt.split(/(\{\d+\})/)
    const order = []
    const source = parts
      .map((part) => {
        const m = /^\{(\d+)\}$/.exec(part)
        if (!m) return part.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
        order.push(Number(m[1]))
        return '(.+?)'
      })
      .join('')
    patterns.push({ re: new RegExp(`^${source}$`, 's'), order, text, fixed: pt.replace(/\{\d+\}/g, '').length })
  } else {
    exact.set(pt, text)
  }
}
// Os modelos mais específicos (mais texto fixo) primeiro.
patterns.sort((a, b) => b.fixed - a.fixed)

/** Nome oficial do Pokémon no idioma (preenchido por loadPokemonNames). */
const names = new Map()
const cache = new Map()
// Textos que o próprio tradutor gerou: não são traduzidos de novo.
const produced = new Set()

/** Tradução de um texto (sem tradução: o próprio texto). */
export function t(text) {
  if (language === 'pt' && !exact.size) return text
  if (typeof text !== 'string') return text
  const trimmed = text.replace(/\s+/g, ' ').trim()
  if (!trimmed) return text
  if (produced.has(trimmed)) return text
  let out = cache.get(trimmed)
  if (out === undefined) {
    out = exact.get(trimmed) ?? names.get(trimmed) ?? null
    if (out === null) {
      for (const p of patterns) {
        const m = p.re.exec(trimmed)
        if (m) {
          out = p.text.replace(/\{(\d+)\}/g, (_, n) => {
            const value = m[p.order.indexOf(Number(n)) + 1] ?? ''
            return names.get(value) ?? exact.get(value) ?? value
          })
          break
        }
      }
    }
    if (out === null) out = trimmed
    cache.set(trimmed, out)
    if (out !== trimmed) produced.add(out)
  }
  if (out === trimmed) return text
  // Mantém os espaços das pontas (texto grudado em negrito, links...).
  const start = /^\s/.test(text) ? ' ' : ''
  const end = /\s$/.test(text) ? ' ' : ''
  return start + out + end
}

/** Texto no idioma escolhido a partir de {en, fr, es} (português: `pt`). */
export const pick = (pt, others) => (language === 'pt' ? pt : others?.[language] || pt)

// ------------------------------------------------------------------ nomes dos Pokémon

const cap = (s) => (s ? s[0].toUpperCase() + s.slice(1) : s)

/** Nomes oficiais no idioma (do índice do site: {name, names: {en, fr, es}}). */
export function loadPokemonNames(index) {
  if (language === 'pt' || language === 'en') return
  const seen = new Map()
  for (const p of index) {
    if (!p.default) continue
    const local = p.names?.[language] ?? p.names?.en
    if (!local) continue
    // Como o site mostra o nome: "Bulbasaur", "Mr mime", "Mr" (primeira parte).
    for (const key of [cap(p.name), cap(p.name.replace(/-/g, ' ')), cap(p.name.split('-')[0]), p.names?.en]) {
      if (!key) continue
      if (seen.has(key) && seen.get(key) !== local) seen.set(key, null) // ambíguo: não troca
      else seen.set(key, local)
    }
  }
  for (const [key, local] of seen) if (local) names.set(key, local)
  cache.clear()
}

// ------------------------------------------------------------------ tela

const ATTRS = ['placeholder', 'title', 'aria-label', 'alt']
const SKIP = new Set(['SCRIPT', 'STYLE', 'TEXTAREA', 'INPUT', 'CODE', 'PRE'])

function translateNode(node) {
  if (node.nodeType === Node.TEXT_NODE) {
    const parent = node.parentElement
    if (!parent || SKIP.has(parent.tagName) || parent.closest('[data-no-translate]')) return
    const next = t(node.nodeValue)
    if (next !== node.nodeValue) node.nodeValue = next
    return
  }
  if (node.nodeType !== Node.ELEMENT_NODE || SKIP.has(node.tagName) || node.hasAttribute('data-no-translate')) {
    if (node.nodeType === Node.ELEMENT_NODE && (node.tagName === 'INPUT' || node.tagName === 'TEXTAREA')) translateAttrs(node)
    return
  }
  translateAttrs(node)
  for (const child of node.childNodes) translateNode(child)
}

function translateAttrs(el) {
  for (const attr of ATTRS) {
    const value = el.getAttribute(attr)
    if (value) {
      const next = t(value)
      if (next !== value) el.setAttribute(attr, next)
    }
  }
}

/** Traduz a tela e tudo o que aparecer depois (só quando o idioma não é o original). */
export function startTranslating() {
  if (language === 'pt' && !exact.size) return
  document.documentElement.lang = language === 'pt' ? 'pt-BR' : language
  translateNode(document.body)
  new MutationObserver((mutations) => {
    for (const m of mutations) {
      if (m.type === 'characterData') translateNode(m.target)
      else if (m.type === 'attributes') translateAttrs(m.target)
      else m.addedNodes.forEach(translateNode)
    }
  }).observe(document.body, { childList: true, subtree: true, characterData: true, attributes: true, attributeFilter: ATTRS })
}

// ------------------------------------------------------------------ descrições

let texts = null

/** Descrições de golpes, habilidades e itens no idioma (data/texts_<idioma>.json). */
export async function loadTexts() {
  if (language === 'pt') return
  try {
    const res = await fetch(`${import.meta.env.BASE_URL}data/texts_${language}.json`)
    texts = await res.json()
  } catch {
    texts = null
  }
}

/** Descrição no idioma; em português (ou sem tradução), `fallback`. kind: 'moves' | 'abilities' | 'items'. */
export const localText = (kind, name, fallback) => (language === 'pt' ? fallback : texts?.[kind]?.[name] || fallback)

/** O texto em português extra (a descrição do jogo) só aparece em português. */
export const showPortugueseExtra = language === 'pt'
