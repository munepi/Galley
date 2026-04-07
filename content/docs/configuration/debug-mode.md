+++
title = "Debug Mode"
weight = 40
+++

# Debug Mode

Enable the HUD to verify SyncTeX coordinate data or troubleshoot Forward
Search:

```bash
# Permanent Enable
defaults write com.github.munepi.galley debugMode -bool true

# Temporary Enable (Terminal)
/Applications/GalleyPDF.app/Contents/MacOS/GalleyPDF /path/to/document.pdf -debugMode YES
```

To disable the permanent setting:

```bash
defaults delete com.github.munepi.galley debugMode
```
