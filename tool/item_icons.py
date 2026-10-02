#!/usr/bin/env python3
"""Ícones dos itens que estão sem imagem no banco (as Mega Pedras novas do
Legends Z-A, Rusted Sword, máscaras da Ogerpon...), recortados da folha de
ícones do Pokémon Showdown (24×24, a mesma arte dos jogos), no meio de um
quadro 30×30 como os outros ícones do banco. Só preenche quem está sem imagem.

Uso (o pacote do Showdown é o mesmo do tool/build_battle_items.mjs):
  npm pack pokemon-showdown && tar xf pokemon-showdown-*.tgz -C /tmp/ps-pkg
  curl -A Mozilla/5.0 -o /tmp/itemicons-sheet.png https://play.pokemonshowdown.com/sprites/itemicons-sheet.png
  python3 tool/item_icons.py /tmp/ps-pkg/package /tmp/itemicons-sheet.png
"""

import json
import os
import re
import subprocess
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(ROOT, 'assets', 'database')
ICON = 24
PER_ROW = 16


def to_id(name):
    return re.sub('[^a-z0-9]', '', re.sub(r'--held$', '', name.lower()))


def main():
    package, sheet_path = sys.argv[1:3]
    # {id do Showdown: spritenum}
    script = f"const {{Items}} = require({json.dumps(os.path.join(package, 'dist/data/items.js'))});" \
        "console.log(JSON.stringify(Object.fromEntries(Object.entries(Items).map(([k, v]) => [k, v.spritenum]))))"
    spritenum = json.loads(subprocess.run(['node', '-e', script], capture_output=True, text=True, check=True).stdout)
    sheet = Image.open(sheet_path).convert('RGBA')
    path = os.path.join(DB, 'items.json')
    with open(path, encoding='utf-8') as f:
        items = json.load(f)
    done = 0
    for item in items:
        if item.get('sprite'):
            continue
        num = spritenum.get(to_id(item['name']))
        if not num:
            continue
        x, y = (num % PER_ROW) * ICON, (num // PER_ROW) * ICON
        icon = sheet.crop((x, y, x + ICON, y + ICON))
        if not icon.getbbox():
            continue
        out = Image.new('RGBA', (30, 30))
        out.paste(icon, (3, 3))
        rel = f"items/{item['name']}.png"
        out.save(os.path.join(DB, 'sprites', rel))
        item['sprite'] = rel
        done += 1
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(items, f, ensure_ascii=False, separators=(',', ':'))
    print('ícones novos:', done)


if __name__ == '__main__':
    main()
