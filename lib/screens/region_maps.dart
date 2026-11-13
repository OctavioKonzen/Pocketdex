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
    (id: 'johto', aspect: 1.5, art: true, cities: <String, List<double>>{'Azalea Town': [11.2, 48.34], 'Cherrygrove City': [18.88, 62.01], 'New Bark Town': [38.93, 62.7], 'Ecruteak City': [37.63, 45.12], 'Goldenrod City': [40.89, 33.2], 'Mahogany Town': [58.46, 32.42], 'Olivine City': [72.92, 32.03], 'Violet City': [64.78, 50.0], 'Cianwood City': [92.45, 65.23], 'Blackthorn City': [92.12, 46.68]}),
    (id: 'kanto', aspect: 1.5, art: true, cities: <String, List<double>>{'Indigo Plateau': [22.79, 22.46], 'Pewter City': [34.51, 24.41], 'Viridian City': [16.28, 40.04], 'Celadon City': [32.55, 41.99], 'Saffron City': [55.99, 32.23], 'Lavender Town': [67.71, 41.99], 'Cerulean City': [73.57, 22.46], 'Vermilion City': [77.47, 43.95], 'Pallet Town': [27.34, 62.5], 'Fuchsia City': [59.24, 64.94], 'Cinnabar Island': [14.32, 79.1], 'Seafoam Islands': [46.88, 87.89]}),
  ],
  'Hoenn': [
    (id: 'hoenn', aspect: 1.5, art: true, cities: <String, List<double>>{'Mauville City': [40.36, 28.32], 'Fortree City': [65.1, 24.41], 'Petalburg City': [49.48, 38.57], 'Lavaridge Town': [9.77, 42.97], 'Pacifidlog Town': [12.37, 63.48], 'Lilycove City': [74.87, 36.62], 'Sootopolis City': [75.52, 44.43], 'Mossdeep City': [71.29, 74.71], 'Ever Grande City': [91.15, 21.0], 'Rustboro City': [32.55, 38.09], 'Slateport City': [32.23, 68.36], 'Verdanturf Town': [20.83, 52.73], 'Fallarbor Town': [27.99, 24.41], 'Oldale Town': [39.71, 13.18], 'Littleroot Town': [13.35, 83.5], 'Dewford Town': [47.85, 81.05], 'Battle Frontier': [93.1, 45.9]}),
  ],
  'Sinnoh': [
    (id: 'sinnoh', aspect: 1.5, art: true, cities: <String, List<double>>{'Snowpoint City': [45.57, 16.11], 'Veilstone City': [65.1, 23.44], 'Pokémon League': [79.75, 22.66], 'Pastoria City': [81.38, 36.33], 'Oreburgh City': [39.84, 39.55], 'Eterna City': [24.22, 53.22], 'Jubilife City': [56.64, 57.13], 'Canalave City': [90.49, 64.65], 'Twinleaf Town': [20.83, 74.02], 'Hearthome City': [62.83, 80.27], 'Sunyshore City': [78.78, 77.34], 'Sandgem Town': [39.84, 77.15], 'Celestic Town': [38.54, 63.48], 'Solaceon Town': [69.01, 67.38], 'Floaroma Town': [14.65, 58.59], 'Survival Area': [16.28, 17.58], 'Fight Area': [22.46, 32.23], 'Resort Area': [87.57, 39.55]}),
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
  'Unova': [
    (id: 'unova', aspect: 1.5, art: true, cities: <String, List<double>>{'Nuvema Town': [25.07, 18.55], 'Nacrene City': [48.18, 22.27], 'Icirrus City': [77.47, 20.31], 'Opelucid City': [90.82, 29.3], 'Castelia City': [51.11, 42.48], 'Striaton City': [9.77, 44.73], 'Nimbasa City': [25.07, 67.87], 'Undella Town': [51.76, 77.15], 'Driftveil City': [82.16, 72.27], 'Pokémon League': [10.74, 20.02], 'Accumula Town': [30.92, 47.85], 'Lacunosa Town': [70.96, 8.79], 'Humilau City': [87.37, 58.4], 'Lentimas Town': [59.9, 10.74], 'Black City': [50.13, 54.69], 'Aspertia City': [9.11, 72.75], 'Floccesy Town': [27.34, 53.22], 'Virbank City': [31.25, 77.15], 'Pokéstar Studios': [35.68, 87.89], 'Mistralton City': [67.71, 49.32]}),
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
