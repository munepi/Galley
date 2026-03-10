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
  * A lightweight executable (~740KB) and lean app bundle, leveraging native macOS frameworks to ensure near-instant startup and peak efficiency.
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



## Integration & Automation

Galley provides two ways to communicate with external editors and scripts. **Using the URL Scheme is highly recommended for maximum performance.**

### 1. URL Scheme (`galleypdf://`) - ⭐️ Recommended

Galley registers a custom URL scheme (`galleypdf://`) with macOS LaunchServices. This allows zero-overhead, instantaneous communication with the app, bypassing the need for Bash execution or AppleScript compilation.

Available endpoints:

* **Force Reload**
  ~~~bash
  open -g "galleypdf://reload"
  ~~~

* **Forward Search**
  ~~~bash
  open -g "galleypdf://forward?line=<line>&pdfpath=<absolute_pdf_path>"

  open -g "galleypdf://forward?line=<line>&pdfpath=<absolute_pdf_path>&srcpath=<absolute_src_path>"

  open -g "galleypdf://forward?line=<line>&column=<column>&pdfpath=<absolute_pdf_path>&srcpath=<absolute_src_path>"
  ~~~
  *(Note: URL parameters must be URL-encoded, especially if paths contain spaces.)*

  > [!TIP]
  > **Overcoming the SyncTeX "Column 0" Limitation**
  > Most PDF viewers suffer from a notorious SyncTeX issue where initiating a forward search from the beginning of a line (column 0) incorrectly jumps to the end of the previous line. **Galley automatically detects `column=0` and intelligently shifts the search target to `line + 1`**, guaranteeing precise jumps regardless of your cursor position.

  > [!WARNING]
  > **Security Note on First Forward Search**
  > The first time you execute a forward search from your editor (e.g., Emacs), macOS will present a security prompt asking for Automation permissions. 
  > Please click **OK (Allow)** to grant the necessary AppleEvents permissions. You can later manage this in **System Settings > Privacy & Security > Automation**.



### 2. Command Line Utility (`displayline`)

For legacy compatibility with older scripts, Galley includes a `displayline` bash script inside the application bundle.

> [!WARNING]
> **Performance Note**: We highly recommend migrating your editor configurations to the `galleypdf://` URL scheme. The `displayline` utility relies on `osascript` (AppleEvents), which introduces a noticeable delay (several hundred milliseconds) due to process forking and script compilation. The URL scheme is significantly faster.

Usage:
~~~bash
/Applications/GalleyPDF.app/Contents/MacOS/displayline [-g] LINE PDFFILE [SRCFILE]
~~~



## Configuration

Galley is designed to be configured via the macOS Menu Bar and `UserDefaults` to maintain its clean, zero-UI aesthetic.

### 1. Emacs Setup (Forward Search)

To jump from Emacs to Galley, configure your TeX environment to call Galley's high-speed URL scheme using the `open` command. 
By passing both the line and column numbers, Galley can perform highly accurate SyncTeX jumps.

#### For AUCTeX Users
Add the following to your `init.el` or `.emacs`. 
We define a custom expansion `%c` to pass the cursor's current column to Galley.

~~~elisp
;; Enable SyncTeX correlation
(setq TeX-source-correlate-mode t)
(setq TeX-source-correlate-start-server t)

;; Define %c to get the current column for precise Forward Search
(add-to-list 'TeX-expand-list
             '("%c" (lambda () (number-to-string (current-column)))))

;; Register Galley as a custom PDF viewer
(add-to-list 'TeX-view-program-list
             '("Galley" "open -g \"galleypdf://forward?line=%n&column=%c&pdfpath=%o&srcpath=%b\""))

;; Set Galley as the default viewer for PDF output
(setq TeX-view-program-selection '((output-pdf "Galley")))
~~~

To execute Forward Search in AUCTeX, simply press `C-c C-v` (or `C-c C-c` and select `View`).


#### For YaTeX Users
Add the following function to your `init.el` or `.emacs`. 
It extracts both the line and column numbers and safely URL-encodes the paths before sending them to macOS LaunchServices.

~~~elisp
(defun YaTeX:galley-forward-search ()
  "Perform a precise Forward Search using Galley's URL scheme."
  (interactive)
  (require 'url-util)
  (let* ((line (number-to-string (save-restriction
                                   (widen)
                                   (count-lines (point-min) (point)))))
         (column (number-to-string (current-column)))
         (pdf-file (expand-file-name
                    (concat (file-name-sans-extension
                             (or YaTeX-parent-file
                                 (save-excursion
                                   (YaTeX-visit-main t)
                                   buffer-file-name)))
                            ".pdf")))
         (tex-file buffer-file-name)
         (url (format "galleypdf://forward?line=%s&column=%s&pdfpath=%s&srcpath=%s"
                      line
                      column
                      (url-hexify-string pdf-file)
                      (url-hexify-string tex-file))))
    ;; Add the -g option to perform the jump in the background without bringing Galley to the foreground.
    (start-process "galley-forward" nil "open" "-g" url)))

;; Shortcut key configuration for YaTeX (e.g., prefix + C-j)
(add-hook 'yatex-mode-hook
          (lambda ()
            (YaTeX-define-key "\C-j" 'YaTeX:galley-forward-search)
            ;; (YaTeX-define-key "\C-l" 'YaTeX:galley-forward-search)
        ))
~~~


### 2. Selecting your Editor (Inverse Search)

You can select your preferred editor for Inverse Search (`Cmd + Click`) directly from the **SyncTeX** menu in the menu bar:

* **Emacs**: Uses `emacsclient`. (Default)
  * Galley automatically searches for the executable in the following default locations:
    1. `/Applications/Emacs.app/Contents/MacOS/bin/emacsclient`
    2. `/opt/homebrew/bin/emacsclient`
    3. `/usr/local/bin/emacsclient`
* **Visual Studio Code**: Uses the native `vscode://` URL scheme.
* **Custom**: Uses a user-defined shell command.

#### Custom Editor Command
When **"Custom..."** is selected, Galley executes the command stored in the `customEditorCommand` preference. You can use `%file` and `%line` as placeholders.

Set your custom command via Terminal:

~~~bash
# Example for VSCode (CLI)
defaults write com.github.munepi.galley customEditorCommand "/opt/homebrew/bin/code --goto '%file':%line"

# Example for Sublime Text
defaults write com.github.munepi.galley customEditorCommand "/opt/homebrew/bin/subl '%file':%line"
~~~

#### Specifying Emacsclient Path
If your `emacsclient` is located in a path other than the default locations listed above, you must specify its absolute path here:

~~~bash
defaults write com.github.munepi.galley emacsclientPath "/path/to/your/emacsclient"
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
* **Window Title Info**: To keep the interface zero-distraction, the title bar dynamically displays `<FileName> - Page <label> (<physical>/<total>)` (e.g., `document.pdf - Page iv (4/120)`).
* **Persistence**: Galley automatically remembers your Display Mode, Book Mode, and RTL settings using `UserDefaults`.


## Roadmap: The "Galley Pro" Ambitions

Galley currently focuses on being the fastest, most precise lightweight viewer for macOS. However, we have a massive roadmap aimed at transforming Galley into an ultimate open-source Swiss Army knife for professional typesetters and DTP operators.

Here are the experimental features and architectures currently in the R&D phase:

### 1. Universal SyncTeX Bridge: `pandoc-synctex`
Going beyond traditional SyncTeX. We are building a universal bidirectional synchronization bridge between **any structured text format** and Galley. By leveraging ASTs (like Pandoc's `+sourcepos`) and custom Lua filters, this will allow true Forward/Inverse Search directly from the final PDF back to your original lightweight markup sources—not just Markdown, but also **Typst, SATySFi, Vivliostyle (VFM), AsciiDoc, and Re:VIEW**—without breaking the rendering pipeline.

### 2. Galley Pro Hybrid Engine & Typography Inspector (Poppler + HarfBuzz + FreeType)
Apple's native `PDFKit` is optimized for RGB screen rendering, which hides crucial print data. We plan to statically link C++ libraries to build a professional hybrid backend combined with an advanced **Text Selection HUD**:
* **True Output Preview:** Rendering 1x1 pixel samples in `/Separation` and `/DeviceN` modes via **Poppler** to extract pure CMYK and Spot Color (e.g., DIC, PANTONE) percentages, completely bypassing OS-level RGB fallbacks.
* **Ultimate Typography Inspector:** A subtle HUD displaying character/word counts, while extracting the *true* embedded font names, raw CIDs/GIDs, and subset statuses directly from the PDF stream.
* **OpenType Shaping Validation:** Passing extracted raw text to **HarfBuzz** and **FreeType** to logically verify if the PDF's absolute glyph positioning matches the font's internal kerning, ligatures, and complex text layout (CTL) rules.

### 3. Native PDF/X & PDF/A Preflight and Fixup
The holy grail of open-source DTP. Instead of relying on the unpredictable Ghostscript (`gs`), we are developing a native PDF/X (X-1a, X-4) and PDF/A export and fixup engine. We aim to implement enterprise-grade transparency flattening, bleed box generation, deep color conversions (via macOS ColorSync), and correct ICC profile tagging (`/OutputIntents`) to ensure print-ready compliance.

### 4. Comprehensive URL Scheme API
We plan to significantly expand our `galleypdf://` URL scheme. Beyond zero-overhead reloading and SyncTeX jumping, we will expose Galley's advanced features to URL events, enabling deep integration with external editors, CI/CD pipelines, and automation scripts. 

*While the exact endpoint names and parameters are still in the conceptual phase, here is a glimpse of the API we envision:*
* **Advanced Navigation**: `galleypdf://page?num=iv` or `galleypdf://find?query=Theorem1`
* **Build Integration**: `galleypdf://highlight?page=5&rect=x,y,w,h` (Visualizing compiler errors or Overfull hboxes directly on the PDF)
* **Dynamic Configuration**: `galleypdf://set?editor=vscode` (Changing the target editor per project without restarting)
* **Preflight & Visualization**:
    * `galleypdf://boxes?show=trim,bleed` (Overlaying TrimBox and BleedBox lines)
    * `galleypdf://fonts?audit=true` (Highlighting un-embedded or Type 3 fonts)
    * `galleypdf://ink?tac=300` (Highlighting Total Area Coverage violations)
    * `galleypdf://audit?warn=hairline&threshold=0.25` (Detecting hairlines that might disappear in print)
* **Document Manipulation & Diff**:
    * `galleypdf://props?set=openaction&mode=UseOutlines` (Forcing PDF open actions)
    * `galleypdf://diff?target=/path/to/old.pdf&mode=difference` (Visual diffing for proofreaders)
* **Export & Conversion**:
    * `galleypdf://convert?format=pdfx4&input=<pdf>&output=<pdf>`
    * `galleypdf://convert?action=vivid-cmyk&n-colors=5` (Algorithmic RGB-to-CMYK conversion mitigating gamut clipping, optionally injecting `/Separation` or `/DeviceN` for wide-gamut and vivid print results)
    * `galleypdf://imposition?layout=booklet` (Dynamic N-up/Booklet preview and generation)

### 5. Full Command Line Interface (CLI) Equivalency
A core philosophy for Galley's future: **anything you can do in the GUI, you should be able to do via the CLI**. We are building a robust command-line interface that allows you to execute precise PDF/X preflight/exports, generate N-up impositions, apply vivid CMYK conversions, dump Typography Inspector data, and manipulate the viewer seamlessly from your terminal.


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
