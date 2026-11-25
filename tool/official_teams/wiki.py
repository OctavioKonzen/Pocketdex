"""Times dos personagens dos jogos sem desmontagem aberta, a partir dos dados de
treinadores do Trevenant (github.com/zacharybussey/Trevenant, MIT), que vêm
do VanillaNuzlockeCalc (Honko e colaboradores, tirados dos jogos pela
comunidade). Mesmo formato dos outros jogos; aqui os valores vêm prontos
(nível, golpes, item, habilidade, nature, IVs e EVs) e são marcados como
"dados da comunidade" na tela.

Arquivo de cada jogo: src/data/trainers/<Jogo>.json.
"""

import re

STARTERS = {'Chikorita', 'Cyndaquil', 'Totodile', 'Treecko', 'Torchic', 'Mudkip', 'Turtwig', 'Chimchar', 'Piplup', 'Snivy', 'Tepig',
            'Oshawott', 'Chespin', 'Fennekin', 'Froakie', 'Rowlet', 'Rowlett', 'Litten', 'Popplio', 'Grookey', 'Scorbunny', 'Sobble'}
BY_CLASS = {'Leader': 'Líder de Ginásio', 'Gym Leader': 'Líder de Ginásio', 'Elite Four': 'Elite Four', 'Champion': 'Campeão',
            'Admin': 'Equipe Skull'}
PLACES = {
    'VR': 'Victory Road', 'BR': 'Battle Royal', 'Mt Moon': 'Mt. Moon', 'Mt Chimney': 'Mt. Chimney', 'Mt Pyre': 'Mt. Pyre',
    'Pokemon League': 'Liga Pokémon', 'Postgame': 'Depois da Liga', 'Post Game': 'Depois da Liga', 'Post Champ': 'Depois da Liga',
    'Rematch': 'Revanche', 'Champion': 'Luta pelo título', 'Pearl/Diamond': '', 'TGEB': 'Galactic Eterna Building',
    'TCHQ': 'Galactic HQ', 'TRHQ': 'Rocket Hideout', 'TRHQ Double': 'Rocket Hideout (dupla)', 'RT': 'Radio Tower',
    'RT 4F': 'Radio Tower 4F', 'Double': 'Batalha dupla', 'Hearthome CIty': 'Hearthome City', 'Paniola Town': 'Paniola Town',
    'Panolia Town': 'Paniola Town',
}

# Jogo -> (arquivo, {nome: classe}, nome do rival "#", nomes trocados)
GAMES = {
    'diamond-pearl': ('Diamond_Pearl', {
        'Barry': 'Rival', 'Cyrus': 'Chefe da Equipe Galáctica', 'Mars': 'Comandante da Equipe Galáctica',
        'Jupiter': 'Comandante da Equipe Galáctica', 'Saturn': 'Comandante da Equipe Galáctica'}, None, {}),
    'heartgold-soulsilver': ('HeartGold_SoulSilver', {
        'Archer': 'Executivo da Equipe Rocket', 'Ariana': 'Executivo da Equipe Rocket', 'Petrel': 'Executivo da Equipe Rocket',
        'Proton': 'Executivo da Equipe Rocket', 'Eusine': 'Treinador Pokémon'}, 'Silver', {'Surge': 'Lt. Surge'}),
    'black-white': ('Black_White', {
        'Cheren': 'Rival', 'Bianca': 'Rival', 'N': 'Rei da Equipe Plasma', 'Ghetsis': 'Chefe da Equipe Plasma', 'Alder': 'Campeão',
        'Caitlin': 'Elite Four', 'Grimsley': 'Elite Four', 'Marshal': 'Elite Four', 'Shauntal': 'Elite Four'}, None, {}),
    'x-y': ('X_Y', {
        'Shauna': 'Rival', 'Calem': 'Rival', 'Serena': 'Rival', 'Tierno': 'Rival', 'Trevor': 'Rival',
        'Lysandre': 'Chefe da Equipe Flare', 'Aliana': 'Equipe Flare', 'Celosia': 'Equipe Flare', 'Bryony': 'Equipe Flare',
        'Mable': 'Equipe Flare', 'Xerosic': 'Equipe Flare', 'AZ': 'Treinador Pokémon'}, None, {'Bryoyn': 'Bryony'}),
    'omegaruby-alphasapphire': ('OmegaRuby_AlphaSapphire', {
        'Wally': 'Rival', 'Maxie': 'Chefe da Equipe Magma', 'Archie': 'Chefe da Equipe Aqua', 'Courtney': 'Equipe Magma',
        'Tabitha': 'Equipe Magma', 'Matt': 'Equipe Aqua', 'Shelly': 'Equipe Aqua'}, 'Brendan/May', {'Watson': 'Wattson'}),
    'sun-moon': ('Sun_Moon', {
        'Hau': 'Rival', 'Gladion': 'Rival', 'Guzma': 'Chefe da Equipe Skull', 'Plumeria': 'Equipe Skull',
        'Lusamine': 'Fundação Aether', 'Faba': 'Fundação Aether', 'Kukui': 'Professor', 'Red': 'Treinador Pokémon',
        'Blue': 'Treinador Pokémon', 'Dexio': 'Treinador Pokémon', 'Sina': 'Treinador Pokémon', 'Molayne': 'Capitão',
        'Ryuki': 'Treinador Pokémon', 'Anabel': 'Treinador Pokémon'}, None, {}),
    'ultrasun-ultramoon': ('UltraSun_UltraMoon', {
        'Hau': 'Rival', 'Gladion': 'Rival', 'Guzma': 'Chefe da Equipe Skull', 'Plumeria': 'Equipe Skull',
        'Lusamine': 'Fundação Aether', 'Faba': 'Fundação Aether', 'Red': 'Treinador Pokémon', 'Blue': 'Treinador Pokémon',
        'Dexio': 'Treinador Pokémon', 'Sina': 'Treinador Pokémon', 'Ryuki': 'Treinador Pokémon', 'Lillie': 'Treinador Pokémon',
        'Dulse': 'Ultra Recon Squad', 'Soliera': 'Ultra Recon Squad', 'Cyrus': 'Equipe Rainbow Rocket',
        'Ghetsis': 'Equipe Rainbow Rocket', 'Lysandre': 'Equipe Rainbow Rocket', 'Maxie': 'Equipe Rainbow Rocket'}, None, {}),
    'sword-shield': ('Sword_Shield', {
        'Hop': 'Rival', 'Bede': 'Rival', 'Marnie': 'Rival', 'Leon': 'Campeão', 'Sordward': 'Treinador Pokémon',
        'Shielbert': 'Treinador Pokémon'}, None, {}),
    'brilliantdiamond-shiningpearl': ('BrilliantDiamond_ShiningPearl', {
        'Cyrus': 'Chefe da Equipe Galáctica'}, 'Barry', {}),
}
# Prefixos do nome que viram a classe.
PREFIXES = [('Island Kahuna ', 'Kahuna'), ('Captain ', 'Capitão'), ('Postgame Rival', 'Rival')]
SKIP_WORDS = ('&', ',', 'PARTNER', 'Partner', 'Totem', 'Trial', '???', 'Employee', 'Grunt', 'Double', 'Lucas', 'Dawn')


def slug(text):
    return re.sub(r'[^a-z0-9]+', '-', text.lower().replace('’', "'").replace("'", '').replace('.', '')).strip('-')


def parse(entry, people, rival, rename):
    """(classe, nome, número, inicial escolhido, local) ou None se não é um personagem."""
    cls, raw, where = entry['trainerClass'], entry['trainerName'].strip(), entry['location'].strip()
    if any(w in raw for w in SKIP_WORDS) or raw in ('!',) or cls in ('Team Galactic', 'Café Master'):
        return None
    starter = None
    m = re.search(r'\((\w+)\)', raw)
    if m and m.group(1) in STARTERS:
        starter = m.group(1)
    raw = re.sub(r'\s*\(.*?\)', '', raw).strip()
    if where in STARTERS:
        starter, where = where, ''
    label_extra = ''
    for prefix, pcls in PREFIXES:
        if raw.startswith(prefix):
            raw, cls = raw[len(prefix):].strip(), pcls
            if pcls == 'Rival':
                label_extra = 'Depois da Liga'
    if raw.endswith(' Champ'):
        raw, label_extra = raw[:-6], 'Luta pelo título'
    number = None
    m = re.match(r'^(.*?)\s*#?(\d+)$', raw)
    if m:
        raw, number = m.group(1).strip(), int(m.group(2))
    if cls == 'Rival' and raw in ('', '#') or raw == '#':
        if cls in ('Sordward', 'Shielbert'):
            raw = cls
        elif rival:
            raw = rival
        else:
            return None
    name = rename.get(raw, raw)
    if cls in BY_CLASS:
        out_cls = BY_CLASS[cls]
    elif cls in ('Kahuna', 'Capitão', 'Rival'):
        out_cls = cls
    elif name in people:
        out_cls = people[name]
    else:
        return None
    if starter == 'Rowlett':
        starter = 'Rowlet'
    where = PLACES.get(where, re.sub(r'^R(\d+)$', r'Route \1', where))
    return out_cls, name, number, starter, where, label_extra


def build(data, resolve, gid):
    file, people, rival, rename = GAMES[gid]
    people = {**people, **{rename.get(k, k): v for k, v in people.items()}}
    out, seen = [], set()
    for e in data['encounters']:
        info = parse(e, people, rival, rename)
        if not info:
            continue
        cls, name, number, starter, where, extra = info
        team = []
        for p in e['team']:
            sid = resolve('species_name', p['species'])
            if not sid:
                continue
            ivs, evs = p['ivs'], p['evs']
            team.append({
                'id': sid, 'level': p['level'], 'item': resolve('item_name', p['item']) if p['item'] else None,
                'moves': [m for m in (resolve('move_name', mv) for mv in p['moves'] if mv and mv != 'No Move') if m],
                'iv': ivs['hp'] if len(set(ivs.values())) == 1 else ivs, 'ev': evs['hp'] if len(set(evs.values())) == 1 else evs,
                'nature': p['nature'] or None, 'ability': resolve('ability_name', p['ability']) if p['ability'] else None,
            })
        if not team:
            continue
        sig = (cls, name, repr(team))
        if sig in seen:
            continue
        seen.add(sig)
        label = extra or where or (f'Luta {number}' if number else 'Luta')
        if starter:
            label = f'{label} (se você escolheu {starter})'
        out.append({'key': e['id'], 'name': name, 'class': cls, 'label': label or 'Luta', 'number': number or 0, 'team': team})
    # Mesma legenda mais de uma vez para a mesma pessoa: numera (Luta 1, Luta 2...; Ultra Space (2)...).
    count, seen_labels = {}, {}
    for b in out:
        count[(b['class'], b['name'], b['label'])] = count.get((b['class'], b['name'], b['label']), 0) + 1
    for b in out:
        key = (b['class'], b['name'], b['label'])
        if count[key] > 1:
            seen_labels[key] = seen_labels.get(key, 0) + 1
            n = seen_labels[key]
            b['label'] = f'Luta {n}' if b['label'] == 'Luta' else f'{b["label"]} ({n})'
        b.pop('number')
    return out
