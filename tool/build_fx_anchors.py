#!/usr/bin/env python3
"""Onde fica a boca e a frente de cada Pokémon nos sprites animados (assets/database/fx_anchors.json).

Os golpes saem do lugar certo: o Flamethrower da boca, o soco da frente do corpo, nunca das costas.
Para cada sprite (front = o de frente, que olha para a esquerda/baixo, para você; back = o de costas, que olha
para a direita/cima, para o outro), no primeiro quadro:
  [largura, altura, x0, y0, x1, y1, boca_x, boca_y, frente_x, frente_y]  em pixels do sprite
(x0..y1: o contorno do que aparece; os pés ficam em y1).

A boca: na faixa da cabeça (o terço de cima do corpo), o ponto mais virado para quem está do outro lado, um pouco
abaixo do meio da cabeça. A frente: o lado do corpo virado para o outro, na altura do peito.

Uso: python3 tool/build_fx_anchors.py
"""
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SPR = ROOT / 'assets' / 'database' / 'sprites' / 'animated'
OUT = ROOT / 'assets' / 'database' / 'fx_anchors.json'


def first_frame(path):
    im = Image.open(path)
    im.seek(0)
    return im.convert('RGBA')


def anchors(path, facing):
    """facing -1: olha para a esquerda (sprite de frente); +1: para a direita (de costas)."""
    im = first_frame(path)
    w, h = im.size
    a = im.getchannel('A').load()
    rows = []
    for y in range(h):
        xs = [x for x in range(w) if a[x, y] >= 128]
        rows.append((min(xs), max(xs)) if xs else None)
    filled = [y for y in range(h) if rows[y]]
    if not filled:
        return None
    y0, y1 = filled[0], filled[-1]
    x0 = min(rows[y][0] for y in filled)
    x1 = max(rows[y][1] for y in filled)
    bh = y1 - y0 + 1
    # Ignora pontinhas finas no topo (antenas, orelhas): começa onde a linha já tem corpo.
    need = max(2, int((x1 - x0 + 1) * 0.12))
    top = y0
    while top < y1 and (rows[top] is None or rows[top][1] - rows[top][0] + 1 < need):
        top += 1
    # A cabeça: do topo até um terço do corpo (no de costas, a boca fica escondida: usa a parte de cima da frente).
    head_lo = top
    head_hi = min(y1, top + max(3, int(bh * (0.34 if facing < 0 else 0.3))))
    # O meio da cabeça (no topo) e, em cada linha, o pedaço contínuo que contém a cabeça (sem pegar a asa ou o rabo).
    tr = [x for x in range(w) if a[x, top] >= 128]
    hx = (tr[0] + tr[-1]) // 2 if tr else (x0 + x1) // 2
    reach = max(4, int((x1 - x0 + 1) * 0.35))

    def run(y, cx):
        if a[cx, y] < 128:
            near = [x for x in range(max(0, cx - 3), min(w, cx + 4)) if a[x, y] >= 128]
            if not near:
                return None
            cx = near[0]
        lo = cx
        while lo > 0 and a[lo - 1, y] >= 128:
            lo -= 1
        hi = cx
        while hi < w - 1 and a[hi + 1, y] >= 128:
            hi += 1
        return lo, hi

    best = None
    for y in range(head_lo, head_hi + 1):
        r = run(y, hx)
        if not r:
            continue
        lo, hi = max(r[0], hx - reach), min(r[1], hx + reach)
        edge = lo if facing < 0 else hi
        score = -edge if facing < 0 else edge
        # Prefere a parte de baixo da cabeça (a boca), não o topo.
        score += (y - head_lo) * 0.15
        if best is None or score > best[0]:
            best = (score, edge, y)
        hx = (lo + hi) // 2
    if best is None:
        best = (0, hx, top + bh // 6)
    _, mx, my = best
    mx = mx + (3 if facing < 0 else -3)  # um pouco para dentro do contorno
    # A frente do corpo: o lado virado para o outro, na altura do peito.
    fy = min(y1, top + int(bh * 0.45))
    while fy < y1 and not rows[fy]:
        fy += 1
    fr = rows[fy] or (x0, x1)
    fx = (fr[0] + 4) if facing < 0 else (fr[1] - 4)
    return [w, h, x0, y0, x1, y1, mx, my, fx, fy]


def main():
    out = {}
    fronts = sorted(p.stem for p in (SPR / 'front').glob('*.gif'))
    for sid in fronts:
        entry = {}
        f = anchors(SPR / 'front' / f'{sid}.gif', -1)
        if f:
            entry['f'] = f
        bp = SPR / 'back' / f'{sid}.gif'
        if bp.exists():
            b = anchors(bp, 1)
            if b:
                entry['b'] = b
        if entry:
            out[sid] = entry
    OUT.write_text(json.dumps(out, separators=(',', ':'), sort_keys=True) + '\n')
    print(f'fx_anchors.json: {len(out)} Pokémon')


if __name__ == '__main__':
    main()
