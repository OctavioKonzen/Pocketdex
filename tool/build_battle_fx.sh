#!/usr/bin/env bash
# Empacota o battleFx.js do site num arquivo só (assets/database/battle_fx.js) para o app rodar no QuickJS.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ESBUILD="$ROOT/tool/battle-engine/node_modules/.bin/esbuild"
[ -x "$ESBUILD" ] || (cd "$ROOT/tool/battle-engine" && npm ci)
"$ESBUILD" "$ROOT/tool/battle-fx/entry.js" --bundle --format=iife --target=es2019 --minify --legal-comments=none --outfile="$ROOT/assets/database/battle_fx.js"
echo "battle_fx.js: $(wc -c < "$ROOT/assets/database/battle_fx.js") bytes"
