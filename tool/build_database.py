#!/usr/bin/env python3
"""Gera o banco de dados local do Pocketdex (assets/database/*.json).

O app não consulta mais a PokeAPI em tempo de execução: todos os dados vêm
dos arquivos gerados por este script, a partir do dump estático da PokeAPI
(https://github.com/PokeAPI/api-data).

Uso:
    git clone --depth 1 --filter=blob:none --sparse https://github.com/PokeAPI/api-data.git
    cd api-data && git sparse-checkout set data/api/v2/pokemon data/api/v2/pokemon-species \
        data/api/v2/evolution-chain data/api/v2/move data/api/v2/type data/api/v2/ability \
        data/api/v2/item data/api/v2/egg-group data/api/v2/generation data/api/v2/pokemon-form && cd ..

    # Imagens (sprites normais/shiny, artes oficiais normais/shiny e itens)
    git clone --depth 1 --filter=blob:none --sparse https://github.com/PokeAPI/sprites.git
    cd sprites && git sparse-checkout set --no-cone '/sprites/pokemon/*.png' '/sprites/pokemon/shiny/*.png' \
        '/sprites/pokemon/other/official-artwork/*.png' '/sprites/pokemon/other/official-artwork/shiny/*.png' \
        '/sprites/items/*.png' && cd ..

    python3 tool/build_database.py api-data sprites   # requer Pillow (pip install pillow)

Rode novamente sempre que quiser atualizar os dados (novos Pokémon, etc.).
As artes oficiais são convertidas para WebP (mesma resolução) para ocupar menos espaço.
"""

import json
import os
import shutil
import sys
from concurrent.futures import ProcessPoolExecutor

SPRITES_PREFIX = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/'
STAT_ORDER = ['hp', 'attack', 'defense', 'special-attack', 'special-defense', 'speed']
DAMAGE_RELATIONS = [
    'double_damage_from', 'double_damage_to',
    'half_damage_from', 'half_damage_to',
    'no_damage_from', 'no_damage_to',
]


def id_from_url(url):
    return int(url.rstrip('/').split('/')[-1])


def english(entries, key, latest=False):
    found = None
    for entry in entries:
        if entry['language']['name'] == 'en' and entry.get(key):
            if not latest:
                return entry[key]
            found = entry[key]
    return found


def clean(text):
    return ' '.join(text.split()) if text else text


def name_of(ref):
    return ref['name'] if ref else None


# Todas as imagens referenciadas pelo banco; copiadas no final por copy_images().
IMAGES = set()


def sprite(url):
    if not url:
        return None
    path = url[len(SPRITES_PREFIX):] if url.startswith(SPRITES_PREFIX) else url
    IMAGES.add(path)
    return path


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
        # Todos os golpes e formas de aprendizado ([golpe, método, nível]).
        # Para cada método vale o registro mais recente (último version group).
        moves = []
        for m in p['moves']:
            name = m['move']['name']
            learned = {}
            for detail in m['version_group_details']:
                method = detail['move_learn_method']['name']
                if method == 'level-up' and detail['level_learned_at'] == 0 and learned.get(method):
                    continue
                learned[method] = detail['level_learned_at']
            if not learned and 'gmax' in name:
                learned['machine'] = 0
            for method, level in learned.items():
                moves.append([name, method, level])

        stats = {s['stat']['name']: [s['base_stat'], s['effort']] for s in p['stats']}
        artwork = p['sprites']['other']['official-artwork']
        result.append({
            'id': p['id'],
            'name': p['name'],
            'species': id_from_url(p['species']['url']),
            'is_default': p['is_default'],
            'base_experience': p['base_experience'],
            'abilities': [[a['ability']['name'], a['is_hidden']] for a in sorted(p['abilities'], key=lambda a: a['slot'])],
            'forms': [id_from_url(f['url']) for f in p['forms']],
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
            'capture_rate': s['capture_rate'],
            'base_happiness': s['base_happiness'],
            'growth_rate': name_of(s['growth_rate']),
            'habitat': name_of(s['habitat']),
            'color': name_of(s['color']),
            'shape': name_of(s['shape']),
            'is_baby': s['is_baby'],
            'is_legendary': s['is_legendary'],
            'is_mythical': s['is_mythical'],
            'evolves_from': id_from_url(s['evolves_from_species']['url']) if s['evolves_from_species'] else None,
            'names': {n['language']['name']: n['name'] for n in s['names']},
            'pokedex_numbers': {n['pokedex']['name']: n['entry_number'] for n in s['pokedex_numbers']},
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
            'effect_full': clean(english(m['effect_entries'], 'effect')),
            'flavor': clean(english(m['flavor_text_entries'], 'flavor_text', latest=True)),
            'priority': m['priority'],
            'target': name_of(m['target']),
            'generation': id_from_url(m['generation']['url']) if m['generation'] else None,
            'meta': {
                'ailment': name_of(m['meta']['ailment']),
                'category': name_of(m['meta']['category']),
                **{k: m['meta'][k] for k in ('min_hits', 'max_hits', 'min_turns', 'max_turns', 'drain', 'healing',
                                             'crit_rate', 'ailment_chance', 'flinch_chance', 'stat_chance')},
            } if m['meta'] else None,
            'stat_changes': [[c['stat']['name'], c['change']] for c in m['stat_changes']],
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
            'effect_full': clean(english(a['effect_entries'], 'effect')),
            'flavor': clean(english(a['flavor_text_entries'], 'flavor_text', latest=True)),
            'generation': id_from_url(a['generation']['url']) if a['generation'] else None,
            'is_main_series': a['is_main_series'],
            'pokemon': [id_from_url(p['pokemon']['url']) for p in a['pokemon']],
            'hidden_for': [id_from_url(p['pokemon']['url']) for p in a['pokemon'] if p['is_hidden']],
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
            'effect_full': clean(english(i['effect_entries'], 'effect')),
            'flavor': clean(english(i['flavor_text_entries'], 'text', latest=True)),
            'cost': next((pr['purchase_price'] for pr in reversed(i.get('prices', [])) if pr['purchase_price']), i.get('cost')),
            'fling_power': i['fling_power'],
            'fling_effect': name_of(i['fling_effect']),
            'attributes': [a['name'] for a in i['attributes']],
            'held_by': [id_from_url(h['pokemon']['url']) for h in i['held_by_pokemon']],
        })
    return result


def build_forms(src):
    result = []
    for f in src.all('pokemon-form'):
        result.append({
            'id': f['id'],
            'name': f['name'],
            'form_name': f['form_name'],
            'pokemon': id_from_url(f['pokemon']['url']),
            'is_default': f['is_default'],
            'is_mega': f['is_mega'],
            'is_battle_only': f['is_battle_only'],
            'types': [t['type']['name'] for t in sorted(f['types'], key=lambda t: t['slot'])],
            'sprites': [
                sprite(f['sprites']['front_default']),
                sprite(f['sprites']['front_shiny']),
                sprite(f['sprites']['other']['official-artwork']['front_default']),
                sprite(f['sprites']['other']['official-artwork']['front_shiny']),
            ],
        })
    return result


def _copy_image(job):
    source, target = job
    os.makedirs(os.path.dirname(target), exist_ok=True)
    if target.endswith('.webp'):
        from PIL import Image
        Image.open(source).save(target, 'WEBP', quality=80, method=4)
    else:
        shutil.copyfile(source, target)
    return os.path.getsize(target)


def copy_images(sprites_root, out_dir):
    """Copia todas as imagens referenciadas para assets/database/sprites/.

    As artes oficiais viram WebP (mesma resolução), o resto é copiado como PNG.
    """
    base = os.path.join(sprites_root, 'sprites')
    jobs, missing = [], []
    for path in sorted(IMAGES):
        source = os.path.join(base, path)
        if not os.path.exists(source):
            missing.append(path)
            continue
        target = os.path.join(out_dir, 'sprites', path)
        if path.startswith('pokemon/other/official-artwork/'):
            target = target[:-4] + '.webp'
        if not os.path.exists(target):
            jobs.append((source, target))
    with ProcessPoolExecutor() as pool:
        list(pool.map(_copy_image, jobs, chunksize=16))
    total = sum(
        os.path.getsize(os.path.join(root, f))
        for root, _, files in os.walk(os.path.join(out_dir, 'sprites')) for f in files
    )
    print(f'imagens: {len(IMAGES) - len(missing)} arquivos ({len(jobs)} novos), {total // (1024 * 1024)} MB')
    if missing:
        print(f'  {len(missing)} imagens não encontradas no repositório de sprites, ex.: {missing[:5]}')


def build_egg_groups(src):
    return {g['name']: [id_from_url(s['url']) for s in g['pokemon_species']] for g in src.all('egg-group')}


def build_generations(src):
    return {
        str(g['id']): sorted(id_from_url(s['url']) for s in g['pokemon_species'])
        for g in src.all('generation')
    }


def main():
    if len(sys.argv) not in (2, 3):
        print(__doc__)
        sys.exit(1)

    src = Source(sys.argv[1])
    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'database')
    os.makedirs(out_dir, exist_ok=True)

    tables = {
        'pokemon': build_pokemon,
        'forms': build_forms,
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

    if len(sys.argv) == 3:
        copy_images(sys.argv[2], out_dir)


if __name__ == '__main__':
    main()
