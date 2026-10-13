"""Cenários da batalha desenhados por código, no estilo das imagens de
referência do usuário: 4:3, horizonte por volta de 1/3 da altura, profundidade
(o que está longe mais claro e desfocado, o que está perto mais escuro e
detalhado) e as duas bases azuis com anéis pixelados nos mesmos lugares (a do
adversário lá atrás à direita, a sua grande na frente à esquerda).

Cada lugar sai em 5 versões: sem clima e com sol, chuva, areia e neve
(granizo usa a de neve), porque golpes como Sunny Day e Rain Dance mudam o
cenário: assets/database/sprites/battle/<lugar>.webp e <lugar>-<clima>.webp.

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
FOE = (0.761, 0.393, 0.241, 0.066)
MINE = (0.462, 0.80, 0.525, 0.20)
HORIZON = int(H * 0.36)
WEATHERS = ['sun', 'rain', 'sand', 'snow']


# ------------------------------------------------------------ ferramentas

def rgb(h):
    h = h.lstrip('#')
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32)


def mix(a, b, t):
    return a + (b - a) * t


# O céu de cada lugar (o primeiro degradê que ele pinta): os climas trocam só ele.
SKY = []


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


SCENES = {
    'grass': grass, 'forest': forest, 'water': water, 'beach': beach, 'underwater': underwater, 'swamp': swamp, 'sewer': sewer,
    'cave': cave, 'icecave': icecave, 'mountain': mountain, 'desert': desert, 'volcano': volcano, 'snow': snow, 'city': city,
    'sky': sky, 'tower': tower, 'gym': gym, 'league': league, 'center': center,
}


def render(name, w=''):
    SKY.clear()
    a, info = SCENES[name]()
    if w:
        a = weather(a, w, info)
    for spec in (FOE, MINE):
        a = platform(a, spec)
    if w == 'rain':
        a = a * 0.92
    elif w == 'sun':
        a = a * np.array([1.04, 1.0, 0.94], np.float32)
    elif w == 'sand':
        a = mix(a, rgb('d2a468'), 0.12)
    return finish(a, info.get('seed', 1))


def main():
    names = sys.argv[1:] or list(SCENES)
    weathers = [''] + (WEATHERS if os.environ.get('WEATHERS', '1') != '0' else [])
    os.makedirs(OUT, exist_ok=True)
    for name in names:
        for w in weathers:
            render(name, w).save(os.path.join(OUT, f"{name}{'-' + w if w else ''}.webp"), 'WEBP', quality=78, method=6)
        print(name, flush=True)
    sheet = os.environ.get('SHEET')
    if sheet:
        cols, tw, th = 4, W // 3, H // 3
        rows = [(n, w) for n in names for w in weathers] if len(names) <= 3 else [(n, '') for n in names]
        out = Image.new('RGB', (tw * cols, th * math.ceil(len(rows) / cols)), 'black')
        for i, (n, w) in enumerate(rows):
            im = Image.open(os.path.join(OUT, f"{n}{'-' + w if w else ''}.webp")).resize((tw, th))
            ImageDraw.Draw(im).text((6, 4), f'{n} {w}', fill='white')
            out.paste(im, ((i % cols) * tw, (i // cols) * th))
        out.save(sheet)


if __name__ == '__main__':
    main()
