"""Formas sem imagem parada no banco (só o GIF animado): a parada vira o
primeiro quadro do GIF (frente e shiny), para a Pokédex e o resto do app e
do site terem o que mostrar (antes o card ficava vermelho, com erro).

Uso: python3 tool/stills_from_animated.py && python3 tool/build_sprite_boxes.py
"""

import json
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(ROOT, 'assets', 'database')


def still(gif, out):
    with Image.open(gif) as im:
        im.seek(0)
        frame = im.convert('RGBA')
    # Num quadro quadrado (como os outros sprites), apoiado embaixo.
    side = max(frame.size)
    canvas = Image.new('RGBA', (side, side))
    canvas.paste(frame, ((side - frame.width) // 2, side - frame.height))
    os.makedirs(os.path.dirname(out), exist_ok=True)
    canvas.save(out, optimize=True)


def main():
    path = os.path.join(DB, 'pokemon.json')
    with open(path, encoding='utf-8') as f:
        rows = json.load(f)
    fixed = []
    for p in rows:
        sprites = p['sprites']
        for slot, kind, folder in ((0, 'front', 'pokemon'), (1, 'shiny', 'pokemon/shiny')):
            if sprites[slot]:
                continue
            gif = os.path.join(DB, 'sprites', 'animated', kind, f"{p['id']}.gif")
            if not os.path.exists(gif):
                continue
            rel = f"{folder}/{p['id']}.png"
            still(gif, os.path.join(DB, 'sprites', rel))
            sprites[slot] = rel
            fixed.append(f"{p['name']} ({kind})")
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(rows, f, ensure_ascii=False, separators=(',', ':'))
    print(len(fixed), 'imagens:', ', '.join(fixed))


if __name__ == '__main__':
    main()
