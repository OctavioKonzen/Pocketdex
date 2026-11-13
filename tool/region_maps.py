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
    # Paldea: pelo mapa que você mandou (Mesagoza no centro-sul, o lago no noroeste, os rios, Cabo Poco no sul).
    'paldea': {
        'aspect': 1.0,
        'cities': {'Porto Marinada': (14.6, 49.1), 'Cascarrafa': (44.3, 52.5), 'Medali': (59.9, 45.8), 'Montenevera': (81.9, 28.6), 'Zapapico': (94.2, 53.7), 'Levincia': (124.8, 57.6), 'Pokémon League': (58.0, 67.3), 'Mesagoza': (71.7, 76.2), 'Cortondo': (42.5, 76.3), 'Artazon': (111.9, 74.4), 'Alfornada': (25.5, 88.4), 'Los Platos': (71.7, 87.3), 'Cabo Poco': (71.7, 95.1), 'Glaseado': (77.6, 19.7)},
        'land': [(15.5, 22.3), (32.6, 15.0), (48.1, 17.1), (62.1, 12.4), (76.1, 14.0), (100.9, 15.5), (108.7, 23.8), (121.1, 24.3), (127.3, 29.0), (133.5, 36.2), (140.5, 45.5), (132.0, 54.3), (130.4, 61.1), (133.5, 67.8), (128.9, 75.6), (116.5, 80.7), (111.0, 88.0), (100.9, 89.5), (89.3, 91.6), (77.6, 92.7), (74.5, 96.3), (68.3, 96.3), (66.8, 93.2), (54.3, 92.7), (43.5, 91.1), (25.6, 93.7), (17.9, 91.1), (15.5, 83.9), (10.9, 75.6), (7.8, 64.7), (10.9, 54.3), (15.5, 48.7), (16.3, 41.4), (15.5, 31.1)],
        'islands': [(5.4, 43.0, 1.6, 2.1), (111.8, 22.0, 2.3, 0.9), (139.8, 64.2, 1.9, 1.3), (10.1, 38.8, 1.1, 0.7)],
        'water': [[(22.5, 25.4), (37.3, 23.3), (49.7, 24.3), (55.9, 29.0), (60.6, 33.6), (54.3, 36.2), (45.0, 37.3), (32.6, 39.3), (23.3, 39.3), (21.0, 36.2)], (67.5, 14.5, 3.1, 2.1)],
        'biomes': [('snow', [(62.1, 13.5), (100.9, 15.5), (97.0, 32.1), (77.6, 33.1), (63.7, 29.0)]), ('desert', (38.8, 54.9, 10.9, 6.2)), ('crater', (83.9, 45.5, 14.8, 7.8)), ('forest', (102.5, 45.5, 7.0, 4.1)), ('forest', (112.6, 73.5, 9.3, 4.1)), ('mountain', (124.2, 36.2, 8.5, 6.2)), ('swamp', (97.0, 87.5, 6.2, 2.6)), ('plain', (46.6, 80.2, 11.6, 4.7)), ('forest', (29.5, 67.3, 7.0, 3.6)), ('mountain', (23.3, 31.1, 4.7, 4.1)), ('forest', (116.5, 56.9, 4.7, 2.6)), ('plain', (85.4, 85.4, 9.3, 3.1)), ('mountain', (59.0, 36.2, 5.4, 2.6))],
        'rivers': [[(16.3, 41.4), (43.5, 41.9), (54.3, 38.3), (69.9, 35.2), (73.0, 29.0), (77.6, 26.9)], [(101.7, 16.6), (91.6, 20.7), (89.3, 30.5)], [(93.2, 39.9), (108.7, 43.0), (121.1, 45.0), (140.5, 46.1)], [(90.8, 59.0), (100.9, 56.4), (119.6, 56.4), (125.0, 57.5)], [(100.9, 56.9), (107.1, 64.7), (116.5, 67.8), (128.9, 63.7)], [(17.1, 64.2), (31.1, 67.3), (54.3, 68.8), (63.7, 73.5), (66.8, 75.1)], [(29.5, 68.3), (34.9, 77.6), (46.6, 82.3), (60.6, 81.8)], [(83.1, 78.7), (96.3, 82.8), (108.7, 85.9)]],
        'roads': [['Cabo Poco', 'Los Platos'], ['Los Platos', 'Mesagoza'], ['Mesagoza', 'Pokémon League'], ['Mesagoza', (54.3, 77.6), 'Cortondo'], ['Cortondo', (32.6, 83.9), 'Alfornada'], ['Cortondo', (41.9, 62.1), 'Cascarrafa'], ['Cascarrafa', 'Porto Marinada'], ['Cascarrafa', 'Medali'], ['Medali', (69.9, 36.2), 'Montenevera'], ['Montenevera', 'Glaseado'], ['Montenevera', (89.3, 41.4), 'Zapapico'], ['Zapapico', 'Levincia'], ['Levincia', (116.5, 67.3), 'Artazon'], ['Artazon', (93.2, 75.6), 'Mesagoza'], ['Pokémon League', 'Medali']],
    },
    # Galar: pelo mapa que você mandou (Postwick no sul, a Wild Area no meio, Wyndon no norte, as montanhas de neve).
    'galar': {
        'aspect': 0.707,
        'cities': {'Postwick': (73.4, 91.0), 'Wedgehurst': (73.4, 84.2), 'Motostoke': (66.6, 54.2), 'Turffield': (55.7, 45.8), 'Hulbury': (83.0, 45.8), 'Hammerlocke': (77.9, 36.9), 'Stow-on-Side': (50.9, 36.9), 'Ballonlea': (50.9, 32.2), 'Circhester': (103.3, 30.3), 'Spikemuth': (114.9, 36.9), 'Wyndon': (77.9, 17.1)},
        'land': [(19.3, 9.1), (48.3, 6.1), (83.7, 4.6), (122.3, 7.6), (138.4, 13.7), (141.6, 22.8), (135.2, 34.9), (141.6, 45.5), (128.8, 57.7), (122.3, 69.8), (106.2, 81.9), (96.6, 91.0), (83.7, 97.1), (57.9, 97.1), (38.6, 91.0), (25.8, 78.9), (19.3, 65.3), (22.5, 53.1), (19.3, 44.0), (16.1, 34.9), (19.3, 22.8)],
        'islands': [(130.4, 28.8, 3.9, 1.2), (12.9, 63.7, 4.5, 1.5)],
        'water': [(80.5, 60.7, 8.4, 2.7), (96.6, 68.3, 6.4, 2.1), (96.6, 85.0, 5.2, 1.5)],
        'biomes': [('snow', [(29.0, 19.7), (64.4, 16.7), (122.3, 18.2), (128.8, 30.3), (96.6, 32.6), (64.4, 28.8), (38.6, 30.3)]), ('forest', (38.6, 32.6, 9.7, 3.9)), ('desert', (53.1, 40.2, 9.0, 2.7)), ('plain', (72.4, 66.8, 19.3, 9.1)), ('mountain', (106.2, 50.1, 12.9, 6.1)), ('forest', (35.4, 50.1, 9.7, 6.1)), ('mountain', (32.2, 68.3, 8.0, 4.6)), ('forest', (90.1, 91.0, 9.7, 3.8)), ('mountain', (112.7, 68.3, 9.7, 6.1)), ('plain', (64.4, 85.0, 9.7, 3.0))],
        'rivers': [[(80.5, 45.5), (77.3, 53.1), (80.5, 60.7)], [(103.0, 37.9), (106.2, 45.5), (99.8, 54.6)]],
        'roads': [['Postwick', 'Wedgehurst'], ['Wedgehurst', (67.6, 75.9), (67.6, 63.7), 'Motostoke'], ['Wedgehurst', (93.3, 81.9), (93.3, 78.6)], ['Motostoke', (55.7, 52.4), 'Turffield'], ['Motostoke', (83.0, 52.4), 'Hulbury'], ['Motostoke', (77.9, 48.6), 'Hammerlocke'], ['Hammerlocke', 'Stow-on-Side'], ['Stow-on-Side', 'Ballonlea'], ['Hammerlocke', 'Wyndon'], ['Hammerlocke', 'Spikemuth'], ['Circhester', (103.3, 36.9)]],
    },
    # Alola: pelo mapa que você mandou (Melemele, Akala, Ula'ula e Poni, e a Aether Paradise no meio do mar).
    'alola': {
        'aspect': 1.667,
        'cities': {'Iki Town': (49.3, 20.5), "Hau'oli City": (43.4, 28.5), 'Verdant Cavern': (55.7, 26.5), 'Paniola Town': (94.0, 29.3), 'Heahea City': (87.6, 36.3), 'Konikoni City': (84.4, 42.4), 'Brooklet Hill': (98.5, 19.9), 'Lush Jungle': (104.5, 15.5), 'Wela Volcano Park': (102.5, 32.1), 'Ruins of Life': (92.6, 46.5), 'Po Town': (117.9, 53.7), 'Malie City': (130.6, 63.1), 'Mount Lanakila': (123.4, 60.3), 'Hokulani Observatory': (138.4, 70.8), 'Tapu Village': (124.8, 81.2), 'Seafolk Village': (14.4, 54.3), 'Vast Poni Canyon': (23.9, 42.0), 'Aether Paradise': (59.5, 61.2)},
        'land': [],
        'islands': [[(34.8, 13.8), (39.8, 12.7), (44.8, 12.2), (50.8, 10.0), (55.7, 12.2), (59.7, 10.5), (62.2, 13.8), (60.7, 21.0), (63.2, 22.7), (64.7, 26.5), (69.7, 27.7), (71.2, 33.2), (69.7, 38.7), (63.7, 39.8), (55.7, 38.7), (52.8, 33.2), (48.8, 32.1), (47.8, 35.4), (44.8, 36.0), (44.8, 32.1), (41.8, 32.1), (38.3, 31.0), (37.8, 26.5), (36.8, 19.9)], [(91.1, 13.3), (95.6, 8.8), (103.5, 10.0), (107.0, 15.5), (110.5, 15.5), (111.5, 21.0), (107.5, 24.3), (108.5, 35.4), (111.0, 38.7), (107.5, 43.1), (102.5, 42.0), (99.5, 38.2), (100.5, 34.3), (93.6, 36.5), (89.6, 37.6), (86.6, 39.8), (85.6, 44.2), (88.6, 48.7), (95.6, 48.7), (96.1, 45.4), (92.6, 42.6), (87.6, 38.7), (86.6, 33.2), (89.6, 29.3), (88.6, 23.8), (90.6, 18.8)], [(114.5, 51.4), (117.5, 49.2), (120.4, 53.1), (129.4, 54.4), (130.4, 59.7), (134.4, 63.6), (138.9, 64.2), (142.3, 71.9), (142.3, 78.5), (135.4, 80.8), (128.4, 83.0), (127.4, 87.4), (121.4, 87.4), (115.5, 85.2), (113.5, 77.4), (114.5, 70.8), (115.5, 64.2), (117.0, 58.6)], [(12.9, 44.2), (17.9, 35.4), (20.9, 33.2), (25.9, 35.4), (31.9, 37.6), (32.8, 44.2), (30.9, 50.9), (26.9, 54.2), (19.9, 54.2), (14.9, 55.3), (11.9, 52.0), (12.4, 46.5)], (59.5, 60.8, 3.0, 2.4), (5.5, 52.0, 2.2, 1.7), (129.9, 14.2, 1.4, 1.3), (109.5, 19.4, 1.5, 2.2), (137.9, 63.9, 1.0, 0.9)],
        'water': [],
        'biomes': [('volcano', (102.5, 31.0, 4.0, 3.9)), ('snow', (123.4, 59.7, 6.0, 4.4)), ('forest', (104.5, 15.5, 4.0, 3.9)), ('mountain', (23.9, 42.0, 6.0, 5.5)), ('desert', (117.5, 76.3, 3.0, 3.3)), ('forest', (52.8, 19.9, 4.0, 3.3)), ('plain', (93.6, 25.4, 4.0, 3.3)), ('mountain', (138.4, 71.9, 2.5, 2.8)), ('swamp', (129.4, 77.4, 3.0, 2.2)), ('forest', (21.9, 48.7, 4.0, 2.8)), ('mountain', (46.8, 16.6, 3.0, 2.2))],
        'rivers': [],
        'roads': [['Iki Town', "Hau'oli City"], ['Iki Town', (55.7, 22.1), 'Verdant Cavern'], ['Verdant Cavern', (63.7, 33.2)], ['Heahea City', 'Paniola Town'], ['Paniola Town', 'Brooklet Hill'], ['Brooklet Hill', 'Lush Jungle'], ['Paniola Town', 'Wela Volcano Park'], ['Wela Volcano Park', (103.5, 38.7), 'Konikoni City'], ['Konikoni City', 'Ruins of Life'], ['Malie City', 'Mount Lanakila'], ['Malie City', 'Hokulani Observatory'], ['Malie City', (121.4, 57.5), 'Po Town'], ['Malie City', (128.4, 71.9), 'Tapu Village'], ['Seafolk Village', 'Vast Poni Canyon'], ['sea', "Hau'oli City", (64.7, 35.4), (83.6, 36.5), 'Heahea City'], ['sea', 'Konikoni City', (99.5, 53.1), (119.4, 64.2), 'Malie City'], ['sea', 'Tapu Village', (79.6, 77.4), (29.9, 57.5), 'Seafolk Village'], ['sea', "Hau'oli City", (55.7, 47.6), 'Aether Paradise']],
    },
    # Kalos: pelo mapa que você mandou (Lumiose no centro, a costa a oeste com Shalour, Cyllage e Ambrette).
    'kalos': {
        'aspect': 1.525,
        'cities': {'Laverre City': (77.4, 11.9), 'Coumarine City': (51.6, 29.6), 'Shalour City': (22.3, 35.4), 'Geosenge Town': (14.1, 47.0), 'Cyllage City': (25.8, 57.2), 'Ambrette Town': (33.4, 75.1), 'Camphrier Town': (61.7, 57.5), 'Lumiose City': (76.9, 36.7), 'Dendemille Town': (102.4, 29.8), 'Anistar City': (131.2, 38.1), 'Couriway Town': (139.4, 45.6), 'Snowbelle City': (126.9, 55.2), 'Pokémon League': (109.8, 43.4), 'Santalune City': (92.4, 56.6), 'Aquacorde Town': (99.2, 74.0), 'Vaniville Town': (99.2, 85.1), 'Kiloude City': (111.4, 92.0)},
        'land': [(0.0, 0.0), (150.0, 0.0), (150.0, 100.0), (0.0, 100.0)],
        'islands': [(46.2, 11.0, 2.2, 1.7), (27.2, 16.6, 1.9, 1.4)],
        'water': [[(0.0, 0.0), (40.8, 0.0), (38.0, 11.0), (32.6, 19.3), (40.8, 22.1), (43.5, 27.6), (35.3, 30.9), (27.2, 29.8), (19.0, 32.6), (10.9, 38.7), (8.2, 44.2), (9.8, 55.2), (19.0, 61.9), (27.2, 68.0), (28.3, 82.9), (21.7, 100.0), (0.0, 100.0)], [(40.8, 0.0), (67.9, 0.0), (62.5, 8.3), (54.3, 16.6), (48.9, 16.6), (43.5, 11.0)], [(141.3, 80.1), (150.0, 74.6), (150.0, 100.0), (135.9, 100.0)]],
        'biomes': [('snow', (126.9, 58.0, 10.9, 8.3)), ('snow', (102.4, 26.2, 8.2, 5.5)), ('mountain', (109.8, 48.3, 6.0, 4.4)), ('forest', (89.7, 66.3, 6.5, 5.0)), ('forest', (119.6, 69.1, 8.2, 6.1)), ('mountain', (14.1, 52.5, 4.3, 3.9)), ('mountain', (40.8, 69.1, 4.9, 3.9)), ('desert', (62.5, 38.7, 6.0, 4.4)), ('mountain', (135.9, 30.4, 4.3, 3.9)), ('forest', (81.5, 22.1, 5.4, 4.4))],
        'rivers': [[(65.2, 27.6), (71.2, 47.0), (68.5, 69.1), (63.0, 93.9)], [(127.7, 66.3), (135.9, 77.3), (144.0, 82.9)]],
        'roads': [['Shalour City', (38.0, 30.4), 'Coumarine City'], ['Coumarine City', 'Lumiose City'], ['Lumiose City', 'Laverre City'], ['Laverre City', 'Dendemille Town'], ['Lumiose City', 'Dendemille Town'], ['Dendemille Town', 'Anistar City'], ['Anistar City', 'Couriway Town'], ['Couriway Town', 'Snowbelle City'], ['Santalune City', (109.8, 55.2), 'Snowbelle City'], ['Pokémon League', (109.8, 55.2)], ['Lumiose City', 'Santalune City'], ['Santalune City', (99.2, 64.1), 'Aquacorde Town'], ['Aquacorde Town', 'Vaniville Town'], ['Lumiose City', 'Camphrier Town'], ['Camphrier Town', 'Cyllage City'], [(43.5, 44.2), 'Camphrier Town'], ['Shalour City', (19.0, 40.1), 'Geosenge Town'], ['Geosenge Town', 'Cyllage City'], ['Cyllage City', (27.2, 66.3), 'Ambrette Town'], ['Ambrette Town', (54.3, 75.1)]],
    },
    # Unova: pelo mapa do Black 2/White 2 que você mandou (Castelia na baía do sul, o rio que desce do norte, Nuvema no sudeste).
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
        'biomes': [('snow', [(33.1, 0.0), (66.3, 0.0), (68.5, 26.5), (46.4, 28.4), (33.1, 24.6)]), ('mountain', [(55.2, 16.1), (63.0, 19.9), (69.6, 39.8), (67.4, 60.6), (63.0, 66.3), (58.5, 56.8), (57.4, 30.3)]), ('forest', (36.5, 54.9, 5.5, 4.7)), ('swamp', (97.2, 81.4, 5.5, 3.8)), ('mountain', (139.7, 53.0, 3.3, 4.7)), ('forest', (83.9, 53.0, 4.4, 2.8)), ('snow', [(95.0, 0.9), (117.1, 0.0), (119.3, 11.4), (99.4, 11.4)])],
        'rivers': [],
        'roads': [['Snowpoint City', (47.2, 4.3), (47.2, 29.4), (61.9, 29.4), (61.9, 45.8)], ['Eterna City', 'Celestic Town'], ['Celestic Town', (86.2, 45.8), (86.2, 54.5), 'Veilstone City'], [(86.2, 54.5), 'Solaceon Town'], ['Solaceon Town', (86.2, 70.1), 'Hearthome City'], ['Eterna City', (47.2, 71.0), 'Hearthome City'], [(47.2, 71.0), 'Oreburgh City'], ['Eterna City', (32.0, 45.8), (27.6, 53.0), 'Floaroma Town'], ['Floaroma Town', 'Jubilife City'], ['Jubilife City', 'Canalave City'], ['Jubilife City', 'Oreburgh City'], ['Jubilife City', 'Sandgem Town'], ['Sandgem Town', (11.0, 87.6), (11.0, 83.3)], ['Twinleaf Town', (18.0, 87.6)], ['sea', 'Sandgem Town', (27.6, 96.1), (46.4, 96.1)], ['Hearthome City', (71.8, 87.6), 'Pastoria City'], ['Veilstone City', (109.9, 73.9), (106.0, 83.3), 'Pastoria City'], [(109.9, 78.6), 'Sunyshore City'], ['sea', 'Sunyshore City', (129.8, 66.3), 'Pokémon League'], ['Pokémon League', (139.7, 49.2), (139.7, 2.8)], ['Fight Area', (95.5, 33.3), (95.5, 20.8), 'Survival Area'], ['Survival Area', (115.4, 20.8), (115.4, 7.6)], ['Survival Area', (117.1, 20.8), (120.4, 30.3), 'Resort Area'], ['sea', 'Fight Area', (122.6, 33.3), 'Resort Area']],
    },
    # Hoenn: pelo mapa que você mandou (o continente a oeste, as ilhas de Mossdeep, Sootopolis, Ever Grande e Pacifidlog a leste).
    'hoenn': {
        'aspect': 1.524,
        'cities': {'Fallarbor Town': (28.1, 14.3), 'Lavaridge Town': (36.9, 31.0), 'Rustboro City': (12.9, 47.6), 'Verdanturf Town': (28.1, 47.6), 'Mauville City': (51.6, 47.6), 'Petalburg City': (23.4, 63.1), 'Oldale Town': (35.2, 63.1), 'Littleroot Town': (35.2, 75.0), 'Slateport City': (51.6, 75.0), 'Dewford Town': (23.4, 90.5), 'Fortree City': (76.2, 14.3), 'Lilycove City': (87.9, 25.0), 'Mossdeep City': (123.0, 37.5), 'Sootopolis City': (108.4, 53.6), 'Ever Grande City': (135.9, 57.1), 'Pacifidlog Town': (90.8, 73.8)},
        'land': [(4.7, 8.3), (41.0, 3.6), (82.0, 3.6), (96.7, 14.3), (97.3, 31.0), (82.0, 39.3), (70.3, 54.8), (60.9, 66.7), (60.9, 82.1), (49.2, 88.1), (30.5, 82.1), (14.1, 78.6), (4.7, 59.5), (2.3, 29.8)],
        'islands': [(123.0, 37.5, 11.7, 7.7), (108.4, 53.6, 8.2, 7.1), (135.9, 57.1, 5.9, 10.7), (90.8, 73.8, 4.7, 3.6), (23.4, 90.5, 7.0, 4.8), (104.3, 83.3, 4.1, 2.4), (72.7, 82.1, 2.9, 1.8), (117.2, 17.9, 4.7, 3.0)],
        'water': [(108.4, 53.6, 3.5, 3.0)],
        'biomes': [('volcano', (35.2, 23.8, 7.0, 6.0)), ('mountain', (23.4, 17.9, 8.2, 6.0)), ('desert', (51.6, 23.8, 5.3, 5.4)), ('forest', (17.6, 56.5, 4.7, 4.8)), ('forest', (67.4, 23.8, 5.9, 10.7)), ('forest', (82.0, 17.9, 4.7, 3.6)), ('mountain', (108.4, 53.6, 8.2, 7.1)), ('mountain', (135.9, 52.4, 3.5, 4.8)), ('mountain', (8.2, 35.7, 4.7, 6.0)), ('forest', (41.0, 54.8, 5.9, 3.6))],
        'rivers': [[(67.4, 17.9), (69.1, 35.7), (65.6, 47.6)]],
        'roads': [['Rustboro City', (12.9, 14.3), 'Fallarbor Town'], ['Fallarbor Town', (51.6, 14.3), (51.6, 31.0)], ['Lavaridge Town', (51.6, 31.0)], [(51.6, 31.0), 'Mauville City'], ['Rustboro City', 'Verdanturf Town'], ['Verdanturf Town', 'Mauville City'], ['Rustboro City', (12.9, 63.1), 'Petalburg City'], ['Petalburg City', 'Oldale Town'], ['Oldale Town', 'Littleroot Town'], ['Mauville City', (51.6, 63.1), 'Slateport City'], ['Oldale Town', (51.6, 63.1)], ['Mauville City', (64.5, 47.6), (76.2, 47.6), 'Fortree City'], ['Fortree City', (87.9, 14.3), 'Lilycove City'], ['sea', 'Lilycove City', (111.3, 28.6), 'Mossdeep City'], ['sea', 'Mossdeep City', (117.2, 47.6), 'Sootopolis City'], ['sea', 'Sootopolis City', (126.0, 59.5), 'Ever Grande City'], ['sea', 'Slateport City', (70.3, 81.0), 'Pacifidlog Town'], ['sea', 'Pacifidlog Town', (99.6, 65.5), 'Sootopolis City'], ['sea', 'Petalburg City', (10.5, 71.4), (10.5, 89.3), 'Dewford Town'], ['sea', 'Dewford Town', (41.0, 90.5), 'Slateport City']],
    },
    # Johto: pelo mapa que você mandou (Cianwood na ilha a oeste, o Lake of Rage ao norte de Mahogany, a Liga a leste).
    'johto': {
        'aspect': 1.428,
        'cities': {'Cianwood City': (16.9, 64.7), 'Olivine City': (34.3, 48.1), 'Ecruteak City': (58.7, 28.6), 'Mahogany Town': (79.2, 28.6), 'Blackthorn City': (102.0, 28.6), 'Violet City': (71.9, 46.0), 'Goldenrod City': (49.2, 65.0), 'Azalea Town': (57.6, 83.7), 'Cherrygrove City': (85.7, 68.2), 'New Bark Town': (106.5, 68.4), 'Indigo Plateau': (135.7, 15.8)},
        'land': [(0, 0), (150, 0), (150, 100), (0, 100)],
        'islands': [(12.6, 64.7, 13.5, 13.4)],
        'water': [[(0.0, 45.5), (26.7, 45.5), (29.5, 50.3), (36.0, 50.8), (39.3, 61.5), (39.3, 74.9), (42.1, 88.2), (56.2, 91.4), (68.8, 88.8), (74.7, 80.2), (74.7, 63.6), (82.0, 64.7), (92.7, 67.4), (112.4, 65.8), (123.6, 65.8), (134.8, 58.3), (150.0, 53.5), (150.0, 100.0), (0.0, 100.0)], (79.5, 8.0, 6.2, 3.7)],
        'biomes': [('mountain', (68.8, 22.7, 6.2, 3.7)), ('snow', (103.9, 20.1, 5.6, 3.7)), ('mountain', [(120.8, 5.3), (150.0, 0.0), (150.0, 45.5), (123.6, 42.8)]), ('forest', (44.9, 78.9, 5.1, 5.9)), ('forest', (61.8, 37.4, 4.5, 3.2)), ('mountain', (92.7, 50.8, 4.5, 3.7)), ('mountain', (66.0, 80.2, 3.9, 3.2)), ('forest', (19.7, 32.1, 8.4, 5.3)), ('forest', (92.7, 16.0, 5.1, 3.2))],
        'rivers': [],
        'roads': [['Cianwood City', (3.7, 69.5), (3.7, 55.3)], ['sea', 'Cianwood City', (30.3, 64.7), (30.3, 50.8), 'Olivine City'], ['Olivine City', (34.3, 28.6), 'Ecruteak City'], ['Ecruteak City', 'Mahogany Town'], ['Mahogany Town', 'Blackthorn City'], ['Mahogany Town', (79.2, 10.7)], ['Ecruteak City', (58.7, 46.0), 'Violet City'], ['Goldenrod City', (49.2, 46.0), (58.7, 46.0)], ['Violet City', (85.7, 46.0), 'Cherrygrove City'], ['Goldenrod City', (49.2, 83.7), 'Azalea Town'], ['Azalea Town', (71.9, 83.7), 'Violet City'], ['Cherrygrove City', 'New Bark Town'], ['New Bark Town', (118.5, 68.4), (118.5, 49.5), (150.0, 49.5)], ['Indigo Plateau', (134.8, 68.4)], ['Blackthorn City', (102.0, 56.1), (95.5, 56.1), (95.5, 68.2)]],
    },
    # Kanto: pelo mapa do HeartGold/SoulSilver que você mandou (Mt. Silver e as montanhas no noroeste, a enseada a oeste de Fuchsia).
    'kanto': {
        'aspect': 1.524,
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
    img = details(cv, img, land, layers, seed)
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


def details(cv, img, land, layers, seed):
    """O detalhe de cada bioma (como num mapa desenhado): árvores, picos, dunas, juncos, a lava e os arvoredos dos campos."""
    rng = np.random.default_rng(seed + 11)
    out = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).convert('RGBA')
    d = ImageDraw.Draw(out, 'RGBA')
    covered = np.zeros_like(land)
    for kind, shape, m in layers:
        covered = np.maximum(covered, m)
        if kind == 'forest':
            for x, y in scatter(m, 7, rng, 0.45):
                r = rng.uniform(3.2, 5.0)
                d.ellipse([x - r, y - r + 2, x + r, y + r + 2], fill=(10, 34, 18, 150))
                d.ellipse([x - r, y - r, x + r, y + r], fill=(26 + int(rng.integers(0, 20)), 82 + int(rng.integers(0, 30)), 40, 255))
                d.ellipse([x - r * 0.5, y - r * 0.7, x + r * 0.1, y - r * 0.1], fill=(90, 150, 80, 200))
        elif kind in ('mountain', 'snow', 'volcano', 'crater'):
            step = 14 if kind != 'snow' else 16
            for x, y in scatter(m, step, rng, 0.5):
                h = rng.uniform(8, 15)
                wdt = h * rng.uniform(0.8, 1.1)
                snowy = kind == 'snow' or rng.random() < 0.25 and kind == 'mountain'
                left, right = ((214, 226, 238, 255), (150, 168, 190, 255)) if kind == 'snow' else ((168, 146, 112, 255), (104, 84, 62, 255))
                if kind == 'volcano':
                    left, right = (120, 84, 70, 255), (76, 50, 44, 255)
                d.polygon([(x, y - h), (x - wdt, y), (x, y)], fill=left)
                d.polygon([(x, y - h), (x + wdt, y), (x, y)], fill=right)
                if snowy and kind != 'snow':
                    d.polygon([(x, y - h), (x - wdt * 0.35, y - h * 0.62), (x + wdt * 0.35, y - h * 0.62)], fill=(236, 242, 250, 255))
                elif kind == 'snow':
                    d.polygon([(x, y - h), (x - wdt * 0.4, y - h * 0.55), (x + wdt * 0.4, y - h * 0.55)], fill=(255, 255, 255, 255))
            if kind == 'volcano':
                cx, cy, rx, ry = shape
                X, Y = cx * cv.w / 100, cy * cv.h / 100
                d.ellipse([X - rx * cv.w / 400, Y - ry * cv.h / 400, X + rx * cv.w / 400, Y + ry * cv.h / 400], fill=(240, 96, 40, 255), outline=(90, 30, 20, 255))
        elif kind == 'desert':
            for x, y in scatter(m, 13, rng, 0.5):
                d.arc([x - 7, y - 3, x + 7, y + 4], 200, 340, fill=(170, 130, 76, 220), width=2)
        elif kind == 'swamp':
            for x, y in scatter(m, 8, rng, 0.5):
                d.line([(x, y), (x - 1, y - 5)], fill=(40, 70, 40, 230), width=1)
                d.line([(x + 2, y), (x + 3, y - 4)], fill=(40, 70, 40, 230), width=1)
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
