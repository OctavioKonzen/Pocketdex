"""Cenários da batalha desenhados por código, no mesmo formato dos que o
usuário mandou (KEEP, em assets/database/sprites/battle/): 4:3,
horizonte por volta de 1/3 da altura e as duas bases nos mesmos lugares
(a do adversário lá atrás à direita, a sua grande na frente à esquerda), com
os anéis pixelados. Os lugares que já têm imagem de verdade não são
sobrescritos (KEEP); mandando a imagem de um lugar, é só tirar daqui.

Uso: python3 tool/battle_backgrounds.py [lugar ...]   (sem nada: todos)
     SHEET=caminho.png python3 tool/battle_backgrounds.py   (+ folha com todos)

As bases: iguais a PLATFORMS.bw (web-site/src/components/BattleScene.jsx e
lib/widgets/battle_scene.dart), em frações da imagem.
"""

import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

W, H = 960, 716
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'database', 'sprites', 'battle')
# Os que vieram do usuário (imagens de verdade).
KEEP = {'snow', 'city', 'cave', 'icecave', 'forest', 'grass'}
# As bases (centro x, centro y, raio x, raio y), em frações da imagem: iguais às das imagens do usuário.
FOE = (0.761, 0.393, 0.241, 0.066)
MINE = (0.462, 0.80, 0.525, 0.20)


# ------------------------------------------------------------ ferramentas

def rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def noise(w, h, cells, seed, octaves=4, stretch=1.0):
    """Ruído suave (soma de oitavas), 0 a 1. stretch > 1 estica na horizontal (chão em perspectiva)."""
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w), np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        cw = max(2, int(cells * 2 ** o / stretch))
        ch = max(2, int(cells * 2 ** o * h / w))
        small = Image.fromarray((rng.random((ch, cw)) * 255).astype(np.uint8))
        out += np.asarray(small.resize((w, h), Image.BICUBIC), np.float32) / 255 * amp
        total += amp
        amp *= 0.5
    out /= total
    return (out - out.min()) / max(1e-6, out.max() - out.min())


def gradient(colors, w=W, h=H, y0=0, y1=None):
    """Degradê vertical por paradas [(posição 0-1, cor), ...] entre y0 e y1."""
    y1 = H if y1 is None else y1
    arr = np.zeros((h, w, 3), np.float32)
    for y in range(h):
        t = 0 if y1 == y0 else min(1, max(0, (y - y0) / (y1 - y0)))
        for (p0, c0), (p1, c1) in zip(colors, colors[1:]):
            if p0 <= t <= p1:
                k = 0 if p1 == p0 else (t - p0) / (p1 - p0)
                arr[y, :] = [c0[i] + (c1[i] - c0[i]) * k for i in range(3)]
                break
    return arr


def blend(base, color, alpha):
    """Pinta color por cima de base (arrays) com alpha (array 0-1 ou número)."""
    a = alpha[..., None] if isinstance(alpha, np.ndarray) else alpha
    return base * (1 - a) + np.array(color, np.float32) * a


def mask_from(draw_fn, blur=0):
    """Máscara 0-1 de um desenho (draw_fn recebe ImageDraw em L)."""
    m = Image.new('L', (W, H), 0)
    draw_fn(ImageDraw.Draw(m))
    if blur:
        m = m.filter(ImageFilter.GaussianBlur(blur))
    return np.asarray(m, np.float32) / 255


def ridge(seed, y, amp, rough=0.5, step=8):
    """Linha de montanhas/árvores: pontos de x=0 a W com altura variando."""
    rnd = random.Random(seed)
    pts, h = [], 0.0
    for x in range(-step, W + step * 2, step):
        h += rnd.uniform(-1, 1) * rough
        h *= 0.92
        pts.append((x, y - amp * (0.5 + 0.5 * math.sin(x / W * math.pi * rnd.uniform(1.5, 3) + seed)) - h * amp * 0.3))
    return pts


def hills(base, color, seed, y, amp, rough=0.5, step=8, blur=0, alpha=1.0, shade=None):
    pts = ridge(seed, y, amp, rough, step)
    m = mask_from(lambda d: d.polygon(pts + [(W + 20, H), (-20, H)], fill=255), blur)
    if shade is not None:
        # Mais claro em cima (luz), mais escuro embaixo.
        g = gradient([(0, shade), (1, color)], y0=int(y - amp * 1.2), y1=int(y + amp))
        return base * (1 - m[..., None] * alpha) + g * m[..., None] * alpha
    return blend(base, color, m * alpha)


def ground(base, top, c_far, c_near, seed, tex=(0.10, 0.10), stretch=4.0, cells=10, tint=None):
    """O chão do horizonte (top) até embaixo: degradê do longe ao perto com textura esticada (perspectiva)."""
    g = gradient([(0, c_far), (1, c_near)], y0=top, y1=H)
    n = noise(W, H, cells, seed, 5, stretch) - 0.5
    g = g + n[..., None] * np.array(tex[0] * 255) + (noise(W, H, cells * 3, seed + 1, 3, stretch * 1.5)[..., None] - 0.5) * tex[1] * 255
    if tint is not None:
        g = blend(g, tint[0], noise(W, H, 4, seed + 2, 2, 2) * tint[1])
    m = np.zeros((H, W), np.float32)
    m[top:] = 1
    edge = 10
    for i in range(edge):
        if top - edge + i >= 0:
            m[top - edge + i] = i / edge
    return base * (1 - m[..., None]) + g * m[..., None]


def platform(img, spec, edge, mid, center, outline, scale=3):
    """Base com anéis pixelados (como nas imagens do usuário): desenhada em baixa resolução e ampliada sem suavizar."""
    cx, cy, rx, ry = spec
    w, h = W // scale, H // scale
    layer = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    X, Y, RX, RY = cx * w, cy * h, rx * w, ry * h
    d.ellipse([X - RX, Y - RY, X + RX, Y + RY], fill=outline + (255,))
    rings = 14
    for k in range(rings):
        t = k / (rings - 1)
        f = 1 - t * 0.96
        col = lerp(edge, mid, min(1, t * 1.6)) if t < 0.62 else lerp(mid, center, (t - 0.62) / 0.38)
        rxk, ryk = (RX - 1.4) * f, (RY - 1.2) * f
        oy = -RY * 0.06 * t  # o meio um pouco mais para trás (perspectiva)
        d.ellipse([X - rxk, Y + oy - ryk, X + rxk, Y + oy + ryk], fill=col + (255,))
    big = layer.resize((W, H), Image.NEAREST)
    return Image.alpha_composite(img, big)


def to_img(arr):
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).convert('RGBA')


def paint(img, fn, blur=0, alpha=255):
    """Desenha numa camada (RGBA) e junta; blur para o que está longe."""
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    fn(ImageDraw.Draw(layer))
    if blur:
        layer = layer.filter(ImageFilter.GaussianBlur(blur))
    if alpha < 255:
        a = layer.getchannel('A').point(lambda v: v * alpha // 255)
        layer.putalpha(a)
    return Image.alpha_composite(img, layer)


def glow(img, x, y, r, color, strength=160):
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse([x - r, y - r, x + r, y + r], fill=color + (strength,))
    return Image.alpha_composite(img, layer.filter(ImageFilter.GaussianBlur(r * 0.6)))


def tree_cluster(d, x, y, size, color, light, rnd):
    """Copa de árvore: bolhas sobrepostas (escura embaixo, clara em cima à esquerda)."""
    for _ in range(9):
        ox, oy, r = rnd.uniform(-0.6, 0.6) * size, rnd.uniform(-0.9, 0.2) * size, rnd.uniform(0.35, 0.6) * size
        d.ellipse([x + ox - r, y + oy - r, x + ox + r, y + oy + r], fill=color)
    for _ in range(4):
        ox, oy, r = rnd.uniform(-0.6, 0.1) * size, rnd.uniform(-1.0, -0.4) * size, rnd.uniform(0.2, 0.35) * size
        d.ellipse([x + ox - r, y + oy - r, x + ox + r, y + oy + r], fill=light)


def pine(d, x, y, h, color, snow=None):
    w = h * 0.42
    for i in range(4):
        t = i / 4
        top = y - h + h * t * 0.75
        d.polygon([(x, top), (x - w * (0.45 + t * 0.55), top + h * 0.38), (x + w * (0.45 + t * 0.55), top + h * 0.38)], fill=color)
        if snow:
            d.polygon([(x, top), (x - w * 0.25, top + h * 0.12), (x + w * 0.2, top + h * 0.1)], fill=snow)
    d.rectangle([x - h * 0.03, y - h * 0.1, x + h * 0.03, y], fill=(60, 40, 30, 255))


def sparkles(img, n, seed, color, area=(0, 0, W, H), rmax=3, blur=1):
    rnd = random.Random(seed)

    def fn(d):
        for _ in range(n):
            x, y = rnd.uniform(area[0], area[2]), rnd.uniform(area[1], area[3])
            r = rnd.uniform(0.8, rmax)
            d.ellipse([x - r, y - r, x + r, y + r], fill=color + (rnd.randint(120, 255),))
    return paint(img, fn, blur)


HORIZON = int(H * 0.33)

# Cores das bases (borda, meio, centro, contorno) por clima do lugar.
BASE_BLUE = (rgb('2c5f9e'), rgb('3f86c8'), rgb('8cc8f4'), rgb('1d3f72'))


def bases(img, colors=BASE_BLUE):
    for spec in (FOE, MINE):
        img = platform(img, spec, *colors)
    return img


# ------------------------------------------------------------ lugares

def grass():
    a = gradient([(0, rgb('5fa8e8')), (0.6, rgb('a9d8f5')), (1, rgb('e3f3ff'))], y1=HORIZON)
    a = hills(a, rgb('7fb6a0'), 3, HORIZON - 10, 60, 0.4, 10, blur=2, alpha=0.8)
    a = hills(a, rgb('4f9a5a'), 5, HORIZON + 2, 34, 0.6, 6, shade=rgb('7cc06a'))
    a = ground(a, HORIZON, rgb('8fcf6c'), rgb('4f9c3e'), 11, tex=(0.12, 0.08), stretch=5)
    img = to_img(a)
    rnd = random.Random(7)
    img = paint(img, lambda d: [d.ellipse([x - 70, 60 + i * 9 - 18, x + 70, 60 + i * 9 + 18], fill=(255, 255, 255, 170)) for i, x in enumerate([120, 330, 600, 820])], blur=12)
    img = paint(img, lambda d: [tree_cluster(d, x, HORIZON + 6, rnd.uniform(26, 40), (46, 104, 52, 255), (88, 152, 78, 255), rnd) for x in range(-20, W + 40, 70)], blur=1)
    # Tufos de grama na frente.
    def tufts(d):
        r = random.Random(12)
        for _ in range(500):
            x, y = r.uniform(0, W), r.uniform(HORIZON + 20, H)
            s = 2 + (y - HORIZON) / H * 14
            d.polygon([(x, y), (x + s * 0.3, y - s), (x + s * 0.6, y)], fill=(60, 130, 50, 200) if r.random() < 0.6 else (130, 200, 90, 200))
    img = paint(img, tufts)
    return bases(img, (rgb('3d7f3a'), rgb('5ea84e'), rgb('a9dc84'), rgb('2a5a2a')))


def forest():
    a = gradient([(0, rgb('16361f')), (1, rgb('3f6b3a'))], y1=HORIZON + 20)
    a = ground(a, HORIZON + 10, rgb('3e5a2c'), rgb('24391c'), 21, tex=(0.16, 0.1), stretch=4, tint=(rgb('5b4a2a'), 0.35))
    img = to_img(a)
    # Raios de luz entre as árvores.
    img = paint(img, lambda d: [d.polygon([(x, 0), (x + 60, 0), (x + 200, HORIZON + 80), (x + 120, HORIZON + 80)], fill=(220, 240, 170, 40)) for x in (180, 470, 720)], blur=18)
    rnd = random.Random(4)
    for layer, (col, light, size, y, blur) in enumerate([
        ((26, 60, 30, 255), (40, 86, 42, 255), 70, HORIZON - 30, 4),
        ((22, 52, 26, 255), (46, 96, 44, 255), 90, HORIZON + 10, 2),
    ]):
        def fn(d, col=col, light=light, size=size, y=y):
            for x in range(-40, W + 80, int(size * 1.1)):
                d.rectangle([x - size * 0.08, y - size * 0.4, x + size * 0.08, y + size * 0.5], fill=(54, 38, 24, 255))
                tree_cluster(d, x, y - size * 0.6, size, col, light, rnd)
        img = paint(img, fn, blur)
    # Troncos grossos dos lados.
    img = paint(img, lambda d: [d.rectangle([x, 0, x + w, HORIZON + 70], fill=(48, 34, 22, 255)) for x, w in ((-10, 60), (W - 50, 70))])
    img = sparkles(img, 40, 9, (220, 255, 150), (0, 60, W, HORIZON + 60), 2.5, 2)
    return bases(img, (rgb('2f5f2a'), rgb('4f8c3c'), rgb('9fd06a'), rgb('1c3a1a')))


def water():
    a = gradient([(0, rgb('4a90d9')), (1, rgb('bfe4ff'))], y1=HORIZON)
    a = hills(a, rgb('6f9ab8'), 8, HORIZON - 4, 26, 0.5, 10, blur=3, alpha=0.7)
    a = ground(a, HORIZON, rgb('5fb0e0'), rgb('1f5f9f'), 31, tex=(0.10, 0.06), stretch=8)
    img = to_img(a)
    img = paint(img, lambda d: [d.ellipse([x - 80, 70 + i * 13 - 20, x + 80, 70 + i * 13 + 20], fill=(255, 255, 255, 180)) for i, x in enumerate([150, 420, 700, 900])], blur=12)

    def waves(d):
        r = random.Random(5)
        for _ in range(420):
            y = r.uniform(HORIZON + 6, H)
            s = 6 + (y - HORIZON) / H * 60
            x = r.uniform(-20, W)
            d.arc([x, y - s * 0.15, x + s, y + s * 0.15], 200, 340, fill=(230, 248, 255, 160), width=max(1, int(s / 25)))
    img = paint(img, waves, 0.6)
    return bases(img, (rgb('2b6aa8'), rgb('4b9be0'), rgb('a6dcff'), rgb('16406e')))


def beach():
    a = gradient([(0, rgb('3f9ee8')), (1, rgb('cdeeff'))], y1=HORIZON - 30)
    a = ground(a, HORIZON - 30, rgb('4fb3e6'), rgb('2a86c8'), 41, tex=(0.06, 0.04), stretch=10)
    a = ground(a, HORIZON + 14, rgb('f1dca6'), rgb('d9b878'), 42, tex=(0.10, 0.08), stretch=5)
    img = to_img(a)
    img = paint(img, lambda d: [d.ellipse([x - 90, 50 + i * 10 - 20, x + 90, 50 + i * 10 + 20], fill=(255, 255, 255, 190)) for i, x in enumerate([200, 520, 830])], blur=12)
    # Espuma na beira.
    img = paint(img, lambda d: d.line(ridge(3, HORIZON + 16, 4, 0.8, 12), fill=(255, 255, 255, 220), width=5), 1.5)

    def palm(d, x, y, h, flip):
        pts = [(x + math.sin(t / 10) * 18 * flip, y - h * t / 10) for t in range(11)]
        d.line(pts, fill=(110, 78, 46, 255), width=int(h * 0.06))
        tx, ty = pts[-1]
        for ang in range(0, 360, 45):
            a = math.radians(ang)
            d.polygon([(tx, ty), (tx + math.cos(a) * h * 0.45, ty + math.sin(a) * h * 0.22 + h * 0.08), (tx + math.cos(a + 0.25) * h * 0.4, ty + math.sin(a + 0.25) * h * 0.2 + h * 0.1)], fill=(40, 120, 60, 255))
    img = paint(img, lambda d: (palm(d, 40, HORIZON + 40, 230, 1), palm(d, W - 30, HORIZON + 30, 260, -1)))
    return bases(img, (rgb('c69a5a'), rgb('e3c487'), rgb('fff0c8'), rgb('8f6a36')))


def swamp():
    a = gradient([(0, rgb('2a3b2e')), (1, rgb('6f8a63'))], y1=HORIZON)
    a = ground(a, HORIZON, rgb('556b3f'), rgb('2e3b22'), 51, tex=(0.14, 0.1), stretch=4)
    img = to_img(a)
    # Poças de água parada.
    rnd = random.Random(6)
    img = paint(img, lambda d: [d.ellipse([x - w, y - w * 0.12, x + w, y + w * 0.12], fill=(70, 96, 80, 200)) for x, y, w in [(rnd.uniform(0, W), rnd.uniform(HORIZON + 20, H - 40), rnd.uniform(40, 140)) for _ in range(9)]], 2)

    def dead(d, x, y, h):
        d.line([(x, y), (x + 6, y - h)], fill=(40, 34, 28, 255), width=int(h * 0.07))
        for k in range(5):
            yy = y - h * (0.4 + k * 0.12)
            s = 1 if k % 2 else -1
            d.line([(x + 3, yy), (x + s * h * 0.25, yy - h * 0.15)], fill=(40, 34, 28, 255), width=max(2, int(h * 0.025)))
    img = paint(img, lambda d: [dead(d, x, HORIZON + 6, h) for x, h in ((70, 200), (240, 130), (520, 110), (690, 170), (900, 220))], 1.2)
    # Névoa.
    fog = noise(W, H, 5, 52, 3, 3)
    a = np.asarray(img, np.float32)[..., :3]
    m = np.clip((fog - 0.35) * 1.4, 0, 1) * np.clip(1 - np.abs(np.arange(H)[:, None] - HORIZON) / 180, 0, 1)
    img = to_img(blend(a, rgb('a9c29a'), m * 0.55))
    img = sparkles(img, 25, 53, (200, 255, 120), (0, HORIZON - 80, W, HORIZON + 140), 2, 2)
    return bases(img, (rgb('3a5a3a'), rgb('557d4c'), rgb('93b77a'), rgb('22361f')))


def sewer():
    a = gradient([(0, rgb('1e2326')), (1, rgb('3a4448'))], y1=HORIZON + 30)
    img = to_img(a)

    def bricks(d):
        for row in range(0, HORIZON + 40, 22):
            off = 0 if (row // 22) % 2 else 30
            for x in range(-60 + off, W, 60):
                c = 55 + (x * 7 + row * 3) % 18
                d.rectangle([x + 2, row + 2, x + 58, row + 20], fill=(c, c + 4, c + 2, 255))
    img = paint(img, bricks)
    # Arco escuro no fundo e canos.
    img = paint(img, lambda d: (d.ellipse([W * 0.32, HORIZON - 170, W * 0.68, HORIZON + 120], fill=(12, 14, 16, 255)), d.rectangle([W * 0.32, HORIZON - 25, W * 0.68, HORIZON + 40], fill=(12, 14, 16, 255))), 3)
    img = paint(img, lambda d: [d.rectangle([x, 0, x + 26, HORIZON + 30], fill=(70, 86, 78, 255)) for x in (60, 870)] + [d.rectangle([0, y, W, y + 18], fill=(64, 78, 72, 255)) for y in (40,)])
    a = np.asarray(img, np.float32)[..., :3]
    a = ground(a, HORIZON + 30, rgb('4d5652'), rgb('2d3431'), 61, tex=(0.12, 0.1), stretch=3)
    img = to_img(a)
    # Canal de água suja no meio.
    img = paint(img, lambda d: d.polygon([(W * 0.40, HORIZON + 30), (W * 0.60, HORIZON + 30), (W * 0.72, H * 0.52), (W * 0.30, H * 0.52)], fill=(52, 82, 70, 230)), 2)
    img = glow(img, W * 0.5, HORIZON - 20, 60, (120, 200, 160), 90)
    return bases(img, (rgb('3d4a46'), rgb('5c6e66'), rgb('94aaa0'), rgb('202826')))


def icecave():
    a = gradient([(0, rgb('0d2238')), (1, rgb('2f6d96'))], y1=HORIZON + 20)
    img = to_img(a)

    def icicles(d):
        r = random.Random(71)
        for x in range(-10, W + 20, 26):
            h = r.uniform(40, 170)
            d.polygon([(x, 0), (x + 26, 0), (x + 13 + r.uniform(-4, 4), h)], fill=(150, 210, 240, 230))
    img = paint(img, icicles, 1)
    img = paint(img, lambda d: [d.polygon([(x - 40, HORIZON + 30), (x, HORIZON - h), (x + 40, HORIZON + 30)], fill=(90, 160, 210, 255)) for x, h in ((80, 120), (180, 70), (780, 100), (900, 150))], 1.5)

    def crystals(d):
        for x, y, s in ((140, HORIZON + 10, 70), (830, HORIZON + 5, 90), (480, HORIZON - 10, 40)):
            for k in range(-1, 2):
                d.polygon([(x + k * s * 0.3, y), (x + k * s * 0.3 - s * 0.12, y - s * 0.4), (x + k * s * 0.3 + k * s * 0.15, y - s * (1.2 - abs(k) * 0.4)), (x + k * s * 0.3 + s * 0.12, y - s * 0.4)], fill=(170, 235, 255, 240))
    img = paint(img, crystals)
    for x, y in ((140, HORIZON - 30), (830, HORIZON - 40)):
        img = glow(img, x, y, 70, (120, 220, 255), 110)
    a = np.asarray(img, np.float32)[..., :3]
    a = ground(a, HORIZON + 20, rgb('9ccbe6'), rgb('4a8fbe'), 72, tex=(0.10, 0.08), stretch=6)
    img = to_img(a)
    img = sparkles(img, 80, 73, (230, 250, 255), (0, HORIZON + 20, W, H), 2, 0.8)
    return bases(img)


def underwater():
    a = gradient([(0, rgb('1a6fae')), (0.5, rgb('0f4f8a')), (1, rgb('0a2f5c'))])
    img = to_img(a)
    # Raios de luz de cima.
    img = paint(img, lambda d: [d.polygon([(x, 0), (x + 50, 0), (x + 160, H), (x + 60, H)], fill=(170, 230, 255, 45)) for x in (100, 380, 640, 860)], 20)
    a = np.asarray(img, np.float32)[..., :3]
    a = ground(a, HORIZON + 30, rgb('5d7fa0'), rgb('3a5876'), 81, tex=(0.14, 0.1), stretch=4, tint=(rgb('c2b38a'), 0.3))
    img = to_img(a)

    def weed(d):
        r = random.Random(82)
        for x in list(range(10, 260, 22)) + list(range(700, W, 24)):
            h = r.uniform(80, 220)
            pts = [(x + math.sin(t / 2 + x) * 10, HORIZON + 40 - h * t / 8) for t in range(9)]
            d.line(pts, fill=(40, 140, 90, 255), width=8)
        for x, y, s in ((90, HORIZON + 40, 60), (860, HORIZON + 30, 80), (430, HORIZON + 34, 35)):
            d.ellipse([x - s, y - s * 0.6, x + s, y + s * 0.3], fill=(52, 70, 92, 255))
    img = paint(img, weed, 1)
    rnd = random.Random(83)
    img = paint(img, lambda d: [d.ellipse([x - r, y - r, x + r, y + r], outline=(220, 245, 255, 200), width=2) for x, y, r in [(rnd.uniform(0, W), rnd.uniform(0, H * 0.7), rnd.uniform(3, 9)) for _ in range(40)]])
    return bases(img, (rgb('2a5f8e'), rgb('3f86c0'), rgb('8fd0f0'), rgb('163a5e')))


def mountain():
    a = gradient([(0, rgb('6aa6dc')), (1, rgb('d8ecf8'))], y1=HORIZON)
    a = hills(a, rgb('8aa0b8'), 91, HORIZON - 70, 120, 0.35, 24, blur=3, alpha=0.9, shade=rgb('eef4fa'))
    a = hills(a, rgb('7d7268'), 92, HORIZON + 4, 60, 0.4, 14, shade=rgb('a89a8a'))
    a = ground(a, HORIZON, rgb('a8998a'), rgb('6e6256'), 93, tex=(0.16, 0.1), stretch=4)
    img = to_img(a)
    rnd = random.Random(94)
    img = paint(img, lambda d: [d.polygon([(x - s, y), (x - s * 0.4, y - s * 0.8), (x + s * 0.5, y - s * 0.6), (x + s, y)], fill=(110, 100, 90, 255)) for x, y, s in [(rnd.uniform(0, W), rnd.uniform(HORIZON + 20, H * 0.55), rnd.uniform(12, 40)) for _ in range(12)]])
    return bases(img, (rgb('6b5e52'), rgb('8f8070'), rgb('c8b8a2'), rgb('3e352e')))


def volcano():
    a = gradient([(0, rgb('2a0f12')), (0.7, rgb('7a2a1a')), (1, rgb('c2552a'))], y1=HORIZON)
    img = to_img(a)
    img = paint(img, lambda d: d.polygon([(W * 0.2, HORIZON + 10), (W * 0.45, 70), (W * 0.58, 70), (W * 0.85, HORIZON + 10)], fill=(46, 26, 26, 255)), 2)
    img = glow(img, W * 0.515, 70, 70, (255, 140, 40), 200)
    img = paint(img, lambda d: [d.line([(W * 0.5 + k * 8, 72), (W * 0.48 + k * 30, HORIZON - 20)], fill=(255, 110, 30, 200), width=6) for k in (-1, 0, 1)], 2)
    img = paint(img, lambda d: [d.ellipse([x - r, y - r, x + r, y + r], fill=(60, 50, 50, 140)) for x, y, r in ((W * 0.5, 30, 50), (W * 0.56, -10, 60), (W * 0.45, 0, 40))], 10)
    a = np.asarray(img, np.float32)[..., :3]
    a = ground(a, HORIZON + 10, rgb('4a2a24'), rgb('24140f'), 101, tex=(0.14, 0.1), stretch=4)
    img = to_img(a)

    def lava(d):
        r = random.Random(102)
        for _ in range(14):
            x, y = r.uniform(0, W), r.uniform(HORIZON + 30, H)
            pts = [(x, y)]
            for _ in range(5):
                x += r.uniform(10, 50)
                y += r.uniform(-6, 6)
                pts.append((x, y))
            d.line(pts, fill=(255, 120, 30, 230), width=3)
    img = paint(img, lava, 1)
    img = sparkles(img, 60, 103, (255, 170, 60), (0, 0, W, H), 2.5, 1)
    return bases(img, (rgb('5a2a1e'), rgb('8a3e22'), rgb('e0742e'), rgb('2e130c')))


def desert():
    a = gradient([(0, rgb('e7a24f')), (1, rgb('fbe3a8'))], y1=HORIZON)
    img = to_img(a)
    img = glow(img, W * 0.2, 80, 70, (255, 250, 220), 230)
    a = np.asarray(img, np.float32)[..., :3]
    a = hills(a, rgb('d9a868'), 111, HORIZON - 8, 40, 0.3, 16, blur=3, alpha=0.8)
    a = hills(a, rgb('e6b874'), 112, HORIZON + 6, 26, 0.3, 14, shade=rgb('f6d49a'))
    a = ground(a, HORIZON, rgb('f0cd8e'), rgb('c9944f'), 113, tex=(0.10, 0.08), stretch=7)
    img = to_img(a)

    def cactus(d, x, y, h):
        c = (70, 130, 70, 255)
        d.rounded_rectangle([x - h * 0.08, y - h, x + h * 0.08, y], radius=int(h * 0.08), fill=c)
        d.rounded_rectangle([x - h * 0.3, y - h * 0.65, x - h * 0.2, y - h * 0.35], radius=int(h * 0.05), fill=c)
        d.rectangle([x - h * 0.3, y - h * 0.42, x - h * 0.05, y - h * 0.34], fill=c)
    img = paint(img, lambda d: (cactus(d, 60, HORIZON + 50, 120), cactus(d, 900, HORIZON + 30, 90)))
    return bases(img, (rgb('b07a3e'), rgb('d6a462'), rgb('f8dca6'), rgb('7a5026')))


def sky():
    a = gradient([(0, rgb('2f7fd6')), (1, rgb('bfe6ff'))])
    img = to_img(a)
    rnd = random.Random(121)

    def clouds(d, y0, y1, n, a):
        for _ in range(n):
            x, y, r = rnd.uniform(-50, W + 50), rnd.uniform(y0, y1), rnd.uniform(40, 110)
            d.ellipse([x - r, y - r * 0.45, x + r, y + r * 0.45], fill=(255, 255, 255, a))
    img = paint(img, lambda d: clouds(d, 40, HORIZON, 14, 170), 10)
    img = paint(img, lambda d: clouds(d, HORIZON, H, 40, 235), 6)
    return bases(img, (rgb('9bb8d6'), rgb('d6e8f6'), rgb('ffffff'), rgb('6f8fb2')))


def tower():
    a = gradient([(0, rgb('1b1030')), (1, rgb('4a2f72'))], y1=HORIZON + 20)
    img = to_img(a)
    img = paint(img, lambda d: [d.rectangle([x, 0, x + 50, HORIZON + 40], fill=(42, 30, 66, 255)) for x in (40, 230, 680, 870)] + [d.rectangle([x - 6, 0, x + 56, 22], fill=(58, 42, 88, 255)) for x in (40, 230, 680, 870)])
    for x in (65, 255, 705, 895):
        img = glow(img, x, HORIZON - 40, 26, (180, 140, 255), 160)
    img = paint(img, lambda d: [d.rectangle([x - 5, HORIZON - 40, x + 5, HORIZON - 20], fill=(230, 220, 250, 255)) for x in (65, 255, 705, 895)])
    a = np.asarray(img, np.float32)[..., :3]
    a = ground(a, HORIZON + 20, rgb('5a447e'), rgb('2b1f40'), 131, tex=(0.10, 0.08), stretch=3)
    fog = noise(W, H, 6, 132, 3, 3)
    a = blend(a, rgb('b9a2e6'), np.clip((fog - 0.45) * 1.2, 0, 1) * 0.4)
    img = to_img(a)
    return bases(img, (rgb('4d3a78'), rgb('6d58a8'), rgb('b8a4ee'), rgb('2a1f48')))


def gym():
    a = gradient([(0, rgb('202a3a')), (1, rgb('46566e'))], y1=HORIZON + 20)
    img = to_img(a)
    # Arquibancada e luzes.
    img = paint(img, lambda d: [d.rectangle([0, y, W, y + 14], fill=(60 + i * 8, 70 + i * 8, 90 + i * 8, 255)) for i, y in enumerate(range(80, HORIZON + 10, 22))])
    for x in (120, 360, 600, 840):
        img = glow(img, x, 40, 40, (255, 250, 220), 200)
    a = np.asarray(img, np.float32)[..., :3]
    a = ground(a, HORIZON + 20, rgb('c8b48a'), rgb('9c845a'), 141, tex=(0.05, 0.04), stretch=6)
    img = to_img(a)
    # Linhas do campo.
    img = paint(img, lambda d: (d.line([(W * 0.5, HORIZON + 20), (W * 0.5, H)], fill=(255, 255, 255, 200), width=4),
                                d.ellipse([W * 0.38, H * 0.5, W * 0.62, H * 0.62], outline=(255, 255, 255, 200), width=4),
                                d.line([(0, HORIZON + 60), (W, HORIZON + 60)], fill=(255, 255, 255, 160), width=3)), 0.8)
    return bases(img, (rgb('6a5a3a'), rgb('9a8458'), rgb('d8c49a'), rgb('3e3320')))


def league():
    a = gradient([(0, rgb('140c1e')), (1, rgb('3a2448'))], y1=HORIZON + 20)
    img = to_img(a)
    img = paint(img, lambda d: [d.rectangle([x, 20, x + 46, HORIZON + 30], fill=(196, 160, 90, 255)) for x in (30, 210, 700, 884)] + [d.rectangle([x - 8, 10, x + 54, 30], fill=(220, 190, 120, 255)) for x in (30, 210, 700, 884)])
    img = glow(img, W * 0.5, 60, 120, (255, 220, 140), 120)
    a = np.asarray(img, np.float32)[..., :3]
    a = ground(a, HORIZON + 20, rgb('5a3a5e'), rgb('2a1a2e'), 151, tex=(0.06, 0.04), stretch=6)
    img = to_img(a)
    # Tapete vermelho até o fundo.
    img = paint(img, lambda d: d.polygon([(W * 0.44, HORIZON + 20), (W * 0.56, HORIZON + 20), (W * 0.8, H), (W * 0.2, H)], fill=(150, 30, 40, 230)), 1)
    return bases(img, (rgb('8a6a2a'), rgb('c09a48'), rgb('f2d888'), rgb('4e3a12')))


def center():
    a = gradient([(0, rgb('f7c6d8')), (1, rgb('fdeef4'))], y1=HORIZON + 20)
    img = to_img(a)
    img = paint(img, lambda d: (d.rounded_rectangle([W * 0.3, 40, W * 0.7, HORIZON + 10], radius=20, fill=(255, 255, 255, 255)),
                                d.rectangle([W * 0.47, 70, W * 0.53, 170], fill=(230, 60, 80, 255)),
                                d.rectangle([W * 0.42, 100, W * 0.58, 140], fill=(230, 60, 80, 255)),
                                d.rectangle([0, HORIZON - 30, W, HORIZON + 20], fill=(240, 150, 175, 255))))
    a = np.asarray(img, np.float32)[..., :3]
    a = ground(a, HORIZON + 20, rgb('f4e2ea'), rgb('d8b6c6'), 161, tex=(0.04, 0.03), stretch=6)
    img = to_img(a)
    return bases(img, (rgb('d0607e'), rgb('ec90aa'), rgb('ffd8e4'), rgb('8e3550')))


SCENES = {
    'grass': grass, 'forest': forest, 'water': water, 'beach': beach, 'swamp': swamp, 'sewer': sewer,
    'icecave': icecave, 'underwater': underwater, 'mountain': mountain, 'volcano': volcano, 'desert': desert,
    'sky': sky, 'tower': tower, 'gym': gym, 'league': league, 'center': center,
}


def main():
    names = sys.argv[1:] or list(SCENES)
    os.makedirs(OUT, exist_ok=True)
    for name in names:
        if name in KEEP:
            continue
        img = SCENES[name]().convert('RGB')
        img.save(os.path.join(OUT, f'{name}.webp'), 'WEBP', quality=82, method=6)
        print(name)
    sheet = os.environ.get('SHEET')
    if sheet:
        all_names = sorted(set(SCENES) | KEEP)
        cols = 4
        tw, th = W // 3, H // 3
        out = Image.new('RGB', (tw * cols, th * math.ceil(len(all_names) / cols)), 'black')
        for i, name in enumerate(all_names):
            im = Image.open(os.path.join(OUT, f'{name}.webp')).resize((tw, th))
            ImageDraw.Draw(im).text((6, 4), name, fill='white')
            out.paste(im, ((i % cols) * tw, (i // cols) * th))
        out.save(sheet)


if __name__ == '__main__':
    main()
