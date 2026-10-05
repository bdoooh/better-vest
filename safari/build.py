#!/usr/bin/env python3
"""Better Vest for Safari - build script.

Makes the Safari copy of the extension from ../extension (the Chrome source stays the single source of truth),
then, on a Mac, wraps it in an Xcode project with Apple's safari-web-extension-converter.

    python3 safari/build.py                      # build/extension only (any OS)
    python3 safari/build.py --xcode              # + the Xcode project in build/xcode (macOS with Xcode)
    python3 safari/build.py --xcode --ios        # + an iOS / iPadOS target as well

What changes for Safari (every patch checks its anchor, so a change upstream fails the build instead of
slipping through):
  - the self-updater is switched off and its files are left out. Safari runs the extension from inside an app
    bundle that it can't rewrite, so the GitHub release check and the folder rewrite are both gone. Updates
    come from rebuilding the app.
  - files.json / files.json.sig (the updater's signed file list) and INSTALL.txt (Chrome steps) are left out.
  - the manifest asks for Safari 18 or later, the first version that runs a manifest content script in the
    page's MAIN world, which the suite needs (it hooks the page's WebSocket and reads the TradingView chart).
"""
import argparse
import json
import platform
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / 'extension'
OUT = Path(__file__).resolve().parent / 'build'
EXT = OUT / 'extension'

# The updater's page, its key and its signed list. update/core.js stays: sw.js imports its helpers.
LEAVE_OUT = {'update.html', 'update/page.js', 'update/key.js', 'update/update.css',
             'files.json', 'files.json.sig', 'INSTALL.txt'}

SAFARI_MIN = '18.0'


def fail(msg):
    sys.exit('build.py: ' + msg)


def patch(path, old, new):
    text = path.read_text(encoding='utf-8')
    if text.count(old) != 1:
        fail(f'{path.relative_to(EXT)}: expected exactly one match for {old!r}; the source changed, update this patch')
    path.write_text(text.replace(old, new), encoding='utf-8')


def copy_source():
    if EXT.exists():
        shutil.rmtree(EXT)
    for f in sorted(SRC.rglob('*')):
        rel = f.relative_to(SRC).as_posix()
        if f.is_dir() or rel in LEAVE_OUT:
            continue
        dst = EXT / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(f, dst)


def patch_manifest():
    path = EXT / 'manifest.json'
    m = json.loads(path.read_text(encoding='utf-8'))
    m['browser_specific_settings'] = {'safari': {'strict_min_version': SAFARI_MIN}}
    path.write_text(json.dumps(m, indent=2) + '\n', encoding='utf-8')


def patch_sources():
    # sw.js: the updater flag. Off, the service worker never asks GitHub for a release, the alarm is never
    # created, and update-state answers supported:false, so the popup and the dock hide every update control.
    patch(EXT / 'sw.js', 'let UPDATER = false;\nUPDATER = true;\n', 'let UPDATER = false;\n')


def check():
    m = json.loads((EXT / 'manifest.json').read_text(encoding='utf-8'))
    refs = [m['background']['service_worker'], m['action']['default_popup']]
    refs += list(m['icons'].values()) + list(m['action']['default_icon'].values())
    for cs in m['content_scripts']:
        refs += cs.get('js', []) + cs.get('css', [])
    missing = [r for r in refs if not (EXT / r).is_file()]
    if missing:
        fail('manifest points at missing files: ' + ', '.join(missing))
    # nothing left that would still call GitHub
    for f in EXT.rglob('*.js'):
        t = f.read_text(encoding='utf-8')
        if 'UPDATER = true' in t:
            fail(f'{f.relative_to(EXT)} still switches the updater on')
    # the pages the extension opens itself must exist
    for page in ('popup.html', 'journal.html', 'certificate.html'):
        if not (EXT / page).is_file():
            fail('missing page ' + page)


def xcode(bundle_id, ios):
    if platform.system() != 'Darwin' or not shutil.which('xcrun'):
        fail('--xcode needs macOS with Xcode installed (xcrun safari-web-extension-converter)')
    cmd = ['xcrun', 'safari-web-extension-converter', str(EXT),
           '--project-location', str(OUT / 'xcode'),
           '--app-name', 'Better Vest',
           '--bundle-identifier', bundle_id,
           '--swift', '--no-open', '--no-prompt', '--force']
    if not ios:
        cmd.append('--macos-only')
    # no --copy-resources: the Xcode project points at build/extension, so re-running this script and
    # building again in Xcode picks up the new files.
    print(' '.join(cmd))
    subprocess.run(cmd, check=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--xcode', action='store_true', help='also generate the Xcode project (macOS only)')
    ap.add_argument('--ios', action='store_true', help='with --xcode: add an iOS / iPadOS target too')
    ap.add_argument('--bundle-id', default='com.example.better-vest',
                    help='bundle identifier for the app (use your own reverse-DNS name)')
    a = ap.parse_args()
    copy_source()
    patch_manifest()
    patch_sources()
    check()
    print('Safari extension written to', EXT.relative_to(ROOT))
    if a.xcode:
        xcode(a.bundle_id, a.ios)
        print('Xcode project written to', (OUT / 'xcode').relative_to(ROOT))


if __name__ == '__main__':
    main()
