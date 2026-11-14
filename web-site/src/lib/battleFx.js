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
export function fxPlan2({ kind, type, slug = '', from = 0, seed = 1, stage = FX_STAGE, recipe = null, boosts = null }) {
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
  // As bolas (carregando com swirl ou voando com trail) giram e ficam irregulares, como no Black & White.
  const add = (layer) => L.push(layer.s === 'glow' && (layer.swirl || layer.trail) && layer.spin == null ? { ...layer, spin: 1.3 * (from === 0 ? 1 : -1) } : layer)
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

  // Os socos elementais (Ice/Fire/Thunder Punch): o punho pega o elemento, avança, acerta e o efeito fica no alvo.
  const punch = (c, style, tint) => {
    cam = [[0, ...NEUTRAL], [250, ...look(a, 1.3, 2 * toward)], [550, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.1, 0)], [750, ...look(tc, 1.6, -3 * toward)], [1400, ...look(tc, 1.5, -2 * toward)]]
    add({ s: 'particles', t0: 150, t1: 650, n: 24, seed, x: front.x, y: front.y, sx: 0, sy: 0, mode: 'converge', r: 120, life: 400, size: [12, 5], style, c })
    add({ s: 'glow', t0: 200, t1: 700, x: front.x, y: front.y, r: [6, 44], c, a: 1 })
    S.push({ who: 'A', k: 'move', t0: 500, t1: 1250, dx: (tc.x - a.x) * 0.55, dy: (tc.y - a.y) * 0.55, back: 1 })
    add({ s: 'icon', t0: 620, t1: 950, x: tc.x, y: tc.y, size: [170, 90], a: [0.6, 1], style: 'fist', c, rot: -0.2 * toward })
    add({ s: 'particles', t0: 700, t1: 1500, n: 40, seed: seed + 2, x: tc.x, y: tc.y, sx: 30, sy: 30, v: 220, vy: style === 'flame' ? -200 : -60, g: style === 'crystal' ? 300 : 0, life: 600, mode: 'burst', size: [14, 6], style, c })
    hit(700, 1.25, tint)
    S.push({ who: 'T', k: 'tint', t0: 700, t1: 1500, color: tint, a: 0.55, pulse: style === 'spark' ? 45 : undefined })
    back(1350, 80)
    flashAfter(1950)
  }

  // As mordidas elementais (Thunder/Fire/Ice Fang): avança, as presas com o elemento fecham e o efeito fica no alvo.
  const fang = (c, style, tint) => {
    cam = [[0, ...NEUTRAL], [280, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.1, 0)], [550, ...look(tc, 1.6, -3 * toward)], [1300, ...look(tc, 1.5, -2 * toward)]]
    S.push({ who: 'A', k: 'move', t0: 80, t1: 1100, dx: (tc.x - a.x) * 0.5, dy: (tc.y - a.y) * 0.5, back: 1 })
    add({ s: 'fangs', t0: 420, t1: 950, x: tc.x, y: tc.y, r: 110, close: [0, 1], c: c[0], c2: c[2] })
    add({ s: 'glow', t0: 420, t1: 900, x: tc.x, y: tc.y, r: [40, 130], c, a: [0.5, 0] })
    add({ s: 'particles', t0: 650, t1: 1400, n: 36, seed: seed + 2, x: tc.x, y: tc.y, sx: 30, sy: 30, v: 220, vy: style === 'flame' ? -200 : -60, g: style === 'crystal' ? 300 : 0, life: 600, mode: 'burst', size: [14, 6], style, c })
    shake.push([650, 850, 9])
    hit(650, 1.25, tint)
    S.push({ who: 'T', k: 'tint', t0: 650, t1: 1400, color: tint, a: 0.55, pulse: style === 'spark' ? 45 : undefined })
    back(1300, 80)
    flashAfter(1900)
  }
  // As barreiras (Reflect, Light Screen): um painel de luz se ergue na frente do lado de quem usa e brilha.
  const wall = (c1w, c2w) => {
    const x = a.x + (tc.x - a.x) * 0.3
    const y = a.y + (tc.y - a.y) * 0.3
    cam = [[0, ...NEUTRAL], [400, ...look({ x, y }, 1.25, toward)], [1600, ...look({ x, y }, 1.3, toward)]]
    for (let i = 0; i < 5; i++) add({ s: 'beam', t0: 300 + i * 60, t1: 1700, x0: x - 140 + i * 70, y0: y + 120, x1: x - 140 + i * 70, y1: y - 160, w: [4, 8], c: ['#ffffff', c1w, c2w], a: [0.9, 0.2], grow: 300 })
    add({ s: 'glow', t0: 400, t1: 1700, x, y: y - 20, r: [40, 200], c: ['rgba(0,0,0,0)', c1w, c2w], a: [0.6, 0], core: 0.5 })
    add({ s: 'rays', t0: 800, t1: 1300, x: x + 60, y: y - 100, n: 4, r0: 0, r1: [10, 70], w: 4, c: '#ffffff', c2: c1w, a: [1, 0], rot: 0.4 })
    hud = [100, 1700]
    cam.push([2000, ...NEUTRAL])
    end(2100)
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
      add({ s: 'glow', t0: 1500, t1: 2550, x: sky.x, y: sky.y, r: [10, 105], c: [c0, c1, c2, c3], a: 1, core: 0.25, spin: 1.1 * toward })
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
      // Como no BW: a água sobe aos pés de quem ataca, a onda em pixels cresce atrás dele, enrola, quebra por cima do
      // alvo e atravessa a tela; depois escoa e o alvo fica pingando.
      const wide = [(a.x + tc.x) / 2, (a.y + tc.y) / 2 + 10, 0.95, -toward]
      cam = [[0, ...NEUTRAL], [450, ...wide], [1750, ...wide], [2100, ...look(tc, 1.35, -2 * toward)]]
      add({ s: 'tint', t0: 150, t1: 2500, color: '#06235c', a: [0, 0.32] })
      add({ s: 'ring', t0: 150, t1: 800, x: a.x, y: a.y, r: [20, A.h * 0.7], ratio: 0.28, w: [8, 2], c: '#bfe8ff', a: [1, 0], n: 3, stagger: 1 })
      add({ s: 'particles', t0: 150, t1: 900, n: 36, seed, x: a.x, y: a.y, sx: A.h * 0.5, sy: 8, v: 30, vy: -300, g: 500, life: 550, mode: 'stream', size: [8, 4], style: 'droplet', c: ['#ffffff', '#bfe8ff', '#5cc8ff'] })
      add({ s: 'surge', t0: 350, t1: 2350, dir: toward, c: ['#f4fdff', '#7fd6ff', '#2a86e0', '#0d3f99'], a: 0.93 })
      add({ s: 'particles', t0: 1250, t1: 2000, n: 46, seed: seed + 2, x: tc.x, y: tc.y, sx: 30, sy: 30, v: 260, vy: -220, g: 700, life: 650, mode: 'burst', size: [10, 4], style: 'droplet', c: ['#ffffff', '#bfe8ff', '#5cc8ff'] })
      add({ s: 'particles', t0: 1450, t1: 2400, n: 26, seed: seed + 4, x: tc.x, y: T.y, sx: T.h * 0.6, sy: 20, v: 20, vy: -160, g: -40, life: 800, mode: 'stream', size: [12, 6], style: 'bubble', c: ['#ffffff', '#bfe8ff'] })
      add({ s: 'particles', t0: 2050, t1: 2800, n: 22, seed: seed + 6, x: tc.x, y: tc.y - T.h * 0.2, sx: T.h * 0.35, sy: T.h * 0.25, v: 0, vy: 40, g: 600, life: 500, mode: 'stream', size: [7, 4], style: 'droplet', c: ['#ffffff', '#9edcff'] })
      hit(1250, 1.25, '#5cc8ff')
      S.push({ who: 'T', k: 'tint', t0: 1250, t1: 2700, color: '#4aa8ff', a: 0.55 })
      S.push({ who: 'A', k: 'tint', t0: 200, t1: 900, color: '#7fd6ff', a: 0.4 })
      back(2650, 60)
      flashAfter(3200)
    },
    earthquake: () => {
      // Como no BW: a câmera desce para o chão, o campo inteiro balança para os lados, o chão racha embaixo do alvo,
      // nuvens de poeira rolam pelo chão, pedras pulam e os dois Pokémon quicam.
      const ground = [(a.x + tc.x) / 2, (a.y + tc.y) / 2 + 40, 0.92, 0]
      cam = [[0, ...NEUTRAL], [350, ...ground], [2050, ground[0], ground[1], 0.96, 0]]
      shake.push([300, 2150, 30, 1])
      add({ s: 'tint', t0: 250, t1: 2350, color: '#2a1606', a: [0, 0.22] })
      add({ s: 'crack', t0: 450, t1: 2250, x: tc.x, y: T.y, r: [30, 380], n: 9, c: '#2b1b08', c2: '#e0b866', a: [1, 0] })
      add({ s: 'crack', t0: 950, t1: 2250, x: tc.x + 60 * toward, y: T.y + 10, r: [20, 220], n: 6, c: '#2b1b08', c2: '#c9974a', a: [1, 0] })
      for (const [y, w, sd] of [[T.y, 320, 0], [a.y, 380, 7], [(a.y + T.y) / 2, 420, 13]])
        add({ s: 'particles', t0: 350, t1: 2250, n: 30, seed: seed + sd, x: tc.x * 0.5 + a.x * 0.5, y, sx: w, sy: 8, v: 90, vy: -110, g: 160, life: 900, mode: 'stream', size: [18, 8], style: 'dust', c: ['#d9b47a', '#a8742e', '#6b4a1c'] })
      for (const t of [500, 1000, 1500])
        add({ s: 'particles', t0: t, t1: t + 900, n: 9, seed: seed + t, x: tc.x, y: T.y, sx: 140, sy: 6, v: 60, vy: -520, g: 1300, life: 750, mode: 'burst', size: [18, 12], style: 'shard', c: ['#d6b98a', '#9b7c4f', '#6b4f2a'] })
      add({ s: 'particles', t0: 400, t1: 2100, n: 60, seed: seed + 3, x: tc.x, y: T.y, sx: 260, sy: 8, v: 40, vy: -260, g: 600, life: 700, mode: 'stream', size: [8, 3], style: 'dust', c: ['#e0b866', '#a8742e'] })
      S.push({ who: 'T', k: 'move', t0: 450, t1: 1950, dx: 0, dy: -38, bounce: 6 })
      S.push({ who: 'A', k: 'move', t0: 350, t1: 1800, dx: 0, dy: -14, bounce: 6 })
      hit(700, 1.3, '#a8742e')
      impactBurst(1300, 0.9, { x: tc.x, y: T.y - 20 })
      S.push({ who: 'T', k: 'tint', t0: 700, t1: 2150, color: '#8a5a20', a: 0.5 })
      back(2150, 0)
      flashAfter(2650)
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
      // Como no BW: espadas aparecem uma a uma girando em volta de quem usa (uma por estágio de Ataque: +2 são duas,
      // +6 são seis), se juntam no alto, brilham e o ataque sobe.
      const n = Math.max(1, Math.min(6, boosts?.atk ?? 2))
      const mid = { x: a.x, y: A.y - A.h * 0.55 }
      cam = [[0, ...NEUTRAL], [400, ...look(mid, 1.45, 2 * toward)], [2000, ...look(mid, 1.5, 2 * toward)]]
      add({ s: 'swords', t0: 250, t1: 2000, x: mid.x, y: mid.y, rx: Math.max(80, A.h * 0.66), ry: Math.max(18, A.h * 0.16), n, size: Math.max(40, A.h * 0.42), spin: 0.75 * toward, top: A.y - A.h * 1.12, c: ['#ffffff', '#c9d6e3', '#6b7a8c', '#ef4444', '#facc15'] })
      add({ s: 'rays', t0: 1650, t1: 2150, x: a.x, y: A.y - A.h * 1.12, n: 12, r0: 10, r1: [40, 180], w: 5, c: '#ffffff', c2: '#ef4444', a: [1, 0], rot: 0.2 })
      add({ s: 'glow', t0: 1650, t1: 2050, x: a.x, y: A.y - A.h * 1.12, r: [10, 90], c: ['#ffffff', '#ffe0e0', '#ef4444'], a: [1, 0] })
      add({ s: 'particles', t0: 1700, t1: 2300, n: 10, seed: seed + 4, x: a.x, y: A.y - A.h * 0.3, sx: A.h * 0.35, sy: 20, v: 0, vy: -220, g: 0, life: 600, mode: 'stream', size: [18, 14], style: 'arrowUp', c: ['#ffffff', '#fca5a5', '#ef4444'] })
      S.push({ who: 'A', k: 'tint', t0: 1650, t1: 2300, color: '#ef4444', a: 0.5, pulse: 18 })
      hud = [100, 2300]
      cam.push([2600, ...NEUTRAL])
      end(2700)
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
    // ---- Lote 2, feitos à mão como no Black & White ----
    'brave-bird': () => {
      // Envolto em fogo azul, sobe, mergulha no alvo deixando penas e sente o tranco depois.
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.3, 2 * toward)], [700, ...look({ x: a.x, y: a.y - 120 }, 1.15, 3 * toward)], [950, ...look(tc, 1.6, -3 * toward)], [1600, ...look(tc, 1.45, -2 * toward)]]
      S.push({ who: 'A', k: 'tint', t0: 150, t1: 1100, color: '#7cc4ff', a: 0.6, pulse: 24 })
      add({ s: 'glow', t0: 150, t1: 750, x: a.x, y: a.y, r: [20, A.h * 0.7], c: ['rgba(0,0,0,0)', '#bfe3ff', '#3b82f6'], a: [0.4, 0.9], core: 0.55 })
      S.push({ who: 'A', k: 'move', t0: 300, t1: 700, dx: 0, dy: -110, back: 0 })
      S.push({ who: 'A', k: 'move', t0: 700, t1: 1500, dx: (tc.x - a.x) * 0.6, dy: (tc.y - a.y) * 0.6 + 110, back: 1 })
      add({ s: 'particles', t0: 700, t1: 1100, n: 40, seed, x: [a.x, tc.x], y: [a.y - 110, tc.y], sx: 30, sy: 30, v: 40, vy: 0, g: 0, life: 320, mode: 'trail', size: [16, 4], style: 'streak', c: ['#ffffff', '#bfe3ff', '#3b82f6'] })
      add({ s: 'particles', t0: 950, t1: 1800, n: 18, seed: seed + 3, x: tc.x, y: tc.y, sx: 30, sy: 30, v: 160, vy: -120, g: 160, life: 900, mode: 'burst', size: [16, 10], style: 'feather', c: ['#ffffff', '#dbeafe', '#93c5fd'] })
      hit(950, 1.4, '#3b82f6')
      S.push({ who: 'A', k: 'flash', t0: 1600, n: 1 })
      S.push({ who: 'A', k: 'move', t0: 1600, t1: 1800, dx: -10 * toward, dy: 0 })
      back(1550, 100)
      flashAfter(2150)
    },
    'flare-blitz': () => {
      // Pega fogo do corpo inteiro, avança como uma bola de chamas, explode no alvo e sente o tranco.
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.35, 2 * toward)], [800, ...look(a, 1.3, 2 * toward)], [1000, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.05, 0)], [1150, ...look(tc, 1.55, -3 * toward)]]
      S.push({ who: 'A', k: 'tint', t0: 200, t1: 1300, color: '#ff4a0a', a: 0.7, pulse: 26 })
      add({ s: 'particles', t0: 200, t1: 1200, n: 90, seed, x: a.x, y: A.y, sx: A.h * 0.4, sy: 10, v: 30, vy: -340, g: -60, life: 600, mode: 'stream', size: [22, 6], style: 'flame', c: ['#fff7c2', '#ffb02e', '#ff6a12', '#d6200f'] })
      S.push({ who: 'A', k: 'move', t0: 850, t1: 1600, dx: (tc.x - a.x) * 0.6, dy: (tc.y - a.y) * 0.6, back: 1 })
      add({ s: 'glow', t0: 850, t1: 1150, x: [a.x, tc.x], y: [a.y, tc.y], r: [A.h * 0.5, 90], c: ['#fff7c2', '#ffb02e', '#e5391a', '#7a1406'], a: 0.8, trail: 1, spin: 0 })
      add({ s: 'fill', t0: 1150, t1: 1900, c: ['#fff7c2', '#ffb02e', '#ff6a12', '#d6200f'], from: 'center', a: 0.75 })
      add({ s: 'glow', t0: 1150, t1: 1800, x: tc.x, y: tc.y, r: [60, 240], c: ['#fffbe0', '#ff8a2a', '#d6200f'], a: [1, 0] })
      hit(1150, 1.5, '#ff4a0a')
      S.push({ who: 'T', k: 'tint', t0: 1150, t1: 2000, color: '#ff4a0a', a: 0.6, pulse: 22 })
      S.push({ who: 'A', k: 'flash', t0: 2050, n: 1 })
      back(1950, 60)
      flashAfter(2500)
    },
    outrage: () => {
      // Fica vermelho de raiva, a tela pulsa e ele ataca três vezes sem controle.
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.4, 3 * toward)], [800, ...look(a, 1.45, -3 * toward)], [1050, ...look(tc, 1.55, -3 * toward)], [1900, ...look(tc, 1.5, 3 * toward)]]
      S.push({ who: 'A', k: 'tint', t0: 200, t1: 2000, color: '#e11d48', a: 0.6, pulse: 30 })
      add({ s: 'tint', t0: 200, t1: 2000, color: '#5b0010', a: [0, 0.35] })
      add({ s: 'particles', t0: 250, t1: 950, n: 40, seed, x: a.x, y: A.y, sx: A.h * 0.45, sy: 10, v: 20, vy: -300, g: -40, life: 600, mode: 'stream', size: [18, 6], style: 'flame', c: ['#fecdd3', '#e11d48', '#5a4ae0'] })
      shake.push([300, 900, 4])
      S.push({ who: 'A', k: 'move', t0: 900, t1: 1950, dx: (tc.x - a.x) * 0.55, dy: (tc.y - a.y) * 0.55, back: 1 })
      for (let i = 0; i < 3; i++) {
        const t = 1050 + i * 260
        add({ s: 'arc', t0: t - 60, t1: t + 260, x: tc.x + (i - 1) * 30, y: tc.y + (i - 1) * 20, r: 110, a0: i % 2 ? 0.6 : -2.4, a1: i % 2 ? [0.6, -2.4] : [-2.4, 0.6], w: 12, c: '#ffe4e6', c2: '#e11d48', flip: toward > 0 ? 0 : 1 })
        impactBurst(t, 1)
        shake.push([t, t + 160, 9])
        S.push({ who: 'T', k: 'move', t0: t, t1: t + 160, dx: 14 * toward, dy: -4 })
      }
      hit(1570, 1.35, '#e11d48')
      back(1950, 100)
      flashAfter(2550)
    },
    'iron-head': () => {
      // A cabeça fica de metal brilhando, avança e dá uma cabeçada com estrela e brilho prateado.
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.4, 2 * toward)], [700, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.1, 0)], [900, ...look(tc, 1.65, -3 * toward)], [1500, ...look(tc, 1.5, -2 * toward)]]
      S.push({ who: 'A', k: 'tint', t0: 200, t1: 1100, color: '#cbd5e1', a: 0.6, pulse: 20 })
      add({ s: 'rays', t0: 250, t1: 700, x: mouth.x, y: mouth.y - 20, n: 6, r0: 4, r1: [20, 70], w: 4, c: '#ffffff', c2: '#94a3b8', a: [1, 0], rot: [0, 1] })
      S.push({ who: 'A', k: 'move', t0: 650, t1: 1400, dx: (tc.x - a.x) * 0.6, dy: (tc.y - a.y) * 0.6, back: 1 })
      add({ s: 'icon', t0: 850, t1: 1150, x: tc.x, y: tc.y, size: [160, 90], a: [0.6, 1], style: 'head', c: ['#ffffff', '#e2e8f0', '#64748b'], rot: 0 })
      add({ s: 'rays', t0: 900, t1: 1300, x: tc.x, y: tc.y, n: 14, r0: 20, r1: [60, 200], w: 6, c: '#ffffff', c2: '#94a3b8', a: [1, 0], rot: [0, 0.4] })
      add({ s: 'particles', t0: 900, t1: 1500, n: 20, seed, x: tc.x, y: tc.y, sx: 20, sy: 20, v: 240, vy: -60, g: 100, life: 500, mode: 'burst', size: [10, 4], style: 'glint', c: ['#ffffff', '#e2e8f0'] })
      hit(900, 1.35, '#94a3b8')
      back(1400, 120)
      flashAfter(2000)
    },
    'play-rough': () => {
      // Uma nuvem de briga rosa no alvo: socos, chutes, corações e estrelas saindo para todo lado.
      cam = [[0, ...NEUTRAL], [300, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.1, 0)], [550, ...look(tc, 1.55, -2 * toward)], [1800, ...look(tc, 1.5, 2 * toward)]]
      S.push({ who: 'A', k: 'move', t0: 80, t1: 1900, dx: (tc.x - a.x) * 0.5, dy: (tc.y - a.y) * 0.5, back: 1 })
      S.push({ who: 'A', k: 'hide', t0: 500, t1: 1600 })
      add({ s: 'particles', t0: 450, t1: 1750, n: 24, seed, x: tc.x, y: tc.y, sx: T.h * 0.4, sy: T.h * 0.3, v: 30, vy: -20, g: 0, life: 500, mode: 'stream', size: [30, 14], style: 'dust', c: ['#fff1f8', '#fbcfe8', '#f9a8d4'] })
      for (let i = 0; i < 7; i++) {
        const t = 550 + i * 150
        const ox = (rnd(i) - 0.5) * 160
        const oy = (rnd(i + 3) - 0.5) * 120
        add({ s: 'icon', t0: t, t1: t + 200, x: tc.x + ox, y: tc.y + oy, size: [30, 70], a: [1, 0], style: ['fist', 'foot', 'star', 'heart'][i % 4], c: ['#ffffff', '#fbcfe8', '#ec4899'], rot: (rnd(i + 7) - 0.5) * 1.2 })
        shake.push([t, t + 90, 5])
      }
      add({ s: 'particles', t0: 600, t1: 1700, n: 20, seed: seed + 2, x: tc.x, y: tc.y, sx: 40, sy: 40, v: 220, vy: -80, g: 100, life: 600, mode: 'stream', size: [14, 6], style: 'star', c: ['#ffffff', '#fbcfe8', '#ec4899'] })
      hit(1500, 1.25, '#ec4899')
      back(1900, 60)
      flashAfter(2450)
    },
    waterfall: () => {
      // Uma coluna de água sobe com ele, avança subindo pela corrente e a água desaba em cima do alvo.
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.3, 2 * toward)], [800, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 - 60 }, 1.05, 0)], [1050, ...look(tc, 1.5, -3 * toward)]]
      add({ s: 'particles', t0: 200, t1: 900, n: 120, seed, x: a.x, y: A.y, sx: A.h * 0.35, sy: 8, v: 10, vy: -520, g: 200, life: 600, mode: 'stream', size: [12, 22], style: 'droplet', c: ['#ffffff', '#bfe8ff', '#5cc8ff', '#1f6fd6'] })
      S.push({ who: 'A', k: 'tint', t0: 200, t1: 1100, color: '#5cc8ff', a: 0.45 })
      S.push({ who: 'A', k: 'move', t0: 700, t1: 1500, dx: (tc.x - a.x) * 0.55, dy: (tc.y - a.y) * 0.55 - 40, back: 1 })
      add({ s: 'particles', t0: 950, t1: 1700, n: 120, seed: seed + 2, x: tc.x, y: tc.y - T.h * 0.9, sx: T.h * 0.4, sy: 10, v: 0, vy: 520, g: 600, life: 450, mode: 'stream', size: [12, 22], style: 'droplet', c: ['#ffffff', '#bfe8ff', '#5cc8ff', '#1f6fd6'] })
      add({ s: 'particles', t0: 1050, t1: 1800, n: 40, seed: seed + 4, x: tc.x, y: T.y, sx: T.h * 0.5, sy: 6, v: 160, vy: -200, g: 600, life: 500, mode: 'stream', size: [9, 4], style: 'droplet', c: ['#ffffff', '#5cc8ff'] })
      hit(1000, 1.3, '#1f6fd6')
      back(1750, 60)
      flashAfter(2300)
    },
    crunch: () => {
      // A tela escurece, uma mandíbula enorme fecha duas vezes no alvo e racha.
      cam = [[0, ...NEUTRAL], [300, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.1, 0)], [550, ...look(tc, 1.6, -3 * toward)], [1400, ...look(tc, 1.5, -2 * toward)]]
      add({ s: 'tint', t0: 200, t1: 1500, color: '#0b0614', a: [0, 0.5] })
      S.push({ who: 'A', k: 'move', t0: 80, t1: 1000, dx: (tc.x - a.x) * 0.5, dy: (tc.y - a.y) * 0.5, back: 1 })
      for (let i = 0; i < 2; i++) {
        const t = 550 + i * 380
        add({ s: 'fangs', t0: t - 160, t1: t + 280, x: tc.x, y: tc.y, r: 120 - i * 10, close: [0, 1], c: '#ffffff', c2: '#3d2f55' })
        add({ s: 'rays', t0: t, t1: t + 220, x: tc.x, y: tc.y, n: 10, r0: 20, r1: [50, 150], w: 6, c: '#ffffff', c2: '#6d28d9', a: [1, 0], rot: rnd(i) })
        shake.push([t, t + 180, 10])
      }
      add({ s: 'crack', t0: 950, t1: 1500, x: tc.x, y: tc.y + 30, r: [10, 120], n: 7, c: '#1a0f2a', c2: '#a78bfa', a: [1, 0] })
      hit(930, 1.3, '#3d2f55')
      back(1400, 120)
      flashAfter(2000)
    },
    'drain-punch': () => {
      // Soco com energia verde; a vida do alvo volta em bolinhas para quem bateu.
      cam = [[0, ...NEUTRAL], [300, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.1, 0)], [520, ...look(tc, 1.6, -3 * toward)], [1000, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.1, 0)], [1900, ...look(a, 1.35, 2 * toward)]]
      S.push({ who: 'A', k: 'move', t0: 80, t1: 900, dx: (tc.x - a.x) * 0.55, dy: (tc.y - a.y) * 0.55, back: 1 })
      add({ s: 'icon', t0: 420, t1: 760, x: tc.x, y: tc.y, size: [170, 90], a: [0.6, 1], style: 'fist', c: ['#f0ffe6', '#86efac', '#16a34a'], rot: -0.2 * toward })
      hit(520, 1.2, '#16a34a')
      add({ s: 'particles', t0: 800, t1: 1800, n: 22, seed, x: [tc.x, a.x], y: [tc.y, a.y], sx: 50, sy: 40, mode: 'travel', life: 700, size: [12, 12], style: 'dot', c: ['#ffffff', '#bbf7d0', '#22c55e'] })
      add({ s: 'glow', t0: 1400, t1: 2100, x: a.x, y: a.y, r: [30, A.h * 0.7], c: ['#ffffff', '#bbf7d0', '#22c55e'], a: [0.6, 0] })
      S.push({ who: 'A', k: 'tint', t0: 1400, t1: 2100, color: '#4ade80', a: 0.45, pulse: 10 })
      back(2100, 0)
      flashAfter(2700)
    },
    'giga-drain': () => {
      // Raízes de luz envolvem o alvo, muitas bolinhas verdes saem dele e voam até quem usou, que brilha.
      cam = [[0, ...NEUTRAL], [350, ...look(tc, 1.4, -2 * toward)], [1100, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.0, 0)], [2000, ...look(a, 1.35, 2 * toward)]]
      add({ s: 'ring', t0: 250, t1: 1100, x: tc.x, y: tc.y, r: [T.h * 0.7, 30], ratio: 0.9, w: [3, 8], c: '#86efac', a: [0.3, 1], n: 3, stagger: 1 })
      S.push({ who: 'T', k: 'tint', t0: 400, t1: 1200, color: '#22c55e', a: 0.5, pulse: 14 })
      hit(700, 1.0, '#16a34a')
      add({ s: 'particles', t0: 900, t1: 2000, n: 46, seed, x: [tc.x, a.x], y: [tc.y, a.y], sx: 70, sy: 60, mode: 'travel', life: 800, size: [10, 10], style: 'dot', c: ['#ffffff', '#bbf7d0', '#22c55e'] })
      add({ s: 'particles', t0: 1500, t1: 2300, n: 26, seed: seed + 3, x: a.x, y: A.y, sx: A.h * 0.4, sy: 10, v: 0, vy: -200, g: 0, life: 700, mode: 'stream', size: [10, 4], style: 'star', c: ['#ffffff', '#bbf7d0'] })
      S.push({ who: 'A', k: 'tint', t0: 1600, t1: 2300, color: '#4ade80', a: 0.45, pulse: 10 })
      back(2300, 0)
      flashAfter(2800)
    },
    scald: () => {
      // Um jato de água fervendo sai da boca e solta vapor no alvo, que fica vermelho de queimadura.
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.3, 2 * toward)], [700, ...look({ x: a.x * 0.4 + tc.x * 0.6, y: a.y * 0.4 + tc.y * 0.6 }, 1.1, -toward)], [1400, ...look(tc, 1.45, -2 * toward)]]
      add({ s: 'glow', t0: 200, t1: 1500, x: mouth.x, y: mouth.y, r: [6, 36], c: ['#ffffff', '#ffd2c2', '#5cc8ff'], a: [1, 0.7] })
      add({ s: 'particles', t0: 450, t1: 1500, n: 140, seed, x: [mouth.x, tc.x], y: [mouth.y, tc.y], sx: 6, sy: 6, spread: 24, mode: 'jet', life: 360, size: [12, 22], style: 'droplet', c: ['#ffffff', '#ffe4dc', '#7fd6ff', '#2a86e0'] })
      add({ s: 'particles', t0: 800, t1: 2000, n: 34, seed: seed + 3, x: tc.x, y: tc.y, sx: T.h * 0.4, sy: T.h * 0.3, v: 20, vy: -140, g: -30, life: 900, mode: 'stream', size: [34, 14], style: 'smoke', c: ['#ffffff', '#f1f5f9', '#e2e8f0'] })
      hit(800, 1.15, '#2a86e0')
      S.push({ who: 'T', k: 'tint', t0: 900, t1: 1900, color: '#ff5a1a', a: 0.45, pulse: 18 })
      back(1850, 60)
      flashAfter(2400)
    },
    'dark-pulse': () => {
      // Tudo escurece e ondas de energia sombria em anéis saem dele, cruzam o campo e acertam o alvo.
      cam = [[0, ...NEUTRAL], [350, ...look(a, 1.3, 2 * toward)], [800, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 0.98, 0)], [1500, ...look(tc, 1.45, -2 * toward)]]
      add({ s: 'tint', t0: 150, t1: 1900, color: '#06020c', a: [0, 0.6] })
      S.push({ who: 'A', k: 'tint', t0: 250, t1: 1200, color: '#4c1d95', a: 0.5, pulse: 16 })
      add({ s: 'ring', t0: 300, t1: 900, x: a.x, y: a.y, r: [20, A.h * 0.8], ratio: 1, w: [12, 2], c: '#a78bfa', a: [1, 0], n: 3, stagger: 1 })
      add({ s: 'ring', t0: 700, t1: 1500, x: [front.x, tc.x], y: [front.y, tc.y], r: [40, 120], ratio: 0.9, w: [14, 4], c: '#2e1065', a: [1, 0.5], n: 6, stagger: 1 })
      add({ s: 'ring', t0: 720, t1: 1520, x: [front.x, tc.x], y: [front.y, tc.y], r: [36, 112], ratio: 0.9, w: [4, 2], c: '#c4b5fd', a: [1, 0.4], n: 6, stagger: 1 })
      add({ s: 'particles', t0: 1200, t1: 1900, n: 26, seed, x: tc.x, y: tc.y, sx: 20, sy: 20, v: 200, vy: -40, g: 0, life: 600, mode: 'burst', size: [16, 6], style: 'wisp', c: ['#c4b5fd', '#6d28d9', '#1e0b3a'] })
      hit(1200, 1.25, '#4c1d95')
      back(1800, 60)
      flashAfter(2350)
    },
    'aura-sphere': () => {
      // A aura azul se junta nas mãos, vira uma esfera girando, voa reto e estoura em raios azuis.
      const o = { x: front.x + 40 * toward, y: (mouth.y + front.y) / 2 }
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.35, 2 * toward)], [1000, ...look(a, 1.4, 2 * toward)], [1200, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.0, 0)], [1400, ...look(tc, 1.5, -2 * toward)]]
      S.push({ who: 'A', k: 'tint', t0: 200, t1: 1050, color: '#60a5fa', a: 0.45, pulse: 18 })
      add({ s: 'particles', t0: 200, t1: 1000, n: 40, seed, x: o.x, y: o.y, sx: 0, sy: 0, mode: 'converge', r: 200, life: 500, size: [16, 5], style: 'streak', c: ['#ffffff', '#bfdbfe', '#3b82f6'] })
      add({ s: 'glow', t0: 300, t1: 1050, x: o.x, y: o.y, r: [6, 54], c: ['#ffffff', '#bfdbfe', '#3b82f6', '#1e3a8a'], a: 1, core: 0.3, swirl: 1 })
      add({ s: 'glow', t0: 1050, t1: 1330, x: [o.x, tc.x], y: [o.y, tc.y], r: [54, 66], c: ['#ffffff', '#bfdbfe', '#3b82f6', '#1e3a8a'], a: 1, core: 0.3, swirl: 1, trail: 1 })
      add({ s: 'rays', t0: 1330, t1: 1800, x: tc.x, y: tc.y, n: 14, r0: 20, r1: [60, 210], w: 7, c: '#ffffff', c2: '#3b82f6', a: [1, 0], rot: [0, 0.5] })
      add({ s: 'ring', t0: 1330, t1: 1800, x: tc.x, y: tc.y, r: [30, 170], ratio: 1, w: [12, 2], c: '#bfdbfe', a: [1, 0], n: 2, stagger: 1 })
      hit(1330, 1.25, '#3b82f6')
      back(1450, 300)
      flashAfter(2400)
    },
    'focus-blast': () => {
      // Concentra com o corpo tremendo, a esfera laranja cresce bem grande, voa e explode forte.
      const o = { x: front.x + 60 * toward, y: (mouth.y + front.y) / 2 }
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.35, 2 * toward)], [1300, ...look(a, 1.45, 3 * toward)], [1500, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.0, 0)], [1700, ...look(tc, 1.5, -2 * toward)]]
      S.push({ who: 'A', k: 'tint', t0: 200, t1: 1350, color: '#fb923c', a: 0.45, pulse: 24 })
      S.push({ who: 'A', k: 'move', t0: 300, t1: 1300, dx: 3, dy: 0, bounce: 14 })
      add({ s: 'particles', t0: 250, t1: 1300, n: 50, seed, x: o.x, y: o.y, sx: 0, sy: 0, mode: 'converge', r: 240, life: 600, size: [12, 4], style: 'streak', c: ['#ffffff', '#fed7aa', '#f97316'] })
      add({ s: 'glow', t0: 300, t1: 1350, x: o.x, y: o.y, r: [6, 80], c: ['#ffffff', '#fed7aa', '#f97316', '#9a3412'], a: 1, core: 0.25, swirl: 1 })
      add({ s: 'glow', t0: 1350, t1: 1650, x: [o.x, tc.x], y: [o.y, tc.y], r: [80, 90], c: ['#ffffff', '#fed7aa', '#f97316', '#9a3412'], a: 1, core: 0.25, swirl: 1, trail: 1 })
      add({ s: 'tint', t0: 1650, t1: 1780, color: '#fff7ed', a: [0.9, 0] })
      add({ s: 'glow', t0: 1650, t1: 2300, x: tc.x, y: tc.y, r: [80, 260], c: ['#ffffff', '#fdba74', '#ea580c'], a: [1, 0] })
      add({ s: 'rays', t0: 1650, t1: 2200, x: tc.x, y: tc.y, n: 16, r0: 30, r1: [80, 280], w: 8, c: '#ffffff', c2: '#f97316', a: [1, 0], rot: [0, 0.6] })
      shake.push([1650, 2300, 14])
      hit(1650, 1.5, '#ea580c')
      back(2250, 60)
      flashAfter(2800)
    },
    'air-slash': () => {
      // Três lâminas de ar em meia-lua voam em sequência e cortam o alvo.
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.25, 2 * toward)], [650, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.0, 0)], [900, ...look(tc, 1.5, -3 * toward)]]
      for (let i = 0; i < 3; i++) {
        const t = 350 + i * 160
        const dy = (i - 1) * 40
        add({ s: 'shot', t0: t, t1: t + 420, x: [front.x, tc.x], y: [front.y + dy, tc.y + dy], r: 34, c: ['#ffffff', '#e0f2fe', '#7dd3fc', '#0c4a6e'], style: 'moon', spin: 0 })
        add({ s: 'particles', t0: t, t1: t + 450, n: 12, seed: seed + i, x: [front.x, tc.x], y: [front.y + dy, tc.y + dy], sx: 10, sy: 10, v: 20, vy: 0, g: 0, life: 220, mode: 'trail', size: [18, 3], style: 'streak', c: ['#ffffff', '#e0f2fe'] })
        add({ s: 'arc', t0: t + 420, t1: t + 700, x: tc.x, y: tc.y + dy, r: 90, a0: -2.2, a1: [-2.2, 0.9], w: 8, c: '#ffffff', c2: '#7dd3fc', flip: i % 2 })
        shake.push([t + 420, t + 520, 6])
      }
      hit(770, 1.2, '#7dd3fc')
      back(1450, 80)
      flashAfter(2000)
    },
    'bug-buzz': () => {
      // As asas vibram e ondas de som verdes, tremidas, saem dele e chacoalham o alvo.
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.35, 2 * toward)], [700, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.0, 0)], [1300, ...look(tc, 1.45, -2 * toward)]]
      S.push({ who: 'A', k: 'move', t0: 200, t1: 1600, dx: 3, dy: 0, bounce: 24 })
      add({ s: 'ring', t0: 300, t1: 1600, x: [mouth.x, tc.x], y: [mouth.y, tc.y], r: [20, 110], ratio: 0.75, w: [8, 3], c: '#bef264', a: [1, 0.3], n: 8, stagger: 1 })
      add({ s: 'ring', t0: 340, t1: 1640, x: [mouth.x, tc.x], y: [mouth.y, tc.y], r: [16, 100], ratio: 0.75, w: [3, 2], c: '#ef4444', a: [0.8, 0.2], n: 8, stagger: 1 })
      add({ s: 'particles', t0: 400, t1: 1500, n: 12, seed, x: [mouth.x, tc.x], y: [mouth.y, tc.y], sx: 60, sy: 50, mode: 'travel', life: 700, size: [16, 12], style: 'note', c: ['#ffffff', '#bef264', '#65a30d'] })
      S.push({ who: 'T', k: 'move', t0: 1000, t1: 1700, dx: 7, dy: 0, bounce: 14 })
      hit(1050, 1.15, '#65a30d')
      back(1750, 60)
      flashAfter(2300)
    },
    'power-gem': () => {
      // Pedras preciosas brilham na frente dele e um raio de luz de cristais vai até o alvo.
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.35, 2 * toward)], [850, ...look(a, 1.35, 2 * toward)], [1050, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.0, 0)], [1300, ...look(tc, 1.45, -2 * toward)]]
      for (let i = 0; i < 5; i++) add({ s: 'icon', t0: 250 + i * 80, t1: 1000, x: front.x + Math.cos(i * 1.26) * 60, y: front.y + Math.sin(i * 1.26) * 50, size: [6, 22], a: [0.4, 1], style: 'crystal', c: ['#ffffff', ['#fde68a', '#f9a8d4', '#a5f3fc', '#bbf7d0', '#c4b5fd'][i], '#78350f'], rot: i })
      add({ s: 'glow', t0: 600, t1: 1050, x: front.x, y: front.y, r: [10, 60], c: ['#ffffff', '#fde68a', '#d97706'], a: 1 })
      add({ s: 'beam', t0: 950, t1: 1700, x0: front.x, y0: front.y, x1: tc.x, y1: tc.y, w: [10, 30], c: ['#ffffff', '#fef3c7', '#f59e0b'], a: [1, 0], wobble: 2, grow: 130 })
      add({ s: 'particles', t0: 1000, t1: 1700, n: 40, seed, x: [front.x, tc.x], y: [front.y, tc.y], sx: 24, sy: 24, v: 40, vy: 0, g: 0, life: 300, mode: 'trail', size: [10, 4], style: 'crystal', c: ['#ffffff', '#fde68a', '#f9a8d4', '#a5f3fc'] })
      add({ s: 'particles', t0: 1100, t1: 1900, n: 26, seed: seed + 3, x: tc.x, y: tc.y, sx: 0, sy: 0, mode: 'burst', v: 220, vy: -40, g: 300, life: 700, size: [14, 8], style: 'crystal', c: ['#ffffff', '#fde68a', '#f9a8d4', '#a5f3fc'] })
      hit(1100, 1.2, '#d97706')
      back(1750, 80)
      flashAfter(2300)
    },
    'earth-power': () => {
      // O chão embaixo do alvo brilha laranja, racha e explode numa coluna de terra e fogo da terra.
      cam = [[0, ...NEUTRAL], [350, ...look({ x: tc.x, y: T.y - 40 }, 1.35, -2 * toward)], [1500, ...look({ x: tc.x, y: tc.y - 30 }, 1.4, -3 * toward)]]
      add({ s: 'tint', t0: 200, t1: 1900, color: '#1c0d02', a: [0, 0.35] })
      add({ s: 'glow', t0: 300, t1: 1000, x: tc.x, y: T.y, r: [10, T.h * 0.7], c: ['#fff7c2', '#fb923c', '#7c2d12'], a: [0.3, 1], core: 0.3 })
      add({ s: 'crack', t0: 400, t1: 1800, x: tc.x, y: T.y, r: [20, 220], n: 8, c: '#3b1a05', c2: '#fb923c', a: [1, 0] })
      shake.push([400, 900, 4])
      add({ s: 'particles', t0: 900, t1: 1700, n: 120, seed, x: tc.x, y: T.y, sx: T.h * 0.3, sy: 6, v: 30, vy: -620, g: 400, life: 700, mode: 'stream', size: [16, 6], style: 'dust', c: ['#fde68a', '#fb923c', '#a16207', '#7c2d12'] })
      add({ s: 'particles', t0: 950, t1: 1700, n: 30, seed: seed + 2, x: tc.x, y: T.y, sx: T.h * 0.3, sy: 6, v: 80, vy: -540, g: 1000, life: 800, mode: 'stream', size: [16, 12], style: 'shard', c: ['#d6b98a', '#9b7c4f'] })
      shake.push([900, 1500, 11])
      hit(950, 1.3, '#c2410c')
      back(1800, 60)
      flashAfter(2350)
    },
    'ice-punch': () => {
      // O punho congela, acerta e o alvo fica coberto de gelo com cristais estourando.
      punch(['#ffffff', '#c8f6ff', '#6cc9f0'], 'crystal', '#9ee8ff')
    },
    'fire-punch': () => {
      // O punho pega fogo, acerta e as chamas sobem no alvo.
      punch(['#fff7c2', '#ffb02e', '#e5391a'], 'flame', '#ff4a0a')
    },
    'thunder-punch': () => {
      // O punho solta faíscas, acerta e o alvo fica cheio de raios.
      punch(['#ffffff', '#ffe94a', '#d4a106'], 'spark', '#ffe94a')
      add({ s: 'bolt', t0: 650, t1: 1300, x: tc.x, y: tc.y, r: 120, n: 6, c: '#ffffff', c2: '#ffe94a', w: 3, flicker: 1 })
    },
    'extreme-speed': () => {
      // Some de vista; riscos de velocidade cruzam a tela, o alvo leva vários golpes e ele aparece de volta.
      cam = [[0, ...NEUTRAL], [250, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.05, 0)], [450, ...look(tc, 1.5, -3 * toward)], [1100, ...look(tc, 1.5, 3 * toward)]]
      S.push({ who: 'A', k: 'hide', t0: 200, t1: 1200 })
      add({ s: 'particles', t0: 150, t1: 350, n: 10, seed, x: a.x, y: a.y, sx: 30, sy: A.h * 0.3, v: 900 * toward, vy: 0, g: 0, life: 200, mode: 'stream', size: [60, 4], style: 'streak', c: ['#ffffff', '#fef3c7'] })
      for (let i = 0; i < 4; i++) {
        const t = 450 + i * 150
        const ang = rnd(i) * Math.PI
        add({ s: 'beam', t0: t, t1: t + 140, x0: tc.x - Math.cos(ang) * 260, y0: tc.y - Math.sin(ang) * 180, x1: tc.x + Math.cos(ang) * 260, y1: tc.y + Math.sin(ang) * 180, w: [4, 10], c: ['#ffffff', '#fef9c3', '#facc15'], a: [1, 0], grow: 80 })
        add({ s: 'rays', t0: t + 40, t1: t + 200, x: tc.x + (rnd(i + 5) - 0.5) * 80, y: tc.y + (rnd(i + 9) - 0.5) * 80, n: 8, r0: 10, r1: [30, 90], w: 4, c: '#ffffff', c2: '#facc15', a: [1, 0], rot: ang })
        shake.push([t + 40, t + 120, 6])
        S.push({ who: 'T', k: 'move', t0: t + 40, t1: t + 160, dx: (i % 2 ? -10 : 10), dy: -4 })
      }
      hit(1000, 1.25, '#facc15')
      back(1150, 100)
      flashAfter(1750)
    },
    'sucker-punch': () => {
      // Some numa sombra e aparece atrás do alvo dando um soco escuro antes que ele reaja.
      cam = [[0, ...NEUTRAL], [250, ...look(tc, 1.5, -2 * toward)], [900, ...look(tc, 1.55, -3 * toward)]]
      add({ s: 'tint', t0: 150, t1: 1100, color: '#06020c', a: [0, 0.45] })
      S.push({ who: 'A', k: 'fade', t0: 100, t1: 300, a0: 1, a1: 0 })
      S.push({ who: 'A', k: 'hide', t0: 300, t1: 1000 })
      add({ s: 'particles', t0: 100, t1: 450, n: 20, seed, x: a.x, y: a.y, sx: A.h * 0.3, sy: A.h * 0.3, v: 30, vy: -60, g: 0, life: 350, mode: 'stream', size: [22, 8], style: 'wisp', c: ['#6b5b8a', '#2e1d40'] })
      add({ s: 'particles', t0: 350, t1: 650, n: 16, seed: seed + 2, x: tc.x + 70 * toward, y: tc.y, sx: 0, sy: 0, mode: 'converge', r: 120, life: 300, size: [20, 8], style: 'wisp', c: ['#6b5b8a', '#2e1d40'] })
      add({ s: 'icon', t0: 550, t1: 850, x: tc.x + 30 * toward, y: tc.y, size: [180, 100], a: [0.6, 1], style: 'fist', c: ['#c4b5fd', '#4c1d95', '#1e0b3a'], rot: Math.PI * (toward > 0 ? 1 : 0) })
      add({ s: 'rays', t0: 650, t1: 950, x: tc.x, y: tc.y, n: 10, r0: 10, r1: [40, 140], w: 6, c: '#ffffff', c2: '#4c1d95', a: [1, 0], rot: 0.3 })
      S.push({ who: 'T', k: 'move', t0: 650, t1: 1000, dx: -18 * toward, dy: -4 })
      hit(650, 1.2, '#3d2f55')
      S.push({ who: 'A', k: 'fade', t0: 1000, t1: 1200, a0: 0, a1: 1 })
      back(1050, 100)
      flashAfter(1650)
    },
    'bullet-punch': () => {
      // Socos de metal rapidíssimos, um atrás do outro, com brilho prateado.
      cam = [[0, ...NEUTRAL], [220, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.1, 0)], [400, ...look(tc, 1.6, -3 * toward)], [950, ...look(tc, 1.55, -2 * toward)]]
      S.push({ who: 'A', k: 'tint', t0: 100, t1: 1000, color: '#cbd5e1', a: 0.5 })
      S.push({ who: 'A', k: 'move', t0: 50, t1: 1050, dx: (tc.x - a.x) * 0.6, dy: (tc.y - a.y) * 0.6, back: 1 })
      for (let i = 0; i < 4; i++) {
        const t = 400 + i * 110
        const ox = (rnd(i) - 0.5) * 70
        const oy = (rnd(i + 3) - 0.5) * 70
        add({ s: 'icon', t0: t - 60, t1: t + 120, x: tc.x + ox, y: tc.y + oy, size: [130, 70], a: [0.6, 1], style: 'fist', c: ['#ffffff', '#e2e8f0', '#64748b'], rot: (rnd(i + 7) - 0.5) * 0.6 })
        add({ s: 'rays', t0: t, t1: t + 150, x: tc.x + ox, y: tc.y + oy, n: 6, r0: 8, r1: [24, 70], w: 4, c: '#ffffff', c2: '#94a3b8', a: [1, 0], rot: rnd(i) })
        shake.push([t, t + 80, 5])
      }
      hit(800, 1.15, '#94a3b8')
      back(1050, 100)
      flashAfter(1650)
    },
    'aqua-jet': () => {
      // Fica coberto de água e dispara como um jato, deixando gotas no caminho.
      cam = [[0, ...NEUTRAL], [250, ...look(a, 1.3, 2 * toward)], [550, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.05, 0)], [700, ...look(tc, 1.55, -3 * toward)]]
      S.push({ who: 'A', k: 'tint', t0: 150, t1: 1000, color: '#5cc8ff', a: 0.55 })
      add({ s: 'ring', t0: 150, t1: 600, x: a.x, y: a.y, r: [A.h * 0.6, A.h * 0.4], ratio: 1, w: [4, 10], c: '#bfe8ff', a: [0.4, 1], n: 2, stagger: 1 })
      S.push({ who: 'A', k: 'move', t0: 500, t1: 1200, dx: (tc.x - a.x) * 0.65, dy: (tc.y - a.y) * 0.65, back: 1 })
      add({ s: 'particles', t0: 500, t1: 850, n: 60, seed, x: [a.x, tc.x], y: [a.y, tc.y], sx: 30, sy: 30, v: 60, vy: -40, g: 400, life: 350, mode: 'trail', size: [10, 4], style: 'droplet', c: ['#ffffff', '#bfe8ff', '#5cc8ff'] })
      add({ s: 'particles', t0: 700, t1: 1300, n: 36, seed: seed + 2, x: tc.x, y: tc.y, sx: 20, sy: 20, v: 260, vy: -180, g: 700, life: 600, mode: 'burst', size: [10, 4], style: 'droplet', c: ['#ffffff', '#5cc8ff'] })
      hit(700, 1.15, '#1f6fd6')
      back(1200, 60)
      flashAfter(1750)
    },
    'nasty-plot': () => {
      // A tela escurece, ele fica roxo, interrogações e pensamentos maldosos giram na cabeça e o Ataque Especial sobe.
      const head = { x: a.x, y: A.y - A.h * 0.95 }
      cam = [[0, ...NEUTRAL], [400, ...look({ x: a.x, y: A.y - A.h * 0.6 }, 1.45, 2 * toward)], [1700, ...look({ x: a.x, y: A.y - A.h * 0.6 }, 1.5, 2 * toward)]]
      add({ s: 'tint', t0: 200, t1: 1900, color: '#0a0414', a: [0, 0.55] })
      S.push({ who: 'A', k: 'tint', t0: 300, t1: 1900, color: '#7c3aed', a: 0.5, pulse: 8 })
      add({ s: 'particles', t0: 350, t1: 1600, n: 6, seed, x: head.x, y: head.y, sx: 0, sy: 0, mode: 'orbit', r: A.h * 0.35, life: 1200, size: [16, 16], style: 'wisp', c: ['#ddd6fe', '#7c3aed', '#2e1065'] })
      add({ s: 'ring', t0: 400, t1: 1500, x: head.x, y: head.y, r: [A.h * 0.5, 20], ratio: 0.4, w: [2, 6], c: '#c4b5fd', a: [0.2, 1], n: 3, spiral: 3 })
      add({ s: 'glow', t0: 1300, t1: 1800, x: head.x, y: head.y, r: [10, 70], c: ['#ffffff', '#ddd6fe', '#7c3aed'], a: [1, 0] })
      add({ s: 'particles', t0: 1300, t1: 2000, n: 12, seed: seed + 4, x: a.x, y: A.y - A.h * 0.3, sx: A.h * 0.35, sy: 20, v: 0, vy: -220, g: 0, life: 600, mode: 'stream', size: [18, 14], style: 'arrowUp', c: ['#ffffff', '#ddd6fe', '#7c3aed'] })
      hud = [100, 2000]
      cam.push([2300, ...NEUTRAL])
      end(2400)
    },
    'calm-mind': () => {
      // Fecha os olhos: anéis rosados descem calmos em volta dele, a mente brilha e Atq. e Def. Especial sobem.
      cam = [[0, ...NEUTRAL], [450, ...look(a, 1.4, 2 * toward)], [1800, ...look(a, 1.45, 2 * toward)]]
      add({ s: 'tint', t0: 200, t1: 1900, color: '#2a0a2a', a: [0, 0.3] })
      add({ s: 'ring', t0: 300, t1: 1500, x: a.x, y: [A.y - A.h * 1.1, A.y], r: [A.h * 0.5, A.h * 0.4], ratio: 0.28, w: [6, 2], c: '#fbcfe8', a: [1, 0], n: 4, stagger: 1 })
      add({ s: 'glow', t0: 500, t1: 1600, x: a.x, y: A.y - A.h * 0.85, r: [10, A.h * 0.3], c: ['#ffffff', '#fbcfe8', '#ec4899'], a: [0.1, 0.45], core: 0.3 })
      S.push({ who: 'A', k: 'tint', t0: 600, t1: 1800, color: '#f9a8d4', a: 0.45, pulse: 6 })
      add({ s: 'particles', t0: 1300, t1: 2000, n: 12, seed: seed + 4, x: a.x, y: A.y - A.h * 0.3, sx: A.h * 0.35, sy: 20, v: 0, vy: -200, g: 0, life: 650, mode: 'stream', size: [18, 14], style: 'arrowUp', c: ['#ffffff', '#fbcfe8', '#ec4899'] })
      hud = [100, 2000]
      cam.push([2300, ...NEUTRAL])
      end(2400)
    },
    spikes: () => {
      // Joga três espinhos em arco que caem e ficam fincados no chão do outro lado.
      cam = [[0, ...NEUTRAL], [350, ...look({ x: (a.x + tc.x) / 2, y: (a.y + T.y) / 2 - 40 }, 1.05, 0)], [1100, ...look({ x: tc.x + (a.x - tc.x) * 0.3, y: Math.min(T.y + (A.y - T.y) * 0.3, stage.h * 0.66) - 40 }, 1.3, -toward)], [1900, ...look({ x: tc.x + (a.x - tc.x) * 0.3, y: Math.min(T.y + (A.y - T.y) * 0.3, stage.h * 0.66) - 40 }, 1.3, -toward)]]
      // No chão na frente do alvo, acima da caixa de texto (o seu Pokémon fica com os pés bem embaixo).
      const gy = Math.min(T.y + (A.y - T.y) * 0.3, stage.h * 0.66)
      const gx = tc.x + (a.x - tc.x) * 0.3
      for (let i = 0; i < 3; i++) {
        const tx = gx + (i - 1) * 70
        add({ s: 'shot', t0: 250 + i * 150, t1: 950 + i * 150, x: [front.x, tx], y: [front.y, gy], r: 26, c: ['#ffffff', '#cbd5e1', '#64748b'], style: 'shard', arc: 200, spin: 2 * toward })
        add({ s: 'particles', t0: 950 + i * 150, t1: 1250 + i * 150, n: 8, seed: seed + i, x: tx, y: gy, sx: 10, sy: 4, v: 80, vy: -160, g: 600, life: 300, mode: 'burst', size: [8, 4], style: 'dust', c: ['#d6b98a', '#9b7c4f'] })
        add({ s: 'icon', t0: 950 + i * 150, t1: 2100, x: tx, y: gy - 4, size: 30, a: 1, style: 'shard', c: ['#ffffff', '#cbd5e1', '#475569'], rot: 0 })
      }
      hud = [100, 2100]
      cam.push([2400, ...NEUTRAL])
      end(2500)
    },
    roost: () => {
      // Pousa no chão (desce um pouco), penas caem em volta e a luz verde o cura.
      cam = [[0, ...NEUTRAL], [400, ...look(a, 1.35, 2 * toward)], [1700, ...look(a, 1.4, 2 * toward)]]
      S.push({ who: 'A', k: 'move', t0: 200, t1: 1700, dx: 0, dy: 26, back: 1 })
      add({ s: 'particles', t0: 300, t1: 1600, n: 16, seed, x: a.x, y: A.y - A.h * 1.1, sx: A.h * 0.6, sy: 10, v: 20, vy: 60, g: 40, life: 1200, mode: 'stream', size: [16, 10], style: 'feather', c: ['#ffffff', '#f5f5f4', '#d6d3d1'] })
      add({ s: 'glow', t0: 700, t1: 1700, x: a.x, y: a.y, r: [40, A.h * 0.8], c: ['#ffffff', '#b8ffcf', '#4ade80'], a: [0.7, 0] })
      add({ s: 'particles', t0: 800, t1: 1700, n: 26, seed: seed + 2, x: a.x, y: A.y, sx: A.h * 0.45, sy: 10, v: 0, vy: -220, g: 0, life: 700, mode: 'stream', size: [12, 4], style: 'star', c: ['#ffffff', '#d9fbe8', '#4ade80'] })
      S.push({ who: 'A', k: 'tint', t0: 800, t1: 1700, color: '#4ade80', a: 0.4, pulse: 10 })
      hud = [100, 1800]
      cam.push([2100, ...NEUTRAL])
      end(2200)
    },
    'rain-dance': () => {
      // O céu fecha com nuvens escuras e cai uma chuva forte em todo o campo.
      cam = [[0, ...NEUTRAL], [400, stage.w / 2, stage.h / 2 - 30, 0.95, 0], [2200, stage.w / 2, stage.h / 2 - 30, 0.97, 0]]
      add({ s: 'tint', t0: 150, t1: 2500, color: '#0b1a33', a: [0, 0.5] })
      add({ s: 'particles', t0: 200, t1: 1200, n: 14, seed, x: stage.w / 2, y: 40, sx: stage.w * 0.55, sy: 30, v: 10, vy: 0, g: 0, life: 1400, mode: 'stream', size: [80, 30], style: 'smoke', c: ['#64748b', '#475569', '#334155'] })
      add({ s: 'particles', t0: 500, t1: 2400, n: 260, seed: seed + 2, x: stage.w / 2, y: -20, sx: stage.w * 0.65, sy: 20, v: 0, vy: 900, g: 0, life: 700, mode: 'stream', size: [16, 3], style: 'rain', c: ['#e0f2fe', '#93c5fd'] })
      add({ s: 'particles', t0: 900, t1: 2400, n: 40, seed: seed + 4, x: stage.w / 2, y: Math.max(a.y, T.y), sx: stage.w * 0.5, sy: 60, v: 40, vy: -60, g: 300, life: 300, mode: 'stream', size: [5, 3], style: 'droplet', c: ['#ffffff', '#bfdbfe'] })
      hud = [100, 2400]
      cam.push([2700, ...NEUTRAL])
      end(2800)
    },
    'sunny-day': () => {
      // A tela clareia, um sol forte aparece no alto com raios girando e o campo fica dourado.
      const sun = { x: stage.w / 2, y: 60 }
      cam = [[0, ...NEUTRAL], [450, stage.w / 2, stage.h / 2 - 50, 0.95, 0], [2100, stage.w / 2, stage.h / 2 - 40, 0.97, 0]]
      add({ s: 'tint', t0: 200, t1: 2400, color: '#fbbf24', a: [0, 0.22] })
      add({ s: 'rays', t0: 300, t1: 2300, x: sun.x, y: sun.y, n: 16, r0: 40, r1: [60, 520], w: [4, 12], c: '#fffbeb', c2: '#fbbf24', a: [0.2, 0.9], rot: [0, 1] })
      add({ s: 'glow', t0: 300, t1: 2300, x: sun.x, y: sun.y, r: [20, 110], c: ['#ffffff', '#fef3c7', '#f59e0b'], a: [0.4, 1], core: 0.3 })
      add({ s: 'icon', t0: 400, t1: 2300, x: sun.x, y: sun.y, size: [20, 60], a: [0.4, 1], style: 'sun', c: ['#ffffff', '#fde68a', '#f59e0b'] })
      add({ s: 'particles', t0: 600, t1: 2300, n: 40, seed, x: stage.w / 2, y: stage.h / 2, sx: stage.w * 0.5, sy: stage.h * 0.4, v: 10, vy: -30, g: 0, life: 900, mode: 'stream', size: [6, 3], style: 'glint', c: ['#ffffff', '#fde68a'] })
      hud = [100, 2300]
      cam.push([2600, ...NEUTRAL])
      end(2700)
    },
    // ---- Lote 3, feitos à mão como no Black & White ----
    'hyper-beam': () => {
      // Energia laranja se junta na boca, a tela escurece e sai um raio enorme que explode no alvo.
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.4, 2 * toward)], [1100, ...look(a, 1.45, 2 * toward)], [1300, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 0.98, 0)], [1600, ...look(tc, 1.4, -2 * toward)]]
      add({ s: 'tint', t0: 200, t1: 2300, color: '#120600', a: [0, 0.55] })
      add({ s: 'particles', t0: 250, t1: 1150, n: 44, seed, x: mouth.x, y: mouth.y, sx: 0, sy: 0, mode: 'converge', r: 240, life: 500, size: [14, 4], style: 'streak', c: ['#ffffff', '#fde68a', '#f97316'] })
      add({ s: 'glow', t0: 300, t1: 1200, x: mouth.x, y: mouth.y, r: [6, 70], c: ['#ffffff', '#fde68a', '#f97316', '#9a3412'], a: 1, core: 0.3, swirl: 1, spin: 0 })
      add({ s: 'beam', t0: 1150, t1: 2150, x0: mouth.x, y0: mouth.y, x1: tc.x, y1: tc.y, w: [26, 70], c: ['#ffffff', '#fde68a', '#f97316'], a: [1, 0], wobble: 5, grow: 150 })
      add({ s: 'tint', t0: 1300, t1: 1450, color: '#fff7ed', a: [0.9, 0] })
      add({ s: 'glow', t0: 1300, t1: 2200, x: tc.x, y: tc.y, r: [80, 280], c: ['#ffffff', '#fdba74', '#ea580c'], a: [1, 0] })
      add({ s: 'rays', t0: 1300, t1: 2100, x: tc.x, y: tc.y, n: 16, r0: 30, r1: [80, 300], w: 9, c: '#ffffff', c2: '#f97316', a: [1, 0], rot: [0, 0.6] })
      shake.push([1300, 2100, 14])
      hit(1300, 1.5, '#ea580c')
      S.push({ who: 'T', k: 'tint', t0: 1300, t1: 2200, color: '#f97316', a: 0.6, pulse: 30 })
      back(2200, 60)
      flashAfter(2750)
    },
    'giga-impact': () => {
      // Envolto numa aura roxa e dourada, ele dispara como um cometa, a tela vira um estouro e o alvo voa.
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.4, 2 * toward)], [900, ...look(a, 1.45, 3 * toward)], [1050, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.0, 0)], [1200, ...look(tc, 1.65, -4 * toward)]]
      S.push({ who: 'A', k: 'tint', t0: 200, t1: 1300, color: '#a855f7', a: 0.6, pulse: 24 })
      add({ s: 'glow', t0: 200, t1: 1000, x: a.x, y: a.y, r: [20, A.h * 0.8], c: ['rgba(0,0,0,0)', '#fde68a', '#a855f7'], a: [0.3, 1], core: 0.55 })
      add({ s: 'particles', t0: 250, t1: 1000, n: 60, seed, x: a.x, y: A.y, sx: A.h * 0.45, sy: 10, v: 20, vy: -360, g: -60, life: 600, mode: 'stream', size: [14, 4], style: 'streak', c: ['#ffffff', '#fde68a', '#a855f7'] })
      S.push({ who: 'A', k: 'move', t0: 950, t1: 1800, dx: (tc.x - a.x) * 0.65, dy: (tc.y - a.y) * 0.65, back: 1 })
      add({ s: 'glow', t0: 950, t1: 1200, x: [a.x, tc.x], y: [a.y, tc.y], r: [A.h * 0.5, 120], c: ['#ffffff', '#fde68a', '#a855f7', '#3b0764'], a: 0.75, trail: 1, spin: 0 })
      add({ s: 'fill', t0: 1200, t1: 1900, c: ['#ffffff', '#fde68a', '#c084fc', '#7e22ce'], from: 'center', a: 0.8 })
      shake.push([1200, 1900, 16])
      hit(1200, 1.6, '#a855f7')
      S.push({ who: 'T', k: 'move', t0: 1200, t1: 1800, dx: 40 * toward, dy: -20, back: 1 })
      back(1900, 100)
      flashAfter(2500)
    },
    'solar-beam': () => {
      // A luz do sol desce e se junta nele, o corpo brilha dourado e sai um raio de luz verde-amarelo.
      cam = [[0, ...NEUTRAL], [400, ...look({ x: a.x, y: a.y - 80 }, 1.25, 2 * toward)], [1300, ...look(a, 1.4, 2 * toward)], [1500, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.0, 0)], [1750, ...look(tc, 1.45, -2 * toward)]]
      add({ s: 'tint', t0: 150, t1: 1400, color: '#fef3c7', a: [0, 0.25] })
      add({ s: 'rays', t0: 200, t1: 1400, x: a.x, y: -40, n: 9, r0: 0, r1: [60, 520], w: [6, 16], c: '#fffbeb', c2: '#fde047', a: [0.3, 0.9], rot: [Math.PI * 0.35, Math.PI * 0.65] })
      add({ s: 'particles', t0: 300, t1: 1300, n: 50, seed, x: a.x, y: a.y, sx: 0, sy: 0, mode: 'converge', r: 260, life: 600, size: [6, 10], style: 'glint', c: ['#ffffff', '#fef08a', '#a3e635'] })
      S.push({ who: 'A', k: 'tint', t0: 600, t1: 1400, color: '#fde047', a: 0.6, pulse: 14 })
      add({ s: 'glow', t0: 1000, t1: 1400, x: mouth.x, y: mouth.y, r: [10, 60], c: ['#ffffff', '#fef08a', '#84cc16'], a: 1 })
      add({ s: 'beam', t0: 1350, t1: 2300, x0: mouth.x, y0: mouth.y, x1: tc.x, y1: tc.y, w: [20, 56], c: ['#ffffff', '#fef08a', '#84cc16'], a: [1, 0], wobble: 4, grow: 150 })
      add({ s: 'rays', t0: 1500, t1: 2200, x: tc.x, y: tc.y, n: 14, r0: 30, r1: [70, 240], w: 7, c: '#ffffff', c2: '#a3e635', a: [1, 0], rot: [0, 0.5] })
      add({ s: 'particles', t0: 1500, t1: 2300, n: 40, seed: seed + 2, x: tc.x, y: tc.y, sx: 30, sy: 30, v: 220, vy: -60, g: 0, life: 600, mode: 'burst', size: [8, 4], style: 'glint', c: ['#ffffff', '#fef08a'] })
      hit(1500, 1.45, '#84cc16')
      back(2350, 60)
      flashAfter(2900)
    },
    blizzard: () => {
      // A tela fica branca de neve, um vento gelado em diagonal cobre o campo e o alvo congela.
      cam = [[0, ...NEUTRAL], [400, stage.w / 2, stage.h / 2, 0.95, -toward], [1800, ...look(tc, 1.35, -2 * toward)]]
      add({ s: 'tint', t0: 200, t1: 2200, color: '#dbeafe', a: [0, 0.4] })
      add({ s: 'particles', t0: 300, t1: 2000, n: 260, seed, x: stage.w / 2 - 300 * toward, y: stage.h / 2 - 100, sx: stage.w * 0.4, sy: stage.h * 0.4, v: 700 * toward, vy: 260, g: 0, life: 700, mode: 'stream', size: [10, 4], style: 'crystal', c: ['#ffffff', '#e0f2fe', '#bae6fd'] })
      add({ s: 'particles', t0: 300, t1: 2000, n: 120, seed: seed + 2, x: stage.w / 2 - 300 * toward, y: stage.h / 2 - 100, sx: stage.w * 0.4, sy: stage.h * 0.4, v: 900 * toward, vy: 300, g: 0, life: 500, mode: 'stream', size: [30, 3], style: 'streak', c: ['#ffffff', '#e0f2fe'] })
      add({ s: 'particles', t0: 1000, t1: 2100, n: 20, seed: seed + 4, x: tc.x, y: tc.y, sx: 0, sy: 0, mode: 'burst', v: 160, vy: 40, g: 200, life: 700, size: [18, 10], style: 'crystal', c: ['#ffffff', '#c8f6ff', '#6cc9f0'] })
      hit(1000, 1.3, '#9ee8ff')
      S.push({ who: 'T', k: 'tint', t0: 1000, t1: 2200, color: '#bfeeff', a: 0.7 })
      back(2200, 60)
      flashAfter(2750)
    },
    'heat-wave': () => {
      // O ar ferve: ondas de calor laranja saem dele e varrem o campo, a imagem treme de calor.
      cam = [[0, ...NEUTRAL], [350, ...look(a, 1.3, 2 * toward)], [800, stage.w / 2, stage.h / 2, 0.95, 0], [1800, ...look(tc, 1.35, -2 * toward)]]
      add({ s: 'tint', t0: 200, t1: 2100, color: '#7c2d12', a: [0, 0.35] })
      S.push({ who: 'A', k: 'tint', t0: 200, t1: 900, color: '#ff6a12', a: 0.5, pulse: 20 })
      add({ s: 'ring', t0: 400, t1: 1700, x: [front.x, tc.x], y: [front.y, tc.y], r: [40, 220], ratio: 0.5, w: [18, 4], c: '#fdba74', a: [0.9, 0.2], n: 5, stagger: 1 })
      add({ s: 'particles', t0: 500, t1: 1800, n: 120, seed, x: [front.x, tc.x], y: [front.y, tc.y], sx: 160, sy: 120, mode: 'travel', life: 700, size: [18, 6], style: 'ember', c: ['#fff7c2', '#ffb02e', '#e5391a'] })
      S.push({ who: 'T', k: 'move', t0: 1000, t1: 1900, dx: 4, dy: 0, bounce: 18 })
      hit(1100, 1.2, '#ff5a1a')
      S.push({ who: 'T', k: 'tint', t0: 1100, t1: 1900, color: '#ff4a0a', a: 0.55, pulse: 22 })
      back(1900, 60)
      flashAfter(2450)
    },
    overheat: () => {
      // Esquenta até ficar branco, explode num jorro de fogo enorme e depois fica cansado e cinza.
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.45, 2 * toward)], [1100, ...look(a, 1.5, 3 * toward)], [1300, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.0, 0)], [1500, ...look(tc, 1.45, -2 * toward)]]
      S.push({ who: 'A', k: 'tint', t0: 200, t1: 1200, color: '#ffedd5', a: 0.8, pulse: 30 })
      add({ s: 'glow', t0: 200, t1: 1200, x: a.x, y: a.y, r: [20, A.h], c: ['#ffffff', '#fde68a', '#ef4444', '#7f1d1d'], a: [0.3, 0.9], core: 0.2 })
      add({ s: 'particles', t0: 200, t1: 1200, n: 80, seed, x: a.x, y: A.y, sx: A.h * 0.5, sy: 10, v: 30, vy: -380, g: -60, life: 600, mode: 'stream', size: [22, 6], style: 'flame', c: ['#ffffff', '#fde68a', '#ff6a12', '#d6200f'] })
      add({ s: 'particles', t0: 1150, t1: 2000, n: 240, seed: seed + 2, x: [mouth.x, tc.x], y: [mouth.y, tc.y], sx: 10, sy: 10, spread: 60, mode: 'jet', life: 420, size: [20, 44], style: 'flame', c: ['#ffffff', '#fde68a', '#ff6a12', '#d6200f'] })
      add({ s: 'fill', t0: 1350, t1: 2100, c: ['#fff7c2', '#ffb02e', '#ff6a12', '#d6200f'], from: toward > 0 ? 'left' : 'right', a: 0.7 })
      shake.push([1350, 2000, 12])
      hit(1350, 1.5, '#ff4a0a')
      S.push({ who: 'A', k: 'tint', t0: 2050, t1: 2600, color: '#57534e', a: 0.5 })
      back(2200, 60)
      flashAfter(2750)
    },
    'wild-charge': () => {
      // Cheio de eletricidade, avança soltando raios, bate forte e toma um choque de volta.
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.35, 2 * toward)], [700, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.05, 0)], [900, ...look(tc, 1.6, -3 * toward)]]
      S.push({ who: 'A', k: 'tint', t0: 150, t1: 1300, color: '#ffe94a', a: 0.6, pulse: 40 })
      add({ s: 'bolt', t0: 150, t1: 1300, x: a.x, y: a.y, r: A.h * 0.6, n: 7, c: '#ffffff', c2: '#ffe94a', w: 3, flicker: 1 })
      S.push({ who: 'A', k: 'move', t0: 650, t1: 1400, dx: (tc.x - a.x) * 0.6, dy: (tc.y - a.y) * 0.6, back: 1 })
      add({ s: 'particles', t0: 650, t1: 1000, n: 40, seed, x: [a.x, tc.x], y: [a.y, tc.y], sx: 30, sy: 30, v: 40, vy: 0, g: 0, life: 260, mode: 'trail', size: [9, 3], style: 'spark', c: ['#ffffff', '#ffe94a'] })
      add({ s: 'bolt', t0: 900, t1: 1500, x: tc.x, y: tc.y, r: 150, n: 9, c: '#ffffff', c2: '#ffe94a', w: 4, flicker: 1 })
      add({ s: 'tint', t0: 900, t1: 1000, color: '#ffffff', a: [0.8, 0] })
      hit(900, 1.4, '#ffe94a')
      S.push({ who: 'A', k: 'flash', t0: 1600, n: 1 })
      back(1450, 100)
      flashAfter(2000)
    },
    'volt-switch': () => {
      // Uma bola elétrica sai rodando, acerta o alvo e ele volta correndo para a Poké Ball.
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.3, 2 * toward)], [700, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.0, 0)], [950, ...look(tc, 1.5, -2 * toward)], [1500, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.0, 0)]]
      add({ s: 'glow', t0: 200, t1: 650, x: front.x, y: front.y, r: [6, 40], c: ['#ffffff', '#ffe94a', '#ca8a04'], a: 1, swirl: 1 })
      add({ s: 'glow', t0: 650, t1: 950, x: [front.x, tc.x], y: [front.y, tc.y], r: [40, 50], c: ['#ffffff', '#ffe94a', '#ca8a04'], a: 1, swirl: 1, trail: 1 })
      add({ s: 'bolt', t0: 950, t1: 1500, x: tc.x, y: tc.y, r: 120, n: 7, c: '#ffffff', c2: '#ffe94a', w: 3, flicker: 1 })
      hit(950, 1.2, '#ffe94a')
      add({ s: 'particles', t0: 1200, t1: 1600, n: 30, seed, x: [tc.x, a.x], y: [tc.y, a.y], sx: 20, sy: 20, v: 40, vy: 0, g: 0, life: 260, mode: 'trail', size: [9, 3], style: 'spark', c: ['#ffffff', '#ffe94a'] })
      back(1500, 60)
      flashAfter(2050)
    },
    discharge: () => {
      // Solta eletricidade para todo lado: raios saem do corpo e acertam tudo em volta.
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.35, 2 * toward)], [800, stage.w / 2, stage.h / 2, 0.95, 0], [1700, ...look(tc, 1.35, -2 * toward)]]
      add({ s: 'tint', t0: 200, t1: 1900, color: '#05040f', a: [0, 0.5] })
      S.push({ who: 'A', k: 'tint', t0: 200, t1: 1700, color: '#ffe94a', a: 0.6, pulse: 40 })
      add({ s: 'bolt', t0: 300, t1: 1700, x: a.x, y: a.y, r: A.h * 1.2, n: 10, c: '#ffffff', c2: '#ffe94a', w: 4, flicker: 1 })
      add({ s: 'ring', t0: 600, t1: 1600, x: a.x, y: a.y, r: [40, 520], ratio: 0.6, w: [10, 2], c: '#fef08a', a: [1, 0], n: 3, stagger: 1 })
      for (let i = 0; i < 3; i++) add({ s: 'bolt', t0: 800 + i * 200, t1: 1100 + i * 200, x: tc.x, y: tc.y, r: 0, from: mouth, n: 10, c: '#ffffff', c2: '#ffd400', w: 5, flicker: 1 })
      hit(850, 1.25, '#ffe94a')
      S.push({ who: 'T', k: 'tint', t0: 850, t1: 1700, color: '#ffe94a', a: 0.55, pulse: 45 })
      back(1750, 60)
      flashAfter(2300)
    },
    'rock-slide': () => {
      // Pedras grandes aparecem no alto e despencam sobre o alvo uma atrás da outra.
      cam = [[0, ...NEUTRAL], [400, ...look({ x: tc.x, y: tc.y - 120 }, 1.2, -toward)], [1100, ...look(tc, 1.4, -2 * toward)]]
      for (let i = 0; i < 6; i++) {
        const t = 400 + i * 140
        const dx = (rnd(i) - 0.5) * 220
        add({ s: 'shot', t0: t, t1: t + 380, x: [tc.x + dx * 1.2, tc.x + dx * 0.5], y: [tc.y - 360, T.y - 30 - rnd(i + 4) * 60], r: 34 + rnd(i + 2) * 16, c: ['#e7d3ae', '#b89a6a', '#7a6040'], style: 'shard', spin: rnd(i) - 0.5 })
        add({ s: 'particles', t0: t + 380, t1: t + 800, n: 10, seed: seed + i, x: tc.x + dx * 0.5, y: T.y - 30, sx: 20, sy: 6, v: 150, vy: -220, g: 800, life: 400, mode: 'burst', size: [12, 6], style: 'shard', c: ['#d6b98a', '#9b7c4f'] })
        shake.push([t + 380, t + 500, 8])
      }
      hit(780, 1.3, '#9b7c4f')
      back(1650, 60)
      flashAfter(2200)
    },
    'x-scissor': () => {
      // Avança e corta em X com as garras verdes brilhando.
      cam = [[0, ...NEUTRAL], [280, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.1, 0)], [500, ...look(tc, 1.6, -3 * toward)], [1100, ...look(tc, 1.5, -2 * toward)]]
      S.push({ who: 'A', k: 'move', t0: 80, t1: 950, dx: (tc.x - a.x) * 0.55, dy: (tc.y - a.y) * 0.55, back: 1 })
      S.push({ who: 'A', k: 'tint', t0: 100, t1: 700, color: '#a3e635', a: 0.45 })
      add({ s: 'beam', t0: 480, t1: 900, x0: tc.x - 120, y0: tc.y - 110, x1: tc.x + 120, y1: tc.y + 110, w: [6, 16], c: ['#ffffff', '#ecfccb', '#65a30d'], a: [1, 0], grow: 120 })
      add({ s: 'beam', t0: 600, t1: 1000, x0: tc.x + 120, y0: tc.y - 110, x1: tc.x - 120, y1: tc.y + 110, w: [6, 16], c: ['#ffffff', '#ecfccb', '#65a30d'], a: [1, 0], grow: 120 })
      add({ s: 'rays', t0: 650, t1: 1000, x: tc.x, y: tc.y, n: 8, r0: 10, r1: [40, 130], w: 5, c: '#ffffff', c2: '#a3e635', a: [1, 0], rot: 0.4 })
      hit(620, 1.2, '#65a30d')
      back(1100, 100)
      flashAfter(1700)
    },
    'poison-jab': () => {
      // Avança com o braço roxo pingando veneno e espeta; bolhas de veneno saem do alvo.
      cam = [[0, ...NEUTRAL], [280, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.1, 0)], [500, ...look(tc, 1.6, -3 * toward)], [1200, ...look(tc, 1.5, -2 * toward)]]
      S.push({ who: 'A', k: 'move', t0: 80, t1: 950, dx: (tc.x - a.x) * 0.55, dy: (tc.y - a.y) * 0.55, back: 1 })
      S.push({ who: 'A', k: 'tint', t0: 100, t1: 700, color: '#a855f7', a: 0.45 })
      add({ s: 'beam', t0: 450, t1: 800, x0: tc.x - 160 * toward, y0: tc.y, x1: tc.x + 30 * toward, y1: tc.y, w: [8, 18], c: ['#ffffff', '#e9d5ff', '#9333ea'], a: [1, 0], grow: 80 })
      add({ s: 'particles', t0: 550, t1: 1300, n: 30, seed, x: tc.x, y: tc.y, sx: 20, sy: 20, v: 200, vy: -160, g: 600, life: 600, mode: 'burst', size: [12, 6], style: 'goo', c: ['#f6dcff', '#c56cf0', '#8e2fc2'] })
      add({ s: 'particles', t0: 700, t1: 1400, n: 12, seed: seed + 3, x: tc.x, y: tc.y - 20, sx: 60, sy: 30, v: 0, vy: -90, g: 0, life: 600, mode: 'stream', size: [12, 6], style: 'bubble', c: ['#f6dcff', '#c56cf0'] })
      hit(560, 1.2, '#8e2fc2')
      S.push({ who: 'T', k: 'tint', t0: 560, t1: 1300, color: '#a855f7', a: 0.5, pulse: 16 })
      back(1200, 80)
      flashAfter(1800)
    },
    'zen-headbutt': () => {
      // A testa brilha com energia rosa, ele avança e dá uma cabeçada com ondas da mente.
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.4, 2 * toward)], [700, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.1, 0)], [900, ...look(tc, 1.6, -3 * toward)], [1500, ...look(tc, 1.5, -2 * toward)]]
      S.push({ who: 'A', k: 'tint', t0: 200, t1: 1100, color: '#f472b6', a: 0.55, pulse: 18 })
      add({ s: 'ring', t0: 250, t1: 750, x: mouth.x, y: mouth.y - 20, r: [60, 10], ratio: 0.8, w: [2, 6], c: '#fbcfe8', a: [0.3, 1], n: 3, stagger: 1 })
      S.push({ who: 'A', k: 'move', t0: 650, t1: 1400, dx: (tc.x - a.x) * 0.6, dy: (tc.y - a.y) * 0.6, back: 1 })
      add({ s: 'icon', t0: 850, t1: 1150, x: tc.x, y: tc.y, size: [160, 90], a: [0.6, 1], style: 'head', c: ['#ffffff', '#fbcfe8', '#db2777'] })
      add({ s: 'ring', t0: 900, t1: 1400, x: tc.x, y: tc.y, r: [30, 180], ratio: 0.9, w: [10, 2], c: '#f9a8d4', a: [1, 0], n: 3, stagger: 1 })
      hit(900, 1.3, '#db2777')
      back(1400, 120)
      flashAfter(2000)
    },
    'shadow-claw': () => {
      // A garra vira sombra e rasga o alvo com três riscos roxos escuros.
      cam = [[0, ...NEUTRAL], [280, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.1, 0)], [500, ...look(tc, 1.6, -3 * toward)], [1100, ...look(tc, 1.5, -2 * toward)]]
      add({ s: 'tint', t0: 150, t1: 1200, color: '#0b0614', a: [0, 0.45] })
      S.push({ who: 'A', k: 'move', t0: 80, t1: 900, dx: (tc.x - a.x) * 0.55, dy: (tc.y - a.y) * 0.55, back: 1 })
      for (let i = 0; i < 3; i++) add({ s: 'arc', t0: 460 + i * 60, t1: 800 + i * 60, x: tc.x + (i - 1) * 26, y: tc.y, r: 110, a0: -2.4, a1: [-2.4, 0.7], w: 10, c: '#c4b5fd', c2: '#2e1065', flip: toward > 0 ? 0 : 1 })
      add({ s: 'particles', t0: 560, t1: 1200, n: 20, seed, x: tc.x, y: tc.y, sx: 30, sy: 30, v: 160, vy: -40, g: 0, life: 500, mode: 'burst', size: [14, 6], style: 'wisp', c: ['#c4b5fd', '#6d28d9', '#2e1065'] })
      hit(580, 1.2, '#4c1d95')
      back(1100, 120)
      flashAfter(1750)
    },
    'shadow-sneak': () => {
      // A sombra dele corre pelo chão até o alvo e o acerta por baixo.
      cam = [[0, ...NEUTRAL], [300, ...look({ x: (a.x + tc.x) / 2, y: (A.y + T.y) / 2 }, 1.05, 0)], [800, ...look(tc, 1.5, -2 * toward)]]
      add({ s: 'tint', t0: 150, t1: 1300, color: '#0b0614', a: [0, 0.4] })
      add({ s: 'particles', t0: 200, t1: 800, n: 60, seed, x: [a.x, tc.x], y: [A.y, T.y], sx: 40, sy: 6, mode: 'travel', life: 500, size: [26, 8], style: 'wisp', c: ['#4c1d95', '#2e1065', '#0b0614'] })
      add({ s: 'icon', t0: 700, t1: 1000, x: tc.x, y: T.y - T.h * 0.3, size: [60, 120], a: [0.5, 1], style: 'fist', c: ['#c4b5fd', '#4c1d95', '#0b0614'], rot: -Math.PI / 2 })
      add({ s: 'particles', t0: 750, t1: 1300, n: 20, seed: seed + 2, x: tc.x, y: T.y, sx: T.h * 0.3, sy: 6, v: 30, vy: -260, g: 0, life: 500, mode: 'stream', size: [18, 6], style: 'wisp', c: ['#c4b5fd', '#6d28d9'] })
      S.push({ who: 'T', k: 'move', t0: 750, t1: 1050, dx: 0, dy: -24 })
      hit(750, 1.1, '#4c1d95')
      back(1250, 60)
      flashAfter(1800)
    },
    'dazzling-gleam': () => {
      // Um clarão de luz rosa e branca sai dele em estrelas e ilumina todo o campo.
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.35, 2 * toward)], [800, stage.w / 2, stage.h / 2, 0.95, 0], [1500, ...look(tc, 1.35, -2 * toward)]]
      add({ s: 'glow', t0: 250, t1: 900, x: a.x, y: a.y, r: [20, A.h * 0.9], c: ['#ffffff', '#fce7f3', '#f472b6'], a: [0.4, 1] })
      add({ s: 'rays', t0: 700, t1: 1500, x: a.x, y: a.y, n: 18, r0: 30, r1: [80, 700], w: [10, 22], c: '#ffffff', c2: '#f9a8d4', a: [1, 0], rot: [0, 0.4] })
      add({ s: 'tint', t0: 750, t1: 1100, color: '#fff1f8', a: [0.8, 0] })
      add({ s: 'particles', t0: 750, t1: 1700, n: 50, seed, x: tc.x, y: tc.y, sx: 120, sy: 100, v: 60, vy: -40, g: 0, life: 700, mode: 'stream', size: [14, 5], style: 'star', c: ['#ffffff', '#fbcfe8', '#f472b6'] })
      hit(850, 1.2, '#f472b6')
      back(1600, 60)
      flashAfter(2150)
    },
    'body-slam': () => {
      // Pula alto e cai com o corpo inteiro em cima do alvo, que fica achatado.
      cam = [[0, ...NEUTRAL], [300, ...look({ x: a.x, y: a.y - 60 }, 1.2, 2 * toward)], [750, ...look({ x: (a.x + tc.x) / 2, y: Math.min(a.y, tc.y) - 100 }, 1.0, 0)], [1000, ...look(tc, 1.55, -3 * toward)]]
      S.push({ who: 'A', k: 'squash', t0: 150, t1: 400, sx: 1.12, sy: 0.85 })
      S.push({ who: 'A', k: 'move', t0: 350, t1: 1600, dx: (tc.x - a.x) * 0.6, dy: (tc.y - a.y) * 0.6 - 140, back: 1 })
      add({ s: 'icon', t0: 900, t1: 1250, x: tc.x, y: tc.y - 30, size: [190, 110], a: [0.6, 1], style: 'body', c: ['#ffffff', '#e7e5e4', '#78716c'] })
      S.push({ who: 'T', k: 'squash', t0: 980, t1: 1400, sx: 1.25, sy: 0.7 })
      add({ s: 'particles', t0: 980, t1: 1500, n: 30, seed, x: tc.x, y: T.y, sx: T.h * 0.5, sy: 6, v: 200, vy: -120, g: 500, life: 500, mode: 'stream', size: [14, 6], style: 'dust', c: ['#e7e5e4', '#a8a29e'] })
      shake.push([980, 1300, 12])
      hit(980, 1.3, '#a8a29e')
      back(1600, 60)
      flashAfter(2150)
    },
    'double-edge': () => {
      // Corre com tudo, a tela risca de velocidade, bate com força e sente o tranco.
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.3, 2 * toward)], [550, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.05, 0)], [750, ...look(tc, 1.65, -4 * toward)]]
      S.push({ who: 'A', k: 'move', t0: 150, t1: 350, dx: -20 * toward, dy: 0, back: 1 })
      S.push({ who: 'A', k: 'move', t0: 400, t1: 1300, dx: (tc.x - a.x) * 0.62, dy: (tc.y - a.y) * 0.62, back: 1 })
      add({ s: 'particles', t0: 400, t1: 800, n: 30, seed, x: [a.x, tc.x], y: [a.y, tc.y], sx: 40, sy: A.h * 0.3, v: 40, vy: 0, g: 0, life: 260, mode: 'trail', size: [40, 4], style: 'streak', c: ['#ffffff', '#e7e5e4'] })
      add({ s: 'icon', t0: 700, t1: 1000, x: tc.x, y: tc.y, size: [190, 100], a: [0.6, 1], style: 'body', c: ['#ffffff', '#fde68a', '#d97706'] })
      add({ s: 'rays', t0: 750, t1: 1100, x: tc.x, y: tc.y, n: 12, r0: 20, r1: [60, 200], w: 7, c: '#ffffff', c2: '#fbbf24', a: [1, 0], rot: 0.3 })
      hit(750, 1.45, '#d97706')
      S.push({ who: 'A', k: 'flash', t0: 1450, n: 1 })
      back(1300, 100)
      flashAfter(1900)
    },
    'seed-bomb': () => {
      // Atira várias sementes em arco que explodem em verde no alvo.
      cam = [[0, ...NEUTRAL], [300, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 - 40 }, 1.05, 0)], [900, ...look(tc, 1.45, -2 * toward)]]
      for (let i = 0; i < 4; i++) {
        const t = 250 + i * 120
        const dx = (rnd(i) - 0.5) * 80
        add({ s: 'shot', t0: t, t1: t + 520, x: [mouth.x, tc.x + dx], y: [mouth.y, tc.y + (rnd(i + 2) - 0.5) * 60], r: 16, c: ['#ecfccb', '#84cc16', '#3f6212'], style: 'dot', arc: 140 })
        add({ s: 'glow', t0: t + 520, t1: t + 820, x: tc.x + dx, y: tc.y, r: [10, 80], c: ['#ffffff', '#bef264', '#4d7c0f'], a: [1, 0] })
        add({ s: 'particles', t0: t + 520, t1: t + 900, n: 10, seed: seed + i, x: tc.x + dx, y: tc.y, sx: 10, sy: 10, v: 200, vy: -80, g: 300, life: 400, mode: 'burst', size: [12, 8], style: 'leaf', c: ['#ecfccb', '#84cc16'] })
        shake.push([t + 520, t + 620, 6])
      }
      hit(770, 1.2, '#4d7c0f')
      back(1450, 60)
      flashAfter(2000)
    },
    psyshock: () => {
      // Blocos de energia da mente aparecem em volta do alvo e se chocam contra ele.
      cam = [[0, ...NEUTRAL], [350, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.05, 0)], [800, ...look(tc, 1.45, -2 * toward)]]
      S.push({ who: 'A', k: 'tint', t0: 200, t1: 900, color: '#f472b6', a: 0.5, pulse: 20 })
      add({ s: 'tint', t0: 200, t1: 1700, color: '#3b0a2a', a: [0, 0.3] })
      for (let i = 0; i < 6; i++) {
        const ang = (i / 6) * Math.PI * 2
        add({ s: 'shot', t0: 500 + i * 70, t1: 1000 + i * 70, x: [tc.x + Math.cos(ang) * 200, tc.x], y: [tc.y + Math.sin(ang) * 140, tc.y], r: 22, c: ['#ffffff', '#fbcfe8', '#db2777'], style: 'crystal', spin: 1 })
      }
      add({ s: 'ring', t0: 1000, t1: 1500, x: tc.x, y: tc.y, r: [20, 160], ratio: 0.9, w: [10, 2], c: '#f9a8d4', a: [1, 0], n: 2, stagger: 1 })
      hit(1050, 1.25, '#db2777')
      back(1650, 60)
      flashAfter(2200)
    },
    'bulk-up': () => {
      // Infla os músculos: o corpo cresce e treme, aura laranja e Ataque e Defesa sobem.
      cam = [[0, ...NEUTRAL], [400, ...look(a, 1.4, 2 * toward)], [1700, ...look(a, 1.45, 2 * toward)]]
      S.push({ who: 'A', k: 'squash', t0: 300, t1: 800, sx: 1.12, sy: 1.08 })
      S.push({ who: 'A', k: 'squash', t0: 900, t1: 1400, sx: 1.12, sy: 1.08 })
      S.push({ who: 'A', k: 'tint', t0: 300, t1: 1700, color: '#f97316', a: 0.45, pulse: 12 })
      add({ s: 'glow', t0: 400, t1: 1600, x: a.x, y: a.y, r: [40, A.h * 0.9], c: ['rgba(0,0,0,0)', '#fdba74', '#ea580c'], a: [0.6, 0], core: 0.6 })
      add({ s: 'rays', t0: 400, t1: 1400, x: a.x, y: a.y, n: 10, r0: A.h * 0.4, r1: [A.h * 0.5, A.h * 0.9], w: 6, c: '#ffffff', c2: '#f97316', a: [1, 0], rot: 0.3 })
      add({ s: 'particles', t0: 1200, t1: 1900, n: 12, seed, x: a.x, y: A.y - A.h * 0.3, sx: A.h * 0.35, sy: 20, v: 0, vy: -220, g: 0, life: 600, mode: 'stream', size: [18, 14], style: 'arrowUp', c: ['#ffffff', '#fdba74', '#ea580c'] })
      hud = [100, 1900]
      cam.push([2200, ...NEUTRAL])
      end(2300)
    },
    'quiver-dance': () => {
      // Dança leve: pó de escamas coloridas gira em volta dele, brilha e três atributos sobem.
      cam = [[0, ...NEUTRAL], [400, ...look(a, 1.4, 2 * toward)], [1800, ...look(a, 1.45, 2 * toward)]]
      S.push({ who: 'A', k: 'move', t0: 300, t1: 1600, dx: 0, dy: -18, bounce: 4 })
      add({ s: 'particles', t0: 300, t1: 1700, n: 60, seed, x: a.x, y: a.y, sx: 0, sy: 0, mode: 'swirl', r: A.h * 0.7, life: 1000, size: [8, 4], style: 'glint', c: ['#ffffff', '#fde68a', '#a5f3fc', '#f9a8d4', '#bbf7d0'] })
      add({ s: 'ring', t0: 400, t1: 1500, x: a.x, y: [A.y, A.y - A.h], r: A.h * 0.5, ratio: 0.3, w: 4, c: '#fef9c3', a: [1, 0], n: 3, stagger: 1 })
      S.push({ who: 'A', k: 'tint', t0: 800, t1: 1800, color: '#fef08a', a: 0.4, pulse: 10 })
      add({ s: 'particles', t0: 1300, t1: 2000, n: 12, seed: seed + 4, x: a.x, y: A.y - A.h * 0.3, sx: A.h * 0.35, sy: 20, v: 0, vy: -220, g: 0, life: 600, mode: 'stream', size: [18, 14], style: 'arrowUp', c: ['#ffffff', '#fde68a', '#84cc16'] })
      hud = [100, 2000]
      cam.push([2300, ...NEUTRAL])
      end(2400)
    },
    'shell-smash': () => {
      // A casca racha e se quebra em pedaços, ele fica vermelho e os atributos de ataque sobem.
      cam = [[0, ...NEUTRAL], [400, ...look(a, 1.45, 2 * toward)], [1700, ...look(a, 1.5, 2 * toward)]]
      add({ s: 'crack', t0: 300, t1: 1000, x: a.x, y: a.y, r: [10, A.h * 0.5], n: 8, c: '#ffffff', c2: '#94a3b8', a: [1, 0.6] })
      S.push({ who: 'A', k: 'move', t0: 300, t1: 900, dx: 4, dy: 0, bounce: 12 })
      add({ s: 'tint', t0: 950, t1: 1080, color: '#ffffff', a: [0.8, 0] })
      add({ s: 'particles', t0: 950, t1: 1700, n: 26, seed, x: a.x, y: a.y, sx: 20, sy: 20, v: 320, vy: -200, g: 900, life: 700, mode: 'burst', size: [18, 12], style: 'shard', c: ['#f1f5f9', '#cbd5e1', '#94a3b8'] })
      shake.push([950, 1150, 9])
      S.push({ who: 'A', k: 'tint', t0: 1000, t1: 1900, color: '#ef4444', a: 0.5, pulse: 18 })
      add({ s: 'particles', t0: 1200, t1: 1900, n: 12, seed: seed + 4, x: a.x, y: A.y - A.h * 0.3, sx: A.h * 0.35, sy: 20, v: 0, vy: -240, g: 0, life: 600, mode: 'stream', size: [18, 14], style: 'arrowUp', c: ['#ffffff', '#fca5a5', '#ef4444'] })
      hud = [100, 1900]
      cam.push([2200, ...NEUTRAL])
      end(2300)
    },
    'leech-seed': () => {
      // Uma semente voa em arco, cai no alvo e brotam ramos verdes que o prendem.
      cam = [[0, ...NEUTRAL], [300, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 - 40 }, 1.05, 0)], [900, ...look(tc, 1.45, -2 * toward)]]
      add({ s: 'shot', t0: 250, t1: 850, x: [mouth.x, tc.x], y: [mouth.y, tc.y - 30], r: 14, c: ['#fef9c3', '#a16207', '#422006'], style: 'dot', arc: 160 })
      add({ s: 'ring', t0: 900, t1: 1800, x: tc.x, y: [T.y, tc.y - 40], r: [T.h * 0.5, T.h * 0.35], ratio: 0.35, w: [4, 7], c: '#4ade80', a: [1, 0.6], n: 4, spiral: 3 })
      add({ s: 'particles', t0: 950, t1: 1800, n: 20, seed, x: tc.x, y: T.y, sx: T.h * 0.35, sy: 6, v: 0, vy: -160, g: 0, life: 700, mode: 'stream', size: [14, 8], style: 'leaf', c: ['#dcfce7', '#4ade80', '#15803d'] })
      S.push({ who: 'T', k: 'tint', t0: 1000, t1: 1900, color: '#22c55e', a: 0.45, pulse: 12 })
      hud = [100, 1900]
      cam.push([2200, ...NEUTRAL])
      end(2300)
    },
    spore: () => {
      // Uma nuvem de esporos laranja cai em cima do alvo, que adormece.
      cam = [[0, ...NEUTRAL], [400, ...look(tc, 1.4, -2 * toward)], [1800, ...look(tc, 1.4, -2 * toward)]]
      add({ s: 'particles', t0: 200, t1: 800, n: 30, seed, x: [front.x, tc.x], y: [front.y, tc.y - T.h * 0.6], sx: 40, sy: 30, mode: 'travel', life: 500, size: [8, 4], style: 'dust', c: ['#fed7aa', '#fb923c', '#c2410c'] })
      add({ s: 'particles', t0: 700, t1: 1700, n: 70, seed: seed + 2, x: tc.x, y: tc.y - T.h * 0.6, sx: T.h * 0.5, sy: 20, v: 20, vy: 80, g: 30, life: 900, mode: 'stream', size: [8, 4], style: 'dust', c: ['#fed7aa', '#fb923c', '#c2410c'] })
      add({ s: 'particles', t0: 1300, t1: 2100, n: 4, seed: seed + 4, x: tc.x + 30, y: tc.y - T.h * 0.4, sx: 20, sy: 10, v: 20, vy: -60, g: 0, life: 800, mode: 'stream', size: [18, 10], style: 'zzz', c: ['#ffffff', '#e0e7ff'] })
      S.push({ who: 'T', k: 'tint', t0: 1100, t1: 2000, color: '#818cf8', a: 0.35 })
      hud = [100, 2100]
      cam.push([2400, ...NEUTRAL])
      end(2500)
    },
    'sleep-powder': () => {
      // Pó azul brilhante se espalha em volta do alvo e ele cai no sono.
      cam = [[0, ...NEUTRAL], [400, ...look(tc, 1.4, -2 * toward)], [1800, ...look(tc, 1.4, -2 * toward)]]
      add({ s: 'particles', t0: 200, t1: 900, n: 30, seed, x: [front.x, tc.x], y: [front.y, tc.y], sx: 60, sy: 40, mode: 'travel', life: 600, size: [6, 4], style: 'glint', c: ['#ffffff', '#bfdbfe', '#60a5fa'] })
      add({ s: 'particles', t0: 700, t1: 1800, n: 60, seed: seed + 2, x: tc.x, y: tc.y, sx: 0, sy: 0, mode: 'swirl', r: T.h * 0.6, life: 900, size: [6, 4], style: 'glint', c: ['#ffffff', '#bfdbfe', '#60a5fa'] })
      add({ s: 'particles', t0: 1300, t1: 2100, n: 4, seed: seed + 4, x: tc.x + 30, y: tc.y - T.h * 0.4, sx: 20, sy: 10, v: 20, vy: -60, g: 0, life: 800, mode: 'stream', size: [18, 10], style: 'zzz', c: ['#ffffff', '#e0e7ff'] })
      S.push({ who: 'T', k: 'tint', t0: 1100, t1: 2000, color: '#818cf8', a: 0.35 })
      hud = [100, 2100]
      cam.push([2400, ...NEUTRAL])
      end(2500)
    },
    taunt: () => {
      // Ele provoca: balança na frente do alvo e um símbolo de raiva aparece em cima do alvo, que fica vermelho.
      cam = [[0, ...NEUTRAL], [350, ...look(a, 1.35, 2 * toward)], [1000, ...look(tc, 1.4, -2 * toward)], [1900, ...look(tc, 1.4, -2 * toward)]]
      S.push({ who: 'A', k: 'move', t0: 200, t1: 900, dx: 14 * toward, dy: 0, bounce: 4 })
      add({ s: 'particles', t0: 300, t1: 900, n: 6, seed, x: front.x, y: front.y - 20, sx: 30, sy: 20, v: 40, vy: -60, g: 0, life: 500, mode: 'stream', size: [16, 10], style: 'note', c: ['#ffffff', '#fde68a'] })
      add({ s: 'icon', t0: 1100, t1: 1900, x: tc.x + 40, y: tc.y - T.h * 0.55, size: [10, 32], a: [1, 1], style: 'star', c: ['#ffffff', '#ef4444', '#7f1d1d'], rot: 0.4 })
      S.push({ who: 'T', k: 'tint', t0: 1100, t1: 1900, color: '#ef4444', a: 0.45, pulse: 20 })
      S.push({ who: 'T', k: 'move', t0: 1100, t1: 1700, dx: 5, dy: 0, bounce: 10 })
      hud = [100, 1900]
      cam.push([2200, ...NEUTRAL])
      end(2300)
    },
    'trick-room': () => {
      // Uma sala de luz rosa se forma por cima do campo e o espaço fica distorcido.
      cam = [[0, ...NEUTRAL], [500, stage.w / 2, stage.h / 2, 0.92, -3], [1500, stage.w / 2, stage.h / 2, 0.92, 3], [2200, stage.w / 2, stage.h / 2, 0.95, 0]]
      add({ s: 'tint', t0: 200, t1: 2300, color: '#2a0a2a', a: [0, 0.45] })
      for (let i = 0; i < 6; i++) add({ s: 'beam', t0: 300 + i * 90, t1: 2300, x0: 80 + i * 160, y0: 0, x1: 80 + i * 160 + (i % 2 ? 60 : -60), y1: stage.h, w: 4, c: ['#ffffff', '#fbcfe8', '#ec4899'], a: [0.9, 0.3], grow: 400 })
      for (let i = 0; i < 4; i++) add({ s: 'beam', t0: 500 + i * 90, t1: 2300, x0: 0, y0: 90 + i * 120, x1: stage.w, y1: 90 + i * 120 + (i % 2 ? 40 : -40), w: 4, c: ['#ffffff', '#fbcfe8', '#ec4899'], a: [0.9, 0.3], grow: 400 })
      add({ s: 'glow', t0: 300, t1: 2200, x: stage.w / 2, y: stage.h / 2, r: [40, 420], c: ['rgba(0,0,0,0)', '#fbcfe8', '#ec4899'], a: [0.5, 0], core: 0.7 })
      hud = [100, 2300]
      cam.push([2600, ...NEUTRAL])
      end(2700)
    },
    tailwind: () => {
      // Um vento forte sopra pelas costas do seu lado, com riscos e folhas passando.
      cam = [[0, ...NEUTRAL], [400, ...look(a, 1.2, 2 * toward)], [1800, ...look(a, 1.25, 2 * toward)]]
      add({ s: 'particles', t0: 200, t1: 2000, n: 120, seed, x: a.x, y: a.y - 40, sx: 300, sy: A.h * 0.6, v: 800 * toward, vy: -20, g: 0, life: 500, mode: 'stream', size: [40, 3], style: 'streak', c: ['#ffffff', '#e0f2fe', '#bae6fd'] })
      add({ s: 'particles', t0: 300, t1: 1900, n: 20, seed: seed + 2, x: a.x, y: a.y - 40, sx: 300, sy: A.h * 0.6, v: 500 * toward, vy: -60, g: 0, life: 800, mode: 'stream', size: [14, 10], style: 'leaf', c: ['#f1ffd0', '#9be35a'] })
      S.push({ who: 'A', k: 'move', t0: 300, t1: 1800, dx: 4 * toward, dy: 0, bounce: 6 })
      hud = [100, 2000]
      cam.push([2300, ...NEUTRAL])
      end(2400)
    },
    wish: () => {
      // Uma estrela cadente sobe ao céu, brilha e espera para curar no próximo turno.
      cam = [[0, ...NEUTRAL], [400, ...look({ x: a.x, y: a.y - 120 }, 1.2, 2 * toward)], [1600, ...look({ x: a.x, y: 120 }, 1.15, 0)]]
      add({ s: 'tint', t0: 200, t1: 2100, color: '#0a0620', a: [0, 0.45] })
      add({ s: 'glow', t0: 300, t1: 800, x: a.x, y: a.y - A.h * 0.4, r: [10, 50], c: ['#ffffff', '#fef9c3', '#facc15'], a: 1 })
      add({ s: 'shot', t0: 700, t1: 1400, x: [a.x, a.x + 60 * toward], y: [a.y - A.h * 0.4, 60], r: 26, c: ['#ffffff', '#fef08a', '#facc15'], style: 'star', trail: 1, spin: 1 })
      add({ s: 'rays', t0: 1400, t1: 2000, x: a.x + 60 * toward, y: 60, n: 10, r0: 10, r1: [30, 140], w: 5, c: '#ffffff', c2: '#facc15', a: [1, 0], rot: [0, 0.5] })
      add({ s: 'particles', t0: 1400, t1: 2100, n: 20, seed, x: a.x + 60 * toward, y: 60, sx: 0, sy: 0, mode: 'burst', v: 160, vy: 0, g: 100, life: 600, size: [10, 4], style: 'star', c: ['#ffffff', '#fef08a'] })
      hud = [100, 2100]
      cam.push([2400, ...NEUTRAL])
      end(2500)
    },
    // ---- Lote 4, feitos à mão como no Black & White ----
    'aerial-ace': () => {
      // Some num risco branco, aparece do lado do alvo e corta rápido; nunca erra.
      cam = [[0, ...NEUTRAL], [250, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.05, 0)], [450, ...look(tc, 1.6, -3 * toward)], [1000, ...look(tc, 1.5, -2 * toward)]]
      S.push({ who: 'A', k: 'hide', t0: 200, t1: 750 })
      add({ s: 'particles', t0: 150, t1: 450, n: 30, seed, x: [a.x, tc.x], y: [a.y, tc.y], sx: 20, sy: 20, v: 40, vy: 0, g: 0, life: 220, mode: 'trail', size: [40, 4], style: 'streak', c: ['#ffffff', '#e0f2fe'] })
      add({ s: 'beam', t0: 450, t1: 800, x0: tc.x - 150 * toward, y0: tc.y - 120, x1: tc.x + 150 * toward, y1: tc.y + 100, w: [4, 14], c: ['#ffffff', '#f0f9ff', '#7dd3fc'], a: [1, 0], grow: 90 })
      add({ s: 'rays', t0: 520, t1: 850, x: tc.x, y: tc.y, n: 8, r0: 10, r1: [40, 130], w: 4, c: '#ffffff', c2: '#7dd3fc', a: [1, 0], rot: 0.6 })
      hit(520, 1.15, '#7dd3fc')
      back(950, 100)
      flashAfter(1500)
    },
    acrobatics: () => {
      // Dá piruetas no ar em volta do alvo e acerta de vários lados.
      cam = [[0, ...NEUTRAL], [300, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 - 40 }, 1.05, 0)], [600, ...look(tc, 1.45, -2 * toward)], [1500, ...look(tc, 1.45, 2 * toward)]]
      S.push({ who: 'A', k: 'move', t0: 80, t1: 1600, dx: (tc.x - a.x) * 0.55, dy: (tc.y - a.y) * 0.55 - 80, back: 1 })
      S.push({ who: 'A', k: 'squash', t0: 300, t1: 1400, sx: 0.85, sy: 1.1 })
      add({ s: 'ring', t0: 400, t1: 1400, x: tc.x, y: tc.y, r: [T.h * 0.7, T.h * 0.5], ratio: 0.5, w: [6, 3], c: '#e0f2fe', a: [0.9, 0.2], n: 3, spiral: 4 })
      for (let i = 0; i < 4; i++) {
        const t = 600 + i * 180
        const ang = i * 1.6
        add({ s: 'rays', t0: t, t1: t + 180, x: tc.x + Math.cos(ang) * 50, y: tc.y + Math.sin(ang) * 40, n: 6, r0: 8, r1: [24, 80], w: 4, c: '#ffffff', c2: '#a5b4fc', a: [1, 0], rot: ang })
        add({ s: 'particles', t0: t, t1: t + 400, n: 4, seed: seed + i, x: tc.x, y: tc.y, sx: 20, sy: 20, v: 160, vy: -60, g: 120, life: 400, mode: 'burst', size: [12, 8], style: 'feather', c: ['#ffffff', '#e0e7ff'] })
        shake.push([t, t + 90, 5])
      }
      hit(1200, 1.2, '#818cf8')
      back(1600, 60)
      flashAfter(2150)
    },
    fly: () => {
      // Sobe voando até sumir no alto e mergulha do céu em cima do alvo.
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.25, 2 * toward)], [800, ...look({ x: a.x, y: a.y - 200 }, 1.05, 0)], [1300, ...look({ x: tc.x, y: tc.y - 140 }, 1.1, 0)], [1600, ...look(tc, 1.6, -3 * toward)]]
      S.push({ who: 'A', k: 'move', t0: 250, t1: 900, dx: 0, dy: -600, back: 0 })
      S.push({ who: 'A', k: 'hide', t0: 900, t1: 1300 })
      add({ s: 'particles', t0: 250, t1: 900, n: 14, seed, x: a.x, y: A.y, sx: A.h * 0.5, sy: 10, v: 60, vy: 40, g: 60, life: 900, mode: 'stream', size: [16, 10], style: 'feather', c: ['#ffffff', '#e7e5e4'] })
      add({ s: 'shot', t0: 1250, t1: 1550, x: [tc.x - 120 * toward, tc.x], y: [-80, tc.y], r: 40, c: ['#ffffff', '#e0f2fe', '#93c5fd'], style: 'streak', trail: 1 })
      add({ s: 'rays', t0: 1550, t1: 1900, x: tc.x, y: tc.y, n: 10, r0: 20, r1: [50, 170], w: 6, c: '#ffffff', c2: '#93c5fd', a: [1, 0], rot: 0.3 })
      hit(1550, 1.3, '#93c5fd')
      S.push({ who: 'A', k: 'fade', t0: 1300, t1: 1800, a0: 0, a1: 1 })
      back(1850, 60)
      flashAfter(2400)
    },
    dig: () => {
      // Cava e afunda no chão, o chão treme embaixo do alvo e ele sai de baixo da terra.
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.3, 2 * toward)], [1000, ...look({ x: tc.x, y: T.y - 60 }, 1.35, -toward)], [1500, ...look(tc, 1.5, -3 * toward)]]
      S.push({ who: 'A', k: 'move', t0: 250, t1: 800, dx: 0, dy: 80, back: 0 })
      S.push({ who: 'A', k: 'fade', t0: 300, t1: 800, a0: 1, a1: 0 })
      S.push({ who: 'A', k: 'hide', t0: 800, t1: 1700 })
      add({ s: 'particles', t0: 250, t1: 900, n: 40, seed, x: a.x, y: A.y, sx: A.h * 0.4, sy: 6, v: 160, vy: -260, g: 700, life: 500, mode: 'stream', size: [14, 6], style: 'dust', c: ['#e0b866', '#a8742e', '#5b3c12'] })
      shake.push([900, 1300, 4])
      add({ s: 'crack', t0: 1000, t1: 1900, x: tc.x, y: T.y, r: [10, 200], n: 7, c: '#2b1b08', c2: '#e0b866', a: [1, 0] })
      add({ s: 'particles', t0: 1300, t1: 1900, n: 50, seed: seed + 2, x: tc.x, y: T.y, sx: T.h * 0.3, sy: 6, v: 80, vy: -520, g: 1000, life: 700, mode: 'stream', size: [16, 8], style: 'dust', c: ['#e0b866', '#a8742e', '#5b3c12'] })
      add({ s: 'icon', t0: 1300, t1: 1600, x: tc.x, y: T.y - T.h * 0.3, size: [60, 120], a: [0.5, 1], style: 'body', c: ['#ffffff', '#e0b866', '#5b3c12'], rot: 0 })
      S.push({ who: 'T', k: 'move', t0: 1300, t1: 1700, dx: 0, dy: -40 })
      shake.push([1300, 1600, 10])
      hit(1300, 1.3, '#a8742e')
      S.push({ who: 'A', k: 'fade', t0: 1700, t1: 2000, a0: 0, a1: 1 })
      back(1900, 60)
      flashAfter(2450)
    },
    megahorn: () => {
      // Abaixa a cabeça, o chifre brilha verde e avança com tudo espetando o alvo.
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.4, 2 * toward)], [700, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.05, 0)], [900, ...look(tc, 1.65, -4 * toward)]]
      add({ s: 'glow', t0: 200, t1: 800, x: mouth.x, y: mouth.y - 20, r: [6, 50], c: ['#ffffff', '#d9f99d', '#65a30d'], a: 1 })
      add({ s: 'rays', t0: 300, t1: 800, x: mouth.x, y: mouth.y - 20, n: 6, r0: 6, r1: [20, 70], w: 4, c: '#ffffff', c2: '#84cc16', a: [1, 0], rot: [0, 1] })
      S.push({ who: 'A', k: 'move', t0: 650, t1: 1450, dx: (tc.x - a.x) * 0.62, dy: (tc.y - a.y) * 0.62, back: 1 })
      add({ s: 'beam', t0: 850, t1: 1150, x0: tc.x - 120 * toward, y0: tc.y, x1: tc.x + 60 * toward, y1: tc.y, w: [10, 26], c: ['#ffffff', '#ecfccb', '#65a30d'], a: [1, 0], grow: 60 })
      add({ s: 'rays', t0: 900, t1: 1300, x: tc.x, y: tc.y, n: 12, r0: 20, r1: [60, 200], w: 7, c: '#ffffff', c2: '#84cc16', a: [1, 0], rot: 0.2 })
      hit(900, 1.45, '#65a30d')
      back(1450, 100)
      flashAfter(2000)
    },
    'leaf-blade': () => {
      // Uma lâmina de folha verde aparece no braço e corta o alvo em diagonal com folhas voando.
      cam = [[0, ...NEUTRAL], [280, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.1, 0)], [500, ...look(tc, 1.6, -3 * toward)], [1100, ...look(tc, 1.5, -2 * toward)]]
      S.push({ who: 'A', k: 'move', t0: 80, t1: 950, dx: (tc.x - a.x) * 0.55, dy: (tc.y - a.y) * 0.55, back: 1 })
      S.push({ who: 'A', k: 'tint', t0: 100, t1: 700, color: '#4ade80', a: 0.4 })
      add({ s: 'arc', t0: 450, t1: 850, x: tc.x, y: tc.y, r: 130, a0: -2.6, a1: [-2.6, 0.8], w: 14, c: '#f0fdf4', c2: '#16a34a', flip: toward > 0 ? 0 : 1 })
      add({ s: 'particles', t0: 550, t1: 1300, n: 26, seed, x: tc.x, y: tc.y, sx: 30, sy: 30, v: 220, vy: -80, g: 200, life: 700, mode: 'burst', size: [16, 10], style: 'leaf', c: ['#f1ffd0', '#9be35a', '#3fa34d'] })
      hit(560, 1.25, '#16a34a')
      back(1100, 100)
      flashAfter(1700)
    },
    'night-slash': () => {
      // A tela fica noite por um instante, ele corta no escuro e o risco brilha depois.
      cam = [[0, ...NEUTRAL], [250, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.1, 0)], [450, ...look(tc, 1.6, -3 * toward)], [1100, ...look(tc, 1.5, -2 * toward)]]
      add({ s: 'tint', t0: 200, t1: 900, color: '#020008', a: [0.85, 0.3] })
      S.push({ who: 'A', k: 'hide', t0: 250, t1: 800 })
      add({ s: 'beam', t0: 550, t1: 1000, x0: tc.x - 170 * toward, y0: tc.y + 110, x1: tc.x + 170 * toward, y1: tc.y - 120, w: [4, 16], c: ['#ffffff', '#ddd6fe', '#6d28d9'], a: [1, 0], grow: 80 })
      add({ s: 'particles', t0: 600, t1: 1200, n: 20, seed, x: tc.x, y: tc.y, sx: 30, sy: 30, v: 180, vy: -40, g: 0, life: 500, mode: 'burst', size: [14, 6], style: 'wisp', c: ['#c4b5fd', '#6d28d9', '#1e0b3a'] })
      hit(600, 1.25, '#4c1d95')
      back(1100, 100)
      flashAfter(1700)
    },
    'psycho-cut': () => {
      // Lâminas rosadas da mente se formam e voam girando até o alvo.
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.3, 2 * toward)], [700, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.0, 0)], [950, ...look(tc, 1.5, -3 * toward)]]
      S.push({ who: 'A', k: 'tint', t0: 200, t1: 800, color: '#f472b6', a: 0.5, pulse: 20 })
      for (let i = 0; i < 2; i++) {
        const t = 450 + i * 150
        add({ s: 'shot', t0: t, t1: t + 420, x: [front.x, tc.x], y: [front.y + (i ? 30 : -30), tc.y + (i ? 30 : -30)], r: 36, c: ['#ffffff', '#fbcfe8', '#db2777', '#831843'], style: 'moon', spin: 2 * toward })
        add({ s: 'arc', t0: t + 420, t1: t + 700, x: tc.x, y: tc.y, r: 100, a0: i ? 0.6 : -2.4, a1: i ? [0.6, -2.4] : [-2.4, 0.6], w: 10, c: '#ffffff', c2: '#db2777', flip: toward > 0 ? 0 : 1 })
      }
      hit(870, 1.25, '#db2777')
      back(1350, 100)
      flashAfter(1900)
    },
    'sacred-sword': () => {
      // Uma espada de luz dourada aparece, desce e corta o alvo em linha reta.
      cam = [[0, ...NEUTRAL], [300, ...look({ x: tc.x, y: tc.y - 100 }, 1.3, -toward)], [1000, ...look(tc, 1.55, -3 * toward)]]
      add({ s: 'tint', t0: 200, t1: 1400, color: '#0f0a00', a: [0, 0.35] })
      add({ s: 'swords', t0: 300, t1: 1100, x: tc.x, y: tc.y - T.h * 0.9, rx: 1, ry: 1, n: 1, size: Math.max(70, T.h * 0.7), spin: 0, top: tc.y, c: ['#ffffff', '#fef3c7', '#b45309', '#1e3a8a', '#facc15'] })
      add({ s: 'glow', t0: 300, t1: 1000, x: tc.x, y: tc.y - T.h * 0.9, r: [10, 90], c: ['#ffffff', '#fef3c7', '#f59e0b'], a: [0.4, 0.9] })
      add({ s: 'beam', t0: 950, t1: 1350, x0: tc.x, y0: tc.y - T.h, x1: tc.x, y1: T.y + 20, w: [6, 22], c: ['#ffffff', '#fef3c7', '#f59e0b'], a: [1, 0], grow: 80 })
      add({ s: 'rays', t0: 1000, t1: 1400, x: tc.x, y: tc.y, n: 12, r0: 20, r1: [60, 200], w: 6, c: '#ffffff', c2: '#facc15', a: [1, 0], rot: 0.2 })
      hit(1000, 1.35, '#f59e0b')
      back(1400, 80)
      flashAfter(1950)
    },
    'iron-tail': () => {
      // A cauda vira metal, ele gira e bate com ela no alvo.
      cam = [[0, ...NEUTRAL], [280, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.1, 0)], [550, ...look(tc, 1.6, -3 * toward)], [1100, ...look(tc, 1.5, -2 * toward)]]
      S.push({ who: 'A', k: 'tint', t0: 100, t1: 900, color: '#cbd5e1', a: 0.55, pulse: 20 })
      S.push({ who: 'A', k: 'move', t0: 80, t1: 1000, dx: (tc.x - a.x) * 0.55, dy: (tc.y - a.y) * 0.55, back: 1 })
      add({ s: 'arc', t0: 450, t1: 850, x: tc.x, y: tc.y, r: 130, a0: 2.6, a1: [2.6, -0.6], w: 18, c: '#f8fafc', c2: '#64748b', flip: toward > 0 ? 0 : 1 })
      add({ s: 'rays', t0: 600, t1: 950, x: tc.x, y: tc.y, n: 12, r0: 20, r1: [50, 170], w: 6, c: '#ffffff', c2: '#94a3b8', a: [1, 0], rot: 0.2 })
      hit(600, 1.3, '#94a3b8')
      back(1100, 100)
      flashAfter(1700)
    },
    'dragon-pulse': () => {
      // Uma onda de energia de dragão azul e roxa sai da boca em espiral até o alvo.
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.3, 2 * toward)], [700, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.0, 0)], [1300, ...look(tc, 1.45, -2 * toward)]]
      add({ s: 'glow', t0: 200, t1: 700, x: mouth.x, y: mouth.y, r: [6, 46], c: ['#ffffff', '#a5b4fc', '#4338ca'], a: 1, swirl: 1 })
      add({ s: 'beam', t0: 650, t1: 1500, x0: mouth.x, y0: mouth.y, x1: tc.x, y1: tc.y, w: [10, 32], c: ['#ffffff', '#a5b4fc', '#4338ca'], a: [1, 0], wobble: 6, grow: 200 })
      add({ s: 'ring', t0: 700, t1: 1500, x: [mouth.x, tc.x], y: [mouth.y, tc.y], r: [30, 60], ratio: 0.9, w: [8, 3], c: '#c7d2fe', a: [1, 0.3], n: 6, stagger: 1 })
      add({ s: 'particles', t0: 850, t1: 1600, n: 30, seed, x: tc.x, y: tc.y, sx: 20, sy: 20, v: 220, vy: -40, g: 0, life: 600, mode: 'burst', size: [14, 5], style: 'ember', c: ['#eef0ff', '#9aa6ff', '#5a4ae0'] })
      hit(850, 1.25, '#4338ca')
      back(1550, 60)
      flashAfter(2100)
    },
    'ice-shard': () => {
      // Cristais de gelo se formam e voam rapidinho até o alvo antes de todo mundo.
      cam = [[0, ...NEUTRAL], [250, ...look(a, 1.3, 2 * toward)], [500, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.0, 0)], [700, ...look(tc, 1.5, -2 * toward)]]
      add({ s: 'particles', t0: 150, t1: 450, n: 16, seed, x: front.x, y: front.y, sx: 0, sy: 0, mode: 'converge', r: 120, life: 300, size: [8, 12], style: 'crystal', c: ['#ffffff', '#c8f6ff', '#6cc9f0'] })
      for (let i = 0; i < 3; i++) add({ s: 'shot', t0: 400 + i * 60, t1: 650 + i * 60, x: [front.x, tc.x + (i - 1) * 30], y: [front.y, tc.y + (i - 1) * 30], r: 22, c: ['#ffffff', '#c8f6ff', '#6cc9f0'], style: 'crystal', spin: 2 })
      add({ s: 'particles', t0: 650, t1: 1300, n: 20, seed: seed + 3, x: tc.x, y: tc.y, sx: 0, sy: 0, mode: 'burst', v: 200, vy: 40, g: 300, life: 600, size: [12, 6], style: 'crystal', c: ['#ffffff', '#c8f6ff'] })
      hit(650, 1.1, '#9ee8ff')
      back(1100, 60)
      flashAfter(1650)
    },
    'icicle-crash': () => {
      // Pingentes de gelo enormes se formam no alto e despencam em cima do alvo.
      cam = [[0, ...NEUTRAL], [400, ...look({ x: tc.x, y: tc.y - 140 }, 1.2, -toward)], [1100, ...look(tc, 1.4, -2 * toward)]]
      for (let i = 0; i < 4; i++) {
        const t = 500 + i * 150
        const dx = (i - 1.5) * 60
        add({ s: 'cone', t0: 250 + i * 80, t1: t, x: tc.x + dx, y: tc.y - 200, w: 44, c: '#bfeeff', a: 0.9 })
        add({ s: 'shot', t0: t, t1: t + 220, x: [tc.x + dx, tc.x + dx * 0.6], y: [tc.y - 220, tc.y], r: 34, c: ['#ffffff', '#c8f6ff', '#3b9fd0'], style: 'crystal', spin: 0 })
        add({ s: 'particles', t0: t + 220, t1: t + 700, n: 10, seed: seed + i, x: tc.x + dx * 0.6, y: tc.y, sx: 10, sy: 10, v: 200, vy: -120, g: 600, life: 500, mode: 'burst', size: [14, 6], style: 'crystal', c: ['#ffffff', '#c8f6ff'] })
        shake.push([t + 220, t + 340, 8])
      }
      hit(720, 1.35, '#9ee8ff')
      S.push({ who: 'T', k: 'tint', t0: 720, t1: 1600, color: '#bfeeff', a: 0.6 })
      back(1600, 60)
      flashAfter(2150)
    },
    'freeze-dry': () => {
      // Um ar gelado e seco envolve o alvo e congela até a água dele: cristais e névoa branca.
      cam = [[0, ...NEUTRAL], [350, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.05, 0)], [900, ...look(tc, 1.45, -2 * toward)]]
      add({ s: 'particles', t0: 250, t1: 1000, n: 60, seed, x: [front.x, tc.x], y: [front.y, tc.y], sx: 60, sy: 50, mode: 'travel', life: 600, size: [8, 4], style: 'glint', c: ['#ffffff', '#e0f2fe'] })
      add({ s: 'particles', t0: 800, t1: 1800, n: 30, seed: seed + 2, x: tc.x, y: tc.y, sx: T.h * 0.4, sy: T.h * 0.3, v: 20, vy: -60, g: 0, life: 800, mode: 'stream', size: [34, 14], style: 'smoke', c: ['#ffffff', '#f0f9ff', '#e0f2fe'] })
      add({ s: 'particles', t0: 900, t1: 1700, n: 22, seed: seed + 4, x: tc.x, y: tc.y, sx: 0, sy: 0, mode: 'burst', v: 180, vy: 20, g: 200, life: 700, size: [16, 8], style: 'crystal', c: ['#ffffff', '#c8f6ff', '#6cc9f0'] })
      hit(900, 1.2, '#9ee8ff')
      S.push({ who: 'T', k: 'tint', t0: 900, t1: 1800, color: '#e0faff', a: 0.7 })
      back(1800, 60)
      flashAfter(2350)
    },
    'gunk-shot': () => {
      // Um monte grande de lixo tóxico voa em arco e cai esparramando gosma roxa.
      cam = [[0, ...NEUTRAL], [300, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 - 60 }, 1.0, 0)], [1000, ...look(tc, 1.45, -2 * toward)]]
      add({ s: 'shot', t0: 250, t1: 950, x: [mouth.x, tc.x], y: [mouth.y, tc.y], r: 46, c: ['#f6dcff', '#9333ea', '#581c87', '#2e1065'], style: 'goo', arc: 240, spin: toward })
      add({ s: 'particles', t0: 950, t1: 1800, n: 50, seed, x: tc.x, y: tc.y, sx: 30, sy: 30, v: 280, vy: -200, g: 700, life: 800, mode: 'burst', size: [18, 8], style: 'goo', c: ['#f6dcff', '#c56cf0', '#8e2fc2', '#581c87'] })
      add({ s: 'particles', t0: 1050, t1: 2000, n: 16, seed: seed + 3, x: tc.x, y: tc.y, sx: 80, sy: 30, v: 0, vy: -90, g: 0, life: 700, mode: 'stream', size: [14, 6], style: 'bubble', c: ['#f6dcff', '#c56cf0'] })
      shake.push([950, 1250, 10])
      hit(950, 1.4, '#7e22ce')
      S.push({ who: 'T', k: 'tint', t0: 950, t1: 1900, color: '#a855f7', a: 0.6, pulse: 16 })
      back(1950, 60)
      flashAfter(2500)
    },
    'head-smash': () => {
      // Cabeça de pedra brilhando, avança com uma força enorme, racha tudo e sente um tranco forte.
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.4, 2 * toward)], [800, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.05, 0)], [1000, ...look(tc, 1.7, -5 * toward)]]
      S.push({ who: 'A', k: 'tint', t0: 200, t1: 1100, color: '#b89a6a', a: 0.6, pulse: 18 })
      add({ s: 'glow', t0: 200, t1: 900, x: mouth.x, y: mouth.y - 20, r: [10, 60], c: ['#ffffff', '#e7d3ae', '#7a6040'], a: 1 })
      S.push({ who: 'A', k: 'move', t0: 750, t1: 1550, dx: (tc.x - a.x) * 0.65, dy: (tc.y - a.y) * 0.65, back: 1 })
      add({ s: 'icon', t0: 950, t1: 1300, x: tc.x, y: tc.y, size: [180, 100], a: [0.6, 1], style: 'head', c: ['#ffffff', '#e7d3ae', '#7a6040'] })
      add({ s: 'crack', t0: 1000, t1: 1800, x: tc.x, y: tc.y, r: [20, 220], n: 10, c: '#2b1b08', c2: '#e7d3ae', a: [1, 0] })
      add({ s: 'particles', t0: 1000, t1: 1700, n: 24, seed, x: tc.x, y: tc.y, sx: 20, sy: 20, v: 320, vy: -200, g: 900, life: 700, mode: 'burst', size: [16, 10], style: 'shard', c: ['#d6b98a', '#9b7c4f'] })
      add({ s: 'tint', t0: 1000, t1: 1120, color: '#ffffff', a: [0.85, 0] })
      shake.push([1000, 1500, 15])
      hit(1000, 1.6, '#9b7c4f')
      S.push({ who: 'A', k: 'flash', t0: 1700, n: 2 })
      back(1550, 100)
      flashAfter(2150)
    },
    superpower: () => {
      // Junta força com aura vermelha, avança e solta um golpe enorme; depois fica mais fraco.
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.4, 2 * toward)], [900, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.05, 0)], [1100, ...look(tc, 1.65, -4 * toward)]]
      S.push({ who: 'A', k: 'tint', t0: 200, t1: 1200, color: '#ef4444', a: 0.55, pulse: 22 })
      S.push({ who: 'A', k: 'squash', t0: 300, t1: 850, sx: 1.12, sy: 1.08 })
      add({ s: 'glow', t0: 200, t1: 900, x: a.x, y: a.y, r: [20, A.h * 0.85], c: ['rgba(0,0,0,0)', '#fca5a5', '#b91c1c'], a: [0.4, 1], core: 0.55 })
      S.push({ who: 'A', k: 'move', t0: 850, t1: 1650, dx: (tc.x - a.x) * 0.6, dy: (tc.y - a.y) * 0.6, back: 1 })
      add({ s: 'icon', t0: 1050, t1: 1400, x: tc.x, y: tc.y, size: [220, 110], a: [0.6, 1], style: 'fist', c: ['#fff2e0', '#fca5a5', '#b91c1c'], rot: -0.2 * toward })
      add({ s: 'rays', t0: 1100, t1: 1500, x: tc.x, y: tc.y, n: 16, r0: 30, r1: [80, 260], w: 8, c: '#ffffff', c2: '#ef4444', a: [1, 0], rot: 0.2 })
      shake.push([1100, 1500, 14])
      hit(1100, 1.55, '#b91c1c')
      S.push({ who: 'A', k: 'tint', t0: 1800, t1: 2300, color: '#3b82f6', a: 0.4 })
      add({ s: 'particles', t0: 1800, t1: 2300, n: 8, seed, x: a.x, y: A.y - A.h * 0.8, sx: A.h * 0.35, sy: 20, v: 0, vy: 180, g: 0, life: 500, mode: 'stream', size: [16, 12], style: 'arrowDown', c: ['#ffffff', '#93c5fd', '#2563eb'] })
      back(1650, 100)
      flashAfter(2200)
    },
    'mach-punch': () => {
      // Um soco tão rápido que só se vê um risco e o punho já acertou.
      cam = [[0, ...NEUTRAL], [200, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.1, 0)], [350, ...look(tc, 1.6, -3 * toward)], [800, ...look(tc, 1.5, -2 * toward)]]
      S.push({ who: 'A', k: 'move', t0: 40, t1: 800, dx: (tc.x - a.x) * 0.6, dy: (tc.y - a.y) * 0.6, back: 1 })
      add({ s: 'particles', t0: 40, t1: 350, n: 24, seed, x: [a.x, tc.x], y: [a.y, tc.y], sx: 20, sy: A.h * 0.25, v: 40, vy: 0, g: 0, life: 200, mode: 'trail', size: [40, 4], style: 'streak', c: ['#ffffff', '#fed7aa'] })
      add({ s: 'icon', t0: 300, t1: 600, x: tc.x, y: tc.y, size: [170, 90], a: [0.6, 1], style: 'fist', c: ['#fff2e0', '#ffb067', '#d0562b'], rot: -0.2 * toward })
      add({ s: 'rays', t0: 350, t1: 650, x: tc.x, y: tc.y, n: 10, r0: 10, r1: [40, 140], w: 5, c: '#ffffff', c2: '#ffb067', a: [1, 0], rot: 0.3 })
      hit(350, 1.15, '#d0562b')
      back(800, 100)
      flashAfter(1350)
    },
    'hammer-arm': () => {
      // Levanta o braço e desce como um martelo em cima do alvo; fica mais lento depois.
      cam = [[0, ...NEUTRAL], [300, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.1, 0)], [600, ...look({ x: tc.x, y: tc.y - 60 }, 1.5, -2 * toward)], [1200, ...look(tc, 1.5, -2 * toward)]]
      S.push({ who: 'A', k: 'move', t0: 80, t1: 1300, dx: (tc.x - a.x) * 0.55, dy: (tc.y - a.y) * 0.55, back: 1 })
      add({ s: 'icon', t0: 500, t1: 850, x: [tc.x, tc.x], y: [tc.y - 200, tc.y - 20], size: [140, 120], a: [0.6, 1], style: 'fist', c: ['#fff2e0', '#ffb067', '#d0562b'], rot: 0.5 * toward })
      add({ s: 'rays', t0: 850, t1: 1200, x: tc.x, y: tc.y - 20, n: 12, r0: 20, r1: [60, 200], w: 7, c: '#ffffff', c2: '#ffb067', a: [1, 0], rot: 0.3 })
      S.push({ who: 'T', k: 'squash', t0: 850, t1: 1200, sx: 1.18, sy: 0.82 })
      shake.push([850, 1150, 12])
      hit(850, 1.4, '#d0562b')
      add({ s: 'particles', t0: 1400, t1: 1900, n: 8, seed, x: a.x, y: A.y - A.h * 0.8, sx: A.h * 0.35, sy: 20, v: 0, vy: 180, g: 0, life: 500, mode: 'stream', size: [16, 12], style: 'arrowDown', c: ['#ffffff', '#93c5fd', '#2563eb'] })
      back(1300, 100)
      flashAfter(1900)
    },
    'thunder-fang': () => {
      // Presas cheias de eletricidade mordem o alvo e soltam faíscas.
      fang(['#ffffff', '#ffe94a', '#d4a106'], 'spark', '#ffe94a')
      add({ s: 'bolt', t0: 650, t1: 1300, x: tc.x, y: tc.y, r: 120, n: 6, c: '#ffffff', c2: '#ffe94a', w: 3, flicker: 1 })
    },
    'fire-fang': () => {
      // Presas em chamas mordem o alvo e o fogo sobe.
      fang(['#fff7c2', '#ffb02e', '#e5391a'], 'flame', '#ff4a0a')
    },
    'ice-fang': () => {
      // Presas de gelo mordem o alvo e cristais se espalham.
      fang(['#ffffff', '#c8f6ff', '#6cc9f0'], 'crystal', '#9ee8ff')
    },
    'muddy-water': () => {
      // Uma onda de água barrenta passa pelo campo e deixa o alvo sujo de lama.
      const wide = [(a.x + tc.x) / 2, (a.y + tc.y) / 2 + 10, 0.95, -toward]
      cam = [[0, ...NEUTRAL], [450, ...wide], [1750, ...wide], [2100, ...look(tc, 1.35, -2 * toward)]]
      add({ s: 'tint', t0: 150, t1: 2500, color: '#2a1606', a: [0, 0.3] })
      add({ s: 'surge', t0: 350, t1: 2350, dir: toward, c: ['#f5e6c8', '#c9a46a', '#8a6630', '#4a3214'], a: 0.93 })
      add({ s: 'particles', t0: 1250, t1: 2000, n: 40, seed, x: tc.x, y: tc.y, sx: 30, sy: 30, v: 260, vy: -220, g: 700, life: 650, mode: 'burst', size: [10, 4], style: 'droplet', c: ['#f5e6c8', '#c9a46a', '#8a6630'] })
      hit(1250, 1.25, '#8a6630')
      S.push({ who: 'T', k: 'tint', t0: 1250, t1: 2700, color: '#8a6630', a: 0.55 })
      back(2650, 60)
      flashAfter(3200)
    },
    'mud-shot': () => {
      // Bolas de lama voam em sequência e espirram no alvo.
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.3, 2 * toward)], [600, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.0, 0)], [850, ...look(tc, 1.45, -2 * toward)]]
      for (let i = 0; i < 3; i++) {
        const t = 350 + i * 130
        add({ s: 'shot', t0: t, t1: t + 400, x: [mouth.x, tc.x + (i - 1) * 30], y: [mouth.y, tc.y + (i - 1) * 25], r: 22, c: ['#e0b866', '#8a6630', '#4a3214'], style: 'goo', arc: 40 })
        add({ s: 'particles', t0: t + 400, t1: t + 800, n: 10, seed: seed + i, x: tc.x + (i - 1) * 30, y: tc.y + (i - 1) * 25, sx: 10, sy: 10, v: 180, vy: -100, g: 600, life: 400, mode: 'burst', size: [10, 5], style: 'goo', c: ['#e0b866', '#8a6630'] })
        shake.push([t + 400, t + 480, 5])
      }
      hit(750, 1.15, '#8a6630')
      S.push({ who: 'T', k: 'tint', t0: 750, t1: 1500, color: '#8a6630', a: 0.5 })
      back(1450, 60)
      flashAfter(2000)
    },
    'ancient-power': () => {
      // Pedras antigas brilhando flutuam em volta dele, sobem e são atiradas no alvo.
      cam = [[0, ...NEUTRAL], [350, ...look(a, 1.35, 2 * toward)], [1200, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.0, 0)], [1500, ...look(tc, 1.45, -2 * toward)]]
      add({ s: 'particles', t0: 250, t1: 1200, n: 6, seed, x: a.x, y: a.y, sx: 0, sy: 0, mode: 'orbit', r: A.h * 0.6, life: 950, size: [22, 18], style: 'shard', c: ['#e7d3ae', '#b89a6a'] })
      add({ s: 'glow', t0: 300, t1: 1200, x: a.x, y: a.y, r: [30, A.h * 0.8], c: ['rgba(0,0,0,0)', '#fde68a', '#b45309'], a: [0.2, 0.6], core: 0.6 })
      for (let i = 0; i < 5; i++) add({ s: 'shot', t0: 1150 + i * 60, t1: 1500 + i * 60, x: [a.x + Math.cos(i * 1.3) * A.h * 0.6, tc.x + (rnd(i) - 0.5) * 60], y: [a.y + Math.sin(i * 1.3) * A.h * 0.3, tc.y + (rnd(i + 3) - 0.5) * 60], r: 26, c: ['#fff3dd', '#d6b98a', '#9b7c4f'], style: 'shard', spin: 1 })
      add({ s: 'particles', t0: 1500, t1: 2100, n: 20, seed: seed + 3, x: tc.x, y: tc.y, sx: 20, sy: 20, v: 220, vy: -150, g: 700, life: 600, mode: 'burst', size: [12, 6], style: 'shard', c: ['#d6b98a', '#9b7c4f'] })
      hit(1500, 1.2, '#9b7c4f')
      back(2000, 60)
      flashAfter(2550)
    },
    hex: () => {
      // Olhos roxos e chamas fantasmas aparecem no alvo; se ele já tem problema de status, a maldição pesa mais.
      cam = [[0, ...NEUTRAL], [400, ...look(tc, 1.45, -2 * toward)], [1600, ...look(tc, 1.5, -3 * toward)]]
      add({ s: 'tint', t0: 150, t1: 1800, color: '#0b0614', a: [0, 0.6] })
      add({ s: 'particles', t0: 300, t1: 1400, n: 6, seed, x: tc.x, y: tc.y, sx: 0, sy: 0, mode: 'orbit', r: T.h * 0.5, life: 1000, size: [24, 20], style: 'wisp', c: ['#ddd6fe', '#7c3aed', '#2e1065'] })
      add({ s: 'ring', t0: 400, t1: 1300, x: tc.x, y: tc.y, r: [T.h * 0.8, 20], ratio: 0.8, w: [2, 8], c: '#a78bfa', a: [0.2, 1], n: 3, spiral: 3 })
      add({ s: 'glow', t0: 1150, t1: 1600, x: tc.x, y: tc.y, r: [20, 160], c: ['#ffffff', '#c4b5fd', '#4c1d95'], a: [1, 0] })
      hit(1200, 1.3, '#4c1d95')
      S.push({ who: 'T', k: 'tint', t0: 1200, t1: 1800, color: '#7c3aed', a: 0.55, pulse: 14 })
      back(1750, 60)
      flashAfter(2300)
    },
    'charge-beam': () => {
      // A energia elétrica junta na frente e sai num raio amarelo grosso; ele fica carregado.
      cam = [[0, ...NEUTRAL], [300, ...look(a, 1.35, 2 * toward)], [850, ...look(a, 1.35, 2 * toward)], [1050, ...look({ x: (a.x + tc.x) / 2, y: (a.y + tc.y) / 2 }, 1.0, 0)], [1300, ...look(tc, 1.45, -2 * toward)]]
      add({ s: 'particles', t0: 250, t1: 950, n: 26, seed, x: front.x, y: front.y, sx: 0, sy: 0, mode: 'converge', r: 170, life: 450, size: [7, 2], style: 'spark', c: ['#ffffff', '#ffe94a'] })
      add({ s: 'glow', t0: 300, t1: 1000, x: front.x, y: front.y, r: [6, 50], c: ['#ffffff', '#fef08a', '#ca8a04'], a: 1, swirl: 1 })
      add({ s: 'beam', t0: 950, t1: 1750, x0: front.x, y0: front.y, x1: tc.x, y1: tc.y, w: [12, 36], c: ['#ffffff', '#fef08a', '#eab308'], a: [1, 0], wobble: 4, grow: 120 })
      add({ s: 'bolt', t0: 1050, t1: 1700, x: tc.x, y: tc.y, r: 120, n: 6, c: '#ffffff', c2: '#ffe94a', w: 3, flicker: 1 })
      hit(1050, 1.2, '#ffe94a')
      S.push({ who: 'A', k: 'tint', t0: 1800, t1: 2300, color: '#ffe94a', a: 0.45, pulse: 30 })
      back(1750, 80)
      flashAfter(2300)
    },
    reflect: () => {
      // Um painel de vidro azul se ergue na frente do seu lado e brilha.
      wall('#93c5fd', '#2563eb')
    },
    'light-screen': () => {
      // Um painel de luz rosa-dourada se ergue na frente do seu lado e brilha.
      wall('#fde68a', '#ec4899')
    },
    agility: () => {
      // Fica leve: imagens rápidas dele aparecem dos lados e a Velocidade sobe muito.
      cam = [[0, ...NEUTRAL], [400, ...look(a, 1.35, 2 * toward)], [1600, ...look(a, 1.4, 2 * toward)]]
      for (let i = 0; i < 4; i++) S.push({ who: 'A', k: 'move', t0: 300 + i * 220, t1: 500 + i * 220, dx: (i % 2 ? -1 : 1) * 60, dy: 0 })
      add({ s: 'particles', t0: 300, t1: 1300, n: 40, seed, x: a.x, y: a.y, sx: A.h * 0.6, sy: A.h * 0.4, v: 600, vy: 0, g: 0, life: 200, mode: 'stream', size: [30, 3], style: 'streak', c: ['#ffffff', '#e0f2fe'] })
      add({ s: 'particles', t0: 1200, t1: 1900, n: 12, seed: seed + 4, x: a.x, y: A.y - A.h * 0.3, sx: A.h * 0.35, sy: 20, v: 0, vy: -240, g: 0, life: 600, mode: 'stream', size: [18, 14], style: 'arrowUp', c: ['#ffffff', '#bae6fd', '#0ea5e9'] })
      S.push({ who: 'A', k: 'tint', t0: 1200, t1: 1900, color: '#38bdf8', a: 0.4, pulse: 14 })
      hud = [100, 1900]
      cam.push([2200, ...NEUTRAL])
      end(2300)
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
export function fxForMove({ slug, type, category, self = false, entry = null, recipe = null, from = 0, seed = 1, stage = FX_STAGE, boosts = null }) {
  const kind = entry?.[0] ?? (category === 'status' ? (self ? 'boost' : 'status') : moveAnim(slug, type, category))
  return fxPlan2({ kind, type, slug, from, seed, recipe, stage, boosts })
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
  let sway = 0
  for (const [t0, t1, f, mode] of plan.shake) {
    if (ms < t0 || ms > t1) continue
    const k = (ms - t0) / (t1 - t0)
    // mode 1: a tela balança para os lados (Earthquake), sobe rápido e acalma no fim.
    if (mode === 1) sway = Math.max(sway, f * Math.min(1, k * 6, (1 - k) * 2.5))
    else amp = Math.max(amp, f * (1 - k))
  }
  if (!amp && !sway) return [0, 0]
  const i = Math.floor(ms / 33)
  const sx = sway * Math.sin((ms / 150) * Math.PI * 2)
  const sy = sway * 0.15 * Math.sin((ms / 75) * Math.PI * 2)
  return [(fxRand(i) - 0.5) * 2 * amp + sx, (fxRand(i + 99) - 0.5) * 2 * amp + sy]
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
