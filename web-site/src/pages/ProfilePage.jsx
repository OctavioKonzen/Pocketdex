// Perfil público (/perfil/{uid}): abre por link, até sem conta. Mostra a foto,
// o treinador, o tema (o desenho do Pokémon no fundo do cartão), os recordes,
// as medalhas e o Hall da Fama (lib/profile.js). Igual ao app.

import { useEffect, useState } from 'react'
import { useParams } from 'react-router-dom'
import { Avatar } from '../components/AccountAvatar'
import { Medal } from '../components/Achievements'
import PokeIcon from '../components/PokeIcon'
import { TrainerSprite } from '../components/Trainer'
import { Button, Empty, Loader } from '../components/ui'
import { getDefense, getProfile, useAuth } from '../lib/auth'
import { useStore } from '../lib/store'
import { t } from '../lib/i18n'
import { MEDALS } from '../lib/medals'
import { CHAMPION_GOLD, lineColor, themeArt, themeColor } from '../lib/pokemonTheme'
import { profileLink } from '../lib/profile'
import { useTrainers } from '../lib/trainers'

/** O time de defesa (duelo assíncrono): os amigos batalham contra ele. No seu, dá para escolher qual. */
function DefenseCard({ uid, mine }) {
  const teams = useStore((s) => s.teams)
  const defenseTeam = useStore((s) => s.defenseTeam)
  const setDefenseTeam = useStore((s) => s.setDefenseTeam)
  const [theirs, setTheirs] = useState(null)
  useEffect(() => {
    if (mine) return undefined
    let live = true
    getDefense(uid).then((d) => live && setTheirs(d)).catch(() => {})
    return () => {
      live = false
    }
  }, [uid, mine])
  const options = teams.filter((x) => x.pokemon?.some((p) => p != null))
  const team = mine ? teams.find((x) => x.id === defenseTeam) : theirs && { name: theirs.teamName, pokemon: theirs.pokemon }
  return (
    <section className="rounded-2xl bg-card p-5 shadow" data-testid="profile-defense">
      <div className="mb-2 flex flex-wrap items-center justify-between gap-2">
        <h2 className="font-bold">🛡️ {t('Time de defesa')}</h2>
        {mine && (
          <select aria-label={t('Time de defesa')} value={defenseTeam ?? ''} onChange={(e) => setDefenseTeam(e.target.value || null)}
            className="rounded-full border border-line bg-surface px-3 py-1.5 text-sm font-semibold">
            <option value="">{t('Sem time de defesa')}</option>
            {options.map((x) => <option key={x.id} value={x.id}>{x.name}</option>)}
          </select>
        )}
      </div>
      {team ? (
        <>
          <p className="mb-2 text-sm font-semibold text-muted" data-no-translate>{team.name}</p>
          <div className="grid grid-cols-6 gap-1.5">
            {Array.from({ length: 6 }, (_, i) => team.pokemon?.[i]).map((id, i) => (
              <div key={i} className="grid aspect-square place-items-center rounded-full bg-surface">{id != null && <PokeIcon id={id} className="h-[85%] w-[85%]" />}</div>
            ))}
          </div>
        </>
      ) : (
        <p className="text-sm text-muted">{t(mine ? 'Escolha um dos seus times: os amigos batalham contra ele quando quiserem, com o computador jogando por você.' : 'Ainda sem time de defesa.')}</p>
      )}
    </section>
  )
}

export default function ProfilePage() {
  const { uid } = useParams()
  const [profile, setProfile] = useState(undefined)
  const [art, setArt] = useState(null) // {url, color}
  const [copied, setCopied] = useState(false)
  const trainers = useTrainers()
  const me = useAuth((a) => (a.status === 'signedIn' ? a.user?.uid : null))
  useEffect(() => {
    let live = true
    getProfile(uid).then((p) => live && setProfile(p)).catch(() => live && setProfile(null))
    return () => {
      live = false
    }
  }, [uid])
  useEffect(() => {
    if (!profile?.theme) return undefined
    let live = true
    themeColor(profile.theme, profile.shiny).then(async (hex) => {
      if (!hex) return
      const url = await themeArt(profile.theme, hex, profile.champion ? CHAMPION_GOLD : lineColor(hex), profile.shiny)
      if (live) setArt({ url, color: hex })
    })
    return () => {
      live = false
    }
  }, [profile])

  if (profile === undefined) return <Loader />
  if (!profile) return <Empty>{t('Esse perfil não existe (ou a conta ainda não abriu o PocketDex depois da atualização).')}</Empty>
  const trainer = trainers?.find((x) => x.id === profile.trainer)
  const color = art?.color ?? '#ef3b36'
  const share = async () => {
    const link = profileLink(uid)
    try {
      if (navigator.share) await navigator.share({ title: `PocketDex · ${profile.name}`, url: link })
      else {
        await navigator.clipboard.writeText(link)
        setCopied(true)
      }
    } catch {
      /* cancelado */
    }
  }
  const records = [
    ['🏆', 'Ranked', profile.ranked],
    ['🎲', t('Pokelike: andar'), profile.factory],
    ['🗼', t('Torre: vitórias seguidas'), profile.tower],
    ['🏅', t('Insígnias'), profile.badges],
    ['📘', t('Pokémon pegos'), profile.caught],
  ]
  return (
    <div className="mx-auto max-w-3xl space-y-5" data-testid="public-profile">
      <section
        className="relative overflow-hidden rounded-3xl border p-5"
        style={{ borderColor: `${color}66`, background: `linear-gradient(135deg, ${color}26, transparent 65%), var(--card)` }}
      >
        {art?.url && <img src={art.url} alt="" aria-hidden="true" className="pointer-events-none absolute -right-6 -bottom-6 h-56 w-56 object-contain opacity-40" />}
        <div className="relative flex flex-wrap items-center gap-4">
          <Avatar pokemonId={profile.avatar} name={profile.name} size={84} />
          <div className="min-w-0 flex-1">
            <p className="text-xs font-bold tracking-widest text-muted uppercase">{t('Treinador')}</p>
            <h1 className="font-display truncate text-3xl font-black" data-no-translate>{profile.name}</h1>
            {profile.champion && <p className="text-sm font-bold" style={{ color: CHAMPION_GOLD }}>👑 {t('Campeão')}</p>}
          </div>
          {trainer && <TrainerSprite trainer={trainer} box={110} />}
        </div>
        <div className="relative mt-4">
          <Button color={color} onClick={share} data-testid="profile-share">🔗 {copied ? t('Link copiado!') : t('Compartilhar perfil')}</Button>
        </div>
      </section>

      <DefenseCard uid={uid} mine={me === uid} />

      <section className="grid grid-cols-2 gap-3 sm:grid-cols-5">
        {records.map(([icon, label, value]) => (
          <div key={label} className="rounded-2xl bg-card p-3 text-center shadow">
            <div className="text-xl">{icon}</div>
            <div className="text-2xl font-black">{value ?? 0}</div>
            <div className="text-xs text-muted">{label}</div>
          </div>
        ))}
      </section>

      <section className="rounded-2xl bg-card p-5 shadow">
        <h2 className="mb-4 font-bold">{t('Álbum de medalhas')} · {(profile.medals ?? []).length}/{MEDALS.length}</h2>
        <div className="grid grid-cols-3 gap-4 sm:grid-cols-6">
          {MEDALS.map((m) => <Medal key={m.id} medal={{ ...m, unlocked: (profile.medals ?? []).includes(m.id) }} />)}
        </div>
      </section>

      {(profile.hall ?? []).length > 0 && (
        <section className="rounded-2xl bg-card p-5 shadow">
          <h2 className="mb-3 font-bold">🏆 {t('Hall da Fama')}</h2>
          <ul className="space-y-2">
            {profile.hall.map((h, i) => (
              <li key={i} className="flex flex-wrap items-center gap-2 rounded-xl bg-surface px-3 py-2">
                <span className="w-24 shrink-0 text-sm font-bold" data-no-translate>{h.region}</span>
                {(h.team ?? []).map((id, j) => <PokeIcon key={j} id={id} className="h-10 w-10" />)}
              </li>
            ))}
          </ul>
        </section>
      )}
    </div>
  )
}
