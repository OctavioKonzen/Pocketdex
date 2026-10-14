"""Dados da Battle Factory (o modo de subir andares com um inicial).

Saída: assets/database/factory.json
  {"species": {id: [xp base, total de atributos, raridade, [EVs que dá: hp, atk, def, spa, spd, spe], [tipos], taxa de captura]},
   "evolutions": {id: [[evolui para, nível], ...]},
   "starters": [ids dos iniciais grátis],
   "bosses": [{"region", "game", "leaders": [{"name", "trainer", "kind", "id", "city", "team": [ids], "pool": [ids]}]}],
   "forms": {id da forma: espécie},
   "megas": {espécie: [[Mega Pedra, id da Mega]]}, "gmax": [espécies com G-Max],
   "zcrystals": {tipo: Cristal Z}, "tms": [golpes de TM], "stones": [itens de evolução],
   "stories": {região: {intro, gym, rival, villain, elite, champion, end}} (tool/factory_stories.py)}
raridade: 0 comum, 1 lendário, 2 mítico, 3 bebê.
Evoluções que não são por nível (pedra, troca, amizade...) ganham um nível
fixo para o time poder evoluir no modo.
Chefes (a cada 10 andares): a história de cada jogo (official_teams.json) —
líderes de ginásio (kahunas, capitães) com o rival e os vilões no meio, na
ordem em que aparecem (os times deles crescem a cada batalha), depois a Elite
Four e o Campeão. "pool": todos os Pokémon que o personagem usa no jogo (para
completar o time nos andares altos).

Uso: python3 tool/build_factory_data.py
"""

import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from factory_stories import CITIES, STORIES  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(ROOT, 'assets', 'database')
MAX_SPECIES = 1025
STARTERS = [1, 4, 7, 152, 155, 158, 252, 255, 258, 387, 390, 393, 495, 498, 501, 650, 653, 656, 722, 725, 728, 810, 813, 816,
            906, 909, 912]
# Nível para as evoluções que não são por nível.
OTHER_TRIGGER = {'use-item': 30, 'trade': 36}
DEFAULT_OTHER = 25


def load(name):
    with open(os.path.join(DB, f'{name}.json'), encoding='utf-8') as f:
        return json.load(f)


GYM = {'Líder de Ginásio', 'Kahuna', 'Capitão'}
MAX_SPECIALS = 14
TYPES = {'normal', 'fire', 'water', 'grass', 'electric', 'ice', 'fighting', 'poison', 'ground', 'flying', 'psychic', 'bug', 'rock', 'ghost',
         'dragon', 'dark', 'steel', 'fairy'}


def boss_kind(cls):
    if cls in GYM:
        return 'gym'
    if cls == 'Elite Four':
        return 'elite'
    if cls == 'Campeão':
        return 'champion'
    if cls in ('Rival', 'Treinador Pokémon'):
        return 'rival'
    if 'Equipe' in cls or cls in ('Fundação Aether', 'Ultra Recon Squad'):
        return 'villain'
    return None


def boss_story(game, usable, sprites):
    """A ordem dos chefes de um jogo: ginásios com rival e vilões no meio
    (pela altura da história), depois a Elite Four e o Campeão."""
    region = game['region']

    def entry(t, battle, kind):
        team = [m['id'] for m in battle['team'] if usable(m['id'])]
        pool = []
        for b in sorted(t['battles'], key=lambda b: -len(b['team'])):
            for m in b['team']:
                if usable(m['id']) and m['id'] not in pool:
                    pool.append(m['id'])
        slug = re.sub(r'[^a-z0-9]+', '-', t['name'].lower()).strip('-')
        trainer = t.get('trainer') if t.get('trainer') in sprites else ''
        return {'id': f"{region.lower()}-{slug}", 'name': t['name'], 'trainer': trainer, 'kind': kind, 'team': team, 'pool': pool}

    gyms, elites, champions, specials = [], [], [], []
    for t in game['trainers']:
        kind = boss_kind(t['class'])
        battles = [b for b in t['battles'] if any(usable(m['id']) for m in b['team'])]
        if not kind or not battles:
            continue
        t = {**t, 'battles': battles}
        if kind == 'gym':
            gyms.append(entry(t, battles[0], kind))
        elif kind == 'elite':
            elites.append(entry(t, battles[0], kind))
        elif kind == 'champion':
            champions.append(entry(t, battles[-1], kind))
        else:
            for k, b in enumerate(battles):
                specials.append(((k + 0.5) / len(battles), entry(t, b, kind)))
    if not gyms and not elites:
        return []
    specials.sort(key=lambda x: x[0])
    if len(specials) > MAX_SPECIALS:
        step = len(specials) / MAX_SPECIALS
        specials = [specials[int(i * step)] for i in range(MAX_SPECIALS)]
    middle = [((i + 0.5) / len(gyms), 0, g) for i, g in enumerate(gyms)] + [(f, 1, e) for f, e in specials]
    middle.sort(key=lambda x: (x[0], x[1]))
    return [e for _, _, e in middle] + elites + champions[-1:]


def add_cities(region, story):
    """A cidade de cada chefe (tool/factory_stories.py, CITIES): o ginásio do
    líder; rival e vilões, a do próximo líder; Elite Four e Campeão, a Liga."""
    table = CITIES[region]

    def own(leader):
        if leader['kind'] in ('elite', 'champion'):
            return table['league']
        if leader['kind'] != 'gym':
            return None
        key = re.sub(r'^sd-|-gen\d+$', '', leader['trainer'] or leader['id'].split('-', 1)[1])
        if key not in table:
            print('sem cidade:', region, key)
        return table.get(key, table['league'])

    city = table['league']
    for leader in reversed(story):
        city = own(leader) or city
        leader['city'] = city


# Onde cada espécie vive (os lugares das rotas da Battle Factory): pelos locais de encontro dos jogos (o nome do lugar
# e o jeito de encontrar: surf, vara de pesca, mergulho...), o habitat da Pokédex (1ª a 3ª geração), a forma e, se
# nada disso disser, os tipos. No fundo do mar só quem vive debaixo d'água (mergulho, ou peixes e bichos de
# tentáculos que são de Água).
WATER_METHODS = {'surf', 'old-rod', 'good-rod', 'super-rod', 'super-rod-spots', 'surf-spots', 'overworld-water', 'wanderer-water',
                 'bubbling-spots', 'roaming-water', 'chase-water', 'feebas-tile-fishing', 'sos-from-bubbling-spot'}
PLACE_WORDS = [
    ('sewer', ['sewer']),
    ('plant', ['power-plant', 'generator', 'power-station']),
    ('crystal', ['crystal', 'quarry', 'gem', 'mine']),
    ('ruins', ['ruins', 'ruin', 'tomb', 'alph', 'relic', 'ancient']),
    ('temple', ['temple', 'shrine', 'sanctuary', 'spear-pillar', 'sky-pillar', 'altar', 'dragonspiral']),
    ('bamboo', ['bamboo']),
    ('flowers', ['flower', 'meadow', 'floaroma', 'blossom', 'petal']),
    ('icecave', ['ice-cave', 'icy-cave', 'ice-path', 'seafoam', 'frost-cavern', 'frozen-cave', 'glacier-cave']),
    ('cave', ['cave', 'tunnel', 'cavern', 'grotto', 'chamber', 'underground', 'burrow', 'mt-moon', 'den', 'hollow']),
    ('snow', ['snow', 'ice', 'frost', 'glacier', 'frozen', 'icy', 'freez', 'crown-tundra']),
    ('volcano', ['volcan', 'fiery', 'magma', 'lava', 'stark', 'flame', 'mt-chimney', 'mt-pyre-summit', 'reversal']),
    ('tower', ['tower', 'cemetery', 'graveyard', 'chateau', 'haunted', 'pyre', 'spirit', 'grave', 'mansion', 'ghost']),
    ('swamp', ['marsh', 'swamp', 'bog', 'mire', 'wetland']),
    ('desert', ['desert', 'dune', 'wasteland', 'sand']),
    ('forest', ['forest', 'woods', 'jungle', 'grove', 'orchard', 'garden', 'wood']),
    ('beach', ['beach', 'shore', 'coast', 'seaside', 'cove', 'harbor', 'island']),
    ('mountain', ['mountain', 'mt-', 'mount-', 'peak', 'summit', 'cliff', 'crag', 'pillar', 'canyon']),
    ('city', ['city', 'town', 'factory', 'castle', 'hotel', 'mall', 'department', 'building', 'lab']),
]
HABITAT_PLACES = {'grassland': ['grass'], 'forest': ['forest'], 'waters-edge': ['beach', 'water'], 'mountain': ['mountain'], 'sea': ['water'],
                  'urban': ['city'], 'cave': ['cave'], 'rough-terrain': ['mountain', 'desert']}
TYPE_PLACES = {'normal': ['grass', 'city'], 'fire': ['volcano', 'desert'], 'water': ['water', 'beach'], 'grass': ['forest', 'grass'], 'electric': ['city'],
               'ice': ['snow', 'icecave'], 'fighting': ['mountain', 'city'], 'poison': ['swamp', 'sewer'], 'ground': ['desert', 'cave'], 'flying': ['sky', 'grass'],
               'psychic': ['tower', 'city'], 'bug': ['forest'], 'rock': ['cave', 'mountain'], 'ghost': ['tower'], 'dragon': ['sky', 'mountain'],
               'dark': ['cave', 'tower'], 'steel': ['mountain', 'city'], 'fairy': ['forest', 'sky']}
ORDER = ['grass', 'forest', 'water', 'beach', 'underwater', 'swamp', 'sewer', 'cave', 'icecave', 'mountain', 'desert', 'volcano', 'snow', 'city', 'sky', 'tower',
         'ruins', 'flowers', 'plant', 'crystal', 'dunes', 'bamboo', 'temple']
# Os lugares novos também a partir dos de sempre (pelo tipo): quem vive no deserto e é de Terra, Sombrio, Fantasma ou
# Inseto também vive nas dunas à noite; os de Grama/Fada/Inseto do campo e da floresta, no campo de flores; e assim por diante.
DERIVED = [
    ('dunes', {'desert'}, {'ground', 'dark', 'ghost', 'bug', 'rock'}),
    ('flowers', {'grass', 'forest'}, {'fairy', 'grass', 'bug'}),
    ('bamboo', {'forest', 'grass', 'mountain'}, {'grass', 'fighting', 'bug', 'dark'}),
    ('plant', {'city', 'sewer'}, {'electric', 'steel'}),
    ('crystal', {'cave', 'icecave', 'mountain'}, {'rock', 'steel', 'fairy', 'psychic', 'ice'}),
    ('ruins', {'cave', 'desert', 'mountain', 'tower'}, {'rock', 'psychic', 'ghost', 'ground'}),
    ('temple', {'tower', 'mountain', 'city'}, {'psychic', 'fighting', 'dragon', 'ghost'}),
]


def habitats(sid, s, p, encounters):
    places = set()
    types = p['types']
    deep = 'water' in types and s.get('shape') in ('fish', 'tentacles', 'squiggle') and bool({'water2', 'water3', 'water1'} & set(s.get('egg_groups') or []))
    for area, _game, method, *_ in encounters.get(str(sid), []):
        if method == 'seaweed':
            places.add('underwater')
            continue
        if method in WATER_METHODS:
            places.add('water')
            if deep:
                places.add('underwater')
            continue
        if method in ('gift', 'gift-egg', 'npc-trade', 'max-raid', 'dynamax-adventure', 'static', 'snag', 'snag-rematch', 'island-scan', 'pokeflute'):
            continue
        name = area.lower()
        place = next((b for b, words in PLACE_WORDS if any(w in name for w in words)), 'grass')
        if method in ('overworld-flying', 'overworld-flying-special', 'sky-ambush'):
            place = 'sky'
        places.add(place)
    for b in HABITAT_PLACES.get(s.get('habitat') or '', []):
        places.add(b)
    if deep:
        places.add('underwater')
    # Quem voa (asas e tipo Voador) também aparece no céu.
    if 'flying' in types and s.get('shape') in ('wings', 'bug-wings'):
        places.add('sky')
    if not places:
        for t in types:
            places.update(TYPE_PLACES.get(t, []))
    # Peixes e bichos de tentáculos só na água (os "overworld" dos jogos novos punham alguns na grama da rota).
    if deep:
        places &= {'water', 'underwater', 'beach', 'swamp', 'icecave', 'cave', 'sewer'}
        places |= {'water'}
    for place, near, kinds in DERIVED:
        if places & near and set(types) & kinds and not deep:
            places.add(place)
    # Fundo do mar: só quem vive debaixo d'água.
    if 'underwater' in places and not deep and not any(m[2] == 'seaweed' for m in encounters.get(str(sid), [])):
        places.discard('underwater')
    return [b for b in ORDER if b in places] or ['grass']


def main():
    pokemon = {p['id']: p for p in load('pokemon') if p['is_default'] and p['id'] <= MAX_SPECIES}
    species = {s['id']: s for s in load('species') if s['id'] <= MAX_SPECIES}
    encounters = load('encounters')
    out_species = {}
    for sid, s in species.items():
        p = pokemon.get(sid)
        if not p:
            continue
        bst = sum(stat[0] for stat in p['stats'])
        rarity = 1 if s['is_legendary'] else 2 if s['is_mythical'] else 3 if s['is_baby'] else 0
        out_species[sid] = [p['base_experience'] or 50, bst, rarity, [stat[1] for stat in p['stats']], p['types'], s['capture_rate'], habitats(sid, s, p, encounters)]
    evolutions = {}

    def walk(node):
        for nxt in node['evolves_to']:
            d = nxt.get('details') or {}
            item = d.get('item') if d.get('trigger') == 'use-item' else None
            # Evolução por pedra (ou outro item): só usando o item (nível 0).
            level = 0 if item else d.get('min_level') or OTHER_TRIGGER.get(d.get('trigger'), DEFAULT_OTHER)
            if node['species'] in out_species and nxt['species'] in out_species:
                evolutions.setdefault(node['species'], []).append([nxt['species'], level, item] if item else [nxt['species'], level])
            walk(nxt)

    for chain in load('evolution_chains').values():
        walk(chain)
    # Formas regionais nos times dos chefes (Alola, Galar...): id da forma -> espécie.
    records = {p['id']: p for p in load('pokemon')}
    forms = {}

    def usable(i):
        if i in out_species:
            return True
        if i in records and records[i]['species'] in out_species:
            forms[i] = records[i]['species']
            return True
        return False

    sprites = {t['id'] for t in load('trainers')}
    bosses = []
    for game in load('official_teams'):
        story = boss_story(game, usable, sprites)
        if story:
            add_cities(game['region'], story)
            bosses.append({'region': game['region'], 'game': game['name'], 'leaders': story})
    # Mega: espécie -> [[Mega Pedra (nome do item como no sprite), id da forma Mega]].
    item_files = {re.sub(r'[^a-z0-9]', '', f[:-4]): f[:-4] for f in os.listdir(os.path.join(DB, 'sprites', 'items')) if f.endswith('.png') and '--' not in f}
    by_name = {p['name']: p for p in records.values()}
    battle_items = load('battle_items')
    megas = {}
    for stone, form in battle_items['mega'].items():
        rec = by_name.get(form)
        if rec and rec['species'] in out_species and stone in item_files:
            megas.setdefault(rec['species'], []).append([item_files[stone], rec['id']])
    # Gigantamax: espécies com a forma G-Max (o motor usa a forma pela espécie).
    gmax = sorted({by_name[n]['species'] for n in by_name if n.endswith('-gmax') and by_name[n]['species'] in out_species})
    # Cristais Z por tipo (o nome do item; o sprite é <nome>--held.png).
    held_files = {re.sub(r'[^a-z0-9]', '', f[:-len('--held.png')]): f[:-len('--held.png')]
                  for f in os.listdir(os.path.join(DB, 'sprites', 'items')) if f.endswith('--held.png')}
    zcrystals = {}
    for crystal, typ in battle_items['z'].items():
        name = item_files.get(crystal) or held_files.get(crystal)
        if name and typ in TYPES and typ not in zcrystals:
            zcrystals[typ] = name
    # TMs: golpes que algum Pokémon aprende por máquina (os da loja).
    move_info = {m['name']: m for m in load('moves')}
    tms = sorted({m[0] for p in records.values() for m in p['moves'] if m[1] == 'machine' and m[0] in move_info and (move_info[m[0]].get('power') or 0) >= 50})
    stones = sorted({e[2] for es in evolutions.values() for e in es if len(e) > 2})
    data = {'species': out_species, 'evolutions': evolutions, 'starters': STARTERS, 'bosses': bosses, 'forms': forms,
            'megas': megas, 'gmax': gmax, 'zcrystals': zcrystals, 'tms': tms, 'stones': stones, 'stories': STORIES}
    with open(os.path.join(DB, 'factory.json'), 'w', encoding='utf-8') as f:
        json.dump(data, f, separators=(',', ':'))
        f.write('\n')
    print(len(out_species), 'espécies,', len(evolutions), 'com evolução')


if __name__ == '__main__':
    main()
