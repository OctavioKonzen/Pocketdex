"""Build offline NPC sets from Showdown Factory sets and role-based fallbacks.

Species remain random. Factory spreads are preserved; every IV is 31 and the
battle level is 50. Fallbacks are practical builds, not claims of optimal meta.
Run after rebuilding sets/pokemon/moves/battle_items.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DB = ROOT / 'assets/database'
STATS = ['hp', 'atk', 'def', 'spa', 'spd', 'spe']
EXCLUDE = {'explosion', 'self-destruct', 'hyper-beam', 'giga-impact', 'dream-eater',
           'last-resort', 'belch', 'snore', 'struggle', 'fling', 'natural-gift',
           'solar-beam', 'solar-blade', 'focus-punch', 'bide', 'counter', 'mirror-coat'}
PREFERRED_ABILITIES = ['imposter', 'huge-power', 'pure-power', 'intimidate', 'regenerator',
                      'magic-guard', 'speed-boost', 'technician', 'adaptability',
                      'sheer-force', 'moxie', 'multiscale', 'levitate', 'sturdy']


def load(name):
    return json.loads((DB / f'{name}.json').read_text(encoding='utf-8'))


def fallback(p, moves, profile=None):
    profile = profile or p
    stats = dict(zip(STATS, [v[0] for v in profile['stats']]))
    offense = 'atk' if stats['atk'] >= stats['spa'] else 'spa'
    category = 'physical' if offense == 'atk' else 'special'
    fast = stats['spe'] >= 80
    evs = dict.fromkeys(STATS, 0)
    evs[offense] = 252
    evs['spe' if fast else 'hp'] = 252
    evs['spd'] = 4
    nature = ('Jolly' if offense == 'atk' else 'Timid') if fast else ('Adamant' if offense == 'atk' else 'Modest')
    legal = {m[0] for m in p['moves']}
    def score(name):
        m = moves[name]
        return (m['power'] or 0) * (m['accuracy'] or 100) / 100 * (1.5 if m['type'] in profile['types'] else 1) * (1 if m['damage_class'] == category else .6)
    attacks = sorted((n for n in legal if n in moves and moves[n]['power'] and moves[n]['damage_class'] != 'status' and moves[n]['id'] < 10000 and n not in EXCLUDE), key=lambda n: (-score(n), n))
    chosen = []
    types = set()
    for n in attacks:
        if moves[n]['type'] not in types:
            chosen.append(n)
            types.add(moves[n]['type'])
        if len(chosen) == 4:
            break
    recovery = next((n for n in ['recover', 'roost', 'slack-off', 'synthesis', 'strength-sap', 'shore-up'] if n in legal), None)
    if recovery and not fast and len(chosen) >= 3:
        chosen = chosen[:3] + [recovery]
    for n in attacks:
        if len(chosen) < 4 and n not in chosen:
            chosen.append(n)
    for n in sorted(legal):
        if len(chosen) < 4 and n in moves and n not in chosen and moves[n]['id'] < 10000:
            chosen.append(n)
    abilities = [a[0] for a in p['abilities']]
    ability = next((a for a in PREFERRED_ABILITIES if a in abilities), abilities[0])
    return dict(level=50, nature=nature, ability=ability, evs=evs,
                item='life-orb' if fast else 'leftovers', tera=profile['types'][0], moves=chosen)


def build():
    pokemon = load('pokemon')
    by_name = {p['name']: p for p in pokemon}
    moves = {m['name']: m for m in load('moves')}
    ready = load('sets')
    items = load('battle_items')
    stones = items['mega']
    out = {'_source': ready['_source'], '_fallback': 'Role-based builds; not competitive analysis sets.'}
    for p in pokemon:
        if not p['is_default']:
            continue
        legal = {m[0] for m in p['moves']}
        abilities = {a[0] for a in p['abilities']}
        candidates = [dict(s) for s in ready.get(str(p['id']), [])
                      if s['ability'] in abilities and all(n in legal and n in moves for n in s['moves'])]
        if not candidates:
            candidates = [fallback(p, moves)]
        for s in candidates:
            s.update(level=50, ivs=dict.fromkeys(STATS, 31), gimmick='tera')
            s.pop('tier', None)
        mega = []
        for stone, form in stones.items():
            profile = by_name.get(form)
            if not profile or profile['species'] != p['species']:
                continue
            s = fallback(p, moves, profile)
            s.update(item=stone, gimmick='mega', ivs=dict.fromkeys(STATS, 31))
            mega.append(s)
        attack = next((moves[n] for n in candidates[0]['moves'] if moves[n]['damage_class'] != 'status'), None)
        crystal = next((k for k, v in items['z'].items() if attack and v == attack['type']), None)
        out[str(p['id'])] = {'sets': candidates, 'mega': mega, 'z': crystal,
                            'gmax': any(q['species'] == p['species'] and q['name'].endswith('-gmax') for q in pokemon),
                            'dmax': p['species'] not in [888, 889, 890]}
    return out


if __name__ == '__main__':
    output = json.dumps(build(), ensure_ascii=False, separators=(',', ':'))
    (DB / 'npc_sets.json').write_text(output, encoding='utf-8')
    target = ROOT / 'web-site/public/data/npc_sets.json'
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(output, encoding='utf-8')
