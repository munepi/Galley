+++
title = "Text Weight"
weight = 35
+++

# Text Weight (Font Smoothing)

Galley draws pages with the same PDFKit engine as Preview, and since v0.6 it
leaves macOS's font smoothing at the system default. A page therefore looks
exactly as it does in Preview.

Font smoothing is the slight thickening macOS applies to every antialiased
glyph on screen. Measured on a text-only page it puts about a quarter more ink
on the screen than the glyph outlines themselves cover. Versions up to v0.5
switched it off for sharper, thinner text, which is why body text used to look
lighter in Galley than in Preview.

## If you are setting type for print

Turn smoothing off, and leave it off.

What you then see is the glyph outline as the type designer drew it — the same
geometry the RIP will image — rather than the outline plus a thickening the OS
added for screen legibility. That thickening is a fixed amount of ink per edge,
so it hits small text harder than large, and it flattens the difference between
neighbouring weights of a family.

With it off, a Light next to a Regular on screen stands in the same relation as
it will on press, and a heading that looks too heavy on screen really is too
heavy. For offset work, or proofing against a high-resolution output device,
this is the setting you want.

## Turning smoothing off

Use the same keys that work for any macOS application:

```bash
defaults write com.github.munepi.galley CGFontRenderingFontSmoothingDisabled -bool YES
defaults write com.github.munepi.galley AppleFontSmoothing -int 0
```

Relaunch Galley for the change to take effect; the value is read once at
startup.

To return to the default:

```bash
defaults delete com.github.munepi.galley CGFontRenderingFontSmoothingDisabled
defaults delete com.github.munepi.galley AppleFontSmoothing
```

> [!IMPORTANT]
> Versions up to v0.5 wrote these two keys into Galley's preferences on every
> launch, and they stay there after upgrading. If text still looks thinner than
> in Preview after updating to v0.6, run the two `defaults delete` commands
> above once and relaunch.

## Which one is correct?

Away from print work, neither. Smoothing off reproduces the outline geometry.
Smoothing on is Apple's on-screen compensation for the thinning effect of
grayscale antialiasing, and on a text-only page it happens to land close to
what a 600 dpi laser printer's binary rasterization produces, before toner
spread.

So if the office laser is where your pages end up, leaving smoothing on is a
reasonable stand-in. Neither setting predicts ink on paper, though: dot gain
and toner spread happen after the geometry is fixed, and no screen setting
models them.
