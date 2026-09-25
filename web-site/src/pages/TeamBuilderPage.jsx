import { m } from 'framer-motion'
import { useEffect, useMemo, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import PokemonPicker from '../components/PokemonPicker'
import { Button, Empty, Icon, Loader, Modal, TypeBadge } from '../components/ui'
import { getPokemonById, getTypes } from '../lib/data'
import { ALL_TYPES, analyzeTeam, teamScore } from '../lib/pokemon'
import { useStore } from '../lib/store'
import PokemonCard, { CARD_STYLE } from '../components/PokemonCard'

const TEAM_COLORS = ['#FF5252', '#FFA726', '#FFCA28', '#66BB6A', '#26A69A', '#42A5F5', '#5C6BC0', '#AB47BC', '#EC407A', '#8D6E63', '#78909C']

export default function TeamBuilderPage() {
  const { id } = useParams()
  const navigate = useNavigate()
  const team = useStore((s) => s.teams.find((t) => t.id === id))
  const updateTeam = useStore((s) => s.updateTeam)
  const [byId, setById] = useState(null)
  const [typeData, setTypeData] = useState(null)
  const [pickingSlot, setPickingSlot] = useState(null)
  const [removingSlot, setRemovingSlot] = useState(null)

  useEffect(() => {
    getPokemonById().then(setById)
    getTypes().then(setTypeData)
  }, [])

  const members = useMemo(() => (team && byId ? team.pokemon.filter(Boolean).map((pid) => byId.get(pid)).filter(Boolean) : []), [team, byId])
  const analysis = useMemo(() => (typeData ? analyzeTeam(members.map((m) => m.types), typeData) : null), [members, typeData])
  const score = teamScore(analysis)

  // Guarda a nota junto com o time (aparece na lista de times).
  useEffect(() => {
    if (team && typeData && byId && team.score !== score) updateTeam(team.id, { score })
  }, [team, score, typeData, byId, updateTeam])

  if (!team) {
    return (
      <Empty>
        Time não encontrado. <Link to="/times" className="underline">Voltar aos times</Link>
      </Empty>
    )
  }
  if (!byId || !typeData) return <Loader />

  const setSlot = (slot, pokemonId) => {
    const pokemon = [...team.pokemon]
    pokemon[slot] = pokemonId
    updateTeam(team.id, { pokemon })
  }

  const color = team.color ?? '#FF5252'

  return (
    <div>
      <button type="button" onClick={() => navigate('/times')} className="mb-3 flex cursor-pointer items-center gap-1 text-muted hover:text-text">
        <Icon name="back" size={20} /> Times
      </button>

      <div className="grid gap-6 xl:grid-cols-[1fr_1fr]">
        <section className="rounded-3xl bg-card p-6 shadow-lg">
          <input
            value={team.name}
            onChange={(e) => updateTeam(team.id, { name: e.target.value })}
            className="w-full bg-transparent text-2xl font-bold outline-none"
            aria-label="Nome do time"
          />
          <div className="mt-3 flex flex-wrap gap-2">
            {TEAM_COLORS.map((c) => (
              <m.button
                key={c}
                type="button"
                whileHover={{ scale: 1.2 }}
                onClick={() => updateTeam(team.id, { color: c })}
                aria-label={`Cor ${c}`}
                className="h-7 w-7 cursor-pointer rounded-full"
                style={{ background: c, outline: c === color ? '3px solid var(--text)' : 'none', outlineOffset: 2 }}
              />
            ))}
          </div>

          <h3 className="mt-6 mb-3 font-bold">Pokémon</h3>
          <div className="grid grid-cols-2 gap-4 sm:grid-cols-3">
            {team.pokemon.map((pid, slot) => {
              const p = pid && byId.get(pid)
              // Mesmo card da Pokédex; clicar remove do time.
              return p ? (
                <PokemonCard key={slot} pokemon={p} onClick={() => setRemovingSlot(slot)} />
              ) : (
                <m.button
                  key={slot}
                  type="button"
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.96 }}
                  onClick={() => setPickingSlot(slot)}
                  aria-label="Adicionar Pokémon"
                  className="grid cursor-pointer place-items-center rounded-[18px]"
                  style={{ height: CARD_STYLE.height, background: 'var(--surface)', border: '2px dashed var(--line)' }}
                >
                  <Icon name="add" size={40} className="text-muted" />
                </m.button>
              )
            })}
          </div>
        </section>

        <section className="rounded-3xl bg-card p-6 shadow-lg">
          <h3 className="text-lg font-bold">Análise do time</h3>
          <div className="mt-4 flex items-center gap-4">
            <div className="text-5xl font-black" style={{ color }}>
              {score.toFixed(1)}
            </div>
            <div className="flex-1">
              <div className="text-sm text-muted">Nota (0 a 10)</div>
              <div className="mt-1 h-3 overflow-hidden rounded-full bg-white/15">
                <m.div className="h-full rounded-full" style={{ background: color }} animate={{ width: `${score * 10}%` }} />
              </div>
            </div>
          </div>

          {!analysis ? (
            <p className="mt-6 text-muted">Adicione Pokémon para ver a análise.</p>
          ) : (
            <div className="mt-6 space-y-4">
              <Group title="Fraquezas" entries={Object.entries(analysis.weaknesses)} suffix={(m) => `×${m}`} />
              <Group title="Resistências" entries={Object.entries(analysis.resistances)} suffix={(m) => `×${m}`} />
              <Group title="Imunidades" entries={analysis.immunities.map((t) => [t])} />
              <Group title="Vantagem ofensiva" entries={Object.entries(analysis.advantages)} suffix={(n) => `${n}×`} />
              <div>
                <div className="mb-2 text-sm text-muted">Tipos sem nenhuma vantagem ofensiva</div>
                <div className="flex flex-wrap gap-1.5">
                  {ALL_TYPES.filter((t) => !analysis.advantages[t]).map((t) => (
                    <TypeBadge key={t} type={t} small />
                  ))}
                </div>
              </div>
            </div>
          )}
        </section>
      </div>

      <PokemonPicker
        open={pickingSlot !== null}
        onClose={() => setPickingSlot(null)}
        onPick={(p) => {
          setSlot(pickingSlot, p.id)
          setPickingSlot(null)
        }}
      />

      <Modal open={removingSlot !== null} onClose={() => setRemovingSlot(null)} title="Remover Pokémon?">
        <p>Deseja remover este Pokémon do time?</p>
        <div className="mt-5 flex justify-end gap-3">
          <button type="button" onClick={() => setRemovingSlot(null)} className="cursor-pointer px-4 text-muted">
            Cancelar
          </button>
          <Button
            color="#e53935"
            onClick={() => {
              setSlot(removingSlot, null)
              setRemovingSlot(null)
            }}
          >
            Remover
          </Button>
        </div>
      </Modal>
    </div>
  )
}

function Group({ title, entries, suffix }) {
  return (
    <div>
      <div className="mb-2 text-sm text-muted">{title}</div>
      {entries.length === 0 ? (
        <span className="text-sm text-muted">Nenhuma</span>
      ) : (
        <div className="flex flex-wrap gap-2">
          {entries.map(([type, value]) => (
            <span key={type} className="flex items-center gap-1">
              <TypeBadge type={type} small />
              {suffix && <span className="text-xs text-muted">{suffix(value)}</span>}
            </span>
          ))}
        </div>
      )}
    </div>
  )
}
