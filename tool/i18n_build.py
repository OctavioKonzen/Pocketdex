#!/usr/bin/env python3
"""Copia o dicionário da interface (tool/i18n/ui.json) para o site e o app.

    web-site/src/i18n/ui.json  e  assets/i18n/ui.json

Uso: python3 tool/i18n_build.py (depois de editar tool/i18n/ui.json).
"""

import json
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
LANGS = ('en', 'fr', 'es', 'pt')


def main():
    with open(os.path.join(ROOT, 'tool', 'i18n', 'ui.json'), encoding='utf-8') as f:
        ui = json.load(f)
    problems = []
    for key, tr in ui.items():
        want = sorted(set(re.findall(r'\{\d+\}', key)))
        for lang in ('en', 'fr', 'es'):
            if lang not in tr:
                problems.append(f'{key!r}: falta {lang}')
            elif sorted(set(re.findall(r'\{\d+\}', tr[lang]))) != want:
                problems.append(f'{key!r}: {lang} com marcadores diferentes')
    if problems:
        raise SystemExit('\n'.join(problems))
    # Um arquivo compacto: {texto em português: [en, fr, es, pt?]}
    out = {k: [v['en'], v['fr'], v['es']] + ([v['pt']] if 'pt' in v else []) for k, v in ui.items()}
    for path in ('web-site/src/i18n/ui.json', 'assets/i18n/ui.json'):
        with open(os.path.join(ROOT, path), 'w', encoding='utf-8') as f:
            json.dump(out, f, ensure_ascii=False, separators=(',', ':'))
    print(f'{len(out)} textos traduzidos (en, fr, es) copiados para o site e o app')


if __name__ == '__main__':
    main()
