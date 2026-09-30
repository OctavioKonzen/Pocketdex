// Centro de Batalha (igual ao app): dano, quem vence, velocidade, comparar e
// tabela de tipos. As de treino (EVs, IVs, Natures...) ficam no Treino.

import { AnimatePresence, m } from 'framer-motion'
import { useNavigate, useParams } from 'react-router-dom'
import { Compare } from '../components/BattleTools'
import DamageCalc from '../components/DamageCalc'
import Counters from '../components/tools/Counters'
import SpeedTiers from '../components/tools/SpeedTiers'
import TeraRaid from '../components/tools/TeraRaid'
import TypeChart from '../components/tools/TypeChart'
import { Icon, PageHeader } from '../components/ui'

const BATTLE_TOOLS = [
  { key: 'dano', label: 'Calculadora de dano', subtitle: 'Quanto um golpe tira do outro', color: '#EF5350', icon: 'physical' },
  { key: 'quem-vence', label: 'Quem vence?', subtitle: 'Quem ganha de um Pokémon 1 contra 1', color: '#14B8A6', icon: 'trophy' },
  { key: 'velocidade', label: 'Faixas de velocidade', subtitle: 'Quem ataca primeiro, com Scarf, Tailwind...', color: '#F97316', icon: 'up' },
  { key: 'comparar', label: 'Comparar Pokémon', subtitle: 'Status e fraquezas lado a lado', color: '#7E57C2', icon: 'layers' },
  { key: 'tipos', label: 'Tabela de tipos', subtitle: 'Fraquezas e resistências de cada tipo', color: '#5C6BC0', icon: 'layers' },
  { key: 'tera-raids', label: 'Tera Raids', subtitle: 'Os melhores Pokémon contra cada chefe', color: '#DB2777', icon: 'sparkle' },
]

export default function BattlePage() {
  const { tool = 'dano' } = useParams()
  const navigate = useNavigate()
  return (
    <div>
      <PageHeader title="Centro de Batalha" subtitle="Ferramentas para vencer as batalhas." />
      <div className="mb-6 grid gap-3 sm:grid-cols-2 lg:grid-cols-3 2xl:grid-cols-5">
        {BATTLE_TOOLS.map((t) => (
          <m.button
            key={t.key}
            type="button"
            whileHover={{ scale: 1.03 }}
            onClick={() => navigate(`/batalha/${t.key}`)}
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
          {tool === 'dano' && <DamageCalc />}
          {tool === 'quem-vence' && <Counters />}
          {tool === 'velocidade' && <SpeedTiers />}
          {tool === 'comparar' && <Compare />}
          {tool === 'tipos' && <TypeChart />}
          {tool === 'tera-raids' && <TeraRaid />}
        </m.div>
      </AnimatePresence>
    </div>
  )
}
