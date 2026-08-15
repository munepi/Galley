+++
title = "Installation"
weight = 30
+++

# Installation

## Homebrew

```bash
brew install --cask munepi/galley/galley
```

Homebrew 6 and later only loads casks from non-official taps after you trust
them. If the install is blocked, trust the cask first and run the install
again:

```bash
brew trust munepi/galley/galley
```

This installs `GalleyPDF.app` into `/Applications`. To upgrade or remove it
later:

```bash
brew upgrade --cask galley
brew uninstall --cask galley
```

## Disk Image

Pre-compiled Universal Binaries are available under the
[Releases](https://github.com/munepi/Galley/releases) section.

1. Download `GalleyPDF_<version>.dmg`.
2. Double-click to mount the disk image.
3. Drag `GalleyPDF.app` onto the `Applications` shortcut.

Every release is signed with a Developer ID and notarized by Apple, so no
Gatekeeper warning appears on first launch.

---

After installation, see [Integration]({{< relref "/docs/integration" >}}) to
wire Galley into your text editor.
