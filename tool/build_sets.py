#!/usr/bin/env python3
"""Gera os sets prontos do Montador (assets/database/sets.json).

Fonte: os sets da Battle Factory (singles: Uber, OU, UU, RU, NU, PU) e da
BSS Factory (nível 50) do Pokémon Showdown, geração 9 — pacote npm
"pokemon-showdown", licença MIT (Copyright (c) Guangcong Luo e
colaboradores, http://pokemonshowdown.com/). Não usamos os sets das análises
do Smogon.com, que precisam de permissão.

Saída: {id do Pokémon no banco: [set, ...]}, com cada set no formato do app
(lib/services/team_sets.dart) mais 'tier':
    {tier, level, ability, item, nature, tera, moves: [slug x4], evs: {hp..spe}}

Uso:
    python3 tool/build_sets.py            (baixa o pacote com npm pack)
    PS_DIR=/caminho/package python3 tool/build_sets.py
"""

import glob
import json
import os
import re
import subprocess
import tarfile
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
DB = os.path.join(ROOT, 'assets', 'database')
STATS = ['hp', 'atk', 'def', 'spa', 'spd', 'spe']
TIERS = ['Uber', 'OU', 'UU', 'RU', 'NU', 'PU']
PER_POKEMON = 4


def to_id(text):
    return re.sub(r'[^a-z0-9]', '', str(text).lower())


def showdown_dir():
    if os.environ.get('PS_DIR'):
        return os.environ['PS_DIR']
    tmp = tempfile.mkdtemp()
    subprocess.run(['npm', 'pack', 'pokemon-showdown', '--silent'], cwd=tmp, check=True, stdout=subprocess.DEVNULL)
    tgz = glob.glob(os.path.join(tmp, 'pokemon-showdown-*.tgz'))[0]
    with tarfile.open(tgz) as t:
        t.extractall(tmp)
    return os.path.join(tmp, 'package')


def load(name):
    with open(os.path.join(DB, f'{name}.json'), encoding='utf-8') as f:
        return json.load(f)


def main():
    ps = showdown_dir()
    base = os.path.join(ps, 'dist', 'data', 'random-battles', 'gen9')
    with open(os.path.join(base, 'factory-sets.json'), encoding='utf-8') as f:
        factory = json.load(f)
    with open(os.path.join(base, 'bss-factory-sets.json'), encoding='utf-8') as f:
        bss = json.load(f)

    pokemon = load('pokemon')
    moves = {to_id(m['name']): m['name'] for m in load('moves')}
    items = {to_id(i['name']): i['name'] for i in load('items')}
    abilities = load('abilities')
    abilities = {to_id(a['name']): a['name'] for a in (abilities if isinstance(abilities, list) else abilities.values())}

    by_id = {}
    for p in sorted(pokemon, key=lambda p: (p['id'] >= 10000, len(p['name']))):
        by_id.setdefault(to_id(p['name']), p['id'])

    aliases = {'necrozmaduskmane': 'necrozmadusk', 'necrozmadawnwings': 'necrozmadawn', 'greninjabond': 'greninjabattlebond'}

    def pokemon_id(species):
        key = aliases.get(to_id(species), to_id(species))
        if key in by_id:
            return by_id[key]
        # "Landorus" → landorus-incarnate; "Ogerpon-Wellspring" → ogerpon-wellspring-mask.
        for name, pid in by_id.items():
            if name.startswith(key):
                return pid
        return None

    def first(value):
        return value[0] if isinstance(value, list) else value

    out = {}
    missing = set()

    def add(species, s, tier, level):
        pid = pokemon_id(species)
        if pid is None:
            missing.add(species)
            return
        slots = [first(slot) for slot in s.get('moves', [])][:4]
        move_slugs = [moves.get(to_id(m), '') for m in slots]
        entry = {
            'tier': tier,
            'level': level,
            'ability': abilities.get(to_id(first(s.get('ability', [''])))),
            'item': items.get(to_id(first(s.get('item', ['']))), ''),
            'nature': first(s.get('nature', ['Hardy'])) or 'Hardy',
            'tera': str(first(s.get('teraType', ['']) or [''])).lower(),
            'moves': move_slugs + [''] * (4 - len(move_slugs)),
            'evs': {k: int(s.get('evs', {}).get(k, 0)) for k in STATS},
        }
        if not entry['ability']:
            entry['ability'] = ''
        key = json.dumps({k: v for k, v in entry.items() if k != 'tier'}, sort_keys=True)
        sets = out.setdefault(pid, [])
        if all(json.dumps({k: v for k, v in x.items() if k != 'tier'}, sort_keys=True) != key for x in sets):
            sets.append(entry)

    for tier in TIERS:
        for mon in factory.get(tier, {}).values():
            for s in sorted(mon['sets'], key=lambda s: -s.get('weight', 0)):
                add(s['species'], s, tier, 100)
    for mon in bss.values():
        for s in sorted(mon['sets'], key=lambda s: -s.get('weight', 0)):
            add(s['species'], s, 'BSS', 50)

    result = {
        '_source': 'Pokémon Showdown (Battle Factory e BSS Factory, geração 9), licença MIT, '
                   'Copyright (c) Guangcong Luo e colaboradores, http://pokemonshowdown.com/',
        **{str(pid): sets[:PER_POKEMON] for pid, sets in sorted(out.items())},
    }
    with open(os.path.join(DB, 'sets.json'), 'w', encoding='utf-8') as f:
        json.dump(result, f, ensure_ascii=False, separators=(',', ':'))
    print(f'sets prontos: {len(out)} Pokémon, {sum(min(len(s), PER_POKEMON) for s in out.values())} sets')
    if missing:
        print('sem Pokémon no banco:', ', '.join(sorted(missing)))


if __name__ == '__main__':
    main()
