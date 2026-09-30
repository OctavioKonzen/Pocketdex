// Animação de cada golpe na batalha por turnos, igual ao app
// (lib/services/move_anim.dart). Cada golpe cai num estilo pelo nome e pela
// categoria (soco, mordida, corte, raio, jato, onda, terremoto...) e usa as
// partículas do tipo dele: Flamethrower é um jato de fogo, Hydro Pump um jato
// de água, Thunder Punch um soco com raios, Surf uma onda...
//
// fxPlan monta as peças da animação em % do campo (x da esquerda, y de cima):
//   {shape: 'emoji', char, x0, y0, x1, y1, delay, dur, s0, s1, o0, o1, rot, size}
//   {shape: 'line', x0, y0, x1, y1, delay, dur, width}  (raio, corte, relâmpago)
//   {shape: 'ring', x, y, delay, dur}  {shape: 'wave', dir, delay, dur}
// e diz se o campo treme (shake) ou dá um clarão (flash).

/** Partícula de cada tipo. */
export const TYPE_PARTICLE = {
  normal: '⭐', fire: '🔥', water: '💧', grass: '🍃', electric: '⚡', ice: '❄️', fighting: '💥', poison: '🟣',
  ground: '🟤', flying: '🪶', psychic: '💫', bug: '🐛', rock: '🪨', ghost: '👻', dragon: '🐉', dark: '🌑',
  steel: '⚙️', fairy: '✨', stellar: '🌟', shadow: '🖤',
}

/** Estilo da animação de um golpe. A ordem das regras importa (igual no app). */
export function moveAnim(slug, type, category) {
  const has = (...words) => words.some((w) => slug.includes(w))
  if (has('drain', 'absorb', 'leech', 'draining-kiss', 'bitter-blade', 'parabolic-charge', 'dream-eater')) return 'drain'
  if (has('fang', 'bite', 'crunch', 'jaw', 'chomp')) return 'bite'
  if (has('punch', 'hammer-arm', 'meteor-mash')) return 'punch'
  if (has('kick', 'stomp')) return 'kick'
  if (has('slash', 'claw', 'cut', 'scissor', 'blade', 'sword', 'cleave', 'fury-swipes', 'aerial-ace', 'razor-shell', 'chop', 'false-swipe'))
    return 'slash'
  if (has('bullet', 'pin-missile', 'rock-blast', 'icicle-spear', 'shuriken', 'razor-leaf', 'leaf-storm', 'scale-shot', 'spike-cannon', 'barrage', 'magical-leaf', 'seed', 'needle', 'shot'))
    return 'volley'
  if (has('meteor', 'comet')) return 'meteor'
  if (has('earthquake', 'magnitude', 'bulldoze', 'fissure', 'precipice', 'tantrum', 'earth-power', 'thousand')) return 'quake'
  if (has('rock-slide', 'stone-edge', 'rock-tomb', 'avalanche', 'rock-throw', 'icicle-crash', 'ancient-power', 'diamond-storm', 'stone-axe'))
    return 'rocks'
  if (has('surf', 'muddy-water', 'sludge-wave', 'origin-pulse') || (has('wave') && !has('wave-crash', 'shock-wave', 'heat-wave'))) return 'wave'
  if (has('hurricane', 'gust', 'twister', 'air-cutter', 'wind', 'storm', 'blizzard', 'heat-wave', 'tornado')) return 'wind'
  if (has('beam', 'cannon', 'laser', 'ray', 'gleam', 'signal')) return 'beam'
  if (has('voice', 'boomburst', 'buzz', 'snarl', 'roar', 'uproar', 'round', 'clanging', 'overdrive', 'aria', 'sing')) return 'rings'
  if (category === 'special' && has('flame', 'fire', 'ember', 'inferno', 'overheat', 'lava', 'hydro', 'water', 'scald', 'whirlpool', 'steam', 'torch', 'burn'))
    return 'stream'
  if (category === 'special' && type === 'electric') return 'bolt'
  if (category === 'special' && (type === 'psychic' || has('pulse', 'hex', 'shade'))) return 'rings'
  return category === 'physical' ? 'tackle' : 'orb'
}

/** Quanto tempo (ms) cada estilo leva, para a tela esperar. */
export const FX_DURATION = {
  tackle: 650, punch: 650, kick: 650, bite: 700, slash: 700, orb: 700, beam: 750, stream: 900, volley: 900,
  bolt: 650, quake: 900, rocks: 900, meteor: 1000, wave: 1000, wind: 950, rings: 850, drain: 1100,
}

/**
 * Peças da animação de [kind] do lado [from] (0 = você, 1 = o computador),
 * de A (quem ataca) até T (o alvo).
 */
export function fxPlan(kind, type, from, A, T) {
  const p = TYPE_PARTICLE[type] ?? '⭐'
  const parts = []
  const emoji = (char, x0, y0, x1, y1, extra = {}) =>
    parts.push({ shape: 'emoji', char, x0, y0, x1, y1, delay: 0, dur: 450, s0: 0.6, s1: 1.2, o0: 1, o1: 0, rot: 0, size: 12, ...extra })
  const burst = (delay, size = 16) => emoji(p, T.x, T.y, T.x, T.y, { delay, dur: 380, s0: 0.3, s1: 1.6, size })
  const around = (n, radius, delay, extra = {}) => {
    for (let i = 0; i < n; i++) {
      const a = (i / n) * Math.PI * 2
      emoji(p, T.x, T.y, T.x + Math.cos(a) * radius, T.y + Math.sin(a) * radius * 1.4, { delay, dur: 450, s0: 0.5, s1: 1, size: 8, ...extra })
    }
  }
  let shake = false
  let flash = false
  switch (kind) {
    case 'punch':
    case 'kick':
      emoji(kind === 'punch' ? '👊' : '🦶', T.x, T.y, T.x, T.y, { delay: 150, dur: 380, s0: 2, s1: 0.9, o0: 0.4, o1: 1, size: 18 })
      emoji(kind === 'punch' ? '👊' : '🦶', T.x, T.y, T.x, T.y, { delay: 530, dur: 120, s0: 0.9, s1: 1.1, o0: 1, o1: 0, size: 18 })
      around(5, 9, 450)
      break
    case 'bite':
      emoji('🦷', T.x, T.y - 16, T.x, T.y - 4, { delay: 100, dur: 300, s0: 1, s1: 1, o0: 1, o1: 1, rot: 180, size: 14 })
      emoji('🦷', T.x, T.y + 16, T.x, T.y + 4, { delay: 100, dur: 300, s0: 1, s1: 1, o0: 1, o1: 1, size: 14 })
      around(5, 9, 420)
      break
    case 'slash':
      for (let i = 0; i < 3; i++) {
        const dx = (i - 1) * 5
        parts.push({ shape: 'line', x0: T.x - 9 + dx, y0: T.y - 14, x1: T.x + 9 + dx, y1: T.y + 14, delay: 100 + i * 130, dur: 260, width: 3 })
      }
      around(4, 8, 480)
      break
    case 'beam':
      parts.push({ shape: 'line', x0: A.x, y0: A.y, x1: T.x, y1: T.y, delay: 0, dur: 500, width: 9 })
      for (let i = 1; i <= 6; i++) emoji(p, A.x + ((T.x - A.x) * i) / 7, A.y + ((T.y - A.y) * i) / 7, A.x + ((T.x - A.x) * i) / 7, A.y + ((T.y - A.y) * i) / 7, { delay: i * 50, dur: 400, s0: 0.4, s1: 1, size: 7 })
      burst(450)
      break
    case 'stream':
      for (let i = 0; i < 9; i++) emoji(p, A.x, A.y, T.x + ((i % 3) - 1) * 3, T.y + (((i + 1) % 3) - 1) * 4, { delay: i * 60, dur: 420, s0: 0.5, s1: 1.3, o0: 1, o1: 0.2, size: 9 })
      burst(620)
      break
    case 'volley':
      for (let i = 0; i < 5; i++) {
        emoji(p, A.x, A.y, T.x + ((i % 3) - 1) * 4, T.y + ((i % 2) * 2 - 1) * 4, { delay: i * 110, dur: 330, s0: 0.7, s1: 1, o0: 1, o1: 1, rot: 360, size: 8 })
        emoji(p, T.x + ((i % 3) - 1) * 4, T.y + ((i % 2) * 2 - 1) * 4, T.x + ((i % 3) - 1) * 4, T.y + ((i % 2) * 2 - 1) * 4, { delay: i * 110 + 330, dur: 200, s0: 1, s1: 1.8, size: 8 })
      }
      break
    case 'bolt': {
      const zig = [
        [T.x - 4, 0],
        [T.x + 5, T.y * 0.35],
        [T.x - 3, T.y * 0.6],
        [T.x + 3, T.y * 0.8],
        [T.x, T.y],
      ]
      for (let i = 0; i < zig.length - 1; i++) parts.push({ shape: 'line', x0: zig[i][0], y0: zig[i][1], x1: zig[i + 1][0], y1: zig[i + 1][1], delay: i * 50, dur: 350, width: 5 })
      flash = true
      burst(300, 20)
      around(6, 10, 350)
      break
    }
    case 'quake':
      shake = true
      for (let i = 0; i < 7; i++) emoji(p, T.x + (i - 3) * 6, T.y + 14, T.x + (i - 3) * 7, T.y - 4 - (i % 3) * 5, { delay: 100 + i * 60, dur: 500, s0: 0.6, s1: 1, size: 8 })
      burst(600)
      break
    case 'rocks':
      for (let i = 0; i < 5; i++) emoji(p, T.x + (i - 2) * 6, -10, T.x + (i - 2) * 4, T.y + ((i % 2) * 2 - 1) * 3, { delay: i * 100, dur: 400, s0: 1, s1: 1, o0: 1, o1: 1, rot: 180, size: 11 })
      burst(650)
      break
    case 'meteor':
      for (let i = 0; i < 3; i++) emoji(p, T.x - 40 + i * 10, -15, T.x + (i - 1) * 5, T.y, { delay: i * 200, dur: 450, s0: 1.4, s1: 1, o0: 1, o1: 1, size: 14 })
      flash = true
      burst(800, 22)
      break
    case 'wave':
      parts.push({ shape: 'wave', dir: from === 0 ? 1 : -1, delay: 0, dur: 850 })
      for (let i = 0; i < 6; i++) emoji(p, from === 0 ? 5 : 95, 30 + i * 10, from === 0 ? 95 : 5, 20 + i * 11, { delay: i * 70, dur: 700, s0: 0.8, s1: 1, o0: 1, o1: 0.3, size: 8 })
      break
    case 'wind':
      for (let i = 0; i < 8; i++) {
        const a = (i / 8) * Math.PI * 2
        emoji(p, T.x + Math.cos(a) * 16, T.y + Math.sin(a) * 20, T.x + Math.cos(a + 2.4) * 3, T.y + Math.sin(a + 2.4) * 4, { delay: i * 60, dur: 520, s0: 1, s1: 0.5, o0: 1, o1: 0.2, rot: 540, size: 9 })
      }
      burst(700)
      break
    case 'rings':
      for (let i = 0; i < 3; i++) parts.push({ shape: 'ring', x: T.x, y: T.y, delay: i * 180, dur: 500 })
      around(4, 10, 500, { size: 7 })
      break
    case 'drain':
      burst(0)
      for (let i = 0; i < 6; i++) emoji('💚', T.x + ((i % 3) - 1) * 5, T.y + ((i % 2) * 2 - 1) * 5, A.x, A.y, { delay: 300 + i * 90, dur: 500, s0: 1, s1: 0.6, o0: 1, o1: 0.3, size: 8 })
      break
    case 'orb':
      emoji(p, A.x, A.y, T.x, T.y, { delay: 0, dur: 420, s0: 0.6, s1: 1.8, o0: 1, o1: 1, rot: 360, size: 12 })
      burst(420, 20)
      around(5, 9, 450)
      break
    default:
      // Investida: quem ataca vai com tudo até o alvo.
      burst(250, 18)
      around(6, 10, 300)
  }
  return { parts, shake, flash }
}
