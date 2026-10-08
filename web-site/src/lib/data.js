// Acesso ao banco local do site (arquivos gerados por tool/build_web_data.py).
// Cada arquivo é baixado uma vez e fica em cache na memória.

const BASE = import.meta.env.BASE_URL

const cache = new Map()

function load(path) {
  if (!cache.has(path)) {
    const request = fetch(`${BASE}data/${path}`).then((res) => {
      if (!res.ok) throw new Error(`Falha ao carregar ${path}`)
      return res.json()
    })
    request.catch(() => cache.delete(path))
    cache.set(path, request)
  }
  return cache.get(path)
}

/** URL de uma imagem do banco (ex.: "pokemon/25.png"). */
/** Caminho do sprite shiny de um sprite normal ("pokemon/6.png" → "pokemon/shiny/6.png"). */
export const shinyPath = (path) => (path ? path.replace(/^pokemon\/(?!shiny\/)/, 'pokemon/shiny/') : path)

/**
 * Foto de perfil: o id do Pokémon (formas têm id próprio); shiny = id + SHINY_AVATAR
 * (igual ao app, lib/services/user_data.dart).
 */
export const SHINY_AVATAR = 100000
/** Foto de perfil de treinador: TRAINER_AVATAR + a posição dele em trainers.json. */
export const TRAINER_AVATAR = 1000000
export const avatarOf = (value) =>
  value == null ? null : value >= TRAINER_AVATAR ? { trainer: value - TRAINER_AVATAR } : { id: value % SHINY_AVATAR, shiny: value >= SHINY_AVATAR }

/** Sprite do membro do time: shiny se marcado no set. */
export const memberSprite = (p, set) => (set?.shiny ? shinyPath(p.sprite) : p.sprite)

export function spriteUrl(path) {
  if (!path) return null
  // As artes oficiais estão em WebP no banco.
  const file = path.startsWith('pokemon/other/official-artwork/') ? path.replace(/\.png$/, '.webp') : path
  return `${BASE}sprites/${file}`
}

export const imageUrl = (name) => `${BASE}img/${name}`
export const loaderUrl = `${BASE}pika_loader.gif`

/** Todos os Pokémon e formas: {id, name, species, default, gen, types, sprite}. */
export const getPokemonIndex = () => load('pokemon_index.json')

/** Pokémon padrão de cada espécie, em ordem da Pokédex nacional. */
export async function getPokedex() {
  const index = await getPokemonIndex()
  return index.filter((p) => p.default)
}

export async function getPokemonById() {
  const index = await getPokemonIndex()
  return new Map(index.map((p) => [p.id, p]))
}

/** Detalhes de uma espécie (formas, golpes, evolução...). */
export const getSpecies = (id) => load(`pokemon/${id}.json`)

export const getMoves = () => load('moves.json')
export const getMoveLearners = () => load('move_learners.json')
export const getAbilities = () => load('abilities.json')
export const getItems = () => load('items.json')
export const getTypes = () => load('types.json')
export const getEggGroups = () => load('egg_groups.json')
/** Nomes dos locais de encontro: {área: {name, names: {fr, es}, region}}. */
export const getLocations = () => load('locations.json')
/** Áreas com Pokémon em cada jogo: {jogo: [área]} (Nuzlocke). */
export const getGameAreas = () => load('game_areas.json')

/** Sets prontos: {id do Pokémon: [set + tier]} (Pokémon Showdown, tool/build_sets.py). */
export const getReadySets = () => load('sets.json')
/** Animação de cada golpe na batalha: {slug: [estilo, símbolo, variação]} (tool/build_move_anims.py). */
export const getMoveAnims = () => load('move_anims.json')
/** Regras dos golpes na batalha (efeitos, recuo, dreno, status...): {slug: {...}} (tool/build_move_rules.mjs). */
export const getMoveRules = () => load('move_rules.json')
/** Quais Pokémon têm sprite animado: {front: [ids], shiny: [ids]} (tool/fetch_animated_sprites.py). */
/** Mega Pedras ({id: forma Mega}) e Cristais Z ({id: tipo}) da batalha (tool/build_battle_items.mjs). */
export const getBattleItems = () => load('battle_items.json')

export const getAnimatedSprites = () => load('animated_sprites.json')
/** Treinadores (batalha e foto de perfil): tool/build_trainers.py. */
export const getTrainers = () => load('trainers.json')
/** Líderes de ginásio, Elite Four e campeões com os times originais: tool/build_gym_leaders.py. */
export const getGymLeaders = () => load('gym_leaders.json')
/** Battle Factory: XP base, força, raridade e evoluções de cada espécie (tool/build_factory_data.py). */
export const getFactoryData = () => load('factory.json')
/** Times oficiais dos personagens, por jogo: tool/build_official_teams.py. */
export const getOfficialTeams = () => load('official_teams.json')

/** Grito da espécie (arquivo do banco, não da PokeAPI). */
export const cryUrl = (speciesId) => `${BASE}cries/${speciesId}.mp3`

/** Pré-carrega detalhes (ex.: ao passar o mouse sobre um card). */
export function prefetchSpecies(id) {
  getSpecies(id).catch(() => {})
}

export const getNpcSets = () => load('npc_sets.json')
