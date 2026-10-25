+++
title = "Keyboard Shortcuts"
weight = 10
+++

# Keyboard Shortcuts

| Action                  | Shortcut / Gesture                                                            |
|-------------------------|--------------------------------------------------------------------------------|
| Open File               | `Cmd + O` or `open -a GalleyPDF document.pdf`                                  |
| Print                   | `Cmd + P`                                                                      |
| Quit                    | Hold `Cmd + Q`, or press it twice (Galley ▸ Warn Before Quitting turns this off) |
| Find                    | `Cmd + F` (toggle search bar)                                                  |
| Find Next / Previous    | `Cmd + G` / `Shift + Cmd + G` (also `Enter` / `Shift + Enter` while the search bar is focused) |
| Use Selection for Find  | `Cmd + E`                                                                      |
| Zoom In / Out           | `Cmd + +` / `Cmd + -`                                                          |
| Actual Size             | `Cmd + 0`                                                                      |
| Auto Resize             | `Cmd + _`                                                                      |
| Single Page             | `Cmd + 1`                                                                      |
| Single Page Continuous  | `Shift + Cmd + 1`                                                              |
| Two Pages               | `Cmd + 2`                                                                      |
| Two Pages Continuous    | `Shift + Cmd + 2`                                                              |
| Next Page               | `Space`                                                                        |
| Previous Page           | `Shift + Space`                                                                |
| Jump to Page            | Type page number or label (e.g., `123`, `iv`, `cover`)                         |
| Back / Forward          | `Cmd + [` / `Cmd + ]` (navigation history)                                     |
| Clear Selection / Cancel| `Esc`                                                                          |
| Inverse Search          | `Cmd + Click` on PDF                                                           |
| Character Inspection    | Right-click on selected text                                                   |
| Color Picker            | `Shift + Cmd + K` or right-click ▸ Color Picker (click to lock / unlock, `Esc` to close) |
| Copy Color as Text / as PDF | `Shift + Cmd + C` / `Option + Cmd + C` (while the Color Picker is open)    |
| Measure / Move / Resize Area | `Shift + Drag` (drag inside marquee to move; drag edges/corners to resize) |
| Copy Selection          | `Cmd + C` (copies as vector PDF)                                               |
| Toggle PDF Info Sidebar | `Cmd + I`                                                                      |
| Toggle PDF Bookmarks Sidebar | `Cmd + B`                                                                 |
| Toggle PDF Annotations Sidebar | `Cmd + N`                                                               |
| Copy Annotation Content | `Cmd + C` (with an Annotations row selected)                                   |
| Enter / Exit Full Screen | macOS standard (View ▸ Enter Full Screen, `Fn + F`)                           |
| Minimize                | `Cmd + M`                                                                      |
| Window Tiling           | macOS standard (Window ▸ Move & Resize, `Fn + Ctrl + Arrow keys`)             |

Every one of these is a menu item, and every menu item can be rebound; see
[Custom Key Bindings]({{< relref "key-bindings" >}}).

## Page Navigation & Interface Notes

- Direct Jump: type a page number or label without modifier keys, and a
  minimalist HUD appears at the bottom. Input auto-commits after 1 second of
  inactivity.
- Window Title: displays `<FileName> - Page <label> (<physical>/<total>)`
  for a zero-distraction interface.
- Link Preview: hovering over a PDF link for 0.3 s shows a popover with a
  real-size snippet of the target page (internal links) or the URL text
  (external links).
- Navigation History: `Cmd + [` / `Cmd + ]` return to where you were before
  following a link, clicking a bookmark or annotation, jumping to a search
  match, or running a Forward Search, the same keys Preview uses.
- Last Position: reopening a PDF, after opening another one or after
  quitting, brings back the page, the position on it and the zoom you left it
  at. Galley finds the record by the file's path and, for a file that has
  since been moved or renamed, by a SHA-256 of its contents. If the page count
  has changed (a recompile that reflowed the document, or a different file
  under the same name), it opens at page 1 as before. A Forward Search and
  `galleypdf open --page` always take precedence. View ▸ Restore Last Position
  turns this off.
- Hold to Quit: a quick `Cmd + Q` only shows "Hold ⌘Q to Quit"; keep holding
  for a second, or press it again while the message is showing, to quit, as
  in Chrome. It guards the preview against a stray keystroke while you type in
  your editor. Quitting from the menu, the Dock or a script is immediate, and
  Galley ▸ Warn Before Quitting restores the immediate `Cmd + Q`.
- No `Cmd + W`: Galley has a single window, so closing it quits the app.
  File ▸ Close is left without a key; bind one yourself if you want it, as
  shown in [Custom Key Bindings]({{< relref "key-bindings" >}}).
- macOS 27 and Single Page / Two Pages: PDFKit on macOS 27 stops turning the
  page on `Space`, `Page Down`, `Page Up` and the arrow keys in the
  non-continuous modes whenever its scroll view carries a content inset, as it
  does under Galley's full-size title bar (Skim is affected the same way).
  Galley 0.8 and later detect the stuck key and turn the page themselves.
- Persistence: Galley remembers Display Mode, Book Mode, RTL,
  [Page Color]({{< relref "/docs/features/page-color" >}}), Restore Last
  Position and Warn Before Quitting via `UserDefaults`, and puts the
  [Color Picker]({{< relref "/docs/features/color-picker" >}}) panel back where
  you last left it, with its display mode and simulation profile.
