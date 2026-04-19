+++
title = "Inverse Search Editor"
weight = 10
+++

# Inverse Search Editor Selection

Select your preferred editor for Inverse Search (`Cmd + Click`) from the
SyncTeX menu in Galley:

- Emacs — uses `emacsclient`. (Default.)
  Auto-searches:
  - `/Applications/Emacs.app/.../emacsclient`
  - `/opt/homebrew/bin/emacsclient`
  - `/usr/local/bin/emacsclient`
- Visual Studio Code — uses the native `vscode://` URL scheme.
- Custom — uses a user-defined shell command. See
  [Custom Editor Command]({{< relref "custom-editor" >}}).
