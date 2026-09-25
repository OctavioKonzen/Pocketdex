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

/** Pré-carrega detalhes (ex.: ao passar o mouse sobre um card). */
export function prefetchSpecies(id) {
  getSpecies(id).catch(() => {})
}
