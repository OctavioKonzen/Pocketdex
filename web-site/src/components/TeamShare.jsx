// Janelas de compartilhar e importar times (código, link ou texto de simulador).

import { useEffect, useMemo, useState } from 'react'
import { getAbilities, getItems, getMoves, getPokemonIndex } from '../lib/data'
import { teamImage } from '../lib/teamImage'
import { lookupOf } from '../lib/teamSets'
import { encodeTeam, parseSharedTeam, shareLink, toShowdown } from '../lib/teamShare'
import Sprite from './Sprite'
import { Button, Modal } from './ui'

function CopyField({ label, value, rows = 1 }) {
  const [copied, setCopied] = useState(false)
  const copy = async () => {
    try {
      await navigator.clipboard.writeText(value)
      setCopied(true)
      setTimeout(() => setCopied(false), 1500)
    } catch {
      setCopied(false)
    }
  }
  return (
    <div>
      <div className="mb-1 flex items-center justify-between">
        <span className="text-sm font-bold">{label}</span>
        <button type="button" onClick={copy} className="cursor-pointer text-sm font-bold text-sky-400 hover:underline">
          {copied ? 'Copiado!' : 'Copiar'}
        </button>
      </div>
      {rows > 1 ? (
        <textarea readOnly value={value} rows={rows} className="w-full resize-none rounded-xl bg-surface px-3 py-2 font-mono text-xs outline-none" />
      ) : (
        <input readOnly value={value} onFocus={(e) => e.target.select()} className="w-full rounded-xl bg-surface px-3 py-2 font-mono text-xs outline-none" />
      )}
    </div>
  )
}

/** Imagem do time (lib/teamImage.js): prévia, baixar e compartilhar. */
function TeamImage({ team, byId }) {
  const [url, setUrl] = useState(null)
  const [blob, setBlob] = useState(null)
  const [busy, setBusy] = useState(false)
  useEffect(() => () => url && URL.revokeObjectURL(url), [url])
  const make = async () => {
    setBusy(true)
    const png = await teamImage(team, byId)
    setBusy(false)
    if (!png) return
    setBlob(png)
    setUrl(URL.createObjectURL(png))
  }
  const file = blob && new File([blob], 'pocketdex-time.png', { type: 'image/png' })
  const canShare = file && navigator.canShare?.({ files: [file] })
  if (!url) {
    return (
      <Button onClick={make} disabled={busy} className="w-full">
        {busy ? '...' : '🖼️ Imagem do time'}
      </Button>
    )
  }
  return (
    <div className="space-y-2">
      <img src={url} alt={team.name} className="w-full rounded-2xl" />
      <div className="flex gap-2">
        <a href={url} download="pocketdex-time.png" className="flex-1 rounded-xl bg-sky-600 px-4 py-2.5 text-center font-bold text-white">
          Baixar imagem
        </a>
        {canShare && (
          <Button className="flex-1" onClick={() => navigator.share({ files: [file], title: team.name }).catch(() => {})}>
            Compartilhar
          </Button>
        )}
      </div>
    </div>
  )
}

/** Mostra o link, o código e o texto do Showdown de um time. */
export function ShareTeamModal({ team, byId, open, onClose }) {
  if (!team || !byId) return null
  return (
    <Modal open={open} onClose={onClose} title="Compartilhar time">
      <div className="space-y-4">
        <p className="text-sm text-muted">Mande o link ou o código para um amigo: no site ou no app, ele abre em Times → Importar.</p>
        <CopyField label="Link" value={shareLink(team)} />
        <CopyField label="Código" value={encodeTeam(team)} />
        <CopyField label="Texto (Pokémon Showdown e outros simuladores)" value={toShowdown(team, byId)} rows={8} />
        <TeamImage key={team.id} team={team} byId={byId} />
      </div>
    </Modal>
  )
}

/** Cola um código, link ou texto do Showdown e cria o time. */
export function ImportTeamModal({ open, initial = '', onClose, onImport }) {
  const [text, setText] = useState(initial)
  const [index, setIndex] = useState(null)
  const [lookups, setLookups] = useState(undefined)

  useEffect(() => {
    if (!open) return
    getPokemonIndex().then(setIndex)
    // Nomes de golpes, habilidades e itens do texto → os do banco.
    Promise.all([getMoves(), getAbilities(), getItems()])
      .then(([moves, abilities, items]) =>
        setLookups({
          moves: lookupOf(Object.keys(moves)),
          abilities: lookupOf((Array.isArray(abilities) ? abilities : Object.values(abilities)).map((a) => a.name)),
          items: lookupOf(items.map((i) => i.name)),
        }),
      )
      .catch(() => setLookups({}))
  }, [open])

  const team = useMemo(() => (index && text.trim() ? parseSharedTeam(text, index, lookups) : null), [text, index, lookups])
  const byId = useMemo(() => (index ? new Map(index.map((p) => [p.id, p])) : null), [index])

  return (
    <Modal open={open} onClose={onClose} title="Importar time">
      <div className="space-y-4">
        <textarea
          autoFocus
          value={text}
          onChange={(e) => setText(e.target.value)}
          rows={6}
          placeholder="Cole aqui o link, o código (PDX1...) ou o texto do time (Pokémon Showdown e outros)"
          className="w-full resize-none rounded-xl bg-surface px-4 py-3 text-sm ring-1 ring-line outline-none focus:ring-2 focus:ring-sky-400"
        />
        {team ? (
          <div className="rounded-xl bg-surface p-3">
            <div className="mb-2 font-bold">{team.name}</div>
            <div className="grid grid-cols-6 gap-1">
              {team.pokemon.map((id, i) => {
                const p = id != null && byId?.get(id)
                return (
                  <div key={i} className="grid aspect-square place-items-center rounded-full bg-card">
                    {p && <Sprite path={p.sprite} box={p.box} fill={0.8} className="w-full" />}
                  </div>
                )
              })}
            </div>
          </div>
        ) : (
          text.trim() && <p className="text-sm text-red-400">Não encontrei um time nesse texto.</p>
        )}
        <div className="flex justify-end gap-3">
          <button type="button" onClick={onClose} className="cursor-pointer px-4 text-muted">
            Cancelar
          </button>
          <Button color="#FF5252" disabled={!team} onClick={() => onImport(team)}>
            Importar
          </Button>
        </div>
      </div>
    </Modal>
  )
}
