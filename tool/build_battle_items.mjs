// Gera os itens das mecânicas da batalha (assets/database/battle_items.json) a
// partir dos dados do Pokémon Showdown (pacote npm "pokemon-showdown",
// licença MIT, Copyright (c) Guangcong Luo e colaboradores):
//   mega: {id da Mega Pedra: forma Mega (slug da PokeAPI)}  ex. charizarditex: charizard-mega-x
//   z:    {id do Cristal Z: tipo dos golpes que ele transforma}  ex. firiumz: fire
// (id do Showdown: nome sem espaços nem símbolos, em minúsculas: "Charizardite X" → charizarditex.)
//
// Uso: node tool/build_battle_items.mjs /caminho/do/package (npm pack pokemon-showdown)

import { readFileSync, writeFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import path from 'node:path'

const pkg = process.argv[2]
if (!pkg) throw new Error('Passe a pasta do pacote pokemon-showdown (npm pack pokemon-showdown && tar xzf ...)')
const require = createRequire(import.meta.url)
const { Items } = require(path.join(path.resolve(pkg), 'dist/data/items.js'))
const root = path.dirname(path.dirname(new URL(import.meta.url).pathname))
const pokemon = new Set(JSON.parse(readFileSync(path.join(root, 'assets/database/pokemon.json'), 'utf8')).map((p) => p.name))

const mega = {}
const z = {}
for (const [id, item] of Object.entries(Items)) {
  if (item.megaStone) {
    // Uma pedra, uma forma (a de Charizard Y é outra pedra).
    const form = Object.values(item.megaStone)[0].toLowerCase()
    if (pokemon.has(form)) mega[id] = form
  }
  // Só os cristais de tipo (os de um Pokémon só, como o Pikanium Z, ficam de fora).
  if (item.zMove === true && item.zMoveType) z[id] = item.zMoveType.toLowerCase()
}
const out = { mega, z }
writeFileSync(path.join(root, 'assets/database/battle_items.json'), `${JSON.stringify(out)}\n`)
console.log(`Mega Pedras: ${Object.keys(mega).length}, Cristais Z: ${Object.keys(z).length}`)
