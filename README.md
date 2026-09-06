# Galley ![Galley Icon](GalleyPDF.png)

Galley is a lightweight PDF previewer for macOS, designed with TeX/LaTeX authors and typesetters in mind. Developed by Munehiro Yamamoto (@munepi), it removes unnecessary toolbars and status bars so you can focus on your document.

## The Core Philosophy: 1-to-1 Correspondence

Galley maintains a strict 1-to-1 correspondence between your TeX source and its PDF output. It enforces a single-window policy — one source, one PDF, one window — so that SyncTeX operations always target the correct context without ambiguity.

## System Requirements

* OS: macOS 11.0 (Big Sur) or later.
* Architecture: Universal Binary (native support for both Apple Silicon and Intel Macs).

## Key Features

* Auto-Reload: monitors the PDF file for changes and reloads automatically, preserving your scroll position and zoom level.
* SyncTeX Integration:
  * Forward Search: jump from your editor to the corresponding position in the PDF, highlighted with a fading red dot centered in the window.
  * Inverse Search: `Cmd + Click` anywhere in the PDF to jump back to the source line in your editor. Supports Emacs, Visual Studio Code, Vim/Neovim (VimTeX), and custom editors via CLI.
* Character Inspection: right-click a selected character to view its Unicode code point, name, plane, general category, embedded font name (PostScript), family, traits, point size (pt / mm / Q), vertical metrics (ascent / descent / leading), and Glyph ID (with CID notation for CJK).
* Rectangular Selection & Measurement: `Shift + Drag` to create a selection rectangle with real-time dimensions in mm. Drag inside an existing marquee to reposition it, or drag its edges/corners to resize. `Cmd + C` copies the selected area as a vector PDF.
* PDF Info Sidebar: a side panel with five views, each toggled from the View menu. Sidebar contents can be exported as Markdown or JSON via File ▸ Export… or the in-panel Export dropdown.
  * Info (`Cmd + I`): Document Info, PDF/X, PDF/A, PDF/UA, Security, Pages, Features, Fonts (embedded font scan via `CGPDFDocument` covering inherited page resources and Form XObjects), and the raw XMP packet parsed into sections.
  * Bookmarks (`Cmd + B`): the document outline, click-to-navigate.
  * Annotations (`Cmd + N`): all annotations with click-to-navigate; `Cmd + C` copies the selected annotation content.
* Text Search: `Cmd + F` opens an incremental search bar with a match counter, whole-document highlighting, `Match Case` and `Regex` options, and matching across line breaks. `Cmd + G` / `Shift + Cmd + G` step through matches without the search bar focused, and `Cmd + E` searches for the current selection.
* Page Color: View ▸ Page Color recolors the page for comfortable reading. `Dark` and `Charcoal` invert text and vector art while leaving photographs positive; `Sepia`, `Orange` and `Gray` tint the paper and leave the ink alone. Every preset keeps a WCAG AAA (7:1) contrast ratio, and the change is display-only — copying, exporting and printing keep the document's original colors.
* Lightweight Rendering: Galley draws only the PDF page itself — no annotation overlays or editing tools — so page rendering stays light even when flipping through pages quickly.


## Installation

### Homebrew

~~~bash
brew install --cask munepi/galley/galley
~~~

This installs `GalleyPDF.app` into `/Applications` and puts the bundled
[`galleypdf`](#command-line-galleypdf) command on your `PATH`.

Homebrew 6 and later only loads casks from non-official taps after you trust
them. If the install is blocked, trust the cask first and run the install
again:

~~~bash
brew trust munepi/galley/galley
~~~

### Download Binaries

Pre-compiled Universal Binaries are available under the [Releases](https://github.com/munepi/Galley/releases) section.

1. Download `GalleyPDF_<version>.dmg`. It is signed with a Developer ID and notarized by Apple.
2. Double-click to mount the disk image.
3. Drag `GalleyPDF.app` onto the `Applications` shortcut.

### Building from Source

If you prefer to build it yourself, ensure you have the Swift compiler installed (via Xcode or Command Line Tools).

~~~bash
# Clone the repository
git clone https://github.com/munepi/Galley.git
cd Galley

# Build Universal Binary
make app

# Copy GalleyPDF.app to /Applications, then link the CLI onto your PATH
make install
sudo make install-cli          # override the location with CLI_PREFIX=...
~~~



## Integration & Automation

Galley communicates with external editors and scripts via its URL scheme.
The `galleypdf` command is a thin front end over that same scheme, so both routes behave identically.

### Command Line (`galleypdf`)

`galleypdf` ships inside the application bundle at `GalleyPDF.app/Contents/MacOS/bin/galleypdf` — the same layout Emacs uses for `emacsclient`.

Homebrew puts it on your `PATH` for you. If you installed from the disk image, pick whichever of these you prefer — both keep working across updates, because they point into the bundle rather than at a copy:

~~~bash
# Add the bundle's bin directory to PATH (no administrator rights needed)
export PATH="/Applications/GalleyPDF.app/Contents/MacOS/bin:$PATH"

# ...or link the command into a directory already on your PATH
sudo ln -sf /Applications/GalleyPDF.app/Contents/MacOS/bin/galleypdf /usr/local/bin/galleypdf
~~~

Building from source? `sudo make install-cli` creates the same symlink, and honours `CLI_PREFIX`.

~~~bash
galleypdf paper.pdf                 # open a PDF
galleypdf open -p 12 paper.pdf      # open it at page 12
galleypdf open -g paper.pdf         # ... without stealing focus
galleypdf reload                    # force a reload of the current PDF
galleypdf forward -g -l 120 -c 8 -s paper.tex paper.pdf
galleypdf displayline -g 120 paper.pdf paper.tex
~~~

| Command | Description |
| --- | --- |
| `open [-g] [-p PAGE] <file.pdf>` | Open a PDF, optionally jumping to a page. Also the default when the first argument is a file. |
| `reload` | Force Galley to reload the PDF it is currently showing. |
| `forward [-g] -l LINE [-c COL] [-s SRC] <file.pdf>` | SyncTeX forward search. |
| `displayline [-g] LINE <file.pdf> [SRC]` | Same as `forward`, using Skim's `displayline` argument order. |
| `--app-path`, `--version`, `--help` | Report the bundle in use, its version, or usage. |

`-g` (`--background`) performs the action without bringing Galley to the foreground.
Relative paths are resolved against the working directory, and paths containing spaces or non-ASCII characters are percent-encoded for you.

The command talks to the bundle it was launched from, so a symlink from any prefix resolves to the right copy of Galley.
Set `GALLEYPDF_APP` to target a different bundle, or `GALLEYPDF_DRY_RUN=1` to print the `galleypdf://` URL instead of sending it.

### URL Scheme (`galleypdf://`)

Galley registers a custom URL scheme (`galleypdf://`) with macOS LaunchServices, giving editors a zero-overhead way to drive forward search and reload.

Available endpoints:

* Force Reload
  ~~~bash
  open -g "galleypdf://reload"
  ~~~

* Open a PDF
  ~~~bash
  open "galleypdf://open?pdfpath=<absolute_pdf_path>"

  open "galleypdf://open?pdfpath=<absolute_pdf_path>&page=<page>"
  ~~~

* Forward Search
  ~~~bash
  open -g "galleypdf://forward?line=<line>&pdfpath=<absolute_pdf_path>"

  open -g "galleypdf://forward?line=<line>&pdfpath=<absolute_pdf_path>&srcpath=<absolute_src_path>"

  open -g "galleypdf://forward?line=<line>&column=<column>&pdfpath=<absolute_pdf_path>&srcpath=<absolute_src_path>"
  ~~~
  *(Note: URL parameters must be URL-encoded, especially if paths contain spaces.)*

Every endpoint accepts `background=1`, which pairs with `open -g`: Galley shows the window but leaves your editor in the foreground.

> [!TIP]
> **SyncTeX "Column 0" Workaround**
> Many PDF viewers have a known SyncTeX issue where forward search from the beginning of a line (column 0) incorrectly jumps to the end of the previous line. Galley detects `column=0` and automatically shifts the search target to `line + 1` to avoid this.

> [!WARNING]
> **Security Note on First Forward Search**
> The first time you execute a forward search from your editor (e.g., Emacs), macOS will present a security prompt asking for Automation permissions.
> Please click **OK (Allow)** to grant the necessary AppleEvents permissions. You can later manage this in System Settings > Privacy & Security > Automation.



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

To execute Forward Search, press `Cmd + Opt + J` (or run `LaTeX Workshop: SyncTeX from cursor` from the Command Palette).


### 3. Vim / Neovim Setup (Forward Search)

[VimTeX](https://github.com/lervag/vimtex) v2.18 and later ships with native Galley support. Add the following to your `vimrc` / `init.vim`:

~~~vim
let g:vimtex_view_method = 'galley'
~~~

Galley is opened and updated in the background by default. Set `g:vimtex_view_galley_activate` to `1` to bring it to the foreground after a forward search.

To execute Forward Search, run `:VimtexView` (default mapping: `<localleader>lv`).


### 4. Selecting your Editor (Inverse Search)

You can select your preferred editor for Inverse Search (`Cmd + Click`) directly from the SyncTeX menu in the menu bar:

* Emacs: uses `emacsclient`. (Default)
  * Galley automatically searches for the executable in the following default locations:
    1. `/Applications/Emacs.app/Contents/MacOS/bin/emacsclient`
    2. `/opt/homebrew/bin/emacsclient`
    3. `/usr/local/bin/emacsclient`
* Visual Studio Code: uses the native `vscode://` URL scheme.
* Vim/Neovim (VimTeX): runs `:VimtexInverseSearch` in a headless instance, which forwards the jump to your running Vim or Neovim (the same approach as the VimTeX preset for Skim). Requires the [VimTeX](https://github.com/lervag/vimtex) plugin.
  * Galley runs one of the following commands. Only the startup flags differ; VimTeX itself absorbs the difference between Vim's `clientserver` and Neovim's RPC:
    ~~~bash
    vim  -v --not-a-term -T dumb -c "VimtexInverseSearch <line> '<file>'"
    nvim --headless              -c "VimtexInverseSearch <line> '<file>'"
    ~~~
  * Which binary to launch is decided by the `vimtexFlavor` preference. See [Selecting Vim or Neovim](#selecting-vim-or-neovim) below.
* Custom: uses a user-defined shell command.

#### Custom Editor Command
When `Custom...` is selected, Galley executes the command stored in the `customEditorCommand` preference. You can use `%file` and `%line` as placeholders.

Set your custom command via Terminal:

~~~bash
# Example for VSCode (CLI)
defaults write com.github.munepi.galley customEditorCommand "/opt/homebrew/bin/code --goto '%file':%line"

# Example for Sublime Text
defaults write com.github.munepi.galley customEditorCommand "/opt/homebrew/bin/subl '%file':%line"
~~~

Galley's `%file` and `%line` placeholders carry the same meaning as Skim's, so a command written for Skim can usually be reused as-is. This also covers Vim plugins that use a different protocol from VimTeX. For example, [vim-skim-synctex](https://github.com/ryota2357/vim-skim-synctex) runs an HTTP server inside the editor instead of launching a headless instance, so it is driven with `curl` rather than the built-in `Vim/Neovim (VimTeX)` entry:

~~~bash
# Example for vim-skim-synctex (adjust the port to match synctex#option('port', ...))
defaults write com.github.munepi.galley customEditorCommand "curl localhost:8080 -XPUT -d '%line %file'"
~~~

#### Specifying Emacsclient Path
If your `emacsclient` is located in a path other than the default locations listed above, you must specify its absolute path here:

~~~bash
defaults write com.github.munepi.galley emacsclientPath "/path/to/your/emacsclient"
~~~

#### Selecting Vim or Neovim
By default (`vimtexFlavor = auto`), Galley launches `nvim` if it can find one and falls back to `vim` otherwise. Pin it explicitly if you have both installed:

~~~bash
defaults write com.github.munepi.galley vimtexFlavor "vim"   # or "nvim", or "auto"
~~~

The executable is searched for in `/opt/homebrew/bin`, `/usr/local/bin`, and `/usr/bin`, in that order. If your binary lives elsewhere, specify its absolute path:

~~~bash
defaults write com.github.munepi.galley vimPath "/path/to/your/vim"
defaults write com.github.munepi.galley nvimPath "/path/to/your/nvim"
~~~

> [!NOTE]
> The `vim` bundled with macOS (`/usr/bin/vim`) is built without `+clientserver`, so inverse search silently does nothing with it. Check with `vim --version | grep clientserver`, and point `vimPath` at a build that has it (typically MacVim):
>
> ~~~bash
> defaults write com.github.munepi.galley vimPath "/Applications/MacVim.app/Contents/MacOS/Vim"
> ~~~
>
> Neovim has RPC built in and needs no equivalent setup.


### 5. Page Color

View ▸ Page Color recolors the page. It is an accessibility and reading-comfort setting, not a document edit: copying, exporting and printing are untouched, and the choice is remembered in `pageColorMode` across launches.

| Preset | What it does |
| :--- | :--- |
| `Normal` | The document as authored. Nothing is installed in the rendering path. |
| `Dark` | Inverts the page onto PDFKit's dark paper (`#1E1E1E`), the same color Preview uses. |
| `Charcoal` | The same inversion onto a slightly lighter, slightly warmer paper (`#2C2C2B`). |
| `Sepia` | Tints the paper `#F4ECD8`. Ink stays black. |
| `Orange` | Tints the paper `#FFF0D9`. Ink stays black. |
| `Gray` | Tints the paper `#D8D8D2`. Ink stays black. |

`Dark` and `Charcoal` swap light for dark while preserving hue, so a `hyperref` link stays blue and a red TikZ rule stays red rather than flipping to its complement. On macOS 26 and later, Galley hands the inversion to PDFKit itself — the same facility behind Preview's *Use Dark Appearance for PDF* — which protects embedded raster images, so photographs and screenshots stay positive.

`Sepia`, `Orange` and `Gray` are drawn as a multiply-blended overlay rather than an image filter, so glyphs stay vector-sharp at any zoom level and nothing is inverted. They are the better choice for design-heavy documents.

> [!NOTE]
> PDFKit decides what to invert by drawing operator, not by intent: anything drawn as text or vector paths is inverted, and only raster images are protected. A pictorial illustration exported from Illustrator is therefore inverted just like a TikZ diagram — Preview behaves identically with the same file. Use `Sepia` or `Gray` for such documents.

On macOS 25 and earlier the SPI does not exist, and Galley falls back to a layer filter. That fallback inverts embedded images as well, cannot set the paper color (so `Charcoal` looks like `Dark`), and rasterizes at the current zoom level. The paper-tinting presets are unaffected.

`Dark` and `Charcoal` are greyed out while System Settings ▸ Accessibility ▸ Display ▸ *Invert colors* is on, so the page is never inverted twice. Toggling that system setting updates the menu without relaunching Galley.

#### Adjusting the Dark Page Color

`Dark` uses the same paper color as Preview (`#1E1E1E`), and `Charcoal` uses `#2C2C2B`. If neither weight suits you, `Dark` can be tuned:

~~~bash
defaults write com.github.munepi.galley pageColorDarkPaper "#282828"
~~~

Anything from roughly `#242424` to `#303030` reads as a softer dark; past that the page starts to look washed out rather than dark. Delete the key to return to the default. Colors whose relative luminance exceeds 0.10 are ignored, so that light text keeps a WCAG AAA (7:1) contrast ratio against the page. `Charcoal` is unaffected by this preference.

> [!NOTE]
> This is an unadvertised preference that rides on a private PDFKit facility, and it exists only because the default suits some readers and not others. It may be removed or stop working in a future release of Galley or of macOS. Nothing else depends on it — if it goes away, `Dark` simply returns to the default paper color.


### 6. Debug Logging

Galley emits structured logs via Apple's unified logging system (`os_log`) under the subsystem `com.github.munepi.galley`. Use this to verify SyncTeX coordinate data, inspect reload behavior, or troubleshoot Forward/Inverse Search.

Stream logs in Terminal:

~~~bash
log stream --predicate 'subsystem == "com.github.munepi.galley"' --level info
~~~

A convenience target is also available in the source tree:

~~~bash
make log
~~~

Alternatively, open Console.app, select your Mac under *Devices*, and filter by `subsystem:com.github.munepi.galley`.



## Usage & Shortcuts

| Action | Shortcut / Gesture |
| :--- | :--- |
| Open File | `Cmd + O` or `open -a GalleyPDF document.pdf` |
| Print | `Cmd + P` |
| Find | `Cmd + F` (toggle search bar) |
| Find Next / Previous | `Cmd + G` / `Shift + Cmd + G` (also `Enter` / `Shift + Enter` while the search bar is focused) |
| Use Selection for Find | `Cmd + E` |
| Zoom In/Out | `Cmd + "+"` / `Cmd + "-"` |
| Actual Size | `Cmd + 0` |
| Auto Resize | `Cmd + _` |
| Single Page | `Cmd + 1` |
| Single Page Continuous | `Shift + Cmd + 1` |
| Two Pages | `Cmd + 2` |
| Two Pages Continuous | `Shift + Cmd + 2` |
| Next Page | `Space` |
| Previous Page | `Shift + Space` |
| Jump to Page | Type page number or label (e.g., `123`, `iv`, `cover`) |
| Back / Forward | `Cmd + [` / `Cmd + ]` (navigation history) |
| Clear Selection / Cancel | `Esc` |
| Inverse Search | `Cmd + Click` on PDF |
| Character Inspection | Right-click on selected text |
| Measure / Move / Resize Area | `Shift + Drag` (drag inside an existing marquee to move it; drag edges/corners to resize) |
| Copy Selection | `Cmd + C` (while area is selected, copies as vector PDF) |
| Toggle PDF Info Sidebar | `Cmd + I` |
| Toggle PDF Bookmarks Sidebar | `Cmd + B` |
| Toggle PDF Annotations Sidebar | `Cmd + N` |

### Page Navigation & Interface Notes
* Direct Jump: when you type a page number or label without any modifier keys, a minimalist HUD will appear at the bottom to guide your jump instantly. The input auto-commits after 1 second of inactivity.
* Window Title Info: to keep the interface zero-distraction, the title bar dynamically displays `<FileName> - Page <label> (<physical>/<total>)` (e.g., `document.pdf - Page iv (4/120)`).
* Link Preview: hovering over a PDF link for 0.3 seconds shows a popover with a real-size snippet of the target page (internal links) or the URL text (external links). Clicking a link follows it normally.
* Navigation History: `Cmd + [` / `Cmd + ]` return to where you were before following a link, clicking a bookmark or annotation, jumping to a search match, or running a Forward Search — the same keys Preview uses.
* Persistence: Galley automatically remembers your Display Mode, Book Mode, RTL, and Page Color settings using `UserDefaults`.

### Custom Key Bindings (Vim-style and others)

Galley deliberately ships only standard macOS shortcuts and does not implement modal or Vim-like key handling. Single letters without modifiers are already reserved: typing `iv` or `cover` jumps to that page label, so `h`, `j`, `k`, `l`, `n` and `g` cannot double as commands without breaking direct page jumps.

Instead, every command is a menu item with a unique title, so you can bind whatever keys you like. There are three ways to do it, and which one you want depends on whether your binding uses a modifier key.

#### 1. System Settings (any binding with a modifier)

System Settings ▸ Keyboard ▸ Keyboard Shortcuts ▸ App Shortcuts ▸ `+`, choose GalleyPDF, and type the menu item title exactly as it appears in the menu bar (for example `Next Page`, `Back`, `Find Next`). Submenu items are addressed by their own title, not by a path.

#### 2. `defaults` (the same thing, scriptable)

App Shortcuts are stored as an `NSUserKeyEquivalents` dictionary in the app's preference domain. Galley's bundle identifier is `com.github.munepi.galley`. Modifiers are written as symbols: `@` Command, `~` Option, `^` Control, `$` Shift.

```bash
defaults write com.github.munepi.galley NSUserKeyEquivalents -dict "Next Page" "~j" "Previous Page" "~k" "Back" "~h" "Forward" "~l"
```

```bash
defaults read com.github.munepi.galley NSUserKeyEquivalents
```

```bash
defaults delete com.github.munepi.galley NSUserKeyEquivalents
```

`-dict` writes the whole dictionary at once, discarding any bindings already stored. To add a single binding to an existing set, use `-dict-add` — note that it accepts exactly one key/value pair per invocation, so repeat the command rather than chaining pairs.

```bash
defaults write com.github.munepi.galley NSUserKeyEquivalents -dict-add "Find Next" "~n"
```

Relaunch Galley for the change to take effect; run `killall cfprefsd` first if it does not. Titles must match exactly, including the ASCII ellipsis in items such as `Find...`.

Note that `NSUserKeyEquivalents` *replaces* a menu item's key equivalent rather than adding to it. Binding `Next Page` to `~j` removes `Space`, and binding `Back` to `~h` removes `Cmd + [`. If you want to keep both, use the next option.

#### 3. Karabiner-Elements (bare single keys, or keeping the built-in keys)

App Shortcuts cannot bind a key without a modifier, so bare `/` or `h` `j` `k` `l` need a remapper. Map them onto Galley's existing modifier shortcuts rather than sending bare letters — a bare letter is swallowed by the page-label input. Scoping the rule to Galley's bundle identifier keeps the rest of your system untouched, and unlike `defaults`, the built-in keys keep working.

Save the following as `~/.config/karabiner/assets/complex_modifications/galley.json`, then enable it from Karabiner-Elements ▸ Complex Modifications.

```json
{
  "title": "Galley",
  "rules": [
    {
      "description": "Galley: Opt+hjkl navigation, / for find",
      "manipulators": [
        {
          "type": "basic",
          "from": { "key_code": "j", "modifiers": { "mandatory": ["option"] } },
          "to": [{ "key_code": "spacebar" }],
          "conditions": [{ "type": "frontmost_application_if", "bundle_identifiers": ["^com\\.github\\.munepi\\.galley$"] }]
        },
        {
          "type": "basic",
          "from": { "key_code": "k", "modifiers": { "mandatory": ["option"] } },
          "to": [{ "key_code": "spacebar", "modifiers": ["left_shift"] }],
          "conditions": [{ "type": "frontmost_application_if", "bundle_identifiers": ["^com\\.github\\.munepi\\.galley$"] }]
        },
        {
          "type": "basic",
          "from": { "key_code": "h", "modifiers": { "mandatory": ["option"] } },
          "to": [{ "key_code": "open_bracket", "modifiers": ["left_command"] }],
          "conditions": [{ "type": "frontmost_application_if", "bundle_identifiers": ["^com\\.github\\.munepi\\.galley$"] }]
        },
        {
          "type": "basic",
          "from": { "key_code": "l", "modifiers": { "mandatory": ["option"] } },
          "to": [{ "key_code": "close_bracket", "modifiers": ["left_command"] }],
          "conditions": [{ "type": "frontmost_application_if", "bundle_identifiers": ["^com\\.github\\.munepi\\.galley$"] }]
        },
        {
          "type": "basic",
          "from": { "key_code": "slash" },
          "to": [{ "key_code": "f", "modifiers": ["left_command"] }],
          "conditions": [{ "type": "frontmost_application_if", "bundle_identifiers": ["^com\\.github\\.munepi\\.galley$"] }]
        }
      ]
    }
  ]
}
```

#### Vim equivalents

| Vim | Galley |
| :--- | :--- |
| `j` / `k`, `Ctrl-F` / `Ctrl-B` | `Space` / `Shift + Space` (`Next Page` / `Previous Page`) |
| `Ctrl-E` / `Ctrl-Y` | arrow keys |
| `{N}G`, `:{N}` | type the page number or label directly |
| `Ctrl-O` / `Ctrl-I` | `Cmd + [` / `Cmd + ]` (`Back` / `Forward`) |
| `/` | `Cmd + F` (`Find...`) |
| `n` / `N` | `Cmd + G` / `Shift + Cmd + G` (`Find Next` / `Find Previous`) |
| `*` | `Cmd + E` (`Use Selection for Find`) |
| `:noh` | `Esc` |
| `ignorecase` / `smartcase` | `Match Case` checkbox in the search bar |
| `\v` | `Regex` checkbox in the search bar |

Galley has no equivalent for `Ctrl-D` / `Ctrl-U`: a half screen is not a meaningful unit in a PDF, since it changes with the zoom level. Use `Next Page` / `Previous Page` instead. `gg` and `G` are likewise absent — typing a page label already jumps directly, so there is nothing left for them to do.


## Roadmap: The "Galley Pro" Ambitions

Galley is currently a focused, lightweight viewer. The following features are under consideration or in early exploration:

### 1. Universal SyncTeX Bridge: `pandoc-synctex`
A bidirectional synchronization bridge between structured text formats and Galley. By leveraging ASTs (like Pandoc's `+sourcepos`) and custom Lua filters, this would enable Forward/Inverse Search from the PDF back to sources in formats such as Typst, SATySFi, Vivliostyle (VFM), AsciiDoc, and Re:VIEW.

### 2. Hybrid Rendering Engine & Typography Inspector (Poppler + HarfBuzz + FreeType)
Apple's `PDFKit` is optimized for screen rendering and does not expose all print-related data. A hybrid backend using C++ libraries could provide:
* Output Preview: extracting CMYK and Spot Color (e.g., DIC, PANTONE) values via Poppler in `/Separation` and `/DeviceN` modes.
* Typography Inspector: displaying embedded font names, raw CIDs/GIDs, and subset statuses from the PDF stream.
* OpenType Shaping Validation: using HarfBuzz and FreeType to verify whether glyph positioning matches the font's kerning, ligatures, and complex text layout rules.

### 3. PDF/X & PDF/A Preflight and Fixup
Native PDF/X (X-1a, X-4) and PDF/A validation and fixup, including transparency flattening, bleed box generation, color conversions (via macOS ColorSync), and ICC profile tagging (`/OutputIntents`).

### 4. Extended URL Scheme API
Expanding the `galleypdf://` URL scheme to expose more features for editor integration and automation.

*The following endpoints are tentative:*
* Advanced Navigation: `galleypdf://page?num=iv` or `galleypdf://find?query=Theorem1`
* Build Integration: `galleypdf://highlight?page=5&rect=x,y,w,h` (visualizing compiler errors or Overfull hboxes directly on the PDF)
* Dynamic Configuration: `galleypdf://set?editor=vscode` (changing the target editor per project without restarting)
* Preflight & Visualization:
    * `galleypdf://boxes?show=trim,bleed` (overlaying TrimBox and BleedBox lines)
    * `galleypdf://fonts?audit=true` (highlighting un-embedded or Type 3 fonts)
    * `galleypdf://ink?tac=300` (highlighting Total Area Coverage violations)
    * `galleypdf://audit?warn=hairline&threshold=0.25` (detecting hairlines that might disappear in print)
* Document Manipulation & Diff:
    * `galleypdf://props?set=openaction&mode=UseOutlines` (forcing PDF open actions)
    * `galleypdf://diff?target=/path/to/old.pdf&mode=difference` (visual diffing for proofreaders)
* Export & Conversion:
    * `galleypdf://convert?format=pdfx4&input=<pdf>&output=<pdf>`
    * `galleypdf://convert?action=vivid-cmyk&n-colors=5` (algorithmic RGB-to-CMYK conversion mitigating gamut clipping, optionally injecting `/Separation` or `/DeviceN` for wide-gamut and vivid print results)
    * `galleypdf://imposition?layout=booklet` (dynamic N-up/Booklet preview and generation)

### 5. Command Line Interface (CLI)
Providing CLI access to preflight, export, imposition, and viewer control so that any GUI operation can also be scripted from the terminal.


## Why Galley?

Most PDF viewers are general-purpose readers, not optimized for the edit–compile–preview cycle of TeX/LaTeX work.
Galley is built with native macOS technologies (PDFKit, AppKit) and has no external dependencies, resulting in a small binary and fast startup.

It does not try to be a general-purpose PDF reader.
Instead, it aims to be a reliable companion for your text editor, updating your document in the background as you write.


## License

Distributed under the BSD 3-Clause License. See `LICENSE` for more information.

Copyright © 2026 Munehiro Yamamoto. All rights reserved.

--------------------

Munehiro Yamamoto
[https://github.com/munepi](https://github.com/munepi)
