#!/usr/bin/env bash
# Release the development version as a numbered version of the book.
#
#   bash tools/release.sh 0.1
#
# Turns the "In preparation" block of news.qmd into the entry for version 0.1,
# dated today, with a link to every changed line since the previous version;
# starts a fresh development entry; commits; merges development into main;
# tags v0.1. It does not push: it prints the push command at the end.
set -euo pipefail
cd "$(dirname "$0")/.."
version="${1:?usage: bash tools/release.sh <version>, e.g. 0.1}"
[ "$(git rev-parse --abbrev-ref HEAD)" = "development" ] || { echo "Switch to the development branch first."; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "Commit or discard your changes first."; exit 1; }
previous="$(git describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null || true)"
today="$(date '+%-d %B %Y')"
export version previous today
python3 - <<'PY'
import os, re, pathlib
version, previous, today = os.environ["version"], os.environ["previous"], os.environ["today"]
p = pathlib.Path("news.qmd"); s = p.read_text()
m = re.search(r"<!-- dev-start -->\n(.*?)<!-- dev-end -->\n", s, re.S)
if not m: raise SystemExit("news.qmd has no development entry between <!-- dev-start --> and <!-- dev-end -->")
dev = m.group(1)
changes = dev[dev.index("\n- "):] if "\n- " in dev else "\n"
changes = changes[:changes.index("\n:::")] + "\n" if "\n:::" in changes else changes
link = (f" Every changed line since version {previous[1:]}: [compare on GitHub]"
        f"(https://github.com/MaartenMarsman/computational-methods-book/compare/{previous}...v{version})." if previous else "")
release = (f"## Version {version} ({today}) {{.unnumbered}}\n\n"
           f"Released {today}.{link}\n\n" + (f"Changes since version {previous[1:]}:\n" if previous else "First release. Contents:\n") + changes)
newdev = (f"<!-- dev-start -->\n::: {{.content-visible when-meta=\"dev-build\"}}\n## In preparation {{.unnumbered}}\n\n"
          f"What the next release will contain: everything in version {version} plus the changes below.\n\n"
          f"Changes since version {version}:\n\n- Nothing yet.\n:::\n<!-- dev-end -->\n")
p.write_text(s[:m.start()] + newdev + "\n" + release + "\n" + s[m.end():])
PY
git add news.qmd
git commit -q -m "Release version $version"
git checkout -q main
git merge -q --ff-only development
git tag "v$version"
git checkout -q development
echo "Version $version is tagged locally. To publish it, run:"
echo "  git push origin main development v$version"
