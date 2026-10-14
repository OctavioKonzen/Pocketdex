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


def weather(a, w, scene):
    out = scene.get('outdoor', True)
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


SCENES = {
    'grass': grass, 'forest': forest, 'water': water, 'beach': beach, 'underwater': underwater, 'swamp': swamp, 'sewer': sewer,
    'cave': cave, 'icecave': icecave, 'mountain': mountain, 'desert': desert, 'volcano': volcano, 'snow': snow, 'city': city,
    'sky': sky, 'tower': tower, 'gym': gym, 'league': league, 'center': center,
    'ruins': ruins, 'flowers': flowers, 'plant': plant, 'crystal': crystal, 'dunes': dunes, 'bamboo': bamboo, 'temple': temple,
    'lavacave': lavacave, 'poisoncave': poisoncave, 'seacave': seacave,
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
    if w:
        a = weather(a, w, info)
    if bases:
        for spec in (FOE, MINE):
            a = platform(a, spec)
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
