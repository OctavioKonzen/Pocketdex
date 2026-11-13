#!/usr/bin/env python3
"""Animações no estilo Black & White feitas por fãs, para quem não tem a do
Showdown (gen5ani) e estava com a arte BW parada.

Fonte: Animated sprites by Ghasty001 (github.com/Ghasty001/Animated_sprites_by_Ghasty001),
livres para usar com crédito (Ghasty001 e os artistas das bases, listados no
README de lá e no nosso README). Só troca o GIF quando o nosso está parado (um
quadro só): nunca troca uma animação BW que já existe.

Rode depois de tool/bw_style_sprites.py (que refaz os parados) e antes de
tool/fetch_animated_sprites.py (que refaz animated_sprites.json); no fim este
script já chama o fetch.

Uso:
  git clone --depth 1 https://github.com/Ghasty001/Animated_sprites_by_Ghasty001 /tmp/ghasty
  python3 tool/fan_sprites.py /tmp/ghasty
"""

import json
import os
import re
import subprocess
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bw_style_sprites import DB, OUT, ROOT, crop_gif  # noqa: E402

FOLDERS = {'FRONT': 'front', 'FRONT_SHINY': 'shiny', 'BACK': 'back', 'BACK_SHINY': 'back-shiny'}

# Nome do arquivo de lá → slug do nosso banco (o resto é o nome em minúsculas
# e "_Mega" vira "-mega").
SLUGS = {
    'ABSOL_Mega': 'absol-mega-z',  # a Mega Absol Z
    'AVALUGG_1': 'avalugg-hisui',
    'BRAVIARY': 'braviary-hisui',
    'QWILFISH_1': 'qwilfish-hisui',
    'SLIGGOO_1': 'sliggoo-hisui',
    'SNEASEL-m': 'sneasel-hisui',
    'SNEASEL-f': None,  # a fêmea: no banco só tem uma forma
    'ORICORIO': 'oricorio-baile',
    'ROTOM_dj': None,  # forma que não existe nos jogos
    'VICTREBELL_mega': 'victreebel-mega',
    'MEGANIUM_1': 'meganium-mega',  # o shiny da Mega Meganium
}


def slug_of(name):
    # "BRAMBLIN back shiny" (o nome da pasta já diz se é costas/shiny).
    name = re.sub(r'( back)?( shiny)?$', '', name)
    if name in SLUGS:
        return SLUGS[name]
    return re.sub(r'_mega$', '-mega', name.lower())


def is_still(path):
    return getattr(Image.open(path), 'n_frames', 1) == 1


def main():
    repo = sys.argv[1] if len(sys.argv) > 1 else '/tmp/ghasty'
    with open(os.path.join(DB, 'pokemon.json'), encoding='utf-8') as f:
        ids = {p['name']: p['id'] for p in json.load(f)}
    counts = {'trocado': 0, 'já animado': 0, 'fora do banco': 0}
    for folder, kind in FOLDERS.items():
        for file in sorted(os.listdir(os.path.join(repo, folder))):
            if not file.lower().endswith('.gif'):
                continue
            slug = slug_of(file[:-4])
            pid = ids.get(slug) if slug else None
            if pid is None:
                counts['fora do banco'] += 1
                continue
            out = os.path.join(OUT, kind, f'{pid}.gif')
            if os.path.exists(out) and not is_still(out):
                counts['já animado'] += 1
                continue
            crop_gif(os.path.join(repo, folder, file), out)
            counts['trocado'] += 1
    print('animações de fãs:', counts)
    subprocess.run([sys.executable, os.path.join(ROOT, 'tool', 'fetch_animated_sprites.py')], check=True)


if __name__ == '__main__':
    main()
