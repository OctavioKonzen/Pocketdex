#!/usr/bin/env python3
"""Gera a animação de cada golpe da batalha (assets/database/move_anims.json).

Cada golpe de dano ganha a sua: [estilo, símbolo, variação].
  • estilo: o movimento (soco, jato, raio, onda, terremoto...), pelas regras
    de moveAnim.js / move_anim.dart ou pela receita feita à mão (RECIPES);
  • símbolo: tirado do próprio nome do golpe (Ice Punch 🧊, Sacred Sword ⚔️,
    Bone Rush 🦴, Petal Dance 🌸...) ou, se o nome não diz nada, o do tipo;
  • variação (0, 1, 2...): muda quantidade, caminho e giro das partículas;
    golpes com o mesmo estilo e símbolo ganham variações diferentes, então
    nenhum golpe tem a animação igual à de outro.
O site (public/data, por tool/build_web_data.py) e o app leem o mesmo arquivo.

Uso: python3 tool/build_move_anims.py
"""

import hashlib
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(ROOT, 'assets', 'database')

TYPE_PARTICLE = {
    'normal': '⭐', 'fire': '🔥', 'water': '💧', 'grass': '🍃', 'electric': '⚡', 'ice': '❄️', 'fighting': '💥', 'poison': '🟣',
    'ground': '🟤', 'flying': '🪶', 'psychic': '💫', 'bug': '🐛', 'rock': '🪨', 'ghost': '👻', 'dragon': '🐉', 'dark': '🌑',
    'steel': '⚙️', 'fairy': '✨', 'stellar': '🌟', 'shadow': '🖤',
}

# Palavra do nome → símbolo (a primeira palavra do golpe que tiver símbolo vale).
WORD_ICON = [
    (('leaf', 'leafage', 'leaves'), '🍃'), (('petal', 'flower', 'blossom', 'floral'), '🌸'), (('seed', 'nut'), '🌰'),
    (('wood', 'branch', 'trop'), '🪵'), (('vine', 'grass', 'grassy', 'power-whip'), '🌿'), (('solar', 'sun', 'sunsteel'), '☀️'),
    (('moon', 'moonblast', 'lunar', 'moongeist'), '🌙'), (('star', 'swift'), '🌟'), (('meteor', 'comet', 'draco'), '☄️'),
    (('rock', 'stone', 'rocks', 'boulder', 'gem', 'diamond', 'power-gem'), '🪨'), (('sand', 'mud', 'muddy', 'dirt'), '🟫'),
    (('earth', 'land', 'ground', 'precipice', 'headlong'), '🟤'), (('ice', 'icy', 'icicle', 'frost', 'freeze', 'glacial', 'cold'), '🧊'),
    (('snow', 'blizzard', 'hail', 'aurora', 'chilling'), '❄️'), (('surf', 'wave', 'tsunami'), '🌊'), (('bubble', 'foam', 'suds'), '🫧'),
    (('water', 'aqua', 'hydro', 'rain', 'scald', 'brine', 'dive', 'whirlpool', 'splash', 'jet'), '💧'),
    (('fire', 'flame', 'flare', 'blaze', 'blazing', 'heat', 'burn', 'burning', 'ember', 'inferno', 'lava', 'magma', 'eruption', 'overheat', 'pyro', 'sizzly'), '🔥'),
    (('thunder', 'volt', 'electro', 'electric', 'spark', 'zap', 'shock', 'bolt', 'discharge', 'plasma', 'zing'), '⚡'),
    (('psychic', 'psycho', 'psy', 'psyshock', 'psystrike', 'psybeam', 'mind', 'zen', 'future', 'extrasensory', 'confusion', 'esper', 'expanding'), '🔮'),
    (('dream',), '💤'), (('dark', 'night', 'darkest', 'foul', 'sucker', 'throat', 'lash', 'feint'), '🌑'),
    (('shadow', 'ghost', 'phantom', 'spirit', 'spite', 'hex', 'curse', 'poltergeist', 'astral', 'infernal', 'bitter', 'last-respects'), '👻'),
    (('poison', 'toxic', 'sludge', 'acid', 'venom', 'venoshock', 'gunk', 'smog', 'barb', 'cross-poison', 'mortal'), '☠️'),
    (('dragon', 'outrage', 'clanging', 'dynamax', 'breaking', 'dual-chop'), '🐉'),
    (('steel', 'iron', 'metal', 'gear', 'bullet', 'magnet', 'anchor', 'gigaton', 'doom'), '⚙️'), (('flash', 'mirror', 'luster', 'shine'), '💡'),
    (('heart', 'love', 'charm'), '💗'), (('kiss', 'draining-kiss'), '💋'),
    (('fairy', 'dazzling', 'gleam', 'sparkle', 'sparkling', 'play', 'spirit-break', 'strange', 'misty', 'mist', 'nature', 'fleur'), '✨'),
    (('wing', 'feather', 'air', 'aerial', 'aero', 'sky', 'brave', 'bird', 'peck', 'fly', 'dragon-ascent', 'beak', 'oblivion'), '🪶'),
    (('wind', 'gust', 'twister', 'hurricane', 'tornado', 'storm', 'bleakwind', 'razor-wind', 'cutter'), '🌪️'),
    (('bug', 'buzz', 'x-scissor', 'signal', 'attack-order', 'lunge', 'leech', 'pounce', 'skitter', 'fell', 'first'), '🐛'),
    (('web', 'string', 'sticky'), '🕸️'), (('bone', 'bonemerang', 'shadow-bone'), '🦴'), (('horn', 'megahorn', 'smart', 'drill'), '🔱'),
    (('sword', 'blade', 'sacred', 'cleave', 'saber', 'kowtow', 'secret-sword', 'solar-blade'), '⚔️'),
    (('punch', 'fist', 'hammer', 'mach', 'jab', 'arm', 'comet-punch', 'mega-punch', 'power-up'), '👊'),
    (('kick', 'foot', 'stomp', 'trop-kick', 'axe'), '🦶'), (('fang', 'bite', 'crunch', 'jaw', 'chomp'), '🦷'),
    (('tail', 'whip', 'slap', 'lash'), '〰️'), (('claw', 'slash', 'cut', 'swipe', 'scratch', 'fury'), '✴️'),
    (('egg',), '🥚'), (('coin', 'pay', 'gold', 'make-it-rain'), '🪙'), (('music', 'sing', 'voice', 'song', 'round', 'aria', 'boom', 'boomburst', 'echoed', 'uproar', 'snarl', 'roar', 'overdrive', 'relic'), '🎵'),
    (('drain', 'absorb', 'giga', 'mega-drain', 'horn-leech', 'parabolic'), '💚'), (('spike', 'needle', 'pin', 'spikes', 'thousand'), '📌'),
    (('whirl', 'vortex', 'spin', 'rapid', 'roll', 'rollout', 'gyro', 'twirl', 'cyclone'), '🌀'),
    (('explosion', 'blast', 'burst', 'bomb', 'boom', 'self-destruct', 'mind-blown'), '💥'),
    (('tackle', 'slam', 'take', 'edge', 'impact', 'charge', 'rush', 'crash', 'head', 'headbutt', 'body', 'body-slam', 'ram', 'extreme', 'quick'), '💨'),
    (('beam', 'ray', 'laser', 'cannon', 'pulse', 'orb', 'ball', 'sphere', 'shot'), None),
]

# Receitas feitas à mão para os golpes mais conhecidos: (estilo, símbolo).
RECIPES = {
    'thunderbolt': ('bolt', '⚡'), 'thunder': ('bolt', '🌩️'), 'thunder-shock': ('bolt', '⚡'), 'discharge': ('rings', '⚡'),
    'volt-switch': ('orb', '⚡'), 'thunder-wave': ('rings', '⚡'), 'electro-ball': ('orb', '🟡'), 'zap-cannon': ('beam', '⚡'),
    'flamethrower': ('stream', '🔥'), 'fire-blast': ('orb', '🔥'), 'heat-wave': ('wind', '🔥'), 'overheat': ('stream', '☄️'),
    'ember': ('volley', '🔥'), 'fire-spin': ('wind', '🔥'), 'lava-plume': ('rings', '🌋'), 'eruption': ('rocks', '🌋'),
    'flare-blitz': ('tackle', '🔥'), 'flame-wheel': ('tackle', '🔥'), 'sacred-fire': ('stream', '🔥'), 'blue-flare': ('orb', '🔵'),
    'hydro-pump': ('stream', '💧'), 'surf': ('wave', '🌊'), 'water-gun': ('stream', '💧'), 'scald': ('stream', '♨️'),
    'waterfall': ('tackle', '🌊'), 'aqua-jet': ('tackle', '💧'), 'aqua-tail': ('slash', '💧'), 'liquidation': ('bite', '💧'),
    'muddy-water': ('wave', '🟫'), 'water-shuriken': ('volley', '💠'), 'bubble-beam': ('beam', '🫧'), 'origin-pulse': ('wave', '🌊'),
    'earthquake': ('quake', '🟤'), 'earth-power': ('quake', '🌋'), 'bulldoze': ('quake', '🟤'), 'precipice-blades': ('quake', '🔺'),
    'dig': ('quake', '🕳️'), 'mud-shot': ('volley', '🟫'), 'high-horsepower': ('kick', '🐎'), 'drill-run': ('tackle', '🌀'),
    'ice-beam': ('beam', '🧊'), 'blizzard': ('wind', '❄️'), 'freeze-dry': ('rings', '🧊'), 'icicle-crash': ('rocks', '🧊'),
    'icicle-spear': ('volley', '🧊'), 'ice-shard': ('volley', '💎'), 'avalanche': ('rocks', '🏔️'), 'triple-axel': ('kick', '⛸️'),
    'psychic': ('rings', '🔮'), 'psyshock': ('rings', '🔷'), 'psystrike': ('rings', '🔮'), 'zen-headbutt': ('tackle', '🔮'),
    'psycho-cut': ('slash', '🔮'), 'future-sight': ('meteor', '🔮'), 'expanding-force': ('rings', '🔮'), 'psybeam': ('beam', '🌈'),
    'shadow-ball': ('orb', '👻'), 'shadow-claw': ('slash', '👻'), 'shadow-sneak': ('tackle', '👤'), 'hex': ('rings', '👁️'),
    'poltergeist': ('rocks', '🪑'), 'phantom-force': ('tackle', '👻'), 'shadow-punch': ('punch', '👻'), 'night-shade': ('rings', '🌑'),
    'dark-pulse': ('rings', '🌑'), 'crunch': ('bite', '🦷'), 'knock-off': ('slash', '👋'), 'sucker-punch': ('punch', '🌑'),
    'foul-play': ('punch', '😈'), 'night-slash': ('slash', '🌙'), 'throat-chop': ('slash', '🌑'), 'pursuit': ('tackle', '🏃'),
    'dragon-pulse': ('beam', '🐉'), 'draco-meteor': ('meteor', '☄️'), 'outrage': ('tackle', '😡'), 'dragon-claw': ('slash', '🐉'),
    'dragon-rush': ('tackle', '🐉'), 'dragon-darts': ('volley', '🐉'), 'dragon-tail': ('slash', '〰️'), 'spacial-rend': ('slash', '🌌'),
    'roar-of-time': ('rings', '⏳'), 'scale-shot': ('volley', '🐉'), 'dragon-energy': ('beam', '🐉'),
    'sludge-bomb': ('orb', '☠️'), 'sludge-wave': ('wave', '🟣'), 'gunk-shot': ('orb', '🗑️'), 'poison-jab': ('punch', '☠️'),
    'acid': ('volley', '🟢'), 'venoshock': ('orb', '🟣'), 'cross-poison': ('slash', '☠️'),
    'moonblast': ('orb', '🌙'), 'dazzling-gleam': ('rings', '✨'), 'play-rough': ('tackle', '💫'), 'draining-kiss': ('drain', '💋'),
    'spirit-break': ('punch', '✨'), 'fairy-wind': ('wind', '✨'), 'misty-explosion': ('rings', '🌫️'),
    'flash-cannon': ('beam', '💡'), 'iron-head': ('tackle', '⚙️'), 'meteor-mash': ('punch', '☄️'), 'bullet-punch': ('punch', '🔩'),
    'iron-tail': ('slash', '⚙️'), 'heavy-slam': ('tackle', '🏋️'), 'gyro-ball': ('orb', '⚙️'), 'make-it-rain': ('rocks', '🪙'),
    'steel-wing': ('slash', '⚙️'), 'smart-strike': ('tackle', '🔱'), 'metal-claw': ('slash', '⚙️'),
    'close-combat': ('punch', '💥'), 'focus-blast': ('orb', '💥'), 'aura-sphere': ('orb', '🔵'), 'drain-punch': ('drain', '👊'),
    'mach-punch': ('punch', '💨'), 'high-jump-kick': ('kick', '🦘'), 'low-kick': ('kick', '🦶'), 'brick-break': ('punch', '🧱'),
    'superpower': ('punch', '💪'), 'cross-chop': ('slash', '✖️'), 'dynamic-punch': ('punch', '💥'), 'body-press': ('tackle', '🛡️'),
    'seismic-toss': ('tackle', '🌍'), 'hammer-arm': ('punch', '🔨'), 'vacuum-wave': ('rings', '💨'), 'sacred-sword': ('slash', '⚔️'),
    'brave-bird': ('tackle', '🦅'), 'hurricane': ('wind', '🌪️'), 'air-slash': ('slash', '🪶'), 'fly': ('tackle', '🦅'),
    'drill-peck': ('tackle', '🌀'), 'aerial-ace': ('slash', '💨'), 'acrobatics': ('tackle', '🤸'), 'dual-wingbeat': ('slash', '🪶'),
    'gust': ('wind', '🍃'), 'wing-attack': ('slash', '🪶'), 'bleakwind-storm': ('wind', '❄️'),
    'bug-buzz': ('rings', '🐝'), 'x-scissor': ('slash', '✂️'), 'u-turn': ('tackle', '↩️'), 'megahorn': ('tackle', '🦏'),
    'leech-life': ('drain', '🦟'), 'pin-missile': ('volley', '📌'), 'first-impression': ('tackle', '🐛'), 'lunge': ('tackle', '🕷️'),
    'stone-edge': ('rocks', '🗿'), 'rock-slide': ('rocks', '🪨'), 'head-smash': ('tackle', '🪨'), 'rock-blast': ('volley', '🪨'),
    'power-gem': ('beam', '💎'), 'ancient-power': ('rocks', '🏺'), 'diamond-storm': ('rocks', '💎'), 'meteor-beam': ('beam', '☄️'),
    'leaf-storm': ('volley', '🍃'), 'energy-ball': ('orb', '🟢'), 'giga-drain': ('drain', '💚'), 'solar-beam': ('beam', '☀️'),
    'leaf-blade': ('slash', '🍃'), 'wood-hammer': ('tackle', '🪵'), 'power-whip': ('slash', '🌿'), 'seed-bomb': ('orb', '🌰'),
    'bullet-seed': ('volley', '🌰'), 'petal-dance': ('wind', '🌸'), 'petal-blizzard': ('wind', '🌸'), 'razor-leaf': ('volley', '🍃'),
    'horn-leech': ('drain', '🌿'), 'grass-knot': ('kick', '🪢'), 'magical-leaf': ('volley', '🍁'), 'flower-trick': ('volley', '🌺'),
    'body-slam': ('tackle', '💥'), 'double-edge': ('tackle', '💢'), 'hyper-voice': ('rings', '🎵'), 'boomburst': ('rings', '🔊'),
    'return': ('tackle', '💗'), 'facade': ('tackle', '😤'), 'extreme-speed': ('tackle', '⚡'), 'quick-attack': ('tackle', '💨'),
    'tackle': ('tackle', '💥'), 'hyper-beam': ('beam', '🌟'), 'giga-impact': ('tackle', '🌟'), 'swift': ('volley', '⭐'),
    'tri-attack': ('orb', '🔺'), 'explosion': ('rings', '💥'), 'self-destruct': ('rings', '💥'), 'pay-day': ('volley', '🪙'),
    'egg-bomb': ('orb', '🥚'), 'bone-rush': ('volley', '🦴'), 'bonemerang': ('orb', '🦴'), 'rapid-spin': ('tackle', '🌀'),
    'fake-out': ('punch', '👏'), 'slash': ('slash', '✴️'), 'scratch': ('slash', '✴️'), 'bite': ('bite', '🦷'),
}

HAS = lambda slug, *words: any(w in slug for w in words)


def rule_kind(slug, type_, cat):
    """As mesmas regras de moveAnim.js / move_anim.dart (quando não há receita)."""
    if HAS(slug, 'drain', 'absorb', 'leech', 'draining-kiss', 'bitter-blade', 'parabolic-charge', 'dream-eater'):
        return 'drain'
    if HAS(slug, 'fang', 'bite', 'crunch', 'jaw', 'chomp'):
        return 'bite'
    if HAS(slug, 'punch', 'hammer-arm', 'meteor-mash'):
        return 'punch'
    if HAS(slug, 'kick', 'stomp'):
        return 'kick'
    if HAS(slug, 'slash', 'claw', 'cut', 'scissor', 'blade', 'sword', 'cleave', 'fury-swipes', 'aerial-ace', 'razor-shell', 'chop', 'false-swipe'):
        return 'slash'
    if HAS(slug, 'bullet', 'pin-missile', 'rock-blast', 'icicle-spear', 'shuriken', 'razor-leaf', 'leaf-storm', 'scale-shot', 'spike-cannon',
           'barrage', 'magical-leaf', 'seed', 'needle', 'shot'):
        return 'volley'
    if HAS(slug, 'meteor', 'comet'):
        return 'meteor'
    if HAS(slug, 'earthquake', 'magnitude', 'bulldoze', 'fissure', 'precipice', 'tantrum', 'earth-power', 'thousand'):
        return 'quake'
    if HAS(slug, 'rock-slide', 'stone-edge', 'rock-tomb', 'avalanche', 'rock-throw', 'icicle-crash', 'ancient-power', 'diamond-storm', 'stone-axe'):
        return 'rocks'
    if HAS(slug, 'surf', 'muddy-water', 'sludge-wave', 'origin-pulse') or (HAS(slug, 'wave') and not HAS(slug, 'wave-crash', 'shock-wave', 'heat-wave')):
        return 'wave'
    if HAS(slug, 'hurricane', 'gust', 'twister', 'air-cutter', 'wind', 'storm', 'blizzard', 'heat-wave', 'tornado'):
        return 'wind'
    if HAS(slug, 'beam', 'cannon', 'laser', 'ray', 'gleam', 'signal'):
        return 'beam'
    if HAS(slug, 'voice', 'boomburst', 'buzz', 'snarl', 'roar', 'uproar', 'round', 'clanging', 'overdrive', 'aria', 'sing'):
        return 'rings'
    if cat == 'special' and HAS(slug, 'flame', 'fire', 'ember', 'inferno', 'overheat', 'lava', 'hydro', 'water', 'scald', 'whirlpool', 'steam', 'torch', 'burn'):
        return 'stream'
    if cat == 'special' and type_ == 'electric':
        return 'bolt'
    if cat == 'special' and (type_ == 'psychic' or HAS(slug, 'pulse', 'hex', 'shade')):
        return 'rings'
    return 'tackle' if cat == 'physical' else 'orb'


def icon_of(slug, type_):
    words = slug.split('-')
    for word in words + [slug]:
        for keys, icon in WORD_ICON:
            if word in keys or slug in keys:
                return icon or TYPE_PARTICLE.get(type_, '⭐')
    return TYPE_PARTICLE.get(type_, '⭐')


def main():
    with open(os.path.join(DB, 'moves.json'), encoding='utf-8') as f:
        moves = json.load(f)
    out = {}
    for m in sorted(moves, key=lambda m: m['name']):
        cat = m.get('damage_class')
        if cat not in ('physical', 'special'):
            continue
        slug, type_ = m['name'], m['type']
        kind, icon = RECIPES.get(slug, (rule_kind(slug, type_, cat), icon_of(slug, type_)))
        out[slug] = [kind, icon]
    # Variação: a próxima livre entre os golpes com o mesmo estilo e símbolo
    # (na ordem de um sorteio fixo pelo nome, para não depender da ordem alfabética).
    used = {}
    for slug in sorted(out, key=lambda s: hashlib.md5(s.encode()).hexdigest()):
        key = tuple(out[slug])
        out[slug].append(used.get(key, 0))
        used[key] = used.get(key, 0) + 1
    out = dict(sorted(out.items()))
    with open(os.path.join(DB, 'move_anims.json'), 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, separators=(',', ':'))
        f.write('\n')
    combos = {tuple(v) for v in out.values()}
    print(f'{len(out)} golpes, {len(combos)} animações diferentes ({len(RECIPES)} receitas feitas à mão)')


if __name__ == '__main__':
    main()
