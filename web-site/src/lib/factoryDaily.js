// Missões diárias do Pokelike (igual ao app: lib/services/factory_daily.dart).
// Três por dia, as mesmas para todos (sorteadas pela data de Brasília). O
// progresso sai da diferença entre a corrida salva antes e a de agora
// (saveFactory); cada missão cumprida dá moedas.
//
//   factory.daily = {day, p: {tipo: progresso}, done: [tipos], streak}

import { dayKey, seededRandom, seedOf } from './league'
import { HEAL_TIERS } from './factoryRun'

export const MISSIONS = {
  defeat: { label: 'Derrote {0} Pokémon', counts: [8, 15], coins: 40 },
  floors: { label: 'Suba {0} andares', counts: [5, 10], coins: 40 },
  boss: { label: 'Vença {0} chefes', one: 'Vença um chefe', counts: [1, 2], coins: 60 },
  catch: { label: 'Capture {0} Pokémon novos na corrida', one: 'Capture um Pokémon novo na corrida', counts: [1, 3], coins: 50 },
  noPotion: { label: 'Suba {0} andares seguidos sem usar poção', counts: [3, 5], coins: 70 },
}

/** O texto da missão (no singular quando é uma só). */
export const missionLabel = (kind, count) => (count === 1 && MISSIONS[kind].one) || MISSIONS[kind].label

/** As três missões do dia: [{kind, count, coins}]. */
export function dailyMissions(day = dayKey()) {
  const random = seededRandom(seedOf(`pocketdex-missions-${day}`))
  const kinds = Object.keys(MISSIONS)
  const out = []
  while (out.length < 3) {
    const kind = kinds.splice(Math.floor(random() * kinds.length), 1)[0]
    const m = MISSIONS[kind]
    const big = random() < 0.5
    out.push({ kind, count: m.counts[big ? 1 : 0], coins: m.coins + (big ? 30 : 0) })
  }
  return out
}

/** O estado de hoje (zerado quando o dia vira). */
export const dailyOf = (factory, day = dayKey()) => (factory?.daily?.day === day ? factory.daily : { day, p: {}, done: [], streak: 0 })

const heals = (run) => HEAL_TIERS.reduce((sum, k) => sum + (run?.bag?.[k] ?? 0), 0)
const dex = (run) => run?.dex?.length ?? (run?.starter != null ? 1 : 0)

/** O que mudou de [prev] para [next] (a mesma corrida; uma nova começa do zero). */
function deltas(prev, next) {
  if (!next) return null
  const same = prev && next.floor >= prev.floor && next.defeated >= prev.defeated && (next.bosses ?? 0) >= (prev.bosses ?? 0)
  const base = same ? prev : { floor: 1, defeated: 0, bosses: 0, bag: next.bag, dex: next.dex?.slice(0, 1), starter: next.starter }
  return {
    defeat: next.defeated - base.defeated,
    floors: next.floor - base.floor,
    boss: (next.bosses ?? 0) - (base.bosses ?? 0),
    catch: Math.max(0, dex(next) - dex(base)),
    // Usou poção: a soma das poções na Bolsa caiu (comprar só aumenta).
    potion: same && heals(next) < heals(prev),
  }
}

/** A Factory com o progresso das missões de hoje (e as moedas das cumpridas). */
export function trackDaily(prev, next, day = dayKey()) {
  const d = deltas(prev?.run, next?.run)
  if (!d) return next
  const missions = dailyMissions(day)
  const daily = dailyOf(next, day)
  const p = { ...daily.p }
  const streak = d.potion ? 0 : daily.streak + d.floors
  let coins = 0
  const done = [...daily.done]
  for (const { kind, count, coins: reward } of missions) {
    const value = kind === 'noPotion' ? Math.max(p[kind] ?? 0, streak) : (p[kind] ?? 0) + Math.max(0, d[kind])
    p[kind] = Math.min(count, value)
    if (p[kind] >= count && !done.includes(kind)) {
      done.push(kind)
      coins += reward
    }
  }
  const changed = coins || streak !== daily.streak || missions.some(({ kind }) => p[kind] !== (daily.p[kind] ?? 0)) || daily !== next.daily
  if (!changed) return next
  return { ...next, coins: (next.coins ?? 0) + coins, daily: { day, p, done, streak } }
}
