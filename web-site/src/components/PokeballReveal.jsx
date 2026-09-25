// Animação do Pokémon saindo da Pokébola: a Pokébola cai, balança, abre com
// um clarão e o Pokémon sai crescendo (primeiro branco, depois colorido).
// Troque a `key` do componente para repetir a animação.

import { m } from 'framer-motion'

const TIMES = { drop: 0.35, wiggle: 0.35, open: 0.2 }
const OPEN_AT = TIMES.drop + TIMES.wiggle

function Pokeball({ size }) {
  return (
    <m.svg
      viewBox="0 0 100 100"
      width={size}
      height={size}
      className="absolute"
      initial={{ y: -160, opacity: 1, rotate: 0 }}
      animate={{
        y: [-160, 0, -18, 0, 0, 0, 0, 0],
        rotate: [0, 0, 0, 0, -18, 14, -8, 0],
        opacity: [1, 1, 1, 1, 1, 1, 1, 0],
      }}
      transition={{ duration: OPEN_AT + TIMES.open, times: [0, 0.25, 0.33, 0.42, 0.55, 0.66, 0.76, 1], ease: 'easeOut' }}
    >
      <circle cx="50" cy="50" r="46" fill="#fff" stroke="#222" strokeWidth="6" />
      <m.g
        style={{ originX: '4px', originY: '50px' }}
        initial={{ rotate: 0 }}
        animate={{ rotate: -60 }}
        transition={{ delay: OPEN_AT, duration: TIMES.open }}
      >
        <path d="M4 50a46 46 0 0 1 92 0z" fill="#E3350D" stroke="#222" strokeWidth="6" />
      </m.g>
      <line x1="4" y1="50" x2="96" y2="50" stroke="#222" strokeWidth="6" />
      <circle cx="50" cy="50" r="14" fill="#222" />
      <circle cx="50" cy="50" r="8" fill="#fff" />
    </m.svg>
  )
}

export default function PokeballReveal({ children, ballSize = 100 }) {
  return (
    <div className="relative flex h-full w-full items-center justify-center">
      {/* Pokémon saindo */}
      <m.div
        className="flex h-full w-full items-center justify-center"
        initial={{ scale: 0, filter: 'brightness(0) invert(1)' }}
        animate={{ scale: [0, 1.12, 1], filter: ['brightness(0) invert(1)', 'brightness(0) invert(1)', 'brightness(1) invert(0)'] }}
        transition={{ delay: OPEN_AT, duration: 0.9, times: [0, 0.5, 1], ease: 'easeOut' }}
      >
        {children}
      </m.div>
      {/* Clarão */}
      <m.div
        className="pointer-events-none absolute rounded-full"
        style={{ width: ballSize, height: ballSize, background: 'radial-gradient(circle, rgba(255,255,255,.95), rgba(255,255,255,0) 70%)' }}
        initial={{ scale: 0, opacity: 0 }}
        animate={{ scale: [0, 5], opacity: [0, 1, 0] }}
        transition={{ delay: OPEN_AT, duration: 0.6, ease: 'easeOut' }}
      />
      <Pokeball size={ballSize} />
    </div>
  )
}
