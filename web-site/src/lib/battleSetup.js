// Monta os Pokémon da batalha por turnos (turnBattle.js) a partir dos times,
// igual ao app (TurnBattleSetup em lib/services/turn_battle.dart): status com
// Nature/EVs/IVs pela calculadora do Showdown e 4 golpes de dano — os do set
// e, se faltar, os melhores que ele aprende (um de cada tipo primeiro).

import { getBattleItems, getMoveRules, getMoves, getPokemonById, getSpecies } from './data'
import { t } from './i18n'
import { prettyName } from './pokemon'
import { fighter } from './teamBattle'
import { CALC_WEATHER } from './turnBattle'

/** Golpes que ficam de fora do preenchimento automático (recarga, carga, se sacrificar...). */
export const BANNED_MOVES = new Set([
  'explosion', 'self-destruct', 'misty-explosion', 'memento', 'final-gambit',
  'hyper-beam', 'giga-impact', 'blast-burn', 'frenzy-plant', 'hydro-cannon', 'rock-wrecker', 'roar-of-time',
  'prismatic-laser', 'eternabeam', 'meteor-assault', 'solar-beam', 'solar-blade', 'sky-attack', 'skull-bash',
  'razor-wind', 'freeze-shock', 'ice-burn', 'geomancy', 'meteor-beam', 'electro-shot', 'focus-punch',
  'dream-eater', 'belch', 'last-resort', 'synchronoise', 'fake-out', 'first-impression', 'steel-beam',
  'mind-blown', 'shadow-force', 'phantom-force', 'dig', 'dive', 'fly', 'bounce', 'sky-drop', 'future-sight',
  'doom-desire', 'snore', 'spit-up', 'natural-gift', 'fling', 'present', 'counter', 'mirror-coat',
  'metal-burst', 'bide', 'endeavor', 'super-fang', 'natures-madness', 'ruination', 'guillotine', 'fissure',
  'horn-drill', 'sheer-cold', 'struggle', 'self-destruct', 'dragon-rage', 'sonic-boom', 'night-shade',
  'seismic-toss', 'psywave', 'hold-back', 'false-swipe', 'burn-up', 'double-shock', 'hyperspace-fury',
  'dark-void', 'upper-hand', 'poltergeist', 'sucker-punch', 'thunderclap',
])

/**
 * Os 4 golpes: os do set (de dano, ou de status que a batalha sabe usar:
 * rules[slug].ok) e, se faltar, os melhores de dano que aprende (poder × STAB ×
 * precisão), um de cada tipo primeiro. Igual ao app.
 */
export function pickMoves(setMoves, learnable, types, moves, _rules = {}) {
  const damaging = (slug) => moves[slug] && moves[slug].category !== 'status' && moves[slug].power > 0
  const usable = (slug) => Boolean(moves[slug])
  const chosen = [...new Set(setMoves.filter((s) => s && usable(s)))].slice(0, 4)
  const score = (slug) => {
    const m = moves[slug]
    return m.power * (types.includes(m.type) ? 1.5 : 1) * ((m.accuracy ?? 100) / 100)
  }
  const pool = learnable
    .filter((s) => damaging(s) && !BANNED_MOVES.has(s) && !chosen.includes(s))
    .sort((a, b) => score(b) - score(a) || (a < b ? -1 : a > b ? 1 : 0))
  for (const slug of pool) {
    if (chosen.length >= 4) break
    if (!chosen.some((c) => moves[c].type === moves[slug].type)) chosen.push(slug)
  }
  for (const slug of pool) {
    if (chosen.length >= 4) break
    if (!chosen.includes(slug)) chosen.push(slug)
  }
  return chosen
}

/** Membros do time ({id, set}) → Pokémon da batalha. */
export async function battleMons(members) {
  const calc = await import('./damageCalc')
  const byId = await getPokemonById()
  const moves = await getMoves()
  const rules = await getMoveRules().catch(() => ({}))
  const battleItems = await getBattleItems().catch(() => ({ mega: {}, z: {} }))
  const out = []
  for (const original of members) {
    const member = entryForm(original, byId, battleItems)
    const f = await fighter(calc, byId, member)
    if (!f) continue
    const stats = calc.sideStats(f.base, { ...f.side, hpPct: 100 })
    // The simulator, rather than the damage-only calculator, decides which
    // moves exist. This also preserves fixed damage and Let's Go moves.
    const known = (list) => list.filter((s) => s && globalThis.PocketDexSim.move(s))
    const slugs = pickMoves(known(member.set?.moves ?? []), known(f.learnable), f.form.types, moves, rules)
    if (!stats || !slugs.length) continue
    // Mecânicas, com as regras dos jogos: Mega só segurando a Mega Pedra dele
    // (a X ou a Y decide a forma), Z-Move só com o Cristal Z (e só nos golpes
    // do tipo dele), Dinamax menos Zacian/Zamazenta/Eternatus e o Tipo Tera.
    const species = byId.get(f.id)?.species ?? f.id
    const forms = (await getSpecies(species).catch(() => null))?.forms ?? []
    const itemId = toId((member.set?.item ?? '').replace(/--held$/, ''))
    // A Mega da forma dele, se existir (Tatsugiri Droopy → Mega Tatsugiri Droopy).
    const stoneForm = battleItems.mega?.[itemId]
    const ownMega = `${byId.get(f.id)?.name}-mega`
    const megaForm = stoneForm ? (forms.find((x) => x.name === ownMega) ?? forms.find((x) => x.name === stoneForm) ?? null) : null
    out.push({
      id: f.id,
      name: t(prettyName(byId.get(f.id)?.name ?? f.form.name)),
      level: f.side.level,
      maxHp: stats.maxHP,
      hp: stats.maxHP,
      spe: stats.stats.spe,
      types: f.form.types,
      shiny: Boolean(member.set?.shiny),
      moves: slugs.map((slug) => {
        const m = moves[slug]
        return {
          slug,
          name: calc.moveData(slug)?.name ?? slug,
          type: m.type,
          category: m.category,
          power: m.power,
          accuracy: m.accuracy ?? null,
          pp: m.pp ?? 10,
          maxPp: m.pp ?? 10,
          priority: m.priority ?? 0,
          // Regras do Pokémon Showdown (efeitos, recuo, dreno, status...).
          ...(rules[slug] ? { rules: rules[slug] } : {}),
        }
      }),
      base: f.base,
      side: f.side,
      mega: megaForm ? await megaOf(calc, byId, member, megaForm) : null,
      gmax: forms.find((x) => x.name.endsWith('-gmax'))?.id ?? null,
      teraType: (member.set?.tera || f.form.types[0] || '').toLowerCase(),
      gimmick: member.set?.gimmick || '',
      zType: battleItems.z?.[itemId] ?? '',
      noDmax: NO_DMAX.has(species),
      ability: f.side.ability ?? '',
      simulation: {set: {species: globalThis.PocketDexSim.species(f.base.name)?.name || calc.speciesName(f.base.name), moves: slugs, level: f.side.level, nature: f.side.nature, ability: f.side.ability, item: f.side.item, ivs: f.side.ivs, evs: f.side.evs, shiny: Boolean(member.set?.shiny)}},
    })
  }
  return out
}

/**
 * Formas que aparecem ao entrar na batalha segurando o item: Groudon/Kyogre
 * com Red/Blue Orb viram Primal, Zacian/Zamazenta com Rusted Sword/Shield
 * viram Crowned (como nos jogos).
 */
const ENTRY_FORMS = ['-primal', '-crowned']
function entryForm(member, byId, battleItems) {
  const itemId = toId((member.set?.item ?? '').replace(/--held$/, ''))
  const me = byId.get(member.id)
  if (!itemId || !me) return member
  for (const [form, items] of Object.entries(battleItems.forms ?? {})) {
    if (!items.includes(itemId) || !ENTRY_FORMS.some((e) => form.endsWith(e))) continue
    const target = [...byId.values()].find((p) => p.name === form && p.species === me.species)
    if (target && target.id !== member.id) return { ...member, id: target.id }
  }
  return member
}

/** Quem não pode dinamaxizar nos jogos: Zacian, Zamazenta e Eternatus. */
const NO_DMAX = new Set([888, 889, 890])
const toId = (s) => s.toLowerCase().replace(/[^a-z0-9]/g, '')

/** Atributos, tipos e habilidade da forma Mega (pela calculadora). */
async function megaOf(calc, byId, member, form) {
  const m = await fighter(calc, byId, { id: form.id, set: { ...member.set, ability: '' } })
  if (!m) return null
  const stats = calc.sideStats(m.base, { ...m.side, hpPct: 100 })
  // "charizard-mega-x" → "Mega Charizard X" (como nos jogos).
  const [base, letter] = form.name.split(/-mega-?/)
  const name = `Mega ${t(prettyName(base))}${letter ? ` ${letter.toUpperCase()}` : ''}`
  return { id: form.id, name, types: m.form.types, spe: stats?.stats.spe ?? 0, base: m.base, side: m.side, ability: m.side.ability ?? '' }
}

/** Time aleatório para o computador: 6 Pokémon totalmente evoluídos (sem lendários). */
export async function randomTeam(random) {
  const calc = await import('./damageCalc')
  const byId = await getPokemonById()
  const pool = [...byId.values()].filter((p) => p.default && !p.tag && !calc.isNfe(p.name)).sort((a, b) => a.id - b.id)
  const ids = []
  while (ids.length < 6 && ids.length < pool.length) {
    const id = pool[Math.floor(random() * pool.length)].id
    if (!ids.includes(id)) ids.push(id)
  }
  return ids.map((id) => ({ id, set: null }))
}

/** A função de dano para o motor. */
export async function battleHitter() {
  const calc = await import('./damageCalc')
  // O clima do motor (rain, sun...) vira o da calculadora (Rain, Sun...).
  return (att, def, slug, crit, power, weather) => calc.battleHit(att, def, slug, crit, power, CALC_WEATHER[weather] ?? '')
}
