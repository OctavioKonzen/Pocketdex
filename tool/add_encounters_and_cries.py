#!/usr/bin/env python3
"""Coloca no banco local onde encontrar cada Pokémon e o grito de cada um.

Lê uma cópia dos dados da PokeAPI (repositório PokeAPI/api-data, pastas
pokemon/*/encounters, location-area e location) e dos gritos
(repositório PokeAPI/cries, pasta cries/pokemon/latest). O app e o site não
acessam a PokeAPI: tudo fica em assets/database/.

Saída:
    assets/database/encounters.json   {idDoPokémon: [[área, jogo, método, nívelMín, nívelMáx, chance, versões]]}
    assets/database/locations.json    {área: {name, names: {fr, es}, region}}
    assets/database/cries/<id>.mp3    grito (mono, 32 kbps) de cada espécie

Os locais cobrem os jogos que a PokeAPI tem (até Sword/Shield e os DLCs).

Uso:
    python3 tool/add_encounters_and_cries.py <api-data> <cries> [ffmpeg]
"""

import json
import os
import re
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
DB = os.path.join(ROOT, 'assets', 'database')

# Versão da PokeAPI → jogo do PocketDex (lib/models/game.dart e web-site/src/lib/pokemon.js).
VERSION_TO_GAME = {
    'red': 'rb', 'blue': 'rb', 'red-japan': 'rb', 'green-japan': 'rb', 'blue-japan': 'rb',
    'yellow': 'yellow',
    'gold': 'gs', 'silver': 'gs',
    'crystal': 'crystal',
    'ruby': 'rs', 'sapphire': 'rs',
    'emerald': 'emerald',
    'firered': 'frlg', 'leafgreen': 'frlg',
    'diamond': 'dp', 'pearl': 'dp',
    'platinum': 'platinum',
    'heartgold': 'hgss', 'soulsilver': 'hgss',
    'black': 'bw', 'white': 'bw',
    'black-2': 'b2w2', 'white-2': 'b2w2',
    'x': 'xy', 'y': 'xy',
    'omega-ruby': 'oras', 'alpha-sapphire': 'oras',
    'sun': 'sm', 'moon': 'sm',
    'ultra-sun': 'usum', 'ultra-moon': 'usum',
    'lets-go-pikachu': 'lgpe', 'lets-go-eevee': 'lgpe',
    'sword': 'swsh', 'shield': 'swsh',
    'the-isle-of-armor-sword': 'swsh', 'the-isle-of-armor-shield': 'swsh',
    'the-crown-tundra-sword': 'swsh', 'the-crown-tundra-shield': 'swsh',
    'colosseum': 'colosseum', 'xd': 'xd',
}

# Nome curto da versão, quando o Pokémon só aparece em uma delas.
VERSION_SHORT = {
    'red': 'Red', 'blue': 'Blue', 'red-japan': 'Red (JP)', 'green-japan': 'Green (JP)', 'blue-japan': 'Blue (JP)',
    'gold': 'Gold', 'silver': 'Silver', 'ruby': 'Ruby', 'sapphire': 'Sapphire',
    'firered': 'FireRed', 'leafgreen': 'LeafGreen', 'diamond': 'Diamond', 'pearl': 'Pearl',
    'heartgold': 'HeartGold', 'soulsilver': 'SoulSilver', 'black': 'Black', 'white': 'White',
    'black-2': 'Black 2', 'white-2': 'White 2', 'x': 'X', 'y': 'Y',
    'omega-ruby': 'Omega Ruby', 'alpha-sapphire': 'Alpha Sapphire', 'sun': 'Sun', 'moon': 'Moon',
    'ultra-sun': 'Ultra Sun', 'ultra-moon': 'Ultra Moon', 'lets-go-pikachu': "Let's Go Pikachu",
    'lets-go-eevee': "Let's Go Eevee", 'sword': 'Sword', 'shield': 'Shield',
    'the-isle-of-armor-sword': 'Sword', 'the-isle-of-armor-shield': 'Shield',
    'the-crown-tundra-sword': 'Sword', 'the-crown-tundra-shield': 'Shield',
}

GAME_VERSIONS = {}
for v, g in VERSION_TO_GAME.items():
    GAME_VERSIONS.setdefault(g, set()).add(VERSION_SHORT.get(v, v))


def load(path):
    with open(path, encoding='utf-8') as f:
        return json.load(f)


def names_of(entry):
    return {n['language']['name']: n['name'] for n in entry.get('names', [])}


def pretty(slug):
    return ' '.join(w[:1].upper() + w[1:] for w in slug.replace('-', ' ').split())


def main():
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    api = os.path.join(sys.argv[1], 'data', 'api', 'v2')
    cries = sys.argv[2]
    ffmpeg = sys.argv[3] if len(sys.argv) > 3 else 'ffmpeg'

    pokemon = load(os.path.join(DB, 'pokemon.json'))
    species_ids = sorted({p['species'] for p in pokemon})

    # ------------------------------------------------------------ locais
    locations = {}  # nome da área → {name, names, region}
    location_cache = {}

    def area_info(area_name, url):
        if area_name in locations:
            return
        area_id = re.search(r'/(\d+)/?$', url).group(1)
        area = load(os.path.join(api, 'location-area', area_id, 'index.json'))
        loc_name = area['location']['name']
        if loc_name not in location_cache:
            loc_id = re.search(r'/(\d+)/?$', area['location']['url']).group(1)
            location_cache[loc_name] = load(os.path.join(api, 'location', loc_id, 'index.json'))
        loc = location_cache[loc_name]
        loc_names = names_of(loc)
        area_names = names_of(area)
        # Parte da área além do lugar ("1f", "south-towards-route-..."), se houver.
        suffix = area_name.removeprefix(loc_name).strip('-')
        suffix = '' if suffix in ('', 'area') else pretty(suffix.removesuffix('-area'))

        def label(lang):
            if area_names.get(lang):
                return area_names[lang]
            base = loc_names.get(lang) or loc_names.get('en') or pretty(loc_name)
            return f'{base} ({suffix})' if suffix else base

        en = label('en')
        locations[area_name] = {
            'name': en,
            'names': {lang: label(lang) for lang in ('fr', 'es') if label(lang) != en},
            'region': (loc.get('region') or {}).get('name'),
        }

    encounters = {}
    for p in pokemon:
        path = os.path.join(api, 'pokemon', str(p['id']), 'encounters', 'index.json')
        if not os.path.exists(path):
            continue
        rows = {}
        for e in load(path):
            area = e['location_area']['name']
            area_info(area, e['location_area']['url'])
            for vd in e['version_details']:
                version = vd['version']['name']
                game = VERSION_TO_GAME.get(version)
                if not game:
                    continue
                for d in vd['encounter_details']:
                    key = (area, game, d['method']['name'])
                    row = rows.setdefault(key, {'min': d['min_level'], 'max': d['max_level'], 'chance': 0, 'versions': set()})
                    row['min'] = min(row['min'], d['min_level'])
                    row['max'] = max(row['max'], d['max_level'])
                    row['chance'] = max(row['chance'], d['chance'] or 0)
                    row['versions'].add(VERSION_SHORT.get(version, version))
        if rows:
            out = []
            for (area, game, method), r in sorted(rows.items(), key=lambda kv: (kv[0][1], kv[0][0], kv[0][2])):
                # Só guarda as versões quando não são todas as do jogo (ex.: só Sword).
                versions = sorted(r['versions']) if r['versions'] != GAME_VERSIONS[game] else []
                out.append([area, game, method, r['min'], r['max'], r['chance'], versions])
            encounters[str(p['id'])] = out

    with open(os.path.join(DB, 'encounters.json'), 'w', encoding='utf-8') as f:
        json.dump(encounters, f, ensure_ascii=False, separators=(',', ':'))
    with open(os.path.join(DB, 'locations.json'), 'w', encoding='utf-8') as f:
        json.dump(locations, f, ensure_ascii=False, separators=(',', ':'), sort_keys=True)
    print(f'locais: {len(encounters)} Pokémon, {len(locations)} áreas')

    # ------------------------------------------------------------ gritos
    out_dir = os.path.join(DB, 'cries')
    os.makedirs(out_dir, exist_ok=True)
    done = 0
    for sid in species_ids:
        src = os.path.join(cries, 'cries', 'pokemon', 'latest', f'{sid}.ogg')
        dst = os.path.join(out_dir, f'{sid}.mp3')
        if not os.path.exists(src) or os.path.exists(dst):
            continue
        subprocess.run([ffmpeg, '-loglevel', 'error', '-y', '-i', src, '-ac', '1', '-ar', '22050', '-b:a', '32k', dst], check=True)
        done += 1
    total = sum(os.path.getsize(os.path.join(out_dir, n)) for n in os.listdir(out_dir))
    print(f'gritos: {len(os.listdir(out_dir))} arquivos ({done} novos), {total // 1024} KB')


if __name__ == '__main__':
    main()
