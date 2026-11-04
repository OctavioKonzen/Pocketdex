"""Desafio dos Líderes: líderes de ginásio, Elite Four e campeões de cada
região com o time original do primeiro jogo da região (mesma quantidade de
Pokémon), cada um na evolução final, todos no nível 50 (os sets do
computador, npc_sets.json).

Saída: assets/database/gym_leaders.json
    [{"region", "leaders": [{"id", "name", "kind" (gym|elite|champion|kahuna),
      "type", "trainer" (trainers.json), "team": [id do Pokémon]}]}]

Uso: python3 tool/build_gym_leaders.py
"""

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(ROOT, 'assets', 'database')

# (id, nome, tipo, treinador, time) por região. kind: gym / elite / champion / kahuna.
REGIONS = [
    ('Kanto', [
        ('gym', 'brock', 'Brock', 'rock', 'brock', 'golem steelix'),
        ('gym', 'misty', 'Misty', 'water', 'misty', 'starmie starmie'),
        ('gym', 'lt-surge', 'Lt. Surge', 'electric', 'lt-surge', 'electrode raichu raichu'),
        ('gym', 'erika', 'Erika', 'grass', 'erika', 'victreebel tangrowth vileplume'),
        ('gym', 'koga', 'Koga', 'poison', 'koga', 'weezing muk weezing weezing'),
        ('gym', 'sabrina', 'Sabrina', 'psychic', 'sabrina', 'alakazam mr-mime venomoth alakazam'),
        ('gym', 'blaine', 'Blaine', 'fire', 'blaine', 'arcanine rapidash rapidash arcanine'),
        ('gym', 'giovanni', 'Giovanni', 'ground', 'giovanni', 'rhyperior dugtrio nidoqueen nidoking rhyperior'),
        ('elite', 'lorelei', 'Lorelei', 'ice', 'lorelei', 'dewgong cloyster slowbro jynx lapras'),
        ('elite', 'bruno', 'Bruno', 'fighting', 'bruno', 'steelix hitmonchan hitmonlee steelix machamp'),
        ('elite', 'agatha', 'Agatha', 'ghost', 'agatha', 'gengar crobat gengar arbok gengar'),
        ('elite', 'lance', 'Lance', 'dragon', 'lance', 'gyarados dragonite dragonite aerodactyl dragonite'),
        ('champion', 'blue', 'Blue', '', 'champion-blue', 'pidgeot alakazam rhyperior exeggutor gyarados charizard'),
    ]),
    ('Johto', [
        ('gym', 'falkner', 'Falkner', 'flying', 'falkner', 'pidgeot pidgeot'),
        ('gym', 'bugsy', 'Bugsy', 'bug', 'bugsy', 'butterfree beedrill scizor'),
        ('gym', 'whitney', 'Whitney', 'normal', 'whitney', 'clefable miltank'),
        ('gym', 'morty', 'Morty', 'ghost', 'morty', 'gengar gengar gengar gengar'),
        ('gym', 'chuck', 'Chuck', 'fighting', 'chuck', 'annihilape poliwrath'),
        ('gym', 'jasmine', 'Jasmine', 'steel', 'jasmine', 'magnezone magnezone steelix'),
        ('gym', 'pryce', 'Pryce', 'ice', 'pryce', 'dewgong dewgong mamoswine'),
        ('gym', 'clair', 'Clair', 'dragon', 'clair', 'dragonite dragonite dragonite kingdra'),
        ('elite', 'will', 'Will', 'psychic', 'will', 'xatu jynx exeggutor slowbro xatu'),
        ('elite', 'koga', 'Koga', 'poison', 'koga', 'ariados venomoth forretress muk crobat'),
        ('elite', 'bruno', 'Bruno', 'fighting', 'bruno', 'hitmontop hitmonlee hitmonchan steelix machamp'),
        ('elite', 'karen', 'Karen', 'dark', 'karen', 'umbreon vileplume gengar honchkrow houndoom'),
        ('champion', 'lance', 'Lance', 'dragon', 'champion-lance', 'gyarados dragonite dragonite aerodactyl charizard dragonite'),
    ]),
    ('Hoenn', [
        ('gym', 'roxanne', 'Roxanne', 'rock', 'roxanne', 'golem probopass'),
        ('gym', 'brawly', 'Brawly', 'fighting', 'brawly', 'machamp hariyama'),
        ('gym', 'wattson', 'Wattson', 'electric', 'wattson', 'magnezone electrode magnezone'),
        ('gym', 'flannery', 'Flannery', 'fire', 'flannery', 'magcargo magcargo torkoal'),
        ('gym', 'norman', 'Norman', 'normal', 'norman', 'spinda slaking linoone slaking'),
        ('gym', 'winona', 'Winona', 'flying', 'winona', 'swellow pelipper skarmory altaria'),
        ('gym', 'tate-liza', 'Tate & Liza', 'psychic', 'tate-liza', 'lunatone solrock'),
        ('gym', 'wallace', 'Wallace', 'water', 'wallace', 'luvdisc whiscash walrein seaking milotic'),
        ('elite', 'sidney', 'Sidney', 'dark', 'sd-sidney', 'mightyena shiftry cacturne crawdaunt absol'),
        ('elite', 'phoebe', 'Phoebe', 'ghost', 'sd-phoebe-gen6', 'dusknoir banette sableye banette dusknoir'),
        ('elite', 'glacia', 'Glacia', 'ice', 'sd-glacia', 'walrein glalie walrein glalie walrein'),
        ('elite', 'drake', 'Drake', 'dragon', 'sd-drake-gen3', 'salamence altaria kingdra flygon salamence'),
        ('champion', 'steven', 'Steven', '', 'steven', 'skarmory claydol aggron cradily armaldo metagross'),
    ]),
    ('Sinnoh', [
        ('gym', 'roark', 'Roark', 'rock', 'roark', 'golem steelix rampardos'),
        ('gym', 'gardenia', 'Gardenia', 'grass', 'gardenia', 'cherrim torterra roserade'),
        ('gym', 'maylene', 'Maylene', 'fighting', 'maylene', 'medicham machamp lucario'),
        ('gym', 'wake', 'Crasher Wake', 'water', 'wake', 'gyarados quagsire floatzel'),
        ('gym', 'fantina', 'Fantina', 'ghost', 'fantina', 'drifblim gengar mismagius'),
        ('gym', 'byron', 'Byron', 'steel', 'byron', 'bronzong steelix bastiodon'),
        ('gym', 'candice', 'Candice', 'ice', 'candice', 'weavile mamoswine abomasnow froslass'),
        ('gym', 'volkner', 'Volkner', 'electric', 'volkner', 'raichu ambipom octillery luxray'),
        ('elite', 'aaron', 'Aaron', 'bug', 'aaron', 'dustox beautifly vespiquen heracross drapion'),
        ('elite', 'bertha', 'Bertha', 'ground', 'bertha', 'quagsire sudowoodo golem whiscash hippowdon'),
        ('elite', 'flint', 'Flint', 'fire', 'flint', 'rapidash infernape steelix lopunny drifblim'),
        ('elite', 'lucian', 'Lucian', 'psychic', 'lucian', 'mr-mime farigiraf medicham alakazam bronzong'),
        ('champion', 'cynthia', 'Cynthia', '', 'cynthia', 'spiritomb roserade gastrodon lucario milotic garchomp'),
    ]),
    ('Unova', [
        ('gym', 'cilan', 'Cilan', 'grass', 'cilan', 'stoutland simisage'),
        ('gym', 'chili', 'Chili', 'fire', 'chili', 'stoutland simisear'),
        ('gym', 'cress', 'Cress', 'water', 'cress', 'stoutland simipour'),
        ('gym', 'lenora', 'Lenora', 'normal', 'lenora', 'stoutland watchog'),
        ('gym', 'burgh', 'Burgh', 'bug', 'burgh', 'scolipede crustle leavanny'),
        ('gym', 'elesa', 'Elesa', 'electric', 'elesa', 'emolga emolga zebstrika'),
        ('gym', 'clay', 'Clay', 'ground', 'clay', 'krookodile seismitoad excadrill'),
        ('gym', 'skyla', 'Skyla', 'flying', 'skyla', 'swoobat unfezant swanna'),
        ('gym', 'brycen', 'Brycen', 'ice', 'brycen', 'vanilluxe cryogonal beartic'),
        ('gym', 'drayden', 'Drayden', 'dragon', 'drayden', 'haxorus druddigon haxorus'),
        ('gym', 'cheren', 'Cheren', 'normal', 'cheren-leader', 'watchog stoutland'),
        ('gym', 'roxie', 'Roxie', 'poison', 'roxie', 'weezing scolipede'),
        ('gym', 'marlon', 'Marlon', 'water', 'marlon', 'carracosta wailord jellicent'),
        ('elite', 'shauntal', 'Shauntal', 'ghost', 'shauntal', 'cofagrigus jellicent golurk chandelure'),
        ('elite', 'grimsley', 'Grimsley', 'dark', 'grimsley', 'scrafty liepard krookodile kingambit'),
        ('elite', 'caitlin', 'Caitlin', 'psychic', 'caitlin', 'musharna sigilyph reuniclus gothitelle'),
        ('elite', 'marshal', 'Marshal', 'fighting', 'marshal', 'throh sawk mienshao conkeldurr'),
        ('champion', 'alder', 'Alder', '', 'alder', 'accelgor bouffalant druddigon vanilluxe escavalier volcarona'),
        ('champion', 'iris', 'Iris', '', 'iris', 'hydreigon druddigon aggron archeops lapras haxorus'),
    ]),
    ('Kalos', [
        ('gym', 'viola', 'Viola', 'bug', 'sd-viola', 'masquerain vivillon'),
        ('gym', 'grant', 'Grant', 'rock', 'sd-grant', 'aurorus tyrantrum'),
        ('gym', 'korrina', 'Korrina', 'fighting', 'sd-korrina', 'mienshao machamp hawlucha'),
        ('gym', 'ramos', 'Ramos', 'grass', 'sd-ramos', 'jumpluff victreebel gogoat'),
        ('gym', 'clemont', 'Clemont', 'electric', 'sd-clemont', 'emolga magnezone heliolisk'),
        ('gym', 'valerie', 'Valerie', 'fairy', 'sd-valerie', 'mawile mr-mime sylveon'),
        ('gym', 'olympia', 'Olympia', 'psychic', 'sd-olympia', 'sigilyph slowking meowstic'),
        ('gym', 'wulfric', 'Wulfric', 'ice', 'sd-wulfric', 'abomasnow cryogonal avalugg'),
        ('elite', 'malva', 'Malva', 'fire', 'sd-malva', 'pyroar torkoal chandelure talonflame'),
        ('elite', 'siebold', 'Siebold', 'water', 'sd-siebold', 'clawitzer gyarados starmie barbaracle'),
        ('elite', 'wikstrom', 'Wikstrom', 'steel', 'sd-wikstrom', 'klefki probopass scizor aegislash'),
        ('elite', 'drasna', 'Drasna', 'dragon', 'sd-drasna', 'dragalge druddigon altaria noivern'),
        ('champion', 'diantha', 'Diantha', '', 'sd-diantha', 'hawlucha tyrantrum aurorus gourgeist goodra gardevoir'),
    ]),
    ('Alola', [
        ('kahuna', 'hala', 'Hala', 'fighting', 'sd-hala', 'annihilape hariyama crabominable'),
        ('kahuna', 'olivia', 'Olivia', 'rock', 'sd-olivia', 'probopass gigalith lycanroc-midnight'),
        ('kahuna', 'nanu', 'Nanu', 'dark', 'sd-nanu', 'sableye krookodile persian-alola'),
        ('kahuna', 'hapu', 'Hapu', 'ground', 'sd-hapu', 'dugtrio-alola gastrodon flygon mudsdale'),
        ('champion', 'kukui', 'Kukui', '', 'sd-kukui', 'lycanroc-midday ninetales-alola braviary magnezone snorlax primarina'),
    ]),
    ('Galar', [
        ('gym', 'milo', 'Milo', 'grass', 'sd-milo', 'eldegoss eldegoss'),
        ('gym', 'nessa', 'Nessa', 'water', 'sd-nessa', 'seaking barraskewda drednaw'),
        ('gym', 'kabu', 'Kabu', 'fire', 'sd-kabu', 'ninetales arcanine centiskorch'),
        ('gym', 'bea', 'Bea', 'fighting', 'sd-bea', 'hitmontop pangoro sirfetchd machamp'),
        ('gym', 'allister', 'Allister', 'ghost', 'sd-allister', 'runerigus mimikyu cursola gengar'),
        ('gym', 'opal', 'Opal', 'fairy', 'sd-opal', 'weezing-galar mawile togekiss alcremie'),
        ('gym', 'gordie', 'Gordie', 'rock', 'sd-gordie', 'barbaracle shuckle stonjourner coalossal'),
        ('gym', 'melony', 'Melony', 'ice', 'sd-melony', 'frosmoth darmanitan-galar-standard eiscue lapras'),
        ('gym', 'piers', 'Piers', 'dark', 'sd-piers', 'scrafty malamar skuntank obstagoon'),
        ('gym', 'raihan', 'Raihan', 'dragon', 'sd-raihan', 'gigalith flygon sandaconda archaludon'),
        ('champion', 'leon', 'Leon', '', 'sd-leon', 'aegislash dragapult haxorus seismitoad mr-rime charizard'),
    ]),
    ('Paldea', [
        ('gym', 'katy', 'Katy', 'bug', 'sd-katy', 'lokix spidops ursaluna'),
        ('gym', 'brassius', 'Brassius', 'grass', 'sd-brassius', 'lilligant arboliva sudowoodo'),
        ('gym', 'iono', 'Iono', 'electric', 'sd-iono', 'kilowattrel bellibolt luxray mismagius'),
        ('gym', 'kofu', 'Kofu', 'water', 'sd-kofu', 'veluza wugtrio crabominable'),
        ('gym', 'larry', 'Larry', 'normal', 'sd-larry', 'komala dudunsparce staraptor'),
        ('gym', 'ryme', 'Ryme', 'ghost', 'sd-ryme', 'banette mimikyu houndstone toxtricity'),
        ('gym', 'tulip', 'Tulip', 'psychic', 'sd-tulip', 'farigiraf gardevoir espathra florges'),
        ('gym', 'grusha', 'Grusha', 'ice', 'sd-grusha', 'frosmoth beartic cetitan altaria'),
        ('elite', 'rika', 'Rika', 'ground', 'sd-rika', 'whiscash camerupt donphan dugtrio clodsire'),
        ('elite', 'poppy', 'Poppy', 'steel', 'sd-poppy', 'copperajah magnezone bronzong corviknight tinkaton'),
        ('elite', 'larry-elite', 'Larry', 'flying', 'sd-larry', 'tropius oricorio altaria staraptor flamigo'),
        ('elite', 'hassel', 'Hassel', 'dragon', 'sd-hassel', 'noivern haxorus dragalge flapple baxcalibur'),
        ('champion', 'geeta', 'Geeta', '', 'sd-geeta', 'espathra gogoat veluza avalugg kingambit glimmora'),
    ]),
]


def main():
    pokemon = json.load(open(os.path.join(DB, 'pokemon.json'), encoding='utf-8'))
    sets = json.load(open(os.path.join(DB, 'npc_sets.json'), encoding='utf-8'))
    trainers = {t['id'] for t in json.load(open(os.path.join(DB, 'trainers.json'), encoding='utf-8'))}
    by_name = {p['name']: p for p in pokemon}

    def resolve(name):
        p = by_name.get(name) or next((p for p in pokemon if p['is_default'] and p['name'].startswith(name + '-')), None)
        if not p:
            raise SystemExit(f'Pokémon desconhecido: {name}')
        if str(p['id']) not in sets:
            raise SystemExit(f'Sem set do computador: {name} ({p["id"]})')
        return p['id']

    out = []
    for region, leaders in REGIONS:
        rows = []
        for kind, lid, name, type_, trainer, team in leaders:
            if trainer not in trainers:
                raise SystemExit(f'Treinador desconhecido: {trainer}')
            ids = [resolve(n) for n in team.split()]
            assert 1 <= len(ids) <= 6, lid
            rows.append({'id': f'{region.lower()}-{lid}', 'name': name, 'kind': kind, 'type': type_, 'trainer': trainer, 'team': ids})
        out.append({'region': region, 'leaders': rows})
    with open(os.path.join(DB, 'gym_leaders.json'), 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, separators=(',', ':'))
        f.write('\n')
    print(sum(len(r['leaders']) for r in out), 'líderes em', len(out), 'regiões')


if __name__ == '__main__':
    main()
