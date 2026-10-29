// A velocidade da batalha (⏩ na faixa do campo): 1× ou 2×. Em 2×, as esperas
// entre os textos e as animações andam no dobro. Fica guardada neste
// navegador. Igual ao app (lib/services/battle_speed.dart).

import { useEffect } from 'react'
import { create } from 'zustand'

const KEY = 'pocketdex-battle-speed'
const saved = () => {
  try {
    return Number(localStorage.getItem(KEY)) === 2 ? 2 : 1
  } catch {
    return 1
  }
}

export const useBattleSpeed = create(() => ({ speed: saved() }))

export function toggleBattleSpeed() {
  const speed = useBattleSpeed.getState().speed === 1 ? 2 : 1
  useBattleSpeed.setState({ speed })
  try {
    localStorage.setItem(KEY, String(speed))
  } catch { /* sem armazenamento: só nesta página */ }
}

/** A espera de ms na velocidade de agora. */
export const fast = (ms) => Math.round(ms / useBattleSpeed.getState().speed)

/** Enquanto a batalha está aberta, as animações (CSS) andam na velocidade escolhida. */
export function useBattleAnimationSpeed() {
  const speed = useBattleSpeed((s) => s.speed)
  useEffect(() => {
    if (speed === 1 || typeof document === 'undefined' || !document.getAnimations) return undefined
    const tick = () => document.getAnimations().forEach((a) => { if (a.playbackRate !== speed) a.playbackRate = speed })
    tick()
    const id = setInterval(tick, 80)
    return () => {
      clearInterval(id)
      document.getAnimations().forEach((a) => { a.playbackRate = 1 })
    }
  }, [speed])
}
