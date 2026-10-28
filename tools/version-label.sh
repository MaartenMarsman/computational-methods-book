#!/usr/bin/env bash
# Write _version.yml: the label and date shown on the title page of the PDF.
# A tag v<version> on HEAD gives "Version <version>"; anything else is the
# development version. Run before quarto render (the workflow does this).
set -euo pipefail
cd "$(dirname "$0")/.."
tag="$(git describe --tags --exact-match HEAD 2>/dev/null || true)"
case "$tag" in
  v[0-9]*) label="Version ${tag#v}" ;;
  *)       label="Development version" ;;
esac
printf 'format:\n  pdf:\n    date: "%s"\n    date-format: "[%s,] D MMMM YYYY"\n' "$(date -u +%F)" "$label" > _version.yml
echo "$label, $(date -u +%F)"
