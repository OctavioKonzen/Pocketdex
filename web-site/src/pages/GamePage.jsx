// "Quem é esse Pokémon?" — mesmas regras do app: 4 opções, 3 vidas, recorde
// salvo e jogo em andamento que pode ser continuado depois.
//
// Layout de tela cheia: Pokémon (silhueta) de um lado e as opções do outro;
// no celular um embaixo do outro. Teclas 1 a 4 respondem.

import { AnimatePresence, m } from 'framer-motion'
import { useCallback, useEffect, useState } from 'react'
import GenerationPicker from '../components/GenerationPicker'
import Sprite from '../components/Sprite'
import { Button, Icon, Loader, Modal } from '../components/ui'
import { getPokedex } from '../lib/data'
import { GENERATIONS, generationBackground, prettyName } from '../lib/pokemon'
import { useStore } from '../lib/store'

const LIVES = 3
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

export default function GamePage() {
  const record = useStore((s) => s.quizRecord)
  const saved = useStore((s) => s.quizGame)
  const saveGame = useStore((s) => s.saveQuizGame)
  const finish = useStore((s) => s.finishQuiz)
  const [pokedex, setPokedex] = useState(null)
  const [generation, setGeneration] = useState(0)
  const [game, setGame] = useState(null) // {generation, score, lives, streak, answerId, options}
  const [chosen, setChosen] = useState(null)
  const [ended, setEnded] = useState(null)

  useEffect(() => {
    getPokedex().then(setPokedex)
  }, [])

  const pool = useCallback((gen) => (gen ? pokedex.filter((p) => p.gen === gen) : pokedex), [pokedex])
  const byId = (id) => pokedex.find((p) => p.id === id)

  const start = () => {
    const g = { generation, score: 0, lives: LIVES, streak: 0, ...pickQuestion(pool(generation)) }
    setGame(g)
    saveGame(g)
    setChosen(null)
  }

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
            finish(next.score)
            setGame(null)
            setEnded(next.score)
          } else {
            const g = { ...next, ...pickQuestion(pool(next.generation)) }
            setGame(g)
            saveGame(g)
          }
        },
        correct ? 1100 : 2000,
      )
    },
    [chosen, game, finish, pool, saveGame],
  )

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
      <div className="grid gap-6 lg:grid-cols-[1.2fr_1fr]" style={layoutHeight}>
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
          <div className="flex items-center gap-4 rounded-2xl bg-surface p-4">
            <span className="grid h-14 w-14 place-items-center rounded-full bg-yellow-400 text-3xl">🏆</span>
            <div>
              <div className="text-sm text-muted">Seu recorde</div>
              <div className="text-3xl font-black text-yellow-400">{record} pontos</div>
            </div>
          </div>
          <ul className="space-y-1 text-sm text-muted">
            <li>• Adivinhe o Pokémon pela silhueta entre 4 opções.</li>
            <li>• Você tem 3 vidas; cada erro custa uma.</li>
            <li>• Use o mouse ou as teclas 1 a 4.</li>
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
            <Button onClick={start} className="w-full py-4 text-lg">
              ▶ {saved ? 'Iniciar novo jogo' : 'Iniciar jogo'}
            </Button>
          </div>
        </div>
        <EndModal score={ended} record={record} onClose={() => setEnded(null)} onRestart={() => (setEnded(null), start())} />
      </div>
    )
  }

  // ---------------------------------------------------------------- Jogo
  const answerPokemon = byId(game.answerId)
  const revealed = Boolean(chosen)
  const hit = revealed && chosen === game.answerId
  const gen = GENERATIONS.find((g) => g.id === game.generation)

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
          <button type="button" onClick={() => setGame(null)} className="flex cursor-pointer items-center gap-1 text-muted hover:text-text">
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
          <p className={`text-center text-lg font-bold ${hit ? 'text-green-400' : 'text-red-400'}`}>{hit ? 'Acertou! +1 ponto' : 'Errou! -1 vida'}</p>
        )}
      </div>
    </div>
  )
}

function EndModal({ score, record, onClose, onRestart }) {
  return (
    <Modal open={score !== null} onClose={onClose} title="Fim de Jogo!">
      <div className="text-center">
        <p>Sua pontuação foi:</p>
        <p className="my-2 text-6xl font-black text-yellow-400">{score}</p>
        {score !== null && score >= record && score > 0 && <p className="text-green-400">Novo recorde! 🎉</p>}
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
