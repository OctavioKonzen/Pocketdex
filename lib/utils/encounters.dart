// lib/utils/encounters.dart
//
// Onde encontrar cada Pokémon: nomes dos métodos e dos locais (os mesmos do
// site, web-site/src/lib/encounters.js). Os dados vêm do banco local.

import '../i18n/i18n.dart';

const encounterMethods = {
  'walk': 'Andando na grama',
  'dark-grass': 'Grama escura',
  'grass-spots': 'Grama balançando',
  'cave-spots': 'Poeira na caverna',
  'bridge-spots': 'Sombra na ponte',
  'rough-terrain': 'Terreno acidentado',
  'yellow-flowers': 'Flores amarelas',
  'purple-flowers': 'Flores roxas',
  'red-flowers': 'Flores vermelhas',
  'surf': 'Surfando',
  'surf-spots': 'Água ondulando',
  'old-rod': 'Vara velha',
  'good-rod': 'Vara boa',
  'super-rod': 'Supervara',
  'super-rod-spots': 'Supervara (água ondulando)',
  'rock-smash': 'Quebrando pedras',
  'headbutt': 'Cabeçada em árvores',
  'headbutt-low': 'Cabeçada em árvores',
  'headbutt-normal': 'Cabeçada em árvores',
  'headbutt-high': 'Cabeçada em árvores',
  'honey-tree': 'Árvore com mel',
  'berry-trees': 'Árvores de frutas',
  'gift': 'Presente',
  'gift-egg': 'Ovo de presente',
  'npc-trade': 'Troca com personagem',
  'static': 'Encontro fixo',
  'only-one': 'Encontro único',
  'pokeflute': 'Tocando a Poké Flute',
  'squirt-bottle': 'Usando o regador',
  'wailmer-pail': 'Usando o regador',
  'devon-scope': 'Usando o Devon Scope',
  'seaweed': 'Algas no fundo do mar',
  'sos': 'Chamado de ajuda (SOS)',
  'sos-from-bubbling-spot': 'Chamado de ajuda (água borbulhando)',
  'bubbling-spots': 'Água borbulhando',
  'horde': 'Horda',
  'hidden-grotto': 'Gruta escondida',
  'island-scan': 'Island Scan',
  'overworld': 'Andando pelo mapa',
  'overworld-water': 'Andando pelo mapa (água)',
  'overworld-flying': 'Voando pelo mapa',
  'overworld-flying-special': 'Voando pelo mapa',
  'overworld-dirt': 'Saindo da terra',
  'wanderer': 'Andando pelo mapa',
  'wanderer-water': 'Andando pelo mapa (água)',
  'max-raid': 'Max Raid',
  'dynamax-adventure': 'Dynamax Adventure',
  'snag': 'Capturando de treinador (Snag)',
  'poke-radar': 'Poké Radar',
  'roaming-grass': 'Andando pela região (grama)',
  'roaming-water': 'Andando pela região (água)',
  'diving': 'Mergulhando',
};

String encounterMethodLabel(String method) {
  final known = encounterMethods[method];
  if (known != null) return known;
  final text = method.replaceAll('-', ' ');
  return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}

/// Nome do local no idioma (português usa o inglês, como nos jogos).
String locationName(Map<String, dynamic>? locations, String area) {
  final loc = locations?[area];
  if (loc is! Map) return area.replaceAll('-', ' ');
  final lang = I18n.language;
  final names = loc['names'];
  if (lang != 'pt' && lang != 'en' && names is Map && names[lang] is String) return names[lang] as String;
  return loc['name'] as String? ?? area;
}
