"""Times dos personagens de Scarlet/Violet (versão 1.0, sem as DLCs).

Fonte: trdata_array do jogo, em JSON (trdata_array_clean.json) com o esquema
FlatBuffers (trdata_array.bfbs), como estão no SV-Randomizer
(github.com/XLuma/SV-Randomizer, pasta Randomizer/Trainers). O esquema traz os
enums do jogo: o número de cada espécie, golpe e nature é o oficial. O
número interno das espécies novas difere da Pokédex nacional a partir do 917;
a tabela de conversão é a do PKHeX (SpeciesConverter, Table9InternalToNational).

Aqui o jogo define tudo: nível, golpes, item, IVs, EVs, nature, habilidade
(slot) e o tipo Tera. Quando o jogo sorteia (IVs, nature ou habilidade
"aleatórios"), fica anotado assim.
"""

import struct

# PKHeX: SpeciesConverter.Table9InternalToNational (a partir do interno 917).
INTERNAL_TO_NATIONAL = [
    65, -1, -1, -1, -1, 31, 31, 47, 47, 29, 29, 53, 31, 31, 46, 44, 30, 30, -7, -7, -7, 13, 13, -2, -2, 23, 23, 24, -21, -21,
    27, 27, 47, 47, 47, 26, 14, -33, -33, -33, -17, -17, 3, -29, 12, -12, -31, -31, -31, 3, 3, -24, -24, -44, -44, -30, -30,
    -28, -28, 23, 23, 6, 7, 29, 8, 3, 4, 4, 20, 4, 23, 6, 3, 3, 4, -1, 13, 9, 7, 5, 7, 9, 9, -43, -43, -43, -68, -68, -68,
    -58, -58, -25, -29, -31, 6, -1, 6, 0, 0, 0, 3, 3, 4, 2, 3, 3, -5, -12, -12,
]
NATURES = ['Hardy', 'Lonely', 'Brave', 'Adamant', 'Naughty', 'Bold', 'Docile', 'Relaxed', 'Impish', 'Lax', 'Timid', 'Hasty', 'Serious',
           'Jolly', 'Naive', 'Modest', 'Mild', 'Quiet', 'Bashful', 'Rash', 'Calm', 'Gentle', 'Sassy', 'Careful', 'Quirky']
TYPES = ['normal', 'fighting', 'flying', 'poison', 'ground', 'rock', 'bug', 'ghost', 'steel', 'fire', 'water', 'grass', 'electric',
         'psychic', 'ice', 'dragon', 'dark', 'fairy']
# Os poucos itens que os personagens seguram (nomes internos em japonês romanizado).
ITEMS = {'ITEMID_NONE': None, 'ITEMID_BUUSUTOENAJII': 'booster-energy', 'ITEMID_ATUIIWA': 'heat-rock', 'ITEMID_GURANDOKOOTO': 'terrain-extender'}
STATS = [('hp', 'hp'), ('atk', 'atk'), ('def', 'def'), ('spAtk', 'spa'), ('spDef', 'spd'), ('agi', 'spe')]

# Nome no jogo (TRNAME_*) -> nome em inglês.
NAMES = {
    'OMODAKA': 'Geeta', 'NEMO': 'Nemona', 'PEPAA': 'Arven', 'BOTAN': 'Penny', 'KURABERU': 'Clavell',
    'KAEDE': 'Katy', 'KORUSA': 'Brassius', 'NANJAMO': 'Iono', 'HAIDAI': 'Kofu', 'AOKI': 'Larry', 'RAIMU': 'Ryme',
    'RIPPU': 'Tulip', 'GURUUSYA': 'Grusha', 'TIRI': 'Rika', 'POPII': 'Poppy', 'HASSAKU': 'Hassel',
    'PIINYA': 'Giacomo', 'MEROKO': 'Mela', 'SYUUMEI': 'Atticus', 'ORUTHIGA': 'Ortega', 'BIWA': 'Eri',
    'HAKASE_A': 'Sada', 'HAKASE_B': 'Turo',
    'KIHADA': 'Dendra', 'MIMOZA': 'Miriam', 'REHOORU': 'Raifort', 'SAWARO': 'Saguaro', 'SEIJI': 'Salvatore', 'TAIMU': 'Tyme', 'JINIA': 'Jacq',
}
TOURNAMENT = 'Torneio da Academia'
# O rival e o Clavell levam o inicial forte contra o seu.
CHOICE = {'hono': 'Sprigatito', 'kusa': 'Quaxly', 'mizu': 'Fuecoco'}


def enums(buf):
    """Os enums de um esquema FlatBuffers binário (.bfbs): {nome: {valor: número}}."""
    u32 = lambda o: struct.unpack_from('<I', buf, o)[0]

    def field(table, i):
        vt = table - struct.unpack_from('<i', buf, table)[0]
        if 4 + 2 * i >= struct.unpack_from('<H', buf, vt)[0]:
            return None
        off = struct.unpack_from('<H', buf, vt + 4 + 2 * i)[0]
        return table + off if off else None

    def ref(p):
        return p + u32(p)

    def string(p):
        p = ref(p)
        return buf[p + 4:p + 4 + u32(p)].decode()

    def vector(p):
        p = ref(p)
        return [ref(p + 4 + 4 * k) for k in range(u32(p))]

    out = {}
    for e in vector(field(u32(0), 1)):
        vals = {}
        for v in vector(field(e, 1)):
            vp = field(v, 1)
            vals[string(field(v, 0))] = struct.unpack_from('<q', buf, vp)[0] if vp else 0
        out[string(field(e, 0))] = vals
    return out


def national(internal):
    shift = internal - 917
    return internal + INTERNAL_TO_NATIONAL[shift] if 0 <= shift < len(INTERNAL_TO_NATIONAL) else internal


def battle(trid):
    """(classe, legenda) de cada luta dos personagens; None para as que ficam de fora."""
    parts = trid.split('_')
    if trid.startswith('gym_') and '_leader_' in trid:
        return 'Líder de Ginásio', 'Luta no ginásio' if parts[-1] == '01' else TOURNAMENT
    if trid.startswith('e4_'):
        return 'Elite Four', 'Liga Pokémon' if parts[-1] == '01' else TOURNAMENT
    if trid.startswith('chairperson_'):
        return 'Campeão', 'Liga Pokémon' if parts[-1] == '01' else TOURNAMENT
    if trid.startswith('rival_') and parts[-1] in CHOICE and parts[1].isdigit():
        n = int(parts[1])
        label = {7: 'Luta depois da Liga', 8: TOURNAMENT}.get(n, f'Luta {n}')
        return 'Rival', f'{label} (se você escolheu {CHOICE[parts[-1]]})'
    if trid.startswith('clavel_') and parts[-1] in CHOICE:
        label = 'Luta final da Equipe Star' if parts[1] == '01' else TOURNAMENT
        return 'Diretor da Academia', f'{label} (se você escolheu {CHOICE[parts[-1]]})'
    if trid.startswith('dan_') and '_boss_' in trid:
        return 'Chefe da Equipe Star', 'Base da Equipe Star' if parts[-1] == '01' else TOURNAMENT
    if trid in ('botan_01', 'botan_02'):
        return 'Chefe da Equipe Star', 'Luta final da Equipe Star' if trid == 'botan_01' else TOURNAMENT
    if trid in ('pepper_01', 'pepper_02', 'pepper_03'):
        return 'Rival', 'Luta depois da história' if trid == 'pepper_01' else TOURNAMENT
    if trid.startswith('professor_'):
        return 'Professor', 'Área Zero' if parts[-1] == '01' else 'Área Zero (luta final)'
    if trid.split('_')[0] in ('kihada', 'mimoza', 'rehoru', 'sawaro', 'seizi', 'taimu', 'zinia'):
        return 'Professor da Academia', TOURNAMENT
    return None


def build(data, schema, resolve, pokemon):
    e = enums(schema)
    dev, waza = e['pml.common.DevID'], e['pml.common.WazaID']
    seikaku, gem = e['SeikakuType'], e['GemType']
    by_species = {}
    for p in pokemon:
        if not any(k in p['name'] for k in ('-mega', '-gmax', '-totem')):
            by_species.setdefault(p['species'], []).append(p)
    rows = {p['id']: p for p in pokemon}

    def level_moves(pid, level):
        learn = sorted((lv, m) for m, how, lv in rows[pid]['moves'] if how == 'level-up' and lv <= level)
        out = []
        for _, m in learn:
            if m in out:
                continue
            if len(out) == 4:
                out.pop(0)
            out.append(m)
        return out

    out = []
    for t in data['values']:
        kind = battle(t['trid'])
        name = NAMES.get(t['trNameLabel'].removeprefix('TRNAME_'))
        if not kind or not name:
            continue
        team = []
        for k in range(1, 7):
            p = t[f'poke{k}']
            if p['devId'] == 'DEV_NULL':
                continue
            species = national(dev[p['devId']])
            forms = sorted(by_species[species], key=lambda r: (not r['is_default'], r['id']))
            row = forms[p['formId']] if p['formId'] < len(forms) else forms[0]
            if p['wazaType'] == 'MANUAL':
                moves = [resolve('move_id', waza[p[f'waza{i}']['wazaId']]) for i in range(1, 5) if p[f'waza{i}']['wazaId'] != 'WAZA_NULL']
            else:
                moves = level_moves(row['id'], p['level'])
            normal = [a for a, hidden in row['abilities'] if not hidden]
            hidden = [a for a, h in row['abilities'] if h]
            slot = p['tokusei']
            ability = (normal[0] if slot == 'SET_1' else (normal[1:] or normal)[0] if slot == 'SET_2'
                       else (hidden or normal)[0] if slot == 'SET_3' else None)
            options = None if ability else (normal if slot == 'RANDOM_12' else normal + hidden)
            if options and len(options) == 1:
                ability, options = options[0], None
            if p['talentType'] == 'VALUE':
                ivs = {short: p['talentValue'][long] for long, short in STATS}
                iv = ivs['hp'] if len(set(ivs.values())) == 1 else ivs
                iv_note = None
            elif p['talentType'] == 'V_NUM':
                iv, iv_note = None, f'{p["talentVnum"]} em 31, o resto sorteado'
            else:
                iv, iv_note = None, 'sorteados'
            evs = {short: p['effortValue'][long] for long, short in STATS}
            nature = seikaku[p['seikaku']]
            tera = gem[p['gemType']]
            team.append({
                'id': row['id'], 'level': p['level'], 'item': ITEMS[p['item']], 'moves': moves,
                'iv': iv, 'ivNote': iv_note, 'ev': evs['hp'] if len(set(evs.values())) == 1 else evs,
                'nature': NATURES[nature - 1] if nature else None, 'ability': ability, 'abilityOptions': options,
                'tera': TYPES[tera - 2] if tera >= 2 else None, 'shiny': p['rareType'] == 'RARE',
            })
        cls, label = kind
        out.append({'key': t['trid'], 'name': name, 'class': cls, 'label': label, 'team': team})
    # Mesma luta repetida no arquivo (ex.: duas cópias do torneio): fica uma.
    seen, unique = set(), []
    for b in out:
        sig = (b['name'], b['label'], repr(b['team']))
        if sig not in seen:
            seen.add(sig)
            unique.append(b)
    return unique
