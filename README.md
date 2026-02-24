# Leaf 🌿

**Leaf** is a minimalist, ultra-lightweight PDF previewer specifically designed for TeX/LaTeX authors and professional typesetters on macOS. Developed by **Munehiro Yamamoto (@munepi)**, it provides a "content-first" experience by eliminating unnecessary toolbars and status bars, focusing entirely on your document and your workflow.

## The Core Philosophy: 1-to-1 Correspondence

Most PDF viewers are designed for reading multiple documents simultaneously. Leaf is different. It maintains a strict **1-to-1 correspondence** between your TeX source and its PDF output. By enforcing a **single-window policy**, Leaf ensures your focus remains on the current task without the clutter of multiple open documents, while ensuring SyncTeX operations always target the correct context.

## System Requirements

* **OS:** macOS 11.0 (Big Sur) or later.
* **Architecture:** Universal Binary (Native support for both Apple Silicon and Intel Macs).

## Key Features

* **⚡ High-Speed Auto-Reload**: Detects PDF updates instantly and reloads the document while preserving your scroll position and zoom level.
* **🎯 Precise SyncTeX Integration**:
  * **Forward Search**: Jump from your editor to the exact line in the PDF with a soft-fading red dot highlight, automatically centered in the window for better visibility.
  * **Inverse Search**: Command-Click anywhere in the PDF to jump back to the corresponding source line in your editor (Emacs supported out-of-the-box).
* **📏 Precision Measurements**: Hold **Shift + Drag** to create a rectangular selection. Real-time dimensions are displayed in millimeters at the point of selection, and the area can be copied as a high-fidelity vector PDF object.
* **🍃 Featherweight & Zero-Distraction**:
  * An incredibly small footprint (~600KB), leveraging native macOS frameworks.
  * A truly minimalist interface that gives 100% of the window space to your PDF, keeping you in the flow of writing and editing.

---

## Installation

### Download Binaries

Pre-compiled **Universal Binaries** are available under the [Releases](https://github.com/munepi/Leaf/releases) section. 

1. Download `LeafPDF.dmg`.
2. Double-click to open the disk image.
3. Drag **LeafPDF.app** to the `Applications` folder shortcut.

> **Note**: Leaf will undergo Apple Notarization in the future. For now, if macOS warns you about an unidentified developer, simply **Right-Click** `LeafPDF.app` in your Applications folder and select **"Open"** to bypass Gatekeeper for the first launch.

### Building from Source

If you prefer to build it yourself, ensure you have the Swift compiler installed (via Xcode or Command Line Tools).

```bash
# Clone the repository
git clone https://github.com/munepi/Leaf.git
cd Leaf

# Build Universal Binary and create a DMG
make dmg
```

---

## Configuration

Leaf is configured via macOS `UserDefaults` to keep the interface clean.

### 1. Setting your Editor (Inverse Search)

By default, Leaf looks for `emacsclient` when you `Cmd + Click` on the PDF. You can specify the path to your preferred editor client using your bundle identifier:

```bash
defaults write com.github.munepi.leaf emacsclientPath "/usr/local/bin/emacsclient"
```

### 2. Emacs Setup (Forward Search)

To jump from your Emacs buffer to the corresponding line in Leaf, configure your TeX environment to call Leaf's `displayline-leaf` script.

#### For YaTeX Users
Add the following to your `init.el` or `.emacs`:

```elisp
(defun YaTeX:leaf-forward-search ()
  "Perform a Forward Search in the PDF corresponding to the current line using Leaf."
  (interactive)
  (let* ((line (number-to-string (save-restriction
                                   (widen)
                                   (count-lines (point-min) (point)))))
         (pdf-file (expand-file-name
                    (concat (file-name-sans-extension
                             (or YaTeX-parent-file
                                 (save-excursion
                                   (YaTeX-visit-main t)
                                   buffer-file-name)))
                            ".pdf")))
         (tex-file buffer-file-name)
         (cmd "/Applications/LeafPDF.app/Contents/MacOS/displayline-leaf"))

    (if (file-executable-p cmd)
        ;; Add the -g option to perform the jump in the background without bringing Leaf to the foreground
        (let ((proc (start-process "displayline-leaf" nil cmd "-g" line pdf-file tex-file)))
          (if (fboundp 'set-process-query-on-exit-flag)
              (set-process-query-on-exit-flag proc nil)
            (process-kill-without-query proc)))
      (message "Executable file not found. Please ensure LeafPDF.app is installed correctly."))))

;; Shortcut key configuration for YaTeX (e.g., prefix + C-l)
(add-hook 'yatex-mode-hook
          (lambda ()
            (YaTeX-define-key "\C-j" 'YaTeX:leaf-forward-search)
            (YaTeX-define-key "\C-l" 'YaTeX:leaf-forward-search)
        ))
```

### 3. Debug Mode

If you need to verify SyncTeX coordinate data or troubleshoot Forward Search, you can enable the HUD (Head-Up Display):

* **Option 1: Permanent Enable**
```bash
defaults write com.github.munepi.leaf debugMode -bool true
```

* **Option 2: Temporary Enable (Terminal)**
```bash
/Applications/LeafPDF.app/Contents/MacOS/LeafPDF /path/to/document.pdf -debugMode YES
```

---

## Usage & Shortcuts

| Action | Shortcut / Gesture |
| :--- | :--- |
| **Open File** | `Cmd + O` or `open -a LeafPDF document.pdf` |
| **Zoom In/Out** | `Cmd + "+"` / `Cmd + "-"` |
| **Actual Size** | `Cmd + 0` |
| **Auto Resize** | `Cmd + _` |
| **Next/Prev Page** | `Space` / `Shift + Space` (or `Opt + J/K`) |
| **Inverse Search** | `Cmd + Click` on PDF |
| **Measure Area** | `Shift + Drag` |
| **Copy Selection** | `Cmd + C` (while area is selected) |

---

## Roadmap

Leaf is actively being developed with the following features planned for future releases:

* **Enhanced Inverse Search**:
  * Out-of-the-box support for **Visual Studio Code (VSCode)**.
  * Support for **Custom Editors**: Allowing users to define arbitrary commands and arguments (e.g., using `%line` and `"%file"` placeholders) to seamlessly integrate with any text editor of their choice.
* **Text Selection HUD**: 
  * A subtle, non-intrusive pop-up displaying text information (e.g., character/word counts for multi-character selections) and character details (e.g., Unicode, embedded font information for single-character selections) when selecting text in the PDF.

---

## Why Leaf?

Most PDF viewers are designed for reading books, not for the rigorous, iterative cycle of writing and typesetting LaTeX. Leaf was built to be the "missing link" for TeX users who find standard viewers too heavy or cluttered. By using native macOS technologies like PDFKit and SwiftUI, Leaf provides a smooth, "Apple-native" feel with a binary size that is orders of magnitude smaller than Electron-based alternatives. 

It doesn't try to be everything for everyone. Instead, it aims to be the perfect companion for your text editor, quietly and flawlessly updating your document in the background—whether you are drafting an academic paper or professionally typesetting a multi-volume book.

---

## License

Distributed under the **BSD 3-Clause License**. See `LICENSE` for more information.

Copyright © 2026 Munehiro Yamamoto. All rights reserved.

--------------------

Munehiro Yamamoto
https://github.com/munepi
