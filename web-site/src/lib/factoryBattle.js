// A batalha de um andar da Battle Factory (lib/factoryRun.js): o seu time
// (com os níveis, itens e bônus da corrida) contra o que apareceu no andar.
// Igual ao app (FactoryBattle em lib/services/factory_run.dart).

import { battleMons } from './battleSetup'
import { t } from './i18n'
import { getFactoryData, getMoves, getPokemonById, getSpecies } from './data'
import { bagsFor, battleOrder, bossScene, captureFor, clockOf, fieldOf, isDoubleBattle, weatherOf, EXP_SHARE, expAt, expFactor, expProgress, expShares, foeMember, memberOf, movesAt } from './factoryRun'
import { seededRandom } from './league'
import { newBattle } from './turnBattle'

/** Os golpes que o Pokémon (id) sabe no nível. */
export async function movesFor(id, level) {
  const [byId, moves] = await Promise.all([getPokemonById(), getMoves()])
  const entry = byId.get(id)
  const species = await getSpecies(entry?.species ?? id)
  const form = species.forms.find((f) => f.id === id) ?? species.forms[0]
  return movesAt(form.moves, level, form.types, moves)
}

/**
 * Monta a batalha do andar atual da corrida. Quem está de pé vai na frente
 * (battle.factoryOrder: a posição de cada um no time da corrida, para ler o HP
 * no fim: factoryAfter).
 */
export async function factoryBattle(run) {
  const order = battleOrder(run)
  const data = await getFactoryData()
  const mine = await Promise.all(order.map(async (i) => memberOf(run, run.team[i], await movesFor(run.team[i].id, run.team[i].level), data)))
  const theirs = await Promise.all(run.encounter.foes.map(async (f) => foeMember(f, await movesFor(f.id, f.level))))
  const [a, b] = await Promise.all([battleMons(mine), battleMons(theirs)])
  if (!a.length || !b.length) throw new Error('Não foi possível montar a batalha do andar.')
  const seed = run.seed ^ (run.floor * 2654435761)
  // Selvagem: as Poké Balls da Bolsa funcionam (captureFor: a taxa de captura de cada um).
  // O cenário: o lugar do andar (cidade, floresta, caverna, mar...).
  // Líder de ginásio no ginásio, Elite Four e Campeão na Liga.
  // O líder no ginásio do tipo dele, a Elite Four na Liga, o Campeão na sala dele e o vilão na base da equipe.
  const scene = bossScene(data, run.encounter.boss, run.encounter.scene ?? run.encounter.biome ?? 'grass')
  // E o clima do lugar (sol no deserto, chuva no mar, neve na caverna de gelo...).
  // E o efeito do lugar (terreno, chuva de diamantes, aura sombria...; no céu, ventos fortes).
  const place = fieldOf(run, scene)
  // No inverno (a estação de verdade), neva nos lugares abertos.
  const weather = weatherOf(run, scene, clockOf().season) || (place === 'wind' ? 'wind' : '')
  const field = place === 'wind' ? '' : place
  // A barra de XP (expBarOf) e o XP na hora: o XP de cada um agora e quanto cada adversário derrubado dá para cada um (quem lutou: tudo; com o Exp. Share, o resto: a metade).
  const expBar = {
    mons: order.map((i) => ({ level: run.team[i].level, exp: run.team[i].exp })),
    table: run.encounter.foes.map((f) => { const all = expShares(run, data, f, null, expFactor(run.encounter.kind)); return order.map((i) => all[i]) }),
    share: run.expShare ? EXP_SHARE : 0,
  }
  // Dupla de treinadores a partir do andar DOUBLE_FLOOR: batalha dupla (2 contra 2).
  const doubles = isDoubleBattle(run)
  const battle = newBattle(a, b, seededRandom(seed >>> 0), { ai: 'normal', seed: seed >>> 0, bags: bagsFor(run), healPct: true, capture: captureFor(run, data), weather, field, exp: expBar,
    ...(doubles ? { mode: 'doubles', controllers: [['me', 'me'], ['npc1', 'npc2']] } : {}) })
  battle.members = { mine, theirs }
  battle.scene = scene
  battle.factoryOrder = order
  battle.expBar = expBar
  return battle
}

/** A barra de XP de quem está na posição (slot) da batalha (0 a 1), com o que já ganhou (foeHp: o HP na tela de cada adversário). null fora da Factory. */
export function expBarOf(battle, slot, foeHp) {
  const bar = battle.expBar
  if (!bar?.mons[slot]) return null
  let extra = 0
  bar.table.forEach((row, j) => {
    if ((foeHp?.[j] ?? battle.sides[1].team[j]?.hp) > 0 && battle.captured !== j) return
    extra += battle.fought?.[j]?.includes(slot) ? row[slot] : Math.floor(row[slot] * bar.share)
  })
  // Passou de nível na luta: a barra no nível novo.
  const mon = bar.mons[slot]
  const total = (mon.exp ?? expAt(mon.level)) + extra
  let level = mon.level
  while (total >= expAt(level + 1)) level++
  return expProgress({ level, exp: total })
}

/** Como o time terminou a batalha (para winFloor): a parte do HP de cada um, na ordem da corrida, a Bolsa, se capturou o selvagem e quem lutou contra cada adversário. */
export function factoryAfter(battle, run) {
  const hp = run.team.map((m) => m.hp ?? 1)
  battle.factoryOrder?.forEach((teamIndex, slot) => {
    const mon = battle.sides[0].team[slot]
    if (mon) hp[teamIndex] = mon.maxHp ? Math.round((Math.max(0, mon.hp) / mon.maxHp) * 1000) / 1000 : 0
  })
  // Quem lutou contra cada adversário (posições na corrida), para o XP.
  const fought = run.encounter.foes.map((_, j) => (battle.fought?.[j] ?? []).map((slot) => battle.factoryOrder?.[slot] ?? slot))
  // O XP que cada um ganhou na luta (o motor deu na hora), na ordem da corrida.
  const gained = battle.expNow ? run.team.map(() => 0) : null
  if (gained) Object.entries(battle.expNow.gained ?? {}).forEach(([slot, exp]) => { gained[battle.factoryOrder?.[Number(slot)] ?? Number(slot)] += exp })
  return { hp, bag: { ...battle.bags[0] }, captured: battle.captured != null, fought, ...(gained ? { gained } : {}), ...(battle.capturedBall ? { ball: battle.capturedBall } : {}) }
}

/** Quem é o adversário do andar: o chefe (nome, treinador e música) ou um selvagem (sem treinador). */
/** Os capangas de cada equipe vilã (homem e mulher). Igual ao app. */
export const GRUNT_TRAINERS = {
  rocket: ['sd-rocketgrunt', 'sd-rocketgruntf'], aqua: ['sd-aquagrunt', 'sd-aquagruntf'], magma: ['sd-magmagrunt', 'sd-magmagruntf'],
  galactic: ['sd-galacticgrunt', 'sd-galacticgruntf'], plasma: ['sd-plasmagrunt', 'sd-plasmagruntf'], flare: ['sd-flaregrunt', 'sd-flaregruntf'],
  skull: ['sd-skullgrunt', 'sd-skullgruntf'], aether: ['sd-aetheremployee', 'sd-aetheremployeef'], star: ['sd-stargrunt-s', 'sd-stargruntf-s'],
}

export function factoryFoe(run) {
  const { kind, boss, grunt, trainerSeed, pair } = run.encounter
  return {
    // Dupla de treinadores: os dois juntos.
    foeName: boss?.name ?? (pair ? t('Dupla de treinadores') : ''),
    // Na base de uma equipe vilã, o capanga dela.
    foeTrainer: boss?.trainer || (grunt ? GRUNT_TRAINERS[grunt]?.[(trainerSeed ?? 0) % 2] : null) || null,
    challenge: { kind: 'factory', wild: kind === 'wild' || kind === 'wildboss', ...(boss ? { boss } : {}) },
  }
}

/** Os golpes que ele pode aprender: [golpe, como] da forma (level-up, machine, tutor, egg...). */
export async function learnsetOf(id) {
  const byId = await getPokemonById()
  const species = await getSpecies(byId.get(id)?.species ?? id)
  const form = species.forms.find((f) => f.id === id) ?? species.forms[0]
  return form.moves
}
