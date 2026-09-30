// Escolha da versão de um jogo (Red ou Blue...): cada versão tem Pokémon que
// a outra não tem. "Todas" mostra os dois lados.

import { GAME_BY_KEY } from '../lib/pokemon'

/** Pokémon aparece na versão escolhida? (sem versão: sempre). */
export const inVersion = (p, game, version) => !version || !p.only?.[game] || p.only[game] === version

export default function VersionPicker({ game, value, onChange }) {
  const versions = GAME_BY_KEY[game]?.versions
  if (!versions?.length) return null
  return (
    <div className="flex rounded-full bg-card p-1 shadow">
      {[null, ...versions].map((v) => (
        <button
          key={v ?? 'all'}
          type="button"
          onClick={() => onChange(v)}
          aria-pressed={value === v}
          className={`cursor-pointer rounded-full px-3 py-1.5 text-sm font-semibold whitespace-nowrap ${value === v ? 'bg-sky-500 text-white' : 'text-muted hover:text-text'}`}
        >
          {v ?? 'Todas as versões'}
        </button>
      ))}
    </div>
  )
}
