import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {PocketDexSim as sim} from './engine.mjs';
const mon = (species, moves, extra = {}) => ({set: {species, moves, level: 50}, ...extra});
const create = (team, foe) => sim.create({teams: [team, foe], seed: [1, 2, 3, 4]});
const move = index => ({kind: 'move', index, gimmick: ''});

test('U-turn pauses for replacement and continues the queued enemy attack', () => {
  const game = create([mon('Scizor', ['uturn']), mon('Pikachu', ['thunderbolt'])], [mon('Blissey', ['tackle'])]);
  try {
    const first = sim.choose(game.handle, [move(0), move(0)]);
    assert.equal(first.state.sides[0].forceSwitch, true);
    assert.equal(first.state.sides[1].wait, true);
    assert.equal(first.state.sides[0].team[0].hp, first.state.sides[0].team[0].maxHp);
    const next = sim.choose(game.handle, [{kind: 'switch', index: 1}, {kind: 'wait'}]);
    assert.equal(next.state.sides[0].active, 1);
    assert.equal(next.state.turn, 2);
    assert.ok(next.state.sides[0].team[1].hp < next.state.sides[0].team[1].maxHp);
  } finally { sim.dispose(game.handle); }
});

test('Protect blocks an attack without inflicting damage', () => {
  const game = create([mon('Pikachu', ['protect'])], [mon('Blissey', ['tackle'])]);
  try {
    const next = sim.choose(game.handle, [move(0), move(0)]);
    assert.equal(next.state.sides[0].team[0].hp, next.state.sides[0].team[0].maxHp);
    assert.ok(next.log.some(line => line.includes('Protect')));
  } finally { sim.dispose(game.handle); }
});

test('Seismic Toss inflicts level-dependent fixed damage', () => {
  const game = create([mon('Blissey', ['seismictoss'])], [mon('Snorlax', ['splash'])]);
  try {
    const next = sim.choose(game.handle, [move(0), move(0)]);
    assert.equal(next.state.sides[1].team[0].maxHp - next.state.sides[1].team[0].hp, 50);
  } finally { sim.dispose(game.handle); }
});

test('Stealth Rock damages the replacement according to its Rock weakness', () => {
  const game = create([mon('Blissey', ['stealthrock', 'splash'])], [mon('Snorlax', ['splash']), mon('Charizard', ['splash'])]);
  try {
    sim.choose(game.handle, [move(0), move(0)]);
    const next = sim.choose(game.handle, [move(1), {kind: 'switch', index: 1}]);
    const target = next.state.sides[1].team[1];
    assert.equal(target.maxHp - target.hp, Math.floor(target.maxHp / 2));
  } finally { sim.dispose(game.handle); }
});

test('Electric Terrain boosts grounded Electric attacks and does not boost airborne attackers', () => {
  const attack = (species, terrain) => {
    const game = create([mon(species, ['electricterrain', 'thunderbolt'])], [mon('Blissey', ['splash'])]);
    try {
      if (terrain) sim.choose(game.handle, [move(0), move(0)]);
      const next = sim.choose(game.handle, [move(1), move(0)]);
      return next.state.sides[1].team[0].maxHp - next.state.sides[1].team[0].hp;
    } finally { sim.dispose(game.handle); }
  };
  assert.ok(attack('Pikachu', true) > attack('Pikachu', false));
  // Use identical PRNG advancement for the control; setup moves consume no
  // damage roll, so airborne attackers receive exactly the same damage roll.
  assert.equal(attack('Zapdos', true), attack('Zapdos', false));
});

test('Misty Terrain prevents poisoning a grounded target', () => {
  const game = create([mon('Pikachu', ['mistyterrain', 'splash'])], [mon('Blissey', ['toxic'])]);
  try {
    const next = sim.choose(game.handle, [move(0), move(0)]);
    assert.equal(next.state.sides[0].team[0].status, '');
  } finally { sim.dispose(game.handle); }
});

test('Guaranteed secondary status respects the target type immunity', () => {
  for (const [species, expected] of [['Blissey', 'par'], ['Pikachu', '']]) {
    const game = create([mon('Jirachi', ['nuzzle'])], [mon(species, ['splash'])]);
    try {
      const next = sim.choose(game.handle, [move(0), move(0)]);
      assert.equal(next.state.sides[1].team[0].status, expected);
    } finally { sim.dispose(game.handle); }
  }
});

test('Move accuracy rolls and secondary chance are separate, seeded events', () => {
  let hits = 0;
  let burns = 0;
  const trials = 256;
  for (let n = 0; n < trials; n++) {
    const game = sim.create({teams: [[mon('Charmander', ['inferno'])], [mon('Blissey', ['splash'])]], seed: [n, 2, 3, 4]});
    try {
      const next = sim.choose(game.handle, [move(0), move(0)]);
      const target = next.state.sides[1].team[0];
      if (target.hp < target.maxHp) hits++;
      if (target.status === 'brn') burns++;
    } finally { sim.dispose(game.handle); }
  }
  assert.ok(hits > trials * 0.35 && hits < trials * 0.65, `Inferno 50% accuracy: ${hits}/${trials}`);
  assert.equal(burns, hits, 'Inferno burns on every successful hit');
});

test('Dynamax, Mega and Terastal have separate team budgets', () => {
  const game = create([
    mon('Charizard', ['flamethrower'], {gimmick: 'mega'}),
    mon('Pikachu', ['thunderbolt'], {gimmick: 'dmax'}),
    mon('Blissey', ['splash'], {gimmick: 'tera', teraType: 'water'}),
  ], [mon('Blissey', ['splash'])]);
  // Mega requires the respective stone; missing stones must not expose it.
  try {
    assert.equal(game.state.sides[0].request.canMegaEvo, undefined);
    assert.equal(game.state.sides[0].used.dmax, false);
    sim.choose(game.handle, [{kind: 'switch', index: 1}, move(0)]);
    const max = sim.choose(game.handle, [{kind: 'move', index: 0, gimmick: 'dmax'}, move(0)]);
    assert.equal(max.state.sides[0].used.dmax, true);
    assert.equal(max.state.sides[0].team[1].dmax > 0, true);
    assert.equal(max.state.sides[0].team[1].maxHp, game.state.sides[0].team[1].maxHp * 2);
    sim.choose(game.handle, [{kind: 'switch', index: 2}, move(0)]);
    const tera = sim.choose(game.handle, [{kind: 'move', index: 0, gimmick: 'tera'}, move(0)]);
    assert.equal(tera.state.sides[0].used.dmax, true);
    assert.equal(tera.state.sides[0].used.tera, true);
  } finally { sim.dispose(game.handle); }
});

test('Bag healing spends a turn and the opponent still attacks', () => {
  const game = create([mon('Blissey', ['splash'])], [mon('Snorlax', ['tackle'])]);
  try {
    const hurt = sim.choose(game.handle, [move(0), move(0)]);
    const healed = sim.choose(game.handle, [{kind: 'item', item: 'hyper-potion', index: 0}, move(0)]);
    assert.equal(healed.state.bags[0]['hyper-potion'], 0);
    assert.equal(healed.state.turn, 3);
    assert.ok(healed.state.sides[0].team[0].hp >= hurt.state.sides[0].team[0].hp);
    assert.ok(healed.state.sides[0].team[0].hp < healed.state.sides[0].team[0].maxHp);
  } finally { sim.dispose(game.handle); }
});

test('Shadow moves are excluded from battle teams', () => {
  assert.equal(sim.move('shadow-rush'), null);
  assert.throws(() => create([mon('Mew', ['shadow-rush'])], [mon('Blissey', ['splash'])]), /Golpe desconhecido/);
});

test('Toxic Spikes layers poison grounded replacements and Poison types remove them', () => {
  for (const layers of [1, 2]) {
    const game = create([mon('Mew', ['toxicspikes', 'splash'])], [mon('Blissey', ['splash']), mon('Snorlax', ['splash']), mon('Muk', ['splash']), mon('Pikachu', ['splash'])]);
    try {
      for (let i = 0; i < layers; i++) sim.choose(game.handle, [move(0), move(0)]);
      let next = sim.choose(game.handle, [move(1), {kind: 'switch', index: 1}]);
      assert.equal(next.state.sides[1].team[1].status, layers === 1 ? 'psn' : 'tox');
      sim.choose(game.handle, [move(1), {kind: 'switch', index: 2}]);
      next = sim.choose(game.handle, [move(1), {kind: 'switch', index: 3}]);
      assert.equal(next.state.sides[1].team[3].status, '');
    } finally { sim.dispose(game.handle); }
  }
});

test('Toxic Spikes respects airborne targets, Steel and Heavy-Duty Boots', () => {
  for (const [species, ability, item] of [['Charizard', 'Blaze', ''], ['Gengar', 'Levitate', ''], ['Scizor', 'Technician', ''], ['Snorlax', 'Immunity', ''], ['Pikachu', 'Static', 'Heavy-Duty Boots']]) {
    const target = mon(species, ['splash']);
    Object.assign(target.set, {ability, item});
    const game = create([mon('Mew', ['toxicspikes', 'splash'])], [mon('Blissey', ['splash']), target]);
    try {
      sim.choose(game.handle, [move(0), move(0)]);
      const next = sim.choose(game.handle, [move(1), {kind: 'switch', index: 1}]);
      assert.equal(next.state.sides[1].team[1].status, '', `${species}: ${ability}/${item}`);
    } finally { sim.dispose(game.handle); }
  }
});

test('All 25 Natures apply their exact raised and lowered stats', () => {
  const names = ['Hardy','Lonely','Brave','Adamant','Naughty','Bold','Docile','Relaxed','Impish','Lax','Timid','Hasty','Serious','Jolly','Naive','Modest','Mild','Quiet','Bashful','Rash','Calm','Gentle','Sassy','Careful','Quirky'];
  const baseGame = create([mon('Mew', ['splash'])], [mon('Blissey', ['splash'])]);
  const base = baseGame.state.sides[0].team[0].stats;
  sim.dispose(baseGame.handle);
  for (const name of names) {
    const pokemon = mon('Mew', ['splash']); pokemon.set.nature = name;
    const game = create([pokemon], [mon('Blissey', ['splash'])]);
    try {
      const nature = sim.nature(name);
      for (const key of ['atk', 'def', 'spa', 'spd', 'spe']) {
        const multiplier = nature.plus === key ? 1.1 : nature.minus === key ? 0.9 : 1;
        assert.equal(game.state.sides[0].team[0].stats[key], Math.floor(base[key] * multiplier), `${name}/${key}`);
      }
    } finally { sim.dispose(game.handle); }
  }
});

test('Hidden abilities execute battle effects: Contrary and Magic Bounce', () => {
  const serperior = mon('Serperior', ['leafstorm']); serperior.set.ability = 'Contrary';
  let game = create([serperior], [mon('Blissey', ['splash'])]);
  try {
    const next = sim.choose(game.handle, [move(0), move(0)]);
    assert.equal(next.state.sides[0].team[0].boosts.spa, 2);
  } finally { sim.dispose(game.handle); }
  const espeon = mon('Espeon', ['splash']); espeon.set.ability = 'Magic Bounce';
  game = create([mon('Mew', ['toxic'])], [espeon]);
  try {
    const next = sim.choose(game.handle, [move(0), move(0)]);
    assert.equal(next.state.sides[0].team[0].status, 'tox');
    assert.equal(next.state.sides[1].team[0].status, '');
  } finally { sim.dispose(game.handle); }
});

test('Max Lightning creates Electric Terrain and G-Max Wildfire deals residual damage', () => {
  for (const [species, slug, gmax, field] of [['Pikachu', 'thunderbolt', null, 'electricterrain'], ['Charizard', 'flamethrower', 10201, null]]) {
    const game = create([mon(species, [slug], {gimmick: 'dmax', gmax})], [mon('Blissey', ['splash'])]);
    try {
      const next = sim.choose(game.handle, [{kind: 'move', index: 0, gimmick: 'dmax'}, move(0)]);
      if (field) assert.equal(next.state.terrain, field);
      else {
        assert.ok(next.log.some(line => line.includes('G-Max Wildfire')));
        const damage = next.log.filter(line => line.startsWith('|-damage|'));
        assert.equal(damage.length, 2, 'attack and residual Wildfire damage');
      }
    } finally { sim.dispose(game.handle); }
  }
});

test('Z-status moves keep their original effect and apply their Z bonus once', () => {
  const pokemon = mon('Mew', ['toxicspikes'], {gimmick: 'z'}); pokemon.set.item = 'Poisonium Z';
  const game = create([pokemon], [mon('Blissey', ['splash']), mon('Snorlax', ['splash'])]);
  try {
    let next = sim.choose(game.handle, [{kind: 'move', index: 0, gimmick: 'z'}, move(0)]);
    assert.equal(next.state.sides[0].team[0].boosts.def, 1);
    assert.equal(next.state.sides[0].used.z, true);
    next = sim.choose(game.handle, [move(0), {kind: 'switch', index: 1}]);
    assert.equal(next.state.sides[1].team[1].status, 'psn');
    assert.equal(next.state.sides[0].team[0].boosts.def, 1);
  } finally { sim.dispose(game.handle); }
});

test('Mega stone changes species and ability before attacking', () => {
  const pokemon = mon('Charizard', ['flamethrower'], {gimmick: 'mega', mega: {id: 10034}}); pokemon.set.item = 'Charizardite Y';
  const game = create([pokemon], [mon('Blissey', ['splash'])]);
  try {
    const next = sim.choose(game.handle, [{kind: 'move', index: 0, gimmick: 'mega'}, move(0)]);
    assert.equal(next.state.sides[0].team[0].species, 'Charizard-Mega-Y');
    assert.equal(next.state.sides[0].team[0].ability, 'Drought');
    assert.equal(next.state.weather, 'sunnyday');
    assert.equal(next.state.sides[0].used.mega, true);
  } finally { sim.dispose(game.handle); }
});

test('Every supported database move runs offline without callback errors', () => {
  const records = JSON.parse(readFileSync(new URL('../../assets/database/moves.json', import.meta.url)));
  let checked = 0;
  for (const record of records) {
    if (!sim.move(record.name)) continue; // Only the 18 excluded XD moves.
    const game = create([mon('Mew', [record.name]), mon('Mew', ['splash'])], [mon('Blissey', ['splash']), mon('Snorlax', ['splash'])]);
    try {
      let state = game.state;
      for (let turn = 0; turn < 3 && state.winner == null; turn++) {
        const actions = state.sides.map(side => {
          if (side.wait) return {kind: 'wait'};
          if (side.forceSwitch) return {kind: 'switch', index: side.switchOptions[0]};
          const index = side.request?.moves?.findIndex(m => !m.disabled && m.pp > 0) ?? 0;
          return move(index);
        });
        state = sim.choose(game.handle, actions).state;
        for (const side of state.sides) for (const pokemon of side.team) {
          assert.ok(Number.isFinite(pokemon.hp) && pokemon.hp >= 0 && pokemon.hp <= pokemon.maxHp, record.name);
        }
      }
      checked++;
    } catch (error) { throw new Error(`${record.name}: ${error.message}`, {cause: error}); }
    finally { sim.dispose(game.handle); }
  }
  assert.equal(checked, 919);
});

test('Types and abilities block attacks; Mold Breaker bypasses Levitate', () => {
  for (const [slug, species, ability, sourceAbility, immune] of [
    ['thunderbolt','Garchomp','Rough Skin','Synchronize',true],
    ['tackle','Gengar','Cursed Body','Synchronize',true],
    ['psychic','Umbreon','Synchronize','Synchronize',true],
    ['earthquake','Gengar','Levitate','Synchronize',true],
    ['earthquake','Gengar','Levitate','Mold Breaker',false],
    ['flamethrower','Heatran','Flash Fire','Synchronize',true],
    ['surf','Vaporeon','Water Absorb','Synchronize',true],
    ['thunderbolt','Jolteon','Volt Absorb','Synchronize',true],
    ['shadowball','Shedinja','Wonder Guard','Synchronize',false],
    ['tackle','Shedinja','Wonder Guard','Synchronize',true],
  ]) {
    const attacker = mon('Mew', [slug]); attacker.set.ability = sourceAbility;
    const target = mon(species, ['splash']); target.set.ability = ability;
    const game = create([attacker], [target]);
    try {
      const next = sim.choose(game.handle, [move(0), move(0)]);
      const pokemon = next.state.sides[1].team[0];
      assert.equal(pokemon.hp === pokemon.maxHp, immune, `${slug}/${species}/${ability}/${sourceAbility}`);
    } finally { sim.dispose(game.handle); }
  }
});

test('Aura Guard halves contact damage but Long Reach prevents contact', () => {
  const damage = (ability, sourceAbility) => {
    const attacker = mon('Mew', ['tackle']); attacker.set.ability = sourceAbility;
    const target = mon('Blissey', ['splash']); target.set.ability = ability;
    const game = create([attacker], [target]);
    try { const next = sim.choose(game.handle, [move(0), move(0)]); const p = next.state.sides[1].team[0]; return p.maxHp - p.hp; }
    finally { sim.dispose(game.handle); }
  };
  const regular = damage('Natural Cure', 'Synchronize');
  assert.ok(damage('Aura Guard', 'Synchronize') <= Math.ceil(regular / 2));
  assert.equal(damage('Aura Guard', 'Long Reach'), regular);
});

test('All main-series database abilities execute without callback errors', () => {
  const abilities = JSON.parse(readFileSync(new URL('../../assets/database/abilities.json', import.meta.url))).filter(a => a.is_main_series);
  for (const record of abilities) {
    const pokemon = mon('Mew', ['thunderbolt']); pokemon.set.ability = sim.ability(record.name).name;
    assert.ok(pokemon.set.ability, record.name);
    const game = create([pokemon], [mon('Blissey', ['tackle'])]);
    try { sim.choose(game.handle, [move(0), move(0)]); }
    catch (error) { throw new Error(`${record.name}: ${error.message}`, {cause: error}); }
    finally { sim.dispose(game.handle); }
  }
  assert.equal(abilities.length, 314);
});

test('Recharge is exposed as a safe action and consumes the next turn', () => {
  const game = create([mon('Mew', ['hyperbeam'])], [mon('Blissey', ['splash'])]);
  try {
    const first = sim.choose(game.handle, [move(0), move(0)]);
    assert.equal(first.state.sides[0].request.moves[0].id, 'recharge');
    assert.equal(sim.move('recharge').category, 'status');
    const next = sim.choose(game.handle, [move(0), move(0)]);
    assert.equal(next.state.sides[0].request.moves[0].id, 'hyperbeam');
    assert.equal(next.state.sides[1].team[0].hp, first.state.sides[1].team[0].hp);
  } finally { sim.dispose(game.handle); }
});

test('Every database form resolves to a simulator species instead of a generic fallback', () => {
  const records = JSON.parse(readFileSync(new URL('../../assets/database/pokemon.json', import.meta.url)));
  for (const record of records) assert.ok(sim.species(record.name).name, record.name);
});
