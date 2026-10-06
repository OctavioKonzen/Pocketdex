#!/usr/bin/env python3
"""Gera a animação de cada golpe da batalha (assets/database/move_anims.json).

Cada golpe ganha a sua: [estilo, símbolo, variação].
  • estilo: o movimento (soco, jato, raio, onda, terremoto...). Os golpes de
    status têm todos receita feita à mão (STATUS_RECIPES: atributo subindo,
    cura, redoma, barreira, pó, clima...); os de dano usam a receita (RECIPES)
    ou as regras de moveAnim.js / move_anim.dart, junto com o que o Pokémon
    Showdown sabe de cada golpe (mordida, soco, corte, som, vento, bomba,
    pulso, autodestruição, Max Move...);
  • símbolo: tirado do próprio nome do golpe (Ice Punch 🧊, Sacred Sword ⚔️,
    Bone Rush 🦴, Petal Dance 🌸...) ou, se o nome não diz nada, o do tipo;
  • variação (0, 1, 2...): muda quantidade, caminho e giro das partículas;
    golpes com o mesmo estilo e símbolo ganham variações diferentes, então
    nenhum golpe tem a animação igual à de outro.
O site (public/data, por tool/build_web_data.py) e o app leem o mesmo arquivo.

Uso (precisa do npm ci em tool/battle-engine, como no build_battle_engine.sh):
  python3 tool/build_move_anims.py
"""

import hashlib
import json
import os
import re
import subprocess

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

# Golpes de status, um por um: (estilo, símbolo).
STATUS_RECIPES = {
    # Atributos subindo em quem usa.
    'swords-dance': ('boost', '⚔️'), 'growth': ('boost', '🌱'), 'meditate': ('boost', '🧘'), 'agility': ('boost', '💨'),
    'double-team': ('boost', '👥'), 'harden': ('boost', '🪨'), 'minimize': ('boost', '🔹'), 'withdraw': ('boost', '🐢'),
    'defense-curl': ('boost', '🔄'), 'barrier': ('wall', '🔷'), 'amnesia': ('boost', '❓'), 'acid-armor': ('boost', '🟣'),
    'sharpen': ('boost', '📐'), 'howl': ('boost', '🐺'), 'bulk-up': ('boost', '💪'), 'calm-mind': ('boost', '🧘'),
    'dragon-dance': ('boost', '🐉'), 'cosmic-power': ('boost', '🌌'), 'iron-defense': ('boost', '🛡️'), 'tail-glow': ('boost', '💡'),
    'rock-polish': ('boost', '💎'), 'nasty-plot': ('boost', '😈'), 'defend-order': ('boost', '🐝'), 'hone-claws': ('boost', '✴️'),
    'autotomize': ('boost', '⚙️'), 'quiver-dance': ('boost', '🦋'), 'coil': ('boost', '🐍'), 'shell-smash': ('boost', '🐚'),
    'shift-gear': ('boost', '⚙️'), 'work-up': ('boost', '😤'), 'cotton-guard': ('boost', '☁️'), 'geomancy': ('charge', '🌈'),
    'extreme-evoboost': ('boost', '🦊'), 'no-retreat': ('boost', '🚫'), 'clangorous-soul': ('boost', '🎵'), 'victory-dance': ('boost', '🏆'),
    'shelter': ('boost', '🏠'), 'fillet-away': ('boost', '🐟'), 'belly-drum': ('boost', '🥁'), 'take-heart': ('boost', '❤️‍🔥'),
    'tidy-up': ('boost', '🧹'), 'stuff-cheeks': ('heal', '🍒'), 'acupressure': ('boost', '📍'), 'aromatic-mist': ('boost', '🌸'),
    'coaching': ('boost', '📣'), 'gear-up': ('boost', '🔩'), 'magnetic-flux': ('boost', '🧲'), 'decorate': ('boost', '🎀'),
    'flower-shield': ('boost', '🌼'), 'rototiller': ('terrain', '🌱'), 'happy-hour': ('boost', '🎉'), 'celebrate': ('boost', '🎊'),
    'hold-hands': ('boost', '🤝'), 'helping-hand': ('boost', '✋'), 'dragon-cheer': ('boost', '🐲'), 'power-trick': ('boost', '🔀'),
    'power-shift': ('boost', '🔃'), 'laser-focus': ('charge', '🎯'), 'focus-energy': ('charge', '🔥'), 'charge': ('charge', '⚡'),
    'stockpile': ('charge', '🫃'), 'swallow': ('heal', '😋'), 'spit-up': ('orb', '💨'),
    # Atributos descendo no alvo.
    'sand-attack': ('powder', '🟫'), 'tail-whip': ('drop', '〰️'), 'leer': ('drop', '👀'), 'growl': ('rings', '🗯️'),
    'string-shot': ('powder', '🕸️'), 'screech': ('rings', '📢'), 'smokescreen': ('powder', '💨'), 'kinesis': ('drop', '🥄'),
    'flash': ('status', '💡'), 'cotton-spore': ('powder', '☁️'), 'scary-face': ('drop', '😱'), 'charm': ('drop', '💗'),
    'sweet-scent': ('powder', '🌺'), 'feather-dance': ('powder', '🪶'), 'fake-tears': ('drop', '😢'), 'metal-sound': ('rings', '🔔'),
    'tickle': ('drop', '🤭'), 'memento': ('explode', '🪦'), 'captivate': ('drop', '😍'), 'noble-roar': ('rings', '🦁'),
    'play-nice': ('drop', '🤗'), 'confide': ('rings', '🤫'), 'eerie-impulse': ('rings', '⚡'), 'venom-drench': ('powder', '🟣'),
    'baby-doll-eyes': ('drop', '🥺'), 'tearful-look': ('drop', '😭'), 'tar-shot': ('powder', '⚫'), 'toxic-thread': ('powder', '🧵'),
    'strength-sap': ('drain', '🌱'), 'parting-shot': ('rings', '😝'), 'spicy-extract': ('powder', '🌶️'), 'corrosive-gas': ('powder', '🟢'),
    'sticky-web': ('hazard', '🕸️'),
    # Problemas no alvo.
    'sing': ('rings', '🎶'), 'supersonic': ('rings', '〰️'), 'poison-powder': ('powder', '☠️'), 'stun-spore': ('powder', '⚡'),
    'sleep-powder': ('powder', '💤'), 'thunder-wave': ('status', '⚡'), 'toxic': ('status', '☠️'), 'hypnosis': ('status', '🌀'),
    'confuse-ray': ('status', '😵'), 'glare': ('status', '👁️'), 'poison-gas': ('powder', '🟣'), 'lovely-kiss': ('status', '💋'),
    'spore': ('powder', '🍄'), 'sweet-kiss': ('status', '😘'), 'swagger': ('status', '😤'), 'attract': ('status', '💕'),
    'will-o-wisp': ('status', '🔥'), 'flatter': ('status', '🥰'), 'yawn': ('status', '🥱'), 'grass-whistle': ('rings', '🎶'),
    'teeter-dance': ('rings', '💃'), 'dark-void': ('powder', '🌑'), 'nightmare': ('status', '😱'), 'leech-seed': ('hazard', '🌱'),
    'disable': ('status', '🚫'), 'taunt': ('status', '😜'), 'torment': ('status', '😖'), 'encore': ('status', '👏'),
    'curse': ('status', '📌'), 'perish-song': ('rings', '🎼'), 'destiny-bond': ('charge', '⛓️'), 'grudge': ('charge', '👻'),
    'spite': ('status', '😠'), 'mean-look': ('status', '👁️‍🗨️'), 'block': ('wall', '🧱'), 'spider-web': ('hazard', '🕸️'),
    'octolock': ('status', '🐙'), 'embargo': ('status', '📦'), 'heal-block': ('status', '⛔'), 'gastro-acid': ('powder', '🟢'),
    'worry-seed': ('status', '🌰'), 'telekinesis': ('status', '🛸'), 'soak': ('stream', '💦'), 'simple-beam': ('beam', '⚪'),
    'entrainment': ('rings', '💃'), 'electrify': ('status', '🔌'), 'powder': ('powder', '🧂'), 'magic-powder': ('powder', '🔮'),
    'trick-or-treat': ('status', '🎃'), 'forests-curse': ('status', '🌲'), 'spotlight': ('status', '🔦'), 'quash': ('status', '🤐'),
    'foresight': ('status', '🔍'), 'odor-sleuth': ('status', '👃'), 'miracle-eye': ('status', '👁️'), 'lock-on': ('status', '🎯'),
    'mind-reader': ('status', '🧠'), 'imprison': ('wall', '🔒'), 'topsy-turvy': ('swap', '🙃'), 'purify': ('heal', '🫧'),
    'instruct': ('status', '☝️'), 'after-you': ('status', '🙇'), 'psycho-shift': ('swap', '🔮'), 'reflect-type': ('swap', '🪞'),
    # Trocar coisas com o alvo.
    'trick': ('swap', '🎩'), 'switcheroo': ('swap', '🔄'), 'skill-swap': ('swap', '🧩'), 'role-play': ('swap', '🎭'),
    'power-swap': ('swap', '💪'), 'guard-swap': ('swap', '🛡️'), 'heart-swap': ('swap', '💞'), 'speed-swap': ('swap', '💨'),
    'guard-split': ('swap', '⚖️'), 'power-split': ('swap', '⚖️'), 'pain-split': ('swap', '💔'), 'bestow': ('swap', '🎁'),
    'transform': ('swap', '🟪'), 'mimic': ('swap', '🪞'), 'sketch': ('swap', '🖌️'), 'doodle': ('swap', '🎨'),
    'psych-up': ('swap', '📈'), 'conversion': ('boost', '🔣'), 'conversion-2': ('boost', '🔁'), 'camouflage': ('boost', '🦎'),
    'ally-switch': ('charge', '↔️'), 'baton-pass': ('charge', '🪄'), 'teleport': ('charge', '✨'), 'shed-tail': ('shield', '🦎'),
    'court-change': ('field', '🔄'), 'recycle': ('charge', '♻️'),
    # Cura.
    'recover': ('heal', '💖'), 'soft-boiled': ('heal', '🥚'), 'rest': ('heal', '💤'), 'milk-drink': ('heal', '🥛'),
    'morning-sun': ('heal', '🌅'), 'synthesis': ('heal', '🌿'), 'moonlight': ('heal', '🌙'), 'slack-off': ('heal', '🦥'),
    'roost': ('heal', '🪶'), 'heal-order': ('heal', '🐝'), 'shore-up': ('heal', '🏖️'), 'wish': ('heal', '🌠'),
    'healing-wish': ('heal', '🙏'), 'lunar-dance': ('heal', '🌕'), 'heal-pulse': ('rings', '💗'), 'floral-healing': ('heal', '🌸'),
    'life-dew': ('heal', '💧'), 'jungle-healing': ('heal', '🌴'), 'lunar-blessing': ('heal', '🌙'), 'aqua-ring': ('shield', '💧'),
    'ingrain': ('heal', '🌳'), 'heal-bell': ('heal', '🔔'), 'aromatherapy': ('heal', '🌺'), 'refresh': ('heal', '🫧'),
    'revival-blessing': ('heal', '🪽'), 'teatime': ('heal', '🍵'),
    # Proteção.
    'protect': ('shield', '🟢'), 'detect': ('shield', '👁️'), 'endure': ('shield', '😣'), 'kings-shield': ('shield', '👑'),
    'spiky-shield': ('shield', '🌵'), 'baneful-bunker': ('shield', '☠️'), 'obstruct': ('shield', '✋'), 'silk-trap': ('shield', '🕸️'),
    'burning-bulwark': ('shield', '🔥'), 'max-guard': ('shield', '🔰'), 'substitute': ('shield', '🧸'), 'magic-coat': ('shield', '🪞'),
    'snatch': ('charge', '🫳'), 'follow-me': ('boost', '👉'), 'rage-powder': ('charge', '😡'), 'magnet-rise': ('boost', '🧲'),
    'mat-block': ('wall', '🟫'), 'quick-guard': ('wall', '⚡'), 'wide-guard': ('wall', '🪨'), 'crafty-shield': ('wall', '✨'),
    # Barreiras no lado de quem usa.
    'reflect': ('wall', '🟪'), 'light-screen': ('wall', '🟨'), 'aurora-veil': ('wall', '🌌'), 'safeguard': ('wall', '🛡️'),
    'mist': ('wall', '🌫️'), 'lucky-chant': ('wall', '🍀'), 'tailwind': ('weather', '🌬️'),
    # Armadilhas no chão do outro lado.
    'spikes': ('hazard', '📌'), 'toxic-spikes': ('hazard', '☠️'), 'stealth-rock': ('hazard', '🪨'),
    # Clima e terreno.
    'sunny-day': ('weather', '☀️'), 'rain-dance': ('weather', '🌧️'), 'sandstorm': ('weather', '🟫'), 'hail': ('weather', '🧊'),
    'snowscape': ('weather', '❄️'), 'chilly-reception': ('weather', '🥶'), 'grassy-terrain': ('terrain', '🌿'), 'misty-terrain': ('terrain', '🌫️'),
    'electric-terrain': ('terrain', '⚡'), 'psychic-terrain': ('terrain', '🔮'),
    # O campo todo.
    'trick-room': ('field', '🔲'), 'gravity': ('field', '🌑'), 'wonder-room': ('field', '❔'), 'magic-room': ('field', '🪄'),
    'mud-sport': ('terrain', '🟤'), 'water-sport': ('terrain', '💦'), 'fairy-lock': ('field', '🔐'), 'ion-deluge': ('field', '⚡'),
    'haze': ('field', '🌫️'), 'defog': ('weather', '🌬️'), 'whirlwind': ('wind', '🌪️'), 'roar': ('rings', '🦁'),
    # Golpes que chamam outros golpes.
    'metronome': ('charge', '☝️'), 'mirror-move': ('swap', '🪞'), 'nature-power': ('charge', '🌳'), 'assist': ('charge', '🤝'),
    'copycat': ('charge', '🐱'), 'me-first': ('swap', '🥇'), 'sleep-talk': ('charge', '💭'), 'splash': ('boost', '💦'),
    # Golpes Sombrios do Colosseum/XD.
    'shadow-down': ('drop', '🖤'), 'shadow-hold': ('status', '🖤'), 'shadow-mist': ('powder', '🖤'), 'shadow-panic': ('status', '😵‍💫'),
    'shadow-shed': ('field', '🖤'), 'shadow-sky': ('weather', '🖤'),
}

# Mais golpes de dano feitos à mão: estocadas, chicotes, giros e quedas do alto.
RECIPES.update({
    'horn-attack': ('pierce', '🦏'), 'fury-attack': ('pierce', '🔱'), 'horn-drill': ('pierce', '🌀'), 'peck': ('pierce', '🐦'),
    'drill-peck': ('pierce', '🌀'), 'poison-jab': ('pierce', '☠️'), 'poison-sting': ('pierce', '🐝'), 'twineedle': ('pierce', '🐝'),
    'megahorn': ('pierce', '🦏'), 'smart-strike': ('pierce', '🔱'), 'jab': ('pierce', '👊'), 'pluck': ('pierce', '🐦'),
    'vine-whip': ('whip', '🌿'), 'power-whip': ('whip', '🌿'), 'iron-tail': ('whip', '⚙️'), 'dragon-tail': ('whip', '🐉'),
    'aqua-tail': ('whip', '💧'), 'tail-slap': ('whip', '〰️'), 'slam': ('whip', '💥'), 'wrap': ('whip', '🐍'), 'bind': ('whip', '🪢'),
    'fire-lash': ('whip', '🔥'), 'trop-kick': ('kick', '🌴'), 'poison-tail': ('whip', '☠️'), 'constrict': ('whip', '🐙'),
    'rapid-spin': ('spin', '🌀'), 'rollout': ('spin', '🪨'), 'ice-ball': ('spin', '🧊'), 'gyro-ball': ('spin', '⚙️'),
    'flame-wheel': ('spin', '🔥'), 'steamroller': ('spin', '🐛'), 'mortal-spin': ('spin', '☠️'), 'ice-spinner': ('spin', '⛸️'),
    'aqua-step': ('spin', '💃'), 'fiery-dance': ('spin', '💃'), 'shadow-bone': ('spin', '🦴'),
    'fly': ('dive', '🦅'), 'bounce': ('dive', '🦘'), 'sky-drop': ('dive', '🦅'), 'heavy-slam': ('dive', '🏋️'),
    'heat-crash': ('dive', '🔥'), 'body-slam': ('dive', '💥'), 'dive': ('dive', '🌊'), 'phantom-force': ('dive', '👻'),
    'shadow-force': ('dive', '👻'), 'dragon-ascent': ('dive', '🐉'), 'sky-attack': ('dive', '🦅'), 'supercell-slam': ('dive', '⚡'),
    'explosion': ('explode', '💥'), 'self-destruct': ('explode', '💥'), 'misty-explosion': ('explode', '🌫️'), 'mind-blown': ('explode', '🤯'),
    'final-gambit': ('explode', '💀'), 'spit-up': ('orb', '💨'),
})

# Os golpes de dano que as regras não acertavam, um por um.
RECIPES.update({
    'accelerock': ('tackle', '🪨'), 'apple-acid': ('stream', '🍏'), 'arm-thrust': ('punch', '🖐️'), 'assurance': ('punch', '🌑'),
    'astonish': ('status', '😱'), 'attack-order': ('volley', '🐝'), 'baddy-bad': ('wall', '😈'), 'beak-blast': ('pierce', '🔥'),
    'beat-up': ('volley', '👊'), 'behemoth-bash': ('tackle', '🛡️'), 'belch': ('stream', '🤢'), 'bide': ('charge', '😤'),
    'bitter-malice': ('powder', '🥶'), 'blazing-torque': ('spin', '🏍️'), 'blood-moon': ('beam', '🌕'), 'bolt-beak': ('pierce', '⚡'),
    'bolt-strike': ('bolt', '🌩️'), 'bone-club': ('whip', '🦴'), 'branch-poke': ('pierce', '🪵'), 'breaking-swipe': ('whip', '🐉'),
    'brine': ('stream', '🧂'), 'brutal-swing': ('whip', '🌑'), 'bubble': ('volley', '🫧'), 'chip-away': ('slash', '⭐'),
    'chloroblast': ('beam', '🍀'), 'circle-throw': ('spin', '🥋'), 'clamp': ('bite', '🐚'), 'clear-smog': ('powder', '🌫️'),
    'collision-course': ('dive', '🏎️'), 'combat-torque': ('spin', '🥊'), 'comeuppance': ('punch', '😠'), 'core-enforcer': ('beam', '🐍'),
    'counter': ('punch', '↩️'), 'covet': ('swap', '🥺'), 'crabhammer': ('punch', '🦀'), 'crush-grip': ('punch', '✊'),
    'doom-desire': ('meteor', '🌟'), 'double-hit': ('whip', '✌️'), 'double-shock': ('bolt', '⚡'), 'double-slap': ('punch', '🖐️'),
    'dragon-breath': ('stream', '🐉'), 'dragon-hammer': ('dive', '🔨'), 'dragon-rage': ('orb', '🐉'), 'drum-beating': ('quake', '🥁'),
    'endeavor': ('tackle', '😤'), 'false-surrender': ('slash', '🙇'), 'feint': ('tackle', '🎭'), 'feint-attack': ('tackle', '🎭'),
    'fiery-wrath': ('rings', '😡'), 'flail': ('tackle', '😫'), 'flame-charge': ('spin', '🔥'), 'fling': ('orb', '🎒'),
    'flip-turn': ('spin', '🐬'), 'floaty-fall': ('dive', '🪶'), 'flying-press': ('dive', '🤼'), 'force-palm': ('punch', '🖐️'),
    'freeze-shock': ('bolt', '🧊'), 'freezy-frost': ('weather', '🧊'), 'frenzy-plant': ('quake', '🌳'), 'frost-breath': ('stream', '🌬️'),
    'frustration': ('tackle', '💢'), 'fusion-bolt': ('bolt', '⚡'), 'fusion-flare': ('orb', '🔥'), 'gear-grind': ('spin', '⚙️'),
    'gigaton-hammer': ('dive', '🔨'), 'glaciate': ('wind', '🧊'), 'glaive-rush': ('tackle', '🗡️'), 'grass-pledge': ('quake', '🌿'),
    'fire-pledge': ('quake', '🔥'), 'water-pledge': ('quake', '💧'), 'grassy-glide': ('tackle', '🛹'), 'grav-apple': ('dive', '🍎'),
    'hard-press': ('punch', '🗜️'), 'head-charge': ('tackle', '🐂'), 'headbutt': ('tackle', '🤕'), 'heart-stamp': ('kick', '💗'),
    'hidden-power': ('orb', '❔'), 'hold-back': ('tackle', '🫷'), 'hyperspace-fury': ('volley', '🌀'), 'incinerate': ('stream', '🔥'),
    'infernal-parade': ('volley', '👻'), 'infestation': ('powder', '🐜'), 'ivy-cudgel': ('whip', '🎋'), 'judgment': ('meteor', '⚖️'),
    'lands-wrath': ('quake', '🟢'), 'last-resort': ('tackle', '🃏'), 'last-respects': ('rings', '🪦'), 'leafage': ('volley', '🍂'),
    'lick': ('bite', '👅'), 'light-of-ruin': ('beam', '🌸'), 'low-sweep': ('kick', '🦵'), 'magical-torque': ('spin', '🎠'),
    'magnet-bomb': ('volley', '🧲'), 'malignant-chain': ('whip', '⛓️'), 'metal-burst': ('explode', '⚙️'), 'mountain-gale': ('rocks', '🏔️'),
    'mud-bomb': ('orb', '🟫'), 'mud-slap': ('volley', '🟫'), 'multi-attack': ('slash', '💿'), 'natural-gift': ('orb', '🫐'),
    'night-daze': ('rings', '🌑'), 'noxious-torque': ('spin', '🟣'), 'nuzzle': ('tackle', '⚡'), 'octazooka': ('stream', '🐙'),
    'order-up': ('dive', '🍣'), 'payback': ('punch', '↩️'), 'pollen-puff': ('orb', '🌼'), 'pounce': ('dive', '🐛'),
    'pound': ('punch', '🖐️'), 'powder-snow': ('wind', '❄️'), 'power-trip': ('boost', '😎'), 'present': ('orb', '🎁'),
    'psyshield-bash': ('tackle', '🛡️'), 'punishment': ('whip', '⚖️'), 'pyro-ball': ('orb', '⚽'), 'rage': ('tackle', '😡'),
    'raging-bull': ('tackle', '🐂'), 'raging-fury': ('stream', '😡'), 'retaliate': ('punch', '😤'), 'revelation-dance': ('spin', '💃'),
    'revenge': ('punch', '😠'), 'reversal': ('punch', '🔄'), 'rock-climb': ('tackle', '🧗'), 'rock-smash': ('punch', '🪨'),
    'rock-wrecker': ('orb', '🪨'), 'ruination': ('meteor', '🌑'), 'salt-cure': ('powder', '🧂'), 'sand-tomb': ('wind', '🏜️'),
    'scorching-sands': ('stream', '🏜️'), 'secret-power': ('orb', '🗝️'), 'shell-side-arm': ('beam', '🐚'), 'shell-trap': ('explode', '🐚'),
    'sizzly-slide': ('spin', '🔥'), 'skitter-smack': ('tackle', '🦗'), 'skull-bash': ('tackle', '💀'), 'sludge': ('orb', '🟣'),
    'smack-down': ('dive', '🪨'), 'smelling-salts': ('punch', '🧂'), 'smog': ('powder', '🌫️'), 'snap-trap': ('bite', '🪤'),
    'sonic-boom': ('rings', '💨'), 'sparkly-swirl': ('wind', '✨'), 'spectral-thief': ('swap', '👻'), 'spirit-shackle': ('pierce', '🏹'),
    'strength': ('punch', '💪'), 'struggle': ('tackle', '😣'), 'struggle-bug': ('volley', '🐞'), 'submission': ('spin', '🤼'),
    'sunsteel-strike': ('dive', '☀️'), 'syrup-bomb': ('orb', '🍯'), 'take-down': ('tackle', '💢'), 'techno-blast': ('beam', '💿'),
    'temper-flare': ('stream', '😡'), 'tera-blast': ('beam', '💎'), 'thief': ('swap', '🦹'), 'thrash': ('tackle', '😤'),
    'trailblaze': ('tackle', '🥾'), 'triple-arrows': ('volley', '🏹'), 'triple-dive': ('dive', '🐟'), 'trump-card': ('orb', '🃏'),
    'upper-hand': ('punch', '🫲'), 'v-create': ('dive', '🔥'), 'veevee-volley': ('tackle', '💖'), 'vice-grip': ('bite', '🦀'),
    'vital-throw': ('spin', '🥋'), 'volt-tackle': ('tackle', '⚡'), 'wake-up-slap': ('punch', '🖐️'), 'wave-crash': ('tackle', '🌊'),
    'weather-ball': ('orb', '🌦️'), 'wicked-torque': ('spin', '🌑'), 'wild-charge': ('tackle', '⚡'), 'wring-out': ('punch', '🫳'),
    'zing-zap': ('bolt', '⚡'), 'zippy-zap': ('tackle', '⚡'), 'buzzy-buzz': ('bolt', '🐝'), 'bouncy-bubble': ('drain', '🫧'),
    'glitzy-glow': ('wall', '💡'), 'sappy-seed': ('hazard', '🌱'), 'sparkling-aria': ('rings', '🫧'), 'pika-papow': ('bolt', '⚡'),
    'splishy-splash': ('wave', '🌊'),
    # Z-Moves: o golpe mais forte de cada tipo.
    'breakneck-blitz--physical': ('dive', '⭐'), 'breakneck-blitz--special': ('meteor', '⭐'),
    'all-out-pummeling--physical': ('punch', '💥'), 'all-out-pummeling--special': ('volley', '💥'),
    'supersonic-skystrike--physical': ('dive', '🪶'), 'supersonic-skystrike--special': ('meteor', '🪶'),
    'acid-downpour--physical': ('rocks', '☠️'), 'acid-downpour--special': ('weather', '☠️'),
    'tectonic-rage--physical': ('quake', '🟤'), 'tectonic-rage--special': ('quake', '🌋'),
    'continental-crush--physical': ('rocks', '🪨'), 'continental-crush--special': ('meteor', '🪨'),
    'savage-spin-out--physical': ('whip', '🕸️'), 'savage-spin-out--special': ('powder', '🕸️'),
    'never-ending-nightmare--physical': ('field', '👻'), 'never-ending-nightmare--special': ('status', '👻'),
    'corkscrew-crash--physical': ('spin', '⚙️'), 'corkscrew-crash--special': ('pierce', '⚙️'),
    'inferno-overdrive--physical': ('orb', '🔥'), 'inferno-overdrive--special': ('stream', '🔥'),
    'hydro-vortex--physical': ('wind', '💧'), 'hydro-vortex--special': ('wave', '💧'),
    'bloom-doom--physical': ('terrain', '🌺'), 'bloom-doom--special': ('beam', '🌺'),
    'gigavolt-havoc--physical': ('bolt', '⚡'), 'gigavolt-havoc--special': ('beam', '⚡'),
    'shattered-psyche--physical': ('dive', '🔮'), 'shattered-psyche--special': ('rings', '🔮'),
    'subzero-slammer--physical': ('dive', '🧊'), 'subzero-slammer--special': ('rocks', '🧊'),
    'devastating-drake--physical': ('dive', '🐉'), 'devastating-drake--special': ('beam', '🐉'),
    'black-hole-eclipse--physical': ('field', '🌑'), 'black-hole-eclipse--special': ('drain', '🌑'),
    'twinkle-tackle--physical': ('tackle', '✨'), 'twinkle-tackle--special': ('rings', '✨'),
    'catastropika': ('dive', '⚡'), 'sinister-arrow-raid': ('volley', '🏹'), 'malicious-moonsault': ('dive', '🐯'),
    'oceanic-operetta': ('wave', '🎶'), 'guardian-of-alola': ('dive', '🗿'), 'soul-stealing-7-star-strike': ('punch', '🌟'),
    'stoked-sparksurfer': ('wave', '🏄'), 'pulverizing-pancake': ('dive', '🥞'), 'extreme-evoboost': ('boost', '🦊'),
    'genesis-supernova': ('field', '🌌'), 'lets-snuggle-forever': ('tackle', '🧸'), 'splintered-stormshards': ('rocks', '🗡️'),
    'clangorous-soulblaze': ('rings', '🎵'), 'menacing-moonraze-maelstrom': ('beam', '🌙'), 'searing-sunraze-smash': ('dive', '☀️'),
    'light-that-burns-the-sky': ('beam', '🌈'), 'natures-madness': ('rings', '🌿'),
    # Golpes Sombrios do Colosseum/XD.
    'shadow-blast': ('slash', '🖤'), 'shadow-blitz': ('tackle', '🖤'), 'shadow-bolt': ('bolt', '🖤'), 'shadow-break': ('punch', '🖤'),
    'shadow-chill': ('wind', '🖤'), 'shadow-end': ('explode', '🖤'), 'shadow-fire': ('stream', '🖤'), 'shadow-rave': ('volley', '🖤'),
    'acid-spray': ('stream', '🧪'), 'anchor-shot': ('whip', '⚓'), 'blast-burn': ('meteor', '🌋'), 'charge-beam': ('beam', '⚡'),
    'darkest-lariat': ('spin', '🌑'), 'electroweb': ('powder', '🕸️'), 'guillotine': ('slash', '✂️'), 'headlong-rush': ('tackle', '🟤'),
    'lumina-crash': ('rings', '🌈'), 'mirror-coat': ('rings', '🪞'), 'population-bomb': ('volley', '🐭'), 'sky-uppercut': ('punch', '🪶'),
    'thousand-arrows': ('volley', '🏹'), 'thousand-waves': ('quake', '🌊'), 'water-pulse': ('rings', '💧'), 'whirlpool': ('wind', '💧'),
    'needle-arm': ('punch', '🌵'), 'snore': ('rings', '💤'), 'sheer-cold': ('wind', '🥶'), 'storm-throw': ('spin', '🌪️'),
    'shadow-rush': ('dive', '🖤'), 'shadow-storm': ('wind', '🖤'), 'shadow-wave': ('wave', '🖤'), 'shadow-half': ('field', '🖤'),
})
RECIPES.update(STATUS_RECIPES)

HAS = lambda slug, *words: any(w in slug for w in words)


def to_id(name):
    """O id do golpe no Showdown (Hidden Power Fire--physical → hiddenpowerfire)."""
    return re.sub('[^a-z0-9]', '', re.sub('--(physical|special)$', '', name))


def showdown_moves():
    """O que o Pokémon Showdown sabe de cada golpe (o mesmo motor da batalha)."""
    script = ("import {Dex} from '@pkmn/sim'; console.log(JSON.stringify(Object.fromEntries(Dex.moves.all().map((m) => [m.id, "
              "{flags: Object.keys(m.flags), multihit: !!m.multihit, selfdestruct: !!m.selfdestruct, isMax: !!m.isMax, "
              "ohko: !!m.ohko, drain: !!m.drain, charge: !!m.flags.charge}]))))")
    out = subprocess.run(['node', '--input-type=module', '-e', script], cwd=os.path.join(ROOT, 'tool', 'battle-engine'),
                         capture_output=True, text=True, check=True).stdout
    return json.loads(out)


def damage_kind(slug, type_, cat, sd):
    """Estilo de um golpe de dano sem receita: dados do Showdown + as regras de moveAnim.js."""
    flags = set(sd.get('flags', []))
    if sd.get('selfdestruct'):
        return 'explode'
    if sd.get('isMax'):
        return 'meteor'
    if sd.get('drain'):
        return 'drain'
    kind = rule_kind(slug, type_, cat)
    if kind not in ('tackle', 'orb'):
        return kind
    if 'bite' in flags:
        return 'bite'
    if 'punch' in flags:
        return 'punch'
    if 'slicing' in flags:
        return 'slash'
    if HAS(slug, 'horn', 'peck', 'jab', 'sting', 'drill', 'spear', 'lance'):
        return 'pierce'
    if HAS(slug, 'whip', 'tail', 'lash', 'wrap', 'bind', 'tentacle'):
        return 'whip'
    if HAS(slug, 'spin', 'roll', 'wheel', 'gyro', 'twirl'):
        return 'spin'
    if 'sound' in flags:
        return 'rings'
    if 'wind' in flags:
        return 'wind'
    if 'bullet' in flags:
        return 'volley' if sd.get('multihit') else 'orb'
    if 'pulse' in flags:
        return 'rings'
    if sd.get('ohko'):
        return 'quake' if type_ == 'ground' else 'meteor'
    return kind


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
    sd = showdown_moves()
    out = {}
    for m in sorted(moves, key=lambda m: m['name']):
        cat = m.get('damage_class')
        slug, type_ = m['name'], m['type']
        if cat == 'status' and slug not in RECIPES:
            raise SystemExit(f'golpe de status sem receita: {slug}')
        kind, icon = RECIPES.get(slug, (damage_kind(slug, type_, cat, sd.get(to_id(slug), {})), icon_of(slug, type_)))
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
