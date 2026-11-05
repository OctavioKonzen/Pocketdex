// Cadeia de golpes de ovo (igual ao app, lib/services/egg_chain.dart): para
// ensinar um golpe de ovo a um filhote, o pai precisa saber o golpe. Se
// nenhum pai compatível aprende sozinho (nível, TM ou tutor), o pai pode ter
// recebido o golpe de ovo do pai dele, e assim por diante.
//
// Dados (tool/build_web_data.py):
//   breeding.json   {espécie: [grupos de ovo, gender_rate, evolui de, golpes de ovo]}
//   egg_moves.json  {golpe: {pokémon: nível (>= 1) | 0 = TM/tutor | -1 = de ovo}}

const BASE = import.meta.env.BASE_URL
let cache = null
const load = () =>
  (cache ??= Promise.all(
    ['breeding.json', 'egg_moves.json'].map((f) =>
      fetch(`${BASE}data/${f}`).then((r) => {
        if (!r.ok) throw new Error(`Falha ao carregar ${f}`)
        return r.json()
      }),
    ),
  ).catch((e) => {
    cache = null
    throw e
  }))

/** Golpes de ovo do Pokémon (slugs, em ordem alfabética). */
export async function eggMoves(id) {
  const [breeding] = await load()
  return breeding[id]?.[3] ?? []
}

/**
 * Cadeias mais curtas (até maxDepth pais) para ensinar move a targetId.
 * Cada cadeia: [{id, method: 'level-up'|'machine'|'egg', level}] do primeiro
 * pai (que aprende sozinho) até o pai direto.
 */
export async function eggChains(targetId, move, { maxDepth = 3, limit = 12 } = {}) {
  const [breeding, learn] = await load()
  const learners = learn[move] ?? {}
  const groups = (id) => {
    const g = breeding[id]?.[0] ?? []
    if (!g.includes('no-eggs')) return g
    // Filhote (Pichu...): usa os grupos de quem ele vira.
    const next = Object.keys(breeding).find((k) => breeding[k][2] === Number(id))
    return next ? groups(next) : g
  }
  const canFather = (id) => {
    const rate = breeding[id]?.[1] ?? -1
    const g = groups(id)
    return rate >= 0 && rate < 8 && !g.includes('no-eggs') && !g.includes('ditto')
  }
  const how = (id) => {
    const code = learners[id]
    if (code === undefined) return null
    return code >= 1 ? { id, method: 'level-up', level: code } : code === 0 ? { id, method: 'machine', level: 0 } : { id, method: 'egg', level: 0 }
  }

  const ids = Object.keys(learners).map(Number)
  const chains = []
  const seen = new Set([targetId])
  let frontier = [[{ id: targetId, method: 'egg', level: 0 }]]
  for (let depth = 0; depth < maxDepth && !chains.length && frontier.length; depth++) {
    const next = []
    for (const path of frontier) {
      const childGroups = new Set(groups(path[0].id))
      for (const id of ids) {
        if (seen.has(id) || !canFather(id) || !groups(id).some((g) => childGroups.has(g))) continue
        const link = how(id)
        if (!link) continue
        if (link.method === 'egg') next.push([link, ...path])
        else chains.push([link, ...path.slice(0, -1)])
      }
    }
    for (const p of next) seen.add(p[0].id)
    frontier = next
  }
  const lvl = (c) => (c[0].method === 'level-up' ? c[0].level : 999)
  return chains.sort((a, b) => lvl(a) - lvl(b)).slice(0, limit)
}
