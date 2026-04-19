+++
title = "SyncTeX Integration"
weight = 20
+++

# SyncTeX Integration

Galley implements both directions of SyncTeX:

- Forward Search — jump from your editor to the corresponding position in
  the PDF. The target is briefly highlighted with a fading red dot so it is
  easy to spot.
- Inverse Search — `Cmd + Click` on a glyph in the PDF to jump back to
  the source location in your editor. Galley supports Emacs (via
  `emacsclient`), VS Code (via the `vscode://` URL scheme), and arbitrary
  custom editors via a shell command template.

Forward Search is invoked through the [`galleypdf://` URL
scheme]({{< relref "/docs/integration/url-scheme" >}}), so it works with any
editor that can `open` a URL — including AUCTeX, YaTeX, LaTeX Workshop, and
hand-rolled build scripts.

See:

- [URL Scheme reference]({{< relref "/docs/integration/url-scheme" >}})
- [AUCTeX setup]({{< relref "/docs/integration/auctex" >}})
- [YaTeX setup]({{< relref "/docs/integration/yatex" >}})
- [VS Code setup]({{< relref "/docs/integration/vscode" >}})
- [Inverse search editor selection]({{< relref "/docs/configuration/inverse-search" >}})
