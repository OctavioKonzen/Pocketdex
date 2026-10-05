// Compare every database move with a standalone, unwrapped Showdown battle.
// This verifies our integration, not the correctness of the upstream itself.
import {Battle, Dex, extractChannelMessages} from '@pkmn/sim';
import {readFileSync, writeFileSync, mkdirSync} from 'node:fs';
import assert from 'node:assert/strict';
import {PocketDexSim as sim} from './engine.mjs';

const canonical = value => Array.isArray(value) ? value.map(canonical) : value && typeof value === 'object' ? Object.fromEntries(Object.keys(value).sort().map(key => [key, canonical(value[key])])) : value;
const serialize = value => JSON.stringify(canonical(value));
export function comparable(state) {
  return {turn: state.turn, winner: state.winner, weather: state.weather, terrain: state.terrain,
    sides: state.sides.map(side => ({active: side.active, forceSwitch: side.forceSwitch, wait: side.wait,
      team: side.team.map(p => ({hp: p.hp, maxHp: p.maxHp, status: p.status, boosts: p.boosts,
        species: p.species, types: p.types, ability: p.ability, item: p.item, tera: p.tera, dmax: p.dmax,
        moves: p.moves.map(m => ({slug: m.slug, pp: m.pp, maxPp: m.maxPp, disabled: Boolean(m.disabled)}))}))}))};
}
const indexOf = p => Number(p.set.name.slice(2));
function referenceState(b) {
  return {turn: b.turn, winner: b.ended ? b.winner === 'Você' ? 0 : b.winner === 'Adversário' ? 1 : -1 : null,
    weather: b.field.weather, terrain: b.field.terrain,
    sides: b.sides.map(side => ({active: indexOf(side.active[0]),
      forceSwitch: Boolean(side.activeRequest?.forceSwitch?.[0]), wait: Boolean(side.activeRequest?.wait),
      team: [...side.pokemon].sort((a, c) => indexOf(a) - indexOf(c)).map(p => ({hp: p.hp, maxHp: p.maxhp,
        status: p.status, boosts: {...p.boosts}, species: p.species.name, types: p.getTypes(),
        ability: Dex.abilities.get(p.ability).name, item: Dex.items.get(p.item).name,
        tera: p.terastallized || '', dmax: p.volatiles.dynamax ? p.volatiles.dynamax.duration ?? 3 : 0,
        moves: p.moveSlots.map(m => ({slug: m.id, pp: m.pp, maxPp: m.maxpp, disabled: Boolean(m.disabled)}))}))}))};
}
const format = {...Dex.formats.get('gen9customgame'), id: 'reference', name: 'Reference', mod: 'gen9', gameType: 'singles', ruleset: [], banlist: [], unbanlist: [], restricted: []};
function reference(input) {
  const b = new Battle({format, seed: input.seed});
  input.teams.forEach((team, side) => b.setPlayer(`p${side + 1}`, {name: side ? 'Adversário' : 'Você', team: team.map((m, index) => ({...m.set, name: `pd${index}`, gigantamax: Boolean(m.gmax)}))}));
  for (const side of b.sides) {
    side.dynamaxUsed = false;
    side.canDynamaxNow = () => !side.dynamaxUsed;
    for (const p of side.pokemon) for (const slot of p.moveSlots) slot.pp = slot.maxpp = Dex.moves.get(slot.id).pp;
  }
  b.makeRequest('move');
  return b;
}

const baseMove = (type, category) => Dex.moves.all().find(m => m.exists && !m.isZ && !m.isMax && !m.isNonstandard && m.type === type && m.category === category && m.basePower > 0 && m.accuracy === 100 && !m.selfSwitch && !m.selfdestruct && !m.self)?.id;
function specimen(record) {
  const slug = record.name.replace(/--(physical|special)$/, '').replace(/[^a-z0-9]/g, '');
  const m = Dex.moves.get(slug);
  const category = record.name.endsWith('--special') || record.category === 'special' ? 'Special' : 'Physical';
  const specialSpecies = {aurawheel: 'Morpeko', darkvoid: 'Darkrai', hyperspacefury: 'Hoopa-Unbound', burnup: 'Charizard', doubleshock: 'Pikachu', ivycudgel: 'Ogerpon', ragingbull: 'Tauros-Paldea-Blaze'};
  const held = {fling: 'Flame Orb', naturalgift: 'Liechi Berry', stuffcheeks: 'Liechi Berry', teatime: 'Liechi Berry', bestow: 'Leftovers'};
  const mon = {name: record.name, set: {species: specialSpecies[slug] || 'Mew', moves: [slug], level: 50, ability: 'No Ability', item: held[slug] || ''}};
  if (m.isZ) {
    const item = Dex.items.get(m.isZ);
    mon.set.species = item.itemUser?.[0] || 'Mew';
    mon.set.item = item.name;
    mon.set.moves = [item.zMoveFrom || baseMove(m.type, category)];
    mon.gimmick = 'z';
  } else if (m.isMax) {
    mon.set.species = typeof m.isMax === 'string' ? m.isMax : 'Mew';
    mon.set.moves = [m.id === 'maxguard' ? 'Protect' : baseMove(m.type, category)];
    mon.gimmick = 'dmax';
    if (typeof m.isMax === 'string') mon.gmax = 1;
  }
  assert.ok(mon.set.moves[0], `Missing base move: ${record.name}`);
  return mon;
}
function actionsFor(b, gimmick, phase, scenario) {
  return b.sides.map((side, sideIndex) => {
    const request = side.activeRequest;
    if (request.wait) return {kind: 'wait'};
    if (request.forceSwitch) {
      const revival = side.slotConditions[side.active[0].position]?.revivalblessing;
      const p = side.pokemon.find(p => revival ? p.fainted : !p.fainted && p !== side.active[0]);
      return {kind: 'switch', index: indexOf(p)};
    }
    if (sideIndex === 1 && scenario === 'switch' && phase === 1 && !request.active?.[0]?.trapped) {
      const replacement = side.pokemon.find(p => !p.fainted && p !== side.active[0]);
      if (replacement) return {kind: 'switch', index: indexOf(replacement)};
    }
    const moves = request.active?.[0]?.moves;
    const index = moves?.findIndex(m => m.pp > 0 && !m.disabled) ?? 0;
    return {kind: 'move', index: Math.max(0, index), gimmick: sideIndex === 0 && phase === 0 ? gimmick || '' : ''};
  });
}
function referenceChoose(b, actions) {
  for (const [sideIndex, a] of actions.entries()) {
    if (a.kind === 'wait') continue;
    const side = b.sides[sideIndex];
    const command = a.kind === 'switch' ? `switch ${side.pokemon.findIndex(p => indexOf(p) === a.index) + 1}` : `move ${a.index + 1}${a.gimmick === 'z' && side.activeRequest.active[0].canZMove?.[a.index] ? ' zmove' : a.gimmick === 'dmax' && side.activeRequest.active[0].canDynamax ? ' dynamax' : ''}`;
    assert.ok(b.choose(`p${sideIndex + 1}`, command), `${command}: ${side.choice.error}`);
  }
}
const normalizeLog = lines => lines.filter(line => !line.startsWith('|t:|'));
// Set up prerequisites instead of counting only the expected failure at full HP,
// without sleep, without Stockpile, without hazards, or without a fainted ally.
function conditional(input, slug) {
  const source = input.teams[0][0], target = input.teams[1][0];
  const move = index => ({kind: 'move', index, gimmick: ''});
  const prepare = (own, foe = 'Splash') => {
    source.set.moves.push(own); target.set.moves = ['Splash', foe];
    return [[move(1), move(1)]];
  };
  if (['recover','softboiled','rest','milkdrink','morningsun','synthesis','moonlight','slackoff','roost','healorder','shoreup','lifedew','junglehealing','lunarblessing'].includes(slug)) return prepare('Splash', 'Seismic Toss');
  if (['snore','sleeptalk'].includes(slug)) return prepare('Splash', 'Spore');
  if (['healbell','refresh','aromatherapy','psychoshift'].includes(slug)) return prepare('Splash', 'Toxic');
  if (slug === 'nightmare') return prepare('Spore');
  if (['spitup','swallow'].includes(slug)) return prepare('Stockpile', slug === 'swallow' ? 'Seismic Toss' : 'Splash');
  if (slug === 'recycle') { source.set.item = 'Liechi Berry'; return prepare('Stuff Cheeks'); }
  if (slug === 'lastresort') return prepare('Splash');
  if (slug === 'topsyturvy') return prepare('Splash', 'Swords Dance');
  if (['venomdrench','purify'].includes(slug)) return prepare('Toxic');
  if (slug === 'flowershield') source.set.species = 'Venusaur';
  if (['magneticflux','gearup'].includes(slug)) source.set.ability = 'Plus';
  if (slug === 'auroraveil') { source.set.species = 'Abomasnow'; source.set.ability = 'Snow Warning'; }
  if (slug === 'courtchange') return prepare('Splash', 'Spikes');
  if (slug === 'steelroller') return prepare('Grassy Terrain');
  if (slug === 'bestow') target.set.item = '';
  if (['mirrorcoat','metalburst','comeuppance'].includes(slug)) {
    source.set.item = 'Lagging Tail'; target.set.moves = [slug === 'mirrorcoat' ? 'Psychic' : 'Tackle'];
  }
  if (slug === 'mirrormove') { target.set.species = 'Deoxys-Speed'; target.set.moves = ['Tackle']; }
  if (slug === 'upperhand') target.set.moves = ['Quick Attack'];
  if (slug === 'revivalblessing') {
    source.set.species = 'Pawmot';
    input.teams[0].unshift({set: {species: 'Mew', moves: ['Explosion'], level: 50, ability: 'No Ability'}});
    return [[move(0), move(0)], null];
  }
  return [];
}
const records = JSON.parse(readFileSync(new URL('../../assets/database/moves.json', import.meta.url))).filter(m => sim.move(m.name));
const report = [];
const fixtures = [];
let comparisons = 0;
for (const record of records) {
  const checks = [];
  for (const scenario of ['normal', 'attack', 'switch', 'immunity', 'conditions']) {
    const source = specimen(record);
    const target = {set: {species: scenario === 'immunity' ? 'Gengar' : 'Blissey', moves: [scenario === 'attack' ? 'Tackle' : 'Splash'], level: 50, ability: scenario === 'immunity' ? 'Levitate' : 'No Ability', item: 'Leftovers'}};
    const bench = {set: {species: 'Snorlax', moves: ['Splash'], level: 50, ability: 'No Ability'}};
    const input = {teams: [[source, bench], [target, bench]], seed: scenario === 'attack' ? [19, 31, 7, 5] : [1, 2, 3, 4]};
    const preparation = scenario === 'conditions' ? conditional(input, record.name.replace(/[^a-z0-9]/g, '')) : [];
    const expected = reference(input);
    const actual = sim.create(input);
    const fixture = {slug: record.name, input, steps: []};
    let cursor = expected.log.length;
    const effects = new Set();
    let firstUseFailed = false;
    try {
      assert.deepEqual(comparable(actual.state), referenceState(expected), `${record.name}/${scenario}/initial`);
      for (const planned of preparation) {
        const actions = planned || actionsFor(expected, '', 0, 'conditions');
        referenceChoose(expected, actions);
        let next;
        try { next = sim.choose(actual.handle, actions); } catch (error) { throw new Error(`${record.name}/${scenario}/preparation: ${JSON.stringify(actions)}`, {cause: error}); }
        assert.deepEqual(comparable(next.state), referenceState(expected), `${record.name}/preparation`);
        const raw = extractChannelMessages(expected.log.slice(cursor).join('\n'), [-1])[-1];
        cursor = expected.log.length;
        assert.deepEqual(normalizeLog(next.log), normalizeLog(raw), `${record.name}/preparation-events`);
        fixture.steps.push({actions, expected: serialize(referenceState(expected))});
        comparisons++;
      }
      for (let phase = 0; phase < 5 && !expected.ended; phase++) {
        const actions = actionsFor(expected, source.gimmick, phase, scenario);
        referenceChoose(expected, actions);
        const next = sim.choose(actual.handle, actions);
        const raw = extractChannelMessages(expected.log.slice(cursor).join('\n'), [-1])[-1];
        cursor = expected.log.length;
        if (phase === 0) firstUseFailed = raw.some(line => line.startsWith('|-fail|p1'));
        const state = referenceState(expected);
        assert.deepEqual(comparable(next.state), state, `${record.name}/${scenario}/phase-${phase}`);
        assert.deepEqual(normalizeLog(next.log), normalizeLog(raw), `${record.name}/${scenario}/events-${phase}`);
        for (const line of raw) if (/^\|-(?!damage|heal)/.test(line)) effects.add(line.split('|')[1]);
        fixture.steps.push({actions, expected: serialize(state)});
        comparisons++;
      }
      checks.push({scenario, phases: fixture.steps.length, stateAndEventsMatch: true, firstUseFailed, observedEffects: [...effects].sort()});
      if (scenario === 'conditions') fixtures.push(fixture);
    } finally { expected.destroy(); sim.dispose(actual.handle); }
  }
  report.push({slug: record.name, mode: specimen(record).gimmick || 'normal', checks});
}
mkdirSync(new URL('../../test/fixtures/', import.meta.url), {recursive: true});
mkdirSync(new URL('../../docs/', import.meta.url), {recursive: true});
writeFileSync(new URL('../../test/fixtures/battle_move_reference.json', import.meta.url), JSON.stringify(fixtures) + '\n');
writeFileSync(new URL('../../docs/battle-move-verification.json', import.meta.url), JSON.stringify({reference: '@pkmn/sim@0.10.11 standalone', format: 'Generation 9 singles', records: report.length, comparisons, limitation: 'Conformance in the listed scenarios; not exhaustive proof of all interactions or of upstream game accuracy.', moves: report}, null, 2) + '\n');
console.log(JSON.stringify({records: report.length, scenarios: report.length * 5, stateAndEventComparisons: comparisons, result: 'pass'}));
