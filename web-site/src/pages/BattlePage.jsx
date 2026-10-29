// Centro de Batalha (igual ao app, battle_center_screen.dart), em três partes:
//   • Batalhar: contra o computador, online com amigos e draft;
//   • Preparar o time: dano, quem vence e comparar;
//   • Consultar: tabela de tipos e Tera Raids.
// As de treino (EVs, IVs, Natures...) ficam no Treino.

import { AnimatePresence, m } from 'framer-motion'
import { useNavigate, useParams } from 'react-router-dom'
import { Compare } from '../components/BattleTools'
import DamageCalc from '../components/DamageCalc'
import ModeCard from '../components/ModeCard'
import Counters from '../components/tools/Counters'
import TeraRaid from '../components/tools/TeraRaid'
import TypeChart from '../components/tools/TypeChart'
import { PageHeader } from '../components/ui'
import { t } from '../lib/i18n'

/** Os modos de batalha: cada um abre a sua tela. */
const BATTLE_MODES = [
  { to: '/batalha/computador', pokemon: 448, emoji: '🎮', label: 'PvE', subtitle: 'Contra o computador: individual, dupla ou tripla, com o seu time ou um aleatório', from: '#DC2626', to2: '#9333EA' },
  { to: '/batalha/online', pokemon: 6, emoji: '🌐', label: 'PvP', tag: 'Ao vivo', subtitle: 'Contra amigos: convide e batalhem ao vivo', from: '#0284C7', to2: '#4F46E5' },
  { to: '/batalha/historico', pokemon: 65, emoji: '📜', label: 'Histórico e replays', subtitle: 'Suas vitórias, o MVP do time e o replay de cada batalha', from: '#059669', to2: '#0D9488' },
]

const TOOL_GROUPS = [
  {
    title: 'Preparar o time',
    tools: [
      { key: 'dano', pokemon: 68, label: 'Calculadora de dano', subtitle: 'Quanto um golpe tira do outro', color: '#EF5350', icon: 'physical' },
      { key: 'quem-vence', pokemon: 107, label: 'Quem vence?', subtitle: 'Quem ganha de um Pokémon 1 contra 1', color: '#14B8A6', icon: 'trophy' },
      { key: 'comparar', pokemon: 132, label: 'Comparar Pokémon', subtitle: 'Status e fraquezas lado a lado', color: '#7E57C2', icon: 'layers' },
    ],
  },
  {
    title: 'Consultar',
    tools: [
      { key: 'tipos', pokemon: 133, label: 'Tabela de tipos', subtitle: 'Fraquezas e resistências de cada tipo', color: '#5C6BC0', icon: 'layers' },
      { key: 'tera-raids', pokemon: 1024, label: 'Tera Raids', subtitle: 'Os melhores Pokémon contra cada chefe', color: '#DB2777', icon: 'sparkle' },
    ],
  },
]

function SectionTitle({ children }) {
  return <h2 className="font-display mb-4 text-xl font-semibold">{t(children)}</h2>
}

export default function BattlePage() {
  const { tool } = useParams()
  const navigate = useNavigate()
  return (
    <div>
      <PageHeader eyebrow="Arena" title="Batalha" subtitle="Enfrente o computador, desafie amigos online e prepare o seu time." />
      <SectionTitle>Batalhar</SectionTitle>
      <div className="mb-10 grid gap-4 md:grid-cols-2">
        {BATTLE_MODES.map((mode, i) => (
          <ModeCard key={mode.to} title={mode.label} subtitle={mode.subtitle} color={mode.from} emoji={mode.emoji} pokemon={mode.pokemon} tag={mode.tag} large={i < 2} onClick={() => navigate(mode.to)} />
        ))}
      </div>
      {TOOL_GROUPS.map((group) => (
        <div key={group.title} className="mb-6">
          <SectionTitle>{group.title}</SectionTitle>
          <div className="grid gap-4 md:grid-cols-2">
            {group.tools.map((tl) => (
              <ModeCard key={tl.key} title={tl.label} subtitle={tl.subtitle} color={tl.color} icon={tl.icon} pokemon={tl.pokemon} active={tool === tl.key} onClick={() => navigate(tool === tl.key ? '/batalha' : `/batalha/${tl.key}`)} />
            ))}
          </div>
        </div>
      ))}
      <AnimatePresence mode="wait">
        {tool && (
          <m.div key={tool} initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -12 }} transition={{ duration: 0.2 }}>
            {tool === 'dano' && <DamageCalc />}
            {tool === 'quem-vence' && <Counters />}
            {tool === 'comparar' && <Compare />}
            {tool === 'tipos' && <TypeChart />}
            {tool === 'tera-raids' && <TeraRaid />}
          </m.div>
        )}
      </AnimatePresence>
    </div>
  )
}
