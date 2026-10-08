"""Dados da Battle Factory (o modo de subir andares com um inicial).

Saída: assets/database/factory.json
  {"species": {id: [xp base, total de atributos, raridade]},
   "evolutions": {id: [[evolui para, nível], ...]},
   "starters": [ids dos iniciais grátis]}
raridade: 0 comum, 1 lendário, 2 mítico, 3 bebê.
Evoluções que não são por nível (pedra, troca, amizade...) ganham um nível
fixo para o time poder evoluir no modo.

Uso: python3 tool/build_factory_data.py
"""

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(ROOT, 'assets', 'database')
MAX_SPECIES = 1025
STARTERS = [1, 4, 7, 152, 155, 158, 252, 255, 258, 387, 390, 393, 495, 498, 501, 650, 653, 656, 722, 725, 728, 810, 813, 816,
            906, 909, 912]
# Nível para as evoluções que não são por nível.
OTHER_TRIGGER = {'use-item': 30, 'trade': 36}
DEFAULT_OTHER = 25


def load(name):
    with open(os.path.join(DB, f'{name}.json'), encoding='utf-8') as f:
        return json.load(f)


def main():
    pokemon = {p['id']: p for p in load('pokemon') if p['is_default'] and p['id'] <= MAX_SPECIES}
    species = {s['id']: s for s in load('species') if s['id'] <= MAX_SPECIES}
    out_species = {}
    for sid, s in species.items():
        p = pokemon.get(sid)
        if not p:
            continue
        bst = sum(stat[0] for stat in p['stats'])
        rarity = 1 if s['is_legendary'] else 2 if s['is_mythical'] else 3 if s['is_baby'] else 0
        out_species[sid] = [p['base_experience'] or 50, bst, rarity]
    evolutions = {}

    def walk(node):
        for nxt in node['evolves_to']:
            d = nxt.get('details') or {}
            level = d.get('min_level') or OTHER_TRIGGER.get(d.get('trigger'), DEFAULT_OTHER)
            if node['species'] in out_species and nxt['species'] in out_species:
                evolutions.setdefault(node['species'], []).append([nxt['species'], level])
            walk(nxt)

    for chain in load('evolution_chains').values():
        walk(chain)
    data = {'species': out_species, 'evolutions': evolutions, 'starters': STARTERS}
    with open(os.path.join(DB, 'factory.json'), 'w', encoding='utf-8') as f:
        json.dump(data, f, separators=(',', ':'))
        f.write('\n')
    print(len(out_species), 'espécies,', len(evolutions), 'com evolução')


if __name__ == '__main__':
    main()
