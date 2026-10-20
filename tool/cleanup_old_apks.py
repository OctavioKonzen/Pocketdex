"""Keep the latest complete Android release; retain tags and release history."""
import argparse
import json
import os
import re
from pathlib import Path
import subprocess

REPOSITORY = 'OctavioKonzen/Pocketdex'


def gh(*args):
    text = subprocess.check_output(['gh', *args],text=True)
    return json.loads(text) if text.strip() else None


def removal_plan(releases, latest):
    assets = {a['name']:a for a in latest.get('assets',[])}
    for name in ['PocketDex.apk','PocketDex_32bits.apk']:
        if name not in assets or assets[name].get('size',0)<=0 or assets[name].get('state')!='uploaded':
            raise ValueError('O APK atual precisa estar completo antes de remover os anteriores.')
    return [a for release in releases if release['id']!=latest['id'] and not release['draft']
            for a in release.get('assets',[]) if a['name'].lower().endswith('.apk')]


def releases():
    pages=gh('api','--paginate','--slurp',f'repos/{REPOSITORY}/releases?per_page=100')
    return [release for page in pages for release in page]


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--dry-run',action='store_true')
    parser.add_argument('--count',action='store_true')
    args=parser.parse_args()
    if os.environ.get('GITHUB_REPOSITORY',REPOSITORY)!=REPOSITORY:
        raise ValueError('Repositório inesperado; nenhuma alteração foi feita.')
    history=releases()
    if args.count:
        published = [r for r in history if not r['draft'] and not r['prerelease']]
        baseline = int(Path('tool/apk_release_baseline.txt').read_text().strip())
        counters = [int(m[1]) * 100 + int(m[2]) * 10 + int(m[3]) for r in published
                    if (m := re.fullmatch(r'apk-(\d+)\.([0-9])\.([0-9])', r['tag_name']))]
        print(max([len(published), baseline, *counters]))
    else:
        latest=gh('api',f'repos/{REPOSITORY}/releases/latest')
        plan=removal_plan(history,latest)
        for asset in plan:
            if not args.dry_run:
                gh('api','--method','DELETE',f'repos/{REPOSITORY}/releases/assets/{asset["id"]}')
        print(json.dumps({'kept':latest['tag_name'],'removed' if not args.dry_run else 'wouldRemove':len(plan)}))
