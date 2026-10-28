"""Advance the visible version once per published APK, carrying at 9."""
import argparse
import re
from pathlib import Path


def parts(value):
    match = re.fullmatch(r'v?(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?', value.strip())
    if not match:
        raise ValueError(f'Versão inválida: {value!r}')
    return tuple(int(n or 0) for n in match.groups())


def next_version(published_count, current, previous):
    if published_count < 0:
        raise ValueError('A quantidade de lançamentos não pode ser negativa.')
    counter = published_count + 1
    build = max(parts(current)[3], parts(previous)[3] + 1)
    return f'{counter // 100}.{counter // 10 % 10}.{counter % 10}+{build}'


def write_version(version, root=Path('.')):
    pubspec = root / 'pubspec.yaml'
    text, count = re.subn(r'^version:.*$', f'version: {version}', pubspec.read_text(encoding='utf-8'), count=1, flags=re.M)
    if count != 1:
        raise ValueError('Não foi encontrada a versão em pubspec.yaml.')
    pubspec.write_text(text, encoding='utf-8')
    readme = root / 'README.md'
    if readme.exists():
        text = re.sub(r'badge/Android-[\d.]+-green', f'badge/Android-{version.split("+")[0]}-green', readme.read_text(encoding='utf-8'))
        readme.write_text(text, encoding='utf-8')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('published_count', type=int)
    parser.add_argument('current')
    parser.add_argument('previous')
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    version = next_version(args.published_count, args.current, args.previous)
    if args.write:
        write_version(version)
    print(version)
