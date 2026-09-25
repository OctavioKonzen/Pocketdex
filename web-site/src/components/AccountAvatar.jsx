// Foto de perfil: o Pokémon escolhido (o mesmo no app e no site), ou a foto
// do Google, ou a inicial do nome.

import { useEffect, useState } from 'react'
import { useAuth } from '../lib/auth'
import { getPokemonById } from '../lib/data'
import { useStore } from '../lib/store'
import Sprite from './Sprite'

/** Foto de qualquer jogador (ex.: nas linhas do ranking). */
export function Avatar({ pokemonId, name, photo, size = 36, className = '' }) {
  const [pokemon, setPokemon] = useState(null)

  useEffect(() => {
    if (pokemonId == null) return
    let alive = true
    getPokemonById().then((byId) => alive && setPokemon(byId.get(pokemonId) ?? null))
    return () => {
      alive = false
    }
  }, [pokemonId])

  const shown = pokemonId != null && pokemon?.id === pokemonId ? pokemon : null
  return (
    <span
      className={`grid shrink-0 place-items-center overflow-hidden rounded-full bg-gradient-to-br from-red-600 to-red-800 font-black text-white ring-2 ring-white/80 ${className}`}
      style={{ width: size, height: size, fontSize: size * 0.45 }}
    >
      {shown ? (
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
