+++
title = "Text Search"
weight = 25
+++

# Text Search

`Cmd + F` (Edit ▸ Find…) opens a search bar across the top of the window.
`Cmd + F` again, or `Esc`, closes it.

| Key | Action |
|-----|--------|
| `Cmd + F` | Toggle the search bar |
| `Enter` | Next match |
| `Shift + Enter` | Previous match |
| `Esc` | Close the search bar |

The chevron buttons beside the field do the same as `Enter` and
`Shift + Enter`. A counter to their left shows which match you are on; it
reads `Not found` when there is nothing to jump to.

## Matches that span a line break

Searching runs against the page text with line breaks folded away, so a phrase
that a paragraph happens to wrap in the middle still matches. Looking for
`Theorem 1` finds it even when the PDF broke the line between the two words.
This is what you want when searching typeset output, where line breaks are an
artefact of layout rather than anything you wrote.

## Regular expressions

Tick **Regex** in the search bar to treat the query as a regular expression.
The syntax is `NSRegularExpression` — that is, ICU — and matching is
case-insensitive.

```
\d+\.\d+          section numbers such as 2.3
Fig(ure)? \d+     both "Fig 4" and "Figure 4"
^\s*Abstract      Abstract at the start of a line
```

A pattern that does not compile shows `Invalid regex` in place of the match
counter, and the search is left alone until you fix it.
