"""Dados da Battle Factory (o modo de subir andares com um inicial).

Saída: assets/database/factory.json
  {"species": {id: [xp base, total de atributos, raridade, [EVs que dá: hp, atk, def, spa, spd, spe], [tipos], taxa de captura]},
   "evolutions": {id: [[evolui para, nível], ...]},
   "starters": [ids dos iniciais grátis],
   "bosses": [{"region", "game", "leaders": [{"name", "trainer", "kind", "id", "city", "team": [ids], "pool": [ids]}]}],
   "forms": {id da forma: espécie},
   "megas": {espécie: [[Mega Pedra, id da Mega]]}, "gmax": [espécies com G-Max],
   "zcrystals": {tipo: Cristal Z}, "tms": [golpes de TM], "stones": [itens de evolução],
   "stories": {região: {intro, gym, rival, villain, elite, champion, end}} (tool/factory_stories.py),
   "routes": {cities: {cidade: [lugar, rota, lugar no caminho, [lugares da cidade]]}, start: {região: cidade}} (tool/factory_routes.py)}
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
from factory_extra_regions import REGIONS as EXTRA_REGIONS  # noqa: E402
from factory_scenes import SCENES  # noqa: E402
from factory_routes import CITIES as ROUTE_CITIES, START as ROUTE_START, FEATURES as ROUTE_FEATURES, RARE as ROUTE_RARE, TUTOR_EVERYWHERE as ROUTE_TUTORS  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(ROOT, 'assets', 'database')
MAX_SPECIES = 1025
STARTERS = [1, 4, 7, 152, 155, 158, 252, 255, 258, 387, 390, 393, 495, 498, 501, 650, 653, 656, 722, 725, 728, 810, 813, 816,
            906, 909, 912]
# Nível para as evoluções que não são por nível (troca, amizade, lugar, golpe, ponta-cabeça...):
# viram por nível, pelo menos 10 acima do nível em que a forma anterior chegou (não pula estágio).
OTHER_TRIGGER = {'use-item': 30, 'trade': 36}
DEFAULT_OTHER = 25
OTHER_GAP = 10
# Como nos jogos novos: Leafeon e Glaceon pela pedra.
ITEM_OVERRIDE = {470: 'leaf-stone', 471: 'ice-stone'}
# Shedinja não é evolução de escolha: aparece junto quando o Nincada vira Ninjask (com vaga no time), no motor.
SKIP_TRIGGERS = {'shed'}

# Formas regionais, como nos jogos. A região é a do jogo da perna da corrida; Hisui (Legends: Arceus) é uma região
# própria (o passado de Sinnoh): as formas e evoluções de Hisui valem só nas pernas de Hisui.
# forms: quem aparece (selvagem) na forma da região. evolveIn: quem, evoluindo nessa região, vira a forma dela
# (Pikachu → Raichu de Alola). regionEvos: evoluções que só acontecem na região (Stantler → Wyrdeer em Hisui).
REGIONAL = {
    'forms': {
        'Alola': {19: 10091, 20: 10092, 26: 10100, 27: 10101, 28: 10102, 37: 10103, 38: 10104, 50: 10105, 51: 10106, 52: 10107,
                  53: 10108, 74: 10109, 75: 10110, 76: 10111, 88: 10112, 89: 10113, 103: 10114, 105: 10115},
        'Galar': {52: 10161, 77: 10162, 78: 10163, 79: 10164, 80: 10165, 83: 10166, 110: 10167, 122: 10168, 199: 10172, 222: 10173,
                  263: 10174, 264: 10175, 554: 10176, 555: 10177, 562: 10179, 618: 10180},
        'Hisui': {58: 10229, 59: 10230, 100: 10231, 101: 10232, 157: 10233, 211: 10234, 215: 10235, 503: 10236, 549: 10237,
                   550: 10247, 570: 10238, 571: 10239, 628: 10240, 705: 10241, 706: 10242, 713: 10243, 724: 10244},
        'Paldea': {128: 10250, 194: 10253},
    },
    'evolveIn': {
        'Alola': {26: 10100, 103: 10114, 105: 10115},
        'Galar': {110: 10167, 122: 10168},
        'Hisui': {157: 10233, 503: 10236, 549: 10237, 628: 10240, 705: 10241, 713: 10243, 724: 10244},
    },
    'regionEvos': {
        'Hisui': {234: [[899, 25]], 123: [[900, 0, 'black-augurite']], 217: [[901, 0, 'peat-block']]},
        'Paldea': {217: [[901, 0, 'peat-block']]},
    },
    # Só com esse gênero (o resto do ramo segue igual): Burmy, Combee, Salandit e as pedras do Kirlia e do Snorunt.
    'gender': {413: 'F', 414: 'M', 416: 'F', 758: 'F', 475: 'M', 478: 'F'},
    # A fêmea vira a forma feminina (Meowstic, Oinkologne, Basculegion).
    'femaleForm': {678: 10025, 916: 10254, 902: 10248},
}
# As evoluções das formas regionais (a forma continua a da região, evolua onde evoluir).
FORM_EVOS = {
    10091: [[10092, 20]], 10101: [[10102, 0, 'ice-stone']], 10103: [[10104, 0, 'ice-stone']], 10105: [[10106, 26]],
    10107: [[10108, 28]], 10109: [[10110, 25]], 10110: [[10111, 36]], 10112: [[10113, 38]],
    10161: [[863, 28]], 10162: [[10163, 40]], 10164: [[10165, 37], [10172, 37]], 10166: [[865, 25]], 10168: [[866, 42]],
    10173: [[864, 38]], 10174: [[10175, 20]], 10175: [[862, 35]], 10176: [[10177, 0, 'ice-stone']], 10179: [[867, 34]],
    10229: [[10230, 0, 'fire-stone']], 10231: [[10232, 0, 'leaf-stone']], 10234: [[904, 25]], 10235: [[903, 25]],
    10238: [[10239, 30]], 10241: [[10242, 50]], 10247: [[902, 25]],
    10253: [[980, 20]],
}
# Evoluções que nos jogos só a forma regional faz (ou só numa região): saem da espécie comum.
REGIONAL_ONLY = {(52, 863), (83, 865), (122, 866), (222, 864), (264, 862), (562, 867), (194, 980), (211, 904), (215, 903),
                 (550, 902), (234, 899), (123, 900), (217, 901)}


def load(name):
    with open(os.path.join(DB, f'{name}.json'), encoding='utf-8') as f:
        return json.load(f)


GYM = {'Líder de Ginásio', 'Kahuna', 'Capitão'}
# Rivais e vilões aparecem quantas vezes você luta com eles no jogo: uma luta por lugar (as variações pelo inicial,
# "(se você escolheu ...)", e pela versão são a mesma luta).
VARIANT = re.compile(r'\s*\((se você escolheu [^)]*|Eevee → [^)]*)\)')
# Lutas que dá para repetir (torneio da academia, castelo do N): fora.
REPEATABLE = re.compile(r'Torneio da Academia')
# Depois do Campeão (o pós-jogo): pelo nome da luta, pela classe ou por quem é.
POSTGAME_LABEL = re.compile(r'depois da (liga|história)|fight area|stark mountain|slumbering weald 2|champion tournament|mt\. moon|indigo plateau', re.I)
POSTGAME_CLASS = {'Equipe Rainbow Rocket'}
POSTGAME = {('Gold/Silver', 'Red'), ('Crystal', 'Red'), ('HeartGold/SoulSilver', 'Red'), ('Black/White', 'Cynthia'),
            ('Black 2/White 2', 'Cynthia'), ('Black 2/White 2', 'N'), ('Black 2/White 2', 'Benga'), ('X/Y', 'AZ'),
            ('Sun/Moon', 'Red'), ('Sun/Moon', 'Blue'), ('Sun/Moon', 'Anabel'), ('Ultra Sun/Ultra Moon', 'Red'),
            ('Ultra Sun/Ultra Moon', 'Blue'), ('Ultra Sun/Ultra Moon', 'Lillie')}
# Quais lutas valem (e em que ordem, quando a lista do jogo vem fora de ordem): só estas.
KEEP = {
    ('Emerald', 'Wally'): ['Mauville', 'Victory Road 1'],  # as outras de Victory Road são revanches
    ('Platinum', 'Barry'): ['Route 201', 'Route 203', 'Route 209', 'Pastoria City', 'Canalave City', 'Spear Pillar', 'Pokémon League',
                            'Fight Area'],
    ('Platinum', 'Mars'): ['Valley Windworks', 'Lake Verity', 'Spear Pillar', 'Stark Mountain'],
    ('Platinum', 'Jupiter'): ['Team Eterna Building', 'Spear Pillar', 'Stark Mountain'],
    ('Platinum', 'Saturn'): ['Valor Cavern', 'HQ'],
    ('Platinum', 'Cyrus'): ['Celestic Town Ruins', 'HQ', 'Distortion World'],
    ('Black 2/White 2', 'N'): ['Castelo do N (time 1)'],
    ('Black 2/White 2', 'Benga'): ['Black Tower / White Treehollow'],  # o (2) é a outra versão
    ('X/Y', 'Serena'): ['Tower Of Mastery', 'Coumarine City', 'Route 14', 'Anistar City', 'Victory Road'],
    ('Sword/Shield', 'Hop'): ['Luta 1', 'Route 2', 'Motostoke', 'Route 5', 'Stow-On-Side', 'Route 7', 'Circhester', 'Wyndon Stadium',
                              'Slumbering Weald', 'Slumbering Weald 2', 'Champion Tournament'],
}
# A altura da história de algumas lutas (0 é o começo, 1 a Liga), quando o espalhado não acerta.
AT = {}
for g in ('Red/Blue', 'Yellow'):
    AT.update({(g, 'Giovanni', 'Rocket Hideout B4F'): 0.5, (g, 'Giovanni', 'Silph Co. 11F'): 0.7, (g, 'Giovanni', 'Viridian Gym'): 0.95})
AT.update({('FireRed/LeafGreen', 'Giovanni', 'Luta 1'): 0.5, ('FireRed/LeafGreen', 'Giovanni', 'Luta 2'): 0.7})
AT.update({('Diamond/Pearl', 'Mars', 'Valley Windwork'): 0.15, ('Diamond/Pearl', 'Jupiter', 'Galactic Eterna Building'): 0.3,
           ('Diamond/Pearl', 'Saturn', 'Lake Valor'): 0.68, ('Diamond/Pearl', 'Mars', 'Lake Verity'): 0.69,
           ('Diamond/Pearl', 'Saturn', 'Galactic HQ'): 0.7, ('Diamond/Pearl', 'Cyrus', 'Galactic HQ'): 0.71, ('Diamond/Pearl', 'Cyrus', 'Spear Pillar'): 0.72})
AT.update({('Scarlet/Violet', n, 'Base da Equipe Star'): at for n, at in (('Giacomo', 0.2), ('Mela', 0.35), ('Atticus', 0.5), ('Ortega', 0.65), ('Eri', 0.8))})
AT[('Scarlet/Violet', 'Penny', 'Luta final da Equipe Star')] = 0.9
# Jessie e James, da Equipe Rocket: aparecem em toda região (como no anime), sempre juntos (batalha em dupla, o sprite dos
# dois), com os Pokémon que tinham naquela fase do anime e o Meowth. Em Paldea (Horizontes) eles não aparecem.
JESSIE_JAMES = {
    'Kanto': (24, 108, 110, 71, 52), 'Johto': (24, 202, 110, 71, 52), 'Hoenn': (336, 269, 202, 331, 358, 52),
    'Sinnoh': (336, 469, 202, 455, 439, 52), 'Unova': (527, 592, 562, 591, 52), 'Kalos': (710, 202, 687, 52),
    'Alola': (778, 202, 747, 52), 'Galar': (778, 202, 747, 877, 52),
}
# Os ginásios na ordem dos jogos, um por cidade: as alternativas (Chili, Cilan e Cress em Striaton, pelo inicial;
# Bea/Allister e Gordie/Melony, pela versão) contam uma vez, e quem só vira líder no pós-jogo (Bede e Marnie) sai.
GYM_ORDER = {
    'Black/White': ['Cilan', 'Lenora', 'Burgh', 'Elesa', 'Clay', 'Skyla', 'Brycen', 'Drayden'],
    'Sword/Shield': ['Milo', 'Nessa', 'Kabu', 'Bea', 'Opal', 'Gordie', 'Piers', 'Raihan'],
    'Sun/Moon': ['Ilima', 'Hala', 'Lana', 'Kiawe', 'Mallow', 'Olivia', 'Molayne', 'Nanu', 'Hapu'],
    'Ultra Sun/Ultra Moon': ['Ilima', 'Hala', 'Lana', 'Kiawe', 'Mallow', 'Olivia', 'Sophocles', 'Nanu', 'Mina', 'Hapu'],
    'HeartGold/SoulSilver': ['Falkner', 'Bugsy', 'Whitney', 'Morty', 'Chuck', 'Jasmine', 'Pryce', 'Clair', 'Brock', 'Misty', 'Lt. Surge', 'Erika',
                             'Janine', 'Sabrina', 'Blaine', 'Blue'],
    'Omega Ruby/Alpha Sapphire': ['Roxanne', 'Brawly', 'Wattson', 'Flannery', 'Norman', 'Winona', 'Tate & Liza', 'Wallace'],
}
# Em Johto, os ginásios de Kanto vêm depois do Campeão (o pós-jogo), antes do Red.
KANTO_LATE = {'Gold/Silver', 'Crystal', 'HeartGold/SoulSilver'}
KANTO_GYMS = {'Brock', 'Misty', 'Lt. Surge', 'Erika', 'Janine', 'Sabrina', 'Blaine', 'Blue'}
# A mesma luta em partes (o time dividido em várias entradas): vira uma só.
MERGE = {('Sun/Moon', 'Lusamine'): 'Ultra Space', ('Sun/Moon', 'Red'): 'Luta', ('Ultra Sun/Ultra Moon', 'Red'): 'Luta'}
# O rival é um só (o do outro gênero do jogador de sempre): o outro sai.
SKIP = {('Emerald', 'Brendan'), ('X/Y', 'Calem')}
# Em Alola não tem a classe Campeão: a luta pelo título.
CHAMPION = {('Sun/Moon', 'Kukui'): 'Luta pelo título', ('Ultra Sun/Ultra Moon', 'Hau'): 'Luta pelo título'}
# Quem faltava nos dados dos jogos (times da luta, pela memória dos jogos).
EXTRA = {
    'HeartGold/SoulSilver': [{'name': 'Red', 'class': 'Treinador Pokémon', 'trainer': 'red',
                              'battles': [{'label': 'Mt. Silver', 'team': [{'id': i} for i in (25, 196, 143, 3, 6, 9)]}]},
                             {'name': 'Chuck', 'class': 'Líder de Ginásio', 'trainer': 'chuck',
                              'battles': [{'label': 'Luta', 'team': [{'id': i} for i in (57, 62)]}]}],
    'Omega Ruby/Alpha Sapphire': [
        {'name': 'Tate & Liza', 'class': 'Líder de Ginásio', 'trainer': 'tate-liza', 'battles': [{'label': 'Luta', 'team': [{'id': i} for i in (337, 338)]}]},
        {'name': 'Sidney', 'class': 'Elite dos Quatro', 'trainer': 'sd-sidney', 'battles': [{'label': 'Luta', 'team': [{'id': i} for i in (262, 275, 332, 342, 359)]}]},
        {'name': 'Phoebe', 'class': 'Elite dos Quatro', 'trainer': 'sd-phoebe-gen6', 'battles': [{'label': 'Luta', 'team': [{'id': i} for i in (356, 354, 302, 354, 477)]}]},
        {'name': 'Glacia', 'class': 'Elite dos Quatro', 'trainer': 'sd-glacia', 'battles': [{'label': 'Luta', 'team': [{'id': i} for i in (362, 478, 362, 478, 365)]}]},
        {'name': 'Drake', 'class': 'Elite dos Quatro', 'trainer': 'sd-drake-gen3', 'battles': [{'label': 'Luta', 'team': [{'id': i} for i in (334, 230, 330, 612, 373)]}]}],
    'Black/White': [{'name': 'Cynthia', 'class': 'Treinador Pokémon', 'trainer': 'cynthia',
                     'battles': [{'label': 'Undella Town', 'team': [{'id': i} for i in (442, 407, 468, 448, 350, 445)]}]}],
    'Black 2/White 2': [{'name': 'Cynthia', 'class': 'Treinador Pokémon', 'trainer': 'cynthia',
                         'battles': [{'label': 'Undella Town', 'team': [{'id': i} for i in (442, 407, 468, 448, 350, 445)]}]}],
    'Sword/Shield': [{'name': 'Equipe Yell', 'class': 'Equipe Yell', 'trainer': 'sd-yellgrunt',
                      'battles': [{'label': 'Motostoke', 'at': 0.22, 'team': [{'id': i} for i in (10174, 827)]},
                                  {'label': 'Route 4', 'at': 0.4, 'team': [{'id': i} for i in (10175, 828, 559)]},
                                  {'label': 'Spikemuth', 'at': 0.78, 'team': [{'id': i} for i in (510, 560, 862, 828)]}]},
                     {'name': 'Sordward e Shielbert', 'class': 'Dupla', 'trainer': 'sd-sordward-shielbert', 'pair': True,
                      'battles': [{'label': 'Depois da Liga', 'team': [{'id': i} for i in (865, 768, 625, 437, 601, 870)]}]},
                     {'name': 'Oleana', 'class': 'Macro Cosmos', 'trainer': 'sd-oleana',
                      'battles': [{'label': 'Rose Tower', 'at': 0.99, 'team': [{'id': i} for i in (478, 758, 569, 350, 763)]}]},
                     {'name': 'Rose', 'class': 'Macro Cosmos', 'trainer': 'sd-rose',
                      'battles': [{'label': 'Rose Tower', 'at': 0.99, 'team': [{'id': i} for i in (589, 598, 863, 601, 879)]}]}],
}
# Hisui (Legends: Arceus): não está nos dados dos times dos jogos, então vem daqui. Os Nobres no lugar dos ginásios (o
# guardião de cada um com o Nobre por último), o rival (Akari, a outra pessoa da Equipe Galáxia), os líderes dos
# clãs (Adaman e Irida), o Kamado (comandante da Equipe Galáxia) e o Volo como o último chefe, no Temple of Sinnoh.
# As cidades: você sai da Jubilife Village e passa pelas 5 áreas, como no jogo.
HISUI_STARTERS = [722, 723, 724, 10244, 155, 156, 157, 10233, 501, 502, 503, 10236]
HISUI = [
    ('Akari', 'sd-akari', 'rival', [722], 'Obsidian Fieldlands', {}),
    ('Lian', 'sd-lian', 'gym', [74, 123, 900], 'Obsidian Fieldlands', {}),
    ('Adaman', 'sd-adaman', 'rival', [470, 197, 134, 169], 'Crimson Mirelands', {'guest': True}),
    ('Arezu', 'sd-arezu', 'gym', [315, 455, 10237], 'Crimson Mirelands', {}),
    ('Akari', 'sd-akari', 'rival', [397, 403, 723], 'Cobalt Coastlands', {}),
    ('Irida', 'sd-irida', 'rival', [471, 196, 136, 450], 'Cobalt Coastlands', {'guest': True}),
    ('Melli', 'sd-melli', 'gym', [78, 126, 10230], 'Cobalt Coastlands', {}),
    ('Kamado', 'sd-kamado', 'villain', [214, 76, 143], 'Coronet Highlands', {}),
    ('Ingo', 'sd-ingo-hisui', 'gym', [404, 82, 10232], 'Coronet Highlands', {}),
    ('Akari', 'sd-akari', 'rival', [398, 404, 724], 'Alabaster Icelands', {}),
    ('Gaeric', 'sd-gaeric', 'gym', [221, 478, 362, 10243], 'Alabaster Icelands', {}),
    ('Volo', 'sd-volo', 'champion', [442, 407, 10230, 448, 468, 445], 'Temple of Sinnoh', {}),
]


def hisui_game(usable, sprites):
    leaders = []
    for name, trainer, kind, team, city, extra in HISUI:
        team = [i for i in team if usable(i)]
        pool = list(team)
        if name == 'Akari':
            pool = [i for i in dict.fromkeys(HISUI_STARTERS + [m for t in HISUI if t[0] == 'Akari' for m in t[3]]) if usable(i)]
        slug = re.sub(r'[^a-z0-9]+', '-', name.lower()).strip('-')
        leaders.append({'id': f'hisui-{slug}', 'name': name, 'trainer': trainer if trainer in sprites else '', 'kind': kind, 'team': team,
                        'pool': pool, **extra, 'city': city})
    return {'region': 'Hisui', 'game': 'Legends: Arceus', 'leaders': leaders}


TYPES = {'normal', 'fire', 'water', 'grass', 'electric', 'ice', 'fighting', 'poison', 'ground', 'flying', 'psychic', 'bug', 'rock', 'ghost',
         'dragon', 'dark', 'steel', 'fairy'}


def boss_kind(cls):
    if cls in GYM:
        return 'gym'
    if cls == 'Elite dos Quatro':
        return 'elite'
    if cls == 'Campeão':
        return 'champion'
    if cls in ('Rival', 'Treinador Pokémon', 'Dupla da Equipe Rocket', 'Dupla'):
        return 'rival'
    if 'Equipe' in cls or cls in ('Fundação Aether', 'Ultra Recon Squad', 'Macro Cosmos'):
        return 'villain'
    return None


def boss_story(game, usable, sprites):
    """A ordem dos chefes de um jogo: ginásios com rival e vilões no meio
    (pela altura da história), depois a Elite dos Quatro e o Campeão."""
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

    gyms, elites, champions, specials, post = [], [], [], [], []
    for t in game['trainers'] + EXTRA.get(game['name'], []):
        key = (game['name'], t['name'])
        if key in SKIP:
            continue
        battles = [b for b in t['battles'] if any(usable(m['id']) for m in b['team'])]
        if key in CHAMPION:
            title = [b for b in battles if VARIANT.sub('', b['label']) == CHAMPION[key]]
            if title:
                champions.append(entry({**t, 'battles': title}, title[0], 'champion'))
            battles = [b for b in battles if b not in title]
        kind = boss_kind(t['class'])
        if not kind or not battles:
            continue
        if kind in ('gym', 'elite', 'champion'):
            t = {**t, 'battles': battles}
            if kind == 'gym':
                gyms.append(entry(t, battles[0], kind))
            elif kind == 'elite':
                elites.append(entry(t, battles[0], kind))
            else:
                champions.append(entry(t, battles[-1], kind))
            continue
        # Uma luta por lugar (a primeira variação; as partes de uma luta juntas).
        fights = {}
        for b in battles:
            label = VARIANT.sub('', b['label'])
            if key in KEEP:
                label = re.sub(r' \(\d\)$', '', label).replace('Slumber Weald', 'Slumbering Weald')
            if key in MERGE and label.startswith(MERGE[key]):
                label = MERGE[key]
                if label in fights:
                    fights[label]['team'] += [m for m in b['team'] if m not in fights[label]['team']]
                    continue
            if REPEATABLE.search(label) or label in fights:
                continue
            fights[label] = {**b, 'label': label, 'team': list(b['team'])}
        if key in KEEP:
            missing = [label for label in KEEP[key] if label not in fights]
            if missing:
                print('sem a luta:', key, missing)
            fights = {label: fights[label] for label in KEEP[key] if label in fights}
        battles = list(fights.values())
        t = {**t, 'battles': battles}
        late = key in POSTGAME or t['class'] in POSTGAME_CLASS
        story = [b for b in battles if not late and not POSTGAME_LABEL.search(b['label'])]
        guest = t['class'] != 'Rival'
        for b in battles:
            e = entry(t, b, kind)
            if guest and kind == 'rival':
                e['guest'] = True  # não é o rival do jogo: não leva o inicial contra o seu nem aparece de surpresa
            if t.get('pair'):
                e['pair'] = True  # dois treinadores juntos: batalha em dupla
            if b in story:
                k = story.index(b)
                # A altura da história: o rival desde o começo (a primeira luta antes do primeiro ginásio); os outros espalhados no meio.
                at = k / len(story) if t['class'] == 'Rival' else (k + 1) / (len(story) + 1)
                specials.append((AT.get((game['name'], t['name'], b['label']), b.get('at', at)), e))
            else:
                post.append(e)
    if not gyms and not elites:
        return []
    if game['name'] in GYM_ORDER:
        names = {g['name']: g for g in gyms}
        missing = [n for n in GYM_ORDER[game['name']] if n not in names]
        if missing:
            print('sem o ginásio:', game['name'], missing)
        gyms = [names[n] for n in GYM_ORDER[game['name']] if n in names]
    kanto = []
    if game['name'] in KANTO_LATE:
        kanto = [g for g in gyms if g['name'] in KANTO_GYMS]
        gyms = [g for g in gyms if g['name'] not in KANTO_GYMS]
    specials.sort(key=lambda x: x[0])
    middle = [((i + 0.5) / len(gyms), 0, g) for i, g in enumerate(gyms)] + [(f, 1, e) for f, e in specials]
    middle.sort(key=lambda x: (x[0], x[1]))
    return [e for _, _, e in middle] + elites + champions[-1:] + kanto + post


def rocket_of(region, usable, sprites):
    """Jessie e James da região (sem lugar fixo na história: aparecem de surpresa na rota, por sorteio)."""
    if region not in JESSIE_JAMES:
        return None
    team = [i for i in JESSIE_JAMES[region] if usable(i)]
    return {'id': f"{region.lower()}-jessie-e-james", 'name': 'Jessie e James', 'trainer': 'sd-teamrocket' if 'sd-teamrocket' in sprites else '',
            'kind': 'rival', 'team': team, 'pool': team, 'guest': True, 'pair': True}


def add_cities(region, story):
    """A cidade de cada chefe (tool/factory_stories.py, CITIES): o ginásio do
    líder; rival e vilões, a do próximo líder; Elite dos Quatro e Campeão, a Liga."""
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
        out_species[sid] = [p['base_experience'] or 50, bst, rarity, [stat[1] for stat in p['stats']], p['types'], s['capture_rate'], habitats(sid, s, p, encounters),
                            s['gender_rate']]
    evolutions = {}
    special = set()

    def walk(node, reached=0):
        for nxt in node['evolves_to']:
            d = nxt.get('details') or {}
            trigger = d.get('trigger')
            item = ITEM_OVERRIDE.get(nxt['species']) or (d.get('item') if trigger == 'use-item' else None)
            # Evolução por pedra (ou outro item): só usando o item (nível 0).
            if item:
                level = 0
            elif d.get('min_level'):
                level = d['min_level']
            else:
                level = max(OTHER_TRIGGER.get(trigger, DEFAULT_OTHER), reached + OTHER_GAP)
                special.add((node['species'], nxt['species']))
            # Sem gatilho (Phione não evolui de verdade) ou Shedinja (no motor): fora.
            ok = trigger and trigger not in SKIP_TRIGGERS
            if ok and node['species'] in out_species and nxt['species'] in out_species:
                evolutions.setdefault(node['species'], []).append([nxt['species'], level, item] if item else [nxt['species'], level])
            walk(nxt, level)

    for chain in load('evolution_chains').values():
        walk(chain)
    for frm in list(evolutions):
        evolutions[frm] = [e for e in evolutions[frm] if (frm, e[0]) not in REGIONAL_ONLY]
        # Um ramo especial (troca...) não vem antes do ramo por nível (o Slowking não esconde o Slowbro): os dois no mesmo nível.
        natural = max([e[1] for e in evolutions[frm] if len(e) == 2 and (frm, e[0]) not in special] or [0])
        for e in evolutions[frm]:
            if len(e) == 2 and (frm, e[0]) in special and e[1] < natural:
                e[1] = natural
        if not evolutions[frm]:
            del evolutions[frm]
    for frm, es in FORM_EVOS.items():
        evolutions[frm] = es
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
            rocket = rocket_of(game['region'], usable, sprites)
            bosses.append({'region': game['region'], 'game': game['name'], 'leaders': story, **({'rocket': rocket} if rocket else {})})
    bosses.append(hisui_game(usable, sprites))
    # As regiões dos outros jogos (Orre, Ranger, DLC): tool/factory_extra_regions.py. 'after': só depois desse jogo.
    for r in EXTRA_REGIONS:
        leaders = []
        for name, trainer, kind, team, city, extra in r['leaders']:
            team = [i for i in team if usable(i)]
            pool = list(dict.fromkeys(m for t in r['leaders'] if t[0] == name for m in t[3] if usable(m))) if kind == 'rival' else list(team)
            slug = re.sub(r'[^a-z0-9]+', '-', name.lower()).strip('-')
            leaders.append({'id': f"{r['region'].lower()}-{slug}", 'name': name, 'trainer': trainer if trainer in sprites else '', 'kind': kind,
                            'team': team, 'pool': pool, **extra, 'city': city})
        bosses.append({'region': r['region'], 'game': r['game'], **({'after': r['after']} if r.get('after') else {}), 'leaders': leaders})
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
    # Os dados das formas regionais (tipos, atributos e XP da forma; captura, raridade e lugares da espécie).
    form_ids = {f for fs in REGIONAL['forms'].values() for f in fs.values()} | {f for fs in REGIONAL['evolveIn'].values() for f in fs.values()} \
        | {t for es in FORM_EVOS.values() for e in es for t in [e[0]] if t > 10000} | set(REGIONAL['femaleForm'].values())
    form_species = {}
    for fid in sorted(form_ids):
        rec = records[fid]
        base = out_species[rec['species']]
        form_species[fid] = [rec['base_experience'] or base[0], sum(st[0] for st in rec['stats']), base[2], [st[1] for st in rec['stats']], rec['types'],
                             base[5], base[6], base[7], rec['species']]
    regional_items = {e[2] for es in REGIONAL['regionEvos'].values() for x in es.values() for e in x if len(e) > 2}
    stones = sorted({e[2] for es in evolutions.values() for e in es if len(e) > 2} | regional_items)
    data = {'species': out_species, 'evolutions': evolutions, 'starters': STARTERS, 'bosses': bosses, 'forms': forms,
            'formSpecies': form_species, 'regional': REGIONAL,
            'megas': megas, 'gmax': gmax, 'zcrystals': zcrystals, 'tms': tms, 'stones': stones, 'stories': STORIES,
            'scenes': {r: {'cities': {c: [list(x) for x in ls] for c, ls in sc.get('cities', {}).items()},
                           'bosses': {k: {w: [list(x) for x in ls] for w, ls in v.items()} for k, v in sc.get('bosses', {}).items()}} for r, sc in SCENES.items()},
            'routes': {'cities': ROUTE_CITIES, 'start': ROUTE_START, 'features': ROUTE_FEATURES, 'rare': ROUTE_RARE, 'tutors': ROUTE_TUTORS}}
    with open(os.path.join(DB, 'factory.json'), 'w', encoding='utf-8') as f:
        json.dump(data, f, separators=(',', ':'))
        f.write('\n')
    print(len(out_species), 'espécies,', len(evolutions), 'com evolução')


if __name__ == '__main__':
    main()
