#!/usr/bin/env python3
"""Descrições em português no banco do app (e, por tabela, no site).

Os nomes de golpes, habilidades e itens continuam em inglês; só as
descrições são traduzidas:
    Pokémon    → descrição (flavor) e categoria (genus, ex.: "Seed Pokémon")
    golpes     → efeito e descrição
    habilidades→ efeito e descrição
    itens      → efeito e descrição

As traduções ficam em tool/translations/pt.json ({texto em inglês: tradução}).
Alguns textos seguem um modelo e são traduzidos por regra (ex.: os TMs).

Uso:
    python3 tool/translate_texts.py pending [N]  mostra N textos ainda sem tradução (JSON)
    python3 tool/translate_texts.py add ARQ.json junta traduções {inglês: português}
    python3 tool/translate_texts.py apply        grava as traduções em assets/database/
    python3 tool/translate_texts.py status       quantos faltam
"""

import json
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
DB = os.path.join(ROOT, 'assets', 'database')
DICT = os.path.join(ROOT, 'tool', 'translations', 'pt.json')

# tabela → campos traduzidos
FIELDS = {
    'species': ['flavor', 'genus'],
    'moves': ['effect', 'flavor'],
    'abilities': ['effect', 'flavor'],
    'items': ['effect', 'flavor'],
}


def load_dict():
    if not os.path.exists(DICT):
        return {}
    with open(DICT, encoding='utf-8') as f:
        return json.load(f)


def save_dict(d):
    os.makedirs(os.path.dirname(DICT), exist_ok=True)
    with open(DICT, 'w', encoding='utf-8') as f:
        json.dump(dict(sorted(d.items())), f, ensure_ascii=False, indent=0)
        f.write('\n')


def load_table(name):
    with open(os.path.join(DB, f'{name}.json'), encoding='utf-8') as f:
        return json.load(f)


# ---------------------------------------------------------------- regras

TM = re.compile(r'^Teaches (.+?) to a compatible Pokémon\.(?:\s*\((.*)\))?$')
TR = re.compile(r'^Teaches (.+?) to a compatible Pokémon\. Consumed on use\.$')


PLACEHOLDER = re.compile(r'^XXX new effect for ')


def by_rule(text):
    """Tradução por modelo (ou None)."""
    if PLACEHOLDER.match(text):
        return ''  # texto provisório do PokeAPI: melhor ficar sem descrição
    m = TR.match(text)
    if m:
        return f'Ensina {m[1]} a um Pokémon compatível. Some depois de usado.'
    m = TM.match(text)
    if m:
        extra = f' ({m[2]})' if m[2] else ''
        return f'Ensina {m[1]} a um Pokémon compatível.{extra}'
    return None


def all_texts():
    """Todos os textos (únicos) que aparecem no app, na ordem das tabelas."""
    seen = []
    known = set()
    for table, fields in FIELDS.items():
        for row in load_table(table):
            for field in fields:
                text = row.get(field)
                if isinstance(text, str) and text.strip() and text not in known:
                    known.add(text)
                    seen.append(text)
    return seen


def translate(text, d):
    """Tradução do texto; '' quando o texto deve sumir e None quando falta traduzir."""
    if text in d:
        return d[text]
    return by_rule(text)


def cmd_pending(limit=150):
    d = load_dict()
    pending = [t for t in all_texts() if translate(t, d) is None]
    print(json.dumps(pending[:limit], ensure_ascii=False, indent=0))


def cmd_status():
    d = load_dict()
    texts = all_texts()
    done = sum(1 for t in texts if translate(t, d) is not None)
    print(f'{done}/{len(texts)} textos traduzidos')


def cmd_add(path):
    d = load_dict()
    with open(path, encoding='utf-8') as f:
        new = json.load(f)
    d.update({k: v for k, v in new.items() if isinstance(v, str) and v.strip()})
    save_dict(d)
    cmd_status()


def cmd_apply():
    """Troca os textos em inglês pelas traduções (se já traduzido, não mexe)."""
    d = load_dict()
    total = 0
    for table, fields in FIELDS.items():
        rows = load_table(table)
        for row in rows:
            for field in fields:
                text = row.get(field)
                if isinstance(text, str):
                    pt = translate(text, d)
                    if pt is not None and pt != text:
                        row[field] = pt
                        total += 1
        with open(os.path.join(DB, f'{table}.json'), 'w', encoding='utf-8') as f:
            json.dump(rows, f, ensure_ascii=False, separators=(',', ':'))
    print(f'{total} textos trocados para português')


if __name__ == '__main__':
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'status'
    if cmd == 'pending':
        cmd_pending(int(sys.argv[2]) if len(sys.argv) > 2 else 150)
    elif cmd == 'add':
        cmd_add(sys.argv[2])
    elif cmd == 'apply':
        cmd_apply()
    else:
        cmd_status()
