#!/usr/bin/env python3
"""Coloca no banco local onde encontrar cada Pokémon e o grito de cada um.

Lê uma cópia dos dados da PokeAPI (repositório PokeAPI/api-data, pastas
pokemon/*/encounters, location-area e location) e dos gritos
(repositório PokeAPI/cries, pasta cries/pokemon/latest). O app e o site não
acessam a PokeAPI: tudo fica em assets/database/.

Saída:
    assets/database/encounters.json   {idDoPokémon: [[área, jogo, método, nívelMín, nívelMáx, chance, versões]]}
    assets/database/locations.json    {área: {name, names: {fr, es}, region}}
    assets/database/exclusives.json   {idDoPokémon: {jogo: versão}} exclusivos de uma versão
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

# As duas versões de cada jogo (para os exclusivos: "só em Red").
PAIRS = {
    'rb': ['Red', 'Blue'], 'gs': ['Gold', 'Silver'], 'rs': ['Ruby', 'Sapphire'], 'frlg': ['FireRed', 'LeafGreen'],
    'dp': ['Diamond', 'Pearl'], 'hgss': ['HeartGold', 'SoulSilver'], 'bw': ['Black', 'White'],
    'b2w2': ['Black 2', 'White 2'], 'xy': ['X', 'Y'], 'oras': ['Omega Ruby', 'Alpha Sapphire'], 'sm': ['Sun', 'Moon'],
    'usum': ['Ultra Sun', 'Ultra Moon'], 'lgpe': ["Let's Go Pikachu", "Let's Go Eevee"], 'swsh': ['Sword', 'Shield'],
}
# Scarlet/Violet (a PokeAPI não tem os locais deles).
SV_EXCLUSIVES = {
    'Scarlet': ['larvitar', 'pupitar', 'tyranitar', 'drifloon', 'drifblim', 'stunky', 'skuntank', 'skrelp', 'dragalge',
                'oranguru', 'stonjourner', 'armarouge', 'great-tusk', 'scream-tail', 'brute-bonnet', 'flutter-mane',
                'slither-wing', 'sandy-shocks', 'roaring-moon', 'koraidon'],
    'Violet': ['bagon', 'shelgon', 'salamence', 'misdreavus', 'mismagius', 'gulpin', 'swalot', 'clauncher', 'clawitzer',
               'passimian', 'eiscue-ice', 'ceruledge', 'iron-treads', 'iron-bundle', 'iron-hands', 'iron-jugulis',
               'iron-moth', 'iron-thorns', 'iron-valiant', 'miraidon'],
}

# Versões japonesas de Red/Blue: Red (JP) = Red; Green (JP) tinha os de Blue.
SAME_AS = {'Red (JP)': 'Red', 'Green (JP)': 'Blue', 'Blue (JP)': None}

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

    # ------------------------------------------------------------ exclusivos
    # Um Pokémon é exclusivo de uma versão quando todos os encontros dele no
    # jogo são só nela. Sem encontro no jogo (ex.: evolução), herda o da
    # pré-evolução (Growlithe só em Red → Arcanine também).
    species = {sp['id']: sp for sp in load(os.path.join(DB, 'species.json'))}
    by_id = {pk['id']: pk for pk in pokemon}
    default_of = {sp_id: sp_id for sp_id in species}  # a forma padrão tem o id da espécie

    def own(pid, game):
        rows = [r for r in encounters.get(str(pid), []) if r[1] == game]
        if not rows:
            return None
        found = set()
        for r in rows:
            if not r[6]:
                return ''  # nas duas versões
            for v in r[6]:
                v = SAME_AS.get(v, v)
                if v:
                    found.add(v)
        both = set(PAIRS[game])
        found &= both
        return next(iter(found)) if len(found) == 1 else ('' if found else None)

    exclusives = {}
    for pk in pokemon:
        for game in pk.get('games', []):
            if game not in PAIRS:
                continue
            result = own(pk['id'], game)
            sp = species.get(pk['species'])
            # Sem encontros: procura na pré-evolução.
            while result is None and sp and sp.get('evolves_from'):
                sp = species.get(sp['evolves_from'])
                pre = default_of.get(sp['id']) if sp else None
                if pre is None or game not in by_id.get(pre, {}).get('games', []):
                    break
                result = own(pre, game)
            if result:
                exclusives.setdefault(str(pk['id']), {})[game] = result
    # Jogos sem dados de locais na PokeAPI:
    #   BDSP repete os exclusivos de Diamond/Pearl;
    #   Scarlet/Violet: lista oficial (jogo base).
    by_name = {pk['name']: pk for pk in pokemon}
    for pk in pokemon:
        dp = exclusives.get(str(pk['id']), {}).get('dp')
        if dp and 'bdsp' in pk.get('games', []):
            exclusives[str(pk['id'])]['bdsp'] = {'Diamond': 'Brilliant Diamond', 'Pearl': 'Shining Pearl'}[dp]
    for version, names in SV_EXCLUSIVES.items():
        for name in names:
            pk = by_name.get(name)
            if pk and 'sv' in pk.get('games', []):
                exclusives.setdefault(str(pk['id']), {})['sv'] = version
    with open(os.path.join(DB, 'exclusives.json'), 'w', encoding='utf-8') as f:
        json.dump(exclusives, f, ensure_ascii=False, separators=(',', ':'), sort_keys=True)
    print(f'exclusivos: {sum(len(v) for v in exclusives.values())} (Pokémon, jogo)')

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
