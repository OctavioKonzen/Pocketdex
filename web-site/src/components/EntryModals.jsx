// Janelas de detalhe da Enciclopédia: golpe, habilidade e item. Também são
// abertas a partir do painel de detalhes do Pokémon.

import { useEffect, useState } from 'react'
import { getAbilities, getMoveLearners, getMoves, getPokemonById, spriteUrl } from '../lib/data'
import { prettyName } from '../lib/pokemon'
import { Icon, Loader, Modal, TypeBadge } from './ui'
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
