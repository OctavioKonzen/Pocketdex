"""Acrescenta os treinadores do Pokémon Showdown (80 × 80, estilo BW) no fim
de assets/database/trainers.json.

Só as versões padrão (sem -gen1…, -masters etc.). Sprites © Nintendo/Game
Freak e os artistas creditados pelo Showdown (play.pokemonshowdown.com/credits);
uso sem fins lucrativos, com os créditos no README. A ordem da lista é a
posição salva no avatar: os novos entram no fim e os que já estão não mudam.

Uso:
    mkdir -p /tmp/sd && cd /tmp/sd
    curl -s https://play.pokemonshowdown.com/sprites/trainers/ | grep -o 'href="[^"]*\\.png"' \\
      | sed 's/href="//;s/\\.png"//' > names.txt
    grep -v -- '-gen\\|masters\\|-lgpe\\|-conquest\\|-pokestar\\|-dojo' names.txt \\
      | xargs -P 16 -I{} curl -s -f -o {}.png https://play.pokemonshowdown.com/sprites/trainers/{}.png
    python3 tool/build_showdown_trainers.py /tmp/sd
"""

import json
import os
import re
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'database', 'sprites', 'trainers')
LIST = os.path.join(ROOT, 'assets', 'database', 'trainers.json')
SKIP = re.compile(r'-gen|masters|-lgpe|-conquest|-pokestar|-dojo')


def label(name):
    """'acetrainerf-gen' → 'Acetrainerf'; 'leon-tower' → 'Leon (tower)'."""
    base, *rest = name.split('-')
    out = base[:1].upper() + base[1:]
    return f'{out} ({" ".join(rest)})' if rest else out


def main(src):
    with open(LIST, encoding='utf-8') as f:
        listing = json.load(f)
    known = {t['id'] for t in listing}
    added = 0
    for file in sorted(os.listdir(src)):
        name, ext = os.path.splitext(file)
        if ext != '.png' or SKIP.search(name):
            continue
        tid = f'sd-{name}'
        if tid in known:
            continue
        im = Image.open(os.path.join(src, file)).convert('RGBA')
        if im.size != (80, 80):
            continue
        im.save(os.path.join(OUT, f'{tid}.png'), optimize=True)
        listing.append({'id': tid, 'name': label(name), 'title': 'Pokémon Showdown', 'size': 80, 'frames': 1})
        added += 1
    with open(LIST, 'w', encoding='utf-8') as f:
        json.dump(listing, f, ensure_ascii=False, separators=(',', ':'))
        f.write('\n')
    print(added, 'treinadores novos;', len(listing), 'no total')


if __name__ == '__main__':
    main(sys.argv[1])
