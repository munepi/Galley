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

## Getting the thinner rendering back

The thin rendering is the closer match to the bare outlines a high-resolution
imagesetter would put on paper. If you prefer it, turn smoothing off for Galley
alone, with the same keys that work for any macOS application:

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

Neither. Smoothing off reproduces the outline geometry. Smoothing on is Apple's
on-screen compensation for the thinning effect of grayscale antialiasing, and
on a text-only page it happens to land close to what a 600 dpi laser printer's
binary rasterization produces, before toner spread.

Pick whichever you would rather trust while proofreading — and remember that
neither is a prediction of what comes off a press.
