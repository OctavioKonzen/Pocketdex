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
    web-site/public/data/breeding.json        grupos de ovo e gênero de cada espécie
    web-site/public/data/egg_moves.json       quem aprende cada golpe de ovo e como
    web-site/public/data/locations.json       nomes dos locais de encontro
    web-site/public/cries/<id>.mp3            grito de cada espécie
    web-site/public/sprites/...               imagens do banco
    web-site/public/img/...                   imagens da interface

Uso:
    python3 tool/build_web_data.py
"""

import re
import json
import os
import shutil

from PIL import Image

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


_boxes = {}


def box(path):
    """Onde o Pokémon está dentro do sprite: [x0, y0, x1, y1, largura, altura].

    Os sprites têm bordas transparentes de tamanhos diferentes (um Bulbasaur
    ocupa bem menos da imagem que um Charizard). Com esta caixa, o site amplia
    cada Pokémon para preencher o mesmo espaço e todos ficam do mesmo tamanho.
    """
    if not path or not path.endswith('.png'):
        return None
    if path not in _boxes:
        try:
            with Image.open(os.path.join(DB, 'sprites', path)) as im:
                bbox = im.convert('RGBA').getbbox()
                _boxes[path] = [*bbox, *im.size] if bbox else None
        except FileNotFoundError:
            _boxes[path] = None
    return _boxes[path]


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
            'from': {'id': node['species'], 'name': node['name'], 'sprite': sprite_of(node['species']), 'box': box(sprite_of(node['species']))},
            'to': {'id': child['species'], 'name': child['name'], 'sprite': sprite_of(child['species']), 'box': box(sprite_of(child['species']))},
            'trigger': trigger,
        })
        edges.extend(evolution_edges(child, sprite_of))
    return edges


def clean_genus(genus):
    """'Pokémon Semente' / 'Seed Pokémon' → 'Semente' / 'Seed'."""
    return re.sub(r'^Pokémon ', '', (genus or '').replace(' Pokémon', ''))


def local_names(s):
    """Nome da espécie em inglês, francês e espanhol (só os que mudam)."""
    if not s:
        return {}
    names = s.get('names') or {}
    out = {lang: names[lang] for lang in ('en', 'fr', 'es') if names.get(lang)}
    return {k: v for k, v in out.items() if k == 'en' or v != out.get('en')}


def main():
    pokemon = load('pokemon')
    species = load('species')
    chains = load('evolution_chains')
    moves = load('moves')
    abilities = load('abilities')
    items = load('items')
    types = load('types')
    egg_groups = load('egg_groups')
    encounters = load('encounters')
    exclusives = load('exclusives')
    locations = load('locations')

    by_id = {p['id']: p for p in pokemon}
    species_by_id = {s['id']: s for s in species}

    def sprite_of(pokemon_id):
        p = by_id.get(pokemon_id)
        return p['sprites'][0] if p else None

    # Índice leve de todos os Pokémon (inclusive formas), usado em listas.
    index = []
    for p in pokemon:
        s = species_by_id.get(p['species'])
        sprite = p['sprites'][0] or p['sprites'][2]
        index.append({
            'id': p['id'],
            'name': p['name'],
            'species': p['species'],
            'default': p['id'] < 10000,
            'gen': s['generation'] if s else None,
            'types': p['types'],
            'sprite': sprite,
            'box': box(sprite),
            'games': p.get('games', []),
            # Nome da espécie em outros idiomas (português = inglês).
            'names': local_names(s),
            # Filtros da Pokédex: status base, habilidades e lendário/mítico.
            'stats': [v for v, _ in p['stats']],
            'abilities': [a for a, _ in p['abilities']],
            # Exclusivos de uma versão: {jogo: versão} ("só em Red").
            'only': exclusives.get(str(p['id']), {}),
            'tag': ('mythical' if s['is_mythical'] else 'legendary' if s['is_legendary'] else 'baby' if s['is_baby'] else None) if s else None,
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
                'boxes': [box(p['sprites'][0]), box(p['sprites'][1])],
                'moves': p['moves'],
                'games': p.get('games', []),
                # Onde encontrar: [área, jogo, método, nívelMín, nívelMáx, chance, versões]
                'encounters': encounters.get(str(p['id']), []),
                'only': exclusives.get(str(p['id']), {}),
            })
        save(f"pokemon/{s['id']}.json", {
            'id': s['id'],
            'name': s['name'],
            'genus': clean_genus(s['genus']),
            'flavor': s['flavor'] or 'Sem descrição.',
            # Outros idiomas (en, fr, es): nome, descrição e categoria.
            'names': local_names(s),
            'flavors': s.get('flavors') or {},
            'genera': {k: clean_genus(v) for k, v in (s.get('genera') or {}).items()},
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
        text = entry.get('effect') or 'Sem descrição.'
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

    # Criação (cadeia de golpes de ovo, igual ao app lib/services/egg_chain.dart):
    #   breeding.json   {espécie: [grupos de ovo, gender_rate, evolui de, golpes de ovo]}
    #   egg_moves.json  {golpe de ovo: {pokémon: como aprende}}
    #                   como: nível (>= 1), 0 = TM/tutor, -1 = de ovo
    defaults = [p for p in pokemon if p['id'] < 10000]
    own_egg_moves = {p['id']: sorted({m[0] for m in p['moves'] if m[1] == 'egg'}) for p in defaults}
    save('breeding.json', {
        s['id']: [s['egg_groups'], s['gender_rate'], s['evolves_from'], own_egg_moves.get(s['id'], [])] for s in species
    })
    egg_move_names = {m[0] for p in defaults for m in p['moves'] if m[1] == 'egg'}
    learn = {}
    for p in defaults:
        best = {}
        for name, method, level in p['moves']:
            if name not in egg_move_names:
                continue
            code = (level or 1) if method == 'level-up' else 0 if method in ('machine', 'tutor') else -1 if method == 'egg' else None
            if code is None:
                continue
            old = best.get(name)
            # Prioridade: nível (o mais cedo) > TM/tutor > ovo.
            if old is None or (code >= 1 and (old < 1 or code < old)) or (code == 0 and old == -1):
                best[name] = code
        for name, code in best.items():
            learn.setdefault(name, {})[p['id']] = code
    save('egg_moves.json', learn)
    # Sets prontos do Montador (tool/build_sets.py).
    save('sets.json', load('sets'))

    save('abilities.json', [{
        'id': a['id'],
        'name': a['name'],
        'effect': a['effect'] or 'Sem descrição.',
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
        'effect': i['effect'] or 'Sem descrição.',
        'flavor': i['flavor'],
        'cost': i['cost'],
        'attributes': i['attributes'],
    } for i in items])

    # Descrições em outros idiomas (só baixadas com o idioma escolhido).
    for lang in ('en', 'fr', 'es'):
        save(f'texts_{lang}.json', {
            kind: {r['name']: r['flavors'][lang] for r in rows if (r.get('flavors') or {}).get(lang)}
            for kind, rows in (('moves', moves), ('abilities', abilities), ('items', items))
        })

    save('types.json', {name: t['damage_relations'] for name, t in types.items()})
    save('egg_groups.json', egg_groups)
    save('locations.json', locations)
    # Áreas de cada jogo (para o Nuzlocke): por região e nome.
    areas = {}
    for rows in encounters.values():
        for area, game, *_ in rows:
            areas.setdefault(game, set()).add(area)
    save('game_areas.json', {
        game: sorted(names, key=lambda a: ((locations.get(a) or {}).get('region') or '', (locations.get(a) or {}).get('name') or a))
        for game, names in areas.items()
    })

    # Imagens.
    shutil.copytree(os.path.join(DB, 'sprites'), os.path.join(OUT, 'sprites'), dirs_exist_ok=True)
    shutil.copytree(os.path.join(DB, 'cries'), os.path.join(OUT, 'cries'), dirs_exist_ok=True)
    os.makedirs(os.path.join(OUT, 'img'), exist_ok=True)
    for image in ('pokeball.png', 'poke_logo.png'):
        shutil.copyfile(os.path.join(ROOT, 'assets', 'images', image), os.path.join(OUT, 'img', image))

    total = sum(os.path.getsize(os.path.join(r, f)) for r, _, fs in os.walk(DATA) for f in fs)
    print(f'dados do site: {len(index)} Pokémon, {len(species)} espécies, {total // 1024} KB em {DATA}')


if __name__ == '__main__':
    main()
