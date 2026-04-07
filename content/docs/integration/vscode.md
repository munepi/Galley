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
