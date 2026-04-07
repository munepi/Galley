# GalleyPDF project page

Source for <https://munepi.github.io/Galley/>.

This branch is the Hugo source. The built site is published to the
`gh-pages` branch by GitHub Actions on every push to `master`.

## Local development

```bash
git clone --recurse-submodules https://github.com/munepi/Galley.git
cd Galley
make serve     # http://localhost:1313
```

`make serve` requires Hugo extended (`brew install hugo`).

## Build

```bash
make build     # outputs public/
```

## Manual deploy

GitHub Actions handles deploys automatically. If you need to push manually:

```bash
make deploy
```

## Theme

The site uses [hugo-book](https://github.com/alex-shpak/hugo-book) as a git
submodule under `themes/hugo-book/`. Update with:

```bash
make update-theme
```
