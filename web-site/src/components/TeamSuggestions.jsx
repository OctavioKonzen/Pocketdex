// Sugestões para completar o time: Pokémon que aguentam as fraquezas do time
// e acertam os tipos que ele ainda não cobre.

import { useEffect, useMemo, useState } from 'react'
import { getPokedex } from '../lib/data'
import { displayName, suggestMembers } from '../lib/pokemon'
import Sprite from './Sprite'
import { TypeBadge } from './ui'

export default function TeamSuggestions({ members, typeData, onAdd }) {
  const [pokedex, setPokedex] = useState(null)
  useEffect(() => {
    getPokedex().then(setPokedex)
  }, [])
  const list = useMemo(
    () => (pokedex && typeData ? suggestMembers(members.map((m) => m.types), typeData, pokedex, members.map((m) => m.species ?? m.id)) : []),
    [pokedex, typeData, members],
  )
  if (!members.length || members.length >= 6 || !list.length) return null
  return (
    <div className="mt-6">
      <div className="text-sm font-bold">Sugestões para completar o time</div>
      <div className="mb-2 text-xs text-muted">Aguentam as fraquezas do time e acertam tipos que ele ainda não cobre.</div>
      <div className="grid gap-2 sm:grid-cols-2">
        {list.map(({ pokemon: p, resists, covers }) => (
          <div key={p.id} className="flex items-center gap-3 rounded-2xl bg-surface p-2.5">
            <div className="h-14 w-14 shrink-0">
              <Sprite path={p.sprite} box={p.box} />
            </div>
            <div className="min-w-0 flex-1">
              <div className="flex items-center gap-1.5">
                <span className="truncate font-bold">{displayName(p.name)}</span>
                {p.types.map((t) => (
                  <TypeBadge key={t} type={t} small />
                ))}
              </div>
              {resists.length > 0 && <div className="truncate text-xs text-green-400">{`Aguenta: ${resists.join(', ')}`}</div>}
              {covers.length > 0 && <div className="truncate text-xs text-sky-400">{`Acerta: ${covers.join(', ')}`}</div>}
            </div>
            {onAdd && (
              <button
                type="button"
                onClick={() => onAdd(p)}
                className="shrink-0 cursor-pointer rounded-full bg-sky-500 px-3 py-1.5 text-sm font-bold text-white transition hover:scale-105"
              >
                + Adicionar
              </button>
            )}
          </div>
        ))}
      </div>
    </div>
  )
}
