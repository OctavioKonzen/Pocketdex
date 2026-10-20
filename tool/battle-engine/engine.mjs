// Shared offline simulator. Keep the Showdown callbacks intact: move effects
// cannot be faithfully represented by power and a short list of flags.
import {Battle, Dex, extractChannelMessages} from '@pkmn/sim';

// Aura Guard is newer than this pinned simulator. Its contact rule comes from
// the PokeAPI ability record shipped in assets/database/abilities.json.
for (const dex of [Dex, Dex.mod('gen9')]) {
  dex.data.Abilities.auraguard = {
    name: 'Aura Guard', num: 314, rating: 3.5, flags: {breakable: 1},
    onSourceModifyDamage(damage, source, target, move) {
      if (move.flags.contact) return this.chainModify(0.5);
    },
  };
}

const id = value => String(value ?? '').toLowerCase().replace(/--(physical|special)$/, '').replace(/[^a-z0-9]/g, '');
const title = value => String(value ?? '').replace(/(^|[- ])([a-z])/g, (_, space, letter) => space + letter.toUpperCase());
function speciesFor(value) {
  const original = Dex.species.get(value);
  if (original.exists) return original;
  const slug = String(value).toLowerCase();
  const aliases = {
    'raticate-totem-alola': 'Raticate-Alola-Totem', 'marowak-totem': 'Marowak-Alola-Totem',
    'zygarde-10-power-construct': 'Zygarde-10%', 'zygarde-50-power-construct': 'Zygarde',
    'mimikyu-totem-disguised': 'Mimikyu-Totem', 'mimikyu-totem-busted': 'Mimikyu-Busted-Totem',
    'rockruff-own-tempo': 'Rockruff-Dusk', 'darmanitan-galar-standard': 'Darmanitan-Galar',
    'maushold-family-of-three': 'Maushold', 'maushold-family-of-four': 'Maushold-Four',
    'tauros-paldea-combat-breed': 'Tauros-Paldea-Combat', 'tauros-paldea-blaze-breed': 'Tauros-Paldea-Blaze',
    'tauros-paldea-aqua-breed': 'Tauros-Paldea-Aqua', 'meowstic-male-mega': 'Meowstic-Mega',
  };
  let name = aliases[slug] || slug.replace(/-male$/, '').replace(/-female$/, '-f').replace(/-cap$/, '').replace(/-plumage$/, '');
  if (/^minior-.*-meteor$/.test(slug)) name = 'Minior-Meteor';
  if (/^(koraidon|miraidon)-/.test(slug)) name = slug.split('-')[0];
  if (name === 'squawkabilly-green') name = 'Squawkabilly';
  return Dex.species.get(name);
}
const formats = {...Dex.formats.get('gen9customgame'), id: 'pocketdex', name: 'PocketDex', mod: 'gen9', gameType: 'singles', ruleset: [], banlist: [], unbanlist: [], restricted: []};
const games = new Map();
let nextHandle = 1;

function originalIndex(pokemon) { return Number(pokemon.set.name.slice(2)); }
// Espécie do Showdown → id do Pokémon no banco (vem do build.mjs). Nos testes do motor, vazio.
/* global POCKETDEX_FORMS */
const FORMS = typeof POCKETDEX_FORMS === 'undefined' ? {} : POCKETDEX_FORMS;
// Forma que o motor mudou durante a batalha (Aegislash-Blade, Mimikyu-Busted, Darmanitan-Zen,
// Palafin-Hero...): o id dela no banco; null enquanto for a forma do começo da batalha.
function formIdOf(game, pokemon) {
  const start = game.startSpecies?.[pokemon.side.n]?.[originalIndex(pokemon)];
  if (!start || pokemon.species.name === start) return null;
  return FORMS[pokemon.species.name.toLowerCase().replace(/[^a-z0-9]/g, '')] ?? null;
}
function targetsFor(game, pokemon, moveId, targetType) {
  const move = Dex.moves.get(moveId);
  const target = targetType || move.target;
  if (!game.battle.actions.targetTypeChoices(target)) return [];
  return game.battle.getAllActive(true).filter(p => game.battle.validTarget(p, pokemon, target)).map(p => ({
    loc: pokemon.getLocOf(p), side: p.side.n, index: originalIndex(p), slot: p.position,
    name: game.teams[p.side.n][originalIndex(p)].name || p.species.name, ally: pokemon.isAlly(p), fainted: p.fainted,
  }));
}
function slotsFor(game, side) {
  return side.active.map((p, slot) => {
    const request = side.activeRequest?.active?.[slot] ?? null;
    const forced = Boolean(side.activeRequest?.forceSwitch?.[slot]);
    const revival = Boolean(p && side.slotConditions[p.position]?.revivalblessing);
    return {slot, controller: game.controllers?.[side.n]?.[slot] || '', index: p ? originalIndex(p) : -1, forceSwitch: forced, revival,
      pass: !p || p.fainted && !forced, trapped: Boolean(request?.trapped), locked: forced ? null : lockedOf(request),
      canShift: game.battle.gameType === 'triples' && slot !== 1 && !forced && !side.activeRequest?.wait && Boolean(p?.hp),
      switchOptions: side.pokemon.filter(mon => revival ? mon.fainted : !mon.fainted && !side.active.includes(mon) && (!request?.trapped || forced)).map(originalIndex),
      request: request ? {...request, moves: request.moves.map(m => ({...m, targets: p.volatiles.dynamax ? targetsFor(game, p, game.battle.actions.getMaxMove(Dex.moves.get(m.id), p)) : targetsFor(game, p, m.id, m.target || 'randomNormal')}))} : null};
  });
}
function setFor(mon, index) {
  const set = mon.set;
  if (!set || !speciesFor(set.species).exists) throw new Error(`Espécie desconhecida: ${set?.species}`);
  for (const move of set.moves) if (!Dex.moves.get(id(move)).exists) throw new Error(`Golpe desconhecido: ${move}`);
  const aspect = id(set.species).includes('cornerstone') ? 'cornerstone' : id(set.species).includes('hearthflame') ? 'hearthflame' : id(set.species).includes('wellspring') ? 'wellspring' : 'teal';
  const ability = id(set.ability) === 'embodyaspect' ? `Embody Aspect (${aspect})` : set.ability;
  return {...set, species: speciesFor(set.species).name, ability, moves: set.moves.map(id), name: `pd${index}`, level: Math.min(mon.levelCap === 'none' ? 9999 : mon.levelCap === 100 ? 100 : 50, Math.max(1, set.level || 50)), gigantamax: Boolean(mon.gmax), teraType: title(mon.teraType || set.teraType || '')};
}

/**
 * Efeitos de lugar da Battle Factory (como a chuva de diamantes do Mt. Moon): no fim de cada turno, ferem (1/16 do HP)
 * quem não é dos tipos imunes ou curam (1/16) quem é dos tipos do lugar.
 */
const PLACE_EFFECTS = {
  diamonds: {name: 'a chuva de diamantes', hurt: true, types: ['Rock', 'Steel', 'Ground']},
  rockfall: {name: 'o desmoronamento', hurt: true, types: ['Rock', 'Ground', 'Steel']},
  ashes: {name: 'as cinzas ardentes', hurt: true, types: ['Fire']},
  miasma: {name: 'a névoa tóxica', hurt: true, types: ['Poison', 'Steel']},
  chill: {name: 'o frio cortante', hurt: true, types: ['Ice']},
  haunt: {name: 'a aura sombria', hurt: false, types: ['Ghost', 'Dark']},
  current: {name: 'a correnteza', hurt: false, types: ['Water']},
  // Os efeitos com chance: esporos (adormece quem não é de Grama), areia movediça (−Velocidade de quem não voa nem é de
  // Terra), tempestade (raio em quem não é Elétrico) e aurora (cura os de Gelo).
  spores: {name: 'os esporos', mode: 'sleep', chance: 8, types: ['Grass']},
  quicksand: {name: 'a areia movediça', mode: 'slow', chance: 3, types: ['Ground', 'Flying']},
  storm: {name: 'a tempestade', hurt: true, chance: 4, power: 8, types: ['Electric', 'Ground']},
  aurora: {name: 'a aurora', hurt: false, types: ['Ice']},
};
const placeEffects = {};
function placeEffect(key, dex) {
  const effect = makePlaceEffect(key);
  // O simulador procura os efeitos do campo pelo id: registra o nosso.
  dex.conditions.conditionCache.set(effect.id, effect);
  return effect;
}
function makePlaceEffect(key) {
  if (placeEffects[key]) return placeEffects[key];
  const def = PLACE_EFFECTS[key];
  const Condition = Dex.conditions.get('gravity').constructor;
  placeEffects[key] = new Condition({
    name: `PocketDex ${key}`, effectType: 'Condition',
    onResidualOrder: 5,
    onResidual(pokemon) {
      if (!pokemon.hp || pokemon.fainted) return;
      const has = pokemon.getTypes().some(t => def.types.includes(t));
      // Os de chance: só às vezes (1 em def.chance), e só em quem não é dos tipos protegidos.
      if (def.chance && (has || !this.randomChance(1, def.chance))) return;
      if (def.mode === 'sleep') {
        if (!pokemon.status) pokemon.trySetStatus('slp', null, placeEffects[key]);
      } else if (def.mode === 'slow') {
        if (!pokemon.hasAbility('levitate')) {
          this.add('pocketdexplace', pokemon, key, 'hurt');
          this.boost({spe: -1}, pokemon, null, placeEffects[key]);
        }
      } else if (def.hurt && !has) {
        this.add('pocketdexplace', pokemon, key, 'hurt');
        this.damage(pokemon.baseMaxhp / (def.power ?? 16), pokemon, null, placeEffects[key]);
      } else if (!def.hurt && has && pokemon.hp < pokemon.maxhp) {
        this.add('pocketdexplace', pokemon, key, 'heal');
        this.heal(pokemon.baseMaxhp / 16, pokemon, null, placeEffects[key]);
      }
    },
  });
  return placeEffects[key];
}

// Battle Factory (input.exp): o XP de cada adversário derrubado entra na hora, como nos jogos: quem lutou contra ele
// ganha tudo e, com o Exp. Share, o resto do time ganha a metade; subindo de nível, os atributos crescem na hora.
// exp = {mons: [{level, exp}] (por posição), table: [[XP para cada posição]] (por adversário), share}.
function markFought(game) {
  if (!game.exp) return;
  // Todos os que estão em campo (na dupla, os dois de cada lado).
  for (const foe of game.battle.sides[1].active) {
    if (!foe || foe.fainted) continue;
    const list = (game.fought[originalIndex(foe)] ??= []);
    for (const mine of game.battle.sides[0].active) if (mine && !list.includes(originalIndex(mine))) list.push(originalIndex(mine));
  }
}
function levelUp(game, pokemon, level) {
  const before = game.battle.spreadModify(pokemon.species.baseStats, pokemon.set);
  pokemon.set.level = level;
  pokemon.level = level;
  const after = game.battle.spreadModify(pokemon.species.baseStats, pokemon.set);
  for (const stat of Object.keys(after)) {
    const gain = after[stat] - before[stat];
    if (stat === 'hp') {
      pokemon.maxhp += gain;
      pokemon.baseMaxhp += gain;
      if (pokemon.hp > 0) pokemon.hp += gain;
    } else {
      pokemon.storedStats[stat] += gain;
      pokemon.baseStoredStats[stat] += gain;
    }
  }
}
function giveExp(game) {
  const exp = game.exp;
  if (!exp) return;
  for (const foe of game.battle.sides[1].pokemon) {
    const j = originalIndex(foe);
    if (exp.given[j] || !(foe.fainted || game.captured === j)) continue;
    exp.given[j] = true;
    const fought = game.fought[j] ?? [];
    let shared = false;
    for (const mon of game.battle.sides[0].pokemon) {
      const i = originalIndex(mon);
      const now = exp.mons[i];
      if (!now || mon.fainted || !(mon.hp > 0)) continue;
      const full = fought.includes(i);
      const gained = full ? exp.table[j]?.[i] ?? 0 : Math.floor((exp.table[j]?.[i] ?? 0) * exp.share);
      if (!gained) continue;
      now.exp += gained;
      exp.gained[i] = (exp.gained[i] ?? 0) + gained;
      if (full) game.battle.add('pocketdexexp', mon, gained);
      else shared = true;
      let level = now.level;
      while (now.exp >= (level + 1) ** 3) level++;
      if (level > now.level) {
        levelUp(game, mon, level);
        now.level = level;
        game.battle.add('pocketdexlevel', mon, level);
      }
    }
    if (shared) game.battle.add('pocketdexexpshare');
  }
}

function configure(game) {
  const canZMove = game.battle.actions.canZMove.bind(game.battle.actions);
  game.battle.actions.canZMove = pokemon => game.teams[pokemon.side.n][originalIndex(pokemon)].gimmick === 'z' ? canZMove(pokemon) : undefined;
  for (const side of game.battle.sides) {
    side.dynamaxUsed = false;
    side.canDynamaxNow = function () { return !this.dynamaxUsed; };
    for (const pokemon of side.pokemon) {
      const mon = game.teams[side.n][originalIndex(pokemon)];
      // The builder chooses the mechanic; each team has a separate usage budget
      // for Mega, Dynamax/Gigantamax, Terastal and Z-Move.
      if (mon.gimmick !== 'mega') pokemon.canMegaEvo = null;
      pokemon.canTerastallize = mon.gimmick === 'tera' ? pokemon.teraType : null;
      const dynamaxRequest = pokemon.getDynamaxRequest.bind(pokemon);
      pokemon.getDynamaxRequest = skip => mon.gimmick === 'dmax' && !mon.noDmax ? dynamaxRequest(skip) : undefined;
      for (const slot of pokemon.moveSlots) {
        slot.pp = slot.maxpp = Dex.moves.get(slot.id).pp;
      }
      // Battle Factory: pontos a mais nos atributos, sem o limite de IVs/EVs (itens e cartas).
      for (const [stat, value] of Object.entries(mon.bonus ?? {})) {
        const points = Math.max(0, Math.floor(Number(value) || 0));
        if (!points) continue;
        if (stat === 'hp') {
          pokemon.maxhp += points;
          pokemon.baseMaxhp += points;
          pokemon.hp = pokemon.maxhp;
        } else if (stat in pokemon.storedStats) {
          pokemon.storedStats[stat] += points;
          pokemon.baseStoredStats[stat] += points;
        }
      }
      // Battle Factory: os itens a mais (bem mais fracos que o segurado) somam uma porcentagem.
      for (const [stat, value] of Object.entries(mon.boost ?? {})) {
        const pct = Math.max(0, Number(value) || 0);
        if (!pct) continue;
        if (stat === 'hp') {
          pokemon.maxhp = pokemon.baseMaxhp = Math.floor(pokemon.maxhp * (1 + pct));
          pokemon.hp = pokemon.maxhp;
        } else if (stat in pokemon.storedStats) {
          pokemon.storedStats[stat] = pokemon.baseStoredStats[stat] = Math.floor(pokemon.storedStats[stat] * (1 + pct));
        }
      }
      // Battle Factory: o HP que sobrou do andar anterior (0 = continua desmaiado).
      if (mon.hpRatio != null) {
        const ratio = Math.min(1, Math.max(0, Number(mon.hpRatio) || 0));
        pokemon.hp = ratio > 0 ? Math.max(1, Math.ceil(pokemon.maxhp * ratio)) : 0;
        if (!pokemon.hp) {
          pokemon.fainted = true;
          pokemon.status = '';
          side.pokemonLeft--;
        }
      }
    }
  }
  game.battle.makeRequest('move');
  game.battle.onEvent('PocketDexItem', game.battle.format, function (pokemon) {
    // Na única: uma ação do lado; na dupla/tripla: uma por posição (quem usa o turno para o item).
    const pending = game.pendingItems[pokemon.side.n];
    const action = pending?.kind ? pending : pending?.[pokemon.position];
    if (!action) return;
    const done = () => {
      if (pending.kind) game.pendingItems[pokemon.side.n] = null;
      else delete pending[pokemon.position];
    };
    if (BALLS[action.item]) {
      throwBall(game, this, pokemon, action.item);
      done();
      return;
    }
    const target = pokemon.side.pokemon.find(p => originalIndex(p) === action.index);
    const fixed = {potion: 20, 'super-potion': 60, 'hyper-potion': 120, 'max-potion': 1e9, revive: 0}[action.item];
    // Battle Factory (healPct): cura uma parte do HP máximo (o nível não tem limite).
    const share = {potion: .25, 'super-potion': .5, 'hyper-potion': .75, 'max-potion': 1}[action.item];
    const base = fixed === 1e9 ? target.maxhp : fixed;
    const item = game.healPct && share ? Math.max(base, Math.ceil(target.maxhp * share)) : base;
    if (item === undefined || !target || !(game.bags[pokemon.side.n][action.item] > 0)) throw new Error('Item inválido');
    game.bags[pokemon.side.n][action.item]--;
    const previousHp = target.hp;
    this.add('pocketdexitem', target, action.item);
    if (action.item === 'revive') {
      target.fainted = false;
      target.faintQueued = false;
      target.status = '';
      target.side.faintedThisTurn = false;
      target.hp = Math.max(1, Math.floor(target.maxhp / 2));
      target.side.pokemonLeft++;
      this.add('-heal', target, target.getHealth);
    } else if (target.isActive) this.heal(item, target, pokemon, {id: action.item, name: action.item, effectType: 'Item'});
    // No banco: o heal do simulador só cura quem está em campo.
    else target.heal(item, pokemon, {id: action.item, name: action.item, effectType: 'Item'});
    this.add('pocketdexheal', target, action.item, target.hp - previousHp);
    done();
  });
}

/**
 * Battle Factory (input.capture: Pokémon selvagem): as Poké Balls e quanto
 * cada uma ajuda (como nos jogos). Quick Ball: 5× no 1º turno; Net Ball: 3,5×
 * em Água ou Inseto; Dusk Ball: 3× em cavernas (capture.dusk); Timer Ball:
 * sobe a cada turno (até 4×); Master Ball: sempre captura.
 */
export const BALLS = {
  'poke-ball': () => 1, 'great-ball': () => 1.5, 'ultra-ball': () => 2, 'master-ball': () => 255,
  'quick-ball': (battle) => (battle.turn <= 1 ? 5 : 1),
  'net-ball': (battle, foe) => (foe.hasType(['Water', 'Bug']) ? 3.5 : 1),
  'dusk-ball': (battle, foe, capture) => (capture.dusk ? 3 : 1),
  'timer-ball': (battle) => Math.min(4, 1 + (battle.turn * 1229) / 4096),
};
const BALL_NAMES = {'poke-ball': 'Poké Ball', 'great-ball': 'Great Ball', 'ultra-ball': 'Ultra Ball', 'master-ball': 'Master Ball', 'quick-ball': 'Quick Ball', 'net-ball': 'Net Ball', 'dusk-ball': 'Dusk Ball', 'timer-ball': 'Timer Ball'};

/**
 * Joga a bola no selvagem (a conta dos jogos da 6ª geração em diante):
 * a = (3·HPmáx − 2·HP) × taxa de captura × bola ÷ (3·HPmáx) × status
 * (dormindo ou congelado 2,5×; paralisado, envenenado ou queimado 1,5×).
 * São 4 sorteios de (a/255)^¼: passou nos 4, capturou (cada um é um balanço). A Master Ball sempre captura.
 */
function throwBall(game, battle, pokemon, ball) {
  const foe = battle.sides[1 - pokemon.side.n].active[0];
  game.bags[pokemon.side.n][ball]--;
  // capture.bonus: a captura mais fácil da árvore de melhorias (% a mais na taxa).
  const rate = Number(game.capture.rates?.[originalIndex(foe)] ?? 45) * (1 + Number(game.capture.bonus ?? 0) / 100);
  const status = ['slp', 'frz'].includes(foe.status) ? 2.5 : foe.status ? 1.5 : 1;
  // O nível conta: os de nível baixo (até 20) são mais fáceis (como na 8ª geração) e os de nível
  // acima do seu Pokémon em campo, bem mais difíceis (como em Scarlet/Violet). O HP já conta na conta.
  const mine = pokemon.side.active[0] ?? pokemon;
  const low = foe.level < 20 ? (30 - foe.level) / 10 : 1;
  const above = foe.level > mine.level ? Math.max(0.15, (mine.level / foe.level) ** 3) : 1;
  const a = ((3 * foe.maxhp - 2 * foe.hp) * rate * BALLS[ball](battle, foe, game.capture)) / (3 * foe.maxhp) * status * low * above;
  const chance = Math.min(1, a / 255) ** 0.25;
  let shakes = 0;
  while (shakes < 4 && (a >= 255 || ball === 'master-ball' || battle.random() < chance)) shakes++;
  const caught = shakes === 4;
  battle.add('pocketdexball', foe, ball, String(Math.min(3, shakes)), caught ? 'caught' : 'free');
  if (caught) {
    game.captured = originalIndex(foe);
    game.capturedBall = ball;
    battle.win(pokemon.side);
  }
}

/**
 * Golpe que continua sozinho (Outrage, Thrash, Rollout, o segundo turno de
 * Solar Beam/Fly, a recarga do Hyper Beam...): o pedido do Showdown traz um
 * golpe só, sem PP. Nesse turno não tem escolha: a tela joga sozinha.
 */
function lockedOf(request) {
  const moves = request?.moves;
  if (!moves || moves.length !== 1 || moves[0].pp != null) return null;
  return {slug: moves[0].id, name: moves[0].move};
}

/**
 * O que já apareceu de cada Pokémon (como no Showdown): golpes usados,
 * habilidade e item que se mostraram. A tela mostra só isso do adversário.
 */
function revealed(game, side, index) {
  game.revealed ??= game.teams.map(team => team.map(() => ({moves: [], ability: '', item: ''})));
  return game.revealed[side]?.[index] ?? null;
}

function revealFrom(game, kind, actor, value, fromAbility, fromItem, ofRef) {
  const ref = r => {
    const s = /^p[1-4]/.test(r || '') ? Number(r[1]) - 1 : -1, i = Number(r?.split(': ')[1]?.slice(2));
    return s >= 0 && Number.isInteger(i) ? revealed(game, s, i) : null;
  };
  const me = ref(actor), owner = ref(ofRef) ?? me;
  if (me && kind === 'move' && value && !me.moves.includes(value)) me.moves.push(value);
  if (me && kind === '-ability' && value) me.ability = value;
  if (me && (kind === '-item' || kind === '-enditem') && value) me.item = value;
  if (owner && fromAbility) owner.ability = fromAbility;
  if (owner && fromItem) owner.item = fromItem;
}

function snapshot(game) {
  const b = game.battle;
  return {
    turn: b.turn,
    winner: b.ended ? (b.winner === b.sides[0].name || b.winner === `${b.sides[0].name} & ${b.sides[2]?.name}` ? 0 : b.winner ? 1 : -1) : null,
    weather: b.field.weather,
    terrain: b.field.terrain,
    // Trick Room, Gravity, Magic Room, Wonder Room...
    pseudoWeather: Object.keys(b.field.pseudoWeather),
    mode: b.gameType,
    bags: game.bags,
    captured: game.captured ?? null,
    capturedBall: game.capturedBall ?? null,
    // Battle Factory: o XP de cada um (nível e XP de agora, quanto ganhou) e quem lutou contra cada adversário.
    ...(game.exp ? {exp: {mons: game.exp.mons, gained: game.exp.gained}, fought: game.fought} : {}),
    sides: b.sides.map(side => ({
      slots: slotsFor(game, side),
      actives: side.active.map(p => p ? originalIndex(p) : -1),
      active: originalIndex(side.active[0]),
      forceSwitch: Boolean(side.activeRequest?.forceSwitch?.[0]),
      wait: Boolean(side.activeRequest?.wait),
      trapped: Boolean(side.activeRequest?.active?.[0]?.trapped),
      revival: Boolean(side.slotConditions[side.active[0].position]?.revivalblessing),
      switchOptions: side.pokemon.filter(p => side.slotConditions[side.active[0].position]?.revivalblessing ? p.fainted : !p.fainted && p !== side.active[0] && (!side.activeRequest?.active?.[0]?.trapped || side.activeRequest?.forceSwitch)).map(originalIndex),
      request: side.activeRequest?.active?.[0] ?? null,
      locked: side.activeRequest?.forceSwitch || side.activeRequest?.wait ? null : lockedOf(side.activeRequest?.active?.[0]),
      // Stealth Rock, Spikes (camadas), Reflect, Light Screen, Tailwind... (turnos que faltam, se tiver).
      conditions: Object.fromEntries(Object.entries(side.sideConditions).map(([id, c]) => [id, c.layers ?? c.duration ?? 0])),
      used: {mega: game.used[side.n].mega, dmax: Boolean(side.dynamaxUsed), z: Boolean(side.zMoveUsed), tera: game.used[side.n].tera},
      team: [...side.pokemon].sort((a, c) => originalIndex(a) - originalIndex(c)).map(p => ({
        index: originalIndex(p), level: p.level, hp: p.hp, maxHp: p.maxhp, status: p.status, boosts: {...p.boosts},
        species: p.species.name, formId: formIdOf(game, p), types: p.getTypes(), ability: Dex.abilities.get(p.ability).name,
        item: Dex.items.get(p.item).name, stats: {...p.baseStoredStats}, spe: p.baseStoredStats.spe, actionSpeed: p.getActionSpeed(), tera: p.terastallized || '',
        dmax: p.volatiles.dynamax ? Math.max(0, p.volatiles.dynamax.duration ?? 3) : 0,
        moves: p.moveSlots.map(m => ({slug: m.id, name: m.move, pp: m.pp, maxPp: m.maxpp, disabled: m.disabled})),
        revealed: revealed(game, side.n, originalIndex(p)) ?? {moves: [], ability: '', item: ''},
      })),
    })),
  };
}

function result(game) {
  const lines = extractChannelMessages(game.battle.log.slice(game.cursor).join('\n'), [-1])[-1];
  game.cursor = game.battle.log.length;
  const events = eventsFor(game, lines);
  return {state: snapshot(game), log: lines, events};
}

function eventsFor(game, lines) {
  const events = [];
  const active = game.shownActive ??= game.teams.map(() => 0);
  const sideOf = value => /^p[1-4]/.test(value || '') ? Number(value[1]) - 1 : -1;
  let actorSide = -1, actorPokemon = -1;
  const label = side => {
    const mon = game.teams[side][actorSide === side && Number.isInteger(actorPokemon) ? actorPokemon : active[side]];
    return {side, name: mon.name || mon.set.species};
  };
  const say = (key, ...args) => events.push({t: 'text', key, args});
  const health = value => Number(String(value).split(/[ /]/)[0]) || 0;
  // Quem é "p2a: pd3" (o [of] das mensagens: o dono da habilidade ou do item).
  const who = ref => {
    const s = sideOf(ref), i = Number(ref?.split(': ')[1]?.slice(2));
    const mon = s >= 0 && game.teams[s][Number.isInteger(i) ? i : active[s]];
    return mon ? {side: s, name: mon.name || mon.set.species} : null;
  };
  // Clima: o texto de quando começa e quando acaba (como nos jogos).
  const WEATHER_TEXT = {RainDance: 'rain', PrimordialSea: 'rain', SunnyDay: 'sun', DesolateLand: 'sun', Sandstorm: 'sand', Hail: 'hail', Snow: 'snow', Snowscape: 'snow'};
  for (const [lineIndex, line] of lines.entries()) {
    const [, kind, actor, value, extra] = line.split('|');
    const parts = line.split('|');
    // [from] item: Leftovers / [from] ability: Rough Skin / [of] p2a: pd0
    const tag = name => parts.find(x => x.startsWith(`[${name}] `))?.slice(name.length + 3) ?? '';
    const from = tag('from');
    const fromItem = from.startsWith('item: ') ? from.slice(6) : '';
    const fromAbility = from.startsWith('ability: ') ? from.slice(9) : '';
    const of = who(tag('of'));
    const side = sideOf(actor);
    const actorIndex = Number(actor?.split(': ')[1]?.slice(2));
    actorSide = side; actorPokemon = actorIndex;
    // Em dupla/tripla: a posição em campo (p1a → 0, p1b → 1) e quem é no time (a tela mostra um evento de cada vez).
    const at = Number.isInteger(actorIndex) ? {pos: Math.max(0, 'abc'.indexOf(actor.split(': ')[0].slice(2, 3))), at: actorIndex} : {};
    revealFrom(game, kind, actor, value, fromAbility, fromItem, tag('of'));
    if (kind === 'switch' || kind === 'drag') {
      const index = Number(actor.split(': ')[1]?.slice(2));
      if (!Number.isInteger(index)) continue;
      active[side] = index;
      events.push({t: 'switch', side, index, ...at});
      say(side ? 'foeSent' : 'go', label(side));
    } else if (kind === 'move') {
      const m = PocketDexSim.move(value);
      if (m) events.push({t: 'attack', side, type: m.type, category: m.category, slug: m.slug, ...at});
      say('used', label(side), value);
    } else if (kind === '-damage' || kind === '-heal') {
      const index = Number(actor.split(': ')[1]?.slice(2));
      // Por que o HP mudou: item, habilidade, status, clima, armadilha... (o texto vem antes da barra mexer).
      const POTIONS = ['potion', 'super-potion', 'hyper-potion', 'revive'];
      if (kind === '-damage') {
        if (fromItem) say('hurtBy', label(side), fromItem);
        else if (fromAbility) { if (of && of.side !== side) say('abilityShow', of, fromAbility); say('hurtBy', label(side), fromAbility); }
        else if (from === 'brn') say('hurtBurn', label(side));
        else if (from === 'psn' || from === 'tox') say('hurtPoison', label(side));
        else if (from === 'Recoil' || from === 'recoil') say('recoil', label(side));
        else if (from === 'Sandstorm' || from === 'sandstorm') say('hurtSand', label(side));
        else if (from === 'hail' || from === 'Hail') say('hurtHail', label(side));
        else if (from === 'Stealth Rock') say('hurtRocks', label(side));
        else if (from === 'Spikes') say('hurtSpikes', label(side));
        else if (from === 'Leech Seed') say('seedSap', label(side));
        else if (from === 'confusion') say('hurtConfusion', label(side));
        else if (from === 'Curse') say('hurtCurse', label(side));
        else if (from === 'Salt Cure') say('hurtBy', label(side), 'Salt Cure');
        else if (from === 'partiallytrapped') say('hurtBy', label(side), tag('partiallytrapped') || 'Bind');
      } else if (!POTIONS.includes(fromItem.toLowerCase()) && !parts.includes('[silent]')) {
        if (fromItem && !/Berry$/.test(fromItem)) say('healedBy', label(side), fromItem);
        else if (fromAbility) say('healedBy', label(side), fromAbility);
        else if (from === 'Grassy Terrain' || from === 'grassyterrain') say('healedBy', label(side), 'Grassy Terrain');
        else if (from === 'drain' && of) say('drained', of);
        else if (!from && !lines.slice(lineIndex + 1).some(l => l.startsWith('|pocketdexheal|'))) say('healedMove', label(side));
      }
      if (index !== active[side] && Number.isInteger(index)) events.push({t: 'heal', side, index, hp: health(value), ...at});
      else events.push({t: 'hp', side, hp: health(value), ...at});
    } else if (kind === 'faint') {
      events.push({t: 'faint', side, ...at});
      say('fainted', label(side));
    } else if (kind === '-status') {
      events.push({t: 'status', side, status: value, ...at});
      say({brn: 'burned', par: 'paralyzed', psn: 'poisoned', tox: 'badlyPoisoned', slp: 'fellAsleep', frz: 'frozen'}[value] || 'failed', label(side));
    } else if (kind === '-curestatus') {
      events.push({t: 'status', side, status: '', ...at});
      if (value === 'slp' && parts.includes('[msg]')) say('woke', label(side));
      else if (value === 'frz' && parts.includes('[msg]')) say('thawed', label(side));
      else if (fromItem || fromAbility) say('statusCured', label(side), fromItem || fromAbility);
    }
    else if (kind === 'cant') {
      // Não conseguiu agir: paralisia, sono, congelado, recuo, recarga, Truant...
      const reason = {par: 'fullPara', slp: 'asleep', frz: 'isFrozen', flinch: 'flinched', recharge: 'mustRecharge', 'ability: Truant': 'loafing'}[value];
      say(reason || 'cantMove', label(side));
    }
    else if (kind === '-ability') say('abilityShow', label(side), value);
    else if (kind === '-item') {
      // Item que aparece: Air Balloon ao entrar, Frisk mostrando o item, Trick trocando.
      if (fromAbility && of) say('abilityShow', of, fromAbility);
      if (value === 'Air Balloon' && !from) say('balloon', label(side));
      else if (from.startsWith('move: ')) say('gotItem', label(side), value);
      else say('itemShow', label(side), value);
    } else if (kind === '-enditem') {
      // Item gasto: baga comida, balão estourado, Focus Sash, Knock Off...
      if (parts.includes('[eat]')) say('ateItem', label(side), value);
      else if (from === 'gem') say('gemUsed', label(side), value);
      else if (value === 'Air Balloon') say('balloonPop', label(side));
      else if (value === 'Focus Sash') say('sashHung', label(side));
      else if (from.startsWith('move: ') || from === 'stealeat') say('lostItem', label(side), value);
      else say('itemUsedUp', label(side), value);
    } else if (kind === '-immune' && fromAbility) { say('abilityShow', label(side), fromAbility); say('noEffect', label(side)); }
    else if (kind === '-activate' && (value?.startsWith('ability: ') || value?.startsWith('item: '))) {
      const name = value.replace(/^(ability|item): /, '');
      say(value.startsWith('ability: ') ? 'abilityShow' : 'itemActive', label(side), name);
    } else if (kind === '-activate' && (value === 'move: Protect' || value === 'Protect')) say('protected', label(side));
    else if (kind === '-activate' && value === 'confusion') say('isConfused', label(side));
    else if (kind === '-start' && value === 'confusion') say('confused', label(side));
    // Protosynthesis / Quark Drive (sol, Electric Terrain ou Booster Energy): o melhor atributo sobe.
    else if (kind === '-start' && /^(protosynthesis|quarkdrive)(atk|def|spa|spd|spe)$/.test(value)) say('paradoxBoost', label(side), value.slice(-3));
    else if (kind === '-end' && ['Protosynthesis', 'Quark Drive'].includes(value)) continue;
    else if (kind === '-end' && value === 'confusion') say('confusionEnd', label(side));
    else if (kind === '-miss') { events.push({t: 'miss', side, ...at}); say('missed', label(side)); }
    else if (kind === '-immune') say('noEffect', label(side));
    else if (kind === '-crit') say('crit');
    else if (kind === '-supereffective') say('super');
    else if (kind === '-resisted') say('weak');
    else if (kind === '-fail') say('failed', label(side));
    else if (kind === '-hitcount') say('hits', Number(value));
    else if (kind === '-terastallize') { game.used[side].tera = true; events.push({t: 'tera', side, type: value.toLowerCase()}); }
    else if (kind === '-mega') {
      game.used[side].mega = true;
      // Quem megaevoluiu (pdN) e a forma pela pedra que ele segura (X ou Y).
      const index = Number.isInteger(actorIndex) ? actorIndex : active[side];
      const mon = game.teams[side][index];
      const stone = Dex.items.get(extra)?.megaStone;
      const form = typeof stone === 'string' ? stone : stone?.[value] ?? Object.values(stone ?? {})[0];
      const id = (form && FORMS[form.toLowerCase().replace(/[^a-z0-9]/g, '')]) || mon?.mega?.id;
      if (mon?.mega && id) events.push({t: 'mega', side, id});
    } else if ((kind === '-start' || kind === '-end') && value === 'Dynamax') {
      const mon = game.teams[side][active[side]];
      events.push({t: 'dmax', side, on: kind === '-start', id: kind === '-start' ? mon.gmax || mon.id : mon.id});
    } else if (kind === '-weather' && value !== '[upkeep]') {
      const weather = {RainDance: 'rain', SunnyDay: 'sun', Sandstorm: 'sand', Hail: 'hail', Snow: 'snow', DeltaStream: 'wind'}[actor] || '';
      if (actor === 'DeltaStream') say('windStart');
      // Drizzle, Drought, Sand Stream, Snow Warning: mostra a habilidade e o clima que começou.
      if (fromAbility && of) say('abilityShow', of, fromAbility);
      const text = WEATHER_TEXT[actor] || '';
      if (text) say(`${text}Start`);
      else if (actor === 'none' && game.lastWeather) say(`${game.lastWeather}End`);
      game.lastWeather = text;
      events.push({t: 'weather', weather});
      if (actor === 'ShadowSky') say('sim', 'O céu ficou sombrio!');
    } else if ((kind === 'detailschange' || kind === '-formechange') && !/-(Mega|Primal)/.test(value || '')) {
      // Forma que muda na batalha (Stance Change, Disguise, Zen Mode, Zero to Hero, Schooling...).
      const species = (value || '').split(',')[0];
      const id = FORMS[species.toLowerCase().replace(/[^a-z0-9]/g, '')];
      if (id) events.push({t: 'form', side, index: actorIndex, id});
      say('formChanged', label(side), species);
    } else if (kind === '-boost' || kind === '-unboost') {
      // Atributo subindo ou caindo, com o texto dos jogos (Swords Dance: "subiu muito!"; no +6: "não pode subir mais!").
      const by = Math.min(3, Number(extra) || 0);
      const up = kind === '-boost';
      say(by ? `${up ? 'statUp' : 'statDown'}${by > 1 ? by : ''}` : up ? 'statMax' : 'statMin', label(side), value);
    } else if (kind === '-setboost' && Number(extra) === 6) say('statUp3', label(side), value);
    else if (kind === '-clearallboost') say('statsReset');
    else if ((kind === '-fieldstart' || kind === '-fieldend') && /Terrain$/.test(actor ?? '')) {
      // Terreno (o do lugar ou de um golpe): o chão do campo muda.
      const terrain = {'Grassy Terrain': 'grassy', 'Electric Terrain': 'electric', 'Misty Terrain': 'misty', 'Psychic Terrain': 'psychic'}[actor.replace(/^move: /, '')] ?? '';
      events.push({t: 'terrain', terrain: kind === '-fieldstart' ? terrain : ''});
      say(kind === '-fieldstart' ? `${terrain}TerrainStart` : `${terrain}TerrainEnd`);
    } else if (kind === '-fieldstart' && actor?.startsWith('PocketDex: ')) {
      const key = actor.slice(11);
      events.push({t: 'place', place: key});
      say(`${key}Start`);
    } else if (kind === 'pocketdexexp') {
      // XP na hora (Battle Factory) e a subida de nível, com o barulho e a barra.
      events.push({t: 'exp', side, index: actorIndex, exp: Number(value)});
      say('gainExp', label(side), Number(value));
    } else if (kind === 'pocketdexexpshare') {
      say('gainExpShare');
    } else if (kind === 'pocketdexlevel') {
      events.push({t: 'level', side, index: actorIndex, level: Number(value)});
      say('levelUp', label(side), Number(value));
    } else if (kind === 'pocketdexplace') {
      // O efeito do lugar no fim do turno: fere ou cura (a barra mexe na linha seguinte).
      say(extra === 'heal' ? 'placeHeal' : 'placeHurt', label(side), PLACE_EFFECTS[value]?.name ?? value);
    }
    else if (['-start', '-end', '-activate', '-sidestart', '-sideend', '-fieldstart', '-fieldend', '-boost', '-unboost', '-setboost', '-clearboost', '-clearallboost', '-prepare', 'cant', '-item', '-enditem', '-ability', '-transform'].includes(kind)) {
      const subject = side >= 0 ? label(side).name : 'Campo';
      const effect = value?.replace(/^move: /, '') || extra || '';
      say('sim', `${subject}: ${effect}${extra && ['-boost', '-unboost'].includes(kind) ? ` (${kind === '-unboost' ? '−' : '+'}${extra})` : ''}`);
    } else if (kind === 'pocketdexitem' || kind === 'pocketdexheal') {
      const index = Number(actor.split(': ')[1]?.slice(2));
      const target = {side, name: game.teams[side][index].name || game.teams[side][index].set.species};
      if (kind === 'pocketdexitem') say('usedItem', target, {potion: 'Potion', 'super-potion': 'Super Potion', 'hyper-potion': 'Hyper Potion', revive: 'Revive'}[value]);
      else if (value === 'revive') say('revived', target);
      else say('healed', target, Number(extra));
    } else if (kind === 'pocketdexball') {
      const index = Number(actor.split(': ')[1]?.slice(2));
      const target = {side, name: game.teams[side][index].name || game.teams[side][index].set.species};
      say('threwBall', {side: 1 - side, name: ''}, BALL_NAMES[value]);
      events.push({t: 'ball', side, ball: value, shakes: Number(extra), caught: parts[5] === 'caught'});
      say(parts[5] === 'caught' ? 'caught' : 'brokeFree', target);
    } else if (kind === 'message') say('sim', actor);
    else if (kind === 'win' && game.captured != null) continue;
    else if (kind === 'win') say(actor === game.battle.sides[0].name ? 'win' : 'lose');
    else if (kind === 'tie') say('draw');
  }
  return events;
}

function command(game, sideIndex, action, slot = 0) {
  const side = game.battle.sides[sideIndex];
  if (side.activeRequest?.wait) {
    if (action.kind !== 'wait') throw new Error('Aguarde a troca do adversário');
    return null;
  }
  if (action.kind === 'switch') {
    const position = side.pokemon.findIndex(p => originalIndex(p) === action.index);
    if (position < 0) throw new Error('Troca inválida');
    return `switch ${position + 1}`;
  }
  if (action.kind === 'pass') return 'pass';
  if (action.kind === 'shift') return 'shift';
  if (action.kind === 'item') {
    if (side.activeRequest?.forceSwitch?.[slot]) throw new Error('Escolha outro Pokémon');
    if (BALLS[action.item]) {
      if (game.battle.gameType !== 'singles') throw new Error('Não dá para capturar este Pokémon');
      // Só no Pokémon selvagem (input.capture), ainda de pé.
      const foe = game.battle.sides[1 - sideIndex].active[0];
      if (!game.capture || sideIndex !== 0 || !(game.bags[sideIndex][action.item] > 0) || !foe || foe.fainted) throw new Error('Não dá para capturar este Pokémon');
      return {item: action};
    }
    const target = side.pokemon.find(p => originalIndex(p) === action.index);
    if (!target || !(game.bags[sideIndex][action.item] > 0) || (action.item === 'revive' ? !target.fainted : target.fainted || target.hp >= target.maxhp)) throw new Error('Item inválido');
    return {item: action};
  }
  if (action.kind !== 'move' || side.activeRequest?.forceSwitch?.[slot]) throw new Error('Ação inválida');
  // Preso no golpe (Outrage, recarga...): é o único que dá.
  if (lockedOf(side.activeRequest?.active?.[slot])) return `move 1${action.target ? ` ${action.target}` : ''}`;
  const mon = game.teams[sideIndex][originalIndex(side.active[slot])];
  const mechanic = action.gimmick ?? mon.gimmick;
  const req = side.activeRequest?.active?.[slot];
  const available = mechanic === 'mega' ? req?.canMegaEvo : mechanic === 'tera' ? req?.canTerastallize : mechanic === 'dmax' ? req?.canDynamax : mechanic === 'z' ? req?.canZMove?.[Math.max(0, action.index)] : false;
  const suffix = available && mechanic === mon.gimmick ? {mega: ' mega', tera: ' terastallize', dmax: ' dynamax', z: ' zmove'}[mechanic] : '';
  return `move ${action.index < 0 ? 1 : action.index + 1}${action.target ? ` ${action.target}` : ''}${suffix}`;
}

function estimatedDamage(source, target, move) {
  if (!target || target.fainted || !Dex.getImmunity(move.type, target)) return 0;
  const absorb = {water: ['waterabsorb','stormdrain','dryskin'], electric: ['voltabsorb','lightningrod','motordrive'], fire: ['flashfire','wellbakedbody'], grass: ['sapsipper'], ground: ['levitate','eartheater']};
  const ignoresAbility = ['moldbreaker','teravolt','turboblaze'].includes(source.ability);
  if (!ignoresAbility && (absorb[move.type.toLowerCase()]?.includes(target.ability) || target.ability === 'wonderguard' && Dex.getEffectiveness(move.type,target) <= 0 || target.ability === 'soundproof' && move.flags.sound || target.ability === 'bulletproof' && move.flags.bullet || target.ability === 'windrider' && move.flags.wind)) return 0;
  const attack = move.category === 'Physical' ? 'atk' : 'spa', defense = move.category === 'Physical' ? 'def' : 'spd';
  const power = typeof move.damage === 'number' ? move.damage * 2 : move.damage === 'level' ? source.level * 2 : move.basePower || (move.basePowerCallback ? 70 : 0);
  return power * source.getStat(attack, false, true) / Math.max(1, target.getStat(defense, false, true)) * 2 ** Dex.getEffectiveness(move.type, target) * (source.hasType(move.type) ? 1.5 : 1) * (move.accuracy === true ? 1 : (move.accuracy || 100) / 100);
}
function recommended(game, sideIndex, options = {}) {
  const side = game.battle.sides[sideIndex];
  if (side.activeRequest?.wait) return [{kind: 'wait', index: 0}];
  const reserved = new Set(options.reservedSwitches || []), mechanics = new Set(options.reservedMechanics || []);
  return slotsFor(game, side).map(slot => {
    if (options.controlledSlots && !options.controlledSlots.includes(slot.slot)) return {kind: 'pass', index: 0};
    const source = side.active[slot.slot];
    if (slot.pass || side.activeRequest?.forceSwitch && !slot.forceSwitch) return {kind: 'pass', index: 0};
    const foes = side.foes().filter(p => p.hp);
    const bench = slot.switchOptions.filter(index => !reserved.has(index) && (slot.forceSwitch || !slot.request?.maybeTrapped));
    const matchup = p => Math.max(0, ...p.moveSlots.map(m => Math.max(0, ...foes.map(foe => estimatedDamage(p, foe, Dex.moves.get(m.id))))));
    const threat = p => Math.max(0, ...foes.flatMap(foe => foe.moveSlots.filter(m => m.pp > 0 && !m.disabled).map(m => estimatedDamage(foe,p,Dex.moves.get(m.id)))));
    const fitness = p => matchup(p) - threat(p) * .6;
    const bestBench = bench.map(index => ({index, p: side.pokemon.find(p => originalIndex(p) === index)})).sort((a,b) => fitness(b.p) - fitness(a.p))[0];
    if (slot.forceSwitch) {
      if (!bestBench) return {kind: 'pass', index: 0};
      reserved.add(bestBench.index); return {kind: 'switch', index: bestBench.index};
    }
    let best = {score: -1, action: {kind: 'move', index: 0, target: 0, gimmick: ''}};
    for (const [index, requested] of (slot.request?.moves || []).entries()) {
      if (requested.disabled || requested.pp === 0) continue;
      const move = Dex.moves.get(requested.id), targets = requested.targets;
      const choices = targets.length ? targets : [{loc: 0, side: sideIndex, index: originalIndex(source)}];
      for (const target of choices) {
        const p = game.battle.sides[target.side].pokemon.find(p => originalIndex(p) === target.index);
        const ally = source.isAlly(p);
        let score = move.category === 'Status' ? 0 : p.fainted ? 0 : estimatedDamage(source, p, move) * (ally ? -1 : 1);
        if (move.category !== 'Status' && !targets.length) score = foes.reduce((sum, foe) => sum + estimatedDamage(source, foe, move), 0);
        if (move.heal) score = source.hp < source.maxhp * .6 ? 110 : 0;
        if (move.status && p && !p.status && !ally) score = 50;
        if (move.boosts && move.target === 'self' && source.hp > source.maxhp * .7 && Object.keys(move.boosts).some(key => source.boosts[key] < 1)) score = 40;
        if (move.id === 'helpinghand' && ally && p !== source) score = Math.max(...p.moveSlots.map(m => Math.max(0, ...foes.map(foe => estimatedDamage(p, foe, Dex.moves.get(m.id)))))) * .55;
        if (['coaching','dragoncheer','aromaticmist'].includes(move.id) && ally && p !== source) score = 35;
        if (['reflect','lightscreen','auroraveil','tailwind'].includes(move.id) && !side.sideConditions[move.id]) score = 45;
        if (target.fainted) score = 0;
        if (score > best.score) best = {score, action: {kind: 'move', index, target: target.loc, gimmick: ''}};
      }
    }
    if (slot.canShift && best.score <= 0 && foes.some(p => !p.isAdjacent(source))) return {kind:'shift',index:0};
    const chosenMove = Dex.moves.get(slot.request?.moves[best.action.index]?.id);
    const chosenTarget = game.battle.getAllActive(true).find(p => source.getLocOf(p) === best.action.target);
    const advantagedAttack = chosenMove.category !== 'Status' && (chosenTarget ? !source.isAlly(chosenTarget) && Dex.getEffectiveness(chosenMove.type,chosenTarget) > 0 && estimatedDamage(source,chosenTarget,chosenMove) > 0 : foes.some(foe => Dex.getEffectiveness(chosenMove.type,foe) > 0 && estimatedDamage(source,foe,chosenMove) > 0));
    const threatened = foes.some(foe => foe.moveSlots.some(m => m.pp > 0 && !m.disabled && Dex.getEffectiveness(Dex.moves.get(m.id).type,source) > 0 && estimatedDamage(foe,source,Dex.moves.get(m.id)) > 0));
    const poorOffense = best.score < 30 && bestBench && matchup(bestBench.p) > best.score * 1.5 + 25;
    const saferReserve = bestBench && threatened && threat(bestBench.p) < threat(source) * .65 && fitness(bestBench.p) > fitness(source) + 20;
    const cooldownKey = `${sideIndex}:${slot.slot}`;
    if (bestBench && !advantagedAttack && (poorOffense || saferReserve) && game.battle.turn - (game.cpuSwitch?.[cooldownKey] ?? -10) > 2) {
      (game.cpuSwitch ??= {})[cooldownKey] = game.battle.turn; reserved.add(bestBench.index);
      return {kind: 'switch', index: bestBench.index};
    }
    const mechanic = game.teams[sideIndex][originalIndex(source)].gimmick;
    const req = slot.request;
    if (!mechanics.has(mechanic) && (mechanic === 'mega' && req?.canMegaEvo || mechanic === 'tera' && req?.canTerastallize || mechanic === 'dmax' && req?.canDynamax || mechanic === 'z' && req?.canZMove?.[best.action.index])) {
      best.action.gimmick = mechanic; mechanics.add(mechanic);
      // Max/Z can change a spread move into a move that requires one target.
      const base = Dex.moves.get(req.moves[best.action.index].id);
      const transformed = mechanic === 'dmax' ? game.battle.actions.getMaxMove(base, source) : mechanic === 'z' ? req.canZMove[best.action.index].move : null;
      if (transformed && (mechanic === 'dmax' || base.category !== 'Status')) {
        const candidates = targetsFor(game,source,transformed).filter(target => !target.ally && !target.fainted);
        const transformedMove = Dex.moves.get(transformed);
        candidates.sort((a,b) => estimatedDamage(source,game.battle.sides[b.side].pokemon.find(p => originalIndex(p) === b.index),transformedMove) - estimatedDamage(source,game.battle.sides[a.side].pokemon.find(p => originalIndex(p) === a.index),transformedMove));
        best.action.target = candidates[0]?.loc || 0;
      }
    }
    return best.action;
  });
}

export const PocketDexSim = {
  targets(handle, side, slot, index, gimmick = '') {
    const game = games.get(handle), pokemon = game?.battle.sides[side]?.active[slot];
    if (!pokemon) throw new Error('Pokémon inválido');
    const req = pokemon.side.activeRequest?.active?.[slot];
    if (req?.moves[index] && !req.moves[index].target) return {targets: [], automatic: true};
    const base = Dex.moves.get(req?.moves[index]?.id);
    const transformed = gimmick === 'dmax' || pokemon.volatiles.dynamax ? game.battle.actions.getMaxMove(base, pokemon) : gimmick === 'z' ? req?.canZMove?.[index]?.move : null;
    const move = transformed ? Dex.moves.get(transformed) : base;
    // O alvo de verdade deste Pokémon (Curse de quem não é Fantasma: nele mesmo, sem escolher).
    const target = transformed ? move.target : move.nonGhostTarget && !pokemon.hasType('Ghost') ? move.nonGhostTarget : move.target;
    return {targets: targetsFor(game, pokemon, move.id, target), automatic: !game.battle.actions.targetTypeChoices(target)};
  },
  recommend(handle, side, options) {
    const game = games.get(handle);
    if (!game || !game.battle.sides[side]) throw new Error('Batalha inválida');
    return {actions: recommended(game, side, options)};
  },
  create(input) {
    const mode = input.mode || 'singles';
    if (!['singles', 'doubles', 'triples', 'multi'].includes(mode) || input.teams.length !== (mode === 'multi' ? 4 : 2)) throw new Error('Formato inválido');
    const count = mode === 'doubles' ? 2 : mode === 'triples' ? 3 : 1;
    if (input.teams.some(team => team.length < count || team.length > 6)) throw new Error(`Escolha pelo menos ${count} Pokémon por time`);
    // Regras opcionais (convite online): Sleep Clause (só um Pokémon dormindo por vez).
    const ruleset = (input.rules ?? []).includes('sleep') ? ['Sleep Clause Mod'] : [];
    const battle = new Battle({format: {...formats, gameType: mode, playerCount: mode === 'multi' ? 4 : 2, ruleset}, seed: input.seed});
    const game = {battle, teams: input.teams, controllers: input.controllers, cursor: 0, used: input.teams.map(() => ({mega: false, tera: false})), pendingItems: input.teams.map(() => null), bags: input.teams.map((_, side) => ({potion: 3, 'super-potion': 2, 'hyper-potion': 1, 'max-potion': 0, revive: 1, ...(input.bags?.[side] ?? {})})), healPct: Boolean(input.healPct), capture: input.capture ?? null, captured: null};
    input.teams.forEach((team, side) => battle.setPlayer(`p${side + 1}`, {name: ['Você', 'Adversário', 'Aliado', 'Aliado adversário'][side], team: team.map(setFor)}));
    configure(game);
    // O clima do lugar (Battle Factory: sol no deserto, chuva no mar, neve na caverna de gelo...): já começa assim e fica até
    // um golpe ou uma habilidade trocar. Uma habilidade que já mudou o clima ao entrar (Drizzle...) vale mais.
    const [startWeather, weatherName] = {rain: ['raindance', 'RainDance'], sun: ['sunnyday', 'SunnyDay'], sand: ['sandstorm', 'Sandstorm'], snow: ['snowscape', 'Snow'], wind: ['deltastream', 'DeltaStream']}[input.weather] ?? [];
    if (startWeather && !battle.field.weather) {
      battle.field.weather = startWeather;
      battle.field.weatherState = {id: startWeather, duration: 0};
      battle.add('-weather', weatherName);
    }
    // O efeito do lugar (input.field): um terreno de verdade (Grassy, Electric, Misty, Psychic) ou um efeito próprio do
    // lugar (PLACE_EFFECTS: a chuva de diamantes na caverna fere quem não é Pedra, a aura sombria cura Fantasma...).
    const terrain = {grassy: 'grassyterrain', electric: 'electricterrain', misty: 'mistyterrain', psychic: 'psychicterrain'}[input.field];
    if (terrain && !battle.field.terrain) {
      battle.field.terrain = terrain;
      battle.field.terrainState = {id: terrain, duration: 0};
      battle.add('-fieldstart', `move: ${Dex.conditions.get(terrain).name}`);
    } else if (PLACE_EFFECTS[input.field]) {
      battle.field.addPseudoWeather(placeEffect(input.field, battle.dex), 'debug');
      battle.add('-fieldstart', `PocketDex: ${input.field}`);
    }
    // O XP na hora (Battle Factory): quem está em campo junto lutou contra o adversário.
    if (input.exp) {
      game.exp = {mons: input.exp.mons.map(m => ({...m})), table: input.exp.table, share: input.exp.share ?? 0, given: {}, gained: {}};
      game.fought = {};
      markFought(game);
    }
    // A espécie do começo de cada Pokémon: mudou depois, é forma de batalha.
    game.startSpecies = battle.sides.map((side) => Object.fromEntries(side.pokemon.map((p) => [originalIndex(p), p.species.name])));
    const handle = nextHandle++;
    games.set(handle, game);
    return {handle, ...result(game)};
  },
  choose(handle, actions) {
    const game = games.get(handle);
    if (!game) throw new Error('Batalha encerrada');
    if (actions.some(a => a.kind === 'forfeit')) {
      game.battle.win(game.battle.sides[actions[0].kind === 'forfeit' ? 1 : 0]);
      return result(game);
    }
    if (actions.length !== game.teams.length) throw new Error('Faltam ações dos jogadores');
    const commands = actions.map((action, side) => {
      const choices = Array.isArray(action) ? action : [action];
      if (game.battle.sides[side].activeRequest?.wait) return command(game, side, choices[0]);
      if (choices.length !== game.battle.sides[side].active.length) throw new Error('Escolha uma ação para cada Pokémon ativo');
      const result = choices.map((a, slot) => command(game, side, a, slot));
      if (result.length === 1) return result[0];
      // Dupla/tripla: quem usa um item da Bolsa gasta o turno dele (como nos jogos); os outros escolhem normal.
      const items = {};
      result.forEach((r, slot) => { if (r && typeof r === 'object') items[slot] = r.item; });
      if (!Object.keys(items).length) return result.join(', ');
      const need = {};
      for (const a of Object.values(items)) need[a.item] = (need[a.item] ?? 0) + 1;
      if (Object.entries(need).some(([item, n]) => !(game.bags[side][item] >= n))) throw new Error('Item inválido');
      const revived = Object.values(items).filter(a => a.item === 'revive').map(a => a.index);
      if (new Set(revived).size !== revived.length) throw new Error('Item inválido');
      return {items, choice: result.map(r => (r && typeof r === 'object' ? 'pass' : r)).join(', ')};
    });
    // Validate both choices before committing the turn. Roll back the first
    // choice if the second is rejected, leaving the current request intact.
    for (let side = 0; side < game.teams.length; side++) {
      if (!commands[side]) continue;
      if (commands[side].items) {
        // O "pass" de quem usa o item vira a ação do item (antes dos golpes, como na única).
        const s = game.battle.sides[side], items = commands[side].items, pass = s.choosePass;
        game.pendingItems[side] = {...items};
        s.choosePass = function () {
          const index = this.getChoiceIndex(true);
          if (this.requestState !== 'move' || !items[index]) return pass.call(this);
          this.choice.actions.push({choice: 'event', event: 'PocketDexItem', pokemon: this.active[index], order: 102});
          return true;
        };
        let ok;
        try { ok = game.battle.choose(`p${side + 1}`, commands[side].choice); } finally { s.choosePass = pass; }
        if (!ok) {
          const error = s.choice.error || 'Ação inválida';
          for (const x of game.battle.sides) x.clearChoice();
          game.pendingItems = game.teams.map(() => null);
          throw new Error(error);
        }
        continue;
      }
      if (typeof commands[side] === 'object') {
        const s = game.battle.sides[side];
        game.pendingItems[side] = commands[side].item;
        s.clearChoice();
        s.choice.actions.push({choice: 'event', event: 'PocketDexItem', pokemon: s.active[0], order: 102});
        if (game.battle.allChoicesDone()) game.battle.commitChoices();
        continue;
      }
      if (!game.battle.choose(`p${side + 1}`, commands[side])) {
        const error = game.battle.sides[side].choice.error || 'Ação inválida';
        for (const s of game.battle.sides) s.clearChoice();
        game.pendingItems = [null, null];
        throw new Error(error);
      }
    }
    // XP dos derrubados (antes de marcar quem entrou agora) e quem lutou com quem.
    giveExp(game);
    markFought(game);
    return result(game);
  },
  inspect(handle) { return result(games.get(handle)); },
  dispose(handle) { games.get(handle)?.battle.destroy(); games.delete(handle); },
  move(slug) {
    if (id(slug) === 'recharge') return {slug: 'recharge', name: 'Recharge', type: 'normal', category: 'status', power: 0, accuracy: null, pp: 1, priority: 0};
    const m = Dex.moves.get(id(slug));
    return m.exists ? {slug: m.name.toLowerCase().replace(/[^a-z0-9]+/g, '-'), name: m.name, type: m.type.toLowerCase(), category: m.category.toLowerCase(), power: m.basePower, accuracy: m.accuracy === true ? null : m.accuracy, pp: m.pp, priority: m.priority} : null;
  },
  species(slug) { const s = speciesFor(slug); return {name: s.exists ? s.name : null}; },
  ability(slug) { if (id(slug) === 'embodyaspect') return {name: 'Embody Aspect', variants: ['Teal', 'Hearthflame', 'Wellspring', 'Cornerstone']}; const a = Dex.abilities.get(slug); return {name: a.exists ? a.name : null}; },
  item(slug) { const item = Dex.items.get(String(slug ?? '').replace(/--held$/, '')); return {name: item.exists ? item.name : null}; },
  nature(slug) { const n = Dex.natures.get(slug); return {name: n.exists ? n.name : null, plus: n.plus || null, minus: n.minus || null}; },
  audit(slugs) { return slugs.map(slug => {
    const move = Dex.moves.get(id(slug));
    return {slug, canonicalId: move.id, implemented: move.exists,
      ...(move.exists ? {accuracy: move.accuracy, category: move.category, type: move.type,
        basePower: move.basePower, priority: move.priority, target: move.target,
        status: move.status || null, volatileStatus: move.volatileStatus || null,
        secondaries: move.secondaries || (move.secondary ? [move.secondary] : []),
        boosts: move.boosts || null, self: move.self || null,
        terrain: move.terrain || null, weather: move.weather || null,
        sideCondition: move.sideCondition || null, pseudoWeather: move.pseudoWeather || null,
        selfSwitch: move.selfSwitch || null, forceSwitch: Boolean(move.forceSwitch),
        hooks: Object.keys(move).filter(key => typeof move[key] === 'function').sort(),
      } : {}),
    };
  }); },
};
globalThis.PocketDexSim = PocketDexSim;
