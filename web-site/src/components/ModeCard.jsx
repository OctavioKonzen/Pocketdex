// Card de modo/ferramenta do novo visual: ícone colorido, título (a descrição fica na dica do mouse) e
// um Pokémon animado à direita (o mesmo sprite BW da Pokédex) com a altura
// do card.

import { m } from 'framer-motion'
import { t } from '../lib/i18n'
import PokeIcon from './PokeIcon'
import { Icon } from './ui'

export default function ModeCard({ title, subtitle, color, icon, emoji, pokemon, shiny = false, active = false, large = false, tag, onClick, testid }) {
  return (
    <m.button
      type="button"
      whileHover={{ y: -3 }}
      onClick={onClick}
      data-testid={testid}
      title={subtitle ? t(subtitle) : undefined}
      className={`group relative flex w-full cursor-pointer overflow-hidden rounded-2xl border bg-card p-5 text-left transition ${large ? 'h-48 sm:h-52' : 'h-40'} ${active ? '' : 'border-line hover:border-text/20'}`}
      style={active ? { borderColor: color, boxShadow: `0 0 0 1px ${color}` } : undefined}
    >
      <span className={`relative flex min-w-0 flex-1 flex-col ${pokemon != null ? (large ? 'pr-40 sm:pr-44' : 'pr-32') : ''}`}>
        <span className="grid h-11 w-11 shrink-0 place-items-center rounded-xl text-xl" style={{ background: `${color}22`, color }}>
          {emoji ?? <Icon name={icon} />}
        </span>
        <span className="mt-auto block pt-3">
          <span className={`font-display block font-semibold ${large ? 'text-xl sm:text-2xl' : 'text-lg'}`}>{t(title)}</span>
        </span>
      </span>
      {pokemon != null && (
        // O Pokémon ocupa a altura toda do card: caixa quadrada do tamanho do
        // card, com ele apoiado embaixo (os pés de todos na mesma linha).
        <span aria-hidden="true" className="pointer-events-none absolute top-2 right-2 bottom-2 aspect-square">
          <PokeIcon id={pokemon} shiny={shiny} fill={0.96} align="bottom" className="h-full w-full origin-bottom transition-transform duration-300 group-hover:scale-105" />
        </span>
      )}
      {tag && <span className="absolute top-3 right-3 rounded-full bg-[#FFCB05] px-2.5 py-1 text-[11px] font-bold text-[#16130a]">{t(tag)}</span>}
    </m.button>
  )
}
