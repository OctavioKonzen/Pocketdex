// Batalha por turnos (como nos jogos de GBA), igual ao app
// (lib/services/turn_battle.dart). Motor puro: não sabe calcular dano, recebe
// uma função hit(atacante, defensor, golpe, crítico) → {rolls, eff} que usa a
// calculadora do Showdown (battleSetup.js). Mesma semente e mesmos danos dão
// a mesma batalha no site e no app.
//
// Simplificado: golpes de dano (com precisão, prioridade, crítico, vários
// acertos, PP e Struggle), troca de Pokémon e o adversário controlado pelo
// computador. Sem status, clima, efeitos secundários nem mudança de atributos.
//
// Pokémon: {id, name, level, maxHp, hp, spe, types,
//           moves: [{slug, name, type, category, power, accuracy, pp, maxPp, priority}]}
// Eventos (para a tela ir mostrando): {t: 'text', key, args} | {t: 'hp', side, hp}
//   | {t: 'switch', side, index} | {t: 'faint', side}
//   | {t: 'attack', side, type, category, slug} (animação do golpe) | {t: 'miss', side}
//   | {t: 'heal', side, index, hp} (poção ou Revive num Pokémon do time)
// Lado 0 = você, lado 1 = o computador.

export const STRUGGLE = { slug: 'struggle', name: 'Struggle', type: 'normal', category: 'physical', power: 50, accuracy: null, pp: 1, maxPp: 1, priority: 0 }
const CRIT_CHANCE = 1 / 24

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
    const value = expected(hit, me, foe, me.moves[i])
    if (value > bestValue) {
      best = i
      bestValue = value
    }
  }
  return best
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
  const move = moveIndex < 0 ? STRUGGLE : mon.moves[moveIndex]
  if (moveIndex >= 0) move.pp -= 1
  say(events, 'used', label(battle, side), move.name)
  if (move.accuracy != null && battle.random() * 100 >= move.accuracy) {
    events.push({ t: 'miss', side })
    say(events, 'missed', label(battle, side))
    return
  }
  events.push({ t: 'attack', side, type: move.type, category: move.category, slug: move.slug })
  const crit = battle.random() < CRIT_CHANCE
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
  if (move.slug === 'struggle') {
    mon.hp = Math.max(0, mon.hp - Math.max(1, Math.floor(mon.maxHp / 4)))
    events.push({ t: 'hp', side, hp: mon.hp })
    say(events, 'recoil', label(battle, side))
  }
  for (const s of [foeSide, side]) {
    const m = active(battle, s)
    if (m.hp <= 0 && !m.faintShown) {
      m.faintShown = true
      events.push({ t: 'faint', side: s })
      say(events, 'fainted', label(battle, s))
    }
  }
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
    const sa = active(battle, a.side).spe
    const sb = active(battle, b.side).spe
    const tie = battle.random() < 0.5
    const bFirst = pb > pa || (pb === pa && (sb > sa || (sb === sa && tie)))
    if (bFirst) order.reverse()
  }
  for (const o of order) {
    if (active(battle, o.side).hp <= 0 || active(battle, 1 - o.side).hp <= 0) continue
    doMove(battle, o.side, o.move, hit, events)
  }
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
}

/** Evento de texto → [modelo, valores] (o Pokémon vai no lugar de {0}). */
export function lineOf(event) {
  const line = LINES[event.key]
  const [first, ...rest] = event.args
  if (Array.isArray(line)) return [line[first.side], [first.name, ...rest]]
  return [line, event.args]
}
