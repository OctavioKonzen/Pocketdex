// O cenário da batalha: o campo clássico (faixas e duas bases) nas cores do
// lugar, com o que tem nele desenhado atrás: prédios na cidade, árvores na
// floresta, estalactites na caverna, ondas no mar, montanhas, vulcão, neve,
// torre, nuvens. O clima (chuva, sol...) muda as cores do céu e do chão.
// Igual ao app (lib/widgets/battle_scene.dart).

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
export function BattleBackground({ weather = '', scene = 'grass' }) {
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
      <ellipse cx="120" cy="45" rx="32" ry="8" fill={dark} />
      <ellipse cx="120" cy="44" rx="29" ry="6" fill={light} />
      <ellipse cx="38" cy="91" rx="42" ry="12" fill={dark} />
      <ellipse cx="38" cy="89" rx="39" ry="9" fill={light} />
    </svg>
  )
}
