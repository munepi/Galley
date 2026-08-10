# Page Color visual test

Manual check for View > Page Color. Open `pagecolor-test.pdf` in Galley
(rebuild with `pdflatex pagecolor-test.tex` if needed; `photo.png` is the
embedded raster image).

## Dark / Charcoal

- Paper turns dark, body text turns light. `Dark` uses PDFKit's default
  `#1E1E1E`; `Charcoal` uses `#2C2C2B`, the same lightness one step up
  Apple's dark grey ramp but warmed slightly.
- hyperref links and the TikZ bars keep their hue: blue stays blue,
  red stays red. If blue turns yellow, the transform is a naive RGB
  inversion — that is a regression.
- On macOS 26+ the raster photo must stay a positive image (PDFKit SPI,
  same behavior as Preview's "Use Dark Appearance for PDF"). On older
  macOS the fallback inverts it; that limitation is documented, and the
  fallback cannot set the paper color, so `Charcoal` looks like `Dark`
  there.

### What is *not* a bug

PDFKit classifies by drawing operator, not by intent: raster images are
protected, everything drawn as text or vector paths is inverted. A
pictorial illustration drawn in Illustrator is indistinguishable from a
TikZ diagram at that level, so it gets inverted too. Confirmed identical
in Preview with the same file, so this is PDFKit's rule rather than
ours. Suggest `Sepia`/`Gray` for design-heavy documents — those never
invert anything.

A page built entirely from the K plate is very nearly a pure black/white
inversion under `Dark`, because almost every pixel is achromatic and
hue preservation has nothing to preserve. `Charcoal` exists for this
case.

## Sepia / Orange / Gray

- Paper takes the preset color, ink stays black.
- Zoom in far: glyph outlines must stay sharp (vector). Bitmapped edges
  mean the tint is being applied through layer.filters instead of the
  multiply-blend overlay — that is a regression.

## Normal

- Identical to a build without the feature; no tint, no inversion.

## System Invert Colors

With System Settings > Accessibility > Display > Invert colors on,
`Dark` and `Charcoal` must be greyed out in the menu and have no effect,
so the page is never inverted twice. Toggling the system setting while
Galley is running must update the menu without a relaunch.
