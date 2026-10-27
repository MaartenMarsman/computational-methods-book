#!/usr/bin/env bash
# Publish the rendered site (_book/) into the gh-pages branch, keeping every
# other version. Run by .github/workflows/publish.yml after `quarto render`.
#
#   push to development -> ROOT/dev/        the development version
#   push to main        -> ROOT             what the main website shows
#   push of a tag v0.1  -> ROOT/v0.1/       an archived release (and ROOT, as main)
#
# Release = merge development into main, then tag main. versions.json at ROOT is
# regenerated from the tags on every run; folders of deleted tags are removed.
set -euo pipefail

ROOT="/computational-methods-book/"
ref="${GITHUB_REF:-}"
src="$(pwd)/_book"
pages="$(mktemp -d)"
test -d "${src:?}" && test -d "${pages:?}"

git fetch origin gh-pages
git worktree add --detach "$pages" origin/gh-pages

publish_root() {
  # Replace everything at the root except the other versions and the files
  # GitHub Pages needs.
  find "${pages:?}" -mindepth 1 -maxdepth 1 \
    ! -name dev ! -name 'v[0-9]*' ! -name .git ! -name .nojekyll ! -name CNAME \
    -exec rm -rf {} +
  cp -R "$src"/. "$pages"/
}

case "$ref" in
  refs/tags/v*)
    tag="${ref#refs/tags/}"
    rm -rf "${pages:?}/${tag:?}"
    cp -R "$src" "$pages/$tag"
    publish_root
    message="Publish version ${tag#v}"
    ;;
  refs/heads/main)
    publish_root
    message="Publish main (${GITHUB_SHA:0:7})"
    ;;
  refs/heads/development)
    rm -rf "${pages:?}/dev"
    cp -R "$src" "$pages/dev"
    message="Publish development version (${GITHUB_SHA:0:7})"
    ;;
  *)
    echo "Nothing to publish for $ref"
    exit 0
    ;;
esac

# Drop archived folders whose tag no longer exists.
for dir in "$pages"/v[0-9]*/; do
  [ -d "$dir" ] || continue
  tag="$(basename "$dir")"
  git rev-parse -q --verify "refs/tags/$tag" >/dev/null || rm -rf "${pages:?}/${tag:?}"
done

python3 tools/versions.py "$ROOT" > "$pages/versions.json"
touch "$pages/.nojekyll"

cd "$pages"
git add -A
if git diff --cached --quiet; then
  echo "Nothing to publish."
  exit 0
fi
git -c user.name="github-actions[bot]" \
    -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
    commit -q -m "$message"
git push origin HEAD:gh-pages
echo "$message"
