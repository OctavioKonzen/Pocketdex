"""Times oficiais dos personagens (líderes, Elite Four, campeões, vilões e
rivais), exatamente como estão nos jogos, a partir dos projetos de
desmontagem pret (github.com/pret). Nível, golpes, item, IVs, EVs, nature e
habilidade como o jogo gera. Separado por jogo; todas as lutas de cada um.

Saída: assets/database/official_teams.json

Uso:
    python3 tool/build_official_teams.py <pasta com os arquivos do pret>
    (a pasta tem uma subpasta por projeto: trevenant/ (o repositório do
    Trevenant, para os jogos sem desmontagem; ver tool/official_teams/wiki.py),
    pokebw2/ (Black 2/White 2, a
    desmontagem inteira), sv/ (Scarlet/Violet, ver
    tool/official_teams/gen9.py), pokered/, pokeyellow/, pokegold/,
    pokecrystal/, pokeruby/, pokeemerald/, pokefirered/, pokeplatinum/, com os
    arquivos que cada módulo de tool/official_teams/ lê; para a 2ª geração,
    os scripts dos mapas ficam em maps/<projeto>/maps/, de onde sai o local
    de cada luta do rival e dos executivos)
"""

import json
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'official_teams'))
import gen1  # noqa: E402
import gen2  # noqa: E402
import gen3  # noqa: E402
import gen4  # noqa: E402
import gen5  # noqa: E402
import gen9  # noqa: E402
import wiki  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(ROOT, 'assets', 'database')

# Constantes do pret que não batem com o nome do banco (PokéAPI).
ALIASES = {
    'species': {'NIDORAN_F': 'nidoran-f', 'NIDORAN_M': 'nidoran-m', 'MR_MIME': 'mr-mime', 'MR__MIME': 'mr-mime', 'HO_OH': 'ho-oh', 'FARFETCHD': 'farfetchd'},
    'move': {
        'HI_JUMP_KICK': 'high-jump-kick', 'SMELLING_SALT': 'smelling-salts', 'FAINT_ATTACK': 'feint-attack',
        'SONICBOOM': 'sonic-boom', 'DOUBLESLAP': 'double-slap', 'THUNDERPUNCH': 'thunder-punch', 'THUNDERSHOCK': 'thunder-shock',
        'SOLARBEAM': 'solar-beam', 'SELFDESTRUCT': 'self-destruct', 'POISONPOWDER': 'poison-powder', 'DYNAMICPUNCH': 'dynamic-punch',
        'EXTREMESPEED': 'extreme-speed', 'ANCIENTPOWER': 'ancient-power', 'DRAGONBREATH': 'dragon-breath', 'BUBBLEBEAM': 'bubble-beam',
        'SAND_ATTACK': 'sand-attack', 'VICEGRIP': 'vise-grip', 'VICE_GRIP': 'vise-grip', 'SOFTBOILED': 'soft-boiled', 'GRASSWHISTLE': 'grass-whistle',
        'FEATHERDANCE': 'feather-dance', 'PSYCHO_BOOST': 'psycho-boost', 'MUD_SLAP': 'mud-slap', 'U_TURN': 'u-turn', 'SMOKE_SCREEN': 'smokescreen', 'PSYCHIC_M': 'psychic',
    },
    'item': {},
    'ability': {},
}

GAMES = [
    ('red-blue', 'Red/Blue', 'Kanto', 1, gen1, 'pokered', {}),
    ('yellow', 'Yellow', 'Kanto', 1, gen1, 'pokeyellow', {}),
    # (id, nome, região, geração, módulo, pasta pret, arquivos)
    ('gold-silver', 'Gold/Silver', 'Johto', 2, gen2, 'pokegold', {}),
    ('crystal', 'Crystal', 'Johto', 2, gen2, 'pokecrystal', {}),
    ('ruby-sapphire', 'Ruby/Sapphire', 'Hoenn', 3, gen3, 'pokeruby', {
        'charmap': 'charmap.txt', 'species_names': 'species_names.h', 'species_info': 'base_stats.h',
        'learnsets': 'level_up_learnsets.h', 'learnset_pointers': 'level_up_learnset_pointers.h',
        'trainers': 'trainers_en.h', 'parties': 'trainer_parties.h'}),
    ('emerald', 'Emerald', 'Hoenn', 3, gen3, 'pokeemerald', {
        'charmap': 'charmap.txt', 'species_names': 'species_names.h', 'species_info': 'species_info.h',
        'learnsets': 'level_up_learnsets.h', 'learnset_pointers': 'level_up_learnset_pointers.h',
        'trainers': 'trainers.h', 'parties': 'trainer_parties.h'}),
    ('firered-leafgreen', 'FireRed/LeafGreen', 'Kanto', 3, gen3, 'pokefirered', {
        'charmap': 'charmap.txt', 'species_names': 'species_names.h', 'species_info': 'species_info.h',
        'learnsets': 'level_up_learnsets.h', 'learnset_pointers': 'level_up_learnset_pointers.h',
        'trainers': 'trainers.h', 'parties': 'trainer_parties.h'}),
    ('diamond-pearl', 'Diamond/Pearl', 'Sinnoh', 4, wiki, 'trevenant', {}),
    ('platinum', 'Platinum', 'Sinnoh', 4, gen4, 'pokeplatinum', {}),
    ('heartgold-soulsilver', 'HeartGold/SoulSilver', 'Johto', 4, wiki, 'trevenant', {}),
    ('black-white', 'Black/White', 'Unova', 5, wiki, 'trevenant', {}),
    ('black2-white2', 'Black 2/White 2', 'Unova', 5, gen5, 'pokebw2', {}),
    ('x-y', 'X/Y', 'Kalos', 6, wiki, 'trevenant', {}),
    ('omegaruby-alphasapphire', 'Omega Ruby/Alpha Sapphire', 'Hoenn', 6, wiki, 'trevenant', {}),
    ('sun-moon', 'Sun/Moon', 'Alola', 7, wiki, 'trevenant', {}),
    ('ultrasun-ultramoon', 'Ultra Sun/Ultra Moon', 'Alola', 7, wiki, 'trevenant', {}),
    ('sword-shield', 'Sword/Shield', 'Galar', 8, wiki, 'trevenant', {}),
    ('brilliantdiamond-shiningpearl', 'Brilliant Diamond/Shining Pearl', 'Sinnoh', 8, wiki, 'trevenant', {}),
    ('scarlet-violet', 'Scarlet/Violet', 'Paldea', 9, gen9, 'sv', {}),
]

STARTERS = {'MUDKIP', 'TREECKO', 'TORCHIC', 'SQUIRTLE', 'BULBASAUR', 'CHARMANDER', 'CHIKORITA', 'CYNDAQUIL', 'TOTODILE',
            'TURTWIG', 'CHIMCHAR', 'PIPLUP'}
# Treinadores nas classes de rival que não lutam contra você (parceiros, link).
SKIP = {('emerald', 'STEVEN'), ('emerald', 'RED'), ('emerald', 'LEAF')}
# Rivais com o nome que o jogador escolhe: o nome padrão de cada jogo.
RIVAL_NAMES = {'TERRY': 'Blue', 'CEDRIC': 'Barry'}


# Retrato (assets/database/trainers.json) quando o nome não bate direto.
PORTRAITS = {('Campeão', 'Blue'): 'champion-blue', ('Líder de Ginásio', 'Blue'): 'champion-blue', 'Drake': 'sd-drake-gen3', 'Phoebe': 'sd-phoebe-gen6', 'Maxie': 'sd-maxie-gen6',
             'Archie': 'sd-archie-gen6', 'Nemona': 'sd-nemona-v', 'Brendan/May': 'brendan', 'Arven': 'sd-arven-v', 'Clavell': 'sd-clavell-s', 'Executivo': 'rocket-grunt-m', 'Executiva': 'rocket-grunt-f'}


def portrait(person, ids):
    name = person['name']
    if (person['class'], name) in PORTRAITS or name in PORTRAITS:
        return PORTRAITS.get((person['class'], name)) or PORTRAITS[name]
    slug = re.sub(r'[^a-z0-9]+', '-', name.lower()).strip('-')
    return next((c for c in (slug, 'sd-' + slug, 'sd-' + slug.replace('-', '')) if c in ids), None)


# Ginásios na ordem das insígnias (o código do jogo nem sempre segue essa ordem).
GYM_ORDER = ['Falkner', 'Bugsy', 'Whitney', 'Morty', 'Chuck', 'Jasmine', 'Pryce', 'Clair',
             'Brock', 'Misty', 'Lt. Surge', 'Erika', 'Koga', 'Janine', 'Sabrina', 'Blaine', 'Giovanni', 'Blue',
             'Cheren', 'Roxie', 'Burgh', 'Elesa', 'Clay', 'Skyla', 'Drayden', 'Marlon',
             'Katy', 'Brassius', 'Iono', 'Kofu', 'Larry', 'Ryme', 'Tulip', 'Grusha',
             'Roark', 'Gardenia', 'Fantina', 'Maylene', 'Wake', 'Byron', 'Candice', 'Volkner']


def read(path):
    raw = open(path, 'rb').read()
    try:
        return raw.decode('utf-8')
    except UnicodeDecodeError:
        return raw.decode('latin-1')


def load(name):
    with open(os.path.join(DB, f'{name}.json'), encoding='utf-8') as f:
        return json.load(f)


def resolver(errors):
    pokemon = load('pokemon')
    by_name = {p['name']: p for p in pokemon}
    known = {
        'move': {m['name'] for m in load('moves')},
        'item': {i['name'] for i in load('items')},
        'ability': {a['name'] for a in load('abilities')},
    }

    move_by_id = {m['id']: m['name'] for m in load('moves')}

    names = {'move_name': known['move'], 'item_name': known['item'], 'ability_name': known['ability']}

    def resolve(kind, const):
        if kind == 'species_name':
            name = WIKI_SPECIES.get(const, wiki.slug(const))
            p = by_name.get(name) or next((p for p in pokemon if p['is_default'] and p['name'].startswith(name + '-')), None)
            if not p:
                errors.add(f'{kind} {const} -> {name}')
            return p and p['id']
        if kind in names:
            name = WIKI_NAMES.get(const, wiki.slug(const))
            if kind == 'item_name' and name.endswith('ium-z'):
                name += '--held'  # Cristais Z (o banco tem a versão de segurar)
            if name not in names[kind]:
                errors.add(f'{kind} {const} -> {name}')
                return None
            return name
        if kind == 'move_id':
            if const not in move_by_id:
                errors.add(f'move id {const}')
            return move_by_id.get(const)
        prefix = {'species': 'SPECIES_', 'move': 'MOVE_', 'item': 'ITEM_', 'ability': 'ABILITY_'}[kind]
        raw = const[len(prefix):]
        name = ALIASES[kind].get(raw, raw.lower().replace('_', '-'))
        if kind == 'species':
            p = by_name.get(name) or next((p for p in pokemon if p['is_default'] and p['name'].startswith(name + '-')), None)
            if not p:
                errors.add(f'{kind} {const}')
                return None
            return p['id']
        if name not in known[kind]:
            errors.add(f'{kind} {const} -> {name}')
        return name
    return resolve


# Nomes do Trevenant que não viram o nome do banco só trocando espaços por hífen.
WIKI_SPECIES = {'Meowstic-F': 'meowstic-female', 'Meowstic-M': 'meowstic-male', 'Mr.Mime': 'mr-mime'}
WIKI_NAMES = {  # erros de digitação dos dados
    'Beserk': 'berserk', 'Unburnden': 'unburden', 'Pom-Pom Style': 'dancer', 'Scope Lense': 'scope-lens',
    'Attrack': 'attract', 'Heabutt': 'headbutt', 'Poision Fang': 'poison-fang', 'Screch': 'screech', 'Seedbomb': 'seed-bomb',
}


def title(name):
    """'LT. SURGE' -> 'Lt. Surge'; 'TATE&LIZA' -> 'Tate & Liza'."""
    name = re.sub(r'\.(?=\S)', '. ', name.replace('&', ' & '))
    return ' '.join(w[:1].upper() + w[1:].lower() for w in name.split())


# Palavras das constantes do pret nas legendas das lutas.
WORDS = {'REMATCH': 'Revanche', 'VR': 'Victory Road', 'FIRST': '', 'REMATCH': 'Revanche', 'EARLY': '(começo)', 'LATE': '(depois)', 'OAKS': "Oak's",
         'MT': 'Mt.', 'SS': 'S.S.', 'AND': '', 'COMMANDER': '', 'GALACTIC': '', 'HQ': 'HQ', 'POKEMON': 'Pokémon', 'LEADER': '', 'ELITE': '', 'FOUR': '', 'BOSS': '', 'RIVAL': '', 'CHAMPION': ''}


def battle_label(key, name, cls):
    """TRAINER_ROXANNE_2 -> 'Revanche 1'; ..._ROUTE_103_MUDKIP -> 'Route 103 (se você escolheu Mudkip)'."""
    words = key.removeprefix('TRAINER_').split('_')
    tokens = set(re.sub(r'[^A-Z]', ' ', name.upper()).split())
    words = [w for w in words if w not in tokens]
    starter = next((w for w in words if w in STARTERS), None)
    words = [w for w in words if w != starter]
    parts = []
    for w in words:
        if w in WORDS:
            if WORDS[w]:
                parts.append(WORDS[w])
        elif w.isdigit():
            parts.append(w)
        else:
            parts.append(re.sub(r'([A-Z]+)(\d+)', r'\1 \2', w).capitalize().replace('Route ', 'Route '))
    text = ' '.join(parts).strip()
    if text.isdigit():
        n = int(text)
        text = ('Primeira luta' if n == 1 else f'Revanche {n - 1}') if cls == 'Líder de Ginásio' else f'Luta {n}'
    if not text:
        text = 'Primeira luta' if 'FIRST' in words else 'Luta'
    if starter:
        text = f'{text} (se você escolheu {starter.capitalize()})'
    return text


def main(src):
    errors = set()
    resolve = resolver(errors)
    games = []
    ids = {t['id'] for t in load('trainers')}
    for gid, gname, region, gen, module, folder, files in GAMES:
        if module is gen1:
            built = gen1.build(os.path.join(src, folder), resolve, yellow=gid == 'yellow')
        elif module is gen2:
            built = gen2.build(os.path.join(src, folder), resolve, os.path.join(src, 'maps', folder, 'maps'))
        elif module is gen5:
            built = gen5.build(os.path.join(src, folder), resolve, load('pokemon'), load('species'))
        elif module is wiki:
            built = wiki.build(json.loads(read(os.path.join(src, folder, 'src/data/trainers', wiki.GAMES[gid][0] + '.json'))), resolve, gid)
        elif module is gen9:
            built = gen9.build(json.loads(read(os.path.join(src, folder, 'trdata_array_clean.json'))),
                               open(os.path.join(src, folder, 'trdata_array.bfbs'), 'rb').read(), resolve, load('pokemon'))
        elif module is gen4:
            built = gen4.build(os.path.join(src, folder), resolve)
        else:
            built = module.build({k: read(os.path.join(src, folder, v)) for k, v in files.items()}, resolve)
        # Sem nome ou sem time: sobras de outro jogo no código (não aparecem no jogo).
        battles = [b for b in built if b['name'] and b['team'] and all(m['id'] for m in b['team'])]
        battles = [b for b in battles if (gid, b['name']) not in SKIP]
        people = {}
        for b in battles:
            display = b['name'] if module is wiki else RIVAL_NAMES.get(b['name'], title(b['name']))
            person = people.setdefault((b['class'], display), {'name': display, 'class': b['class'], 'battles': []})
            label = b.get('label') or battle_label(b['key'], b['name'], b['class'])
            person['battles'].append({'label': label, 'team': b['team']})
        for person in people.values():
            person['trainer'] = portrait(person, ids)
            labels = [b['label'] for b in person['battles']]
            for b in person['battles']:
                if b['label'] == 'Luta' and 'Luta 2' in labels:
                    b['label'] = 'Luta 1'
                if b['label'] == 'Luta 2' and person['class'] in ('Elite Four', 'Campeão'):
                    b['label'] = 'Revanche'
            # Legenda repetida na mesma pessoa: "(2)", "(3)"...
            used = {}
            for b in person['battles']:
                used[b['label']] = used.get(b['label'], 0) + 1
                if used[b['label']] > 1:
                    b['label'] = f"{b['label']} ({used[b['label']]})"
        rank = ['Líder de Ginásio', 'Elite Four', 'Campeão', 'Rival']
        people = dict(sorted(people.items(), key=lambda kv: (rank.index(kv[0][0]) if kv[0][0] in rank else len(rank),
                                                             GYM_ORDER.index(kv[0][1]) if kv[0][0] == rank[0] and kv[0][1] in GYM_ORDER else 0)))
        source = 'community' if module is wiki else 'game'
        games.append({'id': gid, 'name': gname, 'region': region, 'generation': gen, 'source': source,
                      'trainers': list(people.values())})
    if errors:
        raise SystemExit('Não reconhecidos:\n' + '\n'.join(sorted(errors)))
    with open(os.path.join(DB, 'official_teams.json'), 'w', encoding='utf-8') as f:
        json.dump(games, f, ensure_ascii=False, separators=(',', ':'))
        f.write('\n')
    print({g['name']: (len(g['trainers']), sum(len(t['battles']) for t in g['trainers'])) for g in games})


if __name__ == '__main__':
    main(sys.argv[1])
