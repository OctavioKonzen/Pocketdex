"""Geração 3 (Ruby/Sapphire, Emerald, FireRed/LeafGreen) a partir dos projetos
pret (pokeruby, pokeemerald, pokefirered): os times exatamente como estão no
jogo. A personalidade (e dela a nature e a habilidade) é calculada como o
próprio jogo faz em CreateNPCTrainerParty (src/battle_main.c):

    personalidade = (0x80 em dupla | 0x78 treinadora | 0x88 treinador)
                    + (soma dos bytes do nome do treinador e das espécies até
                       aqui, acumulada no time todo) << 8
    nature = personalidade % 25; habilidade = abilities[personalidade & 1]
    IV de todos os atributos = iv * 31 / 255; EVs = 0.
"""

import re

from common import NATURES, slug

# Classes dos personagens (líderes, Elite Four, campeões, vilões e rivais).
CLASSES = {
    'TRAINER_CLASS_LEADER': 'Líder de Ginásio', 'TRAINER_CLASS_ELITE_FOUR': 'Elite Four', 'TRAINER_CLASS_CHAMPION': 'Campeão',
    'TRAINER_CLASS_MAGMA_LEADER': 'Chefe da Equipe Magma', 'TRAINER_CLASS_AQUA_LEADER': 'Chefe da Equipe Aqua',
    'TRAINER_CLASS_BOSS': 'Chefe da Equipe Rocket', 'TRAINER_CLASS_RIVAL': 'Rival',
    'TRAINER_CLASS_RIVAL_EARLY': 'Rival', 'TRAINER_CLASS_RIVAL_LATE': 'Rival',
}


def charmap(text):
    table = {}
    for line in text.splitlines():
        m = re.match(r"^'(.+?)'\s*=\s*([0-9A-Fa-f]{2})\b", line)
        if m:
            ch = m.group(1).replace("\\'", "'")
            table.setdefault(ch, int(m.group(2), 16))
    return table


def encode(name, table):
    return [table[c] for c in name]


def parse_species_names(text):
    return {k: v for k, v in re.findall(r'\[(SPECIES_\w+)\]\s*=\s*_\("([^"]*)"\)', text)}


def parse_abilities(text):
    out = {}
    for key, body in re.findall(r'\[(SPECIES_\w+)\]\s*=\s*\{(.*?)\n    \}', text, re.S):
        m = re.search(r'\.abilities\s*=\s*\{\s*(\w+)\s*,\s*(\w+)\s*\}', body)
        if m:
            out[key] = (m.group(1), m.group(2))
        else:
            a1 = re.search(r'\.ability1\s*=\s*(\w+)', body)
            a2 = re.search(r'\.ability2\s*=\s*(\w+)', body)
            if a1:
                out[key] = (a1.group(1), a2.group(1) if a2 else 'ABILITY_NONE')
    return out


def parse_learnsets(sets_text, pointers_text):
    sets = {}
    for name, body in re.findall(r'static const u16 (\w+)\[\]\s*=\s*\{(.*?)\};', sets_text, re.S):
        sets[name] = [(int(l), m) for l, m in re.findall(r'LEVEL_UP_MOVE\(\s*(\d+),\s*(\w+)\)', body)]
    pointers = dict(re.findall(r'\[(SPECIES_\w+)\]\s*=\s*(\w+)', pointers_text))
    return {sp: sets.get(p, []) for sp, p in pointers.items()}


def default_moves(learnset, level):
    """GiveBoxMonInitialMoveset: os golpes até o nível; com 4, o mais antigo sai."""
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


def parse_parties(text):
    """Os times (o formato muda um pouco entre pokeruby, pokeemerald e pokefirered)."""
    parties = {}
    for kind, name, body in re.findall(r'(?:static )?const struct (\w+) (\w+)\[\]\s*=\s*\{(.*?)\n\};', text, re.S):
        mons = []
        for chunk in re.split(r'\n    \},?', body):
            if '.species' not in chunk:
                continue
            get = lambda k: (re.search(rf'\.{k}\s*=\s*(\w+)', chunk) or [None, None])[1]
            moves = re.search(r'\.moves\s*=\s*\{?([^}\n]*)', chunk)
            mons.append({
                'iv': int(get('iv')), 'lvl': int(get('lvl') or get('level')), 'species': get('species'),
                'item': get('heldItem'), 'moves': [m.strip() for m in moves.group(1).split(',') if m.strip()] if moves else None,
            })
        parties[name] = mons
    return parties


def parse_trainers(text):
    out = []
    for key, body in re.findall(r'\[(TRAINER_\w+)\]\s*=\s*\{(.*?)\n    \},', text, re.S):
        cls = re.search(r'\.trainerClass\s*=\s*(\w+)', body)
        name = re.search(r'\.trainerName\s*=\s*_\("([^"]*)"\)', body)
        party = re.search(r'\.party\s*=.*?\b(sParty_\w+|gTrainerParty_\w+)', body)
        if not cls or not name or not party:
            continue
        out.append({
            'key': key, 'class': cls.group(1), 'name': name.group(1), 'party': party.group(1),
            'double': bool(re.search(r'\.doubleBattle\s*=\s*TRUE', body)),
            'female': 'F_TRAINER_FEMALE' in body,
        })
    return out


def build(files, resolve):
    """files: textos do jogo; resolve: (kind, CONSTANTE) -> slug/id do banco."""
    table = charmap(files['charmap'])
    names = parse_species_names(files['species_names'])
    abilities = parse_abilities(files['species_info'])
    learnsets = parse_learnsets(files['learnsets'], files['learnset_pointers'])
    parties = parse_parties(files['parties'])
    out = []
    for t in parse_trainers(files['trainers']):
        if t['class'] not in CLASSES or t['party'] not in parties:
            continue
        base = 0x80 if t['double'] else 0x78 if t['female'] else 0x88
        name_hash = 0
        team = []
        for mon in parties[t['party']]:
            name_hash += sum(encode(t['name'], table))
            name_hash += sum(encode(names[mon['species']], table))
            pid = (base + (name_hash << 8)) & 0xFFFFFFFF
            a1, a2 = abilities.get(mon['species'], ('ABILITY_NONE', 'ABILITY_NONE'))
            ability = a2 if (pid & 1) and a2 != 'ABILITY_NONE' else a1
            moves = mon['moves'] or default_moves(learnsets.get(mon['species'], []), mon['lvl'])
            team.append({
                'id': resolve('species', mon['species']), 'level': mon['lvl'],
                'item': resolve('item', mon['item']) if mon['item'] and mon['item'] != 'ITEM_NONE' else None,
                'moves': [resolve('move', m) for m in moves if m != 'MOVE_NONE'],
                'iv': mon['iv'] * 31 // 255, 'ev': 0,
                'nature': NATURES[pid % 25], 'ability': resolve('ability', ability) if ability != 'ABILITY_NONE' else None,
            })
        out.append({'key': t['key'], 'class': CLASSES[t['class']], 'name': t['name'], 'team': team})
    return out
