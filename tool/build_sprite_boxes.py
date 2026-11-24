"""Calcula onde cada Pokémon fica dentro do sprite (recorte sem a borda
transparente) para o app desenhar todos com o mesmo tamanho visual, como o
site faz. Gera assets/database/sprite_boxes.json: {"id": [x0, y0, x1, y1, w, h]}.

Uso: python3 tool/build_sprite_boxes.py
"""

import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SPRITES = ROOT / "assets/database/sprites/pokemon"
OUT = ROOT / "assets/database/sprite_boxes.json"


def main() -> None:
    boxes = {}
    for path in sorted(SPRITES.glob("*.png"), key=lambda p: p.stem):
        if not path.stem.isdigit():
            continue
        with Image.open(path) as im:
            bbox = im.convert("RGBA").getchannel("A").getbbox()
            if bbox:
                boxes[path.stem] = [*bbox, im.width, im.height]
    OUT.write_text(json.dumps(boxes, separators=(",", ":")))
    print(f"{len(boxes)} sprites → {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
