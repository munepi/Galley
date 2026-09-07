+++
title = "Configuration"
weight = 40
bookCollapseSection = true
+++

# Configuration

Galley is configured via the macOS Menu Bar and `UserDefaults`. There are no
configuration files to edit.

- [Inverse Search Editor]({{< relref "inverse-search" >}}) — pick Emacs,
  VS Code, or a custom editor for `Cmd + Click` jump-back.
- [Custom Editor Command]({{< relref "custom-editor" >}}) — define your own
  command line for arbitrary editors.
- [Emacsclient Path]({{< relref "emacsclient-path" >}}) — point Galley at a
  specific `emacsclient` binary.
- [Text Weight]({{< relref "text-weight" >}}) — font smoothing, and how to get
  the thinner pre-v0.6 rendering back.
- [Debug Logging]({{< relref "debug-mode" >}}) — stream `os_log` output for
  SyncTeX and reload troubleshooting.

Page colors are chosen from the View menu rather than a `defaults` key; see
[Page Color]({{< relref "/docs/features/page-color" >}}) for the presets and
the one hidden preference that tunes them.

For the full list of `defaults` keys, see
[UserDefaults Reference]({{< relref "/docs/reference/userdefaults" >}}).
