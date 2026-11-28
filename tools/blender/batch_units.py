#!/usr/bin/env python3
"""Build, render and validate one or more unit YAML recipes from the repository."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

from asset_spec import load_spec
from common import ROOT
from unit_spec import UNIT_OUTPUT, UNIT_SPECS


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('specs', type=Path, nargs='*', help='YAML files; default: assets/specs/units/*.yml')
    parser.add_argument('--output', type=Path, help='Parent of the <id> folders')
    parser.add_argument('--draft', action='store_true', help='2x supersampling and no .blend; requires an alternate output')
    parser.add_argument('--threads', type=int, default=4)
    args = parser.parse_args()
    output = (args.output or UNIT_OUTPUT).resolve()
    if args.draft and (not args.output or output == UNIT_OUTPUT):
        parser.error('--draft requires an alternate --output')
    if args.threads < 1:
        parser.error('--threads must be positive')
    specs = [load_spec(path) for path in args.specs or sorted(UNIT_SPECS.glob('*.yml'))]
    identities = {spec['id'] for spec in specs}
    if not specs or len(identities) != len(specs) or any(spec.get('recipe') != 'unit' for spec in specs):
        parser.error('Provide one or more recipe: unit YAML files with distinct ids')
    output.mkdir(parents=True, exist_ok=True)
    blender = ['blender', '-b', '--factory-startup', '--python-exit-code', '1']
    tools = ROOT / 'tools/blender'
    env = os.environ | {'PYTHONDONTWRITEBYTECODE': '1'}
    for spec in specs:
        ident = spec['id']
        with tempfile.TemporaryDirectory(prefix=f'.{ident}-', dir=output) as temporary:
            common = ['--', '--spec', str(spec['_path']), '--output', temporary]
            supersample = '2' if args.draft else '8'
            flags = [] if args.draft else ['--save-blend']
            subprocess.run([*blender, '-P', str(tools / 'render_sprites.py'), *common,
                            '--supersample', supersample, '--threads', str(args.threads), *flags],
                           check=True, timeout=900, env=env)
            subprocess.run([*blender, '-P', str(tools / 'validate.py'), *common],
                           check=True, timeout=900, env=env)
            target = output / ident
            target.mkdir(exist_ok=True)
            # Publish the manifest last. Until validation succeeds, the previous
            # deliverable in target is untouched.
            for artifact in sorted(Path(temporary).iterdir(), key=lambda p: p.suffix == '.json'):
                artifact.replace(target / artifact.name)
        print(f'UNIT PASS {ident} {target}', flush=True)


if __name__ == '__main__':
    main()
