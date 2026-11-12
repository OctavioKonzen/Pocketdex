// Aba Jogos da página do Pokémon: jogos em que ele aparece, por geração
// (tocar marca como pego na Coleção), e onde encontrá-lo em cada jogo.

import { useEffect, useMemo, useState } from 'react'
import { getLocations } from '../lib/data'
import { encountersByGame, locationName, methodLabel } from '../lib/encounters'
import { language } from '../lib/i18n'
import { GAMES, generationBackground } from '../lib/pokemon'
import { useStore } from '../lib/store'

/**
 * Aba Jogos da página do Pokémon: os jogos em que ele aparece, por geração
 * (principais e secundários), com "Só em Red" quando é exclusivo de uma
 * versão. Tocar num jogo marca/desmarca "peguei" na Coleção.
 */
export function GamesTab({ form }) {
  const collection = useStore((s) => s.collection)
  const toggleCaught = useStore((s) => s.toggleCaught)
  const inGame = new Set(form.games ?? [])
  const main = GAMES.filter((g) => !g.spinoff && inGame.has(g.key))
  const spinoffs = GAMES.filter((g) => g.spinoff && inGame.has(g.key))
  const byGen = main.reduce((acc, g) => ((acc[g.gen] ??= []).push(g), acc), {})
  const caughtCount = [...inGame].filter((k) => collection?.[k]?.c?.includes(form.id)).length

  const card = (game) => {
    const caught = collection?.[game.key]?.c?.includes(form.id)
    const only = form.only?.[game.key]
    return (
      <button
        key={game.key}
        type="button"
        aria-pressed={Boolean(caught)}
        onClick={() => toggleCaught(game.key, form.id)}
        title={caught ? 'Pego — toque para desmarcar' : 'Marcar como pego'}
        className={`relative flex cursor-pointer flex-col items-start rounded-2xl px-3 py-2 text-left text-white shadow transition hover:scale-[1.03] ${caught ? 'ring-2 ring-white' : ''}`}
        style={{ background: generationBackground(game) }}
      >
        <span className="text-sm font-bold">{game.name}</span>
        {only && <span className="mt-0.5 rounded-full bg-black/35 px-2 text-[11px] font-semibold">{`Só em ${only}`}</span>}
        <span className={`absolute top-1.5 right-2 text-sm ${caught ? '' : 'opacity-40'}`}>{caught ? '✓' : '○'}</span>
      </button>
    )
  }

  return (
    <div className="space-y-5">
      {!inGame.size ? (
        <p className="text-sm text-muted">Sem jogos registrados para esta forma.</p>
      ) : (
        <>
          <p className="text-sm text-muted">
            {`Aparece em ${inGame.size} jogos · pego em ${caughtCount}. `}
            <span>Toque num jogo para marcar que você já pegou este Pokémon nele.</span>
          </p>
          {Object.entries(byGen).map(([gen, list]) => (
            <section key={gen}>
              <h3 className="mb-2 text-sm font-bold text-muted">{`Geração ${gen}`}</h3>
              <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">{list.map(card)}</div>
            </section>
          ))}
          {spinoffs.length > 0 && (
            <section>
              <h3 className="mb-2 text-sm font-bold text-muted">Jogos secundários</h3>
              <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">{spinoffs.map(card)}</div>
            </section>
          )}
        </>
      )}
      <WhereToFind form={form} />
    </div>
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
