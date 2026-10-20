// Cadeia de golpes de ovo (igual ao app, egg_chain_screen.dart): escolha o
// filhote e um golpe de ovo dele e veja por quais Pokémon passar.

import { useState } from 'react'
import { eggChains, eggMoves } from '../../lib/eggChain'
import { usePokemonIndex } from '../../lib/pokemonIndex'
import { prettyName } from '../../lib/pokemon'
import PokeIcon from '../PokeIcon'
import PokemonModal from '../PokemonModal'
import PokemonPicker from '../PokemonPicker'
import { Button, Icon } from '../ui'

const pretty = (slug) =>
  slug
    .split('-')
    .map((w) => w[0].toUpperCase() + w.slice(1))
    .join(' ')

const howText = (l) =>
  l.method === 'level-up' ? `aprende no nível ${l.level}` : l.method === 'machine' ? 'aprende por TM ou tutor' : 'recebe de ovo'

export default function EggChain() {
  const byId = usePokemonIndex()
  const [target, setTarget] = useState(null)
  const [moves, setMoves] = useState(null)
  const [move, setMove] = useState(null)
  const [chains, setChains] = useState(null)
  const [picking, setPicking] = useState(false)
  const [open, setOpen] = useState(null)
  const name = (id) => prettyName(byId?.get(id)?.name ?? `#${id}`)

  const pick = async (p) => {
    setPicking(false)
    setTarget(p.id)
    setMove(null)
    setChains(null)
    setMoves(await eggMoves(p.id))
  }
  const choose = async (m) => {
    setMove(m)
    setChains(null)
    setChains(await eggChains(target, m))
  }
  const Node = ({ link }) => (
    <button type="button" onClick={() => setOpen(link.id)} className="flex w-24 shrink-0 cursor-pointer flex-col items-center text-center">
      <PokeIcon id={link.id} className="h-14 w-14" />
      <span className="w-full truncate text-xs font-bold">{name(link.id)}</span>
      <span className="text-[10px] text-muted">{howText(link)}</span>
    </button>
  )

  return (
    <div className="mx-auto max-w-3xl space-y-4">
      <p className="text-muted">Escolha o filhote e o golpe de ovo: mostramos por quais Pokémon passar para ele nascer sabendo o golpe.</p>
      <div className="flex items-center gap-3 rounded-2xl bg-card p-4 shadow">
        {target && <PokeIcon id={target} className="h-16 w-16" />}
        <div className="min-w-0 flex-1 text-lg font-bold">{target ? name(target) : 'Nenhum Pokémon escolhido'}</div>
        <Button onClick={() => setPicking(true)}>{target ? 'Trocar' : 'Escolher Pokémon'}</Button>
      </div>
      {moves && !moves.length && <p className="py-6 text-center text-muted">Esse Pokémon não tem golpes de ovo.</p>}
      {moves?.length > 0 && (
        <div>
          <div className="mb-2 font-bold">Golpes de ovo</div>
          <div className="flex flex-wrap gap-2">
            {moves.map((m) => (
              <button
                key={m}
                type="button"
                onClick={() => choose(m)}
                className={`cursor-pointer rounded-full px-3 py-1.5 text-sm font-semibold ${move === m ? 'bg-pink-500 text-white' : 'bg-card hover:bg-surface'}`}
              >
                {pretty(m)}
              </button>
            ))}
          </div>
        </div>
      )}
      {move && !chains && <p className="text-center text-muted">...</p>}
      {chains && !chains.length && <p className="py-6 text-center text-muted">Não achamos uma cadeia de até 3 pais para esse golpe.</p>}
      {chains?.length > 0 && (
        <div className="space-y-2">
          <div className="font-bold">{`Cadeias para ${name(target)} aprender ${pretty(move)}`}</div>
          {chains.map((chain, i) => (
            <div key={i} className="flex items-start gap-1 overflow-x-auto rounded-2xl bg-card p-3 shadow">
              {chain.map((link) => (
                <div key={link.id} className="flex items-center">
                  <Node link={link} />
                  <Icon name="right" size={20} className="mt-4 text-muted" />
                </div>
              ))}
              <Node link={{ id: target, method: 'egg' }} />
            </div>
          ))}
        </div>
      )}
      <PokemonPicker open={picking} onClose={() => setPicking(false)} onPick={pick} />
      <PokemonModal id={open} onClose={() => setOpen(null)} />
    </div>
  )
}
