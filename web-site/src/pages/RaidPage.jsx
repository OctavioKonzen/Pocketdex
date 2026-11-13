// Raid da semana (lib/raid.js): o chefe gigante, a barra do grupo (você e
// seus amigos), quanto cada um já tirou e a luta (até 3 por dia). Igual ao app
// (lib/screens/raid_screen.dart).

import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import PokeIcon from '../components/PokeIcon'
import { Button, PageHeader } from '../components/ui'
import { getRaidHits, useAuth } from '../lib/auth'
import { getPokemonById } from '../lib/data'
import { saveFactory } from '../components/FactoryPanels'
import { factoryOf } from '../lib/factoryRun'
import { friendsOnly, useFriends } from '../lib/friends'
import { t } from '../lib/i18n'
import { weekKey } from '../lib/league'
import { prettyName } from '../lib/pokemon'
import { RAID_COINS, RAID_POOL, RAID_TRIES, raidBoss, raidClaim, raidClaimed, raidGimmick, raidTriesLeft } from '../lib/raid'
import { useStore } from '../lib/store'

export default function RaidPage() {
  const user = useAuth((s) => (s.status === 'signedIn' ? s.user : null))
  const friends = friendsOnly(useFriends((s) => s.list))
  const league = useStore((s) => s.league)
  const teams = useStore((s) => s.teams)
  const factory = factoryOf(league)
  const navigate = useNavigate()
  const [hits, setHits] = useState(null)
  const [team, setTeam] = useState(0)
  const [boss, setBoss] = useState(null)
  const id = raidBoss()
  const uids = [user?.uid, ...friends.map((f) => f.uid)].filter(Boolean).join('|')
  useEffect(() => {
    let alive = true
    getPokemonById().then((m) => alive && setBoss(m.get(id) ?? null))
    if (!uids) setHits({})
    else getRaidHits(uids.split('|'), weekKey()).then((h) => alive && setHits(h)).catch(() => alive && setHits({}))
    return () => {
      alive = false
    }
  }, [uids, id])
  const total = Object.values(hits ?? {}).reduce((a, b) => a + b, 0)
  const cleared = total >= RAID_POOL
  const left = raidTriesLeft(factory)
  const names = { ...Object.fromEntries(friends.map((f) => [f.uid, f.name])), ...(user ? { [user.uid]: t('Você') } : {}) }
  const name = prettyName(boss?.name ?? '')
  const fight = () => {
    const chosen = teams[team]
    const ids = (chosen?.pokemon ?? []).map((x, i) => [x, chosen.sets?.[i] ?? null]).filter(([x]) => typeof x === 'number')
    const seed = Date.now()
    const mine = ids.length ? ids.map(([x]) => x) : [0, 1, 2].map((i) => 1 + ((seed * (i + 7)) % 1025))
    navigate('/batalha/computador', { state: { mine, mineSets: ids.map(([, s]) => s), theirs: [id], foeName: `🐉 ${t('Raid')}: ${name}`, raid: true } })
  }
  return (
    <div className="space-y-4" data-testid="raid">
      <PageHeader eyebrow="Arena" title={`🐉 ${t('Raid da semana')}`} subtitle={t('Você e seus amigos dividem a vida dele: o dano de todos soma. Quando a barra acaba, cada um pega o prêmio.')} />
      <section className="rounded-2xl bg-card p-5 text-center shadow">
        <PokeIcon id={id} className="mx-auto h-36 w-36" />
        <p className="text-lg font-black" data-no-translate>{name} · {raidGimmick() === 'dmax' ? 'Dynamax' : 'Tera'} · Nv. 75</p>
        <div className="mt-3 h-3.5 overflow-hidden rounded-md bg-surface" data-testid="raid-bar">
          <div className={`h-full ${cleared ? 'bg-emerald-500' : 'bg-red-500'}`} style={{ width: `${100 - Math.min(100, (total / RAID_POOL) * 100)}%` }} />
        </div>
        <p className="mt-1 font-bold" data-testid="raid-total">{cleared ? `🎉 ${t('O grupo derrubou o chefe!')}` : t('Vida do chefe: {0}% de {1}%').replace('{0}', Math.max(0, RAID_POOL - total)).replace('{1}', RAID_POOL)}</p>
      </section>
      <section className="space-y-2 rounded-2xl bg-card p-5 shadow">
        <h2 className="font-black">⚔️ {t('Lutar')}</h2>
        {teams.length > 0 && (
          <select aria-label={t('Seu time')} value={team} onChange={(e) => setTeam(Number(e.target.value))} className="w-full rounded-xl bg-surface p-2" data-no-translate>
            {teams.map((x, i) => <option key={x.id} value={i}>{x.name}</option>)}
          </select>
        )}
        <Button color="#ef4444" className="w-full" data-testid="raid-fight" disabled={left <= 0} onClick={fight}>🐉 {t('Lutar com o chefe')} ({left}/{RAID_TRIES})</Button>
        {left <= 0 && <p className="text-xs text-muted">{t('Volte amanhã para lutar de novo.')}</p>}
        {cleared && (
          <Button color="#22c55e" className="w-full" data-testid="raid-claim" disabled={raidClaimed(factory)} onClick={() => saveFactory(raidClaim(factory, total))}>
            {raidClaimed(factory) ? `✓ ${t('Prêmio pego')}` : `🎁 ${t('Pegar o prêmio')} (+${RAID_COINS} 🪙)`}
          </Button>
        )}
      </section>
      <section className="rounded-2xl bg-card p-5 shadow">
        <h2 className="mb-2 font-black">👥 {t('O grupo')}</h2>
        {hits && !Object.keys(hits).length && <p className="text-xs text-muted">{t('Ninguém lutou ainda nesta semana.')}</p>}
        {Object.entries(hits ?? {}).sort((a, b) => b[1] - a[1]).map(([uid, v]) => (
          <p key={uid} className="flex justify-between" data-no-translate><span>{names[uid] ?? '?'}</span><b>{v}%</b></p>
        ))}
      </section>
    </div>
  )
}
