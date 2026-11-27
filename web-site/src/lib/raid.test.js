import { describe, expect, it } from 'vitest'
import { RAID_BOSSES, RAID_COINS, RAID_POOL, raidAfterFight, raidBoss, raidClaim, raidClaimed, raidDamage, raidGimmick, raidMember, raidTriesLeft } from './raid'

describe('raid da semana (igual ao app)', () => {
  it('o chefe e a mecânica são os mesmos para todo mundo na semana', () => {
    expect(RAID_BOSSES).toContain(raidBoss('2026-11-02'))
    expect(['dmax', 'tera']).toContain(raidGimmick('2026-11-02'))
    let h = 2166136261
    for (const c of '2026-11-02') h = Math.imul(h ^ c.charCodeAt(0), 16777619) >>> 0
    expect(raidBoss('2026-11-02')).toBe(RAID_BOSSES[h % RAID_BOSSES.length])
    // O mesmo número do app (raid_test.dart): Salamence nesta semana.
    expect(raidBoss('2026-11-02')).toBe(373)
    expect(raidMember('2026-11-02').set.level).toBe(75)
  })
  it('3 lutas por dia e o prêmio uma vez quando o grupo derruba o chefe', () => {
    let f = { coins: 0 }
    expect(raidTriesLeft(f, 'w', 'd1')).toBe(3)
    for (let i = 0; i < 3; i++) f = raidAfterFight(f, 40, 'w', 'd1')
    expect(raidTriesLeft(f, 'w', 'd1')).toBe(0)
    expect(raidTriesLeft(f, 'w', 'd2')).toBe(3)
    expect(f.raid.mine).toBe(120)
    expect(raidClaim(f, RAID_POOL - 1, 'w').coins).toBe(0)
    f = raidClaim(f, RAID_POOL, 'w')
    expect(f.coins).toBe(RAID_COINS)
    expect(raidClaim(f, RAID_POOL, 'w').coins).toBe(RAID_COINS)
    expect(raidClaimed(f, 'w2')).toBe(false)
  })
  it('o dano da luta: quanto saiu da vida do chefe', () => {
    expect(raidDamage({ sides: [{}, { team: [{ maxHp: 200, hp: 50 }] }] })).toBe(75)
    expect(raidDamage({ sides: [{}, { team: [{ maxHp: 200, hp: 0 }] }] })).toBe(100)
  })
})
