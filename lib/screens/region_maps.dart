// lib/screens/region_maps.dart
//
// Gerado por tool/region_maps.py (não editar à mão): os mapas de cada região (como o Town Map dos jogos) e onde fica
// cada cidade neles (em % da largura e da altura da imagem assets/database/sprites/maps/<id>.webp). Igual ao site.

typedef RegionMapInfo = ({String id, double aspect, bool art, Map<String, List<double>> cities});

const regionMaps = <String, List<RegionMapInfo>>{
  'Kanto': [
    (id: 'kanto', aspect: 1.7908, art: true, cities: <String, List<double>>{'Pewter City': [24.73, 46.96], 'Viridian City': [50.36, 41.94], 'Celadon City': [64.24, 41.94], 'Cerulean City': [80.15, 42.48], 'Lavender Town': [64.24, 22.63], 'Indigo Plateau': [69.25, 16.86], 'Fuchsia City': [80.33, 64.35], 'Saffron City': [73.0, 79.19], 'Vermilion City': [56.02, 78.23], 'Cinnabar Island': [91.18, 76.63], 'Pallet Town': [33.37, 67.77], 'Seafoam Islands': [32.18, 85.38]}),
  ],
  'Johto': [
    (id: 'johto', aspect: 1.4286, art: false, cities: <String, List<double>>{'Cianwood City': [11.27, 64.7], 'Olivine City': [22.87, 48.1], 'Ecruteak City': [39.13, 28.6], 'Mahogany Town': [52.8, 28.6], 'Blackthorn City': [68.0, 28.6], 'Violet City': [47.93, 46.0], 'Goldenrod City': [32.8, 65.0], 'Azalea Town': [38.4, 83.7], 'Cherrygrove City': [57.13, 68.2], 'New Bark Town': [71.0, 68.4], 'Indigo Plateau': [90.47, 15.8]}),
    (id: 'kanto', aspect: 1.7908, art: true, cities: <String, List<double>>{'Pewter City': [24.73, 46.96], 'Viridian City': [50.36, 41.94], 'Celadon City': [64.24, 41.94], 'Cerulean City': [80.15, 42.48], 'Lavender Town': [64.24, 22.63], 'Indigo Plateau': [69.25, 16.86], 'Fuchsia City': [80.33, 64.35], 'Saffron City': [73.0, 79.19], 'Vermilion City': [56.02, 78.23], 'Cinnabar Island': [91.18, 76.63], 'Pallet Town': [33.37, 67.77], 'Seafoam Islands': [32.18, 85.38]}),
  ],
  'Hoenn': [
    (id: 'hoenn', aspect: 1.5228, art: false, cities: <String, List<double>>{'Fallarbor Town': [15.0, 14.9], 'Fortree City': [45.0, 14.9], 'Lavaridge Town': [21.67, 30.1], 'Lilycove City': [66.53, 30.1], 'Rustboro City': [5.0, 42.6], 'Verdanturf Town': [18.4, 45.3], 'Mauville City': [33.33, 45.3], 'Mossdeep City': [86.6, 40.1], 'Sootopolis City': [75.0, 50.3], 'Petalburg City': [8.33, 60.6], 'Oldale Town': [18.4, 60.6], 'Littleroot Town': [18.4, 70.7], 'Slateport City': [31.67, 68.2], 'Pacifidlog Town': [61.6, 65.5], 'Ever Grande City': [95.0, 58.1], 'Dewford Town': [11.67, 85.9], 'Battle Frontier': [78.33, 75.8]}),
  ],
  'Sinnoh': [
    (id: 'sinnoh', aspect: 1.5, art: true, cities: <String, List<double>>{'Snowpoint City': [45.57, 16.11], 'Veilstone City': [65.1, 23.44], 'Pokémon League': [79.75, 22.66], 'Pastoria City': [81.38, 36.33], 'Oreburgh City': [39.84, 39.55], 'Eterna City': [24.22, 53.22], 'Jubilife City': [56.64, 57.13], 'Canalave City': [90.49, 64.65], 'Twinleaf Town': [20.83, 74.02], 'Hearthome City': [62.83, 80.27], 'Sunyshore City': [78.78, 77.34], 'Sandgem Town': [39.84, 77.15], 'Celestic Town': [38.54, 63.48], 'Solaceon Town': [69.01, 67.38], 'Floaroma Town': [14.65, 58.59], 'Survival Area': [16.28, 17.58], 'Fight Area': [22.46, 32.23], 'Resort Area': [87.57, 39.55]}),
  ],
  'Hisui': [
    (id: 'hisui', aspect: 1.5, art: true, cities: <String, List<double>>{'Jubilife Village': [25.72, 55.66], 'Alabaster Icelands': [30.08, 20.51], 'Coronet Highlands': [57.94, 25.39], 'Crimson Mirelands': [67.71, 52.73], 'Obsidian Fieldlands': [81.05, 58.59], 'Cobalt Coastlands': [76.5, 19.53], 'Temple of Sinnoh': [60.55, 72.75]}),
  ],
  'Unova': [
    (id: 'unova', aspect: 1.5, art: true, cities: <String, List<double>>{'Nuvema Town': [25.07, 18.55], 'Nacrene City': [48.18, 22.27], 'Icirrus City': [77.47, 20.31], 'Opelucid City': [90.82, 29.3], 'Castelia City': [51.11, 42.48], 'Striaton City': [9.77, 44.73], 'Nimbasa City': [25.07, 67.87], 'Undella Town': [51.76, 77.15], 'Driftveil City': [82.16, 72.27], 'Pokémon League': [10.74, 20.02], 'Accumula Town': [30.92, 47.85], 'Lacunosa Town': [70.96, 8.79], 'Humilau City': [87.37, 58.4], 'Lentimas Town': [59.9, 10.74], 'Black City': [50.13, 54.69], 'Aspertia City': [9.11, 72.75], 'Floccesy Town': [27.34, 53.22], 'Virbank City': [31.25, 77.15], 'Pokéstar Studios': [35.68, 87.89], 'Mistralton City': [67.71, 49.32]}),
  ],
  'Kalos': [
    (id: 'kalos', aspect: 1.5, art: true, cities: <String, List<double>>{'Anistar City': [14.0, 37.89], 'Geosenge Town': [30.27, 44.43], 'Cyllage City': [19.53, 55.18], 'Ambrette Town': [30.08, 52.73], 'Coumarine City': [22.79, 72.07], 'Lumiose City': [51.43, 34.18], 'Santalune City': [41.67, 53.52], 'Camphrier Town': [61.85, 68.85], 'Vaniville Town': [41.02, 80.57], 'Aquacorde Town': [64.78, 77.64], 'Dendemille Town': [80.73, 53.52], 'Snowbelle City': [84.64, 41.99], 'Laverre City': [72.27, 41.02], 'Shalour City': [9.77, 46.68], 'Couriway Town': [90.62, 45.7], 'Pokémon League': [65.1, 24.41], 'Kiloude City': [32.55, 27.54]}),
  ],
  'Alola': [
    (id: 'alola', aspect: 1.6667, art: false, cities: <String, List<double>>{'Iki Town': [32.87, 20.5], 'Hau\'oli City': [28.93, 28.5], 'Verdant Cavern': [37.13, 26.5], 'Paniola Town': [62.67, 29.3], 'Heahea City': [58.4, 36.3], 'Konikoni City': [56.27, 42.4], 'Brooklet Hill': [65.67, 19.9], 'Lush Jungle': [69.67, 15.5], 'Wela Volcano Park': [68.33, 32.1], 'Ruins of Life': [61.73, 46.5], 'Po Town': [78.6, 53.7], 'Malie City': [87.07, 63.1], 'Mount Lanakila': [82.27, 60.3], 'Hokulani Observatory': [92.27, 70.8], 'Tapu Village': [83.2, 81.2], 'Seafolk Village': [9.6, 54.3], 'Vast Poni Canyon': [15.93, 42.0], 'Aether Paradise': [39.67, 61.2]}),
  ],
  'Galar': [
    (id: 'galar', aspect: 0.9367, art: true, cities: <String, List<double>>{'Wyndon': [50.25, 18.13], 'Hammerlocke': [24.71, 24.54], 'Motostoke': [74.55, 27.39], 'Stow-on-Side': [25.12, 45.14], 'Ballonlea': [74.55, 49.77], 'Spikemuth': [48.6, 49.38], 'Turffield': [54.78, 87.04], 'Postwick': [52.72, 90.28], 'Wedgehurst': [65.49, 72.15], 'Hulbury': [63.84, 44.6], 'Circhester': [51.89, 35.88]}),
  ],
  'Paldea': [
    (id: 'paldea', aspect: 0.9504, art: false, cities: <String, List<double>>{'Porto Marinada': [7.73, 41.0], 'Cascarrafa': [28.53, 45.6], 'Medali': [38.47, 40.8], 'Montenevera': [51.47, 18.3], 'Zapapico': [64.13, 46.2], 'Levincia': [86.6, 50.0], 'Pokémon League': [37.07, 63.0], 'Mesagoza': [47.73, 69.9], 'Cortondo': [25.73, 72.4], 'Artazon': [77.53, 68.1], 'Alfornada': [13.07, 85.5], 'Los Platos': [47.2, 82.5], 'Cabo Poco': [47.6, 90.2], 'Glaseado': [56.53, 23.8]}),
  ],
};

/// O mapa da região que tem a cidade de agora (Johto também mostra Kanto).
RegionMapInfo? regionMapFor(String region, String? current) {
  final maps = regionMaps[region];
  if (maps == null || maps.isEmpty) return null;
  return maps.where((m) => current != null && m.cities.containsKey(current)).firstOrNull ?? maps.first;
}
