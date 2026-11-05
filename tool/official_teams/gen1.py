"""Times dos personagens de Red/Blue e Yellow (pret/pokered, pret/pokeyellow).

Na 1ª geração o treinador só define espécie e nível; os golpes são os que o
Pokémon aprende até aquele nível (os de nível 1 dos base stats e depois o
learnset, empurrando o mais antigo), com as trocas especiais de cada jogo:
- Red/Blue: LoneMoves (golpe do líder no ginásio), TeamMoves (5º Pokémon da
  Elite Four) e os golpes do campeão.
- Yellow: tabela SpecialTrainerMoves (classe, nº do treinador, posição, slot).
Todos os Pokémon de treinador têm DVs Atk 9, Def 8, Spe 8, Spc 8 (HP 8), sem
stat exp; não há nature nem habilidade.
"""

import os
import re

DV = {'hp': 8, 'atk': 9, 'def': 8, 'spe': 8, 'spc': 8}

# Classe do pret -> (classe em português, nome)
CLASSES = {
    'BROCK': ('Líder de Ginásio', 'Brock'), 'MISTY': ('Líder de Ginásio', 'Misty'), 'LT_SURGE': ('Líder de Ginásio', 'Lt. Surge'),
    'ERIKA': ('Líder de Ginásio', 'Erika'), 'KOGA': ('Líder de Ginásio', 'Koga'), 'SABRINA': ('Líder de Ginásio', 'Sabrina'),
    'BLAINE': ('Líder de Ginásio', 'Blaine'), 'GIOVANNI': ('Chefe da Equipe Rocket', 'Giovanni'),
    'LORELEI': ('Elite Four', 'Lorelei'), 'BRUNO': ('Elite Four', 'Bruno'), 'AGATHA': ('Elite Four', 'Agatha'), 'LANCE': ('Elite Four', 'Lance'),
    'RIVAL1': ('Rival', 'Blue'), 'RIVAL2': ('Rival', 'Blue'), 'RIVAL3': ('Campeão', 'Blue'),
}
DATA_LABELS = {'LT_SURGE': 'LtSurge', 'RIVAL1': 'Rival1', 'RIVAL2': 'Rival2', 'RIVAL3': 'Rival3'}
# Red/Blue: LoneMoves pela ordem do wLoneAttackNo (índice do Pokémon começando em 0, golpe no 3º slot).
LONE = ['BROCK', 'MISTY', 'LT_SURGE', 'ERIKA', 'KOGA', 'SABRINA', 'BLAINE', 'GIOVANNI']
# O rival escolhe o inicial forte contra o seu: linhas na ordem Squirtle, Bulbasaur, Charmander.
RB_STARTER_CHOICE = ['Charmander', 'Squirtle', 'Bulbasaur']
YELLOW_EEVEE = ['Jolteon', 'Flareon', 'Vaporeon']


def code(text):
    return re.sub(r';.*', '', text)


def species_order(text):
    """Constante de espécie em ordem de índice interno (const_skip conta)."""
    order = []
    for line in text.splitlines():
        line = code(line).strip()
        if line.startswith('const_skip'):
            order.append(None)
        elif line.startswith('const ') and not line.startswith('const_def'):
            order.append(line.split()[1])
    return order[1:]  # NO_MON


def learnsets(evos_text, species):
    pointers = re.findall(r'dw (\w+)EvosMoves', evos_text)
    blocks = {}
    for label, body in re.findall(r'^(\w+)EvosMoves:\n(.*?)(?=^\w+EvosMoves:|\Z)', evos_text, re.S | re.M):
        rows = [r for r in (code(l).strip() for l in body.splitlines()) if r.startswith('db')]
        moves, seen_end = [], False
        for r in rows:
            values = [v.strip() for v in r[2:].split(',')]
            if values == ['0']:
                if seen_end:
                    break
                seen_end = True
                continue
            if seen_end and len(values) == 2:
                moves.append((int(values[0]), values[1]))
        blocks[label] = moves
    return {sp: blocks[p] for sp, p in zip(species, pointers) if sp}


def level_one(base_dir):
    out = {}
    for name in os.listdir(base_dir):
        text = open(os.path.join(base_dir, name), encoding='utf-8').read()
        dex = re.search(r'db DEX_(\w+)', text).group(1)
        first = re.search(r'db ([\w, ]+?)\s*; level 1 learnset', text).group(1)
        out[dex] = [m.strip() for m in first.split(',') if m.strip() != 'NO_MOVE']
    return out


def default_moves(species, level, first, sets):
    moves = list(first[species])
    for lvl, move in sets[species]:
        if lvl > level or move in moves:
            continue
        if len(moves) == 4:
            moves.pop(0)
        moves.append(move)
    return moves


def parties(text):
    """{classe: [(comentário de local, [(nível, espécie)])]} na ordem do arquivo."""
    out = {}
    for label, body in re.findall(r'^(\w+)Data:\n(.*?)(?=^\w+Data:|\Z)', text, re.S | re.M):
        where, rows = '', []
        for line in body.splitlines():
            line = line.strip()
            if line.startswith(';'):
                where = line[1:].strip()
                continue
            if not line.startswith('db'):
                continue
            values = [v.strip() for v in code(line)[2:].split(',')][:-1]
            if values[0] == '$FF':
                team = [(int(values[i]), values[i + 1]) for i in range(1, len(values), 2)]
            else:
                team = [(int(values[0]), s) for s in values[1:]]
            rows.append((where, team))
        out[label] = rows
    return out


def special_moves(text):
    """Yellow: {(classe, nº): [(posição 1.., slot 1.., golpe)]}."""
    out, key = {}, None
    for line in text.splitlines():
        line = code(line).strip()
        if not line.startswith('db'):
            continue
        values = [v.strip() for v in line[2:].split(',')]
        if len(values) == 2:
            key = (values[0], int(values[1]))
            out[key] = []
        elif len(values) == 3:
            out[key].append((int(values[0]), int(values[1]), values[2]))
    return out


def lone_moves(text):
    rows = re.findall(r'db (\d+), (\w+)', text.split('LoneMoves:')[1].split('TeamMoves:')[0])
    return {LONE[i]: (int(idx), move) for i, (idx, move) in enumerate(rows)}


def team_moves(text):
    return dict(re.findall(r'db (\w+),\s+(\w+)', text.split('TeamMoves:')[1]))


def build(root, resolve, yellow):
    species = species_order(open(os.path.join(root, 'pokemon_constants.asm'), encoding='utf-8').read())
    sets = learnsets(open(os.path.join(root, 'evos_moves.asm'), encoding='utf-8').read(), species)
    first = level_one(os.path.join(root, 'base_stats'))
    data = parties(open(os.path.join(root, 'parties.asm'), encoding='utf-8').read())
    special = open(os.path.join(root, 'special_moves.asm'), encoding='utf-8').read()
    extra = special_moves(special) if yellow else {}
    lone = {} if yellow else lone_moves(special)
    team = {} if yellow else team_moves(special)
    out = []
    for const, (cls, name) in CLASSES.items():
        label = DATA_LABELS.get(const, const.capitalize())
        rows = data[label]
        for number, (where, party) in enumerate(rows, start=1):
            mons = [default_moves(sp, lvl, first, sets) for lvl, sp in party]

            def put(pos, slot, move):
                while len(mons[pos]) <= slot:
                    mons[pos].append(None)
                mons[pos][slot] = move
            if yellow:
                for pos, slot, move in extra.get((const, number), []):
                    put(pos - 1, slot - 1, move)
            else:
                if const in lone and (const != 'GIOVANNI' or where == 'Viridian Gym'):
                    put(lone[const][0], 2, lone[const][1])
                if const in team:
                    put(4, 2, team[const])
                if const == 'RIVAL3':
                    put(0, 2, 'SKY_ATTACK')
                    starter = party[5][1]
                    put(5, 2, {'VENUSAUR': 'MEGA_DRAIN', 'CHARIZARD': 'FIRE_BLAST'}.get(starter, 'BLIZZARD'))
            if not where:
                where = {'RIVAL1': "Oak's Lab", 'RIVAL3': 'Indigo Plateau'}.get(const, '')
            if const == 'RIVAL3':
                where = 'Liga Pokémon'
            if const.startswith('RIVAL'):
                group = [i for i, r in enumerate(rows, start=1) if r[0] == rows[number - 1][0]]
                if yellow and len(group) == 3:
                    # As 3 variantes seguem a evolução final do Eevee dele (ordem do jogo).
                    where = f'{where} (Eevee → {YELLOW_EEVEE[group.index(number)]})'
                elif not yellow:
                    where = f'{where} (se você escolheu {RB_STARTER_CHOICE[(number - 1) % 3]})'
            out.append({
                'name': name, 'class': cls, 'label': where or 'Luta',
                'team': [{
                    'id': resolve('species', 'SPECIES_' + sp), 'level': lvl, 'item': None,
                    'moves': [resolve('move', 'MOVE_' + m) for m in moves if m],
                    'dv': DV, 'iv': None, 'ev': 0, 'nature': None, 'ability': None,
                } for (lvl, sp), moves in zip(party, mons)],
            })
    return out
