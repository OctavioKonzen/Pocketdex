// Treinadores no estilo BW (assets/database/trainers.json, tool/build_trainers.py):
// a frente animada (tira de quadros), as costas lançando a Poké Ball e a
// escolha do seu treinador (que também pode virar a foto de perfil).
// Igual ao app (lib/widgets/trainer_sprite.dart).

import { useState } from 'react'
import { spriteUrl, TRAINER_AVATAR } from '../lib/data'
import { useStore } from '../lib/store'
import { useTrainers } from '../lib/trainers'
import { Button, Modal, SearchInput } from './ui'

/** Pixels na tela por pixel do sprite, para a caixa `box` (quadro de 96 px cabe nela). */
const unit = (box) => box / 96

/**
 * A frente animada: os quadros da tira passam em loop (com uma pausa no
 * primeiro), apoiada embaixo e centralizada numa caixa de `box` px.
 * @param flip virado para a direita (o seu lado, quando não tem costas)
 */
export function TrainerSprite({ trainer, box = 96, flip = false, still = false, className = '', style }) {
  if (!trainer) return null
  const k = unit(box) * (trainer.scale ?? 1)
  const side = trainer.size * k
  const frames = still ? 1 : trainer.frames
  return (
    <span className={`relative inline-block ${className}`} style={{ width: box, height: box, ...style }} aria-label={trainer.name} role="img">
      <span
        className="pixelated absolute bottom-0 left-1/2"
        style={{
          width: side,
          height: side,
          marginLeft: -side / 2,
          backgroundImage: `url(${spriteUrl(`trainers/${trainer.id}.png`)})`,
          backgroundSize: `${trainer.frames * side}px ${side}px`,
          transform: flip ? 'scaleX(-1)' : undefined,
          '--frames': frames,
          '--strip': `${-trainer.frames * side}px`,
          animation: frames > 1 ? `${stripKeyframes(frames)} ${frames * 90 + 900}ms steps(1) infinite` : 'none',
        }}
      />
    </span>
  )
}

// Um @keyframes por número de quadros: cada quadro 90 ms, e uma pausa no primeiro.
const made = new Set()
function stripKeyframes(frames) {
  const name = `trainer-strip-${frames}`
  if (typeof document === 'undefined' || made.has(frames)) return name
  made.add(frames)
  const total = frames * 90 + 900
  const steps = []
  steps.push(`0% { background-position-x: 0; }`)
  for (let i = 1; i < frames; i++) steps.push(`${((900 + i * 90) / total) * 100}% { background-position-x: calc(var(--strip) * ${i} / var(--frames)); }`)
  steps.push(`100% { background-position-x: 0; }`)
  const style = document.createElement('style')
  style.textContent = `@keyframes ${name} { ${steps.join(' ')} }`
  document.head.appendChild(style)
  return name
}

/**
 * As costas (lançando a Poké Ball): `frame` de 0 a 4. Sem costas, a frente
 * virada para a direita.
 */
export function TrainerBack({ trainer, frame = 0, box = 140, className = '', style }) {
  if (!trainer) return null
  if (!trainer.back) return <TrainerSprite trainer={trainer} box={box * 0.8} flip className={className} style={style} />
  const { width, height, frames } = trainer.back
  const k = box / height
  return (
    <span
      role="img"
      aria-label={trainer.name}
      className={`pixelated inline-block ${className}`}
      style={{
        width: width * k,
        height: box,
        backgroundImage: `url(${spriteUrl(`trainers/${trainer.id}_back.png`)})`,
        backgroundSize: `${width * frames * k}px ${box}px`,
        backgroundPositionX: `${-Math.min(frame, frames - 1) * width * k}px`,
        ...style,
      }}
    />
  )
}

/** O rosto do treinador para a foto de perfil (o primeiro quadro, mais perto). */
export function TrainerFace({ trainer, size }) {
  if (!trainer) return null
  const side = size * 1.9
  return (
    <span className="relative block overflow-hidden" style={{ width: size, height: size }}>
      <span
        className="pixelated absolute left-1/2"
        style={{
          width: side,
          height: side,
          top: -side * 0.04,
          marginLeft: -side / 2,
          backgroundImage: `url(${spriteUrl(`trainers/${trainer.id}.png`)})`,
          backgroundSize: `${trainer.frames * side}px ${side}px`,
        }}
      />
    </span>
  )
}

/** Escolher o seu treinador (e, se quiser, usar como foto de perfil). */
export function TrainerPicker({ open, onClose }) {
  return (
    <Modal open={open} onClose={onClose} title="Escolha seu treinador" wide>
      {open && <PickerBody onClose={onClose} />}
    </Modal>
  )
}

function PickerBody({ onClose }) {
  const list = useTrainers()
  const chosen = useStore((s) => s.trainer)
  const setTrainer = useStore((s) => s.setTrainer)
  const setAvatar = useStore((s) => s.setAvatar)
  const [pick, setPick] = useState(chosen)
  const [query, setQuery] = useState('')
  const index = list?.findIndex((t) => t.id === pick) ?? -1
  const q = query.trim().toLowerCase()
  const shown = (list ?? []).filter((t) => !q || t.name.toLowerCase().includes(q) || t.title.toLowerCase().includes(q))
  return (
    <>
      <p className="mb-3 text-sm text-muted">Ele aparece na batalha lançando a Poké Ball e pode ser a sua foto de perfil.</p>
      <SearchInput value={query} onChange={setQuery} placeholder="Buscar treinador" className="mb-3" />
      <div className="grid max-h-[55vh] grid-cols-3 gap-2 overflow-y-auto sm:grid-cols-5" data-testid="trainer-list">
        {shown.map((t) => (
          <button
            key={t.id}
            type="button"
            onClick={() => setPick(t.id)}
            aria-pressed={pick === t.id}
            data-testid={`trainer-${t.id}`}
            className={`flex cursor-pointer flex-col items-center rounded-xl p-2 ring-2 transition ${pick === t.id ? 'bg-red-500/15 ring-red-500' : 'bg-bg ring-transparent hover:ring-line'}`}
          >
            <TrainerSprite trainer={t} box={84} />
            <span className="mt-1 text-center text-xs leading-tight font-bold" data-no-translate>
              {t.name}
            </span>
            <span className="text-center text-[10px] leading-tight text-muted">{t.title}</span>
          </button>
        ))}
      </div>
      <div className="mt-4 flex flex-wrap justify-end gap-2">
        <Button
          color="#64748b"
          disabled={index < 0}
          onClick={() => {
            setTrainer(pick)
            setAvatar(TRAINER_AVATAR + index)
            onClose()
          }}
        >
          Escolher e usar como foto
        </Button>
        <Button
          disabled={index < 0}
          onClick={() => {
            setTrainer(pick)
            onClose()
          }}
        >
          Escolher
        </Button>
      </div>
    </>
  )
}
