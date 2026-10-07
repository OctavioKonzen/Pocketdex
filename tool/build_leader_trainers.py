"""Acrescenta líderes de ginásio, Elite Four, campeões, vilões e
protagonistas no fim de assets/database/trainers.json.

Gerações 1 a 5: sprites animados no estilo BW do pacote "Animated Trainer
Intros" (add-on do Deluxe Battle Kit, Lucidious89; base Gen 4/5 © Nintendo/
Game Freak), mesmo formato do Elite Battle System (quadros quadrados lado a
lado; costas com 5 quadros do lançamento). Os que não têm versão animada
vêm do Pokémon Showdown (80 × 80). Uso sem fins lucrativos, créditos no
README. A ordem é a posição salva no avatar: só acrescente no fim.

Uso:
    python3 tool/build_leader_trainers.py <Graphics/Trainers do pacote> <pasta com os PNGs extras do Showdown>
"""

import json
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'database', 'sprites', 'trainers')
LIST = os.path.join(ROOT, 'assets', 'database', 'trainers.json')

LEADER, ELITE = 'Líder de Ginásio', 'Elite Four'
# (id, arquivo do pacote, nome, título)
ANIMATED = [
    # Johto
    ('falkner', 'LEADER_Falkner', 'Falkner', LEADER),
    ('bugsy', 'LEADER_Bugsy', 'Bugsy', LEADER),
    ('whitney', 'LEADER_Whitney', 'Whitney', LEADER),
    ('morty', 'LEADER_Morty', 'Morty', LEADER),
    ('chuck', 'LEADER_Chuck', 'Chuck', LEADER),
    ('jasmine', 'LEADER_Jasmine', 'Jasmine', LEADER),
    ('pryce', 'LEADER_Pryce', 'Pryce', LEADER),
    ('clair', 'LEADER_Clair', 'Clair', LEADER),
    ('janine', 'LEADER_Janine', 'Janine', LEADER),
    ('will', 'ELITEFOUR_Will', 'Will', ELITE),
    ('karen', 'ELITEFOUR_Karen', 'Karen', ELITE),
    ('champion-lance', 'ELITEFOUR_Lance', 'Lance', 'Campeão'),
    # Hoenn
    ('roxanne', 'LEADER_Roxanne', 'Roxanne', LEADER),
    ('brawly', 'LEADER_Brawly', 'Brawly', LEADER),
    ('wattson', 'LEADER_Wattson', 'Wattson', LEADER),
    ('flannery', 'LEADER_Flannery', 'Flannery', LEADER),
    ('norman', 'LEADER_Norman', 'Norman', LEADER),
    ('winona', 'LEADER_Winona', 'Winona', LEADER),
    ('tate-liza', 'LEADERS', 'Tate & Liza', LEADER),
    ('wallace', 'LEADER_Wallace', 'Wallace', LEADER),
    ('juan', 'LEADER_Juan', 'Juan', LEADER),
    ('steven', 'CHAMPION_Steven', 'Steven', 'Campeão'),
    # Sinnoh
    ('roark', 'LEADER_Roark', 'Roark', LEADER),
    ('gardenia', 'LEADER_Gardenia', 'Gardenia', LEADER),
    ('maylene', 'LEADER_Maylene', 'Maylene', LEADER),
    ('wake', 'LEADER_Wake', 'Crasher Wake', LEADER),
    ('fantina', 'LEADER_Fantina', 'Fantina', LEADER),
    ('byron', 'LEADER_Byron', 'Byron', LEADER),
    ('candice', 'LEADER_Candice', 'Candice', LEADER),
    ('volkner', 'LEADER_Volkner', 'Volkner', LEADER),
    ('aaron', 'ELITEFOUR_Aaron', 'Aaron', ELITE),
    ('bertha', 'ELITEFOUR_Bertha', 'Bertha', ELITE),
    ('flint', 'ELITEFOUR_Flint', 'Flint', ELITE),
    ('lucian', 'ELITEFOUR_Lucian', 'Lucian', ELITE),
    ('cynthia', 'CHAMPION_Cynthia', 'Cynthia', 'Campeã'),
    # Unova
    ('cilan', 'LEADER_Cilan', 'Cilan', LEADER),
    ('chili', 'LEADER_Chili', 'Chili', LEADER),
    ('cress', 'LEADER_Cress', 'Cress', LEADER),
    ('lenora', 'LEADER_Lenora', 'Lenora', LEADER),
    ('burgh', 'LEADER_Burgh', 'Burgh', LEADER),
    ('elesa', 'LEADER_Elesa2', 'Elesa', LEADER),
    ('clay', 'LEADER_Clay', 'Clay', LEADER),
    ('skyla', 'LEADER_Skyla', 'Skyla', LEADER),
    ('brycen', 'LEADER_Brycen', 'Brycen', LEADER),
    ('drayden', 'LEADER_Drayden', 'Drayden', LEADER),
    ('iris-leader', 'LEADER_Iris', 'Iris', LEADER),
    ('cheren-leader', 'LEADER_Cheren', 'Cheren', LEADER),
    ('roxie', 'LEADER_Roxie', 'Roxie', LEADER),
    ('marlon', 'LEADER_Marlon', 'Marlon', LEADER),
    ('shauntal', 'ELITEFOUR_Shauntal', 'Shauntal', ELITE),
    ('grimsley', 'ELITEFOUR_Grimsley', 'Grimsley', ELITE),
    ('caitlin', 'ELITEFOUR_Caitlin', 'Caitlin', ELITE),
    ('marshal', 'ELITEFOUR_Marshal', 'Marshal', ELITE),
    ('alder', 'CHAMPION_Alder', 'Alder', 'Campeão'),
    ('iris', 'CHAMPION_Iris', 'Iris', 'Campeã'),
    # Vilões
    ('archer', 'ROCKETADMIN_Archer', 'Archer', 'Equipe Rocket'),
    ('ariana', 'ROCKETADMIN_Ariana', 'Ariana', 'Equipe Rocket'),
    ('proton', 'ROCKETADMIN_Proton', 'Proton', 'Equipe Rocket'),
    ('petrel', 'ROCKETADMIN_Petrel', 'Petrel', 'Equipe Rocket'),
    ('giovanni-hgss', 'ROCKETBOSS', 'Giovanni', 'Chefe da Equipe Rocket'),
    ('cyrus', 'GALACTICBOSS', 'Cyrus', 'Chefe da Equipe Galáctica'),
    ('galactic-grunt-m', 'TEAMGALACTIC_M', 'Equipe Galáctica', 'Recruta'),
    ('galactic-grunt-f', 'TEAMGALACTIC_F', 'Equipe Galáctica', 'Recruta'),
    ('ghetsis', 'PLASMABOSS2', 'Ghetsis', 'Equipe Plasma'),
    ('n', 'POKEMONTRAINER_N', 'N', 'Rei da Equipe Plasma'),
    ('colress', 'POKEMONTRAINER_Colress', 'Colress', 'Equipe Plasma'),
    ('zinzolin', 'TEAMPLASMA_Zinzolin', 'Zinzolin', 'Equipe Plasma'),
    ('rood', 'TEAMPLASMA_Rood', 'Rood', 'Equipe Plasma'),
    ('plasma-grunt-m', 'TEAMPLASMA_M', 'Equipe Plasma', 'Recruta'),
    ('plasma-grunt-f', 'TEAMPLASMA_F', 'Equipe Plasma', 'Recruta'),
    # Protagonistas e rivais (com as costas lançando a Poké Ball)
    ('ethan', 'POKEMONTRAINER_Ethan', 'Ethan', 'Treinador'),
    ('lyra', 'POKEMONTRAINER_Lyra', 'Lyra', 'Treinadora'),
    ('silver', 'POKEMONTRAINER_Silver', 'Silver', 'Rival'),
    ('wally', 'POKEMONTRAINER_Wally', 'Wally', 'Rival'),
    ('lucas', 'POKEMONTRAINER_Lucas', 'Lucas', 'Treinador'),
    ('dawn', 'POKEMONTRAINER_Dawn', 'Dawn', 'Treinadora'),
    ('barry', 'POKEMONTRAINER_Barry2', 'Barry', 'Rival'),
    ('hilbert', 'POKEMONTRAINER_Hilbert', 'Hilbert', 'Treinador'),
    ('hilda', 'POKEMONTRAINER_Hilda', 'Hilda', 'Treinadora'),
    ('cheren', 'POKEMONTRAINER_Cheren', 'Cheren', 'Rival'),
    ('bianca', 'POKEMONTRAINER_Bianca2', 'Bianca', 'Rival'),
    ('nate', 'POKEMONTRAINER_Nate', 'Nate', 'Treinador'),
    ('rosa', 'POKEMONTRAINER_Rosa', 'Rosa', 'Treinadora'),
    ('hugh', 'POKEMONTRAINER_Hugh', 'Hugh', 'Rival'),
    # Frente de Batalha / Metrô de Batalha
    ('thorton', 'FRONTIERBRAIN_Thorton', 'Thorton', 'Cérebro da Frente'),
    ('palmer', 'FRONTIERBRAIN_Palmer', 'Palmer', 'Cérebro da Frente'),
    ('dahlia', 'FRONTIERBRAIN_Dahlia', 'Dahlia', 'Cérebro da Frente'),
    ('darach', 'FRONTIERBRAIN_Darach', 'Darach', 'Cérebro da Frente'),
    ('argenta', 'FRONTIERBRAIN_Argenta', 'Argenta', 'Cérebro da Frente'),
    ('ingo', 'SUBWAYBOSS_Ingo', 'Ingo', 'Chefe do Metrô'),
    ('emmet', 'SUBWAYBOSS_Emmet', 'Emmet', 'Chefe do Metrô'),
    ('benga', 'BOSSTRAINER_Benga', 'Benga', 'Treinador'),
]
# Sem versão animada: do Showdown (80 × 80), com as variações que faltam na lista padrão.
SHOWDOWN = [
    ('sd-phoebe-gen6', 'phoebe-gen6', 'Phoebe', ELITE),
    ('sd-drake-gen3', 'drake-gen3', 'Drake', ELITE),
    ('sd-maxie-gen6', 'maxie-gen6', 'Maxie', 'Chefe da Equipe Magma'),
    ('sd-archie-gen6', 'archie-gen6', 'Archie', 'Chefe da Equipe Aqua'),
]


def main(src, extra):
    with open(LIST, encoding='utf-8') as f:
        listing = json.load(f)
    known = {t['id'] for t in listing}
    added = 0
    for tid, name, label, title in ANIMATED:
        if tid in known:
            continue
        im = Image.open(os.path.join(src, name + '.png')).convert('RGBA')
        side = im.height
        count = max(1, im.width // side)
        # Algumas animações começam vazias (o personagem surgindo): pula esses quadros.
        first = 0
        while first < count - 1 and not im.crop((first * side, 0, (first + 1) * side, side)).getbbox():
            first += 1
        count -= first
        im = im.crop((first * side, 0, (first + count) * side, side))
        im.save(os.path.join(OUT, f'{tid}.png'), optimize=True)
        entry = {'id': tid, 'name': label, 'title': title, 'size': side, 'frames': count}
        # Quadros grandes (personagem desenhado maior): na tela, da altura dos outros.
        tall = im.crop((0, 0, side, side)).getbbox()
        if tall and tall[3] - tall[1] > 84:
            entry['scale'] = round(78 / (tall[3] - tall[1]), 3)
        back = os.path.join(src, name + '_back.png')
        if os.path.exists(back):
            bim = Image.open(back).convert('RGBA')
            bw = bim.width // 5
            bim.crop((0, 0, bw * 5, bim.height)).save(os.path.join(OUT, f'{tid}_back.png'), optimize=True)
            entry['back'] = {'width': bw, 'height': bim.height, 'frames': 5}
        listing.append(entry)
        added += 1
    for tid, name, label, title in SHOWDOWN:
        if tid in known:
            continue
        Image.open(os.path.join(extra, name + '.png')).convert('RGBA').save(os.path.join(OUT, f'{tid}.png'), optimize=True)
        listing.append({'id': tid, 'name': label, 'title': title, 'size': 80, 'frames': 1})
        added += 1
    with open(LIST, 'w', encoding='utf-8') as f:
        json.dump(listing, f, ensure_ascii=False, separators=(',', ':'))
        f.write('\n')
    print(added, 'treinadores novos;', len(listing), 'no total')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
