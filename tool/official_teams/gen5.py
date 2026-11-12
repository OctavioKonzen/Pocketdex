"""Times dos personagens de Black 2/White 2 (fuddlesworth/pokebw2, a desmontagem do jogo).

data/trainers/NNNN_nome.s traz cada treinador (classe e Pokémon: nível,
espécie, forma, "difficulty", sexo/habilidade pedidos, item e golpes). Como
o jogo gera o resto (src/system/tr_tool.c, TrainerUtil_LoadParty):
  base do PID = 0x78 (treinadora) ou 0x88 (treinador); se o Pokémon pede sexo,
  base = proporção de sexo da espécie ± 2; habilidade 1/2 zera/liga o bit 0.
  (Bug do jogo: a base não volta ao normal entre um Pokémon e o próximo.)
  semente = difficulty + nível + espécie + nº do treinador; o RNG de 64 bits
  do Nitro (MATH_Rand32) roda "classe do treinador" vezes, até 0x10000.
  PID = (número << 8) + base; nature = (PID >> 8) % 25; IVs = difficulty*31/255.
  Habilidade: 1 = 1ª, 2 = 2ª, 3 = oculta; sem pedido, o bit 16 do PID
  escolhe entre a 1ª e a 2ª (regra da 5ª geração).
"""

import os
import re

MUL = (1566083941 << 32) + 1812433253
ADD = 2531011
MASK = (1 << 64) - 1

# Classe do pret -> (classe em português, nome).
PEOPLE = {
    'LEADER_CHEREN': ('Líder de Ginásio', 'Cheren'), 'LEADER_ROXIE': ('Líder de Ginásio', 'Roxie'),
    'LEADER_BURGH': ('Líder de Ginásio', 'Burgh'), 'LEADER_ELESA': ('Líder de Ginásio', 'Elesa'),
    'LEADER_CLAY': ('Líder de Ginásio', 'Clay'), 'LEADER_SKYLA': ('Líder de Ginásio', 'Skyla'),
    'LEADER_DRAYDEN': ('Líder de Ginásio', 'Drayden'), 'LEADER_MARLON': ('Líder de Ginásio', 'Marlon'),
    'ELITE_FOUR_SHAUNTAL': ('Elite Four', 'Shauntal'), 'ELITE_FOUR_GRIMSLEY': ('Elite Four', 'Grimsley'),
    'ELITE_FOUR_CAITLIN': ('Elite Four', 'Caitlin'), 'ELITE_FOUR_MARSHAL': ('Elite Four', 'Marshal'),
    'CHAMPION': ('Campeão', 'Iris'), 'PKMN_TRAINER_RIVAL': ('Rival', 'Hugh'),
    'TEAM_PLASMA_GHETSIS': ('Chefe da Equipe Plasma', 'Ghetsis'), 'TEAM_PLASMA_COLRESS': ('Equipe Plasma', 'Colress'),
    'PKMN_TRAINER_COLRESS_195': ('Equipe Plasma', 'Colress'), 'PKMN_TRAINER_COLRESS_235': ('Equipe Plasma', 'Colress'), 'TEAM_PLASMA_ZINZOLIN': ('Equipe Plasma', 'Zinzolin'),
    'PKMN_TRAINER_N': ('Treinador Pokémon', 'N'), 'PKMN_TRAINER_ALDER': ('Treinador Pokémon', 'Alder'),
    'BOSS_TRAINER_BENGA': ('Treinador Pokémon', 'Benga'),
}
# Lutas: nº do arquivo -> legenda (do que se sabe pelo time; o resto vira "Luta N").
LABELS = {
    **{n: 'Luta no ginásio' for n in range(153, 161)}, **{n: 'Luta no ginásio (Modo Desafio)' for n in range(764, 772)},
    38: 'Liga Pokémon', 39: 'Liga Pokémon', 40: 'Liga Pokémon', 41: 'Liga Pokémon', 341: 'Liga Pokémon',
    **{n: 'Liga Pokémon (Modo Desafio)' for n in range(772, 777)},
    143: 'Revanche', 144: 'Revanche', 145: 'Revanche', 146: 'Revanche', 536: 'Revanche',
    **{n: 'Revanche (Modo Desafio)' for n in range(777, 782)},
    5: 'Com Zekrom', 6: 'Com Reshiram', 201: 'Black Tower / White Treehollow', 202: 'Black Tower / White Treehollow',
    582: 'Depois da Liga', 813: 'Depois da Liga',
    782: 'Castelo do N (time 1)', 783: 'Castelo do N (time 2)', 784: 'Castelo do N (time 3)', 785: 'Castelo do N (time 4)',
}
SKIP = {581}  # Colress com um Patrat nível 1: dado de teste, não aparece no jogo.
# O Hugh leva o inicial forte contra o seu.
CHOICE = {'TEPIG': 'Snivy', 'OSHAWOTT': 'Tepig', 'SNIVY': 'Oshawott', 'EMBOAR': 'Snivy', 'SAMUROTT': 'Tepig', 'SERPERIOR': 'Oshawott',
          'PIGNITE': 'Snivy', 'DEWOTT': 'Tepig', 'SERVINE': 'Oshawott'}
NATURES = ['Hardy', 'Lonely', 'Brave', 'Adamant', 'Naughty', 'Bold', 'Docile', 'Relaxed', 'Impish', 'Lax', 'Timid', 'Hasty', 'Serious',
           'Jolly', 'Naive', 'Modest', 'Mild', 'Quiet', 'Bashful', 'Rash', 'Calm', 'Gentle', 'Sassy', 'Careful', 'Quirky']


def attrs(text):
    return dict(re.findall(r'(\w+)=([^,]+?)(?=,\s*\w+=|$)', text.strip()))


def class_numbers(text):
    return {m.group(1): int(m.group(2)) for m in re.finditer(r'#define TRAINER_CLASS_(\w+) (\d+)', text)}


def sex_ratio(gender_rate):
    return 255 if gender_rate < 0 else 0 if gender_rate == 0 else 254 if gender_rate == 8 else gender_rate * 32 - 1


def rand32(x, times):
    r = 0
    for _ in range(times):
        x = (MUL * x + ADD) & MASK
        r = ((x >> 32) * 0x10000) >> 32
    return r


def build(root, resolve, pokemon, species):
    # Sexo de cada classe: TRAINER_CLASS_RESOURCES (sprite, sexo, música) em tr_tool.c; 1 = mulher.
    tool = open(os.path.join(root, 'src/system/tr_tool.c'), encoding='utf-8').read()
    female_classes = {c for c, sex in re.findall(r'\[TRAINER_CLASS_(\w+)\] = \{ \d+, (\d+),', tool) if sex == '1'}
    numbers = class_numbers(open(os.path.join(root, 'include/constants/trainer_classes.h'), encoding='utf-8').read())
    rows = {p['id']: p for p in pokemon}
    by_species = {}
    for p in pokemon:
        if not any(k in p['name'] for k in ('-mega', '-gmax', '-totem')):
            by_species.setdefault(p['species'], []).append(p)
    rates = {s['id']: s['gender_rate'] for s in species}
    folder = os.path.join(root, 'data/trainers')
    out = []
    for file in sorted(os.listdir(folder)):
        number = int(file.split('_')[0])
        text = open(os.path.join(folder, file), encoding='utf-8').read()
        head = re.search(r'^\s*Trainer (.*)', text, re.M)
        if not head or number in SKIP:
            continue
        info = attrs(head.group(1))
        cls = info['class'].removeprefix('TRAINER_CLASS_')
        if cls not in PEOPLE:
            continue
        class_label, name = PEOPLE[cls]
        pid_base = 0x78 if cls in female_classes else 0x88
        team = []
        for line in re.findall(r'PartyMon (.*)', text):
            m = attrs(line)
            sp_id = resolve('species', m['species'])
            level, difficulty = int(m['level']), int(m.get('difficulty', 0))
            form = int(m.get('form', 0))
            sex, ability = int(m.get('gender', 0)), int(m.get('ability', 0))
            if sex or ability:  # TrainerUtil_CalcBasePID (a base fica para os próximos: bug do jogo)
                if sex:
                    pid_base = sex_ratio(rates[sp_id]) + (2 if sex == 1 else -2)
                if ability == 1:
                    pid_base &= ~1
                elif ability == 2:
                    pid_base |= 1
            r = rand32(difficulty + level + sp_id + number, numbers[cls])
            pid = ((r << 8) + pid_base) & 0xFFFFFFFF
            forms = sorted(by_species[sp_id], key=lambda p: (not p['is_default'], p['id']))
            row = forms[form] if form < len(forms) else forms[0]
            normal = [a for a, hidden in row['abilities'] if not hidden]
            hidden = [a for a, h in row['abilities'] if h]
            if ability == 3:
                chosen = (hidden or normal)[0]
            elif ability in (1, 2):
                chosen = normal[1] if ability == 2 and len(normal) > 1 else normal[0]
            else:
                chosen = normal[(pid >> 16) & 1] if len(normal) > 1 else normal[0]
            moves = [m[f'move{k}'] for k in range(1, 5) if m.get(f'move{k}', 'MOVE_NONE') != 'MOVE_NONE']
            item = m.get('item', 'ITEM_NONE')
            team.append({
                'id': row['id'], 'level': level, 'item': None if item == 'ITEM_NONE' else resolve('item', item),
                'moves': [resolve('move', mv) for mv in moves], 'iv': difficulty * 31 // 255, 'ev': 0,
                'nature': NATURES[(pid >> 8) % 25], 'ability': chosen,
            })
        if not team:
            continue
        label = LABELS.get(number)
        out.append({'key': f'{number:04d}', 'name': name, 'class': class_label, 'label': label, 'team': team,
                    'starter': next((CHOICE[s] for s in CHOICE if any(rows[t['id']]['name'] == s.lower() for t in team)), None)})
    # Sem legenda conhecida (Hugh, Zinzolin, Colress): "Luta N" na ordem do nível.
    groups = {}
    for b in out:
        if not b['label']:
            groups.setdefault(b['name'], []).append(b)
    for battles in groups.values():
        levels = sorted({max(t['level'] for t in b['team']) for b in battles})
        for b in battles:
            n = levels.index(max(t['level'] for t in b['team'])) + 1
            b['label'] = (f'Luta {n}' if len(levels) > 1 else 'Luta') + (f' (se você escolheu {b["starter"]})' if b['name'] == 'Hugh' and b['starter'] else '')
    for b in out:
        b.pop('starter')
    # As lutas "Luta N" de cada um na ordem (o arquivo não segue a ordem da história).
    def rank(b):
        n = re.match(r'Luta (\d+)', b['label'])
        return int(n.group(1)) if n else 99 if b['label'] == 'Depois da Liga' else 0
    return sorted(out, key=rank)
