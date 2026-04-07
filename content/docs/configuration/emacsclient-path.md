+++
title = "Emacsclient Path"
weight = 30
+++

# Specifying the Emacsclient Path

If your `emacsclient` binary is not in one of the auto-searched locations
(see [Inverse Search]({{< relref "inverse-search" >}})), point Galley at it
explicitly:

```bash
defaults write com.github.munepi.galley emacsclientPath "/path/to/your/emacsclient"
```
