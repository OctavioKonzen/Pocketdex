// Shared offline simulator. Keep the Showdown callbacks intact: move effects
// cannot be faithfully represented by power and a short list of flags.
import {Battle, Dex, extractChannelMessages} from '@pkmn/sim';

const id = value => String(value ?? '').toLowerCase().replace(/--(physical|special)$/, '').replace(/[^a-z0-9]/g, '');
const title = value => String(value ?? '').replace(/(^|[- ])([a-z])/g, (_, space, letter) => space + letter.toUpperCase());
const formats = {...Dex.formats.get('gen9customgame'), id: 'pocketdex', name: 'PocketDex', mod: 'gen9', gameType: 'singles', ruleset: [], banlist: [], unbanlist: [], restricted: []};
const games = new Map();
let nextHandle = 1;

function originalIndex(pokemon) { return Number(pokemon.set.name.slice(2)); }
function setFor(mon, index) {
  const set = mon.set;
  if (!set || !Dex.species.get(set.species).exists) throw new Error(`Espécie desconhecida: ${set?.species}`);
  for (const move of set.moves) if (!Dex.moves.get(id(move)).exists) throw new Error(`Golpe desconhecido: ${move}`);
  return {...set, moves: set.moves.map(id), name: `pd${index}`, level: Math.min(50, Math.max(1, set.level || 50)), gigantamax: Boolean(mon.gmax), teraType: title(mon.teraType || set.teraType || '')};
}

function configure(game) {
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
    this.add('message', `${game.teams[pokemon.side.n][action.index].name}: ${action.item}`);
    if (action.item === 'revive') {
      target.fainted = false;
      target.faintQueued = false;
      target.hp = Math.max(1, Math.floor(target.maxhp / 2));
      target.side.pokemonLeft++;
      this.add('-heal', target, target.getHealth);
    } else this.heal(item, target, pokemon, {id: action.item, name: action.item, effectType: 'Item'});
    game.pendingItems[pokemon.side.n] = null;
  });
}

function snapshot(game) {
  const b = game.battle;
  return {
    turn: b.turn,
    winner: b.ended ? (b.winner === b.sides[0].name ? 0 : b.winner === b.sides[1].name ? 1 : -1) : null,
    weather: b.field.weather,
    terrain: b.field.terrain,
    bags: game.bags,
    sides: b.sides.map(side => ({
      active: originalIndex(side.active[0]),
      forceSwitch: Boolean(side.activeRequest?.forceSwitch?.[0]),
      wait: Boolean(side.activeRequest?.wait),
      trapped: Boolean(side.activeRequest?.active?.[0]?.trapped),
      revival: Boolean(side.slotConditions[side.active[0].position]?.revivalblessing),
      switchOptions: side.pokemon.filter(p => side.slotConditions[side.active[0].position]?.revivalblessing ? p.fainted : !p.fainted && p !== side.active[0] && (!side.activeRequest?.active?.[0]?.trapped || side.activeRequest?.forceSwitch)).map(originalIndex),
      request: side.activeRequest?.active?.[0] ?? null,
      used: {mega: side.pokemon.some(p => p.species.isMega), dmax: Boolean(side.dynamaxUsed), z: Boolean(side.zMoveUsed), tera: side.pokemon.some(p => p.terastallized)},
      team: [...side.pokemon].sort((a, c) => originalIndex(a) - originalIndex(c)).map(p => ({
        index: originalIndex(p), hp: p.hp, maxHp: p.maxhp, status: p.status, boosts: {...p.boosts},
        species: p.species.name, types: p.getTypes(), ability: Dex.abilities.get(p.ability).name,
        item: Dex.items.get(p.item).name, spe: p.getStat('spe'), tera: p.terastallized || '',
        dmax: p.volatiles.dynamax ? Math.max(0, p.volatiles.dynamax.duration ?? 3) : 0,
        moves: p.moveSlots.map(m => ({slug: m.id, name: m.move, pp: m.pp, maxPp: m.maxpp, disabled: m.disabled})),
      })),
    })),
  };
}

function result(game) {
  const lines = extractChannelMessages(game.battle.log.slice(game.cursor).join('\n'), [-1])[-1];
  game.cursor = game.battle.log.length;
  return {state: snapshot(game), log: lines, events: eventsFor(game, lines)};
}

function eventsFor(game, lines) {
  const events = [];
  const active = game.shownActive ??= [0, 0];
  const sideOf = value => value?.startsWith('p1') ? 0 : value?.startsWith('p2') ? 1 : -1;
  const label = side => ({side, name: game.teams[side][active[side]].name || game.teams[side][active[side]].set.species});
  const say = (key, ...args) => events.push({t: 'text', key, args});
  const health = value => Number(String(value).split(/[ /]/)[0]) || 0;
  for (const line of lines) {
    const [, kind, actor, value, extra] = line.split('|');
    const side = sideOf(actor);
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
    else if (kind === '-terastallize') events.push({t: 'tera', side, type: value.toLowerCase()});
    else if (kind === '-mega') {
      const mon = game.teams[side][active[side]];
      if (mon.mega) events.push({t: 'mega', side, id: mon.mega.id});
    } else if ((kind === '-start' || kind === '-end') && value === 'Dynamax') {
      const mon = game.teams[side][active[side]];
      events.push({t: 'dmax', side, on: kind === '-start', id: kind === '-start' ? mon.gmax || mon.id : mon.id});
    } else if (kind === '-weather' && !value.includes('[upkeep]')) {
      const weather = {RainDance: 'rain', SunnyDay: 'sun', Sandstorm: 'sand', Hail: 'hail', Snow: 'snow'}[value] || '';
      events.push({t: 'weather', weather});
    } else if (['-start', '-end', '-activate', '-sidestart', '-sideend', '-fieldstart', '-fieldend', '-boost', '-unboost', '-setboost', '-clearboost', '-clearallboost', '-prepare', 'cant', '-item', '-enditem', '-ability', '-transform'].includes(kind)) {
      const subject = side >= 0 ? label(side).name : 'Campo';
      const effect = value?.replace(/^move: /, '') || extra || '';
      say('sim', `${subject}: ${effect}${extra && ['-boost', '-unboost'].includes(kind) ? ` (${kind === '-unboost' ? '−' : '+'}${extra})` : ''}`);
    } else if (kind === 'message') say('sim', actor);
    else if (kind === 'win') say(actor === game.battle.sides[0].name ? 'win' : 'lose');
  }
  return events;
}

function command(game, sideIndex, action) {
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
  if (action.kind === 'item') {
    if (side.activeRequest?.forceSwitch) throw new Error('Escolha outro Pokémon');
    const target = side.pokemon.find(p => originalIndex(p) === action.index);
    if (!target || !(game.bags[sideIndex][action.item] > 0) || (action.item === 'revive' ? !target.fainted : target.fainted || target.hp >= target.maxhp)) throw new Error('Item inválido');
    return {item: action};
  }
  if (action.kind !== 'move' || side.activeRequest?.forceSwitch) throw new Error('Ação inválida');
  const mon = game.teams[sideIndex][originalIndex(side.active[0])];
  const mechanic = action.gimmick ?? mon.gimmick;
  const req = side.activeRequest?.active?.[0];
  const available = mechanic === 'mega' ? req?.canMegaEvo : mechanic === 'tera' ? req?.canTerastallize : mechanic === 'dmax' ? req?.canDynamax : mechanic === 'z' ? req?.canZMove?.[Math.max(0, action.index)] : false;
  const suffix = available && mechanic === mon.gimmick ? {mega: ' mega', tera: ' terastallize', dmax: ' dynamax', z: ' zmove'}[mechanic] : '';
  return `move ${action.index < 0 ? 1 : action.index + 1}${suffix}`;
}

export const PocketDexSim = {
  create(input) {
    const battle = new Battle({format: formats, seed: input.seed});
    const game = {battle, teams: input.teams, cursor: 0, pendingItems: [null, null], bags: [0, 1].map(() => ({potion: 3, 'super-potion': 2, 'hyper-potion': 1, revive: 1}))};
    input.teams.forEach((team, side) => battle.setPlayer(`p${side + 1}`, {name: side ? 'Adversário' : 'Você', team: team.map(setFor)}));
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
    const commands = actions.map((action, side) => command(game, side, action));
    // Validate both choices before committing the turn. Roll back the first
    // choice if the second is rejected, leaving the current request intact.
    for (let side = 0; side < 2; side++) {
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
        for (const s of game.battle.sides) s.clearChoice();
        throw new Error(game.battle.sides[side].choice.error || 'Ação inválida');
      }
    }
    return result(game);
  },
  inspect(handle) { return result(games.get(handle)); },
  dispose(handle) { games.get(handle)?.battle.destroy(); games.delete(handle); },
  move(slug) {
    const m = Dex.moves.get(id(slug));
    return m.exists ? {slug: m.name.toLowerCase().replace(/[^a-z0-9]+/g, '-'), name: m.name, type: m.type.toLowerCase(), category: m.category.toLowerCase(), power: m.basePower, accuracy: m.accuracy === true ? null : m.accuracy, pp: m.pp, priority: m.priority} : null;
  },
  species(slug) { const s = Dex.species.get(slug); return s.exists ? {name: s.name} : null; },
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
