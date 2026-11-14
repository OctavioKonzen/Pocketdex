// lib/screens/region_maps.dart
//
// Gerado por tool/region_maps.py (não editar à mão): os mapas de cada região (como o Town Map dos jogos) e onde fica
// cada cidade neles (em % da largura e da altura da imagem assets/database/sprites/maps/<id>.webp). Igual ao site.

typedef RegionMapInfo = ({String id, double aspect, bool art, Map<String, List<double>> cities});

const regionMaps = <String, List<RegionMapInfo>>{
  'Kanto': [
    (id: 'kanto', aspect: 1.5, art: true, cities: <String, List<double>>{'Indigo Plateau': [22.79, 22.46], 'Pewter City': [34.51, 24.41], 'Viridian City': [16.28, 40.04], 'Celadon City': [32.55, 41.99], 'Saffron City': [55.99, 32.23], 'Lavender Town': [67.71, 41.99], 'Cerulean City': [73.57, 22.46], 'Vermilion City': [77.47, 43.95], 'Pallet Town': [27.34, 62.5], 'Fuchsia City': [59.24, 64.94], 'Cinnabar Island': [14.32, 79.1], 'Seafoam Islands': [46.88, 87.89]}),
  ],
  'Johto': [
    (id: 'johto', aspect: 1.5, art: true, cities: <String, List<double>>{'Indigo Plateau': [14.0, 30.76], 'Ecruteak City': [57.29, 30.27], 'Blackthorn City': [69.01, 23.44], 'Mahogany Town': [73.57, 34.67], 'Violet City': [64.45, 45.9], 'Cherrygrove City': [76.82, 48.34], 'New Bark Town': [85.94, 42.97], 'Goldenrod City': [44.92, 48.83], 'Cianwood City': [15.3, 59.57], 'Azalea Town': [51.43, 60.55], 'Olivine City': [34.51, 72.27]}),
    (id: 'kanto', aspect: 1.5, art: true, cities: <String, List<double>>{'Indigo Plateau': [22.79, 22.46], 'Pewter City': [34.51, 24.41], 'Viridian City': [16.28, 40.04], 'Celadon City': [32.55, 41.99], 'Saffron City': [55.99, 32.23], 'Lavender Town': [67.71, 41.99], 'Cerulean City': [73.57, 22.46], 'Vermilion City': [77.47, 43.95], 'Pallet Town': [27.34, 62.5], 'Fuchsia City': [59.24, 64.94], 'Cinnabar Island': [14.32, 79.1], 'Seafoam Islands': [46.88, 87.89]}),
  ],
  'Hoenn': [
    (id: 'hoenn', aspect: 1.5, art: true, cities: <String, List<double>>{'Lavaridge Town': [22.46, 28.81], 'Fallarbor Town': [12.04, 36.13], 'Fortree City': [40.69, 23.93], 'Rustboro City': [31.25, 36.62], 'Petalburg City': [24.41, 45.41], 'Mauville City': [49.48, 38.09], 'Lilycove City': [71.29, 31.25], 'Sootopolis City': [86.91, 16.11], 'Mossdeep City': [87.24, 37.6], 'Verdanturf Town': [46.88, 48.83], 'Oldale Town': [40.04, 57.13], 'Slateport City': [63.48, 62.01], 'Ever Grande City': [89.52, 55.66], 'Dewford Town': [23.44, 64.94], 'Littleroot Town': [40.36, 70.8], 'Pacifidlog Town': [69.01, 79.1], 'Battle Frontier': [88.22, 77.64]}),
  ],
  'Sinnoh': [
    (id: 'sinnoh', aspect: 1.2496, art: true, cities: <String, List<double>>{'Snowpoint City': [49.71, 21.39], 'Eterna City': [33.52, 28.7], 'Floaroma Town': [26.53, 37.88], 'Celestic Town': [60.49, 33.69], 'Oreburgh City': [43.65, 47.68], 'Canalave City': [17.62, 50.36], 'Jubilife City': [35.09, 56.33], 'Solaceon Town': [66.19, 45.45], 'Veilstone City': [77.39, 45.01], 'Hearthome City': [74.18, 57.49], 'Pastoria City': [84.88, 65.95], 'Sunyshore City': [88.45, 79.14], 'Twinleaf Town': [11.41, 77.72], 'Sandgem Town': [26.53, 83.96], 'Pokémon League': [90.01, 36.1], 'Fight Area': [82.03, 16.93], 'Survival Area': [85.95, 18.27], 'Resort Area': [89.73, 16.93]}),
  ],
  'Hisui': [
    (id: 'hisui', aspect: 1.5, art: true, cities: <String, List<double>>{'Jubilife Village': [25.72, 55.66], 'Alabaster Icelands': [30.08, 20.51], 'Coronet Highlands': [57.94, 25.39], 'Crimson Mirelands': [67.71, 52.73], 'Obsidian Fieldlands': [81.05, 58.59], 'Cobalt Coastlands': [76.5, 19.53], 'Temple of Sinnoh': [60.55, 72.75]}),
  ],
  'Orre': [
    (id: 'orre', aspect: 1.5, art: true, cities: <String, List<double>>{'Gateon Port': [20.83, 43.95], 'Pyrite Town': [78.12, 24.41], 'Agate Village': [41.67, 41.99], 'Phenac City': [16.28, 21.0], 'Cipher Lab': [50.13, 23.44], 'Desert Resort': [69.01, 42.97], 'Realgam Tower': [74.87, 62.5]}),
  ],
  'Fiore': [
    (id: 'fiore', aspect: 1.5, art: true, cities: <String, List<double>>{'Ringtown': [24.74, 67.38], 'Fall City': [74.22, 67.38], 'Summerland': [68.68, 37.6], 'Wintown': [36.13, 36.62], 'Sekra Range': [25.39, 19.53], 'Fiore Temple': [52.08, 48.83]}),
  ],
  'Almia': [
    (id: 'almia', aspect: 1.5, art: true, cities: <String, List<double>>{'Vientown': [47.53, 62.99], 'Pueltown': [82.68, 38.09], 'Chicole Village': [48.5, 39.06], 'Boyleland': [67.71, 21.0], 'Haruba Village': [18.23, 48.83], 'Altru Building': [30.6, 17.09], 'Almia Castle': [78.12, 78.12]}),
  ],
  'Oblivia': [
    (id: 'oblivia', aspect: 1.5, art: true, cities: <String, List<double>>{'Dolce Island': [19.53, 17.09], 'Renbow Island': [76.82, 45.9], 'Mitonga Island': [28.65, 62.5], 'Layuda Island': [40.04, 21.0], 'Faldera Island': [78.12, 19.53], 'Oblivia Ruins': [50.78, 42.97]}),
  ],
  'Kitakami': [
    (id: 'kitakami', aspect: 1.5, art: true, cities: <String, List<double>>{'Mossui Town': [46.88, 58.59], 'Apple Hills': [23.44, 32.23], 'Oni Mountain': [46.22, 18.55], 'Kitakami Hall': [83.98, 54.69], 'Timeless Woods': [77.47, 25.88], 'Crystal Pool': [61.52, 40.04]}),
  ],
  'Blueberry': [
    (id: 'blueberry', aspect: 1.5, art: true, cities: <String, List<double>>{'Savanna Biome': [83.66, 45.9], 'Coastal Biome': [16.93, 48.83], 'Canyon Biome': [72.27, 72.27], 'Polar Biome': [23.44, 21.0], 'League Club Room': [50.13, 33.69]}),
  ],
  'Sevii': [
    (id: 'sevii', aspect: 1.5, art: true, cities: <String, List<double>>{'One Island': [78.78, 51.76], 'Two Island': [21.48, 41.99], 'Three Island': [46.88, 22.46], 'Four Island': [82.68, 24.41], 'Five Island': [46.22, 46.88], 'Six Island': [50.13, 78.12], 'Seven Island': [82.03, 77.15]}),
  ],
  'Armor': [
    (id: 'armor', aspect: 1.5, art: false, cities: <String, List<double>>{'Master Dojo': [49.47, 42.0], 'Soothing Wetlands': [33.87, 62.5], 'Challenge Beach': [68.33, 68.4], 'Tower of Two Fists': [68.33, 24.4]}),
  ],
  'Crown': [
    (id: 'crown', aspect: 1.5, art: false, cities: <String, List<double>>{'Freezington': [49.47, 60.5], 'Ballimere Lake': [36.47, 43.0], 'Split-Decision Ruins': [72.93, 50.8], 'Crown Shrine': [52.07, 16.6]}),
  ],
  'Orange': [
    (id: 'orange', aspect: 1.5, art: false, cities: <String, List<double>>{'Mikan Island': [19.53, 29.3], 'Navel Island': [42.33, 21.5], 'Trovita Island': [65.13, 32.2], 'Kumquat Island': [45.6, 60.5], 'Pummelo Island': [78.13, 73.2]}),
  ],
  'Unova': [
    (id: 'unova', aspect: 1.5, art: true, cities: <String, List<double>>{'Nuvema Town': [91.15, 87.4], 'Nacrene City': [73.89, 64.65], 'Icirrus City': [19.53, 23.93], 'Opelucid City': [82.16, 26.17], 'Castelia City': [47.72, 84.96], 'Striaton City': [76.82, 85.64], 'Nimbasa City': [48.5, 42.19], 'Undella Town': [89.84, 67.58], 'Driftveil City': [19.53, 46.68], 'Pokémon League': [61.85, 21.29], 'Accumula Town': [83.98, 85.64], 'Lacunosa Town': [86.59, 37.89], 'Humilau City': [88.54, 53.52], 'Lentimas Town': [87.57, 76.37], 'Black City': [73.83, 44.73], 'Aspertia City': [11.39, 74.41], 'Floccesy Town': [18.88, 60.74], 'Virbank City': [30.6, 67.58], 'Pokéstar Studios': [42.32, 67.58], 'Mistralton City': [14.97, 33.01]}),
  ],
  'Kalos': [
    (id: 'kalos', aspect: 1.5, art: true, cities: <String, List<double>>{'Anistar City': [14.0, 37.89], 'Geosenge Town': [30.27, 44.43], 'Cyllage City': [19.53, 55.18], 'Ambrette Town': [30.08, 52.73], 'Coumarine City': [22.79, 72.07], 'Lumiose City': [51.43, 34.18], 'Santalune City': [41.67, 53.52], 'Camphrier Town': [61.85, 68.85], 'Vaniville Town': [41.02, 80.57], 'Aquacorde Town': [64.78, 77.64], 'Dendemille Town': [80.73, 53.52], 'Snowbelle City': [84.64, 41.99], 'Laverre City': [72.27, 41.02], 'Shalour City': [9.77, 46.68], 'Couriway Town': [90.62, 45.7], 'Pokémon League': [65.1, 24.41], 'Kiloude City': [32.55, 27.54]}),
  ],
  'Alola': [
    (id: 'alola', aspect: 1.5, art: true, cities: <String, List<double>>{'Iki Town': [10.42, 29.3], 'Hau\'oli City': [21.48, 34.18], 'Verdant Cavern': [26.69, 21.0], 'Heahea City': [65.76, 28.32], 'Paniola Town': [76.17, 30.27], 'Konikoni City': [73.89, 36.62], 'Brooklet Hill': [90.17, 42.48], 'Lush Jungle': [87.57, 27.34], 'Wela Volcano Park': [79.43, 21.0], 'Ruins of Life': [88.54, 33.69], 'Aether Paradise': [49.48, 41.99], 'Seafolk Village': [10.74, 67.38], 'Vast Poni Canyon': [26.69, 67.38], 'Malie City': [62.83, 64.45], 'Po Town': [62.17, 77.15], 'Mount Lanakila': [78.78, 63.48], 'Hokulani Observatory': [89.19, 71.78], 'Tapu Village': [86.26, 83.01]}),
  ],
  'Galar': [
    (id: 'galar', aspect: 0.9367, art: true, cities: <String, List<double>>{'Wyndon': [50.25, 18.13], 'Hammerlocke': [24.71, 24.54], 'Motostoke': [74.55, 27.39], 'Stow-on-Side': [25.12, 45.14], 'Ballonlea': [74.55, 49.77], 'Spikemuth': [48.6, 49.38], 'Turffield': [54.78, 87.04], 'Postwick': [52.72, 90.28], 'Wedgehurst': [65.49, 72.15], 'Hulbury': [63.84, 44.6], 'Circhester': [51.89, 35.88]}),
  ],
  'Paldea': [
    (id: 'paldea', aspect: 1.5, art: true, cities: <String, List<double>>{'Medali': [23.44, 21.97], 'Cascarrafa': [30.6, 53.52], 'Mesagoza': [50.13, 56.64], 'Levincia': [76.82, 61.04], 'Artazon': [80.73, 39.55], 'Los Platos': [14.97, 68.85], 'Montenevera': [44.92, 17.09], 'Glaseado': [58.59, 22.66], 'Zapapico': [74.87, 22.46], 'Porto Marinada': [9.77, 31.25], 'Pokémon League': [32.23, 31.74], 'Cabo Poco': [50.46, 78.12], 'Cortondo': [29.3, 75.2], 'Alfornada': [89.84, 67.38]}),
  ],
};

/// O mapa da região que tem a cidade de agora (Johto também mostra Kanto).
RegionMapInfo? regionMapFor(String region, String? current) {
  final maps = regionMaps[region];
  if (maps == null || maps.isEmpty) return null;
  return maps.where((m) => current != null && m.cities.containsKey(current)).firstOrNull ?? maps.first;
}
