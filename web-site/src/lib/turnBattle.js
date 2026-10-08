// Production battles use the shared offline Pokémon Showdown simulator.
// The callback-based path is retained for legacy test fixtures without simulator sets.
import {initializeSimulator, simulatorCanGimmick, simulatorRecommend, simulatorTurn} from './battleSimulator'

export const STRUGGLE = { slug: 'struggle', name: 'Struggle', type: 'normal', category: 'physical', power: 50, accuracy: null, pp: 1, maxPp: 1, priority: 0 }
/** Chance de crítico por estágio (geração 7 em diante). */
const CRIT_CHANCE = [1 / 24, 1 / 8, 1 / 2, 1]
export const STATS = ['atk', 'def', 'spa', 'spd', 'spe']
/** Nome dos atributos nas falas (em português; a tela traduz). */
export const STAT_NAMES = { atk: 'Ataque', def: 'Defesa', spa: 'Ataque Especial', spd: 'Defesa Especial', spe: 'Velocidade', accuracy: 'Precisão', evasion: 'Evasão' }
/** Tipos imunes a cada status. */
const STATUS_IMMUNE = { brn: ['fire'], par: ['electric'], psn: ['poison', 'steel'], tox: ['poison', 'steel'], frz: ['ice'], slp: [] }

/** Começa (ou recomeça) o estado de batalha de um Pokémon. */
function resetMon(mon) {
  // Mega, Terastal e Dinamax só valem na batalha: na próxima, volta ao original.
  if (!mon.orig) mon.orig = { id: mon.id, types: mon.types, spe: mon.spe, maxHp: mon.maxHp, base: mon.base, side: mon.side, mega: mon.mega, ability: mon.ability }
  else {
    Object.assign(mon, mon.orig)
    mon.hp = Math.min(mon.hp, mon.maxHp)
  }
  mon.status = ''
  mon.sleep = 0
  mon.toxic = 0
  mon.flinch = false
  mon.boosts = { atk: 0, def: 0, spa: 0, spd: 0, spe: 0 }
  mon.terastal = false
  mon.dmax = 0
}

/** Multiplicador de um estágio de atributo (−6 a +6). */
const stageMult = (s) => (s >= 0 ? (2 + s) / 2 : 2 / (2 - s))
/** Velocidade na hora da ordem: estágio, paralisia (metade) e as habilidades do clima (dobro). */
export const speedOf = (mon, weather = '') => {
  if (mon.effectiveSpe != null) return mon.effectiveSpe
  let spe = Math.floor(mon.spe * stageMult(mon.boosts?.spe ?? 0))
  if (weather && SPEED_ABILITIES[mon.ability]?.includes(weather)) spe *= 2
  return mon.status === 'par' ? Math.floor(spe / 2) : spe
}

/** Climas: rain | sun | sand | hail | snow. Golpes de status que mudam o clima. */
export const WEATHER_MOVES = { 'rain-dance': 'rain', 'sunny-day': 'sun', sandstorm: 'sand', hail: 'hail', snowscape: 'snow' }
/** Max Moves que mudam o clima (pelo tipo). */
const MAX_WEATHER = { water: 'rain', fire: 'sun', rock: 'sand', ice: 'hail' }
/** Habilidades que mudam o clima quando o Pokémon entra (ou megaevolui). */
const WEATHER_ABILITIES = { Drizzle: 'rain', Drought: 'sun', 'Orichalcum Pulse': 'sun', 'Sand Stream': 'sand', 'Snow Warning': 'snow' }
/** Habilidades que dobram a velocidade no clima. */
const SPEED_ABILITIES = { 'Swift Swim': ['rain'], Chlorophyll: ['sun'], 'Sand Rush': ['sand'], 'Slush Rush': ['hail', 'snow'] }
/** Nome do clima na calculadora do Showdown. */
export const CALC_WEATHER = { rain: 'Rain', sun: 'Sun', sand: 'Sand', hail: 'Hail', snow: 'Snow' }
/** Quem não sofre com a areia e o granizo. */
const WEATHER_IMMUNE = { sand: ['rock', 'ground', 'steel'], hail: ['ice'] }

/** Começa um clima (5 turnos). Se já estava, o golpe de [side] falha. */
function setWeather(battle, weather, events, side = -1) {
  if (battle.weather === weather) {
    if (side >= 0) say(events, 'failed', label(battle, side))
    return
  }
  battle.weather = weather
  battle.weatherTurns = 5
  events.push({ t: 'weather', weather })
  say(events, `${weather}Start`)
}

/** Habilidade de clima de quem acabou de entrar (ou megaevoluir). */
function weatherAbility(battle, side, events) {
  const mon = active(battle, side)
  const weather = WEATHER_ABILITIES[mon.ability]
  if (weather && mon.hp > 0 && battle.weather !== weather) setWeather(battle, weather, events)
}

/** Precisão do golpe no clima (Thunder e Hurricane na chuva/sol, Blizzard no granizo/neve). */
function accuracyOf(battle, move) {
  if (move.slug === 'thunder' || move.slug === 'hurricane') {
    if (battle.weather === 'rain') return null
    if (battle.weather === 'sun') return 50
  }
  if (move.slug === 'blizzard' && (battle.weather === 'hail' || battle.weather === 'snow')) return null
  return move.accuracy
}

/** Itens da Bolsa (os mesmos dos dois lados) e quantos cada um começa. */
export const ITEMS = [
  { slug: 'potion', name: 'Potion', heal: 20, count: 3 },
  { slug: 'super-potion', name: 'Super Potion', heal: 60, count: 2 },
  { slug: 'hyper-potion', name: 'Hyper Potion', heal: 120, count: 1 },
  { slug: 'revive', name: 'Revive', revive: true, count: 1 },
]
const newBag = () => Object.fromEntries(ITEMS.map((i) => [i.slug, i.count]))
const itemOf = (slug) => ITEMS.find((i) => i.slug === slug)

/** Dá para usar o item nesse Pokémon? (poção: vivo e ferido; Revive: desmaiado). */
export function canUseItem(battle, side, slug, index) {
  const item = itemOf(slug)
  const mon = battle.sides[side].team[index]
  if (!item || !mon || !(battle.bags[side][slug] > 0)) return false
  return item.revive ? mon.hp <= 0 : mon.hp > 0 && mon.hp < mon.maxHp
}

/** Nova batalha. teams: [meus Pokémon, os do computador]; random: () => [0, 1). */
export function newBattle(mine, theirs, random, options = {}) {
  for (const mon of [...mine, ...theirs]) resetMon(mon)
  const battle = {
    mode: options.mode || 'singles', controllers: options.controllers,
    sides: [
      { team: mine, active: 0 },
      { team: theirs, active: 0 },
    ],
    random,
    bags: [newBag(), newBag()],
    turn: 1,
    // Semente da batalha (para o replay) e as suas jogadas (logTurn).
    seed: options.seed ?? null,
    actions: [],
    // Como o computador joga: 'easy' (golpe ao acaso na maioria das vezes, sem trocas nem Bolsa) ou 'normal'.
    ai: options.ai || 'normal',
    cpuSwitchTurn: -2,
    gimmicks: [null, null], // última mecânica usada, para o registro
    usedGimmicks: [[], []], // cada mecânica pode ser usada uma vez por lado
    weather: '', // rain | sun | sand | hail | snow
    weatherTurns: 0,
    winner: null, // 0 = você ganhou, 1 = o computador
    needSwitch: false, // seu Pokémon desmaiou: escolha outro
  }
  if ([...mine, ...theirs].every(mon => mon.simulation)) {
    initializeSimulator(battle)
    // Quem acabou de entrar fica pelo menos dois turnos antes de o computador trocar.
    battle.cpuSwitchTurn = battle.turn
  }
  return battle
}

export const active = (battle, side) => battle.sides[side].team[battle.sides[side].active]

/**
 * Golpe que continua sozinho neste turno (Outrage, Thrash, Rollout, o segundo
 * turno de Solar Beam/Fly, a recarga do Hyper Beam...): {slug, name, index}
 * ou null. Nesse turno não tem escolha: a tela joga sozinha. Igual ao app.
 */
export function lockedMove(battle, side = 0) {
  const locked = battle.simulator?.state.sides[side]?.locked
  if (!locked) return null
  const key = (s) => String(s ?? '').toLowerCase().replace(/[^a-z0-9]/g, '')
  const index = active(battle, side).moves.findIndex((m) => key(m.slug) === key(locked.slug))
  return { ...locked, index }
}
const alive = (battle, side) => battle.sides[side].team.filter((p) => p.hp > 0).length
const say = (events, key, ...args) => events.push({ t: 'text', key, args })
/** Nome como aparece nas falas: o do computador é "X inimigo". */
const label = (battle, side) => ({ side, name: active(battle, side).name })

/** As mecânicas especiais, na ordem dos botões. */
export const GIMMICKS = ['mega', 'z', 'dmax', 'tera']

/** Z-Move de cada tipo. */
export const Z_MOVES = {
  normal: 'Breakneck Blitz', fire: 'Inferno Overdrive', water: 'Hydro Vortex', grass: 'Bloom Doom', electric: 'Gigavolt Havoc',
  ice: 'Subzero Slammer', fighting: 'All-Out Pummeling', poison: 'Acid Downpour', ground: 'Tectonic Rage', flying: 'Supersonic Skystrike',
  psychic: 'Shattered Psyche', bug: 'Savage Spin-Out', rock: 'Continental Crush', ghost: 'Never-Ending Nightmare', dragon: 'Devastating Drake',
  dark: 'Black Hole Eclipse', steel: 'Corkscrew Crash', fairy: 'Twinkle Tackle',
}

/** Max Move de cada tipo. */
export const MAX_MOVES = {
  normal: 'Max Strike', fire: 'Max Flare', water: 'Max Geyser', grass: 'Max Overgrowth', electric: 'Max Lightning',
  ice: 'Max Hailstorm', fighting: 'Max Knuckle', poison: 'Max Ooze', ground: 'Max Quake', flying: 'Max Airstream',
  psychic: 'Max Mindstorm', bug: 'Max Flutterby', rock: 'Max Rockfall', ghost: 'Max Phantasm', dragon: 'Max Wyrmwind',
  dark: 'Max Darkness', steel: 'Max Steelspike', fairy: 'Max Starfall',
}

/** Poder do Z-Move pelo poder do golpe (tabela dos jogos). */
export function zPower(power) {
  const table = [[55, 100], [65, 120], [75, 140], [85, 160], [95, 175], [100, 180], [110, 185], [125, 190], [130, 195]]
  return (table.find(([max]) => power <= max) ?? [0, 200])[1]
}

/** Poder do Max Move (Lutador e Venenoso têm uma tabela mais fraca). */
export function maxPower(power, type) {
  const weak = type === 'fighting' || type === 'poison'
  const table = weak
    ? [[40, 70], [50, 75], [60, 80], [70, 85], [100, 90], [140, 95]]
    : [[40, 90], [50, 100], [60, 110], [70, 120], [100, 130], [140, 140]]
  return (table.find(([max]) => power <= max) ?? [0, weak ? 100 : 150])[1]
}

/**
 * Dá para usar essa mecânica agora? Uma vez por mecânica e por time; Mega
 * só com a Mega Pedra (mon.mega), Z-Move só com o Cristal Z do tipo do golpe
 * [moveIndex] (mon.zType), Dinamax menos quem não pode (mon.noDmax).
 */
export function canGimmick(battle, side, gimmick, moveIndex = -1) {
  if (battle.simulator) return simulatorCanGimmick(battle, side, gimmick, moveIndex)
  const mon = active(battle, side)
  if (battle.usedGimmicks[side].includes(gimmick) || mon.hp <= 0) return false
  if (mon.gimmick && mon.gimmick !== gimmick) return false
  if (gimmick === 'mega') return Boolean(mon.mega)
  if (gimmick === 'tera') return Boolean(mon.teraType)
  if (gimmick === 'z') {
    // Só com o Cristal Z, e só nos golpes de dano do tipo dele.
    const move = mon.moves[moveIndex]
    return Boolean(move) && move.category !== 'status' && move.pp > 0 && !mon.dmax && move.type === mon.zType
  }
  return gimmick === 'dmax' && !mon.noDmax
}

/** Mega, Terastal e Dinamax acontecem no começo do turno (o Z-Move, no golpe). */
function applyGimmick(battle, side, gimmick, events) {
  const mon = active(battle, side)
  battle.gimmicks[side] = gimmick
  battle.usedGimmicks[side].push(gimmick)
  if (gimmick === 'mega') {
    const mega = mon.mega
    say(events, 'megaReact', label(battle, side))
    Object.assign(mon, { id: mega.id, types: mega.types, spe: mega.spe, ...(mega.base ? { base: mega.base, side: mega.side } : {}), ...(mega.calc ? { calc: mega.calc } : {}), ...('ability' in mega ? { ability: mega.ability } : {}) })
    mon.mega = null
    events.push({ t: 'mega', side, id: mega.id })
    say(events, 'megaEvolved', label(battle, side), mega.name)
    weatherAbility(battle, side, events)
  } else if (gimmick === 'tera') {
    mon.terastal = true
    mon.types = [mon.teraType]
    if (mon.side) mon.side = { ...mon.side, terastallized: true, teraType: mon.teraType }
    events.push({ t: 'tera', side, type: mon.teraType })
    say(events, 'terastallized', label(battle, side), mon.teraType.toUpperCase())
  } else if (gimmick === 'dmax') {
    mon.dmax = 3
    mon.maxHp *= 2
    mon.hp *= 2
    events.push({ t: 'dmax', side, on: true, id: mon.gmax ?? mon.id })
    events.push({ t: 'hp', side, hp: mon.hp })
    say(events, mon.gmax ? 'gigantamaxed' : 'dynamaxed', label(battle, side))
  }
}

/** Fim do Dinamax: volta ao tamanho e à vida de antes (proporcional). */
function endDmax(battle, side, events, quiet = false) {
  const mon = active(battle, side)
  if (!mon.dmax) return
  mon.dmax = 0
  mon.maxHp /= 2
  mon.hp = mon.hp > 0 ? Math.max(1, (mon.hp + 1) >> 1) : 0
  if (quiet) return
  events.push({ t: 'dmax', side, on: false, id: mon.id })
  events.push({ t: 'hp', side, hp: mon.hp })
  say(events, 'dmaxEnd', label(battle, side))
}

/**
 * O computador usa a mecânica dele uma vez: a do set (no primeiro ataque,
 * como a sua) ou, sem set (time aleatório), num turno qualquer.
 */
function cpuGimmick(battle, moveIndex) {
  const mon = active(battle, 1)
  if (mon.gimmick) return canGimmick(battle, 1, mon.gimmick, moveIndex) ? mon.gimmick : null
  if (battle.random() >= 0.35) return null
  if (canGimmick(battle, 1, 'mega')) return 'mega'
  const options = ['tera', 'dmax'].filter((g) => canGimmick(battle, 1, g))
  if (canGimmick(battle, 1, 'z', moveIndex)) options.push('z')
  return options.length ? options[Math.floor(battle.random() * options.length)] : null
}

/** Golpes que dá para usar; sem PP em nenhum, só Struggle. */
export const usableMoves = (mon) => mon.moves.map((m, i) => (m.pp > 0 && !m.disabled ? i : -1)).filter((i) => i >= 0)

/** Dano médio esperado (sem crítico), para a escolha do computador. */
function expected(battle, hit, att, def, move) {
  if (move.category === 'status') return 0
  const r = hit(att, def, move.slug, false, undefined, battle.weather)
  if (!r || !r.eff) return 0
  const avg = r.rolls.reduce((sum, rolls) => sum + rolls.reduce((a, b) => a + b, 0) / rolls.length, 0)
  return Math.min(avg, def.hp) * (move.accuracy == null ? 1 : move.accuracy / 100)
}

/**
 * Dano estimado de um golpe em % da vida máxima do alvo ([mínimo, máximo]),
 * a mesma conta da batalha (sem crítico); null para golpe de status.
 */
export function damageRange(hit, att, def, move, weather = '') {
  if (move.category === 'status' || !def?.maxHp) return null
  const r = hit(att, def, move.slug, false, undefined, weather)
  if (!r || !r.eff) return [0, 0]
  const low = r.rolls.reduce((sum, rolls) => sum + Math.min(...rolls), 0)
  const high = r.rolls.reduce((sum, rolls) => sum + Math.max(...rolls), 0)
  return [Math.floor((low * 100) / def.maxHp), Math.floor((high * 100) / def.maxHp)]
}

/** Nomes das condições do campo (armadilhas, telas, Trick Room...): os do jogo, sem traduzir. */
export const FIELD_NAMES = {
  stealthrock: 'Stealth Rock', spikes: 'Spikes', toxicspikes: 'Toxic Spikes', stickyweb: 'Sticky Web', gmaxsteelsurge: 'Steelsurge',
  reflect: 'Reflect', lightscreen: 'Light Screen', auroraveil: 'Aurora Veil', tailwind: 'Tailwind', safeguard: 'Safeguard',
  mist: 'Mist', luckychant: 'Lucky Chant', trickroom: 'Trick Room', gravity: 'Gravity', magicroom: 'Magic Room',
  wonderroom: 'Wonder Room', electricterrain: 'Electric Terrain', grassyterrain: 'Grassy Terrain',
  mistyterrain: 'Misty Terrain', psychicterrain: 'Psychic Terrain',
}

/** O campo em textos curtos: [[o seu lado], [o do adversário], [o campo todo]]. */
export function fieldConditions(battle) {
  const state = battle.simulator?.state
  if (!state) return [[], [], []]
  const label = (id, n) => {
    const name = FIELD_NAMES[id] ?? id
    if (['spikes', 'toxicspikes'].includes(id) && n > 1) return `${name} ×${n}`
    return name
  }
  const sides = [0, 1].map((s) => Object.entries(state.sides[s]?.conditions ?? {}).map(([id, n]) => label(id, n)))
  const all = [...(state.pseudoWeather ?? []).map((id) => label(id)), ...(state.terrain ? [label(state.terrain)] : [])]
  return [...sides, all]
}

/** O que a tela mostra de um Pokémon no campo (side 0: o seu, tudo; 1: o adversário, só o que já apareceu). */
export function monDetails(battle, side) {
  const state = battle.simulator?.state?.sides?.[side]
  const index = battle.sides[side].active
  const entry = state?.team?.find((m) => m.index === index)
  if (!entry) return null
  const shown = side === 0
  return {
    ability: shown ? entry.ability : entry.revealed?.ability || null,
    item: shown ? entry.item : entry.revealed?.item || null,
    moves: shown ? entry.moves.map((m) => `${m.name} (${m.pp}/${m.maxPp})`) : entry.revealed?.moves ?? [],
    stats: shown ? entry.stats : null,
    types: entry.types,
    tera: entry.tera,
  }
}

/** Efetividade de um golpe (×0 a ×4), a mesma da conta de dano; null para golpe de status. */
export function moveEffect(hit, att, def, move) {
  if (move.category === 'status') return null
  return hit(att, def, move.slug, false)?.eff ?? null
}

/** As palavras dos jogos para a efetividade (a tela traduz). */
export function effectLabel(eff) {
  if (eff == null) return null
  if (eff === 0) return 'Não afeta'
  if (eff < 1) return 'Pouco efetivo'
  if (eff > 1) return 'Super efetivo'
  return 'Efetivo'
}

/**
 * Para a troca: o melhor golpe dele contra o inimigo (attack, null se só tem
 * golpe de status) e o quanto ele sofre com os tipos do inimigo (defense).
 * typeEff(tipo, tipos) = multiplicador de um tipo de ataque contra os tipos.
 */
export function switchMatchup(hit, mon, foe, typeEff) {
  const effs = mon.moves.map((m) => moveEffect(hit, mon, foe, m)).filter((e) => e != null)
  return {
    attack: effs.length ? Math.max(...effs) : null,
    defense: Math.max(...foe.types.map((t) => typeEff(t, mon.types))),
  }
}

/** Tipos que causam ×2 ou mais no Pokémon, do pior para ele ao menos pior. */
export function weaknesses(types, allTypes, typeEff) {
  return allTypes
    .map((t) => ({ type: t, mult: typeEff(t, types) }))
    .filter((w) => w.mult >= 2)
    .sort((a, b) => b.mult - a.mult)
}

/**
 * Escolha do computador, como um treinador: nocauteia quando dá (com
 * prioridade se o seu é mais rápido), não gasta turno com cura ou bônus
 * quando vai cair antes, e senão o maior dano previsto ou um status útil.
 */
export function cpuMove(battle, hit) {
  const me = active(battle, 1)
  const foe = active(battle, 0)
  const usable = usableMoves(me)
  if (!usable.length) return -1
  const faster = speedOf(me, battle.weather) >= speedOf(foe, battle.weather)
  const threat = bestDamage(battle, hit, foe, me)
  // O seu derruba ele antes de ele agir: só um golpe de prioridade age antes.
  const doomed = threat >= me.hp && !faster
  let best = usable[0]
  let bestValue = -1
  for (const i of usable) {
    const move = me.moves[i]
    const first = faster || move.priority > 0
    let value = move.category === 'status' ? statusValue(battle, me, foe, move, threat) : expected(battle, hit, me, foe, move)
    // Nocaute: vale o dobro (e mais se acerta antes do seu).
    if (move.category !== 'status' && value > 0 && averageDamage(battle, hit, me, foe, move) >= foe.hp) value += foe.hp * (first ? 2 : 1) * accuracyFactor(move)
    if (doomed && move.priority <= 0) value *= 0.3
    if (value > bestValue) {
      best = i
      bestValue = value
    }
  }
  return best
}

function accuracyFactor(move) {
  return move.accuracy == null ? 1 : move.accuracy / 100
}

/** Dano médio (sem contar a precisão), para saber se nocauteia. */
function averageDamage(battle, hit, att, def, move) {
  const r = hit(att, def, move.slug, false, undefined, battle.weather)
  if (!r || !r.eff) return 0
  return r.rolls.reduce((sum, rolls) => sum + rolls.reduce((a, b) => a + b, 0) / rolls.length, 0)
}

/** Quanto vale um golpe de status para o computador (comparado com dano). threat: o dano que ele sofre por turno. */
function statusValue(battle, me, foe, move, threat = 0) {
  const r = move.rules ?? {}
  // Clima: vale se ainda não está e ajuda os golpes dele.
  const weather = WEATHER_MOVES[move.slug]
  if (weather) {
    const helps = { rain: 'water', sun: 'fire', sand: 'rock', hail: 'ice', snow: 'ice' }[weather]
    return battle.weather !== weather && me.moves.some((m) => m.type === helps && m.category !== 'status') ? Math.floor(foe.maxHp * 0.2) : 0
  }
  // Cura só se recupera mais do que perde no turno (senão é turno perdido).
  if (r.h) {
    const healed = Math.min(me.maxHp - me.hp, Math.floor((me.maxHp * r.h[0]) / r.h[1]))
    return me.hp * 2 < me.maxHp && healed > threat ? healed : 0
  }
  if (r.s) return !foe.status && !immuneTo(foe, r.s, move) ? Math.floor(foe.maxHp * (r.s === 'slp' ? 0.5 : 0.3)) : 0
  // Bônus em si mesmo só com folga: vida alta e o inimigo sem tirar 1/3 por turno.
  if (r.b && r.t === 'self') {
    const room = Object.entries(r.b).some(([k, v]) => v > 0 && me.boosts[k] < 2)
    return room && me.hp * 10 >= me.maxHp * 6 && threat * 3 < me.hp ? Math.floor(me.maxHp * 0.25) : 0
  }
  if (r.b) return Object.entries(r.b).some(([k, v]) => v < 0 && (foe.boosts[k] ?? 0) > -2) ? Math.floor(foe.maxHp * 0.1) : 0
  return 0
}

/** O Pokémon é imune a esse status (pelo tipo; Thunder Wave não pega em Ground)? */
function immuneTo(mon, status, move) {
  if (STATUS_IMMUNE[status].some((t) => mon.types.includes(t))) return true
  return move?.category === 'status' && move.type === 'electric' && mon.types.includes('ground')
}

/** Status num Pokémon. fromMove: veio de um golpe de status (se não pegar, "Mas falhou!"). */
function inflict(battle, side, status, move, events, fromMove) {
  const mon = active(battle, side)
  if (mon.status || immuneTo(mon, status, move)) {
    if (fromMove) say(events, mon.status ? 'failed' : 'noEffect', label(battle, side))
    return
  }
  mon.status = status
  if (status === 'slp') mon.sleep = 1 + Math.floor(battle.random() * 3)
  if (status === 'tox') mon.toxic = 1
  events.push({ t: 'status', side, status })
  say(events, { brn: 'burned', par: 'paralyzed', psn: 'poisoned', tox: 'badlyPoisoned', slp: 'fellAsleep', frz: 'frozen' }[status], label(battle, side))
}

/** Muda os atributos (estágios de −6 a +6) e diz como ficou. */
function boost(battle, side, boosts, events) {
  const mon = active(battle, side)
  for (const stat of STATS) {
    const by = boosts[stat]
    if (!by) continue
    const now = Math.max(-6, Math.min(6, mon.boosts[stat] + by))
    if (now === mon.boosts[stat]) {
      say(events, by > 0 ? 'statMax' : 'statMin', label(battle, side), stat)
      continue
    }
    const size = Math.min(3, Math.abs(now - mon.boosts[stat]))
    mon.boosts[stat] = now
    say(events, `${by > 0 ? 'statUp' : 'statDown'}${size > 1 ? size : ''}`, label(battle, side), stat)
  }
}

/** Golpe de status: cura, causa status ou muda atributos. */
function statusMove(battle, side, move, events) {
  const mon = active(battle, side)
  const r = move.rules ?? {}
  if (WEATHER_MOVES[move.slug]) {
    setWeather(battle, WEATHER_MOVES[move.slug], events, side)
    return
  }
  if (r.h) {
    if (mon.hp >= mon.maxHp) say(events, 'failed', label(battle, side))
    else {
      const [n, d] = weatherHeal(battle, move.slug) ?? r.h
      mon.hp = Math.min(mon.maxHp, mon.hp + Math.floor((mon.maxHp * n) / d))
      events.push({ t: 'hp', side, hp: mon.hp })
      say(events, 'healedMove', label(battle, side))
    }
  }
  if (r.s) inflict(battle, 1 - side, r.s, move, events, true)
  if (r.b) boost(battle, r.t === 'self' ? side : 1 - side, r.b, events)
  if (!r.h && !r.s && !r.b) say(events, 'failed', label(battle, side))
}

/** Cura que muda com o clima: Moonlight, Synthesis e Morning Sun (sol 2/3, outro clima 1/4), Shore Up (areia 2/3). */
function weatherHeal(battle, slug) {
  if (!battle.weather) return null
  if (slug === 'shore-up') return battle.weather === 'sand' ? [2, 3] : null
  if (!['moonlight', 'synthesis', 'morning-sun'].includes(slug)) return null
  return battle.weather === 'sun' ? [2, 3] : [1, 4]
}

/** Quem ficou sem vida desmaia ([first] primeiro: o alvo do golpe). */
function faints(battle, events, first = 1) {
  for (const s of [first, 1 - first]) {
    const m = active(battle, s)
    if (m.hp <= 0 && !m.faintShown) {
      m.faintShown = true
      endDmax(battle, s, events, true)
      events.push({ t: 'faint', side: s })
      say(events, 'fainted', label(battle, s))
    }
  }
}

/** Fim do turno: queimadura e veneno tiram vida; quem recuou volta ao normal. */
function endOfTurn(battle, events) {
  // Clima: conta os turnos; areia e granizo machucam quem não é imune.
  if (battle.weather) {
    const weather = battle.weather
    battle.weatherTurns -= 1
    if (battle.weatherTurns <= 0) {
      battle.weather = ''
      events.push({ t: 'weather', weather: '' })
      say(events, `${weather}End`)
    } else {
      say(events, `${weather}Go`)
      for (const s of [0, 1]) {
        const mon = active(battle, s)
        if (mon.hp <= 0 || !WEATHER_IMMUNE[weather] || mon.types.some((t) => WEATHER_IMMUNE[weather].includes(t))) continue
        mon.hp = Math.max(0, mon.hp - Math.max(1, Math.floor(mon.maxHp / 16)))
        events.push({ t: 'hp', side: s, hp: mon.hp })
        say(events, weather === 'sand' ? 'hurtSand' : 'hurtHail', label(battle, s))
      }
      faints(battle, events, 0)
    }
  }
  for (const s of [0, 1]) {
    const mon = active(battle, s)
    if (mon.hp <= 0) continue
    let loss = 0
    if (mon.status === 'brn') loss = Math.max(1, Math.floor(mon.maxHp / 16))
    if (mon.status === 'psn') loss = Math.max(1, Math.floor(mon.maxHp / 8))
    if (mon.status === 'tox') {
      loss = Math.max(1, Math.floor((mon.maxHp * mon.toxic) / 16))
      mon.toxic = Math.min(15, mon.toxic + 1)
    }
    if (loss) {
      mon.hp = Math.max(0, mon.hp - loss)
      events.push({ t: 'hp', side: s, hp: mon.hp })
      say(events, mon.status === 'brn' ? 'hurtBurn' : 'hurtPoison', label(battle, s))
    }
  }
  faints(battle, events, 0)
  // Dinamax dura 3 turnos.
  for (const s of [0, 1]) {
    const mon = active(battle, s)
    if (mon.dmax > 1 && mon.hp > 0) mon.dmax -= 1
    else if (mon.dmax === 1 && mon.hp > 0) endDmax(battle, s, events)
  }
  for (const s of [0, 1]) for (const mon of battle.sides[s].team) mon.flinch = false
}

/** Quem o computador manda quando o dele desmaia: o que mais machuca o seu. */
function cpuReplacement(battle, hit) {
  const foe = active(battle, 0)
  let best = -1
  let bestValue = -1
  battle.sides[1].team.forEach((mon, i) => {
    if (battle.simulator ? !battle.simulator.state.sides[1].switchOptions.includes(i) : mon.hp <= 0) return
    const value = Math.max(0, ...usableMoves(mon).map((m) => expected(battle, hit, mon, foe, mon.moves[m])))
    if (value > bestValue) {
      best = i
      bestValue = value
    }
  })
  return best
}

function doMove(battle, side, moveIndex, hit, events, zMove = false) {
  const mon = active(battle, side)
  const foeSide = 1 - side
  const target = active(battle, foeSide)
  // Antes do golpe: congelado, dormindo, recuou ou paralisado.
  if (mon.status === 'frz') {
    if (battle.random() < 0.2) {
      mon.status = ''
      events.push({ t: 'status', side, status: '' })
      say(events, 'thawed', label(battle, side))
    } else {
      say(events, 'isFrozen', label(battle, side))
      return
    }
  }
  if (mon.status === 'slp') {
    mon.sleep -= 1
    if (mon.sleep > 0) {
      say(events, 'asleep', label(battle, side))
      return
    }
    mon.status = ''
    events.push({ t: 'status', side, status: '' })
    say(events, 'woke', label(battle, side))
  }
  if (mon.flinch) {
    say(events, 'flinched', label(battle, side))
    return
  }
  if (mon.status === 'par' && battle.random() < 0.25) {
    say(events, 'fullPara', label(battle, side))
    return
  }
  const move = moveIndex < 0 ? STRUGGLE : mon.moves[moveIndex]
  if (moveIndex >= 0) move.pp -= 1
  // Z-Move e Max Move: outro nome, poder da tabela, nunca erram, sem efeitos extras.
  const special = move.category !== 'status' && moveIndex >= 0 && (zMove || mon.dmax > 0)
  if (zMove) say(events, 'zPower', label(battle, side))
  const name = !special ? move.name : zMove ? Z_MOVES[move.type] : MAX_MOVES[move.type]
  say(events, 'used', label(battle, side), name)
  const accuracy = accuracyOf(battle, move)
  if (!special && accuracy != null && battle.random() * 100 >= accuracy) {
    events.push({ t: 'miss', side })
    say(events, 'missed', label(battle, side))
    return
  }
  events.push({ t: 'attack', side, type: move.type, category: move.category, slug: move.slug })
  if (move.category === 'status') {
    statusMove(battle, side, move, events)
    faints(battle, events, foeSide)
    return
  }
  const rules = special ? {} : (move.rules ?? {})
  const crit = battle.random() < CRIT_CHANCE[Math.min(3, rules.c ?? 0)]
  const power = special ? (zMove ? zPower(move.power) : maxPower(move.power, move.type)) : undefined
  const r = hit(mon, target, move.slug, crit, power, battle.weather)
  if (!r || r.eff === 0) {
    say(events, 'noEffect', label(battle, foeSide))
    return
  }
  let damage = 0
  for (const rolls of r.rolls) damage += rolls[Math.floor(battle.random() * rolls.length)]
  damage = Math.max(0, Math.min(damage, target.hp))
  target.hp -= damage
  events.push({ t: 'hp', side: foeSide, hp: target.hp })
  if (r.rolls.length > 1) say(events, 'hits', r.rolls.length)
  if (crit && damage > 0) say(events, 'crit')
  if (r.eff > 1) say(events, 'super')
  else if (r.eff < 1) say(events, 'weak')
  // Recuo (Struggle: 1/4 da vida máxima) e dreno.
  const recoil = move.slug === 'struggle' ? Math.max(1, Math.floor(mon.maxHp / 4)) : rules.r && damage > 0 ? Math.max(1, Math.floor((damage * rules.r[0]) / rules.r[1])) : 0
  if (recoil) {
    mon.hp = Math.max(0, mon.hp - recoil)
    events.push({ t: 'hp', side, hp: mon.hp })
    say(events, 'recoil', label(battle, side))
  }
  if (rules.d && damage > 0 && mon.hp > 0 && mon.hp < mon.maxHp) {
    mon.hp = Math.min(mon.maxHp, mon.hp + Math.max(1, Math.floor((damage * rules.d[0]) / rules.d[1])))
    events.push({ t: 'hp', side, hp: mon.hp })
    say(events, 'drained', label(battle, foeSide))
  }
  // Efeitos secundários (cada um com a sua chance) e mudanças em quem usou.
  if (damage > 0) {
    for (const e of rules.x ?? []) {
      if (battle.random() * 100 >= e.p) continue
      if (e.s && target.hp > 0) inflict(battle, foeSide, e.s, move, events, false)
      if (e.b && target.hp > 0) boost(battle, foeSide, e.b, events)
      if (e.f && target.hp > 0 && !target.dmax) target.flinch = true
      if (e.sb && mon.hp > 0) boost(battle, side, e.sb, events)
    }
    if (rules.sb && mon.hp > 0) boost(battle, side, rules.sb, events)
  }
  // Max Geyser, Max Flare, Max Rockfall e Max Hailstorm mudam o clima.
  if (special && !zMove && MAX_WEATHER[move.type]) setWeather(battle, MAX_WEATHER[move.type], events)
  faints(battle, events, foeSide)
}

function applyItem(battle, side, slug, index, events) {
  if (!canUseItem(battle, side, slug, index)) return
  const item = itemOf(slug)
  const mon = battle.sides[side].team[index]
  battle.bags[side][slug] -= 1
  say(events, 'usedItem', { side, name: mon.name }, item.name)
  if (item.revive) {
    mon.hp = Math.max(1, Math.floor(mon.maxHp / 2))
    mon.faintShown = false
    events.push({ t: 'heal', side, index, hp: mon.hp })
    say(events, 'revived', { side, name: mon.name })
  } else {
    const healed = Math.min(item.heal, mon.maxHp - mon.hp)
    mon.hp += healed
    events.push({ t: 'heal', side, index, hp: mon.hp })
    say(events, 'healed', { side, name: mon.name }, healed)
  }
}

/** O computador cura o Pokémon dele quando está com pouca vida (às vezes). */
function bestDamage(battle, hit, att, def) {
  return Math.max(0, ...usableMoves(att).map((i) => {
    const move = att.moves[i]
    if (move.category === 'status') return 0
    const result = hit(att, def, move.slug, false, undefined, battle.weather)
    if (!result || !result.eff) return 0
    return result.rolls.reduce((sum, rolls) => sum + rolls.reduce((a, b) => a + b, 0) / rolls.length, 0) * (move.accuracy == null ? 1 : move.accuracy / 100)
  }))
}

function matchupScore(battle, hit, mon, foe) {
  const outgoing = bestDamage(battle, hit, mon, foe) / Math.max(1, foe.hp)
  const incoming = bestDamage(battle, hit, foe, mon) / Math.max(1, mon.hp)
  return outgoing - incoming
}

/** Decide sem olhar a ação do jogador: golpe, troca ou item. */
export function cpuPlan(battle, hit) {
  // Fácil: um golpe qualquer na maioria das vezes; nunca troca nem usa a Bolsa (igual ao app).
  if (battle.ai === 'easy') {
    const usable = usableMoves(active(battle, 1))
    if (!usable.length) return { kind: 'move', index: -1 }
    if (battle.random() < 0.6) return { kind: 'move', index: usable[Math.floor(battle.random() * usable.length)] }
    return { kind: 'move', index: cpuMove(battle, hit) }
  }
  const me = active(battle, 1), foe = active(battle, 0)
  const index = cpuMove(battle, hit)
  const outgoing = bestDamage(battle, hit, me, foe)
  const incoming = bestDamage(battle, hit, foe, me)
  const canFinish = outgoing >= foe.hp && (speedOf(me, battle.weather) >= speedOf(foe, battle.weather) || (index >= 0 && me.moves[index].priority > 0)) && !['slp', 'frz'].includes(me.status)
  if (!canFinish && !me.dmax && !me.trapped && !battle.simulator?.state.sides[1].request?.maybeTrapped && battle.turn - battle.cpuSwitchTurn >= 2) {
    let best = battle.sides[1].active
    const currentScore = matchupScore(battle, hit, me, foe)
    let score = currentScore
    battle.sides[1].team.forEach((mon, i) => {
      if ((battle.simulator ? !battle.simulator.state.sides[1].switchOptions.includes(i) : i === battle.sides[1].active) || mon.hp <= 0 || bestDamage(battle, hit, foe, mon) >= mon.hp) return
      const value = matchupScore(battle, hit, mon, foe)
      if (value > score) { best = i; score = value }
    })
    if (best !== battle.sides[1].active && score > currentScore + 0.35 && (incoming >= me.maxHp / 3 || outgoing === 0)) return { kind: 'switch', index: best }
  }
  if (!canFinish) {
    const missing = me.maxHp - me.hp
    const potions = ITEMS.filter((item) => item.heal && battle.bags[1][item.slug] > 0)
    const potion = potions.find((item) => item.heal >= missing) ?? potions.at(-1)
    // Bolsa como um treinador: poção só para não desmaiar agora (HP baixo e a
    // poção salva); Revive só se quem está em campo não consegue causar dano.
    // Cada item é um turno sem atacar.
    if (potion && me.hp <= me.maxHp / 3 && incoming >= me.hp && me.hp + Math.min(missing, potion.heal) > incoming) {
      return { kind: 'item', item: potion.slug, target: battle.sides[1].active }
    }
    if (outgoing === 0 && incoming < me.hp && battle.bags[1].revive > 0 && battle.sides[1].team.filter((mon) => mon.hp > 0).length < battle.sides[1].team.length) {
      let target = -1, score = -Infinity
      battle.sides[1].team.forEach((mon, i) => {
        if (mon.hp > 0) return
        const value = bestDamage(battle, hit, mon, foe) / Math.max(1, foe.hp)
        if (value > score) { target = i; score = value }
      })
      if (target >= 0) return { kind: 'item', item: 'revive', target }
    }
  }
  return { kind: 'move', index }
}

function switchTo(battle, side, index, events) {
  const before = active(battle, side)
  if (before.hp > 0) say(events, side === 0 ? 'comeBack' : 'foeWithdrew', label(battle, side))
  endDmax(battle, side, events, true)
  // Quem sai perde as mudanças de atributo (e o veneno grave recomeça).
  before.boosts = { atk: 0, def: 0, spa: 0, spd: 0, spe: 0 }
  before.flinch = false
  if (before.toxic) before.toxic = 1
  battle.sides[side].active = index
  events.push({ t: 'switch', side, index })
  say(events, side === 0 ? 'go' : 'foeSent', label(battle, side))
  weatherAbility(battle, side, events)
}

function checkEnd(battle, hit, events) {
  if (!alive(battle, 1)) {
    battle.winner = 0
    say(events, 'win')
    return
  }
  if (!alive(battle, 0)) {
    battle.winner = 1
    say(events, 'lose')
    return
  }
  if (active(battle, 1).hp <= 0) switchTo(battle, 1, cpuReplacement(battle, hit), events)
  if (active(battle, 0).hp <= 0) battle.needSwitch = true
}

/**
 * Um turno. action: {move: índice (-1 = Struggle), gimmick?: 'mega' | 'z' |
 * 'dmax' | 'tera' (sem: a do set do Pokémon)}, {switch: índice} ou
 * {item: slug, target: índice no time}.
 * Trocas e itens vêm antes dos golpes.
 * Devolve os eventos para mostrar na tela.
 */
/**
 * Para o replay e o histórico (lib/battleLog.js): cada jogada sua e quem
 * derrubou quem. Com a semente e os times, a batalha inteira se repete igual.
 */
function logTurn(battle, action, events) {
  ;(battle.actions ??= []).push(action)
  for (const e of events) {
    if (e.t !== 'faint' || e.side !== 1) continue
    const i = battle.sides[0].active
    battle.kos = { ...battle.kos, [i]: (battle.kos?.[i] ?? 0) + 1 }
  }
  return events
}

export function playTurn(battle, action, hit) {
  return logTurn(battle, action, turnOf(battle, action, hit))
}

function turnOf(battle, action, hit) {
  if (battle.simulator) {
    battle.lastHit = hit
    const plan = cpuPlan(battle, hit)
    const mine = action.switch != null ? {kind: 'switch', index: action.switch} : action.item != null ? {kind: 'item', item: action.item, index: action.target} : {kind: 'move', index: action.move, gimmick: action.gimmick}
    const theirs = battle.simulator.state.sides[1].wait ? {kind: 'wait'} : plan.kind === 'item' ? {kind: 'item', item: plan.item, index: plan.target} : plan.kind === 'switch' ? plan : {kind: 'move', index: plan.index, gimmick: cpuGimmick(battle, plan.index)}
    let events
    try {
      events = simulatorTurn(battle, [mine, theirs])
    } catch (error) {
      // O motor recusou a jogada do computador (ex.: golpe bloqueado por
      // Encore/Taunt/Choice): ele joga a que o próprio motor recomenda, em vez
      // de o turno travar.
      if (theirs.kind === 'wait') throw error
      events = simulatorTurn(battle, [mine, simulatorRecommend(battle, 1)[0]])
    }
    completeCpuSwitches(battle, hit, events)
    noteCpuEntry(battle, events)
    return [...turnOrder(events), ...events]
  }
  const events = []
  if (battle.winner != null || battle.needSwitch) return events
  const plan = cpuPlan(battle, hit)
  const cpu = plan.kind === 'move' ? plan.index : null
  const cpuG = cpu != null && cpu >= 0 ? cpuGimmick(battle, cpu) : null
  // A sua: a do set do Pokémon (escolhida no montador), no primeiro ataque dele.
  const wanted = action.gimmick ?? active(battle, 0).gimmick
  const myG = action.move != null && wanted && canGimmick(battle, 0, wanted, action.move) ? wanted : null
  if (action.switch != null) switchTo(battle, 0, action.switch, events)
  if (action.item != null) applyItem(battle, 0, action.item, action.target, events)
  if (plan.kind === 'item') applyItem(battle, 1, plan.item, plan.target, events)
  if (plan.kind === 'switch') { switchTo(battle, 1, plan.index, events); battle.cpuSwitchTurn = battle.turn }
  // Mega, Terastal e Dinamax antes dos golpes (a Mega já vale para a ordem).
  const zMove = [false, false]
  for (const [side, g] of [[0, myG], [1, cpuG]]) {
    if (g === 'z') {
      battle.gimmicks[side] = 'z'; battle.usedGimmicks[side].push('z')
      zMove[side] = true
    } else if (g) applyGimmick(battle, side, g, events)
  }
  const order = []
  if (cpu != null) order.push({ side: 1, move: cpu })
  if (action.move != null) order.push({ side: 0, move: action.move })
  const priority = (o) => (o.move < 0 ? 0 : active(battle, o.side).moves[o.move].priority)
  if (order.length === 2) {
    const [a, b] = order
    const pa = priority(a)
    const pb = priority(b)
    const sa = speedOf(active(battle, a.side), battle.weather)
    const sb = speedOf(active(battle, b.side), battle.weather)
    const tie = battle.random() < 0.5
    const bFirst = pb > pa || (pb === pa && (sb > sa || (sb === sa && tie)))
    if (bFirst) order.reverse()
  }
  for (const o of order) {
    if (active(battle, o.side).hp <= 0 || active(battle, 1 - o.side).hp <= 0) continue
    doMove(battle, o.side, o.move, hit, events, zMove[o.side])
  }
  endOfTurn(battle, events)
  checkEnd(battle, hit, events)
  battle.turn += 1
  return events
}

/** O computador não troca quem acabou de entrar (troca, substituição ou U-turn). */
function noteCpuEntry(battle, events) {
  if (events.some((e) => e.t === 'switch' && e.side === 1)) battle.cpuSwitchTurn = battle.turn
}

/**
 * A fila do turno: quem agiu e em que ordem (pela velocidade e prioridade de
 * verdade, tirada do que o motor executou), mostrada antes das ações.
 * 🔵 = seu, 🔴 = do adversário.
 */
export function turnOrder(events) {
  const queue = []
  let moved = false
  for (const e of events) {
    if (e.t !== 'text') continue
    const who = e.args[0]?.side ? '🔴' : '🔵'
    if (e.key === 'used') { queue.push(`${who} ${e.args[0].name} (${e.args[1]})`); moved = true }
    // Trocas e itens escolhidos vêm antes dos golpes (as trocas depois são substituições).
    else if (!moved && (e.key === 'go' || e.key === 'foeSent')) queue.push(`${who} ⇄ ${e.args[0].name}`)
    else if (!moved && e.key === 'usedItem') queue.push(`${who} ${e.args[1]}`)
  }
  return queue.length > 1 ? [{ t: 'text', key: 'turnOrder', args: [queue.join(' → ')] }] : []
}

function completeCpuSwitches(battle, hit, events) {
  let attempts = 0
  while (battle.winner == null && battle.simulator.state.sides[1].forceSwitch) {
    if (++attempts > 12) throw new Error('Não foi possível resolver a substituição')
    if (battle.simulator.state.sides[0].forceSwitch) break
    const index = cpuReplacement(battle, hit)
    events.push(...simulatorTurn(battle, [{kind: 'wait'}, {kind: 'switch', index}]))
  }
}

/**
 * Começo da batalha: as habilidades de clima de quem entrou (o mais rápido
 * primeiro; o clima do mais lento fica). Devolve os eventos para mostrar.
 */
/** Turno entre dois jogadores. A ordem dos lados nunca muda entre aparelhos. */
export function playOnlineTurn(battle, actions, hit) {
  if (battle.simulator) return simulatorTurn(battle, actions)
  const events = []
  if (battle.winner != null) return events
  if (actions.some((a) => a.kind === 'forfeit')) {
    battle.winner = actions[0].kind === 'forfeit' ? 1 : 0
    return events
  }
  const replacing = [0, 1].some((side) => active(battle, side).hp <= 0)
  if (replacing) {
    for (const side of [0, 1]) {
      if (active(battle, side).hp <= 0) {
        const index = actions[side].index
        if (actions[side].kind !== 'switch' || !battle.sides[side].team[index] || battle.sides[side].team[index].hp <= 0) throw new Error('Troca inválida')
        switchTo(battle, side, index, events)
      }
    }
    return events
  }
  const order = []
  const zMove = [false, false]
  for (const side of [0, 1]) {
    const action = actions[side]
    const mon = active(battle, side)
    if (action.kind === 'switch') {
      if (action.index === battle.sides[side].active || !battle.sides[side].team[action.index] || battle.sides[side].team[action.index].hp <= 0) throw new Error('Troca inválida')
      switchTo(battle, side, action.index, events)
    } else if (action.kind === 'move') {
      const i = action.index
      if (!(i === -1 ? usableMoves(mon).length === 0 : mon.moves[i]?.pp > 0)) throw new Error('Golpe inválido')
      const g = action.gimmick || mon.gimmick
      if (g && canGimmick(battle, side, g, i)) {
        if (g === 'z') { battle.gimmicks[side] = 'z'; battle.usedGimmicks[side].push('z'); zMove[side] = true }
        else applyGimmick(battle, side, g, events)
      }
      order.push({ side, move: i })
    } else throw new Error('Ação inválida')
  }
  if (order.length === 2) {
    const [a, b] = order
    const pa = a.move < 0 ? 0 : active(battle, a.side).moves[a.move].priority
    const pb = b.move < 0 ? 0 : active(battle, b.side).moves[b.move].priority
    const sa = speedOf(active(battle, a.side), battle.weather), sb = speedOf(active(battle, b.side), battle.weather)
    const tie = battle.random() < 0.5
    if (pb > pa || (pb === pa && (sb > sa || (sb === sa && tie)))) order.reverse()
  }
  for (const o of order) {
    if (active(battle, o.side).hp > 0 && active(battle, 1 - o.side).hp > 0) doMove(battle, o.side, o.move, hit, events, zMove[o.side])
  }
  endOfTurn(battle, events)
  if (!alive(battle, 1)) battle.winner = 0
  else if (!alive(battle, 0)) battle.winner = 1
  battle.turn += 1
  return events
}

export function startBattle(battle) {
  if (battle.simulator) return battle.simulator.opening.splice(0)
  const events = []
  const sides = speedOf(active(battle, 1)) > speedOf(active(battle, 0)) ? [1, 0] : [0, 1]
  for (const side of sides) weatherAbility(battle, side, events)
  return events
}

/** Seu Pokémon desmaiou: manda outro (não gasta turno). */
export function replace(battle, index) {
  return logTurn(battle, { replace: index }, replaceOf(battle, index))
}

function replaceOf(battle, index) {
  if (battle.simulator) {
    const cpu = battle.forceSwitch[1] ? {kind: 'switch', index: cpuReplacement(battle, battle.lastHit)} : {kind: 'wait'}
    const events = simulatorTurn(battle, [{kind: 'switch', index}, cpu])
    completeCpuSwitches(battle, battle.lastHit, events)
    noteCpuEntry(battle, events)
    return events
  }
  const events = []
  if (!battle.needSwitch) return events
  battle.needSwitch = false
  switchTo(battle, 0, index, events)
  return events
}

/** Desistir: o computador ganha. */
export function forfeit(battle) {
  battle.winner = 1
  return [{ t: 'text', key: 'ran', args: [] }]
}

/** Texto das falas (em português; a tela traduz). {0} = Pokémon, {1} = golpe. */
export const LINES = {
  sim: '{0}',
  turnOrder: 'Ordem do turno: {0}',
  draw: 'A batalha terminou empatada!',
  used: ['{0} usou {1}!', '{0} inimigo usou {1}!'],
  missed: ['O ataque de {0} errou!', 'O ataque de {0} inimigo errou!'],
  noEffect: ['Não afeta {0}...', 'Não afeta {0} inimigo...'],
  recoil: ['{0} foi atingido pelo recuo!', '{0} inimigo foi atingido pelo recuo!'],
  fainted: ['{0} desmaiou!', '{0} inimigo desmaiou!'],
  comeBack: ['Volte, {0}!', ''],
  go: ['Vai, {0}!', ''],
  foeWithdrew: ['', 'O adversário chamou {0} de volta!'],
  foeSent: ['', 'O adversário mandou {0}!'],
  hits: 'Acertou {0} vezes!',
  crit: 'Um golpe crítico!',
  super: 'É super eficaz!',
  weak: 'Não é muito eficaz...',
  win: 'Você venceu a batalha!',
  lose: 'Todos os seus Pokémon desmaiaram... Você perdeu!',
  ran: 'Você fugiu da batalha!',
  usedItem: ['Você usou {1} em {0}!', 'O adversário usou {1} em {0}!'],
  healed: ['{0} recuperou {1} de HP!', '{0} inimigo recuperou {1} de HP!'],
  revived: ['{0} voltou à batalha!', '{0} inimigo voltou à batalha!'],
  burned: ['{0} foi queimado!', '{0} inimigo foi queimado!'],
  paralyzed: ['{0} foi paralisado! Talvez não consiga se mover!', '{0} inimigo foi paralisado! Talvez não consiga se mover!'],
  poisoned: ['{0} foi envenenado!', '{0} inimigo foi envenenado!'],
  badlyPoisoned: ['{0} foi gravemente envenenado!', '{0} inimigo foi gravemente envenenado!'],
  fellAsleep: ['{0} adormeceu!', '{0} inimigo adormeceu!'],
  frozen: ['{0} foi congelado!', '{0} inimigo foi congelado!'],
  hurtBurn: ['{0} foi ferido pela queimadura!', '{0} inimigo foi ferido pela queimadura!'],
  hurtPoison: ['{0} foi ferido pelo veneno!', '{0} inimigo foi ferido pelo veneno!'],
  asleep: ['{0} está dormindo profundamente.', '{0} inimigo está dormindo profundamente.'],
  woke: ['{0} acordou!', '{0} inimigo acordou!'],
  isFrozen: ['{0} está congelado!', '{0} inimigo está congelado!'],
  thawed: ['{0} descongelou!', '{0} inimigo descongelou!'],
  fullPara: ['{0} está paralisado! Não consegue se mover!', '{0} inimigo está paralisado! Não consegue se mover!'],
  flinched: ['{0} recuou e não conseguiu atacar!', '{0} inimigo recuou e não conseguiu atacar!'],
  statUp: ['{1} de {0} subiu!', '{1} de {0} inimigo subiu!'],
  statUp2: ['{1} de {0} subiu muito!', '{1} de {0} inimigo subiu muito!'],
  statUp3: ['{1} de {0} subiu drasticamente!', '{1} de {0} inimigo subiu drasticamente!'],
  statDown: ['{1} de {0} caiu!', '{1} de {0} inimigo caiu!'],
  statDown2: ['{1} de {0} caiu muito!', '{1} de {0} inimigo caiu muito!'],
  statDown3: ['{1} de {0} caiu drasticamente!', '{1} de {0} inimigo caiu drasticamente!'],
  statsReset: 'Os atributos de todos voltaram ao normal!',
  statMax: ['{1} de {0} não pode subir mais!', '{1} de {0} inimigo não pode subir mais!'],
  statMin: ['{1} de {0} não pode cair mais!', '{1} de {0} inimigo não pode cair mais!'],
  healedMove: ['{0} recuperou HP!', '{0} inimigo recuperou HP!'],
  drained: ['{0} teve a energia drenada!', '{0} inimigo teve a energia drenada!'],
  failed: ['Mas falhou!', 'Mas falhou!'],
  megaReact: ['A Mega Pedra de {0} está reagindo!', 'A Mega Pedra de {0} inimigo está reagindo!'],
  megaEvolved: ['{0} megaevoluiu em {1}!', '{0} inimigo megaevoluiu em {1}!'],
  terastallized: ['{0} terastalizou no tipo {1}!', '{0} inimigo terastalizou no tipo {1}!'],
  dynamaxed: ['{0} dinamaxizou!', '{0} inimigo dinamaxizou!'],
  gigantamaxed: ['{0} gigantamaxizou!', '{0} inimigo gigantamaxizou!'],
  dmaxEnd: ['{0} voltou ao tamanho normal!', '{0} inimigo voltou ao tamanho normal!'],
  zPower: ['{0} libera todo o seu Z-Poder!', '{0} inimigo libera todo o seu Z-Poder!'],
  rainStart: 'Começou a chover!',
  rainGo: 'A chuva continua.',
  rainEnd: 'A chuva parou.',
  sunStart: 'A luz do sol ficou forte!',
  sunGo: 'A luz do sol está forte.',
  sunEnd: 'A luz do sol voltou ao normal.',
  sandStart: 'Começou uma tempestade de areia!',
  sandGo: 'A tempestade de areia continua.',
  sandEnd: 'A tempestade de areia passou.',
  hailStart: 'Começou a cair granizo!',
  hailGo: 'O granizo continua.',
  hailEnd: 'O granizo parou.',
  snowStart: 'Começou a nevar!',
  snowGo: 'A neve continua.',
  snowEnd: 'A neve parou.',
  hurtSand: ['{0} foi atingido pela tempestade de areia!', '{0} inimigo foi atingido pela tempestade de areia!'],
  hurtHail: ['{0} foi atingido pelo granizo!', '{0} inimigo foi atingido pelo granizo!'],
  // Itens e habilidades (motor do Showdown).
  abilityShow: ['{1} de {0}!', '{1} de {0} inimigo!'],
  itemShow: ['{0} está segurando {1}!', '{0} inimigo está segurando {1}!'],
  gotItem: ['{0} recebeu {1}!', '{0} inimigo recebeu {1}!'],
  balloon: ['{0} está flutuando com o Air Balloon!', '{0} inimigo está flutuando com o Air Balloon!'],
  balloonPop: ['O Air Balloon de {0} estourou!', 'O Air Balloon de {0} inimigo estourou!'],
  ateItem: ['{0} comeu {1}!', '{0} inimigo comeu {1}!'],
  sashHung: ['{0} aguentou firme com o Focus Sash!', '{0} inimigo aguentou firme com o Focus Sash!'],
  lostItem: ['{0} perdeu {1}!', '{0} inimigo perdeu {1}!'],
  itemUsedUp: ['{0} usou {1}!', '{0} inimigo usou {1}!'],
  itemActive: ['{1} de {0} foi ativado!', '{1} de {0} inimigo foi ativado!'],
  hurtBy: ['{0} foi ferido por {1}!', '{0} inimigo foi ferido por {1}!'],
  healedBy: ['{0} recuperou um pouco de HP com {1}!', '{0} inimigo recuperou um pouco de HP com {1}!'],
  hurtRocks: ['Pedras afiadas atingiram {0}!', 'Pedras afiadas atingiram {0} inimigo!'],
  hurtSpikes: ['{0} foi ferido pelos espinhos!', '{0} inimigo foi ferido pelos espinhos!'],
  seedSap: ['A Leech Seed drenou a energia de {0}!', 'A Leech Seed drenou a energia de {0} inimigo!'],
  hurtConfusion: ['{0} se feriu na confusão!', '{0} inimigo se feriu na confusão!'],
  hurtCurse: ['{0} foi afetado pela maldição!', '{0} inimigo foi afetado pela maldição!'],
  statusCured: ['{0} se curou com {1}!', '{0} inimigo se curou com {1}!'],
  mustRecharge: ['{0} precisa recarregar!', '{0} inimigo precisa recarregar!'],
  loafing: ['{0} está fazendo corpo mole!', '{0} inimigo está fazendo corpo mole!'],
  cantMove: ['{0} não conseguiu se mover!', '{0} inimigo não conseguiu se mover!'],
  protected: ['{0} se protegeu!', '{0} inimigo se protegeu!'],
  isConfused: ['{0} está confuso!', '{0} inimigo está confuso!'],
  confused: ['{0} ficou confuso!', '{0} inimigo ficou confuso!'],
  confusionEnd: ['{0} não está mais confuso!', '{0} inimigo não está mais confuso!'],
  gemUsed: ['{1} fortaleceu o golpe de {0}!', '{1} fortaleceu o golpe de {0} inimigo!'],
  paradoxBoost: ['{1} de {0} foi fortalecido!', '{1} de {0} inimigo foi fortalecido!'],
  formChanged: ['{0} mudou para a forma {1}!', '{0} inimigo mudou para a forma {1}!'],
}

/** Evento de texto → [modelo, valores] (o Pokémon vai no lugar de {0}). */
export function lineOf(event) {
  const line = LINES[event.key]
  const [first, ...rest] = event.args
  if (Array.isArray(line)) return [line[first.side], [first.name, ...rest.map((x) => STAT_NAMES[x] ?? x)]]
  return [line, event.args]
}
