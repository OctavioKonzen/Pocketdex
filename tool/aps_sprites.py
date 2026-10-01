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
  python3 tool/aps_sprites.py "/tmp/aps/Animated Pokemon Sprites/Graphics/Pokemon" /tmp/aps-plugin/PBS /tmp/pokemon_forms.txt

Os Gigantamax (e o Eternamax) vêm do plugin "Dynamax" do mesmo autor
(eeveeexpo.com/resources/1495), com as formas dele:
  unzip Dynamax.zip -d /tmp/dynamax
  python3 tool/aps_sprites.py /tmp/dynamax/Graphics/Pokemon /tmp/dynamax/PBS /tmp/dynamax/PBS/pokemon_forms_gmax.txt
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
    'PUMPKABOO': ['pumpkaboo-small', 'pumpkaboo-large', 'pumpkaboo-super'],
    'GOURGEIST': ['gourgeist-small', 'gourgeist-large', 'gourgeist-super'],
    'TOXTRICITY_2': ['toxtricity-amped-gmax', 'toxtricity-low-key-gmax'],
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


def build_map(forms):
    """Nome do arquivo (sem .png) → ids do nosso banco."""
    with open(os.path.join(DB, 'pokemon.json'), encoding='utf-8') as f:
        pokemon = json.load(f)
    with open(os.path.join(DB, 'species.json'), encoding='utf-8') as f:
        species = {s['id']: s['name'] for s in json.load(f)}
    by_species = {}
    for p in pokemon:
        by_species.setdefault(p['species'], []).append(p)
    out = {}
    for sid, sname in species.items():
        eid = essentials_id(sname)
        group = by_species.get(sid, [])
        default = next((p for p in group if p['is_default']), None)
        if default:
            out[eid] = default['id']
        base = set(re.findall(r'[a-z0-9]+', sname))
        others = [(p, set(re.findall(r'[a-z0-9]+', p['name'])) - base - NOISE) for p in group if not p['is_default']]
        female = next((p for p, w in others if w == {'female'}), None)
        if female:
            out[f'{eid}_female'] = female['id']
        for (sp, n), label in forms.items():
            if sp != eid:
                continue
            want = words(label) - base
            # A forma nossa cujas palavras estão todas no nome da forma de lá
            # (a com mais palavras; empate ou sobrando mais de uma palavra lá =
            # não sabe, fica sem).
            fits = [(len(w), p['id']) for p, w in others if w and w <= want]
            best = max(fits, default=None)
            if best and sum(1 for k, _ in fits if k == best[0]) == 1 and len(want) <= best[0] + 1:
                out[f'{eid}_{n}'] = best[1]
    ids = {p['name']: p['id'] for p in pokemon}
    out = {k: [v] for k, v in out.items()}
    for key, slugs in EXTRA.items():
        out.setdefault(key, []).extend(ids[s] for s in slugs if s in ids)
    return out


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
    names = build_map(read_forms(forms_txt))
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
                if os.path.exists(out) and not is_still(out):
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
