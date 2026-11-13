// O mapa de cada região (como o Town Map dos jogos): onde fica cada cidade (x e y de 0 a 100, perto do lugar dela
// nos jogos) e as terras (elipses [cx, cy, rx, ry]) sobre o mar. As rotas ligam as cidades na ordem da história.
// Igual ao app (lib/screens/region_maps.dart).

const KANTO = {
  'Pallet Town': [22, 80], 'Viridian City': [22, 62], 'Pewter City': [22, 30], 'Cerulean City': [62, 22], 'Saffron City': [62, 44],
  'Celadon City': [42, 44], 'Vermilion City': [62, 64], 'Lavender Town': [84, 44], 'Fuchsia City': [48, 82], 'Cinnabar Island': [22, 94],
  'Indigo Plateau': [6, 22], 'Seafoam Islands': [36, 92],
}
const KANTO_LAND = [[44, 52, 40, 36], [22, 94, 7, 5], [6, 24, 6, 10], [36, 91, 6, 4]]
const JOHTO = {
  'New Bark Town': [90, 62], 'Cherrygrove City': [78, 64], 'Violet City': [70, 40], 'Azalea Town': [64, 80], 'Goldenrod City': [48, 64],
  'Ecruteak City': [48, 32], 'Olivine City': [28, 42], 'Cianwood City': [8, 60], 'Mahogany Town': [72, 24], 'Blackthorn City': [90, 22],
  'Indigo Plateau': [96, 40],
}
const JOHTO_LAND = [[52, 50, 44, 38], [8, 60, 6, 7]]
// Os dois juntos (HeartGold/SoulSilver): Johto à esquerda e Kanto à direita, como no Pokégear.
const half = (cities, dx) => Object.fromEntries(Object.entries(cities).map(([k, [x, y]]) => [k, [dx + x / 2, 20 + y * 0.6]]))
const halfLand = (land, dx) => land.map(([x, y, rx, ry]) => [dx + x / 2, 20 + y * 0.6, rx / 2, ry * 0.6])

export const REGION_MAPS = {
  Kanto: { cities: KANTO, land: KANTO_LAND },
  Johto: { cities: { ...half(KANTO, 50), ...half(JOHTO, 0), 'Indigo Plateau': [49, 42] }, land: [...halfLand(JOHTO_LAND, 0), ...halfLand(KANTO_LAND, 50), [49, 42, 4, 6]] },
  Hoenn: {
    cities: {
      'Littleroot Town': [30, 76], 'Oldale Town': [30, 66], 'Petalburg City': [18, 66], 'Rustboro City': [8, 42], 'Dewford Town': [10, 88],
      'Slateport City': [42, 80], 'Mauville City': [42, 54], 'Verdanturf Town': [28, 54], 'Fallarbor Town': [24, 22], 'Lavaridge Town': [32, 36],
      'Fortree City': [54, 22], 'Lilycove City': [72, 30], 'Mossdeep City': [88, 40], 'Sootopolis City': [78, 58], 'Pacifidlog Town': [62, 76],
      'Ever Grande City': [94, 68],
    },
    land: [[30, 50, 30, 36], [64, 28, 16, 12], [88, 40, 7, 7], [78, 58, 7, 6], [94, 68, 5, 9], [10, 88, 6, 4], [62, 76, 4, 3]],
  },
  Sinnoh: {
    cities: {
      'Twinleaf Town': [20, 88], 'Sandgem Town': [28, 82], 'Jubilife City': [26, 68], 'Oreburgh City': [38, 66], 'Floaroma Town': [24, 54],
      'Eterna City': [36, 42], 'Hearthome City': [54, 62], 'Solaceon Town': [60, 48], 'Veilstone City': [74, 46], 'Pastoria City': [68, 78],
      'Celestic Town': [52, 36], 'Canalave City': [10, 64], 'Snowpoint City': [46, 8], 'Sunyshore City': [88, 80], 'Pokémon League': [90, 52],
    },
    land: [[46, 58, 38, 36], [44, 22, 18, 18], [10, 64, 6, 7], [90, 52, 7, 9], [88, 80, 7, 7]],
  },
  Unova: {
    cities: {
      'Nuvema Town': [72, 88], 'Accumula Town': [72, 74], 'Striaton City': [66, 60], 'Nacrene City': [54, 60], 'Castelia City': [54, 84],
      'Nimbasa City': [54, 44], 'Driftveil City': [34, 44], 'Mistralton City': [22, 26], 'Icirrus City': [30, 12], 'Opelucid City': [72, 20],
      'Pokémon League': [52, 10], 'Aspertia City': [30, 82], 'Virbank City': [40, 92], 'Humilau City': [92, 38], 'Lacunosa Town': [84, 24],
      'Undella Town': [90, 52],
    },
    land: [[54, 52, 40, 42], [92, 40, 6, 12], [34, 86, 12, 9]],
  },
  Kalos: {
    cities: {
      'Vaniville Town': [40, 94], 'Aquacorde Town': [44, 88], 'Santalune City': [46, 76], 'Lumiose City': [50, 54], 'Camphrier Town': [28, 60],
      'Ambrette Town': [12, 62], 'Cyllage City': [10, 44], 'Geosenge Town': [16, 28], 'Shalour City': [26, 16], 'Coumarine City': [66, 18],
      'Laverre City': [66, 40], 'Dendemille Town': [80, 40], 'Anistar City': [94, 34], 'Couriway Town': [86, 60], 'Snowbelle City': [84, 76],
      'Pokémon League': [76, 56],
    },
    land: [[50, 54, 46, 44]],
  },
  Alola: {
    cities: {
      'Iki Town': [20, 62], 'Verdant Cavern': [30, 74], 'Brooklet Hill': [46, 78], 'Wela Volcano Park': [56, 84], 'Lush Jungle': [44, 90],
      'Ruins of Life': [58, 92], 'Malie City': [66, 50], 'Hokulani Observatory': [78, 36], 'Mount Lanakila': [70, 24], 'Seafolk Village': [26, 34],
      'Vast Poni Canyon': [16, 22],
    },
    land: [[24, 70, 12, 11], [51, 86, 12, 9], [72, 38, 14, 18], [21, 28, 11, 11]],
  },
  Galar: {
    cities: {
      'Postwick': [50, 96], 'Wedgehurst': [50, 88], 'Motostoke': [50, 68], 'Turffield': [32, 78], 'Hulbury': [72, 76], 'Stow-on-Side': [36, 54],
      'Ballonlea': [18, 48], 'Hammerlocke': [52, 44], 'Circhester': [60, 24], 'Spikemuth': [84, 28], 'Wyndon': [50, 6],
    },
    land: [[50, 54, 34, 48]],
  },
  Paldea: {
    cities: {
      'Mesagoza': [50, 50], 'Cortondo': [30, 70], 'Artazon': [38, 38], 'Levincia': [76, 36], 'Cascarrafa': [22, 42], 'Medali': [30, 22],
      'Montenevera': [70, 16], 'Alfornada': [18, 80], 'Glaseado': [50, 12], 'Pokémon League': [52, 60], 'Porto Marinada': [8, 46],
    },
    land: [[48, 48, 42, 40]],
  },
}

/** Se o ponto está em terra (dentro de uma das terras, com folga): a rota entre duas ilhas passa pelo mar. */
export const onLand = (land, x, y) => land.some(([cx, cy, rx, ry]) => ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.2)

/**
 * O mapa da região (null se não tem): cada cidade da história com a posição dela (as sem posição, num canto) e,
 * para cada rota (de uma cidade para a seguinte), se ela vai por terra (o meio dela em terra) ou pelo mar.
 */
export function regionMap(region, cities) {
  const map = REGION_MAPS[region]
  if (!map) return null
  let spare = 0
  const at = (city) => map.cities[city] ?? [8 + (spare++ % 6) * 16, 6]
  const spots = cities.map((c) => ({ ...c, xy: at(c.city) }))
  const byLand = spots.slice(1).map((c, i) => onLand(map.land, (c.xy[0] + spots[i].xy[0]) / 2, (c.xy[1] + spots[i].xy[1]) / 2))
  return { land: map.land, spots, byLand }
}
