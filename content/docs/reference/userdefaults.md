+++
title = "UserDefaults Keys"
weight = 20
+++

# UserDefaults Keys

All settings live under the `com.github.munepi.galley` domain.

| Key                    | Type    | Purpose                                                                                  |
|------------------------|---------|-------------------------------------------------------------------------------------------|
| `syncTexEditor`        | String  | Editor used for inverse search: `emacs` (default), `vscode`, `vimtex` or `custom`. Set from the SyncTeX menu. See [Inverse Search]({{< relref "/docs/configuration/inverse-search" >}}). |
| `customEditorCommand`  | String  | Inverse-search command for the Custom editor. See [Custom Editor]({{< relref "/docs/configuration/custom-editor" >}}). |
| `emacsclientPath`      | String  | Explicit path to `emacsclient`. See [Emacsclient Path]({{< relref "/docs/configuration/emacsclient-path" >}}). |
| `vimtexFlavor`         | String  | Which binary VimTeX inverse search launches: `auto` (default; Neovim if present, otherwise Vim), `nvim` or `vim`. |
| `vimPath`              | String  | Absolute path to `vim`, when it is not in `/opt/homebrew/bin`, `/usr/local/bin` or `/usr/bin`. The system `vim` is built without `+clientserver`, so this usually points at MacVim. |
| `nvimPath`             | String  | Absolute path to `nvim`, for the same reason. |
| `displayMode`          | Integer | Page layout, as a `PDFDisplayMode` value: `0` single page, `1` single page continuous, `2` two pages, `3` two pages continuous. See [Display Modes]({{< relref "/docs/features/display-modes" >}}). |
| `displaysAsBook`       | Boolean | Book Mode — page 1 stands alone as the cover. |
| `displaysRTL`          | Boolean | Right-To-Left spreads, for 縦書き and other right-bound documents. |
| `pageColorMode`        | Integer | Page Color preset: `0` Normal (default), `1` Dark, `2` Sepia, `3` Orange, `4` Gray, `5` Charcoal. Set from View ▸ Page Color. See [Page Color]({{< relref "/docs/features/page-color" >}}). |
| `pageColorDarkPaper`   | String  | Hidden override for the Dark paper color, as `#RRGGBB`. Values whose relative luminance exceeds 0.10 are ignored. Unset by default; does not affect Charcoal. |
| `AppleFontSmoothing`   | Integer | Not Galley's own key, but read from its domain: `0` turns macOS font smoothing off for Galley alone. Unset by default since v0.6. See [Text Weight]({{< relref "/docs/configuration/text-weight" >}}). |
| `CGFontRenderingFontSmoothingDisabled` | Boolean | The companion key to the above; set both together. |

The display and page-color keys are written whenever you change the
corresponding View menu item, which is why your choices survive a restart.

The two font-smoothing keys are the exception: they belong to macOS, not to
Galley, and Galley no longer writes them. Versions up to v0.5 set them on every
launch, so they may still be sitting in your preferences after an upgrade —
`defaults delete` both to be rid of them.

For debug logging, see [Debug Logging]({{< relref "/docs/configuration/debug-mode" >}}) — logs are emitted via `os_log`, no `UserDefaults` key required.

## Read current values

```bash
defaults read com.github.munepi.galley
```

## Reset everything

```bash
defaults delete com.github.munepi.galley
```
