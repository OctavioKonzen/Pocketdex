// Sons da batalha (assets/database/sounds, feitos por tool/build_battle_sounds.py:
// sintetizados, nada copiado de jogo). Igual ao app (lib/services/battle_sounds.dart).
// Efeitos e música podem ser desligados nas Configurações.

import { usePrefs } from './prefs'

const BASE = import.meta.env.BASE_URL
const url = (name) => `${BASE}sounds/${name}.mp3`
const cache = new Map()
let music = null

/** Um efeito: hit, super, weak, faint, throw, open, recall, statup, statdown, heal, select, victory. */
export function playSound(name, volume = 0.6) {
  if (!usePrefs.getState().battleSounds || typeof Audio === 'undefined') return
  try {
    // Uma cópia por vez (dois golpes seguidos tocam os dois).
    const base = cache.get(name) ?? new Audio(url(name))
    cache.set(name, base)
    const audio = base.cloneNode()
    audio.volume = volume
    audio.play().catch(() => {})
  } catch {
    // Sem som: a batalha continua.
  }
}

/** A música da batalha, em loop: battle_music, gym_music (líderes) ou champion_music. */
export function startMusic(track = 'battle_music') {
  if (!usePrefs.getState().battleMusic || typeof Audio === 'undefined') return
  try {
    if (music && !music.src.endsWith(`${track}.mp3`)) music.pause()
    if (!music || !music.src.endsWith(`${track}.mp3`)) music = new Audio(url(track))
    wanted = true
    music.loop = true
    music.volume = 0.3
    music.currentTime = 0
    music.play().catch(() => {})
  } catch {
    // Sem som.
  }
}

export function stopMusic() {
  wanted = false
  try {
    music?.pause()
  } catch {
    // Sem som.
  }
}

// Aba escondida ou navegador minimizado: a música pausa; voltando, continua. Igual ao app.
let wanted = false
if (typeof document !== 'undefined') {
  document.addEventListener('visibilitychange', () => {
    try {
      if (document.hidden) music?.pause()
      else if (wanted) music?.play().catch(() => {})
    } catch {
      // Sem som.
    }
  })
}

/** O som de cada evento da batalha (lastEffect: o último "É super efetivo"/"Não é muito efetivo"). */
export function soundOf(event, lastEffect) {
  if (event.t === 'hp') return lastEffect === 'super' ? 'super' : lastEffect === 'weak' ? 'weak' : 'hit'
  if (event.t === 'faint') return 'faint'
  if (event.t === 'heal') return 'heal'
  if (event.t === 'text') {
    if (/^statUp/.test(event.key ?? '')) return 'statup'
    if (/^statDown/.test(event.key ?? '')) return 'statdown'
  }
  return null
}
