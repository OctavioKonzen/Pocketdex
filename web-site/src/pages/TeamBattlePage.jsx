// Batalha de times entre amigos (igual ao app, team_battle_screen.dart):
// escolha um time seu e um time de um amigo e veja, 1 contra 1, quem ganha
// cada confronto com o melhor golpe de cada lado (lib/teamBattle.js).

import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import BattleResult from '../components/BattleResult'
import PokeIcon from '../components/PokeIcon'
import { Button, Empty, Icon, PageHeader } from '../components/ui'
import { teamsOf, useAuth } from '../lib/auth'
import { friendsOnly, useFriends } from '../lib/friends'
import { useStore } from '../lib/store'
import { runBattle, teamMembers } from '../lib/teamBattle'

const CARD = 'rounded-2xl bg-card p-5 shadow'
const SELECT = 'w-full rounded-xl bg-surface px-3 py-2.5 outline-none focus:ring-2 focus:ring-sky-400'
function TeamLine({ team }) {
  return (
    <div className="flex items-center gap-1">
      {teamMembers(team).map((m, i) => (
        <PokeIcon key={i} id={m.id} className="h-9 w-9" />
      ))}
    </div>
  )
}

export default function TeamBattlePage() {
  const user = useAuth((s) => (s.status === 'signedIn' ? s.user : null))
  const teams = useStore((s) => s.teams)
  const list = useFriends((s) => s.list)
  const friends = useMemo(() => friendsOnly(list), [list])
  const myTeams = teams.filter((t) => teamMembers(t).length)
  const [mine, setMine] = useState('')
  const [friend, setFriend] = useState('')
  const [friendTeams, setFriendTeams] = useState(null)
  const [theirs, setTheirs] = useState('')
  const [result, setResult] = useState(null)
  const [busy, setBusy] = useState(false)

  if (!user) return <Empty>Entre na sua conta para batalhar com os amigos.</Empty>

  const pickFriend = (uid) => {
    setFriend(uid)
    setFriendTeams(null)
    setTheirs('')
    setResult(null)
    if (uid) teamsOf(uid).then((t) => setFriendTeams(t.filter((x) => teamMembers(x).length))).catch(() => setFriendTeams([]))
  }
  const myTeam = myTeams.find((t) => t.id === mine)
  const theirTeam = friendTeams?.find((t) => t.id === theirs)
  const fight = async () => {
    setBusy(true)
    setResult(await runBattle(teamMembers(myTeam), teamMembers(theirTeam)))
    setBusy(false)
  }

  const a = teamMembers(myTeam)
  const b = teamMembers(theirTeam)

  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <PageHeader title="Batalha de times" subtitle="Cada Pokémon do seu time contra cada um do time do amigo, 1 contra 1, com o melhor golpe de cada lado." />
      <Link to="/amigos" className="inline-flex items-center gap-1 text-sm text-muted hover:text-text">
        <Icon name="back" size={16} /> Amigos
      </Link>

      <section className={`${CARD} space-y-4`}>
        {!myTeams.length ? (
          <p className="text-muted">Monte um time em Times para batalhar.</p>
        ) : (
          <label className="block space-y-1.5">
            <span className="text-sm font-semibold text-muted">Seu time</span>
            <select value={mine} onChange={(e) => (setMine(e.target.value), setResult(null))} className={SELECT}>
              <option value="">Escolha…</option>
              {myTeams.map((t) => (
                <option key={t.id} value={t.id}>
                  {t.name}
                </option>
              ))}
            </select>
            {myTeam && <TeamLine team={myTeam} />}
          </label>
        )}
        {!friends.length ? (
          <p className="text-muted">Adicione amigos para batalhar com os times deles.</p>
        ) : (
          <label className="block space-y-1.5">
            <span className="text-sm font-semibold text-muted">Amigo</span>
            <select value={friend} onChange={(e) => pickFriend(e.target.value)} className={SELECT} data-no-translate>
              <option value="">Escolha…</option>
              {friends.map((f) => (
                <option key={f.uid} value={f.uid}>
                  {f.name}
                </option>
              ))}
            </select>
          </label>
        )}
        {friend &&
          (friendTeams === null ? (
            <p className="text-sm text-muted">...</p>
          ) : !friendTeams.length ? (
            <p className="text-sm text-muted">Esse amigo ainda não montou nenhum time.</p>
          ) : (
            <label className="block space-y-1.5">
              <span className="text-sm font-semibold text-muted">Time do amigo</span>
              <select value={theirs} onChange={(e) => (setTheirs(e.target.value), setResult(null))} className={SELECT}>
                <option value="">Escolha…</option>
                {friendTeams.map((t) => (
                  <option key={t.id} value={t.id}>
                    {t.name}
                  </option>
                ))}
              </select>
              {theirTeam && <TeamLine team={theirTeam} />}
            </label>
          ))}
        <Button color="linear-gradient(90deg,#DC2626,#9333EA)" className="w-full" disabled={busy || !myTeam || !theirTeam} onClick={fight}>
          {busy ? 'Calculando...' : '⚔️ Batalhar!'}
        </Button>
      </section>

      {result && <BattleResult result={result} a={a} b={b} />}
    </div>
  )
}
