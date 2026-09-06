+++
title = "Page Color"
weight = 47
+++

# Page Color

View ▸ Page Color recolors the page for comfortable reading — a dark page for
a dark room, a tinted paper for a long proofreading session. It is a viewing
setting, not a document edit: copying, exporting and printing all keep the
document's original colors, and your choice is remembered across launches.

| Preset | What it does |
|--------|--------------|
| Normal | The document as authored. |
| Dark | Inverts the page onto PDFKit's dark paper (`#1E1E1E`), the same color Preview uses. |
| Charcoal | The same inversion onto a slightly lighter, slightly warmer paper (`#2C2C2B`). |
| Sepia | Tints the paper `#F4ECD8`. Ink stays black. |
| Orange | Tints the paper `#FFF0D9`. Ink stays black. |
| Gray | Tints the paper `#D8D8D2`. Ink stays black. |

Every preset keeps a WCAG AAA (7:1) contrast ratio between the ink and the
paper, which is why the tints are as pale as they are.

## Dark and Charcoal

These two swap light for dark while preserving hue, so a `hyperref` link stays
blue and a red TikZ rule stays red rather than flipping to its complement.

On macOS 26 and later, Galley hands the inversion to PDFKit itself — the same
facility behind Preview's *Use Dark Appearance for PDF* — which protects
embedded raster images. Photographs and screenshots stay positive while the
text around them turns light.

Charcoal exists for documents set entirely from the K plate. When nearly every
pixel on the page is achromatic, hue preservation has nothing to preserve and
Dark becomes a plain black-and-white inversion, which is harsh against a
neutral paper. Charcoal warms the paper a little to take the edge off.

> [!NOTE]
> PDFKit classifies by drawing operator, not by intent: raster images are
> protected, and anything drawn as text or vector paths is inverted. A pictorial
> illustration exported from Illustrator is therefore inverted just like a TikZ
> diagram — Preview behaves identically with the same file. For design-heavy
> documents, reach for Sepia or Gray instead; those never invert anything.

On macOS 25 and earlier that facility does not exist, and Galley falls back to
a layer filter. The fallback inverts embedded images as well, cannot set the
paper color (so Charcoal looks like Dark), and rasterizes at the current zoom
level rather than staying vector.

## Sepia, Orange and Gray

The paper tints are drawn as a multiply-blended overlay rather than an image
filter, so glyph outlines stay vector-sharp however far you zoom in, and
nothing is inverted — only the white of the paper takes the color.

## System Invert Colors

While System Settings ▸ Accessibility ▸ Display ▸ *Invert colors* is on, Dark
and Charcoal are greyed out, so the page is never inverted twice. Toggling that
system setting updates the menu without relaunching Galley.

## Adjusting the dark paper

If neither Dark nor Charcoal is the weight you want, Dark can be tuned:

```bash
defaults write com.github.munepi.galley pageColorDarkPaper "#282828"
```

Anything from roughly `#242424` to `#303030` reads as a softer dark; past that
the page starts to look washed out rather than dark. Delete the key to return
to the default. Colors whose relative luminance exceeds 0.10 are ignored, so
light text keeps its AAA contrast ratio against the page. Charcoal is
unaffected by this preference.

> [!WARNING]
> This is an unadvertised preference riding on a private PDFKit facility, and it
> exists only because the default suits some readers and not others. It may be
> removed or stop working in a future release of Galley or of macOS. Nothing else
> depends on it — if it goes away, Dark simply returns to the default paper
> color.

## Cost when off

With Normal selected, no layer filter is installed, no overlay layer is
created, no notification observers are registered, and the document view is
never forced to be layer-backed. Turning the feature off puts nothing back in
the rendering path.
