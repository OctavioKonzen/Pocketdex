import { m } from 'framer-motion'
import { useEffect, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { ImportTeamModal } from '../components/TeamShare'
import { RatingText } from '../components/TeamAnalysis'
import { myTeamRatings, useAuth } from '../lib/auth'
import { useTeamsVersion } from '../lib/sync'
import { Button, Empty, Icon, Modal, PageHeader } from '../components/ui'
import { getPokemonById } from '../lib/data'
import { useStore } from '../lib/store'
import Sprite from '../components/Sprite'

export default function TeamsPage() {
  const teams = useStore((s) => s.teams)
  const createTeam = useStore((s) => s.createTeam)
  const deleteTeam = useStore((s) => s.deleteTeam)
  const importTeam = useStore((s) => s.importTeam)
  const navigate = useNavigate()
  // Link de time compartilhado: #/times/importar/<código>
  const { code } = useParams()
  const [importing, setImporting] = useState(false)
  const [byId, setById] = useState(null)
  const [creating, setCreating] = useState(false)
  const [name, setName] = useState('')
  const [deleting, setDeleting] = useState(null)

  useEffect(() => {
    getPokemonById().then(setById)
  }, [])

  // Nota da comunidade de cada time (os times de quem tem conta são públicos).
  const user = useAuth((s) => (s.status === 'signedIn' ? s.user : null))
  const teamsVersion = useTeamsVersion((s) => s.version)
  const [ratings, setRatings] = useState({})
  useEffect(() => {
    if (!user) return
    let alive = true
    myTeamRatings(user.uid)
      .then((r) => alive && setRatings(r))
      .catch(() => {})
    return () => {
      alive = false
    }
  }, [user, teamsVersion])

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
        <div className="flex flex-wrap gap-2">
          {user && (
            <Button color="linear-gradient(135deg, #7E57C2, #3949AB)" onClick={() => navigate('/times/comunidade')}>
              🔎 Times da comunidade
            </Button>
          )}
          <Button color="#546E7A" onClick={() => setImporting(true)}>
            Importar
          </Button>
          <Button color="#FF5252" onClick={() => setCreating(true)}>
            + Novo time
          </Button>
        </div>
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
                <p className="text-sm text-muted">{team.pokemon.filter(Boolean).length}/6 Pokémon</p>
                {user && <RatingText rating={ratings[team.id]?.rating ?? null} count={ratings[team.id]?.count ?? 0} />}
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

      <ImportTeamModal
        key={code ?? 'manual'}
        open={importing || Boolean(code)}
        initial={code ?? ''}
        onClose={() => {
          setImporting(false)
          if (code) navigate('/times', { replace: true })
        }}
        onImport={(team) => {
          const id = importTeam(team)
          setImporting(false)
          navigate(`/times/${id}`, { replace: Boolean(code) })
        }}
      />

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
