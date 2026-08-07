# Page Color visual test

Manual check for View > Page Color. Open `pagecolor-test.pdf` in Galley
(rebuild with `pdflatex pagecolor-test.tex` if needed; `photo.png` is the
embedded raster image).

## Dark

- Paper turns dark, body text turns light.
- hyperref links and the TikZ bars keep their hue: blue stays blue,
  red stays red. If blue turns yellow, the transform is a naive RGB
  inversion — that is a regression.
- On macOS 26+ the raster photo must stay a positive image (PDFKit SPI,
  same behavior as Preview's "Use Dark Appearance for PDF"). On older
  macOS the fallback inverts it; that limitation is documented.

## Sepia / Orange / Gray

- Paper takes the preset color, ink stays black.
- Zoom in far: glyph outlines must stay sharp (vector). Bitmapped edges
  mean the tint is being applied through layer.filters instead of the
  multiply-blend overlay — that is a regression.

## Normal

- Identical to a build without the feature; no tint, no inversion.
