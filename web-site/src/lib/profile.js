// Perfil público (igual ao app: lib/services/public_profile.dart): o que
// aparece para quem abre o link /perfil/{uid}. Fica em profiles/{uid}, que
// qualquer um lê (até sem conta); só o dono grava.
//
//   profiles/{uid} → { name, avatar, trainer, theme, shiny, champion, ranked,
//                      factory, tower, badges, hall: [{region, team: [id]}],
//                      medals: [id], caught, updatedAt }

import { medalsOf } from './medals'
import { themeIdOf, shinyUnlocked, championUnlocked } from './pokemonTheme'

const caughtCount = (collection) => new Set(Object.values(collection ?? {}).flatMap((g) => [...(g?.c ?? []), ...(g?.s ?? [])])).size

/** Os campos do perfil a partir dos dados da conta (sem o nome nem a data). */
export function profileOf({ avatar = null, trainer = 'red', themePokemon = 0, themeShiny = false, themeChampion = false, rankedRecord = 0, league = {}, collection = {} }) {
  const theme = themeIdOf(themePokemon) || 0
  return {
    avatar: avatar ?? null,
    trainer: trainer ?? 'red',
    theme,
    shiny: Boolean(theme && themeShiny && shinyUnlocked(league, theme)),
    champion: Boolean(themeChampion && championUnlocked(league)),
    ranked: rankedRecord ?? 0,
    factory: league?.factory?.best ?? 0,
    tower: league?.tower?.best ?? 0,
    badges: Object.values(league?.badges ?? {}).reduce((n, b) => n + (Array.isArray(b) ? b.length : 0), 0),
    hall: (league?.hall ?? []).slice(0, 10).map((h) => ({ region: h.region, team: (h.team ?? []).slice(0, 6) })),
    medals: medalsOf({ league, collection }).filter((m) => m.unlocked).map((m) => m.id),
    caught: caughtCount(collection),
  }
}

/** O link do perfil (o site abre com HashRouter). */
export const profileLink = (uid) => `${window.location.origin}${window.location.pathname}#/perfil/${uid}`
