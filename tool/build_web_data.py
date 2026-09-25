#!/usr/bin/env python3
"""Gera os dados do site (web-site/public/) a partir do banco local.

O site em JavaScript não lê o banco inteiro de uma vez: este script divide
assets/database/*.json em arquivos menores, no formato que o site usa, e
copia as imagens. Assim cada página baixa só o que precisa.

Saída (tudo gerado, fora do git):
    web-site/public/data/pokemon_index.json   lista de todos os Pokémon/formas
    web-site/public/data/pokemon/<id>.json    detalhes de cada espécie
    web-site/public/data/moves.json           golpes (sem a lista de quem aprende)
    web-site/public/data/move_learners.json   quem aprende cada golpe
    web-site/public/data/abilities.json       habilidades
    web-site/public/data/items.json           itens
    web-site/public/data/types.json           relações de dano entre tipos
    web-site/public/data/egg_groups.json      egg groups
    web-site/public/sprites/...               imagens do banco
    web-site/public/img/...                   imagens da interface

Uso:
    python3 tool/build_web_data.py
"""

import json
import os
import shutil

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
DB = os.path.join(ROOT, 'assets', 'database')
OUT = os.path.join(ROOT, 'web-site', 'public')
DATA = os.path.join(OUT, 'data')


def load(name):
    with open(os.path.join(DB, f'{name}.json'), encoding='utf-8') as f:
        return json.load(f)


def save(path, data):
    full = os.path.join(DATA, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, separators=(',', ':'))


def form_name(name, base):
    """Mesmo nome de forma exibido no app ("Mega X", "Alola", "Default"...)."""
    if name == base:
        return 'Default'
    words = name.replace(base, '').replace('-', ' ').split()
    return ' '.join(w[0].upper() + w[1:] for w in words if w)


def evolution_edges(node, sprite_of):
    """Lista "de → para" com o gatilho, como na aba Evolution do app."""
    edges = []
    for child in node['evolves_to']:
        d = child['details']
        trigger = 'Unknown'
        if d:
            if d['trigger'] == 'level-up' and d['min_level'] is not None:
                trigger = f"(Level {d['min_level']})"
            elif d['trigger'] == 'use-item' and d['item']:
                trigger = f"({d['item'].replace('-', ' ')})"
            elif d['trigger']:
                trigger = f"({d['trigger'].replace('-', ' ')})"
        edges.append({
            'from': {'id': node['species'], 'name': node['name'], 'sprite': sprite_of(node['species'])},
            'to': {'id': child['species'], 'name': child['name'], 'sprite': sprite_of(child['species'])},
            'trigger': trigger,
        })
        edges.extend(evolution_edges(child, sprite_of))
    return edges


def main():
    pokemon = load('pokemon')
    species = load('species')
    chains = load('evolution_chains')
    moves = load('moves')
    abilities = load('abilities')
    items = load('items')
    types = load('types')
    egg_groups = load('egg_groups')

    by_id = {p['id']: p for p in pokemon}
    species_by_id = {s['id']: s for s in species}

    def sprite_of(pokemon_id):
        p = by_id.get(pokemon_id)
        return p['sprites'][0] if p else None

    # Índice leve de todos os Pokémon (inclusive formas), usado em listas.
    index = []
    for p in pokemon:
        s = species_by_id.get(p['species'])
        index.append({
            'id': p['id'],
            'name': p['name'],
            'species': p['species'],
            'default': p['id'] < 10000,
            'gen': s['generation'] if s else None,
            'types': p['types'],
            'sprite': p['sprites'][0] or p['sprites'][2],
        })
    save('pokemon_index.json', index)

    # Detalhes por espécie.
    for s in species:
        chain = chains.get(str(s['evolution_chain'])) if s['evolution_chain'] else None
        forms = []
        for pid in s['varieties']:
            p = by_id.get(pid)
            if not p:
                continue
            forms.append({
                'id': p['id'],
                'name': p['name'],
                'formName': form_name(p['name'], s['name']),
                'types': p['types'],
                'height': p['height'],
                'weight': p['weight'],
                'baseExperience': p['base_experience'],
                'stats': p['stats'],
                'abilities': p['abilities'],
                'sprites': p['sprites'],
                'moves': p['moves'],
            })
        save(f"pokemon/{s['id']}.json", {
            'id': s['id'],
            'name': s['name'],
            'genus': (s['genus'] or '').replace(' Pokémon', ''),
            'flavor': s['flavor'] or 'No description available.',
            'generation': s['generation'],
            'genderRate': s['gender_rate'],
            'hatchCounter': s['hatch_counter'] or 0,
            'captureRate': s['capture_rate'],
            'baseHappiness': s['base_happiness'],
            'growthRate': s['growth_rate'],
            'habitat': s['habitat'],
            'isLegendary': s['is_legendary'],
            'isMythical': s['is_mythical'],
            'isBaby': s['is_baby'],
            'eggGroups': s['egg_groups'],
            'evolution': evolution_edges(chain, sprite_of) if chain else [],
            'forms': forms,
        })

    def short_effect(entry):
        text = entry.get('effect') or 'No effect description available.'
        chance = entry.get('effect_chance')
        return text.replace('$effect_chance', str(chance) if chance is not None else '')

    save('moves.json', {
        m['name']: {
            'id': m['id'],
            'name': m['name'],
            'type': m['type'],
            'category': m['damage_class'],
            'power': m['power'],
            'accuracy': m['accuracy'],
            'pp': m['pp'],
            'priority': m['priority'],
            'generation': m['generation'],
            'effect': short_effect(m),
            'flavor': m['flavor'],
        } for m in moves
    })
    save('move_learners.json', {m['name']: m['learned_by'] for m in moves})

    save('abilities.json', [{
        'id': a['id'],
        'name': a['name'],
        'effect': a['effect'] or 'No description available for this ability.',
        'flavor': a['flavor'],
        'generation': a['generation'],
        'pokemon': a['pokemon'],
        'hiddenFor': a['hidden_for'],
    } for a in abilities if a['is_main_series']])

    save('items.json', [{
        'id': i['id'],
        'name': i['name'],
        'sprite': i['sprite'],
        'category': i['category'],
        'effect': i['effect'] or 'No effect description available.',
        'flavor': i['flavor'],
        'cost': i['cost'],
        'attributes': i['attributes'],
    } for i in items])

    save('types.json', {name: t['damage_relations'] for name, t in types.items()})
    save('egg_groups.json', egg_groups)

    # Imagens.
    shutil.copytree(os.path.join(DB, 'sprites'), os.path.join(OUT, 'sprites'), dirs_exist_ok=True)
    os.makedirs(os.path.join(OUT, 'img'), exist_ok=True)
    for image in ('pokeball.png', 'poke_logo.png'):
        shutil.copyfile(os.path.join(ROOT, 'assets', 'images', image), os.path.join(OUT, 'img', image))

    total = sum(os.path.getsize(os.path.join(r, f)) for r, _, fs in os.walk(DATA) for f in fs)
    print(f'dados do site: {len(index)} Pokémon, {len(species)} espécies, {total // 1024} KB em {DATA}')


if __name__ == '__main__':
    main()
