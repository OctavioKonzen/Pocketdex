"""Reduz as artes oficiais só para o APK (deixa o app bem menor).

No app as artes aparecem pequenas, então 320 px bastam, com qualidade 70
(cor e transparência); a diferença não aparece na tela e o APK fica uns
18 MB menor. No repositório elas continuam em 475 px porque o site no PC
mostra maiores. Roda no GitHub
Actions antes de gerar o APK — não é para commitar o resultado.

Uso: python3 tool/shrink_app_images.py
"""

from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ARTWORK = ROOT / "assets/database/sprites/pokemon/other/official-artwork"
SIZE = 320
QUALITY = 70


def shrink(path: Path) -> int:
    before = path.stat().st_size
    with Image.open(path) as im:
        im.thumbnail((SIZE, SIZE), Image.LANCZOS)
        im.save(path, "WEBP", quality=QUALITY, alpha_quality=QUALITY, method=4)
    return before - path.stat().st_size


def main() -> None:
    files = sorted(ARTWORK.rglob("*.webp"))
    with ProcessPoolExecutor() as pool:
        saved = sum(pool.map(shrink, files, chunksize=32))
    print(f"{len(files)} artes reduzidas, {saved / 1e6:.1f} MB a menos")


if __name__ == "__main__":
    main()
