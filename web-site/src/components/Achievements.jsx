// Medalhas conquistadas no jogo, na Pokédex e nos times (as mesmas do app).

import { achievementsOf } from '../lib/achievements'
import { ACHIEVEMENTS as FACTORY_ACHIEVEMENTS, factoryOf } from '../lib/factoryRun'
import { t } from '../lib/i18n'
import { useStore } from '../lib/store'

export default function Achievements() {
  const stats = useStore((s) => s.stats)
  const rankedRecord = useStore((s) => s.rankedRecord)
  const favorites = useStore((s) => s.favorites)
  const teams = useStore((s) => s.teams)
  const league = useStore((s) => s.league)
  // As da Battle Factory (as mesmas da tela dela), junto com as outras.
  const factory = factoryOf(league)
  const factoryList = Object.entries(FACTORY_ACHIEVEMENTS).map(([id, a]) => ({
    id: `factory-${id}`, icon: '🎲', title: t(a.label), text: `Pokelike · 🪙${a.coins}`, unlocked: (factory.achievements ?? []).includes(id),
  }))
  const list = [...achievementsOf({ stats, rankedRecord, favorites, teams }), ...factoryList]
  const unlocked = list.filter((a) => a.unlocked).length
  return (
    <div className="rounded-2xl bg-card p-5 shadow">
      <div className="mb-4 flex items-center justify-between gap-4">
        <div>
          <div className="font-bold">Conquistas</div>
          <div className="text-sm text-muted">Jogue, monte times e favorite Pokémon para liberar medalhas.</div>
        </div>
        <span className="rounded-full bg-yellow-400 px-3 py-1 text-sm font-black text-[#3e2723]">
          {unlocked}/{list.length}
        </span>
      </div>
      <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
        {list.map((a) => (
          <div
            key={a.id}
            title={a.text}
            className={`flex items-center gap-3 rounded-xl p-3 ${a.unlocked ? 'bg-yellow-400/15 ring-1 ring-yellow-400/60' : 'bg-surface opacity-50 grayscale'}`}
          >
            <span className="text-2xl">{a.icon}</span>
            <div className="min-w-0">
              <div className="truncate text-sm font-bold">{a.title}</div>
              <div className="text-xs text-muted">{a.text}</div>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
