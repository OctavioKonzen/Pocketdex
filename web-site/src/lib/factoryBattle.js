// A batalha de um andar da Battle Factory (lib/factoryRun.js): o seu time
// (com os níveis, itens e bônus da corrida) contra o que apareceu no andar.
// Igual ao app (FactoryBattle em lib/services/factory_run.dart).

import { battleMons } from './battleSetup'
import { getMoves, getPokemonById, getSpecies } from './data'
import { bagsFor, foeMember, memberOf, movesAt } from './factoryRun'
import { seededRandom } from './league'
import { newBattle } from './turnBattle'

/** Os golpes que o Pokémon (id) sabe no nível. */
async function movesFor(id, level) {
  const [byId, moves] = await Promise.all([getPokemonById(), getMoves()])
  const entry = byId.get(id)
  const species = await getSpecies(entry?.species ?? id)
  const form = species.forms.find((f) => f.id === id) ?? species.forms[0]
  return movesAt(form.moves, level, form.types, moves)
}

/** Monta a batalha do andar atual da corrida. */
export async function factoryBattle(run) {
  const mine = await Promise.all(run.team.map(async (m) => memberOf(run, m, await movesFor(m.id, m.level))))
  const theirs = await Promise.all(run.encounter.foes.map(async (f) => foeMember(f, await movesFor(f.id, f.level))))
  const [a, b] = await Promise.all([battleMons(mine), battleMons(theirs)])
  if (!a.length || !b.length) throw new Error('Não foi possível montar a batalha do andar.')
  const seed = run.seed ^ (run.floor * 2654435761)
  const battle = newBattle(a, b, seededRandom(seed >>> 0), { ai: 'normal', seed: seed >>> 0, bags: bagsFor(run) })
  battle.members = { mine, theirs }
  return battle
}
