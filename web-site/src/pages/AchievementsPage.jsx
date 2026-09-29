// Página das conquistas (aberta pelo menu do avatar).

import Achievements from '../components/Achievements'
import { PageHeader } from '../components/ui'

export default function AchievementsPage() {
  return (
    <div className="mx-auto max-w-2xl">
      <PageHeader title="Conquistas" />
      <Achievements />
    </div>
  )
}
