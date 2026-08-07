+++
title = "Release Notes"
weight = 55
+++

# Release Notes

Every release is a Universal Binary requiring macOS 11 (Big Sur) or later,
signed with a Developer ID and notarized by Apple.

Galley checks for updates once a day and can be updated at any time from
**Galley ▸ Check for Updates…**. Installed through Homebrew? `brew upgrade
--cask galley` gets you to the same build.

---

## v0.4

*7 August 2026 —
[download](https://github.com/munepi/Galley/releases/tag/v0.4)*

### New

- The [`galleypdf` command]({{< relref "/docs/reference/galleypdf" >}}),
  shipped inside the application bundle. Open a PDF, jump to a page, force a
  reload, or run a SyncTeX forward search from your shell, your editor, or a
  build script.
- A [Homebrew tap](https://github.com/munepi/homebrew-galley):
  `brew install --cask munepi/galley/galley` installs Galley and puts
  `galleypdf` on your `PATH`.
- New URL scheme endpoint
  [`galleypdf://open`]({{< relref "/docs/integration/url-scheme" >}}), with an
  optional `page` parameter.
- Every `galleypdf://` endpoint now accepts `background=1`, so a forward
  search never takes focus away from your editor — even when it is what
  launches Galley.

### Changed

- The disk image now contains `GalleyPDF.app` itself instead of a `.pkg`
  installer. Mount it and drag the app onto the `Applications` shortcut.
- Updates therefore replace the application in place, and **no longer ask for
  an administrator password**.
- The application bundle carries a stapled notarization ticket of its own, so
  a first launch works without a network connection.
- `displayline.bash` has been replaced by `galleypdf displayline`, which takes
  the same arguments without the AppleScript round trip.

---

## v0.3

*28 April 2026 —
[download](https://github.com/munepi/Galley/releases/tag/v0.3)*

### New

- [PDF Info sidebar]({{< relref "/docs/features/pdf-info-sidebar" >}}) with
  five panels — Info (Document Info, PDF/X, PDF/A, PDF/UA, Security, Pages,
  Features), Fonts (a `CGPDFDocument` scan walking inherited page resources
  and Form XObjects), XMP (the raw packet parsed into sections), Bookmarks
  (click-to-navigate), and Annotations (click-to-navigate, `Cmd + C` copies
  the content).
- View menu shortcuts: PDF Info (`Cmd + I`), PDF Bookmarks (`Cmd + B`), PDF
  Annotations (`Cmd + N`).
- Export the sidebar as Markdown or JSON via File ▸ Export ▸ … (All / Info /
  Fonts / XMP / Bookmarks / Annotations), or from the in-panel Export
  dropdown.
- The main window remembers its position and size across launches.

---

## v0.2

*19 April 2026 —
[download](https://github.com/munepi/Galley/releases/tag/v0.2)*

### New

- Sparkle 2 auto-update support, with a **Check for Updates…** menu item and
  a daily check against the stable appcast.
- Debug logging through `os_log`, filterable by subsystem (`make log`). See
  [Debug Mode]({{< relref "/docs/configuration/debug-mode" >}}).

### Changed

- Marquee selection refinements in the PDF view.
- Refined page input HUD behaviour.

### Fixed

- A generation token now guards against race conditions during PDF reload.

---

## v0.1

*4 April 2026 —
[download](https://github.com/munepi/Galley/releases/tag/v0.1)*

The first release.

- A lightweight macOS PDF previewer built on PDFKit and AppKit, with SyncTeX
  support.
- [Auto-reload]({{< relref "/docs/features/auto-reload" >}}) when the PDF
  changes on disk.
- [SyncTeX]({{< relref "/docs/features/synctex" >}}) forward and inverse
  search.
- The [`galleypdf://` URL scheme]({{< relref "/docs/integration/url-scheme" >}})
  for editor integration.
- Emacs (AUCTeX / YaTeX) and Visual Studio Code (LaTeX Workshop) integration.
- PDF text search with regular expressions and cross-line matching.
- [Precision measurement]({{< relref "/docs/features/rectangular-selection" >}})
  tools.
