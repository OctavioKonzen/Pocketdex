import { m } from 'framer-motion'
import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Button, Empty, Icon, Modal, PageHeader } from '../components/ui'
import { getPokemonById } from '../lib/data'
import { useStore } from '../lib/store'
import Sprite from '../components/Sprite'

export default function TeamsPage() {
  const teams = useStore((s) => s.teams)
  const createTeam = useStore((s) => s.createTeam)
  const deleteTeam = useStore((s) => s.deleteTeam)
  const navigate = useNavigate()
  const [byId, setById] = useState(null)
  const [creating, setCreating] = useState(false)
  const [name, setName] = useState('')
  const [deleting, setDeleting] = useState(null)

  useEffect(() => {
    getPokemonById().then(setById)
  }, [])

  const create = (e) => {
    e.preventDefault()
    if (!name.trim()) return
    const id = createTeam(name.trim())
    setCreating(false)
    setName('')
    navigate(`/times/${id}`)
  }

  return (
    <div>
      <PageHeader title="Montador de Times" subtitle="Monte times de até 6 Pokémon e veja as fraquezas e a nota de cada um.">
        <Button color="#FF5252" onClick={() => setCreating(true)}>
          + Novo time
        </Button>
      </PageHeader>

      {teams.length === 0 && <Empty>Você ainda não criou nenhum time. Clique em “Novo time” para começar!</Empty>}

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
        {teams.map((team) => (
          <m.div
            key={team.id}
            layout
            whileHover={{ scale: 1.03 }}
            onClick={() => navigate(`/times/${team.id}`)}
            className="cursor-pointer rounded-3xl bg-card p-5 shadow-lg"
            style={{ borderLeft: `8px solid ${team.color ?? '#FF5252'}` }}
          >
            <div className="flex items-start justify-between">
              <div>
                <h2 className="text-lg font-bold">{team.name}</h2>
                <p className="text-sm text-muted">
                  {team.pokemon.filter(Boolean).length}/6 Pokémon
                  {team.score != null && ` · Nota ${team.score.toFixed(1)}`}
                </p>
              </div>
              <button
                type="button"
                aria-label="Deletar time"
                onClick={(e) => {
                  e.stopPropagation()
                  setDeleting(team)
                }}
                className="cursor-pointer rounded-full p-2 text-muted hover:bg-red-500/20 hover:text-red-400"
              >
                <Icon name="delete" />
              </button>
            </div>
            <div className="mt-4 grid grid-cols-6 gap-1">
              {team.pokemon.map((id, i) => {
                const p = id && byId?.get(id)
                return (
                  <div key={i} className="grid aspect-square place-items-center rounded-full bg-surface">
                    {p && <Sprite path={p.sprite} box={p.box} fill={0.8} className="w-full" />}
                  </div>
                )
              })}
            </div>
          </m.div>
        ))}
      </div>

      <Modal open={creating} onClose={() => setCreating(false)} title="Criar Novo Time">
        <form onSubmit={create} className="space-y-4">
          <input
            autoFocus
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Nome do time"
            className="w-full rounded-xl bg-surface px-4 py-3 ring-1 ring-line outline-none focus:ring-2 focus:ring-sky-400"
          />
          <div className="flex justify-end gap-3">
            <button type="button" onClick={() => setCreating(false)} className="cursor-pointer px-4 text-muted">
              Cancelar
            </button>
            <Button type="submit" color="#FF5252" disabled={!name.trim()}>
              Criar
            </Button>
          </div>
        </form>
      </Modal>

      <Modal open={Boolean(deleting)} onClose={() => setDeleting(null)} title="Deletar Time">
        <p>Tem certeza que deseja deletar o time “{deleting?.name}”?</p>
        <div className="mt-5 flex justify-end gap-3">
          <button type="button" onClick={() => setDeleting(null)} className="cursor-pointer px-4 text-muted">
            Cancelar
          </button>
          <Button
            color="#e53935"
            onClick={() => {
              deleteTeam(deleting.id)
              setDeleting(null)
            }}
          >
            Deletar
          </Button>
        </div>
      </Modal>
    </div>
  )
}
