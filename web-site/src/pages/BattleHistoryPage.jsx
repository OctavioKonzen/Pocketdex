// Histórico das batalhas contra o computador: vitórias, o seu MVP, cada
// Pokémon e o replay de cada batalha (igual ao app, battle_history_screen.dart).
// O replay refaz a batalha com a mesma semente e as suas jogadas
// (lib/battleLog.js) e mostra na mesma tela da batalha.

import { useEffect, useRef, useState } from 'react'
import { Link } from 'react-router-dom'
import PokeIcon from '../components/PokeIcon'
import { TrainerSprite } from '../components/Trainer'
import { Button, Empty, Icon, PageHeader } from '../components/ui'
import { battleHitter, battleMons } from '../lib/battleSetup'
import { battleStats, canReplay } from '../lib/battleLog'
import { simulatorDispose } from '../lib/battleSimulator'
import { t } from '../lib/i18n'
import { displayName } from '../lib/pokemon'
import { seededRandom } from '../lib/league'
import { usePokemonIndex } from '../lib/pokemonIndex'
import { useStore } from '../lib/store'
import { useTrainers } from '../lib/trainers'
import { active, newBattle, playTurn, replace, startBattle } from '../lib/turnBattle'
import { Battle } from './TurnBattlePage'

const CARD = 'rounded-2xl bg-card p-4 shadow-lg ring-1 ring-line'

export default function BattleHistoryPage() {
  const battles = useStore((s) => s.battles)
  const deleteBattle = useStore((s) => s.deleteBattle)
  const byId = usePokemonIndex()
  const trainers = useTrainers()
  const [watching, setWatching] = useState(null)
  const stats = battleStats(battles)
  if (watching) return <Replay record={watching} onExit={() => setWatching(null)} />
  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <PageHeader title="Histórico de batalhas" subtitle="Suas batalhas contra o computador, as estatísticas de cada Pokémon e o replay." />
      <Link to="/batalha" className="inline-flex items-center gap-1 text-sm text-muted hover:text-text">
        <Icon name="back" size={16} /> Centro de Batalha
      </Link>
      {!battles.length ? (
        <Empty>Nenhuma batalha ainda. Batalhe contra o computador e ela aparece aqui.</Empty>
      ) : (
        <>
          <section className={`${CARD} grid grid-cols-3 gap-3 text-center`} data-testid="battle-stats">
            <div>
              <div className="text-3xl font-black">{stats.battles}</div>
              <div className="text-xs text-muted">{t('Batalhas')}</div>
            </div>
            <div>
              <div className="text-3xl font-black text-green-500">{stats.wins}</div>
              <div className="text-xs text-muted">{t('Vitórias')}</div>
            </div>
            <div>
              <div className="text-3xl font-black">{stats.rate}%</div>
              <div className="text-xs text-muted">{t('Aproveitamento')}</div>
            </div>
          </section>
          {stats.mons.length > 0 && (
            <section className={CARD}>
              <h2 className="mb-3 font-black">{t('Seus Pokémon')}</h2>
              <div className="space-y-1.5">
                {stats.mons.slice(0, 12).map((m, i) => (
                  <div key={m.id} className="flex items-center gap-3 rounded-xl bg-bg px-2 py-1">
                    <PokeIcon id={m.id} className="h-10 w-10" />
                    <span className="flex-1 font-bold" data-no-translate>
                      {byId?.get(m.id) ? displayName(byId.get(m.id).name) : `#${m.id}`} {i === 0 && <span className="ml-1 rounded bg-amber-400 px-1.5 text-[10px] font-black text-black">MVP</span>}
                    </span>
                    <span className="text-sm text-muted">
                      {m.battles} {t('batalhas')} · {m.wins} {t('vitórias')} · {m.kos} {t('derrubados')}
                    </span>
                  </div>
                ))}
              </div>
            </section>
          )}
          <section className="space-y-2" data-testid="battle-history">
            {battles.map((b) => {
              const trainer = trainers?.find((x) => x.id === b.foeTrainer)
              return (
                <div key={b.id} className={`${CARD} flex flex-wrap items-center gap-3`}>
                  {trainer && <TrainerSprite trainer={trainer} box={48} still />}
                  <div className="min-w-0 flex-1">
                    <div className="font-black">
                      <span className={b.result === 'win' ? 'text-green-500' : 'text-red-500'}>{t(b.result === 'win' ? 'Vitória' : 'Derrota')}</span>{' '}
                      <span className="text-muted">·</span> <span data-no-translate>{b.foe || trainer?.name || t('Computador')}</span>
                    </div>
                    <div className="text-xs text-muted">
                      {new Date(b.at).toLocaleString()} · {b.turns} {t('turnos')} · {t({ easy: 'Fácil', normal: 'Normal' }[b.ai] ?? 'Normal')}
                    </div>
                    <div className="mt-1 flex gap-0.5">
                      {b.mine.map((m, i) => (
                        <PokeIcon key={i} id={m.id} shiny={Boolean(m.set?.shiny)} className="h-8 w-8" />
                      ))}
                      <span className="mx-1 self-center text-xs text-muted">vs</span>
                      {b.theirs.map((m, i) => (
                        <PokeIcon key={i} id={m.id} shiny={Boolean(m.set?.shiny)} className="h-8 w-8" />
                      ))}
                    </div>
                  </div>
                  <div className="flex gap-2">
                    {canReplay(b) && (
                      <Button onClick={() => setWatching(b)} data-testid={`replay-${b.id}`}>
                        ▶ {t('Assistir')}
                      </Button>
                    )}
                    <Button color="#64748b" onClick={() => deleteBattle(b.id)}>
                      {t('Apagar')}
                    </Button>
                  </div>
                </div>
              )
            })}
          </section>
        </>
      )}
    </div>
  )
}

/** O replay: refaz a batalha jogada a jogada e mostra na tela da batalha. */
function Replay({ record, onExit }) {
  const [game, setGame] = useState(null) // {battle, hit}
  const [online, setOnline] = useState(null)
  const [error, setError] = useState('')
  const step = useRef(0)
  useEffect(() => {
    let alive = true
    let built = null
    ;(async () => {
      const [hit, a, b] = await Promise.all([battleHitter(), battleMons(record.mine), battleMons(record.theirs)])
      if (!alive) return
      built = newBattle(a, b, seededRandom(record.seed), { ai: record.ai, seed: record.seed })
      setGame({ battle: built, hit })
    })().catch(() => alive && setError(t('Não foi possível abrir este replay.')))
    return () => {
      alive = false
      if (built) simulatorDispose(built)
    }
  }, [record])

  useEffect(() => {
    if (!game) return
    const { battle, hit } = game
    let round = 0
    const show = (events, before = null) => setOnline({ round: ++round, events, before, locked: true, side: 0, onPlayed: next, message: '', replay: true })
    function next() {
      if (step.current >= record.actions.length || battle.winner != null) return
      const action = record.actions[step.current++]
      const before = [active(battle, 0).id, active(battle, 1).id]
      try {
        show(action.replace != null ? replace(battle, action.replace) : playTurn(battle, action, hit), before)
      } catch {
        setError(t('O replay não pôde continuar daqui (os dados mudaram desde a batalha).'))
      }
    }
    step.current = 0
    show(startBattle(battle))
  }, [game, record])

  return (
    <div className="mx-auto max-w-3xl space-y-4">
      <PageHeader title="Replay" subtitle={`${t(record.result === 'win' ? 'Vitória' : 'Derrota')} · ${new Date(record.at).toLocaleString()}`} />
      {error && <p role="alert" className="text-red-400">{error}</p>}
      {game && online ? (
        <Battle battle={game.battle} foeName={record.foe} foeTrainer={record.foeTrainer} hit={game.hit} online={online} onExit={onExit} onAgain={onExit} />
      ) : (
        !error && <p className="text-muted">{t('Preparando o replay…')}</p>
      )}
      <Button color="#64748b" onClick={onExit}>
        {t('Voltar ao histórico')}
      </Button>
    </div>
  )
}
