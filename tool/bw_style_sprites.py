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

Antes da arte parada, procura animação BW de verdade na pasta gen5ani do
Pokémon Showdown (espelho no GitHub: MaribelHearn/pokemon-showdown-sprites),
que tem parte da 6ª-8ª geração, Megas e formas.

Uso:
  GIT_LFS_SKIP_SMUDGE=1 git clone --depth 1 --filter=blob:none --no-checkout \\
      https://github.com/smogon/sprites /tmp/smogon-sprites
  GIT_LFS_SKIP_SMUDGE=1 git clone --depth 1 --filter=blob:none --no-checkout \\
      https://github.com/MaribelHearn/pokemon-showdown-sprites /tmp/ps-sprites
  python3 tool/bw_style_sprites.py /tmp/smogon-sprites /tmp/ps-sprites [--refazer]
"""

import json
import os
import re
import shutil
import subprocess
import sys

from PIL import Image, ImageFile

ImageFile.LOAD_TRUNCATED_IMAGES = True

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(ROOT, 'assets', 'database')
OUT = os.path.join(DB, 'sprites', 'animated')
STATIC = os.path.join(DB, 'sprites', 'pokemon')

# Sprite BW de verdade: paleta de 16 cores (alguns feitos pela comunidade
# passam um pouco disso) e até 96 px (os animados que abrem asas, um pouco mais).
BW_MAX_SIDE = 160
BW_MAX_COLORS = 20

# Respiração: o Pokémon estica para cima e afina um pouco (apoiado no chão),
# num ciclo suave de FRAMES quadros. Amplitude: 6% da altura (mínimo 3 px).
FRAMES = 16
FRAME_MS = 80
STRETCH = 0.06
# Marca nos GIFs gerados aqui (para refazer só eles com --refazer).
MARK = b'pocketdex-respiracao'

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


def gen5ani_index(repo):
    """Nome do Showdown (ex.: "rotom-wash") → caminho do GIF BW animado."""
    files = subprocess.run(
        ['git', '-C', repo, 'ls-tree', '-r', '--name-only', 'HEAD', 'sprites/gen5ani/', 'sprites/gen5ani-shiny/'],
        capture_output=True, text=True, check=True,
    ).stdout.split()
    index = {'front': {}, 'shiny': {}}
    for f in files:
        if f.endswith('.gif'):
            index['shiny' if '/gen5ani-shiny/' in f else 'front'][f.split('/')[-1][:-4]] = f
    return index


def showdown_names(slug):
    """Jeitos de o Showdown escrever o slug da PokeAPI ("iron-bundle" → "ironbundle")."""
    parts = slug.split('-')
    return [''.join(parts)] + [''.join(parts[:i]) + '-' + ''.join(parts[i:]) for i in range(1, len(parts))]


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


def crop_gif(src, path):
    """Copia o GIF animado recortado justo (pela soma de todos os quadros)."""
    from PIL import ImageSequence
    im = Image.open(src)
    frames, durations, box = [], [], None
    for fr in ImageSequence.Iterator(im):
        f = fr.convert('RGBA')
        frames.append(f)
        durations.append(fr.info.get('duration', 80))
        b = f.getchannel('A').getbbox()
        if b:
            box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
    if box is None:
        shutil.copyfile(src, path)
        return
    frames = [f.crop(box) for f in frames]
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=durations, loop=0, disposal=2)


def breathe(img, path):
    """GIF com o Pokémon respirando (estica para cima e afina, apoiado embaixo)."""
    import math
    w, h = img.size
    amp = max(3, round(h * STRETCH))
    frames = []
    for i in range(FRAMES):
        t = (1 - math.cos(2 * math.pi * i / FRAMES)) / 2  # 0 → 1 → 0
        dh = round(amp * t)
        dw = round(w * (amp * t / h) * 0.5)  # afina metade do que estica
        frame = Image.new('RGBA', (w, h + amp), (0, 0, 0, 0))
        body = img.resize((w - dw, h + dh), Image.NEAREST)
        frame.alpha_composite(body, ((w - body.width) // 2, h + amp - body.height))
        frames.append(frame)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=FRAME_MS, loop=0, disposal=2, comment=MARK)


def generated(path):
    """GIF feito por este script (marca nova ou a respiração antiga de 1,08 s)."""
    from PIL import ImageSequence
    im = Image.open(path)
    if MARK in (im.info.get('comment') or b''):
        return True
    durations = [f.info.get('duration', 0) for f in ImageSequence.Iterator(im)]
    return sum(durations) == 1080 and all(d % 90 == 0 for d in durations)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    repo = args[0] if args else '/tmp/smogon-sprites'
    ps_repo = args[1] if len(args) > 1 else None
    ani = gen5ani_index(ps_repo) if ps_repo else {'front': {}, 'shiny': {}}

    def animated(slug, kind):
        return next((ani[kind][n] for n in showdown_names(slug) if n in ani[kind]), None)
    refazer = '--refazer' in sys.argv  # gera de novo os que este script já fez
    index = smogon_index(repo)
    with open(os.path.join(DB, 'pokemon.json'), encoding='utf-8') as f:
        pokemon = [(p['id'], p['name']) for p in json.load(f) if p['id'] > 649]

    # Quem troca (decide pela frente, para o shiny ficar igual).
    jobs = []
    for pid, slug in pokemon:
        cur = os.path.join(OUT, 'front', f'{pid}.gif')
        if os.path.exists(cur) and is_bw(cur) and not (refazer and (generated(cur) or animated(slug, 'front'))):
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
    need = [a for pid, slug, kind in jobs if (a := animated(slug, kind))]
    for i in range(0, len(need), 200):
        subprocess.run(['git', '-C', ps_repo, 'checkout', 'HEAD', '--', *need[i:i + 200]], check=True)

    counts = {'animado BW': 0, 'smogon': 0, 'banco': 0, 'sem': 0}
    for pid, slug, kind in jobs:
        out = os.path.join(OUT, kind, f'{pid}.gif')
        gif = animated(slug, kind)
        if gif and is_bw(os.path.join(ps_repo, gif)):
            crop_gif(os.path.join(ps_repo, gif), out)
            counts['animado BW'] += 1
            continue
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
