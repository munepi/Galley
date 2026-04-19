+++
title = "UserDefaults Keys"
weight = 20
+++

# UserDefaults Keys

All settings live under the `com.github.munepi.galley` domain.

| Key                    | Type    | Purpose                                                                                  |
|------------------------|---------|-------------------------------------------------------------------------------------------|
| `customEditorCommand`  | String  | Inverse-search command for the **Custom** editor. See [Custom Editor]({{< relref "/docs/configuration/custom-editor" >}}). |
| `emacsclientPath`      | String  | Explicit path to `emacsclient`. See [Emacsclient Path]({{< relref "/docs/configuration/emacsclient-path" >}}). |

For debug logging, see [Debug Logging]({{< relref "/docs/configuration/debug-mode" >}}) — logs are emitted via `os_log`, no `UserDefaults` key required.

## Read current values

```bash
defaults read com.github.munepi.galley
```

## Reset everything

```bash
defaults delete com.github.munepi.galley
```
