// Janelas de compartilhar e importar times (código, link ou Pokémon Showdown).

import { useEffect, useMemo, useState } from 'react'
import { getPokemonIndex } from '../lib/data'
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

/** Mostra o link, o código e o texto do Showdown de um time. */
export function ShareTeamModal({ team, byId, open, onClose }) {
  if (!team || !byId) return null
  return (
    <Modal open={open} onClose={onClose} title="Compartilhar time">
      <div className="space-y-4">
        <p className="text-sm text-muted">Mande o link ou o código para um amigo: no site ou no app, ele abre em Times → Importar.</p>
        <CopyField label="Link" value={shareLink(team)} />
        <CopyField label="Código" value={encodeTeam(team)} />
        <CopyField label="Pokémon Showdown" value={toShowdown(team, byId)} rows={6} />
      </div>
    </Modal>
  )
}

/** Cola um código, link ou texto do Showdown e cria o time. */
export function ImportTeamModal({ open, initial = '', onClose, onImport }) {
  const [text, setText] = useState(initial)
  const [index, setIndex] = useState(null)

  useEffect(() => {
    if (open) getPokemonIndex().then(setIndex)
  }, [open])

  const team = useMemo(() => (index && text.trim() ? parseSharedTeam(text, index) : null), [text, index])
  const byId = useMemo(() => (index ? new Map(index.map((p) => [p.id, p])) : null), [index])

  return (
    <Modal open={open} onClose={onClose} title="Importar time">
      <div className="space-y-4">
        <textarea
          autoFocus
          value={text}
          onChange={(e) => setText(e.target.value)}
          rows={6}
          placeholder="Cole aqui o link, o código (PDX1...) ou o time do Pokémon Showdown"
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
