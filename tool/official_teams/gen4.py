"""Geração 4 (Platinum) a partir do pret/pokeplatinum (res/trainers/data/*.json).
A personalidade é calculada como em TrainerData_BuildParty (src/trainer_data.c):

    semente = escala_iv + nível + espécie + número do treinador
    repete (número da classe) vezes: semente = semente * 1103515245 + 24691;
                                      valor = semente >> 16
    personalidade = (valor << 8) + (120 treinadora | 136 treinador)
    nature = personalidade % 25; habilidade = 2ª se personalidade & 1 (e ela existe)
    IV de todos os atributos = escala_iv * 31 / 255; EVs = 0.
"""

import json
import os
import re

from common import NATURES

# Prefixos dos arquivos dos personagens e a classe na tela.
CLASSES = [('leader_', 'Líder de Ginásio'), ('elite_four_', 'Elite Four'), ('champion_', 'Campeão'),
           ('galactic_boss_', 'Chefe da Equipe Galáctica'), ('commander_', 'Comandante da Equipe Galáctica'), ('rival_', 'Rival')]


def default_moves(learnset, level):
    moves = []
    for lvl, move in learnset:
        if lvl > level:
            break
        if move in moves:
            continue
        if len(moves) == 4:
            moves.pop(0)
        moves.append(move)
    return moves


def build(root, resolve, skip=()):
    lines = lambda name: [l.strip() for l in open(os.path.join(root, 'generated', name), encoding='utf-8') if l.strip()]
    trainers = {name: i for i, name in enumerate(lines('trainers.txt'))}
    classes = {name: i for i, name in enumerate(lines('trainer_classes.txt'))}
    species_ids = {name: i for i, name in enumerate(lines('species.txt'))}
    genders = dict(re.findall(r'\[(TRAINER_CLASS_\w+)\]\s*=\s*(GENDER_\w+)', open(os.path.join(root, 'include', 'data', 'trainer_class_genders.h')).read()))
    species_data = {}

    def species(const):
        if const not in species_data:
            path = os.path.join(root, 'res', 'pokemon', const.removeprefix('SPECIES_').lower(), 'data.json')
            species_data[const] = json.load(open(path, encoding='utf-8'))
        return species_data[const]

    out = []
    folder = os.path.join(root, 'res', 'trainers', 'data')
    for file in sorted(os.listdir(folder)):
        cls = next((label for prefix, label in CLASSES if file.startswith(prefix)), None)
        if not cls or 'unused' in file or file.removesuffix('.json') in skip:
            continue
        data = json.load(open(os.path.join(folder, file), encoding='utf-8'))
        key = 'TRAINER_' + file.removesuffix('.json').upper()
        trainer_id = trainers[key]
        class_id = classes[data['class']]
        gender_mod = 120 if genders.get(data['class']) == 'GENDER_FEMALE' else 136
        team = []
        for mon in data['party']:
            sp = species_ids[mon['species']]
            seed = (mon['iv_scale'] + mon['level'] + sp + trainer_id) & 0xFFFFFFFF
            value = seed
            for _ in range(class_id):
                seed = (seed * 1103515245 + 24691) & 0xFFFFFFFF
                value = seed >> 16
            pid = ((value << 8) + gender_mod) & 0xFFFFFFFF
            info = species(mon['species'])
            a1, a2 = (info['abilities'] + ['ABILITY_NONE'])[:2]
            ability = a2 if (pid & 1) and a2 != 'ABILITY_NONE' else a1
            moves = mon.get('moves') or default_moves(info['learnset']['by_level'], mon['level'])
            team.append({
                'id': resolve('species', mon['species']), 'level': mon['level'],
                'item': resolve('item', mon['item']) if mon.get('item') and mon['item'] != 'ITEM_NONE' else None,
                'moves': [resolve('move', m) for m in moves if m and m != 'MOVE_NONE'],
                'iv': mon['iv_scale'] * 31 // 255, 'ev': 0,
                'nature': NATURES[pid % 25], 'ability': resolve('ability', ability) if ability != 'ABILITY_NONE' else None,
            })
        out.append({'key': key, 'class': cls, 'name': data['name'].upper(), 'team': team})
    return out
