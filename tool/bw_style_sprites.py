#!/usr/bin/env python3
"""Deixa todos os sprites animados no mesmo estilo do Black & White.

Do #650 em diante o Pokémon Showdown só tem animação no estilo BW para parte
da 6ª/7ª geração; o resto (8ª/9ª, Megas, formas novas) são renderizações 3D
(maiores e com centenas de cores), ou nem existem. Para esses usamos a arte
BW parada do Smogon Sprite Project (repositório smogon/sprites, pasta
src/sprites/gen5) e geramos uma animação de "respiração" (o Pokémon estica e
encolhe 1–2 pixels, apoiado no chão). Quem não tem arte BW na Smogon usa o
sprite parado do nosso banco (96x96, também em pixel).

Rode depois de tool/fetch_animated_sprites.py (que baixa o que falta e gera
animated_sprites.json); este script regrava os GIFs e roda o fetch de novo só
para recalcular a lista e os ajustes de tamanho.

Uso:
  GIT_LFS_SKIP_SMUDGE=1 git clone --depth 1 --filter=blob:none --no-checkout \\
      https://github.com/smogon/sprites /tmp/smogon-sprites
  python3 tool/bw_style_sprites.py /tmp/smogon-sprites
"""

import json
import os
import re
import subprocess
import sys

from PIL import Image, ImageFile

ImageFile.LOAD_TRUNCATED_IMAGES = True

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(ROOT, 'assets', 'database')
OUT = os.path.join(DB, 'sprites', 'animated')
STATIC = os.path.join(DB, 'sprites', 'pokemon')

# Sprite BW de verdade: até 96 px e paleta de 16 cores (alguns feitos pela
# comunidade passam um pouco disso).
BW_MAX_SIDE = 96
BW_MAX_COLORS = 20

# Quanto o Pokémon estica (em pixels, de cima) em cada quadro da respiração.
BREATH = [0, 0, 0, 1, 1, 2, 2, 2, 1, 1, 0, 0]
FRAME_MS = 90


def smogon_index(repo):
    """slug da PokeAPI → {'front': caminho, 'shiny': caminho} dos PNG/GIF BW."""
    files = subprocess.run(
        ['git', '-C', repo, 'ls-tree', '-r', '--name-only', 'HEAD', 'src/sprites/gen5/'],
        capture_output=True, text=True, check=True,
    ).stdout.split()
    index = {}
    for f in files:
        name = f[len('src/sprites/gen5/'):]
        if '/' in name:
            continue
        m = re.match(r'^s([a-z0-9_]+)((?:-o[a-z0-9_]+)?)((?:-[a-z]+)*)\.(gif|png)$', name)
        if not m:
            continue
        flags = set(m.group(3).split('-')) - {''}
        if flags - {'s'}:  # costas, fêmea, jogo específico...
            continue
        slug = (m.group(1) + ('-' + m.group(2)[2:] if m.group(2) else '')).replace('_', '-')
        kind = 'shiny' if 's' in flags else 'front'
        index.setdefault(slug, {})[kind] = f
    return index


def is_bw(path):
    im = Image.open(path)
    if max(im.size) > BW_MAX_SIDE:
        return False
    colors = {p for p in im.convert('RGBA').getdata() if p[3] > 0}
    return len(colors) <= BW_MAX_COLORS


def crop(im):
    im = im.convert('RGBA')
    # Pixel art: transparência é tudo ou nada.
    alpha = im.getchannel('A').point(lambda a: 255 if a >= 128 else 0)
    im.putalpha(alpha)
    box = alpha.getbbox()
    return im.crop(box) if box else im


def breathe(img, path):
    """GIF com o Pokémon respirando (esticando para cima, apoiado embaixo)."""
    w, h = img.size
    top = max(BREATH)
    frames = []
    for s in BREATH:
        frame = Image.new('RGBA', (w, h + top), (0, 0, 0, 0))
        frame.alpha_composite(img.resize((w, h + s), Image.NEAREST), (0, top - s))
        frames.append(frame)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=FRAME_MS, loop=0, disposal=2, optimize=False)


def main():
    repo = sys.argv[1] if len(sys.argv) > 1 else '/tmp/smogon-sprites'
    index = smogon_index(repo)
    with open(os.path.join(DB, 'pokemon.json'), encoding='utf-8') as f:
        pokemon = [(p['id'], p['name']) for p in json.load(f) if p['id'] > 649]

    # Quem troca (decide pela frente, para o shiny ficar igual).
    jobs = []
    for pid, slug in pokemon:
        cur = os.path.join(OUT, 'front', f'{pid}.gif')
        if os.path.exists(cur) and is_bw(cur):
            continue
        for kind in ('front', 'shiny'):
            jobs.append((pid, slug, kind))

    # Formas que só mudam de pose (Koraidon/Miraidon de batalha...) e não têm
    # arte própria: usam a da espécie. Mega/Gigantamax nunca (seria outro visual).
    def art(pid, slug, kind):
        if kind in index.get(slug, {}):
            return index[slug][kind]
        if 'mega' in slug or 'gmax' in slug or os.path.exists(os.path.join(STATIC, f'{pid}.png')):
            return None
        return index.get(slug.split('-')[0], {}).get(kind)

    # Baixa só os arquivos da Smogon que vamos usar (clone sem os blobs).
    need = [a for pid, slug, kind in jobs if (a := art(pid, slug, kind))]
    for i in range(0, len(need), 200):
        subprocess.run(['git', '-C', repo, 'checkout', 'HEAD', '--', *need[i:i + 200]], check=True)

    counts = {'smogon': 0, 'banco': 0, 'sem': 0}
    for pid, slug, kind in jobs:
        out = os.path.join(OUT, kind, f'{pid}.gif')
        src = art(pid, slug, kind)
        if src:
            breathe(crop(Image.open(os.path.join(repo, src))), out)
            counts['smogon'] += 1
            continue
        static = os.path.join(STATIC, *(['shiny'] if kind == 'shiny' else []), f'{pid}.png')
        if os.path.exists(static):
            breathe(crop(Image.open(static)), out)
            counts['banco'] += 1
        else:
            if os.path.exists(out):
                os.remove(out)
            counts['sem'] += 1
    print(f'trocados: {len(jobs)} ({counts})')
    subprocess.run([sys.executable, os.path.join(ROOT, 'tool', 'fetch_animated_sprites.py')], check=True)


if __name__ == '__main__':
    main()
