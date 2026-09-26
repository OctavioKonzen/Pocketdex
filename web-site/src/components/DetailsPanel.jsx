// Painel de detalhes de um Pokémon: vitrine (Pokémon saindo da Pokébola,
// nome, tipos, formas e shiny) e as abas About, Base Stats, Evolution e Moves.

import { AnimatePresence, m } from 'framer-motion'
import { useEffect, useMemo, useState } from 'react'
import { getMoves, getSpecies, getTypes } from '../lib/data'
import {
  STAT_LABELS,
  capitalize,
  heightToFeet,
  prettyName,
  typeBackground,
  typeColor,
  typeRelations,
  weightToLbs,
} from '../lib/pokemon'
import { useStore } from '../lib/store'
import { AbilityModal, CategoryIcon, MoveModal } from './EntryModals'
import PokeballReveal from './PokeballReveal'
import { Icon, IconButton, Loader, SpinningPokeball, TypeBadge } from './ui'
import Sprite from './Sprite'

export const TABS = ['About', 'Base Stats', 'Evolution', 'Moves']

export default function DetailsPanel({
  speciesId,
  height = 620,
  tab: initialTab = 0,
  onTabChange,
  onClose,
  onNavigate,
  hasPrevious,
  hasNext,
  onPrevious,
  onNext,
  compact = false,
}) {
  const [species, setSpecies] = useState(null)
  const [formIndex, setFormIndex] = useState(0)
  const [shiny, setShiny] = useState(false)
  const [tab, setTab] = useState(initialTab)
  const [moveOpen, setMoveOpen] = useState(null)
  const [abilityOpen, setAbilityOpen] = useState(null)
  const isFavorite = useStore((s) => s.favorites.includes(speciesId))
  const toggleFavorite = useStore((s) => s.toggleFavorite)

  // O Pokémon anterior continua na tela até o próximo carregar (sem piscar).
  useEffect(() => {
    let alive = true
    getSpecies(speciesId).then((data) => {
      if (!alive) return
      setSpecies(data)
      setFormIndex(0)
      setShiny(false)
    })
    return () => {
      alive = false
    }
  }, [speciesId])

  const changeTab = (index) => {
    setTab(index)
    onTabChange?.(index)
  }

  if (!species) {
    return (
      <div className="grid place-items-center rounded-3xl bg-card" style={{ height }}>
        <Loader />
      </div>
    )
  }

  const form = species.forms[formIndex] ?? species.forms[0]
  const color = typeColor(form.types[0])
  const background = typeBackground(form.types)
  const spriteIndex = shiny && form.sprites[1] ? 1 : 0
  const sprite = form.sprites[spriteIndex] ?? form.sprites[2]
  const box = form.sprites[spriteIndex] ? form.boxes?.[spriteIndex] : null
  const selectPokemon = (p) => {
    setMoveOpen(null)
    setAbilityOpen(null)
    onNavigate?.(p.species)
  }

  return (
    <m.div
      className={`relative grid overflow-hidden rounded-3xl shadow-2xl ${compact ? 'grid-cols-1' : 'grid-cols-[5fr_7fr]'}`}
      animate={{ boxShadow: `0 12px 30px ${color}66` }}
      transition={{ duration: 0.35 }}
      style={{ height: compact ? 'auto' : height }}
    >
      {/* Fundo com a cor do tipo (gradiente se tiver dois tipos), trocando suavemente. */}
      <AnimatePresence initial={false}>
        <m.div
          key={background}
          className="absolute inset-0"
          style={{ background }}
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.4 }}
        />
      </AnimatePresence>
      {/* Vitrine */}
      <div className="relative overflow-hidden" style={{ minHeight: compact ? 420 : undefined }}>
        <div className="absolute inset-0 top-16 grid place-items-center">
          <SpinningPokeball size={Math.min(height * 0.6, 420)} opacity={0.18} slow />
        </div>
        {/* O Pokémon ocupa sempre o mesmo espaço, qualquer que seja o tamanho do sprite. */}
        <div className="absolute inset-x-14 top-[110px] bottom-[52px]" style={{ containerType: 'size' }}>
          <PokeballReveal key={species.id} ballSize={96}>
            <AnimatePresence mode="wait">
              <m.div
                key={sprite}
                style={{ width: 'min(100cqw, 100cqh)' }}
                initial={{ opacity: 0, scale: 0.85 }}
                animate={{ opacity: 1, scale: 1 }}
                exit={{ opacity: 0, scale: 0.85 }}
                whileHover={{ scale: 1.06 }}
                transition={{ duration: 0.25 }}
              >
                <Sprite path={sprite} box={box} alt={species.name} fill={0.72} />
              </m.div>
            </AnimatePresence>
          </PokeballReveal>
        </div>

        {hasPrevious && (
          <IconButton label="Anterior" onClick={onPrevious} className="absolute top-1/2 left-3 -translate-y-1/2 z-10">
            <Icon name="left" size={28} />
          </IconButton>
        )}
        {hasNext && (
          <IconButton label="Próximo" onClick={onNext} className="absolute top-1/2 right-3 -translate-y-1/2 z-10">
            <Icon name="right" size={28} />
          </IconButton>
        )}

        <div className="relative flex h-full flex-col p-6 pt-5">
          <div className="flex items-start gap-2">
            <div className="min-w-0 flex-1">
              <div className="text-sm font-bold text-white/80">#{String(species.id).padStart(3, '0')}</div>
              <h2 className="truncate text-3xl font-black text-white">{capitalize(species.name)}</h2>
              {species.genus && <div className="text-sm text-white/85">Pokémon {species.genus}</div>}
            </div>
            <IconButton label={isFavorite ? 'Remover dos favoritos' : 'Favoritar'} onClick={() => toggleFavorite(species.id)} active={isFavorite}>
              <Icon name={isFavorite ? 'star' : 'starOutline'} />
            </IconButton>
            <IconButton label={shiny ? 'Ver normal' : 'Ver shiny'} onClick={() => setShiny(!shiny)} active={shiny}>
              <Icon name="sparkle" />
            </IconButton>
            {onClose && (
              <IconButton label="Fechar" onClick={onClose}>
                <Icon name="close" />
              </IconButton>
            )}
          </div>
          <div className="mt-3 flex gap-2">
            {form.types.map((t) => (
              <TypeBadge key={t} type={t} outlined />
            ))}
          </div>
          <div className="flex-1" />
          {species.forms.length > 1 && (
            <div className="relative flex gap-1.5 overflow-x-auto pb-1">
              {species.forms.map((f, i) => (
                <m.button
                  key={f.id}
                  type="button"
                  onClick={() => setFormIndex(i)}
                  whileHover={{ scale: 1.08 }}
                  className="shrink-0 cursor-pointer rounded-full px-3 py-1.5 text-xs font-bold transition-colors"
                  style={i === formIndex ? { background: '#fff', color: typeColor(f.types[0]) } : { background: 'rgba(255,255,255,.2)', color: '#fff' }}
                >
                  {f.formName}
                </m.button>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Abas */}
      <div className="relative m-1.5 flex min-h-0 flex-col rounded-[20px] bg-bg p-5">
        <div className="flex justify-between gap-2 px-1">
          {TABS.map((title, i) => (
            <button key={title} type="button" onClick={() => changeTab(i)} className="cursor-pointer text-center">
              <span className={`text-[15px] ${tab === i ? 'font-bold text-text' : 'text-muted hover:text-text'}`}>{title}</span>
              <m.div className="mx-auto mt-1 h-[3px] rounded" animate={{ width: tab === i ? 24 : 0 }} style={{ background: color }} />
            </button>
          ))}
        </div>
        <div className="mt-4 min-h-0 flex-1 overflow-y-auto pr-1" style={{ maxHeight: compact ? 480 : undefined }}>
          <AnimatePresence mode="wait">
            <m.div key={tab} initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: -20 }} transition={{ duration: 0.18 }}>
              {tab === 0 && <AboutTab species={species} form={form} onAbility={setAbilityOpen} />}
              {tab === 1 && <StatsTab form={form} color={color} />}
              {tab === 2 && <EvolutionTab species={species} onSelect={(id) => onNavigate?.(id)} />}
              {tab === 3 && <MovesTab form={form} onMove={setMoveOpen} />}
            </m.div>
          </AnimatePresence>
        </div>
      </div>

      <MoveModal name={moveOpen} onClose={() => setMoveOpen(null)} onSelectPokemon={selectPokemon} />
      <AbilityModal name={abilityOpen} onClose={() => setAbilityOpen(null)} onSelectPokemon={selectPokemon} />
    </m.div>
  )
}

function Row({ label, children }) {
  return (
    <div className="flex gap-4 py-1 text-sm">
      <span className="w-28 shrink-0 text-muted">{label}</span>
      <span className="font-semibold">{children}</span>
    </div>
  )
}

function AboutTab({ species, form, onAbility }) {
  const [typeData, setTypeData] = useState(null)
  useEffect(() => {
    getTypes().then(setTypeData)
  }, [])
  const relations = typeData && typeRelations(form.types, typeData)
  const female = species.genderRate < 0 ? null : (species.genderRate / 8) * 100

  return (
    <div className="space-y-5">
      <p className="leading-relaxed">{species.flavor}</p>
      <div className="flex justify-around rounded-2xl bg-surface py-3 text-sm">
        <span>
          <span className="text-muted">Height: </span>
          <b>{heightToFeet(form.height)}</b>
        </span>
        <span>
          <span className="text-muted">Weight: </span>
          <b>{weightToLbs(form.weight)}</b>
        </span>
      </div>

      <section>
        <h3 className="mb-2 font-bold">Abilities</h3>
        <div className="flex flex-wrap gap-2">
          {form.abilities.map(([name, hidden]) => (
            <button
              key={name}
              type="button"
              onClick={() => onAbility(name)}
              className="cursor-pointer rounded-full bg-surface px-3 py-1.5 text-sm font-semibold transition hover:scale-105 hover:bg-white/10"
            >
              {prettyName(name)}
              {hidden && <span className="ml-1 text-xs text-muted">(oculta)</span>}
            </button>
          ))}
        </div>
      </section>

      <section>
        <h3 className="mb-1 font-bold">Breeding</h3>
        <Row label="Gender">
          {female === null ? (
            'Genderless'
          ) : (
            <>
              <span className="text-sky-400">♂ {100 - female}%</span> <span className="ml-3 text-pink-400">♀ {female}%</span>
            </>
          )}
        </Row>
        <Row label="Egg Groups">{species.eggGroups.map(prettyName).join(', ')}</Row>
        <Row label="Egg Cycle">
          {species.hatchCounter * 255 + 255} steps ({species.hatchCounter} cycles)
        </Row>
      </section>

      <section>
        <h3 className="mb-1 font-bold">Training</h3>
        <Row label="Capture rate">{species.captureRate}</Row>
        <Row label="Base happiness">{species.baseHappiness ?? '—'}</Row>
        <Row label="Growth rate">{prettyName(species.growthRate ?? '—')}</Row>
      </section>

      {relations && (
        <section className="space-y-2">
          <h3 className="font-bold">Type defenses</h3>
          <Relation label="Weak to" entries={Object.entries(relations.weaknesses)} />
          <Relation label="Resistant to" entries={Object.entries(relations.resistances)} />
          <Relation label="Immune to" entries={relations.immunities.map((t) => [t, 0])} />
        </section>
      )}
    </div>
  )
}

function Relation({ label, entries }) {
  if (entries.length === 0) return null
  return (
    <div className="flex flex-wrap items-center gap-1.5 text-sm">
      <span className="w-28 shrink-0 text-muted">{label}</span>
      {entries.map(([type, mult]) => (
        <span key={type} className="flex items-center gap-1">
          <TypeBadge type={type} small />
          <span className="text-xs text-muted">×{mult}</span>
        </span>
      ))}
    </div>
  )
}

function StatsTab({ form, color }) {
  const total = form.stats.reduce((sum, [base]) => sum + base, 0)
  return (
    <div className="space-y-3">
      {form.stats.map(([base, effort], i) => (
        <div key={STAT_LABELS[i]} className="flex items-center gap-3 text-sm">
          <span className="w-16 text-muted">{STAT_LABELS[i]}</span>
          <b className="w-9">{base}</b>
          <div className="h-1.5 flex-1 overflow-hidden rounded-full bg-white/15">
            <m.div className="h-full rounded-full" style={{ background: color }} initial={{ width: 0 }} animate={{ width: `${Math.min(100, (base / 255) * 100)}%` }} transition={{ duration: 0.6, delay: i * 0.05 }} />
          </div>
          {effort > 0 && <span className="w-12 text-right text-xs text-muted">+{effort} EV</span>}
        </div>
      ))}
      <div className="flex gap-3 pt-2 text-sm">
        <span className="w-16 text-muted">Total</span>
        <b>{total}</b>
      </div>
    </div>
  )
}

function EvolutionTab({ species, onSelect }) {
  if (species.evolution.length === 0) return <p className="py-10 text-center text-muted">Este Pokémon não evolui.</p>
  const Poke = ({ p }) => (
    <button type="button" onClick={() => onSelect(p.id)} className="flex cursor-pointer flex-col items-center transition hover:scale-110">
      <Sprite path={p.sprite} box={p.box} className="w-20" />
      <span className="text-xs font-bold">{capitalize(p.name)}</span>
    </button>
  )
  return (
    <div className="space-y-4">
      {species.evolution.map((e, i) => (
        <div key={i} className="grid grid-cols-[1fr_auto_1fr] items-center">
          <Poke p={e.from} />
          <div className="flex flex-col items-center text-xs text-muted">
            <Icon name="right" />
            {e.trigger}
          </div>
          <Poke p={e.to} />
        </div>
      ))}
    </div>
  )
}

const METHODS = [
  ['level-up', 'Nível'],
  ['machine', 'TM'],
  ['tutor', 'Tutor'],
  ['egg', 'Ovo'],
]

function MovesTab({ form, onMove }) {
  const [moves, setMoves] = useState(null)
  const [method, setMethod] = useState('level-up')
  useEffect(() => {
    getMoves().then(setMoves)
  }, [])

  const list = useMemo(() => {
    const isGmax = form.name.includes('gmax')
    const seen = new Map()
    for (const [name, m, level] of form.moves) {
      if (isGmax ? !name.includes('gmax') : m !== method || (m === 'level-up' && level === 0)) continue
      seen.set(name, Math.max(level, seen.get(name) ?? 0))
    }
    return [...seen.entries()].sort((a, b) => a[1] - b[1] || a[0].localeCompare(b[0]))
  }, [form, method])

  if (!moves) return <Loader size={50} />
  return (
    <div>
      {!form.name.includes('gmax') && (
        <div className="mb-3 flex gap-2">
          {METHODS.map(([key, label]) => (
            <button
              key={key}
              type="button"
              onClick={() => setMethod(key)}
              className={`cursor-pointer rounded-full px-3 py-1 text-xs font-bold transition ${method === key ? 'bg-text text-bg' : 'bg-surface text-muted hover:text-text'}`}
            >
              {label}
            </button>
          ))}
        </div>
      )}
      {list.length === 0 && <p className="py-10 text-center text-muted">Nenhum golpe para mostrar.</p>}
      <div className="space-y-2">
        {list.map(([name, level]) => {
          const move = moves[name]
          if (!move) return null
          return (
            <m.button
              key={name}
              type="button"
              onClick={() => onMove(name)}
              whileHover={{ scale: 1.015 }}
              className="flex w-full cursor-pointer items-center gap-3 rounded-2xl bg-surface px-4 py-3 text-left"
            >
              <div className="min-w-0 flex-1">
                <div className="font-bold">{prettyName(name)}</div>
                <div className="mt-1 flex items-center gap-2">
                  <TypeBadge type={move.type} small />
                  <CategoryIcon category={move.category} />
                </div>
              </div>
              {method === 'level-up' && level > 0 && <span className="text-sm text-muted">Lvl {level}</span>}
              <Icon name="right" className="text-muted" />
            </m.button>
          )
        })}
      </div>
    </div>
  )
}
