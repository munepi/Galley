# Galley ![Galley Icon](GalleyPDF.png)

**Galley** is a minimalist, ultra-lightweight PDF previewer specifically designed for TeX/LaTeX authors and professional typesetters on macOS. Developed by **Munehiro Yamamoto (@munepi)**, it provides a "content-first" experience by eliminating unnecessary toolbars and status bars, focusing entirely on your document and your workflow.

## The Core Philosophy: 1-to-1 Correspondence

Most PDF viewers are designed for reading multiple documents simultaneously. Galley is different. It maintains a strict **1-to-1 correspondence** between your TeX source and its PDF output. By enforcing a **single-window policy**, Galley ensures your focus remains on the current task without the clutter of multiple open documents, while ensuring SyncTeX operations always target the correct context.

## System Requirements

* **OS:** macOS 11.0 (Big Sur) or later.
* **Architecture:** Universal Binary (Native support for both Apple Silicon and Intel Macs).

## Key Features

* **⚡ High-Speed Auto-Reload**: Detects PDF updates instantly and reloads the document while preserving your scroll position and zoom level.
* **🎯 Precise SyncTeX Integration**:
  * **Forward Search**: Jump from your editor to the exact line in the PDF with a soft-fading red dot highlight, automatically centered in the window for better visibility.
  * **Inverse Search**: Command-Click anywhere in the PDF to jump back to the corresponding source line in your editor. Supported editors include **Emacs**, **Visual Studio Code**, and any **Custom Editor** via CLI.
* **📏 Precision Measurements**: Hold **Shift + Drag** to create a rectangular selection. You can also reposition an existing selection by holding **Shift** and dragging inside the marquee. Real-time dimensions are displayed in millimeters at the point of selection, and the area can be copied as a high-fidelity vector PDF object.
* **🖋️ Featherweight & Zero-Distraction**:
  * An incredibly small footprint (~600KB), leveraging native macOS frameworks.
  * A truly minimalist interface that gives 100% of the window space to your PDF, keeping you in the flow of writing and editing.



## Installation

### Download Binaries

Pre-compiled **Universal Binaries** are available under the [Releases](https://github.com/munepi/Galley/releases) section. 

1. Download `GalleyPDF.dmg`.
2. Double-click to open the disk image.
3. Drag **GalleyPDF.app** to the `Applications` folder shortcut.

> [!NOTE]
> Galley will undergo Apple Notarization in the future. For now, if macOS warns you about an unidentified developer, simply **Right-Click** `GalleyPDF.app` in your Applications folder and select **"Open"** to bypass Gatekeeper for the first launch.

### Building from Source

If you prefer to build it yourself, ensure you have the Swift compiler installed (via Xcode or Command Line Tools).

~~~bash
# Clone the repository
git clone https://github.com/munepi/Galley.git
cd Galley

# Build Universal Binary
make app
~~~



## Configuration

Galley is designed to be configured via the macOS Menu Bar and `UserDefaults` to maintain its clean, zero-UI aesthetic.

### 1. Selecting your Editor (Inverse Search)

You can select your preferred editor for Inverse Search (`Cmd + Click`) directly from the **SyncTeX** menu in the menu bar:

* **Emacs**: Uses `emacsclient`. (Default)
* **Visual Studio Code**: Uses the native `vscode://` URL scheme.
* **Custom...**: Uses a user-defined shell command.

#### Custom Editor Command
When **"Custom..."** is selected, Galley executes the command stored in the `customEditorCommand` preference. You can use `%file` and `%line` as placeholders.

Set your custom command via Terminal:

~~~bash
# Example for VSCode (CLI)
defaults write com.github.munepi.galley customEditorCommand "/opt/homebrew/bin/code --goto '%file':%line"

# Example for Sublime Text
defaults write com.github.munepi.galley customEditorCommand "/opt/homebrew/bin/subl '%file':%line"

# Example for Vim (CLI)
defaults write com.github.munepi.galley customEditorCommand "/opt/homebrew/bin/vim --remote-silent +%line '%file'"

# Example for MacVim
defaults write com.github.munepi.galley customEditorCommand "/opt/homebrew/bin/mvim --remote-silent +%line '%file'"
~~~

#### Specifying Emacsclient Path
If your `emacsclient` is not in the standard PATH, specify it here:
~~~bash
defaults write com.github.munepi.galley emacsclientPath "/opt/homebrew/bin/emacsclient"
~~~

### 2. Emacs Setup (Forward Search)

To jump from Emacs to Galley, configure your TeX environment to call Galley's `displayline` script.

> [!NOTE]
> **⚠️ Security Note on First Forward Search**
> The first time you execute a forward search from your editor (e.g., Emacs), macOS will present a security prompt asking for Automation permissions. Please click **OK (Allow)** to grant the necessary AppleEvents permissions. You can later manage this in **System Settings > Privacy & Security > Automation**.

#### For AUCTeX Users
Add the following to your `init.el` or `.emacs`:

~~~elisp
;; Enable SyncTeX correlation
(setq TeX-source-correlate-mode t)
(setq TeX-source-correlate-start-server t)

;; Register Galley as a custom PDF viewer
(add-to-list 'TeX-view-program-list
             '("Galley" "/Applications/GalleyPDF.app/Contents/MacOS/displayline -g %n %o %b"))

;; Set Galley as the default viewer for PDF output
(setq TeX-view-program-selection '((output-pdf "Galley")))
~~~

To execute Forward Search in AUCTeX, simply press `C-c C-v` (or `C-c C-c` and select `View`).


#### For YaTeX Users
Add the following to your `init.el` or `.emacs`:

~~~elisp
(defun YaTeX:galley-forward-search ()
  "Perform a Forward Search in the PDF corresponding to the current line using Galley."
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
         (cmd "/Applications/GalleyPDF.app/Contents/MacOS/displayline"))

    (if (file-executable-p cmd)
        ;; Add the -g option to perform the jump in the background without bringing Galley to the foreground
        (let ((proc (start-process "displayline" nil cmd "-g" line pdf-file tex-file)))
          (if (fboundp 'set-process-query-on-exit-flag)
              (set-process-query-on-exit-flag proc nil)
            (process-kill-without-query proc)))
      (message "Executable file not found. Please ensure GalleyPDF.app is installed correctly."))))

;; Shortcut key configuration for YaTeX (e.g., prefix + C-l)
(add-hook 'yatex-mode-hook
          (lambda ()
            ;; (YaTeX-define-key "\C-j" 'YaTeX:galley-forward-search)
            (YaTeX-define-key "\C-l" 'YaTeX:galley-forward-search)
        ))
~~~

### 3. Debug Mode

If you need to verify SyncTeX coordinate data or troubleshoot Forward Search, you can enable the HUD (Head-Up Display):

* **Option 1: Permanent Enable**
~~~bash
defaults write com.github.munepi.galley debugMode -bool true
~~~

* **Option 2: Temporary Enable (Terminal)**
~~~bash
/Applications/GalleyPDF.app/Contents/MacOS/GalleyPDF /path/to/document.pdf -debugMode YES
~~~

In Debug Mode, the HUD stays visible for 15 seconds to ensure you have enough time to read the coordinates.



## Usage & Shortcuts

| Action | Shortcut / Gesture |
| :--- | :--- |
| **Open File** | `Cmd + O` or `open -a GalleyPDF document.pdf` |
| **Zoom In/Out** | `Cmd + "+"` / `Cmd + "-"` |
| **Actual Size** | `Cmd + 0` |
| **Auto Resize** | `Cmd + _` |
| **Next Page** | `Space` or `Opt + J` |
| **Previous Page** | `Shift + Space` or `Opt + K` |
| **Jump to Page** | Type page number or label (e.g., `123`, `iv`, `cover`) |
| **Clear Selection / Cancel Jump** | `Esc` |
| **Inverse Search** | `Cmd + Click` on PDF |
| **Measure / Move Area** | `Shift + Drag` (drag inside an existing marquee to move it) |
| **Copy Selection** | `Cmd + C` (while area is selected) |

### Page Navigation & Interface Notes
* **Direct Jump**: When you type a page number or label without any modifier keys, a minimalist HUD will appear at the bottom to guide your jump instantly.
* **Window Title Info**: To keep the interface zero-distraction, the title bar dynamically displays `<FileName> - Page <label> (<physical>/<total>)` (e.g., `document.pdf - Page iv (4/120)`) or simply `Page <physical>/<total>` instead of using a bulky status bar.
* **Display Modes**: You can switch between Single Page, Two Pages, Continuous, Book Mode, and Right-To-Left (RTL) layouts from the **View** menu in the macOS menu bar.

### Persistence
Galley automatically remembers your **Display Mode** (Single/Two Pages), **Book Mode**, and **Right-To-Left** (RTL) settings using `UserDefaults`. Your preferred viewing environment is restored every time you open the app.



## Roadmap

Galley is actively being developed with the following features planned:

* **Text Selection HUD**: A subtle pop-up displaying character/word counts and Unicode/Font information for professional typesetting analysis.
* **GUI Preferences**: An in-app settings window to manage editor commands and defaults without using the command line.


## Why Galley?

Most PDF viewers are designed for reading books, not for the rigorous, iterative cycle of writing and typesetting LaTeX. 
Galley was built to be the "missing link" for TeX users who find standard viewers too heavy or cluttered. 
By using native macOS technologies like PDFKit and SwiftUI, Galley provides a smooth, "Apple-native" feel with a binary size that is orders of magnitude smaller than Electron-based alternatives. 

It doesn't try to be everything for everyone. 
Instead, it aims to be the perfect companion for your text editor, quietly and flawlessly updating your document in the background—whether you are drafting an academic paper or professionally typesetting a multi-volume book.


## License

Distributed under the **BSD 3-Clause License**. See `LICENSE` for more information.

Copyright © 2026 Munehiro Yamamoto. All rights reserved.

--------------------

Munehiro Yamamoto
[https://github.com/munepi](https://github.com/munepi)
