// Batalha por turnos (como nos jogos de GBA), igual ao app
// (lib/services/turn_battle.dart). Motor puro: não sabe calcular dano, recebe
// uma função hit(atacante, defensor, golpe, crítico) → {rolls, eff} que usa a
// calculadora do Showdown (battleSetup.js). Mesma semente e mesmos danos dão
// a mesma batalha no site e no app.
//
// Regras dos golpes do Pokémon Showdown (move_rules.json, tool/build_move_rules.mjs):
// precisão, prioridade, crítico (e golpes com mais chance de crítico), vários
// acertos, PP, Struggle, recuo, dreno, cura, status (queimadura, paralisia,
// veneno, veneno grave, sono e congelamento), mudanças de atributo (−6 a +6),
// efeitos secundários (com a chance de cada um) e recuar. Mais troca de
// Pokémon, Bolsa e o adversário controlado pelo computador. Sem clima,
// campo nem golpes que mexem no campo (Stealth Rock, Protect...).
//
// Pokémon: {id, name, level, maxHp, hp, spe, types,
//           moves: [{slug, name, type, category, power, accuracy, pp, maxPp, priority, rules?}],
//           status, sleep, toxic, boosts: {atk, def, spa, spd, spe}, flinch}
// Eventos (para a tela ir mostrando): {t: 'text', key, args} | {t: 'hp', side, hp}
//   | {t: 'switch', side, index} | {t: 'faint', side}
//   | {t: 'attack', side, type, category, slug} (animação do golpe) | {t: 'miss', side}
//   | {t: 'heal', side, index, hp} (poção ou Revive num Pokémon do time)
//   | {t: 'status', side, status} (status novo; '' = curou)
// Lado 0 = você, lado 1 = o computador.

export const STRUGGLE = { slug: 'struggle', name: 'Struggle', type: 'normal', category: 'physical', power: 50, accuracy: null, pp: 1, maxPp: 1, priority: 0 }
/** Chance de crítico por estágio (geração 7 em diante). */
const CRIT_CHANCE = [1 / 24, 1 / 8, 1 / 2, 1]
export const STATS = ['atk', 'def', 'spa', 'spd', 'spe']
/** Nome dos atributos nas falas (em português; a tela traduz). */
export const STAT_NAMES = { atk: 'Ataque', def: 'Defesa', spa: 'Ataque Especial', spd: 'Defesa Especial', spe: 'Velocidade' }
/** Tipos imunes a cada status. */
const STATUS_IMMUNE = { brn: ['fire'], par: ['electric'], psn: ['poison', 'steel'], tox: ['poison', 'steel'], frz: ['ice'], slp: [] }

/** Começa (ou recomeça) o estado de batalha de um Pokémon. */
function resetMon(mon) {
  mon.status = ''
  mon.sleep = 0
  mon.toxic = 0
  mon.flinch = false
  mon.boosts = { atk: 0, def: 0, spa: 0, spd: 0, spe: 0 }
}

/** Multiplicador de um estágio de atributo (−6 a +6). */
const stageMult = (s) => (s >= 0 ? (2 + s) / 2 : 2 / (2 - s))
/** Velocidade na hora da ordem: estágio e paralisia (metade). */
export const speedOf = (mon) => {
  const spe = Math.floor(mon.spe * stageMult(mon.boosts?.spe ?? 0))
  return mon.status === 'par' ? Math.floor(spe / 2) : spe
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
export function newBattle(mine, theirs, random) {
  for (const mon of [...mine, ...theirs]) resetMon(mon)
  return {
    sides: [
      { team: mine, active: 0 },
      { team: theirs, active: 0 },
    ],
    random,
    bags: [newBag(), newBag()],
    turn: 1,
    winner: null, // 0 = você ganhou, 1 = o computador
    needSwitch: false, // seu Pokémon desmaiou: escolha outro
  }
}

export const active = (battle, side) => battle.sides[side].team[battle.sides[side].active]
const alive = (battle, side) => battle.sides[side].team.filter((p) => p.hp > 0).length
const say = (events, key, ...args) => events.push({ t: 'text', key, args })
/** Nome como aparece nas falas: o do computador é "X inimigo". */
const label = (battle, side) => ({ side, name: active(battle, side).name })

/** Golpes que dá para usar; sem PP em nenhum, só Struggle. */
export const usableMoves = (mon) => mon.moves.map((m, i) => (m.pp > 0 ? i : -1)).filter((i) => i >= 0)

/** Dano médio esperado (sem crítico), para a escolha do computador. */
function expected(hit, att, def, move) {
  if (move.category === 'status') return 0
  const r = hit(att, def, move.slug, false)
  if (!r || !r.eff) return 0
  const avg = r.rolls.reduce((sum, rolls) => sum + rolls.reduce((a, b) => a + b, 0) / rolls.length, 0)
  return Math.min(avg, def.hp) * (move.accuracy == null ? 1 : move.accuracy / 100)
}

/** Escolha do computador: o golpe com mais dano esperado (às vezes outro qualquer). */
export function cpuMove(battle, hit) {
  const me = active(battle, 1)
  const foe = active(battle, 0)
  const usable = usableMoves(me)
  if (!usable.length) return -1
  if (battle.random() < 0.15) return usable[Math.floor(battle.random() * usable.length)]
  let best = usable[0]
  let bestValue = -1
  for (const i of usable) {
    const move = me.moves[i]
    const value = move.category === 'status' ? statusValue(me, foe, move) : expected(hit, me, foe, move)
    if (value > bestValue) {
      best = i
      bestValue = value
    }
  }
  return best
}

/** Quanto vale um golpe de status para o computador (comparado com dano). */
function statusValue(me, foe, move) {
  const r = move.rules ?? {}
  if (r.h) return me.hp * 2 < me.maxHp ? Math.floor((me.maxHp * r.h[0]) / r.h[1]) : 0
  if (r.s) return !foe.status && !immuneTo(foe, r.s, move) ? Math.floor(foe.maxHp * (r.s === 'slp' ? 0.5 : 0.3)) : 0
  if (r.b && r.t === 'self') {
    const room = Object.entries(r.b).some(([k, v]) => v > 0 && me.boosts[k] < 2)
    return room && me.hp * 10 >= me.maxHp * 6 ? Math.floor(me.maxHp * 0.25) : 0
  }
  if (r.b) return Math.floor(foe.maxHp * 0.1)
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
  if (r.h) {
    if (mon.hp >= mon.maxHp) say(events, 'failed', label(battle, side))
    else {
      mon.hp = Math.min(mon.maxHp, mon.hp + Math.floor((mon.maxHp * r.h[0]) / r.h[1]))
      events.push({ t: 'hp', side, hp: mon.hp })
      say(events, 'healedMove', label(battle, side))
    }
  }
  if (r.s) inflict(battle, 1 - side, r.s, move, events, true)
  if (r.b) boost(battle, r.t === 'self' ? side : 1 - side, r.b, events)
  if (!r.h && !r.s && !r.b) say(events, 'failed', label(battle, side))
}

/** Quem ficou sem vida desmaia ([first] primeiro: o alvo do golpe). */
function faints(battle, events, first = 1) {
  for (const s of [first, 1 - first]) {
    const m = active(battle, s)
    if (m.hp <= 0 && !m.faintShown) {
      m.faintShown = true
      events.push({ t: 'faint', side: s })
      say(events, 'fainted', label(battle, s))
    }
  }
}

/** Fim do turno: queimadura e veneno tiram vida; quem recuou volta ao normal. */
function endOfTurn(battle, events) {
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
  for (const s of [0, 1]) for (const mon of battle.sides[s].team) mon.flinch = false
}

/** Quem o computador manda quando o dele desmaia: o que mais machuca o seu. */
function cpuReplacement(battle, hit) {
  const foe = active(battle, 0)
  let best = -1
  let bestValue = -1
  battle.sides[1].team.forEach((mon, i) => {
    if (mon.hp <= 0) return
    const value = Math.max(0, ...usableMoves(mon).map((m) => expected(hit, mon, foe, mon.moves[m])))
    if (value > bestValue) {
      best = i
      bestValue = value
    }
  })
  return best
}

function doMove(battle, side, moveIndex, hit, events) {
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
  say(events, 'used', label(battle, side), move.name)
  if (move.accuracy != null && battle.random() * 100 >= move.accuracy) {
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
  const rules = move.rules ?? {}
  const crit = battle.random() < CRIT_CHANCE[Math.min(3, rules.c ?? 0)]
  const r = hit(mon, target, move.slug, crit)
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
      if (e.f && target.hp > 0) target.flinch = true
      if (e.sb && mon.hp > 0) boost(battle, side, e.sb, events)
    }
    if (rules.sb && mon.hp > 0) boost(battle, side, rules.sb, events)
  }
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
function cpuItem(battle) {
  const me = active(battle, 1)
  if (me.hp * 4 > me.maxHp) return null
  const potion = [...ITEMS].reverse().find((i) => i.heal && battle.bags[1][i.slug] > 0)
  if (!potion || battle.random() >= 0.5) return null
  return potion.slug
}

function switchTo(battle, side, index, events) {
  const before = active(battle, side)
  if (before.hp > 0) say(events, side === 0 ? 'comeBack' : 'foeWithdrew', label(battle, side))
  // Quem sai perde as mudanças de atributo (e o veneno grave recomeça).
  before.boosts = { atk: 0, def: 0, spa: 0, spd: 0, spe: 0 }
  before.flinch = false
  if (before.toxic) before.toxic = 1
  battle.sides[side].active = index
  events.push({ t: 'switch', side, index })
  say(events, side === 0 ? 'go' : 'foeSent', label(battle, side))
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
 * Um turno. action: {move: índice (-1 = Struggle)}, {switch: índice} ou
 * {item: slug, target: índice no time}. Trocas e itens vêm antes dos golpes.
 * Devolve os eventos para mostrar na tela.
 */
export function playTurn(battle, action, hit) {
  const events = []
  if (battle.winner != null || battle.needSwitch) return events
  const cpuPotion = cpuItem(battle)
  const cpu = cpuPotion ? null : cpuMove(battle, hit)
  if (action.switch != null) switchTo(battle, 0, action.switch, events)
  if (action.item != null) applyItem(battle, 0, action.item, action.target, events)
  if (cpuPotion) applyItem(battle, 1, cpuPotion, battle.sides[1].active, events)
  const order = []
  if (!cpuPotion) order.push({ side: 1, move: cpu })
  if (action.move != null) order.push({ side: 0, move: action.move })
  const priority = (o) => (o.move < 0 ? 0 : active(battle, o.side).moves[o.move].priority)
  if (order.length === 2) {
    const [a, b] = order
    const pa = priority(a)
    const pb = priority(b)
    const sa = speedOf(active(battle, a.side))
    const sb = speedOf(active(battle, b.side))
    const tie = battle.random() < 0.5
    const bFirst = pb > pa || (pb === pa && (sb > sa || (sb === sa && tie)))
    if (bFirst) order.reverse()
  }
  for (const o of order) {
    if (active(battle, o.side).hp <= 0 || active(battle, 1 - o.side).hp <= 0) continue
    doMove(battle, o.side, o.move, hit, events)
  }
  endOfTurn(battle, events)
  checkEnd(battle, hit, events)
  battle.turn += 1
  return events
}

/** Seu Pokémon desmaiou: manda outro (não gasta turno). */
export function replace(battle, index) {
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
  statMax: ['{1} de {0} não pode subir mais!', '{1} de {0} inimigo não pode subir mais!'],
  statMin: ['{1} de {0} não pode cair mais!', '{1} de {0} inimigo não pode cair mais!'],
  healedMove: ['{0} recuperou HP!', '{0} inimigo recuperou HP!'],
  drained: ['{0} teve a energia drenada!', '{0} inimigo teve a energia drenada!'],
  failed: ['Mas falhou!', 'Mas falhou!'],
}

/** Evento de texto → [modelo, valores] (o Pokémon vai no lugar de {0}). */
export function lineOf(event) {
  const line = LINES[event.key]
  const [first, ...rest] = event.args
  if (Array.isArray(line)) return [line[first.side], [first.name, ...rest.map((x) => STAT_NAMES[x] ?? x)]]
  return [line, event.args]
}
