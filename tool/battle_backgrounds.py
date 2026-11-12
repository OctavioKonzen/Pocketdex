"""Cenários da batalha desenhados por código, no estilo das imagens de
referência do usuário e em pixel art como no Black & White (256×192, a tela
do DS, com poucas cores; o site e o app ampliam sem suavizar): 4:3, horizonte por volta de 1/3 da altura, profundidade
(o que está longe mais claro e desfocado, o que está perto mais escuro e
detalhado) e as duas bases azuis com anéis pixelados nos mesmos lugares (a do
adversário lá atrás à direita, a sua grande na frente à esquerda).

Cada lugar sai em 5 versões: sem clima e com sol, chuva, areia e neve
(granizo usa a de neve), porque golpes como Sunny Day e Rain Dance mudam o
cenário: assets/database/sprites/battle/<lugar>.webp e
assets/database/sprites/battle-weather/<lugar>-<clima>.webp (fora do APK: o app
baixa do site quando o clima muda; sem internet, fica a normal).
As bases ficam à parte (<lugar>-base-foe.webp e <lugar>-base-mine.webp): o site e
o app desenham uma embaixo de cada Pokémon, do tamanho dele.

Uso: python3 tool/battle_backgrounds.py [lugar ...]          (sem nada: todos)
     SHEET=folha.png python3 tool/battle_backgrounds.py      (+ folha com todos)
     WEATHERS=0 python3 tool/battle_backgrounds.py grass     (só sem clima)

As bases: iguais a PLATFORMS.bw (web-site/src/components/BattleScene.jsx e
lib/widgets/battle_scene.dart), em frações da imagem.
"""

import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

W, H = 800, 597
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'database', 'sprites', 'battle')
OUT_WEATHER = os.path.join(os.path.dirname(__file__), '..', 'assets', 'database', 'sprites', 'battle-weather')
FOE = (0.761, 0.393, 0.241, 0.066)
MINE = (0.462, 0.80, 0.525, 0.20)
HORIZON = int(H * 0.36)
# A pixel art: o tamanho da tela do DS e quantas cores.
PIXEL = (256, 192)
COLORS = 72
WEATHERS = ['sun', 'rain', 'sand', 'snow']


# ------------------------------------------------------------ ferramentas

def rgb(h):
    h = h.lstrip('#')
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32)


def mix(a, b, t):
    return a + (b - a) * t


# O céu de cada lugar (o primeiro degradê que ele pinta): os climas trocam só ele.
SKY = []
# Onde começa o chão de cada lugar (o último ground() desenhado: o piso onde os Pokémon pisam).
FLOOR = []


def vgrad(stops, y0=0, y1=H):
    """Degradê vertical: stops = [(0..1, cor), ...] de y0 a y1 (fora disso, a cor da ponta)."""
    t = np.clip((np.arange(H, dtype=np.float32) - y0) / max(1, y1 - y0), 0, 1)
    out = np.zeros((H, 3), np.float32)
    for (p0, c0), (p1, c1) in zip(stops, stops[1:]):
        sel = (t >= p0) & (t <= p1)
        k = ((t[sel] - p0) / max(1e-6, p1 - p0))[:, None]
        out[sel] = c0 + (c1 - c0) * k
    full = np.repeat(out[:, None, :], W, axis=1)
    if not SKY:
        SKY.append(full)
    return full


def noise(cells, seed, octaves=4, stretch=1.0, w=W, h=H):
    """Ruído suave 0-1 (oitavas). stretch > 1 estica na horizontal (chão em perspectiva)."""
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w), np.float32)
    amp = tot = 0.0
    amp = 1.0
    for o in range(octaves):
        cw = max(2, int(cells * 2 ** o / stretch))
        ch = max(2, int(cells * 2 ** o * h / w))
        small = Image.fromarray((rng.random((ch, cw)) * 255).astype(np.uint8))
        out += np.asarray(small.resize((w, h), Image.BICUBIC), np.float32) / 255 * amp
        tot += amp
        amp *= 0.55
    out /= tot
    return (out - out.min()) / max(1e-6, out.max() - out.min())


def mask(fn, blur=0):
    m = Image.new('L', (W, H), 0)
    fn(ImageDraw.Draw(m))
    if blur:
        m = m.filter(ImageFilter.GaussianBlur(blur))
    return np.asarray(m, np.float32) / 255


def put(a, color, m):
    """Pinta color (cor ou imagem H×W×3) por cima de a com a máscara m (0-1)."""
    return a * (1 - m[..., None]) + (color if isinstance(color, np.ndarray) and color.ndim == 3 else np.asarray(color, np.float32)) * m[..., None]


def layer(a, fn, blur=0, opacity=1.0):
    """Desenha em RGBA (cores com alfa) e junta em a."""
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    fn(ImageDraw.Draw(im))
    if blur:
        im = im.filter(ImageFilter.GaussianBlur(blur))
    arr = np.asarray(im, np.float32)
    m = arr[..., 3] / 255 * opacity
    return put(a, arr[..., :3], m)


def glow(a, x, y, r, color, strength=0.8):
    m = mask(lambda d: d.ellipse([x - r, y - r, x + r, y + r], fill=255), r * 0.7)
    return a + np.asarray(color, np.float32) * (m * strength)[..., None]


def ridge(seed, y, amp, rough=0.5, step=8, freq=2.0):
    rnd = random.Random(seed)
    pts, drift = [], 0.0
    ph = rnd.uniform(0, 6)
    for x in range(-step * 2, W + step * 3, step):
        drift = drift * 0.9 + rnd.uniform(-1, 1) * rough
        base = 0.5 + 0.5 * math.sin(x / W * math.pi * freq + ph) * 0.8 + 0.2 * math.sin(x / W * math.pi * freq * 3.1 + ph * 2)
        pts.append((x, y - amp * base - drift * amp * 0.35))
    return pts


def mountains(a, seed, y, amp, top, bottom, haze=None, haze_k=0.0, rough=0.5, step=8, freq=2.0, blur=0, tex=0.12, snowcap=None):
    """Cordilheira: degradê de cima (luz) para baixo, textura e névoa de distância."""
    pts = ridge(seed, y, amp, rough, step, freq)
    m = mask(lambda d: d.polygon(pts + [(W + 40, H), (-40, H)], fill=255), blur)
    g = vgrad([(0, top), (1, bottom)], int(y - amp * 1.3), int(y + amp * 0.4))
    g = g * (1 + (noise(14, seed + 1, 4, 1.4) - 0.5)[..., None] * tex * 2)
    if snowcap is not None:
        # Neve só perto dos picos: até um quarto da altura abaixo da crista.
        xs = np.array([p[0] for p in pts], np.float32)
        top_y = np.interp(np.arange(W, dtype=np.float32), xs, np.array([p[1] for p in pts], np.float32))
        near = (np.arange(H, dtype=np.float32)[:, None] < top_y[None, :] + amp * 0.28) & (top_y[None, :] < y - amp * 0.55)
        cap = near.astype(np.float32) * (noise(20, seed + 2, 3) > 0.3)
        g = put(g, snowcap, cap * 0.9)
    if haze is not None:
        g = mix(g, haze, haze_k)
    return put(a, g, m)


def ground(a, top, far, near, seed, stretch=4.0, tex=0.14, cells=10, spots=None):
    """O chão do horizonte (top) até embaixo, com textura esticada (perspectiva) e manchas."""
    FLOOR.append(top)
    g = vgrad([(0, far), (1, near)], top, H)
    n1 = noise(cells, seed, 5, stretch) - 0.5
    n2 = noise(cells * 4, seed + 1, 3, stretch * 1.6) - 0.5
    g = g * (1 + (n1 * tex * 2 + n2 * tex)[..., None])
    if spots is not None:
        g = put(g, spots[0], np.clip((noise(6, seed + 2, 3, stretch) - 0.55) * 3, 0, 1) * spots[1])
    m = np.clip((np.arange(H, dtype=np.float32)[:, None] - (top - 6)) / 12, 0, 1) * np.ones((1, W), np.float32)
    return put(a, g, m)


def rocks(a, seed, n, y0, y1, base, light, dark, smin=10, smax=40):
    """Pedras com face iluminada (em cima à esquerda) e sombra embaixo; maiores quanto mais perto."""
    rnd = random.Random(seed)
    items = sorted([(rnd.uniform(-20, W + 20), rnd.uniform(y0, y1)) for _ in range(n)], key=lambda p: p[1])

    def fn(d):
        for x, y in items:
            s = smin + (smax - smin) * (y - y0) / max(1, y1 - y0) * rnd.uniform(0.6, 1.2)
            d.ellipse([x - s * 1.2, y - s * 0.12, x + s * 1.2, y + s * 0.22], fill=tuple(int(v) for v in dark) + (140,))
            pts = [(x - s, y), (x - s * 0.7, y - s * 0.7), (x - s * 0.1, y - s * rnd.uniform(0.9, 1.2)), (x + s * 0.6, y - s * 0.6), (x + s, y)]
            d.polygon(pts, fill=tuple(int(v) for v in base) + (255,))
            d.polygon([pts[0], pts[1], pts[2], (x, y - s * 0.3)], fill=tuple(int(v) for v in light) + (255,))
            d.line(pts[2:], fill=tuple(int(v) for v in dark) + (200,), width=max(1, int(s / 12)))
    return layer(a, fn)


def canopy(d, x, y, size, dark, mid, light, rnd):
    """Copa de árvore: bolhas sobrepostas, escura embaixo, borda iluminada em cima à esquerda."""
    blobs = [(rnd.uniform(-0.7, 0.7) * size, rnd.uniform(-1.0, 0.2) * size, rnd.uniform(0.32, 0.6) * size) for _ in range(12)]
    for ox, oy, r in blobs:
        d.ellipse([x + ox - r, y + oy - r, x + ox + r, y + oy + r], fill=dark)
    for ox, oy, r in blobs:
        d.ellipse([x + ox - r * 0.85 - r * 0.12, y + oy - r * 0.85 - r * 0.15, x + ox + r * 0.6, y + oy + r * 0.5], fill=mid)
    for ox, oy, r in blobs[:6]:
        d.ellipse([x + ox - r * 0.7, y + oy - r * 0.8, x + ox - r * 0.05, y + oy - r * 0.2], fill=light)


def treeline(a, seed, y, size, colors, gap=1.0, trunk=(40, 30, 24), blur=0, haze=None, haze_k=0.0):
    rnd = random.Random(seed)
    dark, mid, light = [tuple(int(v) for v in mix(np.asarray(c, np.float32), haze, haze_k)) + (255,) if haze is not None else tuple(int(v) for v in c) + (255,) for c in colors]

    def fn(d):
        x = -size
        while x < W + size:
            s = size * rnd.uniform(0.75, 1.25)
            d.rectangle([x - s * 0.07, y - s * 0.3, x + s * 0.07, y + s * 0.15], fill=trunk + (255,))
            canopy(d, x, y - s * 0.55, s, dark, mid, light, rnd)
            x += s * gap * rnd.uniform(0.8, 1.15)
    return layer(a, fn, blur)


def pine(d, x, y, h, dark, light, snow=None):
    w = h * 0.4
    d.rectangle([x - h * 0.03, y - h * 0.12, x + h * 0.03, y], fill=(50, 36, 28, 255))
    for i in range(5):
        t = i / 5
        top = y - h + h * t * 0.78
        hw = w * (0.35 + t * 0.65)
        d.polygon([(x, top), (x - hw, top + h * 0.3), (x + hw, top + h * 0.3)], fill=dark)
        d.polygon([(x, top), (x - hw, top + h * 0.3), (x - hw * 0.2, top + h * 0.26)], fill=light)
        if snow:
            d.polygon([(x, top), (x - hw * 0.7, top + h * 0.2), (x + hw * 0.6, top + h * 0.18)], fill=snow)


def blades(a, seed, n, y0, y1, cols, lean=0.3):
    """Folhas de grama: mais altas e grossas perto (embaixo)."""
    rnd = random.Random(seed)

    def fn(d):
        for _ in range(n):
            x, y = rnd.uniform(-10, W + 10), rnd.uniform(y0, y1)
            k = (y - y0) / max(1, y1 - y0)
            s = 3 + k * 22
            c = cols[rnd.randrange(len(cols))]
            dx = rnd.uniform(-lean, lean) * s
            d.polygon([(x - s * 0.08, y), (x + dx, y - s), (x + s * 0.08, y)], fill=tuple(int(v) for v in c) + (230,))
    return layer(a, fn)


def motes(a, seed, n, area, color, rmax=2.5, blur=1.0, alpha=255):
    rnd = random.Random(seed)

    def fn(d):
        for _ in range(n):
            x, y, r = rnd.uniform(area[0], area[2]), rnd.uniform(area[1], area[3]), rnd.uniform(0.6, rmax)
            d.ellipse([x - r, y - r, x + r, y + r], fill=tuple(int(v) for v in color) + (rnd.randint(alpha // 2, alpha),))
    return layer(a, fn, blur)


def reflect(a, y0, y1, k=0.35, blur=4):
    """Reflexo do que está acima de y0 numa faixa (água, chão molhado)."""
    h = y1 - y0
    src = a[max(0, y0 - h):y0][::-1]
    if src.shape[0] < h:
        return a
    im = Image.fromarray(np.clip(src, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(blur))
    out = a.copy()
    fade = np.linspace(k, 0, h, dtype=np.float32)[:, None, None]
    out[y0:y1] = out[y0:y1] * (1 - fade) + np.asarray(im, np.float32) * fade
    return out


def moon(a, x, y, r, color=(235, 240, 255)):
    a = glow(a, x, y, r * 4, np.asarray(color) * 0.25, 1.0)
    return layer(a, lambda d: d.ellipse([x - r, y - r, x + r, y + r], fill=tuple(color) + (255,)), 0.6)


def stars(a, seed, n, y1):
    return motes(a, seed, n, (0, 0, W, y1), (255, 255, 255), 1.4, 0.3)


# ------------------------------------------------------------ as bases (como nas imagens de referência)

def platform(a, spec, scale=3):
    cx, cy, rx, ry = spec
    w, h = W // scale, H // scale
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    X, Y, RX, RY = cx * w, cy * h, rx * w, ry * h
    edge, mid, center, outline = (34, 92, 156), (58, 136, 202), (140, 204, 248), (22, 62, 116)
    d.ellipse([X - RX, Y - RY, X + RX, Y + RY], fill=outline + (255,))
    rings = 16
    for k in range(rings):
        t = k / (rings - 1)
        f = 1 - t * 0.97
        if t < 0.6:
            c = mix(np.array(edge, np.float32), np.array(mid, np.float32), t / 0.6)
        else:
            c = mix(np.array(mid, np.float32), np.array(center, np.float32), (t - 0.6) / 0.4)
        oy = -RY * 0.05 * t
        d.ellipse([X - (RX - 1.3) * f, Y + oy - (RY - 1.1) * f, X + (RX - 1.3) * f, Y + oy + (RY - 1.1) * f], fill=tuple(int(v) for v in c) + (255,))
    big = np.asarray(im.resize((W, H), Image.NEAREST), np.float32)
    return put(a, big[..., :3], big[..., 3] / 255)


def finish(a, grain_seed=1):
    """Vinheta, grão e um pouco de nitidez (acabamento pintado)."""
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    v = 1 - 0.28 * (((xx - W / 2) / (W / 2)) ** 2 * 0.6 + ((yy - H / 2) / (H / 2)) ** 2 * 0.4)
    a = a * np.clip(v, 0.6, 1)[..., None]
    a = a + (np.random.default_rng(grain_seed).random((H, W, 1), np.float32) - 0.5) * 6
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).filter(ImageFilter.UnsharpMask(1.2, 60, 2))
    return im


# ------------------------------------------------------------ climas

def lum(a):
    return (a[..., 0] * 0.3 + a[..., 1] * 0.59 + a[..., 2] * 0.11)[..., None]


def sky_mask(scene, a):
    """Onde ainda se vê o céu (igual ao degradê do céu e acima do horizonte do lugar)."""
    y = scene.get('sky', HORIZON)
    band = np.clip((y - np.arange(H, dtype=np.float32)[:, None]) / 30, 0, 1) * np.ones((1, W), np.float32)
    same = np.clip(1 - (np.abs(a - SKY[0]).sum(axis=2) - 25) / 60, 0, 1) if SKY else 1
    return band * same


# Os lugares fechados de pedra (cavernas, grutas, esgoto): lá dentro o clima chega como goteira, poeira ou geada.
CAVES = {'cave', 'icecave', 'lavacave', 'poisoncave', 'seacave', 'crystal', 'waterfall', 'seafoam', 'sewer', 'dragonsden', 'origin', 'whirl'}


def window_mask(scene):
    """As janelas do lugar (silph, radio...): é por elas que se vê o clima lá de fora."""
    m = np.zeros((H, W), np.float32)
    for x0, y0, x1, y1 in scene.get('windows', ()):
        m[int(y0):int(y1), int(x0):int(x1)] = 1
    return m


def frost(a, seed, k=0.6):
    """Geada pelas bordas (o frio entrando num lugar fechado)."""
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    edge = np.clip(np.maximum(np.abs(xx - W / 2) / (W / 2), np.abs(yy - H / 2) / (H / 2)) * 1.25 - 0.62, 0, 1)
    return put(a, rgb('eaf4ff'), edge * (0.55 + 0.45 * noise(8, seed, 4, 1.5)) * k)


def weather_indoor(a, w, scene):
    """O clima num lugar fechado tem de fazer sentido: num prédio não chove nem neva lá dentro (vê-se pelas janelas,
    e a luz e o ar mudam); numa caverna chega como goteira e poça, poeira no ar ou geada e flocos pela entrada."""
    seed = scene.get('seed', 1)
    if scene.get('name') == 'underwater':
        # No fundo do mar o clima é o da superfície: a luz que desce muda (sol forte, céu fechado, areia revolvida, gelo em cima).
        if w == 'sun':
            a = a * np.array([1.08, 1.06, 0.96], np.float32) + 8
            a = layer(a, lambda d: [d.polygon([(x, -10), (x + 50, -10), (x - 90, H * 0.8), (x - 170, H * 0.8)], fill=(255, 246, 200, 40)) for x in (180, 420, 660)], 12)
        elif w == 'rain':
            a = mix(a, lum(a), 0.3) * np.array([0.74, 0.8, 0.9], np.float32)
        elif w == 'sand':
            a = put(a * np.array([1.02, 0.96, 0.84], np.float32), rgb('b89a6a'), 0.12 + noise(4, seed + 80, 4, 2.2) * 0.25)
        elif w == 'snow':
            a = mix(a, lum(a), 0.3) * np.array([0.9, 0.97, 1.08], np.float32) + 6
            a = put(a, rgb('e6f2ff'), np.clip(1 - np.arange(H, dtype=np.float32)[:, None] / 70, 0, 1) * np.ones((1, W), np.float32) * 0.7)
        return np.clip(a, 0, 255)
    cave = scene.get('name') in CAVES
    win = window_mask(scene)
    has_win = bool(win.any())
    rnd = random.Random(seed + 70)
    if w == 'sun':
        a = a * np.array([1.10, 1.04, 0.90], np.float32) + 8
        if has_win:
            # O sol entra pelas janelas: o céu claro lá fora e a luz no chão.
            a = put(a, vgrad([(0, rgb('ffd28a')), (1, rgb('fff0c8'))], 0, HORIZON), win * 0.45)
            for x0, y0, x1, y1 in scene['windows']:
                a = glow(a, (x0 + x1) / 2, y1 + 70, (x1 - x0) * 0.8, (255, 226, 160), 0.35)
        elif cave:
            # Um facho de sol por uma fresta no teto.
            a = layer(a, lambda d: d.polygon([(W * 0.62, -10), (W * 0.74, -10), (W * 0.52, H * 0.7), (W * 0.30, H * 0.7)], fill=(255, 236, 180, 46)), 14)
            a = glow(a, W * 0.42, H * 0.68, 150, (255, 230, 170), 0.3)
        else:
            a = glow(a, W * 0.5, -40, W * 0.45, (255, 190, 110), 0.5)
    elif w == 'rain':
        a = mix(a, lum(a), 0.3) * np.array([0.78, 0.82, 0.92], np.float32)
        if has_win:
            clouds = vgrad([(0, rgb('2e3644')), (1, rgb('566274'))], 0, HORIZON)
            a = put(a, clouds, win * 0.7)
            drops = mask(lambda d: [d.line([(x, y), (x - 4, y + L)], fill=255, width=1) for x, y, L in [(rnd.uniform(0, W), rnd.uniform(0, HORIZON + 20), rnd.uniform(10, 26)) for _ in range(1400)]])
            a = put(a, rgb('c8d7f0'), drops * win * 0.55)
        elif cave:
            # Goteiras do teto e as poças no chão.
            a = layer(a, lambda d: [d.line([(x, y), (x, y + L)], fill=(190, 212, 240, 120), width=1) for x, y, L in [(rnd.uniform(0, W), rnd.uniform(-10, H * 0.8), rnd.uniform(8, 20)) for _ in range(70)]])
            a = layer(a, lambda d: [d.ellipse([x - s, y - s * 0.12, x + s, y + s * 0.12], fill=(150, 176, 210, 120)) for x, y, s in [(rnd.uniform(0, W), rnd.uniform(HORIZON + 40, H), rnd.uniform(20, 80)) for _ in range(14)]], 2)
    elif w == 'sand':
        a = a * np.array([1.04, 0.96, 0.82], np.float32)
        haze = noise(4, seed + 80, 4, 2.2)
        if has_win:
            a = put(a, rgb('c89a5e'), win * (0.5 + haze * 0.3))
            a = put(a, rgb('d2a468'), (1 - win) * 0.1)
        elif cave:
            # A poeira que o vento traz pela entrada e a areia juntando no chão.
            gnd = 1 - np.clip((HORIZON + 40 - np.arange(H, dtype=np.float32)[:, None]) / 60, 0, 1) * np.ones((1, W), np.float32)
            a = put(a, rgb('d2a468'), 0.14 + haze * 0.22)
            a = put(a, rgb('c9a06a'), np.clip((noise(9, seed + 82, 5, 3.0) - 0.5) * 3, 0, 1) * gnd * 0.5)
            a = motes(a, seed + 81, 120, (0, 0, W, H), (240, 210, 160), 1.8, 0.8)
        else:
            a = put(a, rgb('d2a468'), 0.1 + haze * 0.08)
    elif w == 'snow':
        a = mix(a, lum(a), 0.3) * np.array([0.93, 0.97, 1.07], np.float32) + 8
        if has_win:
            a = put(a, vgrad([(0, rgb('9aa8bc')), (1, rgb('dfe7f2'))], 0, HORIZON), win * 0.75)
            flakes = mask(lambda d: [d.ellipse([x - r, y - r, x + r, y + r], fill=255) for x, y, r in [(rnd.uniform(0, W), rnd.uniform(0, HORIZON + 20), rnd.uniform(0.8, 2.2)) for _ in range(900)]])
            a = put(a, rgb('ffffff'), flakes * win * 0.9)
            a = frost(a, seed + 92, 0.35)
        elif cave:
            # A geada cobrindo o chão e uns flocos entrando com o vento.
            gnd = 1 - np.clip((HORIZON + 30 - np.arange(H, dtype=np.float32)[:, None]) / 50, 0, 1) * np.ones((1, W), np.float32)
            a = put(a, rgb('eef4ff'), np.clip((noise(9, seed + 90, 5, 3.0) - 0.45) * 3.2, 0, 1) * gnd * 0.6)
            a = frost(a, seed + 92, 0.45)
            a = motes(a, seed + 91, 70, (0, 0, W, H), (255, 255, 255), 2.2, 0.6)
        else:
            a = frost(a, seed + 92, 0.6)
    return np.clip(a, 0, 255)


def weather(a, w, scene):
    out = scene.get('outdoor', True)
    if not out:
        return weather_indoor(a, w, scene)
    sky = sky_mask(scene, a) if out else np.zeros((H, W), np.float32)
    gnd = 1 - np.clip((HORIZON - np.arange(H, dtype=np.float32)[:, None]) / 30, 0, 1) * np.ones((1, W), np.float32)
    seed = scene.get('seed', 1)
    if w == 'sun':
        a = put(a, vgrad([(0, rgb('ffb45a')), (1, rgb('ffe3a8'))], 0, HORIZON), sky * 0.55)
        a = a * np.array([1.12, 1.04, 0.86], np.float32) + 10
        if out:
            a = glow(a, W * 0.84, H * 0.08, W * 0.2, (255, 200, 120), 0.9)
            a = glow(a, W * 0.84, H * 0.08, W * 0.05, (255, 255, 230), 1.6)
            a = layer(a, lambda d: [d.polygon([(W * 0.84, H * 0.08), (W * 0.84 - 900 * math.cos(t), H * 0.08 + 900 * math.sin(t)), (W * 0.84 - 900 * math.cos(t + 0.05), H * 0.08 + 900 * math.sin(t + 0.05))], fill=(255, 240, 200, 26)) for t in (0.5, 0.75, 1.0, 1.3, 1.6, 2.0)], 6)
        else:
            a = glow(a, W * 0.5, -40, W * 0.45, (255, 190, 110), 0.5)
    elif w == 'rain':
        a = mix(a, lum(a), 0.45) * np.array([0.66, 0.72, 0.84], np.float32)
        if out:
            clouds = vgrad([(0, rgb('3b4552')), (1, rgb('6a7686'))], 0, HORIZON) * (0.85 + 0.3 * noise(5, seed + 70, 4, 1.8))[..., None]
            a = put(a, clouds, sky * 0.85)
            rnd = random.Random(seed + 71)
            a = layer(a, lambda d: [d.ellipse([x - s, y - s * 0.1, x + s, y + s * 0.1], fill=(150, 170, 200, 120)) for x, y, s in [(rnd.uniform(0, W), rnd.uniform(HORIZON + 30, H), rnd.uniform(20, 90)) for _ in range(18)]], 2)
        rnd = random.Random(seed + 72)
        a = layer(a, lambda d: [d.line([(x, y), (x - 6, y + L)], fill=(200, 215, 240, 90), width=1) for x, y, L in [(rnd.uniform(0, W + 40), rnd.uniform(-20, H), rnd.uniform(14, 34)) for _ in range(900 if out else 250)]])
    elif w == 'sand':
        haze = noise(4, seed + 80, 4, 2.2)
        a = a * np.array([1.05, 0.94, 0.76], np.float32)
        a = put(a, rgb('d2a468'), (0.25 + haze * 0.35) * (0.7 + 0.3 * sky))
        rnd = random.Random(seed + 81)
        a = layer(a, lambda d: [d.line([(x, y), (x + L, y + L * 0.08)], fill=(240, 200, 140, 110), width=rnd.choice((1, 2))) for x, y, L in [(rnd.uniform(-80, W), rnd.uniform(0, H), rnd.uniform(30, 120)) for _ in range(260)]], 0.6)
    elif w == 'snow':
        a = mix(a, lum(a), 0.4) * np.array([0.92, 0.97, 1.08], np.float32) + 12
        if out:
            a = put(a, vgrad([(0, rgb('8c9bb0')), (1, rgb('c9d4e2'))], 0, HORIZON), sky * 0.7)
            cover = np.clip((noise(9, seed + 90, 5, 3.0) - 0.42) * 3.5, 0, 1) * gnd
            a = put(a, rgb('eef4ff'), cover * 0.75)
        a = motes(a, seed + 91, 260, (0, 0, W, H), (255, 255, 255), 2.6, 0.6)
    return np.clip(a, 0, 255)


# ------------------------------------------------------------ lugares
# Cada um devolve (imagem sem as bases, {outdoor, sky, seed}).

def grass():
    a = vgrad([(0, rgb('2d5fa8')), (0.55, rgb('7fb3e6')), (1, rgb('d8ecff'))], 0, HORIZON)
    a = layer(a, lambda d: [d.ellipse([x - 90, y - 18, x + 90, y + 18], fill=(255, 255, 255, 150)) for x, y in ((120, 60), (380, 40), (640, 80), (760, 30))], 14)
    a = mountains(a, 3, HORIZON - 30, 70, rgb('9db7d8'), rgb('7d9cc0'), rgb('c8dcf2'), 0.5, 0.5, 10, blur=2)
    a = treeline(a, 5, HORIZON + 4, 34, ((40, 92, 60), (60, 124, 70), (110, 170, 96)), 1.0, haze=rgb('a8c8e0'), haze_k=0.35, blur=0.8)
    a = ground(a, HORIZON, rgb('7dc062'), rgb('3b7f2f'), 11, 5, 0.14, spots=(rgb('9a8a5a'), 0.35))
    a = rocks(a, 12, 6, HORIZON + 20, H * 0.62, rgb('8a8a80'), rgb('b8b8aa'), rgb('3a3a34'), 6, 22)
    a = blades(a, 13, 1400, HORIZON + 10, H + 10, [rgb('2f6b28'), rgb('4f9a3c'), rgb('86c860'), rgb('3d8030')])
    a = layer(a, lambda d: [d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=c + (255,)) for x, y, c in [(random.Random(i).uniform(0, W), random.Random(i + 99).uniform(HORIZON + 30, H), ((255, 240, 120), (255, 255, 255), (255, 150, 200))[i % 3]) for i in range(70)]])
    return a, {'outdoor': True, 'seed': 10}


def forest():
    a = vgrad([(0, rgb('0c1a2e')), (1, rgb('25456a'))], 0, HORIZON + 40)
    a = moon(a, W * 0.72, 50, 18)
    a = stars(a, 21, 60, HORIZON - 40)
    for i, (y, s, k) in enumerate(((HORIZON - 20, 50, 0.65), (HORIZON + 10, 70, 0.4))):
        a = treeline(a, 22 + i, y, s, ((14, 40, 40), (24, 64, 58), (50, 104, 90)), 0.95, haze=rgb('2a4f78'), haze_k=k, blur=2 - i)
    # Cachoeira e lago lá no fundo.
    a = layer(a, lambda d: (d.rectangle([W * 0.6, HORIZON - 80, W * 0.66, HORIZON + 10], fill=(150, 200, 240, 220)), d.ellipse([W * 0.45, HORIZON - 4, W * 0.85, HORIZON + 26], fill=(60, 110, 170, 230))), 2)
    a = glow(a, W * 0.63, HORIZON - 20, 60, (80, 140, 220), 0.4)
    a = ground(a, HORIZON + 14, rgb('2f5a4a'), rgb('16302a'), 23, 4, 0.18, spots=(rgb('4a4232'), 0.4))
    # Troncos grossos dos lados (perto).
    a = layer(a, lambda d: (d.polygon([(0, 0), (90, 0), (120, HORIZON + 90), (60, HORIZON + 110), (0, HORIZON + 100)], fill=(30, 36, 40, 255)), d.polygon([(W - 70, 0), (W, 0), (W, HORIZON + 80), (W - 100, HORIZON + 70)], fill=(28, 34, 38, 255))))
    a = treeline(a, 25, -10, 90, ((16, 44, 40), (26, 70, 60), (48, 104, 86)), 0.8)
    a = rocks(a, 26, 7, HORIZON + 30, H * 0.6, rgb('3a4a50'), rgb('5a7078'), rgb('101818'), 8, 26)
    # Cogumelos brilhando.
    rnd = random.Random(27)
    spots = [(rnd.uniform(0, W * 0.4), rnd.uniform(HORIZON + 40, H * 0.5)) for _ in range(6)] + [(rnd.uniform(W * 0.8, W), rnd.uniform(HORIZON + 20, H * 0.45)) for _ in range(4)]
    for x, y in spots:
        a = glow(a, x, y - 6, 22, (60, 160, 255), 0.5)
    a = layer(a, lambda d: [(d.rectangle([x - 1.5, y - 10, x + 1.5, y], fill=(170, 220, 255, 255)), d.pieslice([x - 9, y - 18, x + 9, y - 4], 180, 360, fill=(110, 200, 255, 255))) for x, y in spots])
    a = blades(a, 28, 900, HORIZON + 20, H + 10, [rgb('1f4a3a'), rgb('2f6a50'), rgb('4a8a62')])
    a = motes(a, 29, 50, (0, HORIZON - 120, W, H * 0.7), (120, 200, 255), 2.4, 1.5)
    return a, {'outdoor': True, 'sky': HORIZON - 60, 'seed': 20}


def water():
    a = vgrad([(0, rgb('2a6fc0')), (1, rgb('bfe2ff'))], 0, HORIZON)
    a = layer(a, lambda d: [d.ellipse([x - 110, y - 20, x + 110, y + 20], fill=(255, 255, 255, 170)) for x, y in ((140, 70), (420, 50), (700, 90))], 16)
    a = mountains(a, 31, HORIZON - 4, 34, rgb('8aa8c8'), rgb('6f8fb0'), rgb('bcd6ee'), 0.4, 0.4, 12, blur=2.5)
    a = ground(a, HORIZON, rgb('6fb8e8'), rgb('1a5a96'), 32, 9, 0.08)
    a = reflect(a, HORIZON, HORIZON + 50, 0.4, 3)
    rnd = random.Random(33)

    def waves(d):
        for _ in range(700):
            y = rnd.uniform(HORIZON + 4, H)
            k = (y - HORIZON) / (H - HORIZON)
            s = 6 + k * 70
            x = rnd.uniform(-40, W)
            d.arc([x, y - s * 0.12, x + s, y + s * 0.12], 200, 340, fill=(235, 250, 255, int(90 + 110 * k)), width=max(1, int(s / 22)))
    a = layer(a, waves, 0.5)
    a = motes(a, 34, 120, (0, HORIZON, W, H), (255, 255, 255), 1.8, 0.4)
    return a, {'outdoor': True, 'seed': 30}


def beach():
    a = vgrad([(0, rgb('2f8fe0')), (1, rgb('d4f0ff'))], 0, HORIZON - 30)
    a = layer(a, lambda d: [d.ellipse([x - 100, y - 18, x + 100, y + 18], fill=(255, 255, 255, 190)) for x, y in ((160, 50), (500, 35), (760, 70))], 14)
    a = ground(a, HORIZON - 30, rgb('5ec0ee'), rgb('2a8ad0'), 41, 10, 0.06)
    a = ground(a, HORIZON + 16, rgb('f6e2b0'), rgb('d6b070'), 42, 5, 0.12, spots=(rgb('c49a5a'), 0.3))
    a = layer(a, lambda d: (d.line(ridge(3, HORIZON + 18, 4, 0.8, 12), fill=(255, 255, 255, 230), width=6), d.line(ridge(4, HORIZON + 28, 3, 0.8, 12), fill=(255, 255, 255, 120), width=3)), 1.2)

    def palm(d, x, y, h, flip):
        pts = [(x + math.sin(t / 10 * 1.6) * 22 * flip, y - h * t / 10) for t in range(11)]
        for i in range(10):
            d.line([pts[i], pts[i + 1]], fill=(120, 86, 52, 255) if i % 2 else (98, 68, 40, 255), width=int(h * 0.065 * (1 - i / 16)))
        tx, ty = pts[-1]
        for ang in range(0, 360, 36):
            r = math.radians(ang)
            for j, c in enumerate(((30, 100, 52), (52, 140, 70))):
                d.polygon([(tx, ty), (tx + math.cos(r) * h * 0.5, ty + abs(math.sin(r)) * h * 0.2 + h * 0.12 - j * 4), (tx + math.cos(r + 0.2) * h * 0.42, ty + abs(math.sin(r + 0.2)) * h * 0.18 + h * 0.06)], fill=c + (255,))
    a = layer(a, lambda d: (palm(d, 50, HORIZON + 60, 250, 1), palm(d, W - 40, HORIZON + 40, 280, -1)))
    a = rocks(a, 43, 5, HORIZON + 30, H * 0.6, rgb('a89a88'), rgb('d6cab4'), rgb('6a5a46'), 6, 18)
    a = layer(a, lambda d: [d.ellipse([x - 4, y - 2, x + 4, y + 2], fill=(255, 240, 230, 255)) for x, y in [(random.Random(i).uniform(0, W), random.Random(i * 7).uniform(HORIZON + 40, H)) for i in range(30)]])
    return a, {'outdoor': True, 'sky': HORIZON - 30, 'seed': 40}


def underwater():
    a = vgrad([(0, rgb('2e8ccc')), (0.45, rgb('125a98')), (1, rgb('062a52'))])
    a = layer(a, lambda d: [d.polygon([(x, -10), (x + 40, -10), (x + 170, H), (x + 70, H)], fill=(170, 230, 255, 40)) for x in (60, 260, 470, 650)], 22)
    a = mountains(a, 81, HORIZON + 10, 50, rgb('2c5a86'), rgb('1e4670'), rgb('1a5a90'), 0.5, 0.6, 10, blur=3)
    a = ground(a, HORIZON + 30, rgb('6a8aa8'), rgb('34506e'), 82, 4, 0.16, spots=(rgb('c8b88a'), 0.45))
    rnd = random.Random(83)

    def reef(d):
        for x in list(range(0, 220, 18)) + list(range(600, W, 20)):
            h = rnd.uniform(70, 200)
            col = ((40, 150, 100), (60, 170, 110), (200, 90, 120))[rnd.randrange(3)]
            pts = [(x + math.sin(t / 2 + x) * 9, HORIZON + 46 - h * t / 8) for t in range(9)]
            d.line(pts, fill=col + (255,), width=7)
        for x, y, s in ((80, HORIZON + 48, 50), (720, HORIZON + 40, 70), (380, HORIZON + 40, 28)):
            d.ellipse([x - s, y - s * 0.6, x + s, y + s * 0.3], fill=(52, 72, 96, 255))
            d.ellipse([x - s * 0.8, y - s * 0.6, x + s * 0.2, y - s * 0.1], fill=(80, 104, 130, 255))
    a = layer(a, reef, 0.8)
    a = layer(a, lambda d: [d.ellipse([x - r, y - r, x + r, y + r], outline=(220, 245, 255, 200), width=2) for x, y, r in [(rnd.uniform(0, W), rnd.uniform(0, H * 0.75), rnd.uniform(2, 8)) for _ in range(60)]])
    a = motes(a, 84, 120, (0, 0, W, H), (200, 240, 255), 1.4, 0.8, 140)
    return a, {'outdoor': False, 'seed': 80}


def swamp():
    a = vgrad([(0, rgb('1c2a26')), (1, rgb('5a7660'))], 0, HORIZON)
    a = moon(a, W * 0.3, 60, 14, (220, 235, 200))
    a = treeline(a, 51, HORIZON - 4, 40, ((34, 52, 40), (48, 70, 52), (70, 96, 70)), 1.1, haze=rgb('6a8a70'), haze_k=0.5, blur=2)
    a = ground(a, HORIZON, rgb('4f6644'), rgb('26331e'), 52, 4, 0.18, spots=(rgb('3a4a30'), 0.4))
    rnd = random.Random(53)
    pools = [(rnd.uniform(0, W), rnd.uniform(HORIZON + 20, H - 30), rnd.uniform(40, 150)) for _ in range(10)]
    a = layer(a, lambda d: [d.ellipse([x - w, y - w * 0.12, x + w, y + w * 0.12], fill=(58, 84, 70, 230)) for x, y, w in pools], 1.5)
    a = layer(a, lambda d: [d.ellipse([x - w * 0.6, y - w * 0.04, x + w * 0.2, y + w * 0.02], fill=(150, 180, 150, 110)) for x, y, w in pools], 1.5)

    def dead(d, x, y, h):
        d.polygon([(x - h * 0.05, y), (x + 2, y - h), (x + h * 0.04, y)], fill=(34, 30, 26, 255))
        for k in range(6):
            yy = y - h * (0.35 + k * 0.1)
            s = 1 if k % 2 else -1
            d.line([(x, yy), (x + s * h * 0.28, yy - h * 0.14), (x + s * h * 0.34, yy - h * 0.2)], fill=(34, 30, 26, 255), width=max(2, int(h * 0.02)))
    a = layer(a, lambda d: [dead(d, x, HORIZON + 8, h) for x, h in ((60, 230), (230, 140), (520, 120), (690, 180))], 1.2)
    a = layer(a, lambda d: [dead(d, x, y, h) for x, y, h in ((W - 40, H * 0.55, 280),)])
    fog = noise(5, 54, 4, 3)
    band = np.clip(1 - np.abs(np.arange(H, dtype=np.float32)[:, None] - HORIZON - 20) / 160, 0, 1)
    a = put(a, rgb('a7c09a'), np.clip((fog - 0.3) * 1.3, 0, 1) * band * 0.6)
    a = blades(a, 55, 600, HORIZON + 30, H + 10, [rgb('3a5030'), rgb('556a3e'), rgb('6a8048')], 0.15)
    a = motes(a, 56, 40, (0, HORIZON - 80, W, H * 0.7), (200, 255, 130), 2.2, 1.6)
    return a, {'outdoor': True, 'seed': 50}


def sewer():
    a = vgrad([(0, rgb('1a2024')), (1, rgb('353f44'))], 0, HORIZON + 40)
    rnd = random.Random(61)

    def bricks(d):
        for row in range(0, HORIZON + 50, 18):
            off = 0 if (row // 18) % 2 else 22
            for x in range(-44 + off, W, 44):
                c = 50 + rnd.randint(0, 22)
                d.rectangle([x + 2, row + 2, x + 42, row + 16], fill=(c, c + 6, c + 4, 255))
                d.line([(x + 2, row + 2), (x + 42, row + 2)], fill=(c + 18, c + 24, c + 22, 255))
    a = layer(a, bricks)
    a = put(a, rgb('0a0c0e'), mask(lambda d: (d.ellipse([W * 0.34, HORIZON - 150, W * 0.66, HORIZON + 90], fill=255), d.rectangle([W * 0.34, HORIZON - 30, W * 0.66, HORIZON + 50], fill=255)), 2))
    a = glow(a, W * 0.5, HORIZON - 10, 70, (60, 160, 120), 0.35)
    a = layer(a, lambda d: [(d.rectangle([x, 0, x + 24, HORIZON + 40], fill=(68, 86, 78, 255)), d.rectangle([x, 0, x + 6, HORIZON + 40], fill=(100, 122, 112, 255))) for x in (50, 730)] + [d.rectangle([0, 30, W, 46], fill=(62, 78, 72, 255))])
    a = layer(a, lambda d: [d.ellipse([x - 3, y, x + 3, y + 8], fill=(120, 200, 160, 200)) for x, y in ((70, 60), (300, 120), (560, 90), (742, 140))])
    a = ground(a, HORIZON + 40, rgb('4a5450'), rgb('222a28'), 62, 3, 0.16, spots=(rgb('3a4a3c'), 0.4))
    a = put(a, rgb('2f5446'), mask(lambda d: d.polygon([(W * 0.40, HORIZON + 40), (W * 0.60, HORIZON + 40), (W * 0.74, H * 0.55), (W * 0.28, H * 0.55)], fill=255), 2) * 0.9)
    a = reflect(a, HORIZON + 40, HORIZON + 90, 0.25, 4)
    a = layer(a, lambda d: [d.line([(W * 0.3 + i * 40, H * 0.5 + (i % 3) * 6), (W * 0.33 + i * 40, H * 0.5 + (i % 3) * 6)], fill=(150, 200, 180, 120), width=2) for i in range(11)], 1)
    return a, {'outdoor': False, 'seed': 60}


def cave():
    a = vgrad([(0, rgb('080c18')), (1, rgb('1e2a44'))], 0, HORIZON + 50)
    a = mountains(a, 71, HORIZON + 20, 120, rgb('2a3450'), rgb('161e30'), rgb('101828'), 0.2, 0.8, 10, freq=1.3)
    rnd = random.Random(72)
    a = layer(a, lambda d: [d.polygon([(x, -5), (x + w, -5), (x + w / 2 + rnd.uniform(-5, 5), rnd.uniform(40, 150))], fill=(24, 30, 46, 255)) for x, w in [(x, rnd.uniform(20, 44)) for x in range(-10, W, 30)]])
    a = put(a, rgb('05070c'), mask(lambda d: d.ellipse([W * 0.42, HORIZON - 120, W * 0.72, HORIZON + 30], fill=255), 18) * 0.85)
    for x, y, s in ((110, HORIZON + 10, 60), (700, HORIZON, 70), (520, HORIZON - 6, 30)):
        a = glow(a, x, y - s * 0.6, s * 1.2, (60, 140, 255), 0.6)
        a = layer(a, lambda d, x=x, y=y, s=s: [d.polygon([(x + k * s * 0.32, y), (x + k * s * 0.32 - s * 0.12, y - s * 0.4), (x + k * s * 0.32 + k * s * 0.12, y - s * (1.2 - abs(k) * 0.4)), (x + k * s * 0.32 + s * 0.12, y - s * 0.4)], fill=(150, 210, 255, 240)) for k in (-1, 0, 1)])
    a = ground(a, HORIZON + 24, rgb('3a4258'), rgb('1c2232'), 73, 4, 0.2, spots=(rgb('2a3448'), 0.5))
    a = put(a, rgb('2a4a78'), mask(lambda d: d.ellipse([W * 0.36, HORIZON + 18, W * 0.80, HORIZON + 46], fill=255), 3) * 0.8)
    a = rocks(a, 74, 9, HORIZON + 26, H * 0.6, rgb('3c465c'), rgb('5c6a86'), rgb('0c1018'), 10, 34)
    a = motes(a, 75, 40, (0, 0, W, H * 0.7), (120, 180, 255), 1.6, 1.2)
    return a, {'outdoor': False, 'seed': 70}


def icecave():
    a = vgrad([(0, rgb('0a1a36')), (1, rgb('2a5f96'))], 0, HORIZON + 40)
    a = mountains(a, 101, HORIZON + 20, 110, rgb('4a7ab8'), rgb('20406e'), rgb('1a3a66'), 0.25, 0.7, 12, freq=1.4)
    rnd = random.Random(102)
    a = layer(a, lambda d: [(d.polygon([(x, -5), (x + w, -5), (x + w / 2, h)], fill=(150, 210, 245, 235)), d.polygon([(x, -5), (x + w * 0.4, -5), (x + w / 2, h)], fill=(210, 240, 255, 235))) for x, w, h in [(x, rnd.uniform(18, 34), rnd.uniform(40, 170)) for x in range(-10, W, 24)]], 0.6)
    for x, y, s in ((90, HORIZON + 20, 90), (740, HORIZON + 10, 100), (470, HORIZON - 10, 40)):
        a = glow(a, x, y - s * 0.6, s * 1.3, (90, 180, 255), 0.55)
        a = layer(a, lambda d, x=x, y=y, s=s: [(d.polygon([(x + k * s * 0.32, y), (x + k * s * 0.32 - s * 0.12, y - s * 0.4), (x + k * s * 0.32 + k * s * 0.12, y - s * (1.25 - abs(k) * 0.4)), (x + k * s * 0.32 + s * 0.12, y - s * 0.4)], fill=(170, 230, 255, 245)), d.line([(x + k * s * 0.32, y - s * 0.4), (x + k * s * 0.32 + k * s * 0.12, y - s * (1.25 - abs(k) * 0.4))], fill=(255, 255, 255, 220), width=2)) for k in (-1, 0, 1)])
    a = ground(a, HORIZON + 24, rgb('a6d0ec'), rgb('4a86bc'), 103, 7, 0.1)
    a = reflect(a, HORIZON + 24, HORIZON + 110, 0.35, 3)
    a = layer(a, lambda d: [d.line([(x, y), (x + rnd.uniform(-90, 90), y + rnd.uniform(4, 30))], fill=(230, 245, 255, 150), width=2) for x, y in [(rnd.uniform(0, W), rnd.uniform(HORIZON + 40, H)) for _ in range(40)]], 0.6)
    a = motes(a, 104, 90, (0, HORIZON, W, H), (240, 250, 255), 1.6, 0.6)
    return a, {'outdoor': False, 'seed': 100}


def lavacave():
    """Caverna de lava (Fiery Path, Wela...): pedra escura, rios de lava e brasas no ar."""
    a = vgrad([(0, rgb('120404')), (1, rgb('4a1408'))], 0, HORIZON + 50)
    a = mountains(a, 401, HORIZON + 20, 120, rgb('3a1a12'), rgb('1a0a06'), rgb('2a0e06'), 0.25, 0.8, 10, freq=1.3)
    rnd = random.Random(402)
    a = layer(a, lambda d: [d.polygon([(x, -5), (x + w, -5), (x + w / 2 + rnd.uniform(-5, 5), rnd.uniform(40, 140))], fill=(34, 14, 10, 255)) for x, w in [(x, rnd.uniform(20, 44)) for x in range(-10, W, 30)]])
    # A boca da caverna brilhando com a lava lá no fundo.
    a = glow(a, W * 0.57, HORIZON - 30, 150, (255, 110, 30), 0.7)
    a = put(a, rgb('ff7a1a'), mask(lambda d: d.ellipse([W * 0.44, HORIZON - 90, W * 0.70, HORIZON + 20], fill=255), 22) * 0.55)
    a = ground(a, HORIZON + 24, rgb('4a2a20'), rgb('1e0e0a'), 403, 4, 0.2, spots=(rgb('2a1410'), 0.5))
    # Rios de lava cortando o chão.
    for y0, x0, x1 in ((HORIZON + 36, -20, W * 0.48), (HORIZON + 70, W * 0.62, W + 20), (H * 0.86, -20, W * 0.35)):
        a = glow(a, (x0 + x1) / 2, y0, 90, (255, 90, 20), 0.45)
        a = put(a, rgb('ff8a1e'), mask(lambda d, y0=y0, x0=x0, x1=x1: d.polygon([(x0, y0), (x1, y0 - 6), (x1, y0 + 8), (x0, y0 + 14)], fill=255), 3) * 0.95)
        a = put(a, rgb('ffe07a'), mask(lambda d, y0=y0, x0=x0, x1=x1: d.line([(x0, y0 + 5), (x1, y0 + 1)], fill=255, width=3), 1) * 0.8)
    a = rocks(a, 404, 8, HORIZON + 26, H * 0.6, rgb('3a2018'), rgb('6a3a26'), rgb('120806'), 10, 34)
    a = motes(a, 405, 70, (0, 0, W, H), (255, 160, 60), 2.0, 1.0)
    return a, {'outdoor': False, 'seed': 400}


def poisoncave():
    """Caverna venenosa (perto de pântanos): paredes roxas, poças de veneno e névoa tóxica."""
    a = vgrad([(0, rgb('0c0614')), (1, rgb('2a1a3a'))], 0, HORIZON + 50)
    a = mountains(a, 411, HORIZON + 20, 120, rgb('3a2a4a'), rgb('1a1226'), rgb('140c20'), 0.2, 0.8, 10, freq=1.3)
    rnd = random.Random(412)
    a = layer(a, lambda d: [d.polygon([(x, -5), (x + w, -5), (x + w / 2 + rnd.uniform(-5, 5), rnd.uniform(40, 150))], fill=(30, 20, 40, 255)) for x, w in [(x, rnd.uniform(20, 44)) for x in range(-10, W, 30)]])
    a = put(a, rgb('06030a'), mask(lambda d: d.ellipse([W * 0.42, HORIZON - 120, W * 0.72, HORIZON + 30], fill=255), 18) * 0.85)
    # Cogumelos brilhando nas paredes.
    for x, y, s in ((90, HORIZON + 14, 26), (760, HORIZON + 8, 30), (330, HORIZON - 2, 16), (610, HORIZON + 4, 18)):
        a = glow(a, x, y - s, s * 2.2, (200, 90, 255), 0.6)
        a = layer(a, lambda d, x=x, y=y, s=s: (d.rectangle([x - s * 0.12, y - s, x + s * 0.12, y], fill=(220, 200, 230, 255)), d.pieslice([x - s * 0.6, y - s * 1.5, x + s * 0.6, y - s * 0.5], 180, 360, fill=(190, 80, 230, 255))))
    a = ground(a, HORIZON + 24, rgb('4a3a52'), rgb('1e1626'), 413, 4, 0.2, spots=(rgb('2e2238'), 0.5))
    # Poças de veneno.
    for x0, x1, y in ((W * 0.08, W * 0.36, HORIZON + 44), (W * 0.58, W * 0.92, HORIZON + 80), (W * 0.2, W * 0.5, H * 0.9)):
        a = put(a, rgb('7a2aa8'), mask(lambda d, x0=x0, x1=x1, y=y: d.ellipse([x0, y - 10, x1, y + 10], fill=255), 3) * 0.9)
        a = put(a, rgb('c87aff'), mask(lambda d, x0=x0, x1=x1, y=y: d.ellipse([x0 + 20, y - 5, x1 - 30, y + 2], fill=255), 2) * 0.5)
    a = rocks(a, 414, 8, HORIZON + 26, H * 0.6, rgb('3c3048'), rgb('5c4a6e'), rgb('0c0812'), 10, 34)
    fog = noise(6, 415, 3, 3)
    a = put(a, rgb('9a5ac8'), np.clip((fog - 0.45) * 1.4, 0, 1) * 0.35)
    a = motes(a, 416, 50, (0, HORIZON, W, H), (200, 120, 255), 1.8, 1.2)
    return a, {'outdoor': False, 'seed': 410}


def seacave():
    """Caverna aquática (Seafloor Cavern, Whirl Islands...): pedra molhada, água até o meio e luz azul."""
    a = vgrad([(0, rgb('041018')), (1, rgb('0e3448'))], 0, HORIZON + 50)
    a = mountains(a, 421, HORIZON + 20, 120, rgb('1a3a4a'), rgb('0a1c26'), rgb('08202c'), 0.2, 0.8, 10, freq=1.3)
    rnd = random.Random(422)
    a = layer(a, lambda d: [d.polygon([(x, -5), (x + w, -5), (x + w / 2 + rnd.uniform(-5, 5), rnd.uniform(40, 150))], fill=(18, 36, 46, 255)) for x, w in [(x, rnd.uniform(20, 44)) for x in range(-10, W, 30)]])
    # A luz do mar entrando pela abertura.
    a = glow(a, W * 0.57, HORIZON - 50, 160, (80, 200, 230), 0.55)
    a = put(a, rgb('3ab0d0'), mask(lambda d: d.ellipse([W * 0.44, HORIZON - 110, W * 0.70, HORIZON + 10], fill=255), 22) * 0.45)
    a = ground(a, HORIZON + 24, rgb('2e5060'), rgb('122630'), 423, 4, 0.2, spots=(rgb('1c3a46'), 0.5))
    # A água cobrindo boa parte do chão (com reflexo).
    a = put(a, rgb('1a6a8e'), mask(lambda d: d.polygon([(0, HORIZON + 30), (W, HORIZON + 40), (W, H * 0.62), (0, H * 0.7)], fill=255), 4) * 0.85)
    a = reflect(a, HORIZON + 30, HORIZON + 120, 0.3, 3)
    a = layer(a, lambda d: [d.line([(x, y), (x + rnd.uniform(30, 90), y)], fill=(150, 220, 240, 150), width=2) for x, y in [(rnd.uniform(0, W), rnd.uniform(HORIZON + 34, H * 0.66)) for _ in range(30)]], 0.6)
    a = rocks(a, 424, 8, H * 0.6, H * 0.9, rgb('2c4654'), rgb('4e7484'), rgb('08141a'), 10, 34)
    a = motes(a, 425, 50, (0, 0, W, H * 0.7), (140, 220, 255), 1.6, 1.2)
    return a, {'outdoor': False, 'seed': 420}


def waterfall():
    """Gruta atrás da cachoeira (como a de Waterfall): a cortina de água brilhando ao fundo, névoa, um lago e pedra molhada."""
    a = vgrad([(0, rgb('061a22')), (1, rgb('12384a'))], 0, HORIZON + 50)
    # A cortina de água ao fundo (luz de fora atravessando).
    a = put(a, vgrad([(0, rgb('9ad8f0')), (1, rgb('e8f8ff'))], 0, HORIZON + 30), mask(lambda d: d.rectangle([W * 0.18, -5, W * 0.84, HORIZON + 28], fill=255), 6) * 0.9)
    rnd = random.Random(431)
    a = layer(a, lambda d: [d.line([(x, -5), (x + rnd.uniform(-3, 3), HORIZON + 26)], fill=(255, 255, 255, rnd.randrange(90, 220)), width=rnd.choice((2, 3, 4))) for x in [rnd.uniform(W * 0.18, W * 0.84) for _ in range(90)]], 0.6)
    a = layer(a, lambda d: [d.line([(x, -5), (x, HORIZON + 26)], fill=(90, 170, 210, 160), width=2) for x in [rnd.uniform(W * 0.18, W * 0.84) for _ in range(30)]], 0.4)
    a = glow(a, W * 0.51, HORIZON - 40, 220, (200, 240, 255), 0.35)
    # A boca da gruta (pedra escura emoldurando a água).
    a = layer(a, lambda d: (d.polygon([(-5, -5), (W * 0.24, -5), (W * 0.2, HORIZON * 0.5), (W * 0.15, HORIZON + 40), (-5, HORIZON + 60)], fill=(14, 30, 38, 255)),
                            d.polygon([(W + 5, -5), (W * 0.78, -5), (W * 0.82, HORIZON * 0.45), (W * 0.88, HORIZON + 40), (W + 5, HORIZON + 60)], fill=(14, 30, 38, 255)),
                            d.polygon([(-5, -5), (W + 5, -5), (W + 5, 26), (W * 0.6, 40), (W * 0.4, 34), (-5, 30)], fill=(10, 24, 30, 255))), 1.5)
    a = layer(a, lambda d: [d.polygon([(x, 20), (x + w, 24), (x + w / 2 + rnd.uniform(-4, 4), rnd.uniform(50, 90))], fill=(20, 40, 50, 255)) for x, w in [(x, rnd.uniform(16, 34)) for x in range(-10, W, 34)]])
    # A névoa onde a água cai.
    fog = noise(6, 432, 3, 3)
    a = put(a, rgb('e0f4ff'), mask(lambda d: d.ellipse([W * 0.1, HORIZON - 10, W * 0.92, HORIZON + 60], fill=255), 24) * np.clip(fog * 1.2, 0, 1) * 0.8)
    a = ground(a, HORIZON + 30, rgb('3a5a66'), rgb('142a32'), 433, 4, 0.2, spots=(rgb('22424e'), 0.5))
    # O lago na frente da cachoeira (com reflexo e espuma).
    a = put(a, rgb('2a86ac'), mask(lambda d: d.polygon([(W * 0.08, HORIZON + 30), (W * 0.94, HORIZON + 30), (W, H * 0.56), (0, H * 0.6)], fill=255), 4) * 0.85)
    a = reflect(a, HORIZON + 30, HORIZON + 110, 0.35, 3)
    a = layer(a, lambda d: [d.ellipse([x - 14, y - 3, x + 14, y + 3], fill=(240, 252, 255, 200)) for x, y in [(rnd.uniform(W * 0.2, W * 0.82), rnd.uniform(HORIZON + 30, HORIZON + 46)) for _ in range(40)]], 0.8)
    a = layer(a, lambda d: [d.line([(x, y), (x + rnd.uniform(30, 80), y)], fill=(170, 230, 250, 150), width=2) for x, y in [(rnd.uniform(0, W), rnd.uniform(HORIZON + 50, H * 0.58)) for _ in range(26)]], 0.6)
    a = rocks(a, 434, 8, H * 0.6, H * 0.9, rgb('34505c'), rgb('5a7c8a'), rgb('0a161c'), 10, 34)
    a = motes(a, 435, 60, (0, 0, W, H * 0.7), (200, 240, 255), 1.6, 1.2)
    return a, {'outdoor': False, 'seed': 430}


def mountain():
    a = vgrad([(0, rgb('3f7ec8')), (1, rgb('d4e8f8'))], 0, HORIZON)
    a = layer(a, lambda d: [d.ellipse([x - 110, y - 16, x + 110, y + 16], fill=(255, 255, 255, 150)) for x, y in ((180, 40), (560, 60))], 14)
    a = mountains(a, 91, HORIZON - 50, 140, rgb('a8b8cc'), rgb('7a8ca6'), rgb('c8dcf0'), 0.4, 0.45, 18, 1.6, blur=1.5, snowcap=rgb('f4f8ff'))
    a = mountains(a, 92, HORIZON + 6, 70, rgb('9a8a78'), rgb('5e5246'), None, 0, 0.5, 12, 2.4, tex=0.2)
    a = ground(a, HORIZON + 4, rgb('a8977e'), rgb('5c4e40'), 93, 4, 0.2, spots=(rgb('7a6a52'), 0.4))
    a = rocks(a, 94, 14, HORIZON + 14, H * 0.66, rgb('857664'), rgb('b2a28a'), rgb('2e261e'), 8, 40)
    a = blades(a, 95, 250, HORIZON + 20, H + 10, [rgb('6a7a40'), rgb('8a9a50')], 0.2)
    return a, {'outdoor': True, 'seed': 90}


def desert():
    a = vgrad([(0, rgb('d8853a')), (1, rgb('fbe0a2'))], 0, HORIZON)
    a = glow(a, W * 0.2, 70, 70, (255, 240, 200), 1.0)
    a = mountains(a, 111, HORIZON - 6, 50, rgb('d4a066'), rgb('b88450'), rgb('f0c890'), 0.4, 0.3, 18, 1.5, blur=2)
    a = mountains(a, 112, HORIZON + 8, 30, rgb('f2c886'), rgb('d29c58'), None, 0, 0.3, 16, 2.2)
    a = ground(a, HORIZON + 6, rgb('f2cf90'), rgb('c48c4a'), 113, 7, 0.12)
    rnd = random.Random(114)
    a = layer(a, lambda d: [d.arc([x, y - s * 0.1, x + s, y + s * 0.1], 190, 350, fill=(255, 230, 180, 120), width=2) for x, y, s in [(rnd.uniform(-40, W), rnd.uniform(HORIZON + 10, H), rnd.uniform(40, 160)) for _ in range(60)]], 0.8)

    def cactus(d, x, y, h):
        c, l = (60, 120, 64, 255), (96, 160, 90, 255)
        d.rounded_rectangle([x - h * 0.08, y - h, x + h * 0.08, y], radius=int(h * 0.08), fill=c)
        d.rounded_rectangle([x - h * 0.08, y - h, x - h * 0.02, y], radius=int(h * 0.03), fill=l)
        d.rounded_rectangle([x - h * 0.3, y - h * 0.68, x - h * 0.18, y - h * 0.36], radius=int(h * 0.05), fill=c)
        d.rectangle([x - h * 0.3, y - h * 0.44, x - h * 0.05, y - h * 0.34], fill=c)
        d.rounded_rectangle([x + h * 0.18, y - h * 0.8, x + h * 0.3, y - h * 0.5], radius=int(h * 0.05), fill=c)
        d.rectangle([x + h * 0.05, y - h * 0.58, x + h * 0.3, y - h * 0.5], fill=c)
    a = layer(a, lambda d: (cactus(d, 50, HORIZON + 60, 140), cactus(d, 760, HORIZON + 26, 90), cactus(d, 300, HORIZON + 8, 40)))
    a = rocks(a, 115, 5, HORIZON + 30, H * 0.6, rgb('b48a5a'), rgb('dcb27a'), rgb('6a4a2a'), 6, 20)
    return a, {'outdoor': True, 'seed': 110}


def volcano():
    a = vgrad([(0, rgb('1e0a10')), (0.7, rgb('6a2418')), (1, rgb('b04a24'))], 0, HORIZON)
    a = layer(a, lambda d: [d.ellipse([x - r, y - r * 0.6, x + r, y + r * 0.6], fill=(50, 34, 36, 170)) for x, y, r in ((W * 0.5, 10, 90), (W * 0.62, -20, 110), (W * 0.38, -10, 80))], 12)
    a = put(a, vgrad([(0, rgb('3a2220')), (1, rgb('1e1210'))], 60, HORIZON + 20), mask(lambda d: d.polygon([(W * 0.12, HORIZON + 20), (W * 0.44, 70), (W * 0.58, 70), (W * 0.9, HORIZON + 20)], fill=255), 1.5))
    a = glow(a, W * 0.51, 68, 80, (255, 120, 40), 0.9)
    a = layer(a, lambda d: [d.line([(W * 0.5 + k * 9, 72), (W * 0.47 + k * 34, HORIZON - 10)], fill=(255, 120, 30, 220), width=5) for k in (-1, 0, 1)], 1.5)
    a = mountains(a, 121, HORIZON + 10, 40, rgb('3a2220'), rgb('241412'), None, 0, 0.5, 10)
    a = ground(a, HORIZON + 10, rgb('4a2c24'), rgb('1e100c'), 122, 4, 0.2)
    rnd = random.Random(123)
    cracks = []
    for _ in range(18):
        x, y = rnd.uniform(0, W), rnd.uniform(HORIZON + 30, H)
        pts = [(x, y)]
        for _ in range(6):
            x += rnd.uniform(10, 50)
            y += rnd.uniform(-8, 8)
            pts.append((x, y))
        cracks.append(pts)
    a = layer(a, lambda d: [d.line(p, fill=(255, 100, 20, 160), width=7) for p in cracks], 4)
    a = layer(a, lambda d: [d.line(p, fill=(255, 200, 80, 255), width=2) for p in cracks])
    a = rocks(a, 124, 8, HORIZON + 20, H * 0.6, rgb('3c2a26'), rgb('64463c'), rgb('120806'), 8, 32)
    a = motes(a, 125, 90, (0, 0, W, H), (255, 160, 60), 2.2, 1)
    return a, {'outdoor': True, 'seed': 120}


def snow():
    a = vgrad([(0, rgb('0e1a3e')), (1, rgb('3a5a96'))], 0, HORIZON)
    a = stars(a, 131, 50, HORIZON - 60)
    a = layer(a, lambda d: [d.ellipse([x - 140, y - 30, x + 140, y + 30], fill=(60, 84, 140, 200)) for x, y in ((120, 70), (420, 40), (700, 90))], 18)
    rnd = random.Random(132)
    a = layer(a, lambda d: [pine(d, x, HORIZON + rnd.uniform(-6, 6), rnd.uniform(60, 110), (30, 50, 90, 255), (50, 76, 124, 255), (220, 232, 250, 255)) for x in list(range(-10, 260, 34)) + list(range(560, W + 30, 36))], 1.6)
    a = ground(a, HORIZON, rgb('9ab4e0'), rgb('5c7cbc'), 133, 6, 0.12)
    a = layer(a, lambda d: [d.ellipse([x - s, y - s * 0.16, x + s, y + s * 0.16], fill=(210, 224, 250, 180)) for x, y, s in [(rnd.uniform(0, W), rnd.uniform(HORIZON + 20, H), rnd.uniform(60, 220)) for _ in range(14)]], 6)
    a = motes(a, 134, 220, (0, 0, W, H), (255, 255, 255), 2.4, 0.7)
    return a, {'outdoor': True, 'seed': 130}


def city():
    a = vgrad([(0, rgb('0a1030')), (1, rgb('2a2f6a'))], 0, HORIZON)
    a = stars(a, 141, 30, HORIZON - 80)
    rnd = random.Random(142)
    blds = [(x, rnd.uniform(28, 60), rnd.uniform(60, 190)) for x in range(-10, W, 46)]

    def far(d):
        for x, w, h in blds:
            top = HORIZON - h
            d.rectangle([x, top, x + w, HORIZON + 10], fill=(28, 34, 74, 255))
            for r in range(int(h // 10)):
                for c in range(int(w // 9)):
                    if rnd.random() < 0.55:
                        col = (255, 220, 140, 230) if rnd.random() < 0.7 else (140, 200, 255, 230)
                        d.rectangle([x + 3 + c * 9, top + 4 + r * 10, x + 7 + c * 9, top + 9 + r * 10], fill=col)
            if rnd.random() < 0.4:
                d.ellipse([x + w / 2 - 2, top - 6, x + w / 2 + 2, top - 2], fill=(255, 60, 60, 255))
    a = layer(a, far, 0.8)
    a = glow(a, W * 0.5, HORIZON, W * 0.5, (60, 70, 160), 0.25)
    # Grade e postes.
    a = layer(a, lambda d: [d.line([(0, HORIZON + 26), (W, HORIZON + 26)], fill=(60, 70, 110, 255), width=4)] + [d.line([(x, HORIZON + 26), (x, HORIZON + 46)], fill=(60, 70, 110, 255), width=3) for x in range(10, W, 40)])
    for x in (140, 520, 760):
        a = glow(a, x, HORIZON - 40, 50, (255, 210, 140), 0.6)
    a = layer(a, lambda d: [(d.line([(x, HORIZON - 40), (x, HORIZON + 50)], fill=(50, 56, 80, 255), width=4), d.ellipse([x - 6, HORIZON - 46, x + 6, HORIZON - 36], fill=(255, 240, 200, 255))) for x in (140, 520, 760)])
    a = ground(a, HORIZON + 46, rgb('4c4f78'), rgb('262848'), 143, 6, 0.1)
    a = reflect(a, HORIZON + 46, HORIZON + 150, 0.3, 3)
    # Calçada e árvore à esquerda.
    a = put(a, rgb('3a3c60'), mask(lambda d: d.polygon([(0, HORIZON + 40), (W * 0.42, HORIZON + 40), (W * 0.30, HORIZON + 66), (0, HORIZON + 90)], fill=255)))
    a = treeline(a, 144, HORIZON + 18, 40, ((20, 50, 46), (30, 74, 62), (50, 104, 86)), 4.5)
    return a, {'outdoor': True, 'seed': 140}


def sky():
    a = vgrad([(0, rgb('2672cc')), (1, rgb('c4e6ff'))])
    rnd = random.Random(151)

    def clouds(d, y0, y1, n, a, shade):
        for _ in range(n):
            x, y, r = rnd.uniform(-60, W + 60), rnd.uniform(y0, y1), rnd.uniform(40, 120)
            d.ellipse([x - r, y - r * 0.4, x + r, y + r * 0.45], fill=shade + (a,))
            d.ellipse([x - r * 0.9, y - r * 0.55, x + r * 0.7, y + r * 0.2], fill=(255, 255, 255, a))
    a = layer(a, lambda d: clouds(d, 30, HORIZON, 14, 160, (200, 220, 245)), 10)
    a = layer(a, lambda d: clouds(d, HORIZON, H, 46, 240, (190, 210, 236)), 4)
    a = motes(a, 152, 40, (0, 0, W, H), (255, 255, 255), 2, 1)
    return a, {'outdoor': True, 'sky': H, 'seed': 150}


def tower():
    a = vgrad([(0, rgb('120a24')), (1, rgb('3e2766'))], 0, HORIZON + 30)
    for x in (40, 200, 580, 740):
        a = put(a, vgrad([(0, rgb('3a2c5e')), (1, rgb('24183e'))], 0, HORIZON + 40), mask(lambda d, x=x: d.rectangle([x, 0, x + 44, HORIZON + 40], fill=255)))
        a = layer(a, lambda d, x=x: (d.rectangle([x - 6, 0, x + 50, 20], fill=(70, 54, 108, 255)), d.rectangle([x, 0, x + 8, HORIZON + 40], fill=(80, 64, 120, 255))))
        a = glow(a, x + 22, HORIZON - 30, 30, (190, 150, 255), 0.6)
        a = layer(a, lambda d, x=x: (d.rectangle([x + 18, HORIZON - 30, x + 26, HORIZON - 12], fill=(235, 225, 250, 255)), d.ellipse([x + 19, HORIZON - 38, x + 25, HORIZON - 30], fill=(200, 170, 255, 255))))
    a = put(a, rgb('08040e'), mask(lambda d: d.rounded_rectangle([W * 0.42, HORIZON - 110, W * 0.58, HORIZON + 30], radius=50, fill=255), 6) * 0.9)
    a = ground(a, HORIZON + 30, rgb('5a4682'), rgb('22183a'), 161, 3, 0.12)
    a = layer(a, lambda d: [d.line([(0, y), (W, y)], fill=(90, 72, 130, 120), width=2) for y in range(HORIZON + 50, H, 34)] + [d.line([(W * 0.5 + (x - W * 0.5) * 0.25, HORIZON + 30), (x, H)], fill=(90, 72, 130, 120), width=2) for x in range(-200, W + 240, 110)], 0.5)
    fog = noise(6, 162, 3, 3)
    a = put(a, rgb('b8a0e8'), np.clip((fog - 0.45) * 1.2, 0, 1) * 0.35)
    a = motes(a, 163, 30, (0, 0, W, H * 0.7), (200, 170, 255), 3, 2)
    return a, {'outdoor': False, 'seed': 160}


def gym():
    a = vgrad([(0, rgb('141a2a')), (1, rgb('3a4660'))], 0, HORIZON + 30)
    a = layer(a, lambda d: [d.rectangle([0, y, W, y + 13], fill=(54 + i * 7, 62 + i * 7, 84 + i * 7, 255)) for i, y in enumerate(range(70, HORIZON + 10, 20))])
    rnd = random.Random(171)
    a = layer(a, lambda d: [d.ellipse([x - 4, y - 5, x + 4, y + 5], fill=c + (255,)) for x, y, c in [(rnd.uniform(0, W), rnd.choice(range(66, HORIZON, 20)), ((220, 80, 80), (80, 140, 220), (240, 200, 80), (200, 200, 210))[rnd.randrange(4)]) for _ in range(220)]], 0.6)
    for x in (100, 300, 500, 700):
        a = glow(a, x, 30, 46, (255, 250, 220), 1.2)
    a = layer(a, lambda d: [d.polygon([(x - 18, 30), (x + 18, 30), (x + 160, HORIZON + 60), (x - 160, HORIZON + 60)], fill=(255, 250, 220, 22)) for x in (100, 300, 500, 700)], 10)
    a = ground(a, HORIZON + 30, rgb('cdb98c'), rgb('9a8256'), 172, 6, 0.06)
    a = layer(a, lambda d: (d.line([(W * 0.5, HORIZON + 30), (W * 0.5, H)], fill=(255, 255, 255, 210), width=4),
                            d.ellipse([W * 0.36, H * 0.52, W * 0.64, H * 0.64], outline=(255, 255, 255, 210), width=4),
                            d.line([(0, HORIZON + 70), (W, HORIZON + 70)], fill=(255, 255, 255, 170), width=3),
                            d.rectangle([0, HORIZON + 30, W, HORIZON + 36], fill=(200, 60, 60, 255))), 0.7)
    a = reflect(a, HORIZON + 30, HORIZON + 100, 0.15, 6)
    return a, {'outdoor': False, 'seed': 170}


def league():
    a = vgrad([(0, rgb('0e0818')), (1, rgb('3a2246'))], 0, HORIZON + 30)
    a = glow(a, W * 0.5, 50, 160, (255, 210, 130), 0.5)
    for x in (30, 190, 570, 730):
        a = put(a, vgrad([(0, rgb('e6c682')), (1, rgb('8a6a32'))], 20, HORIZON + 40), mask(lambda d, x=x: d.rectangle([x, 20, x + 40, HORIZON + 40], fill=255)))
        a = layer(a, lambda d, x=x: (d.rectangle([x - 8, 8, x + 48, 26], fill=(240, 210, 140, 255)), d.rectangle([x - 8, HORIZON + 30, x + 48, HORIZON + 44], fill=(200, 170, 100, 255)), d.rectangle([x + 4, 26, x + 10, HORIZON + 30], fill=(255, 236, 180, 255))))
    a = layer(a, lambda d: [(d.polygon([(x, 30), (x + 30, 40), (x + 30, 130), (x, 120)], fill=(150, 30, 40, 255)), d.polygon([(x + 12, 60), (x + 18, 54), (x + 24, 60), (x + 18, 66)], fill=(240, 200, 100, 255))) for x in (120, 650)])
    a = ground(a, HORIZON + 30, rgb('4e3456'), rgb('1e1222'), 181, 6, 0.06)
    a = reflect(a, HORIZON + 30, HORIZON + 120, 0.25, 4)
    a = put(a, vgrad([(0, rgb('a0222e')), (1, rgb('6a1018'))], HORIZON + 30, H), mask(lambda d: d.polygon([(W * 0.45, HORIZON + 30), (W * 0.55, HORIZON + 30), (W * 0.82, H), (W * 0.18, H)], fill=255), 1))
    a = layer(a, lambda d: [d.line([(W * 0.45, HORIZON + 30), (W * 0.18, H)], fill=(230, 190, 100, 255), width=3), d.line([(W * 0.55, HORIZON + 30), (W * 0.82, H)], fill=(230, 190, 100, 255), width=3)])
    a = motes(a, 182, 50, (0, 0, W, H * 0.6), (255, 220, 150), 2, 1.5)
    return a, {'outdoor': False, 'seed': 180}


def center():
    a = vgrad([(0, rgb('f4b8cc')), (1, rgb('fde8f0'))], 0, HORIZON + 30)
    a = layer(a, lambda d: (d.rectangle([0, HORIZON - 40, W, HORIZON + 30], fill=(238, 140, 168, 255)), d.rectangle([0, HORIZON - 40, W, HORIZON - 34], fill=(255, 200, 216, 255)),
                            d.rounded_rectangle([W * 0.3, 30, W * 0.7, HORIZON - 44], radius=18, fill=(255, 255, 255, 255)),
                            d.rectangle([W * 0.475, 52, W * 0.525, HORIZON - 64], fill=(230, 60, 84, 255)), d.rectangle([W * 0.43, 76, W * 0.57, 110], fill=(230, 60, 84, 255))))
    a = layer(a, lambda d: [(d.rounded_rectangle([x, HORIZON - 90, x + 70, HORIZON - 44], radius=8, fill=(220, 230, 240, 255)), d.rectangle([x + 8, HORIZON - 82, x + 62, HORIZON - 60], fill=(120, 200, 240, 255))) for x in (40, 690)])
    a = glow(a, W * 0.5, 0, 200, (255, 255, 255), 0.4)
    a = ground(a, HORIZON + 30, rgb('f6e6ee'), rgb('d6b2c4'), 191, 6, 0.04)
    a = layer(a, lambda d: [d.line([(W * 0.5 + (x - W * 0.5) * 0.2, HORIZON + 30), (x, H)], fill=(230, 200, 214, 255), width=2) for x in range(-300, W + 340, 120)] + [d.line([(0, y), (W, y)], fill=(230, 200, 214, 255), width=2) for y in (HORIZON + 50, HORIZON + 90, HORIZON + 160, HORIZON + 260)])
    a = reflect(a, HORIZON + 30, HORIZON + 110, 0.18, 5)
    return a, {'outdoor': False, 'seed': 190}


def ruins():
    """Ruínas antigas: colunas quebradas, blocos com inscrições e areia no chão."""
    a = vgrad([(0, rgb('c87a4a')), (0.6, rgb('eab47a')), (1, rgb('f6dcb0'))], 0, HORIZON)
    a = glow(a, W * 0.78, 60, 60, (255, 230, 190), 0.8)
    a = mountains(a, 201, HORIZON - 4, 46, rgb('b08a68'), rgb('8a6a4e'), rgb('e0c098'), 0.45, 0.4, 14, 1.6, blur=2)
    rnd = random.Random(202)

    def column(d, x, y, h, w, broken):
        stone, light, dark = (196, 172, 136, 255), (226, 206, 170, 255), (120, 100, 76, 255)
        top = y - h
        d.rectangle([x - w * 0.6, y - w * 0.3, x + w * 0.6, y], fill=dark)
        d.rectangle([x - w / 2, top, x + w / 2, y - w * 0.3], fill=stone)
        d.rectangle([x - w / 2, top, x - w * 0.25, y - w * 0.3], fill=light)
        for k in range(1, 4):
            d.line([(x - w / 2 + k * w / 4, top + 4), (x - w / 2 + k * w / 4, y - w * 0.3)], fill=dark, width=1)
        if broken:
            d.polygon([(x - w / 2, top), (x + w / 2, top), (x + w * 0.2, top - w * 0.4), (x - w * 0.1, top - w * 0.1)], fill=stone)
        else:
            d.rectangle([x - w * 0.7, top - w * 0.3, x + w * 0.7, top], fill=light)
    a = layer(a, lambda d: [column(d, x, HORIZON + 10, h, w, b) for x, h, w, b in ((90, 150, 34, False), (230, 90, 26, True), (560, 120, 28, True), (720, 170, 38, False), (420, 60, 20, True))], 0.6)
    a = layer(a, lambda d: d.rectangle([60, HORIZON - 150, 760, HORIZON - 132], fill=(210, 186, 150, 200)), 1)
    a = ground(a, HORIZON + 8, rgb('e6c48e'), rgb('a07a4c'), 203, 6, 0.14, spots=(rgb('b89a72'), 0.4))
    # Blocos caídos com inscrições.
    blocks = [(rnd.uniform(0, W), rnd.uniform(HORIZON + 30, H * 0.62), rnd.uniform(18, 44)) for _ in range(7)]
    a = layer(a, lambda d: [(d.rectangle([x, y - s * 0.7, x + s * 1.4, y], fill=(176, 150, 112, 255)), d.rectangle([x, y - s * 0.7, x + s * 1.4, y - s * 0.55], fill=(214, 192, 154, 255)),
                            [d.ellipse([x + 4 + k * s * 0.3, y - s * 0.42, x + 8 + k * s * 0.3, y - s * 0.3], outline=(110, 86, 60, 255)) for k in range(4)]) for x, y, s in blocks])
    a = motes(a, 204, 30, (0, HORIZON - 60, W, H * 0.7), (255, 230, 180), 1.8, 1.2)
    return a, {'outdoor': True, 'seed': 200}


def flowers():
    """Campo de flores: colinas suaves cobertas de flores coloridas."""
    a = vgrad([(0, rgb('5a9ae0')), (0.6, rgb('a8d4ff')), (1, rgb('f2f6ff'))], 0, HORIZON)
    a = layer(a, lambda d: [d.ellipse([x - 80, y - 16, x + 80, y + 16], fill=(255, 255, 255, 170)) for x, y in ((150, 50), (470, 30), (700, 70))], 12)
    a = mountains(a, 211, HORIZON - 10, 40, rgb('8fcf7a'), rgb('6aae5a'), rgb('c8ecc0'), 0.5, 0.3, 18, 1.4, blur=2)
    a = ground(a, HORIZON, rgb('9ad47a'), rgb('4e9a3e'), 212, 5, 0.12)
    rnd = random.Random(213)
    cols = [(255, 120, 170), (255, 220, 90), (255, 255, 255), (190, 130, 255), (255, 150, 90)]
    pts = [(rnd.uniform(0, W), rnd.uniform(HORIZON + 4, H), rnd.choice(cols)) for _ in range(1800)]

    def bloom(d):
        for x, y, c in sorted(pts, key=lambda p: p[1]):
            r = 1 + (y - HORIZON) / (H - HORIZON) * 5
            d.ellipse([x - r, y - r * 0.7, x + r, y + r * 0.7], fill=c + (255,))
            d.ellipse([x - r * 0.3, y - r * 0.25, x + r * 0.3, y + r * 0.25], fill=(255, 240, 120, 255))
    a = blades(a, 214, 700, HORIZON + 10, H + 10, [rgb('3f8a34'), rgb('5aa844'), rgb('8ad066')])
    a = layer(a, bloom)
    a = motes(a, 215, 40, (0, HORIZON - 80, W, H * 0.7), (255, 200, 230), 2.2, 1.0)
    return a, {'outdoor': True, 'seed': 210}


def plant():
    """Usina elétrica: máquinas, cabos e faíscas, com luz amarela."""
    a = vgrad([(0, rgb('14161e')), (1, rgb('3a3e4e'))], 0, HORIZON + 40)
    rnd = random.Random(221)

    def machines(d):
        for x in range(-20, W, 120):
            h = rnd.uniform(90, 170)
            d.rectangle([x, HORIZON + 30 - h, x + 96, HORIZON + 30], fill=(70, 74, 86, 255))
            d.rectangle([x, HORIZON + 30 - h, x + 96, HORIZON + 38 - h], fill=(110, 116, 130, 255))
            for k in range(3):
                d.rectangle([x + 10 + k * 28, HORIZON + 50 - h, x + 28 + k * 28, HORIZON + 62 - h], fill=(250, 220, 60, 255) if rnd.random() < 0.6 else (60, 200, 255, 255))
            d.ellipse([x + 30, HORIZON - 20, x + 66, HORIZON + 16], outline=(150, 156, 170, 255), width=4)
        for y in (40, 70):
            d.line([(0, y), (W, y + 20)], fill=(40, 42, 50, 255), width=5)
    a = layer(a, machines)
    for x, y in ((180, 100), (520, 80), (690, 130)):
        a = glow(a, x, y, 40, (255, 230, 80), 0.7)
    a = layer(a, lambda d: [d.line([(x, y), (x + rnd.uniform(-20, 20), y + 14), (x + rnd.uniform(-20, 20), y + 28)], fill=(255, 250, 160, 255), width=2) for x, y in ((180, 100), (520, 80), (690, 130))])
    a = ground(a, HORIZON + 34, rgb('5a5e6c'), rgb('24262e'), 222, 6, 0.1)
    # Faixas de aviso e grade no chão.
    a = layer(a, lambda d: [d.line([(W * 0.5 + (x - W * 0.5) * 0.3, HORIZON + 34), (x, H)], fill=(80, 84, 96, 160), width=2) for x in range(-300, W + 300, 90)] +
              [d.polygon([(x, H - 22), (x + 30, H - 22), (x + 50, H), (x + 20, H)], fill=(240, 200, 40, 255)) for x in range(-20, W, 60)], 0.4)
    a = motes(a, 223, 40, (0, 0, W, H * 0.7), (255, 240, 120), 2, 1)
    return a, {'outdoor': False, 'seed': 220}


def crystal():
    """Mina de cristal: túnel escuro com cristais coloridos brilhando e trilhos."""
    a = vgrad([(0, rgb('0c0818')), (1, rgb('2a1e44'))], 0, HORIZON + 50)
    a = mountains(a, 231, HORIZON + 20, 110, rgb('3a2a56'), rgb('1e1630'), rgb('140e22'), 0.2, 0.7, 10, freq=1.2)
    a = put(a, rgb('06040c'), mask(lambda d: d.rounded_rectangle([W * 0.4, HORIZON - 90, W * 0.6, HORIZON + 30], radius=40, fill=255), 10) * 0.9)
    rnd = random.Random(232)
    gems = [(x, rnd.uniform(HORIZON - 30, HORIZON + 50), rnd.uniform(40, 90), rnd.choice([(90, 210, 255), (255, 90, 200), (160, 100, 255), (80, 240, 160)])) for x in (30, 140, 250, 560, 660, 770)]
    gems += [(rnd.uniform(0, W), rnd.uniform(HORIZON + 60, H * 0.62), rnd.uniform(20, 36), rnd.choice([(90, 210, 255), (255, 90, 200), (160, 100, 255)])) for _ in range(5)]
    for x, y, sz, c in gems:
        a = glow(a, x, y - sz * 0.5, sz * 1.4, c, 0.55)
    a = ground(a, HORIZON + 26, rgb('4a3a66'), rgb('1c1428'), 233, 4, 0.2)
    # Trilhos da mina.
    a = layer(a, lambda d: [d.line([(W * 0.5 + k * 30, HORIZON + 26), (W * 0.5 + k * 260, H)], fill=(120, 110, 130, 255), width=4) for k in (-1, 1)] +
              [d.line([(W * 0.5 - 30 - t * 230, HORIZON + 26 + t * (H - HORIZON - 26)), (W * 0.5 + 30 + t * 230, HORIZON + 26 + t * (H - HORIZON - 26))], fill=(90, 64, 44, 255), width=int(2 + t * 6)) for t in [i / 9 for i in range(1, 10)]])

    def shards(d):
        for x, y, sz, c in gems:
            for k in (-1, 0, 1):
                d.polygon([(x + k * sz * 0.35, y), (x + k * sz * 0.35 - sz * 0.14, y - sz * 0.45), (x + k * sz * 0.5, y - sz * (1.1 - abs(k) * 0.4)), (x + k * sz * 0.35 + sz * 0.14, y - sz * 0.45)], fill=c + (255,))
                d.line([(x + k * sz * 0.35, y), (x + k * sz * 0.5, y - sz * (1.1 - abs(k) * 0.4))], fill=(255, 255, 255, 220), width=2)
    a = layer(a, shards)
    a = motes(a, 234, 25, (0, 0, W, H * 0.7), (220, 180, 255), 1.8, 1.2)
    return a, {'outdoor': False, 'seed': 230}


def dunes():
    """Deserto à noite: dunas azuladas, lua grande e céu estrelado."""
    a = vgrad([(0, rgb('060a24')), (0.7, rgb('1e2a5a')), (1, rgb('46507e'))], 0, HORIZON)
    a = stars(a, 241, 140, HORIZON - 10)
    a = moon(a, W * 0.25, 70, 34, (250, 246, 220))
    a = glow(a, W * 0.25, 70, 90, (200, 200, 255), 0.35)
    a = mountains(a, 242, HORIZON - 4, 40, rgb('3a3e6a'), rgb('2a2e54'), rgb('50567e'), 0.4, 0.3, 18, 1.4, blur=2)
    a = mountains(a, 243, HORIZON + 10, 26, rgb('5a5a86'), rgb('3a3a62'), None, 0, 0.3, 16, 2.0)
    a = ground(a, HORIZON + 8, rgb('6a6a94'), rgb('2e2e52'), 244, 7, 0.12)
    rnd = random.Random(245)
    a = layer(a, lambda d: [d.arc([x, y - s * 0.1, x + s, y + s * 0.1], 190, 350, fill=(150, 150, 200, 110), width=2) for x, y, s in [(rnd.uniform(-40, W), rnd.uniform(HORIZON + 10, H), rnd.uniform(40, 160)) for _ in range(50)]], 0.8)
    a = rocks(a, 246, 4, HORIZON + 30, H * 0.6, rgb('4a4a70'), rgb('6a6a96'), rgb('1a1a30'), 6, 18)
    a = motes(a, 247, 20, (0, HORIZON - 40, W, H * 0.7), (170, 200, 255), 1.6, 1.0)
    return a, {'outdoor': True, 'seed': 240}


def bamboo():
    """Bambuzal: troncos verdes altos, luz filtrada e folhas caindo."""
    a = vgrad([(0, rgb('cfe8b0')), (1, rgb('8ab86a'))], 0, HORIZON + 30)
    rnd = random.Random(251)

    def stalks(d, n, wmin, wmax, cols, y, edges=False):
        for _ in range(n):
            x, w = (rnd.choice([rnd.uniform(-20, 70), rnd.uniform(W - 90, W)]) if edges else rnd.uniform(-10, W + 10)), rnd.uniform(wmin, wmax)
            c = rnd.choice(cols)
            d.rectangle([x, -5, x + w, y], fill=c + (255,))
            d.rectangle([x, -5, x + w * 0.3, y], fill=tuple(min(255, v + 30) for v in c) + (255,))
            for yy in range(int(rnd.uniform(0, 60)), int(y), int(rnd.uniform(50, 80))):
                d.rectangle([x - 1, yy, x + w + 1, yy + 3], fill=tuple(max(0, v - 40) for v in c) + (255,))
    a = layer(a, lambda d: stalks(d, 40, 6, 12, [(130, 170, 90), (150, 190, 100)], HORIZON + 20), 1.5)
    a = layer(a, lambda d: stalks(d, 18, 12, 22, [(80, 140, 60), (100, 160, 70)], HORIZON + 40), 0.5)
    a = ground(a, HORIZON + 30, rgb('8aa45a'), rgb('4a6a2e'), 252, 5, 0.16, spots=(rgb('a08a5a'), 0.3))
    a = layer(a, lambda d: stalks(d, 4, 30, 44, [(60, 120, 50), (70, 130, 56)], H, True), 0)
    a = layer(a, lambda d: [d.ellipse([x - 8, y - 2, x + 8, y + 2], fill=(110, 170, 70, 230)) for x, y in [(rnd.uniform(0, W), rnd.uniform(0, H)) for _ in range(60)]])
    a = blades(a, 253, 500, HORIZON + 30, H + 10, [rgb('4a7a32'), rgb('6a9a44'), rgb('8ab85a')])
    a = motes(a, 254, 40, (0, 0, W, H * 0.7), (255, 250, 200), 2.2, 1.2)
    return a, {'outdoor': True, 'seed': 250}


def temple():
    """Templo antigo: escadaria, colunas e incenso, com luz dourada."""
    a = vgrad([(0, rgb('2a1a10')), (1, rgb('6a3a1e'))], 0, HORIZON + 40)
    a = glow(a, W * 0.5, HORIZON - 40, 160, (255, 190, 90), 0.55)
    # Portal e altar no fundo.
    a = layer(a, lambda d: (d.rectangle([W * 0.36, HORIZON - 150, W * 0.64, HORIZON + 20], fill=(80, 40, 24, 255)), d.rectangle([W * 0.33, HORIZON - 168, W * 0.67, HORIZON - 148], fill=(180, 60, 40, 255)),
                            d.rectangle([W * 0.30, HORIZON - 184, W * 0.70, HORIZON - 172], fill=(150, 46, 30, 255)), d.rectangle([W * 0.44, HORIZON - 70, W * 0.56, HORIZON + 20], fill=(255, 210, 120, 255))))
    for x in (60, 170, 630, 740):
        a = layer(a, lambda d, x=x: (d.rectangle([x, HORIZON - 200, x + 34, HORIZON + 40], fill=(150, 50, 36, 255)), d.rectangle([x, HORIZON - 200, x + 10, HORIZON + 40], fill=(190, 80, 56, 255)),
                                     d.rectangle([x - 8, HORIZON + 30, x + 42, HORIZON + 44], fill=(90, 70, 60, 255))))
    a = ground(a, HORIZON + 40, rgb('a88466'), rgb('5a3e2c'), 261, 3, 0.1)
    # Ladrilhos.
    a = layer(a, lambda d: [d.line([(0, y), (W, y)], fill=(80, 56, 40, 140), width=2) for y in range(HORIZON + 60, H, 40)] + [d.line([(W * 0.5 + (x - W * 0.5) * 0.25, HORIZON + 40), (x, H)], fill=(80, 56, 40, 140), width=2) for x in range(-200, W + 240, 120)], 0.5)
    # Lanternas e incenso.
    for x in (250, 550):
        a = glow(a, x, HORIZON + 6, 30, (255, 200, 110), 0.7)
        a = layer(a, lambda d, x=x: (d.rectangle([x - 10, HORIZON - 14, x + 10, HORIZON + 14], fill=(255, 220, 150, 255)), d.rectangle([x - 12, HORIZON - 18, x + 12, HORIZON - 14], fill=(60, 30, 20, 255))))
    fog = noise(6, 262, 3, 3)
    a = put(a, rgb('e8d8c8'), np.clip((fog - 0.5) * 1.2, 0, 1) * 0.25)
    a = motes(a, 263, 30, (0, 0, W, H * 0.7), (255, 220, 160), 2, 1.5)
    return a, {'outdoor': False, 'seed': 260}



# ------------------------------------------------------------ lugares da cidade (loja, cassino, escola, palco, metrô, navio, ponte, parque)

def store():
    """Loja de departamento (e mercado, loja de ervas): prateleiras coloridas, balcão e luzes no teto."""
    a = vgrad([(0, rgb('f2e6cc')), (1, rgb('d8c49c'))], 0, HORIZON + 30)
    rnd = random.Random(911)
    cols = [(230, 80, 80), (80, 150, 230), (250, 200, 70), (110, 190, 110), (200, 120, 220), (250, 150, 60)]

    def shelves(d):
        for x0 in (20, 290, 560):
            d.rectangle([x0, 40, x0 + 220, HORIZON + 26], fill=(150, 104, 62, 255))
            for r, y in enumerate(range(52, HORIZON + 10, 34)):
                d.rectangle([x0 + 8, y + 26, x0 + 212, y + 30], fill=(110, 74, 42, 255))
                x = x0 + 12
                while x < x0 + 200:
                    w, h = rnd.randint(12, 26), rnd.randint(14, 24)
                    d.rectangle([x, y + 26 - h, x + w, y + 26], fill=cols[rnd.randrange(len(cols))] + (255,))
                    x += w + 3
    a = layer(a, shelves)
    for x in (130, 400, 670):
        a = glow(a, x, 14, 60, (255, 250, 230), 0.9)
    a = layer(a, lambda d: [d.rectangle([x - 50, 8, x + 50, 16], fill=(255, 252, 236, 255)) for x in (130, 400, 670)])
    a = ground(a, HORIZON + 30, rgb('e8dcc6'), rgb('b8a482'), 912, 6, 0.04)
    a = layer(a, lambda d: [d.line([(W * 0.5 + (x - W * 0.5) * 0.2, HORIZON + 30), (x, H)], fill=(200, 184, 156, 255), width=2) for x in range(-300, W + 340, 110)] + [d.line([(0, y), (W, y)], fill=(200, 184, 156, 255), width=2) for y in (HORIZON + 52, HORIZON + 96, HORIZON + 170, HORIZON + 280)])
    a = reflect(a, HORIZON + 30, HORIZON + 110, 0.15, 5)
    return a, {'outdoor': False, 'seed': 910}


def casino():
    """Game Corner: fileiras de caça-níqueis com luzes e o tapete estampado."""
    a = vgrad([(0, rgb('1a0614')), (1, rgb('4a1030'))], 0, HORIZON + 30)
    rnd = random.Random(921)
    sym = [(255, 70, 70), (255, 220, 60), (90, 200, 255), (120, 240, 120)]

    def machines(d):
        for x in range(10, W, 76):
            d.rectangle([x, HORIZON - 120, x + 62, HORIZON + 26], fill=(60, 64, 92, 255))
            d.rectangle([x + 4, HORIZON - 116, x + 58, HORIZON - 100], fill=(240, 200, 60, 255))
            d.rectangle([x + 8, HORIZON - 90, x + 54, HORIZON - 56], fill=(16, 16, 26, 255))
            for k in range(3):
                d.rectangle([x + 11 + k * 14, HORIZON - 84, x + 21 + k * 14, HORIZON - 62], fill=sym[rnd.randrange(4)] + (255,))
            d.rectangle([x + 8, HORIZON - 44, x + 54, HORIZON - 36], fill=(140, 30, 40, 255))
            d.line([(x + 62, HORIZON - 80), (x + 70, HORIZON - 96)], fill=(200, 200, 210, 255), width=3)
            d.ellipse([x + 66, HORIZON - 104, x + 76, HORIZON - 94], fill=(230, 50, 50, 255))
    a = layer(a, machines)
    for x in range(40, W, 76):
        a = glow(a, x, HORIZON - 110, 28, (255, 210, 90), 0.5)
    a = ground(a, HORIZON + 30, rgb('8a1a2a'), rgb('4a0a16'), 922, 6, 0.06)
    a = layer(a, lambda d: [d.polygon([(x, y - 10), (x + 14, y), (x, y + 10), (x - 14, y)], outline=(230, 180, 70, 160)) for y in range(HORIZON + 56, H, 46) for x in range(-20 + (y // 46 % 2) * 40, W + 40, 80)], 0.4)
    a = motes(a, 923, 40, (0, 0, W, HORIZON), (255, 220, 120), 2, 1)
    return a, {'outdoor': False, 'seed': 920}


def school():
    """Escola de treinadores: o quadro-negro, janelas com o céu e o piso de madeira."""
    a = vgrad([(0, rgb('d4ecd4')), (1, rgb('b0d4b4'))], 0, HORIZON + 30)
    a = layer(a, lambda d: (d.rectangle([W * 0.22, 40, W * 0.78, HORIZON - 20], fill=(150, 104, 62, 255)),
                            d.rectangle([W * 0.23, 48, W * 0.77, HORIZON - 28], fill=(34, 80, 58, 255))))
    a = layer(a, lambda d: [d.line([(W * 0.27, y), (W * 0.27 + ln, y)], fill=(236, 240, 230, 220), width=3) for y, ln in ((70, 180), (96, 240), (122, 150), (148, 210))] +
              [d.ellipse([W * 0.62, 66, W * 0.70, 104], outline=(236, 240, 230, 220), width=3), d.line([(W * 0.62, 85), (W * 0.70, 85)], fill=(236, 240, 230, 220), width=3)])
    for x in (16, 680):
        a = put(a, vgrad([(0, rgb('8ac8ff')), (1, rgb('dff0ff'))], 40, HORIZON - 20), mask(lambda d, x=x: d.rectangle([x, 40, x + 104, HORIZON - 20], fill=255)))
        a = layer(a, lambda d, x=x: (d.rectangle([x, 40, x + 104, HORIZON - 20], outline=(240, 240, 236, 255), width=6), d.line([(x + 52, 40), (x + 52, HORIZON - 20)], fill=(240, 240, 236, 255), width=4)))
    a = glow(a, W * 0.5, 0, 220, (255, 255, 240), 0.3)
    a = ground(a, HORIZON + 30, rgb('d2a46a'), rgb('9a6a3a'), 931, 5, 0.06)
    a = layer(a, lambda d: [d.line([(0, y), (W, y)], fill=(140, 96, 54, 255), width=2) for y in range(HORIZON + 44, H, 26)])
    a = reflect(a, HORIZON + 30, HORIZON + 100, 0.12, 5)
    return a, {'outdoor': False, 'seed': 930}


def stage():
    """Palco (concurso, estúdio): cortinas, holofotes e o piso do palco."""
    a = vgrad([(0, rgb('0a0612')), (1, rgb('2a1a3a'))], 0, HORIZON + 30)
    a = layer(a, lambda d: [d.polygon([(x - 14, 0), (x + 14, 0), (x + 150, HORIZON + 60), (x - 150, HORIZON + 60)], fill=(255, 240, 200, 30)) for x in (200, 400, 600)], 10)
    for x in (200, 400, 600):
        a = glow(a, x, 6, 40, (255, 240, 200), 1.0)

    def curtains(d):
        for side in (0, 1):
            x0 = 0 if side == 0 else W - 150
            d.rectangle([x0, 0, x0 + 150, HORIZON + 30], fill=(150, 20, 40, 255))
            for k in range(6):
                xx = x0 + 10 + k * 24
                d.line([(xx, 0), (xx, HORIZON + 30)], fill=(100, 10, 26, 255), width=6)
        d.rectangle([0, 0, W, 26], fill=(170, 26, 48, 255))
        d.rectangle([0, 26, W, 32], fill=(230, 180, 70, 255))
    a = layer(a, curtains)
    a = ground(a, HORIZON + 30, rgb('c08a4a'), rgb('7a4a20'), 941, 5, 0.06)
    a = layer(a, lambda d: [d.line([(W * 0.5 + (x - W * 0.5) * 0.2, HORIZON + 30), (x, H)], fill=(150, 100, 52, 255), width=2) for x in range(-300, W + 340, 70)] + [d.rectangle([0, HORIZON + 30, W, HORIZON + 36], fill=(230, 180, 70, 255))])
    a = reflect(a, HORIZON + 30, HORIZON + 120, 0.2, 4)
    a = motes(a, 942, 40, (0, 0, W, H * 0.6), (255, 230, 170), 2, 1.5)
    return a, {'outdoor': False, 'seed': 940}


def subway():
    """Metrô (Battle Subway): janelas com o túnel passando, bancos e barras."""
    a = vgrad([(0, rgb('bcc6d0')), (1, rgb('8e9aa6'))], 0, HORIZON + 30)
    for x in (40, 300, 560):
        a = put(a, vgrad([(0, rgb('0c1018')), (1, rgb('1e2632'))], 50, HORIZON - 30), mask(lambda d, x=x: d.rounded_rectangle([x, 50, x + 200, HORIZON - 30], radius=12, fill=255)))
        a = layer(a, lambda d, x=x: [d.line([(x + 10 + k * 37, 90 + (k % 3) * 18), (x + 34 + k * 37, 90 + (k % 3) * 18)], fill=(255, 220, 140, 255), width=3) for k in range(5)])
        a = layer(a, lambda d, x=x: d.rounded_rectangle([x, 50, x + 200, HORIZON - 30], radius=12, outline=(220, 226, 232, 255), width=6))
    a = layer(a, lambda d: (d.rectangle([0, HORIZON - 24, W, HORIZON + 6], fill=(60, 100, 170, 255)), d.rectangle([0, HORIZON - 24, W, HORIZON - 18], fill=(90, 140, 210, 255)),
                            d.rectangle([0, 10, W, 16], fill=(210, 214, 220, 255))))
    a = layer(a, lambda d: [d.line([(x, 0), (x, HORIZON + 30)], fill=(230, 220, 120, 255), width=5) for x in (20, 280, 540, 780)])
    a = glow(a, W * 0.5, 0, 260, (255, 255, 255), 0.35)
    a = ground(a, HORIZON + 30, rgb('8a8e96'), rgb('4e525a'), 951, 6, 0.08)
    a = layer(a, lambda d: [d.ellipse([x - 4, y - 2, x + 4, y + 2], fill=(110, 114, 122, 255)) for y in range(HORIZON + 50, H, 30) for x in range(10, W, 40)], 0.5)
    return a, {'outdoor': False, 'seed': 950}


def ship():
    """Navio (S.S. Anne): o mar no horizonte, a amurada com boias e o convés de madeira."""
    a = vgrad([(0, rgb('3a86d8')), (1, rgb('bfe2ff'))], 0, HORIZON)
    a = layer(a, lambda d: [d.ellipse([x, y, x + w, y + 24], fill=(255, 255, 255, 220)) for x, y, w in ((60, 40, 140), (420, 60, 180), (660, 30, 110))], 4)
    a = put(a, vgrad([(0, rgb('2a6ab8')), (1, rgb('1a4a8a'))], HORIZON - 10, HORIZON + 30), mask(lambda d: d.rectangle([0, HORIZON - 10, W, HORIZON + 30], fill=255)))
    a = layer(a, lambda d: (d.rectangle([0, HORIZON - 2, W, HORIZON + 4], fill=(240, 240, 236, 255)),
                            [d.line([(x, HORIZON + 4), (x, HORIZON + 36)], fill=(240, 240, 236, 255), width=4) for x in range(0, W, 36)],
                            d.rectangle([0, HORIZON + 30, W, HORIZON + 36], fill=(240, 240, 236, 255))))
    for x in (150, 610):
        a = layer(a, lambda d, x=x: (d.ellipse([x - 22, HORIZON - 8, x + 22, HORIZON + 36], fill=(240, 90, 60, 255)), d.ellipse([x - 10, HORIZON + 4, x + 10, HORIZON + 24], fill=(40, 90, 150, 255)),
                                       [d.rectangle([x - 4 + dx, HORIZON - 8 + dy, x + 4 + dx, HORIZON + dy], fill=(250, 250, 250, 255)) for dx, dy in ((-20, 18), (12, 18), (-4, -2), (-4, 34))]))
    a = ground(a, HORIZON + 36, rgb('d8a868'), rgb('9a6a34'), 961, 5, 0.07)
    a = layer(a, lambda d: [d.line([(W * 0.5 + (x - W * 0.5) * 0.15, HORIZON + 36), (x, H)], fill=(150, 104, 56, 255), width=2) for x in range(-400, W + 440, 60)])
    return a, {'outdoor': True, 'seed': 960}


def bridge():
    """Ponte (Nugget Bridge): o rio lá embaixo, o guarda-corpo e o piso da ponte."""
    a = vgrad([(0, rgb('4a96e0')), (1, rgb('cde8ff'))], 0, HORIZON - 20)
    a = mountains(a, 971, HORIZON - 30, 50, rgb('7aa8a0'), rgb('5a8a7a'), rgb('cde8ff'), 0.4, 0.4)
    a = put(a, vgrad([(0, rgb('3a86c8')), (1, rgb('2a62a0'))], HORIZON - 30, HORIZON + 30), mask(lambda d: d.rectangle([0, HORIZON - 30, W, HORIZON + 30], fill=255)))
    a = layer(a, lambda d: [d.line([(x, y), (x + 18, y)], fill=(220, 240, 255, 200), width=2) for x, y in ((40, HORIZON - 20), (220, HORIZON - 6), (420, HORIZON - 16), (630, HORIZON + 2), (300, HORIZON + 14))])
    a = layer(a, lambda d: (d.rectangle([0, HORIZON - 4, W, HORIZON + 4], fill=(180, 120, 60, 255)),
                            [d.rectangle([x, HORIZON - 26, x + 10, HORIZON + 30], fill=(160, 104, 52, 255)) for x in range(0, W, 70)],
                            d.rectangle([0, HORIZON - 30, W, HORIZON - 22], fill=(200, 140, 70, 255))))
    a = ground(a, HORIZON + 30, rgb('e0b070'), rgb('a87638'), 972, 5, 0.06)
    a = layer(a, lambda d: [d.line([(0, y), (W, y)], fill=(170, 116, 60, 255), width=2) for y in range(HORIZON + 46, H, 28)])
    return a, {'outdoor': True, 'seed': 970}


def park():
    """Parque de diversões: a roda-gigante com as cabines coloridas, luzes e a praça."""
    a = vgrad([(0, rgb('2a1e5a')), (0.6, rgb('c86a8a')), (1, rgb('f2b07a'))], 0, HORIZON)
    a = stars(a, 981, 20, HORIZON - 120)
    cx, cy, r = W * 0.62, HORIZON - 92, 88
    cab = [(240, 80, 80), (250, 200, 60), (90, 180, 250), (120, 220, 120), (220, 120, 230)]

    def wheel(d):
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(240, 230, 250, 255), width=5)
        for k in range(12):
            ang = k * math.pi / 6
            x, y = cx + r * math.cos(ang), cy + r * math.sin(ang)
            d.line([(cx, cy), (x, y)], fill=(220, 210, 236, 255), width=2)
            d.rounded_rectangle([x - 11, y - 6, x + 11, y + 14], radius=4, fill=cab[k % len(cab)] + (255,))
        d.polygon([(cx, cy), (cx - 70, HORIZON + 20), (cx - 56, HORIZON + 20)], fill=(200, 190, 220, 255))
        d.polygon([(cx, cy), (cx + 70, HORIZON + 20), (cx + 56, HORIZON + 20)], fill=(200, 190, 220, 255))
    a = layer(a, wheel)
    a = glow(a, cx, cy, r * 1.3, (255, 200, 230), 0.25)
    a = layer(a, lambda d: [d.ellipse([x - 3, 70 + 18 * math.sin(x / 40) - 3, x + 3, 70 + 18 * math.sin(x / 40) + 3], fill=((255, 230, 120) if (x // 30) % 2 else (255, 120, 160)) + (255,)) for x in range(0, int(W * 0.45), 30)])
    a = treeline(a, 982, HORIZON + 14, 34, ((40, 40, 70), (60, 56, 96), (90, 80, 130)), 4.5)
    a = ground(a, HORIZON + 30, rgb('c8a8b8'), rgb('7a5a72'), 983, 6, 0.06)
    a = layer(a, lambda d: [d.line([(W * 0.5 + (x - W * 0.5) * 0.2, HORIZON + 30), (x, H)], fill=(170, 140, 160, 255), width=2) for x in range(-300, W + 340, 110)] + [d.line([(0, y), (W, y)], fill=(170, 140, 160, 255), width=2) for y in (HORIZON + 56, HORIZON + 110, HORIZON + 200)])
    return a, {'outdoor': True, 'seed': 980}


def museum():
    """Museu (Pewter, Oreburgh, Nacrene): o esqueleto de um fóssil no meio, vitrines com pedras e o piso de mármore."""
    a = vgrad([(0, rgb('3a3046')), (1, rgb('6a5a64'))], 0, HORIZON + 30)
    # As colunas e a faixa da parede.
    a = layer(a, lambda d: [d.rectangle([x - 14, 20, x + 14, HORIZON + 26], fill=(150, 136, 150, 255)) for x in (60, 740)] +
              [d.rectangle([x - 20, 14, x + 20, 26], fill=(176, 160, 172, 255)) for x in (60, 740)] +
              [d.rectangle([0, 28, W, 34], fill=(196, 160, 96, 255))])
    # O esqueleto (um fóssil grande de pescoço comprido) sobre o pedestal, no fundo.
    bone = (238, 230, 210, 255)
    shade = (150, 138, 116, 255)

    def skeleton(d):
        cx, by = W * 0.5, HORIZON + 4
        d.rectangle([cx - 150, by, cx + 150, by + 22], fill=(120, 96, 70, 255))
        d.rectangle([cx - 160, by + 18, cx + 160, by + 26], fill=(96, 74, 52, 255))
        # pernas
        for x in (cx - 80, cx - 50, cx + 40, cx + 70):
            d.line([(x, by - 70), (x + 6, by - 30), (x, by)], fill=bone, width=7)
        # coluna (do rabo ao pescoço) e costelas
        spine = [(cx - 160, by - 50), (cx - 110, by - 74), (cx - 40, by - 88), (cx + 40, by - 84), (cx + 90, by - 100), (cx + 120, by - 140), (cx + 150, by - 160)]
        d.line(spine, fill=bone, width=8)
        for k in range(7):
            x = cx - 70 + k * 18
            top = by - 86 + abs(k - 3) * 2
            d.arc([x - 14, top - 4, x + 14, top + 46], 20, 160, fill=bone, width=4)
        # crânio
        d.ellipse([cx + 138, by - 176, cx + 182, by - 150], fill=bone)
        d.polygon([(cx + 176, by - 170), (cx + 206, by - 162), (cx + 176, by - 154)], fill=bone)
        d.ellipse([cx + 156, by - 168, cx + 164, by - 160], fill=shade)
    a = layer(a, skeleton)
    # As vitrines dos lados (vidro com as pedras e os fósseis menores).
    rnd = random.Random(1011)

    def cases(d):
        for x0 in (110, 560):
            d.rectangle([x0, HORIZON - 40, x0 + 130, HORIZON + 26], fill=(110, 84, 58, 255))
            d.rectangle([x0 + 6, HORIZON - 34, x0 + 124, HORIZON - 2], fill=(196, 226, 236, 255))
            for k in range(4):
                x = x0 + 16 + k * 28
                c = [(178, 150, 112), (120, 160, 190), (200, 170, 120), (150, 130, 170)][rnd.randrange(4)]
                d.ellipse([x, HORIZON - 22, x + 18, HORIZON - 8], fill=c + (255,))
                d.arc([x + 3, HORIZON - 20, x + 15, HORIZON - 10], 0, 300, fill=(90, 70, 50, 255), width=2)
            d.line([(x0 + 10, HORIZON - 32), (x0 + 40, HORIZON - 6)], fill=(255, 255, 255, 140), width=3)
    a = layer(a, cases)
    # Os holofotes em cima do fóssil e das vitrines.
    for x in (175, 400, 625):
        a = glow(a, x, HORIZON - 70, 120, (255, 236, 190), 0.35)
    # O piso de mármore em xadrez.
    a = ground(a, HORIZON + 30, rgb('e6ddd0'), rgb('b0a28c'), 1012, 5, 0.04)
    a = layer(a, lambda d: [d.line([(W * 0.5 + (x - W * 0.5) * 0.2, HORIZON + 30), (x, H)], fill=(186, 172, 150, 255), width=2) for x in range(-300, W + 340, 110)] +
              [d.line([(0, y), (W, y)], fill=(186, 172, 150, 255), width=2) for y in (HORIZON + 52, HORIZON + 96, HORIZON + 170, HORIZON + 280)])
    a = reflect(a, HORIZON + 30, HORIZON + 110, 0.18, 5)
    return a, {'outdoor': False, 'seed': 1010}


def silph():
    """Silph Co. (Saffron): o saguão do prédio, com as janelas para a cidade, os elevadores e o piso polido."""
    a = vgrad([(0, rgb('c8d4e0')), (1, rgb('9aaabc'))], 0, HORIZON + 30)
    rnd = random.Random(1021)

    def wall(d):
        # As janelas grandes com os prédios de Saffron lá fora.
        for x0 in (30, 560):
            d.rectangle([x0 - 6, 34, x0 + 216, HORIZON + 6], fill=(70, 84, 104, 255))
            d.rectangle([x0, 40, x0 + 210, HORIZON], fill=(126, 178, 226, 255))
            x = x0 + 4
            while x < x0 + 196:
                w, h = rnd.randint(18, 34), rnd.randint(40, 120)
                d.rectangle([x, HORIZON - h, x + w, HORIZON], fill=(86, 116, 160, 255))
                for yy in range(int(HORIZON - h + 6), HORIZON - 6, 10):
                    d.line([(x + 3, yy), (x + w - 3, yy)], fill=(190, 216, 240, 255), width=2)
                x += w + 4
            for k in (1, 2):
                d.line([(x0 + 70 * k, 40), (x0 + 70 * k, HORIZON)], fill=(70, 84, 104, 255), width=4)
            d.line([(x0 + 12, 50), (x0 + 60, HORIZON - 10)], fill=(255, 255, 255, 90), width=6)
        # Os dois elevadores no meio e o painel em cima.
        d.rectangle([290, 60, 510, HORIZON + 26], fill=(92, 104, 122, 255))
        for x0 in (304, 406):
            d.rectangle([x0, 84, x0 + 90, HORIZON + 26], fill=(176, 188, 200, 255))
            d.line([(x0 + 45, 84), (x0 + 45, HORIZON + 26)], fill=(110, 122, 138, 255), width=3)
            d.rectangle([x0 + 30, 68, x0 + 60, 78], fill=(30, 36, 46, 255))
            d.rectangle([x0 + 38, 70, x0 + 44, 76], fill=(255, 90, 60, 255))
        # A faixa da empresa.
        d.rectangle([0, 18, W, 30], fill=(40, 70, 130, 255))
        d.rectangle([340, 14, 460, 34], fill=(230, 236, 244, 255))
        d.rectangle([352, 20, 448, 28], fill=(200, 40, 50, 255))
    a = layer(a, wall)

    def plants(d):
        for x in (262, 538):
            d.rectangle([x - 12, HORIZON + 2, x + 12, HORIZON + 26], fill=(150, 96, 60, 255))
            for k in range(-3, 4):
                d.polygon([(x, HORIZON + 4), (x + k * 9 - 4, HORIZON - 40 + abs(k) * 6), (x + k * 9 + 4, HORIZON - 36 + abs(k) * 6)], fill=(50, 130 + (k % 2) * 30, 70, 255))
    a = layer(a, plants)
    for x in (135, 400, 665):
        a = glow(a, x, 6, 70, (255, 255, 255), 0.7)
    a = ground(a, HORIZON + 30, rgb('d6dde6'), rgb('8794a6'), 1022, 6, 0.04)
    a = layer(a, lambda d: [d.line([(W * 0.5 + (x - W * 0.5) * 0.2, HORIZON + 30), (x, H)], fill=(170, 182, 198, 255), width=2) for x in range(-300, W + 340, 110)] +
              [d.line([(0, y), (W, y)], fill=(170, 182, 198, 255), width=2) for y in (HORIZON + 52, HORIZON + 96, HORIZON + 170, HORIZON + 280)])
    a = reflect(a, HORIZON + 30, HORIZON + 130, 0.28, 5)
    return a, {'outdoor': False, 'seed': 1020, 'windows': [(30, 40, 240, HORIZON), (560, 40, 770, HORIZON)]}


def radio():
    """Radio Tower (Goldenrod): o estúdio, com a mesa de som, o aviso ON AIR, as caixas de som e a antena na janela."""
    a = vgrad([(0, rgb('3a2a4a')), (1, rgb('6a4a6a'))], 0, HORIZON + 30)
    rnd = random.Random(1031)

    def studio(d):
        # A espuma acústica da parede.
        for y in range(36, HORIZON, 22):
            for x in range(0, W, 22):
                c = 78 + ((x // 22 + y // 22) % 2) * 14
                d.polygon([(x, y + 22), (x + 11, y), (x + 22, y + 22)], fill=(c, c - 22, c + 16, 255))
        # A janela com a noite de Goldenrod e a antena piscando.
        d.rectangle([296, 44, 504, HORIZON - 34], fill=(40, 30, 54, 255))
        d.rectangle([304, 52, 496, HORIZON - 42], fill=(24, 34, 84, 255))
        for _ in range(26):
            x, y = rnd.uniform(308, 492), rnd.uniform(56, HORIZON - 90)
            d.point((x, y), fill=(240, 240, 255, 255))
        d.line([(400, HORIZON - 42), (400, 70)], fill=(200, 60, 60, 255), width=4)
        for k in range(5):
            y = HORIZON - 50 - k * 22
            d.line([(400 - 22 + k * 4, y), (400 + 22 - k * 4, y)], fill=(230, 230, 236, 255), width=3)
        d.ellipse([394, 60, 406, 72], fill=(255, 80, 70, 255))
        # ON AIR.
        d.rectangle([340, 18, 460, 40], fill=(40, 12, 16, 255))
        d.rectangle([346, 22, 454, 36], fill=(230, 40, 50, 255))
        for k, x in enumerate(range(356, 446, 16)):
            d.rectangle([x, 25, x + 9, 33], fill=(255, 226, 210, 255))
        # As caixas de som.
        for x0 in (60, 660):
            d.rectangle([x0, HORIZON - 110, x0 + 80, HORIZON + 26], fill=(26, 24, 32, 255))
            d.ellipse([x0 + 14, HORIZON - 96, x0 + 66, HORIZON - 44], fill=(70, 66, 82, 255))
            d.ellipse([x0 + 28, HORIZON - 82, x0 + 52, HORIZON - 58], fill=(30, 28, 38, 255))
            d.ellipse([x0 + 24, HORIZON - 34, x0 + 56, HORIZON - 2], fill=(70, 66, 82, 255))
        # A mesa de som (botões e luzes).
        d.rectangle([180, HORIZON - 26, 620, HORIZON + 26], fill=(54, 50, 66, 255))
        d.rectangle([180, HORIZON - 30, 620, HORIZON - 22], fill=(96, 90, 112, 255))
        for x in range(196, 610, 14):
            h = rnd.randint(6, 30)
            d.line([(x, HORIZON + 18), (x, HORIZON + 18 - h)], fill=[(90, 230, 120, 255), (250, 220, 80, 255), (250, 90, 80, 255)][min(2, h // 11)], width=5)
        # O microfone.
        d.line([(520, HORIZON - 30), (540, HORIZON - 70), (500, HORIZON - 96)], fill=(190, 190, 200, 255), width=4)
        d.ellipse([486, HORIZON - 110, 510, HORIZON - 86], fill=(60, 60, 70, 255))
    a = layer(a, studio)
    a = glow(a, 400, 30, 90, (255, 70, 60), 0.5)
    a = glow(a, 400, 66, 40, (255, 90, 80), 0.6)
    for x in (150, 650):
        a = glow(a, x, 10, 80, (255, 220, 190), 0.4)
    a = ground(a, HORIZON + 30, rgb('7a5a6e'), rgb('3a2838'), 1032, 6, 0.08)
    a = layer(a, lambda d: [d.line([(0, y), (W, y)], fill=(90, 66, 84, 255), width=2) for y in (HORIZON + 52, HORIZON + 96, HORIZON + 170, HORIZON + 280)])
    a = reflect(a, HORIZON + 30, HORIZON + 100, 0.14, 5)
    return a, {'outdoor': False, 'seed': 1030, 'windows': [(304, 52, 496, HORIZON - 42)]}


def seafoam():
    """Seafoam Islands: a caverna gelada com a correnteza do mar passando, blocos de gelo boiando e estalactites."""
    a = vgrad([(0, rgb('071a30')), (1, rgb('1f5a86'))], 0, HORIZON + 40)
    a = mountains(a, 1041, HORIZON + 10, 120, rgb('3f78a8'), rgb('173a5e'), rgb('12304e'), 0.25, 0.8, 10, freq=1.8)
    rnd = random.Random(1042)
    a = layer(a, lambda d: [(d.polygon([(x, -5), (x + w, -5), (x + w / 2, h)], fill=(140, 200, 235, 235)), d.polygon([(x, -5), (x + w * 0.4, -5), (x + w / 2, h)], fill=(214, 240, 255, 235))) for x, w, h in [(x, rnd.uniform(16, 30), rnd.uniform(30, 130)) for x in range(-10, W, 30)]], 0.6)
    # A abertura para o mar, no fundo, com a luz entrando.
    a = layer(a, lambda d: d.ellipse([300, HORIZON - 120, 500, HORIZON + 30], fill=(150, 214, 240, 255)), 6)
    a = glow(a, 400, HORIZON - 50, 170, (170, 230, 255), 0.6)
    # A água (a correnteza) no chão todo, com as margens de gelo dos lados.
    a = ground(a, HORIZON + 16, rgb('4aa6c8'), rgb('124a78'), 1043, 9, 0.08)
    a = reflect(a, HORIZON + 16, HORIZON + 80, 0.4, 3)

    def stream(d):
        for _ in range(420):
            y = rnd.uniform(HORIZON + 22, H)
            k = (y - HORIZON) / (H - HORIZON)
            s = 8 + k * 80
            x = rnd.uniform(-40, W)
            d.line([(x, y), (x + s, y + s * 0.04)], fill=(226, 248, 255, int(70 + 110 * k)), width=max(1, int(s / 26)))
    a = layer(a, stream, 0.5)

    def ice(d):
        # As margens de gelo e os blocos boiando.
        d.polygon([(0, HORIZON + 10), (170, HORIZON + 12), (120, HORIZON + 60), (40, HORIZON + 120), (0, HORIZON + 150)], fill=(206, 234, 248, 255))
        d.polygon([(W, HORIZON + 10), (W - 190, HORIZON + 12), (W - 130, HORIZON + 54), (W - 50, HORIZON + 110), (W, HORIZON + 140)], fill=(206, 234, 248, 255))
        d.line([(0, HORIZON + 150), (40, HORIZON + 120), (120, HORIZON + 60), (170, HORIZON + 12)], fill=(120, 176, 214, 255), width=4)
        d.line([(W, HORIZON + 140), (W - 50, HORIZON + 110), (W - 130, HORIZON + 54), (W - 190, HORIZON + 12)], fill=(120, 176, 214, 255), width=4)
        for x, y, s in ((250, HORIZON + 70, 44), (560, HORIZON + 46, 30), (690, H - 60, 70), (90, H - 40, 60)):
            d.polygon([(x - s, y), (x - s * 0.5, y - s * 0.28), (x + s * 0.6, y - s * 0.3), (x + s, y - s * 0.04), (x + s * 0.5, y + s * 0.18), (x - s * 0.6, y + s * 0.16)], fill=(232, 246, 255, 255))
            d.polygon([(x - s, y), (x - s * 0.6, y + s * 0.16), (x + s * 0.5, y + s * 0.18), (x + s, y - s * 0.04), (x + s * 0.5, y + s * 0.3), (x - s * 0.6, y + s * 0.28)], fill=(138, 190, 224, 255))
    a = layer(a, ice)
    for x, y, s in ((60, HORIZON + 6, 70), (730, HORIZON + 4, 80)):
        a = glow(a, x, y - s * 0.6, s * 1.2, (110, 200, 255), 0.5)
        a = layer(a, lambda d, x=x, y=y, s=s: [(d.polygon([(x + k * s * 0.32, y), (x + k * s * 0.32 - s * 0.12, y - s * 0.4), (x + k * s * 0.32 + k * s * 0.12, y - s * (1.25 - abs(k) * 0.4)), (x + k * s * 0.32 + s * 0.12, y - s * 0.4)], fill=(180, 234, 255, 245)), d.line([(x + k * s * 0.32, y - s * 0.4), (x + k * s * 0.32 + k * s * 0.12, y - s * (1.25 - abs(k) * 0.4))], fill=(255, 255, 255, 220), width=2)) for k in (-1, 0, 1)])
    a = motes(a, 1044, 110, (0, HORIZON - 60, W, H), (240, 250, 255), 1.8, 0.6)
    return a, {'outdoor': False, 'seed': 1040}


def lake():
    """Lake of Rage: o lago largo sob o céu carregado, os pinheiros de Mahogany em volta e o brilho vermelho na água."""
    a = vgrad([(0, rgb('2c3448')), (0.6, rgb('5a6478')), (1, rgb('8a8a96'))], 0, HORIZON)
    clouds = np.clip((noise(5, 1051, 4, 2.2) - 0.35) * 2.2, 0, 1) * np.clip((HORIZON - np.arange(H, dtype=np.float32)[:, None]) / 60, 0, 1)
    a = put(a, rgb('20283a'), clouds * 0.75)
    a = mountains(a, 1052, HORIZON - 6, 60, rgb('3a4a5c'), rgb('2a3a48'), rgb('6a7888'), 0.35, 0.5, 10, blur=2)
    rnd = random.Random(1053)
    a = layer(a, lambda d: [pine(d, x, HORIZON + 4, rnd.uniform(46, 96), (20, 44, 40), (38, 72, 60)) for x in range(-10, W + 20, 26)], 0.6)
    a = ground(a, HORIZON + 4, rgb('5a7a96'), rgb('15304e'), 1054, 9, 0.08)
    a = reflect(a, HORIZON + 4, HORIZON + 90, 0.5, 3)
    # O brilho vermelho do Gyarados lá no meio do lago.
    a = glow(a, W * 0.56, HORIZON + 30, 150, (220, 50, 50), 0.38)
    a = layer(a, lambda d: [d.ellipse([W * 0.56 - 90 + k * 14, HORIZON + 26 + k * 5, W * 0.56 + 90 - k * 14, HORIZON + 34 + k * 5], outline=(240, 120, 110, 150 - k * 30), width=2) for k in range(4)], 1.2)

    def waves(d):
        for _ in range(620):
            y = rnd.uniform(HORIZON + 8, H)
            k = (y - HORIZON) / (H - HORIZON)
            s = 6 + k * 70
            x = rnd.uniform(-40, W)
            d.arc([x, y - s * 0.12, x + s, y + s * 0.12], 200, 340, fill=(214, 228, 244, int(70 + 100 * k)), width=max(1, int(s / 22)))
    a = layer(a, waves, 0.5)
    # A margem de perto, com o capim e os juncos.
    a = put(a, rgb('2e4636'), mask(lambda d: d.polygon([(0, H * 0.74), (W * 0.30, H * 0.80), (W * 0.52, H * 0.93), (W * 0.56, H), (0, H)], fill=255), 2))
    a = blades(a, 1055, 260, H * 0.76, H + 10, [rgb('3a5a40'), rgb('52744c'), rgb('2a4232')], 0.2)
    fog = noise(5, 1056, 4, 3)
    band = np.clip(1 - np.abs(np.arange(H, dtype=np.float32)[:, None] - HORIZON - 10) / 110, 0, 1)
    a = put(a, rgb('b8c2d0'), np.clip((fog - 0.35) * 1.3, 0, 1) * band * 0.5)
    return a, {'outdoor': True, 'seed': 1050}


# ------------------------------------------------------------ lugares com cenário próprio (parecidos com os dos jogos)

def tiles(a, color, top=None, step=110):
    """O piso em perspectiva (as linhas que fogem para o horizonte e as que cruzam)."""
    top = HORIZON + 30 if top is None else top
    return layer(a, lambda d: [d.line([(W * 0.5 + (x - W * 0.5) * 0.2, top), (x, H)], fill=color, width=2) for x in range(-300, W + 340, step)] +
                 [d.line([(0, y), (W, y)], fill=color, width=2) for y in (top + 22, top + 66, top + 140, top + 250)])


def library():
    """Biblioteca (Canalave, Malie): estantes altas até o teto, escada de correr, janelas em arco e o tapete no meio."""
    a = vgrad([(0, rgb('4a3626')), (1, rgb('7a5a3c'))], 0, HORIZON + 30)
    rnd = random.Random(1101)
    cols = [(150, 40, 40), (40, 80, 140), (50, 110, 70), (170, 130, 50), (110, 60, 120), (90, 70, 50), (190, 180, 160)]

    def shelves(d):
        for x0 in (0, 150, 520, 670):
            d.rectangle([x0, 30, x0 + 132, HORIZON + 26], fill=(88, 58, 34, 255))
            for y in range(40, HORIZON + 4, 30):
                d.rectangle([x0 + 6, y + 22, x0 + 126, y + 26], fill=(60, 38, 22, 255))
                x = x0 + 8
                while x < x0 + 120:
                    w, h = rnd.randint(5, 10), rnd.randint(14, 21)
                    d.rectangle([x, y + 22 - h, x + w, y + 22], fill=cols[rnd.randrange(len(cols))] + (255,))
                    x += w + 1
        # A escada de correr.
        d.line([(196, HORIZON + 26), (214, 40)], fill=(170, 130, 80, 255), width=4)
        d.line([(222, HORIZON + 26), (240, 40)], fill=(170, 130, 80, 255), width=4)
        for k in range(7):
            y = HORIZON + 14 - k * 26
            d.line([(198 + k * 2.2, y), (224 + k * 2.2, y)], fill=(170, 130, 80, 255), width=3)
        # A janela em arco, no meio, e o relógio em cima.
        d.rectangle([330, 70, 470, HORIZON + 6], fill=(60, 40, 26, 255))
        d.pieslice([330, 20, 470, 120], 180, 360, fill=(60, 40, 26, 255))
        d.rectangle([340, 78, 460, HORIZON], fill=(150, 200, 236, 255))
        d.pieslice([340, 30, 460, 126], 180, 360, fill=(150, 200, 236, 255))
        d.line([(400, 30), (400, HORIZON)], fill=(60, 40, 26, 255), width=4)
        d.line([(340, 120), (460, 120)], fill=(60, 40, 26, 255), width=4)
        # As mesas de leitura com abajur.
        for x in (300, 500):
            d.rectangle([x - 34, HORIZON + 6, x + 34, HORIZON + 14], fill=(120, 80, 46, 255))
            d.rectangle([x - 28, HORIZON + 14, x - 24, HORIZON + 28], fill=(90, 58, 32, 255))
            d.rectangle([x + 24, HORIZON + 14, x + 28, HORIZON + 28], fill=(90, 58, 32, 255))
            d.polygon([(x - 10, HORIZON - 4), (x + 10, HORIZON - 4), (x + 6, HORIZON - 16), (x - 6, HORIZON - 16)], fill=(70, 150, 90, 255))
    a = layer(a, shelves)
    for x in (300, 500):
        a = glow(a, x, HORIZON - 2, 40, (255, 230, 150), 0.7)
    a = glow(a, 400, 110, 150, (190, 220, 255), 0.3)
    a = ground(a, HORIZON + 30, rgb('8a6238'), rgb('4a3018'), 1102, 6, 0.08)
    a = layer(a, lambda d: [d.line([(W * 0.5 + (x - W * 0.5) * 0.2, HORIZON + 30), (x, H)], fill=(70, 46, 24, 255), width=2) for x in range(-300, W + 340, 70)])
    # O tapete vermelho comprido.
    a = put(a, rgb('8c2a2a'), mask(lambda d: d.polygon([(W * 0.44, HORIZON + 30), (W * 0.56, HORIZON + 30), (W * 0.82, H), (W * 0.18, H)], fill=255)) * 0.9)
    a = layer(a, lambda d: [d.line([(W * 0.44, HORIZON + 30), (W * 0.18, H)], fill=(214, 170, 80, 255), width=4), d.line([(W * 0.56, HORIZON + 30), (W * 0.82, H)], fill=(214, 170, 80, 255), width=4)])
    return a, {'outdoor': False, 'seed': 1100, 'windows': [(340, 30, 460, HORIZON)]}


def mansion():
    """Pokémon Mansion (Cinnabar): a mansão queimada e abandonada, com as estátuas, as paredes rachadas e o tapete rasgado."""
    a = vgrad([(0, rgb('2a2030')), (1, rgb('5a4650'))], 0, HORIZON + 30)
    rnd = random.Random(1111)

    def hall(d):
        # Os painéis da parede, chamuscados, e as rachaduras.
        for x in range(0, W, 100):
            d.rectangle([x + 6, 40, x + 94, HORIZON + 20], outline=(98, 78, 84, 255), width=3)
        for _ in range(14):
            x, y = rnd.uniform(0, W), rnd.uniform(30, HORIZON)
            pts = [(x, y)]
            for _ in range(5):
                x, y = x + rnd.uniform(-22, 22), y + rnd.uniform(8, 26)
                pts.append((x, y))
            d.line(pts, fill=(24, 18, 26, 255), width=2)
        # As janelas quebradas com a noite lá fora.
        for x0 in (110, 610):
            d.rectangle([x0 - 6, 54, x0 + 86, HORIZON - 16], fill=(60, 46, 54, 255))
            d.rectangle([x0, 60, x0 + 80, HORIZON - 22], fill=(28, 34, 70, 255))
            d.polygon([(x0, HORIZON - 22), (x0 + 30, HORIZON - 70), (x0 + 46, HORIZON - 40), (x0 + 80, HORIZON - 90), (x0 + 80, HORIZON - 22)], fill=(60, 46, 54, 255))
            d.line([(x0 + 40, 60), (x0 + 40, HORIZON - 22)], fill=(60, 46, 54, 255), width=3)
        # A porta dupla no fundo e as duas estátuas (as do interruptor secreto).
        d.rectangle([350, 70, 450, HORIZON + 26], fill=(40, 28, 30, 255))
        d.line([(400, 70), (400, HORIZON + 26)], fill=(90, 66, 60, 255), width=3)
        for x in (290, 510):
            d.rectangle([x - 22, HORIZON - 6, x + 22, HORIZON + 26], fill=(110, 104, 112, 255))
            d.polygon([(x - 16, HORIZON - 6), (x - 20, HORIZON - 50), (x - 6, HORIZON - 70), (x + 12, HORIZON - 64), (x + 20, HORIZON - 44), (x + 16, HORIZON - 6)], fill=(150, 144, 152, 255))
            d.polygon([(x + 12, HORIZON - 64), (x + 26, HORIZON - 78), (x + 18, HORIZON - 54)], fill=(150, 144, 152, 255))
            d.ellipse([x + 2, HORIZON - 58, x + 8, HORIZON - 52], fill=(220, 60, 60, 255))
    a = layer(a, hall)
    for x in (290, 510):
        a = glow(a, x + 5, HORIZON - 55, 22, (255, 70, 60), 0.6)
    # A fuligem subindo pelas paredes.
    soot = np.clip((noise(6, 1112, 4, 1.4) - 0.42) * 2.4, 0, 1) * np.clip((HORIZON + 30 - np.arange(H, dtype=np.float32)[:, None]) / 180, 0, 1)
    a = put(a, rgb('120c10'), soot * 0.7)
    a = ground(a, HORIZON + 30, rgb('6a5248'), rgb('2a1e1c'), 1113, 6, 0.14, spots=(rgb('1a1214'), 0.6))
    a = tiles(a, (52, 40, 38, 255))
    a = put(a, rgb('6a1c26'), mask(lambda d: d.polygon([(W * 0.44, HORIZON + 30), (W * 0.56, HORIZON + 30), (W * 0.74, H * 0.86), (W * 0.60, H * 0.80), (W * 0.52, H * 0.92), (W * 0.40, H * 0.84), (W * 0.26, H * 0.9)], fill=255)) * 0.85)
    a = rocks(a, 1114, 10, HORIZON + 60, H - 10, (98, 86, 88), (140, 126, 126), (40, 32, 34), 8, 22)
    a = motes(a, 1115, 40, (0, 0, W, H), (200, 190, 180), 1.6, 0.8)
    return a, {'outdoor': False, 'seed': 1110, 'windows': [(110, 60, 190, HORIZON - 22), (610, 60, 690, HORIZON - 22)]}


def space():
    """Mossdeep Space Center: a sala de controle, com o foguete na plataforma pela janelona e os painéis de lançamento."""
    a = vgrad([(0, rgb('dfe6ee')), (1, rgb('a8b4c2'))], 0, HORIZON + 30)
    rnd = random.Random(1121)

    def room(d):
        # A janelona com o céu, o mar e o foguete na torre de lançamento.
        d.rectangle([194, 30, 606, HORIZON - 14], fill=(70, 84, 104, 255))
        d.rectangle([202, 38, 598, HORIZON - 22], fill=(120, 190, 240, 255))
        d.rectangle([202, HORIZON - 60, 598, HORIZON - 22], fill=(50, 120, 190, 255))
        d.rectangle([330, HORIZON - 66, 470, HORIZON - 54], fill=(120, 124, 130, 255))
        d.rectangle([372, 78, 428, HORIZON - 66], fill=(238, 240, 244, 255))
        d.polygon([(372, 78), (400, 44), (428, 78)], fill=(220, 60, 50, 255))
        d.polygon([(372, HORIZON - 96), (354, HORIZON - 66), (372, HORIZON - 66)], fill=(220, 60, 50, 255))
        d.polygon([(428, HORIZON - 96), (446, HORIZON - 66), (428, HORIZON - 66)], fill=(220, 60, 50, 255))
        d.ellipse([390, 96, 410, 116], fill=(90, 170, 230, 255))
        d.rectangle([372, 130, 428, 138], fill=(40, 70, 130, 255))
        for y in range(60, HORIZON - 66, 18):
            d.line([(440, y), (476, y)], fill=(170, 60, 50, 255), width=2)
        d.line([(440, 56), (440, HORIZON - 66)], fill=(170, 60, 50, 255), width=3)
        d.line([(476, 56), (476, HORIZON - 66)], fill=(170, 60, 50, 255), width=3)
        for k in (1, 2):
            d.line([(202 + 132 * k, 38), (202 + 132 * k, HORIZON - 22)], fill=(70, 84, 104, 255), width=4)
        # O contador de lançamentos e os monitores dos lados.
        d.rectangle([340, 8, 460, 26], fill=(20, 26, 36, 255))
        for k in range(4):
            d.rectangle([352 + k * 26, 12, 370 + k * 26, 22], fill=(90, 240, 140, 255))
        for x0 in (30, 630):
            d.rectangle([x0, 50, x0 + 140, HORIZON - 30], fill=(40, 50, 66, 255))
            for r in range(3):
                for c in range(3):
                    col = [(60, 200, 240), (90, 240, 140), (250, 210, 80)][(r + c) % 3]
                    d.rectangle([x0 + 8 + c * 44, 58 + r * 40, x0 + 44 + c * 44, 88 + r * 40], fill=col + (255,))
                    d.line([(x0 + 12 + c * 44, 80 + r * 40), (x0 + 24 + c * 44, 68 + r * 40), (x0 + 40 + c * 44, 76 + r * 40)], fill=(20, 30, 40, 255), width=2)
        # A bancada de controle.
        d.polygon([(120, HORIZON + 26), (150, HORIZON - 20), (650, HORIZON - 20), (680, HORIZON + 26)], fill=(96, 108, 124, 255))
        d.polygon([(150, HORIZON - 20), (160, HORIZON - 30), (640, HORIZON - 30), (650, HORIZON - 20)], fill=(150, 162, 178, 255))
        for x in range(170, 640, 16):
            d.rectangle([x, HORIZON - 12, x + 8, HORIZON - 6], fill=[(250, 90, 80, 255), (90, 230, 120, 255), (250, 220, 80, 255), (90, 170, 250, 255)][rnd.randrange(4)])
    a = layer(a, room)
    for x in (100, 400, 700):
        a = glow(a, x, 4, 70, (255, 255, 255), 0.6)
    a = ground(a, HORIZON + 30, rgb('ccd6e2'), rgb('7c8a9c'), 1122, 6, 0.04)
    a = tiles(a, (150, 164, 182, 255))
    a = reflect(a, HORIZON + 30, HORIZON + 120, 0.24, 5)
    return a, {'outdoor': False, 'seed': 1120, 'windows': [(202, 38, 598, HORIZON - 22)]}


def lab():
    """Laboratório (Devon, Cinnabar Lab, Weather Institute, Poké Ball Factory): máquinas, tubos de ensaio, monitores e a
    cápsula de vidro no meio."""
    a = vgrad([(0, rgb('d8e4e8')), (1, rgb('a4b8c0'))], 0, HORIZON + 30)
    rnd = random.Random(1131)

    def gear(d):
        d.rectangle([0, 24, W, 34], fill=(60, 120, 140, 255))
        # As máquinas grandes com fitas e luzes.
        for x0 in (20, 640):
            d.rectangle([x0, 50, x0 + 140, HORIZON + 26], fill=(110, 124, 138, 255))
            d.rectangle([x0 + 10, 60, x0 + 130, 110], fill=(24, 40, 50, 255))
            pts = [(x0 + 14 + k * 8, 100 - rnd.randint(4, 32)) for k in range(15)]
            d.line(pts, fill=(90, 240, 160, 255), width=2)
            for r in range(3):
                for c in range(6):
                    d.ellipse([x0 + 14 + c * 20, 124 + r * 22, x0 + 26 + c * 20, 136 + r * 22], fill=[(250, 90, 80, 255), (90, 230, 120, 255), (250, 220, 80, 255)][rnd.randrange(3)])
            d.rectangle([x0 + 10, HORIZON - 14, x0 + 130, HORIZON + 14], fill=(70, 84, 98, 255))
        # A cápsula de vidro (a do fóssil / do experimento) com os canos.
        d.rectangle([356, 44, 444, 58], fill=(70, 84, 98, 255))
        d.rectangle([364, 58, 436, HORIZON + 6], fill=(150, 226, 220, 255))
        d.rectangle([372, 58, 384, HORIZON + 6], fill=(214, 248, 244, 255))
        d.rectangle([350, HORIZON + 6, 450, HORIZON + 26], fill=(70, 84, 98, 255))
        for k in range(8):
            y = HORIZON - 10 - k * 18
            d.ellipse([392 + (k % 3) * 9, y, 400 + (k % 3) * 9, y + 8], outline=(240, 255, 255, 255), width=2)
        d.line([(356, 50), (250, 50), (250, HORIZON + 26)], fill=(90, 104, 118, 255), width=6)
        d.line([(444, 50), (550, 50), (550, HORIZON + 26)], fill=(90, 104, 118, 255), width=6)
        # As bancadas com os tubos de ensaio e o microscópio.
        for x0 in (190, 480):
            d.rectangle([x0, HORIZON - 10, x0 + 130, HORIZON + 26], fill=(226, 232, 236, 255))
            d.rectangle([x0, HORIZON - 14, x0 + 130, HORIZON - 8], fill=(150, 162, 172, 255))
            for k in range(5):
                x = x0 + 12 + k * 14
                d.rectangle([x, HORIZON - 34, x + 6, HORIZON - 14], fill=[(240, 110, 130, 255), (110, 190, 250, 255), (140, 230, 130, 255), (250, 210, 100, 255)][k % 4])
            d.rectangle([x0 + 92, HORIZON - 30, x0 + 116, HORIZON - 14], fill=(50, 60, 72, 255))
            d.line([(x0 + 104, HORIZON - 30), (x0 + 96, HORIZON - 46)], fill=(50, 60, 72, 255), width=5)
    a = layer(a, gear)
    a = glow(a, 400, 130, 90, (130, 240, 230), 0.5)
    for x in (130, 400, 670):
        a = glow(a, x, 6, 60, (255, 255, 255), 0.6)
    a = ground(a, HORIZON + 30, rgb('d4dee4'), rgb('8494a0'), 1132, 6, 0.04)
    a = tiles(a, (160, 176, 186, 255))
    a = reflect(a, HORIZON + 30, HORIZON + 110, 0.2, 5)
    return a, {'outdoor': False, 'seed': 1130}


def observatory():
    """Hokulani Observatory: a cúpula aberta para o céu estrelado e o telescópio enorme apontado para cima."""
    a = vgrad([(0, rgb('1a2238')), (1, rgb('3a4862'))], 0, HORIZON + 30)
    # A cúpula (as nervuras) e a fenda aberta com as estrelas.
    a = layer(a, lambda d: [d.arc([-200 + k * 30, -260 + k * 6, W + 200 - k * 30, HORIZON + 200], 180, 360, fill=(86, 100, 128, 255), width=3) for k in range(0, 9)])
    slit = mask(lambda d: d.polygon([(330, 0), (470, 0), (500, HORIZON - 30), (300, HORIZON - 30)], fill=255))
    night = vgrad([(0, rgb('060a24')), (1, rgb('1c2a66'))], 0, HORIZON)
    a = put(a, night, slit)
    st = stars(np.zeros((H, W, 3), np.float32), 1141, 160, HORIZON)
    a = np.clip(a + st * slit[..., None], 0, 255)
    a = glow(a, 430, 60, 60, (150, 120, 255), 0.35)

    def scope(d):
        d.line([(300, 0), (300, HORIZON - 30)], fill=(110, 124, 150, 255), width=5)
        d.line([(500, 0), (470, 0)], fill=(110, 124, 150, 255), width=5)
        d.line([(470, 0), (500, HORIZON - 30)], fill=(110, 124, 150, 255), width=5)
        # O telescópio (o tubo branco), o suporte e a ocular.
        d.polygon([(250, HORIZON + 10), (290, HORIZON + 30), (470, 70), (420, 44)], fill=(232, 236, 244, 255))
        d.polygon([(250, HORIZON + 10), (262, HORIZON + 16), (432, 50), (420, 44)], fill=(255, 255, 255, 255))
        d.polygon([(410, 36), (480, 74), (490, 56), (424, 22)], fill=(60, 70, 96, 255))
        d.polygon([(300, HORIZON + 26), (340, HORIZON - 30), (370, HORIZON - 30), (400, HORIZON + 26)], fill=(70, 84, 112, 255))
        d.rectangle([280, HORIZON + 18, 420, HORIZON + 30], fill=(50, 60, 84, 255))
        d.rectangle([232, HORIZON, 256, HORIZON + 18], fill=(40, 48, 66, 255))
        # Os computadores do Sophocles.
        for x0 in (40, 620):
            d.rectangle([x0, HORIZON - 40, x0 + 140, HORIZON + 26], fill=(54, 64, 88, 255))
            for c in range(3):
                d.rectangle([x0 + 8 + c * 44, HORIZON - 32, x0 + 44 + c * 44, HORIZON - 6], fill=[(90, 200, 250, 255), (250, 220, 90, 255), (120, 240, 160, 255)][c])
                d.line([(x0 + 12 + c * 44, HORIZON - 12), (x0 + 26 + c * 44, HORIZON - 24), (x0 + 40 + c * 44, HORIZON - 16)], fill=(20, 28, 44, 255), width=2)
    a = layer(a, scope)
    for x in (110, 690):
        a = glow(a, x, HORIZON - 20, 70, (120, 200, 255), 0.4)
    a = ground(a, HORIZON + 30, rgb('5a6a88'), rgb('222a40'), 1142, 6, 0.06)
    a = tiles(a, (74, 88, 116, 255))
    a = reflect(a, HORIZON + 30, HORIZON + 120, 0.25, 5)
    return a, {'outdoor': False, 'seed': 1140, 'windows': [(330, 0, 470, HORIZON - 30)]}


def coldstorage():
    """Cold Storage (Driftveil): o galpão frigorífico, com os contêineres empilhados, o gelo no chão e o ar gelado."""
    a = vgrad([(0, rgb('24384e')), (1, rgb('4a6a86'))], 0, HORIZON + 30)
    rnd = random.Random(1151)
    cols = [(60, 110, 160), (50, 130, 130), (150, 70, 60), (170, 150, 70), (90, 100, 120)]

    def boxes(d):
        # As vigas do teto e as lâmpadas.
        for x in range(0, W, 100):
            d.line([(x, 0), (x + 60, 40)], fill=(50, 70, 92, 255), width=5)
        d.rectangle([0, 36, W, 44], fill=(60, 84, 108, 255))
        # Os contêineres empilhados dos dois lados.
        for x0, n in ((0, 3), (150, 2), (530, 2), (660, 3)):
            for k in range(n):
                y1 = HORIZON + 26 - k * 62
                c = cols[rnd.randrange(len(cols))]
                d.rectangle([x0, y1 - 60, x0 + 140, y1], fill=c + (255,))
                for x in range(x0 + 10, x0 + 140, 12):
                    d.line([(x, y1 - 56), (x, y1 - 4)], fill=tuple(int(v * 0.78) for v in c) + (255,), width=2)
                d.rectangle([x0, y1 - 62, x0 + 140, y1 - 56], fill=(226, 240, 250, 255))
                for x in range(x0 + 8, x0 + 136, 14):
                    d.polygon([(x, y1 - 56), (x + 8, y1 - 56), (x + 4, y1 - 56 + rnd.randint(8, 22))], fill=(214, 236, 250, 255))
        # A porta frigorífica no fundo.
        d.rectangle([330, 70, 470, HORIZON + 26], fill=(150, 168, 184, 255))
        d.rectangle([338, 78, 462, HORIZON + 26], fill=(190, 206, 220, 255))
        d.line([(400, 78), (400, HORIZON + 26)], fill=(120, 138, 156, 255), width=3)
        d.rectangle([386, 140, 396, 170], fill=(60, 70, 84, 255))
        d.rectangle([372, 52, 428, 66], fill=(30, 50, 80, 255))
        d.rectangle([378, 55, 422, 63], fill=(120, 220, 255, 255))
    a = layer(a, boxes)
    for x in (110, 400, 690):
        a = glow(a, x, 40, 80, (200, 236, 255), 0.5)
    a = ground(a, HORIZON + 30, rgb('a8c8de'), rgb('3e607e'), 1152, 7, 0.08)
    a = reflect(a, HORIZON + 30, HORIZON + 130, 0.36, 4)
    cover = np.clip((noise(8, 1153, 5, 3.0) - 0.5) * 3, 0, 1) * (1 - np.clip((HORIZON + 40 - np.arange(H, dtype=np.float32)[:, None]) / 40, 0, 1))
    a = put(a, rgb('eef6ff'), cover * 0.6)
    mist = noise(5, 1154, 4, 3)
    band = np.clip(1 - np.abs(np.arange(H, dtype=np.float32)[:, None] - HORIZON - 40) / 150, 0, 1)
    a = put(a, rgb('dcecf8'), np.clip((mist - 0.35) * 1.3, 0, 1) * band * 0.5)
    a = motes(a, 1155, 80, (0, 0, W, H), (240, 250, 255), 1.6, 0.6)
    return a, {'outdoor': False, 'seed': 1150}


def dojo():
    """Fighting Dojo (Saffron): o tatame de madeira, os pergaminhos na parede, os troncos de treino e o altar no fundo."""
    a = vgrad([(0, rgb('6a4a2a')), (1, rgb('a87a48'))], 0, HORIZON + 30)

    def wall(d):
        # As tábuas da parede e a viga do teto.
        for x in range(0, W, 50):
            d.line([(x, 30), (x, HORIZON + 26)], fill=(120, 86, 50, 255), width=2)
        d.rectangle([0, 18, W, 34], fill=(70, 44, 24, 255))
        d.rectangle([0, HORIZON + 4, W, HORIZON + 26], fill=(82, 54, 30, 255))
        # O altar no fundo com o pergaminho grande e as duas estátuas (Hitmonlee e Hitmonchan).
        d.rectangle([330, 50, 470, HORIZON + 4], fill=(86, 56, 30, 255))
        d.rectangle([352, 60, 448, HORIZON - 26], fill=(240, 232, 208, 255))
        d.rectangle([346, 56, 454, 64], fill=(60, 36, 20, 255))
        d.rectangle([346, HORIZON - 30, 454, HORIZON - 22], fill=(60, 36, 20, 255))
        d.line([(400, 76), (400, HORIZON - 42)], fill=(30, 24, 22, 255), width=9)
        d.line([(372, 100), (428, 100)], fill=(30, 24, 22, 255), width=8)
        d.line([(376, 150), (424, 132)], fill=(30, 24, 22, 255), width=7)
        for x in (300, 500):
            d.rectangle([x - 16, HORIZON - 16, x + 16, HORIZON + 4], fill=(110, 104, 100, 255))
            d.ellipse([x - 12, HORIZON - 52, x + 12, HORIZON - 16], fill=(170, 130, 96, 255))
            d.ellipse([x - 7, HORIZON - 64, x + 7, HORIZON - 48], fill=(170, 130, 96, 255))
        # Os pergaminhos dos lados.
        for x0, c in ((70, (190, 50, 50)), (190, (40, 70, 130)), (560, (40, 70, 130)), (680, (190, 50, 50))):
            d.rectangle([x0, 56, x0 + 50, HORIZON - 30], fill=(240, 232, 208, 255))
            d.rectangle([x0 - 4, 52, x0 + 54, 60], fill=(60, 36, 20, 255))
            d.ellipse([x0 + 10, 90, x0 + 40, 120], fill=c + (255,))
            d.line([(x0 + 25, 130), (x0 + 25, HORIZON - 44)], fill=(30, 24, 22, 255), width=5)
        # Os troncos de treino (com corda) dos lados.
        for x in (30, 770):
            d.rectangle([x - 12, HORIZON - 80, x + 12, HORIZON + 26], fill=(150, 104, 60, 255))
            for y in range(HORIZON - 70, HORIZON - 20, 9):
                d.line([(x - 12, y), (x + 12, y + 4)], fill=(226, 206, 160, 255), width=3)
    a = layer(a, wall)
    for x in (140, 400, 660):
        a = glow(a, x, 20, 80, (255, 220, 160), 0.4)
    a = ground(a, HORIZON + 30, rgb('c89a58'), rgb('7a5228'), 1162, 6, 0.08)
    a = layer(a, lambda d: [d.line([(W * 0.5 + (x - W * 0.5) * 0.2, HORIZON + 30), (x, H)], fill=(120, 84, 44, 255), width=2) for x in range(-300, W + 340, 60)])
    # O tatame verde no meio.
    a = put(a, rgb('8a9a52'), mask(lambda d: d.polygon([(W * 0.30, HORIZON + 44), (W * 0.70, HORIZON + 44), (W * 0.96, H - 20), (W * 0.04, H - 20)], fill=255)) * 0.8)
    a = layer(a, lambda d: d.line([(W * 0.30, HORIZON + 44), (W * 0.70, HORIZON + 44), (W * 0.96, H - 20), (W * 0.04, H - 20), (W * 0.30, HORIZON + 44)], fill=(60, 70, 34, 255), width=4))
    a = reflect(a, HORIZON + 30, HORIZON + 90, 0.12, 5)
    return a, {'outdoor': False, 'seed': 1160}


def dragonsden():
    """Dragon's Den (Blackthorn): a caverna alagada com o santuário de telhado vermelho na ilhota e os redemoinhos."""
    a = vgrad([(0, rgb('0c1420')), (1, rgb('243a52'))], 0, HORIZON + 40)
    a = mountains(a, 1171, HORIZON + 14, 130, rgb('3a4c62'), rgb('18222e'), rgb('121a26'), 0.25, 0.8, 10, freq=1.6)
    rnd = random.Random(1172)
    a = layer(a, lambda d: [d.polygon([(x, -5), (x + w, -5), (x + w / 2, h)], fill=(44, 58, 76, 255)) for x, w, h in [(x, rnd.uniform(18, 40), rnd.uniform(30, 120)) for x in range(-10, W, 34)]], 0.6)
    a = ground(a, HORIZON + 14, rgb('3a86a8'), rgb('0e3252'), 1173, 9, 0.08)

    def shrine(d):
        cx, by = W * 0.5, HORIZON + 22
        # A ilhota de pedra.
        d.ellipse([cx - 150, by - 8, cx + 150, by + 26], fill=(84, 92, 100, 255))
        d.ellipse([cx - 140, by - 12, cx + 140, by + 14], fill=(112, 120, 126, 255))
        # O santuário: os degraus, as paredes brancas, as colunas vermelhas e o telhado curvo.
        d.rectangle([cx - 70, by - 22, cx + 70, by - 8], fill=(150, 150, 150, 255))
        d.rectangle([cx - 56, by - 80, cx + 56, by - 22], fill=(236, 228, 210, 255))
        d.rectangle([cx - 14, by - 60, cx + 14, by - 22], fill=(60, 36, 28, 255))
        for x in (cx - 56, cx - 30, cx + 24, cx + 50):
            d.rectangle([x, by - 80, x + 6, by - 22], fill=(190, 50, 44, 255))
        d.polygon([(cx - 96, by - 76), (cx - 70, by - 100), (cx + 70, by - 100), (cx + 96, by - 76), (cx + 76, by - 82), (cx - 76, by - 82)], fill=(170, 40, 40, 255))
        d.polygon([(cx - 70, by - 100), (cx - 40, by - 126), (cx + 40, by - 126), (cx + 70, by - 100)], fill=(196, 56, 50, 255))
        d.rectangle([cx - 42, by - 132, cx + 42, by - 124], fill=(60, 60, 70, 255))
        # As lanternas de pedra.
        for x in (cx - 110, cx + 110):
            d.rectangle([x - 4, by - 26, x + 4, by], fill=(130, 136, 140, 255))
            d.rectangle([x - 10, by - 40, x + 10, by - 26], fill=(150, 156, 160, 255))
            d.rectangle([x - 5, by - 37, x + 5, by - 29], fill=(255, 220, 130, 255))
            d.polygon([(x - 14, by - 40), (x, by - 52), (x + 14, by - 40)], fill=(110, 116, 120, 255))
    a = layer(a, shrine)
    for x in (W * 0.5 - 110, W * 0.5 + 110):
        a = glow(a, x, HORIZON - 12, 36, (255, 210, 120), 0.7)
    a = reflect(a, HORIZON + 46, HORIZON + 130, 0.4, 3)

    def swirl(d):
        for x, y, s in ((150, HORIZON + 90, 60), (640, HORIZON + 120, 80), (330, H - 70, 110)):
            for k in range(5):
                r = s * (1 - k * 0.17)
                d.arc([x - r, y - r * 0.28, x + r, y + r * 0.28], 20 + k * 50, 250 + k * 50, fill=(220, 244, 255, 200 - k * 24), width=max(1, int(s / 26)))
        for _ in range(260):
            y = rnd.uniform(HORIZON + 30, H)
            k = (y - HORIZON) / (H - HORIZON)
            s = 6 + k * 60
            x = rnd.uniform(-40, W)
            d.arc([x, y - s * 0.12, x + s, y + s * 0.12], 200, 340, fill=(200, 236, 250, int(60 + 90 * k)), width=1)
    a = layer(a, swirl, 0.5)
    a = motes(a, 1174, 50, (0, HORIZON - 60, W, H), (160, 220, 255), 2, 1.2)
    return a, {'outdoor': False, 'seed': 1170}


def spearpillar():
    """Spear Pillar (Mt. Coronet): o topo da montanha acima das nuvens, as colunas quebradas e o céu rasgado."""
    a = vgrad([(0, rgb('120a2e')), (0.6, rgb('3a2a6e')), (1, rgb('8a6aa8'))], 0, HORIZON)
    a = stars(a, 1181, 90, HORIZON - 20)
    # O rasgo no céu (a distorção do espaço-tempo).
    a = glow(a, W * 0.5, 70, 190, (190, 120, 255), 0.5)
    a = layer(a, lambda d: [d.arc([W * 0.5 - r, 70 - r * 0.5, W * 0.5 + r, 70 + r * 0.5], 0, 360, fill=(230, 190, 255, 150 - k * 30), width=3) for k, r in enumerate((40, 80, 130, 190))], 2)
    a = glow(a, W * 0.5, 70, 30, (255, 255, 255), 1.2)
    a = mountains(a, 1182, HORIZON + 6, 50, rgb('6a6a8a'), rgb('4a4a66'), rgb('a898c8'), 0.4, 0.6, 10, blur=2, snowcap=rgb('e6e6f4'))
    # O mar de nuvens embaixo.
    cl = np.clip((noise(6, 1183, 4, 3.0) - 0.4) * 2.2, 0, 1) * np.clip(1 - np.abs(np.arange(H, dtype=np.float32)[:, None] - HORIZON + 4) / 34, 0, 1)
    a = put(a, rgb('d8cfe8'), cl * 0.8)
    a = ground(a, HORIZON + 20, rgb('b8b4c8'), rgb('5c5870'), 1184, 6, 0.1)
    a = tiles(a, (132, 126, 150, 255), HORIZON + 20, 130)
    rnd = random.Random(1185)

    def columns(d):
        for x, h, broken in ((70, 190, False), (190, 110, True), (300, 150, True), (500, 170, True), (610, 96, True), (730, 200, False)):
            y1 = HORIZON + 30 + abs(x - W / 2) * 0.06
            w = 22 + abs(x - W / 2) * 0.03
            d.rectangle([x - w * 0.8, y1 - 10, x + w * 0.8, y1], fill=(150, 146, 166, 255))
            top = y1 - h
            d.rectangle([x - w / 2, top, x + w / 2, y1 - 10], fill=(204, 200, 216, 255))
            d.rectangle([x - w / 2, top, x - w / 2 + w * 0.3, y1 - 10], fill=(232, 230, 242, 255))
            for k in range(1, 4):
                d.line([(x - w / 2 + k * w / 4, top), (x - w / 2 + k * w / 4, y1 - 10)], fill=(160, 156, 178, 255), width=1)
            if broken:
                d.polygon([(x - w / 2 - 1, top - 1), (x - w / 4, top + 14), (x, top + 2), (x + w / 4, top + 18), (x + w / 2 + 1, top - 1)], fill=(58, 42, 110, 255))
            else:
                d.rectangle([x - w * 0.75, top - 10, x + w * 0.75, top], fill=(170, 166, 186, 255))
    a = layer(a, columns)
    a = rocks(a, 1186, 12, HORIZON + 70, H - 10, (160, 156, 176), (214, 210, 228), (84, 80, 104), 8, 26)
    a = motes(a, 1187, 60, (0, 0, W, H), (220, 190, 255), 2.2, 1.2)
    return a, {'outdoor': True, 'seed': 1180}


def origin():
    """Cave of Origin (Sootopolis): a câmara funda de pedra antiga, com o lago brilhando no meio e as inscrições."""
    a = vgrad([(0, rgb('0a0e1a')), (1, rgb('1e2c44'))], 0, HORIZON + 40)
    a = mountains(a, 1191, HORIZON + 20, 150, rgb('34405a'), rgb('141a28'), rgb('0e1420'), 0.2, 0.9, 9, freq=1.4)
    rnd = random.Random(1192)
    a = layer(a, lambda d: [d.polygon([(x, -5), (x + w, -5), (x + w / 2, h)], fill=(40, 50, 70, 255)) for x, w, h in [(x, rnd.uniform(18, 36), rnd.uniform(30, 110)) for x in range(-10, W, 36)]], 0.6)

    def glyphs(d):
        # As inscrições antigas na parede do fundo (os sinais do Groudon e do Kyogre).
        for x0, c in ((150, (230, 80, 60)), (560, (70, 150, 240))):
            d.rectangle([x0, 70, x0 + 90, HORIZON - 10], outline=c + (220,), width=3)
            d.line([(x0 + 14, 100), (x0 + 76, 100)], fill=c + (220,), width=3)
            d.arc([x0 + 20, 110, x0 + 70, 160], 0, 300, fill=c + (220,), width=3)
            d.line([(x0 + 45, 120), (x0 + 45, 176)], fill=c + (220,), width=3)
            d.line([(x0 + 20, 176), (x0 + 70, 176)], fill=c + (220,), width=3)
    a = layer(a, glyphs, 0.8)
    a = glow(a, 195, 130, 90, (255, 90, 60), 0.35)
    a = glow(a, 605, 130, 90, (70, 150, 255), 0.35)
    a = ground(a, HORIZON + 24, rgb('4c5a72'), rgb('181e2c'), 1193, 5, 0.14)
    # O lago no meio, brilhando de baixo.
    pool = mask(lambda d: d.ellipse([W * 0.18, HORIZON + 50, W * 0.82, HORIZON + 150], fill=255), 3)
    a = put(a, vgrad([(0, rgb('58d8e8')), (1, rgb('1a6aa0'))], HORIZON + 40, HORIZON + 160), pool)
    a = glow(a, W * 0.5, HORIZON + 100, 260, (90, 220, 240), 0.5)
    a = layer(a, lambda d: [d.ellipse([W * 0.5 - r, HORIZON + 100 - r * 0.2, W * 0.5 + r, HORIZON + 100 + r * 0.2], outline=(214, 250, 255, 150 - k * 30), width=2) for k, r in enumerate((60, 120, 180, 240))], 1)
    a = rocks(a, 1194, 14, HORIZON + 30, H - 10, (70, 82, 104), (110, 124, 150), (20, 26, 38), 10, 34)
    a = motes(a, 1195, 70, (0, HORIZON - 80, W, H), (150, 240, 255), 2.2, 1.4)
    return a, {'outdoor': False, 'seed': 1190}


def burnedtower():
    """Burned Tower (Ecruteak): a torre queimada, com as vigas carbonizadas, o buraco no assoalho e o céu pelo teto caído."""
    a = vgrad([(0, rgb('2a1c18')), (1, rgb('5a4032'))], 0, HORIZON + 30)
    rnd = random.Random(1201)
    # O teto desabado: o céu do entardecer aparecendo por cima.
    hole = mask(lambda d: d.polygon([(220, 0), (600, 0), (560, 60), (470, 44), (420, 96), (330, 70), (270, 110)], fill=255))
    a = put(a, vgrad([(0, rgb('c86a3a')), (1, rgb('f0c080'))], 0, 120), hole)

    def beams(d):
        # As tábuas da parede e as colunas queimadas.
        for x in range(0, W, 40):
            d.line([(x, 0), (x, HORIZON + 26)], fill=(50, 34, 26, 255), width=2)
        for x in (60, 250, 550, 740):
            d.rectangle([x - 16, 0, x + 16, HORIZON + 26], fill=(34, 24, 20, 255))
            d.rectangle([x - 16, 0, x - 8, HORIZON + 26], fill=(60, 42, 32, 255))
        # As vigas caídas, atravessadas.
        for (x0, y0, x1, y1) in ((30, 60, 330, 130), (470, 150, 790, 40), (200, 180, 520, 120)):
            d.line([(x0, y0), (x1, y1)], fill=(24, 16, 14, 255), width=16)
            d.line([(x0, y0 - 5), (x1, y1 - 5)], fill=(70, 48, 36, 255), width=4)
        # A estátua do fundo (a das feras lendárias).
        d.rectangle([370, HORIZON - 10, 430, HORIZON + 26], fill=(90, 84, 80, 255))
        d.polygon([(378, HORIZON - 10), (372, HORIZON - 50), (390, HORIZON - 76), (410, HORIZON - 76), (428, HORIZON - 50), (422, HORIZON - 10)], fill=(130, 122, 116, 255))
    a = layer(a, beams)
    a = glow(a, 410, 40, 200, (255, 170, 90), 0.3)
    a = ground(a, HORIZON + 30, rgb('6a4a34'), rgb('2a1a12'), 1202, 6, 0.16, spots=(rgb('140c0a'), 0.7))
    a = layer(a, lambda d: [d.line([(0, y), (W, y)], fill=(40, 26, 18, 255), width=2) for y in range(HORIZON + 46, H, 30)] +
              [d.line([(x + (k % 2) * 60, HORIZON + 46 + k * 30), (x + (k % 2) * 60, HORIZON + 76 + k * 30)], fill=(40, 26, 18, 255), width=2) for k in range(12) for x in range(0, W, 120)])
    # O buraco no assoalho (por onde se cai no porão).
    a = put(a, rgb('0a0606'), mask(lambda d: d.polygon([(470, HORIZON + 70), (640, HORIZON + 60), (720, HORIZON + 110), (660, HORIZON + 170), (520, HORIZON + 176), (440, HORIZON + 120)], fill=255), 1.5) * 0.95)
    a = layer(a, lambda d: d.line([(470, HORIZON + 70), (640, HORIZON + 60), (720, HORIZON + 110), (660, HORIZON + 170), (520, HORIZON + 176), (440, HORIZON + 120), (470, HORIZON + 70)], fill=(96, 66, 44, 255), width=3))
    soot = np.clip((noise(6, 1203, 4, 1.4) - 0.45) * 2.4, 0, 1)
    a = put(a, rgb('100a08'), soot * 0.4)
    a = motes(a, 1204, 60, (0, 0, W, H), (255, 170, 90), 1.8, 0.8)
    return a, {'outdoor': False, 'seed': 1200, 'windows': [(270, 0, 560, 60)]}


def lighthouse():
    """Farol (Glitter Lighthouse, Vista Lighthouse): a sala do topo, com a lâmpada enorme, as janelas em volta e o mar."""
    a = vgrad([(0, rgb('c8d0d8')), (1, rgb('8e9aa8'))], 0, HORIZON + 30)

    def room(d):
        # As janelas em volta, com o céu e o mar (e os barcos).
        for x0 in (20, 180, 500, 660):
            d.rectangle([x0 - 6, 44, x0 + 126, HORIZON - 4], fill=(84, 96, 112, 255))
            d.rectangle([x0, 50, x0 + 120, HORIZON - 10], fill=(140, 200, 244, 255))
            d.rectangle([x0, HORIZON - 70, x0 + 120, HORIZON - 10], fill=(40, 110, 180, 255))
            d.line([(x0 + 60, 50), (x0 + 60, HORIZON - 10)], fill=(84, 96, 112, 255), width=3)
            d.line([(x0 + 10, HORIZON - 50), (x0 + 50, HORIZON - 50)], fill=(220, 240, 255, 255), width=2)
            d.line([(x0 + 70, HORIZON - 30), (x0 + 112, HORIZON - 30)], fill=(220, 240, 255, 255), width=2)
        d.polygon([(214, HORIZON - 70), (232, HORIZON - 70), (236, HORIZON - 62), (210, HORIZON - 62)], fill=(240, 240, 240, 255))
        d.polygon([(222, HORIZON - 70), (222, HORIZON - 92), (236, HORIZON - 72)], fill=(240, 80, 70, 255))
        d.rectangle([0, 24, W, 36], fill=(190, 60, 54, 255))
        # A lâmpada do farol: a base, a lente de vidro e o brilho.
        d.rectangle([350, HORIZON - 6, 450, HORIZON + 26], fill=(84, 96, 112, 255))
        d.rectangle([340, HORIZON - 14, 460, HORIZON - 4], fill=(120, 132, 148, 255))
        d.ellipse([352, 60, 448, HORIZON - 10], fill=(255, 240, 170, 255))
        for k in range(5):
            d.arc([352 + k * 9, 60, 448 - k * 9, HORIZON - 10], 0, 360, fill=(220, 190, 110, 255), width=2)
        d.rectangle([340, 52, 460, 62], fill=(120, 132, 148, 255))
        d.polygon([(340, 52), (400, 30), (460, 52)], fill=(190, 60, 54, 255))
    a = layer(a, room)
    a = glow(a, 400, 130, 200, (255, 236, 150), 0.28)
    a = glow(a, 400, 130, 60, (255, 255, 230), 0.45)
    a = layer(a, lambda d: [d.polygon([(400, 130), (0, 60 + k * 30), (0, 110 + k * 30)], fill=(255, 244, 190, 40)) for k in (0, 2)] + [d.polygon([(400, 130), (W, 80 + k * 30), (W, 130 + k * 30)], fill=(255, 244, 190, 40)) for k in (0, 2)], 8)
    a = ground(a, HORIZON + 30, rgb('b8a078'), rgb('5e4c34'), 1212, 6, 0.08)
    a = layer(a, lambda d: [d.arc([W * 0.5 - r, HORIZON + 40 - r * 0.1, W * 0.5 + r, HORIZON + 40 + r * 0.5], 0, 180, fill=(92, 74, 50, 255), width=2) for r in (120, 240, 380, 540, 720)] +
              [d.line([(W * 0.5 + (x - W * 0.5) * 0.2, HORIZON + 30), (x, H)], fill=(92, 74, 50, 255), width=2) for x in range(-300, W + 340, 150)])
    a = reflect(a, HORIZON + 30, HORIZON + 100, 0.16, 5)
    return a, {'outdoor': False, 'seed': 1210, 'windows': [(20, 50, 140, HORIZON - 10), (180, 50, 300, HORIZON - 10), (500, 50, 620, HORIZON - 10), (660, 50, 780, HORIZON - 10)]}


def skypillar():
    """Sky Pillar (Hoenn): o topo da torre de pedra antiga, acima das nuvens, com as ameias gastas e o céu aberto."""
    a = vgrad([(0, rgb('1a56b8')), (0.7, rgb('7ac0f0')), (1, rgb('d8f0ff'))], 0, HORIZON + 10)
    rnd = random.Random(1221)

    def clouds(d, y0, y1, n, al):
        for _ in range(n):
            x, y, r = rnd.uniform(-60, W + 60), rnd.uniform(y0, y1), rnd.uniform(40, 130)
            d.ellipse([x - r, y - r * 0.3, x + r, y + r * 0.34], fill=(206, 226, 246, al))
            d.ellipse([x - r * 0.9, y - r * 0.42, x + r * 0.7, y + r * 0.14], fill=(255, 255, 255, al))
    a = layer(a, lambda d: clouds(d, 40, HORIZON - 40, 8, 150), 10)
    a = layer(a, lambda d: clouds(d, HORIZON - 20, HORIZON + 30, 26, 240), 4)
    a = ground(a, HORIZON + 26, rgb('c8b890'), rgb('6e5e40'), 1222, 5, 0.12, spots=(rgb('8a9a5a'), 0.35))

    def stones(d):
        # As ameias quebradas na borda do topo e os dois pilares com as inscrições.
        for x in range(-10, W, 64):
            h = rnd.choice((18, 30, 44, 26))
            d.rectangle([x, HORIZON + 26 - h, x + 44, HORIZON + 30], fill=(170, 154, 116, 255))
            d.rectangle([x, HORIZON + 26 - h, x + 12, HORIZON + 30], fill=(204, 190, 150, 255))
            d.line([(x + 44, HORIZON + 26 - h), (x + 44, HORIZON + 30)], fill=(110, 96, 66, 255), width=2)
        for x in (110, 690):
            d.rectangle([x - 26, HORIZON - 150, x + 26, HORIZON + 40], fill=(176, 160, 122, 255))
            d.rectangle([x - 26, HORIZON - 150, x - 12, HORIZON + 40], fill=(210, 196, 158, 255))
            d.polygon([(x - 27, HORIZON - 151), (x - 8, HORIZON - 132), (x + 6, HORIZON - 146), (x + 27, HORIZON - 124), (x + 27, HORIZON - 151)], fill=(60, 130, 220, 255))
            for k in range(4):
                y = HORIZON - 100 + k * 30
                d.arc([x - 10, y, x + 14, y + 18], 30, 330, fill=(90, 150, 110, 255), width=3)
        # As lajes do chão.
        for y in (HORIZON + 50, HORIZON + 92, HORIZON + 160, HORIZON + 260):
            d.line([(0, y), (W, y)], fill=(104, 90, 60, 255), width=2)
        for x in range(-300, W + 340, 130):
            d.line([(W * 0.5 + (x - W * 0.5) * 0.25, HORIZON + 30), (x, H)], fill=(104, 90, 60, 255), width=2)
    a = layer(a, stones)
    # O anel verde no chão (onde o Rayquaza pousa).
    a = layer(a, lambda d: [d.ellipse([W * 0.5 - r, HORIZON + 130 - r * 0.24, W * 0.5 + r, HORIZON + 130 + r * 0.24], outline=(60, 170, 110, 220), width=4) for r in (150, 190)], 0.8)
    a = motes(a, 1223, 50, (0, 0, W, H), (255, 255, 255), 2, 1)
    return a, {'outdoor': True, 'seed': 1220}


def whirl():
    """Whirl Islands (Johto): a caverna do mar com a cachoeira no fundo e os redemoinhos girando na água escura."""
    a = vgrad([(0, rgb('081422')), (1, rgb('1c3a58'))], 0, HORIZON + 40)
    a = mountains(a, 1231, HORIZON + 14, 140, rgb('34506c'), rgb('14222e'), rgb('0e1a26'), 0.25, 0.8, 10, freq=1.5)
    rnd = random.Random(1232)
    a = layer(a, lambda d: [d.polygon([(x, -5), (x + w, -5), (x + w / 2, h)], fill=(40, 60, 82, 255)) for x, w, h in [(x, rnd.uniform(18, 40), rnd.uniform(30, 120)) for x in range(-10, W, 34)]], 0.6)
    # A cachoeira no fundo (a do Lugia) e a névoa dela.
    fall = mask(lambda d: d.rectangle([340, 20, 460, HORIZON + 20], fill=255), 2)
    a = put(a, vgrad([(0, rgb('9ad8f0')), (1, rgb('e6f8ff'))], 0, HORIZON + 20), fall * 0.9)
    a = layer(a, lambda d: [d.line([(x, 20), (x + rnd.uniform(-3, 3), HORIZON + 20)], fill=(255, 255, 255, 160), width=2) for x in range(346, 458, 9)], 0.6)
    a = glow(a, 400, HORIZON + 10, 130, (200, 240, 255), 0.6)
    a = ground(a, HORIZON + 14, rgb('2e7aa0'), rgb('0a2a48'), 1233, 9, 0.08)
    a = reflect(a, HORIZON + 14, HORIZON + 90, 0.4, 3)

    def swirl(d):
        for x, y, s in ((170, HORIZON + 70, 70), (610, HORIZON + 90, 90), (380, H - 90, 150), (720, H - 40, 90)):
            for k in range(6):
                r = s * (1 - k * 0.15)
                d.arc([x - r, y - r * 0.28, x + r, y + r * 0.28], 10 + k * 55, 250 + k * 55, fill=(226, 246, 255, 220 - k * 24), width=max(2, int(s / 24)))
            d.ellipse([x - s * 0.12, y - s * 0.035, x + s * 0.12, y + s * 0.035], fill=(6, 24, 44, 255))
        for _ in range(300):
            y = rnd.uniform(HORIZON + 24, H)
            k = (y - HORIZON) / (H - HORIZON)
            s = 6 + k * 60
            x = rnd.uniform(-40, W)
            d.arc([x, y - s * 0.12, x + s, y + s * 0.12], 200, 340, fill=(190, 230, 250, int(60 + 90 * k)), width=1)
    a = layer(a, swirl, 0.5)
    a = rocks(a, 1234, 8, HORIZON + 20, HORIZON + 60, (60, 80, 100), (104, 130, 154), (14, 24, 36), 14, 34)
    a = motes(a, 1235, 70, (0, HORIZON - 60, W, H), (220, 244, 255), 2, 1)
    return a, {'outdoor': False, 'seed': 1230}


def lakeside():
    """Lago calmo (Valor Lakefront e os lagos de Sinnoh): a água azul parada, a ilhota com a caverna no meio e os pinheiros."""
    a = vgrad([(0, rgb('3a8ad8')), (1, rgb('c8e8ff'))], 0, HORIZON)
    a = layer(a, lambda d: [d.ellipse([x - 110, y - 18, x + 110, y + 18], fill=(255, 255, 255, 180)) for x, y in ((160, 60), (470, 44), (700, 86))], 14)
    a = mountains(a, 1241, HORIZON - 4, 70, rgb('7a9cc0'), rgb('5c80a6'), rgb('bcd6ee'), 0.4, 0.5, 10, blur=2, snowcap=rgb('f0f6ff'))
    rnd = random.Random(1242)
    a = layer(a, lambda d: [pine(d, x, HORIZON + 4, rnd.uniform(40, 80), (26, 78, 60), (50, 116, 84)) for x in range(-10, W + 20, 28)], 0.6)
    a = ground(a, HORIZON + 4, rgb('6ab4e6'), rgb('1e5a9a'), 1243, 9, 0.06)
    # A ilhota com a entrada da caverna, no meio do lago.
    a = layer(a, lambda d: (d.ellipse([330, HORIZON + 22, 470, HORIZON + 46], fill=(96, 110, 100, 255)), d.polygon([(346, HORIZON + 34), (372, HORIZON - 6), (406, HORIZON - 22), (438, HORIZON), (456, HORIZON + 34)], fill=(128, 138, 126, 255)),
                           d.ellipse([388, HORIZON + 6, 418, HORIZON + 36], fill=(26, 30, 34, 255))))
    a = reflect(a, HORIZON + 46, HORIZON + 120, 0.5, 3)
    a = layer(a, lambda d: [d.arc([x, y - s * 0.1, x + s, y + s * 0.1], 200, 340, fill=(240, 250, 255, int(70 + 100 * k)), width=1) for x, y, s, k in [(rnd.uniform(-40, W), y, 6 + (y - HORIZON) / (H - HORIZON) * 60, (y - HORIZON) / (H - HORIZON)) for y in [rnd.uniform(HORIZON + 8, H) for _ in range(380)]]], 0.5)
    a = put(a, rgb('4a8a4a'), mask(lambda d: d.polygon([(0, H * 0.74), (W * 0.30, H * 0.80), (W * 0.52, H * 0.93), (W * 0.56, H), (0, H)], fill=255), 2))
    a = blades(a, 1244, 260, H * 0.76, H + 10, [rgb('4a8a40'), rgb('6aa850'), rgb('3a7038')], 0.2)
    a = motes(a, 1245, 60, (0, HORIZON, W, H), (255, 255, 255), 1.6, 0.5)
    return a, {'outdoor': True, 'seed': 1240}


def acuity():
    """Lake Acuity (Snowpoint): o lago gelado no meio da neve, os pinheiros brancos e a ilhota da caverna."""
    a = vgrad([(0, rgb('7088b0')), (1, rgb('dfe8f4'))], 0, HORIZON)
    a = mountains(a, 1251, HORIZON - 4, 80, rgb('b8c8dc'), rgb('8ea2be'), rgb('e6eef8'), 0.4, 0.5, 10, blur=2, snowcap=rgb('ffffff'))
    rnd = random.Random(1252)
    a = layer(a, lambda d: [pine(d, x, HORIZON + 4, rnd.uniform(40, 84), (40, 78, 80), (70, 116, 110), (240, 246, 255, 255)) for x in range(-10, W + 20, 28)], 0.6)
    a = ground(a, HORIZON + 4, rgb('b8dcf0'), rgb('5a90c0'), 1253, 9, 0.05)
    a = layer(a, lambda d: (d.ellipse([330, HORIZON + 22, 470, HORIZON + 46], fill=(214, 226, 240, 255)), d.polygon([(346, HORIZON + 34), (372, HORIZON - 6), (406, HORIZON - 22), (438, HORIZON), (456, HORIZON + 34)], fill=(190, 204, 222, 255)),
                           d.polygon([(372, HORIZON - 6), (406, HORIZON - 22), (438, HORIZON), (410, HORIZON - 8)], fill=(250, 252, 255, 255)), d.ellipse([388, HORIZON + 6, 418, HORIZON + 36], fill=(30, 40, 60, 255))))
    a = reflect(a, HORIZON + 46, HORIZON + 120, 0.5, 3)
    # As rachaduras do gelo e as placas boiando.
    a = layer(a, lambda d: [d.line([(x, y), (x + rnd.uniform(-110, 110), y + rnd.uniform(4, 30))], fill=(240, 250, 255, 170), width=2) for x, y in [(rnd.uniform(0, W), rnd.uniform(HORIZON + 50, H)) for _ in range(46)]], 0.6)
    a = put(a, rgb('f4f8ff'), mask(lambda d: d.polygon([(0, H * 0.72), (W * 0.32, H * 0.79), (W * 0.54, H * 0.93), (W * 0.58, H), (0, H)], fill=255), 2))
    cover = np.clip((noise(9, 1254, 5, 3.0) - 0.5) * 3, 0, 1) * (1 - np.clip((HORIZON + 40 - np.arange(H, dtype=np.float32)[:, None]) / 40, 0, 1))
    a = put(a, rgb('eef6ff'), cover * 0.45)
    a = motes(a, 1255, 160, (0, 0, W, H), (255, 255, 255), 2.2, 0.6)
    return a, {'outdoor': True, 'seed': 1250}


def hotel():
    """Lost Hotel (Kalos): o saguão abandonado, com o papel de parede rasgado, os grafites, o lustre caído e o balcão."""
    a = vgrad([(0, rgb('2e2434')), (1, rgb('5c4a58'))], 0, HORIZON + 30)
    rnd = random.Random(1261)

    def hall(d):
        # O papel de parede listrado, descascando.
        for x in range(0, W, 30):
            d.rectangle([x, 30, x + 14, HORIZON + 26], fill=(82, 62, 76, 255))
        for _ in range(9):
            x, y, w, h = rnd.uniform(0, W), rnd.uniform(30, HORIZON - 40), rnd.uniform(30, 70), rnd.uniform(30, 80)
            d.polygon([(x, y), (x + w, y + rnd.uniform(-8, 8)), (x + w * 0.8, y + h), (x + w * 0.2, y + h * 0.8)], fill=(40, 32, 40, 255))
        d.rectangle([0, 18, W, 32], fill=(96, 70, 46, 255))
        # As janelas com tábuas pregadas.
        for x0 in (70, 650):
            d.rectangle([x0, 60, x0 + 80, HORIZON - 30], fill=(26, 30, 60, 255))
            for k in range(3):
                d.polygon([(x0 - 6, 80 + k * 34), (x0 + 86, 70 + k * 38), (x0 + 86, 82 + k * 38), (x0 - 6, 92 + k * 34)], fill=(110, 80, 50, 255))
        # Os grafites (a marca da gangue) e o balcão da recepção.
        for x0, c in ((190, (240, 80, 170)), (520, (90, 220, 240)), (380, (250, 220, 80))):
            d.arc([x0, 70, x0 + 70, 130], 20, 320, fill=c + (255,), width=6)
            d.line([(x0 + 10, 140), (x0 + 60, 120), (x0 + 30, 160), (x0 + 76, 150)], fill=c + (255,), width=5)
        d.rectangle([250, HORIZON - 24, 550, HORIZON + 26], fill=(74, 50, 34, 255))
        d.rectangle([244, HORIZON - 30, 556, HORIZON - 22], fill=(120, 84, 54, 255))
        for x in range(262, 540, 46):
            d.rectangle([x, HORIZON - 14, x + 34, HORIZON + 18], outline=(54, 36, 24, 255), width=3)
        d.rectangle([386, HORIZON - 44, 414, HORIZON - 30], fill=(200, 170, 70, 255))
        # O lustre caído, torto.
        d.line([(400, 0), (430, 50)], fill=(150, 130, 80, 255), width=3)
        d.polygon([(390, 56), (476, 40), (466, 70), (410, 86)], fill=(190, 160, 90, 255))
        for k in range(4):
            d.ellipse([398 + k * 18, 70 - k * 4, 408 + k * 18, 84 - k * 4], fill=(240, 230, 190, 255))
    a = layer(a, hall)
    a = glow(a, 440, 66, 90, (255, 220, 150), 0.35)
    a = ground(a, HORIZON + 30, rgb('6a5464'), rgb('261c26'), 1262, 6, 0.14, spots=(rgb('18121a'), 0.5))
    a = tiles(a, (60, 46, 58, 255))
    # O tapete gasto e o entulho.
    a = put(a, rgb('7a2a4a'), mask(lambda d: d.polygon([(W * 0.42, HORIZON + 30), (W * 0.58, HORIZON + 30), (W * 0.78, H * 0.9), (W * 0.62, H), (W * 0.24, H)], fill=255)) * 0.6)
    a = rocks(a, 1263, 10, HORIZON + 60, H - 10, (96, 84, 92), (140, 126, 134), (36, 28, 36), 8, 20)
    a = motes(a, 1264, 40, (0, 0, W, H), (210, 200, 220), 1.6, 0.8)
    return a, {'outdoor': False, 'seed': 1260, 'windows': [(70, 60, 150, HORIZON - 30), (650, 60, 730, HORIZON - 30)]}


def wildarea():
    """Wild Area (Galar): a planície enorme, o lago ao longe, a árvore grande, as pedras em pé e a toca com o facho de luz."""
    a = vgrad([(0, rgb('3f8fe0')), (1, rgb('cfeaff'))], 0, HORIZON)
    a = layer(a, lambda d: [d.ellipse([x - 130, y - 22, x + 130, y + 22], fill=(255, 255, 255, 190)) for x, y in ((130, 70), (430, 40), (690, 96))], 14)
    a = mountains(a, 1271, HORIZON - 2, 60, rgb('8aa6c4'), rgb('6c8cae'), rgb('c4dcf0'), 0.45, 0.5, 10, blur=2.5)
    # Hammerlocke ao longe (a muralha e a torre).
    a = layer(a, lambda d: (d.rectangle([560, HORIZON - 50, 720, HORIZON - 6], fill=(150, 150, 170, 255)), d.rectangle([626, HORIZON - 96, 654, HORIZON - 50], fill=(150, 150, 170, 255)),
                           d.polygon([(620, HORIZON - 96), (640, HORIZON - 120), (660, HORIZON - 96)], fill=(170, 80, 80, 255)), [d.rectangle([x, HORIZON - 58, x + 12, HORIZON - 50], fill=(150, 150, 170, 255)) for x in range(560, 720, 22)]), 1.5)
    a = ground(a, HORIZON, rgb('8fd06a'), rgb('3f8a3a'), 1272, 5, 0.12, spots=(rgb('b0c860'), 0.4))
    # O lago ao longe e o caminho de terra.
    a = put(a, rgb('5aa8e0'), mask(lambda d: d.ellipse([40, HORIZON + 6, 380, HORIZON + 40], fill=255), 2))
    a = put(a, rgb('c8b07a'), mask(lambda d: d.polygon([(470, HORIZON + 6), (500, HORIZON + 6), (430, HORIZON + 110), (640, H), (430, H), (330, HORIZON + 120)], fill=255), 3) * 0.7)
    rnd = random.Random(1273)

    def things(d):
        # A árvore grande (a das frutas).
        d.rectangle([118, HORIZON - 30, 138, HORIZON + 26], fill=(110, 74, 44, 255))
        for cx, cy, r in ((128, HORIZON - 70, 56), (92, HORIZON - 44, 36), (166, HORIZON - 46, 38)):
            d.ellipse([cx - r, cy - r * 0.8, cx + r, cy + r * 0.8], fill=(40, 120, 60, 255))
            d.ellipse([cx - r * 0.8, cy - r * 0.8, cx + r * 0.4, cy + r * 0.2], fill=(70, 160, 80, 255))
        for _ in range(8):
            x, y = rnd.uniform(80, 176), rnd.uniform(HORIZON - 100, HORIZON - 30)
            d.ellipse([x - 4, y - 4, x + 4, y + 4], fill=(240, 90, 110, 255))
        # As pedras em pé.
        for x, h in ((300, 46), (330, 30), (700, 54), (742, 34)):
            d.polygon([(x - 10, HORIZON + 30), (x - 8, HORIZON + 30 - h), (x + 4, HORIZON + 24 - h), (x + 12, HORIZON + 30)], fill=(150, 150, 156, 255))
            d.polygon([(x - 10, HORIZON + 30), (x - 8, HORIZON + 30 - h), (x - 2, HORIZON + 28 - h), (x - 2, HORIZON + 30)], fill=(196, 196, 202, 255))
        # A toca de Pokémon (o anel de pedras).
        d.ellipse([520, HORIZON + 34, 620, HORIZON + 62], fill=(120, 110, 110, 255))
        d.ellipse([534, HORIZON + 38, 606, HORIZON + 56], fill=(60, 20, 40, 255))
    a = layer(a, things)
    # O facho de luz vermelha saindo da toca.
    a = layer(a, lambda d: d.polygon([(552, HORIZON + 46), (588, HORIZON + 46), (598, 0), (542, 0)], fill=(255, 60, 110, 120)), 5)
    a = glow(a, 570, HORIZON + 46, 60, (255, 80, 130), 0.7)
    a = blades(a, 1274, 520, HORIZON + 40, H + 10, [rgb('4f9a44'), rgb('79c35a'), rgb('2f7a36')], 0.25)
    a = motes(a, 1275, 50, (0, HORIZON, W, H), (255, 250, 200), 2, 0.8)
    return a, {'outdoor': True, 'seed': 1270}


SCENES = {
    'grass': grass, 'forest': forest, 'water': water, 'beach': beach, 'underwater': underwater, 'swamp': swamp, 'sewer': sewer,
    'cave': cave, 'icecave': icecave, 'mountain': mountain, 'desert': desert, 'volcano': volcano, 'snow': snow, 'city': city,
    'sky': sky, 'tower': tower, 'gym': gym, 'league': league, 'center': center,
    'ruins': ruins, 'flowers': flowers, 'plant': plant, 'crystal': crystal, 'dunes': dunes, 'bamboo': bamboo, 'temple': temple,
    'lavacave': lavacave, 'poisoncave': poisoncave, 'seacave': seacave, 'waterfall': waterfall,
    'store': store, 'casino': casino, 'school': school, 'stage': stage, 'subway': subway, 'ship': ship, 'bridge': bridge, 'park': park, 'museum': museum,
    'silph': silph, 'radio': radio, 'seafoam': seafoam, 'lake': lake,
    'library': library, 'mansion': mansion, 'space': space, 'lab': lab, 'observatory': observatory, 'coldstorage': coldstorage,
    'dojo': dojo, 'dragonsden': dragonsden, 'spearpillar': spearpillar, 'origin': origin, 'burnedtower': burnedtower,
    'lighthouse': lighthouse, 'skypillar': skypillar, 'whirl': whirl, 'lakeside': lakeside, 'acuity': acuity, 'hotel': hotel, 'wildarea': wildarea,
}


# ------------------------------------------------------------ ginásios (um por tipo: o do líder), salas dos Campeões e bases dos vilões

# Tipo do ginásio: [parede em cima, parede embaixo, chão longe, chão perto, cor de destaque].
GYM_TYPES = {
    'normal': ['3a3226', '8a7a5c', 'd8c8a0', 'a08a62', 'f0e0b8'], 'fire': ['2a0806', '7a2010', 'a0402a', '5a1c10', 'ff9a3a'],
    'water': ['06223e', '1a5a8e', '5ab0e0', '2a6aa8', '9ae0ff'], 'grass': ['0e2a12', '2e6a2a', '8ac862', '4a8a3a', 'b8f08a'],
    'electric': ['141428', '3a3a5a', 'c8c070', '8a8240', 'ffe84a'], 'ice': ['1a3050', '6a9ac8', 'd8eeff', '8ab8e0', 'ffffff'],
    'fighting': ['2a1a10', '6a4226', 'c89a5a', '8a6232', 'e04a3a'], 'poison': ['1e0e2a', '5a2a6a', '9a6aaa', '5a3a6a', 'd07aff'],
    'ground': ['2a1a0a', '7a5a32', 'd8b070', 'a07a42', 'f0d090'], 'flying': ['3a6aa8', 'a8d0f0', 'e8f4ff', 'a8c8e8', 'ffffff'],
    'psychic': ['2a0e2a', '7a3a7a', 'e0a0d0', 'a06a9a', 'ff8ae0'], 'bug': ['1a2208', '4a5a1a', 'a8b05a', '6a7a2a', 'e0f04a'],
    'rock': ['1e1a16', '5a5046', 'a89a86', '6a6052', 'd0c4b0'], 'ghost': ['0a0614', '2a1a3e', '4a3a6a', '1e1630', 'a07aff'],
    'dragon': ['0e0a2a', '2e2a6a', '6a5aa0', '342a6a', 'ff6a4a'], 'dark': ['060608', '1e1e26', '3a3a46', '16161e', 'c04a6a'],
    'steel': ['1a2026', '5a6670', 'b8c4cc', '7a868e', 'e8f0f4'], 'fairy': ['3a1a2e', 'c07aa0', 'ffd8ea', 'e8a8c8', 'ffffff'],
}


def gym_decor(t, accent, rnd):
    """O que tem na parede e nos cantos de cada ginásio (pelo tipo)."""
    A = tuple(int(v) for v in accent)
    Y1 = HORIZON + 30

    def fn(d):
        if t == 'fire':
            for x in range(40, W, 120):
                d.rectangle([x - 10, Y1 - 60, x + 10, Y1], fill=(60, 40, 30, 255))
                d.polygon([(x - 18, Y1 - 60), (x, Y1 - 110), (x + 18, Y1 - 60)], fill=(255, 120, 40, 255))
                d.polygon([(x - 8, Y1 - 60), (x, Y1 - 88), (x + 8, Y1 - 60)], fill=(255, 220, 90, 255))
        elif t == 'water':
            for k in range(6):
                y = 60 + k * 26
                d.arc([-40, y - 20, W + 40, y + 20], 0, 180, fill=A + (120,), width=3)
        elif t == 'grass':
            for _ in range(40):
                x, y, r = rnd.uniform(0, W), rnd.uniform(20, Y1 - 10), rnd.uniform(10, 26)
                d.ellipse([x - r, y - r * 0.6, x + r, y + r * 0.6], fill=(60 + rnd.randrange(60), 140 + rnd.randrange(60), 60, 255))
            for x in range(0, W, 60):
                d.line([(x, 0), (x + rnd.uniform(-20, 20), Y1)], fill=(40, 100, 40, 255), width=3)
        elif t == 'electric':
            for x in range(60, W, 140):
                d.polygon([(x, 30), (x + 30, 30), (x + 10, 90), (x + 34, 90), (x - 10, 170), (x + 4, 110), (x - 18, 110)], fill=A + (255,))
            for y in (40, Y1 - 30):
                d.line([(0, y), (W, y)], fill=(80, 220, 255, 200), width=3)
        elif t == 'ice':
            for x in range(0, W, 26):
                h = rnd.uniform(30, 90)
                d.polygon([(x, 0), (x + 13, h), (x + 26, 0)], fill=(220, 240, 255, 230))
            for x in (90, 320, 520, 720):
                d.polygon([(x - 26, Y1), (x, Y1 - 120), (x + 26, Y1)], fill=(190, 230, 255, 220))
        elif t == 'fighting':
            for x in range(0, W, 80):
                d.line([(x, 0), (x, Y1)], fill=(60, 36, 20, 255), width=4)
            for x in (150, 650):
                d.rectangle([x - 30, 20, x + 30, 150], fill=A + (255,))
                d.ellipse([x - 16, 60, x + 16, 92], fill=(250, 240, 220, 255))
        elif t == 'poison':
            for _ in range(60):
                x, y, r = rnd.uniform(0, W), rnd.uniform(10, Y1), rnd.uniform(4, 14)
                d.ellipse([x - r, y - r, x + r, y + r], outline=A + (200,), width=2)
        elif t == 'ground':
            for k, y in enumerate(range(30, Y1, 22)):
                d.rectangle([0, y, W, y + 10], fill=(120 + k * 8, 90 + k * 6, 50 + k * 4, 160))
        elif t == 'flying':
            for x in range(40, W, 190):
                d.rounded_rectangle([x, 30, x + 140, Y1 - 30], radius=60, fill=(140, 200, 250, 255), outline=(255, 255, 255, 255), width=6)
                d.ellipse([x + 20, 80, x + 100, 120], fill=(255, 255, 255, 230))
        elif t == 'psychic':
            for x in (200, 600):
                for r in range(10, 90, 14):
                    d.ellipse([x - r, 110 - r, x + r, 110 + r], outline=A + (150,), width=3)
            for _ in range(40):
                x, y = rnd.uniform(0, W), rnd.uniform(10, Y1)
                d.polygon([(x, y - 6), (x + 2, y - 2), (x + 6, y), (x + 2, y + 2), (x, y + 6), (x - 2, y + 2), (x - 6, y), (x - 2, y - 2)], fill=(255, 230, 255, 220))
        elif t == 'bug':
            for x in range(0, W + 40, 40):
                for y in range(0, Y1, 46):
                    o = 20 if (y // 46) % 2 else 0
                    cx, cy = x + o, y
                    d.polygon([(cx - 18, cy), (cx - 9, cy - 16), (cx + 9, cy - 16), (cx + 18, cy), (cx + 9, cy + 16), (cx - 9, cy + 16)], outline=A + (140,), width=2)
        elif t == 'rock':
            for _ in range(14):
                x, y, r = rnd.uniform(0, W), Y1 - rnd.uniform(0, 30), rnd.uniform(20, 46)
                d.polygon([(x - r, y), (x - r * 0.6, y - r), (x + r * 0.3, y - r * 1.2), (x + r, y - r * 0.4), (x + r * 0.9, y)], fill=(110 + rnd.randrange(40), 100, 90, 255))
        elif t == 'ghost':
            for x in range(50, W, 110):
                d.rectangle([x - 5, Y1 - 40, x + 5, Y1], fill=(220, 210, 190, 255))
                d.ellipse([x - 6, Y1 - 56, x + 6, Y1 - 38], fill=(160, 220, 255, 255))
            for _ in range(20):
                x, y, r = rnd.uniform(0, W), rnd.uniform(20, Y1 - 60), rnd.uniform(6, 12)
                d.ellipse([x - r, y - r, x + r, y + r], fill=A + (120,))
        elif t == 'dragon':
            for x in (120, 680):
                d.polygon([(x - 34, 20), (x + 34, 20), (x + 34, 170), (x, 150), (x - 34, 170)], fill=A + (255,))
                d.polygon([(x - 14, 60), (x, 44), (x + 14, 60), (x, 110)], fill=(250, 220, 120, 255))
        elif t == 'dark':
            d.ellipse([W * 0.5 - 50, 30, W * 0.5 + 50, 130], fill=(240, 236, 220, 255))
            d.ellipse([W * 0.5 - 24, 24, W * 0.5 + 70, 120], fill=(14, 14, 20, 255))
        elif t == 'steel':
            for x in range(0, W, 100):
                for y in range(0, Y1, 60):
                    d.rectangle([x + 4, y + 4, x + 96, y + 56], outline=(140, 150, 160, 255), width=2)
                    for cx, cy in ((x + 10, y + 10), (x + 90, y + 10), (x + 10, y + 50), (x + 90, y + 50)):
                        d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=(200, 210, 220, 255))
        elif t == 'fairy':
            for _ in range(30):
                x, y, r = rnd.uniform(0, W), rnd.uniform(10, Y1 - 10), rnd.uniform(6, 14)
                d.ellipse([x - r, y - r * 0.8, x, y + r * 0.2], fill=(255, 150, 200, 220))
                d.ellipse([x, y - r * 0.8, x + r, y + r * 0.2], fill=(255, 150, 200, 220))
                d.polygon([(x - r, y - r * 0.1), (x + r, y - r * 0.1), (x, y + r)], fill=(255, 150, 200, 220))
        else:
            for x in range(60, W, 170):
                d.rectangle([x - 14, 0, x + 14, Y1], fill=A + (180,))
    return fn


def gym_scene(t):
    def make():
        wall_top, wall_bottom, far, near, accent = [rgb(c) for c in GYM_TYPES[t]]
        rnd = random.Random(sum(map(ord, t)))
        a = vgrad([(0, wall_top), (1, wall_bottom)], 0, HORIZON + 30)
        a = layer(a, gym_decor(t, accent, rnd))
        for x in (160, 400, 640):
            a = glow(a, x, 20, 60, (255, 250, 230), 0.5)
        a = ground(a, HORIZON + 30, far, near, 300 + len(t), 6, 0.08)
        # A arena: a faixa na entrada e o círculo do meio na cor do tipo.
        A = tuple(int(v) for v in accent)
        a = layer(a, lambda d: (d.rectangle([0, HORIZON + 30, W, HORIZON + 37], fill=A + (255,)),
                                d.ellipse([W * 0.34, H * 0.53, W * 0.66, H * 0.66], outline=A + (220,), width=5),
                                d.line([(W * 0.5, HORIZON + 37), (W * 0.5, H)], fill=A + (150,), width=3)), 0.7)
        a = reflect(a, HORIZON + 30, HORIZON + 90, 0.14, 6)
        return a, {'outdoor': False, 'seed': 300 + len(t)}
    return make


# Sala do Campeão de cada região: [parede em cima, parede embaixo, chão longe, chão perto, tapete, detalhe].
CHAMPIONS = {
    'kanto': ['1a0606', '5a1a1a', '6a3a2a', '2a140e', 'b0202a', 'f0c060'], 'johto': ['060e2a', '1a2a6a', '3a4a7a', '141a3a', '2a4ab0', 'f0d070'],
    'hoenn': ['062420', '1a5a4a', '3a7a6a', '143a30', '1a8a7a', 'a0f0e0'], 'sinnoh': ['14141e', '4a4a5a', '8a8a9a', '3a3a46', '5a4ab0', 'e0e0f0'],
    'unova': ['0a0a0a', '3a3a3a', 'd8d8d8', '6a6a6a', '1a1a1a', 'ffffff'], 'kalos': ['0a1430', '2a3a7a', '9aa8d0', '3a4a7a', '2a5ab0', 'e8d8a0'],
    'alola': ['2a5a8a', 'a8d8e8', 'e8d8a8', 'a89a6a', '2a9a6a', 'ffd060'], 'galar': ['100a2a', '3a2a7a', '4a8a3a', '1e3a1a', 'b02a4a', 'f0f0ff'],
    'paldea': ['2a0a1a', '7a2a3a', 'e8b070', 'a06a3a', 'e0601a', 'a060e0'],
}


def champion_scene(region):
    def make():
        top, bottom, far, near, carpet, gold = [rgb(c) for c in CHAMPIONS[region]]
        G = tuple(int(v) for v in gold)
        a = vgrad([(0, top), (1, bottom)], 0, HORIZON + 30)
        a = glow(a, W * 0.5, 40, 200, tuple(int(v) for v in gold), 0.35)
        for x in (40, 170, 590, 720):
            a = layer(a, lambda d, x=x: (d.rectangle([x, 20, x + 36, HORIZON + 34], fill=G + (255,)), d.rectangle([x - 8, 10, x + 44, 26], fill=G + (255,)),
                                         d.rectangle([x + 6, 26, x + 12, HORIZON + 30], fill=(255, 255, 255, 120))))
        a = layer(a, lambda d: (d.polygon([(W * 0.5 - 70, 40), (W * 0.5 + 70, 40), (W * 0.5 + 54, 150), (W * 0.5, 170), (W * 0.5 - 54, 150)], fill=tuple(int(v) for v in carpet) + (255,)),
                                d.ellipse([W * 0.5 - 24, 70, W * 0.5 + 24, 118], outline=G + (255,), width=5)))
        a = ground(a, HORIZON + 30, far, near, 400 + len(region), 6, 0.06)
        a = reflect(a, HORIZON + 30, HORIZON + 120, 0.22, 4)
        a = put(a, vgrad([(0, carpet * 1.1), (1, carpet * 0.7)], HORIZON + 30, H), mask(lambda d: d.polygon([(W * 0.44, HORIZON + 30), (W * 0.56, HORIZON + 30), (W * 0.84, H), (W * 0.16, H)], fill=255), 1))
        a = layer(a, lambda d: [d.line([(W * 0.44, HORIZON + 30), (W * 0.16, H)], fill=G + (255,), width=3), d.line([(W * 0.56, HORIZON + 30), (W * 0.84, H)], fill=G + (255,), width=3)])
        a = motes(a, 410 + len(region), 40, (0, 0, W, H * 0.6), tuple(int(v) for v in gold), 2, 1.5)
        return a, {'outdoor': False, 'seed': 400 + len(region)}
    return make


# Base de cada equipe vilã: [parede em cima, parede embaixo, chão longe, chão perto, cor da equipe, segunda cor].
BASES = {
    'rocket': ['0e0e12', '3a3a42', '5a5a62', '22222a', 'd02020', 'f0f0f0'], 'aqua': ['04142a', '0e3a6a', '2a5a8a', '0e2a4a', '2a8ae0', 'ffffff'],
    'magma': ['1e0604', '5a1a0e', '6a3a2a', '2a120a', 'e04a1a', '2a2a2a'], 'galactic': ['0a1018', '2a3a4a', '8a9aa8', '3a4652', '4ad0e0', 'e0e8f0'],
    'plasma': ['0e1220', '3a4260', '6a7290', '2a3048', '2a5ad0', 'e0e0f0'], 'flare': ['1a0606', '4a1010', '3a2a2a', '160a0a', 'ff4020', 'f0b030'],
    'skull': ['14101a', '3a2e46', '5a5262', '22202a', 'a0a0a8', 'e04ab0'], 'aether': ['b8c8d8', 'f0f4f8', 'f8f8f8', 'c8d0d8', 'e0b040', 'ffffff'],
    'star': ['1a1030', '4a2a6a', 'b07a4a', '6a4a2a', 'ff5ac0', 'ffd040'],
    # Spikemuth (Equipe Yell): a rua coberta à noite, preto e rosa punk.
    'yell': ['0c0a10', '2a1a2a', '3a3238', '18141a', 'ff3aa0', '202020'],
    # Rose Tower (Macro Cosmos): o escritório de vidro, azul-marinho, branco e dourado.
    'macro': ['0a1a3a', '2a4a7a', 'c8d0dc', '6a7890', 'f0f4fa', 'd8b040'],
}


def base_scene(team):
    def make():
        top, bottom, far, near, color, second = [rgb(c) for c in BASES[team]]
        C, S = tuple(int(v) for v in color), tuple(int(v) for v in second)
        rnd = random.Random(500 + len(team))
        a = vgrad([(0, top), (1, bottom)], 0, HORIZON + 30)
        # Painéis na parede, luzes e as faixas da equipe (com o símbolo: um losango com um círculo).
        a = layer(a, lambda d: [d.rectangle([x + 3, y + 3, x + 77, y + 47], outline=tuple(int(v * 1.4) for v in top) + (255,), width=2) for x in range(0, W, 80) for y in range(0, HORIZON + 10, 50)])
        for x in (200, 600):
            a = layer(a, lambda d, x=x: (d.rectangle([x - 46, 18, x + 46, 160], fill=C + (255,)), d.polygon([(x, 50), (x + 30, 88), (x, 126), (x - 30, 88)], fill=S + (255,)),
                                         d.ellipse([x - 12, 76, x + 12, 100], fill=C + (255,))))
        for x in range(40, W, 120):
            a = glow(a, x, HORIZON + 10, 18, C, 0.6)
        a = ground(a, HORIZON + 30, far, near, 500 + len(team), 6, 0.08)
        # O chão em placas e uma faixa da equipe.
        a = layer(a, lambda d: [d.line([(W * 0.5 + (x - W * 0.5) * 0.2, HORIZON + 30), (x, H)], fill=tuple(int(v * 0.8) for v in near) + (255,), width=2) for x in range(-300, W + 340, 110)]
                  + [d.line([(0, y), (W, y)], fill=tuple(int(v * 0.8) for v in near) + (255,), width=2) for y in (HORIZON + 46, HORIZON + 80, HORIZON + 140, HORIZON + 230)]
                  + [d.rectangle([0, HORIZON + 30, W, HORIZON + 36], fill=C + (255,))])
        a = reflect(a, HORIZON + 30, HORIZON + 90, 0.16, 5)
        if team in ('aqua', 'magma'):
            a = motes(a, 520, 40, (0, 0, W, HORIZON), (120, 200, 255) if team == 'aqua' else (255, 140, 60), 2.5, 1.5)
        return a, {'outdoor': False, 'seed': 500 + len(team)}
    return make


for _t in GYM_TYPES:
    SCENES[f'gym-{_t}'] = gym_scene(_t)
for _r in CHAMPIONS:
    SCENES[f'champion-{_r}'] = champion_scene(_r)
for _b in BASES:
    SCENES[f'base-{_b}'] = base_scene(_b)


def foe_feet(top):
    """Onde ficam os pés do adversário (fração da altura): um pouco para dentro do chão do lugar, nunca no horizonte
    (a base não pode parecer voando). Igual a GROUND_FEET no site e no app."""
    return round((top + (H - top) * 0.2) / H, 3)


def render(name, w='', bases=True):
    SKY.clear()
    FLOOR.clear()
    a, info = SCENES[name]()
    info = {**info, 'name': name}
    if w:
        a = weather(a, w, info)
    if bases:
        for spec in (FOE, MINE):
            a = platform(a, spec)
    if not info.get('outdoor', True):
        return finish(a, info.get('seed', 1))
    if w == 'rain':
        a = a * 0.92
    elif w == 'sun':
        a = a * np.array([1.04, 1.0, 0.94], np.float32)
    elif w == 'sand':
        a = mix(a, rgb('d2a468'), 0.12)
    return finish(a, info.get('seed', 1))


def pixelate(im, w=''):
    """Reduz para a tela do DS com poucas cores (sem pontilhado) e desenha as bases já em pixel: vira pixel art."""
    small = im.resize(PIXEL, Image.BOX)
    small = small.quantize(colors=COLORS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert('RGB')
    a = np.asarray(small, np.float32)
    big = np.zeros((H, W, 3), np.float32)
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def base_sprite(scene_im, spec, feet=None):
    """A base sozinha (fundo transparente), em pixel, com a cor do chão do lugar: o site e o app a
    desenham embaixo de cada Pokémon, centralizada nele e do tamanho dele."""
    a = np.asarray(scene_im, np.float32)
    h, w = a.shape[:2]
    cx, cy, rx, ry = spec
    if feet is not None:
        cy = feet
    X, Y, RX, RY = cx * w, cy * h, rx * w, ry * h
    ys = slice(int(max(0, Y - RY * 1.3)), int(min(h, Y + RY * 1.3)))
    xs = slice(int(max(0, X - RX * 1.1)), int(min(w, X + RX * 1.1)))
    ground_c = a[ys, xs].reshape(-1, 3).mean(axis=0)
    RX, RY = round(RX), round(RY)
    thick = max(2, round(RY * 0.16))
    bw, bh = RX * 2 + 4, RY * 2 + thick + 4
    canvas = np.zeros((bh, bw, 4), np.float32)
    # Desenha numa cópia (com transparência) usando o mesmo put_small, centrada.
    rgb_ = np.zeros((bh, bw, 3), np.float32)
    alpha = np.zeros((bh, bw), np.float32)
    spec2 = ((RX + 2) / bw, (RY + 2) / bh, RX / bw, RY / bh)
    black = put_small(np.zeros((bh, bw, 3), np.float32), spec2, 1, ground_c)
    white = put_small(np.full((bh, bw, 3), 255, np.float32), spec2, 1, ground_c)
    # Transparência pela diferença entre o fundo preto e o branco.
    alpha = 1 - (white - black).mean(axis=2) / 255
    alpha = np.clip(alpha, 0, 1)
    rgb_ = np.where(alpha[..., None] > 0.01, black / np.maximum(alpha[..., None], 0.01), 0)
    canvas[..., :3] = np.clip(rgb_, 0, 255)
    canvas[..., 3] = np.round(alpha * 255)
    return Image.fromarray(canvas.astype(np.uint8), 'RGBA')


def put_small(a, spec, tone, ground_c=None):
    """Uma base em pixel: sombra no chão, espessura (a borda de baixo mais escura), um pouco da cor do chão em volta e os anéis."""
    h, w = a.shape[:2]
    cx, cy, rx, ry = spec
    X, Y, RX, RY = cx * w, cy * h, rx * w, ry * h
    # A cor do chão logo em volta (para a base combinar com o lugar).
    ys = slice(int(max(0, Y - RY * 1.3)), int(min(h, Y + RY * 1.3)))
    xs = slice(int(max(0, X - RX * 1.1)), int(min(w, X + RX * 1.1)))
    if ground_c is None:
        ground_c = a[ys, xs].reshape(-1, 3).mean(axis=0)
    thick = max(2, round(RY * 0.16))
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # Sombra no chão (um pouco maior e mais embaixo).
    shadow = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse([X - RX * 1.04, Y - RY * 0.7 + thick, X + RX * 1.04, Y + RY * 1.08 + thick], fill=(0, 0, 0, 120))
    shadow = shadow.filter(ImageFilter.GaussianBlur(2))
    # Bem misturada com a cor do chão: a base é um pedaço do chão do lugar (como no Black & White), não um disco solto.
    blend_k = 0.5
    def col(c):
        c = mix(np.array(c, np.float32), ground_c, blend_k)
        return tuple(int(v) for v in np.clip(c * tone, 0, 255))
    edge, mid, center, outline, lip = (34, 92, 156), (58, 136, 202), (140, 204, 248), (22, 62, 116), (16, 44, 86)
    # Espessura: a "lateral" da base, embaixo.
    d.ellipse([X - RX, Y - RY + thick, X + RX, Y + RY + thick], fill=col(lip) + (255,))
    d.ellipse([X - RX, Y - RY, X + RX, Y + RY], fill=col(outline) + (255,))
    rings = 14
    for k in range(rings):
        t = k / (rings - 1)
        f = 1 - t * 0.97
        c = mix(np.array(edge, np.float32), np.array(mid, np.float32), t / 0.6) if t < 0.6 else mix(np.array(mid, np.float32), np.array(center, np.float32), (t - 0.6) / 0.4)
        oy = -RY * 0.05 * t
        d.ellipse([X - (RX - 1) * f, Y + oy - (RY - 1) * f, X + (RX - 1) * f, Y + oy + (RY - 1) * f], fill=col(c) + (255,))
    # Brilho na borda de trás (a luz vem de cima).
    d.arc([X - RX + 1, Y - RY + 1, X + RX - 1, Y + RY - 1], 195, 345, fill=col((170, 220, 255)) + (110,), width=1)
    out = a
    for layer_im in (shadow, im):
        arr = np.asarray(layer_im, np.float32)
        m = arr[..., 3:] / 255
        out = out * (1 - m) + arr[..., :3] * m
    return out


def main():
    names = sys.argv[1:] or list(SCENES)
    weathers = [''] + (WEATHERS if os.environ.get('WEATHERS', '1') != '0' else [])
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(OUT_WEATHER, exist_ok=True)
    feet = {}
    for name in names:
        for w in weathers:
            im = pixelate(render(name, w, bases=False), w)
            if not w:
                feet[name] = foe_feet(FLOOR[-1]) if FLOOR else 0.45
            im.save(os.path.join(OUT_WEATHER, f'{name}-{w}.webp') if w else os.path.join(OUT, f'{name}.webp'), 'WEBP', lossless=True, method=6)
            if not w:
                # As bases: a de longe (do adversário) e a de perto (a sua), cada uma com a sua perspectiva.
                for side, spec in (('foe', FOE), ('mine', MINE)):
                    base_sprite(im, spec, feet[name] if side == 'foe' else None).save(os.path.join(OUT, f'{name}-base-{side}.webp'), 'WEBP', lossless=True, method=6)
        print(name, feet[name], flush=True)
    sheet = os.environ.get('SHEET')
    if sheet:
        cols, tw, th = 4, PIXEL[0], PIXEL[1]
        rows = [(n, w) for n in names for w in weathers] if len(names) <= 3 else [(n, '') for n in names]
        out = Image.new('RGB', (tw * cols, th * math.ceil(len(rows) / cols)), 'black')
        for i, (n, w) in enumerate(rows):
            im = Image.open(os.path.join(OUT_WEATHER, f'{n}-{w}.webp') if w else os.path.join(OUT, f'{n}.webp')).convert('RGB').resize((tw, th), Image.NEAREST)
            ImageDraw.Draw(im).text((6, 4), f'{n} {w}', fill='white')
            out.paste(im, ((i % cols) * tw, (i // cols) * th))
        out.save(sheet)


if __name__ == '__main__':
    main()
