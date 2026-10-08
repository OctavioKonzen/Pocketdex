// Times dos personagens: os times oficiais dos líderes, Elite Four, campeões,
// vilões e rivais, exatamente como estão nos jogos (nível, golpes, item,
// IVs/DVs, EVs, nature e habilidade). Separados por jogo; ao abrir um
// personagem aparecem todas as lutas dele em todos os jogos.

import { useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import Sprite from '../components/Sprite'
import { TrainerSprite } from '../components/Trainer'
import { Button, Empty, Loader, Modal, PageHeader, SearchInput } from '../components/ui'
import { getOfficialTeams, getPokemonById } from '../lib/data'
import { abilityText, appearances, evText, filterTrainers, generationsOf, ivText } from '../lib/officialTeams'
import { prettyName } from '../lib/pokemon'
import { natureLabel, prettySlug } from '../lib/teamSets'
import { useTrainers } from '../lib/trainers'

export default function OfficialTeamsPage() {
  const navigate = useNavigate()
  const [games, setGames] = useState(null)
  const [byId, setById] = useState(null)
  const [gameId, setGameId] = useState(null)
  const [query, setQuery] = useState('')
  const [open, setOpen] = useState(null) // nome do personagem
  const trainers = useTrainers()
  const portrait = (id) => trainers?.find((t) => t.id === id)

  useEffect(() => {
    getOfficialTeams().then((g) => {
      setGames(g)
      setGameId((id) => id ?? g[0]?.id)
    })
    getPokemonById().then(setById)
  }, [])

  const game = games?.find((g) => g.id === gameId)
  const list = useMemo(() => (game ? filterTrainers(game, query) : []), [game, query])

  if (!games || !byId) return <Loader />
  return (
    <div>
      <PageHeader
        title="Times dos personagens"
        subtitle="Os times oficiais dos jogos: nível, golpes, item, IVs, EVs, nature e habilidade de cada Pokémon, em todas as lutas."
      >
        <Button color="#546E7A" onClick={() => navigate('/times')}>
          Voltar
        </Button>
      </PageHeader>

      {generationsOf(games).map((gen) => (
        <div key={gen} className="mb-2 flex flex-wrap items-center gap-2">
          <span className="w-20 text-xs text-muted">{gen}ª geração</span>
          {games
            .filter((g) => g.generation === gen)
            .map((g) => (
              <button
                key={g.id}
                type="button"
                onClick={() => setGameId(g.id)}
                aria-pressed={g.id === gameId}
                className={`cursor-pointer rounded-full px-3 py-1 text-sm font-bold ${g.id === gameId ? 'bg-[#FF5252] text-white' : 'bg-surface hover:bg-white/10'}`}
              >
                {g.name}
              </button>
            ))}
        </div>
      ))}

      {game?.source === 'community' && (
        <p className="mt-3 rounded-2xl bg-surface p-3 text-xs text-muted">
          📖 {game.name}: dados da comunidade (calculadoras de Nuzlocke, tirados dos jogos por fãs). Podem ter pequenas diferenças do
          jogo.
        </p>
      )}

      <SearchInput value={query} onChange={setQuery} placeholder="Buscar personagem ou classe" className="my-4" />

      {list.length === 0 ? (
        <Empty>Ninguém com esse nome em {game?.name}.</Empty>
      ) : (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {list.map((t) => (
            <button
              key={`${t.class}-${t.name}`}
              type="button"
              onClick={() => setOpen(t.name)}
              className="flex cursor-pointer items-center gap-3 rounded-2xl bg-card p-3 text-left hover:bg-white/5"
            >
              <TrainerSprite trainer={portrait(t.trainer)} box={64} still className="shrink-0" />
              <div className="min-w-0 flex-1">
                <div className="truncate font-bold">{t.name}</div>
                <div className="truncate text-xs text-muted">
                  {t.class} · {t.battles.length} {t.battles.length === 1 ? 'luta' : 'lutas'}
                </div>
                <div className="mt-1 flex flex-wrap">
                  {t.battles[t.battles.length - 1].team.map((mon, i) => {
                    const p = byId.get(mon.id)
                    return p ? <Sprite key={i} path={p.sprite} box={p.box} fill={0.9} className="h-8 w-8" /> : null
                  })}
                </div>
              </div>
            </button>
          ))}
        </div>
      )}

      <p className="mt-6 text-xs text-muted">
        Dados tirados do código dos jogos: da 1ª à 4ª geração pelos projetos de desmontagem do pret (github.com/pret), Black 2/White 2
        pela desmontagem pokebw2 e Scarlet/Violet (versão 1.0, sem as DLCs) pelos arquivos do jogo. Os outros jogos (marcados com 📖)
        vêm dos dados de treinadores do Trevenant/VanillaNuzlockeCalc, feitos pela comunidade.
      </p>

      <TrainerModal key={open ?? ''} name={open} games={games} gameId={gameId} byId={byId} onClose={() => setOpen(null)} />
    </div>
  )
}

function TrainerModal({ name, games, gameId, byId, onClose }) {
  const all = useMemo(() => (name ? appearances(games, name) : []), [name, games])
  // Abre no jogo escolhido na lista; os outros jogos ficam nos botões.
  const [pick, setPick] = useState(() => Math.max(0, all.findIndex((a) => a.game.id === gameId)))
  const current = all[pick]

  return (
    <Modal open={Boolean(name)} onClose={onClose} title={name ?? ''} wide>
      {current && (
        <>
          {all.length > 1 && (
            <div className="mb-4">
              <div className="mb-1 text-xs text-muted">Todas as aparições:</div>
              <div className="flex flex-wrap gap-2">
                {all.map((a, i) => (
                  <button
                    key={`${a.game.id}-${a.trainer.class}`}
                    type="button"
                    onClick={() => setPick(i)}
                    aria-pressed={i === pick}
                    className={`cursor-pointer rounded-full px-3 py-1 text-xs font-bold ${i === pick ? 'bg-[#FF5252] text-white' : 'bg-surface hover:bg-white/10'}`}
                  >
                    {a.game.name} · {a.trainer.class}
                  </button>
                ))}
              </div>
            </div>
          )}
          <p className="mb-3 text-sm text-muted">
            {current.trainer.class} em {current.game.name} ({current.game.region})
          </p>
          {current.trainer.battles.map((battle, b) => (
            <section key={b} className="mb-5">
              <h3 className="mb-2 font-bold">{battle.label}</h3>
              <div className="grid grid-cols-1 gap-2 sm:grid-cols-2 lg:grid-cols-3">
                {battle.team.map((mon, i) => (
                  <OfficialMon key={i} mon={mon} p={byId.get(mon.id)} />
                ))}
              </div>
            </section>
          ))}
        </>
      )}
    </Modal>
  )
}

function OfficialMon({ mon, p }) {
  if (!p) return null
  return (
    <div className="flex gap-3 rounded-2xl bg-surface p-3">
      <Sprite path={p.sprite} box={p.box} fill={0.85} className="h-20 w-20 shrink-0" />
      <div className="min-w-0 text-xs">
        <div className="truncate text-sm font-bold">
          {prettyName(p.name)}
          {mon.shiny ? ' ✨' : ''}
        </div>
        <div className="text-muted">
          <div className="truncate">
            Nv. {mon.level}
            {mon.item ? ` · @ ${prettySlug(mon.item)}` : ''}
            {mon.tera ? ` · Tera ${prettySlug(mon.tera)}` : ''}
          </div>
          {abilityText(mon, prettySlug) && <div>{abilityText(mon, prettySlug)}</div>}
          <div className="truncate">{mon.nature ? natureLabel(mon.nature) : !mon.dv && 'Nature sorteada'}</div>
          <div>{ivText(mon)}</div>
          <div>{evText(mon)}</div>
          <div className="text-text">{mon.moves.map(prettySlug).join(' · ')}</div>
        </div>
      </div>
    </div>
  )
}
