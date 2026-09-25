// "Quem é esse Pokémon?" — mesmas regras do app: 4 opções, 3 vidas, recorde
// salvo e jogo em andamento que pode ser continuado depois.
//
// Layout de tela cheia: Pokémon (silhueta) de um lado e as opções do outro;
// no celular um embaixo do outro. Teclas 1 a 4 respondem.
//
// Modo Ranked (precisa de login): todas as gerações, 5 segundos por Pokémon.
// Só o recorde do Ranked entra no ranking.

import { AnimatePresence, m } from 'framer-motion'
import { useCallback, useEffect, useRef, useState } from 'react'
import GenerationPicker from '../components/GenerationPicker'
import Sprite from '../components/Sprite'
import { Button, Icon, Loader, Modal } from '../components/ui'
import { getRanking, getRankingPosition, useAuth } from '../lib/auth'
import { getPokedex } from '../lib/data'
import { GENERATIONS, generationBackground, prettyName } from '../lib/pokemon'
import { useStore } from '../lib/store'
import { useRankingVersion } from '../lib/sync'

const LIVES = 3
const RANKED_SECONDS = 5
// Ranked fica mais difícil com os pontos: 100 → 4 s, 200 → 3 s, 400 → 2 s (até perder).
function rankedSeconds(score) {
  if (score >= 400) return 2
  if (score >= 200) return 3
  if (score >= 100) return 4
  return RANKED_SECONDS
}
const TIMEOUT = -1 // "resposta" quando o tempo acaba
const TOP_BAR = 72

function pickQuestion(pool) {
  const answer = pool[Math.floor(Math.random() * pool.length)]
  const options = new Set([answer.id])
  while (options.size < Math.min(4, pool.length)) options.add(pool[Math.floor(Math.random() * pool.length)].id)
  return { answerId: answer.id, options: [...options].sort(() => Math.random() - 0.5) }
}

/** Fundo clássico do "Quem é esse Pokémon?": raios azuis girando. */
function Stage({ children }) {
  return (
    <div className="relative flex h-full min-h-[320px] items-center justify-center overflow-hidden rounded-[32px] bg-[#1d5fc2] shadow-2xl">
      <div
        className="spin-slower pointer-events-none absolute top-1/2 left-1/2 aspect-square w-[220%] -translate-x-1/2 -translate-y-1/2"
        style={{ background: 'repeating-conic-gradient(from 0deg, #3b8ff0 0deg 10deg, #1d5fc2 10deg 20deg)' }}
      />
      <div className="pointer-events-none absolute inset-0" style={{ background: 'radial-gradient(circle, rgba(255,255,255,.35) 0%, rgba(255,255,255,0) 55%)' }} />
      {children}
    </div>
  )
}

const layoutHeight = { minHeight: `calc(100vh - ${TOP_BAR}px - 40px)` }

const MEDALS = ['#FFD54F', '#CFD8DC', '#FFAB91']

function RankingRow({ position, name, score, me, index }) {
  const medal = MEDALS[position - 1]
  return (
    <m.li
      initial={{ opacity: 0, x: 16 }}
      animate={{ opacity: 1, x: 0 }}
      transition={{ delay: index * 0.04 }}
      className={`flex items-center gap-3 rounded-2xl px-3 py-2.5 ${me ? 'bg-yellow-400/15 ring-2 ring-yellow-400' : 'bg-surface'}`}
    >
      <span
        className="grid h-9 w-9 shrink-0 place-items-center rounded-full text-sm font-black"
        style={medal ? { background: medal, color: '#3e2723' } : { background: 'var(--card)', color: 'var(--muted)' }}
      >
        {position}
      </span>
      <span className="min-w-0 flex-1 truncate font-bold">
        {name}
        {me && <span className="ml-2 text-xs font-semibold text-yellow-400">você</span>}
      </span>
      <span className="text-lg font-black text-yellow-400">{score}</span>
    </m.li>
  )
}

/** Melhores recordes de todos os jogadores (Firestore: ranking/{uid}). */
function Ranking() {
  const user = useAuth((s) => (s.status === 'signedIn' ? s.user : null))
  const record = useStore((s) => s.rankedRecord)
  const version = useRankingVersion((s) => s.version)
  const [data, setData] = useState(null) // {list, position, error}

  useEffect(() => {
    if (!user) return
    let alive = true
    Promise.all([getRanking(10), record > 0 ? getRankingPosition(record) : null])
      .then(([list, position]) => alive && setData({ list, position, error: false }))
      .catch(() => alive && setData({ list: [], position: null, error: true }))
    return () => {
      alive = false
    }
  }, [user, record, version])

  if (!user) return null
  const inTop = data?.list.some((r) => r.uid === user.uid)
  return (
    <div className="flex flex-col rounded-[32px] bg-card p-6 shadow-xl sm:p-8 lg:col-span-2 xl:col-span-1">
      <div className="mb-4 flex items-center gap-3">
        <span className="grid h-12 w-12 place-items-center rounded-full bg-yellow-400 text-2xl">🏅</span>
        <div>
          <h2 className="text-2xl font-black">Ranking</h2>
          <p className="text-sm text-muted">Os maiores recordes no modo Ranked.</p>
        </div>
      </div>
      {!data ? (
        <Loader size={56} />
      ) : data.error ? (
        <p className="py-10 text-center text-muted">Não foi possível carregar o ranking agora.</p>
      ) : data.list.length === 0 ? (
        <p className="py-10 text-center text-muted">Ninguém pontuou no Ranked ainda. Seja o primeiro!</p>
      ) : (
        <ol className="space-y-2">
          {data.list.map((r, i) => (
            <RankingRow key={r.uid} index={i} position={i + 1} name={r.name} score={r.score} me={r.uid === user.uid} />
          ))}
          {!inTop && data.position && (
            <>
              <li className="py-1 text-center text-muted">⋯</li>
              <RankingRow index={data.list.length} position={data.position} name={user.name} score={record} me />
            </>
          )}
        </ol>
      )}
    </div>
  )
}

export default function GamePage() {
  const normalRecord = useStore((s) => s.quizRecord)
  const rankedRecord = useStore((s) => s.rankedRecord)
  const saved = useStore((s) => s.quizGame)
  const saveNormalGame = useStore((s) => s.saveQuizGame)
  const finishNormal = useStore((s) => s.finishQuiz)
  const finishRanked = useStore((s) => s.finishRanked)
  const canRank = useAuth((s) => s.status === 'signedIn')
  const [pokedex, setPokedex] = useState(null)
  const [generation, setGeneration] = useState(0)
  const [game, setGame] = useState(null) // {generation, score, lives, streak, answerId, options}
  const [chosen, setChosen] = useState(null)
  const [ended, setEnded] = useState(null) // {score, ranked, newRecord}

  useEffect(() => {
    getPokedex().then(setPokedex)
  }, [])

  const pool = useCallback((gen) => (gen ? pokedex.filter((p) => p.gen === gen) : pokedex), [pokedex])
  const byId = (id) => pokedex.find((p) => p.id === id)

  // O Ranked não fica salvo para continuar depois (senão daria para ganhar tempo).
  const saveGame = useCallback((g) => !g.ranked && saveNormalGame(g), [saveNormalGame])

  const start = (ranked = false) => {
    const gen = ranked ? 0 : generation
    const g = { generation: gen, ranked, round: 0, score: 0, lives: LIVES, streak: 0, ...pickQuestion(pool(gen)) }
    setGame(g)
    saveGame(g)
    setChosen(null)
  }

  const end = useCallback(
    (g) => {
      const record = g.ranked ? useStore.getState().rankedRecord : useStore.getState().quizRecord
      if (g.ranked) finishRanked(g.score)
      else finishNormal(g.score)
      setGame(null)
      setChosen(null)
      setEnded({ score: g.score, ranked: g.ranked, newRecord: g.score > record })
    },
    [finishNormal, finishRanked],
  )

  // Sair da página no meio de um Ranked encerra o jogo com os pontos feitos.
  const gameRef = useRef(null)
  useEffect(() => {
    gameRef.current = game
  }, [game])
  useEffect(() => () => gameRef.current?.ranked && finishRanked(gameRef.current.score), [finishRanked])

  const answer = useCallback(
    (id) => {
      if (chosen || !game) return
      setChosen(id)
      const correct = id === game.answerId
      const next = {
        ...game,
        score: game.score + (correct ? 1 : 0),
        lives: game.lives - (correct ? 0 : 1),
        streak: correct ? (game.streak ?? 0) + 1 : 0,
      }
      setTimeout(
        () => {
          setChosen(null)
          if (next.lives === 0) {
            end(next)
          } else {
            const g = { ...next, round: (next.round ?? 0) + 1, ...pickQuestion(pool(next.generation)) }
            setGame(g)
            saveGame(g)
          }
        },
        correct ? 1100 : 2000,
      )
    },
    [chosen, game, end, pool, saveGame],
  )

  // Ranked: tempo para responder cada Pokémon (diminui com os pontos).
  useEffect(() => {
    if (!game?.ranked || chosen) return
    const timer = setTimeout(() => answer(TIMEOUT), rankedSeconds(game.score) * 1000)
    return () => clearTimeout(timer)
  }, [game, chosen, answer])

  // Teclas 1 a 4 escolhem a resposta.
  useEffect(() => {
    if (!game) return
    const onKey = (e) => {
      if (e.target.closest('input, textarea')) return
      const index = Number(e.key) - 1
      if (index >= 0 && index < game.options.length) answer(game.options[index])
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [game, answer])

  if (!pokedex) return <Loader />

  // ---------------------------------------------------------------- Menu
  if (!game) {
    const gen = GENERATIONS.find((g) => g.id === generation)
    const showcase = gen ? gen.starters : [25, 6, 150]
    return (
      <div className="grid gap-6 lg:grid-cols-[1.2fr_1fr] xl:grid-cols-[1.3fr_1fr_1fr]" style={layoutHeight}>
        <Stage>
          <div className="relative mt-16 flex w-full max-w-2xl items-end justify-center gap-2 px-6">
            {showcase.map((id, i) => {
              const p = byId(id)
              return p ? (
                <m.div
                  key={`${generation}-${id}`}
                  className="w-1/3"
                  initial={{ y: 40, opacity: 0 }}
                  animate={{ y: 0, opacity: 1 }}
                  transition={{ delay: i * 0.1, type: 'spring', stiffness: 200, damping: 16 }}
                  style={{ filter: 'brightness(0)' }}
                >
                  <Sprite path={p.sprite} box={p.box} align="bottom" />
                </m.div>
              ) : null
            })}
          </div>
          <h1 className="absolute top-6 left-0 w-full text-center text-3xl font-black tracking-tight text-yellow-300 drop-shadow-[0_3px_0_#1b3f8a] sm:text-5xl">
            Quem é esse Pokémon?
          </h1>
        </Stage>

        <div className="flex flex-col justify-center gap-5 rounded-[32px] bg-card p-6 shadow-xl sm:p-8">
          <div className={`grid gap-3 ${canRank ? 'grid-cols-2' : ''}`}>
            <div className="flex items-center gap-3 rounded-2xl bg-surface p-4">
              <span className="grid h-12 w-12 shrink-0 place-items-center rounded-full bg-sky-500 text-2xl">🎮</span>
              <div>
                <div className="text-sm text-muted">Recorde normal</div>
                <div className="text-2xl font-black text-sky-400">{normalRecord}</div>
              </div>
            </div>
            {canRank && (
              <div className="flex items-center gap-3 rounded-2xl bg-surface p-4">
                <span className="grid h-12 w-12 shrink-0 place-items-center rounded-full bg-yellow-400 text-2xl">🏆</span>
                <div>
                  <div className="text-sm text-muted">Recorde Ranked</div>
                  <div className="text-2xl font-black text-yellow-400">{rankedRecord}</div>
                </div>
              </div>
            )}
          </div>
          <ul className="space-y-1 text-sm text-muted">
            <li>• Adivinhe o Pokémon pela silhueta entre 4 opções.</li>
            <li>• Você tem 3 vidas; cada erro custa uma.</li>
            <li>• Use o mouse ou as teclas 1 a 4.</li>
            {canRank && (
              <li>
                • <b className="text-yellow-400">Ranked:</b> todas as gerações e só {RANKED_SECONDS} segundos por Pokémon, que caem para 4 s com 100 pontos, 3 s com 200 e 2 s com 400. É ele que conta para o ranking.
              </li>
            )}
          </ul>
          <div>
            <div className="mb-2 text-sm font-semibold">Geração</div>
            <GenerationPicker value={generation || null} onChange={(g) => setGeneration(g ?? 0)} />
          </div>
          <div className="flex flex-col gap-3">
            {saved && saved.lives > 0 && (
              <Button color="#43a047" onClick={() => setGame(saved)} className="w-full py-4 text-lg">
                ▶ Continuar jogo ({saved.score} pontos)
              </Button>
            )}
            <Button onClick={() => start(false)} className="w-full py-4 text-lg">
              ▶ {saved ? 'Novo jogo normal' : 'Jogo normal'}
            </Button>
            {canRank && (
              <Button onClick={() => start(true)} color="linear-gradient(135deg, #f9a825, #e65100)" className="w-full py-4 text-lg">
                🏆 Jogar Ranked ({RANKED_SECONDS}s → 2s por Pokémon)
              </Button>
            )}
          </div>
        </div>
        <Ranking />
        <EndModal result={ended} onClose={() => setEnded(null)} onRestart={() => (setEnded(null), start(ended.ranked))} />
      </div>
    )
  }

  // ---------------------------------------------------------------- Jogo
  const answerPokemon = byId(game.answerId)
  const revealed = Boolean(chosen)
  const hit = revealed && chosen === game.answerId
  const gen = GENERATIONS.find((g) => g.id === game.generation)
  const record = game.ranked ? rankedRecord : normalRecord

  return (
    <div className="grid gap-6 lg:grid-cols-[1.4fr_1fr]" style={layoutHeight}>
      <Stage>
        <div className="relative aspect-square h-[78%] max-h-[640px] max-w-[90%]">
          <AnimatePresence mode="wait">
            <m.div
              key={game.answerId}
              className="h-full w-full"
              initial={{ scale: 0.6, opacity: 0 }}
              animate={{ scale: revealed ? [1, 1.12, 1] : 1, opacity: 1 }}
              exit={{ scale: 0.6, opacity: 0 }}
              transition={{ duration: 0.4 }}
              style={{ filter: revealed ? 'drop-shadow(0 0 18px rgba(255,255,255,.7))' : 'brightness(0)' }}
            >
              <Sprite path={answerPokemon.sprite} box={answerPokemon.box} alt="Quem é esse Pokémon?" fill={0.95} />
            </m.div>
          </AnimatePresence>
        </div>
        <AnimatePresence>
          {revealed && (
            <m.div
              initial={{ opacity: 0, y: 20, scale: 0.8 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0 }}
              className="absolute bottom-6 left-0 w-full text-center text-3xl font-black text-yellow-300 drop-shadow-[0_3px_0_#1b3f8a] sm:text-5xl"
            >
              É o {prettyName(answerPokemon.name)}!
            </m.div>
          )}
        </AnimatePresence>
      </Stage>

      <div className="flex flex-col gap-4">
        <div className="flex items-center justify-between rounded-2xl bg-card p-4 shadow">
          <button type="button" onClick={() => (game.ranked ? end(game) : setGame(null))} className="flex cursor-pointer items-center gap-1 text-muted hover:text-text">
            <Icon name="back" size={20} /> Sair
          </button>
          <div className="flex gap-1 text-red-500">
            {Array.from({ length: LIVES }, (_, i) => (
              <m.span key={i} animate={{ scale: i < game.lives ? 1 : 0.6, opacity: i < game.lives ? 1 : 0.25 }}>
                <Icon name="heart" size={28} />
              </m.span>
            ))}
          </div>
        </div>
        <div className="grid grid-cols-3 gap-3 text-center">
          <div className="rounded-2xl bg-card p-3 shadow">
            <div className="text-xs text-muted">Pontos</div>
            <m.div key={game.score} initial={{ scale: 1.4 }} animate={{ scale: 1 }} className="text-3xl font-black">
              {game.score}
            </m.div>
          </div>
          <div className="rounded-2xl bg-card p-3 shadow">
            <div className="text-xs text-muted">Sequência</div>
            <div className="text-3xl font-black text-orange-400">{game.streak ?? 0}🔥</div>
          </div>
          <div className="rounded-2xl bg-card p-3 shadow">
            <div className="text-xs text-muted">Recorde</div>
            <div className="text-3xl font-black text-yellow-400">{Math.max(record, game.score)}</div>
          </div>
        </div>
        {game.ranked && (
          <div className="overflow-hidden rounded-2xl bg-card shadow">
            <div className="flex items-center justify-between px-4 pt-2 text-sm font-bold">
              <span className="text-yellow-400">🏆 Ranked</span>
              <span className="text-muted">{rankedSeconds(game.score)}s por Pokémon</span>
            </div>
            <div className="m-3 mt-2 h-3 overflow-hidden rounded-full bg-surface">
              {/* Barra do tempo: esvazia no tempo da rodada; para quando a resposta aparece. */}
              <div
                key={game.round}
                className="ranked-timer h-full rounded-full"
                style={{ animationDuration: `${rankedSeconds(game.score)}s`, animationPlayState: revealed ? 'paused' : 'running' }}
              />
            </div>
          </div>
        )}
        {gen && (
          <div className="rounded-full px-4 py-2 text-center text-sm font-bold text-white" style={{ background: generationBackground(gen) }}>
            {gen.name.replace('Generation', 'Geração')} · {gen.region}
          </div>
        )}

        <div className="flex flex-1 flex-col justify-center gap-3">
          {game.options.map((id, index) => {
            const p = byId(id)
            const isAnswer = id === game.answerId
            const color = !revealed ? '#42A5F5' : isAnswer ? '#43a047' : id === chosen ? '#e53935' : '#616161'
            return (
              <m.button
                key={id}
                type="button"
                disabled={revealed}
                onClick={() => answer(id)}
                whileHover={revealed ? undefined : { scale: 1.03, x: 6 }}
                whileTap={revealed ? undefined : { scale: 0.97 }}
                animate={{ backgroundColor: color, x: revealed && id === chosen && !isAnswer ? [0, -10, 10, -6, 6, 0] : 0 }}
                transition={{ duration: 0.4 }}
                className="flex cursor-pointer items-center gap-4 rounded-2xl px-5 py-5 text-left text-xl font-bold text-white shadow-lg disabled:cursor-default"
              >
                <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-white/25 text-base">{index + 1}</span>
                {prettyName(p.name)}
                {revealed && isAnswer && <span className="ml-auto">✓</span>}
                {revealed && id === chosen && !isAnswer && <span className="ml-auto">✗</span>}
              </m.button>
            )
          })}
        </div>
        {revealed && (
          <p className={`text-center text-lg font-bold ${hit ? 'text-green-400' : 'text-red-400'}`}>{hit ? 'Acertou! +1 ponto' : chosen === TIMEOUT ? 'Tempo esgotado! -1 vida' : 'Errou! -1 vida'}</p>
        )}
      </div>
    </div>
  )
}

function EndModal({ result, onClose, onRestart }) {
  return (
    <Modal open={result !== null} onClose={onClose} title={result?.ranked ? 'Fim do Ranked!' : 'Fim de Jogo!'}>
      <div className="text-center">
        <p>Sua pontuação foi:</p>
        <p className="my-2 text-6xl font-black text-yellow-400">{result?.score}</p>
        {result?.newRecord && <p className="text-green-400">Novo recorde{result.ranked ? ' no Ranked! Confira sua posição no ranking' : ''}! 🎉</p>}
        <div className="mt-6 flex justify-center gap-3">
          <button type="button" onClick={onClose} className="cursor-pointer px-4 text-muted">
            Sair
          </button>
          <Button onClick={onRestart}>Jogar novamente</Button>
        </div>
      </div>
    </Modal>
  )
}
