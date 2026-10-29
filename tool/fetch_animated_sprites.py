#!/usr/bin/env python3
"""Baixa os sprites animados (GIF) de todos os Pokémon para o banco e gera
animated_sprites.json.

Saída: assets/database/sprites/animated/front/<id>.gif e .../shiny/<id>.gif,
no estilo Black & White: do #1 ao #649 os oficiais do Black & White (do
repositório de sprites da PokeAPI). Do #650 em diante e as formas quem decide
é tool/bw_style_sprites.py (animação BW do Showdown ou a arte BW parada), que
também faz as costas.

animated_sprites.json descreve a pasta: quais existem, os parados (um quadro
só), o ajuste de tamanho, o pé (quem pula ou flutua, para pisar na plataforma
da batalha), o tamanho em pixels e a impressão digital.

Os GIFs vão dentro do app (funciona sem internet) e no site. No fim, passam
pelo gifsicle -O3 (sem perda: os quadros ficam idênticos, só o arquivo
diminui), se ele estiver instalado.

Uso: python3 tool/fetch_animated_sprites.py   (só baixa o que falta)
"""

import json
import os
import urllib.request
from concurrent.futures import ThreadPoolExecutor

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(ROOT, 'assets', 'database')
OUT = os.path.join(DB, 'sprites', 'animated')
BASE = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon'
KINDS = ('front', 'shiny', 'back', 'back-shiny')


def source(pid, shiny):
    return f'{BASE}/versions/generation-v/black-white/animated/{"shiny/" if shiny else ""}{pid}.gif'


def fetch(job):
    pid, shiny = job
    path = os.path.join(OUT, 'shiny' if shiny else 'front', f'{pid}.gif')
    if os.path.exists(path):
        return 'já tinha'
    if pid > 649:
        # Do #650 em diante quem decide é tool/bw_style_sprites.py (só BW).
        return 'sem animado'
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


def foot(path):
    """Quanto o pé do quadro típico fica acima do fundo do GIF (fração do lado
    maior): quem pula ou flutua no meio da animação. Na batalha o Pokémon
    desce isso para pisar na plataforma."""
    from PIL import Image, ImageFile, ImageSequence
    ImageFile.LOAD_TRUNCATED_IMAGES = True
    im = Image.open(path)
    W, H = im.size
    bottoms = sorted(b[3] for fr in ImageSequence.Iterator(im) if (b := fr.convert('RGBA').getchannel('A').getbbox()))
    if not bottoms:
        return 0
    gap = (H - bottoms[len(bottoms) // 2]) / max(W, H)
    return round(gap, 3) if gap >= 0.02 else 0


def frames(path):
    from PIL import Image
    return getattr(Image.open(path), 'n_frames', 1)


def digest(path):
    import hashlib
    with open(path, 'rb') as f:
        return hashlib.sha1(f.read()).hexdigest()[:8]


def fits(sub, ids, root=OUT):
    out = {}
    for pid in ids:
        f = fit(os.path.join(root, sub, f'{pid}.gif'))
        if f:
            out[str(pid)] = f
    return out


def optimize(out=OUT):
    """gifsicle -O3 em todos os GIFs (sem perda; mantém a marca dos gerados)."""
    import shutil
    import subprocess
    if not shutil.which('gifsicle'):
        print('gifsicle não instalado: GIFs sem otimizar')
        return
    files = [os.path.join(out, sub, f) for sub in KINDS if os.path.isdir(os.path.join(out, sub)) for f in os.listdir(os.path.join(out, sub)) if f.endswith('.gif')]
    for i in range(0, len(files), 200):
        subprocess.run(['gifsicle', '-O3', '-b', *files[i:i + 200]], check=False, capture_output=True)


def describe(root):
    """Quais existem, ajuste de tamanho (fit), pé (foot), os parados (still,
    um quadro só), o tamanho em pixels (size: quem desenha amplia por um
    número inteiro, cada pixel do mesmo tamanho) e a impressão digital (hash)
    de cada GIF da pasta.

    As formas só de aparência (Vivillon, Unown, Alcremie...) têm GIF com o
    nome do sprite ("666-polar.gif") e vão à parte, em "forms" (assim versões
    antigas do app, que só leem números, continuam funcionando)."""
    kinds = [k for k in KINDS if os.path.isdir(os.path.join(root, k))]
    gifs = {sub: [f[:-4] for f in os.listdir(os.path.join(root, sub)) if f.endswith('.gif')] for sub in kinds}
    have = {sub: sorted(int(n) for n in gifs[sub] if n.isdigit()) for sub in kinds}
    path = lambda sub, pid: os.path.join(root, sub, f'{pid}.gif')
    have['fit'] = {sub: fits(sub, have[sub], root) for sub in kinds}
    have['foot'] = {sub: {str(pid): v for pid in have[sub] if (v := foot(path(sub, pid)))} for sub in kinds}
    have['still'] = {sub: [pid for pid in have[sub] if frames(path(sub, pid)) == 1] for sub in kinds}
    have['size'] = {sub: {str(pid): list(Image.open(path(sub, pid)).size) for pid in have[sub]} for sub in kinds}
    # Impressão digital de cada GIF: quando um muda, o navegador não usa o
    # velho do cache.
    have['hash'] = {sub: {str(pid): digest(path(sub, pid)) for pid in have[sub]} for sub in kinds}
    forms = {}
    for sub in kinds:
        for key in sorted(n for n in gifs[sub] if not n.isdigit()):
            info = {'size': list(Image.open(path(sub, key)).size), 'hash': digest(path(sub, key))}
            if (v := fit(path(sub, key))):
                info['fit'] = v
            if (v := foot(path(sub, key))):
                info['foot'] = v
            if frames(path(sub, key)) == 1:
                info['still'] = True
            forms.setdefault(sub, {})[key] = info
    have['forms'] = forms
    return have


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
    # Frente, shiny e as costas (para a batalha).
    have = describe(OUT)
    with open(os.path.join(DB, 'animated_sprites.json'), 'w', encoding='utf-8') as f:
        json.dump(have, f, separators=(',', ':'))
        f.write('\n')


if __name__ == '__main__':
    main()
