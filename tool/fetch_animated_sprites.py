#!/usr/bin/env python3
"""Baixa os sprites animados (GIF) de todos os Pokémon para o banco.

Saída: assets/database/sprites/animated/front/<id>.gif e .../shiny/<id>.gif,
de frente, no estilo Black & White:
  • do #1 ao #649: os oficiais do Black & White;
  • do #650 em diante e as formas: os do Pokémon Showdown (Smogon Sprite Project);
os dois do repositório de sprites da PokeAPI. Quem não tem sprite animado fica
de fora (o app e o site mostram o parado de sempre).

O site publica a pasta junto com os outros sprites (tool/build_web_data.py);
o app NÃO embute esses arquivos (o APK ficaria com ~300 MB): baixa do site
cada um da primeira vez que aparece e guarda no celular.

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
    have = {sub: sorted(int(f[:-4]) for f in os.listdir(os.path.join(OUT, sub)) if f.endswith('.gif')) for sub in ('front', 'shiny')}
    with open(os.path.join(DB, 'animated_sprites.json'), 'w', encoding='utf-8') as f:
        json.dump(have, f, separators=(',', ':'))
        f.write('\n')


if __name__ == '__main__':
    main()
