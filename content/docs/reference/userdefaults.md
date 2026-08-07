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
| `displayMode`          | Integer | Page layout, as a `PDFDisplayMode` value: `0` single page, `1` single page continuous, `2` two pages, `3` two pages continuous. See [Display Modes]({{< relref "/docs/features/display-modes" >}}). |
| `displaysAsBook`       | Boolean | Book Mode — page 1 stands alone as the cover. |
| `displaysRTL`          | Boolean | Right-To-Left spreads, for 縦書き and other right-bound documents. |

The display keys are written whenever you change the corresponding View menu
item, which is why the layout survives a restart.

For debug logging, see [Debug Logging]({{< relref "/docs/configuration/debug-mode" >}}) — logs are emitted via `os_log`, no `UserDefaults` key required.

## Read current values

```bash
defaults read com.github.munepi.galley
```

## Reset everything

```bash
defaults delete com.github.munepi.galley
```
