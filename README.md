# Stochastic Simulation for Bayesian Modeling in Psychology

Public website for the textbook *Stochastic Simulation for Bayesian Modeling in Psychology: An Introduction to Computational Methods* (Maarten Marsman and Lourens Waldorp, University of Amsterdam).

Website: https://maartenmarsman.github.io/computational-methods-book/

This repository holds only the chapters that are online. The full book is written elsewhere; chapters are copied here as they become ready.

## Branches and versions

| Branch or tag | Holds | Published at |
|---|---|---|
| `main` | what the main website shows: a shell until the first release, then the latest release | site root |
| `development` | the material as it is being written | `dev/` (development version) |
| tag `v<version>` on `main` | a release, kept forever | `v<version>/` |

Every version stays online, and the version menu in the sidebar switches between them. `versions.json` at the site root lists the versions and is generated from the git tags by `tools/versions.py`; `tools/deploy.sh` does the publishing in `.github/workflows/publish.yml`, which rebuilds the site from the committed `_freeze/` cache (no R needed on GitHub). Neither file needs hand editing.

## Updating the development version

On the `development` branch:

1. Copy the public chapters and the welcome page from the book folder (rewrites cross-references to chapters that are not online):

   ```sh
   python3 tools/sync-from-book.py
   ```

2. Render locally, which re-runs the R code of changed chapters and refreshes `_freeze/`:

   ```sh
   quarto render
   ```

3. Commit and push `development`. The site under `dev/` updates.

To put another chapter online: add it to `PUBLIC_CHAPTERS` and remove it from `ABSENT` in `tools/sync-from-book.py`, and add it to `_quarto.yml`. The note on the landing page updates itself.

## Releasing a version

1. On `development`, turn the top entry of `news.qmd` into a dated, numbered entry (for example `2027-01-15: Version 0.1`) and commit.
2. Merge into `main`, tag, and push both:

   ```sh
   git checkout main
   git merge development
   git tag v0.1
   git push origin main v0.1
   git checkout development
   ```

The root of the website then shows the release, `v0.1/` keeps it permanently, and `dev/` continues to follow `development`.
