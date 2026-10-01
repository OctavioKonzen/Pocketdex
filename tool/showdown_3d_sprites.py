#!/usr/bin/env python3
"""Sprites 3D do Pokémon Showdown, na qualidade original (opção "3D" e a
batalha de quem não tem animação no estilo Black & White).

Saída: assets/database/sprites/3d/<tipo>/<id>.gif (front, shiny, back e
back-shiny), das pastas ani, ani-shiny, ani-back e ani-back-shiny de
play.pokemonshowdown.com/sprites: só recortados justo (sem perder nada) e
otimizados pelo gifsicle -O3 (sem perda). Formas que só mudam de pose usam a
animação da espécie; Mega/Gigantamax, só a delas.

Depois, rode tool/fetch_animated_sprites.py para refazer animated_sprites.json.

Uso: python3 tool/showdown_3d_sprites.py [--refazer]
"""

import json
import os
import sys
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bw_style_sprites import DB, crop_gif, fetch_ps, showdown_names  # noqa: E402

OUT = os.path.join(DB, 'sprites', '3d')
FOLDERS = {'front': 'ani', 'shiny': 'ani-shiny', 'back': 'ani-back', 'back-shiny': 'ani-back-shiny'}


def main():
    refazer = '--refazer' in sys.argv
    with open(os.path.join(DB, 'pokemon.json'), encoding='utf-8') as f:
        everyone = [(p['id'], p['name']) for p in json.load(f)]
    # Um nome que é de outro Pokémon do banco nunca vale ("charizard" não
    # serve para a Mega, "ogerpon" não serve para a máscara).
    taken = {}
    for _, other in everyone:
        taken.setdefault(other.replace('-', ''), set()).add(other)

    def one(job):
        pid, slug, kind = job
        out = os.path.join(OUT, kind, f'{pid}.gif')
        if os.path.exists(out) and not refazer:
            return 'já tinha'
        names = [n for n in showdown_names(slug) if taken.get(n.replace('-', ''), {slug}) == {slug}]
        if '-' in slug and 'mega' not in slug and 'gmax' not in slug:
            names.append(slug.split('-')[0])
        found = next((g for n in names if (g := fetch_ps(FOLDERS[kind], n))), None)
        if not found:
            return 'sem'
        os.makedirs(os.path.dirname(out), exist_ok=True)
        crop_gif(found, out)
        return 'baixado'

    jobs = [(pid, slug, kind) for pid, slug in everyone for kind in FOLDERS]
    with ThreadPoolExecutor(8) as pool:
        results = list(pool.map(one, jobs))
    print('3D:', {k: results.count(k) for k in set(results)})


if __name__ == '__main__':
    main()
