// Times da comunidade: todos os times de quem tem conta aparecem aqui.
// Pesquise pelo nome da pessoa para ver os times dela, dê sua nota (1 a 5
// estrelas) e salve uma cópia nos seus times. Se o dono excluir o time, ele
// some daqui.

import { m } from 'framer-motion'
import { useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Avatar } from '../components/AccountAvatar'
import Sprite from '../components/Sprite'
import TeamAnalysis, { RatingText, Stars } from '../components/TeamAnalysis'
import { Button, Empty, Icon, Loader, Modal, PageHeader, SearchInput } from '../components/ui'
import { errorMessage, getMyVote, getPublicTeam, rateTeam, searchPublicTeams, useAuth } from '../lib/auth'
import { getPokemonById, getTypes } from '../lib/data'
import { analyzeTeam } from '../lib/pokemon'
import { useStore } from '../lib/store'

export default function CommunityTeamsPage() {
  const user = useAuth((s) => (s.status === 'signedIn' ? s.user : null))
  const navigate = useNavigate()
  const [query, setQuery] = useState('')
  const [searched, setSearched] = useState('')
  const [results, setResults] = useState(null) // {list, error}
  const [byId, setById] = useState(null)
  const [open, setOpen] = useState(null)

  useEffect(() => {
    getPokemonById().then(setById)
  }, [])

  // Busca 0,4 s depois de parar de digitar (vazio = os mais recentes).
  useEffect(() => {
    if (!user) return
    let alive = true
    const timer = setTimeout(() => {
      searchPublicTeams(query.trim())
        .then((list) => alive && (setResults({ list, error: null }), setSearched(query.trim())))
        .catch((e) => alive && setResults({ list: [], error: errorMessage(e) }))
    }, 400)
    return () => {
      alive = false
      clearTimeout(timer)
    }
  }, [query, user])

  const updateTeam = (team) => setResults((r) => r && { ...r, list: r.list.map((t) => (t.id === team.id ? team : t)) })
  const removeTeam = (id) => setResults((r) => r && { ...r, list: r.list.filter((t) => t.id !== id) })

  return (
    <div>
      <button type="button" onClick={() => navigate('/times')} className="mb-3 flex cursor-pointer items-center gap-1 text-muted hover:text-text">
        <Icon name="back" size={20} /> Meus times
      </button>
      <PageHeader title="Times da comunidade" subtitle="Veja os times de outros treinadores, dê sua nota e salve os que gostar." />
      {!user ? (
        <Empty>Entre na sua conta para ver os times da comunidade.</Empty>
      ) : (
        <>
          <SearchInput value={query} onChange={setQuery} placeholder="Pesquisar pelo nome do treinador" className="mb-5 max-w-xl" />
          <p className="mb-4 text-sm text-muted">
            {searched ? `Times de “${searched}”` : 'Times mais recentes'}
          </p>
          {!results || !byId ? (
            <Loader />
          ) : results.error ? (
            <Empty>{results.error}</Empty>
          ) : results.list.length === 0 ? (
            <Empty>{searched ? 'Nenhum treinador com esse nome ou ele ainda não tem times.' : 'Ninguém publicou times ainda.'}</Empty>
          ) : (
            <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
              {results.list.map((team) => (
                <PublicTeamCard key={team.id} team={team} byId={byId} mine={team.ownerUid === user.uid} onOpen={() => setOpen(team)} onOwner={() => setQuery(team.ownerName)} />
              ))}
            </div>
          )}
        </>
      )}
      {open && (
        <PublicTeamModal
          team={open}
          byId={byId}
          onClose={() => setOpen(null)}
          onChange={(t) => (updateTeam(t), setOpen(t))}
          onGone={() => (removeTeam(open.id), setOpen(null))}
        />
      )}
    </div>
  )
}

function PublicTeamCard({ team, byId, mine, onOpen, onOwner }) {
  return (
    <m.div
      layout
      whileHover={{ scale: 1.03 }}
      onClick={onOpen}
      className="cursor-pointer rounded-3xl bg-card p-5 shadow-lg"
      style={{ borderLeft: `8px solid ${team.color ?? '#FF5252'}` }}
    >
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <h2 className="truncate text-lg font-bold">{team.name}</h2>
          <RatingText rating={team.rating} count={team.ratingCount} />
        </div>
        <button
          type="button"
          onClick={(e) => {
            e.stopPropagation()
            onOwner()
          }}
          className="flex shrink-0 cursor-pointer items-center gap-2 rounded-full bg-surface py-1 pr-3 pl-1 text-sm font-semibold hover:ring-2 hover:ring-sky-400"
          title="Ver todos os times deste treinador"
        >
          <Avatar pokemonId={team.avatar ?? null} name={team.ownerName} size={28} />
          <span className="max-w-[110px] truncate">{mine ? 'Você' : team.ownerName}</span>
        </button>
      </div>
      <div className="mt-4 grid grid-cols-6 gap-1">
        {team.pokemon.map((id, i) => {
          const p = id != null && byId.get(id)
          return (
            <div key={i} className="grid aspect-square place-items-center rounded-full bg-surface">
              {p && <Sprite path={p.sprite} box={p.box} fill={0.8} className="w-full" />}
            </div>
          )
        })}
      </div>
    </m.div>
  )
}

function PublicTeamModal({ team, byId, onClose, onChange, onGone }) {
  const user = useAuth((s) => s.user)
  const importTeam = useStore((s) => s.importTeam)
  const navigate = useNavigate()
  const [typeData, setTypeData] = useState(null)
  const [vote, setVote] = useState(null)
  const [message, setMessage] = useState('')
  const mine = team.ownerUid === user?.uid

  useEffect(() => {
    getTypes().then(setTypeData)
    if (!mine && user) getMyVote(user.uid, team.id).then(setVote).catch(() => {})
    // Confere se o dono não excluiu o time enquanto a página estava aberta.
    getPublicTeam(team.id)
      .then((t) => (t ? onChange(t) : onGone()))
      .catch(() => {})
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [team.id])

  const analysis = useMemo(() => {
    if (!typeData) return null
    const members = team.pokemon.filter((id) => id != null).map((id) => byId.get(id)).filter(Boolean)
    return analyzeTeam(members.map((p) => p.types), typeData)
  }, [team.pokemon, byId, typeData])

  const rate = async (stars) => {
    setMessage('')
    try {
      const r = await rateTeam(user.uid, team.id, stars)
      setVote(stars)
      onChange({ ...team, rating: r.rating, ratingCount: r.count })
      setMessage('Obrigado pela nota!')
    } catch (e) {
      setMessage(errorMessage(e))
    }
  }

  return (
    <Modal open onClose={onClose} title={team.name} wide>
      <div className="space-y-5">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="flex items-center gap-2">
            <Avatar pokemonId={team.avatar ?? null} name={team.ownerName} size={36} />
            <span className="font-bold">{mine ? 'Seu time' : `Time de ${team.ownerName}`}</span>
          </div>
          <RatingText rating={team.rating} count={team.ratingCount} />
        </div>
        <div className="grid grid-cols-3 gap-2 sm:grid-cols-6">
          {team.pokemon.map((id, i) => {
            const p = id != null && byId.get(id)
            return (
              <div key={i} className="grid aspect-square place-items-center rounded-2xl bg-surface">
                {p && <Sprite path={p.sprite} box={p.box} fill={0.85} className="w-full" />}
              </div>
            )
          })}
        </div>
        {!mine && (
          <div className="flex flex-wrap items-center gap-3 rounded-2xl bg-surface p-4">
            <span className="font-bold">{vote ? 'Sua nota:' : 'Dê sua nota:'}</span>
            <Stars value={vote ?? 0} onRate={rate} size={30} />
            {message && <span className="text-sm text-green-400">{message}</span>}
          </div>
        )}
        <TeamAnalysis analysis={analysis} />
        {!mine && (
          <div className="flex justify-end">
            <Button
              color="#FF5252"
              onClick={() => {
                const id = importTeam({ name: `${team.name} (${team.ownerName})`, color: team.color, pokemon: team.pokemon })
                navigate(`/times/${id}`)
              }}
            >
              Salvar nos meus times
            </Button>
          </div>
        )}
      </div>
    </Modal>
  )
}
