// Janelas de detalhe da Enciclopédia: golpe, habilidade e item. Também são
// abertas a partir do painel de detalhes do Pokémon.

import { useCallback, useEffect, useMemo, useState } from 'react'
import { getAbilities, getMoveLearners, getMoves, getPokemonById, spriteUrl } from '../lib/data'
import { prettyName } from '../lib/pokemon'
import { Icon, Loader, Modal, TypeBadge } from './ui'
import PokedexGrid from './PokedexGrid'
import PokemonCard from './PokemonCard'

const CATEGORY_ICON = { physical: 'physical', special: 'special', status: 'status' }

export function CategoryIcon({ category, className = '' }) {
  return (
    <span title={category} className={`text-muted ${className}`}>
      <Icon name={CATEGORY_ICON[category] ?? 'status'} size={18} />
    </span>
  )
}

/** Grade de Pokémon com o mesmo card da Pokédex (quem aprende um golpe, quem tem uma habilidade...). */
export function PokemonMiniGrid({ ids, onSelect, hidden = [] }) {
  const [byId, setById] = useState(null)
  const [limit, setLimit] = useState(60)
  useEffect(() => {
    getPokemonById().then(setById)
  }, [])
  if (!byId) return <Loader size={50} />
  const list = ids.map((id) => byId.get(id)).filter(Boolean)
  return (
    <>
      <div className="grid grid-cols-[repeat(auto-fill,minmax(190px,1fr))] gap-4">
        {list.slice(0, limit).map((p) => (
          <PokemonCard key={p.id} pokemon={p} onClick={() => onSelect?.(p)} note={hidden.includes(p.id) ? 'oculta' : undefined} />
        ))}
      </div>
      {list.length > limit && (
        <button type="button" onClick={() => setLimit(limit + 60)} className="mt-4 w-full cursor-pointer rounded-xl bg-surface py-3 font-semibold hover:bg-white/10">
          Mostrar mais ({list.length - limit})
        </button>
      )}
    </>
  )
}

function Stat({ label, value }) {
  return (
    <div className="rounded-2xl bg-surface p-3 text-center">
      <div className="text-xs text-muted">{label}</div>
      <div className="text-lg font-bold">{value ?? '—'}</div>
    </div>
  )
}

/** Pokémon de uma lista de ids: dentro da página abrem para baixo (grade da
 * Pokédex); dentro de uma janela, o clique leva ao Pokémon. */
export function PokemonList({ ids, inline, onSelect, hidden = [] }) {
  const [byId, setById] = useState(null)
  useEffect(() => {
    getPokemonById().then(setById)
  }, [])
  const list = useMemo(() => (byId ? ids.map((id) => byId.get(id)).filter(Boolean) : []), [byId, ids])
  const noteFor = useCallback((p) => (hidden.includes(p.id) ? 'oculta' : undefined), [hidden])
  if (!inline) return <PokemonMiniGrid ids={ids} onSelect={onSelect} hidden={hidden} />
  if (!byId) return <Loader size={50} />
  return <PokedexGrid pokemon={list} noteFor={noteFor} />
}

export function MoveDetails({ name, inline = false, onSelectPokemon }) {
  const [move, setMove] = useState(null)
  const [learners, setLearners] = useState(null)
  useEffect(() => {
    getMoves().then((moves) => setMove(moves[name]))
    getMoveLearners().then((all) => setLearners(all[name] ?? []))
  }, [name])

  if (!move) return <Loader />
  return (
    <div className="space-y-5">
      <div className="flex items-center gap-3">
        <TypeBadge type={move.type} />
        <CategoryIcon category={move.category} />
        <span className="text-sm text-muted capitalize">{move.category}</span>
      </div>
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <Stat label="Power" value={move.power} />
        <Stat label="Accuracy" value={move.accuracy} />
        <Stat label="PP" value={move.pp} />
        <Stat label="Priority" value={move.priority} />
      </div>
      <p className="leading-relaxed">{move.effect}</p>
      {move.flavor && <p className="text-sm text-muted italic">{move.flavor}</p>}
      <div>
        <h3 className="mb-3 font-bold">Pokémon que aprendem ({learners?.length ?? '…'})</h3>
        {learners ? <PokemonList ids={learners} inline={inline} onSelect={onSelectPokemon} /> : <Loader size={50} />}
      </div>
    </div>
  )
}

export function AbilityDetails({ name, inline = false, onSelectPokemon }) {
  const [ability, setAbility] = useState(null)
  useEffect(() => {
    getAbilities().then((list) => setAbility(list.find((a) => a.name === name) ?? null))
  }, [name])

  if (!ability) return <Loader />
  return (
    <div className="space-y-5">
      <p className="leading-relaxed">{ability.effect}</p>
      {ability.flavor && <p className="text-sm text-muted italic">{ability.flavor}</p>}
      <div>
        <h3 className="mb-3 font-bold">Pokémon com esta habilidade ({ability.pokemon.length})</h3>
        <PokemonList ids={ability.pokemon} hidden={ability.hiddenFor} inline={inline} onSelect={onSelectPokemon} />
      </div>
    </div>
  )
}

export function ItemDetails({ item }) {
  return (
    <div className="space-y-4">
      <div className="flex items-center gap-4">
        <div className="grid h-24 w-24 shrink-0 place-items-center rounded-2xl bg-surface">
          {item.sprite ? <img src={spriteUrl(item.sprite)} alt="" className="pixelated h-20 w-20" /> : <Icon name="status" size={40} className="text-muted" />}
        </div>
        <div>
          <div className="text-sm text-muted">Categoria</div>
          <div className="font-bold">{prettyName(item.category)}</div>
          {item.cost ? <div className="mt-1 text-sm text-muted">Preço: ₽{item.cost}</div> : null}
        </div>
      </div>
      <p className="leading-relaxed">{item.effect}</p>
      {item.flavor && <p className="text-sm text-muted italic">{item.flavor}</p>}
    </div>
  )
}

// Versões em janela (usadas a partir do painel de detalhes do Pokémon).

export function MoveModal({ name, onClose, onSelectPokemon }) {
  return (
    <Modal open={Boolean(name)} onClose={onClose} title={prettyName(name ?? '')} wide>
      {name && <MoveDetails key={name} name={name} onSelectPokemon={onSelectPokemon} />}
    </Modal>
  )
}

export function AbilityModal({ name, onClose, onSelectPokemon }) {
  return (
    <Modal open={Boolean(name)} onClose={onClose} title={prettyName(name ?? '')} wide>
      {name && <AbilityDetails key={name} name={name} onSelectPokemon={onSelectPokemon} />}
    </Modal>
  )
}
