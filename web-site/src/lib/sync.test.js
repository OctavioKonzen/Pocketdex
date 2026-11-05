// Fechando o app/aba antes de gravar na conta: ao abrir de novo, o que foi jogado vai para a conta (e a conta, mais
// antiga, não apaga). O Pokelike salvava a batalha e os andares, mas a conta velha voltava por cima.
import { beforeEach, describe, expect, it, vi } from 'vitest'

const memory = new Map()
globalThis.localStorage = {
  getItem: (k) => (memory.has(k) ? memory.get(k) : null),
  setItem: (k, v) => memory.set(k, String(v)),
  removeItem: (k) => memory.delete(k),
  clear: () => memory.clear(),
}
globalThis.document = { visibilityState: 'visible', addEventListener: () => {} }
globalThis.window = { addEventListener: () => {}, localStorage: globalThis.localStorage }

const remote = { callback: null, saved: [], fail: false }
// Cada "abrir o app" tem a sua conta conectada (o módulo da conta novo, como numa página nova).
const authModule = async () => {
  const { create } = await import('zustand')
  return {
    useAuth: create(() => ({ status: 'signedOut', user: null })),
    watchUserData: async (uid, callback) => {
      remote.callback = callback
      return () => {}
    },
    saveUserData: async (uid, data) => {
      if (remote.fail) throw new Error('offline')
      remote.saved.push(data)
    },
    publishProfile: async () => {},
    publishTeams: async () => {},
    setDefense: async () => {},
    saveRanking: async () => {},
    signOut: async () => {},
  }
}

async function open() {
  vi.resetModules()
  vi.doMock('./auth', authModule)
  const sync = await import('./sync')
  const { useAuth } = await import('./auth')
  const { useStore } = await import('./store')
  sync.startSync()
  useAuth.setState({ status: 'signedIn', user: { uid: 'u1', name: 'Ash' } })
  await vi.waitFor(() => expect(remote.callback).not.toBeNull())
  return { useStore, sync }
}

describe('sincronização com a conta', () => {
  beforeEach(() => {
    memory.clear()
    remote.callback = null
    remote.saved = []
    remote.fail = false
  })

  it('o que não chegou na conta não é apagado pela conta mais antiga ao abrir de novo', async () => {
    let { useStore, sync } = await open()
    remote.callback({ league: { factory: { run: { floor: 1 } } } })
    expect(useStore.getState().league.factory.run.floor).toBe(1)
    // Jogou (andar 5) e fechou antes de gravar (sem internet).
    remote.fail = true
    useStore.setState({ league: { factory: { run: { floor: 5 } } } })
    expect(JSON.parse(memory.get('pocketdex-sync-dirty')).keys).toContain('league')
    // Não chegou na conta: o ☁️ aparece.
    await vi.waitFor(() => expect(sync.useSyncState.getState().unsynced).toBe(true), { timeout: 3000 })

    // Abre de novo: a conta ainda está no andar 1.
    remote.fail = false
    remote.callback = null
    ;({ useStore, sync } = await open())
    remote.callback({ league: { factory: { run: { floor: 1 } } } })
    expect(useStore.getState().league.factory.run.floor).toBe(5)
    await vi.waitFor(() => expect(remote.saved.at(-1)?.league?.factory?.run?.floor).toBe(5), { timeout: 3000 })
    await vi.waitFor(() => expect(memory.has('pocketdex-sync-dirty')).toBe(false))
    expect(sync.useSyncState.getState().unsynced).toBe(false)
  })

  it('sem nada esperando, a conta (de outro aparelho) chega normalmente', async () => {
    const { useStore } = await open()
    remote.callback({ league: { factory: { run: { floor: 9 } } } })
    expect(useStore.getState().league.factory.run.floor).toBe(9)
  })
})
