// Histórico e replays das batalhas contra o computador (igual ao app,
// lib/services/battle_log.dart). Cada batalha guarda só a semente, os times
// ({id, set}) e as suas jogadas: o motor é determinístico, então o replay
// refaz a batalha inteira igual. Fica nos dados da conta ('battles').

export const MAX_BATTLES = 30

/** O registro de uma batalha que acabou. */
export function battleRecord(battle, { foeName = '', foeTrainer = null, now = Date.now() } = {}) {
  return {
    id: `${now.toString(36)}${Math.floor(Math.random() * 1e6).toString(36)}`,
    at: now,
    result: battle.winner === 0 ? 'win' : 'loss',
    foe: foeName,
    foeTrainer,
    turns: battle.turn,
    ai: battle.ai ?? 'normal',
    seed: battle.seed,
    mine: battle.members.mine,
    theirs: battle.members.theirs,
    actions: battle.actions ?? [],
    // Derrubados por cada Pokémon seu (posição no time).
    kos: battle.kos ?? {},
    // Quem ficou de pé no fim (para as estatísticas).
    left: battle.sides.map((s) => s.team.filter((m) => m.hp > 0).length),
  }
}

/** Dá para refazer (tem semente e os times)? */
export const canReplay = (record) => record?.seed != null && record.mine?.length && record.theirs?.length

/** Vitórias, batalhas e, por Pokémon, quantas batalhas, vitórias e derrubados. */
export function battleStats(records) {
  const byMon = new Map()
  let wins = 0
  for (const r of records) {
    const won = r.result === 'win'
    if (won) wins++
    r.mine.forEach((m, i) => {
      const s = byMon.get(m.id) ?? { id: m.id, battles: 0, wins: 0, kos: 0 }
      s.battles++
      if (won) s.wins++
      s.kos += r.kos?.[i] ?? 0
      byMon.set(m.id, s)
    })
  }
  const mons = [...byMon.values()].sort((a, b) => b.kos - a.kos || b.wins - a.wins || b.battles - a.battles)
  return { battles: records.length, wins, rate: records.length ? Math.round((wins / records.length) * 100) : 0, mons, mvp: mons[0] ?? null }
}
