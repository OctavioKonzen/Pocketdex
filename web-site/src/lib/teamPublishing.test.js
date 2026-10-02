import { beforeEach, describe, expect, it, vi } from 'vitest'

const mock = vi.hoisted(() => ({
  getDocs: vi.fn(),
  update: vi.fn(),
  set: vi.fn(),
  commit: vi.fn(async () => {}),
}))
vi.mock('firebase/app', () => ({ initializeApp: () => ({}) }))
vi.mock('firebase/auth', () => ({ getAuth: () => ({}) }))
vi.mock('firebase/firestore', () => ({
  getFirestore: () => ({}),
  collection: (_db, ...parts) => parts.join('/'),
  doc: (_db, ...parts) => parts.join('/'),
  query: (ref) => ref,
  where: () => null,
  getDocs: mock.getDocs,
  writeBatch: () => ({ update: mock.update, set: mock.set, delete: vi.fn(), commit: mock.commit }),
  serverTimestamp: () => 'server-time',
}))
import { publishTeams } from './auth'

describe('publicação de times', () => {
  const team = { id: 'team-1', name: 'Time', color: null, pokemon: [25, null, null, null, null, null] }
  beforeEach(() => vi.clearAllMocks())

  it('preserva votos recebidos depois da leitura do time', async () => {
    const current = { ownerUid: 'alice', name: 'Antigo', ratingSum: 4, ratingCount: 1, reportCount: 0 }
    mock.getDocs.mockImplementation(async () => {
      const snapshot = { docs: [{ id: team.id, data: () => ({ ...current }) }] }
      const result = snapshot.docs[0].data()
      snapshot.docs[0].data = () => result
      // Um voto chega enquanto o cliente prepara a alteração.
      current.ratingSum = 9
      current.ratingCount = 2
      return snapshot
    })
    mock.update.mockImplementation((_ref, fields) => Object.assign(current, fields))
    await publishTeams('alice', 'Alice', null, [team])
    expect(current.name).toBe('Time')
    expect(current.ratingSum).toBe(9)
    expect(current.ratingCount).toBe(2)
    expect(mock.set).not.toHaveBeenCalled()
    expect(mock.commit).toHaveBeenCalledOnce()
  })

  it('cria times novos com contadores zerados', async () => {
    mock.getDocs.mockResolvedValue({ docs: [] })
    await publishTeams('alice', 'Alice', null, [team])
    expect(mock.set).toHaveBeenCalledWith('publicTeams/team-1', expect.objectContaining({
      ratingSum: 0, ratingCount: 0, reportCount: 0,
    }))
  })
})
