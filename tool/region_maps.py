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
from scipy import ndimage

ROOT = os.path.join(os.path.dirname(__file__), '..')
OUT = os.path.join(ROOT, 'assets', 'database', 'sprites', 'maps')
OUT_SITE = os.path.join(ROOT, 'web-site', 'public', 'sprites', 'maps')

# ------------------------------------------------------------------ as regiões desenhadas à mão
# Hoenn, Alola, Galar e Paldea (sem referência com o traçado): em unidades de 150 × 100.
# land: o contorno da terra; islands: elipses (cx, cy, rx, ry); water: lagos e baías (elipses ou contornos);
# biomes: (tipo, forma) com forma = elipse (4 números) ou contorno (lista de pontos); rivers: linhas;
# roads: linhas (nomes de cidade ou pontos; 'sea' no começo = rota pelo mar); cities: nome → (x, y).
HAND = {
    # Paldea: pelo mapa que você mandou (as áreas, o Casseroya Lake, o Glaseado, a Area Zero e o Asado Desert).
    'paldea': {
        'aspect': 0.95,
        'cities': {'Porto Marinada': (11.6, 41.0), 'Cascarrafa': (42.8, 45.6), 'Medali': (57.7, 40.8), 'Montenevera': (77.2, 18.3), 'Zapapico': (96.2, 46.2), 'Levincia': (129.9, 50.0), 'Pokémon League': (55.6, 63.0), 'Mesagoza': (71.6, 69.9), 'Cortondo': (38.6, 72.4), 'Artazon': (116.3, 68.1), 'Alfornada': (19.6, 85.5), 'Los Platos': (70.8, 82.5), 'Cabo Poco': (71.4, 90.2), 'Glaseado': (84.8, 23.8)},
        'land': [(8.8, 16.7), (26.4, 6.1), (44.8, 7.6), (52.8, 4.6), (76.8, 4.6), (93.6, 6.1), (106.3, 8.6), (111.9, 18.2), (130.3, 20.8), (137.5, 28.4), (146.3, 40.0), (140.7, 45.6), (139.1, 56.7), (143.1, 60.8), (142.3, 73.4), (119.9, 75.9), (111.9, 86.1), (95.9, 87.1), (80.0, 90.1), (76.8, 93.2), (65.6, 92.7), (65.6, 88.6), (33.6, 89.1), (24.0, 90.6), (8.0, 89.1), (7.2, 75.9), (13.6, 73.9), (4.0, 63.3), (2.4, 50.6), (7.2, 44.6), (6.4, 40.5), (8.0, 32.9), (10.4, 30.4)],
        'islands': [(114.3, 14.2, 3.2, 1.3), (147.9, 55.7, 1.6, 0.8), (5.6, 31.4, 1.2, 0.6)],
        'water': [[(12.8, 15.2), (35.2, 14.2), (44.8, 16.7), (51.2, 21.3), (56.0, 27.3), (44.8, 31.4), (33.6, 32.4), (20.0, 32.4), (12.8, 30.4)], (55.2, 61.3, 3.2, 2.0)],
        'biomes': [('snow', [(44.8, 9.6), (78.4, 6.1), (99.9, 8.6), (105.5, 18.2), (98.3, 26.3), (84.8, 32.4), (70.4, 28.4), (65.6, 22.3), (56.0, 18.2)]), ('desert', [(8.0, 45.6), (26.4, 39.5), (41.6, 40.5), (44.8, 45.6), (36.0, 50.6), (16.0, 50.6)]), ('crater', (70.4, 52.7, 18.4, 11.1)), ('forest', (97.5, 37.5, 7.2, 4.1)), ('desert', [(95.9, 39.5), (119.9, 38.5), (143.9, 40.5), (139.9, 46.6), (119.9, 48.6), (99.9, 48.1)]), ('mountain', (21.6, 82.5, 13.6, 6.6)), ('mountain', (102.3, 72.4, 14.4, 4.6)), ('plain', (48.0, 70.9, 13.6, 5.1)), ('forest', (56.0, 82.0, 12.0, 3.5)), ('mountain', (110.3, 12.7, 7.2, 3.5)), ('forest', (121.5, 30.4, 8.0, 5.1)), ('forest', (20.8, 55.7, 9.6, 6.1)), ('swamp', (107.9, 79.0, 6.4, 2.5)), ('mountain', (12.0, 60.8, 4.8, 6.1))],
        'rivers': [[(17.6, 62.8), (32.0, 65.8), (56.0, 67.3), (65.6, 71.9)], [(30.4, 66.8), (36.0, 75.9), (48.0, 80.5), (62.4, 80.0)], [(85.6, 77.0), (99.1, 81.0), (111.9, 84.1)], [(94.3, 53.7), (103.9, 52.7), (123.1, 53.7)], [(44.8, 32.4), (56.0, 35.4), (60.8, 39.5)]],
        'roads': [['Cabo Poco', 'Los Platos'], ['Los Platos', 'Mesagoza'], ['Mesagoza', 'Pokémon League'], ['Mesagoza', (56.0, 73.4), 'Cortondo'], ['Cortondo', (32.0, 80.0), 'Alfornada'], ['Cortondo', (40.0, 58.2), 'Cascarrafa'], ['Cascarrafa', 'Porto Marinada'], ['Cascarrafa', 'Medali'], ['Medali', (68.0, 30.4), 'Montenevera'], ['Montenevera', 'Glaseado'], ['Montenevera', (92.0, 32.9), 'Zapapico'], ['Zapapico', 'Levincia'], ['Levincia', (123.9, 60.8), 'Artazon'], ['Artazon', (92.0, 68.4), 'Mesagoza'], ['Pokémon League', 'Medali']],
    },
    'galar': {
        'aspect': 0.707,
        'cities': {'Postwick': (73.4, 91.0), 'Wedgehurst': (73.4, 84.2), 'Motostoke': (66.6, 54.2), 'Turffield': (55.7, 45.8), 'Hulbury': (83.0, 45.8), 'Hammerlocke': (77.9, 36.9), 'Stow-on-Side': (50.9, 36.9), 'Ballonlea': (50.9, 32.2), 'Circhester': (103.3, 30.3), 'Spikemuth': (114.9, 36.9), 'Wyndon': (77.9, 17.1)},
        'land': [(19.3, 9.1), (48.3, 6.1), (83.7, 4.6), (122.3, 7.6), (138.4, 13.7), (141.6, 22.8), (135.2, 34.9), (141.6, 45.5), (128.8, 57.7), (122.3, 69.8), (106.2, 81.9), (96.6, 91.0), (83.7, 97.1), (57.9, 97.1), (38.6, 91.0), (25.8, 78.9), (19.3, 65.3), (22.5, 53.1), (19.3, 44.0), (16.1, 34.9), (19.3, 22.8)],
        'islands': [(130.4, 28.8, 3.9, 1.2), (12.9, 63.7, 4.5, 1.5)],
        'water': [(80.5, 60.7, 8.4, 2.7), (96.6, 68.3, 6.4, 2.1), (96.6, 85.0, 5.2, 1.5)],
        'biomes': [('snow', [(29.0, 19.0), (64.4, 15.9), (122.3, 17.5), (132.0, 30.3), (106.2, 35.7), (77.3, 32.6), (45.1, 33.4)]), ('forest', (38.6, 32.6, 9.7, 3.9)), ('hills', (48.3, 37.9, 12.9, 3.3)), ('mountain', (83.7, 32.6, 16.1, 2.7)), ('plain', (72.4, 66.8, 19.3, 9.1)), ('hills', (109.4, 63.7, 14.5, 13.7)), ('forest', (35.4, 50.1, 9.7, 6.1)), ('hills', (32.2, 69.8, 9.7, 6.1)), ('forest', (90.1, 91.0, 9.7, 3.8)), ('hills', (48.3, 78.9, 19.3, 4.6)), ('hills', (119.1, 81.9, 12.9, 6.1)), ('plain', (64.4, 87.3, 9.7, 3.0)), ('hills', (35.4, 45.5, 9.7, 4.6))],
        'rivers': [[(80.5, 45.5), (77.3, 53.1), (80.5, 60.7)], [(103.0, 37.9), (106.2, 45.5), (99.8, 54.6)]],
        'roads': [['Postwick', 'Wedgehurst'], ['Wedgehurst', (67.6, 75.9), (67.6, 63.7), 'Motostoke'], ['Wedgehurst', (93.3, 81.9), (93.3, 78.6)], ['Motostoke', (55.7, 52.4), 'Turffield'], ['Motostoke', (83.0, 52.4), 'Hulbury'], ['Motostoke', (77.9, 48.6), 'Hammerlocke'], ['Hammerlocke', 'Stow-on-Side'], ['Stow-on-Side', 'Ballonlea'], ['Hammerlocke', 'Wyndon'], ['Hammerlocke', 'Spikemuth'], ['Circhester', (103.3, 36.9)]],
    },
    # Alola: pelo mapa que você mandou (as 4 ilhas e a Aether Paradise; o relevo pelo mapa ilustrado).
    'alola': {
        'aspect': 1.667,
        'cities': {'Iki Town': (49.3, 20.5), "Hau'oli City": (43.4, 28.5), 'Verdant Cavern': (55.7, 26.5), 'Paniola Town': (94.0, 29.3), 'Heahea City': (87.6, 36.3), 'Konikoni City': (84.4, 42.4), 'Brooklet Hill': (98.5, 19.9), 'Lush Jungle': (104.5, 15.5), 'Wela Volcano Park': (102.5, 32.1), 'Ruins of Life': (92.6, 46.5), 'Po Town': (117.9, 53.7), 'Malie City': (130.6, 63.1), 'Mount Lanakila': (123.4, 60.3), 'Hokulani Observatory': (138.4, 70.8), 'Tapu Village': (124.8, 81.2), 'Seafolk Village': (14.4, 54.3), 'Vast Poni Canyon': (23.9, 42.0), 'Aether Paradise': (59.5, 61.2)},
        'land': [],
        'islands': [[(34.8, 13.8), (39.8, 12.7), (44.8, 12.2), (50.8, 10.0), (55.7, 12.2), (59.7, 10.5), (62.2, 13.8), (60.7, 21.0), (63.2, 22.7), (64.7, 26.5), (69.7, 27.7), (71.2, 33.2), (69.7, 38.7), (63.7, 39.8), (55.7, 38.7), (52.8, 33.2), (48.8, 32.1), (47.8, 35.4), (44.8, 36.0), (44.8, 32.1), (41.8, 32.1), (38.3, 31.0), (37.8, 26.5), (36.8, 19.9)], [(91.1, 13.3), (95.6, 8.8), (103.5, 10.0), (107.0, 15.5), (110.5, 15.5), (111.5, 21.0), (107.5, 24.3), (108.5, 35.4), (111.0, 38.7), (107.5, 43.1), (102.5, 42.0), (99.5, 38.2), (100.5, 34.3), (93.6, 36.5), (89.6, 37.6), (86.6, 39.8), (85.6, 44.2), (88.6, 48.7), (95.6, 48.7), (96.1, 45.4), (92.6, 42.6), (87.6, 38.7), (86.6, 33.2), (89.6, 29.3), (88.6, 23.8), (90.6, 18.8)], [(114.5, 51.4), (117.5, 49.2), (120.4, 53.1), (129.4, 54.4), (130.4, 59.7), (134.4, 63.6), (138.9, 64.2), (142.3, 71.9), (142.3, 78.5), (135.4, 80.8), (128.4, 83.0), (127.4, 87.4), (121.4, 87.4), (115.5, 85.2), (113.5, 77.4), (114.5, 70.8), (115.5, 64.2), (117.0, 58.6)], [(12.9, 44.2), (17.9, 35.4), (20.9, 33.2), (25.9, 35.4), (31.9, 37.6), (32.8, 44.2), (30.9, 50.9), (26.9, 54.2), (19.9, 54.2), (14.9, 55.3), (11.9, 52.0), (12.4, 46.5)], (59.5, 60.8, 3.0, 2.4), (5.5, 52.0, 2.2, 1.7), (129.9, 14.2, 1.4, 1.3), (109.5, 19.4, 1.5, 2.2), (137.9, 63.9, 1.0, 0.9)],
        'water': [],
        'biomes': [('volcano', (99.5, 27.7, 7.0, 6.6)), ('mountain', (98.5, 21.0, 6.0, 5.5)), ('forest', (104.5, 15.5, 4.0, 3.9)), ('snow', (126.4, 70.8, 8.0, 7.7)), ('mountain', (127.4, 71.9, 11.9, 13.3)), ('mountain', (55.7, 25.4, 6.0, 5.5)), ('forest', (44.8, 19.9, 6.0, 4.4)), ('mountain', (23.9, 42.0, 7.0, 6.6)), ('desert', (117.5, 77.4, 3.0, 3.3)), ('forest', (16.9, 49.8, 5.0, 3.3)), ('forest', (89.6, 42.0, 5.0, 4.4)), ('forest', (137.4, 77.4, 4.0, 5.5)), ('plain', (93.6, 31.0, 4.0, 3.3)), ('forest', (63.7, 35.4, 4.0, 3.3))],
        'rivers': [],
        'roads': [['Iki Town', "Hau'oli City"], ['Iki Town', (55.7, 22.1), 'Verdant Cavern'], ['Verdant Cavern', (63.7, 33.2)], ['Heahea City', 'Paniola Town'], ['Paniola Town', 'Brooklet Hill'], ['Brooklet Hill', 'Lush Jungle'], ['Paniola Town', 'Wela Volcano Park'], ['Wela Volcano Park', (103.5, 38.7), 'Konikoni City'], ['Konikoni City', 'Ruins of Life'], ['Malie City', 'Mount Lanakila'], ['Malie City', 'Hokulani Observatory'], ['Malie City', (121.4, 57.5), 'Po Town'], ['Malie City', (128.4, 71.9), 'Tapu Village'], ['Seafolk Village', 'Vast Poni Canyon'], ['sea', "Hau'oli City", (64.7, 35.4), (83.6, 36.5), 'Heahea City'], ['sea', 'Konikoni City', (99.5, 53.1), (119.4, 64.2), 'Malie City'], ['sea', 'Tapu Village', (79.6, 77.4), (29.9, 57.5), 'Seafolk Village'], ['sea', "Hau'oli City", (55.7, 47.6), 'Aether Paradise']],
    },
    'kalos': {
        'aspect': 1.524,
        'cities': {'Laverre City': (77.3, 11.6), 'Coumarine City': (51.3, 30.0), 'Shalour City': (22.3, 35.9), 'Geosenge Town': (13.6, 47.7), 'Cyllage City': (26.0, 57.2), 'Ambrette Town': (33.6, 75.6), 'Camphrier Town': (61.9, 57.2), 'Lumiose City': (77.3, 37.0), 'Dendemille Town': (102.5, 30.0), 'Anistar City': (131.6, 38.0), 'Couriway Town': (139.5, 45.6), 'Snowbelle City': (127.0, 55.6), 'Pokémon League': (110.0, 43.5), 'Santalune City': (92.3, 56.9), 'Aquacorde Town': (99.3, 74.3), 'Vaniville Town': (99.3, 86.1), 'Kiloude City': (112.1, 92.0)},
        'land': [(0.0, 0.0), (150.0, 0.0), (150.0, 100.0), (0.0, 100.0)],
        'islands': [(37.5, 18.5, 2.0, 1.8), (38.8, 27.1, 1.0, 0.8), (42.8, 27.5, 0.8, 0.6), (20.4, 59.7, 1.0, 0.8)],
        'water': [[(0.0, 0.0), (71.7, 0.0), (69.7, 6.1), (65.7, 10.1), (59.7, 16.2), (55.7, 23.3), (46.8, 29.3), (39.8, 30.3), (31.9, 27.3), (23.9, 24.3), (17.9, 30.3), (13.9, 33.4), (10.0, 40.4), (6.0, 44.5), (8.0, 52.6), (12.9, 56.6), (17.9, 60.7), (24.9, 64.7), (28.9, 70.8), (29.9, 80.9), (32.8, 91.0), (37.8, 100.0), (0.0, 100.0)]],
        'biomes': [('mountain', (39.8, 43.5, 13.9, 7.1)), ('mountain', (46.8, 68.8, 13.9, 10.1)), ('mountain', (58.7, 49.5, 5.0, 4.0)), ('mountain', (79.6, 62.7, 6.0, 5.1)), ('mountain', (110.5, 47.5, 5.5, 8.1)), ('mountain', (139.3, 70.8, 10.9, 18.2)), ('snow', [(105.0, 0.0), (150.0, 0.0), (150.0, 30.3), (139.3, 33.4), (122.4, 25.3), (109.5, 20.2)]), ('desert', (63.7, 23.3, 8.0, 6.1)), ('forest', (89.6, 52.6, 5.0, 4.0)), ('forest', (99.5, 45.5, 5.0, 4.0)), ('forest', (122.4, 63.7, 6.0, 6.1)), ('forest', (92.6, 66.7, 6.0, 5.1)), ('forest', (69.7, 74.8, 7.0, 5.1)), ('plain', (82.6, 25.3, 6.0, 5.1)), ('forest', (19.9, 45.5, 4.0, 4.0))],
        'rivers': [[(41.8, 56.6), (46.8, 64.7), (55.7, 69.8), (61.7, 80.9), (69.7, 91.0)], [(86.6, 58.6), (95.6, 70.8), (109.5, 76.8), (117.5, 83.9), (129.4, 84.9)], [(117.5, 52.6), (114.5, 65.7), (113.5, 80.9)], [(123.4, 28.3), (130.4, 26.3), (137.4, 20.2), (150.0, 16.2)], [(61.7, 60.7), (69.7, 70.8), (85.6, 77.9)]],
        'roads': [['Shalour City', 'Coumarine City'], ['Coumarine City', 'Lumiose City'], ['Lumiose City', 'Laverre City'], ['Laverre City', 'Dendemille Town'], ['Lumiose City', 'Dendemille Town'], ['Dendemille Town', 'Anistar City'], ['Anistar City', 'Couriway Town'], ['Couriway Town', 'Snowbelle City'], ['Snowbelle City', (120.9, 75.3)], ['Santalune City', (110.0, 55.1), 'Snowbelle City'], ['Pokémon League', (110.0, 55.1)], ['Lumiose City', 'Santalune City'], ['Santalune City', (99.3, 64.2), 'Aquacorde Town'], ['Aquacorde Town', 'Vaniville Town'], ['Lumiose City', 'Camphrier Town'], ['Camphrier Town', 'Cyllage City'], ['Camphrier Town', (44.1, 44.5)], ['Shalour City', (18.4, 39.9), 'Geosenge Town'], ['Geosenge Town', 'Cyllage City'], ['sea', 'Cyllage City', 'Ambrette Town'], ['Ambrette Town', (54.2, 75.6)]],
    },
    'unova': {
        'aspect': 1.524,
        'cities': {'Icirrus City': (43.4, 25.6), 'Opelucid City': (77.3, 25.6), 'Lacunosa Town': (110.7, 25.6), 'Humilau City': (137.7, 21.4), 'Undella Town': (131.2, 39.9), 'Lentimas Town': (109.0, 39.9), 'Black City': (110.7, 53.9), 'Mistralton City': (23.1, 39.9), 'Driftveil City': (43.4, 53.9), 'Nimbasa City': (77.3, 53.9), 'Castelia City': (77.3, 77.1), 'Nacrene City': (118.9, 69.9), 'Striaton City': (133.6, 69.9), 'Accumula Town': (135.9, 81.8), 'Nuvema Town': (135.9, 93.8), 'Aspertia City': (8.2, 91.1), 'Floccesy Town': (19.0, 75.6), 'Virbank City': (40.4, 75.6), 'Pokémon League': (99.6, 8.6), 'Pokéstar Studios': (37.5, 68.2)},
        'land': [(0.0, 0.0), (150.0, 0.0), (150.0, 100.0), (0.0, 100.0)],
        'islands': [[(65.6, 61.9), (93.8, 61.9), (94.9, 83.3), (87.9, 95.2), (70.3, 95.2), (64.5, 77.4)], (58.0, 93.5, 3.5, 3.0), (43.4, 86.9, 2.3, 1.8)],
        'water': [[(46.9, 61.9), (64.5, 59.5), (69.1, 61.9), (96.7, 61.9), (104.3, 70.2), (114.8, 82.1), (120.7, 89.3), (120.7, 100.0), (46.9, 100.0), (42.2, 83.3), (45.7, 71.4)], [(141.8, 11.9), (150.0, 4.8), (150.0, 75.0), (143.0, 70.2), (140.6, 57.1), (138.3, 47.6), (143.0, 35.7), (140.6, 25.0)], [(0.0, 95.2), (11.7, 97.6), (17.6, 100.0), (0.0, 100.0)]],
        'biomes': [('desert', [(69.1, 59.5), (98.4, 59.5), (97.3, 75.0), (70.3, 75.0)]), ('desert', [(105.5, 23.8), (130.1, 26.2), (128.9, 56.5), (104.3, 56.5)]), ('crater', (77.3, 40.5, 9.4, 6.0)), ('mountain', (41.0, 34.5, 5.9, 6.0)), ('mountain', (23.4, 59.5, 8.2, 4.8)), ('forest', (17.6, 17.9, 14.1, 11.9)), ('forest', (64.5, 35.7, 8.2, 8.3)), ('forest', (117.2, 83.3, 10.5, 6.0)), ('mountain', (97.3, 10.7, 5.9, 4.8))],
        'rivers': [[(57.4, 0.0), (58.6, 23.8), (57.4, 41.7), (58.6, 58.3)], [(85.5, 0.0), (87.9, 11.9), (96.7, 23.8), (99.6, 41.7), (100.8, 59.5)]],
        'roads': [['Icirrus City', 'Opelucid City'], ['Opelucid City', 'Lacunosa Town'], ['Lacunosa Town', (114.3, 20.8), 'Humilau City'], ['Opelucid City', (78.5, 19.0), (93.8, 19.0), (94.9, 14.3), 'Pokémon League'], ['Pokémon League', (107.8, 9.2), (114.3, 10.7), (114.3, 20.8)], ['Humilau City', (146.5, 22.6), (146.5, 40.5), 'Undella Town'], ['Humilau City', 'Undella Town'], ['Lacunosa Town', 'Undella Town'], ['Lentimas Town', 'Undella Town'], ['Mistralton City', 'Icirrus City'], ['Mistralton City', 'Driftveil City'], ['sea', 'Icirrus City', 'Driftveil City'], ['Driftveil City', 'Nimbasa City'], ['Nimbasa City', 'Black City'], ['Black City', 'Undella Town'], ['Nimbasa City', 'Castelia City'], ['Castelia City', (99.6, 71.4), 'Nacrene City'], ['Nacrene City', 'Striaton City'], ['Striaton City', 'Accumula Town'], ['Accumula Town', 'Nuvema Town'], [(118.4, 94.6), 'Nuvema Town'], ['sea', (44.5, 61.0), (64.5, 69.6), 'Castelia City'], ['sea', 'Castelia City', (91.4, 85.1)], ['Aspertia City', (8.2, 78.0), 'Floccesy Town'], ['Floccesy Town', 'Virbank City']],
    },
    # Sinnoh: pelo mapa que você mandou (o Mt. Coronet no meio, a Battle Zone ao nordeste, a Liga do outro lado do mar).
    'sinnoh': {
        'aspect': 1.286,
        'cities': {'Snowpoint City': (56.9, 6.3), 'Eterna City': (49.4, 48.0), 'Celestic Town': (72.2, 45.8), 'Floaroma Town': (27.6, 60.4), 'Canalave City': (8.3, 72.9), 'Jubilife City': (25.3, 76.9), 'Oreburgh City': (44.7, 76.9), 'Hearthome City': (73.8, 68.7), 'Solaceon Town': (88.4, 62.5), 'Veilstone City': (107.7, 56.3), 'Pastoria City': (93.3, 85.5), 'Sunyshore City': (132.2, 76.9), 'Pokémon League': (129.8, 50.0), 'Sandgem Town': (27.6, 87.6), 'Twinleaf Town': (18.0, 91.7), 'Survival Area': (100.6, 20.8), 'Fight Area': (98.3, 33.3), 'Resort Area': (124.8, 37.4)},
        'land': [(0.0, 0.0), (150.0, 0.0), (150.0, 100.0), (0.0, 100.0)],
        'islands': [[(95.0, 0.9), (117.1, 0.0), (122.6, 11.4), (127.0, 28.4), (130.3, 37.9), (127.0, 43.6), (121.5, 42.6), (117.1, 36.0), (110.5, 39.8), (99.4, 37.9), (92.8, 31.2), (93.9, 18.9)], [(135.9, 0.0), (144.7, 0.0), (143.6, 11.4), (139.2, 18.9), (137.0, 11.4)], (13.8, 12.1, 4.4, 4.3), (23.2, 12.1, 4.4, 4.3), (18.2, 41.7, 2.8, 2.1), (23.7, 27.9, 1.7, 0.9)],
        'water': [[(0.0, 0.0), (33.1, 0.0), (32.0, 5.7), (35.3, 12.3), (33.1, 23.7), (32.0, 33.1), (27.6, 39.8), (22.1, 44.5), (17.7, 53.0), (8.8, 60.6), (0.0, 62.5)], [(66.3, 0.0), (95.0, 0.0), (92.8, 5.7), (95.0, 14.2), (91.7, 23.7), (91.7, 37.9), (95.0, 43.6), (102.7, 49.2), (119.3, 56.8), (123.7, 61.6), (127.0, 72.0), (131.4, 68.2), (132.5, 49.2), (139.2, 43.6), (150.0, 35.0), (150.0, 0.0), (135.9, 0.0), (133.7, 8.5), (131.4, 18.9)], [(61.9, 100.0), (99.4, 90.9), (112.7, 88.5), (127.0, 83.8), (138.1, 81.6), (150.0, 75.8), (150.0, 100.0)], (48.6, 6.6, 3.8, 3.4), (11.6, 86.6, 3.8, 2.8), (107.7, 75.8, 4.0, 3.2), (114.9, 67.2, 1.8, 2.1)],
        'biomes': [('snow', [(33.1, 0.0), (71.8, 0.0), (77.3, 18.9), (70.7, 31.2), (47.5, 31.2), (36.5, 26.5), (32.0, 11.4)]), ('mountain', [(59.6, 30.3), (67.4, 28.4), (70.7, 49.2), (72.9, 66.3), (70.7, 85.2), (66.3, 99.4), (59.6, 99.4), (61.9, 80.5), (59.6, 56.8), (57.4, 39.8)]), ('mountain', [(95.0, 0.9), (117.1, 0.0), (122.6, 11.4), (127.0, 28.4), (130.3, 37.9), (121.5, 42.6), (110.5, 39.8), (99.4, 37.9), (92.8, 31.2), (93.9, 18.9)]), ('mountain', (104.9, 53.0, 6.6, 6.6)), ('mountain', (122.6, 56.8, 4.4, 5.7)), ('forest', (36.5, 53.0, 6.6, 5.7)), ('forest', (22.1, 68.2, 7.7, 5.7)), ('forest', (83.9, 81.4, 8.8, 5.7)), ('forest', (116.0, 83.3, 7.7, 4.7)), ('forest', (86.2, 53.0, 4.4, 3.8)), ('swamp', (97.2, 81.4, 5.5, 3.8)), ('forest', (13.3, 92.8, 6.6, 3.8)), ('mountain', (139.7, 56.8, 3.3, 5.7)), ('forest', (49.7, 56.8, 4.4, 5.7))],
        'rivers': [],
        'roads': [['Snowpoint City', (47.2, 4.3), (47.2, 29.4), (61.9, 29.4), (61.9, 45.8)], ['Eterna City', 'Celestic Town'], ['Celestic Town', (86.2, 45.8), (86.2, 54.5), 'Veilstone City'], [(86.2, 54.5), 'Solaceon Town'], ['Solaceon Town', (86.2, 70.1), 'Hearthome City'], ['Eterna City', (47.2, 71.0), 'Hearthome City'], [(47.2, 71.0), 'Oreburgh City'], ['Eterna City', (32.0, 45.8), (27.6, 53.0), 'Floaroma Town'], ['Floaroma Town', 'Jubilife City'], ['Jubilife City', 'Canalave City'], ['Jubilife City', 'Oreburgh City'], ['Jubilife City', 'Sandgem Town'], ['Sandgem Town', (11.0, 87.6), (11.0, 83.3)], ['Twinleaf Town', (18.0, 87.6)], ['sea', 'Sandgem Town', (27.6, 96.1), (46.4, 96.1)], ['Hearthome City', (71.8, 87.6), 'Pastoria City'], ['Veilstone City', (109.9, 73.9), (106.0, 83.3), 'Pastoria City'], [(109.9, 78.6), 'Sunyshore City'], ['sea', 'Sunyshore City', (129.8, 66.3), 'Pokémon League'], ['Pokémon League', (139.7, 49.2), (139.7, 2.8)], ['Fight Area', (95.5, 33.3), (95.5, 20.8), 'Survival Area'], ['Survival Area', (115.4, 20.8), (115.4, 7.6)], ['Survival Area', (117.1, 20.8), (120.4, 30.3), 'Resort Area'], ['sea', 'Fight Area', (122.6, 33.3), 'Resort Area']],
    },
    # Hoenn: pelo mapa que você mandou (o continente a oeste, as ilhas de Mossdeep, Sootopolis, Ever Grande e Pacifidlog a leste).
    # Hoenn: pelo mapa que você mandou (o esquema com as cidades e o mapa ilustrado com o relevo).
    'hoenn': {
        'aspect': 1.522,
        'cities': {'Fallarbor Town': (22.5, 14.9), 'Fortree City': (67.5, 14.9), 'Lavaridge Town': (32.5, 30.1), 'Lilycove City': (99.8, 30.1), 'Rustboro City': (7.5, 42.6), 'Verdanturf Town': (27.6, 45.3), 'Mauville City': (50.0, 45.3), 'Mossdeep City': (129.9, 40.1), 'Sootopolis City': (112.5, 50.3), 'Petalburg City': (12.5, 60.6), 'Oldale Town': (27.6, 60.6), 'Littleroot Town': (27.6, 70.7), 'Slateport City': (47.5, 68.2), 'Pacifidlog Town': (92.4, 65.5), 'Ever Grande City': (142.5, 58.1), 'Dewford Town': (17.5, 85.9), 'Battle Frontier': (117.5, 75.8)},
        'land': [(6.0, 20.2), (10.0, 15.2), (21.9, 9.1), (27.9, 5.1), (32.8, 6.1), (37.8, 9.1), (41.8, 10.1), (51.8, 11.1), (59.7, 10.1), (69.7, 9.1), (79.6, 11.1), (89.6, 15.2), (97.5, 20.2), (103.5, 26.3), (104.5, 33.3), (98.5, 38.4), (94.6, 42.4), (89.6, 47.5), (84.6, 52.5), (75.6, 56.6), (64.7, 60.6), (59.7, 64.6), (55.7, 70.7), (51.8, 74.7), (46.8, 76.8), (43.8, 74.7), (41.8, 72.7), (37.8, 78.8), (32.8, 78.8), (24.9, 77.8), (21.9, 70.7), (14.9, 68.7), (10.9, 64.6), (8.0, 60.6), (6.0, 56.6), (5.5, 50.5), (3.0, 46.5), (2.0, 42.4), (4.0, 38.4), (6.0, 30.3)],
        'islands': [(129.4, 40.4, 6.2, 3.2), (112.5, 50.0, 5.8, 5.3), (144.3, 62.6, 5.0, 10.1), (16.9, 87.9, 9.5, 4.2), (95.6, 75.8, 8.5, 5.1), (129.4, 77.8, 6.0, 5.1), (107.5, 60.6, 2.5, 2.0), (92.6, 60.6, 2.0, 1.5), (49.8, 92.9, 4.5, 3.2), (67.7, 86.1, 1.6, 1.0), (142.3, 85.9, 2.0, 2.0), (60.7, 56.6, 9.5, 6.6), (107.5, 78.8, 2.2, 1.4)],
        'water': [(87.6, 38.4, 3.2, 2.6), (112.5, 50.0, 2.6, 2.2)],
        'biomes': [('volcano', (32.8, 23.2, 6.2, 5.3)), ('mountain', (20.9, 27.3, 7.0, 6.1)), ('desert', (41.8, 21.7, 4.0, 6.1)), ('forest', (10.0, 52.5, 4.2, 5.3)), ('forest', (64.7, 30.3, 8.0, 12.1)), ('forest', (79.6, 24.2, 8.0, 5.6)), ('mountain', (112.5, 50.0, 5.8, 5.3)), ('mountain', (144.3, 56.6, 3.2, 5.6)), ('forest', (32.8, 70.7, 5.5, 4.5)), ('forest', (13.9, 30.3, 5.0, 8.1)), ('forest', (61.7, 56.6, 7.0, 4.5)), ('mountain', (55.7, 26.3, 4.0, 6.1)), ('swamp', (53.7, 19.2, 3.0, 2.0))],
        'rivers': [[(46.8, 46.5), (47.8, 54.5), (46.8, 62.6)], [(59.7, 16.2), (61.7, 30.3), (59.7, 42.4)]],
        'roads': [['Rustboro City', (7.5, 25.3), (11.9, 25.3), (11.9, 14.9), 'Fallarbor Town'], ['Fallarbor Town', (47.6, 14.9), (47.6, 45.3)], [(47.6, 30.1), 'Lavaridge Town'], ['Rustboro City', (27.6, 40.2), 'Verdanturf Town'], ['Verdanturf Town', 'Mauville City'], ['Mauville City', (88.6, 45.3), (88.6, 30.1), 'Lilycove City'], ['Fortree City', (62.5, 14.9), (62.5, 45.3)], ['Fortree City', (72.5, 14.9), (72.5, 30.1), (88.6, 30.1)], ['Rustboro City', (7.5, 60.6), 'Petalburg City'], ['Petalburg City', 'Oldale Town'], ['Oldale Town', 'Littleroot Town'], ['Oldale Town', (27.6, 55.4), (47.6, 55.4), 'Slateport City'], ['Mauville City', (47.6, 55.4)], ['sea', (7.5, 60.6), (7.5, 80.8), (17.5, 80.8), 'Dewford Town'], ['sea', 'Dewford Town', (47.6, 84.8), 'Slateport City'], ['sea', 'Slateport City', 'Pacifidlog Town'], ['sea', 'Pacifidlog Town', (134.4, 65.5), (134.4, 58.1), 'Ever Grande City'], ['sea', 'Lilycove City', (129.9, 28.8), 'Mossdeep City'], ['sea', 'Mossdeep City', (120.9, 50.5), 'Sootopolis City'], ['sea', 'Sootopolis City', (120.9, 60.6), (134.4, 60.6)], ['sea', 'Pacifidlog Town', (109.5, 70.7), 'Battle Frontier']],
    },
    'johto': {
        'aspect': 1.428,
        'cities': {'Cianwood City': (16.9, 64.7), 'Olivine City': (34.3, 48.1), 'Ecruteak City': (58.7, 28.6), 'Mahogany Town': (79.2, 28.6), 'Blackthorn City': (102.0, 28.6), 'Violet City': (71.9, 46.0), 'Goldenrod City': (49.2, 65.0), 'Azalea Town': (57.6, 83.7), 'Cherrygrove City': (85.7, 68.2), 'New Bark Town': (106.5, 68.4), 'Indigo Plateau': (135.7, 15.8)},
        'land': [(0, 0), (150, 0), (150, 100), (0, 100)],
        'islands': [(12.6, 64.7, 13.5, 13.4)],
        'water': [[(0.0, 45.5), (26.7, 45.5), (29.5, 50.3), (36.0, 50.8), (39.3, 61.5), (39.3, 74.9), (42.1, 88.2), (56.2, 91.4), (68.8, 88.8), (74.7, 80.2), (74.7, 63.6), (82.0, 64.7), (92.7, 67.4), (112.4, 65.8), (123.6, 65.8), (134.8, 58.3), (150.0, 53.5), (150.0, 100.0), (0.0, 100.0)], (79.5, 8.0, 6.2, 3.7)],
        'biomes': [('mountain', (68.8, 22.7, 6.2, 3.7)), ('snow', (103.9, 20.1, 5.6, 3.7)), ('mountain', [(120.8, 5.3), (150.0, 0.0), (150.0, 45.5), (123.6, 42.8)]), ('forest', (44.9, 78.9, 5.1, 5.9)), ('forest', (61.8, 37.4, 4.5, 3.2)), ('mountain', (92.7, 50.8, 4.5, 3.7)), ('mountain', (66.0, 80.2, 3.9, 3.2)), ('forest', (19.7, 32.1, 8.4, 5.3)), ('forest', (92.7, 16.0, 5.1, 3.2))],
        'rivers': [],
        'roads': [[(3.7, 55.3), (3.7, 69.0), (16.9, 69.0), 'Cianwood City'], ['sea', 'Cianwood City', (30.3, 64.7), (30.3, 50.8), 'Olivine City'], ['Olivine City', (34.3, 28.6), 'Ecruteak City'], ['Ecruteak City', 'Mahogany Town'], ['Mahogany Town', 'Blackthorn City'], ['Mahogany Town', (79.2, 10.7)], ['Ecruteak City', (58.7, 46.0), 'Violet City'], ['Goldenrod City', (49.2, 46.0), (58.7, 46.0)], ['Violet City', (85.7, 46.0), 'Cherrygrove City'], ['Goldenrod City', (49.2, 83.7), 'Azalea Town'], ['Azalea Town', (71.9, 83.7), 'Violet City'], ['Cherrygrove City', 'New Bark Town'], ['New Bark Town', (118.5, 68.4), (118.5, 49.5), (150.0, 49.5)], ['Indigo Plateau', (134.8, 68.4)], ['Blackthorn City', (102.0, 56.1), (95.5, 56.1), (95.5, 68.2)]],
    },
    # Kanto: pelo mapa do HeartGold/SoulSilver que você mandou (Mt. Silver e as montanhas no noroeste, a enseada a oeste de Fuchsia).
    # Hisui (o provisório; vale o desenho em ART).
    'hisui': {
        'aspect': 1.5,
        'cities': {'Jubilife Village': (38.1, 54.7), 'Obsidian Fieldlands': (125.5, 54.7), 'Crimson Mirelands': (101.1, 51.8), 'Cobalt Coastlands': (132.3, 18.6), 'Coronet Highlands': (74.7, 32.2), 'Alabaster Icelands': (35.6, 20.5), 'Temple of Sinnoh': (97.2, 72.3)},
        'land': [(11.7, 15.6), (39.1, 10.7), (68.4, 8.8), (97.7, 11.7), (122.1, 10.7), (138.7, 19.5), (141.6, 41.0), (138.7, 68.4), (127.0, 80.1), (97.7, 84.0), (68.4, 82.0), (54.7, 78.1), (29.3, 81.1), (11.7, 74.2), (9.8, 50.8), (17.6, 39.1)],
        'islands': [(136.7, 14.6, 5.9, 3.9), (54.7, 62.5, 2.9, 2.4), (106.4, 85.9, 3.9, 2.4)],
        'water': [[(54.7, 58.6), (68.4, 54.7), (80.1, 60.5), (74.2, 70.3), (60.5, 70.3)], (110.4, 33.2, 5.9, 3.9)],
        'biomes': [('snow', [(12.7, 13.7), (54.7, 9.8), (62.5, 25.4), (41.0, 32.2), (19.5, 32.2)]), ('mountain', [(60.5, 19.5), (76.2, 14.6), (89.8, 25.4), (87.9, 44.9), (68.4, 45.9), (58.6, 37.1)]), ('snow', (74.2, 23.4, 6.8, 5.9)), ('forest', (50.8, 46.9, 10.7, 6.8)), ('swamp', (102.5, 54.7, 12.7, 7.8)), ('plain', (125.0, 58.6, 11.7, 8.8)), ('forest', (87.9, 68.4, 11.7, 7.8)), ('desert', (127.0, 24.4, 5.9, 3.9)), ('forest', (29.3, 68.4, 11.7, 5.9))],
        'rivers': [[(74.2, 41.0), (70.3, 50.8), (67.4, 58.6)]],
        'roads': [['Jubilife Village', 'Coronet Highlands'], ['Jubilife Village', (700, 600), 'Temple of Sinnoh'], ['Temple of Sinnoh', 'Crimson Mirelands'], ['Crimson Mirelands', 'Obsidian Fieldlands'], ['Crimson Mirelands', (1130, 400), 'Cobalt Coastlands'], ['Jubilife Village', 'Alabaster Icelands'], ['Coronet Highlands', (1000, 450), 'Crimson Mirelands']],
    },
    # Blueberry Academy (provisório, até o desenho que você mandou).
    'blueberry': {
        'aspect': 1.5,
        'cities': {'Savanna Biome': (125.0, 46.9), 'Coastal Biome': (25.4, 46.9), 'Canyon Biome': (108.4, 72.3), 'Polar Biome': (35.2, 20.5), 'League Club Room': (75.2, 34.2)},
        'land': [],
        'islands': [(75.2, 37.1, 22.5, 14.6), (32.2, 24.4, 22.5, 10.7), (25.4, 48.8, 13.7, 7.8), (43.0, 70.3, 27.3, 13.7), (102.5, 70.3, 31.2, 14.6), (125.0, 47.9, 18.6, 14.6), (127.0, 20.5, 17.6, 8.8)],
        'water': [],
        'biomes': [('snow', (29.3, 18.6, 14.6, 7.8)), ('mountain', (32.2, 17.6, 10.7, 5.9)), ('forest', (125.0, 46.9, 14.6, 10.7)), ('plain', (102.5, 70.3, 21.5, 9.8)), ('crater', (75.2, 35.2, 11.7, 8.8)), ('desert', (25.4, 50.8, 7.8, 3.9))],
        'rivers': [],
        'roads': [['Polar Biome', 'League Club Room'], ['Coastal Biome', 'League Club Room'], ['League Club Room', 'Savanna Biome'], ['League Club Room', 'Canyon Biome']],
    },
    'kanto': {
        'aspect': 1.524,
        'cities': {'Pewter City': (62.7, 28.6), 'Viridian City': (60.9, 53.6), 'Pallet Town': (60.9, 68.5), 'Cinnabar Island': (60.9, 92.9), 'Seafoam Islands': (76.2, 92.9), 'Indigo Plateau': (38.7, 45.8), 'Celadon City': (95.5, 42.9), 'Saffron City': (116.0, 42.9), 'Cerulean City': (116.0, 28.0), 'Lavender Town': (137.1, 42.9), 'Vermilion City': (116.0, 55.4), 'Fuchsia City': (95.5, 83.3)},
        'land': [(0, 0), (150, 0), (150, 100), (0, 100)],
        'islands': [(61, 94, 5, 4), (76, 93, 4, 3)],
        'water': [[(0, 90), (150, 88), (150, 100), (0, 100)],
                  [(0, 62), (40, 62), (52, 72), (58, 76), (66, 76), (72, 66), (74, 56), (82, 54), (83, 68), (82, 80), (86, 90), (0, 92)],
                  [(142, 0), (150, 0), (150, 24), (144, 18)]],
        'biomes': [('mountain', [(0, 0), (58, 0), (60, 18), (50, 34), (30, 38), (12, 56), (0, 58)]), ('mountain', (88, 16, 9, 6)), ('mountain', (137, 30, 4, 5)),
                   ('forest', (61, 40, 4, 5)), ('forest', (95, 72, 6, 4)), ('forest', (128, 70, 6, 5)), ('mountain', (38, 52, 4, 3)), ('forest', (104, 58, 4, 3))],
        'rivers': [[(120, 26), (130, 20), (140, 18)]],
        'roads': [['Viridian City', (23.4, 53.0)], ['Indigo Plateau', (38.7, 53.0)], [(38.7, 53.0), (36.3, 71.4), (0.0, 71.4)], ['Viridian City', 'Pewter City'], ['Viridian City', 'Pallet Town'], ['sea', 'Pallet Town', 'Cinnabar Island'], ['sea', 'Cinnabar Island', 'Seafoam Islands', (95.5, 93.5), 'Fuchsia City'], ['Pewter City', (62.7, 28.0), 'Cerulean City'], ['Cerulean City', (137.1, 28.0), 'Lavender Town'], ['Lavender Town', (137.1, 70.2), (121.9, 70.2), (121.9, 82.1), 'Fuchsia City'], ['Fuchsia City', (82.0, 82.1), (82.0, 54.8), 'Celadon City'], ['Celadon City', 'Saffron City'], ['Saffron City', 'Lavender Town'], ['Cerulean City', 'Saffron City'], ['Saffron City', 'Vermilion City'], ['Vermilion City', (137.1, 55.4)], ['Cerulean City', (116.0, 8.9), (137.7, 8.9)]],
    },
}

# ------------------------------------------------------------------ as regiões com referência
# Kanto, Johto, Sinnoh, Unova e Kalos (as primeiras versões, antes das imagens de referência): o traçado das rotas e o
# lugar das cidades vêm de tool/region_maps_ref/ (rasterizados dos mapas em SVG do projeto maps.pokecompanion, licença
# MIT, github.com/helblinglilly/maps.pokecompanion). Hoje todas as regiões são desenhadas à mão (HAND), que tem a vez.
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
REGIONS = {'Kanto': ['kanto'], 'Johto': ['johto', 'kanto'], 'Hoenn': ['hoenn'], 'Sinnoh': ['sinnoh'], 'Hisui': ['hisui'], 'Orre': ['orre'], 'Fiore': ['fiore'], 'Almia': ['almia'], 'Oblivia': ['oblivia'], 'Kitakami': ['kitakami'], 'Blueberry': ['blueberry'], 'Sevii': ['sevii'], 'Unova': ['unova'], 'Kalos': ['kalos'],
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
    """Desfoque em ponto flutuante (sem degraus: o relevo não fica listrado)."""
    return ndimage.gaussian_filter(np.asarray(a, dtype=float), max(0.1, r))


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
    # O relevo: morros suaves pela terra toda, mais alto longe do mar e bem alto nas montanhas.
    inland = blur(land, 40)
    height = n1 * 0.9 + n2 * 0.45 + n3 * 0.15 + inland * 0.8
    layers = []
    # As bordas dos biomas: deformadas pelo ruído (contorno irregular, como num mapa desenhado, e não elipses).
    wx, wy = cv.noise(5, seed + 50, 3), cv.noise(5, seed + 51, 3)
    yy0, xx0 = np.mgrid[0:cv.h, 0:cv.w].astype(float)
    amp = cv.w * 0.32
    wcoords = [yy0 + (wy - 0.5) * amp, xx0 + (wx - 0.5) * amp]
    # Cristas das serras (ruído "ridged"): o relevo das montanhas tem espinhaço e vales, não é um morro liso.
    ridge = (1 - np.abs(cv.noise(9, seed + 60, 4) * 2 - 1)) ** 2 * 0.7 + (1 - np.abs(cv.noise(22, seed + 61, 3) * 2 - 1)) ** 2 * 0.3
    for kind, shape in biomes:
        # A forma: elipse, contorno ou uma máscara pronta (tirada da imagem de referência).
        if isinstance(shape, np.ndarray):
            m = roughen(shape.astype(float), n3, 0.4, 3)
        else:
            m = roughen(ndimage.map_coordinates(cv.shape(shape), wcoords, order=1, mode='nearest'), n3, 0.6, 4)
        if kind == 'water':
            land = np.minimum(land, 1 - m)
            continue
        m = m * land
        dome = blur(m, cv.w * 0.016)
        layers.append((kind, shape, m, dome))
        if kind in ('mountain', 'volcano', 'snow'):
            height = height + dome * 1.6 + m * dome * ridge * (2.6 if kind != 'snow' else 1.6) + blur(m, 2) * n3 * 0.5
        elif kind == 'crater':
            # Um anel alto em volta de um fundo bem baixo.
            cx, cy, rx, ry = shape
            pit = blur(cv.shape((cx, cy, rx * 0.66, ry * 0.66)), 6) * land
            height = height + dome * 1.4 + m * ridge * 1.6 - pit * 2.6
        elif kind == 'hills':
            # Colinas: relevo só pela sombra (verde), sem pedra.
            height = height + dome * 1.1 + m * dome * ridge * 1.2
        elif kind == 'forest':
            height = height + blur(m, 4) * 0.3 + m * ridge * 0.15
        elif kind == 'plain':
            height = height - blur(m, 6) * 0.2
    lo, hi = height.min(), height.max()
    height = blur(np.clip((height - lo) / max(1e-6, hi - lo), 0, 1), 1.0)
    gy, gx = np.gradient(height)
    # A luz vem do noroeste: a encosta virada para ela clareia, a outra escurece.
    shade = np.clip(1 + (-gx - gy) * 80, 0.42, 1.65)
    # A cor pela altitude: baixada verde-escura, planalto mais claro e amarelado.
    ground = mix(ground, (40, 88, 46), np.clip((0.35 - height) * 3, 0, 1) * 0.5)
    ground = mix(ground, (122, 150, 82), np.clip((height - 0.5) * 2.5, 0, 1) * 0.45)
    for kind, shape, m, dome in layers:
        if kind == 'forest':
            ground = mix(ground, (30, 76, 40), m * 0.9)
            ground = mix(ground, (18, 54, 30), (n3 > 0.62) * m * 0.8)
            ground = mix(ground, (70, 120, 60), (n3 < 0.3) * m * 0.5)
        elif kind == 'mountain':
            # Pé verde-acinzentado, rocha marrom, cume claro e neve no topo das mais altas.
            ground = mix(ground, (104, 112, 74), np.clip(blur(m, 4) * 1.6, 0, 1) * 0.6)
            ground = mix(ground, (128, 108, 80), m * 0.95)
            ground = mix(ground, (168, 150, 120), np.clip((n3 - 0.55) * 4, 0, 1) * m * 0.7)
            ground = mix(ground, (190, 176, 150), np.clip((height - 0.72) * 6, 0, 1) * m * 0.8)
            ground = mix(ground, (240, 244, 250), np.clip((height - 0.86) * 9, 0, 1) * m)
        elif kind == 'volcano':
            ground = mix(ground, (96, 66, 54), m)
            if not isinstance(shape, np.ndarray):
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
        elif kind == 'hills':
            ground = mix(ground, (92, 136, 62), m * 0.5)
            ground = mix(ground, (128, 140, 92), np.clip((height - 0.7) * 5, 0, 1) * m * 0.5)
        elif kind == 'crater':
            cx, cy, rx, ry = shape
            ground = mix(ground, (120, 100, 80), m)
            ground = mix(ground, (70, 120, 72), np.clip((n3 - 0.5) * 4, 0, 1) * m * 0.5)
            ground = mix(ground, (46, 40, 52), roughen(cv.shape((cx, cy, rx * 0.62, ry * 0.62)), n3, 0.4, 4))
            ground = mix(ground, (120, 220, 200), (cv.shape((cx, cy, rx * 0.25, ry * 0.25), 5) * 2 - 0.6) * 0.6)
    ground *= shade[..., None]
    # Curvas de nível: linhas finas onde a altitude muda de faixa (mais marcadas nas serras).
    level = np.floor(height * 18)
    edge = (level != np.roll(level, 1, 0)) | (level != np.roll(level, 1, 1))
    hilly = np.clip(height * 1.6 - 0.35, 0.15, 1)
    ground = mix(ground, (40, 34, 26), edge * hilly * 0.22 * (blur(land, 3) > 0.9))
    beach = np.clip((land - inner) * 3.2, 0, 1) * land
    ground = mix(ground, (226, 208, 150), beach * 0.85)
    img = img * (1 - land[..., None]) + ground * land[..., None]
    # A espuma na beira da praia.
    lm = land > 0.5
    foam = near(lm, 2.5) & ~lm
    img = mix(img, (236, 246, 252), foam * 0.55)
    img = mix(img, (150, 200, 230), (near(lm, 7) & ~near(lm, 4.5)) * (n3 > 0.5) * 0.25)
    img = mix(img, (58, 128, 196), blur(rivers, 1.5) * 1.3 * 0.9)
    img = details(cv, img, land, layers, seed, height)
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


def scatter(mask, step, rng, thresh=0.6):
    """Pontos espalhados (grade com sorteio) onde a máscara é forte."""
    h, w = mask.shape
    pts = []
    for y in range(step // 2, h, step):
        for x in range(step // 2, w, step):
            px_, py_ = int(x + rng.uniform(-step / 2, step / 2)), int(y + rng.uniform(-step / 2, step / 2))
            if 0 <= px_ < w and 0 <= py_ < h and mask[py_, px_] > thresh:
                pts.append((px_, py_))
    rng.shuffle(pts)
    return sorted(pts, key=lambda q: q[1])


def details(cv, img, land, layers, seed, height):
    """O detalhe de cada bioma (como num mapa desenhado): árvores, picos, dunas, juncos, a lava e os arvoredos dos campos."""
    rng = np.random.default_rng(seed + 11)
    out = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).convert('RGBA')
    d = ImageDraw.Draw(out, 'RGBA')
    covered = np.zeros_like(land)
    cold = np.zeros_like(land)
    for kind, shape, m, dome in layers:
        if kind in ('snow', 'mountain'):
            cold = np.maximum(cold, blur(m, 18) * (1.0 if kind == 'snow' else 0.6))
    # Grama: tufos pequenos pela terra toda (textura).
    tuft = rng.random(land.shape) < 0.035
    for y, x in zip(*np.nonzero(tuft & (blur(land, 3) > 0.95))):
        d.line([(x, y), (x + 1, y - 2)], fill=(30, 70, 34, 90), width=1)
    for kind, shape, m, dome in layers:
        covered = np.maximum(covered, m)
        if kind == 'forest':
            dn = dome / max(1e-6, dome.max())
            for x, y in scatter(m, 6, rng, 0.4):
                r = rng.uniform(2.8, 4.2) + dn[y, x] * 1.4
                g = int(rng.integers(0, 26))
                if cold[y, x] > 0.35 or rng.random() < 0.12:
                    # Pinheiro (perto da neve e das serras).
                    d.polygon([(x, y - r * 2.1), (x - r, y + r * 0.6), (x + r, y + r * 0.6)], fill=(10, 34, 18, 140))
                    d.polygon([(x, y - r * 2.3), (x - r * 0.95, y + r * 0.4), (x, y + r * 0.4)], fill=(30 + g, 86 + g, 52, 255))
                    d.polygon([(x, y - r * 2.3), (x + r * 0.95, y + r * 0.4), (x, y + r * 0.4)], fill=(18 + g, 60 + g, 36, 255))
                    if cold[y, x] > 0.7:
                        d.polygon([(x, y - r * 2.3), (x - r * 0.4, y - r * 1.2), (x + r * 0.4, y - r * 1.2)], fill=(236, 244, 250, 230))
                else:
                    d.ellipse([x - r, y - r + 2, x + r, y + r + 2], fill=(10, 34, 18, 150))
                    d.ellipse([x - r, y - r, x + r, y + r], fill=(26 + g, 82 + int(rng.integers(0, 30)), 40, 255))
                    d.ellipse([x - r * 0.5, y - r * 0.7, x + r * 0.1, y - r * 0.1], fill=(90, 150, 80, 200))
        elif kind in ('mountain', 'snow', 'volcano', 'crater'):
            step = 9 if kind != 'snow' else 11
            where = m
            if kind == 'crater':
                cx, cy, rx, ry = shape
                where = m * (1 - cv.shape((cx, cy, rx * 0.7, ry * 0.7), 4))
            dn = dome / max(1e-6, dome.max())
            # Pedras soltas no pé das serras.
            for x, y in scatter(np.clip(blur(m, 8) - m, 0, 1) * 3 * land, 11, rng, 0.35):
                r = rng.uniform(1.2, 2.4)
                d.ellipse([x - r, y - r * 0.7, x + r, y + r * 0.7], fill=(120, 110, 96, 220))
            # Os picos: só nos topos das cristas (máximos locais da altura) e alguns soltos; o resto é a sombra do relevo.
            top = (height == ndimage.maximum_filter(height, size=24)) & (height > ndimage.minimum_filter(height, size=24) + 0.03) & (where > 0.5)
            pts = [(x, y) for y, x in zip(*np.nonzero(top))] + (scatter(where, 40, rng, 0.6) if kind != 'snow' else [])
            for x, y in sorted(pts, key=lambda q: q[1]):
                # Mais alto no meio da serra, menor na borda.
                h = rng.uniform(7, 11) + dn[y, x] * rng.uniform(8, 14)
                wdt = h * rng.uniform(0.8, 1.1)
                snowy = kind == 'snow' or kind == 'mountain' and (height[y, x] > 0.8 or rng.random() < 0.12)
                left, right = ((214, 226, 238, 255), (150, 168, 190, 255)) if kind == 'snow' else ((168, 146, 112, 255), (104, 84, 62, 255))
                if kind == 'volcano':
                    left, right = (120, 84, 70, 255), (76, 50, 44, 255)
                d.polygon([(x + 2, y - h + 2), (x + wdt + 3, y + 1), (x - wdt + 2, y + 1)], fill=(20, 16, 12, 70))
                d.polygon([(x, y - h), (x - wdt, y), (x, y)], fill=left)
                d.polygon([(x, y - h), (x + wdt, y), (x, y)], fill=right)
                # Uma fenda no meio da encosta (dá volume).
                d.line([(x, y - h), (x + wdt * 0.25, y - h * 0.45), (x + wdt * 0.1, y)], fill=tuple(int(c * 0.82) for c in right[:3]) + (200,), width=1)
                if snowy and kind != 'snow':
                    d.polygon([(x, y - h), (x - wdt * 0.35, y - h * 0.62), (x + wdt * 0.35, y - h * 0.62)], fill=(236, 242, 250, 255))
                elif kind == 'snow':
                    d.polygon([(x, y - h), (x - wdt * 0.4, y - h * 0.55), (x + wdt * 0.4, y - h * 0.55)], fill=(255, 255, 255, 255))
            if kind == 'volcano' and not isinstance(shape, np.ndarray):
                cx, cy, rx, ry = shape
                X, Y = cx * cv.w / 100, cy * cv.h / 100
                d.ellipse([X - rx * cv.w / 400, Y - ry * cv.h / 400, X + rx * cv.w / 400, Y + ry * cv.h / 400], fill=(240, 96, 40, 255), outline=(90, 30, 20, 255))
        elif kind == 'desert':
            for x, y in scatter(m, 11, rng, 0.5):
                w = rng.uniform(5, 9)
                d.arc([x - w, y - 3, x + w, y + 4], 200, 340, fill=(170, 130, 76, 220), width=2)
                d.arc([x - w + 1, y - 2, x + w - 1, y + 5], 210, 330, fill=(236, 214, 160, 160), width=1)
            for x, y in scatter(m, 26, rng, 0.6):
                if rng.random() < 0.5:
                    # Cacto ou pedra.
                    d.line([(x, y), (x, y - 6)], fill=(60, 110, 60, 255), width=2)
                    d.line([(x - 3, y - 4), (x - 3, y - 2), (x, y - 2)], fill=(60, 110, 60, 255), width=1)
                else:
                    d.ellipse([x - 3, y - 2, x + 3, y + 2], fill=(150, 116, 80, 230))
        elif kind == 'swamp':
            for x, y in scatter(m, 7, rng, 0.5):
                d.line([(x, y), (x - 1, y - 5)], fill=(40, 70, 40, 230), width=1)
                d.line([(x + 2, y), (x + 3, y - 4)], fill=(40, 70, 40, 230), width=1)
            for x, y in scatter(m, 18, rng, 0.6):
                w = rng.uniform(3, 6)
                d.ellipse([x - w, y - w * 0.5, x + w, y + w * 0.5], fill=(70, 130, 150, 200))
        elif kind == 'plain':
            for x, y in scatter(m, 9, rng, 0.5):
                d.ellipse([x - 1.5, y - 1.5, x + 1.5, y + 1.5], fill=(236, 220, 110, 200) if rng.random() < 0.4 else (150, 196, 100, 220))
    # Nos campos: arvoredos e moitas espalhados (longe da praia e dos outros biomas).
    open_land = (blur(land, 6) > 0.95) & (covered < 0.2)
    for x, y in scatter(open_land.astype(float), 22, rng, 0.5):
        if rng.random() < 0.55:
            for k in range(int(rng.integers(2, 5))):
                tx, ty, r = x + rng.uniform(-7, 7), y + rng.uniform(-5, 5), rng.uniform(2.4, 3.6)
                d.ellipse([tx - r, ty - r + 1.5, tx + r, ty + r + 1.5], fill=(16, 44, 22, 130))
                d.ellipse([tx - r, ty - r, tx + r, ty + r], fill=(40, 100, 48, 255))
        else:
            d.ellipse([x - 4, y - 2, x + 4, y + 2], fill=(110, 160, 80, 160))
    return np.asarray(out.convert('RGB'), dtype=float)


def story_cities():
    data = json.load(open(os.path.join(ROOT, 'assets', 'database', 'factory.json')))
    out = {}
    for g in data['bosses']:
        out.setdefault(g['region'], set()).update(l['city'] for l in g['leaders'] if l.get('city'))
    return out


def build(name, wanted):
    """(imagem, cidades em %) de um mapa."""
    if name in ART:
        return build_art(name)
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
    # Desenhado à mão (unidades de 150 × 100); com as máscaras da imagem de referência (tool/region_maps_masks.py),
    # a terra, as rotas e o relevo vêm delas.
    spec = HAND[name]
    if os.path.exists(os.path.join(REF_DIR, f'{name}-m-land.png')):
        cv = Canvas(spec.get('aspect', 1.5))
        mask = lambda kind: np.asarray(Image.open(os.path.join(REF_DIR, f'{name}-m-{kind}.png')).convert('L').resize((cv.w, cv.h), Image.BILINEAR), dtype=float) / 255  # noqa: E731
        land = mask('land')
        # As rotas: as linhas limpas de cidade a cidade (medidas na imagem); pelo mar, tracejadas.
        pc = lambda q: (q[0] / 1.5, q[1])  # noqa: E731
        cc = {c: pc(xy) for c, xy in spec['cities'].items()}
        lines_land, lines_sea = [], []
        for road in spec.get('roads', []):
            sea = road[0] == 'sea'
            pts = [cc[q] if isinstance(q, str) else pc(q) for q in (road[1:] if sea else road)]
            (lines_sea if sea else lines_land).append(pts)
        roads = cv.lines(lines_land, 5) > 0.5
        sea_roads = cv.lines(lines_sea, 5) > 0.5
        found = [(k, mask(k) * s) for k, s in (('mountain', 1.0), ('desert', 1.0), ('forest', 0.85))]
        # Sem relevo na imagem (um mapa só de linhas, como o de Johto): o relevo marcado à mão.
        flat = all(m.max() < 0.5 for _, m in found)
        hand = [(k, (sh[0] / 1.5, sh[1], sh[2] / 1.5, sh[3]) if isinstance(sh, tuple) and len(sh) == 4 and not isinstance(sh[0], tuple) else [(p[0] / 1.5, p[1]) for p in sh]) for k, sh in spec.get('biomes', [])]
        biomes = ([] if flat else found) + [(k, sh) for k, sh in hand if flat or k in ('snow', 'volcano', 'swamp', 'plain', 'crater')]
        cities = {c: (xy[0] / 1.5, xy[1]) for c, xy in spec['cities'].items()}
        img = paint(cv, land, np.zeros((cv.h, cv.w)), biomes, roads, np.zeros_like(roads), sea_roads, seed=3)
        return img, cities
    # A proporção da imagem de referência (Galar em pé, Paldea quadrado); as posições continuam em 150 × 100.
    cv = Canvas(spec.get('aspect', 1.5))
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


# Mapas desenhados que você mandou (tool/region_maps_art/<id>.webp): a imagem é usada inteira (com a moldura) e só
# as cidades são marcadas (em pixels da imagem original). Os nomes já vêm no desenho, então o app não escreve outros.
ART = {
    'sevii': {'crop': (0, 0, 1536, 1024), 'cities': {'One Island': (1210, 530), 'Two Island': (330, 430), 'Three Island': (720, 230), 'Four Island': (1270, 250), 'Five Island': (710, 480), 'Six Island': (770, 800), 'Seven Island': (1260, 790)}},
    'blueberry': {'crop': (0, 0, 1536, 1024), 'cities': {'Savanna Biome': (1285, 470), 'Coastal Biome': (260, 500), 'Canyon Biome': (1110, 740), 'Polar Biome': (360, 215), 'League Club Room': (770, 345)}},
    'orre': {'crop': (0, 0, 1536, 1024), 'cities': {'Gateon Port': (320, 450), 'Pyrite Town': (1200, 250), 'Agate Village': (640, 430), 'Phenac City': (250, 215), 'Cipher Lab': (770, 240), 'Desert Resort': (1060, 440), 'Realgam Tower': (1150, 640)}},
    'fiore': {'crop': (0, 0, 1536, 1024), 'cities': {'Ringtown': (380, 690), 'Fall City': (1140, 690), 'Summerland': (1055, 385), 'Wintown': (555, 375), 'Sekra Range': (390, 200), 'Fiore Temple': (800, 500)}},
    'almia': {'crop': (0, 0, 1536, 1024), 'cities': {'Vientown': (730, 645), 'Pueltown': (1270, 390), 'Chicole Village': (745, 400), 'Boyleland': (1040, 215), 'Haruba Village': (280, 500), 'Altru Building': (470, 175), 'Almia Castle': (1200, 800)}},
    'oblivia': {'crop': (0, 0, 1536, 1024), 'cities': {'Dolce Island': (300, 175), 'Renbow Island': (1180, 470), 'Mitonga Island': (440, 640), 'Layuda Island': (615, 215), 'Faldera Island': (1200, 200), 'Oblivia Ruins': (780, 440)}},
    'kitakami': {'crop': (0, 0, 1536, 1024), 'cities': {'Mossui Town': (720, 600), 'Apple Hills': (360, 330), 'Oni Mountain': (710, 190), 'Kitakami Hall': (1290, 560), 'Timeless Woods': (1190, 265), 'Crystal Pool': (945, 410)}},
    'johto': {'crop': (0, 0, 1536, 1024), 'cities': {
        'Azalea Town': (172, 495), 'Cherrygrove City': (290, 635), 'New Bark Town': (598, 642), 'Ecruteak City': (578, 462),
        'Goldenrod City': (628, 340), 'Mahogany Town': (898, 332), 'Olivine City': (1120, 328), 'Violet City': (995, 512),
        'Cianwood City': (1420, 668), 'Blackthorn City': (1415, 478)}},
    'hoenn': {'crop': (0, 0, 1536, 1024), 'cities': {
        'Mauville City': (620, 290), 'Fortree City': (1000, 250), 'Petalburg City': (760, 395), 'Lavaridge Town': (150, 440),
        'Pacifidlog Town': (190, 650), 'Lilycove City': (1150, 375), 'Sootopolis City': (1160, 455), 'Mossdeep City': (1095, 765),
        'Ever Grande City': (1400, 215), 'Rustboro City': (500, 390), 'Slateport City': (495, 700), 'Verdanturf Town': (320, 540),
        'Fallarbor Town': (430, 250), 'Oldale Town': (610, 135), 'Littleroot Town': (205, 855), 'Dewford Town': (735, 830),
        'Battle Frontier': (1430, 470)}},
    'alola': {'crop': (0, 0, 1536, 1024), 'cities': {'Iki Town': (160, 300), "Hau'oli City": (330, 350), 'Verdant Cavern': (410, 215), 'Heahea City': (1010, 290), 'Paniola Town': (1170, 310), 'Konikoni City': (1135, 375), 'Brooklet Hill': (1385, 435), 'Lush Jungle': (1345, 280), 'Wela Volcano Park': (1220, 215), 'Ruins of Life': (1360, 345), 'Aether Paradise': (760, 430), 'Seafolk Village': (165, 690), 'Vast Poni Canyon': (410, 690), 'Malie City': (965, 660), 'Po Town': (955, 790), 'Mount Lanakila': (1210, 650), 'Hokulani Observatory': (1370, 735), 'Tapu Village': (1325, 850)}},
    'paldea': {'crop': (0, 0, 1536, 1024), 'cities': {
        'Medali': (360, 225), 'Cascarrafa': (470, 548), 'Mesagoza': (770, 580), 'Levincia': (1180, 625),
        'Artazon': (1240, 405), 'Los Platos': (230, 705), 'Montenevera': (690, 175), 'Glaseado': (900, 232),
        'Zapapico': (1150, 230), 'Porto Marinada': (150, 320), 'Pokémon League': (495, 325), 'Cabo Poco': (775, 800),
        'Cortondo': (450, 770), 'Alfornada': (1380, 690)}},
    'kanto': {'crop': (0, 0, 1536, 1024), 'cities': {'Pewter City': (305, 270), 'Viridian City': (400, 440), 'Pallet Town': (400, 790), 'Cerulean City': (1110, 250), 'Saffron City': (900, 430), 'Fuchsia City': (940, 670), 'Cinnabar Island': (1285, 735), 'Celadon City': (535, 375), 'Lavender Town': (1215, 505), 'Vermilion City': (985, 745), 'Indigo Plateau': (300, 640), 'Seafoam Islands': (720, 880)}},
    'sinnoh': {'crop': (0, 0, 1536, 1024), 'cities': {
        'Snowpoint City': (700, 165), 'Veilstone City': (1000, 240), 'Pokémon League': (1225, 232), 'Pastoria City': (1250, 372),
        'Oreburgh City': (612, 405), 'Eterna City': (372, 545), 'Jubilife City': (870, 585), 'Canalave City': (1390, 662),
        'Twinleaf Town': (320, 758), 'Hearthome City': (965, 822), 'Sunyshore City': (1210, 792), 'Sandgem Town': (612, 790),
        'Celestic Town': (592, 650), 'Solaceon Town': (1060, 690), 'Floaroma Town': (225, 600), 'Survival Area': (250, 180),
        'Fight Area': (345, 330), 'Resort Area': (1345, 405)}},
    'unova': {'crop': (0, 0, 1536, 1024), 'cities': {
        'Nuvema Town': (385, 190), 'Nacrene City': (740, 228), 'Icirrus City': (1190, 208), 'Opelucid City': (1395, 300),
        'Castelia City': (785, 435), 'Striaton City': (150, 458), 'Nimbasa City': (385, 695), 'Undella Town': (795, 790),
        'Driftveil City': (1262, 740), 'Pokémon League': (165, 205), 'Accumula Town': (475, 490), 'Lacunosa Town': (1090, 90),
        'Humilau City': (1342, 598), 'Lentimas Town': (920, 110), 'Black City': (770, 560), 'Aspertia City': (140, 745),
        'Floccesy Town': (420, 545), 'Virbank City': (480, 790), 'Pokéstar Studios': (548, 900), 'Mistralton City': (1040, 505)}},
    'kalos': {'crop': (0, 0, 1536, 1024), 'cities': {
        'Anistar City': (215, 388), 'Geosenge Town': (465, 455), 'Cyllage City': (300, 565), 'Ambrette Town': (462, 540),
        'Coumarine City': (350, 738), 'Lumiose City': (790, 350), 'Santalune City': (640, 548), 'Camphrier Town': (950, 705),
        'Vaniville Town': (630, 825), 'Aquacorde Town': (995, 795), 'Dendemille Town': (1240, 548), 'Snowbelle City': (1300, 430),
        'Laverre City': (1110, 420), 'Shalour City': (150, 478), 'Couriway Town': (1392, 468), 'Pokémon League': (1000, 250),
        'Kiloude City': (500, 282)}},
    'galar': {'crop': (0, 0, 1214, 1296), 'cities': {
        'Wyndon': (610, 235), 'Hammerlocke': (300, 318), 'Motostoke': (905, 355), 'Stow-on-Side': (305, 585),
        'Ballonlea': (905, 645), 'Spikemuth': (590, 640), 'Turffield': (665, 1128), 'Postwick': (640, 1170),
        'Wedgehurst': (795, 935), 'Hulbury': (775, 578), 'Circhester': (630, 465)}},
    'hisui': {'crop': (0, 0, 1536, 1024), 'cities': {
        'Jubilife Village': (395, 570), 'Alabaster Icelands': (462, 210), 'Coronet Highlands': (890, 260), 'Crimson Mirelands': (1040, 540),
        'Obsidian Fieldlands': (1245, 600), 'Cobalt Coastlands': (1175, 200), 'Temple of Sinnoh': (930, 745)}},
}
ART_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'region_maps_art')


def build_art(name):
    spec = ART[name]
    x0, y0, x1, y1 = spec['crop']
    img = Image.open(os.path.join(ART_DIR, f'{name}.webp')).convert('RGB').crop((x0, y0, x1, y1))
    cities = {c: ((x - x0) / (x1 - x0) * 100, (y - y0) / (y1 - y0) * 100) for c, (x, y) in spec['cities'].items()}
    return img, cities


def write_positions(found):
    data = {region: [{'id': m, 'cities': {c: [round(x, 2), round(y, 2)] for c, (x, y) in found[m].items()}} for m in maps] for region, maps in REGIONS.items()}
    js = ('// Gerado por tool/region_maps.py (não editar à mão): os mapas de cada região (como o Town Map dos jogos) e onde\n'
          '// fica cada cidade neles (em % da largura e da altura da imagem sprites/maps/<id>.webp). Igual ao app.\n\n'
          f'export const REGION_MAPS = {json.dumps(data, ensure_ascii=False)}\n\n'
          '/** A proporção (largura / altura) de cada imagem. */\n'
          f'export const MAP_ASPECT = {json.dumps({m: round(ASPECTS[m], 4) for m in found})}\n\n'
          '/** Os mapas desenhados (os nomes das cidades já estão na imagem). */\n'
          f'export const MAP_ART = {json.dumps(sorted(m for m in found if m in ART))}\n\n'
          '/** O mapa da região que tem a cidade de agora (Johto também mostra Kanto) e as cidades da história nele. */\n'
          'export function regionMap(region, cities, current) {\n'
          '  const maps = REGION_MAPS[region]\n'
          '  if (!maps) return null\n'
          '  const map = maps.find((m) => current && m.cities[current]) ?? maps[0]\n'
          '  return { id: map.id, aspect: MAP_ASPECT[map.id] ?? 1.5, art: MAP_ART.includes(map.id), spots: cities.map((c, i) => ({ ...c, i, xy: map.cities[c.city] })).filter((c) => c.xy) }\n'
          '}\n')
    open(os.path.join(ROOT, 'web-site', 'src', 'lib', 'regionMaps.js'), 'w').write(js)
    q = lambda s: "'" + s.replace("'", "\\'") + "'"  # noqa: E731
    lines = ['// lib/screens/region_maps.dart', '//',
             '// Gerado por tool/region_maps.py (não editar à mão): os mapas de cada região (como o Town Map dos jogos) e onde fica',
             '// cada cidade neles (em % da largura e da altura da imagem assets/database/sprites/maps/<id>.webp). Igual ao site.', '',
             'typedef RegionMapInfo = ({String id, double aspect, bool art, Map<String, List<double>> cities});', '',
             'const regionMaps = <String, List<RegionMapInfo>>{']
    for region, maps in data.items():
        lines.append(f'  {q(region)}: [')
        for m in maps:
            cities = ', '.join(f'{q(c)}: [{float(x)}, {float(y)}]' for c, (x, y) in m['cities'].items())
            lines.append(f"    (id: {q(m['id'])}, aspect: {round(ASPECTS[m['id']], 4)}, art: {'true' if m['id'] in ART else 'false'}, cities: <String, List<double>>{{{cities}}}),")
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
            cities = build_art(name)[1] if name in ART else build(name, wanted)[1] if name in REF and name not in HAND else {c: (xy[0] / 1.5, xy[1]) for c, xy in HAND[name]['cities'].items()}
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
