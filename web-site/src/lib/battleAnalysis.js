// A análise do fim da batalha (igual ao app: lib/services/battle_analysis.dart):
// quem varreu o seu time e em que turno a batalha virou, a partir dos nocautes.
//
//   kos: [{turn, side (quem caiu), by: {side, index} | null}]

import { t } from './i18n'

/** As frases da análise: [{icon, text}]. names[side][index] → nome. */
export function battleAnalysis(kos, sizes, names, winner) {
  const out = []
  // Quem mais derrubou do seu time (a partir de 2).
  const byFoe = {}
  for (const k of kos) if (k.side === 0 && k.by?.side === 1) byFoe[k.by.index] = (byFoe[k.by.index] ?? 0) + 1
  const [sweeper, count] = Object.entries(byFoe).sort((a, b) => b[1] - a[1])[0] ?? []
  if (count >= 2) out.push({ icon: '🌪️', text: t('{0} derrubou {1} do seu time.').replace('{0}', names[1][sweeper]).replace('{1}', count) })
  // A virada: o turno em que um lado passou a ter menos Pokémon de pé e não recuperou mais.
  const left = [...sizes]
  let behindSince = null, aheadSince = null, wasBehind = false
  for (const k of kos) {
    left[k.side] -= 1
    if (left[0] < left[1]) {
      behindSince ??= k.turn
      aheadSince = null
      wasBehind = true
    } else {
      behindSince = null
      if (left[0] > left[1]) aheadSince ??= k.turn
    }
  }
  if (winner === 1 && behindSince != null) out.push({ icon: '📉', text: t('A batalha virou no turno {0}: daí em diante o adversário ficou com mais Pokémon de pé.').replace('{0}', behindSince) })
  else if (winner === 0 && wasBehind && aheadSince != null) out.push({ icon: '📈', text: t('Virada! Você estava atrás e passou à frente no turno {0}.').replace('{0}', aheadSince) })
  else if (winner === 0 && !wasBehind && kos.length) out.push({ icon: '🛡️', text: t('Você não ficou atrás em nenhum momento.') })
  // O seu que mais aguentou sem cair (vitória apertada ou derrota): quem ficou por último.
  if (winner === 1) {
    const last = kos.filter((k) => k.side === 0).at(-1)
    const lastFoe = kos.filter((k) => k.side === 1).length
    if (last && lastFoe < sizes[1]) out.push({ icon: '🎯', text: t('Faltaram {0} Pokémon do adversário.').replace('{0}', sizes[1] - lastFoe) })
  }
  return out
}
