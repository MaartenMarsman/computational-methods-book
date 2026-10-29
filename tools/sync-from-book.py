#!/usr/bin/env python3
"""Copy the public chapters from the book source into this website repository.

Usage:  python3 tools/sync-from-book.py [path-to-book-folder]

Only the chapters and appendices listed in PUBLIC_CHAPTERS and
PUBLIC_APPENDICES are copied, together with the
book's welcome page (index.qmd, used as the landing page of the website) and
the shared files they need (helper script, styling, bibliography). Nothing
else from the book folder is touched. A website-only note at the top of the
welcome page says which chapters are online, and an "About this website"
section is appended to it. Cross-references to chapters that are not on
the website are rewritten as plain text, e.g. "@sec-metropolis" becomes
"Chapter 5 (The Metropolis Algorithm)", so that no "??" appears in the output.

After running this script: quarto render, then commit and push.
"""
import re
import shutil
import sys
from pathlib import Path

DEFAULT_BOOK = (Path.home() / "Library/CloudStorage/OneDrive-UvA/Teaching"
                / "Computational Methods Book")

PUBLIC_CHAPTERS = [
    "01-probability-and-simulation.qmd",
    "02-bayesian-inference-recap.qmd",
    "03-markov-chains.qmd",
    "04-diagnosing-markov-chains.qmd",
]
PUBLIC_APPENDICES = [
    "A-software-setup.qmd",
    "B-notation.qmd",
    "C-mcmc-diagnostics.qmd",
]
PUBLIC_FILES = ["chapters/" + n for n in PUBLIC_CHAPTERS] + ["appendices/" + n for n in PUBLIC_APPENDICES]
SHARED = [
    "R/_common.R",
    "style/bayesrules.css",
    "style/bayesrules.sty",
    "style/bookbox.lua",
    "references.bib",
    "references.qmd",
    "apa.csl",
]
# Chapters that are not (yet) on the website. Update when a chapter goes online:
# remove its entry here and add its file to PUBLIC_CHAPTERS and to _quarto.yml.
ABSENT = {
    "sec-metropolis": "Chapter 5 (The Metropolis Algorithm)",
    "sec-metropolis-hastings": "Chapter 6 (Metropolis–Hastings and Adaptive Proposals)",
    "sec-gibbs": "Chapter 7 (Gibbs Sampling and Metropolis-within-Gibbs)",
    "sec-variable-selection": "Chapter 8 (Bayesian Variable Selection)",
    "sec-model-averaging": "Chapter 9 (Bayesian Model Averaging)",
    "sec-hmc": "Chapter 10 (Hamiltonian Monte Carlo)",
}

site = Path(__file__).resolve().parent.parent
book = Path(sys.argv[1]).expanduser() if len(sys.argv) > 1 else DEFAULT_BOOK
if not (book / "_quarto.yml").exists():
    sys.exit(f"Book folder not found or has no _quarto.yml: {book}")

# Labels defined by the public chapters themselves stay as cross-references.
present = set()
for name in PUBLIC_FILES:
    present |= set(re.findall(r"\{#(sec-[a-z0-9-]+)", (book / name).read_text()))

def rewrite(match):
    label = match.group(1)
    if label in present:
        return match.group(0)
    if label in ABSENT:
        return ABSENT[label]
    print(f"  WARNING: unknown cross-reference @{label} left as is")
    return match.group(0)

for name in PUBLIC_FILES:
    text = (book / name).read_text()
    new, n = re.subn(r"@(sec-[a-z0-9-]+)", rewrite, text)
    (site / name).parent.mkdir(parents=True, exist_ok=True)
    (site / name).write_text(new)
    print(f"{name}: copied, {n} cross-references checked")

for rel in SHARED:
    src, dst = book / rel, site / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    print(f"{rel}: copied")

# The book's welcome page becomes the landing page of the website.
def chapter_entry(name):
    number = int(name.split("-", 1)[0])
    title = re.match(r"#\s+(.*?)\s*\{", (book / "chapters" / name).read_text()).group(1)
    return f"[Chapter {number}]({'chapters/' + name}) ({title})"

entries = [chapter_entry(n) for n in PUBLIC_CHAPTERS]
online = entries[0] if len(entries) == 1 else ", ".join(entries[:-1]) + " and " + entries[-1]
NOTE = f"""
::: {{.callout-note appearance="simple"}}
**Work in progress.** This website holds the chapters of the book that are ready for readers. Online now: {online}. Further chapters are added as they are completed, and the chapters already online may still change.
:::
"""
ABOUT = """
## About this website {.unnumbered}

The source of the chapters on this website is kept on [GitHub](https://github.com/MaartenMarsman/computational-methods-book), where every change to the text and code is recorded. If you find an error or have a suggestion, please [open an issue](https://github.com/MaartenMarsman/computational-methods-book/issues) there.
"""
welcome = (book / "index.qmd").read_text()
welcome, n = re.subn(r"@(sec-[a-z0-9-]+)", rewrite, welcome)
welcome = welcome.replace("{{< pagebreak >}}\n\n", "")   # PDF-only page break
first_heading_end = welcome.index("\n", welcome.index("# Welcome")) + 1
welcome = welcome[:first_heading_end] + NOTE + welcome[first_heading_end:].rstrip() + "\n" + ABOUT
(site / "index.qmd").write_text(welcome)
print(f"index.qmd: copied welcome page, {n} cross-references checked")
