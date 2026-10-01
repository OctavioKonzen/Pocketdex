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

/**
 * Peças da animação de um golpe: [kind] (estilo), [icon] (símbolo do golpe,
 * de move_anims.json) e [variant] (a variação dele, que muda quantidade,
 * ângulo, giro, tamanho e ritmo). Do lado [from] (0 = você, 1 = o computador),
 * de A (quem ataca) até T (o alvo). Igual ao app (move_anim.dart).
 */
export function fxPlan(kind, type, from, A, T, icon = null, variant = 0) {
  const q = TYPE_PARTICLE[type] ?? '⭐'
  const p = icon ?? q
  const v = variant
  const extra = v % 3
  const turn = ((v * 47) % 360) * (Math.PI / 180)
  const spin = v % 2 === 0 ? 1 : -1
  const spread = 1 + (v % 4) * 0.15
  const pace = 1 + (Math.floor(v / 4) % 3) * 0.15
  const grow = 1 + ((Math.floor(v / 2) % 3) - 1) * 0.12
  const parts = []
  const emoji = (char, x0, y0, x1, y1, extraProps = {}) => {
    const e = { shape: 'emoji', char, x0, y0, x1, y1, delay: 0, dur: 450, s0: 0.6, s1: 1.2, o0: 1, o1: 0, rot: 0, size: 12, ...extraProps }
    parts.push({ ...e, delay: Math.round(e.delay * pace), rot: e.rot * spin, size: e.size * grow })
  }
  const burst = (delay, size = 16, char = p) => emoji(char, T.x, T.y, T.x, T.y, { delay, dur: 380, s0: 0.3, s1: 1.6, size })
  const around = (n, radius, delay, extraProps = {}, char = q) => {
    const total = n + extra
    for (let i = 0; i < total; i++) {
      const a = turn + (i / total) * Math.PI * 2
      const r = radius * spread
      emoji(char, T.x, T.y, T.x + Math.cos(a) * r, T.y + Math.sin(a) * r * 1.4, { delay, dur: 450, s0: 0.5, s1: 1, size: 8, ...extraProps })
    }
  }
  const line = (x0, y0, x1, y1, delay, dur, width) =>
    parts.push({ shape: 'line', x0, y0, x1, y1, delay: Math.round(delay * pace), dur, width: width * grow })
  let shake = false
  let flash = false
  switch (kind) {
    case 'punch':
    case 'kick': {
      const limb = kind === 'punch' ? '👊' : '🦶'
      emoji(limb, T.x, T.y, T.x, T.y, { delay: 150, dur: 380, s0: 2, s1: 0.9, o0: 0.4, o1: 1, size: 18 })
      emoji(limb, T.x, T.y, T.x, T.y, { delay: 530, dur: 120, s0: 0.9, s1: 1.1, o0: 1, o1: 0, size: 18 })
      around(5, 9, 450, {}, p)
      break
    }
    case 'bite':
      emoji('🦷', T.x, T.y - 16, T.x, T.y - 4, { delay: 100, dur: 300, s0: 1, s1: 1, o0: 1, o1: 1, rot: 180, size: 14 })
      emoji('🦷', T.x, T.y + 16, T.x, T.y + 4, { delay: 100, dur: 300, s0: 1, s1: 1, o0: 1, o1: 1, size: 14 })
      around(5, 9, 420, {}, p)
      break
    case 'slash':
      for (let i = 0; i < 3 + (extra > 1 ? 1 : 0); i++) {
        const dx = (i - 1) * 5 * spread
        const tilt = spin * 9
        line(T.x - tilt + dx, T.y - 14, T.x + tilt + dx, T.y + 14, 100 + i * 130, 260, 3)
      }
      around(4, 8, 480, {}, p)
      break
    case 'beam': {
      line(A.x, A.y, T.x, T.y, 0, 500, 9)
      const n = 6 + extra
      for (let i = 1; i <= n; i++) {
        const x = A.x + ((T.x - A.x) * i) / (n + 1)
        const y = A.y + ((T.y - A.y) * i) / (n + 1)
        emoji(p, x, y, x, y, { delay: i * 50, dur: 400, s0: 0.4, s1: 1, size: 7 })
      }
      burst(450, 16, q)
      break
    }
    case 'stream':
      for (let i = 0; i < 9 + extra * 2; i++)
        emoji(p, A.x, A.y, T.x + ((i % 3) - 1) * 3 * spread, T.y + (((i + 1) % 3) - 1) * 4 * spread, { delay: i * 60, dur: 420, s0: 0.5, s1: 1.3, o0: 1, o1: 0.2, size: 9 })
      burst(620 + extra * 120, 16, q)
      break
    case 'volley':
      for (let i = 0; i < 5 + extra; i++) {
        const x = T.x + ((i % 3) - 1) * 4 * spread
        const y = T.y + ((i % 2) * 2 - 1) * 4 * spread
        emoji(p, A.x, A.y, x, y, { delay: i * 110, dur: 330, s0: 0.7, s1: 1, o0: 1, o1: 1, rot: 360, size: 8 })
        emoji(q, x, y, x, y, { delay: i * 110 + 330, dur: 200, s0: 1, s1: 1.8, size: 8 })
      }
      break
    case 'bolt': {
      const zig = [
        [T.x - 4 * spin, 0],
        [T.x + 5 * spin * spread, T.y * 0.35],
        [T.x - 3 * spin * spread, T.y * 0.6],
        [T.x + 3 * spin, T.y * 0.8],
        [T.x, T.y],
      ]
      for (let i = 0; i < zig.length - 1; i++) line(zig[i][0], zig[i][1], zig[i + 1][0], zig[i + 1][1], i * 50, 350, 5)
      flash = true
      burst(300, 20)
      around(6, 10, 350)
      break
    }
    case 'quake':
      shake = true
      for (let i = 0; i < 7 + extra; i++)
        emoji(p, T.x + (i - 3) * 6 * spread, T.y + 14, T.x + (i - 3) * 7 * spread, T.y - 4 - (i % 3) * 5, { delay: 100 + i * 60, dur: 500, s0: 0.6, s1: 1, size: 8 })
      burst(600, 16, q)
      break
    case 'rocks':
      for (let i = 0; i < 5 + extra; i++)
        emoji(p, T.x + (i - 2) * 6 * spread, -10, T.x + (i - 2) * 4, T.y + ((i % 2) * 2 - 1) * 3, { delay: i * 100, dur: 400, s0: 1, s1: 1, o0: 1, o1: 1, rot: 180, size: 11 })
      burst(650 + extra * 100, 16, q)
      break
    case 'meteor':
      for (let i = 0; i < 3 + extra; i++)
        emoji(p, T.x - 40 * spin + i * 10 * spin, -15, T.x + (i - 1) * 5, T.y, { delay: i * 200, dur: 450, s0: 1.4, s1: 1, o0: 1, o1: 1, size: 14 })
      flash = true
      burst(800 + extra * 200, 22, q)
      break
    case 'wave':
      parts.push({ shape: 'wave', dir: from === 0 ? 1 : -1, delay: 0, dur: 850 })
      for (let i = 0; i < 6 + extra; i++)
        emoji(p, from === 0 ? 5 : 95, 30 + i * 10, from === 0 ? 95 : 5, 20 + i * 11 * spread, { delay: i * 70, dur: 700, s0: 0.8, s1: 1, o0: 1, o1: 0.3, size: 8 })
      break
    case 'wind':
      for (let i = 0; i < 8 + extra; i++) {
        const a = turn + (i / (8 + extra)) * Math.PI * 2
        emoji(p, T.x + Math.cos(a) * 16 * spread, T.y + Math.sin(a) * 20 * spread, T.x + Math.cos(a + 2.4 * spin) * 3, T.y + Math.sin(a + 2.4 * spin) * 4, {
          delay: i * 60,
          dur: 520,
          s0: 1,
          s1: 0.5,
          o0: 1,
          o1: 0.2,
          rot: 540,
          size: 9,
        })
      }
      burst(700, 16, q)
      break
    case 'rings':
      for (let i = 0; i < 3 + extra; i++) parts.push({ shape: 'ring', x: T.x, y: T.y, delay: Math.round(i * 180 * pace), dur: 500 })
      around(4, 10, 500, { size: 7 }, p)
      break
    case 'drain':
      burst(0, 16, q)
      for (let i = 0; i < 6 + extra; i++)
        emoji(p, T.x + ((i % 3) - 1) * 5 * spread, T.y + ((i % 2) * 2 - 1) * 5, A.x, A.y, { delay: 300 + i * 90, dur: 500, s0: 1, s1: 0.6, o0: 1, o1: 0.3, size: 8 })
      break
    case 'orb':
      emoji(p, A.x, A.y, T.x, T.y, { delay: 0, dur: 420, s0: 0.6, s1: 1.8, o0: 1, o1: 1, rot: 360, size: 12 })
      burst(420, 20, q)
      around(5, 9, 450)
      break
    default:
      // Investida: quem ataca vai com tudo até o alvo.
      burst(250, 18)
      around(6, 10, 300)
  }
  const duration = Math.max(...parts.map((x) => x.delay + x.dur))
  return { parts, shake, flash, duration }
}
