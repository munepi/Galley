+++
title = "Custom Editor Command"
weight = 20
+++

# Custom Editor Command

Set your custom command via Terminal using `%file` and `%line` as
placeholders:

```bash
# Example for VSCode (CLI)
defaults write com.github.munepi.galley customEditorCommand \
  "/opt/homebrew/bin/code --goto '%file':%line"

# Example for Sublime Text
defaults write com.github.munepi.galley customEditorCommand \
  "/opt/homebrew/bin/subl '%file':%line"
```

After setting this, switch the inverse search target to **Custom** in the
SyncTeX menu (see [Inverse Search]({{< relref "inverse-search" >}})).
