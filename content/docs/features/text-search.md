+++
title = "Text Search"
weight = 25
+++

# Text Search

`Cmd + F` (Edit ▸ Find ▸ Find…) opens a search bar across the top of the
window. `Cmd + F` again, or `Esc`, closes it.

| Key | Action |
|-----|--------|
| `Cmd + F` | Toggle the search bar |
| `Cmd + G` | Next match |
| `Shift + Cmd + G` | Previous match |
| `Cmd + E` | Search for the current selection |
| `Enter` / `Shift + Enter` | Next / previous match, while the search bar is focused |
| `Esc` | Close the search bar |

The chevron buttons beside the field do the same as `Enter` and
`Shift + Enter`. A counter to their left shows which match you are on; it
reads `Not found` when there is nothing to jump to.

`Cmd + G` and `Shift + Cmd + G` work whether or not the search bar is open.
Closing the bar discards the highlighting, so the first `Cmd + G` afterwards
re-runs the last query and lands on the first match at or after the page you
are on.

`Cmd + E` takes the text you have selected in the page, makes it the query, and
searches immediately. It also writes the term to the system find pasteboard,
which is how macOS shares a search term between applications: switch to your
editor and its own `Cmd + G` looks for the same string.

Jumping to a match is recorded in the
[navigation history]({{< relref "/docs/reference/shortcuts" >}}), so `Cmd + [`
takes you back to where you were reading.

## Matches that span a line break

Searching runs against the page text with line breaks folded away, so a phrase
that a paragraph happens to wrap in the middle still matches. Looking for
`Theorem 1` finds it even when the PDF broke the line between the two words.
This is what you want when searching typeset output, where line breaks are an
artefact of layout rather than anything you wrote.

## Case sensitivity

Search is case-insensitive by default. Tick **Match Case** in the search bar to
require an exact match — the equivalent of turning off Vim's `ignorecase`. The
setting applies to plain and regular-expression searches alike.

## Regular expressions

Tick **Regex** in the search bar to treat the query as a regular expression.
The syntax is `NSRegularExpression` — that is, ICU.

```
\d+\.\d+          section numbers such as 2.3
Fig(ure)? \d+     both "Fig 4" and "Figure 4"
^\s*Abstract      Abstract at the start of a line
```

A pattern that does not compile shows `Invalid regex` in place of the match
counter, and the search is left alone until you fix it.
