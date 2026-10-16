+++
title = "Color Picker"
weight = 35
+++

# Color Picker

View ▸ Color Picker (`Shift + Cmd + K`) opens a small floating panel in the
manner of Digital Color Meter. Move the cursor over the page and it reports the
color of whatever is drawn underneath — not as a screen sample, but as the
values written in the PDF itself:

```
DeviceCMYK                C 0%  M 100%  Y 100%  K 0%
DeviceGray                Gray 0%
Separation "DIC 161s*"    Tint 50%   (alt DeviceCMYK C 0%  M 32%  Y 50%  K 0%)
DeviceRGB                 R 0.000  G 0.400  B 1.000
```

Galley reads these from the page's content stream, so a `DeviceRGB` black and
a `DeviceGray` black are told apart, a rich black shows all four plates, and a
spot color keeps its name. This is the question a screen sample cannot
answer: not "what does this look like", but "what did the PDF ask for".

You can also open the panel by right-clicking the page and choosing
Color Picker; it then reads the point you clicked straight away. While the
panel is open the cursor is a crosshair. `Esc` or the menu item closes it.

## Reading the panel

From top to bottom:

- A magnifier showing the 24 pt square around the cursor, and a swatch of the
  color.
- The component values, one per line. CMYK, Gray and spot tints are given in
  percent; RGB components from 0 to 1, with a second line in 0–255.
- `≈ sRGB #RRGGBB` — the color converted for display. It is an approximation,
  and the only value in the panel that is.
- The color space, what was hit, and any transparency:
  `DeviceCMYK · Text "あ"`, `Separation "DIC 161s*" · Fill`,
  `DeviceRGB · Stroke 1.99 pt · α 0.50 · Multiply`.
- Notes, when there is something to say: the alternate color of a
  Separation, the stroke color of outlined text, invisible text (`Tr 3`), a
  Type 3 font, a stencil mask.
- The position: page label, physical page number when the two differ, and the
  point in page coordinates, e.g. `p. iv (#4)  (72.0, 640.5) pt`.

Over blank paper the panel says `No ink`.

## Exact and sampled values

Text, fills and strokes are reported exactly, from the operators that drew
them, together with constant alpha and blend mode. Strokes also report their
line width; very thin fills such as a 0.4 pt rule are hit with a 2-pixel
tolerance, so you do not have to land on them precisely.

Images, shadings and colored patterns have no single color in the content
stream. For those, Galley waits until the cursor rests, rasterizes the spot
and reports what it finds, marked `(sampled)`. A CMYK image is sampled in a
CMYK context, so its values round-trip rather than passing through RGB.

## Locking a reading

Click the page to lock the panel on the current reading; the title changes to
`Color Picker 🔒 Locked`, and moving the cursor no longer updates it. Click
again to release. Reloading the PDF releases the lock too, since the page the
reading came from no longer exists.

## Copying a color

| Menu item | Shortcut | Puts on the clipboard |
|-----------|----------|------------------------|
| Edit ▸ Copy Color as Text | `Shift + Cmd + C` | The reading as plain text: values with the color space, what was hit and where, and any notes |
| Edit ▸ Copy Color as PDF | `Option + Cmd + C` | A 64 pt square filled with the color, as vector PDF |

The two keys are the ones Digital Color Meter uses for the same jobs. The
panel's Copy Text and Copy PDF buttons do the same.

Copy Color as PDF carries the color space definition with it. Paste into
Illustrator and a `Separation` arrives as a spot swatch under its own name,
and `DeviceCMYK` arrives as the exact CMYK values — not as an RGB
approximation of either. Pasting into a text editor gives the same text as
Copy Color as Text.

## With Page Color

Readings do not change under [Page Color]({{< relref "page-color" >}}).
Dark, Charcoal and the paper tints alter what is on screen; the picker reads
the content stream, which they leave alone. The magnifier draws the page
afresh rather than copying the screen, so it too shows the document's own
colors.

## What it does not report

> [!NOTE]
> - Soft masks (`SMask` in an ExtGState). Constant alpha is reported; a
>   gradient mask is not.
> - Overprint (`OP`, `op`, `OPM`). A K 100 that overprints reads as plain
>   K 100; check overprint settings in a preflight tool.
> - Annotations — link borders, form widgets and the like. Over one with no
>   ink beneath it, the panel says `annotation here (not scanned)`.
> - Optional-content visibility. Content on a hidden layer is still reported
>   as ink.
