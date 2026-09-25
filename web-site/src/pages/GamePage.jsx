// "Quem é esse Pokémon?" — mesmas regras do app: 4 opções, 3 vidas, recorde
// salvo e jogo em andamento que pode ser continuado depois.

import { AnimatePresence, m } from 'framer-motion'
import { useEffect, useState } from 'react'
import { Button, Icon, Loader, Modal, PageHeader } from '../components/ui'
import { getPokedex } from '../lib/data'
import { GENERATIONS, capitalize } from '../lib/pokemon'
import { useStore } from '../lib/store'
import Sprite from '../components/Sprite'

const LIVES = 3

function pickQuestion(pool) {
  const answer = pool[Math.floor(Math.random() * pool.length)]
  const options = new Set([answer.id])
  while (options.size < Math.min(4, pool.length)) options.add(pool[Math.floor(Math.random() * pool.length)].id)
  return { answerId: answer.id, options: [...options].sort(() => Math.random() - 0.5) }
}

export default function GamePage() {
  const record = useStore((s) => s.quizRecord)
  const saved = useStore((s) => s.quizGame)
  const saveGame = useStore((s) => s.saveQuizGame)
  const finish = useStore((s) => s.finishQuiz)
  const [pokedex, setPokedex] = useState(null)
  const [generation, setGeneration] = useState(0)
  const [game, setGame] = useState(null) // {generation, score, lives, answerId, options}
  const [chosen, setChosen] = useState(null)
  const [ended, setEnded] = useState(null)

  useEffect(() => {
    getPokedex().then(setPokedex)
  }, [])

  const pool = (gen) => (gen ? pokedex.filter((p) => p.gen === gen) : pokedex)
  const byId = (id) => pokedex.find((p) => p.id === id)

  const start = () => {
    const g = { generation, score: 0, lives: LIVES, ...pickQuestion(pool(generation)) }
    setGame(g)
    saveGame(g)
    setChosen(null)
  }

  const answer = (id) => {
    if (chosen) return
    setChosen(id)
    const correct = id === game.answerId
    const next = { ...game, score: game.score + (correct ? 1 : 0), lives: game.lives - (correct ? 0 : 1) }
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
      correct ? 1000 : 2000,
    )
  }

  if (!pokedex) return <Loader />

  if (!game) {
    return (
      <div className="mx-auto max-w-md text-center">
        <PageHeader title="Quem é esse Pokémon?" />
        <p className="mt-6 text-2xl font-bold text-yellow-400">Seu Recorde: {record} Pontos</p>
        <p className="mt-8 mb-2 text-muted">Escolha a Geração:</p>
        <select
          value={generation}
          onChange={(e) => setGeneration(Number(e.target.value))}
          className="w-full cursor-pointer rounded-xl bg-surface px-4 py-3 ring-1 ring-line outline-none"
        >
          <option value={0}>Todas as Gerações</option>
          {GENERATIONS.map((g) => (
            <option key={g.id} value={g.id}>
              {g.name}
            </option>
          ))}
        </select>
        <div className="mt-6 flex flex-col gap-3">
          {saved && saved.lives > 0 && (
            <Button color="#43a047" onClick={() => setGame(saved)} className="w-full">
              ▶ Continuar Jogo ({saved.score} pontos)
            </Button>
          )}
          <Button onClick={start} className="w-full">
            ▶ {saved ? 'Iniciar Novo Jogo' : 'Iniciar Jogo'}
          </Button>
        </div>
        <EndModal score={ended} record={record} onClose={() => setEnded(null)} onRestart={() => (setEnded(null), start())} />
      </div>
    )
  }

  const answerPokemon = byId(game.answerId)
  const revealed = Boolean(chosen)

  return (
    <div className="mx-auto max-w-2xl">
      <div className="flex items-center justify-between">
        <button type="button" onClick={() => setGame(null)} className="flex cursor-pointer items-center gap-1 text-muted hover:text-text">
          <Icon name="back" size={20} /> Sair
        </button>
        <div className="text-xl font-bold">Pontos: {game.score}</div>
        <div className="flex gap-1 text-red-500">
          {Array.from({ length: LIVES }, (_, i) => (
            <m.span key={i} animate={{ scale: i < game.lives ? 1 : 0.6, opacity: i < game.lives ? 1 : 0.25 }}>
              <Icon name="heart" size={26} />
            </m.span>
          ))}
        </div>
      </div>

      <div className="mt-6 grid h-[380px] w-full place-items-center overflow-hidden rounded-3xl bg-surface">
        <AnimatePresence mode="wait">
          <m.div
            key={`${game.answerId}-${revealed}`}
            className="h-[85%] aspect-square"
            initial={{ opacity: 0, scale: 0.8 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0 }}
            style={{ filter: revealed ? 'none' : 'brightness(0)' }}
          >
            <Sprite path={answerPokemon.sprite} box={answerPokemon.box} alt="Quem é esse Pokémon?" />
          </m.div>
        </AnimatePresence>
      </div>
      <AnimatePresence>
        {revealed && (
          <m.p initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} className="mt-3 text-center text-2xl font-black">
            É o {capitalize(answerPokemon.name)}!
          </m.p>
        )}
      </AnimatePresence>

      <div className="mt-5 grid grid-cols-2 gap-3">
        {game.options.map((id) => {
          const p = byId(id)
          const isAnswer = id === game.answerId
          const color = !revealed ? '#42A5F5' : isAnswer ? '#43a047' : id === chosen ? '#e53935' : '#616161'
          return (
            <m.button
              key={id}
              type="button"
              disabled={revealed}
              onClick={() => answer(id)}
              whileHover={revealed ? undefined : { scale: 1.04 }}
              whileTap={revealed ? undefined : { scale: 0.96 }}
              animate={{ backgroundColor: color }}
              className="cursor-pointer rounded-2xl py-4 text-lg font-bold text-white shadow disabled:cursor-default"
            >
              {capitalize(p.name)}
            </m.button>
          )
        })}
      </div>
    </div>
  )
}

function EndModal({ score, record, onClose, onRestart }) {
  return (
    <Modal open={score !== null} onClose={onClose} title="Fim de Jogo!">
      <div className="text-center">
        <p>Sua pontuação foi:</p>
        <p className="my-2 text-5xl font-black text-yellow-400">{score}</p>
        {score !== null && score >= record && score > 0 && <p className="text-green-400">Novo recorde! 🎉</p>}
        <div className="mt-6 flex justify-center gap-3">
          <button type="button" onClick={onClose} className="cursor-pointer px-4 text-muted">
            Sair
          </button>
          <Button onClick={onRestart}>Jogar Novamente</Button>
        </div>
      </div>
    </Modal>
  )
}
