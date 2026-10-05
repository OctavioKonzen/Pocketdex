#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
PACKAGE="$(python3 -c "import json,pathlib,urllib.parse; p=pathlib.Path('.dart_tool/package_config.json').resolve(); c=json.load(open(p)); print(urllib.parse.unquote(urllib.parse.urljoin(p.as_uri(),next(x['rootUri'] for x in c['packages'] if x['name']=='quickjs_engine'))).removeprefix('file://'))")"
cmake -S "$PACKAGE/native" -B "$ROOT/build/quickjs-test" -DCMAKE_BUILD_TYPE=Release
cmake --build "$ROOT/build/quickjs-test" --parallel 2
echo "LIBQUICKJSC_TEST_PATH=$ROOT/build/quickjs-test/libquickjs_c_bridge_plugin.so" >> "$GITHUB_ENV"
