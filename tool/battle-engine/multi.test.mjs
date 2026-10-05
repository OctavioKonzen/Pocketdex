import {test} from 'node:test';
import assert from 'node:assert/strict';
import {PocketDexSim as sim} from './engine.mjs';
const mon = (species, moves, ability = 'No Ability') => ({name: species, set: {species, moves, ability, level: 50}});
const attack = (index = 0, target = 0) => ({kind: 'move', index, target, gimmick: ''});

test('Doubles: Helping Hand boosts an ally, spread damage hits both foes', () => {
  const run = help => {
    const g = sim.create({mode: 'doubles', seed: [1,2,3,4], teams: [[mon('Mew',['helpinghand','splash']), mon('Charizard',['heatwave'])], [mon('Blissey',['splash']),mon('Snorlax',['splash'])]]});
    try { return sim.choose(g.handle, [[attack(help ? 0 : 1, help ? -2 : 0),attack()], [attack(),attack()]]); }
    finally { sim.dispose(g.handle); }
  };
  const boosted = run(true), normal = run(false);
  for (let slot = 0; slot < 2; slot++) assert.ok(boosted.state.sides[1].team[slot].hp < normal.state.sides[1].team[slot].hp);
  assert.ok(boosted.log.some(line => line.includes('Helping Hand')));
});
test('Triples: corner adjacency restricts normal attacks; shift moves to center', () => {
  const g = sim.create({mode: 'triples', seed: [1,2,3,4], teams: [[mon('Mew',['tackle']),mon('Mew',['splash']),mon('Mew',['splash'])], [mon('Snorlax',['splash']),mon('Snorlax',['splash']),mon('Snorlax',['splash'])]]});
  try {
    assert.deepEqual(sim.targets(g.handle,0,0,0).targets.filter(t => !t.ally).map(t => t.loc), [2,3]);
    sim.choose(g.handle, [[{kind:'shift'},attack(),attack()], [attack(),attack(),attack()]]);
    assert.equal(sim.inspect(g.handle).state.sides[0].actives[1],0);
  } finally {sim.dispose(g.handle);}
});
test('Four players: each trainer has a party, can target an ally and all four act', () => {
  const g = sim.create({mode:'multi', seed:[1,2,3,4], teams:[[mon('Mew',['helpinghand']),mon('Pikachu',['splash'])],[mon('Blissey',['splash'])],[mon('Charizard',['flamethrower'])],[mon('Snorlax',['splash'])]]});
  try {
    assert.equal(g.state.sides.length,4);
    const ally = sim.targets(g.handle,0,0,0).targets.find(t => t.side === 2);
    assert.ok(ally);
    const target = sim.targets(g.handle,2,0,0).targets.find(t => t.side === 1);
    const next = sim.choose(g.handle, [[attack(0,ally.loc)],[attack()],[attack(0,target.loc)],[attack()]]);
    assert.equal(next.state.turn,2);
    assert.ok(next.state.sides[1].team[0].hp < next.state.sides[1].team[0].maxHp);
    assert.equal(next.state.sides[0].team.length,2);
    assert.equal(next.state.sides[2].team.length,1);
  } finally {sim.dispose(g.handle);}
});
test('CPU chooses a legal action for every active Pokémon in all formats', () => {
  for (const mode of ['doubles','triples','multi']) {
    const count = mode === 'triples' ? 3 : mode === 'doubles' ? 2 : 1;
    const teams = Array.from({length:mode === 'multi' ? 4 : 2},()=>Array.from({length:count+1},()=>mon('Mew',['tackle','helpinghand','recover'])));
    const g=sim.create({mode,teams,seed:[1,2,3,4]});
    try {
      for(let turn=0;turn<8 && sim.inspect(g.handle).state.winner == null;turn++) {
        const actions=teams.map((_,side)=>sim.recommend(g.handle,side).actions);
        sim.choose(g.handle,actions);
      }
    } finally {sim.dispose(g.handle);}
  }
});

test('A voluntary switch consumes that slot action; partners and foes still act', () => {
  for (const mode of ['singles','doubles','triples']) {
    const count = mode === 'singles' ? 1 : mode === 'doubles' ? 2 : 3;
    const own = Array.from({length:count+1},()=>mon('Mew',['splash']));
    own[count] = mon('Snorlax',['tackle']);
    const foe = Array.from({length:count},()=>mon('Mew',['tackle']));
    const game=sim.create({mode,teams:[own,foe],seed:[1,2,3,4]});
    try {
      const targets=foe.map((_,slot)=>{
        const legal=sim.targets(game.handle,1,slot,0).targets.filter(t=>t.side===0);
        return legal.find(t=>t.slot===0)||legal[0];
      });
      const next=sim.choose(game.handle,[own.slice(0,count).map((_,slot)=>slot===0?{kind:'switch',index:count}:attack()),foe.map((_,slot)=>attack(0,targets[slot]?.loc||0))]);
      assert.equal(next.state.turn,2);
      assert.equal(next.state.sides[0].actives[0],count);
      assert.ok(next.state.sides[0].team[count].hp<next.state.sides[0].team[count].maxHp);
      assert.equal(next.log.filter(line=>line.includes('|move|p1a:')).length,0,'replacement must not attack after a voluntary switch');
      assert.equal(next.log.filter(line=>/\|move\|p1[bc]:/.test(line)).length,count-1);
    } finally {sim.dispose(game.handle);}
  }
});

test('Triple CPU shifts into reach after adjacent foes faint and finishes the battle', () => {
  const game=sim.create({mode:'triples',seed:[1,2,3,4],teams:[Array.from({length:3},()=>mon('Magikarp',['splash'])),Array.from({length:3},()=>mon('Mewtwo',['psychic']))]});
  try {
    let next;
    for(let turn=0;turn<8;turn++) {
      next=sim.choose(game.handle,[sim.recommend(game.handle,0).actions,sim.recommend(game.handle,1).actions]);
      if(next.state.winner!==null) break;
    }
    assert.equal(next.state.winner,1);
  } finally {sim.dispose(game.handle);}
});

test('CPU switches a healthy disadvantaged Pokémon to a safer reserve', () => {
  const g = sim.create({seed:[1,2,3,4],teams:[[mon('Charizard',['tackle']),mon('Venusaur',['energyball'])],[mon('Blastoise',['hydropump'])]]});
  try {
    const action = sim.recommend(g.handle,0).actions[0];
    assert.deepEqual(action,{kind:'switch',index:1});
    assert.equal(g.state.sides[0].team[0].hp,g.state.sides[0].team[0].maxHp);
  } finally {sim.dispose(g.handle);}
});
test('CPU attacks with a super-effective move instead of unnecessarily switching', () => {
  const g = sim.create({seed:[1,2,3,4],teams:[[mon('Charizard',['tackle','energyball']),mon('Venusaur',['energyball'])],[mon('Blastoise',['hydropump'])]]});
  try {
    const action = sim.recommend(g.handle,0).actions[0];
    assert.equal(action.kind,'move');assert.equal(action.index,1);
  } finally {sim.dispose(g.handle);}
});

test('CPU Dynamax attacks target an opponent instead of the adjacent ally', () => {
  const charizard = {...mon('Charizard',['heatwave']),gimmick:'dmax'};
  const g = sim.create({mode:'doubles',seed:[1,2,3,4],teams:[[charizard,mon('Blissey',['splash'])],[mon('Venusaur',['splash']),mon('Scizor',['splash'])]]});
  try {
    const actions = sim.recommend(g.handle,0).actions;
    assert.equal(actions[0].gimmick,'dmax');assert.ok(actions[0].target>0);
    sim.choose(g.handle,[actions,sim.recommend(g.handle,1).actions]);
  } finally {sim.dispose(g.handle);}
});

test('CPU Z-status support retains its ally target', () => {
  const helper = {...mon('Mew',['helpinghand']),gimmick:'z'};helper.set.item='Normalium Z';
  const g = sim.create({mode:'doubles',seed:[1,2,3,4],teams:[[helper,mon('Charizard',['flamethrower'])],[mon('Venusaur',['splash']),mon('Scizor',['splash'])]]});
  try {
    const actions = sim.recommend(g.handle,0).actions;
    assert.equal(actions[0].gimmick,'z');assert.ok(actions[0].target<0);
    sim.choose(g.handle,[actions,sim.recommend(g.handle,1).actions]);
  } finally {sim.dispose(g.handle);}
});

test('CPU planning does not run attack-only ability callbacks without a move', () => {
  for (const [species,ability,move] of [['Venusaur','Overgrow','energyball'],['Charizard','Blaze','flamethrower'],['Blastoise','Torrent','surf'],['Scizor','Swarm','xscissor']]) {
    const g = sim.create({seed:[1,2,3,4],teams:[[mon(species,[move],ability)],[mon('Mew',['splash'])]]});
    try {assert.equal(sim.recommend(g.handle,0).actions[0].kind,'move');}
    finally {sim.dispose(g.handle);}
  }
});

test('CPU does not attempt a voluntary switch under possible Shadow Tag trapping', () => {
  const g = sim.create({mode:'triples',seed:[1,2,3,4],teams:[[mon('Mew',['splash']),mon('Mew',['splash']),mon('Mew',['splash']),mon('Darkrai',['darkpulse'])],[mon('Wynaut',['splash'],'Shadow Tag'),mon('Mew',['splash']),mon('Mew',['splash'])]]});
  try {
    const actions = sim.recommend(g.handle,0).actions;
    assert.ok(actions.every(a=>a.kind!=='switch'));
    sim.choose(g.handle,[actions,sim.recommend(g.handle,1).actions]);
  } finally {sim.dispose(g.handle);}
});


test('CPU keeps choosing a foe for spread attacks during every Dynamax turn', () => {
  const attacker = {...mon('Dusknoir',['earthquake']),gimmick:'dmax'};
  const g = sim.create({mode:'doubles',seed:[1,2,3,4],teams:[[attacker,mon('Blissey',['splash'])],[mon('Blissey',['splash']),mon('Blissey',['splash'])]]});
  try {
    for (let turn=0;turn<3;turn++) {
      const actions=sim.recommend(g.handle,0).actions;
      assert.ok(actions[0].target>0);
      sim.choose(g.handle,[actions,sim.recommend(g.handle,1).actions]);
    }
  } finally {sim.dispose(g.handle);}
});


test('locked second-turn moves retain their automatic target in doubles', () => {
  const g=sim.create({mode:'doubles',seed:[1,2,3,4],teams:[[mon('Mew',['bounce']),mon('Blissey',['splash'])],[mon('Blissey',['splash']),mon('Blissey',['splash'])]]});
  try {
    sim.choose(g.handle,[sim.recommend(g.handle,0).actions,sim.recommend(g.handle,1).actions]);
    const actions=sim.recommend(g.handle,0).actions;
    assert.equal(actions[0].target,0);
    assert.equal(sim.targets(g.handle,0,0,0).automatic,true);
    sim.choose(g.handle,[actions,sim.recommend(g.handle,1).actions]);
  } finally {sim.dispose(g.handle);}
});
