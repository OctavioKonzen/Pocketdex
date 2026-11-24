// Raid da semana: um chefe gigante (Dynamax ou Tera) por semana, com uma barra
// de vida enorme dividida entre você e seus amigos. Cada um luta com ele até
// RAID_TRIES vezes por dia; o dano de cada luta soma na conta
// (raids/{semana}/hits/{uid}). Quando o total do grupo chega à barra, cada um
// pega o prêmio uma vez. Igual ao app (lib/services/raid.dart).

import { dayKey, weekKey } from './league'

export const RAID_POOL = 1500
export const RAID_TRIES = 3
export const RAID_COINS = 400
export const RAID_MAX_HIT = 100
export const RAID_BOSSES = [6, 130, 143, 94, 149, 248, 445, 131, 9, 373, 376, 3, 609, 635, 887, 1000, 25, 448]

function hash(s) {
  let h = 2166136261
  for (let i = 0; i < s.length; i++) h = Math.imul(h ^ s.charCodeAt(i), 16777619) >>> 0
  return h
}

export const raidBoss = (week = weekKey()) => RAID_BOSSES[hash(week) % RAID_BOSSES.length]
export const raidGimmick = (week = weekKey()) => (hash(`g${week}`) % 2 === 0 ? 'dmax' : 'tera')
const STATS = ['hp', 'atk', 'def', 'spa', 'spd', 'spe']
/** O chefe como adversário: nível 75, perfeito e com +50% em tudo. */
export const raidMember = (week = weekKey()) => ({
  id: raidBoss(week),
  set: {
    level: 75, levelCap: 'none', gimmick: raidGimmick(week),
    ivs: Object.fromEntries(STATS.map((s) => [s, 31])), evs: Object.fromEntries(STATS.map((s) => [s, 84])), boost: Object.fromEntries(STATS.map((s) => [s, 0.5])),
  },
})

/** Quanto a luta tirou da vida do chefe (0 a 100). */
export function raidDamage(battle) {
  const boss = battle.sides[1].team[0]
  if (!boss?.maxHp) return 0
  return Math.max(0, Math.min(RAID_MAX_HIT, Math.round(((boss.maxHp - Math.max(0, Math.min(boss.maxHp, boss.hp))) * 100) / boss.maxHp)))
}

export function raidState(factory, week = weekKey()) {
  const s = factory?.raid ?? {}
  return s.week === week ? { ...s } : { week }
}
export function raidTriesLeft(factory, week = weekKey(), day = dayKey()) {
  const s = raidState(factory, week)
  return RAID_TRIES - (s.day === day ? s.tries ?? 0 : 0)
}
export function raidAfterFight(factory, damage, week = weekKey(), day = dayKey()) {
  const s = raidState(factory, week)
  const used = s.day === day ? s.tries ?? 0 : 0
  return { ...factory, raid: { ...s, day, tries: used + 1, mine: (s.mine ?? 0) + damage } }
}
export const raidClaimed = (factory, week = weekKey()) => raidState(factory, week).claimed === true
export function raidClaim(factory, groupTotal, week = weekKey()) {
  if (groupTotal < RAID_POOL || raidClaimed(factory, week)) return factory
  return { ...factory, coins: (factory.coins ?? 0) + RAID_COINS, raid: { ...raidState(factory, week), claimed: true } }
}
