"""Gera o ícone do app Android a partir da logo (assets/images/poke_logo.png).

- ic_launcher.png (ícone clássico) em cada densidade: logo sobre fundo branco
  com cantos arredondados.
- Ícone adaptável (Android 8+): fundo branco + logo como camada da frente,
  dentro da área segura, para qualquer formato (círculo, gota, quadrado).

- Site (web-site/public): favicon com a Poké Bola e os ícones do app
  instalável (PWA), no mesmo estilo do ícone do Android.

Uso: python3 tool/build_app_icon.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
LOGO = ROOT / "assets/images/poke_logo.png"
RES = ROOT / "android/app/src/main/res"
WEB = ROOT / "web-site/public"
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
BACKGROUND = (255, 255, 255, 255)


def logo_fitted(size: int, fill: float) -> Image.Image:
    logo = Image.open(LOGO).convert("RGBA")
    logo = logo.crop(logo.getbbox())
    side = int(size * fill)
    logo.thumbnail((side, side), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(logo, ((size - logo.width) // 2, (size - logo.height) // 2), logo)
    return canvas


def legacy(size: int) -> Image.Image:
    icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size - 1, size - 1), radius=size // 5, fill=255)
    icon.paste(Image.new("RGBA", (size, size), BACKGROUND), (0, 0), mask)
    front = logo_fitted(size, 0.84)
    return Image.alpha_composite(icon, front)


def ball(size: int) -> Image.Image:
    """Só a Poké Bola da logo (o nome some em tamanhos pequenos)."""
    logo = Image.open(LOGO).convert("RGBA").crop((230, 190, 810, 710))
    logo.thumbnail((size, size), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(logo, ((size - logo.width) // 2, (size - logo.height) // 2), logo)
    return canvas


def full_square(size: int, fill: float) -> Image.Image:
    """Logo sobre fundo branco sem cantos (o sistema recorta: iOS e ícone maskable)."""
    return Image.alpha_composite(Image.new("RGBA", (size, size), BACKGROUND), logo_fitted(size, fill))


def build_web() -> None:
    icons = WEB / "icons"
    icons.mkdir(parents=True, exist_ok=True)
    ball(64).save(WEB / "favicon.png", optimize=True)
    for size in (192, 512):
        legacy(size).save(icons / f"icon-{size}.png", optimize=True)
    # Maskable: a logo fica nos 62% centrais (área segura de 80% com folga).
    full_square(512, 0.62).save(icons / "icon-maskable-512.png", optimize=True)
    full_square(180, 0.84).convert("RGB").save(icons / "apple-touch-icon.png", optimize=True)


def main() -> None:
    build_web()

    for name, scale in DENSITIES.items():
        folder = RES / f"mipmap-{name}"
        folder.mkdir(parents=True, exist_ok=True)
        legacy(round(48 * scale)).save(folder / "ic_launcher.png", optimize=True)
        # Camada da frente: 108dp, com a logo nos 66dp centrais (área segura).
        logo_fitted(round(108 * scale), 0.62).save(folder / "ic_launcher_foreground.png", optimize=True)

    adaptive = RES / "mipmap-anydpi-v26"
    adaptive.mkdir(exist_ok=True)
    (adaptive / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        "</adaptive-icon>\n"
    )
    values = RES / "values"
    (values / "ic_launcher_background.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<resources>\n"
        '    <color name="ic_launcher_background">#FFFFFF</color>\n'
        "</resources>\n"
    )
    print("Ícones gerados em", RES)


if __name__ == "__main__":
    main()
