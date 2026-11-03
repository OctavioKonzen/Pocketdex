#!/usr/bin/env python3
"""Publica no site (web-site/public/ota/) o motor da batalha e os dados que o
app pode baixar sem APK novo (lib/services/ota_update.dart), com um
manifest.json: a versão, a api e o SHA-256 de cada arquivo.

OTA_API tem que ser igual a OtaUpdate.api no app: mude os dois quando o app
precisar de código novo para os arquivos (o app com outra api ignora a
atualização e continua com o que tem).

Uso (depois de tool/build_battle_engine.sh): python3 tool/build_ota.py
"""
import hashlib
import json
import os
import shutil

OTA_API = 1
FILES = ['battle_engine.js', 'factory.json', 'battle_items.json', 'move_rules.json']

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = os.path.join(root, 'assets', 'database')
out = os.path.join(root, 'web-site', 'public', 'ota')
os.makedirs(out, exist_ok=True)
hashes = {}
for name in FILES:
    data = open(os.path.join(src, name), 'rb').read()
    hashes[name] = hashlib.sha256(data).hexdigest()
    shutil.copyfile(os.path.join(src, name), os.path.join(out, name))
# A versão: muda quando algum arquivo muda (o mesmo conteúdo, a mesma versão).
version = hashlib.sha256(''.join(hashes[n] for n in FILES).encode()).hexdigest()[:16]
with open(os.path.join(out, 'manifest.json'), 'w') as f:
    json.dump({'api': OTA_API, 'version': version, 'files': hashes}, f, indent=1)
    f.write('\n')
print(f'ota {version}: {", ".join(FILES)}')
