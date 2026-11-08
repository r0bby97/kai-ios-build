#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
task_app="build/Build/Products/Release-iphoneos/Faden.app"
test -d "$task_app"
test -f "$task_app/Faden"
mkdir -p build/ipa/Payload
ditto "$task_app" build/ipa/Payload/Faden.app
python3 - <<'PY'
from pathlib import Path
checkouts = Path('build/SourcePackages/checkouts')
parts = ['Kai · Third-party notices\n\nOriginal starter characters and illustrations: Kai (formerly Faden).\nDesign guidance: Unslop by Damir Sokolovsky, CC BY 4.0, https://github.com/heydamir/unslop\n']
for repo in sorted(checkouts.glob('*')):
    if not repo.is_dir():
        continue
    files = [p for p in repo.iterdir() if p.is_file() and p.name.lower().startswith(('license', 'copying', 'notice'))]
    for location in ['Source/Cmlx/mlx/LICENSE', 'Libraries/MLXCXGrammar/xgrammar/LICENSE']:
        candidate = repo / location
        if candidate.is_file():
            files.append(candidate)
    for path in files:
        parts.append('\n\n' + '=' * 60 + '\n' + repo.name + '/' + str(path.relative_to(repo)) + '\n' + '=' * 60 + '\n' + path.read_text(errors='replace'))
Path('build/ipa/Payload/Faden.app/ThirdPartyNotices.txt').write_text('\n'.join(parts))
PY
cd build/ipa
/usr/bin/zip -qry ../Kai.ipa Payload
/usr/bin/unzip -t ../Kai.ipa
