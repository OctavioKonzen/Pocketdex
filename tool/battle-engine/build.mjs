import {build} from 'esbuild';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
const root = path.dirname(fileURLToPath(import.meta.url));
await build({absWorkingDir: root, entryPoints: ['engine.mjs'], outfile: '../../assets/database/battle_engine.js', bundle: true, platform: 'browser', format: 'iife', target: 'es2020', minify: true, tsconfigRaw: {}, legalComments: 'eof'});
