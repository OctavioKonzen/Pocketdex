// Gera as regras dos golpes da batalha (assets/database/move_rules.json) a
// partir dos dados do Pokémon Showdown (pacote npm "pokemon-showdown",
// licença MIT, Copyright (c) Guangcong Luo e colaboradores).
//
// Para cada golpe do nosso banco, o que a batalha sabe fazer:
//   c: estágio de crítico (1 = mais chance)   r: recuo [n, d] do dano causado
//   d: dreno [n, d] do dano causado            h: cura [n, d] da vida máxima
//   s: status que o golpe de status causa (brn, par, psn, tox, slp, frz)
//   b: mudanças de atributo do golpe de status, em quem usa (t: 'self') ou no alvo
//   sb: mudanças em quem usa depois de um golpe de dano (Close Combat, Draco Meteor)
//   x: efeitos secundários [{p: chance, s?: status, b?: atributos no alvo, sb?: em quem usa, f?: 1 recua}]
//   w: clima que o golpe de status começa (rain, sun, sand, hail, snow)
//   ok: 1 = golpe de status que a batalha sabe usar
//
// Uso: node tool/build_move_rules.mjs /caminho/do/package (npm pack pokemon-showdown)

import { readFileSync, writeFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import path from 'node:path'

const pkg = process.argv[2]
if (!pkg) throw new Error('Passe a pasta do pacote pokemon-showdown (npm pack pokemon-showdown && tar xzf ...)')
const require = createRequire(import.meta.url)
const { Moves } = require(path.join(path.resolve(pkg), 'dist/data/moves.js'))
const root = path.dirname(path.dirname(new URL(import.meta.url).pathname))
const ours = JSON.parse(readFileSync(path.join(root, 'assets/database/moves.json'), 'utf8'))
const toId = (s) => s.toLowerCase().replace(/[^a-z0-9]/g, '')
const STATUSES = new Set(['brn', 'par', 'psn', 'tox', 'slp', 'frz'])
const STATS = ['atk', 'def', 'spa', 'spd', 'spe']
const WEATHERS = { raindance: 'rain', sunnyday: 'sun', sandstorm: 'sand', hail: 'hail', snowscape: 'snow' }
const boostsOf = (b) => {
  if (!b) return null
  const out = Object.fromEntries(Object.entries(b).filter(([k, v]) => STATS.includes(k) && v))
  return Object.keys(out).length ? out : null
}

const out = {}
for (const m of [...ours].sort((a, b) => (a.name < b.name ? -1 : 1))) {
  const ps = Moves[toId(m.name)]
  if (!ps || ps.isZ || ps.isMax) continue
  const r = {}
  if (ps.critRatio > 1) r.c = ps.critRatio - 1
  if (ps.recoil) r.r = ps.recoil
  if (ps.drain) r.d = ps.drain
  const secs = ps.secondaries ?? (ps.secondary ? [ps.secondary] : [])
  const x = []
  for (const s of secs) {
    const e = { p: s.chance ?? 100 }
    if (STATUSES.has(s.status)) e.s = s.status
    if (boostsOf(s.boosts)) e.b = boostsOf(s.boosts)
    if (boostsOf(s.self?.boosts)) e.sb = boostsOf(s.self.boosts)
    if (s.volatileStatus === 'flinch') e.f = 1
    if (Object.keys(e).length > 1) x.push(e)
  }
  if (x.length) r.x = x
  if (boostsOf(ps.self?.boosts) && ps.category !== 'Status') r.sb = boostsOf(ps.self.boosts)
  if (ps.category === 'Status') {
    // Só os que a batalha sabe usar: mudar atributos, causar status e curar.
    if (STATUSES.has(ps.status) && ps.target === 'normal') r.s = ps.status
    if (boostsOf(ps.boosts) && ['self', 'normal', 'adjacentFoe', 'allAdjacentFoes', 'adjacentAllyOrSelf'].includes(ps.target)) {
      r.b = boostsOf(ps.boosts)
      if (ps.target === 'self' || ps.target === 'adjacentAllyOrSelf') r.t = 'self'
    }
    if (ps.heal && ps.target === 'self') r.h = ps.heal
    if (['roost', 'moonlight', 'morningsun', 'synthesis', 'shoreup'].includes(ps.id)) r.h = [1, 2]
    // Golpes de clima (Rain Dance, Sunny Day, Sandstorm, Hail, Snowscape).
    if (WEATHERS[toId(ps.weather ?? '')] && ps.target === 'all' && !ps.selfSwitch) {
      r.w = WEATHERS[toId(ps.weather)]
      r.ok = 1
    } else if (r.s || r.b || r.h) {
      // Golpes de status com outras coisas que não fazemos (troca, campo...) ficam de fora.
      const extra = ps.volatileStatus || ps.sideCondition || ps.weather || ps.terrain || ps.pseudoWeather || ps.selfSwitch || ps.forceSwitch
      if (!extra || ps.id === 'roost') r.ok = 1
      else continue
    } else continue
  }
  if (Object.keys(r).length) out[m.name] = r
}
writeFileSync(path.join(root, 'assets/database/move_rules.json'), `${JSON.stringify(out)}\n`)
const status = Object.values(out).filter((r) => r.ok).length
console.log(`${Object.keys(out).length} golpes com regras (${status} de status)`)
