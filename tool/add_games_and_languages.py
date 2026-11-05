#!/usr/bin/env python3
"""Acrescenta ao banco local (assets/database/) os jogos de cada Pokémon e os
textos em outros idiomas, a partir do dump estático da PokeAPI (api-data).

  pokemon.json  → "games": jogos em que o Pokémon (ou a forma) aparece, pelas
                  chaves de GAMES (golpes por jogo + Pokédex regionais da espécie).
  species.json  → "flavors" e "genera": descrição e categoria em en, fr, es
                  (o português já está em "flavor" e "genus").

Uso (com api-data baixado como em tool/build_database.py, mais as pastas
version, version-group e pokedex):
    python3 tool/add_games_and_languages.py api-data
"""

import json
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
DB = os.path.join(ROOT, 'assets', 'database')

# Grupo de versões da PokeAPI → jogo (mesma ordem do site e do app).
GROUP_TO_GAME = {
    'red-blue': 'rb', 'red-green-japan': 'rb', 'blue-japan': 'rb',
    'yellow': 'yellow',
    'gold-silver': 'gs',
    'crystal': 'crystal',
    'ruby-sapphire': 'rs',
    'emerald': 'emerald',
    'firered-leafgreen': 'frlg',
    'diamond-pearl': 'dp',
    'platinum': 'platinum',
    'heartgold-soulsilver': 'hgss',
    'black-white': 'bw',
    'black-2-white-2': 'b2w2',
    'x-y': 'xy',
    'omega-ruby-alpha-sapphire': 'oras',
    'sun-moon': 'sm',
    'ultra-sun-ultra-moon': 'usum',
    'lets-go-pikachu-lets-go-eevee': 'lgpe',
    'sword-shield': 'swsh', 'the-isle-of-armor': 'swsh', 'the-crown-tundra': 'swsh',
    'brilliant-diamond-shining-pearl': 'bdsp',
    'legends-arceus': 'pla',
    'scarlet-violet': 'sv', 'the-teal-mask': 'sv', 'the-indigo-disk': 'sv',
    'legends-za': 'lza', 'mega-dimension': 'lza',
    # Jogos secundários.
    'colosseum': 'colosseum',
    'xd': 'xd',
    'champions': 'champions',
}
# Pokédex sem grupo de versões na PokeAPI (jogos secundários).
DEX_TO_GAME = {'conquest-gallery': 'conquest'}
GAME_ORDER = ['rb', 'yellow', 'gs', 'crystal', 'rs', 'emerald', 'frlg', 'dp', 'platinum', 'hgss', 'bw', 'b2w2',
              'xy', 'oras', 'sm', 'usum', 'lgpe', 'swsh', 'bdsp', 'pla', 'sv', 'lza',
              'colosseum', 'xd', 'conquest', 'champions']
LANGS = ['en', 'fr', 'es']


def load_json(path):
    with open(path, encoding='utf-8') as f:
        return json.load(f)


def clean(text):
    return ' '.join(text.replace('­', '').split()) if text else text


def main(api):
    v2 = os.path.join(api, 'data', 'api', 'v2')

    version_group = {}
    for d in os.listdir(os.path.join(v2, 'version')):
        if d.isdigit():
            v = load_json(os.path.join(v2, 'version', d, 'index.json'))
            version_group[v['name']] = v['version_group']['name']
    dex_groups = {}
    for d in os.listdir(os.path.join(v2, 'pokedex')):
        if d.isdigit():
            p = load_json(os.path.join(v2, 'pokedex', d, 'index.json'))
            dex_groups[p['name']] = [g['name'] for g in p['version_groups']]

    species_path = os.path.join(DB, 'species.json')
    species = load_json(species_path)
    species_dex = {}
    for s in species:
        raw = load_json(os.path.join(v2, 'pokemon-species', str(s['id']), 'index.json'))
        species_dex[s['id']] = [d['pokedex']['name'] for d in raw['pokedex_numbers']]
        flavors, genera = {}, {}
        for lang in LANGS:
            # A descrição mais recente no idioma (a da PokeAPI vem em ordem de jogo).
            texts = [clean(f['flavor_text']) for f in raw['flavor_text_entries'] if f['language']['name'] == lang]
            if texts:
                flavors[lang] = texts[-1]
            genus = next((g['genus'] for g in raw['genera'] if g['language']['name'] == lang), None)
            if genus:
                genera[lang] = genus
        s['flavors'] = flavors
        s['genera'] = genera
    with open(species_path, 'w', encoding='utf-8') as f:
        json.dump(species, f, ensure_ascii=False, separators=(',', ':'))

    pokemon_path = os.path.join(DB, 'pokemon.json')
    pokemon = load_json(pokemon_path)
    for p in pokemon:
        path = os.path.join(v2, 'pokemon', str(p['id']), 'index.json')
        groups = set()
        if os.path.exists(path):
            raw = load_json(path)
            for m in raw['moves']:
                for d in m['version_group_details']:
                    groups.add(d['version_group']['name'])
            # (game_indices não serve: a PokeAPI lista todos os jogos para todos.)
        # Pokédex regionais: só para a forma padrão (as regionais têm os próprios golpes).
        extra = set()
        if p.get('is_default'):
            for dex in species_dex.get(p['species'], []):
                groups.update(dex_groups.get(dex, []))
                if dex in DEX_TO_GAME:
                    extra.add(DEX_TO_GAME[dex])
        games = {GROUP_TO_GAME[g] for g in groups if g in GROUP_TO_GAME} | extra
        # Formas só de batalha, sem golpes próprios na PokeAPI.
        if p['name'].endswith('-gmax'):
            games.add('swsh')
        if '-totem' in p['name']:
            games.update(['sm', 'usum'])
        # Megas: a Mega Evolução voltou em Legends: Z-A (e na DLC Mega Dimension).
        if '-mega' in p['name']:
            games.add('lza')
        p['games'] = [g for g in GAME_ORDER if g in games]
    with open(pokemon_path, 'w', encoding='utf-8') as f:
        json.dump(pokemon, f, ensure_ascii=False, separators=(',', ':'))

    # Golpes, habilidades e itens: descrição do jogo em en, fr e es.
    for table, folder in (('moves', 'move'), ('abilities', 'ability'), ('items', 'item')):
        base = os.path.join(v2, folder)
        if not os.path.isdir(base):
            continue
        by_name = {}
        for d in os.listdir(base):
            if d.isdigit():
                raw = load_json(os.path.join(base, d, 'index.json'))
                flavors = {}
                for lang in LANGS:
                    texts = [clean(f.get('flavor_text') or f.get('text')) for f in raw.get('flavor_text_entries', [])
                             if f['language']['name'] == lang]
                    texts = [t for t in texts if t and 'XXX' not in t and 'dummy' not in t.lower()]
                    if texts:
                        flavors[lang] = texts[-1]
                by_name[raw['name']] = flavors
        path = os.path.join(DB, f'{table}.json')
        rows = load_json(path)
        for row in rows:
            row['flavors'] = by_name.get(row['name'], {})
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(rows, f, ensure_ascii=False, separators=(',', ':'))
        print(f'{table}: {sum(1 for r in rows if r["flavors"])} de {len(rows)} com descrição em outros idiomas')

    no_games = [p['name'] for p in pokemon if not p['games']]
    print(f'{len(pokemon)} Pokémon/formas; sem jogo: {len(no_games)} {no_games[:10]}')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'api-data')
