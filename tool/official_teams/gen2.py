"""Times dos personagens de Gold/Silver e Crystal (pret/pokegold, pret/pokecrystal).

parties.asm traz nível, espécie e, conforme o tipo do treinador, item e os 4
golpes; sem golpes, o Pokémon fica com os que aprende até o nível (empurrando
o mais antigo). Os DVs vêm por classe de treinador (dvs.asm); o HP sai dos bits
baixos dos outros. Sem stat exp, nature ou habilidade nessa geração.
O local de cada luta vem dos scripts dos mapas (loadtrainer/trainer).
"""

import os
import re

CLASSES = {
    **{c: 'Líder de Ginásio' for c in ('FALKNER', 'BUGSY', 'WHITNEY', 'MORTY', 'CHUCK', 'JASMINE', 'PRYCE', 'CLAIR',
                                       'BROCK', 'MISTY', 'LT_SURGE', 'ERIKA', 'JANINE', 'SABRINA', 'BLAINE', 'BLUE')},
    **{c: 'Elite Four' for c in ('WILL', 'KOGA', 'BRUNO', 'KAREN')},
    'CHAMPION': 'Campeão', 'RIVAL1': 'Rival', 'RIVAL2': 'Rival', 'RED': 'Treinador Pokémon',
    'EXECUTIVEM': 'Executivo da Equipe Rocket', 'EXECUTIVEF': 'Executiva da Equipe Rocket',
}
NAMES = {'RIVAL1': 'Silver', 'RIVAL2': 'Silver', 'EXECUTIVEM': 'Executivo', 'EXECUTIVEF': 'Executiva'}
PLACES = {'IndigoPlateauPokecenter1F': 'Indigo Plateau', 'GoldenrodUndergroundSwitchRoomEntrances': 'Goldenrod Underground',
          'MountMoon': 'Mt. Moon', 'TeamRocketBaseB2F': 'Rocket Hideout B2F', 'TeamRocketBaseB3F': 'Rocket Hideout B3F'}
# O rival pega o inicial forte contra o seu.
CHOICE = {'CHIKORITA': 'Totodile', 'CYNDAQUIL': 'Chikorita', 'TOTODILE': 'Cyndaquil'}


def code(text):
    return re.sub(r';.*', '', text)


def learnsets(text):
    out = {}
    for label, body in re.findall(r'^(\w+)EvosAttacks:\n(.*?)(?=^\w+EvosAttacks:|^\w+:|\Z)', text, re.S | re.M):
        rows = [r for r in (code(l).strip() for l in body.splitlines()) if r.startswith('db')]
        moves, after = [], False
        for r in rows:
            values = [v.strip() for v in r[2:].split(',')]
            if values == ['0']:
                if after:
                    break
                after = True
            elif after and len(values) == 2:
                moves.append((int(values[0]), values[1]))
        out[label] = moves
    return out  # na ordem da Pokédex


def species_consts(text):
    names = []
    for line in text.splitlines():
        m = re.match(r'\s*const (\w+)', line)
        if m and m.group(1) not in ('NO_MON',) and not m.group(1).startswith('const_'):
            names.append(m.group(1))
        if names and names[-1] == 'CELEBI':
            break
    return names


def default_moves(sets, level):
    moves = []
    for lvl, move in sets:
        if lvl > level:
            break
        if move in moves:
            continue
        if len(moves) == 4:
            moves.pop(0)
        moves.append(move)
    return moves


def class_dvs(text):
    out = {}
    for atk, df, spd, spc, cls in re.findall(r'dn\s+(\d+),\s*(\d+),\s*(\d+),\s*(\d+)\s*;\s*(\w+)', text):
        a, d, s, c = map(int, (atk, df, spd, spc))
        out[cls] = {'hp': (a & 1) << 3 | (d & 1) << 2 | (s & 1) << 1 | (c & 1), 'atk': a, 'def': d, 'spe': s, 'spc': c}
    return out


def trainer_consts(text):
    out, cls = {}, None
    for line in text.splitlines():
        m = re.match(r'\s*trainerclass (\w+)', line)
        if m:
            cls = m.group(1)
            out[cls] = []
            continue
        m = re.match(r'\s*const (\w+)', line)
        if m and cls:
            out[cls].append(m.group(1))
    return out


def places(maps_dir):
    out = {}
    if not maps_dir or not os.path.isdir(maps_dir):
        return out
    for name in sorted(n for n in os.listdir(maps_dir) if n.endswith('.asm')):
        text = open(os.path.join(maps_dir, name), encoding='utf-8').read()
        for cls, const in re.findall(r'(?:loadtrainer|trainer)\s+(\w+),\s*(\w+)', text):
            out.setdefault((cls, const), name.removesuffix('.asm'))
    return out


def place_label(name):
    return PLACES.get(name) or re.sub(r'(?<=[a-z])(?=[A-Z0-9])|(?<=[0-9])(?=[A-Z][a-z])', ' ', name)


def parties(text):
    """[(classe, nº, nome, tipo, linhas)]"""
    out = []
    for cls, number, body in re.findall(r';\s*(\w+) \((\d+)\)\n(.*?)db -1', text, re.S):
        head = re.search(r'db "(.*?)@", (TRAINERTYPE_\w+)', body)
        rows = [[v.strip() for v in code(l).strip()[2:].split(',')] for l in body.splitlines()[1:]
                if code(l).strip().startswith('db ') and '"' not in l]
        out.append((cls, int(number), head.group(1), head.group(2), rows))
    return out


def build(root, resolve, maps_dir=None):
    read = lambda name: open(os.path.join(root, name), encoding='utf-8').read()
    by_species = dict(zip(species_consts(read('pokemon_constants.asm')), learnsets(read('evos_attacks.asm')).values()))
    dvs = class_dvs(read('dvs.asm'))
    consts = trainer_consts(read('trainer_constants.asm'))
    where = places(maps_dir)
    out = []
    for cls, number, name, kind, rows in parties(read('parties.asm')):
        if cls not in CLASSES:
            continue
        const = consts[cls][number - 1]
        if (cls, const) not in where and cls not in ('CHAMPION',):
            continue  # não é usado em nenhum mapa
        label = place_label(where[(cls, const)]) if cls in ('RIVAL1', 'RIVAL2', 'EXECUTIVEM', 'EXECUTIVEF') else 'Luta'
        starter = const.rsplit('_', 1)[-1]
        if starter in CHOICE:
            label = f'{label} (se você escolheu {CHOICE[starter]})'
        team = []
        for row in rows:
            level, sp = int(row[0]), row[1]
            item = row[2] if 'ITEM' in kind else None
            moves = row[3:] if kind == 'TRAINERTYPE_ITEM_MOVES' else row[2:] if kind == 'TRAINERTYPE_MOVES' else default_moves(by_species[sp], level)
            team.append({
                'id': resolve('species', 'SPECIES_' + sp), 'level': level,
                'item': resolve('item', 'ITEM_' + item) if item and item != 'NO_ITEM' else None,
                'moves': [resolve('move', 'MOVE_' + m) for m in moves if m != 'NO_MOVE'],
                'dv': dvs[cls], 'iv': None, 'ev': 0, 'nature': None, 'ability': None,
            })
        out.append({'name': NAMES.get(cls, name), 'class': CLASSES[cls], 'label': label, 'team': team, 'order': list(CLASSES).index(cls)})
    # Na ordem em que você enfrenta (o arquivo do jogo segue a ordem das classes).
    out.sort(key=lambda b: b.pop('order'))
    return out
