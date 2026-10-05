import {build} from 'esbuild';
import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
const root = path.dirname(fileURLToPath(import.meta.url));
await build({absWorkingDir: root, entryPoints: ['engine.mjs'], outfile: '../../assets/database/battle_engine.js', bundle: true, platform: 'browser', format: 'iife', target: 'es2020', minify: true, tsconfigRaw: {}, legalComments: 'eof', banner: {js: '/*!\n' + readFileSync(new URL('../../assets/database/battle_engine.LICENSE.txt', import.meta.url), 'utf8') + '\n*/'}});
