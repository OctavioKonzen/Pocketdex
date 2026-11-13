// Pokémon do dia (igual ao app, daily_pokemon_card.dart): um card no topo da
// Pokédex com o Pokémon de hoje, uma curiosidade e o grito.

import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { cryUrl, getSpecies } from '../lib/data'
import { DAILY_BATTLE_COINS, DAILY_BATTLE_FOES, dailyBattleDone } from '../lib/dailyBattle'
import { factoryOf } from '../lib/factoryRun'
import { t } from '../lib/i18n'
import { useStore } from '../lib/store'
import { dailyPokemonId } from '../lib/dailyPokemon'
import { pick } from '../lib/i18n'
import { usePokemonIndex } from '../lib/pokemonIndex'
import { prettyName, typeBackground } from '../lib/pokemon'
import PokeIcon from './PokeIcon'
import PokemonModal from './PokemonModal'
import { Icon } from './ui'

export default function DailyPokemonCard() {
  const id = dailyPokemonId()
  const byId = usePokemonIndex()
  const [species, setSpecies] = useState(null)
  const [open, setOpen] = useState(false)
  const navigate = useNavigate()
  const teams = useStore((s) => s.teams)
  const done = dailyBattleDone(factoryOf(useStore((s) => s.league)))
  // O desafio do dia: o seu primeiro time (ou três ao acaso) contra um trio dele; vencer dá moedas do Pokelike (1 vez por dia). Igual ao app.
  const challenge = (e) => {
    e.stopPropagation()
    const first = (teams[0]?.pokemon ?? []).filter((x) => typeof x === 'number').slice(0, 6)
    const seed = Date.now()
    const mine = first.length ? first : [0, 1, 2].map((i) => 1 + ((seed * (i + 7)) % 1025))
    navigate('/batalha/computador', { state: { mine, theirs: Array(DAILY_BATTLE_FOES).fill(id), foeName: `${t('Pokémon do dia')}: ${prettyName(p.name.split('-')[0])}`, daily: true } })
  }
  useEffect(() => {
    getSpecies(id)
      .then(setSpecies)
      .catch(() => {})
  }, [id])
  const p = byId?.get(id)
  if (!p) return null
  const play = (e) => {
    e.stopPropagation()
    const audio = new Audio(cryUrl(id))
    audio.volume = 0.6
    audio.play().catch(() => {})
  }
  return (
    <>
      <div
        role="button"
        tabIndex={0}
        onClick={() => setOpen(true)}
        onKeyDown={(e) => e.key === 'Enter' && setOpen(true)}
        className="mb-5 flex cursor-pointer items-center gap-3 rounded-2xl p-3 text-white shadow transition hover:scale-[1.005]"
        style={{ background: typeBackground(p.types) }}
      >
        <PokeIcon id={id} className="h-20 w-20" fill={0.95} />
        <div className="min-w-0 flex-1">
          <div className="text-xs font-bold opacity-90">⭐ Pokémon do dia</div>
          <div className="text-xl font-black drop-shadow">{`${prettyName(p.name.split('-')[0])} #${String(id).padStart(3, '0')}`}</div>
          {species && (
            <p className="line-clamp-2 text-sm opacity-95" data-no-translate>
              {pick(species.flavor, species.flavors)}
            </p>
          )}
          <button type="button" onClick={done ? (e) => e.stopPropagation() : challenge} disabled={done} data-testid="daily-battle"
            className={`mt-1 cursor-pointer rounded-full px-2.5 py-1 text-xs font-extrabold ${done ? 'bg-black/15' : 'bg-black/35 hover:bg-black/45'}`}>
            {done ? `✅ ${t('Desafio de hoje vencido')}` : `⚔️ ${t('Desafiar o trio do dia (+{0} moedas)').replace('{0}', DAILY_BATTLE_COINS)}`}
          </button>
        </div>
        <button type="button" onClick={play} aria-label="Ouvir o grito" title="Ouvir o grito" className="grid h-11 w-11 shrink-0 cursor-pointer place-items-center rounded-full bg-white/20 hover:bg-white/30">
          <Icon name="volume" />
        </button>
      </div>
      <PokemonModal id={open ? id : null} onClose={() => setOpen(false)} />
    </>
  )
}
