import {test} from 'node:test';
import assert from 'node:assert/strict';
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
