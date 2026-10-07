// Centro de Batalha (igual ao app, battle_center_screen.dart), em três partes:
//   • Batalhar: contra o computador, online com amigos e draft;
//   • Preparar o time: dano, quem vence, velocidade e comparar;
//   • Consultar: tabela de tipos e Tera Raids.
// As de treino (EVs, IVs, Natures...) ficam no Treino.

import { AnimatePresence, m } from 'framer-motion'
import { useNavigate, useParams } from 'react-router-dom'
import { Compare } from '../components/BattleTools'
import DamageCalc from '../components/DamageCalc'
import Counters from '../components/tools/Counters'
import SpeedTiers from '../components/tools/SpeedTiers'
import TeraRaid from '../components/tools/TeraRaid'
import TypeChart from '../components/tools/TypeChart'
import { Icon, PageHeader } from '../components/ui'
import { t } from '../lib/i18n'

/** Os modos de batalha: cada um abre a sua tela. */
const BATTLE_MODES = [
  { to: '/batalha/computador', emoji: '🎮', label: 'Contra o computador', subtitle: 'Individual, dupla ou tripla, com o seu time ou um aleatório', from: '#DC2626', to2: '#9333EA' },
  { to: '/batalha/online', emoji: '🌐', label: 'Online com amigos', subtitle: 'Convide amigos e batalhem ao vivo', from: '#0284C7', to2: '#4F46E5' },
  { to: '/batalha/draft', emoji: '🎯', label: 'Draft', subtitle: 'Você e um amigo escolhem Pokémon um de cada vez e batalham', from: '#F59E0B', to2: '#EA580C' },
  { to: '/batalha/historico', emoji: '📜', label: 'Histórico e replays', subtitle: 'Suas vitórias, o MVP do time e o replay de cada batalha', from: '#059669', to2: '#0D9488' },
]

const TOOL_GROUPS = [
  {
    title: 'Preparar o time',
    tools: [
      { key: 'dano', label: 'Calculadora de dano', subtitle: 'Quanto um golpe tira do outro', color: '#EF5350', icon: 'physical' },
      { key: 'quem-vence', label: 'Quem vence?', subtitle: 'Quem ganha de um Pokémon 1 contra 1', color: '#14B8A6', icon: 'trophy' },
      { key: 'velocidade', label: 'Faixas de velocidade', subtitle: 'Quem ataca primeiro, com Scarf, Tailwind...', color: '#F97316', icon: 'up' },
      { key: 'comparar', label: 'Comparar Pokémon', subtitle: 'Status e fraquezas lado a lado', color: '#7E57C2', icon: 'layers' },
    ],
  },
  {
    title: 'Consultar',
    tools: [
      { key: 'tipos', label: 'Tabela de tipos', subtitle: 'Fraquezas e resistências de cada tipo', color: '#5C6BC0', icon: 'layers' },
      { key: 'tera-raids', label: 'Tera Raids', subtitle: 'Os melhores Pokémon contra cada chefe', color: '#DB2777', icon: 'sparkle' },
    ],
  },
]

function SectionTitle({ children }) {
  return <h2 className="mb-3 text-sm font-black tracking-wide text-muted uppercase">{t(children)}</h2>
}

export default function BattlePage() {
  const { tool } = useParams()
  const navigate = useNavigate()
  return (
    <div>
      <PageHeader title="Centro de Batalha" subtitle="Batalhe e prepare o seu time." />
      <SectionTitle>Batalhar</SectionTitle>
      <div className="mb-8 grid gap-3 sm:grid-cols-2">
        {BATTLE_MODES.map((mode) => (
          <m.button
            key={mode.to}
            type="button"
            whileHover={{ scale: 1.03 }}
            onClick={() => navigate(mode.to)}
            className="cursor-pointer rounded-2xl p-4 text-left text-white shadow"
            style={{ background: `linear-gradient(135deg, ${mode.from}, ${mode.to2})` }}
          >
            <span className="block text-3xl">{mode.emoji}</span>
            <span className="mt-1 block text-lg font-black">{t(mode.label)}</span>
            <span className="block text-xs opacity-90">{t(mode.subtitle)}</span>
          </m.button>
        ))}
      </div>
      {TOOL_GROUPS.map((group) => (
        <div key={group.title} className="mb-6">
          <SectionTitle>{group.title}</SectionTitle>
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            {group.tools.map((tl) => (
              <m.button
                key={tl.key}
                type="button"
                whileHover={{ scale: 1.03 }}
                onClick={() => navigate(tool === tl.key ? '/batalha' : `/batalha/${tl.key}`)}
                className="flex cursor-pointer items-center gap-3 rounded-2xl p-4 text-left shadow"
                animate={{ backgroundColor: tool === tl.key ? tl.color : 'var(--card)', color: tool === tl.key ? '#fff' : 'var(--text)' }}
              >
                <span className="grid h-11 w-11 shrink-0 place-items-center rounded-full bg-white/20" style={{ color: tool === tl.key ? undefined : tl.color }}>
                  <Icon name={tl.icon} />
                </span>
                <span>
                  <span className="block font-bold">{t(tl.label)}</span>
                  <span className="block text-xs opacity-80">{t(tl.subtitle)}</span>
                </span>
              </m.button>
            ))}
          </div>
        </div>
      ))}
      <AnimatePresence mode="wait">
        {tool && (
          <m.div key={tool} initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -12 }} transition={{ duration: 0.2 }}>
            {tool === 'dano' && <DamageCalc />}
            {tool === 'quem-vence' && <Counters />}
            {tool === 'velocidade' && <SpeedTiers />}
            {tool === 'comparar' && <Compare />}
            {tool === 'tipos' && <TypeChart />}
            {tool === 'tera-raids' && <TeraRaid />}
          </m.div>
        )}
      </AnimatePresence>
    </div>
  )
}
