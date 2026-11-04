// Contador de shiny hunt: +1 a cada encontro, com a chance do método escolhido.

import { m } from 'framer-motion'
import { useEffect, useState } from 'react'
import { getPokemonById } from '../../lib/data'
import { displayName } from '../../lib/pokemon'
import { METHOD_BY_KEY, SHINY_METHODS, chanceSoFar } from '../../lib/shiny'
import { t } from '../../lib/i18n'
import { useStore } from '../../lib/store'
import PokemonPicker from '../PokemonPicker'
import Sprite from '../Sprite'
import { Button, Empty, Icon } from '../ui'

export default function ShinyHunt() {
  const hunts = useStore((s) => s.hunts)
  const addHunt = useStore((s) => s.addHunt)
  const updateHunt = useStore((s) => s.updateHunt)
  const deleteHunt = useStore((s) => s.deleteHunt)
  const [byId, setById] = useState(null)
  const [picking, setPicking] = useState(false)
  const [method, setMethod] = useState('full')

  useEffect(() => {
    getPokemonById().then(setById)
  }, [])

  return (
    <div>
      <div className="mb-5 flex flex-wrap items-end gap-3 rounded-2xl bg-card p-4 shadow">
        <label className="text-sm">
          <span className="mb-1 block text-muted">Método</span>
          <select value={method} onChange={(e) => setMethod(e.target.value)} className="rounded-xl bg-surface px-3 py-2 outline-none">
            {SHINY_METHODS.map((mt) => (
              <option key={mt.key} value={mt.key}>
                {`${t(mt.label)} · 1/${mt.odds}`}
              </option>
            ))}
          </select>
        </label>
        <Button color="#F59E0B" onClick={() => setPicking(true)}>
          ✨ Nova caçada
        </Button>
      </div>

      {!hunts.length ? (
        <Empty>Nenhuma caçada ainda. Escolha o método e o Pokémon para começar a contar.</Empty>
      ) : (
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {hunts.map((h) => {
            const p = byId?.get(h.pokemonId)
            const mt = METHOD_BY_KEY[h.method] ?? SHINY_METHODS[0]
            const chance = chanceSoFar(h.count, mt.odds)
            return (
              <div key={h.id} className={`rounded-3xl p-5 shadow-lg ${h.found ? 'bg-yellow-400/15 ring-2 ring-yellow-400' : 'bg-card'}`}>
                <div className="flex items-center gap-3">
                  <div className="h-20 w-20 shrink-0">{p && <Sprite path={p.sprite.replace(/^pokemon\/(\d)/, 'pokemon/shiny/$1')} box={p.box} />}</div>
                  <div className="min-w-0 flex-1">
                    <div className="truncate text-lg font-black">{p ? displayName(p.name) : '...'}</div>
                    <div className="text-xs text-muted">
                      {mt.label}
                      {` · 1/${mt.odds}`}
                    </div>
                    {h.found && <div className="text-sm font-bold text-yellow-400">{`✨ Encontrado com ${h.count} encontros!`}</div>}
                  </div>
                  <button type="button" onClick={() => deleteHunt(h.id)} aria-label="Apagar caçada" className="cursor-pointer text-muted hover:text-red-400">
                    <Icon name="delete" size={20} />
                  </button>
                </div>
                <div className="mt-4 text-center text-5xl font-black tabular-nums">{h.count}</div>
                <div className="text-center text-xs text-muted">{`${Math.round(chance * 100)}% de chance de já ter aparecido`}</div>
                {!h.found && (
                  <div className="mt-4 flex items-center gap-2">
                    <button
                      type="button"
                      onClick={() => updateHunt(h.id, { count: Math.max(0, h.count - 1) })}
                      className="h-12 w-12 shrink-0 cursor-pointer rounded-full bg-surface text-2xl font-black"
                      aria-label="Menos um"
                    >
                      −
                    </button>
                    <m.button
                      type="button"
                      whileTap={{ scale: 0.94 }}
                      onClick={() => updateHunt(h.id, { count: h.count + 1 })}
                      className="h-12 flex-1 cursor-pointer rounded-full bg-sky-500 text-xl font-black text-white shadow"
                    >
                      +1
                    </m.button>
                    <button
                      type="button"
                      onClick={() => updateHunt(h.id, { found: true, foundAt: Date.now() })}
                      className="h-12 shrink-0 cursor-pointer rounded-full bg-yellow-400 px-4 font-bold text-[#3e2723]"
                    >
                      Achei ✨
                    </button>
                  </div>
                )}
              </div>
            )
          })}
        </div>
      )}

      <PokemonPicker
        open={picking}
        title="Qual Pokémon você vai caçar?"
        onClose={() => setPicking(false)}
        onPick={(p) => {
          addHunt({ pokemonId: p.id, method })
          setPicking(false)
        }}
      />
    </div>
  )
}
