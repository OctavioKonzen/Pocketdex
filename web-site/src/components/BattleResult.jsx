// Resultado da batalha de times (lib/teamBattle.js): quem leva vantagem e a
// grade de confrontos, com o detalhe de cada um. Usado na batalha de times e
// no draft.

import { useState } from 'react'
import PokeIcon from './PokeIcon'
import { Button } from './ui'

const CARD = 'rounded-2xl bg-card p-5 shadow'
const COLORS = { 1: '#22C55E', '-1': '#EF4444', 0: '#9CA3AF' }

const pct = (x) => `${x.toFixed(1).replace('.', ',')}%`
const hitsText = (n) => (n === 1 ? '1 golpe' : `${n} golpes`)

function Detail({ duel, mine, theirs, onClose }) {
  const side = (id, h) => (
    <div className="flex items-center gap-3">
      <PokeIcon id={id} className="h-14 w-14" />
      <div className="text-sm">{h.hits >= 99 ? 'Não consegue causar dano.' : `${h.move}: ${pct(h.pct)} por golpe · derrota em ${hitsText(h.hits)}`}</div>
    </div>
  )
  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/60 p-4" onClick={onClose}>
      <div className="w-full max-w-md space-y-3 rounded-2xl bg-card p-5 shadow-xl" onClick={(e) => e.stopPropagation()}>
        <div className="text-xl font-bold">{duel.result === 1 ? '✅ Você ganha' : duel.result === -1 ? '❌ Você perde' : '🤝 Empate'}</div>
        {side(mine, duel.mine)}
        {side(theirs, duel.theirs)}
        <p className="text-sm text-muted">{duel.sameSpeed ? 'Mesma velocidade.' : duel.faster ? 'O seu é mais rápido.' : 'O dele é mais rápido.'}</p>
        <Button onClick={onClose} className="w-full">
          Fechar
        </Button>
      </div>
    </div>
  )
}

/** result: [i][j] (lib/teamBattle.js); a e b: membros [{id}] dos dois times. */
export default function BattleResult({ result, a, b }) {
  const [detail, setDetail] = useState(null)
  const all = result.flat().filter(Boolean)
  const wins = all.filter((d) => d.result === 1).length
  const losses = all.filter((d) => d.result === -1).length
  return (
    <section className={CARD}>
      <div className="text-xl font-black">
        {wins > losses ? '🏆 Seu time leva vantagem!' : wins < losses ? '😬 O time do amigo leva vantagem.' : '🤝 Equilibrado.'}
      </div>
      <p className="mt-1 mb-4">{`Você ganha ${wins}, perde ${losses} e empata ${all.length - wins - losses} de ${all.length} confrontos.`}</p>
      <div className="overflow-x-auto">
        <table className="border-separate border-spacing-1">
          <thead>
            <tr>
              <th />
              {b.map((m, j) => (
                <th key={j}>
                  <PokeIcon id={m.id} className="h-11 w-11" />
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {result.map((row, i) => (
              <tr key={i}>
                <td>
                  <PokeIcon id={a[i].id} className="h-11 w-11" />
                </td>
                {row.map((d, j) => (
                  <td key={j}>
                    {d && (
                      <button
                        type="button"
                        onClick={() => setDetail({ duel: d, mine: a[i].id, theirs: b[j].id })}
                        className="grid h-10 w-10 cursor-pointer place-items-center rounded-lg text-xs font-bold text-white transition hover:scale-110"
                        style={{ background: COLORS[d.result] }}
                      >
                        {d.mine.hits >= 99 ? '—' : `${d.mine.hits}×`}
                      </button>
                    )}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <p className="mt-3 text-xs text-muted">
        Linhas: seu time. Colunas: o time do amigo. O número é quantos golpes o seu precisa. Clique num quadrado para ver os golpes.
      </p>
      {detail && <Detail {...detail} onClose={() => setDetail(null)} />}
    </section>
  )
}
