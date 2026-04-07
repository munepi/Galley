+++
title = "URL Scheme"
weight = 10
+++

# URL Scheme (`galleypdf://`)

Galley registers a custom URL scheme with macOS LaunchServices for
zero-overhead, instantaneous communication with external editors and
scripts.

## Force Reload

```bash
open -g "galleypdf://reload"
```

## Forward Search

```bash
open -g "galleypdf://forward?line=<line>&pdfpath=<absolute_pdf_path>"

open -g "galleypdf://forward?line=<line>&pdfpath=<absolute_pdf_path>&srcpath=<absolute_src_path>"

open -g "galleypdf://forward?line=<line>&column=<column>&pdfpath=<absolute_pdf_path>&srcpath=<absolute_src_path>"
```

`line` is required. `column` is optional but improves jump accuracy.
`srcpath` is optional and is needed only when SyncTeX cannot determine the
source from the PDF alone (multi-file projects).

> [!TIP]
> **SyncTeX "Column 0" Workaround**
>
> Many PDF viewers have a known SyncTeX issue where forward search from
> column 0 incorrectly jumps to the end of the previous line. Galley detects
> `column=0` and automatically shifts the search target to `line + 1` to
> avoid this.

> [!WARNING]
> **First Forward Search**
>
> The first time you execute a forward search, macOS will present a security
> prompt asking for Automation permissions. Please click **OK (Allow)**. You
> can later manage this in **System Settings → Privacy & Security →
> Automation**.
