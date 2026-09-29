// Gera, a partir da calculadora do Pokémon Showdown (@smogon/calc, MIT):
//
//   assets/database/damage_data.json  dados que a calculadora do app usa
//                                     (golpes, itens, espécies, Natures, tipos)
//   test/fixtures/damage_cases.json.gz milhares de situações com o resultado
//                                     oficial, para conferir a conta do app
//                                     (test/damage_calc_test.dart)
//
// Uso (na pasta web-site): node scripts/build-damage-data.mjs

import { createRequire } from 'node:module'
import { readFileSync, readdirSync, writeFileSync, mkdirSync } from 'node:fs'
import { gzipSync } from 'node:zlib'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const require = createRequire(import.meta.url)
const { calculate, Field, Generations, Move, Pokemon } = require('@smogon/calc')
const items = require('@smogon/calc/dist/items')

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..')
const gen = Generations.get(9)
const toId = (s) => String(s ?? '').toLowerCase().replace(/[^a-z0-9]/g, '')

// ------------------------------------------------------------------ dados

const moves = {}
for (const m of gen.moves) {
  const stat = m.category === 'Special' ? 'spa' : 'atk'
  const drop = m.self?.boosts?.[stat]
  moves[m.id] = [
    m.name,
    m.type,
    m.category ?? 'Status',
    m.basePower ?? 0,
    m.priority ?? 0,
    m.target ?? 'any',
    Object.keys(m.flags ?? {}).filter((k) => m.flags[k]),
    m.multihit ?? 0,
    // bits: 1 secondaries, 2 recoil, 4 crash, 8 mindBlown, 16 struggle, 32 willCrit, 64 drain,
    // 128 ignoreDefensive, 256 breaksProtect, 512 multiaccuracy, 1024 isZ, 2048 isMax
    (m.secondaries ? 1 : 0) | (m.recoil ? 2 : 0) | (m.hasCrashDamage ? 4 : 0) | (m.mindBlownRecoil ? 8 : 0) |
      (m.struggleRecoil ? 16 : 0) | (m.willCrit ? 32 : 0) | (m.drain ? 64 : 0) | (m.ignoreDefensive ? 128 : 0) |
      (m.breaksProtect ? 256 : 0) | (m.multiaccuracy ? 512 : 0) | (m.isZ ? 1024 : 0) | (m.isMax ? 2048 : 0),
    drop && drop < 0 ? -drop : 0,
    m.overrideDefensiveStat ?? '',
  ]
}

const itemData = {}
for (const it of gen.items) {
  const entry = {}
  const boost = items.getItemBoostType(it.name)
  if (boost) entry.b = boost
  const resist = items.getBerryResistType(it.name)
  if (resist) entry.r = resist
  const fling = items.getFlingPower(it.name, 9)
  if (fling) entry.f = fling
  if (it.naturalGift) entry.g = [it.naturalGift.basePower, it.naturalGift.type]
  if (it.megaStone) entry.m = [...Object.keys(it.megaStone), ...Object.values(it.megaStone)]
  if (it.isBerry) entry.y = 1
  const techno = it.name.includes('Drive') ? items.getTechnoBlast(it.name) : undefined
  if (techno) entry.t = techno
  const multi = it.name.includes('Memory') ? items.getMultiAttack(it.name) : undefined
  if (multi) entry.a = multi
  itemData[it.name] = entry
}

const species = {}
for (const s of gen.species) {
  species[s.id] = [s.name, s.nfe ? 1 : 0, s.gender ?? '', s.abilities?.[0] ?? '']
}

const natures = {}
for (const n of gen.natures) natures[n.name] = [n.plus ?? '', n.minus ?? '']

const types = {}
for (const t of gen.types) types[t.name] = t.effectiveness

const abilities = [...gen.abilities].map((a) => a.name).sort()

const out = { version: 1, moves, items: itemData, species, natures, types, abilities, seedStat: items.SEED_BOOSTED_STAT }
writeFileSync(join(ROOT, 'assets/database/damage_data.json'), JSON.stringify(out))

// ------------------------------------------------------------------ casos de teste

// Gerador aleatório com semente (os casos saem sempre iguais).
let seed = 20260926
const rand = () => {
  // mulberry32
  seed = (seed + 0x6d2b79f5) | 0
  let t = Math.imul(seed ^ (seed >>> 15), 1 | seed)
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296
}
const pick = (list) => list[Math.floor(rand() * list.length)]
const chance = (p) => rand() < p

const DATA = join(ROOT, 'web-site/public/data/pokemon')
const pokemonFiles = readdirSync(DATA).filter((f) => f.endsWith('.json'))
const forms = []
for (const file of pokemonFiles) {
  const sp = JSON.parse(readFileSync(join(DATA, file), 'utf8'))
  for (const f of sp.forms) forms.push(f)
}
const NAMES = new Map([...gen.species].map((s) => [toId(s.name), s.name]))
const speciesName = (slug) => {
  const parts = slug.split('-')
  for (let n = parts.length; n > 0; n--) {
    const name = NAMES.get(toId(parts.slice(0, n).join('-')))
    if (name) return name
  }
  return 'Mew'
}
const cap = (s) => s.charAt(0).toUpperCase() + s.slice(1)
const damaging = [...gen.moves].filter((m) => m.category !== 'Status' && !m.isZ && !m.isMax)
const SPECIAL_MOVES = [
  'Payback', 'Bolt Beak', 'Fishious Rend', 'Pursuit', 'Electro Ball', 'Gyro Ball', 'Punishment', 'Low Kick', 'Grass Knot', 'Hex',
  'Infernal Parade', 'Barb Barrage', 'Heavy Slam', 'Heat Crash', 'Stored Power', 'Power Trip', 'Acrobatics', 'Assurance', 'Wake-Up Slap',
  'Smelling Salts', 'Weather Ball', 'Terrain Pulse', 'Rising Voltage', 'Psyblade', 'Fling', 'Dragon Energy', 'Eruption', 'Water Spout',
  'Flail', 'Reversal', 'Natural Gift', 'Nature Power', 'Water Shuriken', 'Triple Axel', 'Triple Kick', 'Crush Grip', 'Wring Out',
  'Hard Press', 'Tera Blast', 'Facade', 'Brine', 'Venoshock', 'Lash Out', 'Expanding Force', 'Knock Off', 'Misty Explosion', 'Grav Apple',
  'Solar Beam', 'Solar Blade', 'Collision Course', 'Electro Drift', 'Foul Play', 'Body Press', 'Psyshock', 'Psystrike', 'Secret Sword',
  'Photon Geyser', 'Shell Side Arm', 'Seismic Toss', 'Night Shade', 'Super Fang', 'Final Gambit', "Nature's Madness", 'Ruination',
  'Freeze-Dry', 'Flying Press', 'Thousand Arrows', 'Hydro Steam', 'Brick Break', 'Psychic Fangs', 'Raging Bull', 'Ivy Cudgel',
  'Revelation Dance', 'Judgment', 'Multi-Attack', 'Techno Blast', 'Surging Strikes', 'Wicked Blow', 'Population Bomb', 'Scale Shot',
  'Bullet Seed', 'Dragon Darts', 'Bonemerang', 'Draco Meteor', 'Close Combat', 'Earthquake', 'Surf', 'Heat Wave', 'Rock Slide',
  'Moongeist Beam', 'Sunsteel Strike', 'Spectral Thief', 'Power-Up Punch', 'Meteor Beam', 'Steel Roller', 'Poltergeist', 'Dream Eater',
  'Synchronoise', 'Sky Drop', 'Pain Split', 'Tera Starstorm', 'Aura Wheel', 'Fake Out', 'Sucker Punch', 'Extreme Speed', 'Explosion',
  'Rage Fist', 'Last Respects', 'Struggle', 'Hurricane', 'Blizzard', 'Thunder', 'Outrage', 'Leaf Storm', 'U-turn', 'Mach Punch',
  'Iron Head', 'Moonblast', 'Hyper Voice', 'Boomburst', 'Bite', 'Crunch', 'Aura Sphere', 'Dark Pulse', 'Sacred Sword', 'Leaf Blade',
  'Flare Blitz', 'Brave Bird', 'Head Smash', 'Wave Crash', 'High Jump Kick', 'Drain Punch', 'Giga Drain', 'Gigaton Hammer',
]
const ITEMS = [
  '', '', '', 'Choice Band', 'Choice Specs', 'Choice Scarf', 'Life Orb', 'Expert Belt', 'Leftovers', 'Black Sludge', 'Assault Vest',
  'Eviolite', 'Heavy-Duty Boots', 'Air Balloon', 'Iron Ball', 'Booster Energy', 'Muscle Band', 'Wise Glasses', 'Punching Glove',
  'Metronome', 'Charcoal', 'Mystic Water', 'Miracle Seed', 'Magnet', 'Never-Melt Ice', 'Black Belt', 'Poison Barb', 'Soft Sand',
  'Sharp Beak', 'Twisted Spoon', 'Silver Powder', 'Hard Stone', 'Spell Tag', 'Dragon Fang', 'Black Glasses', 'Metal Coat',
  'Silk Scarf', 'Fairy Feather', 'Flame Plate', 'Pixie Plate', 'Normal Gem', 'Fire Gem', 'Water Gem', 'Occa Berry', 'Passho Berry',
  'Yache Berry', 'Chilan Berry', 'Shuca Berry', 'Babiri Berry', 'Roseli Berry', 'Kee Berry', 'Maranga Berry', 'Sitrus Berry',
  'Light Ball', 'Thick Club', 'Deep Sea Tooth', 'Deep Sea Scale', 'Metal Powder', 'Quick Powder', 'Soul Dew', 'Adamant Orb',
  'Lustrous Orb', 'Griseous Orb', 'Utility Umbrella', 'Ring Target', 'Float Stone', 'Macho Brace', 'Power Weight', 'Sticky Barb',
  'Safety Goggles', 'Covert Cloak', 'Clear Amulet', 'White Herb', 'Luminous Moss', 'Electric Seed', 'Grassy Seed', 'Psychic Seed',
  'Misty Seed', 'Ability Shield', 'Wellspring Mask', 'Hearthflame Mask', 'Cornerstone Mask', 'Rusted Sword', 'Big Root',
  'Binding Band', 'Burn Drive', 'Fire Memory', 'Charizardite X', 'Adamant Crystal', 'Griseous Core', 'Loaded Dice', 'Focus Sash',
]
const ABILITIES = [
  'Adaptability', 'Huge Power', 'Pure Power', 'Hustle', 'Guts', 'Technician', 'Tough Claws', 'Iron Fist', 'Strong Jaw', 'Mega Launcher',
  'Sharpness', 'Reckless', 'Sheer Force', 'Solar Power', 'Sand Force', 'Water Bubble', 'Transistor', "Dragon's Maw", 'Steelworker',
  'Rocky Payload', 'Aerilate', 'Pixilate', 'Refrigerate', 'Galvanize', 'Normalize', 'Liquid Voice', 'Tinted Lens', 'Sniper', 'Analytic',
  'Punk Rock', 'Flare Boost', 'Toxic Boost', 'Blaze', 'Torrent', 'Overgrow', 'Swarm', 'Gorilla Tactics', 'Supreme Overlord',
  'Orichalcum Pulse', 'Hadron Engine', 'Protosynthesis', 'Quark Drive', 'Sword of Ruin', 'Beads of Ruin', 'Tablets of Ruin',
  'Vessel of Ruin', 'Scrappy', "Mind's Eye", 'Stakeout', 'Neuroforce', 'Fairy Aura', 'Dark Aura', 'Aura Break', 'Steely Spirit',
  'Parental Bond', 'Skill Link', 'Mold Breaker', 'Teravolt', 'Turboblaze', 'Multiscale', 'Shadow Shield', 'Filter', 'Solid Rock',
  'Prism Armor', 'Thick Fat', 'Heatproof', 'Fur Coat', 'Ice Scales', 'Fluffy', 'Purifying Salt', 'Levitate', 'Flash Fire',
  'Water Absorb', 'Volt Absorb', 'Dry Skin', 'Storm Drain', 'Lightning Rod', 'Sap Sipper', 'Motor Drive', 'Earth Eater',
  'Well-Baked Body', 'Wind Rider', 'Bulletproof', 'Soundproof', 'Wonder Guard', 'Marvel Scale', 'Grass Pelt', 'Tera Shell',
  'Unaware', 'Intimidate', 'Download', 'Simple', 'Contrary', 'Defiant', 'Competitive', 'Clear Body', 'Infiltrator', 'Klutz',
  'Neutralizing Gas', 'Battle Armor', 'Merciless', 'Air Lock', 'Cloud Nine', 'Slow Start', 'Defeatist', 'Plus', 'Stamina',
  'Weak Armor', 'Water Compaction', 'Heavy Metal', 'Light Metal', 'Protean', 'Libero', 'Magic Guard', 'Poison Heal', 'Rain Dish',
  'Ice Body', 'Overcoat', 'Sand Rush', 'Chlorophyll', 'Swift Swim', 'Quick Feet', 'Unburden', 'Rivalry', 'Triage', 'Gale Wings',
  'Queenly Majesty', 'Dazzling', 'Armor Tail', 'Long Reach', 'Ripen', 'Unnerve', 'Mummy', 'Electromorphosis', 'Intrepid Sword',
  'Dauntless Shield', 'Friend Guard', 'Flower Gift', 'Forecast', 'Teraform Zero', 'Seed Sower', 'Sand Spit', 'Comatose', 'Bad Dreams',
  'Mountaineer', 'Guard Dog', 'Embody Aspect (Wellspring)', 'Embody Aspect (Hearthflame)', 'Unseen Fist', 'Prankster', 'Mega Sol',
]
const TYPES = ['Normal', 'Fire', 'Water', 'Electric', 'Grass', 'Ice', 'Fighting', 'Poison', 'Ground', 'Flying', 'Psychic', 'Bug', 'Rock', 'Ghost', 'Dragon', 'Dark', 'Steel', 'Fairy', 'Stellar']
const NATURE_LIST = [...gen.natures].map((n) => n.name)
const STATS = ['hp', 'atk', 'def', 'spa', 'spd', 'spe']
const STATUS = ['', '', '', 'brn', 'par', 'psn', 'tox', 'slp', 'frz']

function randomSide(form) {
  const evs = {}
  let left = 510
  for (const s of STATS) {
    const v = chance(0.4) ? pick([0, 4, 252, 252, 128, 36, 100]) : 0
    evs[s] = Math.min(v, left)
    left -= evs[s]
  }
  const ivs = {}
  for (const s of STATS) ivs[s] = chance(0.9) ? 31 : Math.floor(rand() * 32)
  const boosts = {}
  for (const s of STATS.slice(1)) boosts[s] = chance(0.2) ? Math.floor(rand() * 13) - 6 : 0
  const own = form.abilities.map(([slug]) => slug)
  const ability = chance(0.55)
    ? pick(ABILITIES)
    : (gen.abilities.get(toId(pick(own)))?.name ?? pick(ABILITIES))
  return {
    species: speciesName(form.name),
    baseStats: Object.fromEntries(STATS.map((s, i) => [s, form.stats[i][0]])),
    types: form.types.map(cap),
    weightkg: form.weight / 10,
    level: pick([50, 50, 100, 100, 5, 37, 80]),
    nature: pick(NATURE_LIST),
    ability,
    abilityOn: chance(0.4),
    item: pick(ITEMS),
    teraType: chance(0.25) ? pick(TYPES) : '',
    status: pick(STATUS),
    hpPct: chance(0.3) ? Math.ceil(rand() * 100) : 100,
    evs,
    ivs,
    boosts,
    alliesFainted: chance(0.2) ? Math.floor(rand() * 6) : 0,
    toxicCounter: chance(0.1) ? Math.floor(rand() * 5) : 0,
  }
}

function randomField() {
  const f = () => chance(0.12)
  return {
    gameType: chance(0.3) ? 'Doubles' : 'Singles',
    weather: chance(0.35) ? pick(['Sun', 'Rain', 'Sand', 'Snow', 'Hail', 'Harsh Sunshine', 'Heavy Rain', 'Strong Winds']) : '',
    terrain: chance(0.3) ? pick(['Electric', 'Grassy', 'Psychic', 'Misty']) : '',
    isGravity: f(),
    isMagicRoom: chance(0.05),
    isWonderRoom: chance(0.05),
    isSwordOfRuin: chance(0.05),
    isBeadsOfRuin: chance(0.05),
    isTabletsOfRuin: chance(0.05),
    isVesselOfRuin: chance(0.05),
    isFairyAura: chance(0.05),
    isDarkAura: chance(0.05),
    isAuraBreak: chance(0.05),
    attackerSide: {
      isHelpingHand: f(), isBattery: f(), isPowerSpot: f(), isSteelySpirit: f(), isFlowerGift: f(), isCharge: f(), isTailwind: f(),
      isSeeded: chance(0.05), isPowerTrick: chance(0.03), isForesight: false, isReflect: false, isLightScreen: false, isAuroraVeil: false,
      isFriendGuard: false, isSR: false, spikes: 0, isSaltCured: false, isProtected: false,
    },
    defenderSide: {
      isReflect: f(), isLightScreen: f(), isAuroraVeil: chance(0.06), isFriendGuard: f(), isSR: chance(0.2),
      spikes: chance(0.2) ? Math.ceil(rand() * 3) : 0, isSaltCured: chance(0.08), isSeeded: chance(0.08), isProtected: chance(0.04),
      isTailwind: f(), isForesight: chance(0.05), isNightmared: chance(0.03), isPowerTrick: chance(0.03),
      isSwitching: chance(0.05) ? 'out' : undefined, isHelpingHand: false, isBattery: false, isPowerSpot: false, isSteelySpirit: false,
      isFlowerGift: chance(0.05), isCharge: false,
    },
  }
}

function makePokemon(side) {
  const opts = {
    level: side.level,
    nature: side.nature,
    ability: side.ability || undefined,
    abilityOn: side.abilityOn,
    item: side.item || undefined,
    teraType: side.teraType || undefined,
    status: side.status,
    evs: side.evs,
    ivs: side.ivs,
    boosts: side.boosts,
    alliesFainted: side.alliesFainted,
    toxicCounter: side.toxicCounter,
    overrides: { baseStats: side.baseStats, types: side.types, weightkg: side.weightkg },
  }
  if (side.ability === 'Protosynthesis' || side.ability === 'Quark Drive') opts.boostedStat = side.abilityOn ? 'auto' : undefined
  const p = new Pokemon(gen, side.species, opts)
  p.originalCurHP = Math.max(1, Math.floor((p.maxHP() * side.hpPct) / 100))
  return p
}

const cases = []
let attempts = 0
while (cases.length < 6000 && attempts < 60000) {
  attempts++
  const aForm = pick(forms)
  const dForm = pick(forms)
  const attacker = randomSide(aForm)
  const defender = randomSide(dForm)
  const learned = aForm.moves.map((m) => gen.moves.get(toId(m[0]))).filter((m) => m && m.category !== 'Status' && !m.isZ && !m.isMax)
  const moveName = chance(0.45) ? pick(SPECIAL_MOVES) : learned.length && chance(0.6) ? pick(learned).name : pick(damaging).name
  const moveOpts = {
    isCrit: chance(0.12),
    isStellarFirstUse: chance(0.5),
    ability: attacker.ability,
    item: attacker.item,
  }
  const data = gen.moves.get(toId(moveName))
  if (!data) continue
  if (Array.isArray(data.multihit) && chance(0.5)) moveOpts.hits = data.multihit[0] + Math.floor(rand() * (data.multihit[1] - data.multihit[0] + 1))
  if (chance(0.08)) moveOpts.timesUsed = 2 + Math.floor(rand() * 3)
  if (attacker.item === 'Metronome' && chance(0.6)) moveOpts.timesUsedWithMetronome = 1 + Math.floor(rand() * 6)
  const field = randomField()
  let result
  try {
    result = calculate(gen, makePokemon(attacker), makePokemon(defender), new Move(gen, data.name, moveOpts), new Field(field))
  } catch {
    continue
  }
  const raw = result.damage
  const damage = typeof raw === 'number' ? [[raw]] : typeof raw[0] === 'number' ? (raw.length >= 16 ? [raw] : raw.map((x) => [x])) : raw.map((x) => (typeof x === 'number' ? [x] : x))
  let ko = null
  const log = console.log
  console.log = () => {} // a biblioteca avisa quando não há dano
  try {
    const k = result.kochance(false)
    ko = [k.chance ?? -1, k.n, k.text]
  } catch {
    ko = null
  }
  console.log = log
  const [min, max] = (() => {
    try {
      return result.range()
    } catch {
      return [0, 0]
    }
  })()
  cases.push({
    a: attacker,
    d: defender,
    m: { name: data.name, isCrit: moveOpts.isCrit, isStellarFirstUse: moveOpts.isStellarFirstUse, hits: moveOpts.hits, timesUsed: moveOpts.timesUsed, timesUsedWithMetronome: moveOpts.timesUsedWithMetronome },
    f: field,
    out: { damage, min, max, ko, hits: result.move.hits, spe: [result.attacker.stats.spe, result.defender.stats.spe] },
  })
}

mkdirSync(join(ROOT, 'test/fixtures'), { recursive: true })
writeFileSync(join(ROOT, 'test/fixtures/damage_cases.json.gz'), gzipSync(JSON.stringify(cases), { level: 9 }))
console.log(`damage_data.json: ${Object.keys(moves).length} golpes, ${Object.keys(itemData).length} itens; ${cases.length} casos de teste`)
