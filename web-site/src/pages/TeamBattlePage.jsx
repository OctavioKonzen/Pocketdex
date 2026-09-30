// Batalha de times entre amigos (igual ao app, team_battle_screen.dart):
// escolha um time seu e um time de um amigo e veja, 1 contra 1, quem ganha
// cada confronto com o melhor golpe de cada lado (lib/teamBattle.js).

import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import PokeIcon from '../components/PokeIcon'
import { Button, Empty, Icon, PageHeader } from '../components/ui'
import { teamsOf, useAuth } from '../lib/auth'
import { friendsOnly, useFriends } from '../lib/friends'
import { useStore } from '../lib/store'
import { runBattle, teamMembers } from '../lib/teamBattle'

const CARD = 'rounded-2xl bg-card p-5 shadow'
const SELECT = 'w-full rounded-xl bg-surface px-3 py-2.5 outline-none focus:ring-2 focus:ring-sky-400'
const COLORS = { 1: '#22C55E', '-1': '#EF4444', 0: '#9CA3AF' }

const pct = (x) => `${x.toFixed(1).replace('.', ',')}%`
const hitsText = (n) => (n === 1 ? '1 golpe' : `${n} golpes`)

function TeamLine({ team }) {
  return (
    <div className="flex items-center gap-1">
      {teamMembers(team).map((m, i) => (
        <PokeIcon key={i} id={m.id} className="h-9 w-9" />
      ))}
    </div>
  )
}

function Detail({ duel, mine, theirs, onClose }) {
  const side = (id, h) => (
    <div className="flex items-center gap-3">
      <PokeIcon id={id} className="h-14 w-14" />
      <div className="text-sm">{h.hits >= 99 ? 'Não consegue causar dano.' : `${h.move}: ${pct(h.pct)} por golpe · derrota em ${hitsText(h.hits)}`}</div>
    </div>
  )
  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/60 p-4" onClick={onClose}>
      <div className="w-full max-w-md space-y-3 rounded-2xl bg-card p-5 shadow-xl" onClick={(e) => e.stopPropagation()}>
        <div className="text-xl font-bold">{duel.result === 1 ? '✅ Você ganha' : duel.result === -1 ? '❌ Você perde' : '🤝 Empate'}</div>
        {side(mine, duel.mine)}
        {side(theirs, duel.theirs)}
        <p className="text-sm text-muted">{duel.sameSpeed ? 'Mesma velocidade.' : duel.faster ? 'O seu é mais rápido.' : 'O dele é mais rápido.'}</p>
        <Button onClick={onClose} className="w-full">
          Fechar
        </Button>
      </div>
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
  const [detail, setDetail] = useState(null)

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

  const all = (result ?? []).flat().filter(Boolean)
  const wins = all.filter((d) => d.result === 1).length
  const losses = all.filter((d) => d.result === -1).length
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

      {result && (
        <section className={CARD}>
          <div className="text-xl font-black">
            {wins > losses ? '🏆 Seu time leva vantagem!' : wins < losses ? '😬 O time do amigo leva vantagem.' : '🤝 Equilibrado.'}
          </div>
          <p className="mt-1 mb-4">{`Você ganha ${wins}, perde ${losses} e empata ${all.length - wins - losses} de ${all.length} confrontos.`}</p>
          <div className="overflow-x-auto">
            <table className="border-separate border-spacing-1">
              <thead>
                <tr>
                  <th />
                  {b.map((m, j) => (
                    <th key={j}>
                      <PokeIcon id={m.id} className="h-11 w-11" />
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {result.map((row, i) => (
                  <tr key={i}>
                    <td>
                      <PokeIcon id={a[i].id} className="h-11 w-11" />
                    </td>
                    {row.map((d, j) => (
                      <td key={j}>
                        {d && (
                          <button
                            type="button"
                            onClick={() => setDetail({ duel: d, mine: a[i].id, theirs: b[j].id })}
                            className="grid h-10 w-10 cursor-pointer place-items-center rounded-lg text-xs font-bold text-white transition hover:scale-110"
                            style={{ background: COLORS[d.result] }}
                          >
                            {d.mine.hits >= 99 ? '—' : `${d.mine.hits}×`}
                          </button>
                        )}
                      </td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p className="mt-3 text-xs text-muted">
            Linhas: seu time. Colunas: o time do amigo. O número é quantos golpes o seu precisa. Clique num quadrado para ver os golpes.
          </p>
        </section>
      )}
      {detail && <Detail {...detail} onClose={() => setDetail(null)} />}
    </div>
  )
}
