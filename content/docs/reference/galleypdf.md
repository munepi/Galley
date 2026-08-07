+++
title = "galleypdf Command"
weight = 30
+++

# `galleypdf`

`galleypdf` drives a running Galley from the shell: open a PDF, jump to a
page, force a reload, or run a SyncTeX forward search. It is optional — Galley
is a complete application without it — and exists for people who script their
builds or wire Galley into an editor.

## Getting the command

Homebrew puts `galleypdf` on your `PATH` when you install the cask. If you
installed from the disk image, the command is inside the bundle at
`GalleyPDF.app/Contents/MacOS/bin/galleypdf`. Pick whichever of these suits
you — both keep working across updates, because they point into the bundle
rather than at a copy of the binary:

```bash
# Add the bundle's bin directory to PATH (no administrator rights needed)
export PATH="/Applications/GalleyPDF.app/Contents/MacOS/bin:$PATH"

# ...or link the command into a directory already on your PATH
sudo ln -sf /Applications/GalleyPDF.app/Contents/MacOS/bin/galleypdf /usr/local/bin/galleypdf
```

## Synopsis

```
galleypdf [-g] <file.pdf>
galleypdf open [-g] [-p PAGE] <file.pdf>
galleypdf reload
galleypdf forward [-g] -l LINE [-c COLUMN] [-s SRCFILE] <file.pdf>
galleypdf displayline [-g] LINE <file.pdf> [SRCFILE]
galleypdf --app-path | --version | --help
```

## Commands

| Command | Description |
|---------|-------------|
| `open [-g] [-p PAGE] <file.pdf>` | Open a PDF, optionally jumping to a page. This is also the default when the first argument is a file, so `galleypdf paper.pdf` works. |
| `reload` | Force Galley to reload the PDF it is currently showing. |
| `forward [-g] -l LINE [-c COL] [-s SRC] <file.pdf>` | SyncTeX forward search. |
| `displayline [-g] LINE <file.pdf> [SRC]` | The same as `forward`, in Skim's `displayline` argument order, for editors already configured that way. |
| `--app-path` | Print the bundle the command talks to. |
| `--version` | Print the bundle's version. |
| `--help` | Print usage. |

## Options

| Option | Description |
|--------|-------------|
| `-g`, `--background` | Perform the action without bringing Galley to the foreground. Your editor keeps focus. |
| `-p`, `--page PAGE` | Page number to show, 1-based (`open` only). Out-of-range values clamp to the first or last page. |
| `-l`, `--line LINE` | Source line number (`forward` only). |
| `-c`, `--column COL` | Source column number (`forward` only). Improves jump accuracy. |
| `-s`, `--src FILE` | TeX source file. Needed for multi-file projects, where SyncTeX cannot infer the source from the PDF alone. |

Relative paths are resolved against the working directory. Paths containing
spaces or non-ASCII characters need no quoting beyond what your shell already
requires — percent-encoding is handled for you.

## Examples

```bash
galleypdf paper.pdf                                       # open a PDF
galleypdf open -p 12 paper.pdf                            # open it at page 12
galleypdf open -g paper.pdf                               # ...without stealing focus
galleypdf reload                                          # after an out-of-band rebuild
galleypdf forward -g -l 120 -c 8 -s paper.tex paper.pdf   # forward search
galleypdf displayline -g 120 paper.pdf paper.tex          # the same, Skim's argument order
```

A `latexmk` rule that reloads the viewer after every successful build:

```makefile
paper.pdf: paper.tex
	latexmk -pdf -synctex=1 $<
	galleypdf -g $@
```

## Environment

| Variable | Description |
|----------|-------------|
| `GALLEYPDF_APP` | Path to the `GalleyPDF.app` bundle to talk to. Defaults to the bundle containing the executable. Useful when testing a build that is not the one in `/Applications`. |
| `GALLEYPDF_DRY_RUN` | If set, print the `galleypdf://` URL that would be sent, and send nothing. Handy when debugging an editor configuration. |

```bash
GALLEYPDF_DRY_RUN=1 galleypdf forward -g -l 120 -s paper.tex paper.pdf
# galleypdf://forward?line=120&pdfpath=/…/paper.pdf&srcpath=/…/paper.tex&background=1
```

## Exit status

`0` on success, `1` on a usage error or when the PDF does not exist. The
command returns as soon as Galley has received the request; it does not wait
for the jump or the reload to finish.

---

## Design notes

The rest of this page is for the curious. Nothing here is needed to use the
command.

### Why the command lives inside the bundle

`galleypdf` is not installed as a standalone tool. It ships at
`GalleyPDF.app/Contents/MacOS/bin/galleypdf`, and Homebrew's cask merely
symlinks it onto your `PATH`.

This is the same arrangement Emacs uses for `emacsclient`
(`Emacs.app/Contents/MacOS/bin/emacsclient`), and for the same reason: the
command is a client for a running application, not a second copy of the
application. Keeping it in the bundle means everyone gets the same command
whether they installed through Homebrew, from the disk image, or from source,
and it means the command and the application can never drift out of step.

Apple's bundle layout puts executable code under `Contents/MacOS`, so that is
where it goes. The `bin/` subdirectory is not decoration: on a
case-insensitive filesystem — the macOS default — `Contents/MacOS/galleypdf`
and `Contents/MacOS/GalleyPDF` are the same path, and the helper would
silently overwrite the application binary.

### Why everything goes through the URL scheme

Each subcommand is translated into a
[`galleypdf://` URL]({{< relref "/docs/integration/url-scheme" >}}) and handed
to LaunchServices, which delivers it to the bundle the command was launched
from. `galleypdf reload` and `open -g "galleypdf://reload"` reach the same
handler by the same route.

That is a deliberate constraint. One vocabulary means an editor plugin, a
shell script, and a Makefile all describe what they want in the same terms,
and every capability added to the URL scheme is immediately available from the
command line without new plumbing.

It also avoids a permission prompt. Sending an Apple Event from one process to
another requires macOS Automation access, and the user has to approve it.
A URL handed to LaunchServices does not: the system delivers the event, so no
prompt appears.

### What this makes possible later

The URL scheme is not one-way. `kAEGetURL` carries a reply slot, and Galley's
handler already receives one — the forward-search handler fills it in today.
What discards the reply is `open(1)`, which returns the moment the event is
dispatched.

Because `galleypdf` is a compiled program rather than a wrapper around
`open`, it can send the event itself and wait for the answer. Measured on an
already-running Galley, waiting for a reply costs about three milliseconds
more than not waiting. Commands that need to report something back — page
counts, font audits, preflight results — can therefore be added without
changing how the command talks to the application.
