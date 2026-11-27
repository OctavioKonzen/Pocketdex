"""Gera docs/mapas.txt: cada região e jogo, cada cidade com a rota até ela (cada rota), os lugares, o ginásio, a Liga,
e tudo o que existe em cada lugar (trocas, presentes, Creche, tutores, museu, Game Corner, loja, Safari, lendários,
clima e efeito de cada lugar, água, chaves, os Pokémon que aparecem pelo terreno) e o cenário usado hoje."""
import json, re, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(ROOT, 'assets', 'database')
d = json.load(open(os.path.join(DB, 'factory.json')))
names = {p['id']: p['name'].replace('-', ' ').title() for p in json.load(open(os.path.join(DB, 'pokemon.json')))}
r = d['routes']; cities = r['cities']; feats = r['features']; sp = d['species']
js = open(os.path.join(ROOT, 'web-site', 'src', 'lib', 'factoryRun.js')).read()
blk = js[js.index('export const PLACE_SCENES = {'):]; blk = blk[:blk.index('\n}\n')]
PS = dict(re.findall(r"'([^']+)': '([^']+)'", blk))
pid = lambda n: re.sub(r'[^a-z0-9]+', '-', n.lower())
ELITE = {'Lorelei': 'ice', 'Agatha': 'ghost', 'Lance': 'dragon'}
TERR = {'grass': 'campo de grama', 'forest': 'floresta', 'water': 'mar/rio', 'beach': 'praia', 'underwater': 'fundo do mar', 'swamp': 'pântano',
        'sewer': 'esgoto/túnel', 'cave': 'caverna', 'icecave': 'caverna de gelo', 'mountain': 'montanha', 'desert': 'deserto', 'volcano': 'vulcão',
        'snow': 'neve', 'city': 'cidade', 'sky': 'céu', 'tower': 'torre', 'ruins': 'ruínas', 'flowers': 'campo de flores', 'plant': 'usina',
        'crystal': 'caverna de cristal', 'dunes': 'dunas', 'bamboo': 'bambuzal', 'temple': 'templo', 'lavacave': 'caverna de lava',
        'poisoncave': 'caverna venenosa', 'seacave': 'caverna do mar', 'waterfall': 'cachoeira', 'lake': 'lago', 'lakeside': 'margem do lago'}
TOWN = {'village': 'vila pequena', 'port': 'porto', 'metro': 'metrópole', 'snow': 'cidade de neve', 'mountain': 'cidade de montanha', 'island': 'ilha',
        'old': 'cidade histórica', 'forest': 'cidade na floresta', 'flower': 'cidade de flores', 'desert': 'cidade do deserto',
        'industrial': 'cidade industrial', 'water': 'cidade sobre a água', 'volcano': 'cidade de vulcão', 'league': 'Liga Pokémon'}
EFF = {'rain': 'chuva', 'sun': 'sol forte', 'sand': 'tempestade de areia', 'snow': 'neve', 'diamonds': 'chuva de diamantes', 'rockfall': 'desmoronamento',
       'ashes': 'cinzas', 'miasma': 'névoa tóxica', 'chill': 'frio', 'aurora': 'aurora', 'haunt': 'aura sombria', 'current': 'correnteza', 'wind': 'ventania',
       'storm': 'tempestade elétrica', 'grassy': 'terreno de grama', 'electric': 'terreno elétrico', 'psychic': 'terreno psíquico', 'misty': 'névoa',
       'fog': 'neblina', 'quicksand': 'areia movediça', 'spores': 'esporos'}
def nm(i):
    if isinstance(i, dict):
        return nm(i['id']) if 'id' in i else ', '.join(f'{k}: {nm(v) if isinstance(v, (int, dict)) else v}' for k, v in i.items())
    if isinstance(i, list):
        return ' / '.join(nm(x) for x in i)
    try:
        return names.get(int(i), f'#{i}')
    except (TypeError, ValueError):
        return str(i)
pretty = lambda s: s.replace('evo:', '').replace('tm:', 'TM ').replace('-', ' ').title()

def ltype(l):
    c = {}
    for i in l.get('team', []):
        s = sp.get(str(i)) or d['formSpecies'].get(str(i))
        for t in (s[4] if s else []): c[t] = c.get(t, 0) + 1
    return max(c, key=c.get) if c else 'normal'

def wild(biome, k=14):
    ids = [int(i) for i, v in sp.items() if biome in (v[6] or []) and v[2] == 0]
    return f'{len(ids)} espécies — ex.: ' + ', '.join(nm(i) for i in ids[:k]) if ids else 'nenhuma espécie própria'

def climate(c):
    out = []
    for place, v in c.items():
        parts = [f'{EFF.get(e, e)} {int(p * 100)}%' for e, p in (v.get('w') or []) + (v.get('f') or [])]
        out.append(f'{"a rota" if place == "route" else place}: ' + ', '.join(parts))
    return out

L = ['MAPAS DO POKELIKE — cada região, cada rota e tudo o que existe em cada lugar', '=' * 78,
     'Formato: ► cidade (tipo) [cenário de hoje]; a rota até ela (cada rota, o terreno, os Pokémon); os lugares; o que tem na cidade.',
     'O cenário entre colchetes é o que o jogo usa hoje (por tipo de lugar). Cada ► precisaria de um cenário próprio para ficar como no jogo.', '']
for g in d['bosses']:
    region, game = g['region'], g['game']
    L += ['', '#' * 78, f'# {region} — {game}', '#' * 78]
    start = (r['start'] or {}).get(region) if isinstance(r['start'], dict) else None
    if start: L.append(f'Começo: {start}')
    seen = []
    for l in g['leaders']:
        if l.get('city') and l['city'] not in seen: seen.append(l['city'])
    for c in seen:
        row = cities.get(f'{region}:{c}') or cities.get(c)
        f = feats.get(f'{region}:{c}') or feats.get(c) or {}
        L += ['', f'► {c} — {TOWN.get(f.get("town"), "cidade")} [town-{f["town"]}]' if f.get('town') else f'► {c} [city]']
        if row:
            L.append(f'  ROTA ATÉ AQUI ({TERR.get(row[0], row[0])}) [{row[0]}]')
            for rt in row[1].split(' · '):
                L.append(f'    • {rt}')
            L.append(f'    Pokémon que vivem nesse terreno (todas as regiões): {wild(row[0])}')
            if row[2]:
                n, s = row[2]
                L.append(f'  ► LUGAR NO CAMINHO: {n} — {TERR.get(s, s)} [{PS.get(pid(n), s)}]')
                L.append(f'    Pokémon que vivem nesse lugar (todas as regiões): {wild(s)}')
            for n, s in (row[3] if len(row) > 3 else []):
                L.append(f'  ► LUGAR DA CIDADE: {n} [{PS.get(pid(n), s)}]')
        info = []
        if f.get('trade'): info.append('Troca do morador: dá ' + ' ou '.join(nm(i) for i in f['trade']))
        for gft in f.get('gifts', []):
            who = ' ou '.join(nm(i) for i in gft['choose']) if gft.get('choose') else nm(gft['id'])
            info.append(f'Presente: {who}' + (' (ovo)' if gft.get('egg') else '') + (f' — depois de {gft["after"]}' if gft.get('after') else ''))
        if f.get('daycare'): info.append('Creche (deixa um Pokémon, volta com ovo)')
        if f.get('tutors'): info.append('Tutores: ' + ', '.join({'deleter': 'Move Deleter', 'reminder': 'Move Reminder'}.get(t, str(t)) for t in f['tutors']))
        for place, ids in (f.get('museum') or {}).items(): info.append(f'Museu ({place}): revive ' + ', '.join(nm(i) for i in ids))
        if f.get('corner'): info.append(f'Game Corner ({f["corner"]["name"]}): prêmios ' + ', '.join(f'{nm(i)} ({p} fichas)' if isinstance(i, int) else f'{pretty(str(i))} ({p})' for i, p in f['corner']['prizes']))
        if f.get('store'): info.append(f'Loja ({f["store"]["name"]}): ' + ', '.join(pretty(x) for x in f['store']['stock']))
        if f.get('safari'): info.append('Safari Zone')
        for place, i in (f.get('legends') or {}).items(): info.append(f'Lendário em {place}: {nm(i)}')
        if f.get('routeLegend'): info.append(f'Lendário dormindo na rota: {nm(f["routeLegend"])}')
        if f.get('water'): info.append(f'Água: {f["water"]}')
        if f.get('fall'): info.append('Cachoeira (Waterfall)')
        if f.get('cycling'): info.append('Ciclovia (Cycling Road)')
        if f.get('arrive'): info.append('Ao chegar ganha: ' + ', '.join(pretty(x) for x in f['arrive']))
        for place, key in (f.get('keys') or {}).items(): info.append(f'Chave: {pretty(key)} (de {place})')
        for place, key in (f.get('needs') or {}).items(): info.append(f'Precisa de {pretty(key)} para entrar em {place}')
        if f.get('blocker'): info.append(f'Bloqueio no caminho: {nm(f["blocker"])}' + (f' (acorda com {pretty(f["blocker"]["item"])})' if isinstance(f['blocker'], dict) and f['blocker'].get('item') else ''))
        for place, item in (f.get('rewards') or {}).items(): info.append(f'Prêmio de {place}: {pretty(item)}')
        for line in climate(f.get('climate') or {}): info.append('Clima/efeito — ' + line)
        if info:
            L.append('  NA CIDADE E ARREDORES:')
            L += [f'    - {x}' for x in info]
        for l in g['leaders']:
            if l.get('city') != c: continue
            k, team = l['kind'], ', '.join(nm(i) for i in l.get('team', []))
            if k == 'gym': L.append(f'  ► GINÁSIO: {l["name"]} (tipo {ltype(l)}) [gym-{ltype(l)}] — time: {team}')
            elif k == 'elite':
                t = ELITE.get(l['name']) or ltype(l); L.append(f'  ► ELITE DOS QUATRO: {l["name"]} (tipo {t}) [elite-{t}] — time: {team}')
            elif k == 'champion': L.append(f'  ► CAMPEÃO: {l["name"]} [champion-{region.lower()}] — time: {team}')
            elif k == 'villain': L.append(f'  ► VILÃO: {l["name"]} [base da equipe] — time: {team}')
            elif k == 'rival': L.append(f'    Rival {l["name"]} na rota — time: {team}')
open(os.path.join(ROOT, 'docs', 'mapas.txt'), 'w').write('\n'.join(L) + '\n')
print(len(L))
