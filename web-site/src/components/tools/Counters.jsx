// "Quem vence esse Pokémon?" (igual ao app): quem ganha dele 1 contra 1 no
// nível 50, com o melhor golpe de cada lado (lib/teamBattle.js).

import { useRef, useState } from 'react'
import { prettyName } from '../../lib/pokemon'
import { counters } from '../../lib/teamBattle'
import PokeIcon from '../PokeIcon'
import PokemonModal from '../PokemonModal'
import PokemonPicker from '../PokemonPicker'
import { usePokemonIndex } from '../../lib/pokemonIndex'
import { Button } from '../ui'

const pct = (x) => `${x.toFixed(1).replace('.', ',')}%`
const hits = (n) => (n === 1 ? '1 golpe' : `${n} golpes`)

export default function Counters() {
  const byId = usePokemonIndex()
  const [target, setTarget] = useState(null)
  const [legendaries, setLegendaries] = useState(false)
  const [progress, setProgress] = useState(null)
  const [result, setResult] = useState(null)
  const [picking, setPicking] = useState(false)
  const [open, setOpen] = useState(null)
  const run = useRef(0)

  const go = async (id, withLegendaries) => {
    const mine = ++run.current
    setProgress(0)
    setResult(null)
    const list = await counters(id, { legendaries: withLegendaries, progress: (p) => mine === run.current && setProgress(p) })
    if (mine === run.current) {
      setResult(list)
      setProgress(null)
    }
  }
  const name = (id) => prettyName(byId?.get(id)?.name ?? `#${id}`)

  return (
    <div className="mx-auto max-w-3xl space-y-4">
      <p className="text-muted">Escolha um Pokémon e veja quem ganha dele 1 contra 1 (nível 50, melhor golpe de cada lado).</p>
      <div className="flex flex-wrap items-center gap-3 rounded-2xl bg-card p-4 shadow">
        {target && <PokeIcon id={target} className="h-16 w-16" />}
        <div className="min-w-0 flex-1 text-lg font-bold">{target ? name(target) : 'Nenhum Pokémon escolhido'}</div>
        <Button onClick={() => setPicking(true)}>{target ? 'Trocar' : 'Escolher Pokémon'}</Button>
        <label className="flex w-full cursor-pointer items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={legendaries}
            onChange={(e) => {
              setLegendaries(e.target.checked)
              if (target) go(target, e.target.checked)
            }}
          />
          Incluir lendários e míticos
        </label>
      </div>
      {progress !== null && (
        <div>
          <div className="h-2 overflow-hidden rounded-full bg-card">
            <div className="h-full bg-sky-500 transition-all" style={{ width: `${progress * 100}%` }} />
          </div>
          <p className="mt-1 text-xs text-muted">Calculando os confrontos...</p>
        </div>
      )}
      {result && !result.length && <p className="py-8 text-center text-muted">Ninguém ganha dele 1 contra 1 nessas condições.</p>}
      {result?.length > 0 && (
        <>
          <div className="font-bold">{`${result.length} Pokémon ganham do ${name(target)}`}</div>
          <div className="space-y-2">
            {result.slice(0, 40).map(({ id, duel }) => (
              <button
                key={id}
                type="button"
                onClick={() => setOpen(id)}
                className="flex w-full cursor-pointer items-center gap-3 rounded-2xl bg-card p-3 text-left shadow transition hover:scale-[1.01]"
              >
                <PokeIcon id={id} className="h-12 w-12" />
                <span className="min-w-0 flex-1">
                  <span className="block font-bold">{name(id)}</span>
                  <span className="block text-sm">{`${duel.mine.move}: ${pct(duel.mine.pct)} por golpe · derrota em ${hits(duel.mine.hits)}`}</span>
                  <span className="block text-xs text-muted">{duel.theirs.hits >= 99 ? 'Não leva dano dele.' : `Aguenta ${hits(duel.theirs.hits)}`}</span>
                </span>
              </button>
            ))}
          </div>
        </>
      )}
      <PokemonPicker
        open={picking}
        onClose={() => setPicking(false)}
        onPick={(p) => {
          setPicking(false)
          setTarget(p.id)
          go(p.id, legendaries)
        }}
      />
      <PokemonModal id={open} onClose={() => setOpen(null)} />
    </div>
  )
}
