import {readFileSync, writeFileSync} from 'node:fs';
import {PocketDexSim} from './engine.mjs';
const moves = JSON.parse(readFileSync(new URL('../../assets/database/moves.json', import.meta.url)));
const rows = PocketDexSim.audit(moves.map(move => move.name));
const missing = rows.filter(row => !row.implemented);
console.log(JSON.stringify({total: rows.length, implemented: rows.length - missing.length, missing}, null, 2));
writeFileSync(new URL('../../assets/database/battle_move_coverage.json', import.meta.url), JSON.stringify({engine: '@pkmn/sim@0.10.11', rules: 'Generation 9 singles, legacy mechanics enabled', moves: rows}, null, 2) + '\n');
