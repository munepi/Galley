+++
title = "Integration"
weight = 30
bookCollapseSection = true
+++

# Integration

Galley communicates with external editors and scripts via its URL scheme.

- [URL Scheme (`galleypdf://`)]({{< relref "url-scheme" >}}) — the canonical
  reference for the `open`, `reload` and `forward` endpoints.
- [AUCTeX]({{< relref "auctex" >}}) — Emacs setup for forward search.
- [YaTeX]({{< relref "yatex" >}}) — Emacs (YaTeX) setup for forward search.
- [Visual Studio Code]({{< relref "vscode" >}}) — LaTeX Workshop setup.

For build scripts and Makefiles, the
[`galleypdf` command]({{< relref "/docs/reference/galleypdf" >}}) wraps the
same URL scheme in ordinary command line arguments.

For inverse search (Cmd+Click in the PDF), see
[Inverse Search]({{< relref "/docs/configuration/inverse-search" >}}) under
Configuration.
