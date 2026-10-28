// Página das conquistas (aberta pelo menu do avatar).

import Achievements, { MedalAlbum } from '../components/Achievements'
import { PageHeader } from '../components/ui'

export default function AchievementsPage() {
  return (
    <div className="mx-auto max-w-3xl">
      <PageHeader eyebrow="Perfil" title="Conquistas" subtitle="Acompanhe seu progresso como treinador." />
      <div className="space-y-5">
        <MedalAlbum />
        <Achievements />
      </div>
    </div>
  )
}
