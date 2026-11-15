// Página das conquistas (só pelo seu perfil): Geral, Medalhas e Pokelike, em abas. Igual ao app.

import { useState } from 'react'
import Achievements, { MedalAlbum } from '../components/Achievements'
import { PageHeader, ToolTabs } from '../components/ui'
import { t } from '../lib/i18n'

export default function AchievementsPage() {
  const [tab, setTab] = useState('geral')
  return (
    <div className="mx-auto max-w-3xl">
      <PageHeader eyebrow="Perfil" title="Conquistas" subtitle="Acompanhe seu progresso como treinador." />
      <ToolTabs
        tabs={[{ key: 'geral', label: t('Geral') }, { key: 'medalhas', label: t('Medalhas') }, { key: 'pokelike', label: 'Pokelike' }]}
        value={tab}
        onChange={setTab}
        color="#F59E0B"
      />
      {tab === 'geral' && <Achievements />}
      {tab === 'medalhas' && <MedalAlbum />}
      {tab === 'pokelike' && <Achievements factory />}
    </div>
  )
}
