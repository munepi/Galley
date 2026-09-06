+++
title = "Custom Key Bindings"
weight = 15
+++

# Custom Key Bindings (Vim-style and others)

Galley deliberately ships only standard macOS shortcuts and does not implement
modal or Vim-like key handling. Single letters without modifiers are already
reserved: typing `iv` or `cover` jumps to that page label, so `h`, `j`, `k`,
`l`, `n` and `g` cannot double as commands without breaking direct page jumps.

Instead, every command is a menu item with a unique title, so you can bind
whatever keys you like. There are three ways to do it, and which one you want
depends on whether your binding uses a modifier key.

## 1. System Settings (any binding with a modifier)

System Settings ▸ Keyboard ▸ Keyboard Shortcuts ▸ App Shortcuts ▸ `+`, choose
GalleyPDF, and type the menu item title exactly as it appears in the menu bar
(for example `Next Page`, `Back`, `Find Next`). Submenu items are addressed by
their own title, not by a path.

## 2. `defaults` (the same thing, scriptable)

App Shortcuts are stored as an `NSUserKeyEquivalents` dictionary in the app's
preference domain. Galley's bundle identifier is `com.github.munepi.galley`.
Modifiers are written as symbols: `@` Command, `~` Option, `^` Control,
`$` Shift.

```bash
defaults write com.github.munepi.galley NSUserKeyEquivalents -dict "Next Page" "~j" "Previous Page" "~k" "Back" "~h" "Forward" "~l"
```

```bash
defaults read com.github.munepi.galley NSUserKeyEquivalents
```

```bash
defaults delete com.github.munepi.galley NSUserKeyEquivalents
```

`-dict` writes the whole dictionary at once, discarding any bindings already
stored. To add a single binding to an existing set, use `-dict-add` — note that
it accepts exactly one key/value pair per invocation, so repeat the command
rather than chaining pairs.

```bash
defaults write com.github.munepi.galley NSUserKeyEquivalents -dict-add "Find Next" "~n"
```

Relaunch Galley for the change to take effect; run `killall cfprefsd` first if
it does not. Titles must match exactly, including the ASCII ellipsis in items
such as `Find...`.

Note that `NSUserKeyEquivalents` *replaces* a menu item's key equivalent rather
than adding to it. Binding `Next Page` to `~j` removes `Space`, and binding
`Back` to `~h` removes `Cmd + [`. If you want to keep both, use the next
option.

## 3. Karabiner-Elements (bare single keys, or keeping the built-in keys)

App Shortcuts cannot bind a key without a modifier, so bare `/` or
`h` `j` `k` `l` need a remapper. Map them onto Galley's existing modifier
shortcuts rather than sending bare letters — a bare letter is swallowed by the
page-label input. Scoping the rule to Galley's bundle identifier keeps the rest
of your system untouched, and unlike `defaults`, the built-in keys keep
working.

Save the following as
`~/.config/karabiner/assets/complex_modifications/galley.json`, then enable it
from Karabiner-Elements ▸ Complex Modifications.

```json
{
  "title": "Galley",
  "rules": [
    {
      "description": "Galley: Opt+hjkl navigation, / for find",
      "manipulators": [
        {
          "type": "basic",
          "from": { "key_code": "j", "modifiers": { "mandatory": ["option"] } },
          "to": [{ "key_code": "spacebar" }],
          "conditions": [{ "type": "frontmost_application_if", "bundle_identifiers": ["^com\\.github\\.munepi\\.galley$"] }]
        },
        {
          "type": "basic",
          "from": { "key_code": "k", "modifiers": { "mandatory": ["option"] } },
          "to": [{ "key_code": "spacebar", "modifiers": ["left_shift"] }],
          "conditions": [{ "type": "frontmost_application_if", "bundle_identifiers": ["^com\\.github\\.munepi\\.galley$"] }]
        },
        {
          "type": "basic",
          "from": { "key_code": "h", "modifiers": { "mandatory": ["option"] } },
          "to": [{ "key_code": "open_bracket", "modifiers": ["left_command"] }],
          "conditions": [{ "type": "frontmost_application_if", "bundle_identifiers": ["^com\\.github\\.munepi\\.galley$"] }]
        },
        {
          "type": "basic",
          "from": { "key_code": "l", "modifiers": { "mandatory": ["option"] } },
          "to": [{ "key_code": "close_bracket", "modifiers": ["left_command"] }],
          "conditions": [{ "type": "frontmost_application_if", "bundle_identifiers": ["^com\\.github\\.munepi\\.galley$"] }]
        },
        {
          "type": "basic",
          "from": { "key_code": "slash" },
          "to": [{ "key_code": "f", "modifiers": ["left_command"] }],
          "conditions": [{ "type": "frontmost_application_if", "bundle_identifiers": ["^com\\.github\\.munepi\\.galley$"] }]
        }
      ]
    }
  ]
}
```

## Vim equivalents

| Vim | Galley |
|-----|--------|
| `j` / `k`, `Ctrl-F` / `Ctrl-B` | `Space` / `Shift + Space` (`Next Page` / `Previous Page`) |
| `Ctrl-E` / `Ctrl-Y` | arrow keys |
| `{N}G`, `:{N}` | type the page number or label directly |
| `Ctrl-O` / `Ctrl-I` | `Cmd + [` / `Cmd + ]` (`Back` / `Forward`) |
| `/` | `Cmd + F` (`Find...`) |
| `n` / `N` | `Cmd + G` / `Shift + Cmd + G` (`Find Next` / `Find Previous`) |
| `*` | `Cmd + E` (`Use Selection for Find`) |
| `:noh` | `Esc` |
| `ignorecase` / `smartcase` | `Match Case` checkbox in the search bar |
| `\v` | `Regex` checkbox in the search bar |

Galley has no equivalent for `Ctrl-D` / `Ctrl-U`: a half screen is not a
meaningful unit in a PDF, since it changes with the zoom level. Use
`Next Page` / `Previous Page` instead. `gg` and `G` are likewise absent —
typing a page label already jumps directly, so there is nothing left for them
to do.
