/** Allocate one holder for each mechanic; the battle enforces the team budgets. */
export function npcMembers(ids, builds, random, difficulty = 'normal') {
  const members = ids.map(id => {
    const options = builds[id].sets
    return {id, set: structuredClone(options[Math.floor(random() * options.length)])}
  })
  const assigned = new Set()
  const mega = ids.findIndex(id => builds[id].mega.length)
  if (mega >= 0) {
    const options = builds[ids[mega]].mega
    members[mega].set = structuredClone(options[Math.floor(random() * options.length)])
    assigned.add(mega)
  }
  let dmax = ids.findIndex((id, i) => !assigned.has(i) && builds[id].gmax && builds[id].dmax)
  if (dmax < 0) dmax = ids.findIndex((id, i) => !assigned.has(i) && builds[id].dmax)
  if (dmax >= 0) {members[dmax].set.gimmick = 'dmax'; assigned.add(dmax)}
  const z = ids.findIndex((id, i) => !assigned.has(i) && builds[id].z)
  if (z >= 0) {
    // Crystal and attack come from the same template, even when another set was sampled.
    members[z].set = structuredClone(builds[ids[z]].sets[0])
    members[z].set.item = builds[ids[z]].z
    members[z].set.gimmick = 'z'
  }
  if (difficulty !== 'hard') {
    for (const {set} of members) {
      const stats = ['hp','atk','def','spa','spd','spe']
      set.ivs = Object.fromEntries(stats.map(s => [s, Math.floor(random() * 32)]))
      set.evs = Object.fromEntries(stats.map(s => [s, 0]))
      for (let unit = 0; unit < 127; unit++) {
        const available = stats.filter(s => set.evs[s] < 252)
        set.evs[available[Math.floor(random() * available.length)]] += 4
      }
    }
  }
  return members
}
