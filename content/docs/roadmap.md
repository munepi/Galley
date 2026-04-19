+++
title = "Roadmap"
weight = 60
+++

# Roadmap: The "Galley Pro" Ambitions

Galley is currently a focused, lightweight viewer. The following features are
under consideration or in early exploration.

## 1. Universal SyncTeX Bridge: `pandoc-synctex`

A bidirectional synchronization bridge between structured text formats and
Galley. By leveraging ASTs (like Pandoc's `+sourcepos`) and custom Lua
filters, enabling Forward / Inverse Search from Typst, SATySFi, Vivliostyle
(VFM), AsciiDoc, and Re:VIEW sources.

## 2. Hybrid Rendering Engine & Typography Inspector

A hybrid backend (Poppler + HarfBuzz + FreeType) to go beyond PDFKit's
screen rendering:

- Output Preview — CMYK and Spot Color extraction in `/Separation` and
  `/DeviceN` modes.
- Typography Inspector — embedded font names, raw CIDs/GIDs, and subset
  statuses from the PDF stream.
- OpenType Shaping Validation — verify glyph positioning against
  kerning, ligatures, and complex text layout rules.

## 3. PDF/X & PDF/A Preflight and Fixup

Native PDF/X (X-1a, X-4) and PDF/A validation and fixup, including
transparency flattening, bleed box generation, color conversions via macOS
ColorSync, and ICC profile tagging.

## 4. Extended URL Scheme API

Expanding the `galleypdf://` scheme for advanced navigation, build
integration, dynamic configuration, preflight visualization, document diff,
and export / conversion.

## 5. Command Line Interface (CLI)

Providing CLI access to preflight, export, imposition, and viewer control
so that any GUI operation can also be scripted from the terminal.
