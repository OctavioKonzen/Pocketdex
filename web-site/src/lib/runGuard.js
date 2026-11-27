// A corrida do Pokelike aberta em dois aparelhos: quando a conta traz uma
// corrida diferente da daqui (continuada no app ou em outra aba), a batalha
// velha daqui fecha e avisa — senão o fim dela gravaria por cima do que foi
// jogado lá. Igual ao app (lib/services/run_guard.dart).
import { create } from 'zustand'

/** Sobe a cada corrida continuada em outro aparelho. */
export const useRunTakeover = create(() => ({ count: 0 }))

const runOf = (league) => league?.factory?.run ?? null

/** O JSON com as chaves em ordem: a conta devolve os campos em outra ordem e não é mudança. */
export const canonical = (v) => JSON.stringify(v ?? null, (_, x) => (x && typeof x === 'object' && !Array.isArray(x) ? Object.fromEntries(Object.entries(x).sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))) : x))

/** before e after: a "league" da conta antes e depois do que veio de fora. */
export function runChanged(before, after) {
  const old = runOf(before)
  // Sem corrida aqui (ou já acabada) não tem o que perder.
  return old != null && canonical(old) !== canonical(runOf(after))
}

export const noteTakeover = () => useRunTakeover.setState((s) => ({ count: s.count + 1 }))
