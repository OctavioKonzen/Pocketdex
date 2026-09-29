// Registro de Nuzlocke: um Pokémon por local; quem desmaia vai para o
// cemitério. Os locais de cada jogo vêm do banco local.

import { useEffect, useMemo, useState } from 'react'
import { getGameAreas, getLocations, getPokemonById } from '../../lib/data'
import { locationName } from '../../lib/encounters'
import { language } from '../../lib/i18n'
import { GAMES, GAME_BY_KEY, displayName, generationBackground } from '../../lib/pokemon'
import { useStore } from '../../lib/store'
import PokemonPicker from '../PokemonPicker'
import Sprite from '../Sprite'
import { Button, Empty, Icon, Modal } from '../ui'

const STATUS = [
  { key: 'caught', label: 'Vivo', color: '#22c55e' },
  { key: 'dead', label: 'Morto', color: '#ef4444' },
  { key: 'missed', label: 'Perdido', color: '#78909c' },
]
const FIELD = 'w-full rounded-xl bg-surface px-3 py-2 outline-none focus:ring-2 focus:ring-sky-400'

export default function Nuzlocke() {
  const runs = useStore((s) => s.nuzlockes)
  const addNuzlocke = useStore((s) => s.addNuzlocke)
  const deleteNuzlocke = useStore((s) => s.deleteNuzlocke)
  const [areas, setAreas] = useState(null)
  const [openId, setOpenId] = useState(null)
  const [creating, setCreating] = useState(false)
  const [name, setName] = useState('')
  const [game, setGame] = useState('frlg')

  useEffect(() => {
    getGameAreas().then(setAreas)
  }, [])

  const games = GAMES.filter((g) => areas?.[g.key])
  const open = runs.find((r) => r.id === openId)
  if (open) return <Run run={open} areas={areas?.[open.game] ?? []} onBack={() => setOpenId(null)} />

  return (
    <div>
      <div className="mb-5 flex justify-end">
        <Button color="#EF5350" onClick={() => setCreating(true)}>
          + Novo Nuzlocke
        </Button>
      </div>
      {!runs.length ? (
        <Empty>Nenhum Nuzlocke ainda. Crie um para anotar cada captura por local, as mortes e o seu time.</Empty>
      ) : (
        <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
          {runs.map((r) => {
            const g = GAME_BY_KEY[r.game]
            const alive = r.entries.filter((e) => e.status === 'caught').length
            const dead = r.entries.filter((e) => e.status === 'dead').length
            return (
              <div key={r.id} className="flex items-center gap-3 rounded-2xl p-4 text-white shadow" style={{ background: g ? generationBackground(g) : '#546E7A' }}>
                <button type="button" onClick={() => setOpenId(r.id)} className="min-w-0 flex-1 cursor-pointer text-left">
                  <div className="truncate text-lg font-black">{r.name}</div>
                  <div className="text-sm opacity-90">{g?.name}</div>
                  <div className="mt-1 text-sm font-semibold">{`${alive} vivos · ${dead} mortos · ${r.entries.length} locais`}</div>
                </button>
                <button type="button" onClick={() => deleteNuzlocke(r.id)} aria-label="Apagar Nuzlocke" className="cursor-pointer opacity-80 hover:opacity-100">
                  <Icon name="delete" />
                </button>
              </div>
            )
          })}
        </div>
      )}

      <Modal open={creating} onClose={() => setCreating(false)} title="Novo Nuzlocke">
        <input value={name} onChange={(e) => setName(e.target.value)} placeholder="Nome (ex.: Minha run de FireRed)" className={FIELD} maxLength={40} />
        <select value={game} onChange={(e) => setGame(e.target.value)} className={`mt-3 ${FIELD}`}>
          {games.map((g) => (
            <option key={g.key} value={g.key}>
              {g.name}
            </option>
          ))}
        </select>
        <div className="mt-5 flex justify-end gap-3">
          <button type="button" onClick={() => setCreating(false)} className="cursor-pointer px-4 text-muted">
            Cancelar
          </button>
          <Button
            color="#EF5350"
            onClick={() => {
              const id = addNuzlocke({ name: name.trim() || GAME_BY_KEY[game]?.name || 'Nuzlocke', game })
              setCreating(false)
              setName('')
              setOpenId(id)
            }}
          >
            Criar
          </Button>
        </div>
      </Modal>
    </div>
  )
}

/** Um Nuzlocke aberto: capturas por local, com o estado de cada uma. */
function Run({ run, areas, onBack }) {
  const updateNuzlocke = useStore((s) => s.updateNuzlocke)
  const [byId, setById] = useState(null)
  const [locations, setLocations] = useState(null)
  const [area, setArea] = useState('')
  const [picking, setPicking] = useState(false)
  const [nickname, setNickname] = useState('')

  useEffect(() => {
    getPokemonById().then(setById)
    getLocations().then(setLocations)
  }, [])

  const used = useMemo(() => new Set(run.entries.map((e) => e.area)), [run.entries])
  const free = areas.filter((a) => !used.has(a))
  const chosen = area && !used.has(area) ? area : free[0] ?? ''
  const setEntries = (entries) => updateNuzlocke(run.id, { entries })
  const g = GAME_BY_KEY[run.game]

  const groups = STATUS.map((s) => ({ ...s, items: run.entries.filter((e) => e.status === s.key) }))

  return (
    <div>
      <button type="button" onClick={onBack} className="mb-3 flex cursor-pointer items-center gap-1 text-muted hover:text-text">
        <Icon name="back" size={20} /> Nuzlockes
      </button>
      <div className="mb-5 rounded-2xl p-4 text-white shadow" style={{ background: g ? generationBackground(g) : '#546E7A' }}>
        <div className="text-2xl font-black">{run.name}</div>
        <div className="text-sm opacity-90">{`${g?.name} · ${run.entries.length}/${areas.length} locais`}</div>
      </div>

      <div className="mb-6 rounded-2xl bg-card p-4 shadow">
        <div className="mb-2 font-bold">Novo encontro</div>
        <p className="mb-3 text-xs text-muted">Regra do Nuzlocke: só o primeiro Pokémon de cada local. Os locais já usados somem da lista.</p>
        <div className="grid gap-3 md:grid-cols-[2fr_1fr_auto]">
          <select value={chosen} onChange={(e) => setArea(e.target.value)} className={FIELD}>
            {free.map((a) => (
              <option key={a} value={a}>
                {locationName(locations, a, language)}
              </option>
            ))}
          </select>
          <input value={nickname} onChange={(e) => setNickname(e.target.value)} placeholder="Apelido (opcional)" className={FIELD} maxLength={20} />
          <Button color="#42A5F5" onClick={() => setPicking(true)} disabled={!chosen}>
            Escolher Pokémon
          </Button>
        </div>
      </div>

      {groups.map((group) => (
        <section key={group.key} className="mb-6">
          <h3 className="mb-2 font-bold" style={{ color: group.color }}>
            {group.label}
            {` (${group.items.length})`}
          </h3>
          {!group.items.length ? (
            <p className="text-sm text-muted">Nenhum.</p>
          ) : (
            <div className="grid gap-2 sm:grid-cols-2 xl:grid-cols-3">
              {group.items.map((e) => {
                const p = byId?.get(e.pokemonId)
                return (
                  <div key={e.area} className={`flex items-center gap-3 rounded-2xl bg-card p-3 shadow ${e.status === 'dead' ? 'opacity-70' : ''}`}>
                    <div className={`h-14 w-14 shrink-0 ${e.status === 'dead' ? 'grayscale' : ''}`}>{p && <Sprite path={p.sprite} box={p.box} />}</div>
                    <div className="min-w-0 flex-1">
                      <div className="truncate font-bold">{e.nickname || (p ? displayName(p.name) : '')}</div>
                      <div className="truncate text-xs text-muted">{locationName(locations, e.area, language)}</div>
                      <div className="mt-1 flex gap-1">
                        {STATUS.map((s) => (
                          <button
                            key={s.key}
                            type="button"
                            onClick={() => setEntries(run.entries.map((x) => (x.area === e.area ? { ...x, status: s.key } : x)))}
                            className="cursor-pointer rounded-full px-2 py-0.5 text-[11px] font-bold"
                            style={{ background: e.status === s.key ? s.color : 'var(--surface)', color: e.status === s.key ? '#fff' : 'var(--muted)' }}
                          >
                            {s.label}
                          </button>
                        ))}
                      </div>
                    </div>
                    <button
                      type="button"
                      onClick={() => setEntries(run.entries.filter((x) => x.area !== e.area))}
                      aria-label="Tirar encontro"
                      className="cursor-pointer text-muted hover:text-red-400"
                    >
                      <Icon name="close" size={18} />
                    </button>
                  </div>
                )
              })}
            </div>
          )}
        </section>
      ))}

      <PokemonPicker
        open={picking}
        title="Qual Pokémon apareceu?"
        onClose={() => setPicking(false)}
        onPick={(p) => {
          setEntries([...run.entries, { area: chosen, pokemonId: p.id, nickname: nickname.trim(), status: 'caught' }])
          setPicking(false)
          setNickname('')
          setArea('')
        }}
      />
    </div>
  )
}
