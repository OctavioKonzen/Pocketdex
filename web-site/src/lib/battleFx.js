// Animações dos golpes no nível do port de Black & White: cada golpe tem fases (carga, golpe, impacto, sumir), a
// câmera acompanha (vai até quem ataca, dá zoom no alvo e volta), os Pokémon ficam da cor do golpe, recuam e piscam
// em silhueta branca, e os efeitos são desenhados (brilhos, raios, teias, ondas, pedras, folhas), sem emoji.
// Igual ao app (lib/services/battle_fx.dart).
//
// fxPlan2 devolve só números e cores (quem desenha é o fxPainter.js no site e o battle_fx_painter.dart no app):
//   dur      quanto dura (ms)
//   cam      [[ms, x, y, zoom, giro]] a câmera (x, y: o ponto do mundo no meio da tela; o mundo tem 960 × 540)
//   hud      [de, até] quando os HPs e a caixa de texto somem
//   shake    [[de, até, força]] a tela tremendo
//   sprites  [{who: 'A' | 'T', k: 'tint' | 'flash' | 'move' | 'hide' | 'squash', t0, t1, ...}] o que acontece com quem ataca (A) e o alvo (T)
//   layers   [{s: forma, t0, t1, ...}] o que é desenhado, de trás para a frente:
//            glow, rays, ring, particles, bolt, beam, web, arc, fill, tint, wave, crack, cone
//            Um número pode ser [de, até] (anda ao longo da camada) e um ponto {x, y} vira [{x, y}, {x, y}] para andar.

import { moveAnim } from './moveAnim'

/** As cores de cada tipo: [miolo, meio, borda, sombra] e o jeito das partículas. */
export const FX_TYPES = {
  normal: { c: ['#ffffff', '#f4f1e8', '#c9c3b0', '#6f6a5b'], p: 'star' },
  fire: { c: ['#fff7c2', '#ffb02e', '#e5391a', '#7a1406'], p: 'ember' },
  water: { c: ['#e8fbff', '#5cc8ff', '#1f6fd6', '#0b3b8a'], p: 'bubble' },
  electric: { c: ['#ffffe6', '#ffe94a', '#f5b800', '#7a5c00'], p: 'spark' },
  grass: { c: ['#f1ffd0', '#9be35a', '#3fa34d', '#1d5a2a'], p: 'leaf' },
  ice: { c: ['#ffffff', '#c8f6ff', '#6cc9f0', '#2a6fa8'], p: 'crystal' },
  fighting: { c: ['#fff2e0', '#ffb067', '#d0562b', '#6b2412'], p: 'star' },
  poison: { c: ['#f6dcff', '#c56cf0', '#8e2fc2', '#43125e'], p: 'bubble' },
  ground: { c: ['#fff1cf', '#e0b866', '#a8742e', '#5b3c12'], p: 'dust' },
  flying: { c: ['#ffffff', '#e4f3ff', '#9cc8ee', '#5f86b0'], p: 'feather' },
  psychic: { c: ['#fff0fb', '#ff8fd0', '#e2479c', '#7a1f57'], p: 'dot' },
  bug: { c: ['#f7ffd6', '#c9e04a', '#8aa61c', '#3f4f0b'], p: 'dot' },
  rock: { c: ['#fff3dd', '#d6b98a', '#9b7c4f', '#4f3b20'], p: 'shard' },
  ghost: { c: ['#f3e8ff', '#a78bfa', '#6d3fc9', '#2a1450'], p: 'wisp' },
  dragon: { c: ['#eef0ff', '#9aa6ff', '#5a4ae0', '#24166b'], p: 'ember' },
  dark: { c: ['#ece6f6', '#8a76a8', '#3d2f55', '#120b1d'], p: 'wisp' },
  steel: { c: ['#ffffff', '#e3eaf2', '#9aaabd', '#4c5a6b'], p: 'glint' },
  fairy: { c: ['#fff4fb', '#ffc6e8', '#f77fbe', '#9a2f6d'], p: 'star' },
  stellar: { c: ['#ffffff', '#bfe9ff', '#7b8cff', '#30206e'], p: 'star' },
  shadow: { c: ['#e8e0f2', '#6b4f8a', '#2e1d40', '#0b0612'], p: 'wisp' },
}

/** Onde cada um fica na tela, sem zoom: você de costas embaixo à esquerda (grande, cortado pela borda), o outro em cima à direita. */
export const FX_STAGE = {
  w: 960,
  h: 540,
  // pé (x, y) e altura do sprite
  near: { x: 285, y: 655, h: 330 },
  far: { x: 590, y: 335, h: 220 },
}


/** O estilo das partículas de cada forma. */
const MOTIF_STYLE = {
  petal: 'leaf', rock: 'shard', crystal: 'crystal', heart: 'heart', moon: 'moon', sun: 'sun', star: 'star', note: 'note',
  gear: 'gear', wisp: 'wisp', dragon: 'ember', bubble: 'bubble', flame: 'ember', spark: 'spark', goo: 'goo', dust: 'dust',
  ring: 'dot', eye: 'dot', wing: 'feather', web: 'dot', fist: 'star', foot: 'star', head: 'star', body: 'star',
  fang: 'star', claw: 'streak', blade: 'streak', horn: 'glint', whip: 'streak',
}

/** O efeito no fim de cada golpe: queimar, congelar, paralisar, envenenar, dormir, confundir, atributos. */
const FX_EFFECT = {
  burn: { n: 22, vy: -180, size: [10, 3], style: 'ember', c: ['#fff7c2', '#ffb02e', '#e5391a'], tint: '#ff5a1a' },
  freeze: { n: 16, vy: 40, size: [16, 8], style: 'crystal', c: ['#ffffff', '#c8f6ff', '#6cc9f0'], tint: '#9ee8ff', ring: '#c8f6ff' },
  para: { n: 14, vy: 0, v: 160, size: [8, 3], style: 'spark', c: ['#ffffff', '#ffe94a'], tint: '#ffe94a', bolt: 1 },
  poison: { n: 18, vy: -120, size: [12, 6], style: 'goo', c: ['#f6dcff', '#c56cf0', '#8e2fc2'], tint: '#a855f7' },
  sleep: { n: 6, vy: -90, v: 40, size: [18, 26], style: 'zzz', c: ['#ffffff', '#c7d2fe'], tint: '#818cf8' },
  confuse: { n: 8, vy: 0, mode: 'orbit', size: [14, 14], style: 'star', c: ['#fff7c2', '#facc15'] },
  flinch: { n: 6, vy: 0, mode: 'orbit', size: [12, 12], style: 'star', c: ['#ffffff', '#fde68a'] },
  trap: { n: 10, vy: 0, mode: 'orbit', size: [10, 10], style: 'dot', c: ['#ffffff', '#cbd5e1'], ring: '#e2e8f0' },
  heart: { n: 10, vy: -120, size: [14, 10], style: 'heart', c: ['#ffd6ec', '#f472b6', '#db2777'], tint: '#f472b6' },
  up: { n: 10, vy: -200, size: [16, 12], style: 'arrowUp', c: ['#ffffff', '#fca5a5', '#ef4444'], tint: '#ef4444' },
  down: { n: 10, vy: 200, size: [16, 12], style: 'arrowDown', c: ['#ffffff', '#93c5fd', '#3b82f6'], tint: '#3b82f6' },
  drain: {},
  heal: {},
  recoil: {},
}


/**
 * Onde cada um fica, como no Black & White: o outro no meio-direita, de frente, no tamanho do sprite dele (3×); você
 * de costas à esquerda, maior (5,4×) e cortado pela borda de baixo. [anchors] = fx_anchors.json (boca e frente de
 * cada sprite), [near]/[far] = o id do sprite de cada lado. Devolve, para cada lado, o pé (x, y), a altura, a caixa
 * do sprite na tela e de onde saem os golpes: mouth (Flamethrower, Ice Beam) e front (soco, bola, tiro).
 */
export const FX_SCALE = { far: 3, near: 5.4, farFeet: { x: 590, y: 335 }, nearFeet: { x: 270, y: 600 } }

export function fxStage(anchors, near, far) {
  const place = (id, key, scale, feet, fallback) => {
    const v = anchors?.[id]?.[key]
    if (!v) return fallback
    const [w, h, x0, y0, x1, y1, mx, my, fx, fy] = v
    const left = feet.x - ((x0 + x1) / 2) * scale
    // O de costas baixinho (Clodsire, Snorlax deitado) sobe até aparecer bem acima da caixa de texto.
    const lift = key === 'b' ? Math.max(0, feet.y - (y1 - y0) * scale - 250) : 0
    const top = feet.y - y1 * scale - lift
    return {
      x: feet.x,
      y: feet.y - lift,
      h: (y1 - y0) * scale,
      box: { left, top, w: w * scale, h: h * scale },
      mouth: { x: left + mx * scale, y: top + my * scale },
      front: { x: left + fx * scale, y: top + fy * scale },
    }
  }
  return {
    w: 960,
    h: 540,
    near: place(near, 'b', FX_SCALE.near, FX_SCALE.nearFeet, FX_STAGE.near),
    far: place(far, 'f', FX_SCALE.far, FX_SCALE.farFeet, FX_STAGE.far),
  }
}

const NEUTRAL = [480, 270, 1, 0]
const clamp = (v, a = 0, b = 1) => Math.max(a, Math.min(b, v))

/** Um número pseudo-aleatório de 0 a 1 que sempre dá o mesmo (o mesmo golpe anima sempre igual). */
export function fxRand(i) {
  const x = Math.sin(i * 127.1 + 311.7) * 43758.5453
  return x - Math.floor(x)
}

/** Centro do corpo e topo de quem está em [p] (pé e altura). */
const body = (p, k = 0.5) => ({ x: p.x, y: p.y - p.h * k })

/**
 * O plano da animação de um golpe. [from] 0: você ataca (o alvo é o de cima); 1: o outro ataca.
 * [kind] o estilo (moveAnim / move_anims.json), [slug] o golpe (os marcantes têm animação própria).
 */
export function fxPlan2({ kind, type, slug = '', from = 0, seed = 1, stage = FX_STAGE, recipe = null }) {
  const P = FX_TYPES[type] ?? FX_TYPES.normal
  const [c0, c1, c2, c3] = P.c
  // A câmera sem zoom: o meio do mundo (960 × 540 no harness; no campo 4:3 da batalha, 960 × 720).
  const NEUTRAL = [stage.w / 2, stage.h / 2, 1, 0]
  const A = from === 0 ? stage.near : stage.far
  const T = from === 0 ? stage.far : stage.near
  const a = body(A)
  const tc = body(T)
  // De onde o golpe sai: a boca (jatos, raios, sopros) ou a frente do corpo (bolas, tiros), nunca as costas.
  const mouth = A.mouth ?? { x: a.x + 40 * (from === 0 ? 1 : -1), y: A.y - A.h * 0.7 }
  const front = A.front ?? { x: a.x + 40 * (from === 0 ? 1 : -1), y: a.y }
  const L = [] // camadas
  const S = [] // sprites
  const shake = []
  let cam = []
  let hud = null
  let dur = 0
  const rnd = (i) => fxRand(seed * 13.7 + i)
  const add = (layer) => L.push(layer)
  const end = (ms) => (dur = Math.max(dur, ms))
  // Câmera olhando para um ponto, mais perto (zoom) e com um leve giro.
  const look = (p, z, r = 0) => [p.x, p.y, z, r]
  const toward = from === 0 ? 1 : -1 // para que lado fica o alvo
  // Fases comuns: some o HUD, a câmera vai até o alvo, golpe, volta.
  const strike = (t0, z = 1.45) => {
    cam = [[0, ...NEUTRAL], [t0, ...look(tc, z, -2 * toward)]]
    return t0
  }
  const back = (t, hold = 0) => {
    cam.push([t + hold, ...cam[cam.length - 1].slice(1)])
    cam.push([t + hold + 380, ...NEUTRAL])
    hud = [120, t + hold + 300]
    end(t + hold + 420)
  }
  // O alvo acertado: fica da cor do golpe, recua, a tela treme e ele pisca branco duas vezes depois que a câmera volta.
  const hit = (t, power = 1, tint = c2) => {
    S.push({ who: 'T', k: 'tint', t0: t, t1: t + 420, color: tint, a: 0.55 })
    S.push({ who: 'T', k: 'move', t0: t, t1: t + 380, dx: 18 * toward * power, dy: -4 * power })
    shake.push([t, t + 300, 7 * power])
    if (power > 1.1) add({ s: 'tint', t0: t, t1: t + 140, color: '#ffffff', a: [Math.min(0.55, (power - 1.1) * 0.8), 0] })
    impactBurst(t, power)
  }
  const flashAfter = (t) => S.push({ who: 'T', k: 'flash', t0: t, n: 2 })
  // O estouro do impacto: brilho, raios e partículas do tipo se espalhando.
  const impactBurst = (t, power = 1, at = tc) => {
    add({ s: 'glow', t0: t, t1: t + 320, x: at.x, y: at.y, r: [20, 110 * power], c: [c0, c1, c2], a: [1, 0] })
    add({ s: 'rays', t0: t, t1: t + 260, x: at.x, y: at.y, n: 10, r0: [10, 30], r1: [60, 150 * power], w: 5, c: c0, c2: c1, a: [1, 0], rot: rnd(3) })
    add(typeParticles(t, at, 14 + Math.round(8 * power), 'burst', 420, power))
  }
  // As partículas do tipo (brasas sobem, gotas caem, faíscas se espalham...).
  const typeParticles = (t, at, n, mode = 'burst', life = 500, power = 1) => {
    const style = P.p
    const rise = ['ember', 'wisp', 'dot'].includes(style)
    const fall = ['bubble', 'shard', 'crystal', 'leaf', 'dust'].includes(style)
    return {
      s: 'particles', t0: t, t1: t + life + 120, n, seed: seed + t, x: at.x, y: at.y, sx: 30, sy: 30,
      v: 220 * power, vy: rise ? -160 : fall ? -60 : 0, g: fall ? 520 : rise ? -80 : 0, life, mode,
      size: [style === 'leaf' || style === 'feather' ? 14 : 8, 3], style, c: [c0, c1, c2],
    }
  }

  const has = (str, ...w) => w.some((x) => str.includes(x))
  const contact = ['punch', 'kick', 'bite', 'slash', 'tackle', 'spin', 'dive', 'pierce', 'whip'].includes(kind)

  // ---- Os golpes marcantes, com animação própria ----
  const signature = {
    'fusion-flare': () => {
      // Carrega em quem ataca, a bola de fogo nasce no céu, cresce, desce e explode no alvo.
      const sky = { x: a.x + 40 * toward, y: Math.min(a.y, tc.y) - 230 }
      cam = [[0, ...NEUTRAL], [600, ...look(a, 1.55, 2 * toward)], [1350, ...look({ x: a.x, y: sky.y + 80 }, 1.3, 4 * toward)], [2300, ...look(sky, 1.5, 3 * toward)],
        [2700, ...look({ x: (sky.x + tc.x) / 2, y: (sky.y + tc.y) / 2 }, 1.05, 0)], [2850, ...look(tc, 1.65, -3 * toward)], [3600, ...look(tc, 1.45, -2 * toward)]]
      S.push({ who: 'T', k: 'hide', t0: 300, t1: 2500 })
      S.push({ who: 'A', k: 'tint', t0: 450, t1: 2400, color: '#ff2a0a', a: 0.7, pulse: 25 })
      S.push({ who: 'A', k: 'squash', t0: 500, t1: 1300, sy: 1.06, sx: 0.97 })
      add({ s: 'particles', t0: 500, t1: 2500, n: 70, seed, x: a.x, y: a.y + A.h * 0.3, sx: A.h * 0.45, sy: A.h * 0.2, v: 30, vy: -360, g: -120, life: 1100, mode: 'stream', size: [9, 3], style: 'ember', c: [c0, c1, c2] })
      add({ s: 'tint', t0: 1200, t1: 2800, color: '#1a0200', a: [0, 0.5] })
      add({ s: 'rays', t0: 1500, t1: 2750, x: sky.x, y: sky.y, n: 16, r0: 0, r1: [60, 420], w: [2, 7], c: c1, c2: c3, a: [0.2, 1], rot: [0, 2.2] })
      add({ s: 'particles', t0: 1500, t1: 2700, n: 40, seed: seed + 5, x: sky.x, y: sky.y, sx: 0, sy: 0, mode: 'converge', r: 260, life: 700, size: [4, 7], style: 'ember', c: [c0, c1] })
      add({ s: 'glow', t0: 1500, t1: 2550, x: sky.x, y: sky.y, r: [10, 105], c: [c0, c1, c2, c3], a: 1, core: 0.25 })
      add({ s: 'glow', t0: 2550, t1: 2860, x: [sky.x, tc.x], y: [sky.y, tc.y - 20], r: [105, 230], c: [c0, c1, c2, c3], a: 1, core: 0.25, trail: 1 })
      add({ s: 'tint', t0: 2850, t1: 3050, color: '#fff8e0', a: [1, 0] })
      add({ s: 'fill', t0: 2850, t1: 3900, c: [c1, c2, '#ff6a1a', c3], from: toward > 0 ? 'right' : 'left', a: 0.88 })
      add({ s: 'glow', t0: 2850, t1: 3700, x: tc.x, y: tc.y, r: [120, 420], c: ['#fffbe0', c1, c2], a: [0.95, 0] })
      add({ s: 'particles', t0: 3300, t1: 4600, n: 36, seed: seed + 9, x: tc.x, y: tc.y + T.h * 0.3, sx: T.h * 0.6, sy: 20, v: 20, vy: -120, g: -30, life: 1200, mode: 'stream', size: [10, 3], style: 'smoke', c: ['#3b3b3b', '#555', '#222'] })
      S.push({ who: 'T', k: 'tint', t0: 2850, t1: 3900, color: '#ff2a0a', a: 0.7, pulse: 30 })
      S.push({ who: 'T', k: 'move', t0: 2850, t1: 3300, dx: 26 * toward, dy: 6 })
      shake.push([2850, 3600, 12])
      hud = [150, 3900]
      cam.push([3950, ...NEUTRAL])
      flashAfter(4050)
      end(4500)
    },
    // ---- Lote 1, feitos à mão como no Black & White ----
    thunderbolt: () => {
      // Carrega faíscas no corpo, o raio sai e acerta em zigue-zague, o alvo fica eletrificado.
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.35, 2 * toward)], [800, ...look(a, 1.35, 2 * toward)], [1000, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.05, 0)], [1200, ...look(tc, 1.45, -2 * toward)]]
      S.push({ who: 'A', k: 'tint', t0: 250, t1: 950, color: '#ffe94a', a: 0.55, pulse: 40 })
      add({ s: 'bolt', t0: 250, t1: 950, x: a.x, y: a.y, r: A.h * 0.55, n: 6, c: '#ffffff', c2: '#ffe94a', w: 3, flicker: 1 })
      add({ s: 'tint', t0: 900, t1: 1500, color: '#05040f', a: [0.45, 0.1] })
      for (let i = 0; i < 3; i++) add({ s: 'bolt', t0: 950 + i * 90, t1: 1250 + i * 90, x: tc.x, y: tc.y, r: 0, from: mouth, n: 10, c: '#ffffff', c2: '#ffd400', w: 7 - i, flicker: 1 })
      add({ s: 'tint', t0: 1000, t1: 1100, color: '#ffffff', a: [0.85, 0] })
      add({ s: 'bolt', t0: 1150, t1: 1800, x: tc.x, y: tc.y, r: 120, n: 7, c: '#ffffff', c2: '#ffe94a', w: 3, flicker: 1 })
      add({ s: 'particles', t0: 1150, t1: 1800, n: 26, seed, x: tc.x, y: tc.y, sx: 90, sy: 80, v: 120, vy: 0, g: 0, life: 260, mode: 'stream', size: [7, 2], style: 'spark', c: ['#ffffff', '#ffe94a'] })
      hit(1050, 1.2, '#ffe94a')
      S.push({ who: 'T', k: 'tint', t0: 1100, t1: 1800, color: '#ffe94a', a: 0.55, pulse: 45 })
      back(1800, 60)
      flashAfter(2350)
    },
    flamethrower: () => {
      // Brasa na boca, o jato de fogo grosso cobre o alvo, que pega fogo.
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.3, 2 * toward)], [700, ...look({ x: a.x * 0.4 + tc.x * 0.6, y: a.y * 0.4 + tc.y * 0.6 }, 1.15, -toward)], [1500, ...look(tc, 1.45, -2 * toward)]]
      add({ s: 'glow', t0: 200, t1: 1600, x: mouth.x, y: mouth.y, r: [6, 46], c: ['#fff7c2', '#ffb02e', '#e5391a'], a: [1, 0.8] })
      add({ s: 'particles', t0: 450, t1: 1650, n: 190, seed, x: [mouth.x, tc.x], y: [mouth.y, tc.y], sx: 8, sy: 8, spread: 34, mode: 'jet', life: 380, size: [14, 34], style: 'flame', c: ['#fff7c2', '#ffd23a', '#ff6a12', '#d6200f'] })
      add({ s: 'particles', t0: 500, t1: 1650, n: 60, seed: seed + 2, x: [mouth.x, tc.x], y: [mouth.y, tc.y], sx: 6, sy: 6, spread: 20, mode: 'jet', life: 420, size: [6, 3], style: 'ember', c: ['#ffffff', '#ffd23a'] })
      add({ s: 'glow', t0: 800, t1: 1800, x: tc.x, y: tc.y, r: [40, 140], c: ['#fff7c2', '#ff8a2a', '#d6200f'], a: [0.95, 0] })
      add({ s: 'particles', t0: 900, t1: 2000, n: 40, seed: seed + 4, x: tc.x, y: T.y, sx: T.h * 0.4, sy: 10, v: 20, vy: -260, g: -60, life: 700, mode: 'stream', size: [12, 4], style: 'ember', c: ['#fff7c2', '#ffb02e', '#e5391a'] })
      hit(850, 1.1, '#ff5a1a')
      S.push({ who: 'T', k: 'tint', t0: 850, t1: 1900, color: '#ff4a0a', a: 0.6, pulse: 22 })
      back(1900, 60)
      flashAfter(2450)
    },
    'ice-beam': () => {
      // Cristais se juntam na boca, o raio azul-claro gela o caminho e o alvo fica coberto de gelo.
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.35, 2 * toward)], [850, ...look(a, 1.35, 2 * toward)], [1050, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.0, 0)], [1300, ...look(tc, 1.45, -2 * toward)]]
      add({ s: 'particles', t0: 250, t1: 950, n: 30, seed, x: mouth.x, y: mouth.y, sx: 0, sy: 0, mode: 'converge', r: 170, life: 450, size: [6, 12], style: 'crystal', c: ['#ffffff', '#c8f6ff', '#6cc9f0'] })
      add({ s: 'glow', t0: 300, t1: 1000, x: mouth.x, y: mouth.y, r: [6, 44], c: ['#ffffff', '#c8f6ff', '#6cc9f0'], a: 1 })
      add({ s: 'beam', t0: 950, t1: 1750, x0: mouth.x, y0: mouth.y, x1: tc.x, y1: tc.y, w: [8, 26], c: ['#ffffff', '#bfeeff', '#6cc9f0'], a: [1, 0], wobble: 2, grow: 140 })
      add({ s: 'particles', t0: 1000, t1: 1750, n: 40, seed: seed + 3, x: [mouth.x, tc.x], y: [mouth.y, tc.y], sx: 24, sy: 24, v: 40, vy: 0, g: 0, life: 320, mode: 'trail', size: [9, 3], style: 'crystal', c: ['#ffffff', '#c8f6ff'] })
      add({ s: 'particles', t0: 1150, t1: 2000, n: 22, seed: seed + 5, x: tc.x, y: tc.y, sx: 0, sy: 0, mode: 'burst', v: 160, vy: 40, g: 200, life: 700, size: [18, 10], style: 'crystal', c: ['#ffffff', '#c8f6ff', '#6cc9f0'] })
      add({ s: 'ring', t0: 1150, t1: 1800, x: tc.x, y: T.y, r: [20, T.h * 0.6], ratio: 0.3, w: [8, 2], c: '#e0faff', a: [1, 0], n: 2, stagger: 1 })
      hit(1150, 1.1, '#9ee8ff')
      S.push({ who: 'T', k: 'tint', t0: 1150, t1: 2000, color: '#bfeeff', a: 0.65 })
      back(2000, 80)
      flashAfter(2550)
    },
    surf: () => {
      // A câmera abre, a parede de água atravessa a tela inteira e espirra no alvo.
      cam = [[0, ...NEUTRAL], [400, ...[stage.w / 2, stage.h / 2 + 20, 0.94, -toward]], [1800, ...look(tc, 1.3, -2 * toward)]]
      add({ s: 'tint', t0: 200, t1: 1900, color: '#0b3b8a', a: [0, 0.25] })
      add({ s: 'wave', t0: 300, t1: 1700, dir: toward, c: ['#e8fbff', '#5cc8ff', '#1f6fd6', '#0b3b8a'], h: [0.25, 0.85] })
      add({ s: 'particles', t0: 600, t1: 1800, n: 70, seed, x: tc.x, y: tc.y, sx: 240, sy: 140, v: 140, vy: -240, g: 520, life: 650, mode: 'stream', size: [9, 4], style: 'droplet', c: ['#ffffff', '#bfe8ff', '#5cc8ff'] })
      add({ s: 'particles', t0: 700, t1: 1800, n: 20, seed: seed + 2, x: tc.x, y: tc.y, sx: 120, sy: 80, v: 30, vy: -80, g: 0, life: 700, mode: 'stream', size: [10, 6], style: 'bubble', c: ['#ffffff', '#bfe8ff'] })
      hit(1050, 1.2, '#5cc8ff')
      back(1850, 60)
      flashAfter(2400)
    },
    earthquake: () => {
      // A câmera abre, tudo treme forte, o chão racha embaixo do alvo e pedras e poeira sobem.
      cam = [[0, ...NEUTRAL], [300, stage.w / 2, stage.h / 2 + 30, 0.9, 0], [1700, stage.w / 2, stage.h / 2 + 30, 0.93, 0]]
      shake.push([300, 1700, 18])
      add({ s: 'crack', t0: 350, t1: 1700, x: tc.x, y: T.y, r: [30, 340], n: 9, c: '#3b2a12', c2: '#e0b866', a: [1, 0] })
      add({ s: 'particles', t0: 400, t1: 1700, n: 70, seed, x: tc.x, y: T.y, sx: 260, sy: 10, v: 80, vy: -320, g: 700, life: 750, mode: 'stream', size: [16, 6], style: 'dust', c: ['#e0b866', '#a8742e', '#5b3c12'] })
      add({ s: 'particles', t0: 500, t1: 1600, n: 18, seed: seed + 2, x: tc.x, y: T.y, sx: 200, sy: 10, v: 40, vy: -420, g: 900, life: 800, mode: 'stream', size: [16, 12], style: 'shard', c: ['#d6b98a', '#9b7c4f'] })
      S.push({ who: 'T', k: 'move', t0: 450, t1: 1400, dx: 0, dy: -30, bounce: 4 })
      S.push({ who: 'A', k: 'move', t0: 350, t1: 1300, dx: 0, dy: -10, bounce: 5 })
      hit(800, 1.3, '#a8742e')
      back(1700, 0)
      flashAfter(2200)
    },
    'shadow-ball': () => {
      // Sombras se juntam na frente dele, a bola roxa gira, cresce, voa e estoura em fantasmas.
      const o = { x: front.x + 50 * toward, y: (mouth.y + front.y) / 2 }
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.3, 2 * toward)], [950, ...look(a, 1.35, 2 * toward)], [1200, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.0, 0)], [1400, ...look(tc, 1.5, -2 * toward)]]
      add({ s: 'tint', t0: 200, t1: 1700, color: '#120624', a: [0, 0.45] })
      add({ s: 'particles', t0: 250, t1: 1000, n: 34, seed, x: o.x, y: o.y, sx: 0, sy: 0, mode: 'converge', r: 200, life: 500, size: [10, 18], style: 'wisp', c: ['#a78bfa', '#6d3fc9', '#2a1450'] })
      add({ s: 'glow', t0: 300, t1: 1000, x: o.x, y: o.y, r: [6, 56], c: ['#2a1450', '#6d3fc9', '#a78bfa', '#120624'], a: 1, core: 0.4, swirl: 1 })
      add({ s: 'glow', t0: 1000, t1: 1330, x: [o.x, tc.x], y: [o.y, tc.y], r: [56, 70], c: ['#2a1450', '#6d3fc9', '#a78bfa', '#120624'], a: 1, core: 0.4, swirl: 1, trail: 1 })
      add({ s: 'particles', t0: 1330, t1: 2000, n: 26, seed: seed + 3, x: tc.x, y: tc.y, sx: 20, sy: 20, v: 180, vy: -40, g: 0, life: 650, mode: 'burst', size: [16, 6], style: 'wisp', c: ['#c4b5fd', '#7c3aed', '#2a1450'] })
      add({ s: 'ring', t0: 1330, t1: 1800, x: tc.x, y: tc.y, r: [20, 150], ratio: 0.8, w: [10, 2], c: '#a78bfa', a: [1, 0], n: 2, stagger: 1 })
      hit(1330, 1.15, '#6d3fc9')
      back(1450, 300)
      flashAfter(2400)
    },
    psychic: () => {
      // A tela fica rosa e pulsa, anéis apertam o alvo, ele é erguido e sacudido pela mente.
      cam = [[0, ...NEUTRAL], [400, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.05, 0)], [900, ...look(tc, 1.45, -2 * toward)], [1900, ...look(tc, 1.5, -3 * toward)]]
      S.push({ who: 'A', k: 'tint', t0: 250, t1: 900, color: '#ff8fd0', a: 0.5, pulse: 20 })
      add({ s: 'tint', t0: 300, t1: 2000, color: '#ff3fa4', a: [0, 0.3] })
      add({ s: 'ring', t0: 300, t1: 1000, x: [a.x, tc.x], y: [a.y, tc.y], r: [40, 120], ratio: 0.85, w: 6, c: '#ffc0e6', a: [1, 0.4], n: 5, stagger: 1 })
      add({ s: 'ring', t0: 900, t1: 1900, x: tc.x, y: tc.y, r: [170, 30], ratio: 1, w: [2, 9], c: '#ff8fd0', a: [0.2, 1], n: 4, stagger: 1 })
      add({ s: 'particles', t0: 900, t1: 1900, n: 24, seed, x: tc.x, y: tc.y, sx: 0, sy: 0, mode: 'swirl', r: 160, life: 800, size: [10, 5], style: 'dot', c: ['#ffffff', '#ff8fd0'] })
      S.push({ who: 'T', k: 'move', t0: 1000, t1: 1800, dx: 0, dy: -40, back: 1 })
      S.push({ who: 'T', k: 'tint', t0: 900, t1: 1900, color: '#ff8fd0', a: 0.6, pulse: 30 })
      shake.push([1300, 1800, 6])
      hit(1500, 1.1, '#e2479c')
      back(1950, 60)
      flashAfter(2500)
    },
    'close-combat': () => {
      // Avança e acerta uma sequência de socos e chutes, cada um com estrela e tranco.
      cam = [[0, ...NEUTRAL], [280, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.1, 0)], [500, ...look(tc, 1.6, -3 * toward)], [1500, ...look(tc, 1.5, -2 * toward)]]
      S.push({ who: 'A', k: 'move', t0: 80, t1: 1500, dx: (tc.x - a.x) * 0.55, dy: (tc.y - a.y) * 0.55, back: 1 })
      for (let i = 0; i < 6; i++) {
        const t = 500 + i * 150
        const ox = (rnd(i) - 0.5) * 90
        const oy = (rnd(i + 3) - 0.5) * 80
        add({ s: 'icon', t0: t - 90, t1: t + 140, x: tc.x + ox, y: tc.y + oy, size: [150, 80], a: [0.5, 1], style: i % 2 ? 'foot' : 'fist', c: ['#fff2e0', '#ffb067', '#d0562b'], rot: (rnd(i + 7) - 0.5) * 0.8 })
        add({ s: 'rays', t0: t, t1: t + 180, x: tc.x + ox, y: tc.y + oy, n: 8, r0: 10, r1: [30, 90], w: 5, c: '#ffffff', c2: '#ffb067', a: [1, 0], rot: rnd(i) })
        shake.push([t, t + 100, 6])
        S.push({ who: 'T', k: 'move', t0: t, t1: t + 140, dx: 10 * toward, dy: 0 })
      }
      hit(1350, 1.3, '#d0562b')
      back(1500, 150)
      flashAfter(2150)
    },
    'dragon-claw': () => {
      // Avança com garras de energia azul e rasga o alvo três vezes.
      cam = [[0, ...NEUTRAL], [280, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.1, 0)], [520, ...look(tc, 1.6, -3 * toward)], [1100, ...look(tc, 1.5, -2 * toward)]]
      S.push({ who: 'A', k: 'move', t0: 80, t1: 900, dx: (tc.x - a.x) * 0.55, dy: (tc.y - a.y) * 0.55, back: 1 })
      S.push({ who: 'A', k: 'tint', t0: 100, t1: 600, color: '#5a4ae0', a: 0.45 })
      for (let i = 0; i < 3; i++) add({ s: 'arc', t0: 480 + i * 60, t1: 820 + i * 60, x: tc.x + (i - 1) * 26, y: tc.y, r: 110, a0: -2.4, a1: [-2.4, 0.7], w: 9, c: '#e0e4ff', c2: '#5a4ae0', flip: toward > 0 ? 0 : 1 })
      add({ s: 'particles', t0: 560, t1: 1200, n: 26, seed, x: tc.x, y: tc.y, sx: 30, sy: 30, v: 200, vy: -60, g: 0, life: 500, mode: 'burst', size: [10, 3], style: 'ember', c: ['#eef0ff', '#9aa6ff', '#5a4ae0'] })
      hit(600, 1.2, '#5a4ae0')
      back(1100, 120)
      flashAfter(1750)
    },
    moonblast: () => {
      // A lua aparece no alto e brilha; a luz dela vira uma esfera rosa que desce no alvo e estoura em brilhos.
      const moon = { x: a.x + 80 * toward, y: Math.min(a.y, tc.y) - 200 }
      cam = [[0, ...NEUTRAL], [450, ...look({ x: moon.x, y: moon.y + 80 }, 1.25, 0)], [1300, ...look({ x: moon.x, y: moon.y + 80 }, 1.3, 0)], [1600, ...look(tc, 1.45, -2 * toward)]]
      add({ s: 'tint', t0: 200, t1: 1900, color: '#0a0620', a: [0, 0.5] })
      add({ s: 'glow', t0: 300, t1: 1500, x: moon.x, y: moon.y, r: [10, 90], c: ['#ffffff', '#ffe6f6', '#f7a8d8'], a: [0.3, 1] })
      add({ s: 'icon', t0: 300, t1: 1500, x: moon.x, y: moon.y, size: [20, 70], a: [0.3, 1], style: 'moon', c: ['#ffffff', '#fff4fb', '#f7a8d8'] })
      add({ s: 'particles', t0: 500, t1: 1400, n: 26, seed, x: moon.x, y: moon.y, sx: 0, sy: 0, mode: 'converge', r: 220, life: 500, size: [5, 10], style: 'star', c: ['#ffffff', '#ffc6e8'] })
      add({ s: 'glow', t0: 1350, t1: 1650, x: [moon.x, tc.x], y: [moon.y, tc.y], r: [40, 70], c: ['#ffffff', '#ffc6e8', '#f77fbe'], a: 1, trail: 1 })
      add({ s: 'particles', t0: 1650, t1: 2300, n: 34, seed: seed + 3, x: tc.x, y: tc.y, sx: 20, sy: 20, v: 220, vy: -40, g: 60, life: 650, mode: 'burst', size: [14, 4], style: 'star', c: ['#ffffff', '#ffc6e8', '#f77fbe'] })
      hit(1650, 1.2, '#f77fbe')
      back(2000, 100)
      flashAfter(2600)
    },
    'hydro-pump': () => {
      // Dois jatos de água fortes saem da boca e empurram o alvo para trás.
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.3, 2 * toward)], [700, ...look({ x: a.x * 0.4 + tc.x * 0.6, y: a.y * 0.4 + tc.y * 0.6 }, 1.1, -toward)], [1600, ...look(tc, 1.45, -2 * toward)]]
      add({ s: 'glow', t0: 200, t1: 1700, x: mouth.x, y: mouth.y, r: [6, 40], c: ['#ffffff', '#5cc8ff', '#1f6fd6'], a: [1, 0.7] })
      for (const off of [-16, 16]) add({ s: 'particles', t0: 450, t1: 1700, n: 140, seed: seed + off, x: [mouth.x, tc.x], y: [mouth.y + off * 0.4, tc.y + off], sx: 6, sy: 6, spread: 18, mode: 'jet', life: 340, size: [12, 22], style: 'droplet', c: ['#ffffff', '#bfe8ff', '#5cc8ff', '#1f6fd6'] })
      add({ s: 'particles', t0: 850, t1: 1800, n: 50, seed: seed + 9, x: tc.x, y: tc.y, sx: 60, sy: 50, v: 200, vy: -160, g: 500, life: 600, mode: 'stream', size: [9, 4], style: 'droplet', c: ['#ffffff', '#5cc8ff'] })
      S.push({ who: 'T', k: 'move', t0: 850, t1: 1700, dx: 34 * toward, dy: -6, back: 1 })
      hit(850, 1.25, '#1f6fd6')
      back(1800, 60)
      flashAfter(2350)
    },
    'fire-blast': () => {
      // Uma bola de fogo voa e explode na estrela de cinco pontas, o "大" de fogo dos jogos.
      const o = { x: mouth.x, y: mouth.y }
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.3, 2 * toward)], [800, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.0, 0)], [1050, ...look(tc, 1.4, -2 * toward)], [2000, ...look(tc, 1.45, -2 * toward)]]
      add({ s: 'glow', t0: 200, t1: 700, x: o.x, y: o.y, r: [6, 50], c: ['#fff7c2', '#ffb02e', '#e5391a'], a: 1, swirl: 1 })
      add({ s: 'glow', t0: 700, t1: 1000, x: [o.x, tc.x], y: [o.y, tc.y], r: [50, 64], c: ['#fff7c2', '#ffb02e', '#e5391a', '#7a1406'], a: 1, trail: 1 })
      add({ s: 'tint', t0: 1000, t1: 1120, color: '#fff3d0', a: [0.85, 0] })
      add({ s: 'rays', t0: 1000, t1: 2000, x: tc.x, y: tc.y, n: 5, r0: 20, r1: [60, 260], w: [30, 46], c: '#ffd23a', c2: '#e5391a', a: [1, 0], rot: -Math.PI / 2 })
      add({ s: 'glow', t0: 1000, t1: 2000, x: tc.x, y: tc.y, r: [60, 200], c: ['#fff7c2', '#ff8a2a', '#d6200f'], a: [1, 0] })
      add({ s: 'particles', t0: 1050, t1: 2200, n: 60, seed, x: tc.x, y: tc.y, sx: 140, sy: 140, v: 30, vy: -220, g: -60, life: 800, mode: 'stream', size: [16, 5], style: 'flame', c: ['#fff7c2', '#ffb02e', '#e5391a'] })
      shake.push([1000, 1700, 12])
      hit(1000, 1.4, '#ff4a0a')
      S.push({ who: 'T', k: 'tint', t0: 1000, t1: 2000, color: '#ff4a0a', a: 0.65, pulse: 24 })
      back(2050, 60)
      flashAfter(2600)
    },
    thunder: () => {
      // O céu escurece, um raio gigante cai do alto no alvo duas vezes, com clarões.
      cam = [[0, ...NEUTRAL], [400, ...look({ x: tc.x, y: tc.y - 140 }, 1.15, -toward)], [1000, ...look(tc, 1.45, -3 * toward)]]
      add({ s: 'tint', t0: 200, t1: 1900, color: '#05040f', a: [0, 0.6] })
      for (let i = 0; i < 2; i++) {
        const t = 700 + i * 380
        add({ s: 'bolt', t0: t, t1: t + 320, x: tc.x, y: tc.y, r: 0, from: { x: tc.x + (rnd(i) - 0.5) * 120, y: -60 }, n: 12, c: '#ffffff', c2: '#ffe94a', w: 14, flicker: 1 })
        add({ s: 'tint', t0: t, t1: t + 140, color: '#ffffff', a: [0.9, 0] })
        shake.push([t, t + 220, 12])
      }
      add({ s: 'bolt', t0: 750, t1: 1700, x: tc.x, y: tc.y, r: 150, n: 8, c: '#ffffff', c2: '#ffe94a', w: 4, flicker: 1 })
      hit(720, 1.4, '#ffe94a')
      S.push({ who: 'T', k: 'tint', t0: 720, t1: 1700, color: '#ffe94a', a: 0.6, pulse: 50 })
      back(1750, 60)
      flashAfter(2300)
    },
    hurricane: () => {
      // Um furacão se forma no alvo: anéis de vento girando, riscos e o alvo girando no ar.
      cam = [[0, ...NEUTRAL], [400, ...look(tc, 1.35, -2 * toward)], [1900, ...look({ x: tc.x, y: tc.y - 40 }, 1.45, -4 * toward)]]
      add({ s: 'ring', t0: 300, t1: 1900, x: tc.x, y: [T.y, tc.y - 120], r: [50, 170], ratio: 0.3, w: [12, 3], c: '#e4f3ff', a: [0.9, 0], n: 8, spiral: 6 })
      add({ s: 'particles', t0: 300, t1: 1900, n: 80, seed, x: tc.x, y: tc.y, sx: 0, sy: 0, mode: 'swirl', r: 190, life: 900, size: [16, 5], style: 'streak', c: ['#ffffff', '#e4f3ff', '#9cc8ee'] })
      add({ s: 'particles', t0: 400, t1: 1800, n: 16, seed: seed + 2, x: tc.x, y: tc.y, sx: 0, sy: 0, mode: 'swirl', r: 150, life: 1000, size: [14, 10], style: 'feather', c: ['#ffffff', '#e4f3ff'] })
      S.push({ who: 'T', k: 'move', t0: 600, t1: 1700, dx: 0, dy: -50, back: 1 })
      S.push({ who: 'T', k: 'squash', t0: 600, t1: 1700, sx: 0.85, sy: 1.08 })
      hit(1100, 1.2, '#9cc8ee')
      back(1950, 60)
      flashAfter(2500)
    },
    'leaf-storm': () => {
      // Uma tempestade de folhas sai de quem ataca, vai até o alvo e gira em volta dele.
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.25, 2 * toward)], [800, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.0, 0)], [1300, ...look(tc, 1.4, -2 * toward)]]
      add({ s: 'particles', t0: 200, t1: 1300, n: 90, seed, x: [front.x, tc.x], y: [front.y, tc.y], sx: 80, sy: 70, mode: 'travel', life: 700, size: [18, 14], style: 'leaf', c: ['#f1ffd0', '#9be35a', '#3fa34d'] })
      add({ s: 'particles', t0: 900, t1: 2000, n: 70, seed: seed + 3, x: tc.x, y: tc.y, sx: 0, sy: 0, mode: 'swirl', r: 180, life: 800, size: [18, 12], style: 'leaf', c: ['#f1ffd0', '#9be35a', '#3fa34d'] })
      add({ s: 'ring', t0: 900, t1: 1900, x: tc.x, y: tc.y, r: [160, 60], ratio: 0.5, w: [3, 7], c: '#9be35a', a: [0, 0.8], n: 3, spiral: 3 })
      hit(1200, 1.25, '#3fa34d')
      back(2000, 60)
      flashAfter(2550)
    },
    'stone-edge': () => {
      // Pedras pontudas brotam do chão embaixo do alvo, uma atrás da outra, e o acertam.
      cam = [[0, ...NEUTRAL], [350, ...look({ x: tc.x, y: T.y - 60 }, 1.35, -2 * toward)], [1400, ...look(tc, 1.45, -3 * toward)]]
      for (let i = 0; i < 5; i++) {
        const t = 400 + i * 110
        const dx = (i - 2) * 46 + (rnd(i) - 0.5) * 20
        add({ s: 'cone', t0: t, t1: t + 420, x: tc.x + dx, y: [T.y + 30, T.y - 80 - rnd(i + 2) * 80], w: 40, c: '#b89a6a', a: 1 })
        add({ s: 'particles', t0: t, t1: t + 420, n: 8, seed: seed + i, x: tc.x + dx, y: T.y, sx: 20, sy: 4, v: 120, vy: -260, g: 700, life: 400, mode: 'burst', size: [10, 5], style: 'shard', c: ['#d6b98a', '#9b7c4f'] })
        shake.push([t, t + 120, 7])
      }
      hit(700, 1.3, '#9b7c4f')
      back(1450, 60)
      flashAfter(2000)
    },
    'u-turn': () => {
      // Avança num risco verde, acerta e volta voando para o lugar dele.
      cam = [[0, ...NEUTRAL], [280, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.05, 0)], [480, ...look(tc, 1.5, -3 * toward)], [800, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.05, 0)]]
      S.push({ who: 'A', k: 'move', t0: 60, t1: 900, dx: (tc.x - a.x) * 0.6, dy: (tc.y - a.y) * 0.6, back: 1 })
      add({ s: 'particles', t0: 80, t1: 900, n: 40, seed, x: [a.x, tc.x], y: [a.y, tc.y], sx: 30, sy: 30, v: 40, vy: 0, g: 0, life: 300, mode: 'trail', size: [14, 3], style: 'streak', c: ['#ffffff', '#c9e04a', '#8aa61c'] })
      add({ s: 'arc', t0: 420, t1: 760, x: tc.x, y: tc.y, r: 120, a0: -2.6, a1: [-2.6, 0.6], w: 12, c: '#f7ffd6', c2: '#8aa61c', flip: toward > 0 ? 0 : 1 })
      hit(500, 1.1, '#8aa61c')
      back(900, 0)
      flashAfter(1450)
    },
    'knock-off': () => {
      // Um golpe sombrio arranca o item: o tapa escuro acerta e uma estrela sai voando.
      cam = [[0, ...NEUTRAL], [280, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.1, 0)], [500, ...look(tc, 1.55, -3 * toward)], [1200, ...look(tc, 1.45, -2 * toward)]]
      S.push({ who: 'A', k: 'move', t0: 80, t1: 850, dx: (tc.x - a.x) * 0.55, dy: (tc.y - a.y) * 0.55, back: 1 })
      add({ s: 'arc', t0: 460, t1: 800, x: tc.x, y: tc.y, r: 100, a0: 0.4, a1: [0.4, -2.6], w: 16, c: '#2e1d40', c2: '#8a76a8', flip: toward > 0 ? 1 : 0 })
      add({ s: 'shot', t0: 560, t1: 1250, x: [tc.x, tc.x + 260 * toward], y: [tc.y - 20, tc.y - 220], r: 22, c: ['#ffffff', '#fde68a', '#f59e0b', '#92400e'], style: 'star', arc: 60, spin: toward })
      hit(540, 1.15, '#3d2f55')
      back(1200, 60)
      flashAfter(1750)
    },
    'draco-meteor': () => {
      // Energia laranja sobe da boca ao céu; de lá caem vários meteoros no campo, com explosões.
      cam = [[0, ...NEUTRAL], [350, ...look(a, 1.3, 2 * toward)], [900, ...look({ x: a.x, y: a.y - 200 }, 1.1, 0)], [1300, stage.w / 2, stage.h / 2, 0.92, 0], [2600, ...look(tc, 1.2, -2 * toward)]]
      S.push({ who: 'A', k: 'tint', t0: 250, t1: 900, color: '#ff8a2a', a: 0.5, pulse: 20 })
      add({ s: 'glow', t0: 300, t1: 900, x: mouth.x, y: mouth.y, r: [6, 50], c: ['#fff7c2', '#ffb02e', '#e5391a'], a: 1 })
      add({ s: 'glow', t0: 850, t1: 1150, x: [mouth.x, mouth.x], y: [mouth.y, -80], r: [40, 30], c: ['#fff7c2', '#ffb02e', '#e5391a'], a: 1, trail: 1 })
      add({ s: 'tint', t0: 1100, t1: 2700, color: '#1a0612', a: [0, 0.45] })
      for (let i = 0; i < 6; i++) {
        const t = 1350 + i * 180
        const dx = (rnd(i) - 0.5) * 260
        add({ s: 'shot', t0: t - 300, t1: t, x: [tc.x + dx - 220 * toward, tc.x + dx * 0.5], y: [-60, T.y - 40 + (rnd(i + 3) - 0.5) * 40], r: 30, c: ['#fff7c2', '#ffb02e', '#e5391a', '#7a1406'], style: 'dot', trail: 1 })
        add({ s: 'glow', t0: t, t1: t + 300, x: tc.x + dx * 0.5, y: T.y - 40, r: [20, 120], c: ['#fff7c2', '#ff8a2a', '#d6200f'], a: [1, 0] })
        shake.push([t, t + 160, 10])
      }
      hit(1350, 1.4, '#e5391a')
      back(2650, 100)
      flashAfter(3250)
    },
    'sludge-bomb': () => {
      // Uma bola de lodo roxo voa em arco e estoura espirrando gosma no alvo.
      cam = [[0, ...NEUTRAL], [300, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 - 40 }, 1.05, 0)], [900, ...look(tc, 1.45, -2 * toward)]]
      add({ s: 'shot', t0: 250, t1: 850, x: [mouth.x, tc.x], y: [mouth.y, tc.y], r: 30, c: ['#f6dcff', '#c56cf0', '#8e2fc2', '#43125e'], style: 'goo', arc: 180, spin: toward })
      add({ s: 'particles', t0: 850, t1: 1600, n: 34, seed, x: tc.x, y: tc.y, sx: 20, sy: 20, v: 220, vy: -160, g: 600, life: 700, mode: 'burst', size: [14, 6], style: 'goo', c: ['#f6dcff', '#c56cf0', '#8e2fc2'] })
      add({ s: 'particles', t0: 950, t1: 1800, n: 14, seed: seed + 3, x: tc.x, y: tc.y - 20, sx: 70, sy: 30, v: 0, vy: -90, g: 0, life: 700, mode: 'stream', size: [12, 6], style: 'bubble', c: ['#f6dcff', '#c56cf0'] })
      hit(850, 1.15, '#8e2fc2')
      S.push({ who: 'T', k: 'tint', t0: 850, t1: 1700, color: '#a855f7', a: 0.55, pulse: 16 })
      back(1750, 60)
      flashAfter(2300)
    },
    'flash-cannon': () => {
      // Luz prateada junta na frente, sai um raio de metal largo e brilhante.
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.35, 2 * toward)], [850, ...look(a, 1.35, 2 * toward)], [1050, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.0, 0)], [1300, ...look(tc, 1.45, -2 * toward)]]
      add({ s: 'particles', t0: 250, t1: 950, n: 26, seed, x: front.x, y: front.y, sx: 0, sy: 0, mode: 'converge', r: 170, life: 450, size: [5, 10], style: 'glint', c: ['#ffffff', '#e3eaf2'] })
      add({ s: 'glow', t0: 300, t1: 1000, x: front.x, y: front.y, r: [6, 50], c: ['#ffffff', '#e3eaf2', '#9aaabd'], a: 1, swirl: 1 })
      add({ s: 'beam', t0: 950, t1: 1750, x0: front.x, y0: front.y, x1: tc.x, y1: tc.y, w: [12, 40], c: ['#ffffff', '#e3eaf2', '#9aaabd'], a: [1, 0], wobble: 3, grow: 120 })
      add({ s: 'rays', t0: 1050, t1: 1600, x: tc.x, y: tc.y, n: 12, r0: 20, r1: [60, 180], w: 5, c: '#ffffff', c2: '#9aaabd', a: [1, 0], rot: [0, 0.6] })
      hit(1050, 1.2, '#9aaabd')
      back(1750, 80)
      flashAfter(2300)
    },
    'energy-ball': () => {
      // A bola verde de natureza se forma com folhinhas girando, voa e estoura em verde.
      const o = { x: front.x + 50 * toward, y: (mouth.y + front.y) / 2 }
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.3, 2 * toward)], [950, ...look(a, 1.35, 2 * toward)], [1200, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.0, 0)], [1400, ...look(tc, 1.5, -2 * toward)]]
      add({ s: 'particles', t0: 250, t1: 1000, n: 24, seed, x: o.x, y: o.y, sx: 0, sy: 0, mode: 'converge', r: 170, life: 500, size: [12, 8], style: 'leaf', c: ['#f1ffd0', '#9be35a'] })
      add({ s: 'glow', t0: 300, t1: 1000, x: o.x, y: o.y, r: [6, 52], c: ['#f1ffd0', '#9be35a', '#3fa34d', '#1d5a2a'], a: 1, core: 0.3, swirl: 1 })
      add({ s: 'glow', t0: 1000, t1: 1330, x: [o.x, tc.x], y: [o.y, tc.y], r: [52, 64], c: ['#f1ffd0', '#9be35a', '#3fa34d', '#1d5a2a'], a: 1, core: 0.3, swirl: 1, trail: 1 })
      add({ s: 'particles', t0: 1330, t1: 2000, n: 30, seed: seed + 3, x: tc.x, y: tc.y, sx: 20, sy: 20, v: 220, vy: -40, g: 200, life: 650, mode: 'burst', size: [14, 8], style: 'leaf', c: ['#f1ffd0', '#9be35a', '#3fa34d'] })
      hit(1330, 1.15, '#3fa34d')
      back(1450, 300)
      flashAfter(2400)
    },
    'swords-dance': () => {
      // Espadas de luz giram em volta de quem usa, cruzam no alto e o ataque sobe.
      cam = [[0, ...NEUTRAL], [400, ...look(a, 1.4, 2 * toward)], [1700, ...look(a, 1.45, 2 * toward)]]
      for (let i = 0; i < 4; i++) add({ s: 'arc', t0: 300 + i * 120, t1: 1300 + i * 120, x: a.x, y: a.y - A.h * 0.1, r: A.h * (0.45 + i * 0.04), a0: (i * Math.PI) / 2, a1: [(i * Math.PI) / 2, (i * Math.PI) / 2 + 4], w: 7, c: '#ffffff', c2: '#fca5a5' })
      add({ s: 'particles', t0: 400, t1: 1500, n: 6, seed, x: a.x, y: a.y - A.h * 0.1, sx: 0, sy: 0, mode: 'orbit', r: A.h * 0.55, life: 1100, size: [26, 26], style: 'streak', c: ['#ffffff', '#e3eaf2'] })
      add({ s: 'rays', t0: 1300, t1: 1700, x: a.x, y: a.y - A.h * 0.5, n: 10, r0: 10, r1: [40, 160], w: 5, c: '#ffffff', c2: '#ef4444', a: [1, 0], rot: 0.2 })
      add({ s: 'particles', t0: 1300, t1: 1900, n: 10, seed: seed + 4, x: a.x, y: A.y - A.h * 0.3, sx: A.h * 0.35, sy: 20, v: 0, vy: -220, g: 0, life: 600, mode: 'stream', size: [18, 14], style: 'arrowUp', c: ['#ffffff', '#fca5a5', '#ef4444'] })
      S.push({ who: 'A', k: 'tint', t0: 1200, t1: 1900, color: '#ef4444', a: 0.5, pulse: 18 })
      hud = [100, 1900]
      cam.push([2200, ...NEUTRAL])
      end(2300)
    },
    'dragon-dance': () => {
      // Chamas roxas e vermelhas giram e sobem em volta dele, a aura cresce e os atributos sobem.
      cam = [[0, ...NEUTRAL], [400, ...look(a, 1.4, 2 * toward)], [1700, ...look(a, 1.45, 2 * toward)]]
      add({ s: 'particles', t0: 300, t1: 1600, n: 10, seed, x: a.x, y: a.y, sx: 0, sy: 0, mode: 'orbit', r: A.h * 0.55, life: 1300, size: [26, 22], style: 'flame', c: ['#ffd6a0', '#9aa6ff', '#5a4ae0'] })
      add({ s: 'particles', t0: 300, t1: 1700, n: 50, seed: seed + 2, x: a.x, y: A.y, sx: A.h * 0.45, sy: 10, v: 0, vy: -300, g: 0, life: 700, mode: 'stream', size: [14, 4], style: 'ember', c: ['#ffd6a0', '#ff6a12', '#5a4ae0'] })
      add({ s: 'glow', t0: 700, t1: 1700, x: a.x, y: a.y, r: [40, A.h * 0.8], c: ['rgba(0,0,0,0)', '#9aa6ff', '#5a4ae0'], a: [0.6, 0], core: 0.6 })
      add({ s: 'particles', t0: 1200, t1: 1900, n: 10, seed: seed + 4, x: a.x, y: A.y - A.h * 0.3, sx: A.h * 0.35, sy: 20, v: 0, vy: -220, g: 0, life: 600, mode: 'stream', size: [18, 14], style: 'arrowUp', c: ['#ffffff', '#9aa6ff', '#5a4ae0'] })
      S.push({ who: 'A', k: 'tint', t0: 600, t1: 1800, color: '#7c6cf0', a: 0.45, pulse: 14 })
      hud = [100, 1900]
      cam.push([2200, ...NEUTRAL])
      end(2300)
    },
    protect: () => {
      // Uma redoma verde-clara se fecha em volta dele, brilha e some.
      cam = [[0, ...NEUTRAL], [350, ...look(a, 1.35, 2 * toward)], [1400, ...look(a, 1.4, 2 * toward)]]
      add({ s: 'ring', t0: 300, t1: 1300, x: a.x, y: a.y, r: [A.h * 0.2, A.h * 0.7], ratio: 1, w: [14, 4], c: '#d9fbe8', a: [1, 0.3], n: 1 })
      add({ s: 'glow', t0: 400, t1: 1400, x: a.x, y: a.y, r: A.h * 0.72, c: ['rgba(0,0,0,0)', '#86efac', '#ecfdf5'], a: [0.7, 0], core: 0.75 })
      add({ s: 'rays', t0: 500, t1: 1100, x: a.x - A.h * 0.25, y: a.y - A.h * 0.35, n: 4, r0: 0, r1: [10, 60], w: 4, c: '#ffffff', c2: '#86efac', a: [1, 0], rot: 0.4 })
      hud = [100, 1400]
      cam.push([1750, ...NEUTRAL])
      end(1850)
    },
    'will-o-wisp': () => {
      // Três chamas fantasmas azuladas flutuam devagar até o alvo, giram nele e ele se queima.
      cam = [[0, ...NEUTRAL], [400, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.05, 0)], [1300, ...look(tc, 1.4, -2 * toward)]]
      add({ s: 'tint', t0: 200, t1: 2000, color: '#0a0620', a: [0, 0.4] })
      add({ s: 'particles', t0: 300, t1: 1400, n: 3, seed, x: [front.x, tc.x], y: [front.y, tc.y], sx: 60, sy: 40, mode: 'travel', life: 1000, size: [26, 26], style: 'wisp', c: ['#c7d2fe', '#818cf8', '#4f46e5'] })
      add({ s: 'particles', t0: 1300, t1: 2000, n: 3, seed: seed + 2, x: tc.x, y: tc.y, sx: 0, sy: 0, mode: 'orbit', r: T.h * 0.4, life: 700, size: [24, 18], style: 'wisp', c: ['#c7d2fe', '#818cf8'] })
      add({ s: 'particles', t0: 1500, t1: 2200, n: 20, seed: seed + 4, x: tc.x, y: T.y, sx: T.h * 0.4, sy: 10, v: 0, vy: -200, g: 0, life: 600, mode: 'stream', size: [10, 3], style: 'ember', c: ['#fff7c2', '#ffb02e', '#e5391a'] })
      S.push({ who: 'T', k: 'tint', t0: 1500, t1: 2200, color: '#ff5a1a', a: 0.5, pulse: 16 })
      hud = [100, 2200]
      cam.push([2200, ...look(tc, 1.4, -2 * toward)], [2550, ...NEUTRAL])
      end(2650)
    },
    'thunder-wave': () => {
      // Ondas elétricas saem dele até o alvo, que fica cercado de faíscas e paralisado.
      cam = [[0, ...NEUTRAL], [400, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.05, 0)], [1100, ...look(tc, 1.4, -2 * toward)]]
      add({ s: 'ring', t0: 250, t1: 1150, x: [front.x, tc.x], y: [front.y, tc.y], r: [30, 100], ratio: 0.8, w: 5, c: '#ffe94a', a: [1, 0.3], n: 5, stagger: 1 })
      add({ s: 'bolt', t0: 1050, t1: 1900, x: tc.x, y: tc.y, r: 120, n: 6, c: '#ffffff', c2: '#ffe94a', w: 3, flicker: 1 })
      add({ s: 'particles', t0: 1050, t1: 1900, n: 18, seed, x: tc.x, y: tc.y, sx: 90, sy: 80, v: 100, vy: 0, g: 0, life: 260, mode: 'stream', size: [7, 2], style: 'spark', c: ['#ffffff', '#ffe94a'] })
      S.push({ who: 'T', k: 'tint', t0: 1050, t1: 1900, color: '#ffe94a', a: 0.5, pulse: 40 })
      S.push({ who: 'T', k: 'move', t0: 1100, t1: 1700, dx: 6, dy: 0, bounce: 8 })
      hud = [100, 1900]
      cam.push([1900, ...look(tc, 1.4, -2 * toward)], [2250, ...NEUTRAL])
      end(2350)
    },
    toxic: () => {
      // Gotas de veneno caem em cima do alvo, ele borbulha roxo.
      cam = [[0, ...NEUTRAL], [400, ...look(tc, 1.35, -2 * toward)], [1700, ...look(tc, 1.4, -2 * toward)]]
      add({ s: 'shot', t0: 200, t1: 700, x: [front.x, tc.x], y: [front.y, tc.y - 140], r: 22, c: ['#f6dcff', '#c56cf0', '#8e2fc2', '#43125e'], style: 'goo', arc: 120 })
      add({ s: 'particles', t0: 700, t1: 1600, n: 30, seed, x: tc.x, y: tc.y - 160, sx: 70, sy: 10, v: 0, vy: 320, g: 300, life: 500, mode: 'stream', size: [12, 8], style: 'goo', c: ['#f6dcff', '#c56cf0', '#8e2fc2'] })
      add({ s: 'particles', t0: 1000, t1: 1900, n: 18, seed: seed + 3, x: tc.x, y: tc.y, sx: 70, sy: 40, v: 0, vy: -100, g: 0, life: 700, mode: 'stream', size: [14, 6], style: 'bubble', c: ['#f6dcff', '#c56cf0'] })
      S.push({ who: 'T', k: 'tint', t0: 900, t1: 1900, color: '#a855f7', a: 0.55, pulse: 16 })
      hud = [100, 1900]
      cam.push([2200, ...NEUTRAL])
      end(2300)
    },
    recover: () => {
      // Brilhos verdes e brancos sobem em volta dele, a luz o envolve e ele se cura.
      cam = [[0, ...NEUTRAL], [400, ...look(a, 1.35, 2 * toward)], [1600, ...look(a, 1.4, 2 * toward)]]
      add({ s: 'particles', t0: 300, t1: 1500, n: 40, seed, x: a.x, y: A.y, sx: A.h * 0.45, sy: 10, v: 0, vy: -240, g: 0, life: 800, mode: 'stream', size: [12, 4], style: 'star', c: ['#ffffff', '#d9fbe8', '#4ade80'] })
      add({ s: 'ring', t0: 400, t1: 1400, x: a.x, y: [A.y, A.y - A.h], r: A.h * 0.45, ratio: 0.3, w: 5, c: '#b8ffcf', a: [1, 0], n: 3, stagger: 1 })
      add({ s: 'glow', t0: 700, t1: 1600, x: a.x, y: a.y, r: [40, A.h * 0.8], c: ['#ffffff', '#b8ffcf', '#4ade80'], a: [0.7, 0] })
      S.push({ who: 'A', k: 'tint', t0: 700, t1: 1600, color: '#4ade80', a: 0.45, pulse: 10 })
      hud = [100, 1700]
      cam.push([2000, ...NEUTRAL])
      end(2100)
    },
    'stealth-rock': () => {
      // Pedras pontudas flutuam do lado do adversário, giram e ficam espalhadas pelo campo dele.
      cam = [[0, ...NEUTRAL], [450, ...look({ x: tc.x, y: T.y - 60 }, 1.3, -toward)], [1800, ...look({ x: tc.x, y: T.y - 60 }, 1.3, -toward)]]
      add({ s: 'particles', t0: 300, t1: 1300, n: 8, seed, x: [front.x, tc.x], y: [front.y, T.y - 120], sx: 120, sy: 40, mode: 'travel', life: 800, size: [20, 18], style: 'shard', c: ['#d6b98a', '#9b7c4f'] })
      add({ s: 'particles', t0: 1100, t1: 1900, n: 8, seed: seed + 2, x: tc.x, y: T.y - 100, sx: 0, sy: 0, mode: 'orbit', r: T.h * 0.7, life: 800, size: [18, 18], style: 'shard', c: ['#d6b98a', '#9b7c4f'] })
      for (let i = 0; i < 5; i++) add({ s: 'icon', t0: 1500 + i * 60, t1: 2300, x: tc.x + (i - 2) * 55, y: T.y - 10 - (i % 2) * 14, size: 22, a: [1, 0.9], style: 'shard', c: ['#fff3dd', '#d6b98a', '#9b7c4f'], rot: rnd(i) })
      hud = [100, 2200]
      cam.push([2400, ...NEUTRAL])
      end(2500)
    },
    electroweb: () => {
      strike(380, 1.55)
      add({ s: 'ring', t0: 350, t1: 1150, x: tc.x, y: tc.y + T.h * 0.25, r: [10, 120], ratio: 0.45, w: [8, 2], c: '#ffffff', a: [1, 0], n: 4, spiral: 1 })
      add({ s: 'web', t0: 900, t1: 2500, x: tc.x, y: tc.y + 10, r: [20, 150], n: 10, rings: 6, w: 2.5, c: '#ffffff', c2: c1, charge: [1150, 2100], a: [1, 0] })
      add({ s: 'bolt', t0: 1150, t1: 2200, x: tc.x, y: tc.y, r: 140, n: 7, c: c1, c2: '#b8ff3a', w: 3, flicker: 1 })
      add({ s: 'particles', t0: 1200, t1: 2300, n: 30, seed, x: tc.x, y: tc.y, sx: 90, sy: 70, v: 60, vy: 0, g: 0, life: 260, mode: 'stream', size: [6, 2], style: 'spark', c: ['#ffffff', c1, '#b8ff3a'] })
      S.push({ who: 'T', k: 'tint', t0: 1150, t1: 2200, color: c1, a: 0.35, pulse: 30 })
      S.push({ who: 'T', k: 'move', t0: 2300, t1: 2700, dx: 22 * toward, dy: 0 })
      cam.push([2300, ...look(tc, 1.75, -3 * toward)])
      back(2500, 150)
      flashAfter(3100)
    },
  }
  const sig = signature[slug]
  if (sig) sig()
  else if (recipe) {
    byRecipe(recipe)
    shapeCamera(recipe.k)
  }
  else {
    switch (kind) {
      // ---- Golpes de contato: quem ataca avança, a câmera segue e dá zoom no impacto ----
      case 'punch':
      case 'kick':
      case 'bite':
      case 'slash':
      case 'pierce':
      case 'whip':
      case 'tackle':
      case 'spin':
      case 'dive': {
        const t = 520
        cam = [[0, ...NEUTRAL], [280, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.1, 0)], [t, ...look(tc, 1.6, -3 * toward)], [t + 380, ...look(tc, 1.45, -2 * toward)]]
        if (kind === 'dive') {
          S.push({ who: 'A', k: 'move', t0: 0, t1: t, dx: 0, dy: -600, back: 0 })
          S.push({ who: 'A', k: 'hide', t0: t - 200, t1: t + 600 })
          add({ s: 'cone', t0: t - 220, t1: t + 40, x: tc.x, y: [tc.y - 420, tc.y], w: 60, c: c1, a: 0.9 })
        } else {
          S.push({ who: 'A', k: 'move', t0: 80, t1: t + 200, dx: (tc.x - a.x) * 0.55, dy: (tc.y - a.y) * 0.55, back: 1 })
          add({ s: 'particles', t0: 120, t1: t, n: 16, seed, x: [a.x, tc.x], y: [a.y, tc.y], sx: 40, sy: 30, v: 40, vy: 0, g: 0, life: 260, mode: 'trail', size: [7, 2], style: 'dot', c: ['#ffffff', c1] })
        }
        if (kind === 'slash' || kind === 'whip') {
          for (let i = 0; i < 3; i++)
            add({ s: 'arc', t0: t - 60 + i * 110, t1: t + 200 + i * 110, x: tc.x + (i - 1) * 18, y: tc.y, r: 95, a0: -2.2 + i * 0.25, a1: [-2.2 + i * 0.25, 0.9 + i * 0.25], w: 9, c: '#ffffff', c2: c1, flip: i % 2 })
          hit(t + 120, 1)
        } else if (kind === 'bite') {
          add({ s: 'fangs', t0: t - 140, t1: t + 260, x: tc.x, y: tc.y, r: 80, close: [0, 1], c: '#ffffff', c2: c2 })
          hit(t + 60, 1.1)
        } else if (kind === 'pierce') {
          for (let i = 0; i < 3; i++) add({ s: 'cone', t0: t - 100 + i * 90, t1: t + 40 + i * 90, x: tc.x + (i - 1) * 22, y: [tc.y + 120, tc.y], w: 14, c: c1, a: 1 })
          hit(t + 120, 0.9)
        } else if (kind === 'spin') {
          add({ s: 'ring', t0: 100, t1: t + 200, x: [a.x, tc.x], y: [a.y, tc.y], r: 60, ratio: 1, w: 6, c: c1, a: 1, n: 3, spiral: 3 })
          hit(t, 1)
        } else {
          hit(t, kind === 'dive' ? 1.4 : 1.1)
        }
        if (type !== 'normal' && type !== 'fighting') add(typeParticles(t + 40, tc, 18, 'burst', 520, 1))
        back(t + 380, 120)
        flashAfter(t + 950)
        break
      }
      // ---- Raio: carrega em quem ataca, um feixe atravessa, o alvo fica cheio de energia ----
      case 'beam': {
        cam = [[0, ...NEUTRAL], [350, ...look(a, 1.35, 2 * toward)], [800, ...look(a, 1.4, 2 * toward)], [1000, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.0, 0)], [1300, ...look(tc, 1.4, -2 * toward)]]
        add({ s: 'particles', t0: 250, t1: 900, n: 26, seed, x: a.x, y: a.y, sx: 0, sy: 0, mode: 'converge', r: 160, life: 450, size: [3, 7], style: 'dot', c: [c0, c1] })
        add({ s: 'glow', t0: 300, t1: 950, x: a.x + 40 * toward, y: a.y - 10, r: [6, 55], c: [c0, c1, c2], a: 1 })
        add({ s: 'beam', t0: 900, t1: 1800, x0: a.x + 40 * toward, y0: a.y - 10, x1: tc.x, y1: tc.y, w: [10, 46], c: [c0, c1, c2], a: [1, 0], wobble: 4, grow: 120 })
        add({ s: 'particles', t0: 950, t1: 1750, n: 40, seed: seed + 3, x: [a.x, tc.x], y: [a.y, tc.y], sx: 20, sy: 20, v: 60, vy: 0, g: 0, life: 300, mode: 'trail', size: [6, 2], style: P.p, c: [c0, c1, c2] })
        hit(1080, 1.2)
        S.push({ who: 'T', k: 'tint', t0: 1080, t1: 1800, color: c2, a: 0.55, pulse: 28 })
        back(1800, 80)
        flashAfter(2350)
        break
      }
      // ---- Jato (Flamethrower, Hydro Pump): um rio de partículas sai de quem ataca e cobre o alvo ----
      case 'stream': {
        cam = [[0, ...NEUTRAL], [400, ...look({ x: (a.x * 0.4 + tc.x * 0.6), y: (a.y * 0.4 + tc.y * 0.6) }, 1.2, -toward)], [1500, ...look(tc, 1.45, -2 * toward)]]
        add({ s: 'particles', t0: 250, t1: 1600, n: 120, seed, x: [a.x + 40 * toward, tc.x], y: [a.y - 10, tc.y], sx: 6, sy: 6, spread: 26, mode: 'jet', life: 420, size: [10, 26], style: P.p === 'bubble' ? 'droplet' : 'flame', c: [c0, c1, c2, c3] })
        add({ s: 'glow', t0: 650, t1: 1700, x: tc.x, y: tc.y, r: [40, 120], c: [c0, c1, c2], a: [0.9, 0.2] })
        hit(650, 1)
        S.push({ who: 'T', k: 'tint', t0: 650, t1: 1700, color: c2, a: 0.6, pulse: 22 })
        back(1700, 60)
        flashAfter(2250)
        break
      }
      // ---- Rajada (Bullet Seed, Rock Blast): vários tiros, um atrás do outro ----
      case 'volley':
      case 'rocks':
      case 'meteor': {
        const n = kind === 'meteor' ? 4 : 5
        const t = kind === 'volley' ? 300 : 450
        cam = [[0, ...NEUTRAL], [t, ...look(tc, 1.35, -2 * toward)], [t + n * 150 + 300, ...look(tc, 1.5, -3 * toward)]]
        for (let i = 0; i < n; i++) {
          const k = t + i * 150
          const dx = (rnd(i) - 0.5) * 120
          const dy = (rnd(i + 9) - 0.5) * 80
          const from = kind === 'volley' ? { x: a.x + 30 * toward, y: a.y } : { x: tc.x + dx - 200 * toward, y: tc.y - 420 }
          add({ s: 'shot', t0: k - 220, t1: k, x: [from.x, tc.x + dx * 0.4], y: [from.y, tc.y + dy * 0.4], r: kind === 'meteor' ? 34 : 16, c: [c0, c1, c2, c3], style: P.p, trail: 1 })
          add({ s: 'glow', t0: k, t1: k + 200, x: tc.x + dx * 0.4, y: tc.y + dy * 0.4, r: [10, 70], c: [c0, c1, c2], a: [1, 0] })
          shake.push([k, k + 120, kind === 'meteor' ? 9 : 4])
        }
        hit(t + (n - 1) * 150, kind === 'meteor' ? 1.4 : 1)
        if (kind === 'meteor') add({ s: 'tint', t0: t, t1: t + n * 150 + 200, color: '#0a0620', a: [0.4, 0] })
        back(t + n * 150 + 300, 60)
        flashAfter(t + n * 150 + 850)
        break
      }
      // ---- Terremoto: a câmera abre, o chão racha, tudo treme ----
      case 'quake': {
        cam = [[0, ...NEUTRAL], [300, 480, 300, 0.92, 0], [1500, 480, 300, 0.95, 0]]
        add({ s: 'crack', t0: 300, t1: 1500, x: tc.x, y: T.y, r: [20, 300], n: 7, c: c3, c2: c1, a: [1, 0] })
        add({ s: 'particles', t0: 350, t1: 1500, n: 50, seed, x: tc.x, y: T.y, sx: 220, sy: 10, v: 60, vy: -260, g: 600, life: 700, mode: 'stream', size: [12, 4], style: 'dust', c: [c1, c2, c3] })
        shake.push([300, 1400, 14])
        S.push({ who: 'T', k: 'move', t0: 400, t1: 1200, dx: 0, dy: -24, bounce: 3 })
        hit(700, 1.2)
        back(1500, 0)
        flashAfter(2000)
        break
      }
      // ---- Onda (Surf): uma parede de água atravessa a tela ----
      case 'wave': {
        cam = [[0, ...NEUTRAL], [400, 480, 290, 0.95, -toward], [1600, ...look(tc, 1.3, -2 * toward)]]
        add({ s: 'wave', t0: 300, t1: 1600, dir: toward, c: [c0, c1, c2, c3], h: [0.2, 0.75] })
        add({ s: 'particles', t0: 500, t1: 1600, n: 50, seed, x: tc.x, y: tc.y, sx: 200, sy: 120, v: 120, vy: -200, g: 500, life: 600, mode: 'stream', size: [8, 3], style: P.p === 'bubble' ? 'droplet' : P.p, c: [c0, c1, c2] })
        hit(1000, 1.1)
        back(1650, 60)
        flashAfter(2200)
        break
      }
      // ---- Vento (Hurricane, Blizzard): um redemoinho no alvo ----
      case 'wind': {
        strike(380, 1.45)
        add({ s: 'ring', t0: 300, t1: 1500, x: tc.x, y: [T.y, tc.y - 60], r: [40, 140], ratio: 0.35, w: [10, 3], c: c0, a: [0.9, 0], n: 6, spiral: 4 })
        add({ s: 'particles', t0: 350, t1: 1500, n: 60, seed, x: tc.x, y: tc.y, sx: 0, sy: 0, mode: 'swirl', r: 150, life: 900, size: [10, 4], style: P.p === 'crystal' ? 'crystal' : 'streak', c: [c0, c1, c2] })
        hit(900, 1)
        back(1500, 60)
        flashAfter(2050)
        break
      }
      // ---- Ondas de som e de mente (Hyper Voice, Psychic): anéis que saem de quem ataca e envolvem o alvo ----
      case 'rings': {
        cam = [[0, ...NEUTRAL], [350, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.05, 0)], [1300, ...look(tc, 1.45, -2 * toward)]]
        add({ s: 'ring', t0: 200, t1: 1200, x: [a.x, tc.x], y: [a.y, tc.y], r: [30, 110], ratio: 0.8, w: 5, c: c1, a: [1, 0.3], n: 5, stagger: 1 })
        add({ s: 'ring', t0: 900, t1: 1600, x: tc.x, y: tc.y, r: [140, 20], ratio: 1, w: [2, 8], c: c0, a: [0, 1], n: 3 })
        add({ s: 'tint', t0: 900, t1: 1600, color: c3, a: [0, 0.35] })
        hit(1250, 1)
        S.push({ who: 'T', k: 'tint', t0: 900, t1: 1600, color: c1, a: 0.5, pulse: 18 })
        back(1650, 60)
        flashAfter(2200)
        break
      }
      // ---- Relâmpago (Thunderbolt): cai do céu, clarão e faíscas ----
      case 'bolt': {
        strike(350, 1.4)
        add({ s: 'tint', t0: 300, t1: 1300, color: '#05040f', a: [0.5, 0.2] })
        for (let i = 0; i < 3; i++) add({ s: 'bolt', t0: 450 + i * 160, t1: 650 + i * 160, x: tc.x + (i - 1) * 30, y: tc.y, r: 0, from: { x: tc.x + (rnd(i) - 0.5) * 160, y: tc.y - 480 }, n: 9, c: '#ffffff', c2: c1, w: 6, flicker: 1 })
        add({ s: 'bolt', t0: 650, t1: 1300, x: tc.x, y: tc.y, r: 130, n: 6, c: c1, c2: '#ffffff', w: 3, flicker: 1 })
        add({ s: 'tint', t0: 450, t1: 560, color: '#ffffff', a: [0.8, 0] })
        hit(650, 1.2)
        S.push({ who: 'T', k: 'tint', t0: 650, t1: 1300, color: c1, a: 0.5, pulse: 40 })
        back(1300, 80)
        flashAfter(1850)
        break
      }
      // ---- Absorver (Giga Drain): bolinhas de luz saem do alvo e vão para quem ataca ----
      case 'drain': {
        strike(300, 1.3)
        add({ s: 'glow', t0: 300, t1: 900, x: tc.x, y: tc.y, r: [30, 100], c: [c0, c1, c2], a: [0.9, 0] })
        hit(380, 0.8)
        cam.push([900, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.0, 0)], [1700, ...look(a, 1.3, 2 * toward)])
        add({ s: 'particles', t0: 800, t1: 1800, n: 30, seed, x: [tc.x, a.x], y: [tc.y, a.y], sx: 50, sy: 40, mode: 'travel', life: 800, size: [9, 5], style: 'dot', c: [c0, c1] })
        add({ s: 'glow', t0: 1500, t1: 2000, x: a.x, y: a.y, r: [40, 120], c: [c0, c1, c2], a: [0.8, 0] })
        S.push({ who: 'A', k: 'tint', t0: 1500, t1: 2000, color: c1, a: 0.45 })
        back(2000, 0)
        flashAfter(2500)
        break
      }
      // ---- Bola (Shadow Ball, Energy Ball): forma em quem ataca e voa girando até o alvo ----
      case 'orb':
      default: {
        if (SELF.has(kind)) {
          selfMove(kind)
          break
        }
        cam = [[0, ...NEUTRAL], [350, ...look(a, 1.3, 2 * toward)], [850, ...look(a, 1.35, 2 * toward)], [1150, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.0, 0)], [1350, ...look(tc, 1.5, -2 * toward)]]
        const o = { x: a.x + 50 * toward, y: a.y - 30 }
        add({ s: 'particles', t0: 250, t1: 950, n: 24, seed, x: o.x, y: o.y, sx: 0, sy: 0, mode: 'converge', r: 140, life: 420, size: [3, 7], style: 'dot', c: [c0, c1] })
        add({ s: 'glow', t0: 300, t1: 950, x: o.x, y: o.y, r: [4, 46], c: [c0, c1, c2, c3], a: 1, core: 0.3, swirl: 1 })
        add({ s: 'glow', t0: 950, t1: 1250, x: [o.x, tc.x], y: [o.y, tc.y], r: [46, 60], c: [c0, c1, c2, c3], a: 1, core: 0.3, swirl: 1, trail: 1 })
        hit(1250, 1.15)
        back(1350, 260)
        flashAfter(2250)
      }
    }
  }


  // Cada golpe com a sua câmera: parada, um pouco perto, de lado, zoom forte, a viagem completa ou aberta.
  function shapeCamera(k) {
    if (!k || k === 'cine' || k === 'wide' || k === 'self') return
    const [fp, fz] = { still: [0, 0], nudge: [0.35, 0.3], pan: [0.75, 0.35], zoom: [1, 1.25] }[k] ?? [1, 1]
    cam = cam.map(([t, x, y, zz, r]) => [t, NEUTRAL[0] + (x - NEUTRAL[0]) * fp, NEUTRAL[1] + (y - NEUTRAL[1]) * fp, Math.max(0.9, 1 + (zz - 1) * fz), r * fp])
    // Câmera parada ou quase: os HPs e a caixa de texto ficam na tela (como nos golpes simples do jogo).
    if (k === 'still' || k === 'nudge') hud = [dur + 1, dur + 1]
  }
  // ---- Uma animação para cada golpe: a receita dele (move_fx.json) diz como chega, a forma, a força, os acertos e o efeito ----
  function byRecipe(r) {
    const p = r.p ?? 1
    const pw = 0.75 + 0.2 * p
    const z = 1.3 + 0.07 * p
    const m = r.m
    const st = MOTIF_STYLE[m] ?? P.p
    const n = r.n ?? 1
    const v = r.v ?? 0
    const vr = (i) => fxRand(v * 1.37 + i)
    const tilt = (vr(1) - 0.5) * 4
    let t = 0
    // Carrega antes (Solar Beam, Sky Attack): energia juntando em quem ataca.
    const charge = (t0, len = 650) => {
      cam = [[0, ...NEUTRAL], [t0 + 300, ...look(a, 1.4, 2 * toward)]]
      add({ s: 'particles', t0, t1: t0 + len, n: 30, seed: v, x: a.x, y: a.y, sx: 0, sy: 0, mode: 'converge', r: 170, life: 450, size: [3, 8], style: st === 'leaf' ? 'leaf' : 'dot', c: [c0, c1] })
      add({ s: 'glow', t0: t0 + 100, t1: t0 + len, x: a.x, y: a.y, r: [10, 90], c: [c0, c1, c2], a: [0.2, 0.8], swirl: 1 })
      S.push({ who: 'A', k: 'tint', t0, t1: t0 + len, color: c1, a: 0.5, pulse: 20 })
      return t0 + len
    }
    // A forma do golpe, grande, no impacto (punho, pé, garras, lâmina, chifre, presas, asa, cauda...).
    const motifHit = (t1, at = tc, k = 0) => {
      const sz = 70 + 18 * p
      const flip = (vr(k + 3) > 0.5 ? 1 : -1) * toward
      if (m === 'blade' || m === 'claw' || m === 'whip') {
        const cuts = m === 'claw' ? 3 : m === 'whip' ? 1 : 1 + (p > 2 ? 1 : 0)
        for (let i = 0; i < cuts; i++) {
          const off = (i - (cuts - 1) / 2) * (m === 'claw' ? 26 : 30)
          const a0 = m === 'whip' ? -2.9 : -2.3 + vr(k + i) * 0.4
          add({ s: 'arc', t0: t1 - 80 + i * (m === 'claw' ? 40 : 110), t1: t1 + 220 + i * 60, x: at.x + off, y: at.y, r: m === 'whip' ? 120 : 95, a0, a1: [a0, a0 + (m === 'whip' ? 2.6 : 3.0)], w: m === 'claw' ? 6 : 10, c: '#ffffff', c2: c1, flip: (i + (flip > 0 ? 0 : 1)) % 2 })
        }
      } else if (m === 'fang') add({ s: 'fangs', t0: t1 - 160, t1: t1 + 260, x: at.x, y: at.y, r: 80, close: [0, 1], c: '#ffffff', c2: c2 })
      else if (m === 'horn') for (let i = 0; i < Math.max(1, n === 1 ? 2 : 1); i++) add({ s: 'cone', t0: t1 - 120 + i * 90, t1: t1 + 60 + i * 90, x: at.x + (i - 0.5) * 24, y: [at.y + 140, at.y], w: 20, c: c1, a: 1 })
      else if (m === 'web') add({ s: 'web', t0: t1 - 100, t1: t1 + 700, x: at.x, y: at.y, r: [20, 130], n: 8, rings: 5, w: 2.5, c: '#ffffff', c2: c1, a: [1, 0] })
      else if (['fist', 'foot', 'head', 'body', 'wing'].includes(m))
        add({ s: 'icon', t0: t1 - 140, t1: t1 + 200, x: at.x - 30 * toward, y: at.y, size: [sz * 1.8, sz], a: [0.5, 1], style: m, c: [c0, c1, c2], rot: tilt * 0.08 * flip })
      else add({ s: 'icon', t0: t1 - 60, t1: t1 + 300, x: at.x, y: at.y, size: [sz * 0.4, sz * 1.1], a: [1, 0], style: m, c: [c0, c1, c2], rot: tilt * 0.1 })
    }
    // O efeito no fim (queimou, congelou, paralisou, envenenou, dormiu, ficou confuso, atributo subiu ou desceu...).
    const after = (t1) => {
      const e = r.e
      if (!e) return t1
      const F = FX_EFFECT[e]
      if (!F) return t1
      const at = e === 'up' || e === 'heal' || e === 'recoil' ? a : tc
      const who = at === a ? 'A' : 'T'
      if (e === 'drain' || e === 'heal') {
        if (e === 'drain') add({ s: 'particles', t0: t1, t1: t1 + 800, n: 22, seed: v + 1, x: [tc.x, a.x], y: [tc.y, a.y], sx: 50, sy: 40, mode: 'travel', life: 650, size: [9, 5], style: 'dot', c: ['#ffffff', '#b8ffcf', '#4ade80'] })
        add({ s: 'particles', t0: t1 + 300, t1: t1 + 1000, n: 18, seed: v + 2, x: a.x, y: A.y, sx: A.h * 0.35, sy: 10, v: 0, vy: -220, g: 0, life: 600, mode: 'stream', size: [10, 4], style: 'star', c: ['#ffffff', '#b8ffcf', '#4ade80'] })
        S.push({ who: 'A', k: 'tint', t0: t1 + 300, t1: t1 + 1000, color: '#4ade80', a: 0.4, pulse: 10 })
        return t1 + 1000
      }
      if (e === 'recoil') {
        S.push({ who: 'A', k: 'move', t0: t1, t1: t1 + 300, dx: -14 * toward, dy: 0, bounce: 2 })
        add({ s: 'glow', t0: t1, t1: t1 + 260, x: a.x, y: a.y, r: [10, 70], c: ['#ffffff', c1, c2], a: [0.8, 0] })
        return t1 + 300
      }
      add({ s: 'particles', t0: t1, t1: t1 + 900, n: F.n, seed: v + 3, x: at.x, y: at.y + (F.vy > 0 ? -60 : 30), sx: (at === a ? A.h : T.h) * 0.35, sy: 30, v: F.v ?? 0, vy: F.vy, g: 0, life: 650, mode: F.mode ?? 'stream', r: 110, size: F.size, style: F.style, c: F.c })
      if (F.tint) S.push({ who, k: 'tint', t0: t1, t1: t1 + 800, color: F.tint, a: 0.45, pulse: 16 })
      if (F.ring) add({ s: 'ring', t0: t1, t1: t1 + 700, x: at.x, y: at.y, r: [130, 30], ratio: 0.6, w: [2, 6], c: F.ring, a: [0, 1], n: 2 })
      if (F.bolt) add({ s: 'bolt', t0: t1, t1: t1 + 600, x: at.x, y: at.y, r: 110, n: 5, c: '#ffffff', c2: '#ffe94a', w: 2.5, flicker: 1 })
      return t1 + 900
    }
    const finish = (t1, zoomOut = 0) => {
      const t2 = after(t1 + 100)
      back(Math.max(t1 + 200, t2 - 200), zoomOut)
      flashAfter(Math.max(t1 + 200, t2 - 200) + 520)
    }
    if (r.c) t = charge(0)
    switch (r.d) {
      case 'dash':
      case 'dive': {
        const t1 = t + 520
        cam = (t ? cam : [[0, ...NEUTRAL]]).concat([[t + 280, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.1, 0)], [t1, ...look(tc, z + 0.1, (-3 + tilt) * toward)]])
        if (r.d === 'dive') {
          S.push({ who: 'A', k: 'move', t0: t, t1: t + 380, dx: 0, dy: -700, back: 0 })
          S.push({ who: 'A', k: 'hide', t0: t + 360, t1: t1 + 500 + n * 260 })
          add({ s: 'cone', t0: t1 - 240, t1: t1 + 40, x: tc.x, y: [tc.y - 460, tc.y], w: 70, c: c1, a: 0.95 })
        } else {
          S.push({ who: 'A', k: 'move', t0: t + 80, t1: t1 + 160 + (n - 1) * 260, dx: (tc.x - a.x) * 0.55, dy: (tc.y - a.y) * 0.55, back: 1 })
          add({ s: 'particles', t0: t + 120, t1, n: 16, seed: v, x: [a.x, tc.x], y: [a.y, tc.y], sx: 40, sy: 30, v: 40, vy: 0, g: 0, life: 260, mode: 'trail', size: [7, 2], style: 'streak', c: ['#ffffff', c1] })
        }
        for (let i = 0; i < n; i++) {
          const ti = t1 + i * 260
          motifHit(ti, { x: tc.x + (i - (n - 1) / 2) * 30, y: tc.y + (vr(i) - 0.5) * 30 }, i)
          hit(ti + 60, pw * (i === n - 1 ? 1.15 : 0.8))
          if (type !== 'normal' && type !== 'fighting') add(typeParticles(ti + 80, tc, 10 + 4 * p, 'burst', 520, pw))
        }
        cam.push([t1 + n * 260 + 200, ...look(tc, z, (-2 + tilt) * toward)])
        finish(t1 + n * 260 + 150, 60)
        break
      }
      case 'shot':
      case 'volley': {
        const k = Math.max(n, r.d === 'volley' ? 3 : 1)
        const t0 = t + 380
        cam = (t ? cam : [[0, ...NEUTRAL]]).concat([[t0, ...look({ x: a.x * 0.35 + tc.x * 0.65, y: a.y * 0.35 + tc.y * 0.65 }, 1.15, -toward)], [t0 + 300 + k * 170, ...look(tc, z, (-2 + tilt) * toward)]])
        const o = { x: front.x + 14 * toward, y: front.y }
        add({ s: 'glow', t0: t, t1: t0 + 60, x: o.x, y: o.y, r: [4, 34 + 6 * p], c: [c0, c1, c2], a: 1, swirl: 1 })
        for (let i = 0; i < k; i++) {
          const ti = t0 + 300 + i * 170
          const dx = (vr(i) - 0.5) * (k > 1 ? 110 : 0)
          const dy = (vr(i + 9) - 0.5) * (k > 1 ? 70 : 0)
          add({ s: 'shot', t0: ti - 300, t1: ti, x: [o.x, tc.x + dx], y: [o.y - 40 * Math.sin(vr(i + 5) * 3), tc.y + dy], r: 14 + 5 * p, c: [c0, c1, c2, c3], style: st, trail: 1, spin: vr(i + 7) > 0.5 ? 1 : -1 })
          add({ s: 'glow', t0: ti, t1: ti + 220, x: tc.x + dx, y: tc.y + dy, r: [10, 60 + 10 * p], c: [c0, c1, c2], a: [1, 0] })
          shake.push([ti, ti + 120, 3 + p])
        }
        const last = t0 + 300 + (k - 1) * 170
        motifHit(last + 20)
        hit(last + 40, pw)
        finish(last + 300, 60)
        break
      }
      case 'beam':
      case 'jet': {
        const t0 = t + 350
        cam = (t ? cam : [[0, ...NEUTRAL]]).concat([[t0, ...look(a, 1.3, 2 * toward)], [t0 + 450, ...look(a, 1.35, 2 * toward)], [t0 + 650, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.0, 0)], [t0 + 950, ...look(tc, z, (-2 + tilt) * toward)]])
        const o = mouth
        if (r.d === 'beam') {
          add({ s: 'particles', t0: t0 - 100, t1: t0 + 550, n: 26, seed: v, x: o.x, y: o.y, sx: 0, sy: 0, mode: 'converge', r: 160, life: 450, size: [3, 7], style: 'dot', c: [c0, c1] })
          add({ s: 'glow', t0: t0 - 50, t1: t0 + 600, x: o.x, y: o.y, r: [6, 40 + 8 * p], c: [c0, c1, c2], a: 1 })
          add({ s: 'beam', t0: t0 + 550, t1: t0 + 1450, x0: o.x, y0: o.y, x1: tc.x, y1: tc.y, w: [10, 26 + 8 * p], c: [c0, c1, c2], a: [1, 0], wobble: 4, grow: 120 })
          add({ s: 'particles', t0: t0 + 600, t1: t0 + 1400, n: 30 + 6 * p, seed: v + 3, x: [o.x, tc.x], y: [o.y, tc.y], sx: 20, sy: 20, v: 60, vy: 0, g: 0, life: 300, mode: 'trail', size: [8, 2], style: st, c: [c0, c1, c2] })
        } else
          add({ s: 'particles', t0: t0 + 200, t1: t0 + 1350, n: 70 + 20 * p, seed: v, x: [o.x, tc.x], y: [o.y, tc.y], sx: 6, sy: 6, spread: 18 + 6 * p, mode: 'jet', life: 420, size: [10, 18 + 6 * p], style: st === 'bubble' ? 'droplet' : st === 'goo' ? 'goo' : 'flame', c: [c0, c1, c2, c3] })
        motifHit(t0 + 750)
        hit(t0 + 760, pw)
        S.push({ who: 'T', k: 'tint', t0: t0 + 760, t1: t0 + 1450, color: c2, a: 0.55, pulse: 26 })
        finish(t0 + 1450, 60)
        break
      }
      case 'sky': {
        const t0 = t + 350
        cam = (t ? cam : [[0, ...NEUTRAL]]).concat([[t0, ...look({ x: tc.x, y: tc.y - 120 }, 1.2, -toward)], [t0 + 700, ...look(tc, z, (-3 + tilt) * toward)]])
        add({ s: 'tint', t0, t1: t0 + 1100, color: '#05040f', a: [0.45, 0.15] })
        const k = st === 'spark' ? 3 : 3 + p
        for (let i = 0; i < k; i++) {
          const ti = t0 + 250 + i * 140
          const dx = (vr(i) - 0.5) * 140
          if (st === 'spark') add({ s: 'bolt', t0: ti, t1: ti + 220, x: tc.x + dx * 0.3, y: tc.y, r: 0, from: { x: tc.x + dx, y: tc.y - 480 }, n: 9, c: '#ffffff', c2: c1, w: 5 + p, flicker: 1 })
          else add({ s: 'shot', t0: ti - 260, t1: ti, x: [tc.x + dx - 160 * toward, tc.x + dx * 0.4], y: [tc.y - 460, tc.y + (vr(i + 3) - 0.5) * 40], r: 18 + 6 * p, c: [c0, c1, c2, c3], style: st, trail: 1 })
          add({ s: 'glow', t0: ti, t1: ti + 220, x: tc.x + dx * 0.35, y: tc.y, r: [10, 70 + 10 * p], c: [c0, c1, c2], a: [1, 0] })
          shake.push([ti, ti + 140, 4 + 2 * p])
        }
        if (st === 'spark') add({ s: 'tint', t0: t0 + 250, t1: t0 + 360, color: '#ffffff', a: [0.8, 0] })
        hit(t0 + 250 + (k - 1) * 140, pw * 1.1)
        finish(t0 + 400 + k * 140, 60)
        break
      }
      case 'quake': {
        cam = (t ? cam : [[0, ...NEUTRAL]]).concat([[t + 300, 480, 300, 0.92, 0], [t + 1400, 480, 300, 0.95, 0]])
        add({ s: 'crack', t0: t + 300, t1: t + 1400, x: tc.x, y: T.y, r: [20, 220 + 30 * p], n: 5 + p, c: c3, c2: c1, a: [1, 0] })
        add({ s: 'particles', t0: t + 350, t1: t + 1400, n: 30 + 10 * p, seed: v, x: tc.x, y: T.y, sx: 220, sy: 10, v: 60, vy: -260, g: 600, life: 700, mode: 'stream', size: [12, 4], style: st === 'shard' ? 'shard' : 'dust', c: [c1, c2, c3] })
        shake.push([t + 300, t + 1300, 8 + 2 * p])
        S.push({ who: 'T', k: 'move', t0: t + 400, t1: t + 1100, dx: 0, dy: -24, bounce: 3 })
        hit(t + 700, pw)
        finish(t + 1300, 0)
        break
      }
      case 'wave': {
        cam = (t ? cam : [[0, ...NEUTRAL]]).concat([[t + 400, 480, 290, 0.95, -toward], [t + 1500, ...look(tc, 1.3, -2 * toward)]])
        add({ s: 'wave', t0: t + 300, t1: t + 1500, dir: toward, c: [c0, c1, c2, c3], h: [0.2, 0.55 + 0.06 * p] })
        add({ s: 'particles', t0: t + 500, t1: t + 1500, n: 50, seed: v, x: tc.x, y: tc.y, sx: 200, sy: 120, v: 120, vy: -200, g: 500, life: 600, mode: 'stream', size: [8, 3], style: st === 'bubble' ? 'droplet' : st, c: [c0, c1, c2] })
        hit(t + 950, pw)
        finish(t + 1500, 60)
        break
      }
      case 'gale': {
        cam = (t ? cam : [[0, ...NEUTRAL]]).concat([[t + 380, ...look(tc, z, (-2 + tilt) * toward)]])
        add({ s: 'ring', t0: t + 300, t1: t + 1400, x: tc.x, y: [T.y, tc.y - 60], r: [40, 120 + 10 * p], ratio: 0.35, w: [10, 3], c: c0, a: [0.9, 0], n: 4 + p, spiral: 4 })
        add({ s: 'particles', t0: t + 350, t1: t + 1400, n: 40 + 10 * p, seed: v, x: tc.x, y: tc.y, sx: 0, sy: 0, mode: 'swirl', r: 150, life: 900, size: [10, 4], style: ['crystal', 'leaf', 'feather', 'shard'].includes(st) ? st : 'streak', c: [c0, c1, c2] })
        hit(t + 850, pw)
        finish(t + 1400, 60)
        break
      }
      case 'sound':
      case 'aura': {
        const sound = r.d === 'sound'
        cam = (t ? cam : [[0, ...NEUTRAL]]).concat([[t + 350, ...look(sound ? { x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 } : tc, sound ? 1.05 : z - 0.1, 0)], [t + 1250, ...look(tc, z, (-2 + tilt) * toward)]])
        if (sound) {
          add({ s: 'ring', t0: t + 200, t1: t + 1200, x: [mouth.x, tc.x], y: [mouth.y, tc.y], r: [30, 110], ratio: 0.8, w: 5, c: c1, a: [1, 0.3], n: 3 + p, stagger: 1 })
          add({ s: 'particles', t0: t + 200, t1: t + 1200, n: 14 + 3 * p, seed: v, x: [mouth.x, tc.x], y: [mouth.y, tc.y], sx: 60, sy: 50, mode: 'travel', life: 800, size: [16, 12], style: 'note', c: [c0, c1, c2] })
        } else {
          add({ s: 'tint', t0: t + 300, t1: t + 1300, color: c3, a: [0, 0.4] })
          add({ s: 'particles', t0: t + 300, t1: t + 1200, n: 30 + 6 * p, seed: v, x: tc.x, y: tc.y, sx: 0, sy: 0, mode: 'converge', r: 220, life: 600, size: [4, 10], style: st, c: [c0, c1, c2] })
        }
        add({ s: 'ring', t0: t + 800, t1: t + 1500, x: tc.x, y: tc.y, r: [150, 20], ratio: 1, w: [2, 8], c: c0, a: [0, 1], n: 3 })
        motifHit(t + 1150)
        hit(t + 1200, pw)
        S.push({ who: 'T', k: 'tint', t0: t + 800, t1: t + 1500, color: c1, a: 0.5, pulse: 18 })
        finish(t + 1500, 60)
        break
      }
      case 'blast': {
        const self = has(slug, 'explosion', 'self-destruct', 'mind-blown', 'misty-explosion')
        const at = self ? a : tc
        cam = (t ? cam : [[0, ...NEUTRAL]]).concat([[t + 400, ...look(at, 1.3, 2 * toward)], [t + 900, 480, 280, 0.95, 0]])
        add({ s: 'glow', t0: t + 300, t1: t + 900, x: at.x, y: at.y, r: [10, 90], c: ['#ffffff', c1, c2], a: 1, swirl: 1 })
        add({ s: 'tint', t0: t + 900, t1: t + 1050, color: '#ffffff', a: [1, 0] })
        add({ s: 'fill', t0: t + 900, t1: t + 1800, c: [c0, c1, c2, c3], from: 'center', a: 0.85 })
        add(typeParticles(t + 950, at, 30, 'burst', 700, 1.6))
        shake.push([t + 900, t + 1700, 10 + 2 * p])
        if (self) S.push({ who: 'A', k: 'tint', t0: t + 300, t1: t + 900, color: '#ffffff', a: 0.8, pulse: 30 })
        hit(t + 950, pw * 1.2)
        finish(t + 1700, 0)
        break
      }
      case 'drain': {
        cam = (t ? cam : [[0, ...NEUTRAL]]).concat([[t + 300, ...look(tc, 1.3, -2 * toward)], [t + 900, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.0, 0)]])
        motifHit(t + 380)
        hit(t + 380, pw * 0.8)
        add({ s: 'glow', t0: t + 300, t1: t + 900, x: tc.x, y: tc.y, r: [30, 100], c: [c0, c1, c2], a: [0.9, 0] })
        finish(t + 500, 0)
        break
      }
      case 'hex':
      case 'hazard': {
        cam = (t ? cam : [[0, ...NEUTRAL]]).concat([[t + 400, ...look(tc, 1.35, (-2 + tilt) * toward)]])
        if (r.d === 'hazard') {
          for (let i = 0; i < 4 + (p > 1 ? 1 : 0); i++) {
            const dx = (i - 2) * 50 + (vr(i) - 0.5) * 20
            add({ s: 'shot', t0: t + 100 + i * 110, t1: t + 500 + i * 110, x: [front.x, tc.x + dx], y: [front.y, T.y - 6], r: 16, c: [c0, c1, c2, c3], style: st, arc: 160 })
            add({ s: 'icon', t0: t + 500 + i * 110, t1: t + 1500, x: tc.x + dx, y: T.y - 6, size: 26, a: [1, 1], style: st === 'dot' ? 'star' : st, c: [c0, c1, c2] })
          }
          hud = [100, 1500]
          cam.push([1500, ...look(tc, 1.35, -2 * toward)], [1900, ...NEUTRAL])
          end(2000)
          break
        }
        add({ s: 'particles', t0: t + 150, t1: t + 1100, n: 24 + 4 * p, seed: v, x: [front.x, tc.x], y: [front.y, tc.y], sx: 70, sy: 50, mode: 'travel', life: 800, size: [8, 4], style: st, c: [c0, c1, c2] })
        add({ s: 'ring', t0: t + 700, t1: t + 1400, x: tc.x, y: tc.y, r: [120, 20], ratio: 0.6, w: [2, 7], c: c1, a: [0, 1], n: 3 })
        motifHit(t + 900)
        S.push({ who: 'T', k: 'tint', t0: t + 800, t1: t + 1400, color: c2, a: 0.45, pulse: 14 })
        const t2 = after(t + 1000)
        hud = [100, t2]
        cam.push([t2, ...look(tc, 1.35, -2 * toward)], [t2 + 380, ...NEUTRAL])
        end(t2 + 420)
        break
      }
      case 'self':
      case 'field':
        selfRecipe(r, st)
        break
      case 'orb':
      default: {
        const t0 = t + 350
        cam = (t ? cam : [[0, ...NEUTRAL]]).concat([[t0, ...look(a, 1.3, 2 * toward)], [t0 + 500, ...look(a, 1.35, 2 * toward)], [t0 + 800, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.0, 0)], [t0 + 1000, ...look(tc, z, (-2 + tilt) * toward)]])
        const o = { x: front.x + 40 * toward, y: (mouth.y + front.y) / 2 }
        add({ s: 'particles', t0: t0 - 100, t1: t0 + 600, n: 24, seed: v, x: o.x, y: o.y, sx: 0, sy: 0, mode: 'converge', r: 140, life: 420, size: [3, 7], style: st, c: [c0, c1] })
        add({ s: 'glow', t0: t0 - 50, t1: t0 + 600, x: o.x, y: o.y, r: [4, 36 + 6 * p], c: [c0, c1, c2, c3], a: 1, core: 0.3, swirl: 1 })
        add({ s: 'glow', t0: t0 + 600, t1: t0 + 900, x: [o.x, tc.x], y: [o.y, tc.y], r: [36 + 6 * p, 50 + 8 * p], c: [c0, c1, c2, c3], a: 1, core: 0.3, swirl: 1, trail: 1 })
        motifHit(t0 + 900)
        hit(t0 + 900, pw)
        finish(t0 + 1150, 160)
      }
    }
  }
  // Em quem usa (atributos, cura, redoma, dança) ou no campo (clima, terreno, sala).
  function selfRecipe(r, st) {
    const m = r.m
    const v = r.v ?? 0
    if (r.d === 'field') {
      cam = [[0, ...NEUTRAL], [500, 480, 250, 0.92, 0], [1600, 480, 260, 0.94, 0]]
      const rain = m === 'bubble'
      const sun = m === 'sun' || m === 'flame'
      const sand = m === 'dust' || m === 'rock'
      const snow = m === 'crystal'
      add({ s: 'tint', t0: 300, t1: 1700, color: sun ? '#ffb02e' : rain ? '#0b2a55' : c2, a: [0, sun ? 0.25 : 0.35] })
      if (sun) add({ s: 'rays', t0: 300, t1: 1700, x: 480, y: -40, n: 14, r0: 0, r1: [200, 700], w: [4, 12], c: '#fff7c2', c2: '#ffb02e', a: [0, 0.8], rot: [0, 0.6] })
      add({ s: 'particles', t0: 300, t1: 1700, n: rain ? 110 : 70, seed: v, x: 480, y: rain || snow || sand ? -20 : 560, sx: 560, sy: 10, v: sand ? 900 : 30, vy: rain ? 900 : snow ? 220 : sand ? 120 : -260, g: 0, life: rain ? 500 : 1000, mode: 'stream', size: rain ? [14, 14] : [10, 4], style: rain ? 'rain' : snow ? 'crystal' : sand ? 'dust' : st, c: [c0, c1, c2] })
      hud = [100, 1600]
      cam.push([2000, ...NEUTRAL])
      end(2100)
      return
    }
    cam = [[0, ...NEUTRAL], [400, ...look(a, 1.4, 2 * toward)], [1500, ...look(a, 1.45, 2 * toward)]]
    if (r.e === 'heal') {
      add({ s: 'particles', t0: 400, t1: 1500, n: 30, seed: v, x: a.x, y: A.y, sx: A.h * 0.4, sy: 10, v: 0, vy: -220, g: 0, life: 800, mode: 'stream', size: [10, 4], style: 'star', c: ['#ffffff', '#b8ffcf', '#4ade80'] })
      add({ s: 'glow', t0: 600, t1: 1500, x: a.x, y: a.y, r: [40, 160], c: ['#ffffff', '#b8ffcf', '#4ade80'], a: [0.7, 0] })
      S.push({ who: 'A', k: 'tint', t0: 600, t1: 1400, color: '#4ade80', a: 0.4, pulse: 10 })
    } else if (m === 'ring' || m === 'gear') {
      add({ s: 'ring', t0: 400, t1: 1400, x: a.x, y: a.y, r: [20, A.h * 0.7], ratio: 1, w: [12, 3], c: c0, a: [1, 0.2], n: 1 })
      add({ s: 'glow', t0: 500, t1: 1400, x: a.x, y: a.y, r: A.h * 0.7, c: ['rgba(0,0,0,0)', c1, c0], a: [0.6, 0], core: 0.7 })
      add({ s: 'particles', t0: 500, t1: 1400, n: 12, seed: v, x: a.x, y: a.y, sx: 0, sy: 0, mode: 'orbit', r: A.h * 0.6, life: 900, size: [10, 10], style: m === 'gear' ? 'gear' : 'glint', c: [c0, c1] })
    } else {
      // Dança e atributos: as formas giram em volta, a aura sobe e as setas sobem.
      add({ s: 'particles', t0: 300, t1: 1300, n: 6, seed: v, x: a.x, y: a.y, sx: 0, sy: 0, mode: 'orbit', r: A.h * 0.55, life: 1000, size: [26, 26], style: st, c: [c0, c1, c2] })
      add({ s: 'ring', t0: 300, t1: 1300, x: a.x, y: [A.y, A.y - A.h], r: A.h * 0.45, ratio: 0.3, w: 5, c: c1, a: [1, 0], n: 4, stagger: 1 })
      add({ s: 'particles', t0: 300, t1: 1400, n: 36, seed: v + 1, x: a.x, y: A.y, sx: A.h * 0.4, sy: 10, v: 0, vy: -320, g: 0, life: 700, mode: 'stream', size: [10, 3], style: 'streak', c: [c0, c1, c2] })
      if (r.e === 'up') add({ s: 'particles', t0: 800, t1: 1500, n: 10, seed: v + 4, x: a.x, y: A.y - A.h * 0.3, sx: A.h * 0.35, sy: 20, v: 0, vy: -200, g: 0, life: 600, mode: 'stream', size: [16, 12], style: 'arrowUp', c: ['#ffffff', c1, c2] })
      S.push({ who: 'A', k: 'tint', t0: 600, t1: 1400, color: c1, a: 0.45, pulse: 16 })
    }
    hud = [100, 1500]
    cam.push([1900, ...NEUTRAL])
    end(2000)
  }
  // Golpes que acontecem em quem usa: aura, anéis, brilho subindo (atributos, cura, proteção, clima...).
  function selfMove(k) {
    cam = [[0, ...NEUTRAL], [400, ...look(a, 1.4, 2 * toward)], [1500, ...look(a, 1.45, 2 * toward)]]
    if (k === 'weather' || k === 'terrain' || k === 'field') {
      cam = [[0, ...NEUTRAL], [500, 480, 250, 0.92, 0], [1500, 480, 260, 0.94, 0]]
      add({ s: 'tint', t0: 300, t1: 1600, color: c2, a: [0, 0.3] })
      add({ s: 'particles', t0: 300, t1: 1600, n: 70, seed, x: 480, y: k === 'weather' ? -20 : 560, sx: 520, sy: 10, v: 30, vy: k === 'weather' ? 520 : -260, g: 0, life: 900, mode: 'stream', size: [10, 4], style: P.p, c: [c0, c1, c2] })
      hud = [100, 1500]
      cam.push([1900, ...NEUTRAL])
      end(2000)
      return
    }
    if (k === 'shield' || k === 'wall') {
      add({ s: 'ring', t0: 400, t1: 1400, x: a.x, y: a.y, r: [20, A.h * 0.7], ratio: 1, w: [12, 3], c: c0, a: [1, 0.2], n: 1 })
      add({ s: 'glow', t0: 500, t1: 1400, x: a.x, y: a.y, r: A.h * 0.7, c: ['rgba(0,0,0,0)', c1, c0], a: [0.6, 0], core: 0.7 })
    } else if (k === 'drop' || k === 'status' || k === 'powder' || k === 'hazard' || k === 'swap') {
      // No alvo: o sinal do problema (pó, anéis, setas para baixo).
      cam = [[0, ...NEUTRAL], [400, ...look(tc, 1.4, -2 * toward)], [1500, ...look(tc, 1.45, -2 * toward)]]
      if (k === 'powder') add({ s: 'particles', t0: 200, t1: 1400, n: 50, seed, x: [a.x, tc.x], y: [a.y, tc.y], sx: 60, sy: 50, mode: 'travel', life: 900, size: [6, 3], style: 'dot', c: [c0, c1, c2] })
      add({ s: 'ring', t0: 500, t1: 1400, x: tc.x, y: tc.y, r: [120, 20], ratio: 0.6, w: [2, 7], c: c1, a: [0, 1], n: 3 })
      add({ s: 'particles', t0: 600, t1: 1500, n: 16, seed: seed + 2, x: tc.x, y: tc.y - 40, sx: 70, sy: 30, v: 0, vy: k === 'drop' ? 180 : -60, g: 0, life: 700, mode: 'stream', size: [12, 6], style: k === 'drop' ? 'arrowDown' : 'dot', c: [c0, c1, c2] })
      S.push({ who: 'T', k: 'tint', t0: 600, t1: 1500, color: c2, a: 0.45, pulse: 14 })
      hud = [100, 1500]
      cam.push([1900, ...NEUTRAL])
      end(2000)
      return
    } else if (k === 'heal') {
      add({ s: 'particles', t0: 400, t1: 1500, n: 30, seed, x: a.x, y: A.y, sx: A.h * 0.4, sy: 10, v: 0, vy: -220, g: 0, life: 800, mode: 'stream', size: [10, 4], style: 'star', c: ['#ffffff', '#b8ffcf', '#4ade80'] })
      add({ s: 'glow', t0: 600, t1: 1500, x: a.x, y: a.y, r: [40, 160], c: ['#ffffff', '#b8ffcf', '#4ade80'], a: [0.7, 0] })
      S.push({ who: 'A', k: 'tint', t0: 600, t1: 1400, color: '#4ade80', a: 0.4, pulse: 10 })
    } else if (k === 'explode') {
      add({ s: 'glow', t0: 400, t1: 900, x: a.x, y: a.y, r: [10, 80], c: ['#ffffff', c1, c2], a: 1, swirl: 1 })
      add({ s: 'tint', t0: 900, t1: 1050, color: '#ffffff', a: [1, 0] })
      add({ s: 'fill', t0: 900, t1: 1800, c: ['#ffd36b', '#ff8a2a', '#e5391a', '#5a1a08'], from: 'center', a: 0.9 })
      shake.push([900, 1700, 16])
      S.push({ who: 'A', k: 'tint', t0: 400, t1: 900, color: '#ffffff', a: 0.8, pulse: 30 })
    } else {
      // boost, dance, charge: a aura sobe, anéis apertam e setas sobem.
      add({ s: 'ring', t0: 300, t1: 1300, x: a.x, y: [A.y, A.y - A.h], r: A.h * 0.45, ratio: 0.3, w: 5, c: c1, a: [1, 0], n: 4, stagger: 1 })
      add({ s: 'particles', t0: 300, t1: 1400, n: 40, seed, x: a.x, y: A.y, sx: A.h * 0.4, sy: 10, v: 0, vy: -320, g: 0, life: 700, mode: 'stream', size: [10, 3], style: k === 'dance' ? P.p : 'streak', c: [c0, c1, c2] })
      add({ s: 'particles', t0: 700, t1: 1500, n: 10, seed: seed + 4, x: a.x, y: A.y - A.h * 0.3, sx: A.h * 0.35, sy: 20, v: 0, vy: -200, g: 0, life: 600, mode: 'stream', size: [16, 12], style: 'arrowUp', c: ['#ffffff', c1, c2] })
      S.push({ who: 'A', k: 'tint', t0: 600, t1: 1400, color: c1, a: 0.45, pulse: 16 })
    }
    hud = [100, 1500]
    cam.push([1900, ...NEUTRAL])
    end(2000)
  }

  if (!hud) hud = [120, dur - 80]
  cam.sort((x, y) => x[0] - y[0])
  if (cam[cam.length - 1][0] < dur) cam.push([dur, ...cam[cam.length - 1].slice(1)])
  return { dur, cam, hud, shake, sprites: S, layers: L, contact, from, world: [stage.w, stage.h] }
}


/**
 * As cenas da batalha como no Black & White (mesmo motor dos golpes): kind
 *   sendout  a Poké Ball voa, abre num clarão com brilhos e o Pokémon sai dela como silhueta branca e cresce
 *   recall   o raio vermelho volta para a Poké Ball: o Pokémon fica vermelho e encolhe até sumir
 *   faint    o Pokémon desmaia: desce, fica escuro e some
 * [side] 0 o seu (perto, de costas), 1 o outro. A câmera vai até ele e volta.
 */
export function fxScene({ kind, side = 1, stage = FX_STAGE, seed = 1 }) {
  const S = side === 0 ? stage.near : stage.far
  const c = body(S)
  const NEUTRAL = [stage.w / 2, stage.h / 2, 1, 0]
  const look = (p, z, r = 0) => [p.x, p.y, z, r]
  const L = []
  const SP = []
  const shake = []
  const who = 'A' // a cena é sempre de um Pokémon: ele é o "A" do plano
  const toward = side === 0 ? 1 : -1
  let cam
  let dur
  if (kind === 'sendout') {
    // A bola vem de fora da tela (do treinador), em arco, gira e cai nos pés dele.
    const from = side === 0 ? { x: -60, y: stage.h * 0.8 } : { x: stage.w + 60, y: S.y - S.h * 1.2 }
    const land = { x: S.x, y: S.y - 30 }
    cam = [[0, ...look({ x: (from.x + land.x) / 2, y: (from.y + land.y) / 2 }, side === 0 ? 1.0 : 1.05, 0)], [500, ...look(c, side === 0 ? 1.2 : 1.45, -2 * toward)], [1350, ...look(c, side === 0 ? 1.15 : 1.4, -toward)], [1800, ...NEUTRAL]]
    L.push({ s: 'shot', t0: 0, t1: 520, x: [from.x, land.x], y: [from.y, land.y], r: 14, c: ['#ffffff', '#ef4444', '#991b1b', '#111827'], style: 'pokeball', arc: 140, spin: toward })
    // Abre: clarão, raios, anel e brilhos subindo.
    L.push({ s: 'tint', t0: 520, t1: 680, color: '#ffffff', a: [0.7, 0] })
    L.push({ s: 'glow', t0: 520, t1: 900, x: land.x, y: land.y - S.h * 0.3, r: [10, S.h * 0.75], c: ['#ffffff', '#fff7d6', '#ffd6e0'], a: [1, 0] })
    L.push({ s: 'rays', t0: 520, t1: 880, x: land.x, y: land.y - S.h * 0.3, n: 12, r0: 10, r1: [40, S.h * 0.9], w: 5, c: '#ffffff', c2: '#fde68a', a: [1, 0], rot: [0, 0.8] })
    L.push({ s: 'ring', t0: 540, t1: 1000, x: land.x, y: land.y, r: [10, S.h * 0.55], ratio: 0.35, w: [8, 2], c: '#ffffff', a: [1, 0], n: 2, stagger: 1 })
    L.push({ s: 'particles', t0: 560, t1: 1400, n: 26, seed, x: land.x, y: land.y - S.h * 0.2, sx: S.h * 0.35, sy: S.h * 0.2, v: 0, vy: -140, g: 0, life: 700, mode: 'stream', size: [12, 4], style: 'star', c: ['#ffffff', '#fef3c7', '#bae6fd'] })
    SP.push({ who, k: 'hide', t0: 0, t1: 560 })
    SP.push({ who, k: 'grow', t0: 560, t1: 900, s0: 0.05, s1: 1 })
    SP.push({ who, k: 'silhouette', t0: 560, t1: 980 })
    SP.push({ who, k: 'tint', t0: 900, t1: 1300, color: '#ffffff', a: 0.4 })
    dur = 1850
  } else if (kind === 'recall') {
    // O raio vermelho sai da mão do treinador (fora da tela) e puxa o Pokémon de volta.
    const hand = side === 0 ? { x: -40, y: stage.h * 0.75 } : { x: stage.w + 40, y: S.y - S.h * 1.1 }
    cam = [[0, ...NEUTRAL], [350, ...look(c, side === 0 ? 1.15 : 1.35, -toward)], [1100, ...look(c, side === 0 ? 1.1 : 1.3, 0)], [1450, ...NEUTRAL]]
    L.push({ s: 'beam', t0: 250, t1: 950, x0: hand.x, y0: hand.y, x1: c.x, y1: c.y, w: [4, 14], c: ['#ffe4e6', '#f43f5e', '#9f1239'], a: [1, 0], wobble: 2, grow: 160 })
    L.push({ s: 'glow', t0: 450, t1: 1000, x: c.x, y: c.y, r: [S.h * 0.5, 10], c: ['#ffe4e6', '#f43f5e', '#9f1239'], a: [0.8, 0] })
    L.push({ s: 'particles', t0: 450, t1: 1000, n: 22, seed, x: c.x, y: c.y, sx: 0, sy: 0, mode: 'converge', r: S.h * 0.6, life: 450, size: [8, 3], style: 'dot', c: ['#ffe4e6', '#f43f5e'] })
    SP.push({ who, k: 'tint', t0: 350, t1: 1000, color: '#f43f5e', a: 0.85 })
    SP.push({ who, k: 'grow', t0: 450, t1: 900, s0: 1, s1: 0 })
    SP.push({ who, k: 'hide', t0: 900, t1: 99999 })
    dur = 1500
  } else {
    // Desmaio: grito, desce do chão e some (como no jogo), a câmera chega perto.
    cam = [[0, ...NEUTRAL], [300, ...look(c, side === 0 ? 1.1 : 1.3, toward)], [1200, ...look(c, side === 0 ? 1.1 : 1.3, toward)], [1500, ...NEUTRAL]]
    SP.push({ who, k: 'move', t0: 300, t1: 1000, dx: 0, dy: S.h * 0.9, back: 0 })
    SP.push({ who, k: 'fade', t0: 300, t1: 1000, a0: 1, a1: 0 })
    SP.push({ who, k: 'tint', t0: 250, t1: 1000, color: '#1e1b4b', a: 0.5 })
    SP.push({ who, k: 'hide', t0: 1000, t1: 99999 })
    L.push({ s: 'particles', t0: 350, t1: 1100, n: 18, seed, x: S.x, y: S.y, sx: S.h * 0.4, sy: 6, v: 40, vy: -60, g: 0, life: 600, mode: 'stream', size: [14, 6], style: 'smoke', c: ['#94a3b8', '#64748b'] })
    shake.push([300, 500, 4])
    dur = 1550
  }
  // "from": o lado de quem é a cena (o A é ele).
  return { dur, cam, hud: [80, dur - 200], shake, sprites: SP, layers: L, contact: false, from: side, world: [stage.w, stage.h] }
}

/** Estilos que acontecem em quem usa o golpe (ou no campo), não no alvo. */
const SELF = new Set(['boost', 'dance', 'heal', 'shield', 'charge', 'weather', 'terrain', 'field', 'wall', 'explode', 'drop', 'status', 'powder', 'hazard', 'swap'])

/** Plano de um golpe pelo nome, tipo e categoria (os de status pelo alvo das regras). */
export function fxForMove({ slug, type, category, self = false, entry = null, recipe = null, from = 0, seed = 1, stage = FX_STAGE }) {
  const kind = entry?.[0] ?? (category === 'status' ? (self ? 'boost' : 'status') : moveAnim(slug, type, category))
  return fxPlan2({ kind, type, slug, from, seed, recipe, stage })
}

/** A câmera no instante [ms]: [x, y, zoom, giro], suave entre os pontos. */
export function fxCamera(plan, ms) {
  const [cx, cy, z, r] = fxCameraRaw(plan, ms)
  // Nunca mostra fora do cenário (com zoom, o meio fica longe das bordas).
  const [w, h] = plan.world ?? [960, 540]
  if (z < 1) return [cx, cy, z, r]
  const hw = w / 2 / z
  const hh = h / 2 / z
  return [clamp(cx, hw, w - hw), clamp(cy, hh, h - hh), z, r]
}

function fxCameraRaw(plan, ms) {
  const k = plan.cam
  if (!k.length) return NEUTRAL
  if (ms <= k[0][0]) return k[0].slice(1)
  for (let i = 0; i < k.length - 1; i++) {
    const p = k[i]
    const q = k[i + 1]
    if (ms <= q[0]) {
      const u = fxEase(clamp((ms - p[0]) / Math.max(1, q[0] - p[0])))
      return p.slice(1).map((v, j) => v + (q[j + 1] - v) * u)
    }
  }
  return k[k.length - 1].slice(1)
}

/** Suave no começo e no fim. */
export const fxEase = (k) => (k < 0.5 ? 2 * k * k : 1 - Math.pow(-2 * k + 2, 2) / 2)

/** O quanto a tela treme no instante [ms]: [dx, dy]. */
export function fxShake(plan, ms) {
  let amp = 0
  for (const [t0, t1, f] of plan.shake) if (ms >= t0 && ms <= t1) amp = Math.max(amp, f * (1 - (ms - t0) / (t1 - t0)))
  if (!amp) return [0, 0]
  const i = Math.floor(ms / 33)
  return [(fxRand(i) - 0.5) * 2 * amp, (fxRand(i + 99) - 0.5) * 2 * amp]
}

/** HP e caixa de texto: 1 visível, 0 escondido (some e volta em 150 ms). */
export function fxHud(plan, ms) {
  if (!plan.hud) return 1
  const [h0, h1] = plan.hud
  if (ms < h0) return 1
  if (ms < h0 + 150) return 1 - (ms - h0) / 150
  if (ms < h1) return 0
  return clamp((ms - h1) / 150)
}

/** Como fica cada sprite no instante [ms]: deslocamento, escala, cor por cima, silhueta branca e se aparece. */
export function fxSprite(plan, who, ms) {
  const out = { dx: 0, dy: 0, sx: 1, sy: 1, tint: null, tintA: 0, white: false, hidden: false, alpha: 1 }
  for (const e of plan.sprites) {
    if (e.who !== who) continue
    if (e.k === 'flash') {
      const k = ms - e.t0
      if (k >= 0 && k < e.n * 200) out.white = Math.floor(k / 100) % 2 === 0
      continue
    }
    if (ms < e.t0 || ms > e.t1) continue
    const k = (ms - e.t0) / Math.max(1, e.t1 - e.t0)
    if (e.k === 'tint') {
      const fade = Math.min(1, k * 6, (1 - k) * 4)
      const pulse = e.pulse ? 0.8 + 0.2 * Math.sin(ms / 1000 * e.pulse) : 1
      out.tint = e.color
      out.tintA = Math.max(out.tintA, e.a * fade * pulse)
    } else if (e.k === 'move') {
      // Vai e volta (back) ou só vai e volta sozinho no fim (recuo do golpe).
      const f = e.bounce ? Math.abs(Math.sin(k * Math.PI * e.bounce)) * (1 - k) : e.back === 0 ? fxEase(k) : Math.sin(k * Math.PI)
      out.dx += e.dx * f
      out.dy += e.dy * f
    } else if (e.k === 'hide') out.hidden = true
    else if (e.k === 'grow') {
      // Cresce (sai da Poké Ball) ou encolhe (volta para ela), a partir dos pés.
      const g = e.s0 + (e.s1 - e.s0) * fxEase(k)
      out.sx *= g
      out.sy *= g
    } else if (e.k === 'fade') out.alpha *= e.a0 + (e.a1 - e.a0) * k
    else if (e.k === 'silhouette') out.white = true
    else if (e.k === 'squash') {
      const f = Math.sin(k * Math.PI)
      out.sx *= 1 + (e.sx - 1) * f
      out.sy *= 1 + (e.sy - 1) * f
    }
  }
  return out
}
