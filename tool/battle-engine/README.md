# Shared battle rules

Both the website and Android use the same offline bundle, built from the pinned
`@pkmn/sim` Pokémon Showdown simulator. The existing battle screens consume its
events; the old damage calculator is only used for previews and CPU estimates.

Rules use Generation 9 singles, with legacy moves and separate team budgets for
Mega Evolution, Dynamax/Gigantamax, Terastallization and Z-Moves. Level is capped
at 50. The mechanic is chosen per Pokémon in the team builder. Normal PP starts
without PP Ups. This mixed-mechanic format is specific to PocketDex.

All 919 main-series move records, including Z variants and Max/G-Max moves,
resolve to executable rules. All 314 ability records resolve, including hidden
abilities. Embody Aspect resolves by Ogerpon's mask. Aura Guard's contact-damage
rule supplements the pinned simulator using the bundled PokeAPI record.
The 18 Colosseum/XD Shadow moves are intentionally unavailable in battle.

From this directory run `npm ci`, `npm test`, `npm run build`, then
`node audit.mjs` before building Flutter or the website. Linux CI also runs
`tool/build_quickjs_test.sh` after `flutter pub get` to test the native runtime.
The generated bundle and coverage report are not maintained by hand.

Tests execute every supported move and ability, and separately assert effects
such as accuracy rolls, status immunity, hazards, pivot switches, terrain,
Natures and transformation effects. Execution coverage does not exhaust every
possible combination of moves, abilities, items and battlefield conditions.

Upstream source: https://github.com/pkmn/ps
The upstream MIT notice is included in `assets/database/battle_engine.LICENSE.txt`
and in the generated bundle.
