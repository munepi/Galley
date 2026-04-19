# Galley ![Galley Icon](GalleyPDF.png)

**Galley** is a lightweight PDF previewer for macOS, designed with TeX/LaTeX authors and typesetters in mind. Developed by **Munehiro Yamamoto (@munepi)**, it removes unnecessary toolbars and status bars so you can focus on your document.

## The Core Philosophy: 1-to-1 Correspondence

Galley maintains a strict **1-to-1 correspondence** between your TeX source and its PDF output. It enforces a **single-window policy** — one source, one PDF, one window — so that SyncTeX operations always target the correct context without ambiguity.

## System Requirements

* **OS:** macOS 11.0 (Big Sur) or later.
* **Architecture:** Universal Binary (Native support for both Apple Silicon and Intel Macs).

## Key Features

* **Auto-Reload**: Monitors the PDF file for changes and reloads automatically, preserving your scroll position and zoom level.
* **SyncTeX Integration**:
  * **Forward Search**: Jump from your editor to the corresponding position in the PDF, highlighted with a fading red dot centered in the window.
  * **Inverse Search**: `Cmd + Click` anywhere in the PDF to jump back to the source line in your editor. Supports **Emacs**, **Visual Studio Code**, and **custom editors** via CLI.
* **Character Inspection**: Right-click a selected character to view its Unicode code point, name, plane, general category, embedded font name (PostScript), family, traits, point size (pt / mm / Q), vertical metrics (ascent / descent / leading), and Glyph ID (with CID notation for CJK).
* **Rectangular Selection & Measurement**: `Shift + Drag` to create a selection rectangle with real-time dimensions in mm. Drag inside an existing marquee to reposition it, or drag its edges/corners to resize. `Cmd + C` copies the selected area as a vector PDF.
* **Lightweight Rendering**: Galley draws only the PDF page itself — no annotation overlays or editing tools — so page rendering stays light even when flipping through pages quickly.


## Installation

### Download Binaries

Pre-compiled **Universal Binaries** are available under the [Releases](https://github.com/munepi/Galley/releases) section. 

1. Download `GalleyPDF_<version>.dmg`.
2. Double-click to mount the disk image.
3. Double-click `GalleyPDF.pkg` inside the mounted volume.
4. Follow the on-screen instructions to install **GalleyPDF.app**.
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

Galley communicates with external editors and scripts via its URL scheme.

### URL Scheme (`galleypdf://`)

Galley registers a custom URL scheme (`galleypdf://`) with macOS LaunchServices, giving editors a zero-overhead way to drive forward search and reload.

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
> **SyncTeX "Column 0" Workaround**
> Many PDF viewers have a known SyncTeX issue where forward search from the beginning of a line (column 0) incorrectly jumps to the end of the previous line. Galley detects `column=0` and automatically shifts the search target to `line + 1` to avoid this.

> [!WARNING]
> **Security Note on First Forward Search**
> The first time you execute a forward search from your editor (e.g., Emacs), macOS will present a security prompt asking for Automation permissions.
> Please click **OK (Allow)** to grant the necessary AppleEvents permissions. You can later manage this in **System Settings > Privacy & Security > Automation**.



## Configuration

Galley is configured via the macOS Menu Bar and `UserDefaults`. No configuration files are needed.

### 1. Emacs Setup (Forward Search)

To jump from Emacs to Galley, configure your TeX environment to call Galley's URL scheme using the `open` command.
Passing both the line and column numbers improves the accuracy of SyncTeX jumps.

#### For [AUCTeX](https://www.gnu.org/software/auctex/) Users
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


#### For [YaTeX](https://www.yatex.org/) Users
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


### 2. Visual Studio Code Setup (Forward Search)

For [LaTeX Workshop](https://marketplace.visualstudio.com/items?itemName=James-Yu.latex-workshop) users, add the following to your `settings.json`:

~~~jsonc
{
  // Enable SyncTeX
  "latex-workshop.synctex.afterBuild.enabled": true,

  // Register Galley as an external viewer
  "latex-workshop.view.pdf.viewer": "external",
  "latex-workshop.view.pdf.external.synctex.command": "open",
  "latex-workshop.view.pdf.external.synctex.args": [
    "-g",
    "galleypdf://forward?line=%LINE%&column=0&pdfpath=%PDF%&srcpath=%TEX%"
  ]
}
~~~

To execute Forward Search, press `Cmd + Opt + J` (or run **LaTeX Workshop: SyncTeX from cursor** from the Command Palette).


### 3. Selecting your Editor (Inverse Search)

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


### 4. Debug Logging

Galley emits structured logs via Apple's unified logging system (`os_log`) under the subsystem `com.github.munepi.galley`. Use this to verify SyncTeX coordinate data, inspect reload behavior, or troubleshoot Forward/Inverse Search.

* **Stream logs in Terminal**
~~~bash
log stream --predicate 'subsystem == "com.github.munepi.galley"' --level info
~~~

  A convenience target is also available in the source tree:
  ~~~bash
  make log
  ~~~

* **Inspect in Console.app**
  Open **Console.app**, select your Mac under *Devices*, and filter by `subsystem:com.github.munepi.galley`.



## Usage & Shortcuts

| Action | Shortcut / Gesture |
| :--- | :--- |
| **Open File** | `Cmd + O` or `open -a GalleyPDF document.pdf` |
| **Print** | `Cmd + P` |
| **Find** | `Cmd + F` (toggle search bar) |
| **Find Next / Previous** | `Enter` / `Shift + Enter` (while search bar is open) |
| **Zoom In/Out** | `Cmd + "+"` / `Cmd + "-"` |
| **Actual Size** | `Cmd + 0` |
| **Auto Resize** | `Cmd + _` |
| **Single Page** | `Cmd + 1` |
| **Single Page Continuous** | `Shift + Cmd + 1` |
| **Two Pages** | `Cmd + 2` |
| **Two Pages Continuous** | `Shift + Cmd + 2` |
| **Next Page** | `Space` or `Opt + J` |
| **Previous Page** | `Shift + Space` or `Opt + K` |
| **Jump to Page** | Type page number or label (e.g., `123`, `iv`, `cover`) |
| **Clear Selection / Cancel** | `Esc` |
| **Inverse Search** | `Cmd + Click` on PDF |
| **Character Inspection** | Right-click on selected text |
| **Measure / Move / Resize Area** | `Shift + Drag` (drag inside an existing marquee to move it; drag edges/corners to resize) |
| **Copy Selection** | `Cmd + C` (while area is selected, copies as vector PDF) |

### Page Navigation & Interface Notes
* **Direct Jump**: When you type a page number or label without any modifier keys, a minimalist HUD will appear at the bottom to guide your jump instantly. The input auto-commits after 1 second of inactivity.
* **Window Title Info**: To keep the interface zero-distraction, the title bar dynamically displays `<FileName> - Page <label> (<physical>/<total>)` (e.g., `document.pdf - Page iv (4/120)`).
* **Link Preview**: Hovering over a PDF link for 0.3 seconds shows a popover with a real-size snippet of the target page (internal links) or the URL text (external links). Clicking a link follows it normally.
* **Persistence**: Galley automatically remembers your Display Mode, Book Mode, and RTL settings using `UserDefaults`.


## Roadmap: The "Galley Pro" Ambitions

Galley is currently a focused, lightweight viewer. The following features are under consideration or in early exploration:

### 1. Universal SyncTeX Bridge: `pandoc-synctex`
A bidirectional synchronization bridge between structured text formats and Galley. By leveraging ASTs (like Pandoc's `+sourcepos`) and custom Lua filters, this would enable Forward/Inverse Search from the PDF back to sources in formats such as **Typst, SATySFi, Vivliostyle (VFM), AsciiDoc, and Re:VIEW**.

### 2. Hybrid Rendering Engine & Typography Inspector (Poppler + HarfBuzz + FreeType)
Apple's `PDFKit` is optimized for screen rendering and does not expose all print-related data. A hybrid backend using C++ libraries could provide:
* **Output Preview:** Extracting CMYK and Spot Color (e.g., DIC, PANTONE) values via **Poppler** in `/Separation` and `/DeviceN` modes.
* **Typography Inspector:** Displaying embedded font names, raw CIDs/GIDs, and subset statuses from the PDF stream.
* **OpenType Shaping Validation:** Using **HarfBuzz** and **FreeType** to verify whether glyph positioning matches the font's kerning, ligatures, and complex text layout rules.

### 3. PDF/X & PDF/A Preflight and Fixup
Native PDF/X (X-1a, X-4) and PDF/A validation and fixup, including transparency flattening, bleed box generation, color conversions (via macOS ColorSync), and ICC profile tagging (`/OutputIntents`).

### 4. Extended URL Scheme API
Expanding the `galleypdf://` URL scheme to expose more features for editor integration and automation.

*The following endpoints are tentative:*
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

### 5. Command Line Interface (CLI)
Providing CLI access to preflight, export, imposition, and viewer control so that any GUI operation can also be scripted from the terminal.


## Why Galley?

Most PDF viewers are general-purpose readers, not optimized for the edit–compile–preview cycle of TeX/LaTeX work.
Galley is built with native macOS technologies (PDFKit, AppKit) and has no external dependencies, resulting in a small binary and fast startup.

It does not try to be a general-purpose PDF reader.
Instead, it aims to be a reliable companion for your text editor, updating your document in the background as you write.


## License

Distributed under the **BSD 3-Clause License**. See `LICENSE` for more information.

Copyright © 2026 Munehiro Yamamoto. All rights reserved.

--------------------

Munehiro Yamamoto
[https://github.com/munepi](https://github.com/munepi)
