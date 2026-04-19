+++
title = "Debug Logging"
weight = 40
+++

# Debug Logging

Galley emits structured logs via Apple's unified logging system (`os_log`)
under the subsystem `com.github.munepi.galley`. Use this to verify SyncTeX
coordinate data, inspect reload behavior, or troubleshoot Forward/Inverse
Search.

## Stream logs in Terminal

```bash
log stream --predicate 'subsystem == "com.github.munepi.galley"' --level info
```

A convenience target is also available in the source tree:

```bash
make log
```

## Inspect in Console.app

Open **Console.app**, select your Mac under *Devices*, and filter by
`subsystem:com.github.munepi.galley`.
