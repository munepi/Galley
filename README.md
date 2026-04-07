# GalleyPDF project page

Source for <https://munepi.github.io/Galley/>.

This branch (`site`) holds the Hugo source. Pushes to `site` are built and
published by the [Deploy site](.github/workflows/deploy.yml) GitHub Actions
workflow via the GitHub Pages artifact mechanism — there is no separate
"built output" branch.

## One-time setup

In the GitHub repository, set **Settings → Pages → Build and deployment →
Source** to **GitHub Actions**. The legacy `gh-pages` branch can be deleted
once the new workflow has produced its first successful deploy.

## Local development

```bash
git clone --recurse-submodules --branch site https://github.com/munepi/Galley.git
cd Galley
make serve     # http://localhost:1313/Galley/
```

`make serve` requires Hugo extended (`brew install hugo`).

## Build

```bash
make build     # outputs public/
```

## Manual deploy

Push to `site` and the workflow runs automatically. To trigger it manually
(for example to redeploy without a new commit):

```bash
make deploy    # gh workflow run deploy.yml --ref site
```

This requires the [GitHub CLI](https://cli.github.com/) (`brew install gh`).

## Theme

The site uses [hugo-book](https://github.com/alex-shpak/hugo-book) as a git
submodule under `themes/hugo-book/`. Update with:

```bash
make update-theme
```
