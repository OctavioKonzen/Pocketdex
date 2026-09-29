#!/usr/bin/env python3
"""Lista os textos em português da interface (site e app) para traduzir.

Procura strings no código do site (web-site/src) e do app (lib/), inclusive
texto solto em JSX, e grava em tool/i18n/strings.json. Textos com partes
variáveis (`${x}` no JS, $x / ${x} no Dart) viram modelos com {0}, {1}...

Depois de traduzir (tool/i18n/{en,fr,es}.json), rode tool/i18n_build.py.

Uso:
    python3 tool/i18n_extract.py
"""

import json
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
OUT = os.path.join(ROOT, 'tool', 'i18n', 'strings.json')

SKIP_FILES = ('test', 'firebaseConfig', 'damageCalc.js', 'profanity', 'pix.js', 'generated', 'firebase_options')
PT_HINT = re.compile(r'[ãõçáéíóúâêôà]|\b(de|do|da|dos|das|um|uma|com|para|não|seu|sua|você|seus|suas|os|as|no|na|em|ao|ou|e|é|por|mais|sem)\b', re.I)
CODE_LIKE = re.compile(r'^[\w./#:@?&=%-]+$|^[a-z0-9-]+( [a-z0-9:/\[\]().%-]+)+$|https?://|^\s*$|className|=>|\bfunction\b|\\n|^[A-Z_]+$')


def is_ui_text(text):
    t = text.strip()
    if len(t) < 2 or not re.search(r'[A-Za-zÀ-ú]', t):
        return False
    # Palavra ou frase curta com maiúscula ("Entrar", "Meus times", "Sp. Atk")
    if re.fullmatch(r'[^\w]{0,3}\s?[A-ZÀ-Ú][a-zà-ú]+\.?( [A-Za-zÀ-ú.]+){0,4}[!?.…:]?', t):
        return True
    if CODE_LIKE.search(t) and not PT_HINT.search(t):
        return False
    # classes do Tailwind e afins
    if re.fullmatch(r'[a-z0-9:/\[\]().%#-]+( [a-z0-9:/\[\]().%#-]+)*', t):
        return False
    return bool(PT_HINT.search(t)) or bool(re.search(r'[A-ZÀ-Ú][a-zà-ú]+', t))


def js_strings(src):
    found = []
    # texto solto em JSX: >Texto<
    for m in re.finditer(r'>([^<>{}]*[A-Za-zÀ-ú][^<>{}]*)<', src):
        found.append(' '.join(m.group(1).split()))
    # '...' e "..."
    for m in re.finditer(r"'((?:[^'\\\n]|\\.)*)'|\"((?:[^\"\\\n]|\\.)*)\"", src):
        found.append((m.group(1) if m.group(1) is not None else m.group(2)).replace("\\'", "'").replace('\\"', '"'))
    # `... ${x} ...`
    for m in re.finditer(r'`((?:[^`\\]|\\.)*)`', src):
        body = m.group(1)
        n = [0]

        def ph(_):
            n[0] += 1
            return '{%d}' % (n[0] - 1)

        found.append(re.sub(r'\$\{(?:[^{}]|\{[^{}]*\})*\}', ph, body))
    return found


def dart_strings(src):
    found = []
    # 'texto ' 'continuação' (strings vizinhas viram uma só em Dart)
    src = re.sub(r"'\s*\n\s*'", '', src)
    src = re.sub(r"'\s+'(?=[^,;)])", '', src)
    for m in re.finditer(r"(?<![r\w])'((?:[^'\\\n]|\\.)*)'|(?<![r\w])\"((?:[^\"\\\n]|\\.)*)\"", src):
        body = m.group(1) if m.group(1) is not None else m.group(2)
        body = body.replace("\\'", "'").replace('\\"', '"').replace('\\$', '\u0000')
        n = [0]

        def ph(_):
            n[0] += 1
            return '{%d}' % (n[0] - 1)

        body = re.sub(r'\$\{(?:[^{}]|\{[^{}]*\})*\}|\$[A-Za-z_]\w*(?:\.\w+)*', ph, body).replace('\u0000', '$')
        found.append(body)
    return found


def names_to_skip():
    """Nomes de golpes, habilidades, itens e Pokémon (não são traduzidos)."""
    skip = set()
    data = json.load(open(os.path.join(ROOT, 'assets', 'database', 'damage_data.json'), encoding='utf-8'))
    skip.update(m[0] for m in data['moves'].values())
    skip.update(data['items'].keys())
    skip.update(data['abilities'])
    return skip


def main():
    skip = names_to_skip()
    strings = {}
    for base, exts, fn in [(os.path.join(ROOT, 'web-site', 'src'), ('.js', '.jsx'), js_strings),
                           (os.path.join(ROOT, 'lib'), ('.dart',), dart_strings)]:
        for dirpath, _, files in os.walk(base):
            for name in files:
                if not name.endswith(exts) or any(s in name for s in SKIP_FILES):
                    continue
                path = os.path.join(dirpath, name)
                with open(path, encoding='utf-8') as f:
                    src = f.read()
                # sem comentários
                src = re.sub(r'/\*.*?\*/', '', src, flags=re.S)
                src = re.sub(r'(?m)^\s*//.*$', '', src)
                for text in fn(src):
                    t = text.strip()
                    if t in skip or re.search(r'\$\{|\(\s*\)|\[\s*\]|;|\bset\w+\(', t):
                        continue
                    if is_ui_text(t) and len(t) < 400:
                        strings.setdefault(t, set()).add(os.path.relpath(path, ROOT))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    data = {k: sorted(v) for k, v in sorted(strings.items())}
    with open(OUT, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    print(f'{len(data)} textos em {OUT}')


if __name__ == '__main__':
    main()
