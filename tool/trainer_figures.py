"""Mede onde está a figura de cada treinador no quadro (o primeiro da tira) e guarda em
assets/database/trainers.json como "fig": [topo, pés] (px, dentro do quadro de "size" px), e
"bust": [centro x da cabeça, topo], para mostrar o treinador da cintura para cima, com a cabeça
no mesmo lugar para todos (o cartão do perfil).

Com isso o app e o site desenham o treinador com a altura de uma pessoa na mesma escala dos
Pokémon (a margem vazia de cada imagem não conta). Rode de novo depois de build_trainers.py,
build_leader_trainers.py ou build_showdown_trainers.py (eles reescrevem a lista).

    python3 tool/trainer_figures.py
"""
import json
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIST = os.path.join(ROOT, 'assets', 'database', 'trainers.json')
SPRITES = os.path.join(ROOT, 'assets', 'database', 'sprites', 'trainers')


def main():
    with open(LIST, encoding='utf-8') as f:
        listing = json.load(f)
    for t in listing:
        path = os.path.join(SPRITES, f"{t['id']}.png")
        if not os.path.exists(path):
            continue
        size = t['size']
        box = Image.open(path).convert('RGBA').crop((0, 0, size, size)).getchannel('A').point(lambda a: 255 if a > 24 else 0).getbbox()
        if box:
            t['fig'] = [box[1], box[3]]
            # A cabeça: o alto da figura (~18% da altura), o centro dela na horizontal (braços e
            # cabelo dos lados não contam), para todos ficarem no mesmo lugar no cartão.
            alpha = Image.open(path).convert('RGBA').crop((0, 0, size, size)).getchannel('A').point(lambda a: 255 if a > 24 else 0)
            waist = box[1] + max(4, round((box[3] - box[1]) * 0.18))
            upper = alpha.crop((0, box[1], size, max(box[1] + 1, waist))).getbbox()
            if upper:
                t['bust'] = [round((upper[0] + upper[2]) / 2, 1), box[1]]
    with open(LIST, 'w', encoding='utf-8') as f:
        json.dump(listing, f, ensure_ascii=False, separators=(',', ':'))
        f.write('\n')
    print(sum('fig' in t for t in listing), 'de', len(listing))


if __name__ == '__main__':
    main()
