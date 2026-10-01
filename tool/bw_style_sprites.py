#!/usr/bin/env python3
"""Deixa todos os sprites animados no mesmo estilo do Black & White.

Do #650 em diante o Pokémon Showdown só tem animação no estilo BW para parte
das gerações novas; o resto são renderizações 3D (maiores e com centenas de
cores) ou nem existem. Para cada um desses, em ordem:
  1. a animação BW de verdade da pasta gen5ani do Showdown
     (play.pokemonshowdown.com/sprites), recortada justo;
  2. a animação 3D do Showdown (pasta ani; ou a cópia da PokeAPI) reduzida ao
     tamanho e às 16 cores do BW: o movimento é o de verdade (nada de esticar
     o desenho);
  3. sem animação nenhuma: a arte BW parada do Smogon Sprite Project
     (smogon/sprites, src/sprites/gen5) ou, sem ela, o sprite parado do banco.

Rode depois de tool/fetch_animated_sprites.py (que baixa o que falta e gera
animated_sprites.json); este script regrava os GIFs e roda o fetch de novo só
para recalcular a lista e os ajustes de tamanho.

Uso:
  GIT_LFS_SKIP_SMUDGE=1 git clone --depth 1 --filter=blob:none --no-checkout \\
      https://github.com/smogon/sprites /tmp/smogon-sprites
  python3 tool/bw_style_sprites.py /tmp/smogon-sprites [--refazer] [--costas]
  (--refazer: refaz todos do #650 em diante, buscando de novo no Showdown;
   --costas: também as costas, para a batalha, em sprites/animated/back)
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

# Animação 3D reduzida: paleta do BW e metade dos quadros (o 3D tem o dobro).
BW_COLORS = 16
PS_3D = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/showdown'
CACHE_3D = '/tmp/pokeapi-showdown-3d'
PS = 'https://play.pokemonshowdown.com/sprites'
CACHE_PS = '/tmp/showdown-sprites'
# Marca nos GIFs gerados aqui (para refazer só eles com --refazer).
MARK = b'pocketdex-respiracao'  # (nome antigo, de quando era só respiração; mantido)

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


def showdown_names(slug):
    """Jeitos de o Showdown escrever o slug da PokeAPI ("iron-bundle" → "ironbundle",
    "charizard-mega-x" → "charizard-megax", "ogerpon-wellspring-mask" → "ogerpon-wellspring")."""
    parts = slug.split('-')
    names = []
    for end in range(len(parts), 0, -1):  # também sem as últimas palavras ("-mask", "-build"...)
        p = parts[:end]
        names += [''.join(p)] + [''.join(p[:i]) + '-' + ''.join(p[i:]) for i in range(1, len(p))]
    return list(dict.fromkeys(names))


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


def still(img, path):
    """Arte parada (um quadro só): sem animação nenhuma, nada de deformar o desenho."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, save_all=True, append_images=[], loop=0, disposal=2, comment=MARK)


def fetch_ps(folder, name):
    """Um GIF do servidor de sprites do Showdown (guardado em CACHE_PS; None se não existe)."""
    import urllib.error
    import urllib.request
    path = os.path.join(CACHE_PS, folder, f'{name}.gif')
    missing = path + '.404'
    if os.path.exists(path):
        return path
    if os.path.exists(missing):
        return None
    os.makedirs(os.path.dirname(path), exist_ok=True)
    try:
        # Sem User-Agent o servidor do Showdown responde 403.
        request = urllib.request.Request(f'{PS}/{folder}/{name}.gif', headers={'User-Agent': 'PocketDex sprite tool'})
        with urllib.request.urlopen(request, timeout=60) as r:
            data = r.read()
    except urllib.error.HTTPError as e:
        if e.code == 404:
            open(missing, 'w').close()
        return None
    except Exception:
        return None
    with open(path, 'wb') as f:
        f.write(data)
    return path


def fetch_3d(pid, kind):
    """Animação 3D do Showdown (pelo repositório da PokeAPI), guardada em CACHE_3D."""
    import urllib.request
    path = os.path.join(CACHE_3D, kind, f'{pid}.gif')
    if not os.path.exists(path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        try:
            with urllib.request.urlopen(f"{PS_3D}/{'shiny/' if kind == 'shiny' else ''}{pid}.gif", timeout=60) as r:
                data = r.read()
        except Exception:
            return None
        with open(path, 'wb') as f:
            f.write(data)
    return path


def pixel_3d(src, path, target):
    """Animação 3D reduzida ao tamanho (lado maior = target) e às 16 cores do BW."""
    from PIL import ImageSequence
    im = Image.open(src)
    frames, durations, box = [], [], None
    for fr in ImageSequence.Iterator(im):
        f = fr.convert('RGBA')
        frames.append(f)
        durations.append(fr.info.get('duration', 50))
        b = f.getchannel('A').getbbox()
        if b:
            box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
    if box is None:
        return False
    # O corpo (quadro típico, não a área toda por onde ele voa) fica do tamanho da arte BW.
    sides = sorted(max(b[2] - b[0], b[3] - b[1]) for f in frames if (b := f.getchannel('A').getbbox()))
    frames = [f.crop(box) for f in frames]
    w, h = frames[0].size
    k = target / sides[len(sides) // 2]
    size = (max(1, round(w * k)), max(1, round(h * k)))
    small = [f.resize(size, Image.BOX) for f in frames]
    # Uma paleta só para a animação inteira (as cores não piscam de um quadro
    # para outro), feita só com as cores do Pokémon (sem o fundo).
    pixels = [p[:3] for f in small for p in f.getdata() if p[3] >= 128]
    strip = Image.new('RGB', (max(1, len(pixels)), 1))
    strip.putdata(pixels or [(0, 0, 0)])
    palette = strip.quantize(BW_COLORS, method=Image.Quantize.MEDIANCUT)
    out = []
    for f in small[::2]:
        q = f.convert('RGB').quantize(palette=palette, dither=Image.Dither.NONE).convert('RGBA')
        q.putalpha(f.getchannel('A').point(lambda a: 255 if a >= 128 else 0))  # pixel art: sem meio-transparente
        out.append(q)
    durations = [sum(durations[i:i + 2]) for i in range(0, len(durations), 2)]
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out[0].save(path, save_all=True, append_images=out[1:], duration=durations, loop=0, disposal=2, comment=MARK)
    return True


def generated(path):
    """GIF feito por este script (marca no comentário, ou a primeira versão sem marca)."""
    from PIL import ImageSequence
    im = Image.open(path)
    if MARK in (im.info.get('comment') or b''):
        return True
    durations = [f.info.get('duration', 0) for f in ImageSequence.Iterator(im)]
    return sum(durations) == 1080 and all(d % 90 == 0 for d in durations)


def main():
    from concurrent.futures import ThreadPoolExecutor
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    repo = args[0] if args else '/tmp/smogon-sprites'
    refazer = '--refazer' in sys.argv  # refaz todos do #650 em diante
    index = smogon_index(repo)
    with open(os.path.join(DB, 'pokemon.json'), encoding='utf-8') as f:
        everyone = json.load(f)
    pokemon = [(p['id'], p['name']) for p in everyone if p['id'] > 649]
    ids = {p['name']: p['id'] for p in everyone}

    # Quem troca (decide pela frente, para o shiny ficar igual).
    jobs = []
    for pid, slug in pokemon:
        cur = os.path.join(OUT, 'front', f'{pid}.gif')
        if os.path.exists(cur) and is_bw(cur) and not refazer:
            continue
        for kind in ('front', 'shiny'):
            jobs.append((pid, slug, kind))

    # Um nome que é de outro Pokémon do banco nunca vale ("charizard" não serve
    # para a Mega, "ogerpon" não serve para a máscara).
    taken = {}
    for _, other in pokemon + [(0, n) for n in ids]:
        taken.setdefault(other.replace('-', ''), set()).add(other)

    def ps(folder, slug, kind):
        """Primeiro nome que existe no Showdown para esse slug."""
        folder += '-shiny' if kind == 'shiny' else ''
        names = [n for n in showdown_names(slug) if taken.get(n.replace('-', ''), {slug}) == {slug}]
        return next((g for n in names if (g := fetch_ps(folder, n))), None)

    # Baixa do Showdown em paralelo (animação BW e, para quem não tem, a 3D).
    def ps_bw(slug, kind):
        # Forma que só muda de pose (Miraidon de batalha...): a animação da espécie.
        found = ps('gen5ani', slug, kind)
        if not found and '-' in slug and 'mega' not in slug and 'gmax' not in slug:
            found = ps('gen5ani', slug.split('-')[0], kind)
        return found

    with ThreadPoolExecutor(8) as pool:
        bw = dict(zip(jobs, pool.map(lambda j: ps_bw(j[1], j[2]), jobs)))
        rest = [j for j in jobs if not (bw[j] and is_bw(bw[j]))]
        ani3d = dict(zip(rest, pool.map(lambda j: ps('ani', j[1], j[2]), rest)))

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

    counts = {'animado BW': 0, '3D reduzido': 0, 'parado': 0, 'sem': 0}
    for job in jobs:
        pid, slug, kind = job
        out = os.path.join(OUT, kind, f'{pid}.gif')
        if bw[job] and is_bw(bw[job]):
            crop_gif(bw[job], out)
            counts['animado BW'] += 1
            continue
        # Arte BW parada: a da Smogon ou, sem ela, a do banco.
        src = art(pid, slug, kind)
        static = os.path.join(STATIC, *(['shiny'] if kind == 'shiny' else []), f'{pid}.png')
        img = crop(Image.open(os.path.join(repo, src))) if src else crop(Image.open(static)) if os.path.exists(static) else None
        # O 3D reduzido fica do tamanho da arte BW.
        anim = ani3d.get(job) or fetch_3d(pid, kind)
        if not anim and not ('mega' in slug or 'gmax' in slug):
            # Forma que só muda de pose (Koraidon de batalha...): a animação da espécie.
            base = ids.get(slug.split('-')[0])
            anim = base and base != pid and fetch_3d(base, kind)
        if anim and pixel_3d(anim, out, max(img.size) if img else 80):
            counts['3D reduzido'] += 1
        elif img:
            still(img, out)
            counts['parado'] += 1
        else:
            if os.path.exists(out):
                os.remove(out)
            counts['sem'] += 1
    print(f'trocados: {len(jobs)} ({counts})')
    if '--costas' in sys.argv:
        backs(everyone, ps, refazer)
    subprocess.run([sys.executable, os.path.join(ROOT, 'tool', 'fetch_animated_sprites.py')], check=True)


def backs(everyone, ps, refazer):
    """Costas (para a batalha) no mesmo estilo: até o #649 as oficiais do BW;
    depois, as costas BW do Showdown (gen5ani-back) ou as 3D reduzidas."""
    import urllib.request
    from concurrent.futures import ThreadPoolExecutor
    pokeapi = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon'

    def one(job):
        p, kind = job
        pid, slug = p['id'], p['name']
        shiny = kind == 'back-shiny'
        out = os.path.join(OUT, kind, f'{pid}.gif')
        if os.path.exists(out) and not refazer:
            return 'já tinha'
        os.makedirs(os.path.dirname(out), exist_ok=True)
        if pid <= 649:
            url = f"{pokeapi}/versions/generation-v/black-white/animated/back/{'shiny/' if shiny else ''}{pid}.gif"
            try:
                with urllib.request.urlopen(url, timeout=60) as r:
                    data = r.read()
            except Exception:
                return 'sem'
            with open(out, 'wb') as f:
                f.write(data)
            return 'BW oficial'
        bw = ps('gen5ani-back', slug, 'shiny' if shiny else 'front')
        if not bw and '-' in slug and 'mega' not in slug and 'gmax' not in slug:
            bw = ps('gen5ani-back', slug.split('-')[0], 'shiny' if shiny else 'front')
        if bw and is_bw(bw):
            crop_gif(bw, out)
            return 'animado BW'
        anim = ps('ani-back', slug, 'shiny' if shiny else 'front')
        front = os.path.join(OUT, 'shiny' if shiny else 'front', f'{pid}.gif')
        target = max(Image.open(front).size) if os.path.exists(front) else 80
        if anim and pixel_3d(anim, out, target):
            return '3D reduzido'
        if os.path.exists(out):
            os.remove(out)
        return 'sem'

    jobs = [(p, kind) for p in everyone for kind in ('back', 'back-shiny')]
    with ThreadPoolExecutor(8) as pool:
        results = list(pool.map(one, jobs))
    print('costas:', {k: results.count(k) for k in set(results)})


if __name__ == '__main__':
    main()
