// A batalha de um andar da Battle Factory (lib/factoryRun.js): o seu time
// (com os níveis, itens e bônus da corrida) contra o que apareceu no andar.
// Igual ao app (FactoryBattle em lib/services/factory_run.dart).

import { battleMons } from './battleSetup'
import { getFactoryData, getMoves, getPokemonById, getSpecies } from './data'
import { bagsFor, battleOrder, captureFor, foeMember, memberOf, movesAt } from './factoryRun'
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
  const battle = newBattle(a, b, seededRandom(seed >>> 0), { ai: 'normal', seed: seed >>> 0, bags: bagsFor(run), healPct: true, capture: captureFor(run, data) })
  battle.members = { mine, theirs }
  battle.factoryOrder = order
  return battle
}

/** Como o time terminou a batalha (para winFloor): a parte do HP de cada um, na ordem da corrida, a Bolsa e se capturou o selvagem. */
export function factoryAfter(battle, run) {
  const hp = run.team.map((m) => m.hp ?? 1)
  battle.factoryOrder?.forEach((teamIndex, slot) => {
    const mon = battle.sides[0].team[slot]
    if (mon) hp[teamIndex] = mon.maxHp ? Math.round((Math.max(0, mon.hp) / mon.maxHp) * 1000) / 1000 : 0
  })
  return { hp, bag: { ...battle.bags[0] }, captured: battle.captured != null }
}

/** Quem é o adversário do andar: o chefe (nome, treinador e música) ou um selvagem (sem treinador). */
export function factoryFoe(run) {
  const { kind, boss } = run.encounter
  return {
    foeName: boss?.name ?? '',
    foeTrainer: boss?.trainer || null,
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
