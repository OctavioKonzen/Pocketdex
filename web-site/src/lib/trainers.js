// Os treinadores (assets/database/trainers.json): carregar, o seu e um para o
// computador. Os desenhos ficam em components/Trainer.jsx.

import { useEffect, useState } from 'react'
import { getTrainers } from './data'
import { useStore } from './store'

/** A lista dos treinadores (carrega uma vez). */
export function useTrainers() {
  const [list, setList] = useState(null)
  useEffect(() => {
    let alive = true
    getTrainers()
      .then((t) => alive && setList(t))
      .catch(() => alive && setList([]))
    return () => {
      alive = false
    }
  }, [])
  return list
}

/** O seu treinador (o escolhido ou o Red). */
export function useMyTrainer() {
  const list = useTrainers()
  const id = useStore((s) => s.trainer)
  return list?.find((t) => t.id === id) ?? list?.[0] ?? null
}

/** Um treinador para o computador (não repete o seu). */
export function randomTrainer(list, mine, random = Math.random) {
  const options = (list ?? []).filter((t) => !t.back && t.id !== mine)
  return options.length ? options[Math.floor(random() * options.length)] : null
}

