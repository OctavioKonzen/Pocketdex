// Guia de Tera Raids (igual ao app): escolha o chefe e o tipo Tera dele e veja
// os melhores Pokémon para levar (lib/teraRaid.js).

import { useEffect, useState } from 'react'
import { getPokedex, getTypes } from '../../lib/data'
import { ALL_TYPES, prettyName, typeColor } from '../../lib/pokemon'
import { teraRaidPicks } from '../../lib/teraRaid'
import PokeIcon from '../PokeIcon'
import PokemonModal from '../PokemonModal'
import PokemonPicker from '../PokemonPicker'
import { Button, TypeBadge } from '../ui'

export default function TeraRaid() {
  const [boss, setBoss] = useState(null)
  const [tera, setTera] = useState(null)
  const [data, setData] = useState(null)
  const [picking, setPicking] = useState(false)
  const [open, setOpen] = useState(null)

  useEffect(() => {
    Promise.all([getPokedex(), getTypes(), import('../../lib/damageCalc')]).then(([pokedex, types, calc]) =>
      setData({ pokedex, types, isNfe: calc.isNfe }),
    )
  }, [])

  const picks =
    data && boss && tera
      ? teraRaidPicks(data.pokedex, data.types, boss.types, tera, { allowed: (p) => !p.tag && !data.isNfe(p.name) })
      : null

  return (
    <div className="mx-auto max-w-3xl space-y-4">
      <p className="text-muted">Escolha o chefe da raid e o tipo Tera dele para ver os melhores Pokémon para levar.</p>
      <div className="flex flex-wrap items-center gap-3 rounded-2xl bg-card p-4 shadow">
        {boss && <PokeIcon id={boss.id} className="h-16 w-16" />}
        <div className="min-w-0 flex-1">
          <div className="text-lg font-bold">{boss ? prettyName(boss.name) : 'Escolha o chefe'}</div>
          {boss && (
            <div className="mt-1 flex gap-1">
              {boss.types.map((t) => (
                <TypeBadge key={t} type={t} small />
              ))}
            </div>
          )}
        </div>
        <Button onClick={() => setPicking(true)}>{boss ? 'Trocar' : 'Escolher o chefe'}</Button>
      </div>
      <div>
        <div className="mb-2 font-bold">Tipo Tera do chefe</div>
        <div className="flex flex-wrap gap-1.5">
          {ALL_TYPES.map((t) => (
            <button
              key={t}
              type="button"
              onClick={() => setTera(t)}
              className={`cursor-pointer rounded-xl px-3 py-1.5 text-xs font-bold text-white capitalize transition ${tera && tera !== t ? 'opacity-45' : ''} ${tera === t ? 'ring-2 ring-white' : ''}`}
              style={{ background: typeColor(t) }}
            >
              {t}
            </button>
          ))}
        </div>
      </div>
      {picks && !picks.length && <p className="py-6 text-center text-muted">Nenhum Pokémon bate super efetivo nesse Tera com o próprio tipo.</p>}
      {picks?.length > 0 && (
        <div className="space-y-2">
          <div className="font-bold">{`Melhores para a raid contra ${prettyName(boss.name)} Tera ${tera[0].toUpperCase()}${tera.slice(1)}`}</div>
          {picks.map((p) => (
            <button
              key={p.id}
              type="button"
              onClick={() => setOpen(p.id)}
              className="flex w-full cursor-pointer items-center gap-3 rounded-2xl bg-card p-3 text-left shadow transition hover:scale-[1.01]"
            >
              <PokeIcon id={p.id} className="h-12 w-12" />
              <span className="min-w-0 flex-1">
                <span className="block font-bold">{prettyName(p.name)}</span>
                <span className="mt-1 flex flex-wrap items-center gap-1.5 text-sm">
                  <TypeBadge type={p.attackType} small />
                  {`${p.offense === 4 ? '4×' : '2×'} · ${p.taken < 1 ? 'resiste ao chefe' : p.taken > 1 ? 'leva super efetivo do chefe' : 'dano normal do chefe'}`}
                </span>
              </span>
            </button>
          ))}
        </div>
      )}
      <PokemonPicker
        open={picking}
        onClose={() => setPicking(false)}
        onPick={(p) => {
          setPicking(false)
          setBoss(p)
          setTera((t) => t ?? p.types[0])
        }}
      />
      <PokemonModal id={open} onClose={() => setOpen(null)} />
    </div>
  )
}
