#!/usr/bin/env python3
"""Uma animação para cada golpe (assets/database/move_fx.json), no estilo do port de Black & White.

Cada golpe ganha a sua receita, montada pelo que ele é no jogo:
  d   como chega:  dash (avança e bate), dive (cai do alto), shot (tiro), volley (vários tiros), beam (raio),
                   jet (jato), sky (cai do céu), quake (chão), wave (onda na tela), gale (vento), sound (som),
                   blast (explode no campo todo), orb (bola), aura (surge no alvo), drain (absorve), hex (status no alvo),
                   self (em quem usa), field (clima / terreno / campo), hazard (armadilha no chão do outro lado)
  m   a forma:     fist, foot, fang, claw, blade, horn, wing, whip, head, body, petal, rock, crystal, heart, moon, sun,
                   star, note, gear, wisp, dragon, bubble, flame, spark, goo, dust, ring, web, eye
  n   acertos      (Double Kick 2, Bullet Seed 2-5 → 5)
  p   força 1 a 4  (pelo poder: Ember 1, Flamethrower 2, Fire Blast 3, Eruption 4)
  e   efeito no fim: burn, freeze, para, poison, sleep, confuse, flinch, up, down, heal, drain, recoil, trap
  v   variação     (ângulos e ritmos próprios do golpe)
Os marcantes têm animação feita à mão no battleFx.js / battle_fx.dart (fusion-flare, electroweb...).

Uso: python3 tool/build_move_fx.py
"""
import json
import re
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DB = ROOT / 'assets' / 'database'


def engine_moves():
    """Marcas (flags) e alvo de cada golpe no motor de batalha (Showdown)."""
    src = (DB / 'battle_engine.js').read_text()
    out = {}
    for mt in re.finditer(r'name:"([^"]+)",pp:\d+,priority:-?\d+,flags:\{([^}]*)\}', src):
        name, flags = mt.group(1), mt.group(2)
        slug = re.sub(r'[^a-z0-9]+', '-', name.lower().replace("'", '')).strip('-')
        tail = src[mt.end():mt.end() + 3000]
        cut = re.search(r',[a-z0-9]+:\{num:', tail)
        target = re.search(r'target:"(\w+)"', tail[:cut.start()] if cut else tail)
        if slug in out:
            continue
        out[slug] = {
            'flags': {x.split(':')[0] for x in flags.split(',') if x},
            'target': target.group(1) if target else '',
        }
    return out


def has(slug, *words):
    return any(w in slug for w in words)


# A forma pelo nome (a primeira que bate).
MOTIFS = [
    ('fist', ('punch', 'hammer-arm', 'meteor-mash', 'mach-punch', 'sky-uppercut', 'dynamic-punch', 'plasma-fists')),
    ('foot', ('kick', 'stomp', 'jump-kick', 'trop-kick', 'blaze-kick', 'axe-kick')),
    ('fang', ('fang', 'bite', 'crunch', 'jaw', 'chomp', 'super-fang', 'hyper-fang')),
    ('claw', ('claw', 'scratch', 'swipe', 'fury-', 'rake', 'hone')),
    ('blade', ('slash', 'cut', 'blade', 'sword', 'cleave', 'scissor', 'razor', 'chop', 'sacred-sword', 'psycho-cut', 'kowtow', 'ceaseless', 'bitter', 'aqua-cutter')),
    ('horn', ('horn', 'drill', 'jab', 'peck', 'spear', 'needle', 'pin-', 'sting', 'megahorn', 'smart-strike')),
    ('wing', ('wing', 'feather', 'aerial', 'air-', 'brave-bird', 'fly', 'sky-', 'gust', 'beak', 'dual-wingbeat', 'roost')),
    ('whip', ('tail', 'whip', 'vine', 'lash', 'slam', 'wrap', 'bind', 'constrict', 'power-whip')),
    ('head', ('head', 'skull', 'zen-', 'butt', 'smash')),
    ('web', ('web', 'string-shot', 'spider', 'silk')),
    ('heart', ('heart', 'charm', 'kiss', 'sweet', 'attract', 'love', 'lovely', 'captivate', 'baby-doll')),
    ('moon', ('moon', 'lunar', 'night-', 'dark-void')),
    ('sun', ('sun', 'solar', 'morning', 'synthesis', 'blaze')),
    ('star', ('star', 'swift', 'cosmic', 'meteor', 'comet', 'galaxy', 'wish', 'twinkle')),
    ('note', ('sing', 'song', 'voice', 'sound', 'roar', 'growl', 'chatter', 'boomburst', 'uproar', 'round', 'echo', 'snarl', 'perish', 'aria', 'overdrive', 'clang', 'screech', 'noise', 'buzz')),
    ('gear', ('gear', 'iron', 'metal', 'steel', 'magnet', 'flash-cannon', 'shift')),
    ('eye', ('glare', 'leer', 'mean-look', 'scary', 'stare', 'hypno', 'confuse', 'psych', 'mind', 'dream', 'trick', 'eye')),
    ('petal', ('leaf', 'petal', 'flower', 'seed', 'bloom', 'grass', 'spore', 'powder', 'pollen', 'cotton', 'apple', 'blossom')),
    ('rock', ('rock', 'stone', 'boulder', 'rollout', 'ancient', 'diamond', 'gem', 'salt')),
    ('crystal', ('ice', 'icy', 'frost', 'freeze', 'hail', 'icicle', 'blizzard', 'snow', 'glaciate', 'sheer-cold', 'aurora', 'chill')),
    ('wisp', ('shadow', 'ghost', 'curse', 'hex', 'spite', 'phantom', 'astonish', 'lick', 'grudge', 'nightmare', 'poltergeist', 'infernal', 'spirit', 'soul')),
    ('dragon', ('dragon', 'draco', 'outrage', 'dual-chop', 'clanging', 'spacial', 'roar-of-time', 'core-enforcer')),
    ('flame', ('fire', 'flame', 'ember', 'heat', 'burn', 'lava', 'magma', 'eruption', 'inferno', 'overheat', 'torch', 'flare', 'pyro', 'mystical-fire')),
    ('spark', ('thunder', 'volt', 'spark', 'electro', 'shock', 'zap', 'bolt', 'charge', 'discharge', 'parabolic', 'wild-charge', 'nuzzle', 'electric')),
    ('bubble', ('bubble', 'water', 'aqua', 'hydro', 'surf', 'splash', 'scald', 'brine', 'dive', 'rain', 'soak', 'whirlpool')),
    ('goo', ('poison', 'sludge', 'toxic', 'acid', 'gunk', 'smog', 'venom', 'gastro', 'belch', 'mortal')),
    ('dust', ('sand', 'mud', 'earth', 'dig', 'quake', 'bulldoze', 'magnitude', 'fissure', 'bone', 'spikes', 'precipice', 'land')),
    ('ring', ('psy', 'pulse', 'wave', 'aura', 'calm', 'focus', 'amnesia', 'barrier', 'reflect', 'screen', 'protect', 'detect', 'guard', 'shield')),
]
# A forma do tipo, quando o nome não diz.
TYPE_MOTIF = {
    'normal': 'body', 'fire': 'flame', 'water': 'bubble', 'electric': 'spark', 'grass': 'petal', 'ice': 'crystal',
    'fighting': 'fist', 'poison': 'goo', 'ground': 'dust', 'flying': 'wing', 'psychic': 'ring', 'bug': 'web',
    'rock': 'rock', 'ghost': 'wisp', 'dragon': 'dragon', 'dark': 'moon', 'steel': 'gear', 'fairy': 'heart',
    'stellar': 'star', 'shadow': 'wisp',
}

AILMENT = {'burn': 'burn', 'freeze': 'freeze', 'paralysis': 'para', 'poison': 'poison', 'sleep': 'sleep', 'confusion': 'confuse',
           'trap': 'trap', 'infatuation': 'heart', 'nightmare': 'sleep', 'yawn': 'sleep', 'leech-seed': 'drain', 'perish-song': 'down'}


def delivery(slug, mv, eng):
    """Como o golpe chega no alvo."""
    flags = eng.get('flags', set())
    target = eng.get('target', '') or ''
    klass = mv['damage_class']
    meta = mv.get('meta') or {}
    stats = mv.get('stat_changes') or []
    if klass == 'status':
        if target in ('all',) or has(slug, 'rain-dance', 'sunny-day', 'sandstorm', 'hail', 'snowscape', 'terrain', 'room', 'gravity', 'fog', 'mud-sport', 'water-sport', 'ion-deluge', 'fairy-lock', 'haze'):
            return 'field'
        if target == 'foeSide':
            return 'hazard'
        if target in ('self', 'allySide', 'allies', 'adjacentAllyOrSelf', 'adjacentAlly') or meta.get('healing') or (stats and all(s[1] > 0 for s in stats) and target != 'normal'):
            return 'self'
        if 'sound' in flags:
            return 'sound'
        return 'hex'
    if meta.get('drain', 0) > 0:
        return 'drain'
    if has(slug, 'explosion', 'self-destruct', 'mind-blown', 'misty-explosion'):
        return 'blast'
    if 'contact' in flags:
        if has(slug, 'fly', 'bounce', 'dive', 'sky-drop', 'heavy-slam', 'heat-crash', 'body-slam', 'high-jump', 'stomp', 'dragon-rush', 'supercell', 'phantom-force', 'shadow-force', 'axe-kick', 'flying-press', 'malicious'):
            return 'dive'
        return 'dash'
    if 'sound' in flags:
        return 'sound'
    if 'wind' in flags or has(slug, 'gust', 'twister', 'hurricane', 'tornado'):
        return 'gale'
    if has(slug, 'earthquake', 'magnitude', 'bulldoze', 'fissure', 'precipice', 'earth-power', 'tantrum', 'thousand', 'land', 'stomping', 'high-horsepower'):
        return 'quake'
    if has(slug, 'surf', 'muddy-water', 'sludge-wave', 'origin-pulse', 'water-spout', 'tsunami', 'oceanic'):
        return 'wave'
    if has(slug, 'thunder', 'meteor', 'rock-slide', 'stone-edge', 'avalanche', 'icicle-crash', 'blizzard', 'sky-attack', 'draco', 'comet', 'hail', 'judgment', 'fleur', 'diamond-storm', 'ceaseless', 'spirit-shackle', 'zap-cannon'):
        return 'sky'
    if meta.get('max_hits') or meta.get('min_hits'):
        return 'volley'
    if 'pulse' in flags or has(slug, 'beam', 'ray', 'laser', 'cannon', 'gleam', 'beam', 'signal', 'prismatic', 'light-of-ruin', 'hyper-beam', 'giga-impact', 'photon'):
        return 'beam'
    if has(slug, 'thrower', 'pump', 'spray', 'breath', 'gun', 'spit', 'jet', 'torrent', 'scald', 'steam', 'blast-burn', 'hydro', 'flamethrower', 'acid-spray', 'mud-shot', 'water-gun', 'ember', 'fire-spin', 'whirlpool', 'smog', 'sludge', 'gunk'):
        return 'jet'
    if 'bullet' in flags or has(slug, 'ball', 'bomb', 'shot', 'blast', 'orb', 'seed'):
        return 'shot'
    if target in ('allAdjacentFoes', 'allAdjacent') and klass == 'special':
        return 'blast'
    if mv['type'] in ('psychic', 'ghost', 'dark', 'fairy') and klass == 'special':
        return 'aura'
    if klass == 'physical':
        return 'shot'
    return 'orb'


def effect(slug, mv):
    meta = mv.get('meta') or {}
    stats = mv.get('stat_changes') or []
    a = AILMENT.get(meta.get('ailment') or '')
    if a:
        return a
    if meta.get('drain', 0) < 0 or has(slug, 'double-edge', 'brave-bird', 'flare-blitz', 'head-smash', 'wood-hammer', 'take-down', 'volt-tackle', 'wild-charge', 'submission'):
        return 'recoil'
    if meta.get('drain', 0) > 0:
        return 'drain'
    if meta.get('healing', 0) > 0:
        return 'heal'
    if meta.get('flinch_chance'):
        return 'flinch'
    if stats:
        return 'up' if all(s[1] > 0 for s in stats) else 'down'
    return ''


def power(mv):
    p = mv.get('power') or 0
    if p >= 140:
        return 4
    if p >= 100:
        return 3
    if p >= 70:
        return 2
    return 1


def main():
    moves = json.loads((DB / 'moves.json').read_text())
    eng = engine_moves()
    out = {}
    count = {}
    for mv in moves:
        slug = mv['name']
        e = eng.get(slug, {})
        d = delivery(slug, mv, e)
        m = next((name for name, words in MOTIFS if has(slug, *words)), None) or TYPE_MOTIF.get(mv['type'], 'body')
        meta = mv.get('meta') or {}
        n = meta.get('max_hits') or 1
        if 'double' in slug or slug in ('dual-chop', 'dual-wingbeat', 'twineedle', 'bonemerang', 'gear-grind', 'double-iron-bash', 'dragon-darts', 'tachyon-cutter'):
            n = max(n, 2)
        if slug in ('triple-kick', 'triple-axel', 'surging-strikes', 'triple-dive'):
            n = 3
        recipe = {'d': d, 'm': m, 'p': power(mv), 'v': zlib.crc32(slug.encode()) % 997}
        if n > 1:
            recipe['n'] = min(5, n)
        fx = effect(slug, mv)
        if fx:
            recipe['e'] = fx
        if 'charge' in e.get('flags', set()) or meta.get('category') == 'damage' and has(slug, 'solar-beam', 'solar-blade', 'skull-bash', 'sky-attack', 'razor-wind', 'meteor-beam', 'electro-shot'):
            recipe['c'] = 1  # carrega antes (dois turnos)
        out[slug] = recipe
        count[d] = count.get(d, 0) + 1
    (DB / 'move_fx.json').write_text(json.dumps(out, ensure_ascii=False, separators=(',', ':'), sort_keys=True) + '\n')
    combos = len({json.dumps({k: v for k, v in r.items() if k != 'v'}, sort_keys=True) + k for k, r in out.items()})
    print(f'move_fx.json: {len(out)} golpes, {combos} receitas;', ', '.join(f'{k} {v}' for k, v in sorted(count.items(), key=lambda x: -x[1])))


if __name__ == '__main__':
    main()
