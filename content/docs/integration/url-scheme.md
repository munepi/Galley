+++
title = "URL Scheme"
weight = 10
+++

# URL Scheme (`galleypdf://`)

Galley registers a custom URL scheme with macOS LaunchServices for
zero-overhead, instantaneous communication with external editors and
scripts.

The [`galleypdf` command]({{< relref "/docs/reference/galleypdf" >}}) is a
front end over the very same scheme, so anything below can also be expressed
as a subcommand. Use the URLs directly where an editor plugin wants a viewer
command; reach for `galleypdf` in scripts and Makefiles, where its argument
handling is easier to read.

## Force Reload

```bash
open -g "galleypdf://reload"
```

## Open a PDF

```bash
open "galleypdf://open?pdfpath=<absolute_pdf_path>"

open "galleypdf://open?pdfpath=<absolute_pdf_path>&page=<page>"
```

`pdfpath` is required. `page` is optional and 1-based; values outside the
document clamp to the first or last page.

## Forward Search

```bash
open -g "galleypdf://forward?line=<line>&pdfpath=<absolute_pdf_path>"

open -g "galleypdf://forward?line=<line>&pdfpath=<absolute_pdf_path>&srcpath=<absolute_src_path>"

open -g "galleypdf://forward?line=<line>&column=<column>&pdfpath=<absolute_pdf_path>&srcpath=<absolute_src_path>"
```

`line` is required. `column` is optional but improves jump accuracy.
`srcpath` is optional and is needed only when SyncTeX cannot determine the
source from the PDF alone (multi-file projects).

## Background Operation

Every endpoint accepts `background=1`, which pairs with `open -g`: Galley
brings its window up but leaves your editor in the foreground.

```bash
open -g "galleypdf://open?pdfpath=<absolute_pdf_path>&background=1"
```

`open -g` alone keeps a *running* Galley in the background. Adding
`background=1` extends that to a cold start, where Galley would otherwise
activate itself as it finishes launching. Editor integrations that fire on
every build want both.

> [!TIP]
> **SyncTeX "Column 0" Workaround**
>
> Many PDF viewers have a known SyncTeX issue where forward search from
> column 0 incorrectly jumps to the end of the previous line. Galley detects
> `column=0` and automatically shifts the search target to `line + 1` to
> avoid this.

