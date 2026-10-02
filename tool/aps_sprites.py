#!/usr/bin/env python3
"""Animações no estilo Black & White do pacote "Animated Pokemon System" (plugin
do Pokémon Essentials, por Lucidious89), para quem ainda está com a arte BW
parada (Megas novas, formas e Pokémon da 6ª à 9ª geração).

O pacote junta as animações da comunidade (o plugin espanhol "Sprites Animados"
e outros; créditos no README de lá e no nosso README). Cada sprite é uma tira
PNG com os quadros lado a lado (quadrados); aqui vira GIF, recortado justo.
Só troca o GIF quando o nosso está parado (um quadro só): nunca troca uma
animação que já existe.

Os nomes seguem o Essentials: "VENUSAUR_1.png" é a forma 1 do Venusaur; o nome
de cada forma vem do pokemon_forms.txt do Essentials e é casado com o nosso
banco pelas palavras ("Mega Tatsugiri (Droopy Form)" → tatsugiri-droopy-mega).
A velocidade de cada um vem dos pokemon_metrics*.txt do plugin.

Rode depois de tool/bw_style_sprites.py e tool/fan_sprites.py; no fim este
script já chama tool/fetch_animated_sprites.py.

Uso (os arquivos do pacote ficam no MediaFire, link na página do plugin no
eeveeexpo.com/resources/1544):
  unzip Animated_Pokemon_Sprites.zip -d /tmp/aps
  unzip Animated_Pokemon_System.zip -d /tmp/aps-plugin
  curl -o /tmp/pokemon_forms.txt https://raw.githubusercontent.com/Maruno17/pokemon-essentials/dev/PBS/pokemon_forms.txt
  curl -o /tmp/pokemon.txt https://raw.githubusercontent.com/Maruno17/pokemon-essentials/dev/PBS/pokemon.txt
  python3 tool/aps_sprites.py "/tmp/aps/Animated Pokemon Sprites/Graphics/Pokemon" /tmp/aps-plugin/PBS /tmp/pokemon_forms.txt /tmp/pokemon.txt

Os Gigantamax (e o Eternamax) vêm do plugin "Dynamax" do mesmo autor
(eeveeexpo.com/resources/1495), com as formas dele:
  unzip Dynamax.zip -d /tmp/dynamax
  python3 tool/aps_sprites.py /tmp/dynamax/Graphics/Pokemon /tmp/dynamax/PBS /tmp/dynamax/PBS/pokemon_forms_gmax.txt

Com --todos, usa a animação do pacote em todos que têm (não só nos parados).
"""

import glob
import json
import os
import re
import subprocess
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bw_style_sprites import DB, OUT, ROOT  # noqa: E402

FOLDERS = {'Front': 'front', 'Front shiny': 'shiny', 'Back': 'back', 'Back shiny': 'back-shiny'}

# Atraso de cada quadro no plugin: (velocidade / 2) * ANIMATION_FRAME_DELAY (90 ms).
FRAME_DELAY = 90

# Palavras que não dizem qual é a forma.
NOISE = {'form', 'forme', 'mode', 'style', 'size', 'the', 'of', 'pokemon'}
SYNONYMS = {'alolan': 'alola', 'galarian': 'galar', 'hisuian': 'hisui', 'paldean': 'paldea', 'gigantamax': 'gmax'}

# Os que o nome não resolve sozinho: arquivo de lá → slugs nossos. Os tamanhos
# de Pumpkaboo/Gourgeist usam o mesmo desenho (igual ao Showdown).
EXTRA = {
    'MEOWSTIC_2': ['meowstic-male-mega'],
    'MEOWSTIC_3': ['meowstic-female-mega'],
    'PUMPKABOO': ['pumpkaboo-average', 'pumpkaboo-large', 'pumpkaboo-super'],
    'GOURGEIST': ['gourgeist-average', 'gourgeist-large', 'gourgeist-super'],
    'TOXTRICITY_2': ['toxtricity-amped-gmax', 'toxtricity-low-key-gmax'],
    'GENESECT': ['genesect'],
    'UNOWN_26': ['201-exclamation'],
    'UNOWN_27': ['201-question'],
    'SINISTEA_1': ['854-antique'],
    'POLTEAGEIST_1': ['855-antique'],
    'POLTCHAGEIST_1': ['1012-artisan'],
    'SINISTCHA_1': ['1013-masterpiece'],
}


def words(text):
    text = text.lower().replace('%', '').replace('é', 'e')
    return {SYNONYMS.get(w, w) for w in re.findall(r'[a-z0-9]+', text)} - NOISE


def essentials_id(name):
    """"mr-mime" → "MRMIME" (o id do Essentials)."""
    return re.sub('[^A-Z0-9]', '', name.upper())


def read_forms(path):
    """{(ESPÉCIE, n): nome da forma} do pokemon_forms.txt."""
    out, key = {}, None
    with open(path, encoding='utf-8-sig') as f:
        for line in f:
            m = re.match(r'\[([A-Z0-9_]+),(\d+)\]', line)
            if m:
                key = (m.group(1), int(m.group(2)))
            elif key and line.startswith('FormName'):
                out[key] = line.split('=', 1)[1].strip()
    return out


def read_speeds(pbs):
    """{"ESPÉCIE" ou "ESPÉCIE_n" ou "ESPÉCIE_female": (costas, frente)}."""
    out = {}
    for path in sorted(glob.glob(os.path.join(pbs, 'pokemon_metrics*.txt'))):
        female = 'female' in os.path.basename(path)
        key = None
        with open(path, encoding='utf-8-sig') as f:
            for line in f:
                m = re.match(r'\[([A-Z0-9_]+)(?:,(\d+))?\]', line)
                if m:
                    key = m.group(1) + (f'_{m.group(2)}' if m.group(2) else '') + ('_female' if female else '')
                elif key and line.startswith('AnimationSpeed'):
                    v = [int(x) for x in line.split('=', 1)[1].split(',')]
                    out[key] = (v[0], v[1] if len(v) > 1 else v[0])
    return out


# Alcremie no Essentials: forma = creme * 7 + doce.
CREAMS = ['vanilla-cream', 'ruby-cream', 'matcha-cream', 'mint-cream', 'lemon-cream', 'salted-cream', 'ruby-swirl', 'caramel-swirl', 'rainbow-swirl']
SWEETS = ['strawberry', 'berry', 'love', 'star', 'clover', 'flower', 'ribbon']


def read_defaults(path):
    """{ESPÉCIE: nome da forma 0} do pokemon.txt do Essentials (só de quem tem formas)."""
    out, key = {}, None
    with open(path, encoding='utf-8-sig') as f:
        for line in f:
            m = re.match(r'\[([A-Z0-9_]+)\]', line)
            if m:
                key = m.group(1)
            elif key and line.startswith('FormName'):
                out[key] = line.split('=', 1)[1].strip()
    return out


def build_map(forms, defaults=None):
    """Nome do arquivo (sem .png) → alvos do nosso banco: o id (int) de um
    Pokémon ou a chave (str, "666-polar") de uma forma só de aparência
    (Vivillon, Unown, Alcremie...), que tem o GIF com esse nome."""
    defaults = defaults or {}
    with open(os.path.join(DB, 'pokemon.json'), encoding='utf-8') as f:
        pokemon = json.load(f)
    with open(os.path.join(DB, 'species.json'), encoding='utf-8') as f:
        species = {s['id']: s['name'] for s in json.load(f)}
    with open(os.path.join(DB, 'forms.json'), encoding='utf-8') as f:
        cosmetic = json.load(f)
    pid_species = {p['id']: p['species'] for p in pokemon}
    by_species = {}
    for p in pokemon:
        by_species.setdefault(p['species'], []).append(p)
    # Candidatos de cada espécie: (alvo, palavras da forma).
    cands = {}
    own = {}  # forma de aparência padrão ("666-meadow") → o Pokémon (666)
    for sid, sname in species.items():
        base = set(re.findall(r'[a-z0-9]+', sname))
        cands[sid] = [(p['id'], set(re.findall(r'[a-z0-9]+', p['name'])) - base - NOISE) for p in by_species.get(sid, [])]
    for x in cosmetic:
        sid = pid_species.get(x['pokemon'])
        if sid is None:
            continue
        base = set(re.findall(r'[a-z0-9]+', species[sid]))
        w = set(re.findall(r'[a-z0-9]+', x['name'])) - base - NOISE
        m = re.match(r'pokemon/(\d+-[\w-]+)\.png$', (x['sprites'] or [''])[0] or '')
        if m:
            cands[sid].append((m.group(1), w))
            if x['is_default']:
                own[m.group(1)] = x['pokemon']
        elif x['is_default'] and w:
            # A forma padrão com nome (vivillon-meadow): é o próprio Pokémon.
            cands[sid].append((x['pokemon'], w))

    def pick(sid, label):
        want = words(label) - set(re.findall(r'[a-z0-9]+', species[sid]))
        # O candidato cujas palavras estão todas no nome da forma de lá (o com
        # mais palavras; empate ou sobrando mais de uma palavra lá = não sabe).
        fits = {}
        for target, w in cands[sid]:
            if w and w <= want:
                fits.setdefault(target, len(w))
        if not fits:
            return None
        top = max(fits.values())
        best = [t for t, k in fits.items() if k == top]
        return best[0] if len(best) == 1 and len(want) <= top + 1 else None

    out = {}
    for sid, sname in species.items():
        eid = essentials_id(sname)
        group = by_species.get(sid, [])
        default = next((p for p in group if p['is_default']), None)
        # Forma 0: o padrão daqui, a não ser que lá o padrão seja outra forma
        # (o Vivillon de lá é o Archipelago; o daqui, o Meadow).
        has_cosmetic = any(isinstance(t, str) for t, _ in cands[sid])
        if eid in defaults:
            target = pick(sid, defaults[eid])
            if target is not None:
                out[eid] = target
            elif default and not has_cosmetic:
                out[eid] = default['id']
        elif default:
            out[eid] = default['id']
        female = next((t for t, w in cands[sid] if w == {'female'}), None)
        if female is not None:
            out[f'{eid}_female'] = female
        for (sp, n), label in forms.items():
            if sp == eid:
                target = pick(sid, label)
                if target is not None:
                    out[f'{eid}_{n}'] = target
    ids = {p['name']: p['id'] for p in pokemon}
    # A forma de aparência padrão é também o próprio Pokémon.
    out = {k: [v] + ([own[v]] if v in own else []) for k, v in out.items()}
    for key, slugs in EXTRA.items():
        # "201-question": forma de aparência (o GIF tem esse nome).
        out.setdefault(key, []).extend(s if re.match(r'\d+-', s) else ids[s] for s in slugs if s in ids or re.match(r'\d+-', s))
    for c, cream in enumerate(CREAMS):
        for k, sweet in enumerate(SWEETS):
            n = c * 7 + k
            out[f'ALCREMIE_{n}' if n else 'ALCREMIE'] = [f'869-{cream}-{sweet}-sweet'] + ([869] if n == 0 else [])
    return {k: list(dict.fromkeys(v)) for k, v in out.items()}


def is_still(path):
    return getattr(Image.open(path), 'n_frames', 1) == 1


def frames_of(path):
    """Os quadros da tira (alfa só 0 ou 255, como num GIF), ou [] se não mexe."""
    im = Image.open(path).convert('RGBA')
    side = im.height
    count = im.width // side
    frames = []
    for i in range(count):
        f = im.crop((i * side, 0, i * side + side, side))
        a = f.getchannel('A').point(lambda v: 255 if v >= 128 else 0)
        f.putalpha(a)
        frames.append(f)
    if len({f.tobytes() for f in frames}) < 2:
        return []
    return frames


def save_gif(frames, delay, path):
    box = None
    for f in frames:
        b = f.getchannel('A').getbbox()
        if b:
            box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
    if box is None:
        return False
    frames = [f.crop(box) for f in frames]
    os.makedirs(os.path.dirname(path), exist_ok=True)
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=delay, loop=0, disposal=2, optimize=False)
    return True


def main():
    root, pbs, forms_txt = sys.argv[1:4]
    # Opcional: o pokemon.txt do Essentials (nome da forma 0 de cada espécie).
    species_txt = next((a for a in sys.argv[4:] if not a.startswith('--')), None)
    # --todos: usa a animação daqui em todos que têm (troca também as que já
    # eram animadas, do Showdown ou de fãs); sem ele, só os parados.
    todos = '--todos' in sys.argv
    names = build_map(read_forms(forms_txt), read_defaults(species_txt) if species_txt else None)
    speeds = read_speeds(pbs)
    counts = {'trocado': 0, 'já animado': 0, 'fora do banco': 0, 'parado lá também': 0}
    for folder, kind in FOLDERS.items():
        for file in sorted(os.listdir(os.path.join(root, folder))):
            if not file.endswith('.png'):
                continue
            key = file[:-4]
            if key not in names:
                counts['fora do banco'] += 1
                continue
            for pid in names[key]:
                out = os.path.join(OUT, kind, f'{pid}.gif')
                if not todos and os.path.exists(out) and not is_still(out):
                    counts['já animado'] += 1
                    continue
                back, front = speeds.get(key) or speeds.get(key.split('_')[0]) or (2, 2)
                speed = back if kind.startswith('back') else front
                frames = frames_of(os.path.join(root, folder, file)) if speed else []
                if not frames:
                    counts['parado lá também'] += 1
                    continue
                if save_gif(frames, max(20, round(speed / 2 * FRAME_DELAY)), out):
                    counts['trocado'] += 1
    print('Animated Pokemon System:', counts)
    subprocess.run([sys.executable, os.path.join(ROOT, 'tool', 'fetch_animated_sprites.py')], check=True)


if __name__ == '__main__':
    main()
