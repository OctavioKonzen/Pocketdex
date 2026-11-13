#!/usr/bin/env python3
"""
O mapa de cada região (como o Town Map dos jogos), desenhado aqui (arte própria,
com a geografia da região): o mar, o litoral com praia, o relevo, as florestas,
as montanhas, a neve, o deserto, os vulcões, os lagos, os rios e as rotas
(laranja). As cidades (os círculos) ficam por conta da tela, que mostra onde
você está.

Gera assets/database/sprites/maps/<mapa>.webp (e a cópia do site em
web-site/public/sprites/maps/) e as posições das cidades para o site
(web-site/src/lib/regionMaps.js) e o app (lib/screens/region_maps.dart).

Uso: python3 tool/region_maps.py [mapa ...]   (SHEET=arquivo.png para a folha de conferência)
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), '..')
OUT = os.path.join(ROOT, 'assets', 'database', 'sprites', 'maps')
OUT_SITE = os.path.join(ROOT, 'web-site', 'public', 'sprites', 'maps')

# ------------------------------------------------------------------ as regiões desenhadas à mão
# Hoenn, Alola, Galar e Paldea (sem referência com o traçado): em unidades de 150 × 100.
# land: o contorno da terra; islands: elipses (cx, cy, rx, ry); water: lagos e baías (elipses ou contornos);
# biomes: (tipo, forma) com forma = elipse (4 números) ou contorno (lista de pontos); rivers: linhas;
# roads: linhas (nomes de cidade ou pontos; 'sea' no começo = rota pelo mar); cities: nome → (x, y).
HAND = {
    # Kanto: pelo mapa do HeartGold/SoulSilver que você mandou (Mt. Silver e as montanhas no noroeste, a enseada a oeste de Fuchsia).
    'kanto': {
        'cities': {
            'Pewter City': (61, 28.6), 'Viridian City': (61, 53.6), 'Pallet Town': (61, 69.6), 'Cinnabar Island': (61, 94), 'Indigo Plateau': (38.7, 45.8),
            'Celadon City': (95.5, 42.9), 'Saffron City': (116.6, 42.9), 'Cerulean City': (116.6, 28.6), 'Lavender Town': (137, 42.9),
            'Vermilion City': (116.6, 54.8), 'Fuchsia City': (93.8, 83.3), 'Seafoam Islands': (76, 93),
        },
        'land': [(0, 0), (150, 0), (150, 100), (0, 100)],
        'islands': [(61, 94, 5, 4), (76, 93, 4, 3)],
        'water': [[(0, 90), (150, 88), (150, 100), (0, 100)],
                  [(0, 62), (40, 62), (52, 72), (58, 76), (66, 76), (72, 66), (74, 56), (82, 54), (83, 68), (82, 80), (86, 90), (0, 92)],
                  [(142, 0), (150, 0), (150, 24), (144, 18)]],
        'biomes': [('mountain', [(0, 0), (58, 0), (60, 18), (50, 34), (30, 38), (12, 56), (0, 58)]), ('mountain', (88, 16, 9, 6)), ('mountain', (137, 30, 4, 5)),
                   ('forest', (61, 40, 4, 5)), ('forest', (95, 72, 6, 4)), ('forest', (128, 70, 6, 5)), ('mountain', (38, 52, 4, 3)), ('forest', (104, 58, 4, 3))],
        'rivers': [[(120, 26), (130, 20), (140, 18)]],
        'roads': [
            ['Pewter City', 'Cerulean City'], ['Cerulean City', (137, 28.6), 'Lavender Town'], ['Cerulean City', (116.6, 12), (140, 12)],
            ['Pewter City', 'Viridian City'], ['Viridian City', 'Pallet Town'], ['sea', 'Pallet Town', 'Cinnabar Island'],
            ['sea', 'Cinnabar Island', 'Seafoam Islands', (93.8, 94), 'Fuchsia City'], ['Viridian City', (38.7, 53.6), 'Indigo Plateau'], [(38.7, 53.6), (20, 57), (0, 60)],
            ['Celadon City', 'Saffron City'], ['Saffron City', 'Lavender Town'], ['Cerulean City', 'Saffron City'], ['Saffron City', 'Vermilion City'],
            ['Vermilion City', (137, 54.8)], ['Lavender Town', (140, 71), (120, 76), (104, 83.3), 'Fuchsia City'], ['Celadon City', (85, 42.9), (85, 83.3), 'Fuchsia City'],
        ],
    },
    'hoenn': {
        'cities': {
            'Littleroot Town': (40, 80), 'Oldale Town': (40, 70), 'Petalburg City': (24, 70), 'Rustboro City': (12, 46), 'Dewford Town': (14, 90),
            'Slateport City': (62, 82), 'Mauville City': (60, 52), 'Verdanturf Town': (40, 50), 'Fallarbor Town': (24, 14), 'Lavaridge Town': (38, 34),
            'Fortree City': (78, 14), 'Lilycove City': (108, 24), 'Mossdeep City': (132, 30), 'Sootopolis City': (118, 52), 'Pacifidlog Town': (94, 84),
            'Ever Grande City': (142, 70),
        },
        'land': [(2, 2), (114, 2), (118, 16), (114, 32), (98, 34), (90, 40), (84, 58), (76, 68), (70, 84), (62, 90), (52, 88), (46, 84), (34, 82), (22, 78),
                 (8, 74), (4, 60), (4, 40), (2, 30)],
        'islands': [(132, 30, 9, 7), (118, 52, 8, 7), (142, 70, 6, 10), (14, 90, 4, 3), (94, 84, 3, 2), (104, 64, 3, 2), (128, 46, 3, 2), (82, 94, 2, 1.5)],
        'water': [(118, 52, 4, 3)],
        'biomes': [('volcano', (46, 24, 6, 5)), ('mountain', [(26, 20), (40, 16), (56, 18), (54, 30), (32, 30)]), ('mountain', (14, 28, 6, 6)), ('desert', (60, 24, 7, 7)),
                   ('forest', (14, 60, 5, 5)), ('forest', (82, 30, 6, 10)), ('forest', (96, 22, 6, 5)), ('mountain', (118, 52, 8, 7)), ('forest', (30, 46, 5, 4)),
                   ('mountain', (142, 64, 4, 5))],
        'rivers': [[(78, 16), (82, 36), (78, 52)], [(60, 60), (66, 68), (70, 76)]],
        'roads': [
            ['Littleroot Town', 'Oldale Town'], ['Oldale Town', 'Petalburg City'], ['Petalburg City', (10, 64), (12, 56), 'Rustboro City'],
            ['Rustboro City', (12, 30), (16, 20), 'Fallarbor Town'], ['Rustboro City', (26, 46), 'Verdanturf Town'], ['Verdanturf Town', 'Mauville City'],
            ['Oldale Town', (44, 60), (54, 60)], ['Slateport City', 'Mauville City'], ['sea', (10, 64), (10, 84), 'Dewford Town'],
            ['sea', 'Dewford Town', (30, 92), (50, 90), 'Slateport City'], ['Mauville City', (60, 30), (46, 30), 'Lavaridge Town'],
            [(60, 30), (60, 14), (40, 12), 'Fallarbor Town'], ['Mauville City', (80, 52), (80, 24), 'Fortree City'], ['Fortree City', (96, 16), 'Lilycove City'],
            ['sea', 'Lilycove City', (122, 26), 'Mossdeep City'], ['sea', 'Mossdeep City', (126, 44), 'Sootopolis City'],
            ['sea', 'Sootopolis City', (134, 64), 'Ever Grande City'], ['sea', 'Slateport City', (80, 88), 'Pacifidlog Town'],
            ['sea', 'Pacifidlog Town', (108, 72), 'Sootopolis City'],
        ],
    },
    'alola': {
        'cities': {
            'Iki Town': (32, 56), 'Verdant Cavern': (40, 74), 'Brooklet Hill': (70, 70), 'Wela Volcano Park': (84, 72), 'Lush Jungle': (72, 88),
            'Ruins of Life': (92, 86), 'Malie City': (102, 44), 'Hokulani Observatory': (126, 22), 'Mount Lanakila': (114, 16), 'Seafolk Village': (48, 34),
            'Vast Poni Canyon': (28, 20),
        },
        'land': [],
        'islands': [[(14, 62), (20, 52), (36, 49), (48, 57), (51, 72), (42, 86), (26, 90), (14, 80)],
                    [(60, 72), (70, 62), (86, 62), (98, 70), (100, 84), (88, 96), (70, 96), (60, 86)],
                    [(92, 24), (102, 10), (122, 7), (136, 18), (138, 36), (128, 50), (108, 53), (94, 42)],
                    [(16, 18), (26, 8), (44, 10), (55, 22), (50, 38), (36, 42), (22, 36)],
                    (60, 50, 3, 2), (82, 46, 2.5, 2)],
        'biomes': [('mountain', (32, 64, 6, 5)), ('volcano', (84, 72, 7, 6)), ('forest', (72, 88, 7, 5)), ('snow', (114, 16, 9, 7)), ('mountain', (28, 22, 9, 7)),
                   ('mountain', (126, 24, 5, 4)), ('desert', (100, 24, 5, 4)), ('forest', (22, 76, 5, 5)), ('forest', (118, 42, 6, 5))],
        'roads': [
            ['Iki Town', (34, 66), 'Verdant Cavern'], ['Verdant Cavern', (30, 84)], ['Brooklet Hill', 'Wela Volcano Park'], ['Wela Volcano Park', (86, 84), 'Ruins of Life'],
            ['Brooklet Hill', (66, 82), 'Lush Jungle'], ['Malie City', (110, 30), 'Mount Lanakila'], ['Malie City', (120, 40), 'Hokulani Observatory'],
            ['Seafolk Village', (40, 26), 'Vast Poni Canyon'], ['sea', (48, 72), (62, 74)], ['sea', (94, 66), (100, 52)], ['sea', (94, 38), (54, 30)],
        ],
    },
    'galar': {
        'cities': {
            'Postwick': (66, 94), 'Wedgehurst': (66, 86), 'Motostoke': (74, 72), 'Turffield': (52, 80), 'Hulbury': (98, 78), 'Hammerlocke': (72, 42),
            'Stow-on-Side': (52, 50), 'Ballonlea': (34, 48), 'Circhester': (62, 22), 'Spikemuth': (98, 26), 'Wyndon': (70, 7),
        },
        'land': [(56, 2), (84, 2), (96, 10), (104, 20), (110, 30), (104, 44), (108, 58), (112, 72), (104, 86), (88, 96), (58, 98), (42, 90), (34, 78),
                 (28, 62), (24, 48), (30, 36), (40, 26), (48, 12)],
        'water': [(66, 54, 4, 3)],
        'biomes': [('plain', (72, 58, 11, 11)), ('mountain', (60, 66, 4, 3)), ('forest', (34, 48, 6, 6)), ('desert', (46, 52, 5, 4)), ('snow', (64, 20, 15, 9)),
                   ('mountain', (82, 34, 6, 4)), ('forest', (88, 62, 5, 5)), ('mountain', (44, 30, 5, 4))],
        'rivers': [[(78, 46), (74, 58), (70, 68)], [(90, 40), (98, 56), (100, 70)]],
        'roads': [
            ['Postwick', 'Wedgehurst'], ['Wedgehurst', (68, 80), 'Motostoke'], ['Motostoke', (60, 78), 'Turffield'], ['Turffield', (60, 86), (86, 84), 'Hulbury'],
            ['Motostoke', (72, 58), 'Hammerlocke'], ['Hammerlocke', (56, 46), 'Stow-on-Side'], ['Stow-on-Side', (42, 50), 'Ballonlea'],
            ['Hammerlocke', (66, 32), 'Circhester'], ['Circhester', (82, 24), 'Spikemuth'], ['Circhester', (66, 12), 'Wyndon'],
        ],
    },
    'paldea': {
        'cities': {
            'Mesagoza': (74, 66), 'Cortondo': (50, 76), 'Artazon': (52, 50), 'Levincia': (116, 38), 'Cascarrafa': (30, 50), 'Medali': (46, 28),
            'Montenevera': (104, 18), 'Alfornada': (34, 84), 'Glaseado': (76, 14), 'Pokémon League': (82, 56), 'Porto Marinada': (14, 46),
        },
        'land': [(22, 20), (40, 8), (70, 4), (100, 4), (128, 14), (144, 32), (146, 60), (136, 80), (116, 94), (84, 98), (54, 96), (28, 90), (10, 72),
                 (6, 50), (12, 32)],
        'water': [(56, 16, 6, 4)],
        'biomes': [('crater', (78, 38, 13, 10)), ('desert', (30, 46, 9, 8)), ('snow', (78, 14, 15, 7)), ('mountain', (104, 22, 8, 5)), ('forest', (60, 30, 5, 4)),
                   ('forest', (102, 70, 8, 6)), ('swamp', (124, 56, 5, 4)), ('mountain', (40, 66, 5, 4))],
        'rivers': [[(56, 20), (54, 40), (60, 58), (66, 70), (70, 96)]],
        'roads': [
            ['Mesagoza', (64, 72), 'Cortondo'], ['Cortondo', (42, 80), 'Alfornada'], ['Mesagoza', (60, 58), 'Artazon'], ['Artazon', (40, 50), 'Cascarrafa'],
            ['Cascarrafa', (20, 48), 'Porto Marinada'], ['Cascarrafa', (36, 36), 'Medali'], ['Medali', (62, 18), 'Glaseado'], ['Glaseado', (90, 14), 'Montenevera'],
            ['Montenevera', (112, 26), 'Levincia'], ['Levincia', (100, 52), 'Mesagoza'], ['Mesagoza', 'Pokémon League'],
        ],
    },
}

# ------------------------------------------------------------------ as regiões com referência
# Kanto, Johto, Sinnoh, Unova e Kalos: o traçado das rotas e o lugar das cidades vêm de
# tool/region_maps_ref/ (rasterizados dos mapas em SVG do projeto maps.pokecompanion, licença MIT,
# github.com/helblinglilly/maps.pokecompanion). Aqui ficam o mar, as baías, os rios e o relevo de cada
# região, em % da largura e da altura: elipses (cx, cy, rx, ry) ou contornos (listas de pontos).
REF = {
    'kanto': {
        'sea': [[(0, 60), (9, 58), (13, 74), (28, 78), (44, 80), (50, 90), (64, 92), (80, 88), (100, 84), (100, 100), (0, 100)]],
        'land': [(17.9, 94.9, 6, 4), (37.4, 95, 4, 3), (56.8, 84, 7, 5)],
        'rivers': [[(72, 18), (80, 22), (88, 28)], [(64, 0), (66, 8), (70, 14)]],
        'biomes': [('mountain', [(0, 0), (12, 0), (12, 44), (0, 46)]), ('forest', (44, 60, 5, 5)), ('plain', (82, 66, 6, 4)), ('mountain', (64.5, 13.2, 4, 3))],
        'cities': {'Vermilion City': 'vermillion-city', 'Indigo Plateau': 'indigo-plateau', 'Seafoam Islands': 'seafoam-islands'},
    },
    'johto': {
        'sea': [[(0, 56), (14, 56), (28, 60), (34, 64), (38, 80), (46, 96), (0, 100)], [(46, 96), (56, 92), (62, 84), (72, 82), (80, 86), (100, 82), (100, 100), (40, 100)]],
        'land': [(19, 67, 6, 6), (28, 71, 2, 1.5), (31, 75, 1.5, 1.2), (9, 56, 5, 5)],
        'water': [(65, 17, 4, 3)],
        'rivers': [[(56, 52), (58, 62), (60, 76)], [(44, 40), (40, 50), (38, 60)]],
        'biomes': [('mountain', (57, 37, 5, 4)), ('snow', (86, 31, 4, 4)), ('mountain', (95, 53, 6, 10)), ('mountain', (82, 42, 4, 3)), ('forest', (44, 87, 4, 4)),
                   ('forest', (42, 45, 4, 3)), ('mountain', (57, 81, 3, 3)), ('mountain', (69, 54, 3, 3)), ('forest', (72, 64, 4, 3))],
        'cities': {},
    },
    'sinnoh': {
        'sea': [[(0, 96), (100, 96), (100, 100), (0, 100)], [(0, 0), (5, 0), (5, 68), (0, 70)], [(96, 0), (100, 0), (100, 96), (95, 88), (94, 60)],
                [(56, 47), (78, 46), (92, 46), (92, 49), (78, 49), (60, 49)]],
        'land': [(10, 73, 4, 4), (85, 52, 5, 6), (73, 36, 13, 10)],
        'water': [(12, 89, 2, 1.5), (70, 73, 4, 3), (40, 16, 2.5, 2)],
        'rivers': [],
        'biomes': [('snow', [(0, 0), (100, 0), (100, 24), (60, 26), (30, 26), (0, 24)]), ('mountain', [(40, 20), (46, 20), (47, 58), (46, 84), (41, 84), (42, 58)]),
                   ('forest', (30, 56, 4, 3)), ('swamp', (62, 82, 4, 3)), ('forest', (55, 60, 3, 4)), ('mountain', (85, 46, 3, 2)), ('forest', (78, 70, 4, 3))],
        'cities': {'Floaroma Town': 'floaroma-city', 'Solaceon Town': 'solaceon-city', 'Hearthome City': 'hearthorne-city', 'Pokémon League': 'sinnoh-pokemon-league'},
    },
    'unova': {
        'sea': [[(0, 96), (18, 96), (30, 84), (40, 86), (46, 90), (58, 88), (70, 92), (80, 100), (0, 100)], [(97, 28), (100, 26), (100, 62), (96, 58), (94, 46)]],
        'land': [(29, 86, 2, 1.6), (39, 93, 2, 1.6)],
        'water': [],
        'rivers': [[(42, 0), (41, 20), (40, 40), (40, 60), (42, 76), (46, 88)], [(62, 0), (64, 16), (62, 30)]],
        'biomes': [('mountain', (28, 33, 4, 4)), ('mountain', (26, 18, 4, 3)), ('mountain', (70, 9, 7, 4)), ('mountain', (17, 48, 3, 3)), ('mountain', (80, 40, 4, 3)),
                   ('mountain', (80, 21, 4, 3)), ('forest', (75, 74, 5, 4)), ('forest', (57, 50, 4, 4)), ('forest', (92, 70, 3, 3)), ('desert', (45, 62, 5, 5)),
                   ('swamp', (35, 21, 4, 3)), ('forest', (17, 70, 3, 3))],
        'cities': {'Pokémon League': 'unova-pokemon-league'},
    },
    'kalos': {
        'sea': [[(0, 0), (40, 0), (36, 18), (28, 26), (20, 30), (10, 34), (4, 46), (0, 48)], [(0, 80), (24, 82), (40, 88), (52, 100), (0, 100)], [(96, 0), (100, 0), (100, 100), (94, 80), (95, 50)]],
        'land': [(71, 90, 4, 3)],
        'water': [],
        'rivers': [[(30, 46), (36, 56), (44, 66), (50, 80)], [(88, 46), (92, 56), (96, 64)]],
        'biomes': [('snow', [(60, 18), (80, 16), (84, 32), (70, 34), (60, 30)]), ('snow', (80, 56, 6, 5)), ('mountain', (70, 52, 5, 4)), ('mountain', (89, 36, 3, 3)),
                   ('mountain', (15, 39, 3, 3)), ('forest', (63, 63, 4, 3)), ('forest', (76, 70, 5, 4)), ('desert', (42, 44, 5, 4)), ('mountain', (36, 74, 3, 3)),
                   ('forest', (44, 60, 4, 3))],
        'cities': {'Pokémon League': 'kalos-pokemon-league'},
    },
}
# Os mapas de cada região (Johto também mostra Kanto, onde a história continua depois da Liga).
REGIONS = {'Kanto': ['kanto'], 'Johto': ['johto', 'kanto'], 'Hoenn': ['hoenn'], 'Sinnoh': ['sinnoh'], 'Unova': ['unova'], 'Kalos': ['kalos'],
           'Alola': ['alola'], 'Galar': ['galar'], 'Paldea': ['paldea']}
REF_DIR = os.path.join(os.path.dirname(__file__), 'region_maps_ref')
WPX = 900

# ------------------------------------------------------------------ desenho
from scipy import ndimage  # noqa: E402
from skimage.morphology import skeletonize  # noqa: E402


class Canvas:
    def __init__(self, aspect):
        self.w, self.h = WPX, round(WPX / aspect)

    def pt(self, p):
        return (p[0] * self.w / 100, p[1] * self.h / 100)

    def shape(self, shape, blur=0):
        m = Image.new('L', (self.w, self.h), 0)
        d = ImageDraw.Draw(m)
        if isinstance(shape, tuple) and len(shape) == 4 and not isinstance(shape[0], tuple):
            cx, cy, rx, ry = shape
            d.ellipse([(cx - rx) * self.w / 100, (cy - ry) * self.h / 100, (cx + rx) * self.w / 100, (cy + ry) * self.h / 100], fill=255)
        else:
            d.polygon([self.pt(p) for p in shape], fill=255)
        if blur:
            m = m.filter(ImageFilter.GaussianBlur(blur))
        return np.asarray(m, dtype=float) / 255

    def lines(self, lines, width):
        m = Image.new('L', (self.w, self.h), 0)
        d = ImageDraw.Draw(m)
        for line in lines:
            d.line([self.pt(p) for p in line], fill=255, width=width, joint='curve')
        return np.asarray(m, dtype=float) / 255

    def noise(self, scale, seed, octaves=4):
        g = np.random.default_rng(seed)
        out = np.zeros((self.h, self.w))
        amp, total = 1.0, 0.0
        for o in range(octaves):
            n = max(2, int(scale * 2 ** o))
            grid = g.random((max(2, round(n * self.h / self.w)), n))
            out += np.asarray(Image.fromarray((grid * 255).astype(np.uint8)).resize((self.w, self.h), Image.BICUBIC), dtype=float) / 255 * amp
            total += amp
            amp *= 0.5
        return out / total


def blur(a, r):
    return np.asarray(Image.fromarray(np.clip(a * 255, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r)), dtype=float) / 255


def mix(base, color, alpha):
    a = np.clip(alpha, 0, 1)[..., None]
    return base * (1 - a) + np.array(color, dtype=float) * a


def roughen(mask, n, amount, r):
    return np.clip((blur(mask, r) + (n - 0.5) * amount - 0.5) * 10 + 0.5, 0, 1)


def near(mask, r):
    """Até r pixels de distância da máscara."""
    return ndimage.distance_transform_edt(~(mask > 0.5)) <= r


def load_mask(name, part, cv):
    path = os.path.join(REF_DIR, f'{name}-{part}.png')
    if not os.path.exists(path):
        return np.zeros((cv.h, cv.w), dtype=bool)
    im = Image.open(path).convert('L').resize((cv.w, cv.h), Image.NEAREST)
    return np.asarray(im) < 128


# Os lugares (cavernas, florestas, lagos...) viram o relevo em volta deles.
POI_BIOMES = [
    (r'lake|bay|spring|whirl', 'water', 2.5), (r'marsh|moor|swamp', 'swamp', 3.5), (r'desert|badland|relic-castle', 'desert', 4.5),
    (r'ice|frost|snow|glacier', 'snow', 4), (r'volcano|ember|chimney|stark', 'volcano', 3.5), (r'forest|woods|grove|park|garden|safari|meadow|ranch|dreamyard', 'forest', 4),
    (r'mt-|mount|mountain|cave|tunnel|victory-road|canyon|chasm|spiral|cliff|falls|rock|chamber', 'mountain', 3.5),
]


def ref_spec(name):
    import re
    spec = REF[name]
    places = json.load(open(os.path.join(REF_DIR, 'places.json')))[name]
    aspect = places['__aspect']
    biomes = list(spec.get('biomes', []))
    for pid, v in places.items():
        if pid == '__aspect' or v['kind'] != 'POI':
            continue
        for rx, kind, r in POI_BIOMES:
            if re.search(rx, pid):
                biomes.append((kind, (v['x'], v['y'], r, r * aspect)))
                break
    return aspect, places, biomes


def slug(name):
    import unicodedata
    s = unicodedata.normalize('NFKD', name).encode('ascii', 'ignore').decode().lower()
    return ''.join(c if c.isalnum() else '-' for c in s).strip('-')


def pretty(pid):
    return ' '.join(w.capitalize() for w in pid.split('_')[0].split('-'))


def ref_cities(name, places, wanted):
    """Todas as cidades e vilas do mapa (as da história com o nome dela no jogo): o lugar delas na referência."""
    out = {}
    used = set()
    alias = REF[name].get('cities', {})
    for city in wanted:
        key = alias.get(city) or slug(city)
        hit = next((pid for pid, v in places.items() if pid != '__aspect' and (pid == key or pid.split('_')[0] == key)), None)
        if hit:
            out[city] = (places[hit]['x'], places[hit]['y'])
            used.add(hit)
    for pid, v in places.items():
        if pid != '__aspect' and v['kind'] == 'Cities' and pid not in used and not pid[-1].isdigit():
            out.setdefault(pretty(pid), (v['x'], v['y']))
    return out


def paint(cv, land, rivers, biomes, roads_land, roads_bridge, roads_sea, seed=1):
    n1, n2, n3 = cv.noise(3, seed), cv.noise(6, seed + 1), cv.noise(14, seed + 2, 3)
    land = roughen(land, n2, 0.5, 9)
    land = np.minimum(land, 1 - np.clip(blur(rivers, 1.5) * 1.4 - 0.2, 0, 1))
    close = blur(land, 26)
    inner = blur(land, 5)
    img = np.zeros((cv.h, cv.w, 3))
    img[:] = (20, 58, 120)
    img = mix(img, (38, 104, 170), close * 1.8)
    img = mix(img, (78, 158, 206), close * 3 - 1.4)
    waves = (np.sin(np.arange(cv.h)[:, None] * 0.35 + n2 * 40) > 0.93) * (1 - land) * 0.12
    img = mix(img, (200, 230, 250), waves)
    img *= (0.92 + n1[..., None] * 0.16)
    ground = np.zeros_like(img)
    ground[:] = (64, 118, 56)
    ground = mix(ground, (44, 92, 44), (n1 - 0.45) * 3)
    ground = mix(ground, (96, 146, 70), np.clip((n2 - 0.6) * 3, 0, 1) * 0.6)
    height = n1 * 0.6 + n2 * 0.3 + n3 * 0.1
    layers = []
    for kind, shape in biomes:
        m = roughen(cv.shape(shape), n3, 0.5, 5)
        if kind == 'water':
            land = np.minimum(land, 1 - m)
            continue
        m = m * land
        layers.append((kind, shape, m))
        if kind in ('mountain', 'volcano', 'crater'):
            height = height + m * (0.8 + n3 * 0.8)
    gy, gx = np.gradient(height)
    shade = np.clip(1 + (-gx - gy) * 18, 0.6, 1.4)
    for kind, shape, m in layers:
        if kind == 'forest':
            ground = mix(ground, (30, 76, 40), m * 0.9)
            ground = mix(ground, (18, 54, 30), (n3 > 0.62) * m * 0.8)
            ground = mix(ground, (70, 120, 60), (n3 < 0.3) * m * 0.5)
        elif kind == 'mountain':
            ground = mix(ground, (128, 108, 80), m * 0.95)
            ground = mix(ground, (168, 150, 120), np.clip((n3 - 0.55) * 4, 0, 1) * m * 0.7)
        elif kind == 'volcano':
            ground = mix(ground, (96, 66, 54), m)
            ground = mix(ground, (210, 80, 40), cv.shape(shape, 6) * 3 - 2.2)
        elif kind == 'snow':
            ground = mix(ground, (226, 236, 246), m * 0.92)
        elif kind == 'desert':
            ground = mix(ground, (214, 184, 118), m * 0.95)
            ground = mix(ground, (190, 156, 96), np.clip((n3 - 0.6) * 4, 0, 1) * m * 0.6)
        elif kind == 'swamp':
            ground = mix(ground, (70, 96, 72), m)
            ground = mix(ground, (90, 140, 150), (n3 > 0.6) * m * 0.7)
        elif kind == 'plain':
            ground = mix(ground, (120, 168, 80), m * 0.8)
        elif kind == 'crater':
            cx, cy, rx, ry = shape
            ground = mix(ground, (120, 100, 80), m)
            ground = mix(ground, (46, 40, 52), roughen(cv.shape((cx, cy, rx * 0.62, ry * 0.62)), n3, 0.4, 4))
            ground = mix(ground, (120, 220, 200), (cv.shape((cx, cy, rx * 0.25, ry * 0.25), 5) * 2 - 0.6) * 0.6)
    ground *= shade[..., None]
    beach = np.clip((land - inner) * 3.2, 0, 1) * land
    ground = mix(ground, (226, 208, 150), beach * 0.85)
    img = img * (1 - land[..., None]) + ground * land[..., None]
    img = mix(img, (58, 128, 196), blur(rivers, 1.5) * 1.3 * 0.9)
    # As rotas: laranja com borda escura (pela linha do meio de cada uma); pelo mar, tracejadas.
    yy, xx = np.mgrid[0:cv.h, 0:cv.w]
    dash = ((xx // 9 + yy // 9) % 2) == 0
    for mask, dashed in ((roads_sea, True), (roads_land | roads_bridge, False)):
        if not mask.any():
            continue
        skel = skeletonize(mask)
        dist = ndimage.distance_transform_edt(~skel)
        if dashed:
            on = skel & dash
            dist = ndimage.distance_transform_edt(~on)
            img = mix(img, (120, 60, 10), (dist <= 3.4).astype(float))
            img = mix(img, (248, 184, 72), (dist <= 2.0).astype(float))
        else:
            img = mix(img, (110, 56, 10), np.clip(6.0 - dist, 0, 1))
            img = mix(img, (246, 168, 52), np.clip(4.0 - dist, 0, 1))
    v = 1 - 0.28 * np.clip((np.maximum(np.abs(xx / cv.w - 0.5), np.abs(yy / cv.h - 0.5)) - 0.38) * 8, 0, 1)
    return Image.fromarray(np.clip(img * v[..., None], 0, 255).astype(np.uint8))


def story_cities():
    data = json.load(open(os.path.join(ROOT, 'assets', 'database', 'factory.json')))
    out = {}
    for g in data['bosses']:
        out.setdefault(g['region'], set()).update(l['city'] for l in g['leaders'] if l.get('city'))
    return out


def build(name, wanted):
    """(imagem, cidades em %) de um mapa."""
    if name in REF and name not in HAND:
        aspect, places, biomes = ref_spec(name)
        cv = Canvas(aspect)
        spec = REF[name]
        rl, rb, rs = load_mask(name, 'land', cv), load_mask(name, 'bridge', cv), load_mask(name, 'sea', cv)
        cities = ref_cities(name, places, wanted)
        dots = np.zeros((cv.h, cv.w), dtype=bool)
        for v in places.values():
            if isinstance(v, dict):
                x, y = cv.pt((v['x'], v['y']))
                dots[min(cv.h - 1, max(0, int(y))), min(cv.w - 1, max(0, int(x)))] = True
        # A terra em volta das rotas e dos lugares, sem buracos de mar no meio (os lagos vêm de 'water').
        base = near(rl, 52) | near(dots, 34)
        closed = ~near(~near(base, 70), 70)
        land = ndimage.binary_fill_holes(base | closed).astype(float)
        for sh in spec.get('land', []):
            land = np.maximum(land, cv.shape(sh))
        for sh in spec.get('sea', []):
            land = np.minimum(land, 1 - cv.shape(sh, 6))
        for sh in spec.get('land', []):
            land = np.maximum(land, cv.shape(sh))
        land = np.minimum(land, 1 - near(rs, 12).astype(float) * (1 - np.maximum.reduce([cv.shape(sh) for sh in spec.get('land', [])] or [np.zeros((cv.h, cv.w))])))
        for sh in spec.get('water', []):
            land = np.minimum(land, 1 - cv.shape(sh))
        rivers = cv.lines(spec.get('rivers', []), 9)
        img = paint(cv, land, rivers, biomes, rl, rb, rs)
        return img, cities
    # Desenhado à mão (unidades de 150 × 100).
    spec = HAND[name]
    cv = Canvas(1.5)
    pc = lambda p: (p[0] / 1.5, p[1])  # noqa: E731
    conv = lambda sh: (sh[0] / 1.5, sh[1], sh[2] / 1.5, sh[3]) if isinstance(sh, tuple) and len(sh) == 4 and not isinstance(sh[0], tuple) else [pc(p) for p in sh]  # noqa: E731
    land = np.zeros((cv.h, cv.w))
    if spec.get('land'):
        land = np.maximum(land, cv.shape(conv(spec['land'])))
    for wtr in spec.get('water', []):
        land = np.minimum(land, 1 - cv.shape(conv(wtr)))
    for isl in spec.get('islands', []):
        land = np.maximum(land, cv.shape(conv(isl)))
    cities = {c: pc(xy) for c, xy in spec['cities'].items()}
    lines_land, lines_sea = [], []
    for road in spec.get('roads', []):
        sea = road[0] == 'sea'
        pts = [cities[p] if isinstance(p, str) else pc(p) for p in (road[1:] if sea else road)]
        (lines_sea if sea else lines_land).append(pts)
    rl, rs = cv.lines(lines_land, 5) > 0.5, cv.lines(lines_sea, 5) > 0.5
    rivers = cv.lines([[pc(p) for p in r] for r in spec.get('rivers', [])], 9)
    biomes = [(k, conv(sh)) for k, sh in spec.get('biomes', [])]
    img = paint(cv, land, rivers, biomes, rl, np.zeros_like(rl), rs, seed=3)
    return img, cities


def write_positions(found):
    data = {region: [{'id': m, 'cities': {c: [round(x, 2), round(y, 2)] for c, (x, y) in found[m].items()}} for m in maps] for region, maps in REGIONS.items()}
    js = ('// Gerado por tool/region_maps.py (não editar à mão): os mapas de cada região (como o Town Map dos jogos) e onde\n'
          '// fica cada cidade neles (em % da largura e da altura da imagem sprites/maps/<id>.webp). Igual ao app.\n\n'
          f'export const REGION_MAPS = {json.dumps(data, ensure_ascii=False)}\n\n'
          '/** A proporção (largura / altura) de cada imagem. */\n'
          f'export const MAP_ASPECT = {json.dumps({m: round(ASPECTS[m], 4) for m in found})}\n\n'
          '/** O mapa da região que tem a cidade de agora (Johto também mostra Kanto) e as cidades da história nele. */\n'
          'export function regionMap(region, cities, current) {\n'
          '  const maps = REGION_MAPS[region]\n'
          '  if (!maps) return null\n'
          '  const map = maps.find((m) => current && m.cities[current]) ?? maps[0]\n'
          '  return { id: map.id, aspect: MAP_ASPECT[map.id] ?? 1.5, spots: cities.map((c, i) => ({ ...c, i, xy: map.cities[c.city] })).filter((c) => c.xy) }\n'
          '}\n')
    open(os.path.join(ROOT, 'web-site', 'src', 'lib', 'regionMaps.js'), 'w').write(js)
    q = lambda s: "'" + s.replace("'", "\\'") + "'"  # noqa: E731
    lines = ['// lib/screens/region_maps.dart', '//',
             '// Gerado por tool/region_maps.py (não editar à mão): os mapas de cada região (como o Town Map dos jogos) e onde fica',
             '// cada cidade neles (em % da largura e da altura da imagem assets/database/sprites/maps/<id>.webp). Igual ao site.', '',
             'typedef RegionMapInfo = ({String id, double aspect, Map<String, List<double>> cities});', '',
             'const regionMaps = <String, List<RegionMapInfo>>{']
    for region, maps in data.items():
        lines.append(f'  {q(region)}: [')
        for m in maps:
            cities = ', '.join(f'{q(c)}: [{float(x)}, {float(y)}]' for c, (x, y) in m['cities'].items())
            lines.append(f"    (id: {q(m['id'])}, aspect: {round(ASPECTS[m['id']], 4)}, cities: <String, List<double>>{{{cities}}}),")
        lines.append('  ],')
    lines += ['};', '', '/// O mapa da região que tem a cidade de agora (Johto também mostra Kanto).',
              'RegionMapInfo? regionMapFor(String region, String? current) {', '  final maps = regionMaps[region];',
              '  if (maps == null || maps.isEmpty) return null;',
              '  return maps.where((m) => current != null && m.cities.containsKey(current)).firstOrNull ?? maps.first;', '}', '']
    open(os.path.join(ROOT, 'lib', 'screens', 'region_maps.dart'), 'w').write('\n'.join(lines))


ASPECTS = {}


def main():
    wanted_by_region = story_cities()
    names = [m for maps in REGIONS.values() for m in maps]
    names = list(dict.fromkeys(names))
    only = sys.argv[1:]
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(OUT_SITE, exist_ok=True)
    found, done = {}, []
    for name in names:
        wanted = set().union(*[wanted_by_region.get(r, set()) for r, maps in REGIONS.items() if name in maps])
        img, cities = build(name, wanted) if (not only or name in only) else (None, None)
        if img is None:
            img = Image.open(os.path.join(OUT, f'{name}.webp'))
            cities = build(name, wanted)[1] if name in REF and name not in HAND else {c: (xy[0] / 1.5, xy[1]) for c, xy in HAND[name]['cities'].items()}
        else:
            for folder in (OUT, OUT_SITE):
                img.save(os.path.join(folder, f'{name}.webp'), 'WEBP', quality=86, method=6)
            done.append((name, img, cities))
            print('ok', name, f'{len(cities)} cidades; da história faltando:', sorted(wanted - set(cities)))
        ASPECTS[name] = img.width / img.height
        found[name] = cities
    write_positions(found)
    sheet = os.environ.get('SHEET')
    if sheet and done:
        tw = 600
        rows = [(n, im.resize((tw, round(tw * im.height / im.width)), Image.LANCZOS), c) for n, im, c in done]
        out = Image.new('RGB', (tw * 2, sum(r[1].height for r in rows[::2]) + 10), (0, 0, 0))
        y = 0
        for k in range(0, len(rows), 2):
            for j, (n, t, c) in enumerate(rows[k:k + 2]):
                d = ImageDraw.Draw(t)
                for city, (x, yy) in c.items():
                    cx, cy = x / 100 * t.width, yy / 100 * t.height
                    d.ellipse([cx - 7, cy - 7, cx + 7, cy + 7], outline=(255, 176, 40), width=3, fill=(30, 90, 140))
                d.text((6, 4), n, fill=(255, 255, 255))
                out.paste(t, (j * tw, y))
            y += max(r[1].height for r in rows[k:k + 2])
        out.save(sheet)


if __name__ == '__main__':
    main()
