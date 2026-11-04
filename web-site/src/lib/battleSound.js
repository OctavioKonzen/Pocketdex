// Sons da batalha (assets/database/sounds, feitos por tool/build_battle_sounds.py:
// sintetizados, nada copiado de jogo). Igual ao app (lib/services/battle_sounds.dart).
// Efeitos e música podem ser desligados nas Configurações.

import { usePrefs } from './prefs'

const BASE = import.meta.env.BASE_URL
const url = (name) => `${BASE}sounds/${name}.mp3`
const cache = new Map()

/** Um efeito: hit, super, weak, faint, throw, open, recall, statup, statdown, heal, select, victory, mega, dmax. */
export function playSound(name, volume = 0.6, from = 0) {
  if (!usePrefs.getState().battleSounds || typeof Audio === 'undefined') return
  try {
    // Uma cópia por vez (dois golpes seguidos tocam os dois).
    const base = cache.get(name) ?? new Audio(url(name))
    cache.set(name, base)
    const audio = base.cloneNode()
    audio.volume = volume
    if (from > 0) audio.currentTime = from
    audio.play().catch(() => {})
  } catch {
    // Sem som: a batalha continua.
  }
}

// A música em loop toca pela Web Audio (o loop emenda amostra por amostra, sem buraco), a partir do
// OGG (o MP3 põe um silêncio no começo e no fim, que vira um buraco a cada volta). Sem OGG (alguns
// Safari), a reserva em MP3 (sounds/web/). Igual ao app, que toca o OGG com ANDROID_LOOP.
let ogg = null
const musicUrl = (track) => {
  if (ogg == null) {
    try {
      ogg = typeof Audio !== 'undefined' && new Audio().canPlayType('audio/ogg; codecs="vorbis"') !== ''
    } catch {
      ogg = false
    }
  }
  return ogg ? `${BASE}sounds/${track}.ogg` : `${BASE}sounds/web/${track}.mp3`
}
let ctx = null
let gain = null
let source = null
let current = null // a faixa pedida agora (mesmo carregando)
let wanted = false
const buffers = new Map()

function audioContext() {
  if (ctx) return ctx
  const Ctx = typeof window !== 'undefined' && (window.AudioContext || window.webkitAudioContext)
  if (!Ctx) return null
  ctx = new Ctx()
  gain = ctx.createGain()
  gain.connect(ctx.destination)
  return ctx
}

function bufferOf(track) {
  if (!buffers.has(track)) {
    const p = fetch(musicUrl(track))
      .then((r) => r.arrayBuffer())
      .then((data) => new Promise((resolve, reject) => ctx.decodeAudioData(data, resolve, reject)))
    p.catch(() => buffers.delete(track)) // falhou (sem rede): tenta de novo na próxima
    buffers.set(track, p)
  }
  return buffers.get(track)
}

function stopSource() {
  try {
    source?.stop()
  } catch {
    // Já tinha parado.
  }
  source = null
}

/**
 * O estouro da fanfarra da Mega e do Dynamax cai em 0,7 s, o clarão da animação em 1x. Mais rápido
 * (2x, 4x), o clarão vem antes: o som começa adiantado (em segundos) para o estouro continuar junto. Igual ao app.
 */
export const HIT_AT = 0.7
export const syncedStart = (speed) => (speed <= 1 ? 0 : HIT_AT - HIT_AT / speed)

/** O volume da música no tocador: 0,6 × o das Configurações (0,5 dá o 0,3 de sempre). Igual ao app. */
export const musicLevel = () => 0.6 * (usePrefs.getState().musicVolume ?? 0.5)

/** Mudou o volume nas Configurações: a música que está tocando acompanha. */
export function applyVolume() {
  try {
    if (gain) gain.gain.value = musicLevel()
  } catch {
    // Sem som.
  }
}

/** A música está tocando esta faixa? (a Mega e o Dynamax só trocam para o tema épico uma vez.) */
export const isPlaying = (track) => Boolean(wanted && current === track)

/** A música em loop: battle_music, gym_<região> (líderes), champion_<nome>, place_<lugar>, map_<região> (mapa do Pokelike), mega_theme (depois da Mega Evolução) ou dmax_theme (depois do Dynamax). */
export function startMusic(track = 'battle_music') {
  if (!usePrefs.getState().battleMusic) return
  try {
    const c = audioContext()
    if (!c) return
    wanted = true
    current = track
    stopSource()
    if (!document.hidden) c.resume().catch(() => {})
    bufferOf(track)
      .then((buffer) => {
        // Saiu da batalha ou pediu outra faixa enquanto carregava: não começa.
        if (!wanted || current !== track) return
        stopSource()
        source = c.createBufferSource()
        source.buffer = buffer
        source.loop = true
        source.connect(gain)
        gain.gain.value = musicLevel()
        source.start()
      })
      .catch(() => {})
  } catch {
    // Sem som.
  }
}

/** Para a música; com [track], só se for ela que está tocando (o mapa saindo não para a da batalha que entrou). */
export function stopMusic(track) {
  if (track && current !== track) return
  wanted = false
  current = null
  stopSource()
}

// Aba escondida ou navegador minimizado: a música pausa; voltando, continua. Igual ao app.
if (typeof document !== 'undefined') {
  document.addEventListener('visibilitychange', () => {
    try {
      if (!ctx) return
      if (document.hidden) ctx.suspend().catch(() => {})
      else if (wanted) ctx.resume().catch(() => {})
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
    if (/^statUp/.test(event.key ?? '') || event.key === 'levelUp') return 'statup'
    if (/^statDown/.test(event.key ?? '')) return 'statdown'
  }
  return null
}
