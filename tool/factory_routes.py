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

START: de onde a região começa (a cidade inicial do jogo). A chave é o jogo
quando ele começa em outro lugar (Black 2/White 2).
"""

CITIES = {
    # Kanto
    'Pewter City': ['grass', 'Route 1 · Route 2', ['Viridian Forest', 'forest'], [['Pewter Museum', 'ruins']]],
    'Cerulean City': ['mountain', 'Route 3 · Route 4', ['Mt. Moon', 'cave'], [['Nugget Bridge', 'city']]],
    'Vermilion City': ['grass', 'Route 5 · Route 6', ['Underground Path', 'sewer'], [['S.S. Anne', 'city'], ['Vermilion Harbor', 'beach']]],
    'Celadon City': ['cave', 'Route 9 · Rock Tunnel', ['Pokémon Tower', 'tower'],
                     [['Rocket Game Corner', 'city'], ['Rocket Hideout', 'base-rocket'], ['Celadon Department Store', 'city']]],
    'Fuchsia City': ['grass', 'Route 12 · Route 15', ['Safari Zone', 'swamp'], [['Fuchsia Beach', 'beach']]],
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
                       [['Goldenrod Tunnel', 'sewer'], ['Radio Tower', 'base-rocket'], ['Goldenrod Department Store', 'city']]],
    'Ecruteak City': ['grass', 'Route 35 · Route 36 · Route 37', ['National Park', 'flowers'], [['Burned Tower', 'tower'], ['Bell Tower', 'tower']]],
    'Olivine City': ['beach', 'Route 38 · Route 39', None, [['Glitter Lighthouse', 'tower'], ['Olivine Beach', 'beach']]],
    'Cianwood City': ['water', 'Route 40 · Route 41', ['Whirl Islands', 'cave'], [['Cianwood Beach', 'beach']]],
    'Mahogany Town': ['grass', 'Route 42', ['Mt. Mortar', 'cave'], [['Rocket Hideout', 'base-rocket']]],
    'Blackthorn City': ['icecave', 'Route 44 · Ice Path', ['Lake of Rage', 'swamp'], [["Dragon's Den", 'temple']]],
    # Hoenn
    'Rustboro City': ['grass', 'Route 101 · Route 102 · Route 104', ['Petalburg Woods', 'forest'], [['Devon Corporation', 'plant'], ["Trainers' School", 'city']]],
    'Dewford Town': ['water', 'Route 105 · Route 106', ['Granite Cave', 'cave'], [['Dewford Beach', 'beach']]],
    'Mauville City': ['beach', 'Route 109 · Route 110', ['New Mauville', 'plant'], [['Mauville Game Corner', 'city']]],
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
                       [['Galactic HQ', 'base-galactic'], ['Veilstone Department Store', 'city'], ['Veilstone Game Corner', 'city']]],
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
