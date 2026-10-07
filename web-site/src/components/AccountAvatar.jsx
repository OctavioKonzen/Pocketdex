// Foto de perfil: o Pokémon escolhido (o mesmo no app e no site), ou a foto
// do Google, ou a inicial do nome.

import { useEffect, useState } from 'react'
import { useAuth } from '../lib/auth'
import { avatarOf, getPokemonById, shinyPath } from '../lib/data'
import { useStore } from '../lib/store'
import Sprite from './Sprite'
import { TrainerFace } from './Trainer'
import { useTrainers } from '../lib/trainers'

/** Foto de qualquer jogador (ex.: nas linhas do ranking). pokemonId: o avatar salvo (shiny = id + SHINY_AVATAR). */
export function Avatar({ pokemonId, name, photo, size = 36, className = '' }) {
  const [pokemon, setPokemon] = useState(null)
  const chosen = avatarOf(pokemonId)
  const chosenId = chosen?.id
  // Foto de treinador (TRAINER_AVATAR + posição em trainers.json).
  const trainers = useTrainers()
  const trainer = chosen?.trainer != null ? trainers?.[chosen.trainer] : null

  useEffect(() => {
    if (chosenId == null) return
    let alive = true
    getPokemonById().then((byId) => alive && setPokemon(byId.get(chosenId) ?? null))
    return () => {
      alive = false
    }
  }, [chosenId])

  const found = chosen && pokemon?.id === chosen.id ? pokemon : null
  const shown = found && chosen.shiny ? { ...found, sprite: shinyPath(found.sprite), box: null } : found
  return (
    <span
      className={`grid shrink-0 place-items-center overflow-hidden rounded-full bg-gradient-to-br from-red-600 to-red-800 font-black text-white ring-2 ring-white/80 ${className}`}
      style={{ width: size, height: size, fontSize: size * 0.45 }}
    >
      {trainer ? (
        <TrainerFace trainer={trainer} size={size} />
      ) : shown ? (
        <Sprite path={shown.sprite} box={shown.box} fill={0.9} className="w-[88%]" />
      ) : photo ? (
        <img src={photo} alt="" referrerPolicy="no-referrer" className="h-full w-full object-cover" />
      ) : (
        name?.[0]?.toUpperCase()
      )}
    </span>
  )
}

/** Foto da conta conectada. */
export default function AccountAvatar({ size = 36, className = '' }) {
  const user = useAuth((s) => s.user)
  const avatar = useStore((s) => s.avatar)
  return <Avatar pokemonId={avatar} name={user?.name} photo={user?.photo} size={size} className={className} />
}
