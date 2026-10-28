import {build} from 'esbuild';
import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
const root = path.dirname(fileURLToPath(import.meta.url));
// Espécie do Showdown → id do Pokémon no nosso banco (Aegislash-Blade, Mimikyu-Busted...):
// a tela mostra a forma que o motor mudou durante a batalha.
const toId = (s) => s.toLowerCase().replace(/[^a-z0-9]/g, '');
const forms = Object.fromEntries(JSON.parse(readFileSync(path.join(root, '../../assets/database/pokemon.json'), 'utf8')).map((p) => [toId(p.name), p.id]));
await build({absWorkingDir: root, entryPoints: ['engine.mjs'], outfile: '../../assets/database/battle_engine.js', bundle: true, platform: 'browser', format: 'iife', target: 'es2020', minify: true, tsconfigRaw: {}, define: {POCKETDEX_FORMS: JSON.stringify(forms)}, legalComments: 'eof', banner: {js: '/*!\n' + readFileSync(new URL('../../assets/database/battle_engine.LICENSE.txt', import.meta.url), 'utf8') + '\n*/'}});
