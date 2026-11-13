"""As regiões dos outros jogos (fora da série principal), no mesmo formato do Pokelike. Usado por
tool/build_factory_data.py (os chefes), tool/factory_routes.py (rotas, clima e cenários das cidades) e
tool/factory_stories.py (a história).

Os jogos Ranger não têm batalhas de treinador: os chefes deles são as pessoas da história (a equipe vilã de cada
jogo, o parceiro e o último vilão) com Pokémon que eles usam nos jogos. A ordem das regiões: as de expansão (DLC)
têm 'after' (o jogo delas) e só vêm logo depois dele; as outras entram no sorteio normal.

Cada chefe: (nome, sprite do treinador, tipo, time, cidade de destino, extras).
"""

REGIONS = [
    {
        'region': 'Orre', 'game': 'Colosseum/XD', 'start': 'Gateon Port', 'color': '#b45309', 'legends': [243, 244, 245, 249],
        'leaders': [
            ('Miror B.', 'sd-guitarist', 'gym', [270, 271, 272], 'Pyrite Town', {}),
            ('Wes', 'sd-punkguy', 'rival', [197, 196], 'Agate Village', {'guest': True}),
            ('Dakim', 'sd-roughneck', 'gym', [344, 76, 340, 244], 'Agate Village', {}),
            ('Venus', 'sd-madame', 'gym', [301, 208, 354, 245], 'Phenac City', {}),
            ('Ein', 'sd-scientist', 'gym', [112, 310, 97, 243], 'Cipher Lab', {}),
            ('Wes', 'sd-punkguy', 'rival', [197, 196, 229, 286], 'Desert Resort', {'guest': True}),
            ('Nascour', 'sd-gentleman', 'gym', [334, 199, 110, 97], 'Desert Resort', {}),
            ('Evice', 'sd-veteran', 'champion', [289, 248, 143, 68, 227, 121], 'Realgam Tower', {}),
        ],
        'routes': {
            'Pyrite Town': ['desert', 'Orre Desert', ['Pyrite Cave', 'cave'], [['The Under', 'sewer']]],
            'Agate Village': ['mountain', 'Mt. Battle Road', ['Mt. Battle', 'mountain'], [['Relic Stone', 'ruins']]],
            'Phenac City': ['desert', 'Orre Desert', ['Phenac Stadium', 'city'], []],
            'Cipher Lab': ['desert', 'Orre Desert', ['Cipher Key Lair', 'cave'], []],
            'Desert Resort': ['desert', 'Orre Desert', ['Cave Poké Spot', 'cave'], []],
            'Realgam Tower': ['desert', 'Orre Desert', ['Orre Colosseum', 'city'], []],
        },
        'climate': {
            'Pyrite Town': {'route': {'w': [['sand', 0.7]]}}, 'Phenac City': {'route': {'w': [['sand', 0.6]]}},
            'Cipher Lab': {'route': {'w': [['sand', 0.6]]}}, 'Desert Resort': {'route': {'w': [['sand', 0.9], ['sun', 0.1]]}},
            'Realgam Tower': {'route': {'w': [['sand', 0.6]]}},
        },
        'towns': {'metro': ['Phenac City'], 'industrial': ['Pyrite Town', 'Cipher Lab'], 'village': ['Agate Village'],
                  'desert': ['Desert Resort'], 'league': ['Realgam Tower']},
        'story': {
            'intro': 'Em Orre, um deserto sem Pokémon selvagens, a Cipher fecha o coração dos Pokémon e os transforma em Pokémon Sombrios. Você chega em Gateon Port para impedir.',
            'gym': '{0}, um dos chefes da Cipher, protege esta parte de Orre com Pokémon Sombrios.',
            'rival': '{0} já enfrentou a Cipher antes e quer ver se você aguenta. "Mostre do que é capaz."',
            'villain': '{0} trabalha para a Cipher e não deixa você passar.',
            'elite': '{0} guarda a entrada da Realgam Tower e não deixa ninguém subir.',
            'champion': 'No alto da Realgam Tower, {0}, o líder da Cipher, espera. É a última batalha de Orre.',
            'end': 'Os Pokémon Sombrios abriram o coração de novo. Você deixa Orre para outra região.',
        },
    },
    {
        'region': 'Fiore', 'game': 'Ranger', 'start': 'Ringtown', 'color': '#16a34a', 'legends': [243, 244, 245],
        'leaders': [
            ('Solana', 'sd-pokemonrangerf', 'rival', [311], 'Fall City', {}),
            ('Billy Jo', 'rocker', 'gym', [214, 127, 123], 'Fall City', {}),
            ('Lavana', 'sd-punkgirl', 'gym', [126, 228, 59], 'Summerland', {}),
            ('Solana', 'sd-pokemonrangerf', 'rival', [311, 334, 260], 'Wintown', {}),
            ('Clyde', 'sd-punkguy', 'gym', [125, 82, 101], 'Wintown', {}),
            ('Garret', 'sd-guitarist', 'gym', [96, 97, 280], 'Sekra Range', {}),
            ('Gordor', 'sd-veteran', 'champion', [68, 112, 248, 130, 186, 227], 'Fiore Temple', {}),
        ],
        'routes': {
            'Fall City': ['grass', 'Kisara Plain', ['Lyra Forest', 'forest'], []],
            'Summerland': ['beach', 'Fiore Coast', ['Panula Cave', 'cave'], [['Summerland Beach', 'beach']]],
            'Wintown': ['snow', 'Fiore Snowfield', ['Wintown Cave', 'icecave'], []],
            'Sekra Range': ['mountain', 'Sekra Range', ['Sekra Cave', 'cave'], []],
            'Fiore Temple': ['grass', 'Fiore Lake Road', ['Fiore Temple', 'temple'], []],
        },
        'climate': {
            'Summerland': {'route': {'w': [['sun', 0.6]]}}, 'Wintown': {'route': {'w': [['snow', 0.85]]}},
            'Sekra Range': {'route': {'f': [['rockfall', 0.5]]}}, 'Fiore Temple': {'fiore-temple': {'f': [['psychic', 0.5]]}},
        },
        'features': {'Summerland': {'water': 'sea'}},
        'towns': {'village': ['Fall City'], 'port': ['Summerland'], 'snow': ['Wintown'], 'mountain': ['Sekra Range'], 'league': ['Fiore Temple']},
        'story': {
            'intro': 'Em Fiore, os Pokémon Rangers protegem a natureza sem prender Pokémon. Você sai de Ringtown com o Capture Styler, e a Equipe Go-Rock está tramando algo.',
            'gym': '{0}, da Equipe Go-Rock, quer usar os Pokémon de Fiore para o plano da equipe.',
            'rival': '{0}, a Ranger parceira, quer ver se você está pronto. "Vamos treinar juntos!"',
            'villain': '{0} faz parte da Equipe Go-Rock.',
            'elite': '{0} guarda o caminho até o Fiore Temple.',
            'champion': 'No Fiore Temple, {0}, o chefe da Equipe Go-Rock, quer o poder dos lendários. É a última batalha de Fiore.',
            'end': 'A Equipe Go-Rock foi presa e Fiore ficou em paz. Você segue para outra região.',
        },
    },
    {
        'region': 'Almia', 'game': 'Shadows of Almia', 'start': 'Vientown', 'color': '#0891b2', 'legends': [485, 486, 384],
        'leaders': [
            ('Keith', 'sd-pokemonranger', 'rival', [418], 'Pueltown', {}),
            ('Heath', 'sd-roughneck', 'gym', [72, 279, 171], 'Pueltown', {}),
            ('Wendy', 'sd-punkgirl', 'gym', [315, 192, 357], 'Chicole Village', {}),
            ('Sven', 'sd-guitarist', 'gym', [126, 78, 324], 'Boyleland', {}),
            ('Keith', 'sd-pokemonranger', 'rival', [418, 419, 396, 405], 'Haruba Village', {}),
            ('Kincaid', 'sd-officeworker', 'gym', [262, 302, 436, 437], 'Altru Building', {}),
            ('Blake Hall', 'sd-gentleman', 'champion', [430, 461, 248, 452, 442, 485], 'Almia Castle', {}),
        ],
        'routes': {
            'Pueltown': ['beach', 'Almia Coast', ['Marine Cave', 'seacave'], [['Pueltown Harbor', 'beach']]],
            'Chicole Village': ['forest', 'Chicole Path', ['Altru Park', 'forest'], []],
            'Boyleland': ['mountain', 'Mt. Tember Road', ['Volcano Cave', 'cave'], []],
            'Haruba Village': ['desert', 'Haruba Desert', ['Hippowdon Temple', 'ruins'], []],
            'Altru Building': ['grass', 'Altru Road', ['Dim Sun Hideout', 'cave'], []],
            'Almia Castle': ['grass', 'Almia Castle Road', ['Almia Castle', 'tower'], []],
        },
        'climate': {
            'Boyleland': {'route': {'f': [['ashes', 0.6]]}}, 'Haruba Village': {'route': {'w': [['sand', 0.85]]}},
            'Almia Castle': {'almia-castle': {'f': [['haunt', 0.6]]}},
        },
        'features': {'Pueltown': {'water': 'sea'}},
        'towns': {'port': ['Pueltown'], 'forest': ['Chicole Village'], 'volcano': ['Boyleland'], 'desert': ['Haruba Village'],
                  'metro': ['Altru Building'], 'league': ['Almia Castle']},
        'story': {
            'intro': 'Em Almia, você entra para a Escola de Rangers de Vientown. A Equipe Dim Sun está controlando Pokémon com máquinas.',
            'gym': '{0}, da Equipe Dim Sun, controla os Pokémon daqui com as máquinas da equipe.',
            'rival': '{0} entrou na Escola de Rangers com você e não quer ficar para trás. "Eu sou o melhor Ranger daqui!"',
            'villain': '{0} faz parte da Equipe Dim Sun.',
            'elite': '{0} guarda a entrada do Almia Castle.',
            'champion': 'No Almia Castle, {0}, o presidente da Altru, quer dominar Almia. É a última batalha da região.',
            'end': 'A Equipe Dim Sun acabou e os Pokémon de Almia estão livres. Você segue para outra região.',
        },
    },
    {
        'region': 'Oblivia', 'game': 'Guardian Signs', 'start': 'Dolce Island', 'color': '#2563eb', 'legends': [249, 250, 243, 244, 245],
        'leaders': [
            ('Summer', 'sd-pokemonrangerf', 'rival', [489], 'Renbow Island', {}),
            ('Purple Eyes', 'sd-ninjaboy', 'gym', [24, 336, 169], 'Renbow Island', {}),
            ('Blue Eyes', 'sd-officeworker', 'gym', [130, 319, 121], 'Mitonga Island', {}),
            ('Summer', 'sd-pokemonrangerf', 'rival', [489, 501, 393, 7], 'Layuda Island', {}),
            ('Red Eyes', 'sd-punkguy', 'gym', [229, 126, 59], 'Faldera Island', {}),
            ('Ice', 'sd-veteran', 'champion', [461, 473, 362, 478, 473, 250], 'Oblivia Ruins', {}),
        ],
        'routes': {
            'Renbow Island': ['beach', 'Renbow Coast', ['Renbow Cave', 'seacave'], []],
            'Mitonga Island': ['forest', 'Mitonga Jungle', ['Mitonga Ruins', 'ruins'], []],
            'Layuda Island': ['desert', 'Layuda Dunes', ['Layuda Temple', 'ruins'], []],
            'Faldera Island': ['mountain', 'Faldera Road', ['Faldera Volcano', 'volcano'], []],
            'Oblivia Ruins': ['water', 'Oblivia Sea', ['Sophian Island', 'temple'], []],
        },
        'climate': {
            'Mitonga Island': {'route': {'w': [['rain', 0.5]]}}, 'Layuda Island': {'route': {'w': [['sand', 0.8]]}},
            'Faldera Island': {'route': {'f': [['ashes', 0.7]]}}, 'Oblivia Ruins': {'route': {'w': [['rain', 0.4]]}},
        },
        'features': {'Oblivia Ruins': {'water': 'sea'}, 'Renbow Island': {'water': 'sea'}},
        'towns': {'port': ['Renbow Island'], 'forest': ['Mitonga Island'], 'desert': ['Layuda Island'], 'volcano': ['Faldera Island'],
                  'league': ['Oblivia Ruins']},
        'story': {
            'intro': 'Nas ilhas de Oblivia, os Pokémon Pinchers caçam Pokémon com máquinas. Você chega em Dolce Island como Ranger para proteger as ilhas.',
            'gym': '{0}, dos Pokémon Pinchers, está caçando os Pokémon desta ilha.',
            'rival': '{0}, a Ranger veterana, quer treinar com você antes de seguir. "Fica do meu lado!"',
            'villain': '{0} faz parte dos Pokémon Pinchers.',
            'elite': '{0} guarda a entrada das ruínas de Oblivia.',
            'champion': 'Nas ruínas de Oblivia, {0}, o chefe dos Pinchers, quer o poder dos lendários. É a última batalha de Oblivia.',
            'end': 'Os Pinchers foram presos e as ilhas ficaram em paz. Você segue para outra região.',
        },
    },
    {
        # DLC de Scarlet/Violet: só depois de Paldea.
        'region': 'Kitakami', 'game': 'The Teal Mask', 'after': 'Paldea', 'start': 'Mossui Town', 'color': '#15803d', 'legends': [1017, 1014, 1015, 1016],
        'leaders': [
            ('Kieran', 'sd-kieran', 'rival', [1012], 'Apple Hills', {}),
            ('Carmine', 'sd-carmine', 'rival', [262, 970], 'Apple Hills', {'guest': True}),
            ('Munkidori', 'mon-1015', 'gym', [1012, 108, 1015], 'Apple Hills', {}),
            ('Okidogi', 'mon-1014', 'gym', [453, 108, 1014], 'Oni Mountain', {}),
            ('Fezandipiti', 'mon-1016', 'gym', [1012, 562, 1016], 'Kitakami Hall', {}),
            ('Perrin', 'sd-perrin', 'rival', [436, 571, 330], 'Timeless Woods', {'guest': True}),
            ('Kieran', 'sd-kieran', 'champion', [1012, 1011, 210, 848, 1013], 'Crystal Pool', {}),
        ],
        'routes': {
            'Apple Hills': ['grass', 'Kitakami Road', ['Reveler’s Road', 'forest'], [['Mossui Fields', 'grass']]],
            'Oni Mountain': ['mountain', 'Oni Mountain', ['Fellhorn Gorge', 'cave'], []],
            'Kitakami Hall': ['grass', 'Loyalty Plaza', ['Wistful Fields', 'grass'], []],
            'Timeless Woods': ['forest', 'Kitakami Wilds', ['Timeless Woods', 'forest'], []],
            'Crystal Pool': ['mountain', 'Oni’s Maw', ['Crystal Pool', 'cave'], []],
        },
        'climate': {
            'Oni Mountain': {'route': {'w': [['rain', 0.3]], 'f': [['fog', 0.4]]}}, 'Timeless Woods': {'route': {'f': [['fog', 0.5]]}},
            'Crystal Pool': {'crystal-pool': {'f': [['diamonds', 0.6]]}},
        },
        'towns': {'village': ['Apple Hills', 'Kitakami Hall'], 'mountain': ['Oni Mountain'], 'forest': ['Timeless Woods'], 'league': ['Crystal Pool']},
        'story': {
            'intro': 'A escola levou você numa viagem para Kitakami, terra das lendas do ogro e dos três Pokémon leais. Você chega em Mossui Town, e o festival está para começar.',
            'gym': 'Um dos três leais, {0}, está solto em Kitakami. Pare ele antes que machuque alguém.',
            'rival': '{0} conhece Kitakami melhor do que ninguém e quer provar que é forte. "Não vou perder de novo!"',
            'villain': '{0} está atrás de Pokémon raros.',
            'elite': '{0} guarda a passagem para o Crystal Pool.',
            'champion': 'No Crystal Pool, {0} quer mostrar que ficou mais forte que você. É a última batalha de Kitakami.',
            'end': 'O festival acabou e a lenda do ogro mudou. Você volta para a escola e segue para outra região.',
        },
    },
    {
        # DLC de Scarlet/Violet (The Indigo Disk): só depois de Kitakami.
        'region': 'Blueberry', 'game': 'The Indigo Disk', 'after': 'Kitakami', 'start': 'Blueberry Academy', 'color': '#1d4ed8', 'legends': [1024, 1009, 1010],
        'leaders': [
            ('Carmine', 'sd-carmine', 'rival', [1013, 38, 983], 'Savanna Biome', {}),
            ('Crispin', 'sd-crispin', 'gym', [663, 323, 257, 229, 637], 'Savanna Biome', {}),
            ('Lacey', 'sd-lacey', 'gym', [210, 547, 869, 530, 553], 'Coastal Biome', {}),
            ('Amarys', 'sd-amarys', 'gym', [227, 823, 395, 376, 1018], 'Canyon Biome', {}),
            ('Drayton', 'sd-drayton', 'gym', [149, 330, 612, 230, 1018], 'Polar Biome', {}),
            ('Kieran', 'sd-kieran-champion', 'champion', [1019, 727, 149, 983, 445, 1024], 'League Club Room', {}),
        ],
        'routes': {
            'Savanna Biome': ['grass', 'Savanna Biome', ['Torchlit Labyrinth', 'cave'], []],
            'Coastal Biome': ['beach', 'Coastal Biome', ['Coastal Plaza', 'beach'], []],
            'Canyon Biome': ['mountain', 'Canyon Biome', ['Canyon Plaza', 'cave'], []],
            'Polar Biome': ['snow', 'Polar Biome', ['Chargestone Cavern', 'icecave'], []],
            'League Club Room': ['grass', 'Central Plaza', ['Area Zero Underdepths', 'crystal'], []],
        },
        'climate': {
            'Savanna Biome': {'route': {'w': [['sun', 0.6]]}}, 'Polar Biome': {'route': {'w': [['snow', 0.9]]}},
            'Canyon Biome': {'route': {'f': [['rockfall', 0.4]]}}, 'League Club Room': {'area-zero-underdepths': {'f': [['diamonds', 0.8]]}},
        },
        'features': {'Coastal Biome': {'water': 'sea'}},
        'towns': {'flower': ['Savanna Biome'], 'port': ['Coastal Biome'], 'mountain': ['Canyon Biome'], 'snow': ['Polar Biome'], 'league': ['League Club Room']},
        'story': {
            'intro': 'Você foi estudar na Blueberry Academy, uma escola no mar com uma cúpula gigante de biomas. A Liga Blueberry quer ver do que você é capaz.',
            'gym': '{0}, da Elite dos Quatro da Liga Blueberry, desafia você no bioma dela.',
            'rival': '{0} acha que ninguém de Paldea dá conta da Blueberry. "Vamos ver se aguenta!"',
            'villain': '{0} está atrás de Pokémon raros.',
            'elite': '{0}, da Elite dos Quatro da Blueberry, espera.',
            'champion': 'Na sala do clube, {0} é o campeão da Liga Blueberry e quer ganhar de você de qualquer jeito. É a última batalha.',
            'end': 'A Liga Blueberry tem um novo campeão. Você deixa a academia e segue para outra região.',
        },
    },
    {
        # Ilhas Sevii (FireRed/LeafGreen): só depois de terminar Kanto no FireRed/LeafGreen.
        'region': 'Sevii', 'game': 'Sevii Islands', 'after': 'FireRed/LeafGreen', 'start': 'One Island', 'color': '#0e7490', 'legends': [146, 386, 201],
        'leaders': [
            ('Paxton', 'biker', 'gym', [88, 109, 89, 110], 'Three Island', {}),
            ('Lorelei', 'lorelei', 'rival', [87, 91, 124, 131], 'Four Island', {'guest': True}),
            ('Executivo', 'rocket-grunt-m', 'villain', [24, 110, 229], 'Five Island', {}),
            ('Executiva', 'rocket-grunt-f', 'villain', [42, 89, 229], 'Five Island', {}),
            ('Gideon', 'scientist', 'gym', [81, 100, 137, 82], 'Six Island', {}),
            ('Blue', 'sd-blue', 'champion', [18, 65, 112, 103, 59, 130], 'Seven Island', {}),
        ],
        'routes': {
            'Three Island': ['water', 'Bond Bridge', ['Berry Forest', 'forest'], [['Three Isle Port', 'beach']]],
            'Four Island': ['beach', 'Four Island Shore', ['Icefall Cave', 'icecave'], []],
            'Five Island': ['water', 'Water Labyrinth', ['Memorial Pillar', 'ruins'], [['Rocket Warehouse', 'base-rocket']]],
            'Six Island': ['water', 'Outcast Island', ['Dotted Hole', 'cave'], [['Ruin Valley', 'ruins']]],
            'Seven Island': ['mountain', 'Sevault Canyon', ['Tanoby Ruins', 'ruins'], [['Trainer Tower', 'tower']]],
        },
        'climate': {
            'Four Island': {'icefall-cave': {'f': [['chill', 0.7]]}},
            'Six Island': {'dotted-hole': {'f': [['psychic', 0.4]]}}, 'Seven Island': {'route': {'f': [['rockfall', 0.4]]}},
        },
        'features': {'Three Island': {'water': 'sea'}, 'Four Island': {'water': 'sea', 'daycare': True}, 'Five Island': {'water': 'sea'},
                     'Six Island': {'water': 'sea'}},
        'towns': {'island': ['Three Island', 'Four Island', 'Five Island', 'Six Island'], 'mountain': ['Seven Island']},
        'story': {
            'intro': 'Depois da Liga de Kanto, o Bill leva você de barco às Ilhas Sevii. A Equipe Rocket voltou e está atrás do Ruby e do Sapphire para mexer na Network Machine.',
            'gym': '{0} causa problemas nas ilhas. Só passa quem vencer.',
            'rival': '{0}, da Elite dos Quatro, nasceu em Four Island e quer ver se você protege as ilhas.',
            'villain': '{0}, da Equipe Rocket, guarda o depósito da equipe em Five Island.',
            'elite': '{0} guarda a passagem para Seven Island.',
            'champion': 'No alto da Trainer Tower de Seven Island, {0} espera para uma revanche. É a última batalha das ilhas.',
            'end': 'A Network Machine funciona de novo e as ilhas estão em paz. O barco leva você para outra região.',
        },
    },
]

RARE = {'Orre': ['relic-forest'], 'Fiore': ['hia-valley'], 'Almia': ['shiver-camp'], 'Oblivia': ['sophian-island'], 'Kitakami': ['oni-mountain-summit'],
        'Blueberry': ['area-zero-underdepths'], 'Sevii': ['birth-island']}


def routes_of(key):
    """{cidade: valor} de todas as regiões para uma chave ('routes', 'climate', 'features')."""
    out = {}
    for r in REGIONS:
        out.update(r.get(key, {}))
    return out
