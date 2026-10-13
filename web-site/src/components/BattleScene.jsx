// O cenário da batalha: o campo clássico (faixas e duas bases) nas cores do
// lugar, com o que tem nele desenhado atrás: prédios na cidade, árvores na
// floresta, estalactites na caverna, ondas no mar, montanhas, vulcão, neve,
// torre, nuvens. O clima (chuva, sol...) muda as cores do céu e do chão.
// Igual ao app (lib/widgets/battle_scene.dart).

import { spriteUrl } from '../lib/data'

/** As cores de cada lugar: [céu, chão, base escura, base clara]. 'grass' é o campo de sempre. */
export const SCENE_COLORS = {
  grass: ['#b9e6bd', '#edf9c8', '#7eba62', '#a9d57b'],
  forest: ['#9fd39a', '#d3ebb4', '#4f8a3c', '#6fae4f'],
  water: ['#9fdcff', '#5fb4e8', '#2f74b5', '#5aa0dc'],
  cave: ['#5b5147', '#a89c8a', '#6b5f52', '#8a7d6d'],
  mountain: ['#c9d3dc', '#e7e2d4', '#8f8a80', '#aba497'],
  volcano: ['#f3b38a', '#f7d9b5', '#b4532a', '#d0743e'],
  city: ['#c7d2fe', '#e2e8f0', '#94a3b8', '#b6c2d1'],
  snow: ['#dbeafe', '#f8fafc', '#a5c3dd', '#cfe0ef'],
  tower: ['#a78bfa', '#ddd6fe', '#7c6ba8', '#9d8cc9'],
  sky: ['#bae6fd', '#f0f9ff', '#cbd5e1', '#e2e8f0'],
  center: ['#fbcfe8', '#fdf2f8', '#f472b6', '#f9a8d4'],
  over: ['#94a3b8', '#cbd5e1', '#64748b', '#94a3b8'],
}
const WEATHER_COLORS = { rain: ['#a1bac4', '#d6e3d6'], sun: ['#ffe4a1', '#e8f6b6'], sand: ['#d1bd96', '#eee2ad'], hail: ['#bacbd8', '#eef5e3'], snow: ['#bacbd8', '#eef5e3'] }

/** O que tem no lugar, atrás das bases (coordenadas do campo: 160 × 100). */
function Scenery({ scene }) {
  if (scene === 'city') {
    const blocks = [[0, 14, 22], [16, 10, 30], [28, 16, 18], [46, 12, 26], [60, 18, 34], [80, 10, 22], [92, 16, 28], [110, 12, 20], [124, 18, 32], [144, 16, 24]]
    return (
      <g>
        {blocks.map(([x, w, h]) => (
          <g key={x}>
            <rect x={x} y={40 - h} width={w} height={h} fill="#94a3b8" opacity="0.75" />
            {Array.from({ length: Math.floor(h / 6) }, (_, r) => Array.from({ length: Math.floor(w / 5) }, (_, c) => (
              <rect key={`${r}-${c}`} x={x + 1.5 + c * 5} y={40 - h + 2 + r * 6} width="2" height="2.5" fill="#fef9c3" opacity="0.8" />
            )))}
          </g>
        ))}
        <rect y="40" width="160" height="3" fill="#64748b" opacity="0.6" />
      </g>
    )
  }
  if (scene === 'forest') {
    const trees = [4, 16, 27, 40, 52, 66, 79, 92, 104, 117, 129, 142, 154]
    return (
      <g>
        {trees.map((x, i) => (
          <g key={x}>
            <polygon points={`${x - 7},${42 - (i % 3) * 3} ${x},${18 - (i % 3) * 4} ${x + 7},${42 - (i % 3) * 3}`} fill={i % 2 ? '#2f6b2a' : '#3f7d32'} />
            <rect x={x - 1} y={41 - (i % 3) * 3} width="2" height="4" fill="#5b3a1e" />
          </g>
        ))}
      </g>
    )
  }
  if (scene === 'cave') {
    return (
      <g>
        <rect width="160" height="12" fill="#3f372f" />
        {Array.from({ length: 16 }, (_, i) => (
          <polygon key={i} points={`${i * 10},12 ${i * 10 + 5},${18 + (i % 3) * 5} ${i * 10 + 10},12`} fill="#3f372f" />
        ))}
        {[[20, 60, 6], [70, 64, 4], [140, 58, 7]].map(([x, y, r]) => <ellipse key={x} cx={x} cy={y} rx={r * 1.6} ry={r} fill="#6b5f52" opacity="0.7" />)}
      </g>
    )
  }
  if (scene === 'water') {
    return (
      <g>
        <rect y="38" width="160" height="62" fill="#3b8fd4" opacity="0.55" />
        {Array.from({ length: 9 }, (_, r) => Array.from({ length: 8 }, (_, c) => (
          <path key={`${r}-${c}`} d={`M${c * 20 + (r % 2) * 10} ${42 + r * 6.5} q3 -2 6 0 t6 0`} stroke="#fff" strokeWidth="0.6" fill="none" opacity="0.6" />
        )))}
      </g>
    )
  }
  if (scene === 'mountain' || scene === 'volcano') {
    const volcano = scene === 'volcano'
    return (
      <g>
        <polygon points="-10,42 30,8 70,42" fill={volcano ? '#7c2d12' : '#8f8a80'} opacity="0.8" />
        <polygon points="50,42 100,2 150,42" fill={volcano ? '#9a3412' : '#a8a29e'} opacity="0.85" />
        <polygon points="120,42 150,16 180,42" fill={volcano ? '#7c2d12' : '#8f8a80'} opacity="0.8" />
        {volcano ? (
          <>
            <polygon points="92,8 100,2 108,8" fill="#f97316" />
            {[[100, -4, 6], [106, -10, 5], [96, -14, 4]].map(([x, y, r]) => <circle key={y} cx={x} cy={y + 4} r={r} fill="#57534e" opacity="0.5" />)}
          </>
        ) : (
          <>
            <polygon points="22,15 30,8 38,15" fill="#fff" />
            <polygon points="90,10 100,2 110,10" fill="#fff" />
          </>
        )}
      </g>
    )
  }
  if (scene === 'snow') {
    return (
      <g>
        <ellipse cx="30" cy="42" rx="45" ry="12" fill="#fff" opacity="0.9" />
        <ellipse cx="120" cy="40" rx="55" ry="14" fill="#fff" opacity="0.9" />
        {Array.from({ length: 30 }, (_, i) => <circle key={i} cx={(i * 37) % 160} cy={(i * 23) % 40} r="0.8" fill="#fff" />)}
      </g>
    )
  }
  if (scene === 'tower') {
    return (
      <g>
        {[10, 40, 120, 150].map((x) => (
          <g key={x}>
            <rect x={x - 4} y="6" width="8" height="38" fill="#5b4b8a" opacity="0.8" />
            <rect x={x - 6} y="4" width="12" height="3" fill="#4c3d7a" />
          </g>
        ))}
        {[[60, 40], [80, 42], [100, 40]].map(([x, y]) => <rect key={x} x={x - 3} y={y - 7} width="6" height="8" rx="3" fill="#6d5ba3" opacity="0.7" />)}
      </g>
    )
  }
  if (scene === 'sky') {
    return (
      <g>
        {[[20, 14, 12], [70, 8, 16], [130, 18, 13], [100, 30, 9]].map(([x, y, r]) => (
          <g key={x} fill="#fff" opacity="0.9">
            <ellipse cx={x} cy={y} rx={r} ry={r * 0.45} />
            <ellipse cx={x + r * 0.6} cy={y - 2} rx={r * 0.6} ry={r * 0.4} />
          </g>
        ))}
      </g>
    )
  }
  if (scene === 'center') {
    return (
      <g>
        <rect x="64" y="8" width="32" height="30" rx="3" fill="#fff" opacity="0.8" />
        <rect x="77" y="13" width="6" height="18" fill="#ef4444" />
        <rect x="71" y="19" width="18" height="6" fill="#ef4444" />
      </g>
    )
  }
  return null
}

/** O campo da batalha no lugar (scene) e no clima (weather). */
/**
 * As bases dos dois lados: [cx, cy, rx, ry] no campo (160 × 100). 'bw': como
 * no Black & White (a do adversário lá atrás à direita, a sua grande na frente
 * à esquerda, cortada pela caixa do texto); 'classic': o campo de antes.
 */
export const PLATFORMS = {
  classic: { foe: [120, 45, 32, 8], mine: [38, 91, 42, 12] },
  // Iguais às das imagens dos cenários (sprites/battle/<lugar>.webp).
  bw: { foe: [122, 40, 38, 6.5], mine: [74, 80, 84, 20] },
}

/**
 * Os lugares que têm imagem (sprites/battle/<lugar>.webp, feitas por
 * tool/battle_backgrounds.py, sem as bases: PlatformBase põe uma embaixo de cada
 * Pokémon) e a versão de cada clima (sprites/battle-weather/<lugar>-sun/rain/sand/snow.webp):
 * Sunny Day, Rain Dance... mudam o cenário. Igual ao app.
 */
export const SCENE_IMAGES = ['grass', 'forest', 'water', 'beach', 'underwater', 'swamp', 'sewer', 'cave', 'icecave', 'mountain', 'desert', 'volcano', 'snow', 'city', 'sky', 'tower', 'gym', 'league', 'center']
const usable = (scene) => (SCENE_IMAGES.includes(scene) || SCENE_COLORS[scene] ? scene : 'grass')
/** O clima na imagem (o granizo usa a de neve). */
const WEATHER_IMAGE = { sun: 'sun', rain: 'rain', sand: 'sand', hail: 'snow', snow: 'snow' }
/** Batalha comum (sem lugar): um destes, sorteado pela semente. */
const OUTDOOR = ['grass', 'forest', 'water', 'beach', 'swamp', 'cave', 'icecave', 'mountain', 'desert', 'volcano', 'snow', 'city', 'sky']
/** O cenário da batalha: o do lugar (a rota da Battle Factory, o ginásio, a Liga) ou, numa batalha comum, um sorteado. Igual ao app. */
export function battleScene(scene, seed) {
  return usable(scene || OUTDOOR[Math.abs(Number(seed) || 0) % OUTDOOR.length])
}

/** Líder de ginásio no ginásio; Elite Four e Campeão na Liga. */
export const sceneOfBoss = (kind) => (kind === 'gym' ? 'gym' : kind === 'elite' || kind === 'champion' || kind === 'league' ? 'league' : null)

/**
 * O tamanho na batalha pela altura do Pokémon (decímetros), como nos jogos:
 * um Joltik bem pequeno, um Pikachu pequeno, um Charizard quase do tamanho do
 * espaço e os gigantes (Wailord, Gigantamax) ocupando tudo. Igual ao app.
 */
export const battleScale = (height) => Math.min(1, Math.max(0.3, Math.sqrt((height ?? 10) / 20)))

/**
 * Onde ficam os pés do adversário em cada lugar (fração da altura do campo):
 * um pouco para dentro do chão de cada cenário (tool/battle_backgrounds.py,
 * foe_feet), para a base dele ficar no chão e não voando. Igual ao app.
 */
export const GROUND_FEET = { grass: 0.487, forest: 0.506, water: 0.487, beach: 0.508, underwater: 0.527, swamp: 0.487, sewer: 0.54, cave: 0.519, icecave: 0.519, mountain: 0.492, desert: 0.495, volcano: 0.5, snow: 0.487, city: 0.548, sky: 0.45, tower: 0.527, gym: 0.527, league: 0.527, center: 0.527 }
/** A distância do pé do adversário até a borda de baixo do campo (fração), para o "bottom" da caixa dele. */
export const foeBottom = (scene) => 1 - (GROUND_FEET[scene] ?? 0.45)

/** Largura da base (fração da caixa do Pokémon) pelo tamanho dele: centralizada nele e do tamanho dele. Igual ao app. */
export const baseWidth = (scale) => 0.55 + 0.85 * scale

/**
 * A base embaixo do Pokémon (sprites/battle/<lugar>-base-<foe|mine>.webp, com a
 * cor do chão do lugar): o meio dela nos pés dele e a largura pelo tamanho
 * dele. Fica dentro da caixa (quadrada) do Pokémon, antes dele.
 */
export function PlatformBase({ scene, side, scale = 1 }) {
  if (!SCENE_IMAGES.includes(scene)) return null
  return (
    <img
      src={spriteUrl(`battle/${scene}-base-${side}.webp`)}
      alt=""
      aria-hidden="true"
      className="pixelated pointer-events-none absolute left-1/2 max-w-none"
      style={{ width: `${baseWidth(scale) * 100}%`, bottom: '2.5%', transform: 'translate(-50%, 50%)' }}
      data-testid={`base-${side}`}
    />
  )
}

export function BattleBackground({ weather = '', scene = 'grass', layout = 'classic' }) {
  const { foe, mine } = PLATFORMS[layout] ?? PLATFORMS.classic
  if (layout === 'bw' && SCENE_IMAGES.includes(scene)) {
    // A do clima por cima da normal, aparecendo devagar quando o golpe muda o clima.
    const sky = WEATHER_IMAGE[weather]
    return (
      <div className="pointer-events-none absolute inset-0" aria-hidden="true" data-scene={scene} data-weather={sky ?? ''}>
        <img src={spriteUrl(`battle/${scene}.webp`)} alt="" className="pixelated absolute inset-0 h-full w-full object-fill" />
        {Object.values(WEATHER_IMAGE).filter((w, i, all) => all.indexOf(w) === i).map((w) => (
          <img key={w} src={spriteUrl(`battle-weather/${scene}-${w}.webp`)} alt="" loading="lazy" className="pixelated absolute inset-0 h-full w-full object-fill transition-opacity duration-700" style={{ opacity: sky === w ? 1 : 0 }} />
        ))}
      </div>
    )
  }
  const [skyTop, ground, dark, light] = SCENE_COLORS[scene] ?? SCENE_COLORS.grass
  const [top, bottom] = WEATHER_COLORS[weather] ?? [skyTop, ground]
  const id = `scene-${scene}-${weather || 'clear'}`
  return (
    <svg className="pointer-events-none absolute inset-0 h-full w-full" viewBox="0 0 160 100" preserveAspectRatio="none" aria-hidden="true" data-scene={scene}>
      <defs>
        <linearGradient id={id} x1="0" y1="0" x2="0" y2="1">
          <stop stopColor={top} />
          <stop offset="1" stopColor={bottom} />
        </linearGradient>
      </defs>
      <rect width="160" height="100" fill={`url(#${id})`} />
      <Scenery scene={scene} />
      {Array.from({ length: 50 }, (_, i) => <rect key={i} y={i * 2} width="160" height="0.4" fill="#fff" opacity="0.2" />)}
      {[foe, mine].map(([cx, cy, rx, ry]) => (
        <g key={cx}>
          <ellipse cx={cx} cy={cy} rx={rx} ry={ry} fill={dark} />
          <ellipse cx={cx} cy={cy - ry * 0.15} rx={rx * 0.91} ry={ry * 0.75} fill={light} />
        </g>
      ))}
    </svg>
  )
}
