+++
title = "Visual Studio Code"
weight = 40
+++

# Visual Studio Code

For [LaTeX Workshop](https://marketplace.visualstudio.com/items?itemName=James-Yu.latex-workshop)
users, add the following to your `settings.json`:

```json
{
  // Enable SyncTeX
  "latex-workshop.synctex.afterBuild.enabled": true,

  // Register Galley as an external viewer
  "latex-workshop.view.pdf.viewer": "external",
  "latex-workshop.view.pdf.external.synctex.command": "open",
  "latex-workshop.view.pdf.external.synctex.args": [
    "-g",
    "galleypdf://forward?line=%LINE%&column=0&pdfpath=%PDF%&srcpath=%TEX%"
  ]
}
```

Execute Forward Search with `Cmd + Opt + J` (or run **LaTeX Workshop:
SyncTeX from cursor** from the Command Palette).

## Using the `galleypdf` command

The [`galleypdf` command]({{< relref "/docs/reference/galleypdf" >}}) can take
the place of `open`:

```json
{
  "latex-workshop.view.pdf.viewer": "external",
  "latex-workshop.view.pdf.external.synctex.command": "/opt/homebrew/bin/galleypdf",
  "latex-workshop.view.pdf.external.synctex.args": [
    "forward", "-g",
    "-l", "%LINE%",
    "-c", "0",
    "-s", "%TEX%",
    "%PDF%"
  ]
}
```

The full path matters here: Visual Studio Code launched from the Dock does
not inherit your shell's `PATH`, so a bare `galleypdf` may not resolve. On an
Intel Mac, or with a symlink of your own, point it wherever your `galleypdf`
lives — `galleypdf --app-path` confirms which bundle it talks to.
