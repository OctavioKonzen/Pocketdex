import { describe, expect, it } from 'vitest'
import { decodeReplay, encodeReplay, replayUrl } from './replayLink'

describe('replay por link', () => {
  it('codifica e decodifica a batalha (só o necessário), e recusa código estragado', async () => {
    const record = { id: 'x', seed: 42, ai: 'normal', foe: 'Brock', foeTrainer: 'brock', mine: [{ id: 6, set: { level: 50 } }], theirs: [{ id: 95, set: null }], actions: [{ move: 0, gimmick: 'none' }], result: 'win', turns: 3, at: 5, kos: { 0: 1 } }
    const code = await encodeReplay(record)
    expect(code).toMatch(/^[A-Za-z0-9_-]+$/)
    const back = await decodeReplay(code)
    expect(back).toEqual({ id: 'link', seed: 42, ai: 'normal', foe: 'Brock', foeTrainer: 'brock', mine: record.mine, theirs: record.theirs, actions: record.actions, result: 'win', turns: 3, at: 5 })
    expect(await decodeReplay('estragado')).toBe(null)
    expect(replayUrl(code)).toBe(`https://octaviokonzen.github.io/Pocketdex/#/batalha/replay?d=${code}`)
  })
  it('o mesmo código do app (test/replay_link_test.dart)', async () => {
    // Gerado pelo app: ReplayLink.encode({'seed': 1, 'mine': [{'id': 25}], 'theirs': [{'id': 1}], 'actions': []}).
    const back = await decodeReplay(APP_CODE)
    expect(back).toEqual({ id: 'link', seed: 1, mine: [{ id: 25 }], theirs: [{ id: 1 }], actions: [] })
  })
})

const APP_CODE = 'q1YqTk1NUbIy1FHKzcxLVbKKrlbKTFGyMjKtjdVRKslIzSwqhgsagsQSk0sy8_NAgrG1AA'
