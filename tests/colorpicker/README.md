# Color Picker test

Manual check for View > Color Picker. Open `colorpicker-test.pdf` in Galley
(rebuild with `pdflatex colorpicker-test.tex`, three runs, because the
overlay pictures use `remember picture`; `photo-*.jpg` / `photo-indexed.png`
are the embedded raster images, generated from `../pagecolor/photo.png` with
ImageMagick). The spot color comes from the `spotxcolor` package.

Open the panel (`Shift + Cmd + K` or right-click ▸ Color Picker) and move
the cursor over each element. The panel shows the PDF's own color values;
`≈ sRGB` and anything marked `(sampled)` are color-managed approximations.

## Page 1 (test board, page coordinates in pt, origin bottom-left)

| Element | Where | Expected |
| --- | --- | --- |
| Body text "Plain body text" | top line | `DeviceGray` Gray 0% · Text |
| "CMYK red text." | same line | `DeviceCMYK` C 0 M 100 Y 100 K 0 |
| "RGB blue text." | same line | `DeviceRGB` R 0 G 0.4 B 1 |
| "Gray 50% text." | same line | `DeviceGray` Gray 50% |
| "Spot DIC 161s* 100%." | second line | `Separation "DIC 161s*"` Tint 100% · alt DeviceCMYK C 0 M 64 Y 100 K 0 |
| "Spot DIC 161s* 50%." | second line | `Separation "DIC 161s*"` Tint 50% · alt C 0 M 32 Y 50 K 0 |
| "Rich black text." | second line | `DeviceCMYK` C 60 M 40 Y 40 K 100 |
| "RGB black text." | second line | `DeviceRGB` R 0 G 0 B 0 (distinguishable from DeviceGray 0) |
| Text nodes (y = 700) | x = 60 / 250 / 430 | DeviceGray 0 / DeviceCMYK red / DeviceRGB blue, `Text "…"` |
| Fill row 1 (y 600–660) | x = 60 / 180 / 300 / 420 | CMYK red / RGB blue / Gray 50% / Separation 100% · `Fill` |
| Fill row 2 (y 520–580) | x = 60 | CMYK red with `α 0.50` |
| | x = 180 | DeviceCMYK C 60 M 40 Y 40 K 100 (rich black) |
| | x = 300 | Separation Tint 50% |
| | x = 420 (frame) / inside | CMYK red / `DeviceGray` Gray 100% (the white box on top wins) |
| Strokes (y = 480) | x = 60 / 180 / 300 | `Stroke 1.99 pt` RGB blue / `Stroke 0.40 pt` CMYK red / `Stroke 3.99 pt` Separation |
| Unfilled rectangle (y 470–490, x 420–520) | on the border / inside | `Stroke 0.40 pt` DeviceGray 0 / `No ink` |
| Hatched box (y 380–440, x 60–160) | anywhere | `Pattern /pgfpatN (tiling, uncolored)` Tint 100% (Separation) |
| Axial shading (x 180–280) | anywhere | `Shading (type 2) DeviceRGB` · values `(sampled)` |
| Ball shading (circle at 350,410) | anywhere | `Shading (type 3) DeviceRGB` · `(sampled)` |
| Images (y 250–350) | x = 60 / 180 / 300 / 420 | `Image DeviceRGB 8 bpc` / `Image DeviceCMYK 8 bpc` / `Image Indexed (DeviceRGB) 8 bpc` / `Image DeviceRGB 8 bpc`, all `(sampled)`; the CMYK JPEG samples in a CMYK context |
| Hairline rule (y = 200, 0.4 pt) | anywhere on it | `Fill` DeviceGray 0 (thin fills are hit with a 2 px tolerance) |
| Red / cyan squares (bottom-left) | anywhere | `Inline image DeviceRGB 8 bpc` R 1 G 0 B 0 / `Inline image DeviceCMYK 8 bpc` C 100 M 0 Y 0 K 0, `(sampled)` — the CMYK value round-trips exactly |
| Blank paper | anywhere else | `No ink` |

## Page 2 (`/Rotate 90`) and page 3 (`/CropBox [50 50 400 600]`)

The two boxes and the text node must report the same values as on page 1
at their displayed positions, and the magnifier must show the same
orientation and crop as the page on screen. Wrong values here mean the
scanner's user-space coordinates and PDFKit's page coordinates have
diverged.

## Copy Color as PDF

With the Separation box (x 420–520, y 600–660) locked, Edit ▸ Copy Color as
PDF (`Option + Cmd + C`) and paste into Illustrator: the object must be a
64 pt square filled with the spot color `DIC 161s*` (a new spot swatch
appears in the Swatches panel), not a CMYK approximation. The CMYK red box
must paste as C 0 M 100 Y 100 K 0. Pasting into a text editor gives the same
text as Copy Color as Text.

## What is *not* a bug

- Values under `Dark` / `Charcoal` page colors are unchanged: the picker
  reads the content stream, not the screen.
- Annotations (link borders, widgets) are not scanned; the panel says
  `annotation here (not scanned)` when the cursor is on one with no ink
  beneath it.
- A hidden optional-content layer is still reported as ink.
