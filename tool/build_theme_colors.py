#!/usr/bin/env python3
"""Cor do tema de cada Pokémon (Configurações → Tema de Pokémon).

    assets/database/theme_colors.json  {"6": "#e5762e", ...}

A cor é a mais marcante do sprite BW (o matiz que mais aparece, pesado pela
intensidade da cor). Os de tipo Steel e os quase sem cor (Onix, Magnemite...)
ficam cinza, com só um toque do matiz deles.

Uso: python3 tool/build_theme_colors.py
"""

import colorsys
import json
import os

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
SPRITES = os.path.join(ROOT, 'assets', 'database', 'sprites', 'pokemon')
OUT = os.path.join(ROOT, 'assets', 'database', 'theme_colors.json')


def theme_color(path, types):
    image = Image.open(path).convert('RGBA')
    bins = [0.0] * 36
    pixels = 0
    chroma_sum = 0.0
    for r, g, b, a in image.get_flattened_data() if hasattr(image, 'get_flattened_data') else image.getdata():
        if a < 200:
            continue
        high, low = max(r, g, b), min(r, g, b)
        light = (high + low) / 510
        # O contorno preto e o brilho branco não contam.
        if light < 0.12 or light > 0.94:
            continue
        chroma = (high - low) / 255
        hue = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)[0]
        pixels += 1
        chroma_sum += chroma
        bins[int(hue * 36) % 36] += chroma * chroma
    best = max(range(36), key=lambda k: bins[k])
    hue = (best * 10 + 5) / 360
    gray = 'steel' in types or not pixels or chroma_sum / pixels < 0.17
    r, g, b = colorsys.hls_to_rgb(hue, 0.55, 0.08) if gray else colorsys.hls_to_rgb(hue, 0.52, 0.65)
    return '#%02x%02x%02x' % (round(r * 255), round(g * 255), round(b * 255))


def main():
    with open(os.path.join(ROOT, 'assets', 'database', 'pokemon.json'), encoding='utf-8') as f:
        pokemon = json.load(f)
    colors = {}
    for p in pokemon:
        if not p.get('is_default'):
            continue
        path = os.path.join(SPRITES, f"{p['id']}.png")
        if os.path.exists(path):
            colors[str(p['id'])] = theme_color(path, p['types'])
    with open(OUT, 'w', encoding='utf-8') as f:
        f.write(json.dumps(dict(sorted(colors.items(), key=lambda kv: int(kv[0]))), separators=(',', ':')))
    print(f'{len(colors)} cores de tema em {os.path.relpath(OUT, ROOT)}')


if __name__ == '__main__':
    main()
