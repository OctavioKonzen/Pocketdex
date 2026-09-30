// lib/services/move_anim.dart
//
// Animação de cada golpe na batalha por turnos, igual ao site
// (web-site/src/lib/moveAnim.js; o estilo de todos os golpes é conferido em
// test/fixtures/move_anims.json). Cada golpe cai num estilo pelo nome e pela
// categoria (soco, mordida, corte, raio, jato, onda, terremoto...) e usa as
// partículas do tipo dele.
//
// fxPlan monta as peças em % do campo (x da esquerda, y de cima).

import 'dart:math';

/// Partícula de cada tipo.
const typeParticle = {
  'normal': '⭐',
  'fire': '🔥',
  'water': '💧',
  'grass': '🍃',
  'electric': '⚡',
  'ice': '❄️',
  'fighting': '💥',
  'poison': '🟣',
  'ground': '🟤',
  'flying': '🪶',
  'psychic': '💫',
  'bug': '🐛',
  'rock': '🪨',
  'ghost': '👻',
  'dragon': '🐉',
  'dark': '🌑',
  'steel': '⚙️',
  'fairy': '✨',
  'stellar': '🌟',
  'shadow': '🖤',
};

/// Estilo da animação de um golpe. A ordem das regras importa (igual no site).
String moveAnim(String slug, String type, String category) {
  bool has(List<String> words) => words.any(slug.contains);
  if (has(['drain', 'absorb', 'leech', 'draining-kiss', 'bitter-blade', 'parabolic-charge', 'dream-eater'])) return 'drain';
  if (has(['fang', 'bite', 'crunch', 'jaw', 'chomp'])) return 'bite';
  if (has(['punch', 'hammer-arm', 'meteor-mash'])) return 'punch';
  if (has(['kick', 'stomp'])) return 'kick';
  if (has(['slash', 'claw', 'cut', 'scissor', 'blade', 'sword', 'cleave', 'fury-swipes', 'aerial-ace', 'razor-shell', 'chop', 'false-swipe'])) {
    return 'slash';
  }
  if (has([
    'bullet',
    'pin-missile',
    'rock-blast',
    'icicle-spear',
    'shuriken',
    'razor-leaf',
    'leaf-storm',
    'scale-shot',
    'spike-cannon',
    'barrage',
    'magical-leaf',
    'seed',
    'needle',
    'shot',
  ])) {
    return 'volley';
  }
  if (has(['meteor', 'comet'])) return 'meteor';
  if (has(['earthquake', 'magnitude', 'bulldoze', 'fissure', 'precipice', 'tantrum', 'earth-power', 'thousand'])) return 'quake';
  if (has(['rock-slide', 'stone-edge', 'rock-tomb', 'avalanche', 'rock-throw', 'icicle-crash', 'ancient-power', 'diamond-storm', 'stone-axe'])) {
    return 'rocks';
  }
  if (has(['surf', 'muddy-water', 'sludge-wave', 'origin-pulse']) || (has(['wave']) && !has(['wave-crash', 'shock-wave', 'heat-wave']))) {
    return 'wave';
  }
  if (has(['hurricane', 'gust', 'twister', 'air-cutter', 'wind', 'storm', 'blizzard', 'heat-wave', 'tornado'])) return 'wind';
  if (has(['beam', 'cannon', 'laser', 'ray', 'gleam', 'signal'])) return 'beam';
  if (has(['voice', 'boomburst', 'buzz', 'snarl', 'roar', 'uproar', 'round', 'clanging', 'overdrive', 'aria', 'sing'])) return 'rings';
  if (category == 'special' &&
      has(['flame', 'fire', 'ember', 'inferno', 'overheat', 'lava', 'hydro', 'water', 'scald', 'whirlpool', 'steam', 'torch', 'burn'])) {
    return 'stream';
  }
  if (category == 'special' && type == 'electric') return 'bolt';
  if (category == 'special' && (type == 'psychic' || has(['pulse', 'hex', 'shade']))) return 'rings';
  return category == 'physical' ? 'tackle' : 'orb';
}

/// Quanto tempo (ms) cada estilo leva, para a tela esperar.
const fxDuration = {
  'tackle': 650,
  'punch': 650,
  'kick': 650,
  'bite': 700,
  'slash': 700,
  'orb': 700,
  'beam': 750,
  'stream': 900,
  'volley': 900,
  'bolt': 650,
  'quake': 900,
  'rocks': 900,
  'meteor': 1000,
  'wave': 1000,
  'wind': 950,
  'rings': 850,
  'drain': 1100,
};

/// Golpes corpo a corpo: quem ataca vai até o alvo.
const contactKinds = {'tackle', 'punch', 'kick', 'bite', 'slash'};

/// Uma peça da animação: partícula (emoji), linha (raio, corte, relâmpago), anel ou onda.
class FxPart {
  final String shape; // emoji | line | ring | wave
  final String char;
  final double x0, y0, x1, y1, s0, s1, o0, o1, rot, size, width;
  final int delay, dur, dir;
  const FxPart(
    this.shape, {
    this.char = '',
    this.x0 = 0,
    this.y0 = 0,
    this.x1 = 0,
    this.y1 = 0,
    this.delay = 0,
    this.dur = 450,
    this.s0 = 0.6,
    this.s1 = 1.2,
    this.o0 = 1,
    this.o1 = 0,
    this.rot = 0,
    this.size = 12,
    this.width = 3,
    this.dir = 1,
  });
}

class FxPlan {
  final List<FxPart> parts;
  final bool shake, flash;
  const FxPlan(this.parts, {this.shake = false, this.flash = false});
}

/// Peças da animação de [kind] do lado [from] (0 = você, 1 = o computador), de [a] (quem ataca) até [t] (o alvo). Igual ao site.
FxPlan fxPlan(String kind, String type, int from, Point<double> a, Point<double> t) {
  final p = typeParticle[type] ?? '⭐';
  final parts = <FxPart>[];
  void emoji(String char, double x0, double y0, double x1, double y1,
          {int delay = 0, int dur = 450, double s0 = 0.6, double s1 = 1.2, double o0 = 1, double o1 = 0, double rot = 0, double size = 12}) =>
      parts.add(
          FxPart('emoji', char: char, x0: x0, y0: y0, x1: x1, y1: y1, delay: delay, dur: dur, s0: s0, s1: s1, o0: o0, o1: o1, rot: rot, size: size));
  void burst(int delay, [double size = 16]) => emoji(p, t.x, t.y, t.x, t.y, delay: delay, dur: 380, s0: 0.3, s1: 1.6, size: size);
  void around(int n, double radius, int delay, {double size = 8}) {
    for (var i = 0; i < n; i++) {
      final ang = i / n * pi * 2;
      emoji(p, t.x, t.y, t.x + cos(ang) * radius, t.y + sin(ang) * radius * 1.4, delay: delay, dur: 450, s0: 0.5, s1: 1, size: size);
    }
  }

  void line(double x0, double y0, double x1, double y1, int delay, int dur, double width) =>
      parts.add(FxPart('line', x0: x0, y0: y0, x1: x1, y1: y1, delay: delay, dur: dur, width: width));
  var shake = false, flash = false;
  switch (kind) {
    case 'punch':
    case 'kick':
      final icon = kind == 'punch' ? '👊' : '🦶';
      emoji(icon, t.x, t.y, t.x, t.y, delay: 150, dur: 380, s0: 2, s1: 0.9, o0: 0.4, o1: 1, size: 18);
      emoji(icon, t.x, t.y, t.x, t.y, delay: 530, dur: 120, s0: 0.9, s1: 1.1, o0: 1, o1: 0, size: 18);
      around(5, 9, 450);
    case 'bite':
      emoji('🦷', t.x, t.y - 16, t.x, t.y - 4, delay: 100, dur: 300, s0: 1, s1: 1, o0: 1, o1: 1, rot: 180, size: 14);
      emoji('🦷', t.x, t.y + 16, t.x, t.y + 4, delay: 100, dur: 300, s0: 1, s1: 1, o0: 1, o1: 1, size: 14);
      around(5, 9, 420);
    case 'slash':
      for (var i = 0; i < 3; i++) {
        final dx = (i - 1) * 5.0;
        line(t.x - 9 + dx, t.y - 14, t.x + 9 + dx, t.y + 14, 100 + i * 130, 260, 3);
      }
      around(4, 8, 480);
    case 'beam':
      line(a.x, a.y, t.x, t.y, 0, 500, 9);
      for (var i = 1; i <= 6; i++) {
        final x = a.x + (t.x - a.x) * i / 7, y = a.y + (t.y - a.y) * i / 7;
        emoji(p, x, y, x, y, delay: i * 50, dur: 400, s0: 0.4, s1: 1, size: 7);
      }
      burst(450);
    case 'stream':
      for (var i = 0; i < 9; i++) {
        emoji(p, a.x, a.y, t.x + (i % 3 - 1) * 3, t.y + ((i + 1) % 3 - 1) * 4, delay: i * 60, dur: 420, s0: 0.5, s1: 1.3, o0: 1, o1: 0.2, size: 9);
      }
      burst(620);
    case 'volley':
      for (var i = 0; i < 5; i++) {
        final x = t.x + (i % 3 - 1) * 4, y = t.y + ((i % 2) * 2 - 1) * 4;
        emoji(p, a.x, a.y, x, y, delay: i * 110, dur: 330, s0: 0.7, s1: 1, o0: 1, o1: 1, rot: 360, size: 8);
        emoji(p, x, y, x, y, delay: i * 110 + 330, dur: 200, s0: 1, s1: 1.8, size: 8);
      }
    case 'bolt':
      final zig = [
        Point(t.x - 4, 0.0),
        Point(t.x + 5, t.y * 0.35),
        Point(t.x - 3, t.y * 0.6),
        Point(t.x + 3, t.y * 0.8),
        Point(t.x, t.y),
      ];
      for (var i = 0; i < zig.length - 1; i++) {
        line(zig[i].x, zig[i].y, zig[i + 1].x, zig[i + 1].y, i * 50, 350, 5);
      }
      flash = true;
      burst(300, 20);
      around(6, 10, 350);
    case 'quake':
      shake = true;
      for (var i = 0; i < 7; i++) {
        emoji(p, t.x + (i - 3) * 6, t.y + 14, t.x + (i - 3) * 7, t.y - 4 - (i % 3) * 5, delay: 100 + i * 60, dur: 500, s0: 0.6, s1: 1, size: 8);
      }
      burst(600);
    case 'rocks':
      for (var i = 0; i < 5; i++) {
        emoji(p, t.x + (i - 2) * 6, -10, t.x + (i - 2) * 4, t.y + ((i % 2) * 2 - 1) * 3,
            delay: i * 100, dur: 400, s0: 1, s1: 1, o0: 1, o1: 1, rot: 180, size: 11);
      }
      burst(650);
    case 'meteor':
      for (var i = 0; i < 3; i++) {
        emoji(p, t.x - 40 + i * 10, -15, t.x + (i - 1) * 5, t.y, delay: i * 200, dur: 450, s0: 1.4, s1: 1, o0: 1, o1: 1, size: 14);
      }
      flash = true;
      burst(800, 22);
    case 'wave':
      parts.add(FxPart('wave', dir: from == 0 ? 1 : -1, delay: 0, dur: 850));
      for (var i = 0; i < 6; i++) {
        emoji(p, from == 0 ? 5 : 95, 30.0 + i * 10, from == 0 ? 95 : 5, 20.0 + i * 11,
            delay: i * 70, dur: 700, s0: 0.8, s1: 1, o0: 1, o1: 0.3, size: 8);
      }
    case 'wind':
      for (var i = 0; i < 8; i++) {
        final ang = i / 8 * pi * 2;
        emoji(p, t.x + cos(ang) * 16, t.y + sin(ang) * 20, t.x + cos(ang + 2.4) * 3, t.y + sin(ang + 2.4) * 4,
            delay: i * 60, dur: 520, s0: 1, s1: 0.5, o0: 1, o1: 0.2, rot: 540, size: 9);
      }
      burst(700);
    case 'rings':
      for (var i = 0; i < 3; i++) {
        parts.add(FxPart('ring', x0: t.x, y0: t.y, delay: i * 180, dur: 500));
      }
      around(4, 10, 500, size: 7);
    case 'drain':
      burst(0);
      for (var i = 0; i < 6; i++) {
        emoji('💚', t.x + (i % 3 - 1) * 5, t.y + ((i % 2) * 2 - 1) * 5, a.x, a.y,
            delay: 300 + i * 90, dur: 500, s0: 1, s1: 0.6, o0: 1, o1: 0.3, size: 8);
      }
    case 'orb':
      emoji(p, a.x, a.y, t.x, t.y, delay: 0, dur: 420, s0: 0.6, s1: 1.8, o0: 1, o1: 1, rot: 360, size: 12);
      burst(420, 20);
      around(5, 9, 450);
    default:
      // Investida: quem ataca vai com tudo até o alvo.
      burst(250, 18);
      around(6, 10, 300);
  }
  return FxPlan(parts, shake: shake, flash: flash);
}
