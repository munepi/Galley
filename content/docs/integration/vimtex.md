+++
title = "VimTeX (Vim / Neovim)"
weight = 35
+++

# VimTeX

[VimTeX](https://github.com/lervag/vimtex) v2.18 and later ships with native
Galley support. Add the following to your `vimrc` or `init.vim`:

```vim
let g:vimtex_view_method = 'galley'
```

That is the whole configuration — VimTeX drives the
[`galleypdf://` URL scheme]({{< relref "url-scheme" >}}) for you.

Run `:VimtexView` to execute Forward Search (default mapping:
`<localleader>lv`).

## Options

Galley is opened and updated in the background, so a forward search never
takes focus away from Vim. To bring it to the foreground instead:

```vim
let g:vimtex_view_galley_activate = 1
```
