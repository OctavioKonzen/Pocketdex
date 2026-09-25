// Janelas de detalhe da Enciclopédia: golpe, habilidade e item. Também são
// abertas a partir do painel de detalhes do Pokémon.

import { useEffect, useState } from 'react'
import { getAbilities, getMoveLearners, getMoves, getPokemonById, spriteUrl } from '../lib/data'
import { displayName, prettyName } from '../lib/pokemon'
import { Icon, Loader, Modal, TypeBadge } from './ui'

const CATEGORY_ICON = { physical: 'physical', special: 'special', status: 'status' }

export function CategoryIcon({ category, className = '' }) {
  return (
    <span title={category} className={`text-muted ${className}`}>
      <Icon name={CATEGORY_ICON[category] ?? 'status'} size={18} />
    </span>
  )
}

/** Grade pequena de Pokémon (quem aprende um golpe, quem tem uma habilidade...). */
export function PokemonMiniGrid({ ids, onSelect, hidden = [] }) {
  const [byId, setById] = useState(null)
  useEffect(() => {
    getPokemonById().then(setById)
  }, [])
  if (!byId) return <Loader size={50} />
  return (
    <div className="grid grid-cols-[repeat(auto-fill,minmax(96px,1fr))] gap-3">
      {ids.map((id) => {
        const p = byId.get(id)
        if (!p) return null
        return (
          <button
            key={id}
            type="button"
            onClick={() => onSelect?.(p)}
            className="flex cursor-pointer flex-col items-center rounded-2xl bg-surface p-2 transition hover:scale-105 hover:bg-white/10"
          >
            <img src={spriteUrl(p.sprite)} alt="" loading="lazy" className="pixelated h-16 w-16" />
            <span className="w-full truncate text-center text-xs font-semibold">{displayName(p.name)}</span>
            {hidden.includes(id) && <span className="text-[10px] text-muted">oculta</span>}
          </button>
        )
      })}
    </div>
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

export function MoveModal({ name, onClose, onSelectPokemon }) {
  const [move, setMove] = useState(null)
  const [learners, setLearners] = useState(null)
  useEffect(() => {
    if (!name) return
    setMove(null)
    setLearners(null)
    getMoves().then((moves) => setMove(moves[name]))
    getMoveLearners().then((all) => setLearners(all[name] ?? []))
  }, [name])

  return (
    <Modal open={Boolean(name)} onClose={onClose} title={prettyName(name ?? '')} wide>
      {!move ? (
        <Loader />
      ) : (
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
            {learners ? <PokemonMiniGrid ids={learners} onSelect={onSelectPokemon} /> : <Loader size={50} />}
          </div>
        </div>
      )}
    </Modal>
  )
}

export function AbilityModal({ name, onClose, onSelectPokemon }) {
  const [ability, setAbility] = useState(null)
  useEffect(() => {
    if (!name) return
    setAbility(null)
    getAbilities().then((list) => setAbility(list.find((a) => a.name === name) ?? null))
  }, [name])

  return (
    <Modal open={Boolean(name)} onClose={onClose} title={prettyName(name ?? '')} wide>
      {!ability ? (
        <Loader />
      ) : (
        <div className="space-y-5">
          <p className="leading-relaxed">{ability.effect}</p>
          {ability.flavor && <p className="text-sm text-muted italic">{ability.flavor}</p>}
          <div>
            <h3 className="mb-3 font-bold">Pokémon com esta habilidade ({ability.pokemon.length})</h3>
            <PokemonMiniGrid ids={ability.pokemon} hidden={ability.hiddenFor} onSelect={onSelectPokemon} />
          </div>
        </div>
      )}
    </Modal>
  )
}

export function ItemModal({ item, onClose }) {
  return (
    <Modal open={Boolean(item)} onClose={onClose} title={prettyName(item?.name ?? '')}>
      {item && (
        <div className="space-y-4">
          <div className="flex items-center gap-4">
            <div className="grid h-24 w-24 place-items-center rounded-2xl bg-surface">
              {item.sprite ? (
                <img src={spriteUrl(item.sprite)} alt="" className="pixelated h-20 w-20" />
              ) : (
                <Icon name="status" size={40} className="text-muted" />
              )}
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
      )}
    </Modal>
  )
}
