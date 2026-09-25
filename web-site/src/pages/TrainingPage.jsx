import { AnimatePresence, m } from 'framer-motion'
import { useEffect, useMemo, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import DetailsPanel from '../components/DetailsPanel'
import { PokemonMiniGrid } from '../components/EntryModals'
import PokemonPicker from '../components/PokemonPicker'
import { Button, Empty, Icon, Loader, Modal, PageHeader } from '../components/ui'
import { getEggGroups, getSpecies } from '../lib/data'
import { EV_STATS, MAX_STAT_EVS, MAX_TOTAL_EVS, NATURES, capitalize, prettyName } from '../lib/pokemon'
import { useStore } from '../lib/store'
import Sprite from '../components/Sprite'

const TOOLS = [
  { key: 'natures', label: 'Guia de Natures', subtitle: 'Veja como cada Nature afeta os status', color: '#42A5F5', icon: 'status' },
  { key: 'breeding', label: 'Ajuda de Criação (Breeding)', subtitle: 'Encontre parceiros compatíveis', color: '#EC407A', icon: 'heart' },
  { key: 'evs', label: 'Contador de EVs', subtitle: 'Acompanhe o treino dos seus Pokémon', color: '#66BB6A', icon: 'fitness' },
]

export default function TrainingPage() {
  const { tool = 'natures' } = useParams()
  const navigate = useNavigate()
  return (
    <div>
      <PageHeader title="Centro de Treinamento" subtitle="Ferramentas para treinadores dedicados que buscam o Pokémon perfeito." />
      <div className="mb-6 grid gap-3 md:grid-cols-3">
        {TOOLS.map((t) => (
          <m.button
            key={t.key}
            type="button"
            whileHover={{ scale: 1.03 }}
            onClick={() => navigate(`/treino/${t.key}`)}
            className="flex cursor-pointer items-center gap-3 rounded-2xl p-4 text-left shadow"
            animate={{ backgroundColor: tool === t.key ? t.color : 'var(--card)', color: tool === t.key ? '#fff' : 'var(--text)' }}
          >
            <span className="grid h-11 w-11 shrink-0 place-items-center rounded-full bg-white/20">
              <Icon name={t.icon} />
            </span>
            <span>
              <span className="block font-bold">{t.label}</span>
              <span className="block text-xs opacity-80">{t.subtitle}</span>
            </span>
          </m.button>
        ))}
      </div>
      <AnimatePresence mode="wait">
        <m.div key={tool} initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -12 }} transition={{ duration: 0.2 }}>
          {tool === 'natures' && <Natures />}
          {tool === 'breeding' && <Breeding />}
          {tool === 'evs' && <EvCounter />}
        </m.div>
      </AnimatePresence>
    </div>
  )
}

function Natures() {
  return (
    <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5">
      {NATURES.map((n) => (
        <m.div key={n.name} whileHover={{ scale: 1.04 }} className="rounded-2xl bg-card p-4 shadow">
          <div className="text-lg font-bold">{n.name}</div>
          {n.neutral ? (
            <div className="mt-1 text-sm text-muted">Neutra - Nenhum efeito</div>
          ) : (
            <div className="mt-1 flex gap-4 text-sm">
              <span className="text-green-400">▲ {n.increases}</span>
              <span className="text-red-400">▼ {n.decreases}</span>
            </div>
          )}
        </m.div>
      ))}
    </div>
  )
}

function Breeding() {
  const [picking, setPicking] = useState(false)
  const [chosen, setChosen] = useState(null)
  const [species, setSpecies] = useState(null)
  const [groups, setGroups] = useState(null)
  const [openId, setOpenId] = useState(null)

  useEffect(() => {
    getEggGroups().then(setGroups)
  }, [])
  useEffect(() => {
    if (chosen) getSpecies(chosen.species).then(setSpecies)
  }, [chosen])

  const partners = useMemo(() => {
    if (!species || !groups || species.eggGroups.includes('no-eggs')) return []
    const ids = new Set(species.eggGroups.flatMap((g) => groups[g] ?? []))
    ids.delete(species.id)
    // Ditto cruza com quase todos.
    ids.add(132)
    return [...ids].sort((a, b) => a - b)
  }, [species, groups])

  return (
    <div>
      <Button color="#EC407A" onClick={() => setPicking(true)}>
        {chosen ? 'Trocar Pokémon' : 'Escolher Pokémon'}
      </Button>
      {!chosen && <Empty>Escolha um Pokémon para ver os parceiros de criação compatíveis.</Empty>}
      {chosen && !species && <Loader />}
      {species && species.id === chosen.species && (
        <div className="mt-6 grid gap-6 lg:grid-cols-[320px_1fr]">
          <div className="rounded-3xl bg-card p-5 text-center shadow">
            <Sprite path={chosen.sprite} box={chosen.box} className="mx-auto w-40" />
            <h2 className="text-2xl font-bold">{capitalize(species.name)}</h2>
            <p className="mt-2 text-sm text-muted">Egg groups</p>
            <p className="font-semibold">{species.eggGroups.map(prettyName).join(', ')}</p>
            <p className="mt-2 text-sm text-muted">Egg cycle</p>
            <p className="font-semibold">{species.hatchCounter * 255 + 255} passos</p>
          </div>
          <div>
            <h3 className="mb-3 font-bold">Parceiros Compatíveis ({partners.length})</h3>
            {partners.length === 0 ? (
              <Empty>Este Pokémon não pode se reproduzir.</Empty>
            ) : (
              <PokemonMiniGrid ids={partners} onSelect={(p) => setOpenId(p.species)} />
            )}
          </div>
        </div>
      )}
      <PokemonPicker
        open={picking}
        onClose={() => setPicking(false)}
        onPick={(p) => {
          setSpecies(null)
          setChosen(p)
          setPicking(false)
        }}
      />
      <Modal open={Boolean(openId)} onClose={() => setOpenId(null)} title="Pokémon" wide>
        {openId && <DetailsPanel speciesId={openId} compact onNavigate={setOpenId} />}
      </Modal>
    </div>
  )
}

function EvCounter() {
  const training = useStore((s) => s.training)
  const addTraining = useStore((s) => s.addTraining)
  const removeTraining = useStore((s) => s.removeTraining)
  const addEvs = useStore((s) => s.addEvs)
  const resetEvs = useStore((s) => s.resetEvs)
  const [adding, setAdding] = useState(false)
  const [defeatingFor, setDefeatingFor] = useState(null)
  const [lastGain, setLastGain] = useState(null)

  const defeat = async (p) => {
    const target = defeatingFor
    setDefeatingFor(null)
    const species = await getSpecies(p.species)
    const form = species.forms.find((f) => f.id === p.id) ?? species.forms[0]
    const gained = {}
    form.stats.forEach(([, effort], i) => {
      if (effort > 0) gained[EV_STATS[i].key] = effort
    })
    addEvs(target, gained)
    setLastGain({ id: target, text: `${capitalize(p.name)}: ${Object.entries(gained).map(([k, v]) => `+${v} ${EV_STATS.find((s) => s.key === k).label}`).join(', ')}` })
  }

  return (
    <div>
      <Button color="#66BB6A" onClick={() => setAdding(true)}>
        + Adicionar Pokémon ao treino
      </Button>
      {training.length === 0 && <Empty>Nenhum Pokémon em treinamento. Clique em “Adicionar” para começar.</Empty>}
      <div className="mt-5 grid gap-4 lg:grid-cols-2 2xl:grid-cols-3">
        {training.map((t) => {
          const total = Object.values(t.evs).reduce((a, b) => a + b, 0)
          return (
            <m.div key={t.id} layout className="rounded-3xl bg-card p-5 shadow">
              <div className="flex items-center gap-3">
                <Sprite path={t.sprite} box={t.box} className="w-20 shrink-0" />
                <div className="flex-1">
                  <h3 className="text-lg font-bold">{capitalize(t.name)}</h3>
                  <p className="text-sm text-muted">
                    Total EVs: <b className="text-text">{total}</b> / {MAX_TOTAL_EVS}
                  </p>
                </div>
                <button type="button" aria-label="Remover" onClick={() => removeTraining(t.id)} className="cursor-pointer rounded-full p-2 text-muted hover:bg-red-500/20 hover:text-red-400">
                  <Icon name="delete" />
                </button>
              </div>
              <div className="mt-4 grid grid-cols-2 gap-2">
                {EV_STATS.map((s) => {
                  const value = t.evs[s.key] ?? 0
                  return (
                    <div key={s.key} className="rounded-xl bg-surface p-2.5" style={{ border: `2px solid ${s.color}` }}>
                      <div className="flex justify-between text-sm">
                        <span className="font-semibold">{s.label}</span>
                        <b>{value}</b>
                      </div>
                      <div className="mt-1.5 h-1.5 overflow-hidden rounded-full bg-white/10">
                        <m.div className="h-full" style={{ background: s.color }} animate={{ width: `${(value / MAX_STAT_EVS) * 100}%` }} />
                      </div>
                    </div>
                  )
                })}
              </div>
              <AnimatePresence>
                {lastGain?.id === t.id && (
                  <m.p initial={{ opacity: 0, y: -4 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} className="mt-3 text-sm text-green-400">
                    {lastGain.text}
                  </m.p>
                )}
              </AnimatePresence>
              <div className="mt-4 flex gap-2">
                <Button color="#43a047" onClick={() => setDefeatingFor(t.id)} className="flex-1" disabled={total >= MAX_TOTAL_EVS}>
                  Adicionar Pokémon Derrotado
                </Button>
                <button type="button" onClick={() => resetEvs(t.id)} className="cursor-pointer rounded-xl px-3 text-sm text-muted hover:text-text" title="Zerar EVs">
                  <Icon name="refresh" />
                </button>
              </div>
            </m.div>
          )
        })}
      </div>

      <PokemonPicker
        open={adding}
        title="Qual Pokémon você vai treinar?"
        onClose={() => setAdding(false)}
        onPick={(p) => {
          addTraining(p)
          setAdding(false)
        }}
      />
      <PokemonPicker open={Boolean(defeatingFor)} title="Qual Pokémon foi derrotado?" onClose={() => setDefeatingFor(null)} onPick={defeat} />
    </div>
  )
}
