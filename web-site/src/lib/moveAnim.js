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
//
// Golpes de status também têm a sua: atributo subindo (boost) ou descendo
// (drop), cura, redoma, barreira, pó, sinal do problema no alvo, armadilha no
// chão, clima, terreno, campo, energia juntando, explosão...

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
/** Estilos que acontecem em quem usa o golpe (ele não avança até o alvo). */
export const SELF_KINDS = new Set(['boost', 'heal', 'shield', 'charge', 'weather', 'terrain', 'field', 'wall', 'explode'])

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
  const burstAt = (C, delay, size = 16, char = p) => emoji(char, C.x, C.y, C.x, C.y, { delay, dur: 380, s0: 0.3, s1: 1.6, size })
  const burst = (delay, size = 16, char = p) => burstAt(T, delay, size, char)
  const aroundAt = (C, n, radius, delay, extraProps = {}, char = q) => {
    const total = n + extra
    for (let i = 0; i < total; i++) {
      const a = turn + (i / total) * Math.PI * 2
      const r = radius * spread
      emoji(char, C.x, C.y, C.x + Math.cos(a) * r, C.y + Math.sin(a) * r * 1.4, { delay, dur: 450, s0: 0.5, s1: 1, size: 8, ...extraProps })
    }
  }
  const around = (n, radius, delay, extraProps = {}, char = q) => aroundAt(T, n, radius, delay, extraProps, char)
  const ring = (C, delay, dur = 500) => parts.push({ shape: 'ring', x: C.x, y: C.y, delay: Math.round(delay * pace), dur })
  // Meio do campo e a direção de quem ataca até o alvo.
  const M = { x: (A.x + T.x) / 2, y: (A.y + T.y) / 2 }
  const len = Math.hypot(T.x - A.x, T.y - A.y) || 1
  const ux = (T.x - A.x) / len
  const uy = (T.y - A.y) / len
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
      for (let i = 0; i < 3 + extra; i++) ring(T, i * 180)
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
    case 'boost':
    case 'drop': {
      // Atributo subindo em quem usa (Swords Dance) ou descendo no alvo (Growl, Screech).
      const C = kind === 'boost' ? A : T
      const up = kind === 'boost'
      const n = 4 + extra
      ring(C, 0)
      emoji(p, C.x, C.y, C.x, C.y + (up ? -8 : 8), { delay: 0, dur: 650, s0: 0.5, s1: 1.7, o0: 1, o1: 0, size: 16 })
      for (let i = 0; i < n; i++) {
        const x = C.x + (i - (n - 1) / 2) * 5 * spread
        const y0 = C.y + (up ? 12 : -16) + (i % 2) * 3
        emoji(up ? '⬆️' : '⬇️', x, y0, x, y0 + (up ? -26 : 26), { delay: 120 + i * 90, dur: 480, s0: 0.8, s1: 1, o0: 1, o1: 0, size: 8 })
      }
      break
    }
    case 'heal':
      // Recover, Roost, Synthesis: brilho subindo em quem usa.
      for (let i = 0; i < 6 + extra; i++) {
        const dx = ((i % 3) - 1) * 6 * spread
        emoji(i % 2 ? '✨' : p, A.x + dx, A.y + 14, A.x + dx * 0.5, A.y - 16, { delay: i * 90, dur: 600, s0: 0.5, s1: 1.1, o0: 1, o1: 0, size: 9 })
      }
      ring(A, 250, 600)
      burstAt(A, 600, 18, '💚')
      break
    case 'shield': {
      // Protect, Detect: uma redoma em volta de quem usa.
      const n = 6 + extra
      ring(A, 0, 700)
      for (let i = 0; i < n; i++) {
        const a = turn + (i / n) * Math.PI * 2
        const x = A.x + Math.cos(a) * 13 * spread
        const y = A.y + Math.sin(a) * 18 * spread
        emoji(p, x, y, x, y, { delay: i * 50, dur: 700, s0: 0.3, s1: 1, o0: 0.2, o1: 1, size: 9 })
      }
      burstAt(A, 650, 22, '🛡️')
      break
    }
    case 'wall':
      // Reflect, Light Screen, Aurora Veil: uma barreira entre os dois.
      line(M.x - uy * 18, M.y + ux * 18, M.x + uy * 18, M.y - ux * 18, 0, 750, 6)
      for (let i = 0; i < 4 + extra; i++) {
        const k = (i / (3 + extra) - 0.5) * 32
        const x = M.x - uy * k
        const y = M.y + ux * k
        emoji(p, x, y, x, y, { delay: 100 + i * 80, dur: 600, s0: 0.4, s1: 1.1, o0: 0.3, o1: 1, size: 10 })
      }
      break
    case 'powder':
      // Sleep Powder, Spore, Stun Spore: uma nuvem flutuando até o alvo.
      for (let i = 0; i < 8 + extra * 2; i++) {
        const wob = Math.sin(i * 1.7 + turn) * 6 * spread
        emoji(p, A.x + ux * 6 - uy * wob, A.y + uy * 6 + ux * wob, T.x + ((i % 3) - 1) * 6, T.y + (((i + 1) % 3) - 1) * 6, {
          delay: i * 70,
          dur: 750,
          s0: 0.4,
          s1: 1.2,
          o0: 0.9,
          o1: 0.4,
          rot: 120,
          size: 8,
        })
      }
      around(5, 10, 800, { size: 7 }, p)
      break
    case 'status':
      // Thunder Wave, Will-O-Wisp, Toxic, Hypnosis: o sinal do problema no alvo.
      ring(T, 0)
      ring(T, 180)
      emoji(p, T.x, T.y - 2, T.x, T.y - 16, { delay: 150, dur: 750, s0: 0.4, s1: 1.6, o0: 1, o1: 0.5, size: 16 })
      around(4, 11, 400, { size: 7 }, p)
      break
    case 'hazard':
      // Stealth Rock, Spikes, Toxic Spikes, Sticky Web: espalhados no chão do outro lado.
      for (let i = 0; i < 4 + extra; i++) {
        const x = T.x + (i - (3 + extra) / 2) * 8 * spread
        const y = T.y + 16 + (i % 2) * 4
        emoji(p, A.x, A.y, x, y, { delay: i * 110, dur: 500, s0: 0.6, s1: 1, o0: 1, o1: 1, rot: 270, size: 10 })
        emoji(p, x, y, x, y, { delay: i * 110 + 500, dur: 300, s0: 1, s1: 1.3, o0: 1, o1: 0, size: 10 })
      }
      break
    case 'weather':
      // Sunny Day, Rain Dance, Sandstorm, Snowscape: caindo do céu no campo todo.
      for (let i = 0; i < 12 + extra * 2; i++) {
        const x = 4 + ((i * 37 + v * 11) % 92)
        emoji(p, x, -8, x - 8 * spin, 100, { delay: i * 70, dur: 800, s0: 1, s1: 1, o0: 1, o1: 0.3, size: 9 })
      }
      break
    case 'terrain':
      // Electric, Grassy, Misty, Psychic Terrain: subindo do chão no campo todo.
      parts.push({ shape: 'wave', dir: from === 0 ? 1 : -1, delay: 0, dur: 900 })
      for (let i = 0; i < 10 + extra * 2; i++) {
        const x = 4 + ((i * 41 + v * 13) % 92)
        emoji(p, x, 100, x, 62 - (i % 4) * 6, { delay: i * 60, dur: 700, s0: 0.5, s1: 1.2, o0: 1, o1: 0, size: 9 })
      }
      break
    case 'field':
      // Trick Room, Gravity, Magic Room: o campo todo muda.
      for (let i = 0; i < 3 + extra; i++) ring(M, i * 200, 650)
      emoji(p, M.x, M.y, M.x, M.y, { delay: 100, dur: 900, s0: 0.4, s1: 2.4, o0: 1, o1: 0, rot: 180, size: 18 })
      aroundAt(M, 6, 22, 500, { size: 8 }, p)
      break
    case 'charge':
      // Focus Energy, Charge, Stockpile, Geomancy: energia se juntando em quem usa.
      for (let i = 0; i < 7 + extra; i++) {
        const a = turn + (i / (7 + extra)) * Math.PI * 2
        emoji(p, A.x + Math.cos(a) * 22 * spread, A.y + Math.sin(a) * 26 * spread, A.x, A.y, { delay: i * 60, dur: 450, s0: 1, s1: 0.4, o0: 0.3, o1: 1, size: 8 })
      }
      burstAt(A, 650, 22, p)
      ring(A, 650)
      break
    case 'explode':
      // Explosion, Self-Destruct, Mind Blown: estoura em quem usa e acerta tudo.
      shake = true
      flash = true
      emoji('💥', A.x, A.y, A.x, A.y, { delay: 0, dur: 600, s0: 0.3, s1: 3, o0: 1, o1: 0, size: 24 })
      ring(A, 0, 600)
      ring(A, 200, 600)
      aroundAt(A, 8, 22, 150, { size: 10 }, p)
      burst(400, 18, p)
      break
    case 'spin':
      // Rapid Spin, Rollout, Gyro Ball: rodando até o alvo.
      for (let i = 0; i < 2 + extra; i++)
        emoji(p, A.x, A.y, T.x, T.y, { delay: i * 90, dur: 480, s0: 1 - i * 0.2, s1: 1.3 - i * 0.2, o0: 1 - i * 0.3, o1: 1 - i * 0.3, rot: 900, size: 13 })
      burst(480, 18, q)
      around(5, 9, 520)
      break
    case 'dive':
      // Fly, Bounce, Heavy Slam: cai do alto em cima do alvo.
      shake = true
      emoji(p, T.x + 8 * spin, -18, T.x, T.y, { delay: 150, dur: 380, s0: 1.8, s1: 1, o0: 1, o1: 1, rot: 40, size: 16 })
      burst(530, 22, q)
      around(6, 11, 560)
      break
    case 'pierce':
      // Horn Attack, Poison Jab, Drill Peck: estocadas finas e rápidas.
      for (let i = 0; i < 3 + extra; i++) {
        const off = (i - (2 + extra) / 2) * 4 * spread
        line(T.x - ux * 20 - uy * off, T.y - uy * 20 + ux * off, T.x + ux * 4 - uy * off, T.y + uy * 4 + ux * off, i * 110, 200, 2)
        emoji(p, T.x - uy * off, T.y + ux * off, T.x - uy * off, T.y + ux * off, { delay: i * 110 + 150, dur: 250, s0: 0.5, s1: 1.3, size: 8 })
      }
      around(4, 8, 450)
      break
    case 'whip': {
      // Vine Whip, Iron Tail, Slam: um chicote varrendo o alvo.
      const n = 6 + extra
      for (let i = 0; i < n; i++) {
        const a0 = -1.1 + (i / n) * 2.2
        const a1 = -1.1 + ((i + 1) / n) * 2.2
        const r = 16 * spread
        line(T.x + Math.sin(a0) * r * spin, T.y - Math.cos(a0) * r, T.x + Math.sin(a1) * r * spin, T.y - Math.cos(a1) * r, i * 45, 300, 4)
      }
      burst(320, 16, p)
      around(5, 9, 360)
      break
    }
    case 'swap':
      // Trick, Skill Swap, Switcheroo: um vai, o outro vem.
      emoji(p, A.x, A.y, T.x, T.y, { delay: 0, dur: 600, s0: 0.8, s1: 1.2, o0: 1, o1: 1, rot: 360, size: 13 })
      emoji(q, T.x, T.y, A.x, A.y, { delay: 0, dur: 600, s0: 0.8, s1: 1.2, o0: 1, o1: 1, rot: -360, size: 13 })
      burstAt(A, 600, 14, q)
      burst(600, 14, p)
      break
    default:
      // Investida: quem ataca vai com tudo até o alvo.
      burst(250, 18)
      around(6, 10, 300)
  }
  const duration = Math.max(...parts.map((x) => x.delay + x.dur))
  return { parts, shake, flash, duration }
}
