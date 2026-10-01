#!/usr/bin/env python3
"""Baixa os sprites animados (GIF) de todos os Pokémon para o banco.

Saída: assets/database/sprites/animated/front/<id>.gif e .../shiny/<id>.gif,
de frente, no estilo Black & White:
  • do #1 ao #649: os oficiais do Black & White;
  • do #650 em diante e as formas: os do Pokémon Showdown (Smogon Sprite Project);
os dois do repositório de sprites da PokeAPI. Quem não tem sprite animado fica
de fora (o app e o site mostram o parado de sempre). Depois, rode
tool/bw_style_sprites.py: troca os que vieram em 3D (8ª/9ª geração, Megas...)
e os que faltam pela arte BW da Smogon, para ficarem todos no mesmo estilo.

O site publica a pasta junto com os outros sprites (tool/build_web_data.py)
e o app puxa cada um de lá (da nuvem, com internet; o APK fica leve). No fim, os
GIFs passam pelo gifsicle -O3 (sem perda: os quadros ficam idênticos, só o
arquivo diminui), se ele estiver instalado.

Uso: python3 tool/fetch_animated_sprites.py   (só baixa o que falta)
"""

import json
import os
import urllib.request
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(ROOT, 'assets', 'database')
OUT = os.path.join(DB, 'sprites', 'animated')
BASE = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon'


def source(pid, shiny):
    folder = f'{BASE}/versions/generation-v/black-white/animated' if pid <= 649 else f'{BASE}/other/showdown'
    return f'{folder}/{"shiny/" if shiny else ""}{pid}.gif'


def fetch(job):
    pid, shiny = job
    path = os.path.join(OUT, 'shiny' if shiny else 'front', f'{pid}.gif')
    if os.path.exists(path):
        return 'já tinha'
    try:
        with urllib.request.urlopen(source(pid, shiny), timeout=60) as r:
            data = r.read()
    except Exception:
        return 'sem animado'
    with open(path, 'wb') as f:
        f.write(data)
    return 'baixado'


# Os GIFs são recortados pela soma de todos os quadros: quem abre as asas ou se
# mexe muito (Swanna, Koffing...) fica pequeno na maior parte da animação.
# Para esses guardamos [zoom, dx, dy, largura, altura]: quanto ampliar para o quadro "típico"
# (mediana) ocupar a caixa e onde fica o centro dele (fração do lado maior,
# a partir do centro da imagem).
MAX_ZOOM = 1.5


def fit(path):
    from PIL import Image, ImageFile, ImageSequence
    ImageFile.LOAD_TRUNCATED_IMAGES = True  # alguns GIFs do Showdown vêm com sobra no fim
    im = Image.open(path)
    W, H = im.size
    M = max(W, H)
    boxes = [b for fr in ImageSequence.Iterator(im) if (b := fr.convert('RGBA').getchannel('A').getbbox())]
    if not boxes:
        return None
    mid = lambda xs: sorted(xs)[len(xs) // 2]
    typical = mid([max(b[2] - b[0], b[3] - b[1]) for b in boxes])
    zoom = min(MAX_ZOOM, M / typical)
    if zoom < 1.08:
        return None
    cx = mid([(b[0] + b[2]) / 2 for b in boxes])
    cy = mid([(b[1] + b[3]) / 2 for b in boxes])
    # + largura e altura (fração do lado maior): quem desenha limita o zoom
    # para a animação inteira caber na caixa.
    return [round(zoom, 2), round((cx - W / 2) / M, 3), round((cy - H / 2) / M, 3), round(W / M, 3), round(H / M, 3)]


def digest(path):
    import hashlib
    with open(path, 'rb') as f:
        return hashlib.sha1(f.read()).hexdigest()[:8]


def fits(sub, ids):
    out = {}
    for pid in ids:
        f = fit(os.path.join(OUT, sub, f'{pid}.gif'))
        if f:
            out[str(pid)] = f
    return out


def optimize():
    """gifsicle -O3 em todos os GIFs (sem perda; mantém a marca dos gerados)."""
    import shutil
    import subprocess
    if not shutil.which('gifsicle'):
        print('gifsicle não instalado: GIFs sem otimizar')
        return
    files = [os.path.join(OUT, sub, f) for sub in ('front', 'shiny') for f in os.listdir(os.path.join(OUT, sub)) if f.endswith('.gif')]
    for i in range(0, len(files), 200):
        subprocess.run(['gifsicle', '-O3', '-b', *files[i:i + 200]], check=False, capture_output=True)


def main():
    with open(os.path.join(DB, 'pokemon.json'), encoding='utf-8') as f:
        ids = sorted(p['id'] for p in json.load(f))
    for sub in ('front', 'shiny'):
        os.makedirs(os.path.join(OUT, sub), exist_ok=True)
    jobs = [(pid, shiny) for pid in ids for shiny in (False, True)]
    with ThreadPoolExecutor(16) as pool:
        results = list(pool.map(fetch, jobs))
    for kind in ('baixado', 'já tinha', 'sem animado'):
        print(f'{kind}: {results.count(kind)}')
    # Quais têm sprite animado: {"front": [ids], "shiny": [ids]} (o app e o site
    # só procuram esses).
    optimize()
    have = {sub: sorted(int(f[:-4]) for f in os.listdir(os.path.join(OUT, sub)) if f.endswith('.gif')) for sub in ('front', 'shiny')}
    have['fit'] = {sub: fits(sub, have[sub]) for sub in ('front', 'shiny')}
    # Impressão digital de cada GIF: quando um muda, o app baixa de novo (e o
    # navegador não usa o velho do cache).
    have['hash'] = {sub: {str(pid): digest(os.path.join(OUT, sub, f'{pid}.gif')) for pid in have[sub]} for sub in ('front', 'shiny')}
    with open(os.path.join(DB, 'animated_sprites.json'), 'w', encoding='utf-8') as f:
        json.dump(have, f, separators=(',', ':'))
        f.write('\n')


if __name__ == '__main__':
    main()
