#!/usr/bin/env python3
"""Write versions.json, the index behind the version switcher, from the git tags.

Usage:  python3 tools/versions.py ROOT            prints versions.json
        python3 tools/versions.py ROOT --latest   prints the newest release, e.g. 0.1

ROOT is the path of the site on the web server, e.g. /computational-methods-book/.
A tag v<major>.<minor>[.<patch>] marks a release. The newest release is published
at ROOT, every older one at ROOT/v<version>/, and the main branch at ROOT/dev/ as
the development version. The publish workflow runs this; there is no hand editing.
"""
import json
import re
import subprocess
import sys

root = sys.argv[1]
tags = subprocess.run(["git", "tag", "--list", "v*"], capture_output=True, text=True, check=True).stdout.split()
releases = sorted(
    (t for t in tags if re.fullmatch(r"v\d+(\.\d+)*", t)),
    key=lambda t: tuple(int(x) for x in t[1:].split(".")),
    reverse=True,
)
if "--latest" in sys.argv:
    print(releases[0][1:] if releases else "")
    sys.exit()

versions = [
    {"version": t[1:], "kind": "release", "path": root if i == 0 else f"{root}{t}/"}
    for i, t in enumerate(releases)
]
versions.append({"version": "development", "kind": "development", "path": f"{root}dev/"})
print(json.dumps({
    "_comment": "Written by tools/versions.py in the publish workflow from the git tags; do not edit. "
                "Every published version of the book, newest first.",
    "root": root,
    "versions": versions,
}, indent=2))
