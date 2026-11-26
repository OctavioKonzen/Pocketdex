// Medalhas conquistadas no jogo, na Pokédex e nos times (as mesmas do app).

import { achievementsOf } from '../lib/achievements'
import { ACHIEVEMENTS as FACTORY_ACHIEVEMENTS, factoryOf } from '../lib/factoryRun'
import { t } from '../lib/i18n'
import { useStore } from '../lib/store'
import { useEffect, useState } from 'react'
import { medalsOf } from '../lib/medals'
import { lineColor, themeArt, themeColor } from '../lib/pokemonTheme'

/** Uma medalha do álbum: o desenho do Pokémon na cor dele (liberada) ou só a sombra (trancada). */
export function Medal({ medal }) {
  const [art, setArt] = useState(null)
  const [color, setColor] = useState(null)
  useEffect(() => {
    let live = true
    themeColor(medal.pokemon).then(async (hex) => {
      const fill = medal.unlocked && hex ? hex : '#4b5563'
      const url = await themeArt(medal.pokemon, fill, medal.unlocked && hex ? lineColor(hex) : '#1f2937')
      if (live) {
        setColor(hex)
        setArt(url)
      }
    })
    return () => {
      live = false
    }
  }, [medal.pokemon, medal.unlocked])
  const ring = medal.unlocked && color ? color : 'var(--line)'
  return (
    <div className="flex flex-col items-center gap-1 text-center" title={medal.text} data-testid={`medal-${medal.id}`}>
      <div
        className={`relative grid h-20 w-20 place-items-center rounded-full border-4 ${medal.unlocked ? 'medal-on' : 'opacity-60'}`}
        style={{ borderColor: ring, background: medal.unlocked && color ? `radial-gradient(circle, ${color}33, transparent 70%)` : 'var(--surface)' }}
      >
        {art && <img src={art} alt="" className="h-14 w-14 object-contain" />}
        {!medal.unlocked && <span className="absolute -right-1 -bottom-1 text-base">🔒</span>}
      </div>
      <div className="text-xs font-bold leading-tight">{t(medal.title)}</div>
      <div className="text-[10px] leading-tight text-muted">{t(medal.text)}</div>
    </div>
  )
}

/** O álbum de medalhas: os marcos grandes, com o desenho de um Pokémon cada. */
export function MedalAlbum() {
  const league = useStore((s) => s.league)
  const collection = useStore((s) => s.collection)
  const medals = medalsOf({ league, collection })
  return (
    <div className="rounded-2xl bg-card p-5 shadow" data-testid="medal-album">
      <div className="mb-4 flex items-center justify-between gap-4">
        <div>
          <div className="font-bold">{t('Álbum de medalhas')}</div>
          <div className="text-sm text-muted">{t('Os grandes marcos, cada um com o desenho de um Pokémon.')}</div>
        </div>
        <span className="rounded-full bg-yellow-400 px-3 py-1 text-sm font-black text-[#3e2723]">
          {medals.filter((m) => m.unlocked).length}/{medals.length}
        </span>
      </div>
      <div className="grid grid-cols-3 gap-4 sm:grid-cols-4 lg:grid-cols-6">
        {medals.map((m) => <Medal key={m.id} medal={m} />)}
      </div>
    </div>
  )
}

/** As conquistas do jogo, da Pokédex e dos times; factory: as do Pokelike (cada uma dá moedas uma vez). */
export default function Achievements({ factory: pokelike = false }) {
  const stats = useStore((s) => s.stats)
  const rankedRecord = useStore((s) => s.rankedRecord)
  const favorites = useStore((s) => s.favorites)
  const teams = useStore((s) => s.teams)
  const league = useStore((s) => s.league)
  // As do Pokelike ficam na aba delas.
  const factory = factoryOf(league)
  const list = pokelike
    ? Object.entries(FACTORY_ACHIEVEMENTS).map(([id, a]) => ({
        id: `factory-${id}`, icon: '🎲', title: t(a.label), text: `🪙${a.coins}`, unlocked: (factory.achievements ?? []).includes(id),
      }))
    : achievementsOf({ stats, rankedRecord, favorites, teams })
  const unlocked = list.filter((a) => a.unlocked).length
  return (
    <div className="rounded-2xl bg-card p-5 shadow">
      <div className="mb-4 flex items-center justify-between gap-4">
        <div>
          <div className="font-bold">{pokelike ? 'Pokelike' : t('Conquistas')}</div>
          <div className="text-sm text-muted">{t(pokelike ? 'Cada conquista dá moedas uma vez.' : 'Jogue, monte times e favorite Pokémon para liberar medalhas.')}</div>
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
