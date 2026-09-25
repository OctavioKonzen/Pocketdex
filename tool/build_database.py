#!/usr/bin/env python3
"""Gera o banco de dados local do Pocketdex (assets/database/*.json).

O app não consulta mais a PokeAPI em tempo de execução: todos os dados vêm
dos arquivos gerados por este script, a partir do dump estático da PokeAPI
(https://github.com/PokeAPI/api-data).

Uso:
    git clone --depth 1 --filter=blob:none --sparse https://github.com/PokeAPI/api-data.git
    cd api-data && git sparse-checkout set data/api/v2/pokemon data/api/v2/pokemon-species \
        data/api/v2/evolution-chain data/api/v2/move data/api/v2/type data/api/v2/ability \
        data/api/v2/item data/api/v2/egg-group data/api/v2/generation && cd ..
    python3 tool/build_database.py api-data

Rode novamente sempre que quiser atualizar os dados (novos Pokémon, etc.).
"""

import json
import os
import sys

SPRITES_PREFIX = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/'
STAT_ORDER = ['hp', 'attack', 'defense', 'special-attack', 'special-defense', 'speed']
DAMAGE_RELATIONS = [
    'double_damage_from', 'double_damage_to',
    'half_damage_from', 'half_damage_to',
    'no_damage_from', 'no_damage_to',
]


def id_from_url(url):
    return int(url.rstrip('/').split('/')[-1])


def english(entries, key):
    for entry in entries:
        if entry['language']['name'] == 'en' and entry.get(key):
            return entry[key]
    return None


def sprite(url):
    if not url:
        return None
    return url[len(SPRITES_PREFIX):] if url.startswith(SPRITES_PREFIX) else url


class Source:
    def __init__(self, root):
        self.base = os.path.join(root, 'data', 'api', 'v2')

    def ids(self, resource):
        folder = os.path.join(self.base, resource)
        return sorted(int(d) for d in os.listdir(folder) if d.isdigit())

    def load(self, resource, resource_id):
        with open(os.path.join(self.base, resource, str(resource_id), 'index.json'), encoding='utf-8') as f:
            return json.load(f)

    def all(self, resource):
        for resource_id in self.ids(resource):
            yield self.load(resource, resource_id)


def build_pokemon(src):
    result = []
    for p in src.all('pokemon'):
        moves = []
        for m in p['moves']:
            name = m['move']['name']
            if 'gmax' in name:
                moves.append([name, 0])
                continue
            # Mesmo critério usado pelo app: último registro "level-up" com nível > 0.
            level = None
            for detail in m['version_group_details']:
                if detail['move_learn_method']['name'] == 'level-up' and detail['level_learned_at'] > 0:
                    level = detail['level_learned_at']
            if level is not None:
                moves.append([name, level])

        stats = {s['stat']['name']: [s['base_stat'], s['effort']] for s in p['stats']}
        artwork = p['sprites']['other']['official-artwork']
        result.append({
            'id': p['id'],
            'name': p['name'],
            'species': id_from_url(p['species']['url']),
            'height': p['height'],
            'weight': p['weight'],
            'types': [t['type']['name'] for t in sorted(p['types'], key=lambda t: t['slot'])],
            'stats': [stats.get(name, [0, 0]) for name in STAT_ORDER],
            'sprites': [
                sprite(p['sprites']['front_default']),
                sprite(p['sprites']['front_shiny']),
                sprite(artwork['front_default']),
                sprite(artwork['front_shiny']),
            ],
            'moves': moves,
        })
    return result


def build_species(src):
    result = []
    for s in src.all('pokemon-species'):
        flavor = english(s['flavor_text_entries'], 'flavor_text')
        result.append({
            'id': s['id'],
            'name': s['name'],
            'generation': id_from_url(s['generation']['url']),
            'flavor': flavor.replace('\n', ' ').replace('\f', ' ') if flavor else None,
            'genus': english(s['genera'], 'genus'),
            'egg_groups': [g['name'] for g in s['egg_groups']],
            'gender_rate': s['gender_rate'],
            'hatch_counter': s['hatch_counter'],
            'evolution_chain': id_from_url(s['evolution_chain']['url']) if s['evolution_chain'] else None,
            'varieties': [id_from_url(v['pokemon']['url']) for v in s['varieties']],
        })
    return result


def build_evolution_chains(src):
    def node(n):
        details = None
        if n['evolution_details']:
            d = n['evolution_details'][0]
            details = {
                'trigger': d['trigger']['name'] if d['trigger'] else None,
                'min_level': d['min_level'],
                'item': d['item']['name'] if d['item'] else None,
            }
        return {
            'species': id_from_url(n['species']['url']),
            'name': n['species']['name'],
            'details': details,
            'evolves_to': [node(e) for e in n['evolves_to']],
        }

    return {str(c['id']): node(c['chain']) for c in src.all('evolution-chain')}


def build_moves(src):
    result = []
    for m in src.all('move'):
        result.append({
            'id': m['id'],
            'name': m['name'],
            'type': m['type']['name'] if m['type'] else None,
            'damage_class': m['damage_class']['name'] if m['damage_class'] else None,
            'power': m['power'],
            'accuracy': m['accuracy'],
            'pp': m['pp'],
            'effect_chance': m['effect_chance'],
            'effect': english(m['effect_entries'], 'short_effect'),
            'learned_by': [id_from_url(p['url']) for p in m['learned_by_pokemon']],
        })
    return result


def build_types(src):
    result = {}
    for t in src.all('type'):
        result[t['name']] = {
            'damage_relations': {
                rel: [x['name'] for x in t['damage_relations'][rel]] for rel in DAMAGE_RELATIONS
            },
            'pokemon': [id_from_url(p['pokemon']['url']) for p in t['pokemon']],
        }
    return result


def build_abilities(src):
    result = []
    for a in src.all('ability'):
        result.append({
            'id': a['id'],
            'name': a['name'],
            'effect': english(a['effect_entries'], 'short_effect'),
            'pokemon': [id_from_url(p['pokemon']['url']) for p in a['pokemon']],
        })
    return result


def build_items(src):
    result = []
    for i in src.all('item'):
        result.append({
            'id': i['id'],
            'name': i['name'],
            'sprite': sprite(i['sprites']['default']) if i['sprites'] else None,
            'category': i['category']['name'] if i['category'] else 'other',
            'effect': english(i['effect_entries'], 'short_effect'),
        })
    return result


def build_egg_groups(src):
    return {g['name']: [id_from_url(s['url']) for s in g['pokemon_species']] for g in src.all('egg-group')}


def build_generations(src):
    return {
        str(g['id']): sorted(id_from_url(s['url']) for s in g['pokemon_species'])
        for g in src.all('generation')
    }


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)

    src = Source(sys.argv[1])
    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'database')
    os.makedirs(out_dir, exist_ok=True)

    tables = {
        'pokemon': build_pokemon,
        'species': build_species,
        'evolution_chains': build_evolution_chains,
        'moves': build_moves,
        'types': build_types,
        'abilities': build_abilities,
        'items': build_items,
        'egg_groups': build_egg_groups,
        'generations': build_generations,
    }
    for name, builder in tables.items():
        data = builder(src)
        path = os.path.join(out_dir, f'{name}.json')
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, separators=(',', ':'))
        print(f'{name}.json: {len(data)} registros, {os.path.getsize(path) // 1024} KB')


if __name__ == '__main__':
    main()
