// Onde encontrar cada Pokémon (dados do banco local: encounters e locations,
// gerados por tool/add_encounters_and_cries.py). Os mesmos nomes no app.

/** Como o Pokémon aparece (método da PokeAPI → texto). */
export const METHODS = {
  walk: 'Andando na grama',
  'dark-grass': 'Grama escura',
  'grass-spots': 'Grama balançando',
  'cave-spots': 'Poeira na caverna',
  'bridge-spots': 'Sombra na ponte',
  'rough-terrain': 'Terreno acidentado',
  'yellow-flowers': 'Flores amarelas',
  'purple-flowers': 'Flores roxas',
  'red-flowers': 'Flores vermelhas',
  surf: 'Surfando',
  'surf-spots': 'Água ondulando',
  'old-rod': 'Vara velha',
  'good-rod': 'Vara boa',
  'super-rod': 'Supervara',
  'super-rod-spots': 'Supervara (água ondulando)',
  'rock-smash': 'Quebrando pedras',
  headbutt: 'Cabeçada em árvores',
  'headbutt-low': 'Cabeçada em árvores',
  'headbutt-normal': 'Cabeçada em árvores',
  'headbutt-high': 'Cabeçada em árvores',
  'honey-tree': 'Árvore com mel',
  'berry-trees': 'Árvores de frutas',
  gift: 'Presente',
  'gift-egg': 'Ovo de presente',
  'npc-trade': 'Troca com personagem',
  static: 'Encontro fixo',
  'only-one': 'Encontro único',
  'pokeflute': 'Tocando a Poké Flute',
  'squirt-bottle': 'Usando o regador',
  'wailmer-pail': 'Usando o regador',
  'devon-scope': 'Usando o Devon Scope',
  'seaweed': 'Algas no fundo do mar',
  'sos': 'Chamado de ajuda (SOS)',
  'sos-from-bubbling-spot': 'Chamado de ajuda (água borbulhando)',
  'bubbling-spots': 'Água borbulhando',
  horde: 'Horda',
  'hidden-grotto': 'Gruta escondida',
  'island-scan': 'Island Scan',
  overworld: 'Andando pelo mapa',
  'overworld-water': 'Andando pelo mapa (água)',
  'overworld-flying': 'Voando pelo mapa',
  'overworld-flying-special': 'Voando pelo mapa',
  'overworld-dirt': 'Saindo da terra',
  wanderer: 'Andando pelo mapa',
  'wanderer-water': 'Andando pelo mapa (água)',
  'max-raid': 'Max Raid',
  'dynamax-adventure': 'Dynamax Adventure',
  snag: 'Capturando de treinador (Snag)',
  'poke-radar': 'Poké Radar',
  'roaming-grass': 'Andando pela região (grama)',
  'roaming-water': 'Andando pela região (água)',
  'diving': 'Mergulhando',
}

export const methodLabel = (method) => METHODS[method] ?? method.replace(/-/g, ' ').replace(/^./, (c) => c.toUpperCase())

/** Nome do local no idioma (português usa o inglês, como nos jogos). */
export function locationName(locations, area, language) {
  const loc = locations?.[area]
  if (!loc) return area.replace(/-/g, ' ')
  return (language !== 'pt' && language !== 'en' && loc.names?.[language]) || loc.name
}

/**
 * Encontros de uma forma agrupados por jogo, na ordem da lista de jogos:
 * {jogo: [{area, method, min, max, chance, versions}]}.
 */
export function encountersByGame(encounters = []) {
  const out = {}
  for (const [area, game, method, min, max, chance, versions] of encounters) {
    ;(out[game] ??= []).push({ area, method, min, max, chance, versions })
  }
  return out
}
