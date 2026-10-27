// Preferências deste navegador (não vão para a conta): tamanho do texto e
// animações da Pokébola (ao abrir um Pokémon e girando no fundo). O tema e o idioma ficam à parte
// (o tema vai para a conta; o idioma, em lib/i18n.js).

import { useSyncExternalStore } from 'react'
import { create } from 'zustand'
import { persist } from 'zustand/middleware'

/** Tamanhos do texto: escala de toda a tela. */
/** Os sprites se mexem ou ficam parados (Configurações). */
export const SPRITE_MOTIONS = [
  { key: 'on', label: 'Animados' },
  { key: 'off', label: 'Parados' },
]

export const TEXT_SIZES = [
  { key: 'normal', label: 'Normal', scale: 1 },
  { key: 'large', label: 'Grande', scale: 1.125 },
  { key: 'larger', label: 'Maior', scale: 1.25 },
]

export const usePrefs = create(
  persist(
    (set) => ({
      textSize: 'normal',
      setTextSize: (textSize) => set({ textSize }),
      pokeballAnimation: true,
      setPokeballAnimation: (pokeballAnimation) => set({ pokeballAnimation }),
      /** Pokébola girando no fundo das páginas. */
      backgroundAnimation: true,
      setBackgroundAnimation: (backgroundAnimation) => set({ backgroundAnimation }),
      /** Sprites animados (estilo Black & White) em todo o site. */
      animatedSprites: true,
      setAnimatedSprites: (animatedSprites) => set({ animatedSprites }),
      /** Sons da batalha (golpes, Poké Ball...) e a música (lib/battleSound.js). */
      battleSounds: true,
      setBattleSounds: (battleSounds) => set({ battleSounds }),
      battleMusic: true,
      setBattleMusic: (battleMusic) => set({ battleMusic }),
    }),
    { name: 'pocketdex-prefs' },
  ),
)

/** Tema de verdade ('dark' | 'light'): 'system' segue o do aparelho. */
export function resolveTheme(theme) {
  if (theme !== 'system') return theme === 'light' ? 'light' : 'dark'
  try {
    return window.matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark'
  } catch {
    return 'dark'
  }
}

function watchSystemTheme(onChange) {
  try {
    const query = window.matchMedia('(prefers-color-scheme: light)')
    query.addEventListener('change', onChange)
    return () => query.removeEventListener('change', onChange)
  } catch {
    return () => {}
  }
}

/** Tema de verdade, que acompanha o aparelho quando o tema é 'system'. */
export function useResolvedTheme(theme) {
  const system = useSyncExternalStore(watchSystemTheme, () => resolveTheme('system'))
  return theme === 'system' ? system : resolveTheme(theme)
}
