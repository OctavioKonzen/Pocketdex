"""Monta os treinadores do banco (sprites animados no estilo BW).

As imagens são tiras de quadros: a frente tem quadros quadrados (altura ×
altura) lado a lado; as costas (só dos personagens jogáveis) têm 5 quadros
do lançamento da Poké Ball. Vêm do Elite Battle System para Pokémon
Essentials (Luka S.J. e os spriters da comunidade), base © Nintendo/Game
Freak — uso sem fins lucrativos, com os créditos no README.

Saída:
    assets/database/sprites/trainers/<id>.png       frente (tira)
    assets/database/sprites/trainers/<id>_back.png  costas lançando (tira)
    assets/database/trainers.json                   lista (a ordem não muda:
                                                    o avatar guarda a posição)

Uso:
    python3 tool/build_trainers.py <pasta Graphics/Trainers do pacote>
"""

import json
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'database', 'sprites', 'trainers')

# (id, arquivo, nome, título). A ordem é a posição salva no avatar: só acrescente no fim.
TRAINERS = [
    ('red', 'POKEMONTRAINER_Red', 'Red', 'Treinador'),
    ('leaf', 'POKEMONTRAINER_Leaf', 'Leaf', 'Treinadora'),
    ('brendan', 'POKEMONTRAINER_Brendan', 'Brendan', 'Treinador'),
    ('may', 'POKEMONTRAINER_May', 'May', 'Treinadora'),
    ('blue', 'trainer005', 'Blue', 'Rival'),
    ('aroma-lady', 'trainer006', 'Aroma Lady', 'Aroma Lady'),
    ('beauty', 'trainer007', 'Beauty', 'Beauty'),
    ('biker', 'trainer008', 'Biker', 'Biker'),
    ('bird-keeper', 'trainer009', 'Bird Keeper', 'Bird Keeper'),
    ('bug-catcher', 'trainer010', 'Bug Catcher', 'Bug Catcher'),
    ('channeler', 'trainer012', 'Channeler', 'Channeler'),
    ('cue-ball', 'trainer013', 'Cue Ball', 'Cue Ball'),
    ('engineer', 'trainer014', 'Engineer', 'Engineer'),
    ('fisherman', 'trainer015', 'Fisherman', 'Fisherman'),
    ('gambler', 'trainer016', 'Gambler', 'Gambler'),
    ('gentleman', 'trainer017', 'Gentleman', 'Gentleman'),
    ('hiker', 'trainer018', 'Hiker', 'Hiker'),
    ('juggler', 'trainer019', 'Juggler', 'Juggler'),
    ('lady', 'trainer020', 'Lady', 'Lady'),
    ('painter', 'trainer021', 'Painter', 'Painter'),
    ('pokemaniac', 'trainer022', 'Poké Maniac', 'Poké Maniac'),
    ('breeder', 'trainer023', 'Pokémon Breeder', 'Pokémon Breeder'),
    ('oak', 'trainer024', 'Prof. Oak', 'Professor'),
    ('rocker', 'trainer025', 'Rocker', 'Rocker'),
    ('ruin-maniac', 'trainer026', 'Ruin Maniac', 'Ruin Maniac'),
    ('sailor', 'trainer027', 'Sailor', 'Sailor'),
    ('scientist', 'trainer028', 'Scientist', 'Scientist'),
    ('super-nerd', 'trainer029', 'Super Nerd', 'Super Nerd'),
    ('tamer', 'trainer030', 'Tamer', 'Tamer'),
    ('black-belt', 'trainer031', 'Black Belt', 'Black Belt'),
    ('crush-girl', 'trainer032', 'Crush Girl', 'Crush Girl'),
    ('camper', 'trainer033', 'Camper', 'Camper'),
    ('picnicker', 'trainer034', 'Picnicker', 'Picnicker'),
    ('ace-trainer-m', 'trainer035', 'Ace Trainer', 'Ace Trainer'),
    ('ace-trainer-f', 'trainer036', 'Ace Trainer', 'Ace Trainer'),
    ('youngster', 'trainer037', 'Youngster', 'Youngster'),
    ('lass', 'trainer038', 'Lass', 'Lass'),
    ('ranger-m', 'trainer039', 'Pokémon Ranger', 'Pokémon Ranger'),
    ('ranger-f', 'trainer040', 'Pokémon Ranger', 'Pokémon Ranger'),
    ('psychic-m', 'trainer041', 'Psychic', 'Psychic'),
    ('psychic-f', 'trainer042', 'Psychic', 'Psychic'),
    ('swimmer-m', 'trainer043', 'Swimmer', 'Swimmer'),
    ('swimmer-f', 'trainer044', 'Swimmer', 'Swimmer'),
    ('swimmer-m2', 'trainer045', 'Swimmer', 'Swimmer'),
    ('swimmer-f2', 'trainer046', 'Swimmer', 'Swimmer'),
    ('tuber-m', 'trainer047', 'Tuber', 'Tuber'),
    ('tuber-f', 'trainer048', 'Tuber', 'Tuber'),
    ('tuber-m2', 'trainer049', 'Tuber', 'Tuber'),
    ('tuber-f2', 'trainer050', 'Tuber', 'Tuber'),
    ('cool-couple', 'trainer051', 'Cool Couple', 'Cool Couple'),
    ('crush-kin', 'trainer052', 'Crush Kin', 'Crush Kin'),
    ('sis-and-bro', 'trainer053', 'Sis and Bro', 'Sis and Bro'),
    ('twins', 'trainer054', 'Twins', 'Twins'),
    ('young-couple', 'trainer055', 'Young Couple', 'Young Couple'),
    ('rocket-grunt-m', 'trainer056', 'Team Rocket', 'Team Rocket'),
    ('rocket-grunt-f', 'trainer057', 'Team Rocket', 'Team Rocket'),
    ('rocket-boss', 'trainer058', 'Giovanni', 'Chefe da Equipe Rocket'),
    ('brock', 'trainer059', 'Brock', 'Líder de Ginásio'),
    ('misty', 'trainer060', 'Misty', 'Líder de Ginásio'),
    ('lt-surge', 'trainer061', 'Lt. Surge', 'Líder de Ginásio'),
    ('erika', 'trainer062', 'Erika', 'Líder de Ginásio'),
    ('koga', 'trainer063', 'Koga', 'Líder de Ginásio'),
    ('sabrina', 'trainer064', 'Sabrina', 'Líder de Ginásio'),
    ('blaine', 'trainer065', 'Blaine', 'Líder de Ginásio'),
    ('giovanni', 'trainer066', 'Giovanni', 'Líder de Ginásio'),
    ('lorelei', 'trainer067', 'Lorelei', 'Elite Four'),
    ('bruno', 'trainer068', 'Bruno', 'Elite Four'),
    ('agatha', 'trainer069', 'Agatha', 'Elite Four'),
    ('lance', 'trainer070', 'Lance', 'Elite Four'),
    ('champion-blue', 'trainer071', 'Blue', 'Campeão'),
]


def main(src):
    os.makedirs(OUT, exist_ok=True)
    listing = []
    for tid, name, label, title in TRAINERS:
        im = Image.open(os.path.join(src, name + '.png')).convert('RGBA')
        # Frente: quadros quadrados (altura × altura) lado a lado, como o Elite
        # Battle lê (sobra no fim é ignorada); os jogáveis têm um quadro só.
        side = im.height
        count = max(1, im.width // side)
        im.crop((0, 0, side * count, side)).save(os.path.join(OUT, f'{tid}.png'), optimize=True)
        entry = {'id': tid, 'name': label, 'title': title, 'size': side, 'frames': count}
        # Os jogáveis vêm desenhados maiores (128 px): na tela, do tamanho dos outros.
        if 'back' in tid or name.startswith('POKEMONTRAINER'):
            entry['scale'] = 0.65
        back = os.path.join(src, name + '_back.png')
        if os.path.exists(back):
            bim = Image.open(back).convert('RGBA')
            # Costas: 5 quadros do lançamento da Poké Ball.
            frames = 5
            bw = bim.width // frames
            bim.crop((0, 0, bw * frames, bim.height)).save(os.path.join(OUT, f'{tid}_back.png'), optimize=True)
            entry['back'] = {'width': bw, 'height': bim.height, 'frames': frames}
        listing.append(entry)
    with open(os.path.join(ROOT, 'assets', 'database', 'trainers.json'), 'w', encoding='utf-8') as f:
        json.dump(listing, f, ensure_ascii=False, separators=(',', ':'))
        f.write('\n')
    print(len(listing), 'treinadores')


if __name__ == '__main__':
    main(sys.argv[1])
