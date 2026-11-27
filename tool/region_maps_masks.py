#!/usr/bin/env python3
"""
Tira as máscaras (terra, rotas, montanha, deserto, floresta) de uma imagem de referência de mapa (pelas cores) e
guarda em tool/region_maps_ref/<mapa>-m-<tipo>.png, para o tool/region_maps.py desenhar o mapa com o mesmo formato.
A imagem de referência não vai para o projeto; só as máscaras.

Uso: python3 tool/region_maps_masks.py <mapa> <imagem> [painted|flat]
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

OUT = os.path.join(os.path.dirname(__file__), 'region_maps_ref')


def clean(mask, min_size):
    lab, n = ndimage.label(mask)
    if not n:
        return mask
    sizes = ndimage.sum(mask, lab, range(1, n + 1))
    keep = np.zeros(n + 1, dtype=bool)
    keep[1:] = sizes >= min_size
    return keep[lab]


def main(name, path, style='painted'):
    a = np.asarray(Image.open(path).convert('RGB').resize((900, round(900 * Image.open(path).height / Image.open(path).width)), Image.LANCZOS), dtype=int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    if style == 'flat':
        water = (b > 200) & (b > r + 20) & (g > 180)
        road = (np.abs(r - g) < 16) & (np.abs(g - b) < 16) & (r > 140)
        # As marcas em cima das rotas (os círculos verdes e os quadrados das cidades) também são rota.
        marks = ((g > 150) & (r < 120) & (b < 140)) | ((r > 200) & (g < 60) & (b < 60)) | ((b > 200) & (r < 60) & (g < 60))
        road = ndimage.binary_closing(road | marks, iterations=6)
        mountain = desert = forest = np.zeros_like(water)
    else:
        water = (b > r + 30) & (b >= g) & (b > 100)
        road = (r > 200) & (g > 120) & (b < 110) & (r - b > 110)
        tan = (r > 85) & (np.abs(r - g) < 40) & (b < g + 10) & (g - r < 12) & ~road
        # A rocha cinza-azulada das montanhas (pouca cor, nem escura nem clara demais).
        rock = ((a.max(-1) - a.min(-1)) < 42) & (a.sum(-1) > 170) & (a.sum(-1) < 640) & ~road & ~((b > r + 30) & (b > 100))
        desert = tan & (r > 160) & (r - b > 50) if name != 'kanto' else np.zeros_like(tan)
        mountain = (tan & ~desert) | rock
        forest = (g > r + 12) & (g < 110) & (r + g + b < 260) & ~water
    # Os círculos das cidades e as sombras não são mar: só as águas grandes ficam.
    water = clean(water, 2600)
    land = ndimage.binary_closing(~water, iterations=2)
    land = clean(land, 120)
    os.makedirs(OUT, exist_ok=True)
    for kind, m in [('land', land), ('road', clean(road, 40)), ('mountain', clean(ndimage.binary_opening(mountain, iterations=1), 200)),
                    ('desert', clean(ndimage.binary_opening(desert, iterations=1), 200)), ('forest', clean(ndimage.binary_opening(forest, iterations=1), 300))]:
        Image.fromarray((m * 255).astype(np.uint8)).save(os.path.join(OUT, f'{name}-m-{kind}.png'))
    print('ok', name, {k: int(v.sum()) for k, v in [('land', land), ('road', road), ('mountain', mountain), ('desert', desert), ('forest', forest)]})


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else 'painted')
