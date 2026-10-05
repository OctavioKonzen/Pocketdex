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
      pass: !p || p.fainted && !forced, trapped: Boolean(request?.trapped),
      canShift: game.battle.gameType === 'triples' && slot !== 1 && !forced && !side.activeRequest?.wait && Boolean(p?.hp),
      switchOptions: side.pokemon.filter(mon => revival ? mon.fainted : !mon.fainted && !side.active.includes(mon) && (!request?.trapped || forced)).map(originalIndex),
      request: request ? {...request, moves: request.moves.map(m => ({...m, targets: targetsFor(game, p, m.id, m.target)}))} : null};
  });
}
function setFor(mon, index) {
  const set = mon.set;
  if (!set || !speciesFor(set.species).exists) throw new Error(`Espécie desconhecida: ${set?.species}`);
  for (const move of set.moves) if (!Dex.moves.get(id(move)).exists) throw new Error(`Golpe desconhecido: ${move}`);
  const aspect = id(set.species).includes('cornerstone') ? 'cornerstone' : id(set.species).includes('hearthflame') ? 'hearthflame' : id(set.species).includes('wellspring') ? 'wellspring' : 'teal';
  const ability = id(set.ability) === 'embodyaspect' ? `Embody Aspect (${aspect})` : set.ability;
  return {...set, species: speciesFor(set.species).name, ability, moves: set.moves.map(id), name: `pd${index}`, level: Math.min(50, Math.max(1, set.level || 50)), gigantamax: Boolean(mon.gmax), teraType: title(mon.teraType || set.teraType || '')};
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
    }
  }
  game.battle.makeRequest('move');
  game.battle.onEvent('PocketDexItem', game.battle.format, function (pokemon) {
    const action = game.pendingItems[pokemon.side.n];
    if (!action) return;
    const target = pokemon.side.pokemon.find(p => originalIndex(p) === action.index);
    const item = {potion: 20, 'super-potion': 60, 'hyper-potion': 120, revive: 0}[action.item];
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
    } else this.heal(item, target, pokemon, {id: action.item, name: action.item, effectType: 'Item'});
    this.add('pocketdexheal', target, action.item, target.hp - previousHp);
    game.pendingItems[pokemon.side.n] = null;
  });
}

function snapshot(game) {
  const b = game.battle;
  return {
    turn: b.turn,
    winner: b.ended ? (b.winner === b.sides[0].name || b.winner === `${b.sides[0].name} & ${b.sides[2]?.name}` ? 0 : b.winner ? 1 : -1) : null,
    weather: b.field.weather,
    terrain: b.field.terrain,
    mode: b.gameType,
    bags: game.bags,
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
      used: {mega: game.used[side.n].mega, dmax: Boolean(side.dynamaxUsed), z: Boolean(side.zMoveUsed), tera: game.used[side.n].tera},
      team: [...side.pokemon].sort((a, c) => originalIndex(a) - originalIndex(c)).map(p => ({
        index: originalIndex(p), hp: p.hp, maxHp: p.maxhp, status: p.status, boosts: {...p.boosts},
        species: p.species.name, types: p.getTypes(), ability: Dex.abilities.get(p.ability).name,
        item: Dex.items.get(p.item).name, stats: {...p.baseStoredStats}, spe: p.baseStoredStats.spe, actionSpeed: p.getActionSpeed(), tera: p.terastallized || '',
        dmax: p.volatiles.dynamax ? Math.max(0, p.volatiles.dynamax.duration ?? 3) : 0,
        moves: p.moveSlots.map(m => ({slug: m.id, name: m.move, pp: m.pp, maxPp: m.maxpp, disabled: m.disabled})),
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
  for (const line of lines) {
    const [, kind, actor, value, extra] = line.split('|');
    const side = sideOf(actor);
    const actorIndex = Number(actor?.split(': ')[1]?.slice(2));
    actorSide = side; actorPokemon = actorIndex;
    if (kind === 'switch' || kind === 'drag') {
      const index = Number(actor.split(': ')[1]?.slice(2));
      if (!Number.isInteger(index)) continue;
      active[side] = index;
      events.push({t: 'switch', side, index});
      say(side ? 'foeSent' : 'go', label(side));
    } else if (kind === 'move') {
      const m = PocketDexSim.move(value);
      if (m) events.push({t: 'attack', side, type: m.type, category: m.category, slug: m.slug});
      say('used', label(side), value);
    } else if (kind === '-damage' || kind === '-heal') {
      const index = Number(actor.split(': ')[1]?.slice(2));
      if (index !== active[side] && Number.isInteger(index)) events.push({t: 'heal', side, index, hp: health(value)});
      else events.push({t: 'hp', side, hp: health(value)});
    } else if (kind === 'faint') {
      events.push({t: 'faint', side});
      say('fainted', label(side));
    } else if (kind === '-status') {
      events.push({t: 'status', side, status: value});
      say({brn: 'burned', par: 'paralyzed', psn: 'poisoned', tox: 'badlyPoisoned', slp: 'fellAsleep', frz: 'frozen'}[value] || 'failed', label(side));
    } else if (kind === '-curestatus') events.push({t: 'status', side, status: ''});
    else if (kind === '-miss') { events.push({t: 'miss', side}); say('missed', label(side)); }
    else if (kind === '-immune') say('noEffect', label(side));
    else if (kind === '-crit') say('crit');
    else if (kind === '-supereffective') say('super');
    else if (kind === '-resisted') say('weak');
    else if (kind === '-fail') say('failed', label(side));
    else if (kind === '-hitcount') say('hits', Number(value));
    else if (kind === '-terastallize') { game.used[side].tera = true; events.push({t: 'tera', side, type: value.toLowerCase()}); }
    else if (kind === '-mega') {
      game.used[side].mega = true;
      const mon = game.teams[side][active[side]];
      if (mon.mega) events.push({t: 'mega', side, id: mon.mega.id});
    } else if ((kind === '-start' || kind === '-end') && value === 'Dynamax') {
      const mon = game.teams[side][active[side]];
      events.push({t: 'dmax', side, on: kind === '-start', id: kind === '-start' ? mon.gmax || mon.id : mon.id});
    } else if (kind === '-weather' && value !== '[upkeep]') {
      const weather = {RainDance: 'rain', SunnyDay: 'sun', Sandstorm: 'sand', Hail: 'hail', Snow: 'snow'}[actor] || '';
      events.push({t: 'weather', weather});
      if (actor === 'ShadowSky') say('sim', 'O céu ficou sombrio!');
    } else if (['-start', '-end', '-activate', '-sidestart', '-sideend', '-fieldstart', '-fieldend', '-boost', '-unboost', '-setboost', '-clearboost', '-clearallboost', '-prepare', 'cant', '-item', '-enditem', '-ability', '-transform'].includes(kind)) {
      const subject = side >= 0 ? label(side).name : 'Campo';
      const effect = value?.replace(/^move: /, '') || extra || '';
      say('sim', `${subject}: ${effect}${extra && ['-boost', '-unboost'].includes(kind) ? ` (${kind === '-unboost' ? '−' : '+'}${extra})` : ''}`);
    } else if (kind === 'pocketdexitem' || kind === 'pocketdexheal') {
      const index = Number(actor.split(': ')[1]?.slice(2));
      const target = {side, name: game.teams[side][index].name || game.teams[side][index].set.species};
      if (kind === 'pocketdexitem') say('usedItem', target, {potion: 'Potion', 'super-potion': 'Super Potion', 'hyper-potion': 'Hyper Potion', revive: 'Revive'}[value]);
      else if (value === 'revive') say('revived', target);
      else say('healed', target, Number(extra));
    } else if (kind === 'message') say('sim', actor);
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
    if (game.battle.gameType !== 'singles') throw new Error('Use os itens equipados neste formato');
    const target = side.pokemon.find(p => originalIndex(p) === action.index);
    if (!target || !(game.bags[sideIndex][action.item] > 0) || (action.item === 'revive' ? !target.fainted : target.fainted || target.hp >= target.maxhp)) throw new Error('Item inválido');
    return {item: action};
  }
  if (action.kind !== 'move' || side.activeRequest?.forceSwitch?.[slot]) throw new Error('Ação inválida');
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
  return power * source.getStat(attack) / Math.max(1, target.getStat(defense)) * 2 ** Dex.getEffectiveness(move.type, target) * (source.hasType(move.type) ? 1.5 : 1) * (move.accuracy === true ? 1 : (move.accuracy || 100) / 100);
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
    const bench = slot.switchOptions.filter(index => !reserved.has(index));
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
      if (transformed) best.action.target = targetsFor(game, source, transformed)[0]?.loc || 0;
    }
    return best.action;
  });
}

export const PocketDexSim = {
  targets(handle, side, slot, index, gimmick = '') {
    const game = games.get(handle), pokemon = game?.battle.sides[side]?.active[slot];
    if (!pokemon) throw new Error('Pokémon inválido');
    const req = pokemon.side.activeRequest?.active?.[slot];
    const base = Dex.moves.get(req?.moves[index]?.id);
    const transformed = gimmick === 'dmax' || pokemon.volatiles.dynamax ? game.battle.actions.getMaxMove(base, pokemon) : gimmick === 'z' ? req?.canZMove?.[index]?.move : null;
    const move = transformed ? Dex.moves.get(transformed) : base;
    return {targets: targetsFor(game, pokemon, move.id), automatic: !game.battle.actions.targetTypeChoices(move.target)};
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
    const battle = new Battle({format: {...formats, gameType: mode, playerCount: mode === 'multi' ? 4 : 2}, seed: input.seed});
    const game = {battle, teams: input.teams, controllers: input.controllers, cursor: 0, used: input.teams.map(() => ({mega: false, tera: false})), pendingItems: input.teams.map(() => null), bags: input.teams.map(() => ({potion: 3, 'super-potion': 2, 'hyper-potion': 1, revive: 1}))};
    input.teams.forEach((team, side) => battle.setPlayer(`p${side + 1}`, {name: ['Você', 'Adversário', 'Aliado', 'Aliado adversário'][side], team: team.map(setFor)}));
    configure(game);
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
      return result.length === 1 ? result[0] : result.join(', ');
    });
    // Validate both choices before committing the turn. Roll back the first
    // choice if the second is rejected, leaving the current request intact.
    for (let side = 0; side < game.teams.length; side++) {
      if (!commands[side]) continue;
      if (typeof commands[side] === 'object') {
        const s = game.battle.sides[side];
        game.pendingItems[side] = commands[side].item;
        s.clearChoice();
        s.choice.actions.push({choice: 'event', event: 'PocketDexItem', pokemon: s.active[0], order: 102});
        if (game.battle.sides.every(s => s.isChoiceDone())) game.battle.commitDecisions();
        continue;
      }
      if (!game.battle.choose(`p${side + 1}`, commands[side])) {
        const error = game.battle.sides[side].choice.error || 'Ação inválida';
        for (const s of game.battle.sides) s.clearChoice();
        game.pendingItems = [null, null];
        throw new Error(error);
      }
    }
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
