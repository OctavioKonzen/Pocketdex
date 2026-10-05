#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/tool/battle-engine"
npm ci
npm test
npm run build
node audit.mjs
node verify-moves.mjs
