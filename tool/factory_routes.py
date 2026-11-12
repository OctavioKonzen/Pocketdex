"""O mapa da Battle Factory em cada região, na ordem dos jogos. Usado por
tool/build_factory_data.py (vai para factory.json, chave "routes").

CITIES: a cidade de destino de cada rota (o "city" dos chefes) →
    [lugar da rota, nome da rota, lugar no caminho, [lugares da cidade]]
  - lugar da rota: o cenário (e os selvagens) dos 10 andares até a cidade (o
    10º é o chefe da rota). Pode ser caverna quando ela é o caminho no jogo
    (Victory Road, Rock Tunnel, Ice Path); as outras são opcionais. A água começa sempre pela praia (praia → mar →
    fundo do mar → caverna aquática, cada um um lugar de 10 andares). Uma rota
    de mar ("water") começa pela praia e depois vira mar (o fundo do mar é
    opcional). As cavernas no caminho ("cave") combinam com a rota: no gelo, de
    gelo; no pântano, venenosa; no vulcão, de lava; no mar, aquática;
  - lugar no caminho: [nome, cenário] ou None. Aparece numa bifurcação da rota:
    10 andares e um chefe; depois volta para a rota no mesmo andar;
  - lugares da cidade: [[nome, cenário], ...], só coisas de cidade (esgoto,
    torre, museu, loja, base vilã, a praia dela...), como nos jogos. Dá para
    entrar em mais de um (um por bifurcação da cidade).
  A Liga de cada região tem a chave "Região:Pokémon League" (o nome se repete).

FEATURES: o que existe em cada rota e cidade, como nos jogos (a mesma chave de
CITIES). O que não está aqui não aparece lá:
  - water: até onde a água vai: 'sea' (dá para surfar), 'deep' (tem Dive: o
    fundo do mar) ou 'cave' (tem caverna aquática depois do fundo). Sem a
    chave, a praia é só a praia;
  - fall: tem cachoeira no mar (a gruta da cachoeira, com Waterfall);
  - safari: o nome do Safari no caminho (Safari Zone, Great Marsh);
  - daycare: tem Creche na cidade ou na rota dela;
  - trade: [quem o morador quer, quem ele dá], a troca de lá nos jogos;
  - museum: {lugar: [fósseis que ele revive]} (os museus, a Devon, a Glittering
    Cave, as ruínas de Stow-on-Side): vencendo o chefe dele, um deles entra no time;
  - legends: {lugar: espécie ou {id, shiny}}: o chefe do lugar é ele (dá para
    capturar), como as aves de Kanto e o Gyarados vermelho do Lake of Rage;
  - routeLegend: o chefe da rota é ele (o Moltres na Victory Road);
  - blocker: {id, item}: dorme no meio da rota (o Snorlax, o Sudowoodo); com o
    item (Poké Flute, Squirt Bottle) dá para acordá-lo e lutar, sem ele só dá
    para dar a volta;
  - gifts: [{id, egg?, after?, choose?}]: o presente da cidade (after: só depois
    de vencer aquele lugar; choose: escolha um; egg: vem em ovo);
  - keys: {lugar ou 'gym': item-chave}: o que se ganha vencendo ali (o Silph
    Scope no Rocket Hideout, a Poké Flute na Pokémon Tower, a Squirt Bottle no
    ginásio de Goldenrod);
  - needs: {lugar: item-chave}: sem ele não dá para entrar (os fantasmas da
    Pokémon Tower sem o Silph Scope);
  - rewards: {lugar: item}: o prêmio da história (a Master Ball da Silph Co.);
  - corner: {name, prizes: [[espécie ou tm:golpe, fichas]]}: o Game Corner;
  - store: {name, stock: [...]}: a Department Store (pedras, vitaminas, TMs);
  - tutors: ['deleter', 'reminder', 'heart-scale']: o Move Deleter e o Move
    Reminder da cidade (heart-scale: ele cobra uma, como em Hoenn e Sinnoh).

TUTOR_EVERYWHERE: as regiões em que todo Centro Pokémon lembra e esquece golpes.

RARE: os lugares raros de cada região (só aparecem nela).

START: de onde a região começa (a cidade inicial do jogo). A chave é o jogo
quando ele começa em outro lugar (Black 2/White 2).
"""

CITIES = {
    # Kanto
    'Pewter City': ['grass', 'Route 1 · Route 2', ['Viridian Forest', 'forest'], [['Pewter Museum', 'ruins']]],
    'Cerulean City': ['mountain', 'Route 3 · Route 4', ['Mt. Moon', 'cave'], [['Nugget Bridge', 'city']]],
    'Vermilion City': ['grass', 'Route 5 · Route 6', ['Underground Path', 'sewer'], [['S.S. Anne', 'city'], ['Vermilion Harbor', 'beach']]],
    'Celadon City': ['cave', 'Route 9 · Rock Tunnel', None, [['Rocket Hideout', 'base-rocket'], ['Pokémon Tower', 'tower']]],
    'Fuchsia City': ['grass', 'Route 12 · Route 15', None, [['Fuchsia Beach', 'beach']]],
    'Saffron City': ['city', 'Route 7 · Route 8', ['Power Plant', 'plant'], [['Silph Co.', 'base-rocket'], ['Fighting Dojo', 'temple']]],
    'Cinnabar Island': ['water', 'Route 19 · Route 20', ['Seafoam Islands', 'icecave'],
                        [['Pokémon Mansion', 'ruins'], ['Cinnabar Lab', 'plant'], ['Cinnabar Beach', 'beach']]],
    'Viridian City': ['beach', 'Route 21 · Route 1', None, []],
    'Indigo Plateau': ['cave', 'Route 23 · Victory Road', ['Cerulean Cave', 'cave'], []],
    'Seafoam Islands': ['water', 'Route 20', ['Seafoam Islands', 'icecave'], [['Seafoam Beach', 'beach']]],
    # Johto
    'Violet City': ['grass', 'Route 29 · Route 30 · Route 31', ['Dark Cave', 'cave'], [['Sprout Tower', 'tower'], ['Ruins of Alph', 'ruins']]],
    'Azalea Town': ['grass', 'Route 32 · Route 33', ['Union Cave', 'cave'], [['Slowpoke Well', 'sewer']]],
    'Goldenrod City': ['grass', 'Route 34', ['Ilex Forest', 'forest'],
                       [['Goldenrod Tunnel', 'sewer'], ['Radio Tower', 'base-rocket']]],
    'Ecruteak City': ['grass', 'Route 35 · Route 36 · Route 37', ['National Park', 'flowers'], [['Burned Tower', 'tower'], ['Bell Tower', 'tower']]],
    'Olivine City': ['beach', 'Route 38 · Route 39', None, [['Glitter Lighthouse', 'tower'], ['Olivine Beach', 'beach']]],
    'Cianwood City': ['water', 'Route 40 · Route 41', ['Whirl Islands', 'cave'], [['Cianwood Beach', 'beach']]],
    'Mahogany Town': ['grass', 'Route 42', ['Mt. Mortar', 'cave'], [['Rocket Hideout', 'base-rocket']]],
    'Blackthorn City': ['icecave', 'Route 44 · Ice Path', ['Lake of Rage', 'swamp'], [["Dragon's Den", 'temple']]],
    # Hoenn
    'Rustboro City': ['grass', 'Route 101 · Route 102 · Route 104', ['Petalburg Woods', 'forest'], [['Devon Corporation', 'plant'], ["Trainers' School", 'city']]],
    'Dewford Town': ['water', 'Route 105 · Route 106', ['Granite Cave', 'cave'], [['Dewford Beach', 'beach']]],
    'Mauville City': ['beach', 'Route 109 · Route 110', ['New Mauville', 'plant'], []],
    'Lavaridge Town': ['mountain', 'Route 111 · Route 112', ['Fiery Path', 'lavacave'], [['Lavaridge Herb Shop', 'city']]],
    'Petalburg City': ['desert', 'Route 111 · Route 102', ['Mirage Tower', 'tower'], []],
    'Fortree City': ['forest', 'Route 119', ['Weather Institute', 'plant'], []],
    'Mossdeep City': ['water', 'Route 124 · Route 125', ['Shoal Cave', 'icecave'], [['Space Center', 'base-magma'], ['Mossdeep Beach', 'beach']]],
    'Sootopolis City': ['water', 'Route 126 · Route 127', ['Seafloor Cavern', 'cave'], [['Cave of Origin', 'temple']]],
    'Ever Grande City': ['cave', 'Victory Road', ['Sky Pillar', 'tower'], []],
    # Sinnoh
    'Oreburgh City': ['grass', 'Route 201 · Route 202 · Route 203', ['Oreburgh Gate', 'cave'], [['Oreburgh Mining Museum', 'ruins']]],
    'Eterna City': ['forest', 'Route 204 · Route 205', ['Eterna Forest', 'forest'], [['Galactic Eterna Building', 'base-galactic']]],
    'Hearthome City': ['grass', 'Route 206 · Route 207 · Route 208', ['Mt. Coronet', 'mountain'], [['Hearthome Contest Hall', 'city']]],
    'Veilstone City': ['mountain', 'Route 209 · Route 210 · Route 215', ['Lost Tower', 'tower'],
                       [['Galactic HQ', 'base-galactic']]],
    'Pastoria City': ['swamp', 'Route 213 · Route 214', ['Ruin Maniac Cave', 'cave'], [['Valor Lakefront', 'beach']]],
    'Canalave City': ['water', 'Route 218', ['Iron Island', 'cave'], [['Canalave Library', 'ruins'], ['Canalave Harbor', 'beach']]],
    'Snowpoint City': ['snow', 'Route 216 · Route 217', ['Lake Acuity', 'snow'], [['Snowpoint Temple', 'temple'], ['Snowpoint Harbor', 'beach']]],
    'Sunyshore City': ['beach', 'Route 222', None, [['Vista Lighthouse', 'tower'], ['Sunyshore Beach', 'beach']]],
    'Sinnoh:Pokémon League': ['cave', 'Victory Road', ['Spear Pillar', 'temple'], []],
    # Unova
    'Striaton City': ['grass', 'Route 1 · Route 2', ['Dreamyard', 'ruins'], []],
    'Nacrene City': ['grass', 'Route 3', ['Wellspring Cave', 'cave'], [['Nacrene Museum', 'ruins']]],
    'Castelia City': ['forest', 'Pinwheel Forest · Skyarrow Bridge', ['Pinwheel Forest', 'forest'], [['Castelia Sewers', 'sewer'], ['Castelia Pier', 'beach']]],
    'Nimbasa City': ['desert', 'Route 4', ['Relic Castle', 'ruins'], [['Battle Subway', 'city'], ['Nimbasa Amusement Park', 'city']]],
    'Driftveil City': ['grass', 'Route 5 · Driftveil Drawbridge', None, [['Cold Storage', 'plant'], ['Driftveil Market', 'city']]],
    'Mistralton City': ['mountain', 'Route 6', ['Chargestone Cave', 'crystal'], []],
    'Icirrus City': ['snow', 'Route 7', ['Twist Mountain', 'icecave'], [['Dragonspiral Tower', 'tower']]],
    'Opelucid City': ['swamp', 'Route 8 · Route 9', ['Moor of Icirrus', 'swamp'], []],
    'Aspertia City': ['grass', 'Route 19', ['Floccesy Ranch', 'flowers'], []],
    'Virbank City': ['grass', 'Route 20', None, [['Virbank Complex', 'plant'], ['Pokéstar Studios', 'city']]],
    'Humilau City': ['beach', 'Route 21 · Route 22', ['Seaside Cave', 'cave'], [['Plasma Frigate', 'base-plasma'], ['Humilau Beach', 'beach']]],
    'Unova:Pokémon League': ['cave', 'Victory Road', ['Giant Chasm', 'icecave'], []],
    # Kalos
    'Santalune City': ['forest', 'Route 2 · Santalune Forest', ['Santalune Forest', 'forest'], []],
    'Cyllage City': ['beach', 'Route 7 · Route 8', ['Connecting Cave', 'cave'], [['Cyllage Beach', 'beach']]],
    'Shalour City': ['beach', 'Route 10 · Route 11', ['Reflection Cave', 'crystal'], [['Tower of Mastery', 'tower'], ['Shalour Beach', 'beach']]],
    'Coumarine City': ['beach', 'Route 12', ['Glittering Cave', 'crystal'], [['Coumarine Harbor', 'beach']]],
    'Lumiose City': ['desert', 'Route 13', ['Kalos Power Plant', 'plant'], [['Lysandre Labs', 'base-flare'], ['Prism Tower', 'tower'], ['Lumiose Sewers', 'sewer']]],
    'Laverre City': ['swamp', 'Route 14', ['Lost Hotel', 'ruins'], [['Poké Ball Factory', 'plant']]],
    'Anistar City': ['forest', 'Route 15 · Route 16', ['Frost Cavern', 'icecave'], [['Anistar Sundial', 'ruins']]],
    'Snowbelle City': ['snow', 'Route 17 · Route 19', ['Pokémon Village', 'forest'], [['Team Flare Secret HQ', 'base-flare']]],
    'Kalos:Pokémon League': ['cave', 'Victory Road', ['Terminus Cave', 'cave'], []],
    # Alola
    'Verdant Cavern': ['grass', 'Route 1 · Route 2', ['Verdant Cavern', 'cave'], [["Hau'oli Shopping District", 'city'], ["Hau'oli Beach", 'beach']]],
    'Iki Town': ['grass', 'Route 1', ['Ten Carat Hill', 'cave'], [['Iki Town Dais', 'temple']]],
    'Ruins of Life': ['beach', 'Route 4 · Route 5', None, [['Ruins of Life', 'ruins'], ['Hano Beach', 'beach']]],
    'Brooklet Hill': ['grass', 'Route 5', ['Brooklet Hill', 'swamp'], []],
    'Wela Volcano Park': ['grass', 'Route 7', ['Wela Volcano Park', 'volcano'], []],
    'Lush Jungle': ['grass', 'Route 8', ['Lush Jungle', 'forest'], []],
    'Malie City': ['city', 'Route 10 · Route 11', ['Blush Mountain', 'plant'], [['Malie Garden', 'flowers'], ['Malie Library', 'ruins']]],
    'Hokulani Observatory': ['mountain', 'Mount Hokulani', None, [['Hokulani Observatory', 'plant']]],
    'Seafolk Village': ['water', 'Route 15', None, [['Seafolk Village Pier', 'beach']]],
    'Vast Poni Canyon': ['mountain', 'Poni Plains', ['Vast Poni Canyon', 'cave'], []],
    'Mount Lanakila': ['snow', 'Route 17 · Mount Lanakila', ['Mount Lanakila', 'icecave'], []],
    # Galar
    'Turffield': ['grass', 'Route 1 · Wild Area · Route 3', ['Galar Mine', 'cave'], [['Turffield Geoglyph', 'ruins']]],
    'Hulbury': ['grass', 'Route 4 · Route 5', ['Galar Mine No. 2', 'cave'], [['Hulbury Harbor', 'beach']]],
    'Motostoke': ['grass', 'Motostoke Riverbank', ['Wild Area', 'grass'], []],
    'Stow-on-Side': ['desert', 'Route 6', None, [['Stow-on-Side Ruins', 'ruins']]],
    'Ballonlea': ['forest', 'Glimwood Tangle', ['Glimwood Tangle', 'forest'], []],
    'Circhester': ['snow', 'Route 8', ['Route 8 Ruins', 'ruins'], []],
    'Spikemuth': ['beach', 'Route 9', ['Route 9 Tunnel', 'cave'], [['Spikemuth Back Alley', 'sewer']]],
    'Hammerlocke': ['city', 'Route 9 · Route 10', None, [['Energy Plant', 'plant'], ['Hammerlocke Vault', 'ruins']]],
    'Wyndon': ['snow', 'Route 10', None, [['Rose Tower', 'tower']]],
    # Paldea
    'Cortondo': ['grass', 'South Province (Area One)', ['Inlet Grotto', 'cave'], []],
    'Artazon': ['flowers', 'South Province (Area Three)', None, []],
    'Levincia': ['beach', 'East Province (Area One)', None, [['Team Star Dark Crew', 'base-star'], ['Levincia Beach', 'beach']]],
    'Cascarrafa': ['desert', 'Asado Desert', ['Asado Desert', 'dunes'], []],
    'Medali': ['grass', 'West Province (Area Two)', None, []],
    'Montenevera': ['mountain', 'Glaseado Mountain', ['Dalizapa Passage', 'icecave'], []],
    'Alfornada': ['mountain', 'South Province (Area Six)', ['Alfornada Cavern', 'cave'], [['Team Star Fighting Crew', 'base-star']]],
    'Glaseado': ['snow', 'Glaseado Mountain', ['Dalizapa Passage', 'icecave'], []],
    'Paldea:Pokémon League': ['grass', 'West Province (Area One)', ['Area Zero', 'crystal'], []],
}

FEATURES = {
    'Pewter City': {'trade': [63, 122], 'museum': {'pewter-museum': [138, 140, 142]}},
    'Cerulean City': {'trade': [61, 124], 'gifts': [{'id': 1}]},
    'Vermilion City': {'water': 'sea', 'daycare': True, 'trade': [21, 83], 'gifts': [{'id': 7}]},
    'Celadon City': {
        'gifts': [{'id': 133}],
        'keys': {'rocket-hideout': 'silph-scope', 'pok-mon-tower': 'poke-flute'},
        'needs': {'pok-mon-tower': 'silph-scope'},
        'corner': {'name': 'Rocket Game Corner', 'prizes': [[63, 18], [35, 50], [30, 120], [33, 120], [147, 280], [123, 550], [127, 550], [137, 1000]]},
        'store': {'name': 'Celadon Department Store', 'stock': ['evo:fire-stone', 'evo:water-stone', 'evo:thunder-stone', 'evo:leaf-stone', 'evo:moon-stone',
                                                                 'hp-up', 'protein', 'iron', 'calcium', 'carbos', 'tm:ice-beam', 'tm:thunderbolt', 'tm:flamethrower',
                                                                 'super-potion', 'hyper-potion']},
    },
    'Fuchsia City': {'water': 'sea', 'safari': 'Safari Zone', 'trade': [55, 108], 'blocker': {'id': 143, 'item': 'poke-flute'}, 'tutors': ['deleter']},
    'Saffron City': {'legends': {'power-plant': 145}, 'gifts': [{'id': 131, 'after': 'silph-co-'}, {'choose': [106, 107], 'after': 'fighting-dojo'}], 'rewards': {'silph-co-': 'master-ball'}},
    'Cinnabar Island': {'water': 'sea', 'trade': [48, 114], 'legends': {'seafoam-islands': 144}, 'tutors': ['reminder']},
    'Viridian City': {'water': 'sea'},
    'Indigo Plateau': {'routeLegend': 146},
    'Seafoam Islands': {'water': 'sea', 'legends': {'seafoam-islands': 144}},
    'Violet City': {'trade': [69, 95], 'gifts': [{'id': 175, 'egg': True}]},
    'Goldenrod City': {
        'daycare': True, 'trade': [96, 66], 'gifts': [{'id': 133}], 'keys': {'gym': 'squirt-bottle'}, 'rewards': {'radio-tower': 'max-revive'},
        'corner': {'name': 'Goldenrod Game Corner', 'prizes': [[63, 20], [23, 70], [27, 70], [147, 210]]},
        'store': {'name': 'Goldenrod Department Store', 'stock': ['evo:fire-stone', 'evo:water-stone', 'evo:thunder-stone', 'evo:leaf-stone', 'hp-up', 'protein', 'iron',
                                                                   'calcium', 'carbos', 'tm:dig', 'tm:body-slam', 'tm:double-edge', 'hyper-potion', 'revive']},
    },
    'Ecruteak City': {'blocker': {'id': 185, 'item': 'squirt-bottle'}},
    'Olivine City': {'water': 'sea', 'trade': [98, 100]},
    'Cianwood City': {'water': 'sea', 'fall': True, 'safari': 'Safari Zone', 'gifts': [{'id': 213}]},
    'Blackthorn City': {'trade': [148, 85], 'legends': {'lake-of-rage': {'id': 130, 'shiny': True}}, 'gifts': [{'id': 147, 'after': 'dragon-s-den'}], 'tutors': ['deleter', 'reminder']},
    'Rustboro City': {'trade': [287, 296], 'museum': {'devon-corporation': [345, 347]}},
    'Dewford Town': {'water': 'sea'},
    'Mauville City': {
        'water': 'sea', 'daycare': True,
        'corner': {'name': 'Mauville Game Corner', 'prizes': [['tm:shadow-ball', 150], ['tm:psychic', 350], ['tm:flamethrower', 400], ['tm:thunderbolt', 400], ['tm:ice-beam', 400]]},
    },
    'Lavaridge Town': {'gifts': [{'id': 360, 'egg': True}], 'tutors': ['reminder', 'heart-scale']},
    'Fortree City': {'trade': [25, 300], 'gifts': [{'id': 351, 'after': 'weather-institute'}]},
    'Mossdeep City': {'water': 'deep', 'safari': 'Safari Zone', 'gifts': [{'id': 374}], 'tutors': ['deleter']},
    'Sootopolis City': {'water': 'cave', 'fall': True},
    'Oreburgh City': {'trade': [66, 63], 'museum': {'oreburgh-mining-museum': [408, 410]}},
    'Eterna City': {'trade': [418, 441], 'gifts': [{'id': 175, 'egg': True}]},
    'Hearthome City': {'gifts': [{'id': 133}]},
    'Veilstone City': {
        'daycare': True, 'rewards': {'galactic-hq': 'master-ball'},
        'corner': {'name': 'Veilstone Game Corner', 'prizes': [['tm:dark-pulse', 200], ['tm:earthquake', 400], ['tm:thunderbolt', 400], ['tm:ice-beam', 400], ['tm:flamethrower', 400]]},
        'store': {'name': 'Veilstone Department Store', 'stock': ['hp-up', 'protein', 'iron', 'calcium', 'zinc', 'carbos', 'tm:shadow-ball', 'tm:earthquake', 'tm:psychic',
                                                                   'tm:energy-ball', 'hyper-potion', 'max-potion', 'revive']},
    },
    'Pastoria City': {'water': 'sea', 'safari': 'Great Marsh', 'tutors': ['reminder', 'heart-scale']},
    'Canalave City': {'water': 'sea', 'gifts': [{'id': 447, 'egg': True, 'after': 'iron-island'}], 'tutors': ['deleter']},
    'Snowpoint City': {'trade': [308, 93]},
    'Sunyshore City': {'water': 'sea', 'fall': True},
    'Nacrene City': {'daycare': True, 'trade': [546, 548], 'museum': {'nacrene-museum': [564, 566]}},
    'Driftveil City': {'trade': [572, 550], 'gifts': [{'id': 570}]},
    'Mistralton City': {'tutors': ['deleter', 'reminder']},
    'Icirrus City': {'trade': [525, 587]},
    'Humilau City': {'water': 'deep', 'trade': [226, 465]},
    'Cyllage City': {'water': 'sea', 'daycare': True, 'trade': [370, 208]},
    'Shalour City': {'water': 'sea', 'gifts': [{'id': 448, 'after': 'tower-of-mastery'}]},
    'Coumarine City': {'water': 'sea', 'museum': {'glittering-cave': [696, 698]}},
    'Lumiose City': {'tutors': ['deleter', 'reminder']},
    'Verdant Cavern': {'water': 'sea', 'trade': [21, 66]},
    'Ruins of Life': {'water': 'sea'},
    'Brooklet Hill': {'daycare': True, 'trade': [506, 761]},
    'Malie City': {'trade': [674, 440], 'tutors': ['deleter', 'reminder']},
    'Seafolk Village': {'water': 'sea', 'trade': [210, 762]},
    'Hulbury': {'daycare': True, 'trade': [572, 546], 'gifts': [{'id': 848, 'egg': True}]},
    'Motostoke': {'trade': [659, 819]},
    'Stow-on-Side': {'museum': {'stow-on-side-ruins': [880, 881, 882, 883]}},
    'Circhester': {'trade': [583, 538]},
    'Spikemuth': {'water': 'sea'},
    'Hammerlocke': {'trade': [848, 175]},
    'Wyndon': {'trade': [873, 884], 'gifts': [{'id': 772}]},
    # Paldea (os ovos vêm do piquenique: dá em qualquer cidade)
    'Cortondo': {'daycare': True, 'trade': [669, 872]},
    'Artazon': {'daycare': True},
    'Levincia': {'water': 'sea', 'daycare': True, 'trade': [871, 93]},
    'Cascarrafa': {'daycare': True},
    'Medali': {'daycare': True},
    'Montenevera': {'daycare': True},
    'Alfornada': {'daycare': True},
    'Glaseado': {'daycare': True},
}


# O clima único de cada rota e lugar, como nos jogos: 'route' é a rota até a cidade; as outras chaves são os lugares
# (o mesmo id do jogo). w: o clima (sun, rain, sand, snow); f: o efeito do lugar (diamonds, rockfall, ashes, miasma,
# chill, haunt, current, spores, quicksand, storm, aurora, grassy, electric, misty, psychic, wind). [nome, chance].
# Onde não há nada aqui, vale o clima normal do tipo de lugar.
CLIMATE = {
    # Kanto
    'Cerulean City': {'mt--moon': {'f': [['diamonds', 0.7]]}},                      # as Moon Stones caindo do teto
    'Celadon City': {'pok-mon-tower': {'f': [['haunt', 0.9]]}},                      # os fantasmas da torre
    'Saffron City': {'power-plant': {'f': [['electric', 0.9]]}},     # a usina do Zapdos
    'Cinnabar Island': {'seafoam-islands': {'f': [['chill', 0.6], ['current', 0.3]]}, 'pok-mon-mansion': {'f': [['ashes', 0.5]]}},
    'Seafoam Islands': {'seafoam-islands': {'f': [['chill', 0.6], ['current', 0.3]]}},
    'Indigo Plateau': {'cerulean-cave': {'f': [['psychic', 0.7]]}},                  # a caverna do Mewtwo
    # Johto
    'Violet City': {'ruins-of-alph': {'f': [['psychic', 0.7]]}, 'sprout-tower': {'f': [['grassy', 0.5]]}},
    'Ecruteak City': {'burned-tower': {'f': [['ashes', 0.7]]}},
    'Olivine City': {'glitter-lighthouse': {'f': [['electric', 0.6]]}},
    'Cianwood City': {'route': {'w': [['rain', 0.6]]}, 'whirl-islands': {'f': [['current', 0.8]]}},
    'Mahogany Town': {'mt--mortar': {'f': [['rockfall', 0.5]]}},
    'Blackthorn City': {'route': {'f': [['chill', 0.6]]}, 'lake-of-rage': {'w': [['rain', 1.0]]}},   # chove sem parar no Lake of Rage
    # Hoenn
    'Dewford Town': {'granite-cave': {'f': [['rockfall', 0.4]]}},
    'Mauville City': {'new-mauville': {'f': [['electric', 0.8]]}},
    'Lavaridge Town': {'route': {'f': [['ashes', 0.7]]}, 'fiery-path': {'f': [['ashes', 0.7]]}},     # as cinzas da Route 113
    'Petalburg City': {'route': {'w': [['sand', 0.9]]}},                                             # o deserto da Route 111
    'Fortree City': {'route': {'w': [['rain', 0.85]]}, 'weather-institute': {'f': [['electric', 0.5]]}},  # a chuva da Route 119
    'Mossdeep City': {'shoal-cave': {'f': [['chill', 0.5], ['current', 0.3]]}},
    'Sootopolis City': {'route': {'w': [['rain', 0.5], ['sun', 0.3]]}, 'seafloor-cavern': {'f': [['current', 0.8]]}},  # Kyogre e Groudon
    'Ever Grande City': {'sky-pillar': {'f': [['wind', 0.9]]}},                                      # o Rayquaza
    # Sinnoh
    'Hearthome City': {'mt--coronet': {'w': [['snow', 0.4]], 'f': [['rockfall', 0.4]]}},
    'Veilstone City': {'route': {'w': [['rain', 0.5]], 'f': [['misty', 0.5]]}, 'lost-tower': {'f': [['haunt', 0.8]]}},  # a neblina da 210 e a chuva da 215
    'Pastoria City': {'route': {'w': [['rain', 0.7]]}},
    'Canalave City': {'iron-island': {'f': [['rockfall', 0.4]]}},
    'Snowpoint City': {'route': {'w': [['snow', 0.9]], 'f': [['diamonds', 0.5]]}, 'lake-acuity': {'w': [['snow', 0.8]], 'f': [['aurora', 0.5]]}},  # o Diamond Dust de Snowpoint
    'Sunyshore City': {'vista-lighthouse': {'f': [['electric', 0.6]]}},
    'Sinnoh:Pokémon League': {'spear-pillar': {'f': [['psychic', 0.6]]}},
    # Unova
    'Nimbasa City': {'route': {'w': [['sand', 0.9]]}, 'relic-castle': {'f': [['quicksand', 0.8]]}},  # o Desert Resort
    'Driftveil City': {'cold-storage': {'f': [['chill', 0.8]]}},
    'Mistralton City': {'chargestone-cave': {'f': [['electric', 0.9]]}},
    'Icirrus City': {'route': {'w': [['snow', 0.6]]}, 'twist-mountain': {'f': [['chill', 0.6]]}, 'dragonspiral-tower': {'f': [['electric', 0.5]]}},
    'Opelucid City': {'route': {'w': [['rain', 0.5]]}, 'moor-of-icirrus': {'w': [['rain', 0.5]], 'f': [['miasma', 0.4]]}},
    'Virbank City': {'virbank-complex': {'f': [['miasma', 0.5]]}},
    'Unova:Pokémon League': {'giant-chasm': {'f': [['chill', 0.8]]}},
    # Kalos
    'Shalour City': {'reflection-cave': {'f': [['diamonds', 0.6]]}},
    'Coumarine City': {'glittering-cave': {'f': [['diamonds', 0.8]]}},
    'Lumiose City': {'route': {'w': [['sand', 0.8]]}, 'kalos-power-plant': {'f': [['electric', 0.8]]}},  # as Lumiose Badlands
    'Laverre City': {'route': {'w': [['rain', 0.6]], 'f': [['miasma', 0.3]]}, 'lost-hotel': {'f': [['haunt', 0.6]]}},
    'Anistar City': {'frost-cavern': {'f': [['chill', 0.8]]}},
    'Snowbelle City': {'route': {'w': [['snow', 0.9]]}},                                             # a Mamoswine Road
    # Alola
    'Brooklet Hill': {'brooklet-hill': {'w': [['rain', 0.7]]}},
    'Wela Volcano Park': {'wela-volcano-park': {'f': [['ashes', 0.7]]}},
    'Lush Jungle': {'lush-jungle': {'f': [['spores', 0.6]]}},
    'Malie City': {'route': {'w': [['rain', 0.5]]}, 'blush-mountain': {'f': [['electric', 0.7]]}},
    'Hokulani Observatory': {'hokulani-observatory': {'f': [['electric', 0.6]]}},
    'Vast Poni Canyon': {'vast-poni-canyon': {'f': [['rockfall', 0.6]]}},
    'Mount Lanakila': {'route': {'w': [['snow', 0.9]]}, 'mount-lanakila': {'f': [['chill', 0.7]]}},
    # Galar
    'Turffield': {'galar-mine': {'f': [['diamonds', 0.5]]}},
    'Motostoke': {'wild-area': {'w': [['sun', 0.2], ['rain', 0.2], ['snow', 0.12], ['sand', 0.12]], 'f': [['storm', 0.2], ['misty', 0.2]]}},  # a Wild Area tem todos os climas dos jogos: sol forte, chuva, trovoada, neve, tempestade de areia e neblina
    'Stow-on-Side': {'route': {'w': [['sand', 0.6]]}},
    'Ballonlea': {'route': {'f': [['misty', 0.7]]}, 'glimwood-tangle': {'f': [['misty', 0.5], ['spores', 0.4]]}},
    'Circhester': {'route': {'w': [['snow', 0.8]]}},
    'Hammerlocke': {'energy-plant': {'f': [['electric', 0.7]]}},
    'Wyndon': {'route': {'w': [['snow', 0.8]]}},
    # Paldea
    'Cascarrafa': {'route': {'w': [['sand', 0.9]]}, 'asado-desert': {'w': [['sand', 0.9]], 'f': [['quicksand', 0.4]]}},
    'Montenevera': {'route': {'w': [['snow', 0.8]]}, 'dalizapa-passage': {'f': [['chill', 0.6]]}},
    'Glaseado': {'route': {'w': [['snow', 0.9]]}, 'dalizapa-passage': {'f': [['chill', 0.6]]}},
    'Paldea:Pokémon League': {'area-zero': {'f': [['diamonds', 0.7]]}},                              # os cristais Tera da Area Zero
}
for _city, _climate in CLIMATE.items():
    FEATURES.setdefault(_city, {})['climate'] = _climate


# O cenário de cada cidade ou vila, pela descrição dela nos jogos (o fundo que aparece na cidade e nas batalhas dela):
# vila pequena, porto, metrópole, neve, montanha, ilha, cidade histórica, floresta, flores, deserto, industrial, na água,
# vulcão e a entrada da Liga. Sem nada aqui, a cidade genérica.
TOWNS = {
    'village': ['Fuchsia City', 'Viridian City', 'Azalea Town', 'Mahogany Town', 'Petalburg City', 'Striaton City', 'Aspertia City', 'Santalune City', 'Medali'],
    'port': ['Vermilion City', 'Olivine City', 'Canalave City', 'Sunyshore City', 'Driftveil City', 'Shalour City', 'Coumarine City', 'Seafolk Village', 'Hulbury'],
    'metro': ['Celadon City', 'Saffron City', 'Goldenrod City', 'Rustboro City', 'Mauville City', 'Hearthome City', 'Castelia City', 'Nimbasa City', 'Lumiose City', 'Wyndon', 'Levincia'],
    'snow': ['Snowpoint City', 'Icirrus City', 'Snowbelle City', 'Mount Lanakila', 'Circhester', 'Montenevera', 'Glaseado'],
    'mountain': ['Pewter City', 'Blackthorn City', 'Veilstone City', 'Mistralton City', 'Cyllage City', 'Hokulani Observatory', 'Vast Poni Canyon', 'Alfornada'],
    'island': ['Seafoam Islands', 'Cianwood City', 'Dewford Town', 'Mossdeep City', 'Humilau City', 'Verdant Cavern', 'Iki Town', 'Ruins of Life', 'Brooklet Hill'],
    'old': ['Violet City', 'Ecruteak City', 'Eterna City', 'Opelucid City', 'Anistar City', 'Malie City', 'Hammerlocke'],
    'forest': ['Fortree City', 'Laverre City', 'Lush Jungle', 'Ballonlea'],
    'flower': ['Turffield', 'Cortondo', 'Artazon'],
    'desert': ['Stow-on-Side', 'Cascarrafa'],
    'industrial': ['Oreburgh City', 'Nacrene City', 'Virbank City', 'Motostoke', 'Spikemuth'],
    'water': ['Cerulean City', 'Sootopolis City', 'Pastoria City'],
    'volcano': ['Cinnabar Island', 'Lavaridge Town', 'Wela Volcano Park'],
    'league': ['Indigo Plateau', 'Ever Grande City', 'Sinnoh:Pokémon League', 'Unova:Pokémon League', 'Kalos:Pokémon League', 'Paldea:Pokémon League'],
}
for _kind, _cities in TOWNS.items():
    for _city in _cities:
        FEATURES.setdefault(_city, {})['town'] = _kind

TUTOR_EVERYWHERE = ['Galar', 'Paldea']

RARE = {
    'Kanto': ['cerulean-cave', 'navel-rock'],
    'Johto': ['bell-tower'],
    'Hoenn': ['faraway-island'],
    'Sinnoh': ['distortion-world'],
    'Unova': ['liberty-garden'],
    'Kalos': ['sea-spirit-s-den'],
    'Alola': ['ruins-of-conflict'],
    'Galar': ['crown-shrine'],
    'Paldea': ['grasswither-shrine'],
}

START = {
    'Kanto': 'Pallet Town',
    'Johto': 'New Bark Town',
    'Hoenn': 'Littleroot Town',
    'Sinnoh': 'Twinleaf Town',
    'Unova': 'Nuvema Town',
    'Black 2/White 2': 'Aspertia City',
    'Kalos': 'Vaniville Town',
    'Alola': "Hau'oli City",
    'Galar': 'Postwick',
    'Paldea': 'Cabo Poco',
}
