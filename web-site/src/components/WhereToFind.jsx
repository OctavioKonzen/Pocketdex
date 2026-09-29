// Página do Pokémon: jogos em que ele aparece (tocar marca como pego na
// Coleção) e onde encontrá-lo em cada jogo (dados do banco local).

import { useEffect, useMemo, useState } from 'react'
import { getLocations } from '../lib/data'
import { encountersByGame, locationName, methodLabel } from '../lib/encounters'
import { language } from '../lib/i18n'
import { GAMES, GAME_BY_KEY, generationBackground } from '../lib/pokemon'
import { useStore } from '../lib/store'

/** Jogos do Pokémon; cada um marca/desmarca "peguei" na Coleção. */
export function GamesSection({ form }) {
  const collection = useStore((s) => s.collection)
  const toggleCaught = useStore((s) => s.toggleCaught)
  if (!form.games?.length) return null
  return (
    <section>
      <h3 className="mb-1 font-bold">Jogos</h3>
      <p className="mb-2 text-xs text-muted">Toque num jogo para marcar que você já pegou este Pokémon nele.</p>
      <div className="flex flex-wrap gap-1.5">
        {form.games.map((key) => {
          const game = GAME_BY_KEY[key]
          if (!game) return null
          const caught = collection?.[key]?.c?.includes(form.id)
          return (
            <button
              key={key}
              type="button"
              aria-pressed={Boolean(caught)}
              onClick={() => toggleCaught(key, form.id)}
              title={caught ? 'Pego — toque para desmarcar' : 'Marcar como pego'}
              className={`cursor-pointer rounded-full px-2.5 py-1 text-xs font-bold text-white transition hover:scale-105 ${caught ? 'ring-2 ring-white' : 'opacity-80'}`}
              style={{ background: generationBackground(game) }}
            >
              {caught && '✓ '}
              {game.name}
            </button>
          )
        })}
      </div>
    </section>
  )
}

/** Onde encontrar: escolhe o jogo e vê local, método, nível e chance. */
export function WhereToFind({ form }) {
  const byGame = useMemo(() => encountersByGame(form.encounters), [form.encounters])
  const games = GAMES.filter((g) => byGame[g.key])
  const [game, setGame] = useState(null)
  const [locations, setLocations] = useState(null)
  useEffect(() => {
    if (games.length) getLocations().then(setLocations).catch(() => {})
  }, [games.length])
  const current = byGame[game] ? game : games.at(-1)?.key

  return (
    <section>
      <h3 className="mb-2 font-bold">Onde encontrar</h3>
      {!games.length ? (
        <p className="text-sm text-muted">Sem locais de captura na natureza (evolução, ovo, evento ou jogo sem dados de locais).</p>
      ) : (
        <>
          <select
            value={current}
            onChange={(e) => setGame(e.target.value)}
            className="mb-3 w-full cursor-pointer rounded-xl bg-surface px-3 py-2 text-sm font-semibold outline-none"
          >
            {games.map((g) => (
              <option key={g.key} value={g.key}>
                {g.name}
              </option>
            ))}
          </select>
          <ul className="space-y-1.5">
            {(byGame[current] ?? []).map((e, i) => (
              <li key={i} className="rounded-xl bg-surface px-3 py-2 text-sm">
                <div className="font-semibold">{locationName(locations, e.area, language)}</div>
                {/* Partes separadas: cada uma é traduzida sozinha. */}
                <div className="flex flex-wrap gap-x-1.5 text-xs text-muted">
                  <span>{methodLabel(e.method)}</span>
                  <span>·</span>
                  <span>{e.min === e.max ? `Nível ${e.min}` : `Nível ${e.min}–${e.max}`}</span>
                  {e.chance > 0 && e.chance < 100 && <span>{`· ${e.chance}%`}</span>}
                  {e.versions?.length > 0 && <span>{`· ${e.versions.join(', ')}`}</span>}
                </div>
              </li>
            ))}
          </ul>
        </>
      )}
    </section>
  )
}
